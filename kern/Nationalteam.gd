class_name Nationalteam
extends RefCounted
## Nationalmannschaften und das Winterturnier.
##
## Jede Saison steigt in der Winterpause ein großes Turnier — im Wechsel
## Europameisterschaft und Weltmeisterschaft. Die Nationaltrainer nominieren aus
## allen Spielern der Welt, unabhängig davon, bei welchem Verein sie stehen.
## Für den Vereinstrainer heißt das: Leistungsträger sind wochenlang weg, kommen
## müde zurück — und wer dort auffällt, wird teurer und begehrter.
##
## Technisch sind Nationalmannschaften Vereine mit dem Merkmal "ist_nationalteam".
## Dadurch funktionieren Aufstellung, Taktik und Spielsimulation unverändert.

const EUROPA := ["de", "dk", "fr", "es", "pl", "se", "no", "is", "hr", "hu", "rs", "pt",
	"si", "at", "nl", "mk", "cz", "ch"]
const UEBERSEE := ["eg", "br"]

## Sollbesetzung eines 16er-Turnierkaders.
const KADER_SOLL := {"TW": 2, "LA": 2, "RL": 3, "RM": 2, "RR": 3, "RA": 2, "KM": 2}

const TEILNEHMER := 16
const NOMINIERUNG_TAG := 168
const GRUPPEN_TAGE := [176, 178, 181]
const KO_TAGE := [186, 189, 192]

# ------------------------------------------------------------- Aufbau ---

## Legt für jede Nation eine Auswahlmannschaft an (leerer Kader bis zur Nominierung).
static func erzeuge_teams(d: Dictionary) -> void:
	d["nationalteams"] = []
	for nid in _alle_nationen():
		var cid := "nt_%s" % nid
		var name: String = str(Namen.KULTUR_NAME.get(nid, nid))
		var vn := {"name": name, "kurz": str(Namen.KULTUR_KUERZEL.get(nid, nid.to_upper())),
			"ort": name, "beiname": ""}
		var team := Weltgenerator._baue_verein(d, cid, vn, nid if d["nationen"].has(nid) else "de",
			_erste_liga(d), 70.0, 1.0)
		team["nation"] = nid
		team["ist_nationalteam"] = true
		team["liga"] = ""
		team["kader"] = []
		team["halle"]["name"] = "%s-Arena" % name
		team["halle"]["kapazitaet"] = 12000
		team["fans"]["treue"] = 85.0
		team["hallenpuls_basis"] = 55.0
		team["titel_turnier"] = []
		d["vereine"][cid] = team
		(d["nationalteams"] as Array).append(cid)
	d["turnier"] = leeres_turnier()

static func _alle_nationen() -> Array:
	var liste: Array = EUROPA.duplicate()
	liste.append_array(UEBERSEE)
	return liste

static func _erste_liga(d: Dictionary) -> String:
	for lid in d["ligen"].keys():
		return lid
	return ""

## Die vergebenen Turniere und ihre Gastgeber.
const GASTGEBER := {
	2027: "Deutschland",
	2028: "Spanien, Portugal, Schweiz",
}

static func leeres_turnier() -> Dictionary:
	return {
		"aktiv": false, "art": "", "name": "", "saison": -1, "phase": "keins",
		"teilnehmer": [], "gruppen": [], "tabelle": {}, "paarungen": [],
		"sieger": "", "zweiter": "", "dritter": "", "torschuetzen": {}, "basis": 0,
		"historie": [],
	}

static func team_id(nid: String) -> String:
	return "nt_%s" % nid

# ------------------------------------------------------------ Planung ---

## Setzt das Turnier der laufenden Saison an. Wird vom Spielplan aufgerufen.
static func turnier_planen(d: Dictionary, basis: int) -> void:
	if not d.has("nationalteams") or (d["nationalteams"] as Array).is_empty():
		return
	var saison: int = Welt.saison_index()
	var jahr: int = int(d["startjahr"]) + saison + 1
	# Das Turnier liegt im Januar. Europameisterschaften gibt es in geraden
	# Jahren (2026, 2028, …), Weltmeisterschaften in ungeraden (2027, 2029, …).
	var europameisterschaft: bool = jahr % 2 == 0
	var historie: Array = d.get("turnier", {}).get("historie", [])
	var t := leeres_turnier()
	t["historie"] = historie
	t["aktiv"] = true
	t["art"] = "em" if europameisterschaft else "wm"
	t["name"] = "%s %d" % ["Europameisterschaft" if europameisterschaft else "Weltmeisterschaft", jahr]
	if GASTGEBER.has(jahr):
		t["gastgeber"] = GASTGEBER[jahr]
	t["saison"] = saison
	t["phase"] = "vorbereitung"
	t["basis"] = basis
	t["teilnehmer"] = _teilnehmer_ermitteln(d, europameisterschaft)
	d["turnier"] = t

