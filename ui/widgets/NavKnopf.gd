class_name NavKnopf
extends Button
## Ein Eintrag der Hauptnavigation: Symbol, Beschriftung, aktiver Marker.
## Zeichnet Hintergrund und Aktivbalken selbst, damit der Zustand ohne
## Theme-Umweg eindeutig lesbar ist.

var aktiv: bool = false
var symbol: Symbol
var beschriftung: Label
var zaehler: int = 0

static func neu(id: String, name: String) -> NavKnopf:
	var k := NavKnopf.new()
	k.flat = true
	k.custom_minimum_size = Vector2(0, 36)
	k.focus_mode = Control.FOCUS_NONE
	k.add_theme_stylebox_override("normal", Stil.box_leer())
	k.add_theme_stylebox_override("hover", Stil.box_leer())
	k.add_theme_stylebox_override("pressed", Stil.box_leer())
	k.add_theme_stylebox_override("focus", Stil.box_leer())
	var h := Stil.hbox(10)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 20
	h.offset_right = -12
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.add_child(h)
	k.symbol = Symbol.neu(id, 18.0, Stil.TEXT_SCHWACH)
	h.add_child(k.symbol)
	k.beschriftung = Stil.text(name, Stil.S_NORMAL - 1, Stil.TEXT_MATT)
	k.beschriftung.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(k.beschriftung)
	h.add_child(Stil.dehner())
	k.mouse_entered.connect(k.queue_redraw)
	k.mouse_exited.connect(k.queue_redraw)
	return k

func setze_aktiv(an: bool) -> void:
	aktiv = an
	symbol.setze_farbe(Stil.AKZENT if an else Stil.TEXT_SCHWACH)
	beschriftung.add_theme_color_override("font_color", Stil.TEXT if an else Stil.TEXT_MATT)
	queue_redraw()

## Kleine Zahl am rechten Rand (offene Nachrichten, Angebote).
func setze_zaehler(wert: int) -> void:
	zaehler = wert
	queue_redraw()

## Der aktive Eintrag ist eine gerundete Pille, kein Balken am Rand.
##
## Vorher lag hinter dem aktiven Eintrag ein scharfkantiges Rechteck mit einem
## Strich davor — zwei Zeichen fuer dieselbe Aussage, beide eckig in einer
## Oberflaeche, die sonst nur runde Ecken kennt. Die Pille sagt dasselbe
## einmal, und sie passt zum Rest.
func _draw() -> void:
	var feld := Rect2(Vector2(8, 2), Vector2(size.x - 16, size.y - 4))
	if aktiv:
		draw_style_box(Stil.box(Stil.lasur(Stil.AKZENT, 0.20), Stil.R_KLEIN), feld)
		draw_style_box(Stil.box(Stil.AKZENT, Stil.R_RUND),
			Rect2(Vector2(0, size.y * 0.5 - 9.0), Vector2(3, 18)))
	elif is_hovered():
		draw_style_box(Stil.box(Color(1, 1, 1, 0.05), Stil.R_KLEIN), feld)
	if zaehler > 0:
		var schrift := Stil.schnitt_halbfett()
		var txt := str(mini(zaehler, 99))
		var breite: float = schrift.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Stil.S_ETIKETT).x
		var mitte := Vector2(size.x - 24.0, size.y * 0.5)
		draw_circle(mitte, 9.0, Stil.SIGNAL)
		draw_string(schrift, mitte + Vector2(-breite * 0.5, Stil.S_ETIKETT * 0.36), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Stil.S_ETIKETT, Color.WHITE)
