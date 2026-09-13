extends Node
## Stil — das zentrale Design-System von Hallenherz.
##
## Jede Farbe, jede Schriftgroesse und jedes wiederverwendbare Control stammt aus
## dieser Datei. Bildschirme bauen ihre Oberflaeche ausschliesslich aus den hier
## angebotenen Bausteinen, damit das Spiel ueberall gleich aussieht.
## Es werden keinerlei externe Assets geladen — Schrift ist die Engine-Fallback-Schrift,
## alle Flaechen sind StyleBoxFlat, alle Symbole werden gezeichnet.

# ---------------------------------------------------------------- Farbwelt ---
# "Hallenlicht": tiefes Blaugrau als Grund, warmes Scheinwerfer-Amber als Akzent.
# Die Flaechen bilden eine klare Hoehenstaffelung — Grund, Karte, Zeile, Hover.
var GRUND := Color("#0a0e14")          # Fensterhintergrund
var FLAECHE_TIEF := Color("#070a10")   # eingelassene Bereiche, Eingabefelder
var FLAECHE := Color("#111823")        # Karten
var FLAECHE_HOCH := Color("#18212e")   # hervorgehobene Karten / Zeilen
var FLAECHE_GLAS := Color("#202b3a")   # Hover, aktive Elemente
var RAND := Color("#212b39")
var RAND_HELL := Color("#334152")

var TEXT := Color("#eef3f9")
var TEXT_MATT := Color("#93a3b5")
var TEXT_SCHWACH := Color("#5d6b7c")

var AKZENT := Color("#ffb340")         # Primaerakzent (Hallenlicht)
var AKZENT_TIEF := Color("#c27c1c")
var AKZENT_DUNKEL := Color("#3a2c12")  # Flaeche hinter Akzenttext
var BLAU := Color("#4fa8f5")
var GRUEN := Color("#3fc063")
var GELB := Color("#e9c44c")
var ROT := Color("#f0604f")
var LILA := Color("#a87cf5")
var TUERKIS := Color("#33cfc4")
var SCHATTEN := Color(0, 0, 0, 0.35)

# ------------------------------------------------------------ Typografie ---
const S_ETIKETT := 10
const S_MINI := 11
const S_KLEIN := 13
const S_NORMAL := 15
const S_GROSS := 18
const S_TITEL := 24
const S_RIESIG := 38
const S_ANZEIGE := 54   # Spielstandsanzeige

# ------------------------------------------------------------- Geometrie ---
const R_MINI := 3
const R_KLEIN := 5
const R_NORMAL := 9
const R_GROSS := 14
const R_RUND := 999

const A_MINI := 4
const A_KLEIN := 8
const A_NORMAL := 12
const A_GROSS := 18
const A_RIESIG := 26

var _theme: Theme = null

# ------------------------------------------------------------- Farbhilfen ---

# Farbverlauf fuer Attributwerte (1..20) — von rot ueber gelb zu gruen/tuerkis.
func wert_farbe(wert: float, maximum: float = 20.0) -> Color:
	var t: float = clampf(wert / maximum, 0.0, 1.0)
	if t < 0.35:
		return ROT.lerp(Color("#e58240"), t / 0.35)
	elif t < 0.55:
		return Color("#e58240").lerp(GELB, (t - 0.35) / 0.2)
	elif t < 0.78:
		return GELB.lerp(GRUEN, (t - 0.55) / 0.23)
	else:
		return GRUEN.lerp(TUERKIS, (t - 0.78) / 0.22)

## Farbe fuer Prozentwerte 0..100 (Form, Moral, Fitness).
func prozent_farbe(wert: float) -> Color:
	return wert_farbe(wert, 100.0)

## Dieselbe Farbe, nur als dezente Flaeche.
func lasur(farbe: Color, deckung: float = 0.15) -> Color:
	return Color(farbe.r, farbe.g, farbe.b, deckung)

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

## Karte mit weichem Schlagschatten — fuer erhabene Flaechen und Fenster.
func box_erhaben(fuellung: Color, radius: int = R_NORMAL, randfarbe: Variant = null) -> StyleBoxFlat:
	var sb := box(fuellung, radius, randfarbe)
	sb.shadow_color = SCHATTEN
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	return sb

func box_leer() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

