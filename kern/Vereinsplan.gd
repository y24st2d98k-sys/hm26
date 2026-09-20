class_name Vereinsplan
extends RefCounted
## Was ein Verein in dieser Spielzeit vorhat.
##
## Die Computervereine reagierten wöchentlich: eine Lücke im Kader wurde
## gestopft, ein auslaufender Vertrag verlängert, der Trainingsplan gewürfelt.
## Was fehlte, war eine Absicht über die Saison hinaus — und damit fehlte der
## Liga das, was eine Liga interessant macht: dass ein Verein im Sommer
## entscheidet, dieses Jahr alles auf eine Karte zu setzen, und ein anderer,
## zwei Jahre lang aufzubauen.
##
## Der Plan wird zum Saisonwechsel gefasst und gilt dann. Er steuert, wie viel
## ein Verein ausgibt, wen er sucht und ob er seine Alten hält oder gehen
## lässt. Und er steht im Vereinsfenster, damit man ihn lesen kann, bevor man
## mit diesem Verein verhandelt.

const PLAENE := {
	"titeljagd": {
		"name": "Titeljagd",
		"satz": "Der Verein setzt alles auf diese Spielzeit.",
		"etat": 1.45, "alter_ziel": 27.5, "jugend": 0.5, "halten": 1.3,
	},
	"konsolidieren": {
		"name": "Konsolidierung",
		"satz": "Der Verein will die Mannschaft zusammenhalten und ruhig weiterarbeiten.",
		"etat": 1.0, "alter_ziel": 26.0, "jugend": 1.0, "halten": 1.0,
	},
	"umbruch": {
		"name": "Umbruch",
		"satz": "Der Verein baut um: Ältere gehen, Junge bekommen ihre Chance.",
		"etat": 0.85, "alter_ziel": 23.0, "jugend": 1.8, "halten": 0.6,
	},
	"sparjahr": {
		"name": "Sparjahr",
		"satz": "Der Verein muss die Kosten senken und verkauft, wer Erlös bringt.",
		"etat": 0.45, "alter_ziel": 25.0, "jugend": 1.4, "halten": 0.45,
	},
	"klassenerhalt": {
		"name": "Klassenerhalt",
		"satz": "Der Verein sucht erfahrene Spieler, die sofort helfen.",
		"etat": 1.1, "alter_ziel": 28.5, "jugend": 0.4, "halten": 1.1,
	},
}

## Den Plan eines Vereins lesen. Wer keinen hat, konsolidiert.
static func plan(d: Dictionary, cid: String) -> String:
	var v: Dictionary = (d.get("vereine", {}) as Dictionary).get(cid, {})
	var p: String = str(v.get("vereinsplan", ""))
	return p if PLAENE.has(p) else "konsolidieren"

static func eigenschaft(d: Dictionary, cid: String, feld: String) -> float:
	return float((PLAENE[plan(d, cid)] as Dictionary).get(feld, 1.0))

static func name(d: Dictionary, cid: String) -> String:
	return str((PLAENE[plan(d, cid)] as Dictionary)["name"])

static func satz(d: Dictionary, cid: String) -> String:
	return str((PLAENE[plan(d, cid)] as Dictionary)["satz"])

## Zum Saisonwechsel entscheidet jeder Verein neu.
##
## Die Reihenfolge der Prüfungen ist die Rangfolge der Zwänge: wer kein Geld
## hat, spart, egal was er vorhätte. Wer gerade abgestiegen wäre, rettet sich.
## Erst danach kommt, was der Verein will.
static func neu_fassen(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		if bool(v.get("ist_mensch", false)) or bool(v.get("ist_nationalteam", false)):
			continue
		v["vereinsplan"] = _waehlen(d, cid)
		v["vereinsplan_seit"] = Welt.saison_index()

static func _waehlen(d: Dictionary, cid: String) -> String:
	var v: Dictionary = d["vereine"][cid]
	var kasse: float = float(v.get("kasse", 0.0))
	var etat: float = maxf(float(v.get("transferbudget", 1.0)), 1.0)
	# Ein Verein, der ins Minus gerutscht ist, hat keine Wahl.
	if kasse < 0.0 or kasse < etat * 0.35:
		return "sparjahr"
	var lid: String = str(v["liga"])
	var tabelle: Array = Spielplan.tabelle_sortiert(d, lid)
	var platz: int = tabelle.find(cid) + 1
	var anzahl: int = maxi(tabelle.size(), 1)
	if platz > 0 and float(platz) / float(anzahl) > 0.8:
		return "klassenerhalt"
	# Wie alt ist die Mannschaft, und wie gut war sie?
	var alter := 0.0
	var n := 0
	for sid in (v.get("kader", []) as Array):
		var sp: Dictionary = (d["spieler"] as Dictionary).get(str(sid), {})
		if sp.is_empty():
			continue
		alter += float(sp["alter"])
		n += 1
	var schnittalter: float = alter / maxf(float(n), 1.0)
	var jugendneigung: float = Gegnertrainer.achse(d, cid, "jugend")
	if schnittalter > 28.2 or (schnittalter > 26.8 and jugendneigung > 0.62):
		return "umbruch"
	if platz > 0 and platz <= 3 and kasse > etat * 1.5:
		return "titeljagd"
	if jugendneigung > 0.75 and platz > 0 and float(platz) / float(anzahl) > 0.45:
		return "umbruch"
	return "konsolidieren"

## Was der Plan für einen einzelnen Kandidaten bedeutet.
##
## Gibt einen Faktor auf die Attraktivität zurück: ein Verein im Umbruch
## schaut auf Zwanzigjährige, einer im Abstiegskampf auf Dreißigjährige, die
## sofort spielen können.
static func kandidatengewicht(d: Dictionary, cid: String, sp: Dictionary) -> float:
	if sp.is_empty():
		return 1.0
	var ziel: float = eigenschaft(d, cid, "alter_ziel")
	var abstand: float = absf(float(sp["alter"]) - ziel)
	var gewicht: float = clampf(1.25 - abstand * 0.07, 0.35, 1.25)
	if int(sp["alter"]) <= 22:
		gewicht *= clampf(eigenschaft(d, cid, "jugend"), 0.4, 1.8)
	return gewicht

## Wie viel dieser Verein in dieser Spielzeit auszugeben bereit ist.
static func etatfaktor(d: Dictionary, cid: String) -> float:
	return eigenschaft(d, cid, "etat")

## Wie sehr er seine Leistungsträger halten will.
static func haltefaktor(d: Dictionary, cid: String) -> float:
	return eigenschaft(d, cid, "halten")

## Eine Pressemeldung zum Plan — aber nur für die Vereine, die der Trainer
## sieht: die eigene Liga.
static func melden(d: Dictionary, cid: String) -> void:
	var eigen: Dictionary = (d.get("vereine", {}) as Dictionary).get(Welt.mein_verein_id, {})
	if eigen.is_empty():
		return
	var v: Dictionary = d["vereine"][cid]
	if str(v.get("liga", "")) != str(eigen.get("liga", "")):
		return
	Welt.nachricht({
		"typ": "medien",
		"betreff": "%s: %s" % [str(v["name"]), name(d, cid)],
		"text": "%s %s" % [satz(d, cid), Gegnertrainer.beschreibung(d, cid)],
	})
