extends Node
## Stil — das zentrale Design-System von Hallenherz.
##
## Jede Farbe, jede Schriftgroesse und jedes wiederverwendbare Control stammt aus
## dieser Datei. Bildschirme bauen ihre Oberflaeche ausschliesslich aus den hier
## angebotenen Bausteinen, damit das Spiel ueberall gleich aussieht.
## Es werden keinerlei externe Assets geladen — Schrift ist die Engine-Fallback-Schrift,
## alle Flaechen sind StyleBoxFlat, alle Symbole werden gezeichnet.

# ---------------------------------------------------------------- Farbwelt ---
# "Nachtblau": ein sehr tiefes Blau als Grund, Violett als Handlungsfarbe,
# Magenta als Stimme der Oberflaeche. Die Flaechen bilden eine klare
# Hoehenstaffelung — Grund, Karte, Zeile, Hover.
#
# Der Vorgaenger war Bernstein auf Anthrazit. Das war warm und lesbar, aber es
# sah aus wie eine Tabellenkalkulation mit Lichtstimmung: jede Flaeche trug
# einen Rahmen, jede Karte einen Akzentstrich, und weil alles gleich laut
# sprach, fuehrte nichts das Auge. Der neue Grund kommt ohne Linien aus —
# getrennt wird ueber Hoehe und Abstand, nicht ueber Striche.
var GRUND := Color("#070a14")          # Fensterhintergrund
var FLAECHE_TIEF := Color("#04060d")   # eingelassene Bereiche, Eingabefelder
var FLAECHE := Color("#0f1522")        # Karten
var FLAECHE_HOCH := Color("#151d2e")   # hervorgehobene Karten / Zeilen
var FLAECHE_GLAS := Color("#1e283c")   # Hover, aktive Elemente
var RAND := Color("#1a2234")
var RAND_HELL := Color("#2b3750")

var TEXT := Color("#f2f5fb")
var TEXT_MATT := Color("#98a4bb")
var TEXT_SCHWACH := Color("#5f6b83")

var AKZENT := Color("#8b5cf6")         # Handlungsfarbe: aktiv, primaer, Fortschritt
var AKZENT_TIEF := Color("#6d3fe0")
var AKZENT_DUNKEL := Color("#1d1735")  # Flaeche hinter Akzenttext
## Die Stimme der Oberflaeche: Abschnittsueberschriften, Etiketten, Rubriken.
## Sie handelt nicht, sie benennt — deshalb eine andere Farbe als AKZENT.
var SIGNAL := Color("#ff3d8a")
var BLAU := Color("#38bdf8")
var GRUEN := Color("#34d399")
var GELB := Color("#fbbf24")
var ROT := Color("#f87171")
var LILA := Color("#c084fc")
var TUERKIS := Color("#2dd4bf")
var SCHATTEN := Color(0, 0, 0, 0.55)

# ------------------------------------------------------------- Themenwahl ---
## Zwei Handschriften, eine Datei.
##
## "Nachtblau" ist das, was oben steht: dunkler Grund, gerundete Karten mit
## Hoehenstaffelung, Violett als Handlungsfarbe, Magenta als Stimme.
##
## "Hallenlicht" ist der Gegenentwurf und keine Aufhellung desselben Bildes.
## Der Unterschied liegt nicht in den Farben, sondern darin, was die Flaeche
## traegt: Nachtblau trennt ueber Hoehe — jede Karte ist ein Koerper mit
## Schatten und Lichtkante. Hallenlicht trennt ueber Weissraum und Haarlinien;
## es gibt keine Koerper, nur eine Seite. Damit kann Hierarchie wieder ueber
## Typografie und Abstand entstehen statt ueber Panels, die alle gleich
## aussehen.
##
## Dahinter steht der Zweck: das Spiel ist ein Lese- und Vergleichswerkzeug
## fuer lange Sitzungen. Dichte Zahlenspalten liest man auf hellem, ruhigem
## Grund besser, und je weniger gleichzeitig um Aufmerksamkeit ruft, desto
## eher faellt das auf, was wirklich eine Entscheidung verlangt.
enum { NACHTBLAU, HALLENLICHT }
var thema: int = NACHTBLAU
## Traegt die Flaeche Koerper (Schatten, Rundung) oder nur Linien?
var flaechen_koerper: bool = true

