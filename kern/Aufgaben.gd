class_name Aufgaben
extends RefCounted
## Was gerade auf eine Entscheidung wartet.
##
## Ein Manager-Spiel sagt einem selten, was zu tun ist. Es zeigt Zahlen und
## Bildschirme, und wer es kennt, weiß, wo er nachsehen muss. Wer es nicht
## kennt, sieht eine Zahl an einem Menüpunkt und weiß nicht, was sie von ihm
## will — genau das war die Rückmeldung eines Testspielers.
##
## Diese Liste beantwortet die Frage "was ist dran?" an einer Stelle. Jeder
## Eintrag nennt die Sache, warum sie wichtig ist, wie eilig sie ist und wohin
## sie führt. Die Regeln stehen hier und nicht im Büro, damit derselbe Bestand
## auch woanders benutzt werden kann — etwa beim ersten Spiel.

## Dringlichkeit, absteigend sortiert.
const EILIG := 2
const OFFEN := 1
const HINWEIS := 0

## Alles, was gerade ansteht. [{stufe, titel, text, ziel, knopf}]
##
## ziel ist die Kennung eines Bildschirms; ist sie leer, trägt der Eintrag
## seine eigene Handlung (etwa die Pressekonferenz, die ein Fenster öffnet).
static func offene(d: Dictionary, cid: String) -> Array:
	var aus: Array = []
	if d.is_empty() or cid == "" or not (d.get("vereine", {}) as Dictionary).has(cid):
		return aus
	var v: Dictionary = d["vereine"][cid]
	_gespraeche(d, aus)
	_presse(d, aus)
	_sponsoren(d, cid, aus)
	_aufstellung(d, v, aus)
	_vertraege(d, v, aus)
	_scoutberichte(d, cid, aus)
	_jugend(d, cid, aus)
	_kasse(v, aus)
	_lizenz(d, cid, aus)
	_trainervertrag(d, aus)
	aus.sort_custom(func(a, b): return int(a["stufe"]) > int(b["stufe"]))
	return aus

static func anzahl(d: Dictionary, cid: String) -> int:
	return offene(d, cid).size()

# ------------------------------------------------------------- Die Regeln ---

static func _gespraeche(d: Dictionary, aus: Array) -> void:
	var liste: Array = Anliegen.offene(d)
	if liste.is_empty():
		return
	var kuerzeste: int = 999
	for e in liste:
		kuerzeste = mini(kuerzeste, maxi(int((e as Dictionary)["frist"]) - int(d["tag"]), 0))
	aus.append({
		"stufe": EILIG if kuerzeste <= 4 else OFFEN,
		"titel": "%d Spieler möchten Sie sprechen" % liste.size() if liste.size() > 1 else "Ein Spieler möchte Sie sprechen",
		"text": "Antwort binnen %d Tag(en). Wer eine Frist verstreichen lässt, bekommt die Antwort auf dem Feld." % kuerzeste,
		"ziel": "kabine", "knopf": "Zur Kabine",
	})

static func _presse(d: Dictionary, aus: Array) -> void:
	if not Presse.offen(d):
		return
	aus.append({
		"stufe": EILIG,
		"titel": "Pressekonferenz steht an",
		"text": "Die Journalisten warten auf Ihre Einschätzung vor dem nächsten Spiel. Was Sie sagen, hören Ihre Spieler auch.",
		"ziel": "", "knopf": "Zur Pressekonferenz",
	})

static func _sponsoren(d: Dictionary, cid: String, aus: Array) -> void:
	var angebote: Array = Sponsoren.offene_angebote(d, cid)
	if angebote.is_empty():
		return
	var summe := 0.0
	for a in angebote:
		summe += float((a as Dictionary)["wert"])
	aus.append({
		"stufe": OFFEN,
		"titel": "%d Sponsorenangebote liegen auf dem Tisch" % angebote.size(),
		"text": "Zusammen %s im Jahr. Bis Sie unterschreiben, bleibt das Geld aus." % Stil.geld(summe),
		"ziel": "finanzen", "knopf": "Zu den Finanzen",
	})

