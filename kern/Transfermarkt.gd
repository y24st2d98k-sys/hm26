class_name Transfermarkt
extends RefCounted
## Transfermarkt: Suche, Verhandlung, Leihe, Vertragsgespraeche — und der KI-Markt.
##
## Ein Angebot laeuft in zwei Stufen: erst einigt man sich mit dem abgebenden Verein
## ueber die Abloese, danach mit dem Spieler ueber Gehalt, Rolle und Laufzeit. Beide
## Seiten koennen ablehnen, nachverhandeln oder abwarten — Zeitdruck entsteht durch
## das Transferfenster, das nur im Sommer und im Januar offen steht.

const SOMMER_VON := 0
const SOMMER_BIS := 61
const WINTER_VON := 184
const WINTER_BIS := 213

const ROLLEN := ["leistungstraeger", "stammspieler", "rotation", "ergaenzung", "talent"]
const ROLLEN_NAME := {
	"leistungstraeger": "Leistungsträger", "stammspieler": "Stammspieler",
	"rotation": "Rotationsspieler", "ergaenzung": "Ergänzungsspieler", "talent": "Talent",
}

static func fenster_offen(d: Dictionary) -> bool:
	var tis: int = Kalender.tag_in_saison(int(d["tag"]))
	return (tis >= SOMMER_VON and tis <= SOMMER_BIS) or (tis >= WINTER_VON and tis <= WINTER_BIS)

static func tage_bis_fensterschluss(d: Dictionary) -> int:
	var tis: int = Kalender.tag_in_saison(int(d["tag"]))
	if tis <= SOMMER_BIS:
		return SOMMER_BIS - tis
	if tis < WINTER_VON:
		return -(WINTER_VON - tis)
	if tis <= WINTER_BIS:
		return WINTER_BIS - tis
	return -(365 - tis)

# ------------------------------------------------------------------ Suche ---

## Durchsucht alle Spieler nach Kriterien. filter kennt:
## position, max_alter, min_alter, max_ablöse, max_gehalt, min_gesamt, nur_transferliste,
## nur_vertragsende, nur_vereinslos, nation, text
static func suchen(d: Dictionary, filter: Dictionary, eigener_verein: String = "") -> Array:
	var treffer: Array = []
	var saison: int = Welt.saison_index()
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["verein"]) == eigener_verein and eigener_verein != "":
			continue
		if filter.has("position") and str(filter["position"]) != "" and str(sp["position"]) != str(filter["position"]):
			continue
		if filter.has("max_alter") and int(sp["alter"]) > int(filter["max_alter"]):
			continue
		if filter.has("min_alter") and int(sp["alter"]) < int(filter["min_alter"]):
			continue
		if bool(filter.get("nur_vereinslos", false)) and str(sp["verein"]) != "":
			continue
		if bool(filter.get("nur_transferliste", false)) and not bool(sp.get("auf_transferliste", false)) and not bool(sp.get("transferwunsch", false)):
			continue
		if bool(filter.get("nur_vertragsende", false)):
			if str(sp["verein"]) != "" and int(sp["vertrag"].get("bis_saison", 9)) > saison:
				continue
		if filter.has("min_gesamt") and Spielerfabrik.gesamt(sp) < float(filter["min_gesamt"]):
			continue
		if filter.has("max_ablöse") and str(sp["verein"]) != "" and ablösevorstellung(d, sid) > float(filter["max_ablöse"]):
			continue
		if filter.has("max_gehalt") and Spielerfabrik.gehaltsvorstellung(sp, 60.0) > float(filter["max_gehalt"]):
			continue
		if filter.has("nation") and str(filter["nation"]) != "" and str(sp["nation"]) != str(filter["nation"]):
			continue
		if filter.has("text") and str(filter["text"]) != "":
			var suche: String = str(filter["text"]).to_lower()
			if not Spielerfabrik.voller_name(sp).to_lower().contains(suche):
				continue
		treffer.append(sid)
	treffer.sort_custom(func(a, b): return Spielerfabrik.gesamt(d["spieler"][a]) > Spielerfabrik.gesamt(d["spieler"][b]))
	return treffer.slice(0, int(filter.get("limit", 120)))

