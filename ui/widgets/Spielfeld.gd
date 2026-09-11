class_name Spielfeld
extends Control
## Zeichnet ein Handballfeld (40 × 20 m) samt Mannschaften — vollständig prozedural.
## Wird sowohl für die Aufstellungsvorschau als auch für die Live-Ansicht benutzt.

const LAENGE := 40.0
const BREITE := 20.0

## Angriffspositionen in Meterkoordinaten, wenn auf das rechte Tor gespielt wird.
const ANGRIFF_RECHTS := {
	"LA": Vector2(30.5, 2.4), "RL": Vector2(27.5, 6.4), "RM": Vector2(26.0, 10.0),
	"RR": Vector2(27.5, 13.6), "RA": Vector2(30.5, 17.6), "KM": Vector2(34.6, 10.0),
}
const ABWEHR_RECHTS := [
	Vector2(33.6, 4.6), Vector2(33.9, 7.3), Vector2(34.1, 9.999), Vector2(34.1, 10.001),
	Vector2(33.9, 12.7), Vector2(33.6, 15.4),
]

var heim_farbe: Color = Color("#f0a23c")
var gast_farbe: Color = Color("#48a9f8")
var heim_kurz: String = "HEI"
var gast_kurz: String = "GAS"
## "heim" oder "gast" — wer greift gerade an
var angreifer: String = "heim"
## Sichtbare Spieler: {"heim": {pos: {"name":..,"nummer":..,"aktiv":bool}}, "gast": {...}}
var szene: Dictionary = {"heim": {}, "gast": {}}
var ball: Vector2 = Vector2(20.0, 10.0)
var hervorgehoben: String = ""
var nur_angriff: bool = false
var puls: float = 50.0
var zeige_puls: bool = true

func _init() -> void:
	custom_minimum_size = Vector2(520, 270)

func setze_szene(neue: Dictionary) -> void:
	szene = neue
	queue_redraw()

func _m(p: Vector2) -> Vector2:
	var rand := 14.0
	var sx: float = (size.x - rand * 2.0) / LAENGE
	var sy: float = (size.y - rand * 2.0) / BREITE
	var s: float = minf(sx, sy)
	var versatz := Vector2((size.x - LAENGE * s) * 0.5, (size.y - BREITE * s) * 0.5)
	return versatz + p * s
 
func _skala() -> float:
	var rand := 14.0
	return minf((size.x - rand * 2.0) / LAENGE, (size.y - rand * 2.0) / BREITE)

func _draw() -> void:
	var s := _skala()
	if s <= 0.5:
		return
	# Parkett
	draw_rect(Rect2(_m(Vector2(0, 0)), Vector2(LAENGE, BREITE) * s), Color("#1a2129"), true)
	# Torräume
	_torraum(true, s)
	_torraum(false, s)
	# Linien
	var linie := Color("#4a5766")
	draw_rect(Rect2(_m(Vector2(0, 0)), Vector2(LAENGE, BREITE) * s), linie, false, maxf(s * 0.08, 1.5))
	draw_line(_m(Vector2(20, 0)), _m(Vector2(20, BREITE)), linie, maxf(s * 0.06, 1.0))
	_kreis_linie(0.0, 6.0, linie, s, false)
	_kreis_linie(0.0, 9.0, Color("#3d4a58"), s, true)
	_kreis_linie(LAENGE, 6.0, linie, s, false)
	_kreis_linie(LAENGE, 9.0, Color("#3d4a58"), s, true)
	# Siebenmeterlinien
	draw_line(_m(Vector2(7, 9.2)), _m(Vector2(7, 10.8)), linie, maxf(s * 0.06, 1.0))
	draw_line(_m(Vector2(33, 9.2)), _m(Vector2(33, 10.8)), linie, maxf(s * 0.06, 1.0))
	# Tore
	_tor(0.0, s)
	_tor(LAENGE, s)
	# Mannschaften
	_zeichne_mannschaft("heim", s)
	_zeichne_mannschaft("gast", s)
	# Ball
	draw_circle(_m(ball), maxf(s * 0.3, 3.0), Color("#f5f0e2"))
	draw_arc(_m(ball), maxf(s * 0.3, 3.0), 0.0, TAU, 12, Color("#2a2118"), maxf(s * 0.05, 1.0))

## Der Torraum ist der Halbkreis mit 6 m Radius um die Tormitte.
func _torraum(links: bool, s: float) -> void:
	var x: float = 0.0 if links else LAENGE
	var richtung: float = 1.0 if links else -1.0
	var punkte := PackedVector2Array()
	var schritte := 24
	for i in range(schritte + 1):
		var w: float = PI * float(i) / float(schritte)
		punkte.append(_m(Vector2(x + sin(w) * 6.0 * richtung, 10.0 - cos(w) * 6.0)))
	if punkte.size() >= 3:
		draw_colored_polygon(punkte, Color("#22303b"))

