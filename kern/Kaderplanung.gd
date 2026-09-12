class_name Kaderplanung
extends RefCounted
## Kaderplanung: der Blick über die laufende Saison hinaus.
##
## Ein Manager entscheidet nicht über den nächsten Spieltag, sondern über die
## nächsten drei Jahre. Wer läuft aus, wer wird zu alt, auf welcher Position
## steht in zwei Jahren niemand mehr? Diese Fragen beantwortet keine Kaderliste,
## die nur den heutigen Stand zeigt.

const HORIZONT := 3

## Wie viele Spieler je Position im Kader stehen sollten.
const SOLLTIEFE := {"TW": 2, "LA": 2, "RL": 2, "RM": 2, "RR": 2, "RA": 2, "KM": 2}

## Tiefe je Position, heute und in den kommenden Saisons.
## Liefert {pos: [heute, in 1 Jahr, in 2 Jahren, in 3 Jahren]}
static func tiefe(d: Dictionary, cid: String) -> Dictionary:
	var saison: int = Welt.saison_index()
	var werte := {}
	for pos in Spielerfabrik.POSITIONEN:
		werte[pos] = []
		for _j in range(HORIZONT + 1):
			(werte[pos] as Array).append(0)
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		var pos2: String = str(sp["position"])
		var bis: int = int(sp["vertrag"].get("bis_saison", saison))
		for j in range(HORIZONT + 1):
			# Vertrag muss laufen und der Spieler darf nicht zu alt sein.
			if saison + j > bis:
				continue
			if int(sp["alter"]) + j > 37:
				continue
			(werte[pos2] as Array)[j] = int((werte[pos2] as Array)[j]) + 1
	return werte

## Positionen, auf denen es in den nächsten Jahren eng wird.
static func luecken(d: Dictionary, cid: String) -> Array:
	var t := tiefe(d, cid)
	var liste: Array = []
	for pos in Spielerfabrik.POSITIONEN:
		var soll: int = int(SOLLTIEFE.get(pos, 2))
		for j in range(HORIZONT + 1):
			var ist: int = int((t[pos] as Array)[j])
			if ist < soll:
				liste.append({"position": pos, "in_jahren": j, "ist": ist, "soll": soll})
				break
	return liste

## Altersstruktur: wie viele Spieler in welcher Altersgruppe.
static func altersgruppen(d: Dictionary, cid: String) -> Dictionary:
	var gruppen := {"talent": 0, "aufbau": 0, "beste": 0, "erfahren": 0, "veteran": 0}
	for sid in d["vereine"][cid]["kader"]:
		var a: int = int(d["spieler"][sid]["alter"])
		if a <= 21:
			gruppen["talent"] = int(gruppen["talent"]) + 1
		elif a <= 25:
			gruppen["aufbau"] = int(gruppen["aufbau"]) + 1
		elif a <= 29:
			gruppen["beste"] = int(gruppen["beste"]) + 1
		elif a <= 33:
			gruppen["erfahren"] = int(gruppen["erfahren"]) + 1
		else:
			gruppen["veteran"] = int(gruppen["veteran"]) + 1
	return gruppen

const GRUPPENNAME := {
	"talent": "bis 21", "aufbau": "22–25", "beste": "26–29",
	"erfahren": "30–33", "veteran": "ab 34",
}

## Ein Urteil über die Altersstruktur.
static func altersurteil(d: Dictionary, cid: String) -> String:
	var g := altersgruppen(d, cid)
	var gesamt: int = 0
	for k in g.keys():
		gesamt += int(g[k])
	if gesamt == 0:
		return "Kein Kader vorhanden."
	var jung: float = float(int(g["talent"]) + int(g["aufbau"])) / float(gesamt)
	var alt: float = float(int(g["erfahren"]) + int(g["veteran"])) / float(gesamt)
	if alt > 0.45:
		return "Die Mannschaft ist alt. In zwei, drei Jahren müssen Sie halb neu bauen."
	if jung > 0.55:
		return "Sehr junger Kader — viel Zukunft, wenig Gegenwart. Ein, zwei erfahrene Spieler würden die Achse stützen."
	if alt < 0.12:
		return "Es fehlt an Erfahrung: Niemand da, der eine Mannschaft in einem engen Spiel führt."
	return "Ausgewogene Altersstruktur."

## Alle Spieler mit Vertragsende, nach Ablauf sortiert.
static func vertragsuebersicht(d: Dictionary, cid: String) -> Array:
	var liste: Array = (d["vereine"][cid]["kader"] as Array).duplicate()
	liste.sort_custom(func(a, b):
		var va: int = int(d["spieler"][a]["vertrag"].get("bis_saison", 0))
		var vb: int = int(d["spieler"][b]["vertrag"].get("bis_saison", 0))
		if va != vb:
			return va < vb
		return Spielerfabrik.gesamt(d["spieler"][a]) > Spielerfabrik.gesamt(d["spieler"][b]))
	return liste

## Was die Gehaltsliste in den kommenden Saisons kostet, wenn nichts geschieht.
static func gehaltsverlauf(d: Dictionary, cid: String) -> Array:
	var saison: int = Welt.saison_index()
	var werte: Array = []
	for j in range(HORIZONT + 1):
		var summe := 0.0
		for sid in d["vereine"][cid]["kader"]:
			var sp: Dictionary = d["spieler"][sid]
			if saison + j > int(sp["vertrag"].get("bis_saison", saison)):
				continue
			summe += float(sp["vertrag"].get("gehalt", 0.0))
		werte.append(summe)
	return werte

## Voraussichtliche Stärke eines Spielers in n Jahren — grob, aus Alterskurve
## und Potenzial. Kein Versprechen, sondern eine Einordnung.
static func prognose(sp: Dictionary, jahre: int) -> float:
	var jetzt: float = Spielerfabrik.gesamt(sp)
	var alter_jahre: int = int(sp["alter"])
	var potenzial: float = float(sp["potenzial"])
	var wert: float = jetzt
	for j in range(jahre):
		var a: int = alter_jahre + j
		if a <= 21:
			wert += minf((potenzial - wert) * 0.34, 5.5)
		elif a <= 25:
			wert += minf((potenzial - wert) * 0.22, 3.5)
		elif a <= 28:
			wert += minf((potenzial - wert) * 0.08, 1.2)
		elif a <= 31:
			wert -= 0.8
		elif a <= 34:
			wert -= 2.4
		else:
			wert -= 4.2
	return clampf(wert, 10.0, 99.0)
