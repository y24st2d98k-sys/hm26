class_name Portraet
extends Control
## Prozedurale Spielergesichter.
##
## Jedes Gesicht entsteht ausschliesslich aus der Spieler-ID: daraus wird ein
## Zufallszahlenstrom abgeleitet, der Kopfform, Hautton, Frisur, Augen, Nase,
## Mund, Bart und Ohren festlegt. Dieselbe ID ergibt immer dasselbe Gesicht —
## ueber Spielstaende, Vereinswechsel und Spieljahre hinweg.
##
## Alter und Herkunft wirken mit: die Hauttoene folgen der Nation, Haare werden
## mit den Jahren grau und weichen zurueck, aeltere Spieler bekommen Falten.
## Es wird keine einzige Bilddatei benutzt.

## Hauttoene von hell nach dunkel. Jede Nation zieht aus einem Ausschnitt.
const HAUT := [
	Color("#f2d3bd"), Color("#eac6a8"), Color("#dfb595"), Color("#cf9f7c"),
	Color("#b9865f"), Color("#9c6b48"), Color("#7d5334"), Color("#5f3d26"),
]
## Von-bis-Index in HAUT je Kultur.
const HAUT_BEREICH := {
	"de": [0, 3], "dk": [0, 2], "se": [0, 2], "no": [0, 2], "is": [0, 2],
	"nl": [0, 2], "pl": [0, 3], "cz": [0, 3], "sk": [0, 3], "at": [0, 3],
	"ch": [0, 3], "fr": [1, 5], "es": [1, 5], "pt": [1, 5], "it": [1, 4],
	"hr": [1, 4], "si": [1, 4], "rs": [1, 4], "mk": [1, 4], "ba": [1, 4],
	"me": [1, 4], "hu": [1, 4], "ro": [1, 4], "gr": [1, 4], "tn": [3, 6],
	"eg": [3, 6], "qa": [2, 5], "br": [1, 6], "jp": [1, 3], "kr": [1, 3],
}
const HAARFARBEN := [
	Color("#2b1d14"), Color("#171310"), Color("#4a2f1c"), Color("#6b4423"),
	Color("#8c5a2b"), Color("#b3803f"), Color("#d6b271"), Color("#7a3b1f"),
]

var sid: String = ""
var alter: int = 26
var nation: String = "de"
var trikot: Color = Color("#c8342f")
var zweitfarbe: Color = Color("#f4f1e8")
var ist_torwart: bool = false

# Aus der ID abgeleitete Merkmale
var _bereit: bool = false
var _haut: Color
var _haar: Color
var _frisur: int
var _bart: int
var _kopf: float
var _kinn: float
var _augen: float
var _brauen: float
var _nase: int
var _mund: int
var _ohren: float
var _glatze: float

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Portraet eines Spielers aus dem Spielstand.
static func fuer_spieler(spieler_id: String, groesse: float = 46.0) -> Portraet:
	var p := Portraet.new()
	p.custom_minimum_size = Vector2(groesse, groesse)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sp: Dictionary = Welt.spieler(spieler_id)
	if not sp.is_empty():
		p.setze(sp)
	return p

func setze(sp: Dictionary) -> void:
	sid = str(sp.get("id", ""))
	alter = int(sp.get("alter", 26))
	nation = str(sp.get("nation", "de"))
	ist_torwart = bool(sp.get("ist_torwart", false))
	var cid: String = str(sp.get("verein", ""))
	if cid != "":
		var w: Dictionary = Welt.verein(cid).get("wappen", {})
		trikot = w.get("a", trikot)
		zweitfarbe = w.get("b", zweitfarbe)
	_bereit = false
	queue_redraw()