func thema_setzen(welches: int) -> void:
	thema = welches
	if welches == HALLENLICHT:
		GRUND = Color("#f4f2ee")
		FLAECHE_TIEF = Color("#eceae5")
		FLAECHE = Color("#faf9f7")
		FLAECHE_HOCH = Color("#ffffff")
		FLAECHE_GLAS = Color("#e7e4dd")
		RAND = Color("#d9d5cc")
		RAND_HELL = Color("#c2bdb1")
		TEXT = Color("#16181d")
		TEXT_MATT = Color("#585c66")
		TEXT_SCHWACH = Color("#8a8e99")
		# Eine einzige Handlungsfarbe. Sie sagt "hier kann man etwas tun" und
		# sonst nichts.
		AKZENT = Color("#1d4ed8")
		AKZENT_TIEF = Color("#1e40af")
		AKZENT_DUNKEL = Color("#dfe6fb")
		# Und eine einzige Alarmfarbe, die nirgends als Zierde vorkommt.
		SIGNAL = Color("#b91c1c")
		BLAU = Color("#0369a1")
		GRUEN = Color("#15803d")
		GELB = Color("#a16207")
		ROT = Color("#b91c1c")
		LILA = Color("#6d28d9")
		TUERKIS = Color("#0f766e")
		SCHATTEN = Color(0, 0, 0, 0.10)
		flaechen_koerper = false
	else:
		GRUND = Color("#070a14")
		FLAECHE_TIEF = Color("#04060d")
		FLAECHE = Color("#0f1522")
		FLAECHE_HOCH = Color("#151d2e")
		FLAECHE_GLAS = Color("#1e283c")
		RAND = Color("#1a2234")
		RAND_HELL = Color("#2b3750")
		TEXT = Color("#f2f5fb")
		TEXT_MATT = Color("#98a4bb")
		TEXT_SCHWACH = Color("#5f6b83")
		AKZENT = Color("#8b5cf6")
		AKZENT_TIEF = Color("#6d3fe0")
		AKZENT_DUNKEL = Color("#1d1735")
		SIGNAL = Color("#ff3d8a")
		BLAU = Color("#38bdf8")
		GRUEN = Color("#34d399")
		GELB = Color("#fbbf24")
		ROT = Color("#f87171")
		LILA = Color("#c084fc")
		TUERKIS = Color("#2dd4bf")
		SCHATTEN = Color(0, 0, 0, 0.55)
		flaechen_koerper = true

# ------------------------------------------------------------ Typografie ---
const S_ETIKETT := 10
const S_MINI := 11
const S_KLEIN := 13
const S_NORMAL := 15
const S_GROSS := 19
const S_TITEL := 27
const S_RIESIG := 40
const S_ANZEIGE := 56   # Spielstandsanzeige

# ------------------------------------------------------------- Geometrie ---
# Groessere Radien und mehr Luft. Der alte Satz war auf Dichte ausgelegt; eine
# Oberflaeche, die nach etwas aussehen soll, braucht zuerst Abstand.
const R_MINI := 4
const R_KLEIN := 8
const R_NORMAL := 12
const R_GROSS := 18
const R_RUND := 999

const A_MINI := 4
const A_KLEIN := 8
const A_NORMAL := 14
const A_GROSS := 20
const A_RIESIG := 28

# ------------------------------------------------------------ Schriftschnitte ---
#
# Die Engine bringt genau einen Schnitt mit. Ohne Gewichtsunterschied klingt
# jede Fläche gleich laut: Überschrift, Wert und Fußnote unterscheiden sich nur
# in der Größe, und das reicht nicht, um ein Auge zu führen.
#
# Der erste Versuch löste das mit FontVariation.variation_embolden — und das
# war falsch. Godot fettet synthetisch, indem es die Kontur nach außen
# versetzt; ab etwa 0.08 überschneidet sich die Kontur mit sich selbst, und in
# einer Vergleichstafel über acht Stufen sieht man das Ergebnis: Sporne an den
# Ecken von "N" und "1", zugelaufene Punzen, ein zerfressenes "M". Bei 0.48,
# dem ursprünglich gewählten Wert, ist jede große Zahl sichtbar beschädigt.
#
# Deshalb zwei Wege statt einem:
#   * synthetisch nur noch bis 0.05 — spürbar, aber ohne Artefakte
#   * echte Schriftdateien in assets/schrift/ haben Vorrang, sobald welche
#     dort liegen. Erst damit gibt es einen wirklichen Fettschnitt.

## Ordner für eigene Schriftdateien. Erkannt werden "normal", "halbfett" und
## "fett" mit den üblichen Endungen.
const SCHRIFTORDNER := "res://assets/schrift"
const SCHRIFT_ENDUNGEN := ["ttf", "otf", "woff2", "woff"]
## So weit darf synthetisch gefettet werden, ohne dass die Kontur ausfranst.
const EMBOLDEN_GRENZE := 0.05

var _schnitte: Dictionary = {}

## Sucht eine hinterlegte Schriftdatei. Auch das Nichtvorhandensein wird
## gemerkt — sonst prüft jeder Bildschirmaufbau das Dateisystem erneut.
func _datei_schrift(name: String) -> Font:
	var schluessel := "datei_" + name
	if _schnitte.has(schluessel):
		return _schnitte[schluessel]
	var gefunden: Font = null
	for endung in SCHRIFT_ENDUNGEN:
		var pfad := "%s/%s.%s" % [SCHRIFTORDNER, name, endung]
		if ResourceLoader.exists(pfad):
			var res := ResourceLoader.load(pfad)
			if res is Font:
				gefunden = res
				break
	_schnitte[schluessel] = gefunden
	return gefunden

