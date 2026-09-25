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

## Und die Angriffsformation richtet sich nach dem, was eingestellt ist.
##
## Bis hierher stand jeder Angriff gleich da — ein Kreisfokus sah aus wie ein
## Aussenfokus, und wer die Einstellung aenderte, sah keinen Unterschied. Die
## Zahlen sind Meter vom linken Rand; das Tor steht bei x = 40, die
## Sechsmeterlinie bei etwa x = 34, die Neunmeterlinie bei x = 31.
const ANGRIFF_SYSTEME := {
	# Der Lehrbuchangriff: drei Rueckraumspieler, zwei Aussen, ein Kreis.
	"positionsangriff": {
		"LA": Vector2(30.5, 2.4), "RL": Vector2(27.5, 6.4), "RM": Vector2(26.0, 10.0),
		"RR": Vector2(27.5, 13.6), "RA": Vector2(30.5, 17.6), "KM": Vector2(34.6, 10.0),
	},
	# Alles auf den Kreis: der Rueckraum rueckt auf, die Aussen ziehen ein und
	# binden ihre Verteidiger nah am Kreis.
	"kreisfokus": {
		"LA": Vector2(31.4, 3.6), "RL": Vector2(28.6, 6.9), "RM": Vector2(27.2, 10.0),
		"RR": Vector2(28.6, 13.1), "RA": Vector2(31.4, 16.4), "KM": Vector2(34.9, 9.2),
	},
	# Ueber aussen: die Fluegel gehen weit und hoch, der Rueckraum zieht die
	# Deckung in die Mitte.
	"aussenfokus": {
		"LA": Vector2(32.2, 1.5), "RL": Vector2(27.0, 6.0), "RM": Vector2(25.4, 10.0),
		"RR": Vector2(27.0, 14.0), "RA": Vector2(32.2, 18.5), "KM": Vector2(34.4, 10.6),
	},
	# Aus dem Rueckraum: die drei gehen an die Neun, der Kreis bindet zwei.
	"rueckraumfokus": {
		"LA": Vector2(30.0, 2.6), "RL": Vector2(29.4, 6.8), "RM": Vector2(28.6, 10.0),
		"RR": Vector2(29.4, 13.2), "RA": Vector2(30.0, 17.4), "KM": Vector2(34.7, 10.0),
	},
	# Tempospiel: breit und hoch, damit der erste Pass nach vorn geht.
	"tempospiel": {
		"LA": Vector2(31.0, 1.8), "RL": Vector2(26.2, 5.6), "RM": Vector2(24.6, 10.0),
		"RR": Vector2(26.2, 14.4), "RA": Vector2(31.0, 18.2), "KM": Vector2(34.6, 10.0),
	},
}
## Sechs Plaetze vor dem eigenen Tor. Frueher lagen die beiden Innenblocker
## fast deckungsgleich auf der Mittelachse — ihre Namen ueberdeckten sich.
const ABWEHR_RECHTS := [
	Vector2(33.5, 4.4), Vector2(33.8, 7.0), Vector2(34.0, 9.0), Vector2(34.0, 11.0),
	Vector2(33.8, 13.0), Vector2(33.5, 15.6),
]

## Die Abwehr steht so, wie sie eingestellt ist.
##
## Vorher stand jede Abwehr als flache Sechserkette da, egal ob 6:0 oder
## 3:2:1 eingestellt war. Damit war der Vorschau nicht zu entnehmen, wer
## eigentlich wo steht — man musste raten. Die Zahlen sind Meter vom linken
## Rand des Feldes aus; das Tor steht bei x = 40, die Sechsmeterlinie also bei
## etwa x = 34, die Neunmeterlinie bei x = 31.
##
## Die Reihenfolge ist die der Abwehrplätze: Platz 1 aussen links bis Platz 6
## aussen rechts, die vorgezogenen Spieler an ihrer natuerlichen Stelle in
## der Kette.
const ABWEHR_SYSTEME := {
	"6-0": [
		Vector2(33.5, 4.4), Vector2(33.8, 7.0), Vector2(34.0, 9.0), Vector2(34.0, 11.0),
		Vector2(33.8, 13.0), Vector2(33.5, 15.6),
	],
	"5-1": [
		Vector2(33.5, 4.6), Vector2(33.9, 7.4), Vector2(30.6, 10.0), Vector2(34.0, 10.0),
		Vector2(33.9, 12.6), Vector2(33.5, 15.4),
	],
	"4-2": [
		Vector2(33.6, 5.0), Vector2(31.2, 7.6), Vector2(33.9, 8.6), Vector2(33.9, 11.4),
		Vector2(31.2, 12.4), Vector2(33.6, 15.0),
	],
	"3-2-1": [
		Vector2(33.6, 5.2), Vector2(31.6, 7.4), Vector2(29.9, 10.0), Vector2(33.9, 10.0),
		Vector2(31.6, 12.6), Vector2(33.6, 14.8),
	],
}

