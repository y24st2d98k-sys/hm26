class_name Vorberichtsfenster
extends Control
## Spielvorbereitung: alles, was die Analyseabteilung über den nächsten Gegner weiß.

var gegner: String = ""
var spiel_id: String = ""
var inhalt: VBoxContainer
var kopftitel: Label

static func oeffnen(von: Node, gegner_id: String, mid: String = "") -> void:
	var f = von.get_tree().get_first_node_in_group("vorberichtsfenster")
	if f != null:
		f.zeige(gegner_id, mid)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("vorberichtsfenster")

func _ready() -> void:
	theme = Stil.theme()
	var schleier := ColorRect.new()
	schleier.color = Color(0, 0, 0, 0.62)
	schleier.set_anchors_preset(Control.PRESET_FULL_RECT)
	schleier.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			visible = false)
	add_child(schleier)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mitte)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(940, 700)
	panel.add_theme_stylebox_override("panel", Stil.box(Stil.FLAECHE, Stil.R_GROSS, Stil.RAND_HELL))
	mitte.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(m)
	var v := Stil.vbox(10)
	m.add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopftitel = Stil.titel("Spielvorbereitung", 1)
	kopf.add_child(kopftitel)
	kopf.add_child(Stil.dehner())
	var zu := Stil.knopf("Schließen")
	zu.pressed.connect(func(): visible = false)
	kopf.add_child(zu)
	# Kein Rollbereich um das ganze Fenster: die Reiter bringen ihren eigenen
	# mit, und zwei ineinander sind einer zu viel.
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(inhalt)

## Welcher Reiter offen steht.
var reiter := "bild"

func zeige(gegner_id: String, mid: String = "") -> void:
	gegner = gegner_id
	spiel_id = mid
	visible = true
	_zeichne()

