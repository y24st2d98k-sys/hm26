extends Node
## Stil — das zentrale Design-System von Hallenherz.
##
## Jede Farbe, jede Schriftgroesse und jedes wiederverwendbare Control stammt aus
## dieser Datei. Bildschirme bauen ihre Oberflaeche ausschliesslich aus den hier
## angebotenen Bausteinen, damit das Spiel ueberall gleich aussieht.
## Es werden keinerlei externe Assets geladen — Schrift ist die Engine-Fallback-Schrift,
## alle Flaechen sind StyleBoxFlat, alle Symbole werden gezeichnet.

# ---------------------------------------------------------------- Farbwelt ---
# "Hallenlicht": tiefes Blaugrau als Grund, warmes Scheinwerfer-Orange als Akzent.
var GRUND := Color("#0d1015")          # Fensterhintergrund
var FLAECHE := Color("#151a22")        # Karten
var FLAECHE_HOCH := Color("#1c232e")   # hervorgehobene Karten / Zeilen
var FLAECHE_TIEF := Color("#0a0d12")   # eingelassene Bereiche
var RAND := Color("#2a3341")
var RAND_HELL := Color("#3a4658")

var TEXT := Color("#e8eef5")
var TEXT_MATT := Color("#93a1b1")
var TEXT_SCHWACH := Color("#64748b")

var AKZENT := Color("#f0a23c")         # Primaerakzent (Hallenlicht)
var AKZENT_TIEF := Color("#b9762a")
var BLAU := Color("#48a9f8")
var GRUEN := Color("#46c05e")
var GELB := Color("#e8c34a")
var ROT := Color("#f06055")
var LILA := Color("#a97cf5")
var TUERKIS := Color("#3fd0c9")

# ------------------------------------------------------------ Typografie ---
const S_MINI := 11
const S_KLEIN := 13
const S_NORMAL := 15
const S_GROSS := 19
const S_TITEL := 25
const S_RIESIG := 38

const R_KLEIN := 4
const R_NORMAL := 8
const R_GROSS := 14

var _theme: Theme = null

# Farbverlauf fuer Attributwerte (1..20) — von rot ueber gelb zu gruen/lila.
func wert_farbe(wert: float, maximum: float = 20.0) -> Color:
	var t: float = clampf(wert / maximum, 0.0, 1.0)
	if t < 0.35:
		return ROT.lerp(Color("#e07f3c"), t / 0.35)
	elif t < 0.55:
		return Color("#e07f3c").lerp(GELB, (t - 0.35) / 0.2)
	elif t < 0.78:
		return GELB.lerp(GRUEN, (t - 0.55) / 0.23)
	else:
		return GRUEN.lerp(TUERKIS, (t - 0.78) / 0.22)

## Farbe fuer Prozentwerte 0..100 (Form, Moral, Fitness).
func prozent_farbe(wert: float) -> Color:
	return wert_farbe(wert, 100.0)