## Wie die sechs Plaetze in jedem System heissen. Kuerzel fuers Trikot, der
## ganze Name steht in der Aufstellungsliste daneben.
const ABWEHR_ROLLEN := {
	"6-0": ["Außen links", "Halb links", "Innen links", "Innen rechts", "Halb rechts", "Außen rechts"],
	"5-1": ["Außen links", "Halb links", "Vorgezogen", "Mitte", "Halb rechts", "Außen rechts"],
	"4-2": ["Außen links", "Vorgezogen links", "Innen links", "Innen rechts", "Vorgezogen rechts", "Außen rechts"],
	"3-2-1": ["Außen links", "Halb links vor", "Spitze", "Mitte", "Halb rechts vor", "Außen rechts"],
}
const ABWEHR_KUERZEL := {
	"6-0": ["AL", "HL", "IL", "IR", "HR", "AR"],
	"5-1": ["AL", "HL", "V", "M", "HR", "AR"],
	"4-2": ["AL", "VL", "IL", "IR", "VR", "AR"],
	"3-2-1": ["AL", "HL", "S", "M", "HR", "AR"],
}

## Ist das eine Abwehrplatz-Kennung (A1 bis A6)?
static func ist_abwehrplatz(pos: String) -> bool:
	return pos.length() == 2 and pos.begins_with("A") and pos.substr(1, 1).is_valid_int()

## Der Platz eines Abwehrspielers im eingestellten System, 0-basiert.
static func abwehr_index(pos: String) -> int:
	return clampi(int(pos.substr(1, 1)) - 1, 0, 5)

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
## Welches Abwehrsystem gezeichnet wird: "6-0", "5-1", "4-2" oder "3-2-1".
##
## Es gab genau diese eine Variable fuer beide Mannschaften, und die
## Live-Ansicht setzte sie nie. Auf der Platte stand deshalb jede Abwehr als
## flache Sechserkette, egal was die beiden Mannschaften eingestellt hatten —
## eine 3-2-1 war von einer 6-0 nicht zu unterscheiden. Die Vorschau im
## Taktikbildschirm zeigt eine Mannschaft und benutzt weiter dieses Feld; die
## Live-Ansicht setzt die beiden darunter.
var abwehr_system: String = "6-0"
var abwehr_system_heim: String = ""
var abwehr_system_gast: String = ""
## Dasselbe fuer den Angriff.
var angriff_system: String = "positionsangriff"
var angriff_system_heim: String = ""
var angriff_system_gast: String = ""
var puls: float = 50.0
var zeige_puls: bool = true
## Hochformat: das Feld steht, statt zu liegen. Die Aufstellungsvorschau nutzt
## das, weil daneben die beiden Formationen untereinander Platz brauchen.
var hochkant: bool = false

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
var _rolle: Dictionary = {}      # sid -> {"pos","seite","greift_an","index","rechts"}
var _lauftempo: Dictionary = {}  # sid -> Vector2, Metern je Sekunde
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
	_ballnah_bestimmen()
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
			# Wie schnell er gerade laeuft — daraus wird die Bewegungsspur.
			_lauftempo[sid] = weg / laenge * (schritt / maxf(delta, 0.001))
			bewegt = true
		else:
			_ist[sid] = ziel
			_lauftempo[sid] = Vector2.ZERO
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

## Wo der Ball waere, laege er am Boden. Der Unterschied zu _ballpunkt ist
## seine Flughoehe — und genau daraus wird der Schatten.
func _ballboden() -> Vector2:
	if _ball_t >= 1.0:
		return _ball_nach
	return _ball_von.lerp(_ball_nach, _ball_t)

## Wie hoch der Ball gerade fliegt, 0 bis 1.
func _ballhoehe() -> float:
	if _ball_t >= 1.0 or _ball_bogen <= 0.0:
		return 0.0
	return sin(_ball_t * PI)

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
			var ziel := _position(str(pos), greift_an, nach_rechts,
				int(eintrag.get("index", 0)), seite)
			_ziel[sid] = ziel
			# Wer er im System ist. Ohne das laesst sich die laufende Bewegung
			# ohne Ball nicht rechnen: ein Kreislaeufer wandert an der Sechs,
			# ein Aussen oeffnet sich, ein Verteidiger schiebt in der Kette.
			_rolle[sid] = {"pos": str(pos), "seite": seite, "greift_an": greift_an,
				"index": int(eintrag.get("index", 0)), "rechts": nach_rechts}
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
			_rolle.erase(sid2)
			_laufwege.erase(sid2)

## Wo steht dieser Spieler gerade? Faellt auf seinen Sollplatz zurueck.
func spielerpunkt(sid: String) -> Vector2:
	return _ist.get(sid, _ziel.get(sid, Vector2(20.0, 10.0)))