## Merkmale aus der ID würfeln — immer derselbe Strom für dieselbe ID.
func _merkmale() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sid if sid != "" else "unbekannt")
	var bereich: Array = HAUT_BEREICH.get(nation, [0, 5])
	_haut = HAUT[rng.randi_range(int(bereich[0]), int(bereich[1]))]
	# Sehr helle Haut geht eher mit hellen Haaren einher.
	var hell: bool = _haut.get_luminance() > 0.62
	_haar = HAARFARBEN[rng.randi_range(2, 6)] if hell else HAARFARBEN[rng.randi_range(0, 3)]
	_frisur = rng.randi_range(0, 5)
	_bart = rng.randi_range(0, 4)
	_kopf = rng.randf_range(0.86, 1.06)
	_kinn = rng.randf_range(0.88, 1.12)
	_augen = rng.randf_range(0.90, 1.12)
	_brauen = rng.randf_range(0.80, 1.20)
	_nase = rng.randi_range(0, 2)
	_mund = rng.randi_range(0, 2)
	_ohren = rng.randf_range(0.85, 1.15)
	# Haarverlust und Ergrauen kommen mit den Jahren.
	_glatze = clampf(float(alter - 27) / 16.0, 0.0, 1.0) * rng.randf_range(0.0, 1.6)
	var grau: float = clampf(float(alter - 28) / 14.0, 0.0, 0.75) * rng.randf_range(0.2, 1.0)
	_haar = _haar.lerp(Color("#c9cdd2"), grau)
	_bereit = true

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s < 12.0:
		return
	if not _bereit:
		_merkmale()
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	# Hintergrund in Vereinsfarbe, damit das Portraet auch klein sofort zuordbar ist
	draw_circle(o + Vector2(s, s) * 0.5, s * 0.5, Color(trikot.r, trikot.g, trikot.b, 0.22))
	draw_arc(o + Vector2(s, s) * 0.5, s * 0.5 - 0.5, 0.0, TAU, 32,
		Color(trikot.r, trikot.g, trikot.b, 0.55), maxf(s * 0.02, 1.0), true)

	_schultern(s, o)
	_hals(s, o)
	_kopfform(s, o)
	_ohrenform(s, o)
	_haare(s, o)
	if s >= 26.0:
		_gesicht(s, o)
	if s >= 34.0 and alter >= 30:
		_falten(s, o)

func _p(x: float, y: float, s: float, o: Vector2) -> Vector2:
	return o + Vector2(x, y) * s

func _poly(punkte: Array, farbe: Color, s: float, o: Vector2) -> void:
	var pv := PackedVector2Array()
	for p in punkte:
		pv.append(_p((p as Vector2).x, (p as Vector2).y, s, o))
	if pv.size() >= 3:
		draw_colored_polygon(pv, farbe)

## Trikotschultern am unteren Rand — sie tragen die Vereinsfarben.
func _schultern(s: float, o: Vector2) -> void:
	var t: Color = zweitfarbe if ist_torwart else trikot
	_poly([Vector2(0.06, 1.02), Vector2(0.20, 0.86), Vector2(0.34, 0.80),
		Vector2(0.66, 0.80), Vector2(0.80, 0.86), Vector2(0.94, 1.02)], t, s, o)
	# Kragen in der Gegenfarbe
	var g: Color = trikot if ist_torwart else zweitfarbe
	_poly([Vector2(0.38, 0.81), Vector2(0.50, 0.90), Vector2(0.62, 0.81),
		Vector2(0.58, 0.79), Vector2(0.50, 0.85), Vector2(0.42, 0.79)], g, s, o)

func _hals(s: float, o: Vector2) -> void:
	_poly([Vector2(0.41, 0.70), Vector2(0.59, 0.70), Vector2(0.60, 0.84),
		Vector2(0.40, 0.84)], _haut.darkened(0.16), s, o)

func _kopfform(s: float, o: Vector2) -> void:
	var punkte := _kopfkontur()
	var pv := PackedVector2Array()
	var farben := PackedColorArray()
	for p in punkte:
		var v: Vector2 = p
		pv.append(_p(v.x, v.y, s, o))
		# Von oben nach unten leicht abdunkeln — das nimmt der Flaeche das Maskenhafte.
		var t: float = clampf((v.y - 0.18) / 0.58, 0.0, 1.0)
		farben.append(_haut.lightened(0.07 * (1.0 - t)).darkened(0.13 * t))
	if pv.size() >= 3:
		draw_polygon(pv, farben)
	# Wangenschatten rechts
	var b: float = 0.20 * _kopf
	_poly([Vector2(0.5 + b * 0.58, 0.30), Vector2(0.5 + b * 0.99, 0.44),
		Vector2(0.5 + b * 0.74 * _kinn, 0.665), Vector2(0.5 + b * 0.32, 0.715)],
		Color(0, 0, 0, 0.06), s, o)