## Was der abgebende Verein mindestens sehen will.
static func ablösevorstellung(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = d["spieler"][sid]
	if str(sp["verein"]) == "":
		return 0.0
	var wert: float = float(sp["wert"])
	var rest: int = maxi(int(sp["vertrag"].get("bis_saison", 0)) - Welt.saison_index(), 0)
	var faktor: float = 1.0 + 0.16 * float(rest)
	if bool(sp.get("auf_transferliste", false)):
		faktor *= 0.78
	if bool(sp.get("transferwunsch", false)):
		faktor *= 0.85
	var rolle: String = str(sp["vertrag"].get("rolle", "rotation"))
	if rolle == "leistungstraeger":
		faktor *= 1.35
	elif rolle == "stammspieler":
		faktor *= 1.15
	elif rolle == "ergaenzung":
		faktor *= 0.9
	if rest <= 0:
		faktor = 0.0
	return wert * faktor

# --------------------------------------------------------------- Angebote ---

static func _neue_angebots_id(d: Dictionary) -> String:
	d["zaehler"]["auftrag"] = int(d["zaehler"]["auftrag"]) + 1
	return "a_%05d" % int(d["zaehler"]["auftrag"])

## Der Spieler gibt ein Angebot fuer einen fremden Spieler ab.
static func angebot_abgeben(d: Dictionary, sid: String, ablöse: float, gehalt: float, laufzeit: int,
		rolle: String, art: String = "kauf") -> Dictionary:
	var cid: String = Welt.mein_verein_id
	if cid == "":
		return {"ok": false, "grund": "Sie haben derzeit keinen Verein."}
	if not fenster_offen(d) and art != "vorvertrag":
		return {"ok": false, "grund": "Das Transferfenster ist geschlossen."}
	var sp: Dictionary = d["spieler"][sid]
	var v: Dictionary = d["vereine"][cid]
	if art == "kauf" and ablöse > float(v["transferbudget"]) + float(v["kasse"]):
		return {"ok": false, "grund": "Ablöse und Budget passen nicht zusammen."}
	if (v["kader"] as Array).size() >= 26:
		return {"ok": false, "grund": "Der Kader ist voll (max. 26 Spieler)."}
	var angebot := {
		"id": _neue_angebots_id(d),
		"art": art,
		"spieler": sid,
		"von": str(sp["verein"]),
		"nach": cid,
		"ablöse": ablöse,
		"gehalt": gehalt,
		"laufzeit": laufzeit,
		"rolle": rolle,
		"status": "offen",
		"richtung": "ausgehend",
		"frist_tag": int(d["tag"]) + Namen.wuerfel(1, 3),
		"antwort": "",
		"leihgebuehr_anteil": 0.5,
	}
	(d["transfermarkt"]["angebote"] as Array).append(angebot)
	return {"ok": true, "grund": "Angebot übermittelt. Eine Antwort wird in den nächsten Tagen erwartet."}

## Taegliche Bearbeitung aller offenen Angebote.
static func tageswechsel(d: Dictionary) -> void:
	d["transfermarkt"]["fenster_offen"] = fenster_offen(d)
	var offen: Array = d["transfermarkt"]["angebote"]
	var behalten: Array = []
	for a in offen:
		if str(a["status"]) in ["abgeschlossen", "abgelehnt", "zurueckgezogen"]:
			if int(d["tag"]) - int(a["frist_tag"]) < 21:
				behalten.append(a)
			continue
		if int(d["tag"]) < int(a["frist_tag"]):
			behalten.append(a)
			continue
		_angebot_bearbeiten(d, a)
		behalten.append(a)
	d["transfermarkt"]["angebote"] = behalten
	if Kalender.wochentag(int(d["tag"])) == 1:
		_ki_transferrunde(d)
	_deadline_hinweis(d)

static func _deadline_hinweis(d: Dictionary) -> void:
	var rest: int = tage_bis_fensterschluss(d)
	if Welt.mein_verein_id == "":
		return
	if rest in [7, 3, 1] and fenster_offen(d):
		Welt.nachricht({
			"typ": "transfer", "wichtig": rest <= 3,
			"betreff": "Transferfenster: noch %d Tage" % rest,
			"text": "Danach sind bis zum nächsten Fenster keine Verpflichtungen mehr möglich. Offene Verhandlungen sollten jetzt entschieden werden.",
		})

static func _angebot_bearbeiten(d: Dictionary, a: Dictionary) -> void:
	var sid: String = str(a["spieler"])
	if not d["spieler"].has(sid):
		a["status"] = "abgelehnt"
		return
	var sp: Dictionary = d["spieler"][sid]
	var status: String = str(a["status"])
	if status == "offen":
		if str(a["von"]) == "":
			a["status"] = "verein_einig"
			_spielerverhandlung(d, a)
			return
		_vereinsverhandlung(d, a)
	elif status == "verein_einig":
		_spielerverhandlung(d, a)

static func _vereinsverhandlung(d: Dictionary, a: Dictionary) -> void:
	var sid: String = str(a["spieler"])
	var sp: Dictionary = d["spieler"][sid]
	var von: String = str(a["von"])
	var verkaeufer: Dictionary = d["vereine"][von]
	var forderung: float = ablösevorstellung(d, sid)
	var geboten: float = float(a["ablöse"])
	var not_verkauf: bool = float(verkaeufer["kasse"]) < 0.0
	var schwelle: float = forderung * (0.82 if not_verkauf else 0.97)
	# Wie wichtig ist der Spieler fuer den abgebenden Verein?
	var ersatz_vorhanden: bool = _hat_ersatz(d, von, sid)
	if not ersatz_vorhanden:
		schwelle *= 1.28
	if bool(sp.get("transferwunsch", false)):
		schwelle *= 0.86
	if geboten >= schwelle:
		a["status"] = "verein_einig"
		a["antwort"] = "%s stimmt einer Ablöse von %s zu. Jetzt entscheidet der Spieler." % [verkaeufer["name"], Stil.geld(geboten)]
		a["frist_tag"] = int(d["tag"]) + Namen.wuerfel(1, 3)
		_melde(d, a, "Einigung mit %s" % verkaeufer["name"], a["antwort"])
	elif geboten >= schwelle * 0.8:
		a["status"] = "gegenangebot"
		a["gegenforderung"] = schwelle * Namen.bereich(1.0, 1.08)
		a["antwort"] = "%s fordert %s." % [verkaeufer["name"], Stil.geld(float(a["gegenforderung"]))]
		a["frist_tag"] = int(d["tag"]) + 2
		_melde(d, a, "Gegenangebot von %s" % verkaeufer["name"], a["antwort"])
	else:
		a["status"] = "abgelehnt"
		a["antwort"] = "%s lehnt das Angebot deutlich ab." % verkaeufer["name"]
		_melde(d, a, "Angebot abgelehnt", a["antwort"])

static func _hat_ersatz(d: Dictionary, cid: String, sid: String) -> bool:
	var sp: Dictionary = d["spieler"][sid]
	var pos: String = str(sp["position"])
	var anzahl := 0
	for anderer in d["vereine"][cid]["kader"]:
		if anderer == sid:
			continue
		var asp: Dictionary = d["spieler"][anderer]
		if str(asp["position"]) == pos or Spielerfabrik.eignung(asp, pos) > 0.8:
			anzahl += 1
	return anzahl >= (1 if pos == "TW" else 2)

static func _spielerverhandlung(d: Dictionary, a: Dictionary) -> void:
	var sid: String = str(a["spieler"])
	var sp: Dictionary = d["spieler"][sid]
	var nach: String = str(a["nach"])
	var kaeufer: Dictionary = d["vereine"][nach]
	var wunsch: float = Spielerfabrik.gehaltsvorstellung(sp, float(kaeufer["ruf"]))
	var geboten: float = float(a["gehalt"])
	var attraktivitaet := _attraktivitaet(d, sp, nach, str(a["rolle"]))
	var schwelle: float = wunsch * clampf(1.12 - attraktivitaet * 0.28, 0.78, 1.25)
	if geboten >= schwelle:
		_transfer_vollziehen(d, a)
	elif geboten >= schwelle * 0.85:
		a["status"] = "spieler_gegenangebot"
		a["gehaltsforderung"] = schwelle * Namen.bereich(1.0, 1.06)
		a["antwort"] = "%s verlangt %s pro Woche." % [Spielerfabrik.voller_name(sp), Stil.geld(float(a["gehaltsforderung"]))]
		a["frist_tag"] = int(d["tag"]) + 2
		_melde(d, a, "Gehaltsforderung von %s" % Spielerfabrik.voller_name(sp), a["antwort"])
	else:
		a["status"] = "abgelehnt"
		a["antwort"] = "%s sieht keine sportliche Perspektive bei diesem Angebot." % Spielerfabrik.voller_name(sp)
		_melde(d, a, "Spieler lehnt ab", a["antwort"])

## 0..1 — wie attraktiv ist ein Wechsel fuer den Spieler?
static func _attraktivitaet(d: Dictionary, sp: Dictionary, ziel: String, rolle: String) -> float:
	var neu: Dictionary = d["vereine"][ziel]
	var alt_ruf: float = 30.0
	if str(sp["verein"]) != "" and d["vereine"].has(str(sp["verein"])):
		alt_ruf = float(d["vereine"][str(sp["verein"])]["ruf"])
	var wert := 0.4
	wert += clampf((float(neu["ruf"]) - alt_ruf) / 60.0, -0.35, 0.45)
	var rollen_wert: float = {"leistungstraeger": 0.22, "stammspieler": 0.14, "rotation": 0.0, "ergaenzung": -0.16, "talent": 0.04}.get(rolle, 0.0)
	# Schwache Spieler freuen sich ueber grosse Rollen, starke erwarten sie
	var eigen: float = Spielerfabrik.gesamt(sp)
	var kaderstaerke := _kaderstaerke(d, ziel)
	wert += rollen_wert * (1.4 if eigen < kaderstaerke else 0.7)
	if bool(sp.get("transferwunsch", false)):
		wert += 0.18
	var loyalitaet: float = float(sp["charakter"].get("loyalitaet", 12.0)) / 20.0
	wert -= loyalitaet * 0.12
	if str(sp["nation"]) == str(neu["nation"]):
		wert += 0.06
	if str(d.get("trainer", {}).get("verein", "")) == ziel:
		wert += clampf(float(d["trainer"]["ruf"]) / 300.0, 0.0, 0.3)
	return clampf(wert, 0.0, 1.0)

static func _kaderstaerke(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	var n := 0
	for sid in d["vereine"][cid]["kader"]:
		summe += Spielerfabrik.gesamt(d["spieler"][sid])
		n += 1
	return summe / maxf(float(n), 1.0)

static func _melde(d: Dictionary, a: Dictionary, betreff: String, text: String) -> void:
	if str(a["nach"]) != Welt.mein_verein_id and str(a["von"]) != Welt.mein_verein_id:
		return
	Welt.nachricht({
		"typ": "transfer", "betreff": betreff, "text": text,
		"daten": {"angebot": str(a["id"]), "spieler": str(a["spieler"])},
	})

## Nachbessern eines laufenden Angebots.
static func nachbessern(d: Dictionary, angebots_id: String, ablöse: float, gehalt: float) -> Dictionary:
	for a in d["transfermarkt"]["angebote"]:
		if str(a["id"]) != angebots_id:
			continue
		if str(a["status"]) in ["abgeschlossen", "abgelehnt"]:
			return {"ok": false, "grund": "Diese Verhandlung ist beendet."}
		a["ablöse"] = ablöse
		a["gehalt"] = gehalt
		a["status"] = "offen" if str(a["status"]) == "gegenangebot" else "verein_einig"
		a["frist_tag"] = int(d["tag"]) + Namen.wuerfel(1, 2)
		return {"ok": true, "grund": "Nachgebessertes Angebot übermittelt."}
	return {"ok": false, "grund": "Angebot nicht gefunden."}

static func zurueckziehen(d: Dictionary, angebots_id: String) -> void:
	for a in d["transfermarkt"]["angebote"]:
		if str(a["id"]) == angebots_id:
			a["status"] = "zurueckgezogen"

# ------------------------------------------------------------- Vollziehen ---

static func _transfer_vollziehen(d: Dictionary, a: Dictionary) -> void:
	var sid: String = str(a["spieler"])
	var nach: String = str(a["nach"])
	var von: String = str(a["von"])
	var ablöse: float = float(a["ablöse"])
	if str(a["art"]) == "leihe":
		leihe_vollziehen(d, sid, nach, int(a["laufzeit"]))
		a["status"] = "abgeschlossen"
		return
	transfer_durchfuehren(d, sid, nach, ablöse, float(a["gehalt"]), int(a["laufzeit"]), str(a["rolle"]))
	a["status"] = "abgeschlossen"
	a["antwort"] = "Der Wechsel ist perfekt."
	_melde(d, a, "Transfer abgeschlossen", "%s wechselt für %s." % [Spielerfabrik.voller_name(d["spieler"][sid]), Stil.geld(ablöse)])

static func transfer_durchfuehren(d: Dictionary, sid: String, nach: String, ablöse: float,
		gehalt: float, laufzeit: int, rolle: String) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var von: String = str(sp["verein"])
	if von != "" and d["vereine"].has(von):
		(d["vereine"][von]["kader"] as Array).erase(sid)
		Finanzen.buchen(d, von, ablöse, "Transfererlös %s" % Spielerfabrik.voller_name(sp), "transfer")
		_aufstellung_saeubern(d, von, sid)
	if nach != "" and d["vereine"].has(nach):
		(d["vereine"][nach]["kader"] as Array).append(sid)
		Finanzen.buchen(d, nach, -ablöse, "Ablöse %s" % Spielerfabrik.voller_name(sp), "transfer")
		d["vereine"][nach]["transferbudget"] = maxf(float(d["vereine"][nach]["transferbudget"]) - ablöse, 0.0)
	sp["verein"] = nach
	sp["kenntnis"] = 100.0 if nach == Welt.mein_verein_id else float(sp["kenntnis"])
	sp["vertrag"] = {
		"bis_saison": Welt.saison_index() + maxi(laufzeit, 1),
		"gehalt": gehalt,
		"rolle": rolle,
		"ablöseklausel": 0.0,
		"unterschrieben_saison": Welt.saison_index(),
		"praemie_tor": 0.0,
		"praemie_sieg": 0.0,
	}
	sp["auf_transferliste"] = false
	sp["transferwunsch"] = false
	sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) - 40.0, 0.0, 100.0)
	sp["moral"] = clampf(float(sp["moral"]) + 12.0, 5.0, 100.0)
	(d["transfermarkt"]["verlauf"] as Array).push_front({
		"tag": int(d["tag"]), "spieler": sid, "von": von, "nach": nach, "ablöse": ablöse, "art": "kauf",
	})
	Medien.transfer_meldung(d, sid, von, nach, ablöse)
	Chronik.transfer_pruefen(d, sid, ablöse)
	if nach != "":
		Weltgenerator._setze_standardaufstellung(d, nach)