## Rand nur an einer Seite — fuer Kopfzeilen und Spaltentrenner.
func box_kante(fuellung: Color, seite: String, farbe: Color, breite: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fuellung
	sb.border_color = farbe
	match seite:
		"unten": sb.border_width_bottom = breite
		"oben": sb.border_width_top = breite
		"links": sb.border_width_left = breite
		"rechts": sb.border_width_right = breite
	return sb

# ------------------------------------------------------------------ Theme ---
func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = S_NORMAL

	# Panel
	t.set_stylebox("panel", "PanelContainer", box(FLAECHE, R_NORMAL, RAND))
	t.set_stylebox("panel", "Panel", box(FLAECHE, R_NORMAL, RAND))

	# Label
	t.set_color("font_color", "Label", TEXT)

	# Button — flache Flaeche, klarer Hover, Akzentrand beim Druecken
	var b_normal := box(FLAECHE_HOCH, R_KLEIN, RAND_HELL)
	b_normal.content_margin_left = 14
	b_normal.content_margin_right = 14
	b_normal.content_margin_top = 7
	b_normal.content_margin_bottom = 7
	var b_hover := b_normal.duplicate() as StyleBoxFlat
	b_hover.bg_color = FLAECHE_GLAS
	b_hover.border_color = AKZENT_TIEF
	var b_press := b_normal.duplicate() as StyleBoxFlat
	b_press.bg_color = Color("#2a3646")
	b_press.border_color = AKZENT
	var b_dis := b_normal.duplicate() as StyleBoxFlat
	b_dis.bg_color = Color("#12181f")
	b_dis.border_color = Color("#1d242e")
	var b_fokus := b_normal.duplicate() as StyleBoxFlat
	b_fokus.bg_color = Color(0, 0, 0, 0)
	b_fokus.border_color = lasur(AKZENT, 0.75)
	b_fokus.set_border_width_all(1)
	t.set_stylebox("normal", "Button", b_normal)
	t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_press)
	t.set_stylebox("disabled", "Button", b_dis)
	t.set_stylebox("focus", "Button", b_fokus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", AKZENT)
	t.set_color("font_disabled_color", "Button", TEXT_SCHWACH)
	t.set_constant("h_separation", "Button", 8)

	# LineEdit / SpinBox
	var le := box(FLAECHE_TIEF, R_KLEIN, RAND_HELL)
	le.content_margin_left = 9
	le.content_margin_right = 9
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	var le_f := le.duplicate() as StyleBoxFlat
	le_f.border_color = AKZENT
	t.set_stylebox("focus", "LineEdit", le_f)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_SCHWACH)
	t.set_color("caret_color", "LineEdit", AKZENT)
	t.set_color("selection_color", "LineEdit", lasur(AKZENT, 0.3))

	# OptionButton erbt das Buttonbild
	t.set_stylebox("normal", "OptionButton", b_normal)
	t.set_stylebox("hover", "OptionButton", b_hover)
	t.set_stylebox("pressed", "OptionButton", b_press)
	t.set_stylebox("disabled", "OptionButton", b_dis)
	t.set_stylebox("focus", "OptionButton", b_fokus)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_hover_color", "OptionButton", Color.WHITE)

	# PopupMenu
	var pm := box_erhaben(FLAECHE_HOCH, R_KLEIN, RAND_HELL)
	pm.content_margin_top = 6
	pm.content_margin_bottom = 6
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_stylebox("hover", "PopupMenu", box(lasur(AKZENT, 0.16), R_MINI))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", AKZENT)
	t.set_color("font_separator_color", "PopupMenu", TEXT_SCHWACH)
	t.set_constant("v_separation", "PopupMenu", 4)

	# ScrollBar — schlank und zurueckhaltend
	var sbar := box(Color("#101720"), R_KLEIN)
	var grab := box(Color("#2e3a49"), R_KLEIN)
	var grab_h := box(Color("#46566a"), R_KLEIN)
	for klasse in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", klasse, sbar)
		t.set_stylebox("grabber", klasse, grab)
		t.set_stylebox("grabber_highlight", klasse, grab_h)
		t.set_stylebox("grabber_pressed", klasse, grab_h)

	# ProgressBar
	t.set_stylebox("background", "ProgressBar", box(FLAECHE_TIEF, R_KLEIN, RAND))
	t.set_stylebox("fill", "ProgressBar", box(AKZENT, R_KLEIN))

	# Slider
	t.set_stylebox("slider", "HSlider", box(FLAECHE_TIEF, R_MINI, RAND))
	t.set_stylebox("grabber_area", "HSlider", box(AKZENT_TIEF, R_MINI))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(AKZENT, R_MINI))

	# CheckBox / CheckButton
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_stylebox("focus", "CheckBox", box_leer())
	t.set_color("font_color", "CheckButton", TEXT)

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
	var tt := box_erhaben(Color("#080c12"), R_KLEIN, AKZENT_TIEF)
	tt.content_margin_left = 9
	tt.content_margin_right = 9
	t.set_stylebox("panel", "TooltipPanel", tt)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", S_KLEIN)

	_theme = t
	return _theme