# ---------------------------------------------- Bewegung ohne den Ball ---
#
# Ein Handballspiel besteht nicht aus sieben Kreisen, die Baelle tauschen.
# Waehrend der Ball laeuft, wandert der Kreislaeufer an der Sechs, oeffnen sich
# die Aussen zur Ecke, kippt der Rueckraum zur Ballseite, schiebt die Deckung
# als Kette und tritt der ballnahe Verteidiger heraus.
#
# Das alles haengt hier an keinem Ereignis: es wird in jedem Bild aus der
# Ballposition gerechnet. Vorher bewegte sich nur, wer gerade einen Laufweg
# zugewiesen bekommen hatte — zwischen zwei Takten stand das Bild, und deshalb
# sah es aus, als laufe das Spiel in Schritten.

## Wie weit die Kette dem Ball in der Breite folgt, je Meter Ballversatz.
const BLOCK_FOLGT := 0.40
## So weit tritt der ballnahe Verteidiger heraus.
const HERAUS := 1.7
## Wie weit der Kreislaeufer an der Sechs wandert.
const KREIS_WANDERT := 3.8
## Wie weit sich ein Aussen oeffnet, wenn der Ball auf seiner Seite ist.
const AUSSEN_OEFFNET := 1.4
## Wie weit der Rueckraum zur Ballseite kippt, je Meter Ballversatz.
const RUECKRAUM_KIPPT := 0.26
## Amplitude der ruhigen Eigenbewegung in Metern. Niemand steht still.
const EIGENBEWEGUNG := 0.40

## Je Bild einmal gerechnet: wer auf jeder Seite dem Ball am naechsten steht.
var _ballnah: Dictionary = {}

func _ballnah_bestimmen() -> void:
	_ballnah.clear()
	var ball_p: Vector2 = _ballpunkt()
	for sid in _rolle.keys():
		var r: Dictionary = _rolle[sid]
		if bool(r["greift_an"]) or str(r["pos"]) == "TW":
			continue
		var seite: String = str(r["seite"])
		var d: float = (_ziel.get(sid, Vector2(20.0, 10.0)) as Vector2).distance_to(ball_p)
		if not _ballnah.has(seite) or d < float((_ballnah[seite] as Dictionary)["d"]):
			_ballnah[seite] = {"sid": str(sid), "d": d}

## Der laufende Versatz eines Spielers gegenueber seinem Formationsplatz.
func _bewegungsversatz(sid: String) -> Vector2:
	var r: Dictionary = _rolle.get(sid, {})
	if r.is_empty():
		return Vector2.ZERO
	var pos: String = str(r["pos"])
	var basis: Vector2 = _ziel.get(sid, Vector2(20.0, 10.0))
	var ball_p: Vector2 = _ballpunkt()
	var ph: float = float(_zittern.get(sid, 0.0))
	# Die ruhige Eigenbewegung: klein, langsam, fuer jeden anders.
	var v := Vector2(cos(_zeit * 0.85 + ph), sin(_zeit * 1.25 + ph)) * EIGENBEWEGUNG
	if pos == "TW":
		# Der Torwart stellt sich zum Ball und bleibt in seinem Kasten.
		v.y += clampf((ball_p.y - 10.0) * 0.20, -2.2, 2.2)
		return v
	var zum_tor: float = 1.0 if bool(r.get("rechts", true)) else -1.0
	if bool(r["greift_an"]):
		match pos:
			"KM":
				# Der Kreislaeufer geht dorthin, wo der Ball ist, und arbeitet
				# an der Linie.
				v.y += clampf((ball_p.y - basis.y) * 0.62, -KREIS_WANDERT, KREIS_WANDERT)
				v.x += zum_tor * sin(_zeit * 0.7 + ph) * 0.35
			"LA", "RA":
				# Der Aussen oeffnet sich zur Ecke, wenn der Ball auf seine
				# Seite kommt, und zieht sonst ein.
				var naehe: float = clampf(1.0 - absf(ball_p.y - basis.y) / 9.0, 0.0, 1.0)
				v.x += zum_tor * naehe * AUSSEN_OEFFNET
				v.y += (1.0 if basis.y > BREITE * 0.5 else -1.0) * naehe * 0.7
			_:
				# Der Rueckraum kippt zur Ballseite; wer den Ball hat, stoesst an.
				v.y += clampf((ball_p.y - basis.y) * RUECKRAUM_KIPPT, -2.4, 2.4)
				if str(hervorgehoben) == sid:
					v.x += zum_tor * 0.9
		return v
	# Abwehr: die Kette schiebt zum Ball, der ballnahe Mann tritt heraus.
	v.y += clampf((ball_p.y - basis.y) * BLOCK_FOLGT, -2.8, 2.8)
	var nah: Dictionary = _ballnah.get(str(r["seite"]), {})
	if str(nah.get("sid", "")) == sid:
		var weg: Vector2 = ball_p - basis
		var laenge: float = weg.length()
		if laenge > 0.25:
			v += weg / laenge * minf(HERAUS, laenge * 0.5)
	return v