## Die stärksten Nationen qualifizieren sich; gemessen an den besten 16 Spielern.
static func _teilnehmer_ermitteln(d: Dictionary, nur_europa: bool) -> Array:
	var pool: Array = EUROPA.duplicate() if nur_europa else _alle_nationen()
	var bewertet: Array = []
	for nid in pool:
		bewertet.append({"nation": nid, "staerke": nationalstaerke(d, nid)})
	bewertet.sort_custom(func(a, b): return float(a["staerke"]) > float(b["staerke"]))
	var erg: Array = []
	for e in bewertet:
		if float(e["staerke"]) < 20.0:
			continue
		erg.append(str(e["nation"]))
		if erg.size() >= TEILNEHMER:
			break
	return erg

## Durchschnittsstärke der besten 16 Spieler einer Nation.
static func nationalstaerke(d: Dictionary, nid: String) -> float:
	var werte: Array = []
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["nation"]) != nid or str(sp["verein"]) == "":
			continue
		werte.append(Spielerfabrik.gesamt(sp))
	if werte.size() < 14:
		return 0.0
	werte.sort()
	werte.reverse()
	var summe := 0.0
	for i in range(16):
		summe += float(werte[i]) if i < werte.size() else 0.0
	return summe / 16.0

# -------------------------------------------------------- Nominierung ---

## Beruft die Kader ein und setzt die Gruppenspiele an.
static func nominieren(d: Dictionary) -> void:
	var t: Dictionary = d["turnier"]
	if not bool(t.get("aktiv", false)) or str(t["phase"]) != "vorbereitung":
		return
	t["phase"] = "gruppe"
	var teilnehmer: Array = t["teilnehmer"]
	var eigene: Array = []
	for nid in teilnehmer:
		var cid := team_id(nid)
		if not d["vereine"].has(cid):
			continue
		var selbst: bool = str(nid) == Nationaltrainer.nation(d)
		# Wer selbst Nationaltrainer ist, stellt seinen Kader von Hand zusammen.
		# Der Verbandsstab legt dazu einen Vorschlag vor, den er ändern kann.
		var kader: Array = kader_vorschlag(d, str(nid))
		d["vereine"][cid]["kader"] = kader
		d["vereine"][cid]["ruf"] = nationalstaerke(d, str(nid))
		Weltgenerator.setze_standardaufstellung(d, cid)
		if not selbst:
			KI.taktik_anpassen(d, cid)
		else:
			Welt.nachricht({
				"typ": "karriere", "wichtig": true,
				"betreff": "Nominierung für %s" % str(t["name"]),
				"text": "Ihr Verbandsstab hat einen Kader vorgeschlagen. Bis zum ersten Gruppenspiel können Sie ihn im Bildschirm Nationalteams ändern.",
			})
		for sid in kader:
			var sp: Dictionary = d["spieler"][sid]
			sp["bei_nationalmannschaft"] = true
			sp["nationalspieler"] = int(sp.get("nationalspieler", 0)) + 1
			Laufbahn.nationalelf(d, sid, "%s %d" % [str(t["name"]), Welt.startjahr() + Welt.saison_index()])
			if str(sp["verein"]) == Welt.mein_verein_id:
				eigene.append(sid)
	# Gruppen auslosen: Schlangensetzung nach Stärke
	var sortiert: Array = teilnehmer.duplicate()
	sortiert.sort_custom(func(a, b): return nationalstaerke(d, a) > nationalstaerke(d, b))
	var gruppen: Array = [[], [], [], []]
	for i in range(sortiert.size()):
		var topf: int = int(i / 4.0)
		var g: int = (i % 4) if topf % 2 == 0 else (3 - (i % 4))
		(gruppen[g] as Array).append(sortiert[i])
	t["gruppen"] = gruppen
	t["tabelle"] = {}
	for gruppe in gruppen:
		for nid2 in gruppe:
			t["tabelle"][nid2] = Spielplan.leere_tabellenzeile()
	_gruppenspiele_ansetzen(d, t)
	if not eigene.is_empty():
		var namen: Array = []
		for sid2 in eigene:
			namen.append("%s (%s)" % [Spielerfabrik.voller_name(d["spieler"][sid2]),
				Namen.KULTUR_NAME.get(str(d["spieler"][sid2]["nation"]), "")])
		Welt.nachricht({
			"typ": "national", "wichtig": true,
			"betreff": "%d Spieler zur %s berufen" % [eigene.size(), t["name"]],
			"text": "Folgende Spieler stehen dem Verein während des Turniers nicht zur Verfügung:\n• %s"
				% "\n• ".join(PackedStringArray(namen)),
		})
	Medien.artikel(d, "%s: die Kader stehen" % t["name"],
		"%d Nationen haben ihre Aufgebote gemeldet. In den kommenden Wochen ruht der Ligabetrieb." % teilnehmer.size(),
		"neutral", "national")