func _kreis_linie(x: float, radius: float, farbe: Color, s: float, gestrichelt: bool) -> void:
	var schritte := 30
	var richtung: float = 1.0 if x < LAENGE / 2.0 else -1.0
	var vorher := Vector2.ZERO
	for i in range(schritte + 1):
		var w: float = PI * float(i) / float(schritte)
		var pm := _m(Vector2(x + sin(w) * radius * richtung, 10.0 - cos(w) * radius))
		if i > 0 and (not gestrichelt or i % 2 == 0):
			draw_line(vorher, pm, farbe, maxf(s * 0.05, 1.0))
		vorher = pm

func _tor(x: float, s: float) -> void:
	var links: bool = x < LAENGE / 2.0
	draw_line(_m(Vector2(x, 8.5)), _m(Vector2(x, 11.5)), Color("#e8eef5"), maxf(s * 0.14, 2.5))
	draw_rect(Rect2(_m(Vector2(x - (0.0 if links else 1.0), 8.5)), Vector2(1.0, 3.0) * s), Color(1, 1, 1, 0.09), true)

func _zeichne_mannschaft(seite: String, s: float) -> void:
	var spieler: Dictionary = szene.get(seite, {})
	if spieler.is_empty():
		return
	var greift_an: bool = angreifer == seite
	var farbe: Color = heim_farbe if seite == "heim" else gast_farbe
	# Heim greift auf das rechte Tor an, Gast auf das linke
	var nach_rechts: bool = (seite == "heim")
	for pos in spieler.keys():
		var eintrag: Dictionary = spieler[pos]
		var p := _position(pos, greift_an, nach_rechts, int(eintrag.get("index", 0)))
		var r: float = maxf(s * 0.42, 5.0)
		var ist_tw: bool = pos == "TW"
		var f: Color = farbe.lightened(0.25) if ist_tw else farbe
		if str(eintrag.get("status", "")) == "strafe":
			f = Color("#60636b")
		draw_circle(_m(p), r, f)
		draw_arc(_m(p), r, 0.0, TAU, 14, Color(0, 0, 0, 0.55), maxf(s * 0.06, 1.0))
		if hervorgehoben != "" and str(eintrag.get("sid", "")) == hervorgehoben:
			draw_arc(_m(p), r * 1.55, 0.0, TAU, 18, Color("#ffffff"), maxf(s * 0.09, 1.5))
		var beschriftung: String = str(eintrag.get("kurz", pos))
		var schrift := ThemeDB.fallback_font
		var groesse: int = maxi(int(s * 0.42), 8)
		var breite: float = schrift.get_string_size(beschriftung, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
		draw_string(schrift, _m(p) + Vector2(-breite * 0.5, r + groesse * 1.15), beschriftung,
			HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Color("#c9d4df"))

func _position(pos: String, greift_an: bool, nach_rechts: bool, index: int) -> Vector2:
	if pos == "TW":
		return Vector2(1.2 if nach_rechts else LAENGE - 1.2, 10.0)
	if greift_an:
		var basis: Vector2 = ANGRIFF_RECHTS.get(pos, Vector2(26.0, 10.0))
		return basis if nach_rechts else Vector2(LAENGE - basis.x, basis.y)
	# In der Abwehr steht die Mannschaft vor dem eigenen Tor
	var i: int = clampi(index, 0, ABWEHR_RECHTS.size() - 1)
	var b: Vector2 = ABWEHR_RECHTS[i]
	return Vector2(LAENGE - b.x, b.y) if nach_rechts else b

## Baut aus einer Aufstellung eine Szene fuer die Vorschau.
static func szene_aus_aufstellung(cid: String, angriff: bool) -> Dictionary:
	var v: Dictionary = Welt.verein(cid)
	var auf: Dictionary = v.get("aufstellung", {})
	var block: Dictionary = auf.get("angriff" if angriff else "abwehr", {})
	var eintraege := {}
	var i := 0
	for pos in block.keys():
		var sid: String = str(block[pos])
		if sid == "" or not Welt.daten["spieler"].has(sid):
			continue
		var sp: Dictionary = Welt.spieler(sid)
		eintraege[pos] = {"sid": sid, "kurz": str(sp["nachname"]).substr(0, 9), "index": i if pos != "TW" else 0}
		if pos != "TW":
			i += 1
	return eintraege
