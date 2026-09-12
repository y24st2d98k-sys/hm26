class_name Verhandlungsfenster
extends Control
## Die Vertragsverhandlung als Szene: oben der Raum mit dem Gegenüber, darunter
## sein letzter Satz, links das Angebot, rechts der Gesprächsverlauf.
##
## Geduld und Laune stehen sichtbar daneben — man sieht also, wie weit man gehen
## kann, bevor der andere aufsteht.

var raum: Verhandlungsraum
var spruch: Label
var angebotsbereich: VBoxContainer
var verlaufsbereich: VBoxContainer
var leisten: VBoxContainer
var meldung: Label
var abschluss: Button

var feld_gehalt: SpinBox
var feld_jahre: SpinBox
var feld_rolle: OptionButton
var feld_tor: SpinBox
var feld_sieg: SpinBox
var feld_klausel: SpinBox

static func oeffnen(von: Node, sid: String, art: String) -> void:
	var f = von.get_tree().get_first_node_in_group("verhandlungsfenster")
	if f == null:
		return
	var erg := Verhandlung.starten(Welt.daten, sid, art)
	if not bool(erg["ok"]):
		return
	f.zeige()

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("verhandlungsfenster")

func _ready() -> void:
	theme = Stil.theme()
	var schleier := ColorRect.new()
	schleier.color = Color(0, 0, 0, 0.72)
	schleier.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schleier)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mitte)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1060, 700)
	panel.add_theme_stylebox_override("panel", Stil.box_erhaben(Stil.FLAECHE, Stil.R_GROSS, Stil.RAND_HELL))
	mitte.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(m)
	var v := Stil.vbox(10)
	m.add_child(v)

	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Vertragsverhandlung", 1))
	kopf.add_child(Stil.dehner())
	var zu := Stil.knopf("Abbrechen")
	zu.pressed.connect(func():
		Verhandlung.abbrechen(Welt.daten)
		visible = false)
	kopf.add_child(zu)

	# Szene und Zustandsanzeige nebeneinander
	var oben := Stil.hbox(12)
	v.add_child(oben)
	raum = Verhandlungsraum.neu(Vector2(640.0, 240.0))
	oben.add_child(raum)
	leisten = Stil.vbox(8)
	leisten.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(leisten)

	spruch = Stil.text("", Stil.S_NORMAL, Stil.AKZENT)
	spruch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(spruch)

	var unten := Stil.hbox(12)
	unten.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(unten)
	angebotsbereich = Stil.vbox(8)
	angebotsbereich.custom_minimum_size = Vector2(470, 0)
	unten.add_child(angebotsbereich)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	unten.add_child(scroll)
	verlaufsbereich = Stil.vbox(8)
	verlaufsbereich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(verlaufsbereich)

	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	v.add_child(meldung)

func zeige() -> void:
	visible = true
	meldung.text = ""
	var v: Dictionary = Verhandlung.aktuelle(Welt.daten)
	if not v.is_empty():
		raum.setze_spieler(str(v["spieler"]))
		raum.setze_stimmung(float(v.get("laune", 50.0)) / 100.0)
	_zeichne()

# -------------------------------------------------------------- Zeichnen ---

