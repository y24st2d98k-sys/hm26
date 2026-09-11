class_name Spielbericht
extends Control
## Nachbericht einer gespielten Partie: Ergebnis, Ticker, Mannschaftswerte und
## Einzelbewertungen. Liegt dauerhaft im Baum (Gruppe "spielbericht").

var mid: String = ""
var inhalt: VBoxContainer

static func oeffnen(von: Node, spiel_id: String) -> void:
	var f = von.get_tree().get_first_node_in_group("spielbericht")
	if f != null:
		f.zeige(spiel_id)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("spielbericht")

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
	panel.custom_minimum_size = Vector2(940, 640)
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
	kopf.add_child(Stil.titel("Spielbericht", 1))
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

func zeige(spiel_id: String) -> void:
	mid = spiel_id
	visible = true
	_zeichne()

func _zeichne() -> void:
	Bildschirm.leeren(inhalt)
	var m: Dictionary = Welt.partie(mid)
	if m.is_empty():
		return
	var bericht: Dictionary = m.get("bericht", {})
	var kopf := Stil.hbox(18)
	inhalt.add_child(kopf)
	kopf.add_child(Wappen.fuer_verein(str(m["heim"]), 50.0))
	var mitte := Stil.vbox(2)
	mitte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(mitte)
	var ergebnis := Stil.titel("%s  %d : %d  %s" % [
		Welt.verein(str(m["heim"])).get("kurz", ""), int(m["tore_heim"]), int(m["tore_gast"]),
		Welt.verein(str(m["gast"])).get("kurz", "")], 0)
	ergebnis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(ergebnis)
	var unter := Stil.matt("%s · %s · Halbzeit %d:%d · %s Zuschauer" % [
		Welt.wettbewerb_name(str(m["wettbewerb"])), Kalender.text(int(m["tag"]), Welt.startjahr(), true),
		int((m["halbzeit"] as Array)[0]), int((m["halbzeit"] as Array)[1]),
		Stil.zahl(int(m.get("zuschauer", 0)))])
	unter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(unter)
	if str(m.get("entscheidung", "")) != "":
		var e := Stil.matt("Entscheidung: %s" % str(m["entscheidung"]).capitalize(), Stil.S_KLEIN)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mitte.add_child(e)
	kopf.add_child(Wappen.fuer_verein(str(m["gast"]), 50.0))

	if bericht.is_empty():
		inhalt.add_child(Stil.matt("Zu dieser Partie liegt kein ausführlicher Bericht vor."))
		return

	var spalten := Stil.hbox(12)
	inhalt.add_child(spalten)
	var werte := Bausteine.karte_in(spalten, "Mannschaftswerte")
	Stil.karte_wurzel(werte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hs: Dictionary = bericht["heim"]["stats"]
	var gs: Dictionary = bericht["gast"]["stats"]
	for zeile in [["Würfe", "wuerfe"], ["Tore", "tore"], ["Paraden", "paraden"], ["Blocks", "blocks"],
			["Technische Fehler", "technische_fehler"], ["Ballgewinne", "ballgewinne"],
			["Siebenmeter", "siebenmeter"], ["Zeitstrafen", "zeitstrafen"],
			["Tore nach Gegenstoß", "gegenstoss_tore"], ["Wechsel", "wechsel"]]:
		var h := Stil.hbox(8)
		var a := Stil.text(str(int(hs.get(str(zeile[1]), 0))), Stil.S_KLEIN)
		a.custom_minimum_size = Vector2(44, 0)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(a)
		var l := Stil.matt(str(zeile[0]), Stil.S_KLEIN)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(l)
		var b := Stil.text(str(int(gs.get(str(zeile[1]), 0))), Stil.S_KLEIN)
		b.custom_minimum_size = Vector2(44, 0)
		h.add_child(b)
		werte.add_child(h)
	werte.add_child(Stil.trenner())
	werte.add_child(Stil.info_zeile("Hallenpuls am Ende", "%d" % int(float(bericht.get("hallenpuls", 50.0))),
		Stil.prozent_farbe(float(bericht.get("hallenpuls", 50.0)))))
	var bester: String = str(bericht.get("spieler_des_spiels", ""))
	if bester != "" and Welt.daten["spieler"].has(bester):
		werte.add_child(Stil.info_zeile("Spieler des Spiels", Spielerfabrik.voller_name(Welt.spieler(bester)), Stil.AKZENT))

	var ticker := Bausteine.karte_in(spalten, "Spielverlauf")
	Stil.karte_wurzel(ticker).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in bericht.get("ticker", []):
		var h2 := Stil.hbox(8)
		ticker.add_child(h2)
		var zeit := Stil.matt(_zeit(float(e["zeit"])), Stil.S_MINI)
		zeit.custom_minimum_size = Vector2(44, 0)
		h2.add_child(zeit)
		var stand: Array = e.get("stand", [0, 0])
		var s := Stil.matt("%d:%d" % [int(stand[0]), int(stand[1])], Stil.S_MINI)
		s.custom_minimum_size = Vector2(42, 0)
		h2.add_child(s)
		var t := Stil.text(str(e["text"]), Stil.S_KLEIN, _farbe(str(e["typ"])))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(t)

	for seite in ["heim", "gast"]:
		var cid: String = str(bericht[seite]["cid"])
		var karte := Bausteine.karte_in(inhalt, "Einzelbewertungen — %s" % Welt.verein(cid).get("name", ""))
		var g := Stil.tabelle(["Spieler", "Min", "Tore", "Würfe", "Paraden", "Vorl.", "Fehler", "2min", "Note"])
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		karte.add_child(g)
		var spieler: Dictionary = bericht[seite]["spieler"]
		var ids: Array = spieler.keys()
		ids.sort_custom(func(a, b): return float(spieler[a]["sekunden"]) > float(spieler[b]["sekunden"]))
		for sid in ids:
			if not Welt.daten["spieler"].has(sid):
				continue
			var z: Dictionary = spieler[sid]
			var sp: Dictionary = Welt.spieler(sid)
			var k := Stil.knopf_flach(Spielerfabrik.kurz_name(sp))
			k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
			g.add_child(k)
			g.add_child(Stil.text("%d" % int(float(z["sekunden"]) / 60.0), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["tore"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["wuerfe"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["paraden"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["assists"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["fehler"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["zeitstrafen"])), Stil.S_KLEIN))
			var note: float = float(z["bewertung"])
			g.add_child(Stil.text(Stil.komma(note, 2), Stil.S_KLEIN, Stil.wert_farbe(6.0 - note, 5.0)))

func _zeit(sekunden: float) -> String:
	return "%02d:%02d" % [int(sekunden / 60.0), int(sekunden) % 60]

func _farbe(typ: String) -> Color:
	match typ:
		"tor":
			return Stil.GRUEN
		"zeitstrafe", "rot":
			return Stil.ROT
		"auszeit", "lauf":
			return Stil.AKZENT
		"halbzeit", "ende":
			return Stil.BLAU
	return Stil.TEXT