static func _aufstellung_saeubern(d: Dictionary, cid: String, sid: String) -> void:
	var auf: Dictionary = d["vereine"][cid]["aufstellung"]
	for block in ["angriff", "abwehr"]:
		var b: Dictionary = auf.get(block, {})
		for pos in b.keys():
			if str(b[pos]) == sid:
				b[pos] = ""
	(auf["bank"] as Array).erase(sid)
	if str(auf.get("kapitaen", "")) == sid:
		auf["kapitaen"] = ""
	if str(auf.get("siebenmeter", "")) == sid:
		auf["siebenmeter"] = ""

static func leihe_vollziehen(d: Dictionary, sid: String, nach: String, saisons: int) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var von: String = str(sp["verein"])
	sp["leihe"] = {"stammverein": von, "bis_saison": Welt.saison_index() + maxi(saisons, 1)}
	if von != "" and d["vereine"].has(von):
		(d["vereine"][von]["kader"] as Array).erase(sid)
		_aufstellung_saeubern(d, von, sid)
	(d["vereine"][nach]["kader"] as Array).append(sid)
	sp["verein"] = nach
	(d["transfermarkt"]["verlauf"] as Array).push_front({
		"tag": int(d["tag"]), "spieler": sid, "von": von, "nach": nach, "ablöse": 0.0, "art": "leihe",
	})
	Weltgenerator._setze_standardaufstellung(d, nach)

