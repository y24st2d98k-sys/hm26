class_name Radar
extends Control
## Netzdiagramm der Spielerstärken. Sechs Achsen, jede ein Mittel aus mehreren
## Attributen — so sieht man ein Spielerprofil in einem Blick statt in einer
## Liste aus 29 Zahlen.
##
## Zwei Spieler lassen sich übereinanderlegen; damit wird aus dem Diagramm ein
## Vergleich, ohne dass eine zweite Ansicht nötig wäre.

## Achsen für Feldspieler: Beschriftung -> Attribute, die einfließen.
const ACHSEN_FELD := [
	{"name": "Wurf", "attr": ["wurfkraft", "wurfpraezision", "siebenmeter"]},
	{"name": "Technik", "attr": ["taeuschung", "passspiel", "ballsicherheit"]},
	{"name": "Athletik", "attr": ["tempo", "sprungkraft", "physis", "ausdauer", "beweglichkeit"]},
	{"name": "Abwehr", "attr": ["block", "deckungsarbeit", "zweikampf", "antizipation"]},
	{"name": "Kopf", "attr": ["uebersicht", "entscheidung", "nervenstaerke"]},
	{"name": "Einsatz", "attr": ["fuehrung", "arbeitseinsatz", "teamgeist"]},
]
## Achsen für Torhüter.
const ACHSEN_TW := [
	{"name": "Reflexe", "attr": ["reflexe"]},
	{"name": "Stellung", "attr": ["tw_stellung", "antizipation"]},
	{"name": "Rückraum", "attr": ["rueckraumabwehr"]},
	{"name": "Flügel", "attr": ["fluegelabwehr"]},
	{"name": "Eins gegen Eins", "attr": ["eins_gegen_eins", "siebenmeterabwehr"]},
	{"name": "Ausstrahlung", "attr": ["ausstrahlung", "anspiel"]},
]

var werte_a: Array = []
var werte_b: Array = []
var achsen: Array = []
var farbe_a: Color = Color("#ffb340")
var farbe_b: Color = Color("#4fa8f5")
var name_a: String = ""
var name_b: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(260, 240)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Radar für einen Spieler, optional mit einem zweiten zum Vergleich.
static func fuer(sp: Dictionary, vergleich: Dictionary = {}, groesse: float = 260.0) -> Radar:
	var r := Radar.new()
	r.custom_minimum_size = Vector2(groesse, groesse * 0.92)
	r.achsen = ACHSEN_TW if bool(sp.get("ist_torwart", false)) else ACHSEN_FELD
	r.werte_a = _mittel(sp, r.achsen)
	r.name_a = Spielerfabrik.kurz_name(sp)
	if not vergleich.is_empty():
		r.werte_b = _mittel(vergleich, r.achsen)
		r.name_b = Spielerfabrik.kurz_name(vergleich)
	return r

## Achsenwerte 0..20 als Mittel der zugehörigen Attribute.
static func _mittel(sp: Dictionary, achsen_liste: Array) -> Array:
	var attr: Dictionary = sp.get("attr", {})
	var aus: Array = []
	for a in achsen_liste:
		var summe := 0.0
		var n := 0
		for schluessel in (a as Dictionary)["attr"]:
			summe += float(attr.get(str(schluessel), 1.0))
			n += 1
		aus.append(summe / maxf(float(n), 1.0))
	return aus

func _draw() -> void:
	var n: int = achsen.size()
	if n < 3 or size.x < 80.0:
		return
	var m := Vector2(size.x * 0.5, size.y * 0.52)
	var radius: float = minf(size.x, size.y) * 0.36
	var schrift := ThemeDB.fallback_font

	# Netz: vier Ringe und die Achsen
	for stufe in [0.25, 0.5, 0.75, 1.0]:
		var ring := PackedVector2Array()
		for i in range(n):
			ring.append(m + _richtung(i, n) * radius * stufe)
		ring.append(ring[0])
		draw_polyline(ring, Color(1, 1, 1, 0.10 if stufe < 1.0 else 0.20), 1.0, true)
	for i in range(n):
		draw_line(m, m + _richtung(i, n) * radius, Color(1, 1, 1, 0.08), 1.0)

	# Erst beide Fuellungen, dann beide Umrisse — sonst verschwindet der
	# zweite Spieler unter der Flaeche des ersten.
	if not werte_b.is_empty():
		_fuellung(werte_b, m, radius, n, farbe_b)
	if not werte_a.is_empty():
		_fuellung(werte_a, m, radius, n, farbe_a)
	if not werte_b.is_empty():
		_umriss(werte_b, m, radius, n, farbe_b)
	if not werte_a.is_empty():
		_umriss(werte_a, m, radius, n, farbe_a)

	# Beschriftung der Achsen ausserhalb des Netzes
	for i in range(n):
		var richtung := _richtung(i, n)
		var text := str((achsen[i] as Dictionary)["name"])
		var breite: float = schrift.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Stil.S_ETIKETT).x
		var p: Vector2 = m + richtung * (radius + 14.0)
		p.x -= breite * (0.5 - richtung.x * 0.42)
		p.y += Stil.S_ETIKETT * 0.36 + richtung.y * 3.0
		p.x = clampf(p.x, 1.0, maxf(size.x - breite - 1.0, 1.0))
		draw_string(schrift, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Stil.S_ETIKETT, Stil.TEXT_MATT)

func _richtung(i: int, n: int) -> Vector2:
	var w: float = -PI / 2.0 + TAU * float(i) / float(n)
	return Vector2(cos(w), sin(w))

func _punkte(werte: Array, m: Vector2, radius: float, n: int) -> PackedVector2Array:
	var punkte := PackedVector2Array()
	for i in range(n):
		var anteil: float = clampf(float(werte[i]) / 20.0, 0.04, 1.0)
		punkte.append(m + _richtung(i, n) * radius * anteil)
	return punkte

func _fuellung(werte: Array, m: Vector2, radius: float, n: int, farbe: Color) -> void:
	var punkte := _punkte(werte, m, radius, n)
	if punkte.size() >= 3:
		draw_colored_polygon(punkte, Color(farbe.r, farbe.g, farbe.b, 0.18))

func _umriss(werte: Array, m: Vector2, radius: float, n: int, farbe: Color) -> void:
	var punkte := _punkte(werte, m, radius, n)
	if punkte.size() < 3:
		return
	var rand := punkte.duplicate()
	rand.append(punkte[0])
	draw_polyline(rand, farbe, 2.0, true)
	for p in punkte:
		draw_circle(p, 2.8, farbe)
