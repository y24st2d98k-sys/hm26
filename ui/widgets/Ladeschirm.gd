class_name Ladeschirm
extends Control
## Ein Vorhang für alles, was länger als einen Wimpernschlag dauert.
##
## Beim Vorspulen über mehrere Wochen rechnet das Spiel Hunderte von Partien
## durch. Am Stück gerechnet steht das Bild dabei still, und ein stehendes Bild
## nach einem Knopfdruck sieht aus wie ein Absturz — man weiß nicht, ob noch
## etwas passiert oder ob man noch einmal drücken soll.
##
## Der Ladeschirm legt sich darüber, sagt bis wohin es geht, wie weit es ist
## und was gerade gerechnet wird. Das ändert nichts an der Rechenzeit, aber
## alles daran, ob sie als Warten oder als Fehler ankommt.

var _titel: Label
var _untertitel: Label
var _balken: ProgressBar
var _stand: Label

static func oeffnen(von: Node, titel: String, untertitel: String = "") -> Ladeschirm:
	var l := Ladeschirm.new()
	var wurzel: Node = von.get_tree().current_scene
	if wurzel == null:
		wurzel = von
	wurzel.add_child(l)
	l.setze(titel, untertitel)
	return l

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Alles darunter bleibt unberührbar, solange gerechnet wird.
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200

func _ready() -> void:
	var dunkel := ColorRect.new()
	dunkel.color = Color(Stil.GRUND.r, Stil.GRUND.g, Stil.GRUND.b, 0.93)
	dunkel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dunkel)

	var mitte := Stil.vbox(14)
	mitte.set_anchors_preset(Control.PRESET_CENTER)
	mitte.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mitte.grow_vertical = Control.GROW_DIRECTION_BOTH
	mitte.custom_minimum_size = Vector2(420, 0)
	add_child(mitte)

	_titel = Stil.titel("", 1)
	_titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(_titel)

	_untertitel = Stil.matt("", Stil.S_KLEIN)
	_untertitel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(_untertitel)

	_balken = ProgressBar.new()
	_balken.custom_minimum_size = Vector2(420, 10)
	_balken.min_value = 0.0
	_balken.max_value = 1.0
	_balken.value = 0.0
	_balken.show_percentage = false
	mitte.add_child(_balken)

	_stand = Stil.text("", Stil.S_KLEIN, Stil.AKZENT)
	_stand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(_stand)

func setze(titel: String, untertitel: String = "") -> void:
	if _titel != null:
		_titel.text = titel
	if _untertitel != null:
		_untertitel.text = untertitel
		_untertitel.visible = untertitel != ""

## Fortschritt melden. `anteil` von 0 bis 1.
func fortschritt(anteil: float, text: String = "") -> void:
	if _balken != null:
		_balken.value = clampf(anteil, 0.0, 1.0)
	if _stand != null:
		_stand.text = text

## Ein Bild zeichnen lassen, damit der Fortschritt auch ankommt. Ohne dieses
## Warten sammelt sich alles bis zum Ende an und der Balken springt von null
## auf voll.
func atmen() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func schliessen() -> void:
	queue_free()