## Stellt den bestmöglichen Turnierkader einer Nation zusammen.
static func kader_vorschlag(d: Dictionary, nid: String) -> Array:
	var nach_position := {}
	for pos in Spielerfabrik.POSITIONEN:
		nach_position[pos] = []
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["nation"]) != nid or str(sp["verein"]) == "":
			continue
		if not (sp["verletzung"] as Dictionary).is_empty():
			continue
		if int(sp["alter"]) > 37:
			continue
		(nach_position[str(sp["position"])] as Array).append(sid)
	var kader: Array = []
	for pos in KADER_SOLL.keys():
		var liste: Array = nach_position[pos]
		liste.sort_custom(func(a, b):
			return _auswahlwert(d, a) > _auswahlwert(d, b))
		for i in range(mini(int(KADER_SOLL[pos]), liste.size())):
			kader.append(liste[i])
	return kader

## Nationaltrainer schauen auf Klasse und aktuelle Form.
static func _auswahlwert(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = d["spieler"][sid]
	return Spielerfabrik.gesamt(sp) * 0.8 + float(sp["form"]) * 0.15 + float(sp["moral"]) * 0.05

static func _gruppenspiele_ansetzen(d: Dictionary, t: Dictionary) -> void:
	var basis: int = int(t["basis"])
	var gnamen := ["A", "B", "C", "D"]
	for gi in range((t["gruppen"] as Array).size()):
		var gruppe: Array = t["gruppen"][gi]
		var runden := Spielplan.doppelrunde(gruppe)
		# Nur die Hinrunde spielen: drei Spieltage bei vier Mannschaften
		for r in range(mini(GRUPPEN_TAGE.size(), runden.size())):
			for paar in runden[r]:
				Spielplan.neues_spiel(d, "turnier", "turnier", r + 1,
					basis + GRUPPEN_TAGE[r], team_id(str(paar[0])), team_id(str(paar[1])),
					{"gruppe": gnamen[gi]})

# ------------------------------------------------------------- Ablauf ---

static func tageswechsel(d: Dictionary) -> void:
	if not d.has("turnier"):
		return
	var t: Dictionary = d["turnier"]
	if not bool(t.get("aktiv", false)):
		return
	var tis: int = Kalender.tag_in_saison(int(d["tag"]))
	if str(t["phase"]) == "vorbereitung" and tis >= NOMINIERUNG_TAG:
		nominieren(d)

## Prüft nach jedem Spieltag, ob eine Phase abgeschlossen ist.
static func fortschreiben(d: Dictionary) -> void:
	var t: Dictionary = d.get("turnier", {})
	if t.is_empty() or not bool(t.get("aktiv", false)):
		return
	var phase: String = str(t["phase"])
	if phase == "gruppe":
		if _alle_gespielt(d, "turnier"):
			_ko_starten(d, t)
	elif phase == "ko":
		var offen := false
		for p in t["paarungen"]:
			if not bool(d["spiele"][p["spiel"]]["gespielt"]):
				offen = true
		if not offen and not (t["paarungen"] as Array).is_empty():
			_ko_weiter(d, t)

static func _alle_gespielt(d: Dictionary, wettbewerb: String) -> bool:
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["wettbewerb"]) == wettbewerb and not bool(m["gespielt"]):
			return false
	return true