## Die Kopfumrisslinie als geschlossener Polygonzug — oben rund, unten zum Kinn
## verjuengt. Genug Stuetzpunkte, damit die Silhouette nicht kantig wirkt.
func _kopfkontur() -> Array:
	var b: float = 0.20 * _kopf
	var punkte: Array = []
	for i in range(19):
		var w: float = PI + PI * float(i) / 18.0
		punkte.append(Vector2(0.5 + cos(w) * b, 0.435 + sin(w) * 0.255))
	# Von der rechten Schlaefe ueber Wange und Kiefer zum Kinn
	var kiefer: Array = [
		Vector2(0.5 + b * 1.00, 0.505), Vector2(0.5 + b * 0.94, 0.570),
		Vector2(0.5 + b * 0.82 * _kinn, 0.630), Vector2(0.5 + b * 0.63 * _kinn, 0.686),
		Vector2(0.5 + b * 0.38 * _kinn, 0.730), Vector2(0.5 + b * 0.15 * _kinn, 0.752),
		Vector2(0.5, 0.756),
		Vector2(0.5 - b * 0.15 * _kinn, 0.752), Vector2(0.5 - b * 0.38 * _kinn, 0.730),
		Vector2(0.5 - b * 0.63 * _kinn, 0.686), Vector2(0.5 - b * 0.82 * _kinn, 0.630),
		Vector2(0.5 - b * 0.94, 0.570), Vector2(0.5 - b * 1.00, 0.505),
	]
	punkte.append_array(kiefer)
	return punkte

func _ohrenform(s: float, o: Vector2) -> void:
	var b: float = 0.20 * _kopf
	for seite in [-1.0, 1.0]:
		var em := _p(0.5 + seite * b * 1.03, 0.505, s, o)
		draw_circle(em, s * 0.042 * _ohren, _haut.darkened(0.05))
		draw_arc(em, s * 0.020 * _ohren, 0.0, TAU, 10, _haut.darkened(0.28), maxf(s * 0.012, 1.0), true)

