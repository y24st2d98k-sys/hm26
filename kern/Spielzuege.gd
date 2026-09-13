class_name Spielzuege
extends RefCounted
## Das Spielbuch — einstudierte Spielzüge und wann sie gelaufen werden.
##
## Bis hierher entschied die Simulation jeden Angriff aus Reglern und
## Positionsstärken. Das ist gut kalibriert, aber es ist keine Handschrift:
## zwei Mannschaften mit demselben Kader spielen identisch, egal wer an der
## Seitenlinie steht. Handball lebt aber von einstudierten Abläufen — Kreuz,
## Sperre, Einläufer, Parallelstoß —, und welchen man wann laufen lässt, ist
## die eigentliche Trainerarbeit zwischen zwei Spielen.
##
## Drei Regeln halten das System ehrlich:
##
## 1. Ein Spielzug ist kein Gewinn, sondern ein Tausch. Jeder verschiebt die
##    Wurfverteilung, hebt die Abschlussqualität gegen die eine Deckung und
##    senkt sie gegen die andere; die Faktoren über alle vier Deckungen mitteln
##    sich zu eins. Wer blind einen Zug einträgt, gewinnt nichts. Wer ihn zur
##    Deckung des Gegners passend wählt, gewinnt spürbar.
## 2. Ein Spielzug wirkt nur, soweit er einstudiert ist. Frisch eingetragen
##    passiert nichts; das kostet Wochen.
## 3. Es gibt fünf Plätze im Spielbuch. Was nicht drinsteht, verfällt. Man kann
##    nicht alles können.

## Situationen, denen ein Zug zugeordnet wird. Die Reihenfolge ist zugleich die
## Prüfreihenfolge in der Partie: die speziellste Lage gewinnt.
const SITUATIONEN := [
	{"id": "unterzahl", "name": "In Unterzahl", "text": "Ein Mann weniger auf dem Feld."},
	{"id": "ueberzahl", "name": "In Überzahl", "text": "Der Gegner hat jemanden draußen."},
	{"id": "schluss", "name": "Letzte fünf Minuten", "text": "Enges Spiel, Schlussphase."},
	{"id": "nach_auszeit", "name": "Nach der Auszeit", "text": "Der erste Angriff nach einer grünen Karte."},
	{"id": "standard", "name": "Normaler Angriff", "text": "Alles andere."},
]