## Wer aufgestellt ist, aber nicht spielen kann. Nur wenn der Trainer selbst
## aufstellt — sonst räumt der Stab das vor jeder Partie auf.
static func _aufstellung(d: Dictionary, v: Dictionary, aus: Array) -> void:
	if bool(Welt.einstellung("auto_aufstellung", true)):
		return
	var betroffen: Array = []
	for block in ["angriff", "abwehr"]:
		for pos in (v.get("aufstellung", {}).get(block, {}) as Dictionary).keys():
			var sid: String = str(v["aufstellung"][block][pos])
			if sid == "" or not (d["spieler"] as Dictionary).has(sid):
				continue
			var sp: Dictionary = d["spieler"][sid]
			if betroffen.has(sid):
				continue
			if not (sp["verletzung"] as Dictionary).is_empty() or int(sp["sperre"]) > 0:
				betroffen.append(sid)
	if betroffen.is_empty():
		return
	aus.append({
		"stufe": EILIG,
		"titel": "%d Spieler in der Aufstellung können nicht spielen" % betroffen.size(),
		"text": "Verletzt oder gesperrt. Beim Anpfiff steht dort sonst eine Lücke.",
		"ziel": "taktik", "knopf": "Zur Aufstellung",
	})

## Verträge, die zum Saisonende auslaufen. Wer nichts tut, verliert den Spieler
## ablösefrei — das ist die teuerste Art, eine Entscheidung zu vertagen.
static func _vertraege(d: Dictionary, v: Dictionary, aus: Array) -> void:
	var saison: int = Kalender.saison_index(int(d["tag"]))
	var namen: Array = []
	for sid in (v.get("kader", []) as Array):
		var sp: Dictionary = d["spieler"].get(str(sid), {})
		if sp.is_empty():
			continue
		if int((sp.get("vertrag", {}) as Dictionary).get("bis_saison", 9)) > saison:
			continue
		namen.append(Spielerfabrik.kurz_name(sp))
	if namen.is_empty():
		return
	aus.append({
		"stufe": OFFEN,
		"titel": "%d Verträge laufen am Saisonende aus" % namen.size(),
		"text": "%s. Ohne Verlängerung gehen sie ablösefrei." % ", ".join(PackedStringArray(namen.slice(0, 4))),
		"ziel": "kader", "knopf": "Zum Kader",
	})

static func _scoutberichte(d: Dictionary, cid: String, aus: Array) -> void:
	var fertig := 0
	for a in (d.get("scouting", {}).get("auftraege", []) as Array):
		var auftrag: Dictionary = a
		if not bool(auftrag.get("fertig", false)):
			continue
		if str(auftrag.get("verein", cid)) != cid:
			continue
		if bool(auftrag.get("gelesen", false)):
			continue
		fertig += 1
	if fertig <= 0:
		return
	aus.append({
		"stufe": HINWEIS,
		"titel": "%d Scoutbericht(e) liegen bereit" % fertig,
		"text": "Ein Bericht, den niemand liest, ist ein bezahlter Auftrag ohne Ertrag.",
		"ziel": "scouting", "knopf": "Zum Scouting",
	})

static func _jugend(d: Dictionary, cid: String, aus: Array) -> void:
	var draengen: Array = []
	for sid in Welt.jugend(cid):
		var sp: Dictionary = d["spieler"].get(str(sid), {})
		if sp.is_empty():
			continue
		if int(sp["alter"]) >= Jugend.HOECHSTALTER - 1:
			draengen.append(Spielerfabrik.kurz_name(sp))
	if draengen.is_empty():
		return
	aus.append({
		"stufe": OFFEN,
		"titel": "%d Talent(e) sind zu alt für den Nachwuchs" % draengen.size(),
		"text": "%s. Wer mit %d Jahren nicht befördert ist, verlässt den Verein." % [
			", ".join(PackedStringArray(draengen.slice(0, 3))), Jugend.HOECHSTALTER],
		"ziel": "jugend", "knopf": "Zum Nachwuchs",
	})