## Vertragsverlaengerung eines eigenen Spielers.
static func vertrag_verlaengern(d: Dictionary, sid: String, gehalt: float, laufzeit: int, rolle: String) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var cid: String = str(sp["verein"])
	var wunsch: float = Spielerfabrik.gehaltsvorstellung(sp, float(d["vereine"][cid]["ruf"]))
	var rollen_bonus: float = {"leistungstraeger": 0.9, "stammspieler": 0.96, "rotation": 1.0, "ergaenzung": 1.08, "talent": 1.0}.get(rolle, 1.0)
	var schwelle: float = wunsch * rollen_bonus * clampf(1.0 + float(sp["unzufriedenheit"]) / 260.0, 1.0, 1.4)
	if gehalt >= schwelle:
		sp["vertrag"]["gehalt"] = gehalt
		sp["vertrag"]["bis_saison"] = Welt.saison_index() + maxi(laufzeit, 1)
		sp["vertrag"]["rolle"] = rolle
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) - 25.0, 0.0, 100.0)
		sp["moral"] = clampf(float(sp["moral"]) + 8.0, 5.0, 100.0)
		return {"ok": true, "grund": "%s hat unterschrieben." % Spielerfabrik.voller_name(sp)}
	return {"ok": false, "grund": "%s erwartet mindestens %s pro Woche." % [Spielerfabrik.voller_name(sp), Stil.geld(schwelle)]}

