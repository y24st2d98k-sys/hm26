class_name Auszeichnungen
extends RefCounted
## Ehrungen: Team der Woche, Spieler und Trainer des Monats, Saisonpreise.
##
## Eine Saison ohne Auszeichnungen ist eine Tabelle. Erst wenn jemand für einen
## guten Monat auch genannt wird, bekommt eine Karriere Zwischenstationen —
## und ein Kaderspieler einen Grund, sich über zu wenig Einsatzzeit zu ärgern.
##
## Alles Gewählte landet zusätzlich in der Laufbahn des Spielers und, wo es den
## eigenen Verein betrifft, im Nachrichteneingang.

## Wie viele Monats- und Saisonehrungen aufgehoben werden.
const HOECHSTZAHL := 120
## Mindestens so viele Einsätze für eine Monatswahl.
const MONAT_MINDESTSPIELE := 2

static func daten(d: Dictionary) -> Dictionary:
	if not d.has("auszeichnungen"):
		d["auszeichnungen"] = leer()
	return d["auszeichnungen"]

static func leer() -> Dictionary:
	return {"woche": {}, "woche_roh": {}, "monat": [], "saison": [], "monat_beginn": 0}

# ------------------------------------------------------- Team der Woche ---

## Wird beim Verbuchen jeder Ligapartie gefüllt (siehe Statistik._spielerstats).
static func leistung_merken(d: Dictionary, lid: String, sid: String, note: float, tore: int) -> void:
	var a := daten(d)
	var roh: Dictionary = a["woche_roh"]
	if not roh.has(lid):
		roh[lid] = []
	(roh[lid] as Array).append({"spieler": sid, "note": note, "tore": tore})

## Nach einem Spieltag: je Liga die beste Sieben aus den Noten dieses Tages.
static func woche_auswerten(d: Dictionary, mein: String) -> void:
	var a := daten(d)
	var roh: Dictionary = a["woche_roh"]
	for lid in roh.keys():
		var eintraege: Array = roh[lid]
		if eintraege.size() < 14:
			continue
		var sieben := {}
		var noten := {}
		for pos in Spielerfabrik.POSITIONEN:
			var best := ""
			var bw := 99.0
			for e in eintraege:
				var sid: String = str(e["spieler"])
				var sp: Dictionary = d["spieler"].get(sid, {})
				if sp.is_empty() or str(sp["position"]) != pos:
					continue
				if float(e["note"]) < bw:
					bw = float(e["note"])
					best = sid
			if best != "":
				sieben[pos] = best
				noten[best] = bw
		if sieben.size() < 5:
			continue
		a["woche"][lid] = {"tag": int(d["tag"]), "spieler": sieben, "noten": noten}
		_woche_melden(d, str(lid), sieben, mein)
	a["woche_roh"] = {}

static func _woche_melden(d: Dictionary, lid: String, sieben: Dictionary, mein: String) -> void:
	if mein == "":
		return
	var eigene: Array = []
	for pos in sieben.keys():
		var sid: String = str(sieben[pos])
		if str(d["spieler"][sid]["verein"]) == mein:
			eigene.append(Spielerfabrik.kurz_name(d["spieler"][sid]))
	if eigene.is_empty():
		return
	Welt.nachricht({
		"typ": "auszeichnung",
		"betreff": "Team der Woche: %d aus Ihrem Kader" % eigene.size(),
		"text": "%s %s in der besten Sieben des Spieltags der %s." % [", ".join(eigene),
			"steht" if eigene.size() == 1 else "stehen", str(d["ligen"][lid]["name"])],
	})

static func team_der_woche(d: Dictionary, lid: String) -> Dictionary:
	return (daten(d)["woche"] as Dictionary).get(lid, {})

# ------------------------------------------------------ Monatsehrungen ---

## Am Monatsersten: Spieler und Trainer des Monats je erster Liga.
static func monatswahl(d: Dictionary, mein: String) -> void:
	var a := daten(d)
	var beginn: int = int(a.get("monat_beginn", 0))
	var jetzt: int = int(d["tag"])
	if jetzt - beginn < 21:
		return
	a["monat_beginn"] = jetzt
	var monatsname: String = Kalender.MONATSNAMEN[Kalender.datum(maxi(jetzt - 15, 0), Welt.startjahr())["monat"] - 1]
	for lid in d["ligen"].keys():
		if int(d["ligen"][lid]["stufe"]) != 1:
			continue
		var spieler := _spieler_des_monats(d, str(lid))
		var trainer := _verein_des_monats(d, str(lid), beginn)
		if spieler == "" and trainer == "":
			continue
		var eintrag := {
			"tag": jetzt, "liga": str(lid), "monat": monatsname,
			"spieler": spieler, "verein": trainer,
		}
		(a["monat"] as Array).push_front(eintrag)
		if spieler != "":
			Laufbahn.eintragen(d, spieler, "allstar", "Spieler des Monats %s (%s)" % [
				monatsname, str(d["ligen"][lid]["name"])])
		_monat_melden(d, eintrag, mein)
	while (a["monat"] as Array).size() > HOECHSTZAHL:
		(a["monat"] as Array).pop_back()