## Frisuren: 0 kurz, 1 Seitenscheitel, 2 Bürste, 3 lockig, 4 Zopf, 5 rasiert.
func _haare(s: float, o: Vector2) -> void:
	var b: float = 0.20 * _kopf
	if _glatze > 1.15:
		return  # kahl
	var rand: float = 0.245 - _glatze * 0.045
	match _frisur:
		1:  # Seitenscheitel
			_poly([Vector2(0.5 - b * 1.02, 0.44), Vector2(0.5 - b * 0.98, 0.28),
				Vector2(0.5 - b * 0.40, 0.20), Vector2(0.5 + b * 0.55, 0.22),
				Vector2(0.5 + b * 1.02, 0.36), Vector2(0.5 + b * 1.02, 0.46),
				Vector2(0.5 + b * 0.30, 0.31), Vector2(0.5 - b * 0.62, 0.34)], _haar, s, o)
		2:  # Bürste
			_poly([Vector2(0.5 - b * 1.0, 0.44), Vector2(0.5 - b * 0.96, 0.26),
				Vector2(0.5, 0.19), Vector2(0.5 + b * 0.96, 0.26),
				Vector2(0.5 + b * 1.0, 0.44), Vector2(0.5 + b * 0.86, 0.33),
				Vector2(0.5, 0.30), Vector2(0.5 - b * 0.86, 0.33)], _haar, s, o)
		3:  # lockig / voluminös
			for i in range(7):
				var w: float = PI + PI * (float(i) + 0.5) / 7.0
				draw_circle(_p(0.5 + cos(w) * b * 0.95, 0.40 + sin(w) * rand, s, o),
					s * 0.062, _haar)
		4:  # Zopf im Nacken
			_poly([Vector2(0.5 - b * 1.02, 0.48), Vector2(0.5 - b * 0.95, 0.24),
				Vector2(0.5, 0.18), Vector2(0.5 + b * 0.95, 0.24),
				Vector2(0.5 + b * 1.02, 0.48), Vector2(0.5 + b * 0.80, 0.40),
				Vector2(0.5, 0.36), Vector2(0.5 - b * 0.80, 0.40)], _haar, s, o)
			_poly([Vector2(0.5 - 0.035, 0.52), Vector2(0.5 + 0.035, 0.52),
				Vector2(0.5 + 0.05, 0.70), Vector2(0.5 - 0.05, 0.70)], _haar, s, o)
		5:  # rasiert — nur ein Schatten
			_poly([Vector2(0.5 - b * 1.0, 0.44), Vector2(0.5 - b * 0.92, 0.27),
				Vector2(0.5, 0.21), Vector2(0.5 + b * 0.92, 0.27),
				Vector2(0.5 + b * 1.0, 0.44), Vector2(0.5 + b * 0.90, 0.38),
				Vector2(0.5, 0.34), Vector2(0.5 - b * 0.90, 0.38)],
				Color(_haar.r, _haar.g, _haar.b, 0.42), s, o)
		_:  # kurz
			_poly([Vector2(0.5 - b * 1.02, 0.46), Vector2(0.5 - b * 0.95, 0.25),
				Vector2(0.5, 0.185), Vector2(0.5 + b * 0.95, 0.25),
				Vector2(0.5 + b * 1.02, 0.46), Vector2(0.5 + b * 0.88, 0.36),
				Vector2(0.5 + b * 0.30, 0.315 + _glatze * 0.02),
				Vector2(0.5 - b * 0.30, 0.315 + _glatze * 0.02),
				Vector2(0.5 - b * 0.88, 0.36)], _haar, s, o)

func _gesicht(s: float, o: Vector2) -> void:
	var b: float = 0.20 * _kopf
	var ax: float = b * 0.44
	var ay: float = 0.485
	var ar: float = s * 0.034 * _augen
	# Augen: Weiß, Iris, Lid
	for seite in [-1.0, 1.0]:
		var m := _p(0.5 + seite * ax, ay, s, o)
		draw_circle(m, ar, Color("#f4f6f8"))
		draw_circle(m + Vector2(seite * ar * 0.12, 0), ar * 0.52, Color("#3b2c20"))
		draw_line(m + Vector2(-ar, -ar * 0.55), m + Vector2(ar, -ar * 0.7),
			_haut.darkened(0.35), maxf(s * 0.012, 1.0))
	# Brauen
	var by: float = ay - 0.055 * _brauen
	for seite2 in [-1.0, 1.0]:
		draw_line(_p(0.5 + seite2 * (ax - b * 0.26), by + 0.008, s, o),
			_p(0.5 + seite2 * (ax + b * 0.28), by - 0.004, s, o),
			_haar.darkened(0.12), maxf(s * 0.021, 1.1))
	# Nase: ein schmaler Schatten mit angedeutetem Ruecken — Striche wirkten
	# aus der Naehe wie eine gezeichnete Sieben.
	var schatten := Color(0, 0, 0, 0.10)
	var versatz: float = [0.0, -0.012, 0.012][_nase]
	_poly([Vector2(0.5 + versatz * 0.5, 0.500), Vector2(0.5 + 0.030 + versatz, 0.580),
		Vector2(0.5 + 0.024, 0.598), Vector2(0.5 - 0.024, 0.598),
		Vector2(0.5 - 0.030 + versatz, 0.580)], schatten, s, o)
	draw_line(_p(0.5 - 0.022, 0.596, s, o), _p(0.5 + 0.022, 0.596, s, o),
		Color(0, 0, 0, 0.16), maxf(s * 0.014, 1.0))
	_bartform(s, o, b)
	# Mund — nach dem Bart, damit er nicht verdeckt wird
	var my: float = 0.648
	match _mund:
		1:
			draw_line(_p(0.5 - b * 0.34, my, s, o), _p(0.5 + b * 0.34, my - 0.006, s, o),
				Color("#8f5347"), maxf(s * 0.024, 1.2))
		2:
			draw_line(_p(0.5 - b * 0.30, my - 0.004, s, o), _p(0.5, my + 0.012, s, o),
				Color("#8f5347"), maxf(s * 0.024, 1.2))
			draw_line(_p(0.5, my + 0.012, s, o), _p(0.5 + b * 0.30, my - 0.004, s, o),
				Color("#8f5347"), maxf(s * 0.024, 1.2))
		_:
			draw_line(_p(0.5 - b * 0.32, my, s, o), _p(0.5 + b * 0.32, my, s, o),
				Color("#8f5347"), maxf(s * 0.026, 1.2))