static func auf_transferliste(d: Dictionary, sid: String, wert: bool) -> void:
	d["spieler"][sid]["auf_transferliste"] = wert

## Einen Spieler entlassen (Vertragsaufloesung gegen Abfindung).
static func vertrag_aufloesen(d: Dictionary, sid: String) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var cid: String = str(sp["verein"])
	var rest: int = maxi(int(sp["vertrag"].get("bis_saison", 0)) - Welt.saison_index(), 0)
	var abfindung: float = float(sp["vertrag"].get("gehalt", 0.0)) * 52.0 * float(rest) * 0.45
	if float(d["vereine"][cid]["kasse"]) < abfindung:
		return {"ok": false, "grund": "Die Abfindung von %s ist nicht finanzierbar." % Stil.geld(abfindung)}
	Finanzen.buchen(d, cid, -abfindung, "Abfindung %s" % Spielerfabrik.voller_name(sp), "transfer")
	(d["vereine"][cid]["kader"] as Array).erase(sid)
	_aufstellung_saeubern(d, cid, sid)
	sp["verein"] = ""
	sp["vertrag"] = {}
	return {"ok": true, "grund": "%s wurde freigestellt (Abfindung: %s)." % [Spielerfabrik.voller_name(sp), Stil.geld(abfindung)]}

