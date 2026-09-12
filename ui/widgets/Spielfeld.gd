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
## Sechs Plaetze vor dem eigenen Tor. Frueher lagen die beiden Innenblocker
## fast deckungsgleich auf der Mittelachse — ihre Namen ueberdeckten sich.
const ABWEHR_RECHTS := [
	Vector2(33.5, 4.4), Vector2(33.8, 7.0), Vector2(34.0, 9.0), Vector2(34.0, 11.0),
	Vector2(33.8, 13.0), Vector2(33.5, 15.6),
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

# ------------------------------------------------------------- Bewegung ---
#
# Das Feld ist keine Momentaufnahme mehr: jeder Spieler hat eine tatsaechliche
# und eine angestrebte Position, der Ball fliegt zwischen beiden Punkten. Ohne
# das sprang die Live-Ansicht von Ereignis zu Ereignis, und ein Handballspiel
# sah aus wie eine Tabelle mit Kreisen.

## Laeuft die Bewegung? In der Aufstellungsvorschau bleibt alles ruhig stehen.
var lebendig: bool = false
## Laufgeschwindigkeit in Metern je Sekunde.
const TEMPO := 7.5

var _ist: Dictionary = {}        # sid -> Vector2, wo der Spieler gerade steht
var _ziel: Dictionary = {}       # sid -> Vector2, wohin er unterwegs ist
var _zittern: Dictionary = {}    # sid -> float, Phase der kleinen Standbewegung
var _ball_von: Vector2 = Vector2(20.0, 10.0)
var _ball_nach: Vector2 = Vector2(20.0, 10.0)
var _ball_t: float = 1.0
var _ball_dauer: float = 0.35
var _ball_bogen: float = 0.0
## Kurze Lichtblitze: [{"punkt": Vector2, "farbe": Color, "rest": float, "dauer": float}]
var _blitze: Array = []
var _zeit: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(520, 270)

func _process(delta: float) -> void:
	if not lebendig or not is_visible_in_tree():
		return
	_zeit += delta
	var bewegt := false
	for sid in _ziel.keys():
		var ziel: Vector2 = _ziel[sid]
		var ist: Vector2 = _ist.get(sid, ziel)
		var weg: Vector2 = ziel - ist
		var laenge: float = weg.length()
		if laenge > 0.02:
			var schritt: float = minf(TEMPO * delta, laenge)
			_ist[sid] = ist + weg / laenge * schritt
			bewegt = true
		else:
			_ist[sid] = ziel
	if _ball_t < 1.0:
		_ball_t = minf(_ball_t + delta / maxf(_ball_dauer, 0.05), 1.0)
		bewegt = true
	for i in range(_blitze.size() - 1, -1, -1):
		var b: Dictionary = _blitze[i]
		b["rest"] = float(b["rest"]) - delta
		if float(b["rest"]) <= 0.0:
			_blitze.remove_at(i)
		bewegt = true
	if bewegt or lebendig:
		queue_redraw()

## Wo der Ball gerade ist — auf der Flugbahn zwischen Start und Ziel.
func _ballpunkt() -> Vector2:
	if _ball_t >= 1.0:
		return _ball_nach
	var t: float = _ball_t
	var p: Vector2 = _ball_von.lerp(_ball_nach, t)
	# Ein Wurf fliegt sichtbar hoch, ein Pass bleibt flach.
	if _ball_bogen > 0.0:
		p.y -= sin(t * PI) * _ball_bogen
	return p

## Setzt die Mannschaften. Bekannte Spieler laufen zu ihrem neuen Platz,
## neu erschienene stehen sofort dort.
func setze_szene(neue: Dictionary) -> void:
	szene = neue
	_ziele_berechnen()
	queue_redraw()

func _ziele_berechnen() -> void:
	var gesehen := {}
	for seite in ["heim", "gast"]:
		var spieler: Dictionary = szene.get(seite, {})
		var greift_an: bool = angreifer == seite
		var nach_rechts: bool = seite == "heim"
		for pos in spieler.keys():
			var eintrag: Dictionary = spieler[pos]
			var sid: String = str(eintrag.get("sid", "%s_%s" % [seite, pos]))
			var ziel := _position(str(pos), greift_an, nach_rechts, int(eintrag.get("index", 0)))
			_ziel[sid] = ziel
			if not _ist.has(sid):
				_ist[sid] = ziel
			if not _zittern.has(sid):
				_zittern[sid] = randf() * TAU
			gesehen[sid] = true
	for sid2 in _ziel.keys():
		if not gesehen.has(sid2):
			_ziel.erase(sid2)
			_ist.erase(sid2)
			_zittern.erase(sid2)

## Wo steht dieser Spieler gerade? Faellt auf seinen Sollplatz zurueck.
func spielerpunkt(sid: String) -> Vector2:
	return _ist.get(sid, _ziel.get(sid, Vector2(20.0, 10.0)))

## Der Ball wandert flach zu einem Punkt (Pass, Dribbling, Anspiel).
func ball_spielen(nach: Vector2, dauer: float = 0.32) -> void:
	_ball_von = _ballpunkt()
	_ball_nach = nach
	_ball_dauer = maxf(dauer, 0.05)
	_ball_bogen = 0.0
	_ball_t = 0.0

## Der Ball fliegt in hohem Bogen — ein Wurf.
func ball_werfen(nach: Vector2, dauer: float = 0.30, hoehe: float = 1.6) -> void:
	_ball_von = _ballpunkt()
	_ball_nach = nach
	_ball_dauer = maxf(dauer, 0.05)
	_ball_bogen = hoehe
	_ball_t = 0.0

## Ball ohne Flug an eine Stelle setzen (Anwurf, Auszeit, Halbzeit).
func ball_setzen(punkt: Vector2) -> void:
	_ball_von = punkt
	_ball_nach = punkt
	_ball_t = 1.0
	_ball_bogen = 0.0
	ball = punkt

## Kurzer Lichtblitz an einer Stelle — Tor, Parade, Block.
func aufblitzen(punkt: Vector2, farbe: Color, dauer: float = 0.7) -> void:
	_blitze.append({"punkt": punkt, "farbe": farbe, "rest": dauer, "dauer": dauer})
	# Mehr als eine Handvoll gleichzeitig wäre kein Signal mehr, sondern Nebel.
	while _blitze.size() > 4:
		_blitze.remove_at(0)

## Schon vergebene Namensfelder dieses Zeichenvorgangs.
var _belegt: Array = []

## Schiebt eine Beschriftung so weit, bis sie keine andere überdeckt. In der
## Abwehr stehen sechs Spieler dicht beieinander — ohne das liest man dort nichts.
func _freie_stelle(stelle: Vector2, breite: float, hoehe: float, nach_unten: bool) -> Vector2:
	var richtung: float = 1.0 if nach_unten else -1.0
	for _versuch in range(4):
		var frei := true
		for r in _belegt:
			var anderes: Rect2 = r
			if anderes.intersects(Rect2(stelle - Vector2(0, hoehe), Vector2(breite, hoehe + 2.0))):
				frei = false
				break
		if frei:
			break
		stelle.y += richtung * (hoehe + 1.0)
	_belegt.append(Rect2(stelle - Vector2(0, hoehe), Vector2(breite, hoehe + 2.0)))
	return stelle

## Mittelpunkt des Tores, auf das diese Seite wirft.
func tormitte(seite: String) -> Vector2:
	return Vector2(LAENGE - 0.3, 10.0) if seite == "heim" else Vector2(0.3, 10.0)

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
	_belegt.clear()
	var feld := Rect2(_m(Vector2(0, 0)), Vector2(LAENGE, BREITE) * s)

	# Parkett mit angedeuteten Dielen — sonst wirkt die Flaeche wie ein Loch
	draw_rect(feld, Color("#182029"), true)
	var diele := Color(1, 1, 1, 0.012)
	var x := 0.0
	while x < LAENGE:
		draw_rect(Rect2(_m(Vector2(x, 0)), Vector2(1.25, BREITE) * s), diele, true)
		x += 2.5

	# Torraeume in den Vereinsfarben: man sieht sofort, wer auf welches Tor spielt
	# Heim greift nach rechts an und verteidigt deshalb links.
	_torraum(true, s, heim_farbe)
	_torraum(false, s, gast_farbe)

	var linie := Color("#5a6a7c")
	var schwach := Color("#3f4c5b")
	# Mittellinie und Anwurfkreis
	draw_line(_m(Vector2(20, 0)), _m(Vector2(20, BREITE)), schwach, maxf(s * 0.05, 1.0))
	draw_arc(_m(Vector2(20, 10)), s * 1.6, 0.0, TAU, 28, schwach, maxf(s * 0.05, 1.0), true)

	# Torraum- (6 m), Freiwurf- (9 m, gestrichelt) und Torwartlinie (4 m)
	for tor_x in [0.0, LAENGE]:
		_bogen(tor_x, 6.0, linie, s, 0)
		_bogen(tor_x, 9.0, schwach, s, 2)
		_torwartlinie(tor_x, s, schwach)

	# Siebenmeterlinien
	for sieben in [7.0, LAENGE - 7.0]:
		draw_line(_m(Vector2(sieben, 9.5)), _m(Vector2(sieben, 10.5)), linie, maxf(s * 0.07, 1.2))

	# Wechselzonen auf der Bankseite
	for zone in [Vector2(15.5, 0.0), Vector2(24.5, 0.0)]:
		draw_line(_m(zone), _m(zone + Vector2(0.0, -0.55)), linie, maxf(s * 0.07, 1.2))

	# Aussenlinien zuletzt, damit sie ueber allem liegen
	draw_rect(feld, linie, false, maxf(s * 0.08, 1.5))

	_tor(0.0, s)
	_tor(LAENGE, s)

	_zeichne_mannschaft("heim", s)
	_zeichne_mannschaft("gast", s)

	# Kurze Lichtblitze (Tor, Parade, Block): ein aufgehender Ring, kein Nebel
	for b in _blitze:
		var anteil: float = clampf(float(b["rest"]) / maxf(float(b["dauer"]), 0.01), 0.0, 1.0)
		var f: Color = b["farbe"]
		f.a = anteil * 0.75
		var radius: float = s * (0.7 + (1.0 - anteil) * 1.5)
		draw_arc(_m(b["punkt"]), radius, 0.0, TAU, 22, f, maxf(s * 0.11, 1.6), true)

	# Ball mit weichem Schein
	var bp := _m(_ballpunkt() if lebendig else ball)
	var br: float = maxf(s * 0.3, 3.0)
	draw_circle(bp, br * 2.1, Color(1, 0.95, 0.8, 0.10))
	draw_circle(bp, br, Color("#f7f2e4"))
	draw_arc(bp, br, 0.0, TAU, 12, Color("#2a2118"), maxf(s * 0.05, 1.0))

## Der Torraum ist der Halbkreis mit 6 m Radius um die Tormitte.
func _torraum(links: bool, s: float, farbe: Color) -> void:
	var x: float = 0.0 if links else LAENGE
	var richtung: float = 1.0 if links else -1.0
	var punkte := PackedVector2Array()
	var schritte := 28
	for i in range(schritte + 1):
		var w: float = PI * float(i) / float(schritte)
		punkte.append(_m(Vector2(x + sin(w) * 6.0 * richtung, 10.0 - cos(w) * 6.0)))
	if punkte.size() >= 3:
		draw_colored_polygon(punkte, Color("#202b36"))
		draw_colored_polygon(punkte, Color(farbe.r, farbe.g, farbe.b, 0.10))

## Bogen um ein Tor. luecke = 0 zeichnet durch, sonst wird jedes n-te Stueck ausgelassen.
func _bogen(x: float, radius: float, farbe: Color, s: float, luecke: int) -> void:
	var schritte := 40
	var richtung: float = 1.0 if x < LAENGE / 2.0 else -1.0
	var vorher := Vector2.ZERO
	for i in range(schritte + 1):
		var w: float = PI * float(i) / float(schritte)
		var pm := _m(Vector2(x + sin(w) * radius * richtung, 10.0 - cos(w) * radius))
		if i > 0 and (luecke == 0 or i % (luecke + 1) != 0):
			draw_line(vorher, pm, farbe, maxf(s * 0.05, 1.0))
		vorher = pm

## Die 4-Meter-Linie, bis zu der der Torwart beim Siebenmeter vorlaufen darf.
func _torwartlinie(x: float, s: float, farbe: Color) -> void:
	var richtung: float = 1.0 if x < LAENGE / 2.0 else -1.0
	draw_line(_m(Vector2(x + 4.0 * richtung, 9.85)), _m(Vector2(x + 4.0 * richtung, 10.15)),
		farbe, maxf(s * 0.06, 1.0))

func _tor(x: float, s: float) -> void:
	var links: bool = x < LAENGE / 2.0
	var richtung: float = -1.0 if links else 1.0
	# Netz als angedeutetes Raster hinter der Torlinie
	var netz := Color(1, 1, 1, 0.07)
	for i in range(5):
		var y: float = 8.5 + float(i) * 0.75
		draw_line(_m(Vector2(x, y)), _m(Vector2(x + 1.1 * richtung, y)), netz, 1.0)
	for k in range(4):
		var xx: float = x + (0.28 + float(k) * 0.28) * richtung
		draw_line(_m(Vector2(xx, 8.5)), _m(Vector2(xx, 11.5)), netz, 1.0)
	# Pfosten und Latte
	draw_line(_m(Vector2(x, 8.5)), _m(Vector2(x, 11.5)), Color("#eef3f9"), maxf(s * 0.15, 2.5))
	draw_line(_m(Vector2(x, 8.5)), _m(Vector2(x + 1.1 * richtung, 8.5)), Color("#c8d2dd"), maxf(s * 0.07, 1.2))
	draw_line(_m(Vector2(x, 11.5)), _m(Vector2(x + 1.1 * richtung, 11.5)), Color("#c8d2dd"), maxf(s * 0.07, 1.2))

func _zeichne_mannschaft(seite: String, s: float) -> void:
	var spieler: Dictionary = szene.get(seite, {})
	if spieler.is_empty():
		return
	var greift_an: bool = angreifer == seite
	var farbe: Color = heim_farbe if seite == "heim" else gast_farbe
	# Heim greift auf das rechte Tor an, Gast auf das linke
	var nach_rechts: bool = (seite == "heim")
	var schrift := ThemeDB.fallback_font
	for pos in spieler.keys():
		var eintrag: Dictionary = spieler[pos]
		var sid_e: String = str(eintrag.get("sid", "%s_%s" % [seite, pos]))
		var meter: Vector2 = _position(pos, greift_an, nach_rechts, int(eintrag.get("index", 0)))
		if lebendig and _ist.has(sid_e):
			meter = _ist[sid_e]
			# Ein winziges Wippen: ohne das wirken stehende Spieler wie Pfosten.
			meter.y += sin(_zeit * 2.1 + float(_zittern.get(sid_e, 0.0))) * 0.10
			meter.x += cos(_zeit * 1.7 + float(_zittern.get(sid_e, 0.0))) * 0.07
		var p := _m(meter)
		var r: float = maxf(s * 0.46, 6.0)
		var ist_tw: bool = pos == "TW"
		var f: Color = farbe.lightened(0.30) if ist_tw else farbe
		var bestraft: bool = str(eintrag.get("status", "")) == "strafe"
		if bestraft:
			f = Color("#5b6068")
		# Schatten, Trikot, Rand — der Rand haelt die Farbe auch auf hellem Parkett lesbar
		draw_circle(p + Vector2(0, maxf(s * 0.1, 1.0)), r, Color(0, 0, 0, 0.35))
		draw_circle(p, r, f)
		draw_arc(p, r, 0.0, TAU, 18, Color(0, 0, 0, 0.5), maxf(s * 0.07, 1.2), true)
		if ist_tw:
			draw_arc(p, r * 0.55, 0.0, TAU, 14, Color(0, 0, 0, 0.30), maxf(s * 0.06, 1.0), true)
		if str(eintrag.get("sid", "")) != "" and str(eintrag.get("sid", "")) == hervorgehoben:
			draw_arc(p, r * 1.6, 0.0, TAU, 22, Color("#ffffff"), maxf(s * 0.09, 1.5), true)
		# Rueckennummer im Trikot — nur wo keine bekannt ist, steht das Positionskuerzel
		var nummer: int = int(eintrag.get("nummer", 0))
		var aufdruck: String = str(nummer) if nummer > 0 else pos
		var pgroesse: int = maxi(int(s * (0.46 if nummer > 0 else 0.34)), 7)
		var pbreite: float = schrift.get_string_size(aufdruck, HORIZONTAL_ALIGNMENT_LEFT, -1, pgroesse).x
		var dunkel: bool = f.get_luminance() < 0.5
		draw_string(schrift, p + Vector2(-pbreite * 0.5, pgroesse * 0.36), aufdruck,
			HORIZONTAL_ALIGNMENT_LEFT, -1, pgroesse,
			Color(1, 1, 1, 0.9) if dunkel else Color(0, 0, 0, 0.75))
		# Name darunter, mit dunkler Kante fuer Lesbarkeit
		var beschriftung: String = str(eintrag.get("kurz", ""))
		if beschriftung == "":
			continue
		var groesse: int = maxi(int(s * 0.40), 8)
		var breite: float = schrift.get_string_size(beschriftung, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
		# Namen der verteidigenden Mannschaft nach oben, die der angreifenden nach
		# unten — sonst kollidiert die Beschriftung des Kreislaeufers mit der Abwehr.
		var versatz_y: float = (r + groesse * 1.15) if greift_an else -(r + groesse * 0.55)
		var stelle: Vector2 = p + Vector2(-breite * 0.5, versatz_y)
		stelle.x = clampf(stelle.x, 2.0, maxf(size.x - breite - 2.0, 2.0))
		stelle = _freie_stelle(stelle, breite, float(groesse), greift_an)
		draw_string(schrift, stelle + Vector2(0, 1), beschriftung,
			HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Color(0, 0, 0, 0.65))
		draw_string(schrift, stelle, beschriftung, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse,
			Color("#8d99a6") if bestraft else Color("#dbe4ee"))

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
		eintraege[pos] = {"sid": sid, "kurz": str(sp["nachname"]).substr(0, 9),
			"nummer": int(sp.get("nummer", 0)), "index": i if pos != "TW" else 0}
		if pos != "TW":
			i += 1
	return eintraege
