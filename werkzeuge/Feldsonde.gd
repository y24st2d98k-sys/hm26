extends Node
## Zeigt die Live-Ansicht wirklich das, was im Spiel passiert?
##
## Die Simulation ist vielfach gemessen, die Ansicht darauf nie. Und dort steckte
## ein Fehler, den man sehen konnte: der Ball wurde vor einem Abschluss zum
## eigenen Torwart gepasst und von dessen Position ins gegnerische Tor geworfen.
## Die Ursache war eine Verwechslung im Ereignis — bei einer Parade ist "team"
## die haltende Mannschaft und "spieler" ihr Torwart, und die Ansicht las beides
## als Angreifer und Werfer. Rund ein Drittel aller Angriffe endet mit Parade
## oder Block; alle liefen falschherum ab.
##
## Diese Sonde spielt eine ganze Partie durch die echte Live-Ansicht und prüft
## nach jedem Takt, ob Bild und Simulation zusammenpassen. Dazu zählt sie, wie
## viel sich überhaupt bewegt — ein Handballspiel, in dem nur der Ballträger
## läuft, sieht aus wie eine Tabelle mit Kreisen.
##
##     godot --headless res://werkzeuge/Feldsonde.tscn -- [partien]

const SAAT := 33771
## Wie nah der Ball dem eigenen Tor kommen darf, ohne dass es der Torwart ist.
const EIGENES_TOR_ABSTAND := 4.0
## Bildrate, mit der die Bewegung zwischen den Takten nachgerechnet wird.
const BILDER_JE_TAKT := 12
const BILDZEIT := 1.0 / 60.0

var fehler: int = 0
var geprueft: int = 0

func _log(t: String) -> void:
	printerr(t)

func _pruefe(bedingung: bool, was: String) -> void:
	geprueft += 1
	if not bedingung:
		fehler += 1
		_log("   FEHLER: %s" % was)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var partien: int = int(args[0]) if args.size() > 0 else 1
	seed(SAAT)
	var vorschau := Weltgenerator.erzeuge(2026, SAAT)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Feld", "nachname": "Sonde"}, SAAT)

	_log("")
	_log("=== Die Live-Ansicht, %d Partie(n) ===" % partien)

	var gesamt := {"takte": 0, "wuerfe": 0, "bewegungen": 0, "paesse": 0,
		"laeufer": 0.0, "bilder": 0, "ohne_ball": 0.0}
	for i in range(partien):
		var mid := _eigene_partie()
		if mid == "":
			_log("   Keine eigene Partie gefunden.")
			break
		_partie_spielen(mid, gesamt)

	var bilder: float = maxf(float(gesamt["bilder"]), 1.0)
	_log("")
	_log("Takte: %d  (davon %d Pässe, %d Würfe, %d Bewegungen ohne Ball)" % [
		int(gesamt["takte"]), int(gesamt["paesse"]), int(gesamt["wuerfe"]),
		int(gesamt["bewegungen"])])
	_log("In Bewegung je Bild: %.2f Spieler von 14, davon %.2f ohne Ball" % [
		float(gesamt["laeufer"]) / bilder, float(gesamt["ohne_ball"]) / bilder])
	_log("")
	if fehler == 0:
		_log("— Feldsonde bestanden (%d Prüfungen) —" % geprueft)
	else:
		_log("— Feldsonde: %d von %d Prüfungen fehlgeschlagen —" % [fehler, geprueft])
	get_tree().quit()

func _eigene_partie() -> String:
	for i in range(400):
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			return str(u["spiel"])
	return ""

