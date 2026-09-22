class_name Symbol
extends Control
## Gezeichnete Symbole. Jedes Icon entsteht aus Linien, Kreisen und Polygonen in
## einem 0..1-Raum und wird auf die Knotengroesse skaliert — keine Bilddateien,
## keine Symbolschrift. So bleibt der Satz bei jeder Groesse scharf.

var name_id: String = "punkt"
var farbe: Color = Color("#93a3b5")
var staerke: float = 1.6

static func neu(id: String, groesse: float = 16.0, f: Variant = null) -> Symbol:
	var s := Symbol.new()
	s.name_id = id
	s.custom_minimum_size = Vector2(groesse, groesse)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if f != null:
		s.farbe = f
	return s

func setze_farbe(f: Color) -> void:
	farbe = f
	queue_redraw()

# ------------------------------------------------------------- Zeichnen ---

var _s: float = 16.0
var _o: Vector2 = Vector2.ZERO

func _draw() -> void:
	_s = minf(size.x, size.y)
	if _s < 6.0:
		return
	_o = (size - Vector2(_s, _s)) * 0.5
	staerke = maxf(_s * 0.085, 1.2)
	match name_id:
		"buero": _buero()
		"kader": _kader()
		"taktik": _taktik()
		"training": _training()
		"kabine": _kabine()
		"jugend": _jugend()
		"spielplan": _spielplan()
		"tabellen": _tabellen()
		"pokale": _pokal()
		"national": _flagge()
		"statistik": _statistik()
		"analyse": _analyse()
		"transfer": _transfer()
		"scouting": _lupe()
		"finanzen": _muenze()
		"infrastruktur": _halle()
		"halle": _publikum()
		"personal": _ausweis()
		"vorstand": _stuhl()
		"karriere": _medaille()
		"medien": _mikrofon()
		"chronik": _buch()
		"nachrichten": _brief()
		"system": _diskette()
		"daten": _datenbank()
		"glocke": _glocke()
		"pfeil_rechts": _pfeil_rechts()
		"pfeil_links": _pfeil_links()
		"zahnrad": _zahnrad()
		"frage": _frage()
		"doppelpfeil": _doppelpfeil()
		"pause": _pause()
		"kreuz": _kreuz()
		"haken": _haken()
		"warnung": _warnung()
		"uhr": _uhr()
		"pfeife": _pfeife()
		"ball": _ball()
		_: draw_circle(_p(0.5, 0.5), _s * 0.16, farbe)

# Umrechnung 0..1 -> Pixel
func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s

func _linie(punkte: Array, geschlossen: bool = false, dicke: float = -1.0) -> void:
	var pv := PackedVector2Array()
	for p in punkte:
		pv.append(_p((p as Vector2).x, (p as Vector2).y))
	if geschlossen and pv.size() > 1:
		pv.append(pv[0])
	if pv.size() >= 2:
		draw_polyline(pv, farbe, dicke if dicke > 0.0 else staerke, true)

func _flaeche(punkte: Array, f: Variant = null) -> void:
	var pv := PackedVector2Array()
	for p in punkte:
		pv.append(_p((p as Vector2).x, (p as Vector2).y))
	if pv.size() >= 3:
		draw_colored_polygon(pv, f if f != null else farbe)

func _kasten(x: float, y: float, b: float, h: float, gefuellt: bool = false) -> void:
	var r := Rect2(_p(x, y), Vector2(b, h) * _s)
	if gefuellt:
		draw_rect(r, farbe, true)
	else:
		draw_rect(r, farbe, false, staerke)

func _kreis(x: float, y: float, r: float, gefuellt: bool = false) -> void:
	if gefuellt:
		draw_circle(_p(x, y), r * _s, farbe)
	else:
		draw_arc(_p(x, y), r * _s, 0.0, TAU, 24, farbe, staerke, true)

# ------------------------------------------------------------- Die Icons ---

func _buero() -> void:  # Aktenkoffer
	_kasten(0.12, 0.34, 0.76, 0.50)
	_linie([Vector2(0.36, 0.34), Vector2(0.36, 0.20), Vector2(0.64, 0.20), Vector2(0.64, 0.34)])
	_linie([Vector2(0.12, 0.56), Vector2(0.88, 0.56)])

func _kader() -> void:  # Drei Koepfe
	_kreis(0.32, 0.34, 0.14)
	_linie([Vector2(0.12, 0.82), Vector2(0.14, 0.62), Vector2(0.50, 0.62), Vector2(0.52, 0.82)])
	_kreis(0.70, 0.36, 0.11)
	_linie([Vector2(0.56, 0.82), Vector2(0.58, 0.66), Vector2(0.86, 0.66), Vector2(0.88, 0.82)])

