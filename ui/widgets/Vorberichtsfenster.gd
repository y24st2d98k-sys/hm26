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
	panel.custom_minimum_size = Vector2(880, 600)
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
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)

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
	var b := Vorbericht.erzeuge(Welt.daten, Welt.mein_verein_id, gegner)
	var s: int = int(b["stufe"])

	var kopfkarte := Bausteine.karte_in(inhalt, "Erkenntnisstand")
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

	if s >= 1:
		var mitte := Stil.hbox(12)
		inhalt.add_child(mitte)
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
			kopfz.add_child(Bausteine.positions_abzeichen(str(Welt.spieler(sid2)["position"])))
			var k2 := Stil.knopf_flach(Spielerfabrik.voller_name(Welt.spieler(sid2)), Stil.AKZENT)
			k2.pressed.connect(func(): Spielerfenster.oeffnen(self, sid2))
			kopfz.add_child(k2)
			z.add_child(Stil.matt("   " + str(e["hinweis"]), Stil.S_MINI))

	if s >= 2 and not (b["taktik"] as Dictionary).is_empty():
		var t: Dictionary = b["taktik"]
		var taktikkarte := Bausteine.karte_in(inhalt, "Ausrichtung des Gegners")
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
	inhalt.add_child(unten)
	var st := Bausteine.karte_in(unten, "Stärken")
	Stil.karte_wurzel(st).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in b["staerken"]:
		st.add_child(Stil.text("• " + str(e), Stil.S_KLEIN, Stil.ROT))
	var sw := Bausteine.karte_in(unten, "Ansatzpunkte")
	Stil.karte_wurzel(sw).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in b["schwaechen"]:
		sw.add_child(Stil.text("• " + str(e), Stil.S_KLEIN, Stil.GRUEN))

	if s >= 3 and not (b["wurfverteilung"] as Dictionary).is_empty():
		var wk := Bausteine.karte_in(inhalt, "Wurfverteilung des Gegners")
		var wv: Dictionary = b["wurfverteilung"]
		for pos in ["LA", "RL", "RM", "RR", "RA", "KM"]:
			if not wv.has(pos):
				continue
			wk.add_child(Bausteine.wertzeile(str(Spielerfabrik.POSITION_NAME.get(pos, pos)),
				float(wv[pos]) * 100.0, 40.0, "%s %%" % Stil.komma(float(wv[pos]) * 100.0, 0)))

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
		inhalt.add_child(auftrag)
