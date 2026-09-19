class_name Wochenbericht
extends RefCounted
## Was sich in einer Woche verändert hat — und wodurch.
##
## Ein Manager-Spiel rechnet unablässig: Moral steigt, Verträge altern, die
## Fanszene murrt, der Vorstand rechnet mit. Nur sieht man davon nichts. Man
## gibt eine Pressekonferenz, hält eine Ansprache, verteilt Regeneration — und
## danach passiert sichtbar: nichts. Eine Entscheidung ohne erkennbare Folge
## lehrt niemanden etwas, und sie hält auch niemanden am Spiel.
##
## Dieser Bestand hält jeden Montag zehn Zahlen fest und stellt sie beim
## nächsten Montag daneben. Nichts davon wird neu berechnet — es steht alles
## längst im Spielstand und wurde nur nie gezeigt.

## Ein Posten: Kennung, Anzeigename, wie er zu lesen ist.
##
## `richtung` sagt, ob mehr gut ist (1) oder schlecht (-1). `art` bestimmt die
## Darstellung: eine Zahl, ein Geldbetrag, ein Tabellenplatz.
const POSTEN := [
	{"id": "platz", "name": "Tabellenplatz", "richtung": -1, "art": "platz",
		"deutung": "Wo Sie stehen, wenn heute Schluss wäre."},
	{"id": "punkte", "name": "Punkte", "richtung": 1, "art": "zahl",
		"deutung": "Zwei für einen Sieg, einer für ein Unentschieden."},
	{"id": "vertrauen", "name": "Vertrauen des Vorstands", "richtung": 1, "art": "zahl",
		"deutung": "Fällt es unter dreißig, wird es ungemütlich."},
	{"id": "fans", "name": "Fanstimmung", "richtung": 1, "art": "zahl",
		"deutung": "Trägt die Halle oder pfeift sie."},
	{"id": "kabine", "name": "Kabinenklima", "richtung": 1, "art": "zahl",
		"deutung": "Ergibt sich aus Moral, Hierarchie und Unzufriedenheit."},
	{"id": "moral", "name": "Moral im Kader", "richtung": 1, "art": "zahl",
		"deutung": "Der Schnitt über alle Spieler."},
	{"id": "last", "name": "Lastkonto im Schnitt", "richtung": -1, "art": "zahl",
		"deutung": "Über siebzig wird es gefährlich."},
	{"id": "verletzt", "name": "Verletzte", "richtung": -1, "art": "zahl",
		"deutung": "Wer im Lazarett liegt, steht nicht auf der Platte."},
	{"id": "staerke", "name": "Kaderstärke", "richtung": 1, "art": "zahl",
		"deutung": "Der Schnitt über alle Spieler im Kader."},
	{"id": "kasse", "name": "Kasse", "richtung": 1, "art": "geld",
		"deutung": "Was nach der Wochenabrechnung übrig ist."},
]

## Der heutige Stand aller Posten.
static func stand(d: Dictionary, cid: String) -> Dictionary:
	var aus := {}
	if d.is_empty() or cid == "" or not (d.get("vereine", {}) as Dictionary).has(cid):
		return aus
	var v: Dictionary = d["vereine"][cid]
	var lid: String = str(v["liga"])
	var tabelle: Array = Spielplan.tabelle_sortiert(d, lid)
	var zeile: Dictionary = (d["ligen"][lid]["tabelle"] as Dictionary).get(
		cid, Spielplan.leere_tabellenzeile())
	aus["platz"] = float(tabelle.find(cid) + 1)
	aus["punkte"] = float(int(zeile["punkte"]))
	aus["vertrauen"] = float(v["vorstand"]["vertrauen"])
	aus["fans"] = Fanszene.gesamtstimmung(d, cid)
	aus["kabine"] = float(v.get("stimmung_kabine", 50.0))
	var moral := 0.0
	var last := 0.0
	var staerke := 0.0
	var verletzt := 0
	var n := 0
	for sid in (v.get("kader", []) as Array):
		var sp: Dictionary = (d["spieler"] as Dictionary).get(str(sid), {})
		if sp.is_empty():
			continue
		moral += float(sp["moral"])
		last += float(sp["last"])
		staerke += Spielerfabrik.gesamt(sp)
		if not (sp["verletzung"] as Dictionary).is_empty():
			verletzt += 1
		n += 1
	var teiler: float = maxf(float(n), 1.0)
	aus["moral"] = moral / teiler
	aus["last"] = last / teiler
	aus["staerke"] = staerke / teiler
	aus["verletzt"] = float(verletzt)
	aus["kasse"] = float(v.get("kasse", 0.0))
	return aus