func _taktik() -> void:  # Taktiktafel mit Zug
	_kasten(0.12, 0.14, 0.76, 0.72)
	_kreis(0.32, 0.62, 0.07, true)
	_kreis(0.68, 0.34, 0.07, true)
	_linie([Vector2(0.36, 0.58), Vector2(0.50, 0.40), Vector2(0.63, 0.37)])

func _training() -> void:  # Hantel
	_linie([Vector2(0.22, 0.50), Vector2(0.78, 0.50)], false, staerke * 1.3)
	_kasten(0.10, 0.34, 0.12, 0.32, true)
	_kasten(0.78, 0.34, 0.12, 0.32, true)

func _kabine() -> void:  # Sprechblase
	_linie([Vector2(0.12, 0.20), Vector2(0.88, 0.20), Vector2(0.88, 0.66),
		Vector2(0.44, 0.66), Vector2(0.26, 0.84), Vector2(0.28, 0.66), Vector2(0.12, 0.66)], true)
	_kreis(0.36, 0.43, 0.045, true)
	_kreis(0.50, 0.43, 0.045, true)
	_kreis(0.64, 0.43, 0.045, true)

func _jugend() -> void:  # Spross
	_linie([Vector2(0.50, 0.88), Vector2(0.50, 0.44)])
	_linie([Vector2(0.50, 0.56), Vector2(0.24, 0.44), Vector2(0.28, 0.24), Vector2(0.50, 0.38)], true)
	_linie([Vector2(0.50, 0.46), Vector2(0.76, 0.34), Vector2(0.74, 0.16), Vector2(0.50, 0.30)], true)

func _spielplan() -> void:  # Kalender
	_kasten(0.12, 0.22, 0.76, 0.64)
	_linie([Vector2(0.12, 0.40), Vector2(0.88, 0.40)])
	_linie([Vector2(0.30, 0.12), Vector2(0.30, 0.28)])
	_linie([Vector2(0.70, 0.12), Vector2(0.70, 0.28)])
	_kreis(0.34, 0.60, 0.055, true)
	_kreis(0.56, 0.60, 0.055, true)

func _tabellen() -> void:  # Zeilenliste
	for i in range(3):
		var y: float = 0.26 + float(i) * 0.24
		_kreis(0.18, y, 0.055, true)
		_linie([Vector2(0.34, y), Vector2(0.86, y)], false, staerke * 0.9)

func _pokal() -> void:
	_linie([Vector2(0.30, 0.16), Vector2(0.70, 0.16), Vector2(0.66, 0.50),
		Vector2(0.50, 0.60), Vector2(0.34, 0.50)], true)
	draw_arc(_p(0.30, 0.26), 0.12 * _s, PI * 0.5, PI * 1.5, 12, farbe, staerke, true)
	draw_arc(_p(0.70, 0.26), 0.12 * _s, -PI * 0.5, PI * 0.5, 12, farbe, staerke, true)
	_linie([Vector2(0.50, 0.60), Vector2(0.50, 0.74)])
	_linie([Vector2(0.32, 0.84), Vector2(0.68, 0.84)], false, staerke * 1.4)

func _flagge() -> void:
	_linie([Vector2(0.24, 0.12), Vector2(0.24, 0.90)])
	_linie([Vector2(0.24, 0.16), Vector2(0.82, 0.24), Vector2(0.82, 0.56), Vector2(0.24, 0.48)], true)

func _statistik() -> void:
	_linie([Vector2(0.14, 0.16), Vector2(0.14, 0.86), Vector2(0.88, 0.86)])
	_kasten(0.26, 0.56, 0.13, 0.30, true)
	_kasten(0.46, 0.36, 0.13, 0.50, true)
	_kasten(0.66, 0.22, 0.13, 0.64, true)

## Eine Kurve mit Messpunkten — Auswertung statt Momentaufnahme.
func _analyse() -> void:
	_linie([Vector2(0.14, 0.16), Vector2(0.14, 0.86), Vector2(0.88, 0.86)])
	_linie([Vector2(0.24, 0.68), Vector2(0.42, 0.44), Vector2(0.58, 0.58), Vector2(0.82, 0.26)])
	_kreis(0.42, 0.44, 0.055)
	_kreis(0.82, 0.26, 0.055)