## Ein Schnitt: bevorzugt die hinterlegte Datei, sonst die Engine-Schrift mit
## maßvoller synthetischer Fettung.
func _schnitt(name: String, datei: String, embolden: float, sperrung: int) -> FontVariation:
	if _schnitte.has(name):
		return _schnitte[name]
	var f := FontVariation.new()
	var eigen := _datei_schrift(datei)
	if eigen != null:
		# Mit echtem Schnitt ist synthetische Fettung überflüssig und schädlich.
		f.base_font = eigen
		f.variation_embolden = 0.0
	else:
		f.base_font = grundschrift()
		f.variation_embolden = clampf(embolden, 0.0, EMBOLDEN_GRENZE)
	f.spacing_glyph = sperrung
	_schnitte[name] = f
	return f

## Die Grundschrift für alles ohne besonderen Schnitt.
func grundschrift() -> Font:
	var eigen := _datei_schrift("normal")
	return eigen if eigen != null else ThemeDB.fallback_font

## Halbfett — Werte, Knöpfe, Spielernamen.
func schnitt_halbfett() -> FontVariation:
	return _schnitt("halbfett", "halbfett", 0.03, 0)

## Fett — Überschriften und große Zahlen.
func schnitt_fett() -> FontVariation:
	return _schnitt("fett", "fett", 0.05, 0)

## Gesperrt — Versalien-Etiketten. Ohne Laufweite kleben Großbuchstaben.
func schnitt_gesperrt() -> FontVariation:
	return _schnitt("gesperrt", "halbfett", 0.02, 1)

## Eng — lange Zahlenkolonnen, die sonst die Spalte sprengen.
func schnitt_eng() -> FontVariation:
	return _schnitt("eng", "normal", 0.0, -1)

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
## Grundfläche mit Lichtstimmung.
##
## Ein gleichmäßig gefüllter Hintergrund ist der sicherste Weg, eine Oberfläche
## billig aussehen zu lassen: echtes Licht fällt nie überall gleich. Ein sehr
## flacher radialer Schein oben links über der Mitte genügt — bewusst sieht ihn
## niemand, aber die Fläche bekommt eine Richtung, und alles, was darauf liegt,
## wirkt aufgesetzt statt eingefärbt.
func grundflaeche() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		GRUND.lightened(0.075), GRUND.lightened(0.018), GRUND.darkened(0.32)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.40, 0.02)
	t.fill_to = Vector2(1.30, 1.05)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

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
	if not flaechen_koerper:
		# Hallenlicht kennt keine Koerper. Eine Karte ist hier ein Abschnitt
		# der Seite: gleiche Flaeche wie der Grund, eine Haarlinie ringsum,
		# kaum Rundung, kein Schatten. Was sie zusammenhaelt, ist der Abstand
		# zum Nachbarn — nicht ein aufgemalter Kasten.
		var flach := box(fuellung, 3, RAND)
		flach.shadow_size = 0
		return flach
	var sb := box(fuellung, radius, randfarbe)
	sb.shadow_color = SCHATTEN
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	lichtkante(sb)
	return sb