## Der Katalog.
##
## `gegen` mittelt sich über die vier Deckungen zu 1.0 — ein Zug ist nie
## pauschal gut. `guete` ist der Zuschlag auf die Abschlussqualität in Punkten
## der internen Skala, `fehler` und `siebenmeter` sind Faktoren, `wurf` schiebt
## die Wurfverteilung zu den genannten Positionen.
const ZUEGE := {
	"kreuz_rueckraum": {
		"name": "Kreuzbewegung im Rückraum",
		"text": "Rückraum Mitte und Links kreuzen. Reißt eine geschlossene Deckung auf — gegen eine offensive läuft man sich fest.",
		"wurf": {"RL": 1.5, "RM": 1.4, "RR": 1.3},
		"guete": 2.4, "fehler": 1.06, "siebenmeter": 1.0, "dauer": 1.04,
		"gegen": {"6-0": 1.22, "5-1": 1.06, "3-2-1": 0.86, "4-2": 0.86},
		"anspruch": 1.0,
	},
	"sperre_kreis": {
		"name": "Sperre am Kreis",
		"text": "Der Kreisläufer stellt, der Rückraum zieht ab. Der Klassiker gegen eine tiefe Deckung.",
		"wurf": {"RL": 1.3, "RM": 1.35, "RR": 1.3, "KM": 0.75},
		"guete": 2.8, "fehler": 1.0, "siebenmeter": 0.94, "dauer": 1.0,
		"gegen": {"6-0": 1.18, "5-1": 1.14, "3-2-1": 0.90, "4-2": 0.78},
		"anspruch": 0.9,
	},
	"kreisanspiel": {
		"name": "Kreisanspiel",
		"text": "Konsequent auf den Kreisläufer. Bringt Tore aus kurzer Distanz und zieht Siebenmeter — aber nur mit einem Kreisläufer, der sich durchsetzt.",
		"wurf": {"KM": 2.4, "LA": 0.8, "RA": 0.8},
		"guete": 1.2, "fehler": 1.14, "siebenmeter": 1.34, "dauer": 0.96,
		"gegen": {"6-0": 0.84, "5-1": 1.00, "3-2-1": 1.14, "4-2": 1.22},
		"anspruch": 0.8,
	},
	"einlaeufer": {
		"name": "Einläufer",
		"text": "Ein Außen läuft in den Kreis ein — zwei am Kreis. Zerlegt offene Deckungen, gegen ein 6-0 steht man sich im Weg.",
		"wurf": {"KM": 1.7, "RL": 1.2, "RR": 1.2, "LA": 0.5, "RA": 0.5},
		"guete": 2.2, "fehler": 1.1, "siebenmeter": 1.12, "dauer": 1.05,
		"gegen": {"6-0": 0.80, "5-1": 1.02, "3-2-1": 1.22, "4-2": 1.16},
		"anspruch": 1.15,
	},
	"parallelstoss": {
		"name": "Parallelstoß",
		"text": "Die ganze Reihe verschiebt eine Position. Zwingt jede Deckung zum Mitgehen und sucht die Lücke am Ende der Bewegung.",
		"wurf": {"LA": 1.25, "RL": 1.15, "RR": 1.15, "RA": 1.25},
		"guete": 1.8, "fehler": 0.96, "siebenmeter": 1.0, "dauer": 1.06,
		"gegen": {"6-0": 1.10, "5-1": 1.10, "3-2-1": 0.94, "4-2": 0.86},
		"anspruch": 0.85,
	},
	"zweite_welle": {
		"name": "Zweite Welle",
		"text": "Schnelle Mitte, ehe die Deckung steht. Kurze Angriffe, viele Abschlüsse — und mehr verlorene Bälle.",
		"wurf": {"LA": 1.3, "RA": 1.3, "RM": 1.2},
		"guete": 2.6, "fehler": 1.22, "siebenmeter": 0.9, "dauer": 0.76,
		"gegen": {"6-0": 1.12, "5-1": 1.06, "3-2-1": 0.94, "4-2": 0.88},
		"anspruch": 0.95,
	},
	"aussenueberzahl": {
		"name": "Flügelüberzahl",
		"text": "Den Ball schnell auf die freie Seite ziehen. Wenn jemand draußen sitzt, ist der Flügel offen.",
		"wurf": {"LA": 2.1, "RA": 2.1, "KM": 0.8},
		"guete": 2.0, "fehler": 0.94, "siebenmeter": 1.06, "dauer": 0.9,
		"gegen": {"6-0": 1.04, "5-1": 1.04, "3-2-1": 0.98, "4-2": 0.94},
		"anspruch": 0.75,
	},
	"ballhalten": {
		"name": "Ball halten",
		"text": "Kein Risiko, kein früher Abschluss. Nimmt Zeit von der Uhr, wenn man führt — und Tore, wenn man sie bräuchte.",
		"wurf": {"RM": 1.2, "RL": 1.1, "RR": 1.1},
		"guete": -1.6, "fehler": 0.72, "siebenmeter": 1.0, "dauer": 1.24,
		"gegen": {"6-0": 1.02, "5-1": 1.0, "3-2-1": 1.0, "4-2": 0.98},
		"anspruch": 0.6,
	},
	"stossbewegung": {
		"name": "Stoßbewegung Mitte",
		"text": "Der Mittelmann stößt konsequent in die Lücke zwischen den Innenblock. Zieht Zeitstrafen — und Kontakt.",
		"wurf": {"RM": 1.9, "KM": 1.2},
		"guete": 1.4, "fehler": 1.08, "siebenmeter": 1.28, "dauer": 0.94,
		"gegen": {"6-0": 1.06, "5-1": 1.12, "3-2-1": 0.98, "4-2": 0.84},
		"anspruch": 0.9,
	},
}

