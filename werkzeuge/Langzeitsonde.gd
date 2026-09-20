extends Node
## Kippt die Liga, wenn einer über Jahre gut arbeitet?
##
## Seit die Trainingsarbeit wirklich etwas ändert, steht die Gegenfrage im
## Raum: entwickelt ein Mensch, der sich kümmert, seinen Kader so viel
## schneller als die Konkurrenz, dass er die Liga nach ein paar Spielzeiten
## nicht mehr verlässt? Ein Managerspiel soll Können belohnen — aber es soll
## eine Liga bleiben und kein Selbstläufer.
##
## Die erste Fassung dieser Sonde führte den Verein nur über das Training und
## verlängerte keine Verträge; der Kader blutete aus und der Trainer flog nach
## drei Spielzeiten. Das beantwortete die Frage nicht, sondern wich ihr aus.
##
## Jetzt führt KI.verein_fuehren() den Verein wie ein ordentlicher Manager —
## Verträge, Zugänge, Personal, Infrastruktur — und darüber liegt je nach
## Aufruf eine Schicht besserer Arbeit:
##
##     godot --headless res://werkzeuge/Langzeitsonde.tscn -- <spielzeiten> <art>
##     art: "solide"  — nur KI.verein_fuehren, ein kompetenter Durchschnitt
##          "gut"     — dazu Sonderprogramme für alle Talente, Regeneration
##                      nach Lastkonto und Einsatzzeit für die Jungen

const SAAT := 4242

func _log(t: String) -> void:
	printerr(t)

var art: String = "gut"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var spielzeiten: int = int(args[0]) if args.size() > 0 else 8
	art = str(args[1]) if args.size() > 1 else "gut"
	var vorschau := Weltgenerator.erzeuge(2026, SAAT)
	# Ein Verein aus der Mitte.
	#
	# Bewusst kein Spitzenverein: bei Magdeburg wäre jeder Titel auch ohne gute
	# Arbeit zu erwarten. Aber auch keiner aus dem hinteren Drittel — gemessen
	# hat der Fünfzehnte mit und ohne Führung 29 beziehungsweise 30 Punkte und
	# flog danach. Das beantwortet die Frage nach der Liga nicht, es beendet
	# nur die Messung.
	var liste: Array = vorschau["ligen"]["l_de1"]["vereine"]
	var cid: String = str(liste[int(liste.size() / 2)])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Lang", "nachname": "Zeit"}, SAAT)
	var d: Dictionary = Welt.daten
	_log("")
	_log("=== %d Spielzeiten, Fuehrung %s: %s ===" % [spielzeiten, art,
		str(d["vereine"][cid]["name"])])
	_log("")
	if art == "gut":
		var p: Dictionary = Training.plan(d, cid)
		p["intensitaet"] = 62
		p["schwerpunkt"] = "ausgeglichen"

	_log("%-8s %6s %7s %8s %10s %9s %8s" % ["Saison", "Platz", "Punkte", "Kader Ø",
		"Ligaschnitt", "Abstand", "u23 Ø"])
	# Der Bericht wird nicht an der Unterbrechung "saisonende" gezogen.
	#
	# Die Sonde ruft Welt.saison_pruefen() nach jeder Partie selbst auf, und
	# dabei kann der Saisonwechsel schon durchgelaufen sein, bevor die
	# Unterbrechung hier ankommt. Gemeldet wurden dann Platz 18 mit null
	# Punkten und ein Ligaschnitt von 58 — die frisch zurueckgesetzte Tabelle
	# der neuen Spielzeit. Stattdessen wird jeden Tag ein Abzug mitgefuehrt
	# und der letzte vor dem Wechsel gedruckt.
	var saison := 0
	var tage := 0
	var wochentag := -1
	var letzter_stand: Array = []
	var saison_index: int = Welt.saison_index()
	while saison < spielzeiten and tage < spielzeiten * 380:
		var u := Welt.tag_weiter()
		tage += 1
		# Einmal die Woche führen, wie die KI es für ihre Vereine tut.
		var wt: int = Kalender.wochentag(Welt.tag())
		if wt == 0 and wt != wochentag and Welt.mein_verein_id != "":
			KI.verein_fuehren(d, cid)
			if art == "gut":
				_besser_arbeiten(d, cid)
		wochentag = wt
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		if Welt.mein_verein_id == "":
			# Erst die letzte Spielzeit drucken, dann abbrechen: die
			# Entlassung faellt am Saisonende, und ohne diese Reihenfolge
			# stand von der Saison, die dazu gefuehrt hat, keine Zeile da.
			if not letzter_stand.is_empty():
				_drucken(saison, letzter_stand)
			_log("   Verein nach %d Tagen verloren — entlassen." % tage)
			break
		var stand := _abzug(d, cid)
		if not stand.is_empty():
			letzter_stand = stand
		var jetzt: int = Welt.saison_index()
		if jetzt != saison_index:
			saison_index = jetzt
			if not letzter_stand.is_empty():
				_drucken(saison, letzter_stand)
			saison += 1
	_log("")
	_log("Ein Abstand, der von Spielzeit zu Spielzeit wächst, heißt: die Liga kippt.")
	get_tree().quit()