static func _spieler_des_monats(d: Dictionary, lid: String) -> String:
	var best := ""
	var bw := 99.0
	for cid in d["ligen"][lid]["vereine"]:
		for sid in d["vereine"][cid]["kader"]:
			var sp: Dictionary = d["spieler"][sid]
			var m: Dictionary = sp["stats"].get("monat", {})
			if int(m.get("spiele", 0)) < MONAT_MINDESTSPIELE:
				continue
			var noten: int = int(m.get("noten", 0))
			if noten <= 0:
				continue
			var note: float = float(m["note_summe"]) / float(noten)
			if note < bw:
				bw = note
				best = sid
	return best

## Der Verein mit der besten Punktausbeute seit der letzten Wahl.
static func _verein_des_monats(d: Dictionary, lid: String, seit: int) -> String:
	var punkte := {}
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if not bool(m.get("gespielt", false)) or str(m["wettbewerb"]) != lid:
			continue
		if int(m["tag"]) < seit:
			continue
		var th: int = int(m["tore_heim"])
		var tg: int = int(m["tore_gast"])
		var heim: String = str(m["heim"])
		var gast: String = str(m["gast"])
		punkte[heim] = int(punkte.get(heim, 0)) + (2 if th > tg else (1 if th == tg else 0))
		punkte[gast] = int(punkte.get(gast, 0)) + (2 if tg > th else (1 if th == tg else 0))
	var best := ""
	var bw := -1
	for cid in punkte.keys():
		if int(punkte[cid]) > bw:
			bw = int(punkte[cid])
			best = str(cid)
	return best if bw > 0 else ""

static func _monat_melden(d: Dictionary, e: Dictionary, mein: String) -> void:
	if mein == "":
		return
	var sid: String = str(e["spieler"])
	if sid != "" and str(d["spieler"][sid]["verein"]) == mein:
		Welt.nachricht({
			"typ": "auszeichnung", "wichtig": true,
			"betreff": "Spieler des Monats: %s" % Spielerfabrik.voller_name(d["spieler"][sid]),
			"text": "%s ist zum besten Spieler des Monats %s der %s gewählt worden." % [
				Spielerfabrik.voller_name(d["spieler"][sid]), str(e["monat"]), str(d["ligen"][e["liga"]]["name"])],
			"daten": {"spieler": sid},
		})
	if str(e["verein"]) == mein:
		Welt.nachricht({
			"typ": "auszeichnung", "wichtig": true,
			"betreff": "Trainer des Monats %s" % str(e["monat"]),
			"text": "Die beste Punktausbeute des Monats — die Wahl fiel auf Sie.",
		})
		var t: Dictionary = d.get("trainer", {})
		if not t.is_empty():
			t["ruf"] = clampf(float(t["ruf"]) + 0.8, 1.0, 100.0)
			t["monatstitel"] = int(t.get("monatstitel", 0)) + 1

## Monatsstatistik aller Spieler zurücksetzen — direkt nach der Wahl.
static func monat_zuruecksetzen(d: Dictionary) -> void:
	for sid in d["spieler"].keys():
		d["spieler"][sid]["stats"]["monat"] = Spielerfabrik.leere_saisonstats()

# ------------------------------------------------------ Saisonehrungen ---

## Zusätzliche Preise zum Saisonende: bester Neuzugang, bester junger Spieler
## und Trainer der Saison. Torschützenkönig, wertvollster Spieler und Team der
## Saison vergibt bereits kern/Saison.gd.
static func saisonehrungen(d: Dictionary, lid: String, mein: String) -> void:
	var a := daten(d)
	var saison: int = Welt.saison_index()
	var liganame: String = str(d["ligen"][lid]["name"])
	var neuzugang := _bester(d, lid, func(sp: Dictionary) -> bool:
		return _kam_diese_saison(d, str(sp["id"])))
	var talent := _bester(d, lid, func(sp: Dictionary) -> bool:
		return int(sp["alter"]) <= 21)
	var trainer := _trainer_der_saison(d, lid)
	var eintrag := {
		"saison": saison, "liga": lid, "neuzugang": neuzugang,
		"talent": talent, "trainerverein": trainer,
	}
	(a["saison"] as Array).push_front(eintrag)
	while (a["saison"] as Array).size() > HOECHSTZAHL:
		(a["saison"] as Array).pop_back()
	if neuzugang != "":
		Laufbahn.eintragen(d, neuzugang, "allstar", "Neuzugang der Saison der %s" % liganame)
	if talent != "":
		Laufbahn.eintragen(d, talent, "allstar", "Nachwuchsspieler der Saison der %s" % liganame)
	_saison_melden(d, eintrag, liganame, mein)