## Wohin dieser Spieler gerade unterwegs ist — Laufweg vor Formationsplatz,
## und darauf der laufende Versatz.
func _laufziel(sid: String) -> Vector2:
	var v: Vector2 = _bewegungsversatz(sid)
	if _laufwege.has(sid):
		# Auf einem Laufweg bleibt nur ein Rest der Eigenbewegung — sonst zoege
		# der Versatz den Spieler von seinem Laufweg weg.
		return (_laufwege[sid] as Dictionary)["punkt"] + v * 0.25
	var ziel: Vector2 = _ziel.get(sid, Vector2(20.0, 10.0)) + v
	return Vector2(clampf(ziel.x, 0.5, LAENGE - 0.5), clampf(ziel.y, 0.6, BREITE - 0.6))

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

## Wie schnell ein Pass und ein Wurf fliegen, in Metern je Sekunde.
##
## Vorher bekam jeder Ballweg dieselbe Dauer, egal wie weit er war: ein Anspiel
## an den Kreis ueber zwei Meter brauchte so lange wie ein Pass ueber die halbe
## Feldbreite. Genau daran sah man, dass der Ball springt und nicht fliegt.
## Fuenfzehn Meter je Sekunde ist ein gespielter Pass, dreiundzwanzig ein Wurf —
## ein Bundesligawurf ist schneller, aber dann ist er auf dem Bildschirm nicht
## mehr zu sehen.
const PASS_TEMPO := 15.0
const WURF_TEMPO := 23.0

## Der Ball wandert flach zu einem Punkt (Pass, Dribbling, Anspiel).
## Gibt die Flugzeit zurueck, damit der Takt sich nach ihr richten kann.
func ball_spielen(nach: Vector2, hoechstens: float = 0.0) -> float:
	_ball_von = _ballpunkt()
	_ball_nach = nach
	var dauer: float = clampf(_ball_von.distance_to(nach) / PASS_TEMPO, 0.10, 0.80)
	if hoechstens > 0.0:
		dauer = minf(dauer, hoechstens)
	_ball_dauer = dauer
	_ball_bogen = 0.0
	_ball_t = 0.0
	return dauer

## Der Ball fliegt in hohem Bogen — ein Wurf.
func ball_werfen(nach: Vector2, hoehe: float = 1.6, hoechstens: float = 0.0) -> float:
	_ball_von = _ballpunkt()
	_ball_nach = nach
	var dauer: float = clampf(_ball_von.distance_to(nach) / WURF_TEMPO, 0.10, 0.60)
	if hoechstens > 0.0:
		dauer = minf(dauer, hoechstens)
	_ball_dauer = dauer
	_ball_bogen = hoehe
	_ball_t = 0.0
	return dauer

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
## Sucht eine Stelle fuer eine Beschriftung, an der keine andere steht.
##
## Die alte Fassung ging vier Schritte in eine Richtung und zeichnete dann
## trotzdem — bei sechs Abwehrspielern auf elf Metern reichte das nie, und die
## Namen lagen uebereinander. Sie merkte sich ausserdem auch die Stellen, die
## gar nicht frei waren, sodass die naechste Beschriftung falsch ausgewichen
## ist. Jetzt wird in beide Richtungen gesucht, abwechselnd und in wachsendem
## Abstand — der naechste freie Platz ist damit immer der naechstgelegene.
func _freie_stelle(stelle: Vector2, breite: float, hoehe: float, nach_unten: bool) -> Vector2:
	var schritt: float = hoehe + 2.0
	var erste: float = 1.0 if nach_unten else -1.0
	var gefunden: Vector2 = stelle
	var frei_gefunden := false
	for versuch in range(13):
		var versatz: float = 0.0
		if versuch > 0:
			var stufe: int = int((versuch + 1) / 2)
			versatz = float(stufe) * schritt * (erste if versuch % 2 == 1 else -erste)
		var kandidat: Vector2 = stelle + Vector2(0.0, versatz)
		if kandidat.y - hoehe < 0.0 or kandidat.y > size.y:
			continue
		if _ist_frei(kandidat, breite, hoehe):
			gefunden = kandidat
			frei_gefunden = true
			break
	if not frei_gefunden:
		return Vector2(-9999, -9999)
	_belegt.append(_kasten(gefunden, breite, hoehe))
	return gefunden

func _ist_frei(stelle: Vector2, breite: float, hoehe: float) -> bool:
	var kasten := _kasten(stelle, breite, hoehe)
	for r in _belegt:
		if (r as Rect2).intersects(kasten):
			return false
	return true

func _kasten(stelle: Vector2, breite: float, hoehe: float) -> Rect2:
	return Rect2(stelle - Vector2(1.0, hoehe), Vector2(breite + 2.0, hoehe + 3.0))