# --------------------------------------------------------------- Bausteine ---

## Ueberschrift in drei Stufen (0 = Bildschirmtitel, 1 = Abschnitt, 2 = Kleinkram).
func titel(text_inhalt: String, stufe: int = 0, farbe: Variant = null) -> Label:
	var l := Label.new()
	l.text = text_inhalt
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	match stufe:
		0:
			l.add_theme_font_size_override("font_size", S_TITEL)
		1:
			l.add_theme_font_size_override("font_size", S_GROSS)
		_:
			l.add_theme_font_size_override("font_size", S_KLEIN)
	l.add_theme_color_override("font_color", farbe if farbe != null else TEXT)
	return l

## Bildschirmtitel mit Akzentmarke und optionaler Unterzeile.
func kopfzeile(haupt: String, unter: String = "") -> HBoxContainer:
	var h := hbox(A_NORMAL)
	var marke := Marke.new()
	marke.custom_minimum_size = Vector2(4, 30)
	marke.farbe = AKZENT
	h.add_child(marke)
	var v := vbox(0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	v.add_child(titel(haupt, 0))
	if unter != "":
		v.add_child(matt(unter, S_KLEIN))
	return h

## Senkrechter Akzentstrich mit runden Enden.
class Marke extends Control:
	var farbe: Color = Color.WHITE
	func _draw() -> void:
		var r := size.x * 0.5
		draw_rect(Rect2(Vector2(0, r), Vector2(size.x, maxf(size.y - size.x, 1.0))), farbe)
		draw_circle(Vector2(r, r), r, farbe)
		draw_circle(Vector2(r, size.y - r), r, farbe)

## Kleine Grossbuchstaben-Beschriftung ueber einem Wert oder Abschnitt.
func etikett(text_inhalt: String, farbe: Variant = null) -> Label:
	var l := Label.new()
	l.text = text_inhalt.to_upper()
	l.add_theme_font_size_override("font_size", S_ETIKETT)
	l.add_theme_color_override("font_color", farbe if farbe != null else TEXT_SCHWACH)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## Beschriftung fuer Tabellenkoepfe und Nebeninformationen.
func matt(text_inhalt: String, groesse: int = S_KLEIN) -> Label:
	var l := Label.new()
	l.text = text_inhalt
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", TEXT_MATT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func text(inhalt: String, groesse: int = S_NORMAL, farbe: Variant = null) -> Label:
	var l := Label.new()
	l.text = inhalt
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe if farbe != null else TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## Zahl in Anzeigegroesse — fuer Spielstand und Kennzahlen.
func anzeige(inhalt: String, groesse: int = S_RIESIG, farbe: Variant = null) -> Label:
	var l := Label.new()
	l.text = inhalt
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe if farbe != null else TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## Karte: Panel mit Innenabstand, Kopfzeile und Platz fuer Kopfaktionen.
## Rueckgabe ist die Inhalts-VBox; die Karte selbst liegt in deren Meta "karte".
func karte(ueberschrift: String = "", hoch: bool = false) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_erhaben(FLAECHE_HOCH if hoch else FLAECHE, R_NORMAL, RAND))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 15)
	m.add_theme_constant_override("margin_right", 15)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 13)
	p.add_child(m)
	var aussen := VBoxContainer.new()
	aussen.add_theme_constant_override("separation", A_KLEIN)
	m.add_child(aussen)
	if ueberschrift != "":
		var kopf := hbox(A_KLEIN)
		aussen.add_child(kopf)
		var punkt := Marke.new()
		punkt.custom_minimum_size = Vector2(3, 14)
		punkt.farbe = AKZENT
		punkt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kopf.add_child(punkt)
		kopf.add_child(etikett(ueberschrift, TEXT_MATT))
		kopf.add_child(dehner())
		var aktionen := hbox(A_MINI)
		kopf.add_child(aktionen)
		p.set_meta("aktionen", aktionen)
		aussen.add_child(trenner())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aussen.add_child(v)
	p.set_meta("inhalt", v)
	v.set_meta("karte", p)
	return v