## Bester Spieler der Liga nach Durchschnittsnote, der eine Bedingung erfüllt.
static func _bester(d: Dictionary, lid: String, bedingung: Callable) -> String:
	var best := ""
	var bw := 99.0
	for cid in d["ligen"][lid]["vereine"]:
		for sid in d["vereine"][cid]["kader"]:
			var sp: Dictionary = d["spieler"][sid]
			if int(sp["stats"]["saison"]["spiele"]) < 10:
				continue
			if not bool(bedingung.call(sp)):
				continue
			var note: float = Spielerfabrik.note(sp)
			if note > 0.0 and note < bw:
				bw = note
				best = sid
	return best

## Ist der Spieler in dieser Saison zum Verein gekommen?
static func _kam_diese_saison(d: Dictionary, sid: String) -> bool:
	var saison: int = Welt.saison_index()
	for e in Laufbahn.liste(d["spieler"][sid]):
		if int(e.get("saison", -1)) != saison:
			continue
		if str(e.get("art", "")) in ["wechsel", "leihe", "jugend"]:
			return true
	return false

## Der Trainer mit der besten Saison gemessen an der Erwartung des Vorstands.
static func _trainer_der_saison(d: Dictionary, lid: String) -> String:
	var tabelle: Array = d["ligen"][lid].get("abschlusstabelle", [])
	if tabelle.is_empty():
		return ""
	var best := ""
	var bw := -99.0
	for i in range(tabelle.size()):
		var cid: String = str(tabelle[i])
		var ziel: int = int(d["vereine"][cid]["vorstand"].get("ziel_platz", i + 1))
		var uebertroffen: float = float(ziel - (i + 1))
		if uebertroffen > bw:
			bw = uebertroffen
			best = cid
	return best if bw > 0.0 else ""

static func _saison_melden(d: Dictionary, e: Dictionary, liganame: String, mein: String) -> void:
	if mein == "":
		return
	for schluessel in ["neuzugang", "talent"]:
		var sid: String = str(e[schluessel])
		if sid == "" or str(d["spieler"][sid]["verein"]) != mein:
			continue
		Welt.nachricht({
			"typ": "auszeichnung", "wichtig": true,
			"betreff": "%s der Saison: %s" % [
				"Neuzugang" if schluessel == "neuzugang" else "Nachwuchsspieler",
				Spielerfabrik.voller_name(d["spieler"][sid])],
			"text": "Die %s ehrt %s für seine Saison." % [liganame, Spielerfabrik.voller_name(d["spieler"][sid])],
			"daten": {"spieler": sid},
		})
	if str(e["trainerverein"]) == mein:
		var t: Dictionary = d.get("trainer", {})
		if not t.is_empty():
			t["ruf"] = clampf(float(t["ruf"]) + 3.0, 1.0, 100.0)
			t["saisontitel"] = int(t.get("saisontitel", 0)) + 1
			(t["titel"] as Array).append({"saison": Welt.saison_index(),
				"titel": "Trainer der Saison (%s)" % liganame, "verein": mein})
		Welt.nachricht({
			"typ": "auszeichnung", "wichtig": true,
			"betreff": "Trainer der Saison",
			"text": "Sie haben mit %s die Erwartungen am deutlichsten übertroffen — die %s zeichnet Sie aus." % [
				str(d["vereine"][mein]["name"]), liganame],
		})

## Alle Monatsehrungen einer Liga, neueste zuerst.
static func monatsliste(d: Dictionary, lid: String = "") -> Array:
	var liste: Array = []
	for e in (daten(d)["monat"] as Array):
		if lid == "" or str(e["liga"]) == lid:
			liste.append(e)
	return liste

static func saisonliste(d: Dictionary, lid: String = "") -> Array:
	var liste: Array = []
	for e in (daten(d)["saison"] as Array):
		if lid == "" or str(e["liga"]) == lid:
			liste.append(e)
	return liste