## Innerhalb der Turnierlogik wird durchgängig mit Nationskürzeln gearbeitet.
## Nur beim Ansetzen einer Partie werden daraus Mannschaftskennungen.
static func _ko_starten(d: Dictionary, t: Dictionary) -> void:
	var weiter: Array = []
	var gnamen := ["A", "B", "C", "D"]
	for gi in range((t["gruppen"] as Array).size()):
		var sortiert := Spielplan.gruppen_tabelle_sortiert(t, t["gruppen"][gi])
		t["gruppe_%s" % gnamen[gi]] = sortiert
		for i in range(mini(2, sortiert.size())):
			weiter.append(str(sortiert[i]))
	# Kreuzweise: Gruppensieger gegen Zweiten einer anderen Gruppe
	var sieger: Array = []
	var zweite: Array = []
	for i in range(weiter.size()):
		if i % 2 == 0:
			sieger.append(str(weiter[i]))
		else:
			zweite.append(str(weiter[i]))
	var paare: Array = []
	var kreuz := [1, 0, 3, 2]
	for i in range(sieger.size()):
		var gegner: String = str(zweite[kreuz[i]]) if i < kreuz.size() and kreuz[i] < zweite.size() else str(zweite[i])
		paare.append([str(sieger[i]), gegner])
	t["phase"] = "ko"
	t["runde"] = 0
	_ko_ansetzen(d, t, paare)
	if _eigene_nation_dabei(d, weiter):
		Welt.nachricht({"typ": "national", "betreff": "%s: Viertelfinale steht" % t["name"],
			"text": "Die Gruppenphase ist beendet, die Viertelfinalpaarungen sind ausgelost."})

## paare enthält Nationskürzel.
static func _ko_ansetzen(d: Dictionary, t: Dictionary, paare: Array) -> void:
	var runde: int = int(t.get("runde", 0))
	var tag: int = maxi(int(t["basis"]) + KO_TAGE[mini(runde, KO_TAGE.size() - 1)], int(d["tag"]) + 2)
	var paarungen: Array = []
	for p in paare:
		var a_nid: String = str(p[0])
		var b_nid: String = str(p[1])
		if not d["vereine"].has(team_id(a_nid)) or not d["vereine"].has(team_id(b_nid)):
			continue
		var spiel := Spielplan.neues_spiel(d, "turnier", "turnier", runde + 10, tag,
			team_id(a_nid), team_id(b_nid), {"ko": true})
		paarungen.append({"spiel": spiel["id"], "a": a_nid, "b": b_nid})
	t["paarungen"] = paarungen
	t["runde"] = runde + 1

static func _ko_weiter(d: Dictionary, t: Dictionary) -> void:
	var sieger: Array = []
	var verlierer: Array = []
	for p in t["paarungen"]:
		var m: Dictionary = d["spiele"][p["spiel"]]
		if int(m["tore_heim"]) > int(m["tore_gast"]):
			sieger.append(str(p["a"]))
			verlierer.append(str(p["b"]))
		else:
			sieger.append(str(p["b"]))
			verlierer.append(str(p["a"]))
	if sieger.size() == 1:
		t["sieger"] = str(sieger[0])
		t["zweiter"] = str(verlierer[0])
		_abschluss(d, t)
		return
	var paare: Array = []
	for i in range(0, sieger.size() - 1, 2):
		paare.append([str(sieger[i]), str(sieger[i + 1])])
	if sieger.size() == 2:
		t["verlierer_halbfinale"] = verlierer.duplicate()
	_ko_ansetzen(d, t, paare)

# ---------------------------------------------------------- Abschluss ---

