class_name Sponsoren
extends RefCounted
## Der Sponsorenmarkt.
##
## Sponsoring ist im Hallenhandball die wichtigste Einnahmequelle — vor
## Zuschauern, Medien und Merchandising. Verträge laufen aus und müssen neu
## verhandelt werden; was ein Verein dabei aufruft, hängt an Ansehen, Liga,
## Fanzufriedenheit und den Titeln der letzten Jahre. Wer aufsteigt und
## Erfolg hat, verdient anschließend deutlich mehr; wer abstürzt, verliert
## seine Partner an die Konkurrenz.
##
## Gespeichert wird je Verein in `verein["sponsoren"]` (laufende Verträge) und
## `verein["sponsorangebote"]` (offene Angebote, die der Trainer annehmen kann).

## Die fünf Plätze und ihr Anteil am gesamten Sponsorenvolumen.
const PLAETZE := {
	"Trikotbrust": 0.40,
	"Hallenname": 0.22,
	"Ausrüster": 0.15,
	"Ärmel": 0.13,
	"Rückenpartner": 0.10,
}
const REIHENFOLGE := ["Trikotbrust", "Hallenname", "Ausrüster", "Ärmel", "Rückenpartner"]

## Anteil des Jahresetats, den ein durchschnittlicher Verein über Sponsoring
## einnimmt. Der grösste Einzelposten auf der Einnahmenseite.
const GRUNDANTEIL := 0.52

