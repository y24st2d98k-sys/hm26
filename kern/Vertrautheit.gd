class_name Vertrautheit
extends RefCounted
## Wie gut eine Mannschaft ihre Formationen wirklich kann.
##
## Ohne dieses Konto ist ein Formationswechsel kostenlos: man stellt am
## Dienstag von 6-0 auf 3-2-1 um, und am Samstag läuft die offensive Deckung
## fehlerfrei. Das nimmt der wichtigsten taktischen Entscheidung des Spiels
## jedes Gewicht — wenn Umstellen nichts kostet, gibt es keinen Grund, bei
## etwas zu bleiben.
##
## Vertrautheit ist ein Konto je Formation, das durch Training und vor allem
## durch Pflichtspiele wächst und ohne Gebrauch langsam verfällt. Der Verein
## startet mit seiner Stammformation auf 100 — deshalb verschiebt das System
## die Kalibrierung der Liga nicht. Es kostet nur den, der wechselt.

## Was der Verein von Anfang an kann.
const START_STAMM := 100.0
## Was er von einer Formation weiß, die er nie gespielt hat. Null wäre falsch:
## Profis kennen jedes System, sie haben es nur nicht eingeschliffen.
const START_FREMD := 25.0
const UNTERGRENZE := 20.0

## Wie viel eine Trainingswoche bringt, wenn nichts weiter dazukommt.
const WOCHE_BASIS := 1.6
## Aufschlag, wenn die Woche auf Taktikschulung liegt.
const WOCHE_TAKTIK := 3.4
## Was ein Pflichtspiel in dieser Formation bringt. Ein Spiel schleift mehr ein
## als eine Trainingswoche — deshalb steht die Zahl deutlich darüber.
const PARTIE := 4.2
## Was eine ungenutzte Formation pro Woche verliert.
const VERFALL := 0.7

const ABWEHRFORMATIONEN := ["6-0", "5-1", "3-2-1", "4-2"]
const ANGRIFFSFORMATIONEN := ["positionsangriff", "tempospiel", "kreisfokus",
	"aussenfokus", "rueckraumfokus"]

# ------------------------------------------------------------- Anlegen ---

## Das Startkonto eines Vereins: die eigene Formation sitzt, der Rest nicht.
static func anlegen(taktik: Dictionary) -> Dictionary:
	var konto := {"abwehr": {}, "angriff": {}}
	for f in ABWEHRFORMATIONEN:
		konto["abwehr"][f] = START_STAMM if f == str(taktik.get("abwehr", "6-0")) else START_FREMD
	for f in ANGRIFFSFORMATIONEN:
		konto["angriff"][f] = START_STAMM if f == str(taktik.get("angriff", "positionsangriff")) else START_FREMD
	return konto