func _zeichne() -> void:
	Bildschirm.leeren(angebotsbereich)
	Bildschirm.leeren(verlaufsbereich)
	Bildschirm.leeren(leisten)
	var v: Dictionary = Verhandlung.aktuelle(Welt.daten)
	if v.is_empty():
		spruch.text = "Es läuft keine Verhandlung."
		return
	var sid: String = str(v["spieler"])
	var sp: Dictionary = Welt.spieler(sid)
	var f: Dictionary = v["forderung"]
	var status: String = str(v["status"])

	raum.setze_stimmung(float(v["laune"]) / 100.0)
	var verlauf: Array = v["verlauf"]
	spruch.text = str((verlauf[verlauf.size() - 1] as Dictionary)["text"]) if not verlauf.is_empty() else ""

	# Zustand rechts neben der Szene
	var kopf := Stil.hbox(10)
	leisten.add_child(kopf)
	kopf.add_child(Stil.titel(Spielerfabrik.voller_name(sp), 1))
	kopf.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
	leisten.add_child(Stil.matt("%d Jahre · %s · Stärke %d" % [int(sp["alter"]),
		Namen.KULTUR_NAME.get(str(sp["nation"]), ""), int(Spielerfabrik.gesamt(sp))]))
	leisten.add_child(Bausteine.wertzeile("Geduld", float(v["geduld"]), 100.0,
		"Sinkt mit jeder Runde und stürzt bei schlechten Angeboten ab."))
	leisten.add_child(Bausteine.wertzeile("Laune", float(v["laune"]), 100.0,
		"Gut gelaunt lässt er eher mit sich reden."))
	leisten.add_child(Stil.info_zeile("Runde", "%d von %d" % [int(v["runde"]), Verhandlung.RUNDEN_MAX]))
	leisten.add_child(Stil.info_zeile("Verhältnis zu Ihnen",
		Gespraech.beziehung_text(Gespraech.beziehung(sp)), Stil.prozent_farbe(Gespraech.beziehung(sp))))
	leisten.add_child(Stil.trenner())
	leisten.add_child(Stil.etikett("Aktuelle Forderung"))
	leisten.add_child(Stil.info_zeile("Gehalt", Stil.geld(float(f["gehalt"])), Stil.AKZENT))
	leisten.add_child(Stil.info_zeile("Laufzeit", "%d Jahre" % int(f["jahre"])))
	leisten.add_child(Stil.info_zeile("Rolle",
		str(Transfermarkt.ROLLEN_NAME.get(str(f["rolle"]), "—"))))

	# Verlauf als Sprechblasen
	for e in verlauf:
		var eintrag: Dictionary = e
		var ist_spieler: bool = str(eintrag["wer"]) == "spieler"
		var karte := PanelContainer.new()
		var sb := Stil.box_kante(Stil.lasur(Stil.AKZENT if ist_spieler else Stil.BLAU, 0.10),
			"links" if ist_spieler else "rechts", Stil.AKZENT if ist_spieler else Stil.BLAU, 3)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 7
		sb.content_margin_bottom = 8
		karte.add_theme_stylebox_override("panel", sb)
		var box := Stil.vbox(2)
		karte.add_child(box)
		box.add_child(Stil.etikett(Spielerfabrik.kurz_name(sp) if ist_spieler else "Sie"))
		var t := Stil.text(str(eintrag["text"]), Stil.S_KLEIN,
			Stil.TEXT if ist_spieler else Stil.TEXT_MATT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(t)
		verlaufsbereich.add_child(karte)

	if status == "angenommen":
		_abschlussbereich(sp)
		return
	if status == "geplatzt":
		angebotsbereich.add_child(Stil.banner("Die Verhandlung ist geplatzt. In den nächsten Wochen wird er nicht noch einmal an den Tisch kommen.", "fehler"))
		var zu := Stil.knopf_primaer("Schließen")
		zu.pressed.connect(func():
			Verhandlung.abbrechen(Welt.daten)
			visible = false)
		angebotsbereich.add_child(zu)
		return
	_angebotsformular(sp, f)

func _angebotsformular(sp: Dictionary, f: Dictionary) -> void:
	var karte := Bausteine.karte_in(angebotsbereich, "Ihr Angebot")
	feld_gehalt = _zahl(karte, "Wochengehalt", 100, 250000, 50, float(f["gehalt"]))
	feld_jahre = _zahl(karte, "Laufzeit (Jahre)", 1, 6, 1, float(f["jahre"]))
	var zeile := Stil.hbox(8)
	karte.add_child(zeile)
	var l := Stil.matt("Rolle")
	l.custom_minimum_size = Vector2(150, 0)
	zeile.add_child(l)
	feld_rolle = OptionButton.new()
	feld_rolle.custom_minimum_size = Vector2(180, 0)
	for i in range(Transfermarkt.ROLLEN.size()):
		feld_rolle.add_item(str(Transfermarkt.ROLLEN_NAME[Transfermarkt.ROLLEN[i]]))
		feld_rolle.set_item_metadata(i, Transfermarkt.ROLLEN[i])
		if str(f["rolle"]) == str(Transfermarkt.ROLLEN[i]):
			feld_rolle.select(i)
	zeile.add_child(feld_rolle)

	karte.add_child(Stil.trenner())
	karte.add_child(Stil.etikett("Zugeständnisse statt Gehalt"))
	feld_tor = _zahl(karte, "Prämie je Tor", 0, int(Praemien.TOR_MAX), 50,
		float(sp["vertrag"].get("praemie_tor", 0.0)))
	feld_sieg = _zahl(karte, "Prämie je Sieg", 0, int(Praemien.SIEG_MAX), 100,
		float(sp["vertrag"].get("praemie_sieg", 0.0)))
	feld_klausel = _zahl(karte, "Ablöseklausel", 0, 90000000, 25000,
		float(sp["vertrag"].get("ablöseklausel", 0.0)))
	karte.add_child(Stil.matt("Prämien und eine Klausel rechnet er sich aufs Gehalt an — damit lässt sich ein niedrigeres Grundgehalt ausgleichen.", Stil.S_MINI))

	var knoepfe := Stil.hbox(8)
	angebotsbereich.add_child(knoepfe)
	var senden := Stil.knopf_primaer("Angebot machen")
	senden.pressed.connect(_senden)
	knoepfe.add_child(senden)
	var uebernehmen := Stil.knopf("Forderung übernehmen")
	uebernehmen.tooltip_text = "Setzt genau das ein, was er verlangt."
	uebernehmen.pressed.connect(func():
		feld_gehalt.value = float(f["gehalt"])
		feld_jahre.value = float(f["jahre"])
		for i in range(feld_rolle.item_count):
			if str(feld_rolle.get_item_metadata(i)) == str(f["rolle"]):
				feld_rolle.select(i))
	knoepfe.add_child(uebernehmen)

func _zahl(eltern: Node, beschriftung: String, von: int, bis: int, schritt: int, wert: float) -> SpinBox:
	var zeile := Stil.hbox(8)
	eltern.add_child(zeile)
	var l := Stil.matt(beschriftung)
	l.custom_minimum_size = Vector2(150, 0)
	zeile.add_child(l)
	var f := SpinBox.new()
	f.min_value = von
	f.max_value = bis
	f.step = schritt
	f.value = wert
	f.custom_minimum_size = Vector2(180, 0)
	zeile.add_child(f)
	return f

func _senden() -> void:
	var angebot := {
		"gehalt": feld_gehalt.value,
		"jahre": int(feld_jahre.value),
		"rolle": str(feld_rolle.get_item_metadata(feld_rolle.selected)),
		"praemie_tor": feld_tor.value,
		"praemie_sieg": feld_sieg.value,
		"klausel": feld_klausel.value,
	}
	var erg := Verhandlung.anbieten(Welt.daten, angebot)
	Klang.spiele("klick", 0.6)
	match str(erg["status"]):
		"angenommen":
			_melde("Er ist einverstanden.", true)
		"geplatzt":
			_melde("Die Verhandlung ist geplatzt.", false)
		_:
			_melde("", true)
	_zeichne()

func _abschlussbereich(sp: Dictionary) -> void:
	var karte := Bausteine.karte_in(angebotsbereich, "Einigung")
	var v: Dictionary = Verhandlung.aktuelle(Welt.daten)
	var a: Dictionary = v["angebot"]
	karte.add_child(Stil.info_zeile("Wochengehalt", Stil.geld(float(a["gehalt"])), Stil.AKZENT))
	karte.add_child(Stil.info_zeile("Laufzeit", "%d Jahre" % int(a["jahre"])))
	karte.add_child(Stil.info_zeile("Rolle", str(Transfermarkt.ROLLEN_NAME.get(str(a["rolle"]), "—"))))
	if float(a.get("praemie_tor", 0.0)) > 0.0 or float(a.get("praemie_sieg", 0.0)) > 0.0:
		karte.add_child(Stil.info_zeile("Prämien", "%s je Tor · %s je Sieg" % [
			Stil.geld(float(a.get("praemie_tor", 0.0))), Stil.geld(float(a.get("praemie_sieg", 0.0)))]))
	if float(a.get("klausel", 0.0)) > 0.0:
		karte.add_child(Stil.info_zeile("Ablöseklausel", Stil.geld(float(a["klausel"])), Stil.ROT))
	abschluss = Stil.knopf_primaer("Unterschreiben lassen")
	abschluss.pressed.connect(func():
		var erg := Verhandlung.abschliessen(Welt.daten)
		_melde(str(erg["grund"]), bool(erg["ok"]))
		Klang.spiele("tor", 0.4)
		Welt.zustand_geaendert.emit()
		if bool(erg["ok"]):
			visible = false)
	karte.add_child(abschluss)

func _melde(text: String, gut: bool) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)
