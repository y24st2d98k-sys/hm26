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
## Laufwege: sid -> {"punkt": Vector2, "rest": float, "dauer": float, "tempo": float}
## Ein Laufweg zieht einen Spieler zeitweise von seinem Formationsplatz weg —
## der Kreislaeufer loest sich, der Aussen zieht in die Luecke, der
## Abwehrspieler geht heraus. Laeuft die Zeit ab, geht er zurueck auf Position.
var _laufwege: Dictionary = {}
## Wie lange die Spur hinter dem Ball nachleuchtet.
const SPUR_LAENGE := 14
var _spur: Array = []            # [{"punkt": Vector2, "rest": float}]
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
	for sid in _laufwege.keys():
		var l: Dictionary = _laufwege[sid]
		l["rest"] = float(l["rest"]) - delta
	for sid_weg in _laufwege.keys():
		if float((_laufwege[sid_weg] as Dictionary)["rest"]) <= 0.0:
			_laufwege.erase(sid_weg)
	for sid in _ziel.keys():
		var ziel: Vector2 = _laufziel(str(sid))
		var ist: Vector2 = _ist.get(sid, ziel)
		var weg: Vector2 = ziel - ist
		var laenge: float = weg.length()
		if laenge > 0.02:
			var tempo: float = TEMPO
			if _laufwege.has(sid):
				tempo = float((_laufwege[sid] as Dictionary).get("tempo", TEMPO))
			elif laenge > 7.0:
				# Umschaltspiel: wer die ganze Feldlaenge zurueck muss, geht
				# nicht spazieren. Sonst steht die Abwehr noch im Mittelkreis,
				# wenn der Gegner schon wirft.
				tempo = TEMPO * clampf(laenge / 7.0, 1.0, 3.2)
			var schritt: float = minf(tempo * delta, laenge)
			_ist[sid] = ist + weg / laenge * schritt
			bewegt = true
		else:
			_ist[sid] = ziel
	if _ball_t < 1.0:
		_ball_t = minf(_ball_t + delta / maxf(_ball_dauer, 0.05), 1.0)
		bewegt = true
	# Ballspur: eine kurze Kette der letzten Positionen. Ohne sie verliert man
	# den Ball bei jedem schnellen Pass aus den Augen. Nur bei echter Bewegung
	# eintragen — ein liegender Ball soll die Spur nicht mit sich selbst
	# auffuellen.
	var bp_jetzt: Vector2 = _ballpunkt()
	if _spur.is_empty() or bp_jetzt.distance_to((_spur[0] as Dictionary)["punkt"]) > 0.05:
		_spur.push_front({"punkt": bp_jetzt, "rest": 0.42})
	while _spur.size() > SPUR_LAENGE:
		_spur.pop_back()
	for i in range(_spur.size() - 1, -1, -1):
		var sp_e: Dictionary = _spur[i]
		sp_e["rest"] = float(sp_e["rest"]) - delta
		if float(sp_e["rest"]) <= 0.0:
			_spur.remove_at(i)
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
			_laufwege.erase(sid2)

## Wo steht dieser Spieler gerade? Faellt auf seinen Sollplatz zurueck.
func spielerpunkt(sid: String) -> Vector2:
	return _ist.get(sid, _ziel.get(sid, Vector2(20.0, 10.0)))

## Wohin dieser Spieler gerade unterwegs ist — Laufweg vor Formationsplatz.
func _laufziel(sid: String) -> Vector2:
	if _laufwege.has(sid):
		return (_laufwege[sid] as Dictionary)["punkt"]
	return _ziel.get(sid, Vector2(20.0, 10.0))

## Der Formationsplatz eines Spielers. Alle Laufwege rechnen von hier aus —
## sonst schaukeln sie sich auf: jeder Pass zoege den Verteidiger ein Stueck
## weiter zum Ball, bis er nach fuenf Stationen im gegnerischen Kreis steht.
func grundpunkt(sid: String) -> Vector2:
	return _ziel.get(sid, spielerpunkt(sid))

## Wie weit sich ein Spieler von seinem Platz loesen darf.
const LAUF_MAX := 6.5

## Ein Spieler loest sich fuer eine Weile von seinem Platz. Danach geht er
## automatisch zurueck — genau so, wie eine Kreuzbewegung im Handball endet.
func laufweg(sid: String, nach: Vector2, dauer: float = 1.4, tempo: float = 0.0) -> void:
	if sid == "":
		return
	# Am Formationsplatz haengt eine Leine: ein Laufweg ist eine Bewegung im
	# System und kein Ausflug.
	var basis: Vector2 = grundpunkt(sid)
	var weg: Vector2 = nach - basis
	if weg.length() > LAUF_MAX:
		nach = basis + weg.normalized() * LAUF_MAX
	var punkt := Vector2(clampf(nach.x, 0.6, LAENGE - 0.6), clampf(nach.y, 0.7, BREITE - 0.7))
	_laufwege[sid] = {"punkt": punkt, "rest": maxf(dauer, 0.1),
		"dauer": maxf(dauer, 0.1), "tempo": tempo if tempo > 0.0 else TEMPO * 1.35}

