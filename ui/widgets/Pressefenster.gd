class_name Pressefenster
extends Control
## Die Pressekonferenz: eine Frage nach der anderen, jede Antwort mit Folgen.

var inhalt: VBoxContainer
var kopfzeile: Label

static func oeffnen(von: Node) -> void:
	var f = von.get_tree().get_first_node_in_group("pressefenster")
	if f != null:
		f.zeige()

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("pressefenster")

func _ready() -> void:
	theme = Stil.theme()
	var schleier := ColorRect.new()
	schleier.color = Color(0, 0, 0, 0.7)
	schleier.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schleier)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mitte)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 480)
	panel.add_theme_stylebox_override("panel", Stil.box(Stil.FLAECHE, Stil.R_GROSS, Stil.AKZENT_TIEF))
	mitte.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(m)
	var v := Stil.vbox(12)
	m.add_child(v)
	kopfzeile = Stil.titel("Pressekonferenz", 1, Stil.AKZENT)
	v.add_child(kopfzeile)
	v.add_child(Stil.trenner())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)

func zeige() -> void:
	visible = true
	_zeichne()

func _zeichne() -> void:
	Bildschirm.leeren(inhalt)
	var k: Dictionary = Presse.aktuelle(Welt.daten)
	if k.is_empty():
		visible = false
		return
	kopfzeile.text = "Pressekonferenz — %s" % str(k.get("outlet", ""))
	var fragen: Array = k.get("fragen", [])
	var i: int = int(k.get("index", 0))

	# Bereits Gesagtes bleibt sichtbar
	for e in k.get("protokoll", []):
		var block := Stil.vbox(2)
		inhalt.add_child(block)
		block.add_child(Stil.matt(str(e["frage"]), Stil.S_KLEIN))
		block.add_child(Stil.text("„%s\"" % str(e["antwort"]), Stil.S_KLEIN, Stil.TEXT))
		inhalt.add_child(Stil.trenner())

	if not bool(k.get("offen", false)) or i >= fragen.size():
		inhalt.add_child(Stil.text("Die Konferenz ist beendet.", Stil.S_NORMAL, Stil.GRUEN))
		var zu := Stil.knopf_primaer("Schließen")
		zu.pressed.connect(func():
			visible = false
			Welt.zustand_geaendert.emit())
		inhalt.add_child(zu)
		return

	var frage: Dictionary = fragen[i]
	var f := Stil.titel(str(frage["frage"]), 1)
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inhalt.add_child(f)
	inhalt.add_child(Stil.matt("Frage %d von %d" % [i + 1, fragen.size()], Stil.S_MINI))
	for idx in range((frage["antworten"] as Array).size()):
		var a: Dictionary = frage["antworten"][idx]
		var k2 := Stil.knopf("„%s\"" % str(a["text"]))
		k2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		k2.custom_minimum_size = Vector2(0, 38)
		k2.tooltip_text = _wirkungstext(a)
		var wahl := idx
		k2.pressed.connect(func():
			Presse.antworten(Welt.daten, wahl)
			_zeichne())
		inhalt.add_child(k2)
	var absagen := Stil.knopf_flach("Konferenz abbrechen", Stil.TEXT_SCHWACH)
	absagen.pressed.connect(func():
		Presse.absagen(Welt.daten)
		visible = false
		Welt.zustand_geaendert.emit())
	inhalt.add_child(absagen)

func _wirkungstext(a: Dictionary) -> String:
	var teile: Array = []
	if absf(float(a.get("fans", 0.0))) > 0.1:
		teile.append("Fans %+.0f" % float(a["fans"]))
	if absf(float(a.get("vorstand", 0.0))) > 0.1:
		teile.append("Vorstand %+.0f" % float(a["vorstand"]))
	if absf(float(a.get("moral", 0.0))) > 0.1:
		teile.append("Mannschaftsmoral %+.0f" % float(a["moral"]))
	if absf(float(a.get("gegner_motivation", 0.0))) > 0.001:
		teile.append("Gegner %+.0f %% motiviert" % (float(a["gegner_motivation"]) * 100.0))
	return "Erwartete Wirkung: " + (", ".join(teile) if not teile.is_empty() else "gering")
