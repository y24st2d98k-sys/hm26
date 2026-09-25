class_name Fingerabdruck
extends RefCounted
## Was für ein Trainer man geworden ist.
##
## Ein Spielstand hält einen auch deshalb, weil er nach einer Weile einem
## selbst ähnlich sieht: die Mannschaft, die man gebaut hat, die Art, wie man
## sie spielen lässt, das Geld, das man nicht ausgegeben hat. Das Spiel wusste
## das alles längst — die Handschrift wird seit Langem mitgeschrieben — aber
## es stand als Zahlenreihe da und sagte niemandem etwas.
##
## Hier wird daraus ein Satz. Nicht "Jugend 78", sondern "Sie haben in drei
## Spielzeiten elf Eigengewächse eingesetzt". Zahlen beschreiben, Sätze
## erkennen.

## Die Achsen der Handschrift mit ihren beiden Enden. Ab welchem Wert ein Ende
## überhaupt behauptet wird, steht in SCHWELLE — wer in der Mitte liegt, hat
## in dieser Sache eben keine Handschrift, und das zu behaupten wäre gelogen.
const SCHWELLE := 22.0
const ACHSEN := {
	"tempo": {"hoch": "Sie lassen laufen. Tempo ist Ihr Mittel, nicht Kontrolle.",
		"tief": "Sie lassen den Ball laufen, nicht die Leute. Ihre Angriffe dauern."},
	"bollwerk": {"hoch": "Ihre Abwehr steht, bevor irgendetwas anderes steht.",
		"tief": "Sie verteidigen vorn und nehmen in Kauf, dass hinten Platz ist."},
	"wagemut": {"hoch": "Sie gehen ins Risiko — auch wenn es zweimal im Jahr schiefgeht.",
		"tief": "Sie nehmen den sicheren Abschluss. Kein Spiel wird durch Übermut verloren."},
	"rotation": {"hoch": "Sie wechseln viel. Bei Ihnen spielt der halbe Kader.",
		"tief": "Sie haben eine Sieben, und die spielt."},
	"strenge": {"hoch": "Ihre Abwehr greift zu. Das Gespann kennt Sie.",
		"tief": "Sie lassen verteidigen, ohne zu foulen. Zeitstrafen sind bei Ihnen selten."},
	"jugend": {"hoch": "Sie setzen auf die Jungen, bevor sie fertig sind.",
		"tief": "Sie setzen auf fertige Spieler. Der Nachwuchs wartet."},
}

## Alle Sätze, die sich über diesen Trainer sagen lassen.
## [{titel, text, art}] — art ist "handschrift" oder "zahl".
static func saetze(d: Dictionary, cid: String) -> Array:
	var aus: Array = []
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return aus
	var h: Dictionary = t.get("handschrift", {})
	for achse in ACHSEN.keys():
		if not h.has(achse):
			continue
		var wert: float = float(h[achse])
		var texte: Dictionary = ACHSEN[achse]
		if wert >= 50.0 + SCHWELLE:
			aus.append({"titel": str(achse).capitalize(), "text": str(texte["hoch"]),
				"art": "handschrift", "wert": wert})
		elif wert <= 50.0 - SCHWELLE:
			aus.append({"titel": str(achse).capitalize(), "text": str(texte["tief"]),
				"art": "handschrift", "wert": wert})
	aus.append_array(_zahlen(d, cid, t))
	return aus

## Die harten Zahlen — sie sind überprüfbar und deshalb überzeugender als
## jede Charakterisierung.
static func _zahlen(d: Dictionary, cid: String, t: Dictionary) -> Array:
	var aus: Array = []
	var st: Dictionary = t.get("statistik", {})
	var spiele: int = int(st.get("spiele", 0))
	if spiele >= 10:
		var siege: int = int(st.get("siege", 0))
		aus.append({"titel": "Bilanz", "art": "zahl",
			"text": "%d Partien als Trainer, %d gewonnen — das sind %.0f Prozent." % [
				spiele, siege, float(siege) / float(spiele) * 100.0]})
	var titel: Array = t.get("titel", [])
	if not titel.is_empty():
		var namen: Array = []
		for e in titel.slice(0, 4):
			namen.append(str((e as Dictionary)["titel"]))
		aus.append({"titel": "Titel", "art": "zahl",
			"text": "%s." % ", ".join(PackedStringArray(namen))})
	if cid == "" or not (d.get("vereine", {}) as Dictionary).has(cid):
		return aus
	var v: Dictionary = d["vereine"][cid]

	var eigene := 0
	var eigene_minuten := 0.0
	var alter := 0.0
	var anzahl := 0
	for sid in (v.get("kader", []) as Array):
		var sp: Dictionary = (d["spieler"] as Dictionary).get(str(sid), {})
		if sp.is_empty():
			continue
		alter += float(sp["alter"])
		anzahl += 1
		if str(sp.get("ausbildungsverein", "")) == str(cid):
			eigene += 1
			eigene_minuten += float(sp["stats"]["saison"]["minuten"])
	if anzahl > 0:
		aus.append({"titel": "Der Kader", "art": "zahl",
			"text": "%d Spieler, Schnittalter %.1f, davon %d aus der eigenen Jugend." % [
				anzahl, alter / float(anzahl), eigene]})
	if eigene > 0 and eigene_minuten > 60.0:
		aus.append({"titel": "Eigengewächse", "art": "zahl",
			"text": "Ihre Eigengewächse stehen in dieser Saison zusammen %d Minuten auf der Platte." % int(eigene_minuten)})

	var teuerster := 0.0
	var teuerster_name := ""
	var erloes := 0.0
	for e2 in (d.get("transfermarkt", {}).get("verlauf", []) as Array):
		var z: Dictionary = e2
		var betrag: float = float(z.get("ablöse", 0.0))
		if str(z.get("nach", "")) == cid and betrag > teuerster:
			teuerster = betrag
			teuerster_name = Spielerfabrik.voller_name((d["spieler"] as Dictionary).get(str(z.get("spieler", "")), {}))
		if str(z.get("von", "")) == cid:
			erloes += betrag
	if teuerster > 0.0:
		aus.append({"titel": "Teuerster Zugang", "art": "zahl",
			"text": "%s für %s." % [teuerster_name, Stil.geld(teuerster)]})
	elif not (d.get("transfermarkt", {}).get("verlauf", []) as Array).is_empty():
		aus.append({"titel": "Transfers", "art": "zahl",
			"text": "Sie haben noch nie eine Ablöse gezahlt."})
	if erloes > 0.0:
		aus.append({"titel": "Verkauft", "art": "zahl",
			"text": "%s an Transfererlösen erwirtschaftet." % Stil.geld(erloes)})
	return aus

## Ein einzelner Satz, der den Trainer am besten trifft — für die Kopfzeile.
static func kurzform(d: Dictionary, cid: String) -> String:
	var liste: Array = saetze(d, cid)
	var beste: Dictionary = {}
	for e in liste:
		var eintrag: Dictionary = e
		if str(eintrag["art"]) != "handschrift":
			continue
		var abstand: float = absf(float(eintrag.get("wert", 50.0)) - 50.0)
		if beste.is_empty() or abstand > absf(float(beste.get("wert", 50.0)) - 50.0):
			beste = eintrag
	return str(beste.get("text", "")) if not beste.is_empty() else ""
