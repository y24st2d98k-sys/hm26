class_name Wappen
extends Control
## Zeichnet ein Vereinswappen vollstaendig prozedural — Form, Teilung, Symbol und
## Kuerzel stammen aus dem Vereinsdatensatz. Es werden keine Bilddateien benutzt.
##
## Ein Wappen besteht aus vier Schichten:
##   1. Grundform (Schild, Kreis, Wimpel, …) in der ersten Vereinsfarbe
##   2. Heraldische Teilung (Streifen, Baender, Winkel, …) in der zweiten Farbe
##   3. Symbol oder Kuerzel in der Kontrastfarbe
##   4. Rand, Innenkante und ein feiner Lichtsaum fuer Tiefe
##
## Die echten Vereine bekommen ihre tatsaechlichen Vereinsfarben und ihr Kuerzel;
## damit ist jedes Wappen auf den ersten Blick dem richtigen Verein zuzuordnen,
## ohne dass eine einzige fremde Grafik im Projekt liegt.

const STANDARD := {
	"form": 0, "muster": 0, "symbol": 0, "text": "",
	"a": Color("#c8342f"), "b": Color("#f4f1e8"),
}

var wappen: Dictionary = STANDARD.duplicate()
var mit_rand: bool = true

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setze(w: Dictionary) -> void:
	if w != null and not w.is_empty():
		wappen = w
	queue_redraw()

static func fuer_verein(cid: String, groesse: float = 34.0) -> Wappen:
	var w := Wappen.new()
	w.custom_minimum_size = Vector2(groesse, groesse)
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	w.setze(Welt.verein(cid).get("wappen", {}))
	return w

## Wappen frei aus Farben und Kuerzel — fuer Vorschauen ohne Vereinsdatensatz.
static func aus_werten(form: int, muster: int, symbol: int, a: Color, b: Color,
		kuerzel: String = "", groesse: float = 34.0) -> Wappen:
	var w := Wappen.new()
	w.custom_minimum_size = Vector2(groesse, groesse)
	w.setze({"form": form, "muster": muster, "symbol": symbol, "a": a, "b": b, "text": kuerzel})
	return w

# ------------------------------------------------------------- Zeichnen ---

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s <= 6.0:
		return
	var versatz := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var a: Color = wappen.get("a", STANDARD["a"])
	var b: Color = wappen.get("b", STANDARD["b"])
	var muster := int(wappen.get("muster", 0))
	var schild := _form(int(wappen.get("form", 0)), s, versatz)
	if schild.size() < 3:
		return

	# 1 — Grundflaeche, unten leicht abgedunkelt fuer Volumen
	draw_colored_polygon(schild, a)
	_schattierung(schild, s, versatz)

	# 2 — Teilung
	for teil in _muster(muster, schild, s, versatz):
		if (teil as PackedVector2Array).size() >= 3:
			draw_colored_polygon(teil, b)

	# 3 — Kuerzel schlaegt Symbol: es benennt den Verein eindeutig
	var kuerzel: String = str(wappen.get("text", ""))
	var vordergrund: Color = _kontrast(a, b, muster)
	if kuerzel != "" and s >= 22.0:
		_kuerzel_zeichnen(kuerzel, s, versatz, vordergrund, muster)
	else:
		_symbol(int(wappen.get("symbol", 0)), s, versatz, vordergrund)

	# 4 — Kanten
	if mit_rand:
		var geschlossen := schild.duplicate()
		geschlossen.append(schild[0])
		draw_polyline(geschlossen, Color(0, 0, 0, 0.5), maxf(s * 0.045, 1.0), true)
		if s >= 26.0:
			draw_polyline(_schrumpfen(schild, s * 0.055), Color(1, 1, 1, 0.16), maxf(s * 0.02, 1.0), true)

## Welche Farbe sich vor dem gewaehlten Muster durchsetzt.
func _kontrast(a: Color, b: Color, muster: int) -> Color:
	var traeger: Color = a if muster == 0 else b
	var gegen: Color = b if muster == 0 else a
	# Symbol und Schrift liegen mittig — dort dominiert bei den meisten
	# Teilungen die zweite Farbe. Wir waehlen die besser lesbare.
	if absf(traeger.get_luminance() - gegen.get_luminance()) > 0.22:
		return gegen
	return Color("#f7f9fc") if traeger.get_luminance() < 0.5 else Color("#10151d")

## Sanfter Verlauf von oben hell nach unten dunkel, in zwei Baendern.
func _schattierung(schild: PackedVector2Array, s: float, o: Vector2) -> void:
	var unten := _rechteck(0.0, 0.55, 1.0, 0.45, s, o)
	for teil in Geometry2D.intersect_polygons(schild, unten):
		if (teil as PackedVector2Array).size() >= 3:
			draw_colored_polygon(teil, Color(0, 0, 0, 0.10))
	var oben := _rechteck(0.0, 0.0, 1.0, 0.22, s, o)
	for teil2 in Geometry2D.intersect_polygons(schild, oben):
		if (teil2 as PackedVector2Array).size() >= 3:
			draw_colored_polygon(teil2, Color(1, 1, 1, 0.07))