static func _abschluss(d: Dictionary, t: Dictionary) -> void:
	t["phase"] = "beendet"
	t["aktiv"] = false
	Nationaltrainer.turnier_abrechnen(d)
	var sieger_nid: String = str(t["sieger"])
	var zweiter_nid: String = str(t["zweiter"])
	(t["historie"] as Array).push_front({
		"saison": int(t["saison"]), "name": str(t["name"]),
		"sieger": sieger_nid, "zweiter": zweiter_nid,
	})
	# Nachwirkungen für alle Turnierteilnehmer
	for nid in t["teilnehmer"]:
		var cid := team_id(nid)
		if not d["vereine"].has(cid):
			continue
		var erfolg: float = 0.0
		if str(nid) == sieger_nid:
			erfolg = 1.0
		elif str(nid) == zweiter_nid:
			erfolg = 0.7
		for sid in d["vereine"][cid]["kader"]:
			if not d["spieler"].has(sid):
				continue
			var sp: Dictionary = d["spieler"][sid]
			sp["bei_nationalmannschaft"] = false
			var einsaetze: int = int(sp.get("turnier_spiele", 0))
			sp["last"] = clampf(float(sp["last"]) + 14.0 + float(einsaetze) * 2.0, 0.0, 100.0)
			sp["fitness"] = clampf(float(sp["fitness"]) - 6.0, 25.0, 100.0)
			sp["moral"] = clampf(float(sp["moral"]) + 4.0 + erfolg * 12.0, 5.0, 100.0)
			if erfolg >= 0.7:
				sp["wert"] = float(sp["wert"]) * (1.06 + erfolg * 0.06)
			sp["turnier_spiele"] = 0
		d["vereine"][cid]["kader"] = []
	(d["vereine"][team_id(sieger_nid)]["titel_turnier"] as Array).append(str(t["name"]))
	Medien.artikel(d, "%s gewinnt die %s" % [Namen.KULTUR_NAME.get(sieger_nid, sieger_nid), t["name"]],
		"Im Finale setzte sich %s gegen %s durch. Der Ligabetrieb wird in den kommenden Tagen fortgesetzt." % [
			Namen.KULTUR_NAME.get(sieger_nid, sieger_nid), Namen.KULTUR_NAME.get(zweiter_nid, zweiter_nid)],
		"neutral", "national")
	Welt.nachricht({
		"typ": "national", "wichtig": true,
		"betreff": "%s beendet" % t["name"],
		"text": "%s ist %s. Ihre Nationalspieler kehren in den kommenden Tagen zurück — mit vollem Lastkonto." % [
			Namen.KULTUR_NAME.get(sieger_nid, sieger_nid),
			"Europameister" if str(t["art"]) == "em" else "Weltmeister"],
	})

## Verbucht eine Turnierpartie (eigene Statistik, keine Vereinswertung).
static func spiel_verbuchen(d: Dictionary, m: Dictionary) -> void:
	var t: Dictionary = d.get("turnier", {})
	if t.is_empty():
		return
	if str(t["phase"]) == "gruppe":
		var heim_nid: String = str(d["vereine"][m["heim"]]["nation"])
		var gast_nid: String = str(d["vereine"][m["gast"]]["nation"])
		Statistik._tabelle_eintragen(t["tabelle"], heim_nid, int(m["tore_heim"]), int(m["tore_gast"]))
		Statistik._tabelle_eintragen(t["tabelle"], gast_nid, int(m["tore_gast"]), int(m["tore_heim"]))
	var bericht: Dictionary = m.get("bericht", {})
	for seite in ["heim", "gast"]:
		for sid in bericht.get(seite, {}).get("spieler", {}).keys():
			if not d["spieler"].has(sid):
				continue
			var sp: Dictionary = d["spieler"][sid]
			var z: Dictionary = bericht[seite]["spieler"][sid]
			sp["turnier_spiele"] = int(sp.get("turnier_spiele", 0)) + 1
			var national: Dictionary = sp["stats"].get("national", {"spiele": 0, "tore": 0, "paraden": 0, "turniere": 0})
			national["spiele"] = int(national["spiele"]) + 1
			national["tore"] = int(national["tore"]) + int(z["tore"])
			national["paraden"] = int(national["paraden"]) + int(z["paraden"])
			sp["stats"]["national"] = national
			if int(z["tore"]) > 0:
				var liste: Dictionary = t["torschuetzen"]
				liste[sid] = int(liste.get(sid, 0)) + int(z["tore"])

## Ist eine Nation dabei, für die ein eigener Spieler spielt? (Nationskürzel)
static func _eigene_nation_dabei(d: Dictionary, nationen: Array) -> bool:
	if Welt.mein_verein_id == "":
		return false
	for sid in d["vereine"][Welt.mein_verein_id]["kader"]:
		if nationen.has(str(d["spieler"][sid]["nation"])):
			return true
	return false

## Alle einberufenen Spieler eines Vereins.
static func abwesende(d: Dictionary, cid: String) -> Array:
	var liste: Array = []
	if cid == "" or not d["vereine"].has(cid):
		return liste
	for sid in d["vereine"][cid]["kader"]:
		if bool(d["spieler"][sid].get("bei_nationalmannschaft", false)):
			liste.append(sid)
	return liste

static func torjaeger(d: Dictionary, anzahl: int = 10) -> Array:
	var t: Dictionary = d.get("turnier", {})
	if t.is_empty():
		return []
	var liste: Dictionary = t.get("torschuetzen", {})
	var ids: Array = liste.keys()
	ids.sort_custom(func(a, b): return int(liste[a]) > int(liste[b]))
	var erg: Array = []
	for i in range(mini(anzahl, ids.size())):
		erg.append({"sid": ids[i], "tore": int(liste[ids[i]])})
	return erg