## Wie viel Sponsorengeld ein Verein im Jahr insgesamt anziehen kann.
static func marktwert(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var liga: Dictionary = d["ligen"].get(str(v["liga"]), {})
	var wert: float = float(v["jahresetat"]) * GRUNDANTEIL
	# Die Bühne zählt: eine erste Liga bringt Partner, die eine zweite nicht sieht.
	wert *= 0.72 + float(liga.get("ruf", 50.0)) / 190.0
	# Volle Halle und treue Anhänger sind ein Verkaufsargument.
	var fans: Dictionary = v["fans"]
	wert *= 0.86 + float(fans["zufriedenheit"]) / 480.0 + float(fans["treue"]) / 620.0
	# Titel der letzten Jahre wirken nach.
	var titel: Array = (v.get("chronik", {}) as Dictionary).get("titel", [])
	var frisch := 0
	var saison_jetzt: int = Kalender.saison_index(int(d["tag"]))
	for t in titel:
		if saison_jetzt - int(t["saison"]) <= 3:
			frisch += 1
	wert *= 1.0 + clampf(float(frisch) * 0.05, 0.0, 0.25)
	return maxf(wert, 20000.0)

## Ein Angebot für einen freien Platz.
static func angebot(d: Dictionary, cid: String, platz: String) -> Dictionary:
	var volumen: float = marktwert(d, cid) * float(PLAETZE.get(platz, 0.1))
	return {
		"name": Namen.sponsor(),
		"art": platz,
		"wert": volumen * Namen.bereich(0.86, 1.16),
		"jahre": Namen.wuerfel(2, 4),
		"bonus_titel": Namen.bereich(0.06, 0.22),
	}

static func laufende(d: Dictionary, cid: String) -> Array:
	return d["vereine"][cid].get("sponsoren", [])

static func offene_angebote(d: Dictionary, cid: String) -> Array:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("sponsorangebote"):
		v["sponsorangebote"] = []
	return v["sponsorangebote"]

static func jahressumme(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	for s in laufende(d, cid):
		summe += float(s["wert"])
	return summe

## Welche Plätze gerade unbesetzt sind.
static func freie_plaetze(d: Dictionary, cid: String) -> Array:
	var belegt := {}
	for s in laufende(d, cid):
		belegt[str(s["art"])] = true
	var frei: Array = []
	for platz in REIHENFOLGE:
		if not belegt.has(platz):
			frei.append(platz)
	return frei

## Beim Anlegen der Welt: jeder Verein hat schon Partner, mit gestaffelten
## Laufzeiten — sonst liefen in derselben Saison alle Verträge zugleich aus.
static func erstbelegung(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		v["sponsoren"] = []
		v["sponsorangebote"] = []
		for platz in REIHENFOLGE:
			var a := angebot(d, cid, platz)
			a["jahre"] = Namen.wuerfel(1, 4)
			_unterschreiben(d, cid, a)

# ------------------------------------------------------------ Saisonlauf ---

## Zum Saisonwechsel: ausgelaufene Verträge fallen weg, für jeden freien Platz
## kommt ein neues Angebot. Computervereine unterschreiben sofort, der Trainer
## entscheidet selbst.
static func jahreswechsel(d: Dictionary, mein: String) -> void:
	var saison: int = Kalender.saison_index(int(d["tag"]))
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var weiter: Array = []
		var ausgelaufen: Array = []
		for s in laufende(d, cid):
			if int(s.get("bis_saison", 0)) >= saison:
				weiter.append(s)
			else:
				ausgelaufen.append(s)
		v["sponsoren"] = weiter
		var neue: Array = []
		for platz in freie_plaetze(d, cid):
			neue.append(angebot(d, cid, platz))
		if cid != mein:
			for a in neue:
				_unterschreiben(d, cid, a)
			v["sponsorangebote"] = []
			continue
		v["sponsorangebote"] = neue
		if neue.is_empty():
			continue
		var summe := 0.0
		for a2 in neue:
			summe += float(a2["wert"])
		Welt.nachricht({
			"typ": "finanzen", "wichtig": true,
			"betreff": "%d Sponsorenplätze sind frei" % neue.size(),
			"text": "%s. Auf dem Tisch liegen Angebote über zusammen %s im Jahr. Solange Sie nicht unterschreiben, bleiben die Plätze leer — und das Geld aus." % [
				("Die Verträge von %s sind ausgelaufen" % ", ".join(_namen(ausgelaufen))) if not ausgelaufen.is_empty()
					else "Ihr Verein kann weitere Partner binden",
				Stil.geld(summe)],
		})

static func _namen(liste: Array) -> Array:
	var namen: Array = []
	for s in liste:
		namen.append(str(s["name"]))
	return namen

static func _unterschreiben(d: Dictionary, cid: String, a: Dictionary) -> void:
	var vertrag := a.duplicate()
	vertrag["bis_saison"] = Kalender.saison_index(int(d["tag"])) + maxi(int(a.get("jahre", 2)), 1) - 1
	vertrag.erase("jahre")
	(d["vereine"][cid]["sponsoren"] as Array).append(vertrag)

## Der Trainer nimmt ein Angebot an.
static func annehmen(d: Dictionary, cid: String, index: int) -> Dictionary:
	var angebote: Array = offene_angebote(d, cid)
	if index < 0 or index >= angebote.size():
		return {"ok": false, "grund": "Dieses Angebot gibt es nicht mehr."}
	var a: Dictionary = angebote[index]
	if not freie_plaetze(d, cid).has(str(a["art"])):
		angebote.remove_at(index)
		return {"ok": false, "grund": "Der Platz %s ist bereits vergeben." % str(a["art"])}
	_unterschreiben(d, cid, a)
	angebote.remove_at(index)
	return {"ok": true, "grund": "%s ist neuer Partner (%s, %s im Jahr)." % [
		str(a["name"]), str(a["art"]), Stil.geld(float(a["wert"]))]}

static func alle_annehmen(d: Dictionary, cid: String) -> int:
	var n := 0
	for i in range(offene_angebote(d, cid).size() - 1, -1, -1):
		if bool(annehmen(d, cid, i)["ok"]):
			n += 1
	return n

## Titelprämien der Partner — dafür stehen sie schliesslich auf dem Trikot.
static func titelbonus(d: Dictionary, cid: String, titel: String) -> void:
	var summe := 0.0
	for s in laufende(d, cid):
		summe += float(s["wert"]) * float(s.get("bonus_titel", 0.0))
	if summe <= 0.0:
		return
	Finanzen.buchen(d, cid, summe, "Titelprämien der Sponsoren (%s)" % titel, "sponsor")
	if cid == Welt.mein_verein_id:
		Welt.nachricht({
			"typ": "finanzen",
			"betreff": "Titelprämien der Sponsoren",
			"text": "Für den Gewinn (%s) zahlen Ihre Partner zusammen %s aus." % [titel, Stil.geld(summe)],
		})