# ------------------------------------------------------------- KI-Markt ---

static func _ki_transferrunde(d: Dictionary) -> void:
	if not fenster_offen(d):
		return
	var vereine: Array = d["vereine"].keys()
	vereine.shuffle()
	var geschaefte := 0
	for cid in vereine:
		if cid == Welt.mein_verein_id:
			_angebot_fuer_eigene_spieler(d, cid)
			continue
		if geschaefte > 14:
			break
		if Namen.zufall() > 0.35:
			continue
		if _ki_verstaerkung(d, cid):
			geschaefte += 1

static func _ki_verstaerkung(d: Dictionary, cid: String) -> bool:
	var v: Dictionary = d["vereine"][cid]
	var budget: float = float(v["transferbudget"])
	if budget < 25000.0:
		return false
	var schwaeche := _schwaechste_position(d, cid)
	if schwaeche == "":
		return false
	var kandidaten := suchen(d, {"position": schwaeche, "limit": 60}, cid)
	var kaderstaerke := _kaderstaerke(d, cid)
	for sid in kandidaten:
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["verein"]) == cid:
			continue
		if Spielerfabrik.gesamt(sp) < kaderstaerke + 3.0:
			continue
		var preis := ablösevorstellung(d, sid)
		if preis > budget:
			continue
		var gehalt := Spielerfabrik.gehaltsvorstellung(sp, float(v["ruf"]))
		if gehalt * 52.0 > float(v["gehaltsbudget"]) * 52.0 * 0.25:
			continue
		if str(sp["verein"]) == Welt.mein_verein_id:
			_angebot_an_spieler(d, cid, sid, preis, gehalt)
			return true
		if _attraktivitaet(d, sp, cid, "stammspieler") < 0.42:
			continue
		transfer_durchfuehren(d, sid, cid, preis, gehalt, Namen.wuerfel(2, 4), "stammspieler")
		return true
	return false

