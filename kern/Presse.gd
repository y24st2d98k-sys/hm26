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

## Eine Frage zum Gegner. Welche Liste gezogen wird, haengt an der Lage; die
## Saetze selbst stehen in kern/Textbank.gd.
##
## Vorher stand hier genau eine Frage je Lage mit vier festen Antworten. Nach
## zwei Spieltagen kannte man sie auswendig, und eine Pressekonferenz, deren
## Fragen man auswendig kennt, ist ein Formular.
static func _frage_gegner(d: Dictionary, cid: String, gegner: String, spiel: Dictionary) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var g: Dictionary = d["vereine"][gegner]
	var staerker: bool = float(v["ruf"]) > float(g["ruf"]) + 8.0
	var derby: bool = float((v["rivalen"] as Dictionary).get(gegner, 0.0)) > 45.0
	var quelle: Array = Textbank.PRESSE_GEGNER
	if derby:
		quelle = Textbank.PRESSE_DERBY
	elif not staerker:
		quelle = Textbank.PRESSE_AUSSENSEITER
	var vorlage: Dictionary = Namen.waehle(quelle)
	var frage: Dictionary = vorlage.duplicate(true)
	frage["frage"] = str(frage["frage"]) % str(g["name"]) if str(frage["frage"]).contains("%s") else str(frage["frage"])
	return frage

## Eine Frage zur Lage: Krise, Hoehenflug oder der eigene Stuhl.
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
		return (Namen.waehle(Textbank.PRESSE_KRISE) as Dictionary).duplicate(true)
	if platz > 0 and platz <= 2 and int(liga["tabelle"].get(cid, {}).get("sp", 0)) >= 8:
		var hoch: Dictionary = (Namen.waehle(Textbank.PRESSE_HOEHENFLUG) as Dictionary).duplicate(true)
		if str(hoch["frage"]).contains("%d"):
			hoch["frage"] = str(hoch["frage"]) % platz
		return hoch
	if float(v["vorstand"]["vertrauen"]) < 35.0:
		return (Namen.waehle(Textbank.PRESSE_STUHL) as Dictionary).duplicate(true)
	return {}

## Eine Frage zu einem einzelnen Spieler — zum Wechselwilligen, zum Mann in
## Form oder zum Nachwuchs, der nicht spielt.
static func _frage_spieler(d: Dictionary, cid: String) -> Dictionary:
	var wechsler := ""
	var bester := ""
	var beste_note := 9.0
	var jung := 0
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp.get("transferwunsch", false)) and wechsler == "":
			wechsler = sid
		var note: float = Spielerfabrik.note(sp)
		if note > 0.0 and note < beste_note and int(sp["stats"]["saison"]["spiele"]) >= 4:
			beste_note = note
			bester = sid
		if int(sp["alter"]) <= 21:
			jung += 1
	var moeglich: Array = []
	if wechsler != "":
		moeglich.append({"index": 0, "spieler": wechsler})
	if bester != "" and beste_note <= 2.6:
		moeglich.append({"index": 1, "spieler": bester})
	if jung >= 2:
		moeglich.append({"index": 2, "spieler": ""})
	if moeglich.is_empty():
		return {}
	var wahl: Dictionary = Namen.waehle(moeglich)
	var vorlage: Dictionary = (Textbank.PRESSE_SPIELER[int(wahl["index"])] as Dictionary).duplicate(true)
	var sid2: String = str(wahl["spieler"])
	if sid2 != "" and str(vorlage["frage"]).contains("%s"):
		vorlage["frage"] = str(vorlage["frage"]) % Spielerfabrik.voller_name(d["spieler"][sid2])
		vorlage["spieler"] = sid2
	return vorlage

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
		return str(Namen.waehle(Textbank.FANECHO["gut"]))
	if stimmung < 40.0:
		return str(Namen.waehle(Textbank.FANECHO["schlecht"]))
	return str(Namen.waehle(Textbank.FANECHO["mittel"]))

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