## Eine hellere Oberkante. Licht kommt von oben — ohne diesen einen Pixel
## sieht jede Fläche aus wie ein aufgemalter Kasten statt wie ein Körper.
func lichtkante(sb: StyleBoxFlat, staerke: float = 0.055) -> StyleBoxFlat:
	if not flaechen_koerper:
		return sb
	sb.border_width_top = maxi(sb.border_width_top, 1)
	# Godot kennt nur eine Randfarbe je Box. Die Oberkante wird deshalb über
	# eine leicht aufgehellte Randfarbe angedeutet, die zum Rest noch passt.
	sb.border_color = sb.border_color.lerp(Color(1, 1, 1, sb.border_color.a), staerke * 2.0)
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
	t.set_stylebox("panel", "PanelContainer", box(FLAECHE, R_GROSS, RAND))
	t.set_stylebox("panel", "Panel", box(FLAECHE, R_GROSS, RAND))

	# Label
	t.set_color("font_color", "Label", TEXT)

	# Button — flache Flaeche, klarer Hover, Akzentrand beim Druecken
	# Knoepfe ohne Rahmen. Eine Flaeche, die eine Stufe hoeher liegt als ihr
	# Grund, liest sich als Knopf; ein Strich drumherum macht daraus nur einen
	# Kasten mehr auf einem Bildschirm, der ohnehin voller Kaesten steht.
	var b_normal := box(FLAECHE_HOCH, R_KLEIN)
	b_normal.content_margin_left = 16
	b_normal.content_margin_right = 16
	b_normal.content_margin_top = 8
	b_normal.content_margin_bottom = 8
	var b_hover := b_normal.duplicate() as StyleBoxFlat
	b_hover.bg_color = FLAECHE_GLAS
	var b_press := b_normal.duplicate() as StyleBoxFlat
	b_press.bg_color = AKZENT_DUNKEL.lerp(AKZENT, 0.22)
	var b_dis := b_normal.duplicate() as StyleBoxFlat
	b_dis.bg_color = Color("#0d1320")
	var b_fokus := b_normal.duplicate() as StyleBoxFlat
	b_fokus.bg_color = Color(0, 0, 0, 0)
	b_fokus.border_color = lasur(AKZENT, 0.85)
	b_fokus.set_border_width_all(2)
	t.set_stylebox("normal", "Button", b_normal)
	t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_press)
	t.set_stylebox("disabled", "Button", b_dis)
	t.set_stylebox("focus", "Button", b_fokus)
	# Ein Knopf ist eine Handlung — er darf schwerer wiegen als Fließtext.
	t.set_font("font", "Button", schnitt_halbfett())
	t.set_font("font", "OptionButton", schnitt_halbfett())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", LILA)
	t.set_color("font_disabled_color", "Button", TEXT_SCHWACH)
	t.set_constant("h_separation", "Button", 8)

	# LineEdit / SpinBox
	var le := box(FLAECHE_TIEF, R_KLEIN, RAND)
	le.content_margin_left = 12
	le.content_margin_right = 12
	le.content_margin_top = 8
	le.content_margin_bottom = 8
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
	t.set_stylebox("hover", "PopupMenu", box(lasur(AKZENT, 0.22), R_KLEIN))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_separator_color", "PopupMenu", TEXT_SCHWACH)
	t.set_constant("v_separation", "PopupMenu", 4)

	# ScrollBar — schlank und zurueckhaltend
	var sbar := box(Color(0, 0, 0, 0), R_RUND)
	var grab := box(Color("#26314a"), R_RUND)
	var grab_h := box(Color("#3a4a6b"), R_RUND)
	for klasse in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", klasse, sbar)
		t.set_stylebox("grabber", klasse, grab)
		t.set_stylebox("grabber_highlight", klasse, grab_h)
		t.set_stylebox("grabber_pressed", klasse, grab_h)

	# ProgressBar
	t.set_stylebox("background", "ProgressBar", box(FLAECHE_TIEF, R_RUND))
	t.set_stylebox("fill", "ProgressBar", box(AKZENT, R_RUND))

	# Slider
	t.set_stylebox("slider", "HSlider", box(FLAECHE_TIEF, R_RUND))
	t.set_stylebox("grabber_area", "HSlider", box(AKZENT_TIEF, R_RUND))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(AKZENT, R_RUND))

	# CheckBox / CheckButton
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_stylebox("focus", "CheckBox", box_leer())
	t.set_color("font_color", "CheckButton", TEXT)

	# Separator
	var sep := StyleBoxLine.new()
	sep.color = RAND
	sep.thickness = 1
	sep.grow_begin = 0.0
	sep.grow_end = 0.0
	t.set_stylebox("separator", "HSeparator", sep)
	var sepv := StyleBoxLine.new()
	sepv.color = RAND
	sepv.thickness = 1
	sepv.vertical = true
	t.set_stylebox("separator", "VSeparator", sepv)

	# Tooltip
	var tt := box_erhaben(Color("#0b1120"), R_KLEIN, RAND_HELL)
	tt.content_margin_left = 11
	tt.content_margin_right = 11
	tt.content_margin_top = 7
	tt.content_margin_bottom = 8
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
	# Eine Überschrift ist erst dann eine, wenn sie auch schwerer wiegt.
	l.add_theme_font_override("font", schnitt_fett())
	l.add_theme_color_override("font_color", farbe if farbe != null else TEXT)
	return l

## Bildschirmtitel mit Akzentmarke und optionaler Unterzeile.
func kopfzeile(haupt: String, unter: String = "") -> HBoxContainer:
	var h := hbox(A_NORMAL)
	var v := vbox(1)
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

## Ein Akzentstrich als fertiges Control — spart den immer gleichen Dreisatz
## aus Erzeugen, Groesse setzen und Farbe zuweisen.
func marke_strich(farbe: Color, breite: int = 3, hoehe: int = 16) -> Marke:
	var m := Marke.new()
	m.custom_minimum_size = Vector2(breite, hoehe)
	m.farbe = farbe
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return m

## Kleine Grossbuchstaben-Beschriftung ueber einem Wert oder Abschnitt.
func etikett(text_inhalt: String, farbe: Variant = null) -> Label:
	var l := Label.new()
	l.text = text_inhalt.to_upper()
	l.add_theme_font_size_override("font_size", S_ETIKETT)
	l.add_theme_font_override("font", schnitt_gesperrt())
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