func _zeichne() -> void:
	for k in inhalt.get_children():
		k.queue_free()
	if gegner == "" or not Welt.daten.get("vereine", {}).has(gegner):
		inhalt.add_child(Stil.matt("Kein Gegner ausgewählt."))
		return
	var g: Dictionary = Welt.verein(gegner)
	kopftitel.text = "Spielvorbereitung — %s" % str(g["name"])
	var b := Vorbericht.erzeuge(Welt.daten, Welt.mein_verein_id, gegner, spiel_id)
	var s: int = int(b["stufe"])

	# Drei Reiter: das Bild, das man vom Gegner hat; wer bei ihm spielt; wie er
	# spielt. Untereinander war der Vorbericht mehr als zwei Fensterhoehen,
	# und die Wurfverteilung hat vor dem Spiel niemand gesehen.
	var gruppe := Stil.reitergruppe([
		{"id": "bild", "name": "Lage"},
		{"id": "kader", "name": "Aufstellung"},
		{"id": "taktik", "name": "Spielweise"},
	], reiter)
	gruppe.bei_wechsel = func(id): reiter = str(id)
	inhalt.add_child(gruppe)
	var f_bild := gruppe.feld("bild")

	var kopfkarte := Bausteine.karte_in(f_bild, "Erkenntnisstand")
	var zeile := Stil.hbox(10)
	kopfkarte.add_child(zeile)
	zeile.add_child(Wappen.fuer_verein(gegner, 40.0))
	var spalte := Stil.vbox(2)
	zeile.add_child(spalte)
	spalte.add_child(Stil.titel(str(g["name"]), 2))
	spalte.add_child(Stil.matt(str(b["text"])))
	zeile.add_child(Stil.dehner())
	zeile.add_child(Stil.balken(float(s), 3.0, 130, Stil.TUERKIS))
	zeile.add_child(Stil.abzeichen("Stufe %d von 3" % s, Stil.TUERKIS))
	if s < 3:
		kopfkarte.add_child(Stil.matt(
			"Ein Scoutauftrag auf diesen Gegner und eine bessere Analyseabteilung schärfen das Bild.",
			Stil.S_MINI))

	_gespann_karte(b, f_bild)

	if s >= 1:
		var mitte := Stil.hbox(12)
		gruppe.feld("kader").add_child(mitte)
		var formation := Bausteine.karte_in(mitte, "Voraussichtliche Aufstellung")
		Stil.karte_wurzel(formation).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var liste: Array = b["formation"]
		if liste.is_empty():
			formation.add_child(Stil.matt("Keine belastbare Aufstellung ermittelt."))
		else:
			var gr := Stil.tabelle(["Pos", "Spieler", "Stärke"])
			gr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			formation.add_child(gr)
			for e in liste:
				gr.add_child(Bausteine.positions_abzeichen(str(e["position"])))
				var sid: String = str(e["spieler"])
				var k := Stil.knopf_flach(Spielerfabrik.voller_name(Welt.spieler(sid)))
				k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
				gr.add_child(k)
				gr.add_child(Stil.text(str(e["staerke"]), Stil.S_KLEIN, Stil.AKZENT))

		var schluessel := Bausteine.karte_in(mitte, "Schlüsselspieler")
		Stil.karte_wurzel(schluessel).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sl: Array = b["schluesselspieler"]
		if sl.is_empty():
			schluessel.add_child(Stil.matt("Noch keine aussagekräftigen Saisondaten."))
		for e in sl:
			var sid2: String = str(e["spieler"])
			var z := Stil.vbox(1)
			schluessel.add_child(z)
			var kopfz := Stil.hbox(6)
			z.add_child(kopfz)
			kopfz.add_child(Portraet.fuer_spieler(sid2, 28.0))
			kopfz.add_child(Bausteine.positions_abzeichen(str(Welt.spieler(sid2)["position"])))
			kopfz.add_child(Flagge.fuer(str(Welt.spieler(sid2)["nation"]), 16.0))
			var k2 := Stil.knopf_flach(Spielerfabrik.voller_name(Welt.spieler(sid2)), Stil.AKZENT)
			k2.pressed.connect(func(): Spielerfenster.oeffnen(self, sid2))
			kopfz.add_child(k2)
			z.add_child(Stil.matt("   " + str(e["hinweis"]), Stil.S_MINI))

	_trainerkarte(gruppe.feld("taktik"))

	if s >= 2 and not (b["taktik"] as Dictionary).is_empty():
		var t: Dictionary = b["taktik"]
		var taktikkarte := Bausteine.karte_in(gruppe.feld("taktik"), "Ausrichtung des Gegners")
		var tz := Stil.hbox(10)
		taktikkarte.add_child(tz)
		tz.add_child(Stil.abzeichen("Abwehr %s" % str(t["abwehr"]), Stil.BLAU))
		tz.add_child(Stil.abzeichen(Vorbericht.ANGRIFF_NAME.get(str(t["angriff"]), str(t["angriff"])), Stil.LILA))
		tz.add_child(Stil.abzeichen(str(t["mentalitaet"]).capitalize(), Stil.TUERKIS))
		tz.add_child(Stil.dehner())
		taktikkarte.add_child(Bausteine.wertzeile("Tempo", float(t["tempo"])))
		taktikkarte.add_child(Bausteine.wertzeile("Härte", float(t["haerte"])))
		if str(b["empfehlung"]) != "":
			taktikkarte.add_child(Stil.text(str(b["empfehlung"]), Stil.S_NORMAL, Stil.GRUEN))

	var unten := Stil.hbox(12)
	f_bild.add_child(unten)
	var st := Bausteine.karte_in(unten, "Stärken")
	Stil.karte_wurzel(st).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in b["staerken"]:
		st.add_child(Stil.text("• " + str(e), Stil.S_KLEIN, Stil.ROT))
	var sw := Bausteine.karte_in(unten, "Ansatzpunkte")
	Stil.karte_wurzel(sw).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in b["schwaechen"]:
		sw.add_child(Stil.text("• " + str(e), Stil.S_KLEIN, Stil.GRUEN))

	if s >= 3 and not (b["wurfverteilung"] as Dictionary).is_empty():
		var wk := Bausteine.karte_in(gruppe.feld("taktik"), "Wurfverteilung des Gegners")
		var wv: Dictionary = b["wurfverteilung"]
		for pos in ["LA", "RL", "RM", "RR", "RA", "KM"]:
			if not wv.has(pos):
				continue
			wk.add_child(Bausteine.wertzeile(str(Spielerfabrik.POSITION_NAME.get(pos, pos)),
				float(wv[pos]) * 100.0, 40.0, "%s %%" % Stil.komma(float(wv[pos]) * 100.0, 0)))

	if Welt.mein_verein_id == "":
		return
	var scouts := Scouting.scouts(Welt.daten, Welt.mein_verein_id)
	if not scouts.is_empty() and s < 3:
		var auftrag := Stil.knopf_primaer("Scout auf %s ansetzen" % str(g["kurz"]))
		auftrag.pressed.connect(func():
			var erg := Scouting.auftrag_erteilen(Welt.daten, str(scouts[0]), "gegner", gegner)
			if bool(erg["ok"]):
				auftrag.disabled = true
				auftrag.text = "Auftrag erteilt"
			else:
				auftrag.text = str(erg["grund"]))
		f_bild.add_child(auftrag)