## Liefert das PanelContainer-Wurzelelement einer mit karte() erzeugten Karte.
func karte_wurzel(inhalt: Node) -> Control:
	return inhalt.get_meta("karte") as Control

## Haengt ein Control rechts in die Kopfzeile einer Karte (Filter, kleine Knoepfe).
func karte_aktion(inhalt: Node, steuerung: Control) -> void:
	var wurzel := karte_wurzel(inhalt)
	if wurzel != null and wurzel.has_meta("aktionen"):
		(wurzel.get_meta("aktionen") as Node).add_child(steuerung)

## Kennzahlenkachel: Etikett, grosser Wert, Zusatzzeile.
func kachel(beschriftung: String, wert: String, hinweis: String = "", farbe: Variant = null) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(FLAECHE_HOCH, R_NORMAL, RAND)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := vbox(2)
	p.add_child(v)
	v.add_child(etikett(beschriftung))
	var w := text(wert, S_GROSS, farbe if farbe != null else TEXT)
	v.add_child(w)
	if hinweis != "":
		v.add_child(matt(hinweis, S_MINI))
	p.set_meta("wert", w)
	return p

## Abschnittsband — dezente Zwischenzeile in langen Listen.
func band(beschriftung: String, farbe: Variant = null) -> PanelContainer:
	var p := PanelContainer.new()
	var f: Color = farbe if farbe != null else AKZENT
	var sb := box_kante(lasur(f, 0.08), "links", f, 3)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.corner_radius_top_right = R_MINI
	sb.corner_radius_bottom_right = R_MINI
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(etikett(beschriftung, f))
	return p