static func _kasse(v: Dictionary, aus: Array) -> void:
	if float(v.get("kasse", 0.0)) >= 0.0:
		return
	aus.append({
		"stufe": EILIG,
		"titel": "Die Kasse ist im Minus",
		"text": "%s. Bleibt es dabei, greift der Vorstand ein." % Stil.geld(float(v["kasse"])),
		"ziel": "finanzen", "knopf": "Zu den Finanzen",
	})

static func _lizenz(d: Dictionary, cid: String, aus: Array) -> void:
	var auflagen: Array = Lizenzierung.auflagen(d, cid)
	if auflagen.is_empty():
		return
	aus.append({
		"stufe": OFFEN,
		"titel": "%d Lizenzauflage(n) sind offen" % auflagen.size(),
		"text": str((auflagen[0] as Dictionary)["text"]),
		"ziel": "halle", "knopf": "Zur Halle",
	})

static func _trainervertrag(d: Dictionary, aus: Array) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return
	var rest: int = int((t.get("vertrag", {}) as Dictionary).get("bis_saison", 9)) - Kalender.saison_index(int(d["tag"]))
	if rest > 0:
		return
	aus.append({
		"stufe": OFFEN,
		"titel": "Ihr eigener Vertrag läuft aus",
		"text": "Am Saisonende sind Sie frei. Der Verein macht ein Angebot, wenn die Ergebnisse stimmen.",
		"ziel": "karriere", "knopf": "Zur Laufbahn",
	})


# ------------------------------------------------------- Die ersten Tage ---

## Vier Schritte, die ein Trainer vor seinem ersten Spiel geht.
##
## Kein Lehrgang, der den Weg versperrt — eine Liste, die abhakt, was man schon
## gesehen hat, und verschwindet, sobald alles erledigt ist. Wer das Spiel
## kennt, klickt sie in zehn Sekunden weg; wer es nicht kennt, weiß danach,
## wo die vier Dinge stehen, die vor jedem Spiel zu entscheiden sind.
const SCHRITTE := [
	{"id": "taktik", "titel": "Aufstellung ansehen",
		"text": "Wer steht im Angriff, wer in der Abwehr. Der Stab stellt automatisch auf, solange Sie nichts ändern."},
	{"id": "training", "titel": "Trainingswoche festlegen",
		"text": "Was trainiert wird, entscheidet, wer besser wird — und wie frisch die Mannschaft am Spieltag ist."},
	{"id": "kader", "titel": "Den Kader durchgehen",
		"text": "Stärken, Verträge, Formkurven. Hier steht, womit Sie arbeiten."},
	{"id": "vorstand", "titel": "Das Saisonziel lesen",
		"text": "Der Vorstand misst Sie daran. Wer es kennt, weiß, wie viel Risiko er sich leisten kann."},
]

## Die Schritte mit ihrem Stand. Leer, sobald alle erledigt sind oder der
## Trainer die Liste weggelegt hat.
static func erste_schritte(d: Dictionary) -> Array:
	if d.is_empty() or bool(d.get("erste_schritte_aus", false)):
		return []
	var aus: Array = []
	var offen_zahl := 0
	for s in SCHRITTE:
		var schritt: Dictionary = s
		var erledigt: bool = bool((d.get("besucht", {}) as Dictionary).get(str(schritt["id"]), false))
		if not erledigt:
			offen_zahl += 1
		aus.append({"id": str(schritt["id"]), "titel": str(schritt["titel"]),
			"text": str(schritt["text"]), "erledigt": erledigt})
	if offen_zahl == 0:
		return []
	return aus