## Kuerzt eine Beschriftung auf die verfuegbare Breite — mit Auslassungspunkten,
## damit man sieht, dass gekuerzt wurde.
func _gekuerzt(schrift: Font, text: String, groesse: int, hoechstens: float) -> String:
	if schrift.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x <= hoechstens:
		return text
	var aus: String = text
	while aus.length() > 3:
		aus = aus.substr(0, aus.length() - 1)
		if schrift.get_string_size(aus + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x <= hoechstens:
			return aus + "…"
	return aus

## Mittelpunkt des Tores, auf das diese Seite wirft.
func tormitte(seite: String) -> Vector2:
	return Vector2(LAENGE - 0.3, 10.0) if seite == "heim" else Vector2(0.3, 10.0)

## Meter zu Bildpunkten. Im Hochformat steht das Feld auf dem Kopfende: die
## Laenge laeuft von unten nach oben, das Tor, auf das die eigene Mannschaft
## wirft, liegt oben.
##
## Gezeichnet wird ausschliesslich ueber diese Funktion — Torraeume, Boegen,
## Tore, Trikots, Namen. Deshalb genuegt es, hier die Achsen zu tauschen;
## nur die drei achsenparallelen Rechtecke brauchen _rechteck().
func _m(p: Vector2) -> Vector2:
	var q: Vector2 = Vector2(p.y, LAENGE - p.x) if hochkant else p
	var s := _skala()
	var versatz := Vector2((size.x - _feldbreite() * s) * 0.5, (size.y - _feldhoehe() * s) * 0.5)
	return versatz + q * s

## Ein achsenparalleles Rechteck aus zwei Eckpunkten in Metern — in beiden
## Ausrichtungen richtig herum.
func _rechteck(von: Vector2, bis: Vector2) -> Rect2:
	var a := _m(von)
	var b := _m(bis)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())

func _feldbreite() -> float:
	return BREITE if hochkant else LAENGE

func _feldhoehe() -> float:
	return LAENGE if hochkant else BREITE

func _skala() -> float:
	var rand := 14.0
	return minf((size.x - rand * 2.0) / _feldbreite(), (size.y - rand * 2.0) / _feldhoehe())

func _draw() -> void:
	var s := _skala()
	if s <= 0.5:
		return
	_belegt.clear()
	_punkte.clear()
	var feld := _rechteck(Vector2(0, 0), Vector2(LAENGE, BREITE))

	# Parkett mit angedeuteten Dielen — sonst wirkt die Flaeche wie ein Loch
	draw_rect(feld, Color("#182029"), true)
	var diele := Color(1, 1, 1, 0.012)
	var x := 0.0
	while x < LAENGE:
		draw_rect(_rechteck(Vector2(x, 0), Vector2(x + 1.25, BREITE)), diele, true)
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

	# Erst alle Koerper, dann alle Namen. Anders geht es nicht: eine
	# Beschriftung muss auch den Spielern ausweichen koennen, die erst danach
	# gezeichnet worden waeren — sonst landet ein Name auf einem Trikot, und
	# genau das war zu sehen.
	_entzerren(s)
	_zeichne_koerper("heim", s)
	_zeichne_koerper("gast", s)
	_zeichne_namen("heim", s)
	_zeichne_namen("gast", s)

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

	# Ball mit weichem Schein — und mit Schatten auf dem Parkett.
	#
	# Ein Wurf fliegt: das steht in der Flugbahn, war aber nicht zu sehen, weil
	# der Ball nur ein Kreis war, der sich verschiebt. Der Schatten bleibt am
	# Boden, der Ball steigt darueber und wird dabei groesser — daran liest man
	# die Hoehe, ohne dass irgendwo eine Zahl steht.
	var bp := _m(_ballpunkt() if lebendig else ball)
	var br: float = maxf(s * 0.3, 3.0)
	if lebendig:
		var hoehe: float = _ballhoehe()
		if hoehe > 0.01:
			var schatten := _m(_ballboden())
			draw_circle(schatten, br * (0.85 + hoehe * 0.35), Color(0, 0, 0, 0.30 - hoehe * 0.12))
		br *= 1.0 + hoehe * 0.30
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

## Wie weit zwei Trikots mindestens auseinanderstehen, in Radien.
const TRIKOT_ABSTAND := 2.15
const TRIKOT_ABSTAND_FREMD := 2.9

## Schiebt Trikots auseinander, die uebereinanderliegen wuerden.
##
## Der Kreislaeufer steht im Innenblock, der Aussen klebt am Abwehraussen — das
## ist Handball und soll so sein. Auf dem Bildschirm wird daraus aber ein
## einziger Klecks, in dem weder Nummer noch Positionsschild zu lesen sind.
## Deshalb werden zu dichte Paare ein Stueck auseinandergedrueckt, in
## Bildschirmkoordinaten und nur so weit, dass die Anordnung erhalten bleibt.
var _versatz: Dictionary = {}