## Polygon zum Mittelpunkt hin verkleinern — fuer die Innenkante.
func _schrumpfen(p: PackedVector2Array, abstand: float) -> PackedVector2Array:
	var mitte := Vector2.ZERO
	for punkt in p:
		mitte += punkt
	mitte /= float(p.size())
	var aus := PackedVector2Array()
	for punkt2 in p:
		var richtung: Vector2 = (mitte - punkt2)
		var laenge: float = richtung.length()
		aus.append(punkt2 + richtung / maxf(laenge, 0.001) * minf(abstand, laenge * 0.5))
	if aus.size() > 1:
		aus.append(aus[0])
	return aus

func _form(form: int, s: float, o: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	match form:
		1:  # Kreis
			for i in range(28):
				var w: float = TAU * float(i) / 28.0
				p.append(o + Vector2(0.5 + 0.47 * cos(w), 0.5 + 0.47 * sin(w)) * s)
		2:  # Rechteck mit abgeschraegten Ecken
			p = PackedVector2Array([Vector2(0.12, 0.06), Vector2(0.88, 0.06), Vector2(0.94, 0.16),
				Vector2(0.94, 0.86), Vector2(0.88, 0.94), Vector2(0.12, 0.94), Vector2(0.06, 0.86), Vector2(0.06, 0.16)])
			p = _skalieren(p, s, o)
		3:  # Wimpel
			p = _skalieren(PackedVector2Array([Vector2(0.08, 0.06), Vector2(0.92, 0.06),
				Vector2(0.92, 0.62), Vector2(0.50, 0.95), Vector2(0.08, 0.62)]), s, o)
		4:  # Sechseck stehend
			for i in range(6):
				var w2: float = TAU * float(i) / 6.0 - PI / 2.0
				p.append(o + Vector2(0.5 + 0.48 * cos(w2), 0.5 + 0.48 * sin(w2)) * s)
		5:  # Rundschild — oben gerade, unten halbrund
			p.append(o + Vector2(0.10, 0.08) * s)
			p.append(o + Vector2(0.90, 0.08) * s)
			p.append(o + Vector2(0.90, 0.48) * s)
			for i in range(13):
				var t: float = float(i) / 12.0
				var w3: float = lerpf(0.0, PI, t)
				p.append(o + Vector2(0.5 + 0.40 * cos(w3), 0.48 + 0.46 * sin(w3)) * s)
			p.append(o + Vector2(0.10, 0.48) * s)
		6:  # Raute
			p = _skalieren(PackedVector2Array([Vector2(0.50, 0.03), Vector2(0.95, 0.50),
				Vector2(0.50, 0.97), Vector2(0.05, 0.50)]), s, o)
		7:  # Banner mit Schwalbenschwanz
			p = _skalieren(PackedVector2Array([Vector2(0.07, 0.12), Vector2(0.93, 0.12),
				Vector2(0.93, 0.88), Vector2(0.50, 0.68), Vector2(0.07, 0.88)]), s, o)
		_:  # Klassisches Schild
			p = _skalieren(PackedVector2Array([Vector2(0.08, 0.07), Vector2(0.92, 0.07),
				Vector2(0.92, 0.54), Vector2(0.80, 0.80), Vector2(0.50, 0.96),
				Vector2(0.20, 0.80), Vector2(0.08, 0.54)]), s, o)
	return p

func _skalieren(p: PackedVector2Array, s: float, o: Vector2) -> PackedVector2Array:
	var aus := PackedVector2Array()
	for punkt in p:
		aus.append(o + punkt * s)
	return aus

func _muster(muster: int, schild: PackedVector2Array, s: float, o: Vector2) -> Array:
	var flaechen: Array = []
	match muster:
		1:  # senkrechter Pfahl
			flaechen.append(_rechteck(0.40, 0.0, 0.20, 1.0, s, o))
		2:  # zwei waagerechte Baender
			flaechen.append(_rechteck(0.0, 0.20, 1.0, 0.15, s, o))
			flaechen.append(_rechteck(0.0, 0.55, 1.0, 0.15, s, o))
		3:  # Schraegteilung
			flaechen.append(PackedVector2Array([o, o + Vector2(1, 0) * s, o + Vector2(0, 1) * s]))
		4:  # Winkel (Sparren)
			flaechen.append(_skalieren(PackedVector2Array([Vector2(0.5, 0.16), Vector2(1.0, 0.60),
				Vector2(1.0, 0.84), Vector2(0.5, 0.40), Vector2(0.0, 0.84), Vector2(0.0, 0.60)]), s, o))
		5:  # Viertelung
			flaechen.append(_rechteck(0.0, 0.0, 0.5, 0.5, s, o))
			flaechen.append(_rechteck(0.5, 0.5, 0.5, 0.5, s, o))
		6:  # vier senkrechte Streifen
			for i in range(4):
				flaechen.append(_rechteck(0.06 + float(i) * 0.24, 0.0, 0.12, 1.0, s, o))
		7:  # Kopfband
			flaechen.append(_rechteck(0.0, 0.0, 1.0, 0.30, s, o))
		8:  # Ringband um die Mitte
			flaechen.append(_rechteck(0.0, 0.38, 1.0, 0.24, s, o))
		9:  # gespalten (linke Haelfte)
			flaechen.append(_rechteck(0.0, 0.0, 0.5, 1.0, s, o))
		_:
			return []
	var ergebnis: Array = []
	for f in flaechen:
		for teil in Geometry2D.intersect_polygons(schild, f):
			ergebnis.append(teil)
	return ergebnis

func _rechteck(x: float, y: float, b: float, h: float, s: float, o: Vector2) -> PackedVector2Array:
	return PackedVector2Array([o + Vector2(x, y) * s, o + Vector2(x + b, y) * s,
		o + Vector2(x + b, y + h) * s, o + Vector2(x, y + h) * s])

## Vereinskuerzel mittig ins Wappen setzen, mit Schattenkante fuer Lesbarkeit.
func _kuerzel_zeichnen(kuerzel: String, s: float, o: Vector2, farbe: Color, muster: int) -> void:
	var txt: String = kuerzel.substr(0, 3).to_upper()
	var schrift := ThemeDB.fallback_font
	var groesse: int = int(s * (0.40 if txt.length() <= 2 else 0.30))
	var breite: float = schrift.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
	var mitte: Vector2 = o + Vector2(0.5, 0.50) * s
	# Bei Teilungen, die die Mitte durchschneiden, eine ruhige Flaeche unterlegen
	if muster in [1, 4, 8]:
		draw_circle(mitte, s * 0.30, Color(0, 0, 0, 0.22))
	var stelle: Vector2 = mitte + Vector2(-breite * 0.5, groesse * 0.36)
	draw_string(schrift, stelle + Vector2(0, maxf(s * 0.02, 1.0)), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Color(0, 0, 0, 0.35))
	draw_string(schrift, stelle, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, farbe)

func _symbol(symbol: int, s: float, o: Vector2, farbe: Color) -> void:
	var m: Vector2 = o + Vector2(0.5, 0.46) * s
	var r: float = s * 0.19
	match symbol:
		0:
			draw_circle(m, r, farbe)
		1:  # Stern
			var punkte := PackedVector2Array()
			for i in range(10):
				var radius: float = r if i % 2 == 0 else r * 0.45
				var w: float = TAU * float(i) / 10.0 - PI / 2.0
				punkte.append(m + Vector2(cos(w), sin(w)) * radius)
			_polygon(punkte, farbe)
		2:  # Blitz
			_polygon(PackedVector2Array([
				m + Vector2(0.1, -1.0) * r, m + Vector2(0.85, -0.1) * r, m + Vector2(0.25, -0.05) * r,
				m + Vector2(0.6, 1.0) * r, m + Vector2(-0.8, 0.05) * r, m + Vector2(-0.1, 0.0) * r]), farbe)
		3:  # Handball
			draw_circle(m, r, farbe)
			draw_arc(m, r * 0.62, 0.4, 2.6, 10, Color(0, 0, 0, 0.5), maxf(s * 0.02, 1.0))
			draw_arc(m, r * 0.62, 3.6, 5.8, 10, Color(0, 0, 0, 0.5), maxf(s * 0.02, 1.0))
		4:  # Doppelwinkel
			for k in range(2):
				var y: float = -0.3 + float(k) * 0.6
				draw_polyline(PackedVector2Array([m + Vector2(-0.9, y + 0.3) * r, m + Vector2(0.0, y - 0.3) * r,
					m + Vector2(0.9, y + 0.3) * r]), farbe, maxf(s * 0.045, 1.5), true)
		5:  # Kreuz
			draw_rect(Rect2(m - Vector2(r * 0.22, r), Vector2(r * 0.44, r * 2.0)), farbe)
			draw_rect(Rect2(m - Vector2(r, r * 0.22), Vector2(r * 2.0, r * 0.44)), farbe)
		6:  # Raute
			_polygon(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r * 0.75, 0),
				m + Vector2(0, r), m + Vector2(-r * 0.75, 0)]), farbe)
		_:  # Ring
			draw_arc(m, r * 0.8, 0.0, TAU, 22, farbe, maxf(s * 0.07, 2.0))

## Zeichnet ein Polygon nur, wenn es gueltig ist (verhindert Triangulationsfehler).
func _polygon(punkte: PackedVector2Array, farbe: Color) -> void:
	if punkte.size() >= 3:
		draw_colored_polygon(punkte, farbe)