## So viele Züge passen ins Spielbuch. Mehr wäre keine Handschrift mehr.
const PLAETZE := 5
const START_EINSTUDIERT := 30.0
const UNTERGRENZE := 10.0
## Was eine Trainingswoche an einem Zug bringt.
const WOCHE := 5.2
## Was ein Pflichtspiel bringt, in dem der Zug wirklich gelaufen ist.
const PARTIE := 3.0
## Was ein Zug verliert, der nicht im Spielbuch steht.
const VERFALL := 1.6

static func leeres_buch() -> Dictionary:
	var b := {"zuordnung": {}, "einstudiert": {}}
	for s in SITUATIONEN:
		b["zuordnung"][str((s as Dictionary)["id"])] = ""
	return b

## Holt das Spielbuch eines Vereins und legt es an, falls es fehlt.
static func buch(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("spielbuch") or (v["spielbuch"] as Dictionary).is_empty():
		v["spielbuch"] = leeres_buch()
	return v["spielbuch"]

## Welcher Zug in dieser Situation läuft — oder "" für gar keinen.
static func zug_fuer(b: Dictionary, situation: String) -> String:
	return str((b.get("zuordnung", {}) as Dictionary).get(situation, ""))

static func einstudiert(b: Dictionary, zug: String) -> float:
	if zug == "":
		return 0.0
	return clampf(float((b.get("einstudiert", {}) as Dictionary).get(zug, 0.0)), 0.0, 100.0)

## Alle Züge, die gerade irgendeiner Situation zugeordnet sind.
static func belegte(b: Dictionary) -> Array:
	var raus: Array = []
	for s in (b.get("zuordnung", {}) as Dictionary).values():
		if str(s) != "" and not raus.has(str(s)):
			raus.append(str(s))
	return raus

## Trägt einen Zug ein. Gibt zurück, ob es geklappt hat — mehr als PLAETZE
## verschiedene Züge nimmt das Spielbuch nicht auf.
static func zuordnen(d: Dictionary, cid: String, situation: String, zug: String) -> bool:
	var b := buch(d, cid)
	if zug != "" and not ZUEGE.has(zug):
		return false
	var vorher: Array = belegte(b)
	if zug != "" and not vorher.has(zug) and vorher.size() >= PLAETZE:
		return false
	(b["zuordnung"] as Dictionary)[situation] = zug
	if zug != "" and not (b["einstudiert"] as Dictionary).has(zug):
		# Ein neu aufgenommener Zug ist nicht bei null: die Grundform kennt
		# jeder Profi, es fehlt nur das Zusammenspiel.
		(b["einstudiert"] as Dictionary)[zug] = START_EINSTUDIERT
	return true

# ------------------------------------------------------------- Fortschritt ---

## Wochenlauf: was im Buch steht, wird trainiert; der Rest verfällt.
static func wochenwechsel(d: Dictionary) -> void:
	for cid in d["vereine"].keys():
		_verein_woche(d, str(cid))

static func _verein_woche(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var b := buch(d, cid)
	var aktiv: Array = belegte(b)
	if aktiv.is_empty():
		return
	var qualitaet: float = clampf(0.6 + Training.trainerqualitaet(d, cid, "taktik") / 13.0, 0.6, 1.6)
	if str((v.get("training", {}) as Dictionary).get("schwerpunkt", "")) == "taktik":
		qualitaet *= 1.45
	# Die Trainingszeit teilt sich auf: wer fünf Züge im Buch hat, bekommt
	# jeden langsamer eingeschliffen als jemand mit zweien. Das ist der Preis
	# für ein dickes Spielbuch.
	var teilung: float = 1.0 / sqrt(maxf(float(aktiv.size()), 1.0))
	var e: Dictionary = b["einstudiert"]
	for zug in e.keys():
		var alt: float = float(e[zug])
		if aktiv.has(str(zug)):
			var anspruch: float = float((ZUEGE[zug] as Dictionary)["anspruch"])
			var gewinn: float = WOCHE * qualitaet * teilung / maxf(anspruch, 0.4)
			e[zug] = clampf(alt + gewinn * (1.0 - alt / 116.0), 0.0, 100.0)
		else:
			e[zug] = maxf(alt - VERFALL, UNTERGRENZE)

## Nach der Partie: gelaufene Züge sitzen ein Stück besser.
static func partie_verbuchen(d: Dictionary, cid: String, gelaufen: Dictionary) -> void:
	if not d["vereine"].has(cid) or gelaufen.is_empty():
		return
	var b := buch(d, cid)
	var e: Dictionary = b["einstudiert"]
	var gesamt: float = 0.0
	for n in gelaufen.values():
		gesamt += float(n)
	if gesamt <= 0.0:
		return
	for zug in gelaufen.keys():
		if not e.has(zug):
			continue
		var anteil: float = float(gelaufen[zug]) / gesamt
		var alt: float = float(e[zug])
		e[zug] = clampf(alt + PARTIE * anteil * (1.0 - alt / 116.0), 0.0, 100.0)

# ---------------------------------------------------------------- Wirkung ---

## Die Wirkung eines Zuges gegen eine bestimmte Deckung, schon mit dem
## Einstudierungsgrad verrechnet.
##
## Rückgabe: {"guete", "fehler", "siebenmeter", "dauer", "wurf"}. Bei einem
## nicht eingetragenen oder gar nicht einstudierten Zug ist alles neutral —
## die Simulation rechnet dann exakt wie vorher.
static func wirkung(zug: String, grad: float, deckung: String) -> Dictionary:
	var neutral := {"guete": 0.0, "fehler": 1.0, "siebenmeter": 1.0, "dauer": 1.0, "wurf": {}}
	if zug == "" or not ZUEGE.has(zug):
		return neutral
	var z: Dictionary = ZUEGE[zug]
	var g: float = clampf(grad / 100.0, 0.0, 1.0)
	if g <= 0.0:
		return neutral
	# Der Deckungsfaktor entscheidet, ob sich der Zug lohnt. Er wirkt auf den
	# Nutzen, nicht auf die Kosten: ein Kreisanspiel gegen ein 6-0 bringt
	# weniger, kostet aber genauso viele Bälle.
	var passung: float = float((z["gegen"] as Dictionary).get(deckung, 1.0))
	var wurf := {}
	for pos in (z["wurf"] as Dictionary).keys():
		wurf[pos] = 1.0 + (float(z["wurf"][pos]) - 1.0) * g
	return {
		"guete": float(z["guete"]) * passung * g,
		"fehler": 1.0 + (float(z["fehler"]) - 1.0) * g,
		"siebenmeter": 1.0 + (float(z["siebenmeter"]) - 1.0) * g,
		"dauer": 1.0 + (float(z["dauer"]) - 1.0) * g,
		"wurf": wurf,
	}

static func name_von(zug: String) -> String:
	if zug == "" or not ZUEGE.has(zug):
		return "kein Spielzug"
	return str((ZUEGE[zug] as Dictionary)["name"])

static func stufe_text(grad: float) -> String:
	if grad >= 88.0:
		return "sitzt blind"
	elif grad >= 68.0:
		return "einstudiert"
	elif grad >= 46.0:
		return "im Aufbau"
	elif grad >= 26.0:
		return "angerissen"
	return "kaum geübt"

## Ob sich eine Aussage über die Deckung überhaupt lohnt.
##
## "Ball halten" läuft gegen jede Deckung fast gleich. Trotzdem best- und
## schlechtestgeeignete Deckung anzuzeigen, machte aus einem Rundungsfehler
## eine Empfehlung — und wer danach ginge, entschiede auf Rauschen.
const SPREIZUNG_MINDEST := 0.10

static func deckungsabhaengig(zug: String) -> bool:
	if not ZUEGE.has(zug):
		return false
	var werte: Array = ((ZUEGE[zug] as Dictionary)["gegen"] as Dictionary).values()
	var hoch := -99.0
	var tief := 99.0
	for w in werte:
		hoch = maxf(hoch, float(w))
		tief = minf(tief, float(w))
	return hoch - tief >= SPREIZUNG_MINDEST

## Gegen welche Deckung dieser Zug am besten läuft — für die Oberfläche.
static func beste_deckung(zug: String) -> String:
	if not ZUEGE.has(zug):
		return ""
	var best := ""
	var bw := -99.0
	for dck in ((ZUEGE[zug] as Dictionary)["gegen"] as Dictionary).keys():
		var w: float = float(((ZUEGE[zug] as Dictionary)["gegen"] as Dictionary)[dck])
		if w > bw:
			bw = w
			best = str(dck)
	return best

static func schlechteste_deckung(zug: String) -> String:
	if not ZUEGE.has(zug):
		return ""
	var schlecht := ""
	var sw := 99.0
	for dck in ((ZUEGE[zug] as Dictionary)["gegen"] as Dictionary).keys():
		var w: float = float(((ZUEGE[zug] as Dictionary)["gegen"] as Dictionary)[dck])
		if w < sw:
			sw = w
			schlecht = str(dck)
	return schlecht

# -------------------------------------------------------- Computertrainer ---

## Ein Spielbuch für einen Computerverein. Es soll zum Kader passen, nicht
## zufällig sein — sonst spielt die halbe Liga Einläufer ohne Kreisläufer.
static func ki_buch_anlegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if bool(v.get("ist_mensch", false)):
		return
	var b := buch(d, cid)
	var kreis: float = _positionsstaerke(d, cid, "KM")
	var aussen: float = maxf(_positionsstaerke(d, cid, "LA"), _positionsstaerke(d, cid, "RA"))
	var rueckraum: float = _positionsstaerke(d, cid, "RL")
	var standard: String = "sperre_kreis"
	if kreis > rueckraum + 1.2:
		standard = "kreisanspiel"
	elif aussen > rueckraum + 1.0:
		standard = "parallelstoss"
	elif rueckraum > kreis + 1.5:
		standard = "kreuz_rueckraum"
	zuordnen(d, cid, "standard", standard)
	zuordnen(d, cid, "ueberzahl", "aussenueberzahl")
	# Nicht jeder Verein mauert in Unterzahl — manche ziehen den Angriff
	# durch. Waeren alle gleich, verschoebe das Spielbuch die Ballbesitzzahl
	# der ganzen Liga.
	zuordnen(d, cid, "unterzahl", "ballhalten" if Namen.zufall() < 0.5 else "sperre_kreis")
	zuordnen(d, cid, "schluss", "stossbewegung" if Namen.zufall() < 0.65 else "ballhalten")
	# Die Computertrainer starten eingespielt: ihr Spielbuch steht seit Jahren.
	# Ohne das käme die ganze Liga wie frisch zusammengewürfelt daher.
	for zug in belegte(b):
		(b["einstudiert"] as Dictionary)[zug] = Namen.bereich(64.0, 88.0)

static func _positionsstaerke(d: Dictionary, cid: String, pos: String) -> float:
	var best := 0.0
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp["ist_torwart"]):
			continue
		best = maxf(best, Spielerfabrik.angriff_auf(sp, pos))
	return best