func _partie_spielen(mid: String, gesamt: Dictionary) -> void:
	var live := LiveSpiel.new()
	live.visible = true
	add_child(live)
	live.starte(mid)
	live._setze_tempo(2)
	live.uhr.stop()
	var feld: Spielfeld = live.feld
	var schritte := 0
	while not live.fertig and schritte < 8000:
		var vorher_ball: Vector2 = feld._ballpunkt()
		var offen: int = (live._zug as Array).size()
		var art := ""
		if offen > 0:
			art = str(((live._zug as Array)[0] as Dictionary).get("art", ""))
		live._schritt()
		schritte += 1
		if art != "":
			gesamt["takte"] = int(gesamt["takte"]) + 1
			match art:
				"pass": gesamt["paesse"] = int(gesamt["paesse"]) + 1
				"wurf": gesamt["wuerfe"] = int(gesamt["wuerfe"]) + 1
				"bewegung": gesamt["bewegungen"] = int(gesamt["bewegungen"]) + 1
		_takt_pruefen(live, feld, art, vorher_ball)
		_bewegung_messen(feld, gesamt)
	live.queue_free()

## Nach jedem Takt: passt das Bild zur Simulation?
func _takt_pruefen(live: LiveSpiel, feld: Spielfeld, art: String, _vorher: Vector2) -> void:
	var seite: String = str(feld.angreifer)
	if seite != "heim" and seite != "gast":
		return
	var eigenes_tor: Vector2 = feld.tormitte("gast" if seite == "heim" else "heim")
	var ziel: Vector2 = feld._ball_nach
	# Der Ball darf im Angriff nicht am eigenen Tor landen. Genau das war der
	# Fehler: ein Pass zum eigenen Torwart, und von dort der Wurf.
	if art == "pass" or art == "wurf":
		_pruefe(ziel.distance_to(eigenes_tor) > EIGENES_TOR_ABSTAND,
			"%s der %s-Mannschaft landet %.1f m vor dem eigenen Tor" % [
				art, seite, ziel.distance_to(eigenes_tor)])
	# Und im Aufbau traegt niemals der eigene Torwart den Ball.
	#
	# Direkt nach einer Parade hat er ihn — das ist Handball und kein Fehler,
	# und die erste Fassung dieser Sonde hat es als einen gezaehlt. Geprueft wird
	# deshalb nur, was wirklich falsch waere: ein Pass oder ein Wurf, bei dem er
	# der Ballfuehrende ist.
	var mannschaft: Dictionary = live.sim.heim if seite == "heim" else live.sim.gast
	var tw: String = str((mannschaft["angriff_auf"] as Dictionary).get("TW", ""))
	if tw != "" and str(feld.hervorgehoben) != "" and (art == "pass" or art == "wurf"):
		_pruefe(str(feld.hervorgehoben) != tw,
			"der Torwart der %s-Mannschaft führt den Ball bei einem %s" % [seite, art])
	# Ein Wurf geht auf die Hälfte des Gegners.
	if art == "wurf":
		var gegentor: Vector2 = feld.tormitte(seite)
		_pruefe(ziel.distance_to(gegentor) < ziel.distance_to(eigenes_tor),
			"Wurf der %s-Mannschaft geht Richtung eigenes Tor" % seite)

## Wie viel bewegt sich zwischen zwei Takten — und wie viel davon ohne Ball?
func _bewegung_messen(feld: Spielfeld, gesamt: Dictionary) -> void:
	for b in range(BILDER_JE_TAKT):
		var vorher := {}
		for sid in (feld._ist as Dictionary).keys():
			vorher[sid] = feld._ist[sid]
		feld._process(BILDZEIT)
		var laeufer := 0
		var ohne_ball := 0
		for sid2 in (feld._ist as Dictionary).keys():
			if not vorher.has(sid2):
				continue
			if (feld._ist[sid2] as Vector2).distance_to(vorher[sid2]) > 0.002:
				laeufer += 1
				if str(sid2) != str(feld.hervorgehoben):
					ohne_ball += 1
		gesamt["laeufer"] = float(gesamt["laeufer"]) + float(laeufer)
		gesamt["ohne_ball"] = float(gesamt["ohne_ball"]) + float(ohne_ball)
		gesamt["bilder"] = int(gesamt["bilder"]) + 1