## Den heutigen Stand festhalten. Der bisherige wandert nach "vorher", damit
## der Vergleich auch dann steht, wenn zwischendurch niemand hingesehen hat.
static func festhalten(d: Dictionary, cid: String) -> void:
	var jetzt := stand(d, cid)
	if jetzt.is_empty():
		return
	var alt: Dictionary = (d.get("wochenstand", {}) as Dictionary).get("jetzt", {})
	d["wochenstand"] = {"vorher": alt, "jetzt": jetzt, "tag": int(d.get("tag", 0)),
		"vorher_tag": int((d.get("wochenstand", {}) as Dictionary).get("tag", 0))}

## Der Vergleich: [{name, vorher, jetzt, delta, gut, art, deutung}]
##
## Verglichen wird der letzte festgehaltene Stand mit dem von heute — nicht mit
## dem vorletzten. Wer drei Wochen durchklickt, sieht die Woche, nicht drei.
static func vergleich(d: Dictionary, cid: String) -> Array:
	var aus: Array = []
	var w: Dictionary = d.get("wochenstand", {})
	var vorher: Dictionary = w.get("jetzt", {})
	if vorher.is_empty():
		return aus
	var jetzt := stand(d, cid)
	if jetzt.is_empty():
		return aus
	for p in POSTEN:
		var posten: Dictionary = p
		var id: String = str(posten["id"])
		if not vorher.has(id) or not jetzt.has(id):
			continue
		var a: float = float(vorher[id])
		var b: float = float(jetzt[id])
		var delta: float = b - a
		aus.append({
			"name": str(posten["name"]), "vorher": a, "jetzt": b, "delta": delta,
			"art": str(posten["art"]), "deutung": str(posten["deutung"]),
			"gut": delta * float(posten["richtung"]) > 0.0,
			"gleich": is_zero_approx(delta),
		})
	return aus

## Seit wann verglichen wird, als Tageszahl. 0, wenn noch nichts festgehalten.
static func seit(d: Dictionary) -> int:
	return int((d.get("wochenstand", {}) as Dictionary).get("tag", 0))

## Wie sich ein Posten liest.
static func text(wert: float, art: String) -> String:
	match art:
		"geld":
			return Stil.geld(wert)
		"platz":
			return "%d." % int(round(wert))
	return "%d" % int(round(wert)) if absf(wert - round(wert)) < 0.05 else Stil.komma(wert, 1)

static func delta_text(delta: float, art: String) -> String:
	if is_zero_approx(delta):
		return "±0"
	if art == "geld":
		return "%s%s" % ["+" if delta > 0.0 else "−", Stil.geld(absf(delta))]
	if art == "platz":
		# Ein Platz nach oben ist eine kleinere Zahl. "+2" hiesse hier
		# verschlechtert, und genau das liest niemand so.
		return "%d Plätze %s" % [int(absf(round(delta))), "hoch" if delta < 0.0 else "runter"] \
			if absf(delta) > 1.0 else ("ein Platz hoch" if delta < 0.0 else "ein Platz runter")
	# Unter zehn mit einer Nachkommastelle: gerundet wurde aus 1,4 ein "+1",
	# und damit sah eine Woche Arbeit an der Stimmung aus wie ein Rundungsfehler.
	var betrag: float = absf(delta)
	var zahl: String = "%d" % int(round(betrag)) if betrag >= 10.0 else Stil.komma(betrag, 1)
	return "%s%s" % ["+" if delta > 0.0 else "−", zahl]