## Hinweisstreifen: art = "info" | "erfolg" | "warnung" | "fehler".
func banner(nachricht: String, art: String = "info") -> PanelContainer:
	var f: Color = BLAU
	match art:
		"erfolg": f = GRUEN
		"warnung": f = GELB
		"fehler": f = ROT
	var p := PanelContainer.new()
	var sb := box_kante(lasur(f, 0.11), "links", f, 3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.corner_radius_top_right = R_KLEIN
	sb.corner_radius_bottom_right = R_KLEIN
	p.add_theme_stylebox_override("panel", sb)
	var l := text(nachricht, S_KLEIN, f)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return p

## Leerzustand: erklaert, warum hier nichts steht.
func leerzustand(nachricht: String, hinweis: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(FLAECHE_TIEF, R_NORMAL, RAND)
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var v := vbox(3)
	p.add_child(v)
	var l := text(nachricht, S_KLEIN, TEXT_MATT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if hinweis != "":
		var l2 := matt(hinweis, S_MINI)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l2)
	return p

func trenner() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 6)
	return s

func abstand(hoehe: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hoehe)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func dehner() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Abzeichen — kurzer farbiger Text auf getoenter Flaeche.
func abzeichen(beschriftung: String, farbe: Color, gefuellt: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(farbe.r, farbe.g, farbe.b, 0.92) if gefuellt else lasur(farbe, 0.14), R_MINI, farbe, 1)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = beschriftung
	l.add_theme_font_size_override("font_size", S_ETIKETT)
	l.add_theme_color_override("font_color", Color("#0a0e14") if gefuellt else farbe)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## Monogramm — runde Flaeche mit Initialen, als Ersatz fuer ein Portraet.
func monogramm(initialen: String, farbe: Color, groesse: float = 30.0) -> Control:
	var m := MonogrammZeichner.new()
	m.initialen = initialen.substr(0, 2).to_upper()
	m.farbe = farbe
	m.custom_minimum_size = Vector2(groesse, groesse)
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return m

class MonogrammZeichner extends Control:
	var initialen: String = ""
	var farbe: Color = Color.WHITE
	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		if s <= 5.0:
			return
		var m := Vector2(size.x, size.y) * 0.5
		draw_circle(m, s * 0.5, Color(farbe.r, farbe.g, farbe.b, 0.18))
		draw_arc(m, s * 0.5 - 1.0, 0.0, TAU, 28, Color(farbe.r, farbe.g, farbe.b, 0.6), 1.0, true)
		var schrift := ThemeDB.fallback_font
		var groesse: int = int(s * 0.42)
		var breite: float = schrift.get_string_size(initialen, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
		draw_string(schrift, m + Vector2(-breite * 0.5, groesse * 0.36), initialen,
			HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, farbe)

## Primaerknopf (Akzentfarbe) — fuer die jeweils wichtigste Aktion eines Bildschirms.
func knopf_primaer(beschriftung: String) -> Button:
	var b := Button.new()
	b.text = beschriftung
	var n := box(AKZENT, R_KLEIN)
	n.content_margin_left = 17
	n.content_margin_right = 17
	n.content_margin_top = 8
	n.content_margin_bottom = 9
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = AKZENT.lightened(0.14)
	h.shadow_color = Color(AKZENT.r, AKZENT.g, AKZENT.b, 0.35)
	h.shadow_size = 8
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = AKZENT_TIEF
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color("#33301f")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", box_leer())
	b.add_theme_color_override("font_color", Color("#171104"))
	b.add_theme_color_override("font_hover_color", Color("#000000"))
	b.add_theme_color_override("font_pressed_color", Color("#171104"))
	b.add_theme_color_override("font_disabled_color", Color("#7d7358"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b

func knopf(beschriftung: String) -> Button:
	var b := Button.new()
	b.text = beschriftung
	return b

## Geisterknopf — nur Rand, fuer Nebenaktionen in Kopfzeilen.
func knopf_geist(beschriftung: String, farbe: Variant = null) -> Button:
	var f: Color = farbe if farbe != null else TEXT_MATT
	var b := Button.new()
	b.text = beschriftung
	var n := box(Color(0, 0, 0, 0), R_KLEIN, lasur(f, 0.45))
	n.content_margin_left = 11
	n.content_margin_right = 11
	n.content_margin_top = 5
	n.content_margin_bottom = 6
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = lasur(f, 0.12)
	h.border_color = f
	var p := h.duplicate() as StyleBoxFlat
	p.bg_color = lasur(f, 0.22)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", box_leer())
	b.add_theme_color_override("font_color", f)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", S_KLEIN)
	return b

## Flacher Knopf ohne Rahmen — fuer Listeneintraege und Namen.
## Kleinste Höhe einer anklickbaren Fläche. Neunzehn Pixel trifft man nicht
## zuverlässig — auch nicht mit der Maus, und schon gar nicht in einer Tabelle,
## in der zwanzig davon untereinanderstehen.
const KLICKFLAECHE_MIN := 24

func knopf_flach(beschriftung: String, farbe: Variant = null) -> Button:
	var b := Button.new()
	b.text = beschriftung
	b.flat = true
	b.custom_minimum_size = Vector2(0, KLICKFLAECHE_MIN)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", farbe if farbe != null else TEXT)
	b.add_theme_color_override("font_hover_color", AKZENT)
	b.add_theme_font_size_override("font_size", S_KLEIN)
	b.add_theme_stylebox_override("normal", box_leer())
	b.add_theme_stylebox_override("focus", box_leer())
	var h := box(lasur(AKZENT, 0.10), R_MINI)
	h.content_margin_top = 2
	h.content_margin_bottom = 2
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	return b

## Schalter mit gezeichnetem Kaestchen — Godot bringt ohne Editor-Theme keine
## Haekchen-Symbole mit, deshalb zeichnet Hallenherz seine eigenen.
func schalter(beschriftung: String, an: bool = false) -> Button:
	var b := SchalterKnopf.new()
	b.toggle_mode = true
	b.button_pressed = an
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = beschriftung
	b.add_theme_font_size_override("font_size", S_KLEIN)
	b.add_theme_color_override("font_color", TEXT_MATT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_hover_pressed_color", TEXT)
	b.add_theme_stylebox_override("focus", box_leer())
	var n := box(Color(0, 0, 0, 0), R_KLEIN)
	n.content_margin_left = 26
	n.content_margin_right = 10
	n.content_margin_top = 5
	n.content_margin_bottom = 6
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = lasur(TEXT, 0.06)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("hover_pressed", h)
	b.toggled.connect(func(_an): b.queue_redraw())
	return b

class SchalterKnopf extends Button:
	func _draw() -> void:
		var s := 15.0
		var m := Vector2(8.0, (size.y - s) * 0.5)
		var r := Rect2(m, Vector2(s, s))
		if button_pressed:
			draw_rect(r, Stil.AKZENT, true)
			var p := PackedVector2Array([
				m + Vector2(s * 0.22, s * 0.52), m + Vector2(s * 0.42, s * 0.73),
				m + Vector2(s * 0.80, s * 0.27)])
			draw_polyline(p, Color("#171104"), 2.2, true)
		else:
			draw_rect(r, Stil.FLAECHE_TIEF, true)
			draw_rect(r, Stil.RAND_HELL, false, 1.0)

## Anklickbare Tabellenzeile: Zebrastreifen, Hover, optionale Hervorhebung.
## Listen, die ihre Zeilen selbst bauen, bekommen damit dasselbe Bild wie tabelle().
func zeilen_knopf(index: int, hervorgehoben: bool = false, hoehe: int = 29) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, hoehe)
	b.focus_mode = Control.FOCUS_NONE
	var grund: Color = Color(1, 1, 1, 0.028) if index % 2 == 1 else Color(0, 0, 0, 0)
	var n := box(lasur(AKZENT, 0.10) if hervorgehoben else grund, R_MINI)
	n.content_margin_left = 6
	n.content_margin_right = 6
	n.content_margin_top = 0
	n.content_margin_bottom = 0
	if hervorgehoben:
		n.border_color = AKZENT
		n.border_width_left = 2
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = lasur(AKZENT, 0.14)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = lasur(AKZENT, 0.20)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", d)
	b.add_theme_stylebox_override("focus", box_leer())
	return b

## Segmentierte Umschaltleiste — ersetzt lose Knopfreihen bei Reitern.
## optionen: Array von {"id":…, "name":…}. rueckruf bekommt die id.
func segmente(optionen: Array, aktiv: String, rueckruf: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(FLAECHE_TIEF, R_KLEIN, RAND)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h := hbox(2)
	p.add_child(h)
	for o in optionen:
		var id: String = str((o as Dictionary)["id"])
		var b := Button.new()
		b.text = str((o as Dictionary)["name"])
		b.add_theme_font_size_override("font_size", S_KLEIN)
		b.add_theme_stylebox_override("focus", box_leer())
		var an: bool = id == aktiv
		var n := box(lasur(AKZENT, 0.18) if an else Color(0, 0, 0, 0), R_MINI, AKZENT if an else null)
		n.content_margin_left = 13
		n.content_margin_right = 13
		n.content_margin_top = 5
		n.content_margin_bottom = 6
		var hb := n.duplicate() as StyleBoxFlat
		if not an:
			hb.bg_color = lasur(TEXT, 0.07)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", hb)
		b.add_theme_stylebox_override("pressed", n)
		b.add_theme_color_override("font_color", AKZENT if an else TEXT_MATT)
		b.add_theme_color_override("font_hover_color", Color.WHITE if not an else AKZENT)
		b.pressed.connect(func(): rueckruf.call(id))
		h.add_child(b)
	return p

## Kleiner Balken mit Beschriftung, z. B. fuer Fitness oder Moral.
func balken(wert: float, maximum: float = 100.0, breite: int = 110, farbe: Variant = null) -> Control:
	var b := BalkenZeichner.new()
	b.wert = wert
	b.maximum = maximum
	b.farbe = farbe if farbe != null else prozent_farbe(wert / maxf(maximum, 0.001) * 100.0)
	b.custom_minimum_size = Vector2(breite, 10)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

## Zeichnet einen schlichten Fortschrittsbalken selbst — kein Theme-Umweg noetig.
class BalkenZeichner extends Control:
	var wert: float = 0.0
	var maximum: float = 100.0
	var farbe: Color = Color.WHITE
	var hintergrund: Color = Color("#070a10")

	func _draw() -> void:
		if size.x < 4.0:
			return
		# Der Balken zeichnet immer ein Band fester Hoehe, mittig in der Zelle.
		# Manche Tabellen setzen die Mindestgroesse ihrer Zellen selbst; ohne
		# diese Absicherung bliebe vom Balken nur ein Strich uebrig.
		var h: float = clampf(size.y, 7.0, 11.0)
		var oben: float = maxf((size.y - h) * 0.5, 0.0)
		draw_rect(Rect2(Vector2(0, oben), Vector2(size.x, h)), hintergrund, true)
		draw_rect(Rect2(Vector2(0, oben), Vector2(size.x, h)), Color("#212b39"), false, 1.0)
		var t: float = clampf(wert / maxf(maximum, 0.001), 0.0, 1.0)
		if t <= 0.0:
			return
		var b: float = maxf((size.x - 2.0) * t, 1.5)
		draw_rect(Rect2(Vector2(1, oben + 1.0), Vector2(b, h - 2.0)), farbe, true)

	func setze(neuer_wert: float) -> void:
		wert = neuer_wert
		farbe = Stil.prozent_farbe(wert / maxf(maximum, 0.001) * 100.0)
		queue_redraw()

## Ringanzeige (Donut) fuer einen Anteil — kompakter als ein Balken.
func ring(wert: float, maximum: float = 100.0, groesse: float = 62.0,
		farbe: Variant = null, beschriftung: String = "") -> Control:
	var r := RingZeichner.new()
	r.wert = wert
	r.maximum = maximum
	r.farbe = farbe if farbe != null else prozent_farbe(wert / maxf(maximum, 0.001) * 100.0)
	r.beschriftung = beschriftung if beschriftung != "" else str(int(round(wert)))
	r.custom_minimum_size = Vector2(groesse, groesse)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r

class RingZeichner extends Control:
	var wert: float = 0.0
	var maximum: float = 100.0
	var farbe: Color = Color.WHITE
	var beschriftung: String = ""

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		if s <= 10.0:
			return
		var m := Vector2(size.x, size.y) * 0.5
		var dicke: float = maxf(s * 0.11, 3.0)
		var radius: float = s * 0.5 - dicke * 0.5 - 1.0
		draw_arc(m, radius, 0.0, TAU, 40, Color("#1b2432"), dicke, true)
		var t: float = clampf(wert / maxf(maximum, 0.001), 0.0, 1.0)
		if t > 0.0:
			draw_arc(m, radius, -PI / 2.0, -PI / 2.0 + TAU * t, 40, farbe, dicke, true)
		var schrift := ThemeDB.fallback_font
		var groesse: int = int(s * 0.30)
		var breite: float = schrift.get_string_size(beschriftung, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
		draw_string(schrift, m + Vector2(-breite * 0.5, groesse * 0.36), beschriftung,
			HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Stil.TEXT)

## Verlaufslinie fuer Reihen von Messwerten (Form, Kasse, Platzierung).
func linie(werte: Array, breite: int = 160, hoehe: int = 42, farbe: Variant = null,
		invertiert: bool = false) -> Control:
	var l := LinienZeichner.new()
	l.werte = werte
	l.farbe = farbe if farbe != null else AKZENT
	l.invertiert = invertiert
	l.custom_minimum_size = Vector2(breite, hoehe)
	return l

class LinienZeichner extends Control:
	var werte: Array = []
	var farbe: Color = Color.WHITE
	var invertiert: bool = false

	func _draw() -> void:
		if werte.size() < 2 or size.x < 8.0 or size.y < 8.0:
			return
		var tief: float = INF
		var hoch: float = -INF
		for w in werte:
			tief = minf(tief, float(w))
			hoch = maxf(hoch, float(w))
		if hoch - tief < 0.001:
			hoch = tief + 1.0
		var rand := 3.0
		var punkte := PackedVector2Array()
		for i in range(werte.size()):
			var x: float = rand + (size.x - rand * 2.0) * float(i) / float(werte.size() - 1)
			var t: float = (float(werte[i]) - tief) / (hoch - tief)
			if invertiert:
				t = 1.0 - t
			var y: float = size.y - rand - (size.y - rand * 2.0) * t
			punkte.append(Vector2(x, y))
		# Flaeche unter der Linie als dezente Lasur
		var flaeche := punkte.duplicate()
		flaeche.append(Vector2(punkte[punkte.size() - 1].x, size.y))
		flaeche.append(Vector2(punkte[0].x, size.y))
		if flaeche.size() >= 3:
			draw_colored_polygon(flaeche, Color(farbe.r, farbe.g, farbe.b, 0.12))
		draw_polyline(punkte, farbe, 1.8, true)
		draw_circle(punkte[punkte.size() - 1], 2.6, farbe)

## Saeulenreihe — fuer Verteilungen (Tore je Position, Einnahmen je Woche).
func saeulen(werte: Array, breite: int = 150, hoehe: int = 44, farbe: Variant = null) -> Control:
	var s := SaeulenZeichner.new()
	s.werte = werte
	s.farbe = farbe if farbe != null else BLAU
	s.custom_minimum_size = Vector2(breite, hoehe)
	return s

class SaeulenZeichner extends Control:
	var werte: Array = []
	var farbe: Color = Color.WHITE

	func _draw() -> void:
		if werte.is_empty() or size.x < 6.0:
			return
		var hoch := 0.0
		for w in werte:
			hoch = maxf(hoch, float(w))
		if hoch <= 0.0:
			return
		var luecke := 2.0
		var b: float = maxf((size.x - luecke * float(werte.size() - 1)) / float(werte.size()), 1.0)
		for i in range(werte.size()):
			var h: float = maxf(size.y * (float(werte[i]) / hoch), 1.0)
			var x: float = float(i) * (b + luecke)
			draw_rect(Rect2(Vector2(x, size.y - h), Vector2(b, h)),
				Color(farbe.r, farbe.g, farbe.b, 0.55 + 0.45 * float(werte[i]) / hoch), true)

## Zeile aus Beschriftung + Wert, wie sie in Infokarten ueberall vorkommt.
func info_zeile(beschriftung: String, wert: String, wertfarbe: Variant = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", A_KLEIN)
	h.add_child(matt(beschriftung))
	h.add_child(dehner())
	var l := text(wert, S_KLEIN, wertfarbe)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	return h

## Raster fuer Tabellen: GridContainer mit Kopfzeile, Kopflinie und Zebrastreifen.
func tabelle(spalten: Array) -> GridContainer:
	var g := RasterTabelle.new()
	g.columns = maxi(spalten.size(), 1)
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 6)
	for s in spalten:
		var l := Label.new()
		l.text = str(s).to_upper()
		l.add_theme_font_size_override("font_size", S_ETIKETT)
		l.add_theme_color_override("font_color", TEXT_SCHWACH)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.add_child(l)
	return g

## Zeichnet Zebrastreifen und die Linie unter dem Tabellenkopf hinter den Zellen.
## So bekommt jede Tabelle im Spiel dasselbe Bild, ohne dass ein Bildschirm etwas tun muss.
class RasterTabelle extends GridContainer:
	var hervorgehoben: Array = []

	func _ready() -> void:
		# Erst nach dem Sortieren zeichnen: vorher stehen die Kindpositionen
		# noch auf null und alle Zeilenbaender lägen uebereinander am oberen Rand.
		sort_children.connect(queue_redraw)
		resized.connect(queue_redraw)

	func hebe_zeile(zeile: int) -> void:
		if not hervorgehoben.has(zeile):
			hervorgehoben.append(zeile)
			queue_redraw()

	func _draw() -> void:
		var spalten: int = maxi(columns, 1)
		var zeilen: int = int(ceil(float(get_child_count()) / float(spalten)))
		if zeilen <= 0:
			return
		var luecke: float = float(get_theme_constant("v_separation"))
		for z in range(zeilen):
			var oben: float = INF
			var unten: float = -INF
			for s in range(spalten):
				var i: int = z * spalten + s
				if i >= get_child_count():
					break
				var k := get_child(i) as Control
				if k == null or not k.visible:
					continue
				oben = minf(oben, k.position.y)
				unten = maxf(unten, k.position.y + k.size.y)
			if oben == INF:
				continue
			var r := Rect2(Vector2(-6.0, oben - luecke * 0.5), Vector2(size.x + 12.0, unten - oben + luecke))
			if z == 0:
				draw_line(Vector2(-6.0, unten + luecke * 0.5), Vector2(size.x + 6.0, unten + luecke * 0.5),
					Stil.RAND, 1.0)
				continue
			if hervorgehoben.has(z - 1):
				draw_rect(r, Stil.lasur(Stil.AKZENT, 0.10), true)
				draw_rect(Rect2(r.position, Vector2(2.0, r.size.y)), Stil.AKZENT, true)
			elif z % 2 == 0:
				draw_rect(r, Color(1, 1, 1, 0.032), true)

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

## Raster mit gleich breiten Spalten — fuer Kachelreihen.
func raster(spalten: int, abstand_px: int = 12) -> GridContainer:
	var g := GridContainer.new()
	g.columns = maxi(spalten, 1)
	g.add_theme_constant_override("h_separation", abstand_px)
	g.add_theme_constant_override("v_separation", abstand_px)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

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
