class_name Presse
extends RefCounted
## Pressekonferenzen vor Spielen und in Krisen.
##
## Die Fragen entstehen aus der tatsächlichen Lage: Gegner, Serie, Tabellenplatz,
## Vorstandsvertrauen, wechselwillige Spieler. Jede Antwort wirkt — auf die Fans,
## auf den Vorstand, auf die Moral der eigenen Mannschaft und manchmal auf die
## Motivation des nächsten Gegners.

static func offen(d: Dictionary) -> bool:
	return bool(d.get("pressekonferenz", {}).get("offen", false))

static func aktuelle(d: Dictionary) -> Dictionary:
	return d.get("pressekonferenz", {})

## Prüft täglich, ob eine Konferenz ansteht.
static func tageswechsel(d: Dictionary) -> void:
	var cid: String = Welt.mein_verein_id
	if cid == "":
		return
	if offen(d):
		return
	var naechstes: Dictionary = Welt.naechstes_spiel(cid)
	if naechstes.is_empty():
		return
	if str(naechstes["art"]) == "test":
		return
	var tage_bis: int = int(naechstes["tag"]) - int(d["tag"])
	if tage_bis != 1:
		return
	# Nicht vor jedem Spiel — bei besonderer Lage aber immer.
	var v: Dictionary = d["vereine"][cid]
	var gegner: String = str(naechstes["gast"]) if str(naechstes["heim"]) == cid else str(naechstes["heim"])
	var derby: bool = float((v["rivalen"] as Dictionary).get(gegner, 0.0)) > 45.0
	var krise: bool = float(v["vorstand"]["vertrauen"]) < 35.0
	var pflicht: bool = derby or krise or str(naechstes["art"]) in ["international", "supercup"]
	if not pflicht and Namen.zufall() > 0.4:
		return
	_erzeugen(d, cid, naechstes, gegner)

static func _erzeugen(d: Dictionary, cid: String, spiel: Dictionary, gegner: String) -> void:
	var fragen: Array = []
	fragen.append(_frage_gegner(d, cid, gegner, spiel))
	var lage := _frage_lage(d, cid)
	if not lage.is_empty():
		fragen.append(lage)
	var spielerfrage := _frage_spieler(d, cid)
	if not spielerfrage.is_empty():
		fragen.append(spielerfrage)
	d["pressekonferenz"] = {
		"offen": true,
		"tag": int(d["tag"]),
		"spiel": str(spiel["id"]),
		"gegner": gegner,
		"outlet": str(Medien._outlet(d, str(d["vereine"][cid]["nation"]))["name"]),
		"fragen": fragen,
		"index": 0,
		"protokoll": [],
	}
	Welt.nachricht({
		"typ": "presse", "wichtig": true, "aktion": "pressekonferenz",
		"betreff": "Pressekonferenz vor %s" % str(d["vereine"][gegner]["name"]),
		"text": "Die Journalisten warten. Ihre Antworten werden gelesen — von den Fans, vom Vorstand und von der Mannschaft.",
	})

# ------------------------------------------------------------- Fragen ---

static func _frage_gegner(d: Dictionary, cid: String, gegner: String, spiel: Dictionary) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var g: Dictionary = d["vereine"][gegner]
	var staerker: bool = float(v["ruf"]) > float(g["ruf"]) + 8.0
	var derby: bool = float((v["rivalen"] as Dictionary).get(gegner, 0.0)) > 45.0
	var frage := "Wie gehen Sie die Partie gegen %s an?" % str(g["name"])
	if derby:
		frage = "Derby gegen %s — was bedeutet dieses Spiel für Sie?" % str(g["name"])
	elif not staerker:
		frage = "%s gilt als Favorit. Sehen Sie das auch so?" % str(g["name"])
	return {
		"frage": frage,
		"antworten": [
			{"text": "Wir sind klar besser und werden das zeigen.",
			 "fans": 3.0, "vorstand": 0.0, "moral": 2.0, "gegner_motivation": 0.045,
			 "echo": "Selbstbewusste Ansage vor dem Spiel."},
			{"text": "Ein starker Gegner. Wir müssen an unser Limit gehen.",
			 "fans": 0.5, "vorstand": 1.0, "moral": 0.5, "gegner_motivation": -0.015,
			 "echo": "Respektvolle Töne vor dem Anpfiff."},
			{"text": "Über den Gegner rede ich nicht, nur über uns.",
			 "fans": -1.0, "vorstand": 0.5, "moral": 1.0, "gegner_motivation": 0.0,
			 "echo": "Wortkarg vor dem Spiel."},
			{"text": "Wir sind Außenseiter, der Druck liegt woanders.",
			 "fans": -2.0, "vorstand": -0.5, "moral": 3.0, "gegner_motivation": 0.02,
			 "echo": "Der Trainer nimmt seiner Mannschaft die Last."},
		],
	}