## Rueckgabe ist die Inhalts-VBox; die Karte selbst liegt in deren Meta "karte".
## Karte: Panel mit Innenabstand, Rubrik und Platz fuer Kopfaktionen.
##
## Die Rubrik steht in Magenta, klein und gesperrt. Sie benennt die Karte und
## ist damit die einzige Farbe, die eine ruhige Karte traegt — Strich, Punkt
## und Trennlinie sind weg. Drei Zeichen fuer dieselbe Aussage waren zwei zu
## viel, und die Trennlinie unter jeder Ueberschrift zerschnitt jede Karte in
## zwei Kaesten.
func karte(ueberschrift: String = "", hoch: bool = false) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_erhaben(FLAECHE_HOCH if hoch else FLAECHE, R_GROSS, RAND))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 15)
	m.add_theme_constant_override("margin_bottom", 17)
	p.add_child(m)
	var aussen := VBoxContainer.new()
	aussen.add_theme_constant_override("separation", A_KLEIN + 2)
	m.add_child(aussen)
	if ueberschrift != "":
		var kopf := hbox(A_KLEIN)
		aussen.add_child(kopf)
		var kopftext := etikett(ueberschrift, SIGNAL)
		kopf.add_child(kopftext)
		p.set_meta("kopftext", kopftext)
		kopf.add_child(dehner())
		var aktionen := hbox(A_MINI)
		kopf.add_child(aktionen)
		p.set_meta("aktionen", aktionen)
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

## Hebt eine Karte hervor, die etwas vom Spieler will.
##
## Auf einer Übersicht liegen Anliegen, Pressetermine und reine Auskunft
## nebeneinander. Sind alle gleich gebaut, muss man jede lesen, um zu wissen,
## welche eine Entscheidung verlangt. Ein getönter Grund, eine farbige linke
## Kante und ein eingefärbter Kopf erledigen das vor dem ersten Wort.
func karte_betonen(inhalt: Node, farbe: Variant = null) -> void:
	var wurzel := karte_wurzel(inhalt)
	if wurzel == null:
		return
	var f: Color = farbe if farbe != null else AKZENT
	var sb := box_erhaben(FLAECHE_HOCH.lerp(f, 0.055), R_GROSS, RAND.lerp(f, 0.45))
	wurzel.add_theme_stylebox_override("panel", sb)
	if wurzel.has_meta("kopftext"):
		(wurzel.get_meta("kopftext") as Label).add_theme_color_override("font_color", f)

## Haengt ein Control rechts in die Kopfzeile einer Karte (Filter, kleine Knoepfe).
func karte_aktion(inhalt: Node, steuerung: Control) -> void:
	var wurzel := karte_wurzel(inhalt)
	if wurzel != null and wurzel.has_meta("aktionen"):
		(wurzel.get_meta("aktionen") as Node).add_child(steuerung)

## Kennzahlenkachel: Etikett, grosser Wert, Zusatzzeile.
## Kennzahlenkachel. Drei Ebenen mit deutlich verschiedenem Gewicht: ein
## gesperrtes Etikett, darunter der Wert als schwere Zahl, darunter die
## Einordnung. Eine farbige Oberkante trägt die Bedeutung, ohne dass der Wert
## selbst schreien muss — sonst leuchtet ein Bildschirm an sechs Stellen
## gleich stark und führt das Auge nirgendwohin.
func kachel(beschriftung: String, wert: String, hinweis: String = "", farbe: Variant = null) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box_erhaben(FLAECHE, R_GROSS, RAND)
	sb.content_margin_left = 15
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 15
	if farbe != null:
		sb.bg_color = FLAECHE.lerp(farbe as Color, 0.05)
		sb.border_color = RAND.lerp(farbe as Color, 0.32)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := vbox(3)
	p.add_child(v)
	v.add_child(beschnitten(etikett(beschriftung), float(S_ETIKETT) + 5.0))
	var w := Label.new()
	w.text = wert
	w.add_theme_font_size_override("font_size", S_TITEL)
	w.add_theme_font_override("font", schnitt_fett())
	w.add_theme_color_override("font_color", farbe if farbe != null else TEXT)
	w.clip_text = true
	w.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(beschnitten(w, float(S_TITEL) + 9.0))
	if hinweis != "":
		var hl := matt(hinweis, S_MINI)
		hl.clip_text = true
		v.add_child(beschnitten(hl, float(S_MINI) + 6.0))
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
##
## Ohne Rand. Ein umrandetes Abzeichen ist ein Kasten, und in einer Kaderzeile
## stehen bis zu vier davon nebeneinander: das las sich wie eine Reihe kleiner
## Formularfelder. Die getoente Fuellung traegt die Farbe allein.
func abzeichen(beschriftung: String, farbe: Color, gefuellt: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(farbe.r, farbe.g, farbe.b, 0.95) if gefuellt else lasur(farbe, 0.18), R_KLEIN)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = beschriftung
	l.add_theme_font_size_override("font_size", S_ETIKETT)
	l.add_theme_font_override("font", schnitt_halbfett())
	l.add_theme_color_override("font_color", Color("#080b14") if gefuellt else farbe.lightened(0.18))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## Das Zeichen der Wortmarke: ein Herzschlag in einem Ring.
