class_name Vereinsfenster
extends Control
## Vereinsprofil: Kader, Saisonbilanz, Halle, Chronik und Rivalitäten.

var cid: String = ""
var inhalt: VBoxContainer

static func oeffnen(von: Node, verein_id: String) -> void:
	var f = von.get_tree().get_first_node_in_group("vereinsfenster")
	if f != null:
		f.zeige(verein_id)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("vereinsfenster")

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
	panel.custom_minimum_size = Vector2(860, 600)
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
	kopf.add_child(Stil.titel("Vereinsprofil", 1))
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

func zeige(verein_id: String) -> void:
	cid = verein_id
	visible = true
	_zeichne()

func _zeichne() -> void:
	Bildschirm.leeren(inhalt)
	var v: Dictionary = Welt.verein(cid)
	if v.is_empty():
		return
	var kopf := Stil.hbox(14)
	inhalt.add_child(kopf)
	kopf.add_child(Wappen.fuer_verein(cid, 58.0))
	var box := Stil.vbox(2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(box)
	box.add_child(Stil.titel(str(v["name"]), 0))
	box.add_child(Stil.matt("%s · gegründet %d · %s · %s Plätze" % [
		str(v["ort"]), int(v["gegruendet"]), str(v["halle"]["name"]), Stil.zahl(int(v["halle"]["kapazitaet"]))]))
	box.add_child(Bausteine.formkurve(v["formkurve"], 8))

	var oben := Stil.hbox(12)
	inhalt.add_child(oben)
	var lage := Bausteine.karte_in(oben, "Saison")
	Stil.karte_wurzel(lage).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s: Dictionary = v["saison"]
	lage.add_child(Stil.info_zeile("Liga", Welt.wettbewerb_name(str(v["liga"]))))
	var tabelle := Spielplan.tabelle_sortiert(Welt.daten, str(v["liga"]))
	lage.add_child(Stil.info_zeile("Tabellenplatz", str(tabelle.find(cid) + 1)))
	lage.add_child(Stil.info_zeile("Bilanz", "%d S / %d U / %d N" % [int(s["siege"]), int(s["unentschieden"]), int(s["niederlagen"])]))
	lage.add_child(Stil.info_zeile("Tore", "%d : %d" % [int(s["tore"]), int(s["gegentore"])]))
	lage.add_child(Stil.info_zeile("Ruf", "%d" % int(float(v["ruf"])), Stil.wert_farbe(float(v["ruf"]), 100.0)))
	if int(s["heimspiele"]) > 0:
		lage.add_child(Stil.info_zeile("Zuschauerschnitt", Stil.zahl(int(float(s["zuschauer_summe"]) / float(s["heimspiele"])))))

	var titel := Bausteine.karte_in(oben, "Titel & Chronik")
	Stil.karte_wurzel(titel).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var titel_liste: Array = v["chronik"]["titel"]
	if titel_liste.is_empty():
		titel.add_child(Stil.matt("Noch keine Titel in dieser Karriere."))
	else:
		for t in titel_liste.slice(0, 8):
			titel.add_child(Stil.info_zeile(str(t.get("saisontext", "")), str(t["titel"]), Stil.AKZENT))
	var ewig: Dictionary = v["chronik"]["ewige_bilanz"]
	titel.add_child(Stil.trenner())
	titel.add_child(Stil.info_zeile("Pflichtspiele gesamt", str(int(ewig["spiele"]))))
	titel.add_child(Stil.info_zeile("Ewige Bilanz", "%d / %d / %d" % [int(ewig["siege"]), int(ewig["unentschieden"]), int(ewig["niederlagen"])]))

	var rivalen := Chronik.rivalen(Welt.daten, cid, 4)
	if not rivalen.is_empty():
		var rk := Bausteine.karte_in(inhalt, "Rivalitäten")
		for r in rivalen:
			var zeile := Stil.hbox(8)
			rk.add_child(zeile)
			zeile.add_child(Wappen.fuer_verein(str(r["verein"]), 20.0))
			zeile.add_child(Stil.text(str(Welt.verein(str(r["verein"])).get("name", "")), Stil.S_KLEIN))
			zeile.add_child(Stil.dehner())
			zeile.add_child(Stil.balken(float(r["intensitaet"]), 100.0, 110, Stil.ROT))
			zeile.add_child(Stil.abzeichen(Chronik.rivalitaet_stufe(float(r["intensitaet"])), Stil.ROT))

	var kaderkarte := Bausteine.karte_in(inhalt, "Kader")
	var g := Stil.tabelle(["Pos", "Spieler", "Alter", "Stärke", "Vertrag", "Wert"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kaderkarte.add_child(g)
	for sid in Welt.kader(cid):
		var sp: Dictionary = Welt.spieler(sid)
		g.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		var k := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(k)
		g.add_child(Stil.text(str(int(sp["alter"])), Stil.S_KLEIN))
		g.add_child(Stil.text(Scouting.gesamt_text(Welt.daten, sid), Stil.S_KLEIN, Stil.wert_farbe(Spielerfabrik.gesamt(sp), 100.0)))
		var rest: int = int(sp["vertrag"].get("bis_saison", 0)) - Welt.saison_index()
		g.add_child(Stil.text("%d J." % maxi(rest, 0), Stil.S_KLEIN, Stil.ROT if rest <= 0 else Stil.TEXT_MATT))
		g.add_child(Stil.text(Stil.geld(float(sp["wert"])), Stil.S_KLEIN))