static func _schwaechste_position(d: Dictionary, cid: String) -> String:
	var beste := {}
	for pos in Spielerfabrik.POSITIONEN:
		beste[pos] = 0.0
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		for pos in Spielerfabrik.POSITIONEN:
			var w: float = Spielerfabrik.angriff_auf(sp, pos) if pos != "TW" else (Spielerfabrik.gesamt(sp) if bool(sp["ist_torwart"]) else 0.0)
			if w > float(beste[pos]):
				beste[pos] = w
	var schwaechste := ""
	var minwert := 999.0
	for pos in beste.keys():
		if float(beste[pos]) < minwert:
			minwert = float(beste[pos])
			schwaechste = pos
	return schwaechste

## Ein KI-Verein bietet fuer einen Spieler des menschlichen Trainers.
static func _angebot_an_spieler(d: Dictionary, kaeufer: String, sid: String, ablöse: float, gehalt: float) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var angebot := {
		"id": _neue_angebots_id(d),
		"art": "kauf",
		"spieler": sid,
		"von": str(sp["verein"]),
		"nach": kaeufer,
		"ablöse": ablöse * Namen.bereich(0.85, 1.15),
		"gehalt": gehalt,
		"laufzeit": Namen.wuerfel(2, 4),
		"rolle": "stammspieler",
		"status": "eingegangen",
		"richtung": "eingehend",
		"frist_tag": int(d["tag"]) + Namen.wuerfel(3, 6),
		"antwort": "",
	}
	(d["transfermarkt"]["angebote"] as Array).append(angebot)
	Welt.nachricht({
		"typ": "transfer", "wichtig": true,
		"betreff": "Angebot für %s" % Spielerfabrik.voller_name(sp),
		"text": "%s bietet %s für %s. Die Frist läuft in %d Tagen ab." % [
			d["vereine"][kaeufer]["name"], Stil.geld(float(angebot["ablöse"])),
			Spielerfabrik.voller_name(sp), int(angebot["frist_tag"]) - int(d["tag"])],
		"daten": {"angebot": str(angebot["id"]), "spieler": sid},
	})