## Bärte: 0 keiner, 1 Dreitagebart, 2 Kinnbart, 3 Vollbart, 4 Schnurrbart.
func _bartform(s: float, o: Vector2, b: float) -> void:
	if _bart == 0:
		return
	var f := Color(_haar.r, _haar.g, _haar.b, 0.88)
	# Der Bart folgt der Kieferlinie, damit er nicht als Klotz auf dem Kinn sitzt.
	var kontur := _kopfkontur()
	var unten: Array = []
	for p in kontur:
		if (p as Vector2).y >= 0.50:
			unten.append(p)
	match _bart:
		1:  # Dreitagebart — nur ein Schatten ueber der unteren Gesichtshaelfte
			var flaeche: Array = [Vector2(0.5 - b * 0.92, 0.560)]
			flaeche.append_array(unten)
			flaeche.append(Vector2(0.5 + b * 0.92, 0.560))
			_poly(flaeche, Color(f.r, f.g, f.b, 0.22), s, o)
		2:  # Kinnbart
			_poly([Vector2(0.5 - b * 0.36, 0.660), Vector2(0.5 + b * 0.36, 0.660),
				Vector2(0.5 + b * 0.30, 0.735), Vector2(0.5, 0.752),
				Vector2(0.5 - b * 0.30, 0.735)], f, s, o)
		3:  # Vollbart — Kieferlinie plus Schnurrbart, Mund bleibt frei
			var voll: Array = [Vector2(0.5 - b * 0.96, 0.540)]
			voll.append_array(unten)
			voll.append(Vector2(0.5 + b * 0.96, 0.540))
			voll.append(Vector2(0.5 + b * 0.66, 0.612))
			voll.append(Vector2(0.5, 0.640))
			voll.append(Vector2(0.5 - b * 0.66, 0.612))
			_poly(voll, f, s, o)
			_poly([Vector2(0.5 - b * 0.40, 0.612), Vector2(0.5 + b * 0.40, 0.612),
				Vector2(0.5 + b * 0.32, 0.636), Vector2(0.5 - b * 0.32, 0.636)], f, s, o)
		4:  # Schnurrbart
			_poly([Vector2(0.5 - b * 0.38, 0.608), Vector2(0.5 + b * 0.38, 0.608),
				Vector2(0.5 + b * 0.30, 0.636), Vector2(0.5 - b * 0.30, 0.636)], f, s, o)

func _falten(s: float, o: Vector2) -> void:
	var b: float = 0.20 * _kopf
	var f := Color(0, 0, 0, 0.11)
	draw_line(_p(0.5 - b * 0.30, 0.415, s, o), _p(0.5 + b * 0.30, 0.415, s, o), f, maxf(s * 0.014, 1.0))
	if alter >= 33:
		draw_line(_p(0.5 - b * 0.55, 0.60, s, o), _p(0.5 - b * 0.40, 0.665, s, o), f, maxf(s * 0.012, 1.0))
		draw_line(_p(0.5 + b * 0.55, 0.60, s, o), _p(0.5 + b * 0.40, 0.665, s, o), f, maxf(s * 0.012, 1.0))