# ------------------------------------------------------------- StyleBoxen ---
func box(fuellung: Color, radius: int = R_NORMAL, randfarbe: Variant = null, randbreite: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fuellung
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if randfarbe != null:
		sb.border_color = randfarbe
		sb.set_border_width_all(randbreite)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func box_leer() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

# ------------------------------------------------------------------ Theme ---
func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = S_NORMAL

	# Panel
	var panel := box(FLAECHE, R_NORMAL, RAND)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", box(FLAECHE, R_NORMAL, RAND))

	# Label
	t.set_color("font_color", "Label", TEXT)

	# Button
	var b_normal := box(FLAECHE_HOCH, R_KLEIN, RAND_HELL)
	b_normal.content_margin_left = 14
	b_normal.content_margin_right = 14
	b_normal.content_margin_top = 7
	b_normal.content_margin_bottom = 7
	var b_hover := b_normal.duplicate() as StyleBoxFlat
	b_hover.bg_color = Color("#28313e")
	b_hover.border_color = AKZENT_TIEF
	var b_press := b_normal.duplicate() as StyleBoxFlat
	b_press.bg_color = Color("#323d4d")
	var b_dis := b_normal.duplicate() as StyleBoxFlat
	b_dis.bg_color = Color("#171c24")
	b_dis.border_color = Color("#232a34")
	t.set_stylebox("normal", "Button", b_normal)
	t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_press)
	t.set_stylebox("disabled", "Button", b_dis)
	t.set_stylebox("focus", "Button", box_leer())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", AKZENT)
	t.set_color("font_disabled_color", "Button", TEXT_SCHWACH)

	# LineEdit / SpinBox
	var le := box(FLAECHE_TIEF, R_KLEIN, RAND_HELL)
	le.content_margin_left = 8
	le.content_margin_right = 8
	t.set_stylebox("normal", "LineEdit", le)
	var le_f := le.duplicate() as StyleBoxFlat
	le_f.border_color = AKZENT
	t.set_stylebox("focus", "LineEdit", le_f)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", AKZENT)

	# OptionButton erbt Button
	t.set_stylebox("normal", "OptionButton", b_normal)
	t.set_stylebox("hover", "OptionButton", b_hover)
	t.set_stylebox("pressed", "OptionButton", b_press)
	t.set_stylebox("focus", "OptionButton", box_leer())
	t.set_color("font_color", "OptionButton", TEXT)

	# PopupMenu
	t.set_stylebox("panel", "PopupMenu", box(FLAECHE_HOCH, R_KLEIN, RAND_HELL))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", AKZENT)

	# ScrollBar
	var sbar := box(Color("#1b222c"), 5)
	var grab := box(Color("#3b4756"), 5)
	var grab_h := box(Color("#4e5c6e"), 5)
	t.set_stylebox("scroll", "VScrollBar", sbar)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_h)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_h)
	t.set_stylebox("scroll", "HScrollBar", sbar)
	t.set_stylebox("grabber", "HScrollBar", grab)
	t.set_stylebox("grabber_highlight", "HScrollBar", grab_h)
	t.set_stylebox("grabber_pressed", "HScrollBar", grab_h)

	# ProgressBar
	t.set_stylebox("background", "ProgressBar", box(FLAECHE_TIEF, R_KLEIN, RAND))
	t.set_stylebox("fill", "ProgressBar", box(AKZENT, R_KLEIN))

	# Slider
	t.set_stylebox("slider", "HSlider", box(FLAECHE_TIEF, 4, RAND))
	t.set_stylebox("grabber_area", "HSlider", box(AKZENT_TIEF, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(AKZENT, 4))

	# CheckBox
	t.set_color("font_color", "CheckBox", TEXT)

	# Separator
	var sep := StyleBoxLine.new()
	sep.color = RAND
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	var sepv := StyleBoxLine.new()
	sepv.color = RAND
	sepv.thickness = 1
	sepv.vertical = true
	t.set_stylebox("separator", "VSeparator", sepv)

	# Tooltip
	t.set_stylebox("panel", "TooltipPanel", box(Color("#0c1016"), R_KLEIN, AKZENT_TIEF))
	t.set_color("font_color", "TooltipLabel", TEXT)

	_theme = t
	return _theme

# --------------------------------------------------------------- Bausteine ---

## Ueberschrift in drei Stufen (0 = gross, 1 = Abschnitt, 2 = Kleinkram).
func titel(text: String, stufe: int = 0, farbe: Variant = null) -> Label:
	var l := Label.new()
	l.text = text
	match stufe:
		0:
			l.add_theme_font_size_override("font_size", S_TITEL)
		1:
			l.add_theme_font_size_override("font_size", S_GROSS)
		_:
			l.add_theme_font_size_override("font_size", S_KLEIN)
	l.add_theme_color_override("font_color", farbe if farbe != null else TEXT)
	return l

## Beschriftung fuer Tabellenkoepfe und Nebeninformationen.
func matt(text: String, groesse: int = S_KLEIN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", TEXT_MATT)
	return l

func text(inhalt: String, groesse: int = S_NORMAL, farbe: Variant = null) -> Label:
	var l := Label.new()
	l.text = inhalt
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe if farbe != null else TEXT)
	return l

## Karte: Panel mit Innenabstand und optionaler Kopfzeile.
## Rueckgabe ist der Inhalts-VBox — die Karte selbst haengt als .get_parent().get_parent().
func karte(ueberschrift: String = "", hoch: bool = false) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(FLAECHE_HOCH if hoch else FLAECHE, R_NORMAL, RAND))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	if ueberschrift != "":
		var kopf := titel(ueberschrift, 1)
		v.add_child(kopf)
		v.add_child(trenner())
	p.set_meta("inhalt", v)
	v.set_meta("karte", p)
	return v

## Liefert das PanelContainer-Wurzelelement einer mit karte() erzeugten Karte.
func karte_wurzel(inhalt: Node) -> Control:
	return inhalt.get_meta("karte") as Control

func trenner() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 6)
	return s

func abstand(hoehe: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hoehe)
	return c

func dehner() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

## Abzeichen — kurzer farbiger Text auf getoenter Flaeche.
func abzeichen(beschriftung: String, farbe: Color, gefuellt: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(farbe.r, farbe.g, farbe.b, 0.9) if gefuellt else Color(farbe.r, farbe.g, farbe.b, 0.16), R_KLEIN, farbe, 1)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = beschriftung
	l.add_theme_font_size_override("font_size", S_MINI)
	l.add_theme_color_override("font_color", GRUND if gefuellt else farbe)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p