static func _frage_lage(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var kurve: Array = v["formkurve"]
	var liga: Dictionary = d["ligen"][v["liga"]]
	var tabelle := Spielplan.tabelle_sortiert(d, str(liga["id"]))
	var platz: int = tabelle.find(cid) + 1
	var niederlagen := 0
	for i in range(kurve.size() - 1, maxi(kurve.size() - 4, -1), -1):
		if str(kurve[i]) == "N":
			niederlagen += 1
	if niederlagen >= 3:
		return {
			"frage": "Drei Niederlagen nacheinander. Was läuft schief?",
			"antworten": [
				{"text": "Die Mannschaft arbeitet hart, das dreht sich wieder.",
				 "fans": 0.0, "vorstand": 0.5, "moral": 3.0, "gegner_motivation": 0.0,
				 "echo": "Rückendeckung für die Mannschaft."},
				{"text": "Das war zu wenig. So kann es nicht weitergehen.",
				 "fans": 3.0, "vorstand": 1.5, "moral": -3.5, "gegner_motivation": 0.0,
				 "echo": "Deutliche Kritik an der eigenen Mannschaft."},
				{"text": "Verletzungen und der Terminplan fordern ihren Tribut.",
				 "fans": -2.5, "vorstand": -1.5, "moral": 1.0, "gegner_motivation": 0.0,
				 "echo": "Der Trainer verweist auf die Umstände."},
				{"text": "Die Verantwortung dafür trage ich.",
				 "fans": 2.0, "vorstand": -0.5, "moral": 2.5, "gegner_motivation": 0.0,
				 "echo": "Der Trainer nimmt die Schuld auf sich."},
			],
		}
	if platz > 0 and platz <= 2 and int(liga["tabelle"].get(cid, {}).get("sp", 0)) >= 8:
		return {
			"frage": "Platz %d — reden Sie schon von der Meisterschaft?" % platz,
			"antworten": [
				{"text": "Ja. Wir wollen diesen Titel.",
				 "fans": 4.0, "vorstand": 1.0, "moral": 1.5, "gegner_motivation": 0.035,
				 "echo": "Der Trainer ruft das Titelziel aus."},
				{"text": "Wir schauen von Spiel zu Spiel.",
				 "fans": 0.0, "vorstand": 1.0, "moral": 0.5, "gegner_motivation": 0.0,
				 "echo": "Betont nüchtern trotz Tabellenführung."},
				{"text": "Dafür ist es viel zu früh.",
				 "fans": -1.5, "vorstand": 0.5, "moral": 1.0, "gegner_motivation": -0.01,
				 "echo": "Der Trainer bremst die Erwartungen."},
			],
		}
	if float(v["vorstand"]["vertrauen"]) < 35.0:
		return {
			"frage": "Wie sicher ist Ihr Stuhl noch?",
			"antworten": [
				{"text": "Ich mache mir keine Gedanken darüber.",
				 "fans": 0.0, "vorstand": 0.0, "moral": 1.0, "gegner_motivation": 0.0,
				 "echo": "Gelassen trotz der Lage."},
				{"text": "Das entscheidet der Vorstand, nicht ich.",
				 "fans": -2.0, "vorstand": -1.5, "moral": -1.5, "gegner_motivation": 0.0,
				 "echo": "Der Trainer weicht aus."},
				{"text": "Ich stehe für meine Arbeit ein. Die Ergebnisse kommen.",
				 "fans": 2.5, "vorstand": 2.0, "moral": 2.0, "gegner_motivation": 0.0,
				 "echo": "Kämpferischer Auftritt."},
			],
		}
	return {}

static func _frage_spieler(d: Dictionary, cid: String) -> Dictionary:
	var kandidat := ""
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp.get("transferwunsch", false)):
			kandidat = sid
			break
	if kandidat == "":
		return {}
	var sp2: Dictionary = d["spieler"][kandidat]
	return {
		"frage": "%s soll wechseln wollen. Bleibt er?" % Spielerfabrik.voller_name(sp2),
		"spieler": kandidat,
		"antworten": [
			{"text": "Er ist unverkäuflich. Punkt.",
			 "fans": 3.0, "vorstand": -1.5, "moral": 0.0, "spieler_moral": 6.0, "gegner_motivation": 0.0,
			 "echo": "Klares Bekenntnis zum Leistungsträger."},
			{"text": "Bei einem passenden Angebot reden wir.",
			 "fans": -2.0, "vorstand": 1.5, "moral": -0.5, "spieler_moral": -5.0, "gegner_motivation": 0.0,
			 "echo": "Der Trainer lässt einen Abgang offen."},
			{"text": "Das ist Vereinssache, nicht meine.",
			 "fans": -0.5, "vorstand": 0.5, "moral": 0.0, "spieler_moral": -1.5, "gegner_motivation": 0.0,
			 "echo": "Der Trainer verweist an die Vereinsführung."},
		],
	}