##
## Hallenherz heisst das Spiel, und ein Herzschlag laesst sich in wenigen
## Linien zeichnen — das spart eine Bilddatei und bleibt bei jeder Groesse
## scharf.
func wortzeichen(groesse: float = 32.0) -> Control:
	var w := Wortzeichen.new()
	w.custom_minimum_size = Vector2(groesse, groesse)
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w

class Wortzeichen extends Control:
	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		if s < 8.0:
			return
		var m := size * 0.5
		draw_circle(m, s * 0.5, Stil.lasur(Stil.AKZENT, 0.16))
		draw_arc(m, s * 0.5 - 1.0, 0.0, TAU, 40, Stil.lasur(Stil.AKZENT, 0.55), maxf(s * 0.045, 1.2), true)
		var p := PackedVector2Array()
		var kasten := s * 0.62
		var links := m.x - kasten * 0.5
		var hoch := kasten * 0.30
		for punkt in [Vector2(0.00, 0.0), Vector2(0.22, 0.0), Vector2(0.36, -1.0),
				Vector2(0.52, 0.85), Vector2(0.68, -0.35), Vector2(0.80, 0.0), Vector2(1.0, 0.0)]:
			p.append(Vector2(links + punkt.x * kasten, m.y + punkt.y * hoch))
		draw_polyline(p, Stil.AKZENT, maxf(s * 0.062, 1.6), true)

## Ein Text, der seine Spalte nicht auseinanderdrueckt.
##
## `clip_text` schneidet in Godot zwar die Darstellung ab, senkt aber die
## Mindestbreite eines Labels nicht: die Zelle bleibt so breit wie der Text,
## und eine Reihe aus sechs Kacheln schiebt sich aus dem Bild, sobald eine
## Zahl eine Stelle mehr hat. Ein Control gibt die Mindestgroesse seiner
## Kinder nicht weiter — darin darf der Text so breit sein, wie er will.
func beschnitten(inhalt: Control, hoehe: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hoehe)
	# Der Rahmen nimmt die freie Breite. Ohne das bleibt er in einer Zeile mit
	# einem Dehner genau null Pixel breit — und der Text darin unsichtbar.
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inhalt.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(inhalt)
	return c

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
	n.content_margin_left = 20
	n.content_margin_right = 20
	n.content_margin_top = 9
	n.content_margin_bottom = 10
	n.shadow_color = Color(AKZENT.r, AKZENT.g, AKZENT.b, 0.28)
	n.shadow_size = 10
	n.shadow_offset = Vector2(0, 3)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = AKZENT.lightened(0.16)
	h.shadow_color = Color(AKZENT.r, AKZENT.g, AKZENT.b, 0.50)
	h.shadow_size = 16
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = AKZENT_TIEF
	p.shadow_size = 0
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color("#232a3c")
	d.shadow_size = 0
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", box_leer())
	b.add_theme_color_override("font_color", Color("#ffffff"))
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("#ede9fe"))
	b.add_theme_color_override("font_disabled_color", Color("#5f6b83"))
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
	# Ein Schalter ohne Beschriftung ist so hoch wie sein Text — und der ist
	# leer. In der dichten Tabelle der Regeneration waren das elf Pixel
	# Klickflaeche je Zeile; die Layoutpruefung hat sechs davon gemeldet, und
	# getroffen hat man sie nur mit Glueck. Das Kaestchen selbst ist rund
	# vierzehn Pixel breit, also darf die Zeile nicht darunter liegen.
	b.custom_minimum_size = Vector2(b.custom_minimum_size.x, maxf(b.custom_minimum_size.y, 24.0))
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
func zeilen_knopf(index: int, hervorgehoben: bool = false, hoehe: int = 36) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, hoehe)
	b.focus_mode = Control.FOCUS_NONE
	var n := box(lasur(AKZENT, 0.16) if hervorgehoben else Color(1, 1, 1, 0.026), R_KLEIN)
	n.content_margin_left = 10
	n.content_margin_right = 10
	n.content_margin_top = 0
	n.content_margin_bottom = 0
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = lasur(AKZENT, 0.20)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = lasur(AKZENT, 0.28)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", d)
	b.add_theme_stylebox_override("focus", box_leer())
	return b