## Primaerknopf (Akzentfarbe) — fuer die jeweils wichtigste Aktion eines Bildschirms.
func knopf_primaer(beschriftung: String) -> Button:
	var b := Button.new()
	b.text = beschriftung
	var n := box(AKZENT, R_KLEIN)
	n.content_margin_left = 16
	n.content_margin_right = 16
	n.content_margin_top = 8
	n.content_margin_bottom = 8
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = AKZENT.lightened(0.12)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = AKZENT_TIEF
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color("#3a3428")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_color_override("font_color", Color("#1a1206"))
	b.add_theme_color_override("font_hover_color", Color("#000000"))
	b.add_theme_color_override("font_pressed_color", Color("#1a1206"))
	b.add_theme_color_override("font_disabled_color", Color("#7a6f5c"))
	return b

func knopf(beschriftung: String) -> Button:
	var b := Button.new()
	b.text = beschriftung
	return b

## Flacher Knopf ohne Rahmen — fuer Listeneintraege und Navigationen.
func knopf_flach(beschriftung: String, farbe: Variant = null) -> Button:
	var b := Button.new()
	b.text = beschriftung
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", farbe if farbe != null else BLAU)
	b.add_theme_color_override("font_hover_color", AKZENT)
	b.add_theme_font_size_override("font_size", S_NORMAL)
	return b

## Kleiner Balken mit Beschriftung, z. B. fuer Fitness oder Moral.
func balken(wert: float, maximum: float = 100.0, breite: int = 110, farbe: Variant = null) -> Control:
	var b := BalkenZeichner.new()
	b.wert = wert
	b.maximum = maximum
	b.farbe = farbe if farbe != null else prozent_farbe(wert / maximum * 100.0)
	b.custom_minimum_size = Vector2(breite, 10)
	return b

## Zeichnet einen schlichten Fortschrittsbalken selbst — kein Theme-Umweg noetig.
class BalkenZeichner extends Control:
	var wert: float = 0.0
	var maximum: float = 100.0
	var farbe: Color = Color.WHITE
	var hintergrund: Color = Color("#0a0d12")

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, hintergrund, true)
		draw_rect(r, Color("#2a3341"), false, 1.0)
		var t: float = clampf(wert / maxf(maximum, 0.001), 0.0, 1.0)
		if t > 0.0:
			draw_rect(Rect2(Vector2(1, 1), Vector2(maxf((size.x - 2) * t, 1.0), size.y - 2)), farbe, true)

	func setze(neuer_wert: float) -> void:
		wert = neuer_wert
		farbe = Stil.prozent_farbe(wert / maxf(maximum, 0.001) * 100.0)
		queue_redraw()

## Zeile aus Beschriftung + Wert, wie sie in Infokarten ueberall vorkommt.
func info_zeile(beschriftung: String, wert: String, wertfarbe: Variant = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_child(matt(beschriftung))
	h.add_child(dehner())
	var l := text(wert, S_KLEIN, wertfarbe)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	return h

## Raster fuer Tabellen: liefert einen GridContainer mit Kopfzeile.
func tabelle(spalten: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = spalten.size()
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 5)
	for s in spalten:
		var l := matt(str(s), S_MINI)
		l.add_theme_color_override("font_color", TEXT_SCHWACH)
		g.add_child(l)
	return g

## Scrollbereich, der seinen Inhalt vertikal fuellt.
func scroll(inhalt: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inhalt)
	return sc

func vbox(abstand_px: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", abstand_px)
	return v

func hbox(abstand_px: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", abstand_px)
	return h

## Formatiert Geldbetraege kompakt und deutsch.
func geld(betrag: float) -> String:
	var vz := "-" if betrag < 0 else ""
	var b: float = absf(betrag)
	if b >= 1000000.0:
		return "%s%s Mio. €" % [vz, String.num(b / 1000000.0, 2).replace(".", ",")]
	if b >= 1000.0:
		return "%s%s Tsd. €" % [vz, String.num(b / 1000.0, 1).replace(".", ",")]
	return "%s%d €" % [vz, int(round(b))]

## Zahl mit deutschem Tausenderpunkt.
func zahl(wert: int) -> String:
	var s := str(absi(wert))
	var aus := ""
	var z := 0
	for i in range(s.length() - 1, -1, -1):
		aus = s[i] + aus
		z += 1
		if z % 3 == 0 and i > 0:
			aus = "." + aus
	return ("-" if wert < 0 else "") + aus

func komma(wert: float, stellen: int = 1) -> String:
	return String.num(wert, stellen).replace(".", ",")