## Holt das Konto und legt es an, falls der Spielstand älter ist als dieses
## System. Jede lesende Stelle darf sich darauf verlassen, etwas zu bekommen.
static func konto(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("vertrautheit") or (v["vertrautheit"] as Dictionary).is_empty():
		v["vertrautheit"] = anlegen(v["taktik"])
	return v["vertrautheit"]

## Der Wert einer einzelnen Formation, 0..100.
static func wert(d: Dictionary, cid: String, bereich: String, formation: String) -> float:
	var k := konto(d, cid)
	return clampf(float((k.get(bereich, {}) as Dictionary).get(formation, START_FREMD)), 0.0, 100.0)

# -------------------------------------------------------------- Wirkung ---

## Der Faktor auf die Wirksamkeit einer Formation.
##
## Bei 100 ist er genau 1.0 — eine eingespielte Mannschaft bekommt keinen
## Bonus, sie bekommt nur keinen Abzug. Eine frisch umgestellte verliert bis
## zu zehn Prozent. Das ist genug, um eine Umstellung mitten in der Saison zur
## Entscheidung zu machen, und wenig genug, dass sie nie unmöglich ist.
static func faktor(d: Dictionary, cid: String, bereich: String, formation: String) -> float:
	return 0.90 + wert(d, cid, bereich, formation) / 100.0 * 0.10

## In Worten, für die Oberfläche.
static func stufe_text(v: float) -> String:
	if v >= 92.0:
		return "eingespielt"
	elif v >= 74.0:
		return "sitzt"
	elif v >= 52.0:
		return "im Aufbau"
	elif v >= 34.0:
		return "wackelig"
	return "fremd"

## Was die aktuelle Vertrautheit kostet, als Satz.
static func hinweis(d: Dictionary, cid: String) -> String:
	var v: Dictionary = d["vereine"][cid]
	var a: float = wert(d, cid, "abwehr", str(v["taktik"]["abwehr"]))
	var o: float = wert(d, cid, "angriff", str(v["taktik"]["angriff"]))
	var schlechter: float = minf(a, o)
	if schlechter >= 92.0:
		return "Beide Formationen sitzen. Die Mannschaft verliert nichts an der Umsetzung."
	elif schlechter >= 74.0:
		return "Die Abläufe stimmen weitgehend. Ein paar Prozent gehen noch verloren."
	elif schlechter >= 52.0:
		return "Die Mannschaft baut das System noch auf — das kostet spürbar Wirkung."
	elif schlechter >= 34.0:
		return "Das System ist noch nicht eingeschliffen. Rechnen Sie mit Aussetzern."
	return "Diese Formation hat die Mannschaft praktisch nie gespielt. Das wird man sehen."

## Wie lange es dauert, eine Formation einzuschleifen — in Wochen, grob.
static func wochen_bis(d: Dictionary, cid: String, bereich: String, formation: String) -> int:
	var fehlt: float = 92.0 - wert(d, cid, bereich, formation)
	if fehlt <= 0.0:
		return 0
	# Eine Woche bringt Training plus im Schnitt ein Pflichtspiel.
	return int(ceil(fehlt / maxf(WOCHE_BASIS + WOCHE_TAKTIK * 0.4 + PARTIE * 0.8, 0.5)))

## Setzt das Konto neu auf die aktuell eingestellte Formation.
## Wird beim Weltaufbau gebraucht, wenn die Handschrift eines Vereins erst
## nach dem Anlegen des Kontos feststeht.
static func stammformation_setzen(d: Dictionary, cid: String) -> void:
	d["vereine"][cid]["vertrautheit"] = anlegen(d["vereine"][cid]["taktik"])

## Was eine Sommervorbereitung bringt.
##
## Ein System im Juli umzustellen ist etwas anderes, als es im November zu tun:
## acht Wochen tägliches Training und ein Dutzend Testspiele schleifen die
## Grundzüge ein, bevor es um Punkte geht. Deshalb hebt der Saisonwechsel die
## gerade eingestellten Formationen auf ein solides Niveau an — nie herunter,
## wer schon eingespielt ist, verliert nichts. Das gilt für Computertrainer
## und Spieler gleichermaßen: wer wechseln will, wechselt im Sommer günstig.
const SOMMERBASIS := 70.0

static func sommervorbereitung(d: Dictionary, cid: String) -> void:
	if not d["vereine"].has(cid):
		return
	var v: Dictionary = d["vereine"][cid]
	var k := konto(d, cid)
	for paar in [["abwehr", str(v["taktik"]["abwehr"])], ["angriff", str(v["taktik"]["angriff"])]]:
		var b: Dictionary = k.get(str(paar[0]), {})
		if b.has(str(paar[1])):
			b[str(paar[1])] = maxf(float(b[str(paar[1])]), SOMMERBASIS)

# ------------------------------------------------------------ Fortschreiben ---

## Wochenlauf für alle Vereine: benutzte Formationen wachsen, ungenutzte
## verfallen. Das läuft auch für KI-Vereine — sie wechseln selten, bleiben also
## eingespielt, und genau deshalb ist ihre Kalibrierung unverändert.
static func wochenwechsel(d: Dictionary) -> void:
	for cid in d["vereine"].keys():
		_verein_woche(d, str(cid))

static func _verein_woche(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var k := konto(d, cid)
	var gewinn: float = WOCHE_BASIS
	if str((v.get("training", {}) as Dictionary).get("schwerpunkt", "")) == "taktik":
		gewinn += WOCHE_TAKTIK
	# Ein guter Co-Trainer bringt das System schneller auf die Platte als ein
	# Trainer, der allein vor der Mannschaft steht.
	gewinn *= clampf(0.65 + Training.trainerqualitaet(d, cid, "taktik") / 14.0, 0.65, 1.55)
	_konto_schieben(k, "abwehr", str(v["taktik"]["abwehr"]), gewinn)
	_konto_schieben(k, "angriff", str(v["taktik"]["angriff"]), gewinn)

## Nach einer Partie: die tatsächlich gespielten Formationen wachsen stärker.
static func partie_verbuchen(d: Dictionary, cid: String, abwehr: String, angriff: String) -> void:
	if not d["vereine"].has(cid):
		return
	var k := konto(d, cid)
	_konto_schieben(k, "abwehr", abwehr, PARTIE)
	_konto_schieben(k, "angriff", angriff, PARTIE)

## Hebt eine Formation an und lässt alle anderen desselben Bereichs verfallen.
static func _konto_schieben(k: Dictionary, bereich: String, benutzt: String, gewinn: float) -> void:
	var b: Dictionary = k.get(bereich, {})
	if b.is_empty():
		return
	for f in b.keys():
		var alt: float = float(b[f])
		if str(f) == benutzt:
			# Je näher an 100, desto zäher die letzten Punkte: die Grundzüge
			# sitzen schnell, das Zusammenspiel im Detail braucht Monate.
			b[f] = clampf(alt + gewinn * (1.0 - alt / 118.0), 0.0, 100.0)
		else:
			b[f] = maxf(alt - VERFALL, UNTERGRENZE)