func _entzerren(s: float) -> void:
	_versatz.clear()
	var schluessel: Array = []
	var lagen: Array = []
	for seite in ["heim", "gast"]:
		var spieler: Dictionary = szene.get(seite, {})
		var greift_an: bool = angreifer == seite
		var nach_rechts: bool = (seite == "heim")
		for pos in spieler.keys():
			var eintrag: Dictionary = spieler[pos]
			var sid_e: String = str(eintrag.get("sid", "%s_%s" % [seite, pos]))
			# Dieselbe Unterscheidung wie beim Zeichnen: ein Abwehrplatz steht
			# am eigenen Tor, nicht am fremden. Ohne sie rechnete das
			# Entzerren fuer die Abwehr Angriffskoordinaten aus und schob die
			# Trikots anschliessend dorthin.
			var im_block: bool = ist_abwehrplatz(str(pos))
			var platz: int = abwehr_index(str(pos)) if im_block else int(eintrag.get("index", 0))
			var meter: Vector2 = _position(str(pos), greift_an and not im_block, nach_rechts, platz, seite)
			if lebendig and _ist.has(sid_e):
				meter = _ist[sid_e]
			schluessel.append("%s|%s" % [seite, pos])
			lagen.append(_m(meter))
	var r: float = maxf(s * 0.46, 6.0)
	var mindest: float = r * TRIKOT_ABSTAND
	# Zwei Mannschaften auf demselben Fleck sind der schlimmste Fall: der
	# Kreislaeufer steht im Innenblock, und wenn sich dort gruen und schwarz
	# ueberdecken, liest man weder Nummer noch Schild. Ueber die Mannschaften
	# hinweg wird deshalb weiter auseinandergerueckt als innerhalb.
	var mindest_fremd: float = r * TRIKOT_ABSTAND_FREMD
	for _durchgang in range(4):
		for i in range(lagen.size()):
			for j in range(i + 1, lagen.size()):
				var gleiche_seite: bool = str(schluessel[i]).split("|")[0] == str(schluessel[j]).split("|")[0]
				mindest = r * (TRIKOT_ABSTAND if gleiche_seite else TRIKOT_ABSTAND_FREMD)
				var d: Vector2 = lagen[j] - lagen[i]
				var laenge: float = d.length()
				if laenge >= mindest:
					continue
				if laenge < 0.01:
					d = Vector2(0.0, 1.0)
					laenge = 0.01
				var schub: Vector2 = d.normalized() * (mindest - laenge) * 0.5
				lagen[i] = lagen[i] - schub
				lagen[j] = lagen[j] + schub
	for k in range(schluessel.size()):
		_versatz[schluessel[k]] = lagen[k]

## Wo ein Spieler gerade auf dem Bildschirm steht, samt Radius. Wird im ersten
## Durchgang gefuellt und im zweiten fuer die Namen gebraucht.
var _punkte: Dictionary = {}

