class_name Laufbahn
extends RefCounted
## Die Laufbahn eines Spielers: was in seinem Sportlerleben passiert ist.
##
## Statistik sagt, wie viel einer getroffen hat. Die Laufbahn sagt, wo er
## herkommt: Debüt, Wechsel, Titel, Berufungen, Meilensteine, schwere
## Verletzungen, das Karriereende. Erst damit wird aus einer Zeile in der
## Kaderliste eine Person mit Vergangenheit — und ein Transfer zu einer
## Entscheidung über jemanden, den man einordnen kann.
##
## Gespeichert wird je Spieler in `sp["laufbahn"]`, neueste Einträge zuerst.

const HOECHSTZAHL := 60

## Tore- und Spiele-Marken, die einen Eintrag wert sind.
const TORMARKEN := [50, 100, 200, 300, 500, 750, 1000]
const SPIELMARKEN := [50, 100, 200, 300, 400, 500]
const PARADENMARKEN := [250, 500, 1000, 1500, 2000]

const FARBEN := {
	"debuet": "blau", "wechsel": "matt", "leihe": "matt", "titel": "akzent",
	"allstar": "akzent", "torjaeger": "akzent", "meilenstein": "gruen",
	"nationalelf": "lila", "verletzung": "rot", "ende": "matt", "jugend": "blau",
}

static func liste(sp: Dictionary) -> Array:
	return sp.get("laufbahn", [])

static func eintragen(d: Dictionary, sid: String, art: String, text: String) -> void:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty():
		return
	if not sp.has("laufbahn"):
		sp["laufbahn"] = []
	var eintraege: Array = sp["laufbahn"]
	# Denselben Eintrag am selben Tag nicht zweimal — mehrere Wettbewerbe
	# koennen dieselbe Marke gleichzeitig ausloesen.
	if not eintraege.is_empty():
		var letzter: Dictionary = eintraege[0]
		if int(letzter["tag"]) == int(d["tag"]) and str(letzter["text"]) == text:
			return
	eintraege.push_front({
		"tag": int(d["tag"]),
		"saison": Kalender.saison_index(int(d["tag"])),
		"art": art,
		"text": text,
	})
	if eintraege.size() > HOECHSTZAHL:
		eintraege.resize(HOECHSTZAHL)

# ------------------------------------------------------------- Anlaesse ---

static func debuet_pruefen(d: Dictionary, sid: String) -> void:
	var sp: Dictionary = d["spieler"][sid]
	if int(sp["stats"]["karriere"]["spiele"]) != 1:
		return
	var verein: String = str(Welt.verein(str(sp["verein"])).get("name", ""))
	eintragen(d, sid, "debuet", "Pflichtspieldebüt%s, mit %d Jahren" % [
		" für %s" % verein if verein != "" else "", int(sp["alter"])])

static func wechsel(d: Dictionary, sid: String, von: String, nach: String, ablöse: float) -> void:
	var von_name: String = str(d["vereine"].get(von, {}).get("name", ""))
	var nach_name: String = str(d["vereine"].get(nach, {}).get("name", ""))
	if nach_name == "":
		eintragen(d, sid, "wechsel", "Vertrag bei %s aufgelöst — vereinslos" % von_name)
		return
	var preis: String = " für %s" % Stil.geld(ablöse) if ablöse >= 1000.0 else " ablösefrei"
	if von_name == "":
		eintragen(d, sid, "wechsel", "Ablösefrei zu %s gewechselt" % nach_name)
		return
	eintragen(d, sid, "wechsel", "Von %s zu %s%s" % [von_name, nach_name, preis])

static func leihe(d: Dictionary, sid: String, von: String, nach: String) -> void:
	eintragen(d, sid, "leihe", "Auf Leihbasis von %s zu %s" % [
		str(d["vereine"].get(von, {}).get("name", "—")),
		str(d["vereine"].get(nach, {}).get("name", "—"))])

static func aus_der_jugend(d: Dictionary, sid: String, cid: String) -> void:
	eintragen(d, sid, "jugend", "Aus der eigenen Jugend in den Profikader von %s" % [
		str(d["vereine"].get(cid, {}).get("name", "—"))])

## Titel für alle, die in der Saison mitgespielt haben — Reservisten der
## letzten Woche schreiben sich keinen Meistertitel in die Vita.
static func titel(d: Dictionary, cid: String, bezeichnung: String) -> void:
	for sid in d["vereine"].get(cid, {}).get("kader", []):
		var sp: Dictionary = d["spieler"].get(sid, {})
		if sp.is_empty() or int(sp["stats"]["saison"]["spiele"]) < 5:
			continue
		eintragen(d, sid, "titel", "%s mit %s" % [bezeichnung, str(d["vereine"][cid]["name"])])

static func allstar(d: Dictionary, sid: String, liga_name: String) -> void:
	eintragen(d, sid, "allstar", "Ins Team der Saison der %s gewählt" % liga_name)

static func torjaeger(d: Dictionary, sid: String, liga_name: String, tore: int) -> void:
	eintragen(d, sid, "torjaeger", "Torschützenkönig der %s mit %d Treffern" % [liga_name, tore])

static func nationalelf(d: Dictionary, sid: String, turnier: String) -> void:
	eintragen(d, sid, "nationalelf", "Für %s nominiert" % turnier)

static func schwere_verletzung(d: Dictionary, sid: String, art: String, tage: int) -> void:
	if tage < 56:
		return
	eintragen(d, sid, "verletzung", "%s — etwa %d Tage Ausfall" % [art, tage])

static func karriereende(d: Dictionary, sid: String) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var k: Dictionary = sp["stats"]["karriere"]
	if bool(sp["ist_torwart"]):
		eintragen(d, sid, "ende", "Karriereende mit %d Jahren — %d Spiele, %d Paraden" % [
			int(sp["alter"]), int(k["spiele"]), int(k["paraden"])])
	else:
		eintragen(d, sid, "ende", "Karriereende mit %d Jahren — %d Spiele, %d Tore" % [
			int(sp["alter"]), int(k["spiele"]), int(k["tore"])])

## Runde Marken in Spielen, Toren und Paraden. Geprüft wird das Überschreiten,
## nicht das Treffen — in einem Spiel fallen mehrere Tore auf einmal.
static func marken_pruefen(d: Dictionary, sid: String, vorher: Dictionary) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var k: Dictionary = sp["stats"]["karriere"]
	_marke(d, sid, SPIELMARKEN, int(vorher.get("spiele", 0)), int(k["spiele"]), "%d. Pflichtspiel")
	if bool(sp["ist_torwart"]):
		_marke(d, sid, PARADENMARKEN, int(vorher.get("paraden", 0)), int(k["paraden"]), "%d. Parade der Karriere")
	else:
		_marke(d, sid, TORMARKEN, int(vorher.get("tore", 0)), int(k["tore"]), "%d. Karrieretreffer")

static func _marke(d: Dictionary, sid: String, marken: Array, vorher: int, nachher: int, vorlage: String) -> void:
	if nachher <= vorher:
		return
	for marke in marken:
		var m: int = int(marke)
		if vorher < m and nachher >= m:
			eintragen(d, sid, "meilenstein", vorlage % m)
			return

## Farbschlüssel für die Oberfläche.
static func farbe(art: String) -> Color:
	match str(FARBEN.get(art, "matt")):
		"akzent":
			return Stil.AKZENT
		"gruen":
			return Stil.GRUEN
		"blau":
			return Stil.BLAU
		"lila":
			return Stil.LILA
		"rot":
			return Stil.ROT
		_:
			return Stil.TEXT_MATT