## Segmentierte Umschaltleiste — ersetzt lose Knopfreihen bei Reitern.
## optionen: Array von {"id":…, "name":…}. rueckruf bekommt die id.
func segmente(optionen: Array, aktiv: String, rueckruf: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	# Der aktive Reiter ist gefuellt, nicht umrandet. Ein Rahmen um den
	# aktiven und nichts um die anderen liest sich als "dieser ist anklickbar,
	# die anderen nicht" — genau verkehrt herum.
	var sb := box(FLAECHE_TIEF, R_KLEIN)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h := hbox(3)
	p.add_child(h)
	for o in optionen:
		var id: String = str((o as Dictionary)["id"])
		var b := Button.new()
		b.text = str((o as Dictionary)["name"])
		b.add_theme_font_size_override("font_size", S_KLEIN)
		b.add_theme_stylebox_override("focus", box_leer())
		var an: bool = id == aktiv
		var n := box(AKZENT if an else Color(0, 0, 0, 0), R_KLEIN - 2)
		n.content_margin_left = 15
		n.content_margin_right = 15
		n.content_margin_top = 6
		n.content_margin_bottom = 7
		var hb := n.duplicate() as StyleBoxFlat
		if not an:
			hb.bg_color = lasur(TEXT, 0.08)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", hb)
		b.add_theme_stylebox_override("pressed", n)
		b.add_theme_color_override("font_color", Color.WHITE if an else TEXT_MATT)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(func(): rueckruf.call(id))
		h.add_child(b)
	return p

## Reiter fuer einen ganzen Bildschirm: eine Leiste, darunter genau ein
## Abschnitt.
##
## Scrollen ist die teuerste Bedienhandlung, die eine Oberflaeche verlangen
## kann — man verliert den Ueberblick, den man sich gerade aufgebaut hat. Wo
## ein Bildschirm mehr zeigen will, als auf den Schirm passt, ist ein Reiter
## fast immer die bessere Antwort als eine laengere Seite: er kostet einen
## Klick und spart das Suchen.
##
## `optionen` ist ein Array von {"id":…, "name":…}. Die Abschnitte holt man
## sich mit feld(id) und fuellt sie wie jede andere Spalte.
func reitergruppe(optionen: Array, start: String = "") -> Reitergruppe:
	var g := Reitergruppe.new()
	g.add_theme_constant_override("separation", A_NORMAL)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g.optionen = optionen
	# Eine Kennung, die es nicht gibt, wuerde jeden Abschnitt ausblenden: der
	# Bildschirm waere leer. Lieber der erste Reiter als keiner.
	g.aktiv = str((optionen[0] as Dictionary)["id"])
	for o in optionen:
		if str((o as Dictionary)["id"]) == start:
			g.aktiv = start
	g.aufbauen()
	return g

class Reitergruppe extends VBoxContainer:
	var optionen: Array = []
	var aktiv: String = ""
	var _leiste_halter: HBoxContainer
	var _felder: Dictionary = {}
	var _rollen: Dictionary = {}
	## Wird gerufen, wenn der Nutzer den Reiter wechselt — fuer Bildschirme,
	## die ihren Inhalt erst beim Anzeigen aufbauen.
	var bei_wechsel: Callable = Callable()

	func aufbauen() -> void:
		_leiste_halter = HBoxContainer.new()
		_leiste_halter.add_theme_constant_override("separation", Stil.A_KLEIN)
		add_child(_leiste_halter)
		for o in optionen:
			var id: String = str((o as Dictionary)["id"])
			# Jeder Abschnitt liegt in einem eigenen Rollbereich. Im Normalfall
			# rollt dort nichts — das ist ja der Zweck der Reiter. Aber ein
			# Abschnitt, der auf einem kleinen Fenster doch einmal nicht passt,
			# darf nicht unerreichbar werden: eine Oberflaeche ohne Scrollen
			# ist gut, eine mit verstecktem Inhalt ist kaputt.
			var rolle := ScrollContainer.new()
			rolle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			rolle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rolle.size_flags_vertical = Control.SIZE_EXPAND_FILL
			rolle.visible = id == aktiv
			add_child(rolle)
			var f := VBoxContainer.new()
			f.add_theme_constant_override("separation", Stil.A_NORMAL)
			f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rolle.add_child(f)
			_felder[id] = f
			_rollen[id] = rolle
		_leiste_bauen()

	func _leiste_bauen() -> void:
		for k in _leiste_halter.get_children():
			_leiste_halter.remove_child(k)
			k.queue_free()
		_leiste_halter.add_child(Stil.segmente(optionen, aktiv, func(id): zeige(str(id))))
		_leiste_halter.add_child(Stil.dehner())

	## Der Abschnitt zu einer Reiter-Kennung.
	func feld(id: String) -> VBoxContainer:
		return _felder.get(id, null) as VBoxContainer

	## Haengt ein Control rechts in die Reiterleiste (Filter, kleine Knoepfe).
	func leistenaktion(steuerung: Control) -> void:
		_leiste_halter.add_child(steuerung)

	func zeige(id: String) -> void:
		if not _felder.has(id):
			return
		aktiv = id
		for k in _rollen.keys():
			(_rollen[k] as Control).visible = str(k) == id
		_leiste_bauen()
		if bei_wechsel.is_valid():
			bei_wechsel.call(id)

## Kleiner Balken mit Beschriftung, z. B. fuer Fitness oder Moral.
func balken(wert: float, maximum: float = 100.0, breite: int = 110, farbe: Variant = null) -> Control:
	var b := BalkenZeichner.new()
	b.wert = wert
	b.maximum = maximum
	b.farbe = farbe if farbe != null else prozent_farbe(wert / maxf(maximum, 0.001) * 100.0)
	b.custom_minimum_size = Vector2(breite, 9)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

## Zeichnet einen schlichten Fortschrittsbalken selbst — kein Theme-Umweg noetig.
class BalkenZeichner extends Control:
	var wert: float = 0.0
	var maximum: float = 100.0
	var farbe: Color = Color.WHITE
	var hintergrund: Color = Color("#1a2234")

	## Gerundete Kapsel statt eckigem Kasten mit Rahmen.
	##
	## Ein Balken mit Umrandung liest sich als Eingabefeld; in einer Tabelle
	## mit vier davon nebeneinander sah eine Zeile aus wie ein Formular. Die
	## Kapsel traegt die Aussage allein ueber ihre Fuellung.
	func _draw() -> void:
		if size.x < 4.0:
			return
		# Der Balken zeichnet immer ein Band fester Hoehe, mittig in der Zelle.
		# Manche Tabellen setzen die Mindestgroesse ihrer Zellen selbst; ohne
		# diese Absicherung bliebe vom Balken nur ein Strich uebrig.
		var h: float = clampf(size.y, 6.0, 9.0)
		var oben: float = maxf((size.y - h) * 0.5, 0.0)
		draw_style_box(Stil.box(hintergrund, Stil.R_RUND),
			Rect2(Vector2(0, oben), Vector2(size.x, h)))
		var t: float = clampf(wert / maxf(maximum, 0.001), 0.0, 1.0)
		if t <= 0.0:
			return
		var b: float = maxf(size.x * t, h)
		draw_style_box(Stil.box(farbe, Stil.R_RUND), Rect2(Vector2(0, oben), Vector2(b, h)))

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
## dicht: engere Zeilen fuer Tabellen, die den ganzen Kader fuehren. Elf Pixel
## Luft je Zeile sind bei achtzehn Zeilen zweihundert Pixel, die dann unten
## fehlen.
func tabelle(spalten: Array, dicht: bool = false) -> GridContainer:
	var g := RasterTabelle.new()
	g.columns = maxi(spalten.size(), 1)
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6 if dicht else 11)
	for s in spalten:
		var l := Label.new()
		l.text = str(s).to_upper()
		l.add_theme_font_size_override("font_size", S_ETIKETT)
		l.add_theme_color_override("font_color", TEXT_SCHWACH)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.add_child(l)
	return g