func _transfer() -> void:
	_linie([Vector2(0.14, 0.36), Vector2(0.80, 0.36)])
	_linie([Vector2(0.64, 0.20), Vector2(0.82, 0.36), Vector2(0.64, 0.52)])
	_linie([Vector2(0.86, 0.66), Vector2(0.20, 0.66)])
	_linie([Vector2(0.36, 0.50), Vector2(0.18, 0.66), Vector2(0.36, 0.82)])

func _lupe() -> void:
	_kreis(0.44, 0.42, 0.26)
	_linie([Vector2(0.64, 0.62), Vector2(0.88, 0.88)], false, staerke * 1.2)

func _muenze() -> void:
	_kreis(0.38, 0.40, 0.24)
	_kreis(0.60, 0.60, 0.24)
	_linie([Vector2(0.60, 0.48), Vector2(0.60, 0.72)], false, staerke * 0.9)

func _halle() -> void:
	_linie([Vector2(0.08, 0.84), Vector2(0.92, 0.84)])
	_linie([Vector2(0.14, 0.84), Vector2(0.14, 0.48), Vector2(0.50, 0.22),
		Vector2(0.86, 0.48), Vector2(0.86, 0.84)])
	_kasten(0.40, 0.58, 0.20, 0.26)

func _publikum() -> void:  # Tribuene mit Koepfen und erhobenen Armen
	# Ansteigende Reihen
	_linie([Vector2(0.08, 0.86), Vector2(0.30, 0.86), Vector2(0.30, 0.70),
		Vector2(0.56, 0.70), Vector2(0.56, 0.54), Vector2(0.92, 0.54)])
	# Drei Zuschauer, der vordere mit erhobenen Armen
	_kreis(0.19, 0.72, 0.075)
	_kreis(0.43, 0.56, 0.075)
	_kreis(0.72, 0.40, 0.075)
	_linie([Vector2(0.63, 0.30), Vector2(0.67, 0.42)], false, staerke * 0.9)
	_linie([Vector2(0.81, 0.30), Vector2(0.77, 0.42)], false, staerke * 0.9)

func _ausweis() -> void:
	_kasten(0.10, 0.24, 0.80, 0.56)
	_kreis(0.32, 0.44, 0.10)
	_linie([Vector2(0.20, 0.68), Vector2(0.44, 0.68)], false, staerke * 0.9)
	_linie([Vector2(0.56, 0.42), Vector2(0.80, 0.42)], false, staerke * 0.9)
	_linie([Vector2(0.56, 0.58), Vector2(0.80, 0.58)], false, staerke * 0.9)

func _stuhl() -> void:  # Vorstandssessel
	_linie([Vector2(0.26, 0.62), Vector2(0.26, 0.22), Vector2(0.74, 0.22), Vector2(0.74, 0.62)])
	_linie([Vector2(0.16, 0.62), Vector2(0.84, 0.62)], false, staerke * 1.3)
	_linie([Vector2(0.30, 0.62), Vector2(0.26, 0.88)])
	_linie([Vector2(0.70, 0.62), Vector2(0.74, 0.88)])

func _medaille() -> void:
	_linie([Vector2(0.30, 0.10), Vector2(0.44, 0.44)])
	_linie([Vector2(0.70, 0.10), Vector2(0.56, 0.44)])
	_kreis(0.50, 0.64, 0.24)
	_kreis(0.50, 0.64, 0.10, true)

func _mikrofon() -> void:
	_linie([Vector2(0.50, 0.20), Vector2(0.50, 0.56)], false, staerke * 2.2)
	draw_arc(_p(0.50, 0.52), 0.22 * _s, 0.0, PI, 16, farbe, staerke, true)
	_linie([Vector2(0.50, 0.74), Vector2(0.50, 0.88)])
	_linie([Vector2(0.34, 0.88), Vector2(0.66, 0.88)])

func _buch() -> void:
	_linie([Vector2(0.50, 0.24), Vector2(0.50, 0.84)])
	_linie([Vector2(0.50, 0.24), Vector2(0.16, 0.18), Vector2(0.16, 0.76), Vector2(0.50, 0.84)])
	_linie([Vector2(0.50, 0.24), Vector2(0.84, 0.18), Vector2(0.84, 0.76), Vector2(0.50, 0.84)])

func _brief() -> void:
	_kasten(0.10, 0.26, 0.80, 0.48)
	_linie([Vector2(0.10, 0.28), Vector2(0.50, 0.56), Vector2(0.90, 0.28)])

func _diskette() -> void:
	_linie([Vector2(0.14, 0.14), Vector2(0.76, 0.14), Vector2(0.86, 0.26),
		Vector2(0.86, 0.86), Vector2(0.14, 0.86)], true)
	_kasten(0.32, 0.14, 0.36, 0.24)
	_kasten(0.28, 0.56, 0.44, 0.30)