## Er stoesst von seinem Platz aus ein Stueck in eine Richtung vor.
func vorstossen(sid: String, richtung: Vector2, weite: float, dauer: float = 1.2) -> void:
	if sid == "" or richtung.length() < 0.01:
		return
	laufweg(sid, grundpunkt(sid) + richtung.normalized() * weite, dauer)

## Die verteidigende Mannschaft schiebt zum Ball. Der naechste Abwehrspieler
## geht heraus, seine Nachbarn ruecken nach — das ist die Bewegung, die man
## in einer Halle tatsaechlich sieht.
func abwehr_verschieben(verteidiger: String, ballpunkt: Vector2, staerke: float = 1.0) -> void:
	var spieler: Dictionary = szene.get(verteidiger, {})
	if spieler.is_empty():
		return
	var naechster := ""
	var abstand := 999.0
	for pos in spieler.keys():
		if str(pos) == "TW":
			continue
		var sid: String = str((spieler[pos] as Dictionary).get("sid", ""))
		if sid == "":
			continue
		var d: float = spielerpunkt(sid).distance_to(ballpunkt)
		if d < abstand:
			abstand = d
			naechster = sid
	if naechster == "":
		return
	# Der ballnahe Verteidiger geht heraus, aber nicht bis zum Ball: er stellt
	# sich in die Wurfbahn.
	var eigen: Vector2 = grundpunkt(naechster)
	laufweg(naechster, eigen.lerp(ballpunkt, clampf(0.30 * staerke, 0.1, 0.5)), 1.5)
	for pos2 in spieler.keys():
		if str(pos2) == "TW":
			continue
		var sid2: String = str((spieler[pos2] as Dictionary).get("sid", ""))
		if sid2 == "" or sid2 == naechster:
			continue
		var p2: Vector2 = grundpunkt(sid2)
		# Nachbarn ruecken zur Ballseite, ohne ihren Block zu verlassen.
		var schub: float = clampf((ballpunkt.y - p2.y) * 0.22, -1.3, 1.3) * staerke
		laufweg(sid2, p2 + Vector2(0.0, schub), 1.4, TEMPO * 0.8)

## Alle Laufwege beenden — die Mannschaften gehen zurueck in die Formation.
func laufwege_loesen() -> void:
	_laufwege.clear()

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

	# Ballspur: je aelter, desto blasser. Damit bleibt der Ball auch bei
	# schnellen Pässen mit dem Auge verfolgbar.
	if lebendig and _spur.size() >= 2:
		for i in range(_spur.size() - 1):
			var a: Dictionary = _spur[i]
			var b2: Dictionary = _spur[i + 1]
			var alter: float = clampf(float(a["rest"]) / 0.42, 0.0, 1.0)
			if alter <= 0.02:
				continue
			draw_line(_m(a["punkt"]), _m(b2["punkt"]),
				Color(1.0, 0.93, 0.72, alter * 0.42), maxf(s * 0.14 * alter, 1.0), true)

	# Laufwege: eine dünne Linie zeigt, wohin sich ein Spieler gerade löst.
	if lebendig:
		for sid_l in _laufwege.keys():
			var l2: Dictionary = _laufwege[sid_l]
			var von: Vector2 = spielerpunkt(str(sid_l))
			var nach: Vector2 = l2["punkt"]
			if von.distance_to(nach) < 0.5:
				continue
			var kraft: float = clampf(float(l2["rest"]) / maxf(float(l2["dauer"]), 0.01), 0.0, 1.0)
			_gestrichelt(von, nach, Color(1, 1, 1, 0.26 * kraft), s)

	# Ball mit weichem Schein
	var bp := _m(_ballpunkt() if lebendig else ball)
	var br: float = maxf(s * 0.3, 3.0)
	draw_circle(bp, br * 2.1, Color(1, 0.95, 0.8, 0.10))
	draw_circle(bp, br, Color("#f7f2e4"))
	draw_arc(bp, br, 0.0, TAU, 12, Color("#2a2118"), maxf(s * 0.05, 1.0))

## Eine gestrichelte Linie zwischen zwei Meterpunkten — fuer Laufwege.
func _gestrichelt(von: Vector2, nach: Vector2, farbe: Color, s: float) -> void:
	var strecke: float = von.distance_to(nach)
	var stuecke: int = clampi(int(strecke / 0.6), 2, 24)
	for i in range(stuecke):
		if i % 2 == 1:
			continue
		var t0: float = float(i) / float(stuecke)
		var t1: float = float(i + 1) / float(stuecke)
		draw_line(_m(von.lerp(nach, t0)), _m(von.lerp(nach, t1)), farbe, maxf(s * 0.07, 1.0), true)

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
		var stelle: Vector2
		if greift_an or ist_tw:
			# Angreifer stehen breit verteilt: der Name passt unter den Kreis.
			stelle = p + Vector2(-breite * 0.5, r + groesse * 1.15)
		else:
			# Sechs Abwehrspieler stehen auf elf Metern uebereinander — dort
			# stapeln sich Namen ueber den Kreisen zu einem Block. Zur eigenen
			# Torseite hin ist dagegen Platz, und jeder Name steht auf der Hoehe
			# seines Spielers.
			var zum_tor: float = -1.0 if nach_rechts else 1.0
			var seitlich: float = (r + 4.0) * zum_tor
			stelle = p + Vector2(seitlich - (breite if zum_tor < 0.0 else 0.0), groesse * 0.34)
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