## Wer pfeift — und was das für die eingestellte Härte bedeutet.
##
## Diese Karte steht bewusst vor der Gegneranalyse: die Härte ist die einzige
## Einstellung, die man wegen des Gespanns wirklich anfasst, und sie soll
## einem ins Auge fallen, bevor man sich in Wurfverteilungen vertieft.
func _gespann_karte(b: Dictionary, eltern: Node) -> void:
	var g: Dictionary = b.get("gespann", {})
	if g.is_empty():
		return
	var karte := Bausteine.karte_in(eltern, "Das Gespann")
	var q: float = Schiedsrichter.zeitstrafen_quote(g)
	var farbe: Color = Stil.prozent_farbe(clampf(100.0 - (q - 2.0) * 24.0, 0.0, 100.0))
	var zeile := Stil.hbox(12)
	karte.add_child(zeile)
	var spalte := Stil.vbox(2)
	spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zeile.add_child(spalte)
	spalte.add_child(Stil.text(Schiedsrichter.namen_lang(g), Stil.S_NORMAL))
	spalte.add_child(Bausteine.fliesstext(str(b.get("gespann_hinweis", "")), Stil.S_KLEIN))
	zeile.add_child(Stil.dehner())
	zeile.add_child(Stil.abzeichen(Schiedsrichter.ruf(g), farbe))
	# Die zweite Anlage des Gespanns: gleicht es eine einseitige Strafenbilanz
	# wieder aus? Das ist keine Statistik, sondern Charakter — und es aendert,
	# was eine Zeitstrafe zur Unzeit wirklich kostet.
	zeile.add_child(Stil.abzeichen(Schiedsrichter.ausgleich_text(g), Stil.TEXT_MATT))
	if int(g["spiele"]) > 0:
		var zahlen := Stil.hbox(18)
		karte.add_child(zahlen)
		zahlen.add_child(_gespann_zahl("Spiele geleitet", str(int(g["spiele"])), Stil.TEXT))
		zahlen.add_child(_gespann_zahl("Zeitstrafen je Spiel", "%.1f" % q, farbe))
		zahlen.add_child(_gespann_zahl("Siebenmeter je Spiel",
			"%.1f" % Schiedsrichter.siebenmeter_quote(g), Stil.TEXT))
		zahlen.add_child(_gespann_zahl("Rote Karten", str(int(g["rote"])), Stil.TEXT))
	# Die eigene Einstellung daneben: erst der Vergleich macht die Zahl zur
	# Entscheidung. Ein 78er-Härtewert ist für sich genommen nichts.
	var haerte: float = float(Welt.mein_verein()["taktik"]["haerte"])
	var erwartet: float = Matchsim.zeitstrafenquote_bei_haerte(haerte) \
		* Schiedsrichter.strenge_faktor(g) * 110.0
	karte.add_child(Stil.matt(
		"Ihre Härte steht auf %d. Bei diesem Gespann sind daraus rund %.1f Zeitstrafen zu erwarten." % [
			int(haerte), erwartet], Stil.S_MINI))

func _gespann_zahl(beschriftung: String, wert: String, farbe: Color) -> Control:
	var v := Stil.vbox(1)
	v.add_child(Stil.etikett(beschriftung))
	v.add_child(Stil.text(wert, Stil.S_GROSS, farbe))
	return v


## Wer auf der anderen Bank sitzt.
##
## Bis vor Kurzem saß dort niemand: die siebzehn anderen Vereine waren
## Wartungsroutinen mit unterschiedlichem Etat, und deshalb spielten sie alle
## gleich. Jetzt hat jeder einen Trainer mit einer Handschrift — und die steht
## hier, damit man sie vor dem Spiel liest und nicht erst hinterher merkt.
func _trainerkarte(eltern: Node) -> void:
	var t: Dictionary = Gegnertrainer.fuer(Welt.daten, gegner)
	if t.is_empty():
		return
	var karte := Bausteine.karte_in(eltern, "Auf der anderen Bank")
	var kopf := Stil.hbox(10)
	karte.add_child(kopf)
	kopf.add_child(Stil.text(Gegnertrainer.voller_name(t), Stil.S_NORMAL, Stil.TEXT))
	kopf.add_child(Stil.abzeichen(str(t.get("archetyp_name", "")).to_upper(), Stil.LILA))
	kopf.add_child(Stil.dehner())
	var spiele: int = int(t.get("spiele", 0))
	if spiele > 0:
		kopf.add_child(Stil.matt("%d Spiele, %d Siege" % [spiele, int(t.get("siege", 0))], Stil.S_MINI))
	karte.add_child(Bausteine.fliesstext(Gegnertrainer.beschreibung(Welt.daten, gegner),
		Stil.S_KLEIN, null, 260.0))
	# Nur die beiden ausgeprägtesten Achsen: sechs Balken sind eine Tabelle,
	# zwei Sätze sind eine Einschätzung.
	var achsen: Dictionary = t.get("achsen", {})
	var sortiert: Array = []
	for a in achsen.keys():
		sortiert.append({"achse": str(a), "abstand": absf(float(achsen[a]) - 50.0),
			"wert": float(achsen[a])})
	sortiert.sort_custom(func(x, y): return float(x["abstand"]) > float(y["abstand"]))
	var zeile := Stil.hbox(8)
	karte.add_child(zeile)
	for e in sortiert.slice(0, 3):
		var eintrag: Dictionary = e
		var name: String = str(eintrag["achse"])
		var info: Dictionary = Trainerkarriere.ACHSEN.get(name, {})
		if info.is_empty():
			continue
		var seite: String = str(info["rechts"]) if float(eintrag["wert"]) >= 50.0 else str(info["links"])
		zeile.add_child(Stil.abzeichen(seite, Stil.TUERKIS))