## Erster Durchgang: Trikots, Rueckennummern, Positionsschilder.
func _zeichne_koerper(seite: String, s: float) -> void:
	var spieler: Dictionary = szene.get(seite, {})
	if spieler.is_empty():
		return
	var greift_an: bool = angreifer == seite
	var farbe: Color = heim_farbe if seite == "heim" else gast_farbe
	var nach_rechts: bool = (seite == "heim")
	var schrift := ThemeDB.fallback_font
	for pos in spieler.keys():
		var eintrag: Dictionary = spieler[pos]
		var sid_e: String = str(eintrag.get("sid", "%s_%s" % [seite, pos]))
		# Ein Abwehrplatz ist an seiner Kennung zu erkennen (A1 bis A6). So
		# koennen Angriff und Abwehr derselben Mannschaft zugleich auf dem Feld
		# stehen — der eine am fremden Tor, der andere am eigenen.
		var im_block: bool = ist_abwehrplatz(pos)
		var greift_an_hier: bool = greift_an and not im_block
		var platz: int = abwehr_index(pos) if im_block else int(eintrag.get("index", 0))
		var meter: Vector2 = _position(pos, greift_an_hier, nach_rechts, platz, seite)
		if lebendig and _ist.has(sid_e):
			# Hier stand ein Wippen von zehn Zentimetern, damit stehende Spieler
			# nicht wie Pfosten wirken. Es ist nicht mehr noetig: die Spieler
			# stehen nicht mehr, sondern laufen — siehe _bewegungsversatz.
			meter = _ist[sid_e]
		var p: Vector2 = _versatz.get("%s|%s" % [seite, pos], _m(meter))
		var r: float = maxf(s * 0.46, 6.0)
		var ist_tw: bool = pos == "TW"
		var f: Color = farbe.lightened(0.30) if ist_tw else farbe
		var bestraft: bool = str(eintrag.get("status", "")) == "strafe"
		if bestraft:
			f = Color("#5b6068")
		# Was gerade nicht bearbeitet wird, steht dunkler da: man sieht beide
		# Formationen, aber es ist klar, an welcher man arbeitet.
		var matt: bool = bool(eintrag.get("matt", false))
		if matt:
			f = f.lerp(Color("#101820"), 0.62)
		_punkte["%s|%s" % [seite, pos]] = {"p": p, "r": r, "f": f, "bestraft": bestraft or matt,
			"greift_an": greift_an_hier, "nach_rechts": nach_rechts, "ist_tw": ist_tw}
		# Wer laeuft, zieht eine kurze Spur hinter sich her. Das ist der
		# Unterschied zwischen einem Kreis, der an einer anderen Stelle steht,
		# und einem Spieler, der dorthin gelaufen ist.
		var tempo_v: Vector2 = _lauftempo.get(sid_e, Vector2.ZERO)
		if lebendig and tempo_v.length() > 2.2:
			var zurueck: Vector2 = _m(meter - tempo_v * 0.085) - p
			draw_line(p + zurueck, p, Color(f.r, f.g, f.b, 0.30), r * 1.15, true)
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
		var poskuerzel: String = str(eintrag.get("pos", pos))
		var aufdruck: String = str(nummer) if nummer > 0 else poskuerzel
		var pgroesse: int = maxi(int(s * (0.46 if nummer > 0 else 0.34)), 7)
		var pbreite: float = schrift.get_string_size(aufdruck, HORIZONTAL_ALIGNMENT_LEFT, -1, pgroesse).x
		var dunkel: bool = f.get_luminance() < 0.5
		draw_string(schrift, p + Vector2(-pbreite * 0.5, pgroesse * 0.36), aufdruck,
			HORIZONTAL_ALIGNMENT_LEFT, -1, pgroesse,
			Color(1, 1, 1, 0.9) if dunkel else Color(0, 0, 0, 0.75))

		# Das Positionskuerzel als kleines Schild ueber dem Kreis.
		#
		# Ohne das stand auf dem Feld nur eine Nummer und ein Name, und die
		# Frage "wer spielt gerade Rueckraum Mitte" liess sich nur beantworten,
		# indem man den Kader danebenlegte.
		var pgr: int = maxi(int(s * 0.30), 7)
		var pbr: float = schrift.get_string_size(poskuerzel, HORIZONTAL_ALIGNMENT_LEFT, -1, pgr).x
		# Ueber dem Kreis ist nur beim Angreifer Platz. In der Abwehr stehen
		# sechs Mann auf elf Metern, dort stiesse ein Schild ueber dem einen
		# gegen den Kreis des anderen — deshalb sitzt es dort zur Torseite hin.
		var schild: Rect2
		if greift_an or ist_tw:
			schild = Rect2(p + Vector2(-pbr * 0.5 - 3.0, -r - pgr * 1.55),
				Vector2(pbr + 6.0, pgr + 4.0))
		else:
			var zum_tor: float = -1.0 if nach_rechts else 1.0
			var links: float = p.x + (r + 2.0) * zum_tor - (pbr + 6.0 if zum_tor < 0.0 else 0.0)
			schild = Rect2(Vector2(links, p.y - pgr * 0.62), Vector2(pbr + 6.0, pgr + 4.0))
		draw_rect(schild, Color(0, 0, 0, 0.55), true)
		draw_rect(schild, Color(f.r, f.g, f.b, 0.85), false, maxf(s * 0.045, 1.0))
		draw_string(schrift, schild.position + Vector2(3.0, pgr + 0.5), poskuerzel,
			HORIZONTAL_ALIGNMENT_LEFT, -1, pgr, Color(1, 1, 1, 0.95))
		# Trikot und Schild sind Sperrflaechen fuer jede Beschriftung.
		_belegt.append(Rect2(p - Vector2(r, r), Vector2(r * 2.0, r * 2.0)))
		_belegt.append(schild)

