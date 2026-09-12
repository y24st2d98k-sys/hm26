class_name Anliegenfenster
extends Control
## Ein Spieler steht vor der Tür und will etwas.
##
## Bewusst schlicht gehalten: sein Gesicht, was er sagt, drei mögliche
## Antworten. Die Frist steht dabei, damit man weiß, wie lange man es noch
## aussitzen kann — und was es kostet, wenn man es tut.

var inhalt: VBoxContainer
var sid: String = ""

static func oeffnen(von: Node, spieler_id: String) -> void:
	var f = von.get_tree().get_first_node_in_group("anliegenfenster")
	if f != null:
		f.zeige(spieler_id)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("anliegenfenster")

func _ready() -> void:
	theme = Stil.theme()
	var schleier := ColorRect.new()
	schleier.color = Color(0, 0, 0, 0.68)
	schleier.set_anchors_preset(Control.PRESET_FULL_RECT)
	schleier.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			visible = false)
	add_child(schleier)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mitte)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	panel.add_theme_stylebox_override("panel", Stil.box_erhaben(Stil.FLAECHE, Stil.R_GROSS, Stil.RAND_HELL))
	mitte.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(m)
	inhalt = Stil.vbox(12)
	m.add_child(inhalt)

func zeige(spieler_id: String) -> void:
	sid = spieler_id
	visible = true
	_zeichne()

func _zeichne() -> void:
	Bildschirm.leeren(inhalt)
	var eintrag := Anliegen.fuer_spieler(Welt.daten, sid)
	if eintrag.is_empty() or not Welt.daten["spieler"].has(sid):
		inhalt.add_child(Stil.matt("Dieses Anliegen hat sich erledigt."))
		var zu0 := Stil.knopf("Schließen")
		zu0.pressed.connect(func(): visible = false)
		inhalt.add_child(zu0)
		return
	var sp: Dictionary = Welt.spieler(sid)
	var art: String = str(eintrag["art"])
	var info: Dictionary = Anliegen.ARTEN[art]

	var kopf := Stil.hbox(14)
	inhalt.add_child(kopf)
	kopf.add_child(Portraet.fuer_spieler(sid, 68.0))
	var spalte := Stil.vbox(2)
	spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kopf.add_child(spalte)
	spalte.add_child(Stil.titel(Spielerfabrik.voller_name(sp), 1))
	var zeile := Stil.hbox(7)
	spalte.add_child(zeile)
	zeile.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
	zeile.add_child(Flagge.fuer(str(sp["nation"]), 18.0))
	zeile.add_child(Stil.matt(str(info["titel"])))
	var rest: int = int(eintrag["frist"]) - Welt.tag()
	kopf.add_child(Stil.abzeichen("NOCH %d TAG(E)" % maxi(rest, 0),
		Stil.ROT if rest <= 3 else Stil.GELB))
	var zu := Stil.knopf("Später")
	zu.tooltip_text = "Das Anliegen bleibt offen. Läuft die Frist ab, zieht er seine eigenen Schlüsse."
	zu.pressed.connect(func(): visible = false)
	kopf.add_child(zu)

	# Was er sagt
	var blase := PanelContainer.new()
	var sb := Stil.box_kante(Stil.lasur(Stil.AKZENT, 0.10), "links", Stil.AKZENT, 3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 11
	blase.add_theme_stylebox_override("panel", sb)
	inhalt.add_child(blase)
	var t := Stil.text("„%s“" % str(info["frage"]), Stil.S_NORMAL, Stil.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blase.add_child(t)

	var lage := Stil.hbox(16)
	inhalt.add_child(lage)
	lage.add_child(Bausteine.wertzeile("Moral", float(sp["moral"])))
	lage.add_child(Bausteine.wertzeile("Unzufrieden", float(sp["unzufriedenheit"])))
	lage.add_child(Stil.info_zeile("Verhältnis",
		Gespraech.beziehung_text(Gespraech.beziehung(sp))))

	inhalt.add_child(Stil.etikett("Ihre Antwort"))
	for a in Anliegen.ANTWORTEN.get(art, []):
		var antwort: Dictionary = a
		var k := Stil.knopf(str(antwort["text"]))
		k.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if antwort.has("versprechen"):
			k.tooltip_text = "Das ist ein Versprechen. Es wird in einigen Wochen an den Tatsachen gemessen."
		if str(antwort.get("aktion", "")) == "verhandlung":
			k.tooltip_text = "Öffnet den Verhandlungstisch."
		k.pressed.connect(func():
			var erg := Anliegen.antworten(Welt.daten, sid, str(antwort["id"]))
			Klang.spiele("klick", 0.5)
			_ergebnis(erg, sp)
			Welt.zustand_geaendert.emit())
		inhalt.add_child(k)

func _ergebnis(erg: Dictionary, sp: Dictionary) -> void:
	Bildschirm.leeren(inhalt)
	var kopf := Stil.hbox(14)
	inhalt.add_child(kopf)
	kopf.add_child(Portraet.fuer_spieler(sid, 60.0))
	var spalte := Stil.vbox(3)
	spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kopf.add_child(spalte)
	spalte.add_child(Stil.titel(Spielerfabrik.voller_name(sp), 1))
	spalte.add_child(Stil.text(str(erg.get("text", "")), Stil.S_NORMAL,
		Stil.GRUEN if bool(erg.get("gelungen", false)) else Stil.ROT))
	var knoepfe := Stil.hbox(8)
	inhalt.add_child(knoepfe)
	if str(erg.get("aktion", "")) == "verhandlung":
		var verhandeln := Stil.knopf_primaer("An den Verhandlungstisch")
		verhandeln.pressed.connect(func():
			visible = false
			Verhandlungsfenster.oeffnen(self, sid, "verlaengerung"))
		knoepfe.add_child(verhandeln)
	var weiter := Stil.knopf("Schließen")
	weiter.pressed.connect(func(): visible = false)
	knoepfe.add_child(weiter)