static func _angebot_fuer_eigene_spieler(d: Dictionary, cid: String) -> void:
	if Namen.zufall() > 0.3:
		return
	var kader: Array = d["vereine"][cid]["kader"]
	if kader.is_empty():
		return
	var sid: String = str(kader[Namen.wuerfel(0, kader.size() - 1)])
	var sp: Dictionary = d["spieler"][sid]
	if Spielerfabrik.gesamt(sp) < 55.0 and not bool(sp.get("auf_transferliste", false)):
		return
	var interessenten: Array = []
	for anderer in d["vereine"].keys():
		if anderer == cid:
			continue
		var av: Dictionary = d["vereine"][anderer]
		if float(av["ruf"]) < Spielerfabrik.gesamt(sp) - 18.0:
			continue
		if float(av["transferbudget"]) < float(sp["wert"]) * 0.8:
			continue
		interessenten.append(anderer)
	if interessenten.is_empty():
		return
	var kaeufer: String = str(interessenten[Namen.wuerfel(0, interessenten.size() - 1)])
	_angebot_an_spieler(d, kaeufer, sid, ablösevorstellung(d, sid), Spielerfabrik.gehaltsvorstellung(sp, float(d["vereine"][kaeufer]["ruf"])))

## Antwort des Spielers auf ein eingehendes Angebot.
static func eingehendes_angebot_entscheiden(d: Dictionary, angebots_id: String, annehmen: bool) -> Dictionary:
	for a in d["transfermarkt"]["angebote"]:
		if str(a["id"]) != angebots_id:
			continue
		if annehmen:
			var sid: String = str(a["spieler"])
			var sp: Dictionary = d["spieler"][sid]
			if _attraktivitaet(d, sp, str(a["nach"]), str(a["rolle"])) < 0.3 and not bool(sp.get("transferwunsch", false)):
				a["status"] = "abgelehnt"
				return {"ok": false, "grund": "%s lehnt den Wechsel ab." % Spielerfabrik.voller_name(sp)}
			transfer_durchfuehren(d, sid, str(a["nach"]), float(a["ablöse"]), float(a["gehalt"]), int(a["laufzeit"]), str(a["rolle"]))
			a["status"] = "abgeschlossen"
			return {"ok": true, "grund": "Der Transfer ist vollzogen."}
		a["status"] = "abgelehnt"
		return {"ok": true, "grund": "Sie haben das Angebot abgelehnt."}
	return {"ok": false, "grund": "Angebot nicht gefunden."}

# ------------------------------------------------------------- Geruechte ---

static func geruechtekueche(d: Dictionary) -> void:
	if Welt.mein_verein_id == "":
		return
	if Namen.zufall() > 0.6:
		return
	var alle: Array = d["spieler"].keys()
	if alle.is_empty():
		return
	for i in range(Namen.wuerfel(1, 3)):
		var sid: String = str(alle[Namen.wuerfel(0, alle.size() - 1)])
		var sp: Dictionary = d["spieler"][sid]
		if Spielerfabrik.gesamt(sp) < 58.0:
			continue
		var ziele: Array = d["vereine"].keys()
		var ziel: String = str(ziele[Namen.wuerfel(0, ziele.size() - 1)])
		if ziel == str(sp["verein"]):
			continue
		var texte := [
			"%s soll bei %s auf der Liste stehen." % [Spielerfabrik.voller_name(sp), d["vereine"][ziel]["name"]],
			"Berater von %s führen angeblich Gespräche mit %s." % [Spielerfabrik.voller_name(sp), d["vereine"][ziel]["name"]],
			"%s zeigt Interesse an %s — bestätigt ist nichts." % [d["vereine"][ziel]["name"], Spielerfabrik.voller_name(sp)],
		]
		var text: String = str(texte[Namen.wuerfel(0, texte.size() - 1)])
		(d["transfermarkt"]["gerüchte"] as Array).push_front({"tag": int(d["tag"]), "text": text, "spieler": sid, "verein": ziel})
		if (d["transfermarkt"]["gerüchte"] as Array).size() > 60:
			(d["transfermarkt"]["gerüchte"] as Array).resize(60)
		if Namen.zufall() < 0.35:
			Medien.geruecht(d, text)