# ----------------------------------------------------------- Antworten ---

## Beantwortet die aktuelle Frage und liefert das Presseecho zurück.
static func antworten(d: Dictionary, index: int) -> Dictionary:
	var k: Dictionary = d.get("pressekonferenz", {})
	if k.is_empty() or not bool(k["offen"]):
		return {}
	var fragen: Array = k["fragen"]
	var i: int = int(k["index"])
	if i >= fragen.size():
		return {}
	var frage: Dictionary = fragen[i]
	var antworten_liste: Array = frage["antworten"]
	if index < 0 or index >= antworten_liste.size():
		return {}
	var a: Dictionary = antworten_liste[index]
	var cid: String = Welt.mein_verein_id
	var v: Dictionary = d["vereine"][cid]
	v["fans"]["zufriedenheit"] = clampf(float(v["fans"]["zufriedenheit"]) + float(a.get("fans", 0.0)), 0.0, 100.0)
	v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) + float(a.get("vorstand", 0.0)), 0.0, 100.0)
	for sid in v["kader"]:
		d["spieler"][sid]["moral"] = clampf(float(d["spieler"][sid]["moral"]) + float(a.get("moral", 0.0)), 5.0, 100.0)
	if frage.has("spieler") and d["spieler"].has(str(frage["spieler"])):
		var sp: Dictionary = d["spieler"][str(frage["spieler"])]
		sp["moral"] = clampf(float(sp["moral"]) + float(a.get("spieler_moral", 0.0)), 5.0, 100.0)
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) - float(a.get("spieler_moral", 0.0)) * 0.8, 0.0, 100.0)
	var motivation: float = float(a.get("gegner_motivation", 0.0))
	if absf(motivation) > 0.001:
		var gegner: String = str(k["gegner"])
		if d["vereine"].has(gegner):
			d["vereine"][gegner]["extra_motivation"] = {
				"bis_tag": int(d["tag"]) + 3, "wert": motivation}
	(k["protokoll"] as Array).append({"frage": str(frage["frage"]), "antwort": str(a["text"]), "echo": str(a.get("echo", ""))})
	k["index"] = i + 1
	if int(k["index"]) >= fragen.size():
		_abschliessen(d, k)
	return a

static func _abschliessen(d: Dictionary, k: Dictionary) -> void:
	k["offen"] = false
	var zeilen: Array = []
	for e in k["protokoll"]:
		zeilen.append(str(e["echo"]))
	Medien.artikel(d, "Pressekonferenz: %s" % str(zeilen[0] if not zeilen.is_empty() else "Der Trainer spricht"),
		" ".join(zeilen), "neutral", "pressekonferenz", {"verein": Welt.mein_verein_id})
	var stimmung: float = float(d["vereine"][Welt.mein_verein_id]["fans"]["zufriedenheit"])
	Medien.beitrag(d, _fanreaktion(zeilen, stimmung), "neutral")

static func _fanreaktion(zeilen: Array, stimmung: float) -> String:
	if zeilen.is_empty():
		return "Wieder nichts Konkretes auf der PK."
	if stimmung > 65.0:
		return "Endlich mal einer, der sagt, was Sache ist."
	if stimmung < 40.0:
		return "Große Worte. Auf dem Feld sehen wir davon wenig."
	return "Solide PK. Zählen tut trotzdem nur Samstag."

## Überspringt eine offene Konferenz (kostet Sympathie).
static func absagen(d: Dictionary) -> void:
	var k: Dictionary = d.get("pressekonferenz", {})
	if k.is_empty() or not bool(k["offen"]):
		return
	k["offen"] = false
	var cid: String = Welt.mein_verein_id
	if cid != "" and d["vereine"].has(cid):
		var v: Dictionary = d["vereine"][cid]
		v["fans"]["zufriedenheit"] = clampf(float(v["fans"]["zufriedenheit"]) - 2.0, 0.0, 100.0)
	Medien.artikel(d, "Trainer sagt Pressekonferenz ab",
		"Vor dem Spiel gab es keine Auskunft. Im Umfeld sorgt das für Stirnrunzeln.", "kritik", "pressekonferenz")

## Zusatzmotivation eines Vereins aus Presseaussagen (0.0, wenn abgelaufen).
static func motivation(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"].get(cid, {})
	var m: Dictionary = v.get("extra_motivation", {})
	if m.is_empty() or int(d["tag"]) > int(m.get("bis_tag", 0)):
		return 0.0
	return float(m.get("wert", 0.0))