## Zeichnet die Zeilenbaender und die Linie unter dem Tabellenkopf hinter den
## Zellen. So bekommt jede Tabelle im Spiel dasselbe Bild, ohne dass ein
## Bildschirm etwas tun muss.
##
## Die Baender sind gerundet und liegen nicht mehr in jeder zweiten Zeile,
## sondern in jeder: ein durchgehend ruhiger Grund liest sich besser als ein
## Zebra, sobald die Zeilen hoch genug sind. Zonen — Europa, Abstieg — bekommen
## eine farbige Kante links statt einer eingefaerbten Platzziffer.
class RasterTabelle extends GridContainer:
	var hervorgehoben: Array = []
	var zonen: Dictionary = {}

	func _ready() -> void:
		# Erst nach dem Sortieren zeichnen: vorher stehen die Kindpositionen
		# noch auf null und alle Zeilenbaender lägen uebereinander am oberen Rand.
		sort_children.connect(queue_redraw)
		resized.connect(queue_redraw)

	func hebe_zeile(zeile: int) -> void:
		if not hervorgehoben.has(zeile):
			hervorgehoben.append(zeile)
			queue_redraw()

	## Farbige Kante am linken Rand einer Zeile — fuer Qualifikations- und
	## Abstiegszonen.
	func setze_zone(zeile: int, farbe: Color) -> void:
		zonen[zeile] = farbe
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
			var r := Rect2(Vector2(-8.0, oben - luecke * 0.42), Vector2(size.x + 16.0, unten - oben + luecke * 0.84))
			if z == 0:
				draw_line(Vector2(-8.0, unten + luecke * 0.46), Vector2(size.x + 8.0, unten + luecke * 0.46),
					Stil.RAND, 1.0)
				continue
			if hervorgehoben.has(z - 1):
				draw_style_box(Stil.box(Stil.lasur(Stil.AKZENT, 0.16), Stil.R_KLEIN), r)
			else:
				draw_style_box(Stil.box(Color(1, 1, 1, 0.026), Stil.R_KLEIN), r)
			if zonen.has(z - 1):
				var kante := Rect2(r.position + Vector2(0, 3.0), Vector2(3.0, r.size.y - 6.0))
				draw_style_box(Stil.box(zonen[z - 1] as Color, Stil.R_RUND), kante)

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