## Was ein Trainer zusätzlich tut, der sich wirklich kümmert.
func _besser_arbeiten(d: Dictionary, cid: String) -> void:
	if not (d.get("vereine", {}) as Dictionary).has(cid):
		return
	var p: Dictionary = Training.plan(d, cid)
	p["intensitaet"] = clampi(int(p["intensitaet"]), 55, 68)
	var budget: int = Training.regenerationsbudget(d, cid)
	var kader: Array = (d["vereine"][cid]["kader"] as Array).duplicate()
	kader.sort_custom(func(a, b): return float(d["spieler"][str(a)]["last"]) > float(d["spieler"][str(b)]["last"]))
	var zuteilung := {}
	for i in range(mini(budget, kader.size())):
		if float(d["spieler"][str(kader[i])]["last"]) > 40.0:
			zuteilung[str(kader[i])] = 1
	p["regeneration_zuteilung"] = zuteilung
	for sid in kader:
		var sp: Dictionary = d["spieler"][str(sid)]
		if int(sp["alter"]) <= 23:
			sp["trainingsfokus"] = "athletik" if int(sp["alter"]) <= 20 else "wurf"

## Der heutige Stand als Zahlenreihe. Leer, solange noch keine Partie gespielt
## ist — eine Tabelle mit null Spielen sagt nichts.
func _abzug(d: Dictionary, cid: String) -> Array:
	if not (d.get("vereine", {}) as Dictionary).has(cid):
		return []
	var lid: String = str(d["vereine"][cid]["liga"])
	var zeile: Dictionary = (d["ligen"][lid]["tabelle"] as Dictionary).get(cid,
		Spielplan.leere_tabellenzeile())
	if int(zeile["sp"]) <= 0:
		return []
	var tabelle: Array = Spielplan.tabelle_sortiert(d, lid)
	var eigen: float = _staerke(d, cid)
	var summe := 0.0
	var anzahl := 0
	for c in tabelle:
		summe += _staerke(d, str(c))
		anzahl += 1
	var schnitt: float = summe / maxf(float(anzahl), 1.0)
	return [float(tabelle.find(cid) + 1), float(int(zeile["punkte"])), eigen, schnitt,
		eigen - schnitt, _jung(d, cid), float(int(zeile["sp"]))]

func _drucken(saison: int, stand: Array) -> void:
	_log("%-8d %6d %7d %8.1f %10.1f %9.1f %8.1f   (%d Spiele)" % [saison + 1,
		int(stand[0]), int(stand[1]), float(stand[2]), float(stand[3]), float(stand[4]),
		float(stand[5]), int(stand[6])])

## Die acht Stärksten — sie beschreiben eine Mannschaft besser als der
## Kaderschnitt, in dem der dritte Torwart mitzählt.
func _staerke(d: Dictionary, cid: String) -> float:
	var v: Dictionary = (d.get("vereine", {}) as Dictionary).get(cid, {})
	if v.is_empty():
		return 0.0
	var beste: Array = []
	for sid in (v.get("kader", []) as Array):
		beste.append(Spielerfabrik.gesamt(d["spieler"][str(sid)]))
	beste.sort()
	beste.reverse()
	var summe := 0.0
	var k: int = mini(8, beste.size())
	for i in k:
		summe += float(beste[i])
	return summe / maxf(float(k), 1.0)

func _jung(d: Dictionary, cid: String) -> float:
	var v: Dictionary = (d.get("vereine", {}) as Dictionary).get(cid, {})
	var summe := 0.0
	var anzahl := 0
	for sid in (v.get("kader", []) as Array):
		var sp: Dictionary = d["spieler"][str(sid)]
		if int(sp["alter"]) <= 23:
			summe += Spielerfabrik.gesamt(sp)
			anzahl += 1
	return summe / maxf(float(anzahl), 1.0)
