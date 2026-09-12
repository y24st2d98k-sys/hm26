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
	k.custom_minimum_size = Vector2(0, 29)
	k.focus_mode = Control.FOCUS_NONE
	k.add_theme_stylebox_override("normal", Stil.box_leer())
	k.add_theme_stylebox_override("hover", Stil.box_leer())
	k.add_theme_stylebox_override("pressed", Stil.box_leer())
	k.add_theme_stylebox_override("focus", Stil.box_leer())
	var h := Stil.hbox(10)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 15
	h.offset_right = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.add_child(h)
	k.symbol = Symbol.neu(id, 17.0, Stil.TEXT_SCHWACH)
	h.add_child(k.symbol)
	k.beschriftung = Stil.text(name, Stil.S_KLEIN, Stil.TEXT_MATT)
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

func _draw() -> void:
	if aktiv:
		draw_rect(Rect2(Vector2(4, 0), Vector2(size.x - 8, size.y)), Stil.lasur(Stil.AKZENT, 0.13), true)
		draw_rect(Rect2(Vector2(0, 4), Vector2(3, size.y - 8)), Stil.AKZENT, true)
	elif is_hovered():
		draw_rect(Rect2(Vector2(4, 0), Vector2(size.x - 8, size.y)), Color(1, 1, 1, 0.045), true)
	if zaehler > 0:
		var schrift := ThemeDB.fallback_font
		var txt := str(mini(zaehler, 99))
		var breite: float = schrift.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Stil.S_ETIKETT).x
		var mitte := Vector2(size.x - 20.0, size.y * 0.5)
		draw_circle(mitte, 8.0, Stil.AKZENT)
		draw_string(schrift, mitte + Vector2(-breite * 0.5, Stil.S_ETIKETT * 0.36), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Stil.S_ETIKETT, Color("#171104"))
