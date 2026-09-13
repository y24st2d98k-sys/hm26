class_name Gegnerplan
extends RefCounted
## Der Matchplan gegen einen bestimmten Gegner.
##
## Die Mannschaftstaktik gilt gegen jeden gleich, die Spieleranweisung gilt für
## den eigenen Mann. Was fehlte, war die dritte Ebene: was man gegen *diesen*
## Rückraumschützen unternimmt, der in den letzten fünf Spielen achtundzwanzig
## Tore geworfen hat. Genau darüber redet ein Trainerteam vor dem Spiel.
##
## Zwei Mittel, beide mit Preis:
##
##  * **Manndeckung** — einer geht raus und klebt an ihm. Er kommt kaum noch
##    zum Wurf und trifft schlechter. Dafür deckt der Rest zu fünft: die
##    Abwehr verliert an Kompaktheit, und wer offensiv verteidigt, kassiert
##    mehr Zeitstrafen.
##  * **Kreis zustellen** — der Innenblock bleibt geschlossen und lässt den
##    Kreisläufer nicht anspielbar werden. Dafür steht die Deckung tiefer und
##    der Rückraum wirft freier.
##
## Der Plan gilt nur gegen den Verein, für den er gemacht wurde. Wer ihn nicht
## pflegt, spielt gegen den nächsten Gegner ohne — und das ist auch in Ordnung,
## denn beide Mittel kosten etwas.

const MITTEL := {
	"keins": {
		"name": "Kein besonderer Plan",
		"text": "Die Abwehr steht, wie sie eingestellt ist.",
	},
	"manndeckung": {
		"name": "Manndeckung",
		"text": "Ein Abwehrspieler geht heraus und deckt ihn über das ganze Feld. Der Rest verteidigt zu fünft.",
	},
	"doppeln": {
		"name": "Doppeln beim Anspiel",
		"text": "Zwei rücken heraus, sobald er den Ball bekommt. Weniger radikal als Manndeckung — und weniger wirksam.",
	},
	"kreis_zustellen": {
		"name": "Kreis zustellen",
		"text": "Der Innenblock bleibt geschlossen und nimmt den Kreisläufer aus dem Spiel. Der Rückraum wirft dafür freier.",
	},
}

static func leer() -> Dictionary:
	return {"gegner": "", "mittel": "keins", "ziel": ""}

static func plan(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("gegnerplan") or (v["gegnerplan"] as Dictionary).is_empty():
		v["gegnerplan"] = leer()
	return v["gegnerplan"]

## Der Plan, sofern er für genau diesen Gegner gemacht wurde. Sonst leer.
static func fuer(d: Dictionary, cid: String, gegner: String) -> Dictionary:
	var p := plan(d, cid)
	if str(p["gegner"]) != gegner or str(p["mittel"]) == "keins":
		return leer()
	# Ein Ziel, das nicht mehr im Kader des Gegners steht, macht den Plan
	# gegenstandslos — sonst deckt jemand einen Spieler, der verkauft wurde.
	if str(p["mittel"]) in ["manndeckung", "doppeln"]:
		if str(p["ziel"]) == "" or not (d["vereine"][gegner]["kader"] as Array).has(str(p["ziel"])):
			return leer()
	return p

static func setzen(d: Dictionary, cid: String, gegner: String, mittel: String, ziel: String = "") -> void:
	var p := plan(d, cid)
	p["gegner"] = gegner
	p["mittel"] = mittel if MITTEL.has(mittel) else "keins"
	p["ziel"] = ziel

# ---------------------------------------------------------------- Wirkung ---

## Wie stark der Wurfanteil des gedeckten Spielers einbricht.
static func wurfanteil(p: Dictionary, sid: String) -> float:
	if p.is_empty() or str(p["ziel"]) != sid:
		return 1.0
	match str(p["mittel"]):
		"manndeckung": return 0.42
		"doppeln": return 0.68
	return 1.0

## Abzug auf die Abschlussqualität des gedeckten Spielers, in Punkten der
## internen Gueteskala.
static func gueteabzug(p: Dictionary, sid: String) -> float:
	if p.is_empty() or str(p["ziel"]) != sid:
		return 0.0
	match str(p["mittel"]):
		"manndeckung": return 3.6
		"doppeln": return 2.0
	return 0.0

## Was der Plan die eigene Abwehr insgesamt kostet.
##
## Das ist der Preis, ohne den das Ganze eine Gratisverbesserung wäre: wer
## einen Mann herausschickt, deckt hinten mit einem weniger.
static func abwehrfaktor(p: Dictionary) -> float:
	if p.is_empty():
		return 1.0
	match str(p["mittel"]):
		"manndeckung": return 0.955
		"doppeln": return 0.978
		"kreis_zustellen": return 1.0
	return 1.0

## Wie der Plan die Deckungswerte verschiebt.
static func deckungswerte(p: Dictionary) -> Dictionary:
	if p.is_empty():
		return {}
	match str(p["mittel"]):
		"manndeckung":
			return {"zeitstrafe": 1.18, "ballgewinn": 1.10, "block": 0.94}
		"doppeln":
			return {"zeitstrafe": 1.09, "ballgewinn": 1.06, "block": 0.97}
		"kreis_zustellen":
			# Der Kreis wird zugemacht, der Fernwurf dafür freigegeben.
			return {"kreis": 0.72, "fern": 1.16, "block": 1.05}
	return {}

## Ein Satz für die Oberfläche: was der Plan gerade vorsieht.
static func beschreibung(d: Dictionary, p: Dictionary) -> String:
	if p.is_empty() or str(p["mittel"]) == "keins":
		return "Kein besonderer Plan — die Abwehr steht, wie sie eingestellt ist."
	var text: String = str((MITTEL[str(p["mittel"])] as Dictionary)["text"])
	var ziel: String = str(p["ziel"])
	if ziel != "" and d["spieler"].has(ziel):
		return "%s: %s" % [Spielerfabrik.voller_name(d["spieler"][ziel]), text]
	return text

## Die lohnendsten Ziele beim Gegner — wer wirft, wer trifft.
static func kandidaten(d: Dictionary, gegner: String) -> Array:
	if not d["vereine"].has(gegner):
		return []
	var liste: Array = []
	for sid in d["vereine"][gegner]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp["ist_torwart"]):
			continue
		var s: Dictionary = sp["stats"]["saison"]
		liste.append({
			"spieler": str(sid),
			"tore": int(s["tore"]),
			"staerke": Spielerfabrik.gesamt(sp),
			# Gefahr aus Saisontoren und Stärke: früh in der Saison zählt die
			# Stärke mehr, später sprechen die Tore für sich.
			"gefahr": float(s["tore"]) * 1.6 + Spielerfabrik.gesamt(sp) * 0.35,
		})
	liste.sort_custom(func(a, b): return float(a["gefahr"]) > float(b["gefahr"]))
	return liste.slice(0, 6)