func _glocke() -> void:
	draw_arc(_p(0.50, 0.48), 0.28 * _s, PI, TAU, 18, farbe, staerke, true)
	_linie([Vector2(0.22, 0.48), Vector2(0.22, 0.70), Vector2(0.78, 0.70), Vector2(0.78, 0.48)])
	_linie([Vector2(0.14, 0.70), Vector2(0.86, 0.70)])
	draw_arc(_p(0.50, 0.74), 0.10 * _s, 0.0, PI, 10, farbe, staerke, true)

func _pfeil_rechts() -> void:
	_linie([Vector2(0.24, 0.50), Vector2(0.72, 0.50)])
	_linie([Vector2(0.54, 0.28), Vector2(0.76, 0.50), Vector2(0.54, 0.72)])

func _pfeil_links() -> void:
	_linie([Vector2(0.76, 0.50), Vector2(0.28, 0.50)])
	_linie([Vector2(0.46, 0.28), Vector2(0.24, 0.50), Vector2(0.46, 0.72)])

## Zahnrad: ein Ring und acht Zaehne. Gezeichnet statt gezeichnet abgelegt —
## acht kurze Striche auf dem Kreis genuegen, und bei jeder Groesse sitzen sie.
func _zahnrad() -> void:
	_kreis(0.50, 0.50, 0.17)
	for i in 8:
		var w: float = TAU * float(i) / 8.0
		var r := Vector2(cos(w), sin(w))
		var a := Vector2(0.50, 0.50) + r * 0.25
		var b := Vector2(0.50, 0.50) + r * 0.40
		_linie([a, b], false, staerke * 1.05)

func _frage() -> void:
	_linie([Vector2(0.33, 0.34), Vector2(0.38, 0.24), Vector2(0.56, 0.21),
		Vector2(0.67, 0.31), Vector2(0.63, 0.45), Vector2(0.50, 0.53),
		Vector2(0.50, 0.63)])
	_kreis(0.50, 0.78, 0.055, true)

func _doppelpfeil() -> void:
	_linie([Vector2(0.16, 0.26), Vector2(0.46, 0.50), Vector2(0.16, 0.74)], false, staerke * 1.1)
	_linie([Vector2(0.52, 0.26), Vector2(0.82, 0.50), Vector2(0.52, 0.74)], false, staerke * 1.1)

func _pause() -> void:
	_kasten(0.28, 0.20, 0.14, 0.60, true)
	_kasten(0.58, 0.20, 0.14, 0.60, true)

func _kreuz() -> void:
	_linie([Vector2(0.24, 0.24), Vector2(0.76, 0.76)])
	_linie([Vector2(0.76, 0.24), Vector2(0.24, 0.76)])

func _haken() -> void:
	_linie([Vector2(0.18, 0.52), Vector2(0.42, 0.76), Vector2(0.84, 0.24)], false, staerke * 1.2)

func _warnung() -> void:
	_linie([Vector2(0.50, 0.12), Vector2(0.92, 0.84), Vector2(0.08, 0.84)], true)
	_linie([Vector2(0.50, 0.40), Vector2(0.50, 0.62)])
	_kreis(0.50, 0.73, 0.045, true)

func _uhr() -> void:
	_kreis(0.50, 0.50, 0.36)
	_linie([Vector2(0.50, 0.28), Vector2(0.50, 0.52), Vector2(0.68, 0.60)])

func _pfeife() -> void:
	_kreis(0.36, 0.52, 0.22)
	_linie([Vector2(0.52, 0.38), Vector2(0.90, 0.38), Vector2(0.90, 0.54), Vector2(0.55, 0.62)])

func _ball() -> void:
	_kreis(0.50, 0.50, 0.36)
	draw_arc(_p(0.50, 0.50), 0.20 * _s, 0.5, 2.7, 12, farbe, staerke * 0.8, true)
	draw_arc(_p(0.50, 0.50), 0.20 * _s, 3.7, 5.9, 12, farbe, staerke * 0.8, true)

func _datenbank() -> void:  # gestapelte Scheiben
	_linie([Vector2(0.18, 0.26), Vector2(0.18, 0.74)])
	_linie([Vector2(0.82, 0.26), Vector2(0.82, 0.74)])
	for y in [0.26, 0.50, 0.74]:
		draw_arc(_p(0.50, y), 0.32 * _s, 0.0, PI, 16, farbe, staerke, true)
	draw_arc(_p(0.50, 0.26), 0.32 * _s, PI, TAU, 16, farbe, staerke, true)