## Zweiter Durchgang: die Namen, die jetzt allem ausweichen koennen.
func _zeichne_namen(seite: String, s: float) -> void:
	var spieler: Dictionary = szene.get(seite, {})
	if spieler.is_empty():
		return
	var schrift := ThemeDB.fallback_font
	for pos in spieler.keys():
		var lage: Dictionary = _punkte.get("%s|%s" % [seite, pos], {})
		if lage.is_empty():
			continue
		var roh: String = str((spieler[pos] as Dictionary).get("kurz", ""))
		if roh == "":
			continue
		# In der Abwehr bleibt der Name weg. Sechs Namen auf elf Metern sind
		# ein Block, in dem man nichts mehr liest; wer dort steht, sagt die
		# Aufstellungsleiste neben dem Feld.
		if not bool(lage["greift_an"]) and not bool(lage["ist_tw"]):
			continue
		var p: Vector2 = lage["p"]
		var r: float = lage["r"]
		var groesse: int = maxi(int(s * 0.40), 8)
		var beschriftung: String = _gekuerzt(schrift, roh, groesse, maxf(s * 5.5, 70.0))
		var breite: float = schrift.get_string_size(beschriftung, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
		var stelle: Vector2
		if bool(lage["greift_an"]) or bool(lage["ist_tw"]):
			# Angreifer stehen breit verteilt: der Name passt unter den Kreis.
			stelle = p + Vector2(-breite * 0.5, r + groesse * 1.15)
		else:
			# Sechs Abwehrspieler stehen auf elf Metern uebereinander. Zur
			# Feldmitte hin ist Platz, zum eigenen Tor hin endet gleich die
			# Seitenlinie — deshalb weisen die Namen nach innen.
			var nach_innen: float = 1.0 if bool(lage["nach_rechts"]) else -1.0
			var seitlich: float = (r + 5.0) * nach_innen
			stelle = p + Vector2(seitlich - (breite if nach_innen < 0.0 else 0.0), groesse * 0.34)
		stelle.x = clampf(stelle.x, 2.0, maxf(size.x - breite - 2.0, 2.0))
		stelle = _freie_stelle(stelle, breite, float(groesse), bool(lage["greift_an"]))
		# Findet sich kein freier Platz, bleibt der Name weg. Das Schild mit der
		# Position steht ohnehin da, und ein uebereinandergelegter Namensblock
		# sagt weniger als gar nichts.
		if stelle.x < -1000.0:
			continue
		draw_string(schrift, stelle + Vector2(0, 1), beschriftung,
			HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Color(0, 0, 0, 0.65))
		draw_string(schrift, stelle, beschriftung, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse,
			Color("#8d99a6") if bool(lage["bestraft"]) else Color("#dbe4ee"))

func _position(pos: String, greift_an: bool, nach_rechts: bool, index: int,
		seite: String = "") -> Vector2:
	if pos == "TW":
		return Vector2(1.2 if nach_rechts else LAENGE - 1.2, 10.0)
	if greift_an:
		var form: Dictionary = ANGRIFF_SYSTEME.get(_angriffsart(seite), ANGRIFF_RECHTS)
		var basis: Vector2 = form.get(pos, ANGRIFF_RECHTS.get(pos, Vector2(26.0, 10.0)))
		return basis if nach_rechts else Vector2(LAENGE - basis.x, basis.y)
	# In der Abwehr steht die Mannschaft vor dem eigenen Tor — und zwar so,
	# wie das eingestellte System es vorsieht.
	var kette: Array = ABWEHR_SYSTEME.get(_abwehrart(seite), ABWEHR_RECHTS)
	var i: int = clampi(index, 0, kette.size() - 1)
	var b: Vector2 = kette[i]
	return Vector2(LAENGE - b.x, b.y) if nach_rechts else b

## Welches Abwehrsystem diese Seite spielt. Ohne eigene Angabe das gemeinsame
## Feld — das ist der Fall in der Vorschau, die nur eine Mannschaft zeigt.
func _abwehrart(seite: String) -> String:
	var eigen: String = abwehr_system_heim if seite == "heim" else abwehr_system_gast
	return eigen if ABWEHR_SYSTEME.has(eigen) else abwehr_system

func _angriffsart(seite: String) -> String:
	var eigen: String = angriff_system_heim if seite == "heim" else angriff_system_gast
	return eigen if ANGRIFF_SYSTEME.has(eigen) else angriff_system

## Beide Formationen auf einem Feld: Angriff am fremden Tor, Abwehr am
## eigenen, Torwart dazwischen im eigenen Kasten.
##
## Vorher zeigte die Vorschau immer nur eine der beiden, und man musste
## umschalten, um zu sehen, was die andere macht. Zusammen passen sie ohne
## Gedraenge auf ein Feld — sie stehen ja an entgegengesetzten Enden. Was
## gerade nicht bearbeitet wird, steht dunkler da.
static func szene_beide(cid: String, betont_angriff: bool) -> Dictionary:
	var v: Dictionary = Welt.verein(cid)
	var auf: Dictionary = v.get("aufstellung", {})
	var aus := {}
	var i := 0
	for pos in (auf.get("angriff", {}) as Dictionary).keys():
		var sid: String = str(auf["angriff"][pos])
		if sid == "" or not Welt.daten["spieler"].has(sid):
			continue
		if str(pos) == "TW":
			continue
		var sp: Dictionary = Welt.spieler(sid)
		aus[pos] = {"sid": sid, "kurz": str(sp["nachname"]).substr(0, 9),
			"nummer": int(sp.get("nummer", 0)), "index": i, "matt": not betont_angriff}
		i += 1
	for pos2 in (auf.get("abwehr", {}) as Dictionary).keys():
		var sid2: String = str(auf["abwehr"][pos2])
		if sid2 == "" or not Welt.daten["spieler"].has(sid2):
			continue
		var sp2: Dictionary = Welt.spieler(sid2)
		var eintrag := {"sid": sid2, "kurz": str(sp2["nachname"]).substr(0, 9),
			"nummer": int(sp2.get("nummer", 0)), "index": 0, "matt": betont_angriff}
		if ist_abwehrplatz(str(pos2)):
			# Auf dem Trikot steht das Kuerzel des Platzes im eingestellten
			# System — "HL" sagt mehr als "A2".
			var system: String = str((v.get("taktik", {}) as Dictionary).get("abwehr", "6-0"))
			var kuerzel: Array = ABWEHR_KUERZEL.get(system, ABWEHR_KUERZEL["6-0"])
			eintrag["pos"] = str(kuerzel[abwehr_index(str(pos2))])
		if str(pos2) == "TW":
			# Den Torwart gibt es nur einmal, und er ist nie matt: er steht in
			# beiden Formationen im selben Tor.
			eintrag["matt"] = false
			aus["TW"] = eintrag
		else:
			aus[pos2] = eintrag
	return aus

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
