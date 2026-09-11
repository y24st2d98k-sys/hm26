class_name Wappen
extends Control
## Zeichnet ein Vereinswappen vollstaendig prozedural — Form, Muster und Symbol
## stammen aus drei Zahlen im Vereinsdatensatz. Es werden keine Bilddateien benutzt.

var wappen: Dictionary = {"form": 0, "muster": 0, "symbol": 0, "a": Color("#c8342f"), "b": Color("#f4f1e8")}
var mit_rand: bool = true

func setze(w: Dictionary) -> void:
	if w != null and not w.is_empty():
		wappen = w
	queue_redraw()

static func fuer_verein(cid: String, groesse: float = 34.0) -> Wappen:
	var w := Wappen.new()
	w.custom_minimum_size = Vector2(groesse, groesse)
	w.setze(Welt.verein(cid).get("wappen", {}))
	return w

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s <= 6.0:
		return
	var versatz := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var a: Color = wappen.get("a", Color("#c8342f"))
	var b: Color = wappen.get("b", Color("#f4f1e8"))
	var schild := _form(int(wappen.get("form", 0)), s, versatz)
	if schild.size() < 3:
		return
	draw_colored_polygon(schild, a)
	for teil in _muster(int(wappen.get("muster", 0)), schild, s, versatz):
		if (teil as PackedVector2Array).size() >= 3:
			draw_colored_polygon(teil, b)
	_symbol(int(wappen.get("symbol", 0)), s, versatz, b if int(wappen.get("muster", 0)) == 0 else a)
	if mit_rand:
		var geschlossen := schild.duplicate()
		geschlossen.append(schild[0])
		draw_polyline(geschlossen, Color(0, 0, 0, 0.45), maxf(s * 0.035, 1.0), true)

func _form(form: int, s: float, o: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	match form:
		1:  # Kreis
			for i in range(24):
				var w: float = TAU * float(i) / 24.0
				p.append(o + Vector2(0.5 + 0.46 * cos(w), 0.5 + 0.46 * sin(w)) * s)
		2:  # Rechteck mit abgeschraegten Ecken
			p = PackedVector2Array([Vector2(0.12, 0.06), Vector2(0.88, 0.06), Vector2(0.94, 0.16),
				Vector2(0.94, 0.86), Vector2(0.88, 0.94), Vector2(0.12, 0.94), Vector2(0.06, 0.86), Vector2(0.06, 0.16)])
			for i in range(p.size()):
				p[i] = o + p[i] * s
		3:  # Wimpel
			p = PackedVector2Array([Vector2(0.08, 0.06), Vector2(0.92, 0.06), Vector2(0.92, 0.62),
				Vector2(0.50, 0.95), Vector2(0.08, 0.62)])
			for i in range(p.size()):
				p[i] = o + p[i] * s
		4:  # Sechseck
			for i in range(6):
				var w2: float = TAU * float(i) / 6.0 - PI / 2.0
				p.append(o + Vector2(0.5 + 0.47 * cos(w2), 0.5 + 0.47 * sin(w2)) * s)
		_:  # Klassisches Schild
			p = PackedVector2Array([Vector2(0.08, 0.08), Vector2(0.92, 0.08), Vector2(0.92, 0.55),
				Vector2(0.80, 0.80), Vector2(0.50, 0.96), Vector2(0.20, 0.80), Vector2(0.08, 0.55)])
			for i in range(p.size()):
				p[i] = o + p[i] * s
	return p

func _muster(muster: int, schild: PackedVector2Array, s: float, o: Vector2) -> Array:
	var flaechen: Array = []
	match muster:
		1:  # senkrechter Balken
			flaechen.append(_rechteck(0.40, 0.0, 0.20, 1.0, s, o))
		2:  # waagerechte Baender
			flaechen.append(_rechteck(0.0, 0.22, 1.0, 0.16, s, o))
			flaechen.append(_rechteck(0.0, 0.56, 1.0, 0.16, s, o))
		3:  # Schraegteilung
			flaechen.append(PackedVector2Array([o + Vector2(0, 0) * s, o + Vector2(1, 0) * s, o + Vector2(0, 1) * s]))
		4:  # Winkel
			flaechen.append(PackedVector2Array([o + Vector2(0.5, 0.18) * s, o + Vector2(1.0, 0.62) * s,
				o + Vector2(1.0, 0.86) * s, o + Vector2(0.5, 0.42) * s, o + Vector2(0.0, 0.86) * s, o + Vector2(0.0, 0.62) * s]))
		5:  # Viertelung
			flaechen.append(_rechteck(0.0, 0.0, 0.5, 0.5, s, o))
			flaechen.append(_rechteck(0.5, 0.5, 0.5, 0.5, s, o))
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
