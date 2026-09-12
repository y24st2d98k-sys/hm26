class_name Nationaltrainer
extends RefCounted
## Die Nationaltrainer-Karriere: der zweite Karrierestrang.
##
## Nationalmannschaften, Europa- und Weltmeisterschaft laufen in Hallenherz
## bisher neben dem Spieler her — seine Leistungsträger sind im Winter weg, mehr
## bekommt er davon nicht mit. Dabei ist der Verbandsjob in jedem großen
## Sportmanager ein eigener Strang: Man wird berufen, nominiert selbst, wird an
## einem Turnierziel gemessen und kann Verein und Verband gleichzeitig führen.
##
## Gespeichert wird in `d["trainer"]["nationalteam"]` (Nationskürzel oder "")
## und `d["trainer"]["verbandsangebote"]`.

## Ab diesem Ruf wird man überhaupt für einen Verband interessant.
const RUF_SCHWELLE := 38.0
## Wie viele Spieler in einen Turnierkader gehören.
const KADER_MAX := 18
const KADER_MIN := 14

const ZIELE := {
	"titel": {"name": "Der Titel", "runde": 1},
	"finale": {"name": "Das Finale", "runde": 2},
	"halbfinale": {"name": "Das Halbfinale", "runde": 4},
	"viertelfinale": {"name": "Das Viertelfinale", "runde": 8},
	"hauptrunde": {"name": "Eine ordentliche Vorrunde", "runde": 16},
}

static func nation(d: Dictionary) -> String:
	return str(d.get("trainer", {}).get("nationalteam", ""))

static func ist_nationaltrainer(d: Dictionary) -> bool:
	return nation(d) != ""

## Die Auswahlmannschaft, die der Spieler betreut (als Vereins-Dictionary).
static func team(d: Dictionary) -> Dictionary:
	var nid := nation(d)
	if nid == "":
		return {}
	return d["vereine"].get(Nationalteam.team_id(nid), {})

static func angebote(d: Dictionary) -> Array:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return []
	if not t.has("verbandsangebote"):
		t["verbandsangebote"] = []
	return t["verbandsangebote"]

# ------------------------------------------------------------ Berufung ---

## Verbände suchen einen Trainer. Geprüft wird einmal je Saison, nach dem
## Turnier: wer keinen Erfolg hatte, trennt sich; wer keinen Trainer hat, sucht.
static func angebote_pruefen(d: Dictionary) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty() or ist_nationaltrainer(d):
		return
	var ruf: float = float(t["ruf"])
	if ruf < RUF_SCHWELLE:
		return
	var liste: Array = []
	var eigene: String = str(t.get("nation", "de"))
	for nid in Nationalteam.EUROPA + Nationalteam.UEBERSEE:
		var cid := Nationalteam.team_id(str(nid))
		if not d["vereine"].has(cid):
			continue
		var staerke: float = Nationalteam.nationalstaerke(d, str(nid))
		# Ein Verband greift nach jemandem, der ungefähr zu ihm passt. Beim
		# eigenen Heimatverband darf es auch etwas mehr sein.
		var grenze: float = ruf + (26.0 if str(nid) == eigene else 8.0)
		if staerke > grenze or staerke < ruf - 40.0:
			continue
		if Namen.zufall() > (0.5 if str(nid) == eigene else 0.16):
			continue
		liste.append({
			"nation": str(nid),
			"name": str(Namen.KULTUR_NAME.get(str(nid), str(nid).to_upper())),
			"staerke": staerke,
			"ziel": _ziel_fuer(staerke),
			"gehalt": 900.0 + staerke * 42.0,
		})
	if liste.is_empty():
		return
	liste.sort_custom(func(a, b): return float(a["staerke"]) > float(b["staerke"]))
	t["verbandsangebote"] = liste.slice(0, 3)
	Welt.nachricht({
		"typ": "karriere", "wichtig": true,
		"betreff": "Ein Verband fragt an",
		"text": "%s sucht einen Nationaltrainer und denkt an Sie. Der Karrierebildschirm zeigt alle Anfragen — ein Verbandsamt lässt sich neben dem Vereinsjob führen." % str(liste[0]["name"]),
	})

static func _ziel_fuer(staerke: float) -> String:
	if staerke >= 78.0:
		return "halbfinale"
	if staerke >= 70.0:
		return "viertelfinale"
	return "hauptrunde"

static func annehmen(d: Dictionary, nid: String) -> Dictionary:
	var t: Dictionary = d["trainer"]
	var gewaehlt := {}
	for a in angebote(d):
		if str(a["nation"]) == nid:
			gewaehlt = a
	if gewaehlt.is_empty():
		return {"ok": false, "grund": "Dieses Angebot liegt nicht mehr vor."}
	t["nationalteam"] = nid
	t["verbandsziel"] = str(gewaehlt["ziel"])
	t["verbandsangebote"] = []
	t["verband_seit"] = Welt.saison_index()
	var cid := Nationalteam.team_id(nid)
	if d["vereine"].has(cid):
		d["vereine"][cid]["ist_mensch"] = true
	Welt.nachricht({
		"typ": "karriere", "wichtig": true,
		"betreff": "Sie sind Nationaltrainer von %s" % str(gewaehlt["name"]),
		"text": "Der Verband erwartet: %s. Vor dem Turnier nominieren Sie den Kader selbst — im Bildschirm Nationalteams." % str(ZIELE[str(gewaehlt["ziel"])]["name"]),
	})
	return {"ok": true, "grund": "Sie übernehmen %s." % str(gewaehlt["name"])}

static func ablehnen(d: Dictionary, nid: String) -> void:
	var liste: Array = angebote(d)
	for i in range(liste.size() - 1, -1, -1):
		if str((liste[i] as Dictionary)["nation"]) == nid:
			liste.remove_at(i)

static func niederlegen(d: Dictionary) -> void:
	var t: Dictionary = d["trainer"]
	var cid := Nationalteam.team_id(nation(d))
	if d["vereine"].has(cid):
		d["vereine"][cid]["ist_mensch"] = false
	t["nationalteam"] = ""
	t["verbandsziel"] = ""

# ------------------------------------------------------------ Kaderwahl ---

## Alle Spieler, die für diese Nation infrage kommen, nach Auswahlwert sortiert.
static func kandidaten(d: Dictionary, nid: String) -> Array:
	var liste: Array = []
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["nation"]) != nid or str(sp["verein"]) == "":
			continue
		if not (sp["verletzung"] as Dictionary).is_empty():
			continue
		liste.append(sid)
	liste.sort_custom(func(a, b):
		return Spielerfabrik.gesamt(d["spieler"][a]) + float(d["spieler"][a]["form"]) * 0.15 \
			> Spielerfabrik.gesamt(d["spieler"][b]) + float(d["spieler"][b]["form"]) * 0.15)
	return liste

static func nominiert(d: Dictionary) -> Array:
	var t := team(d)
	return t.get("kader", []) if not t.is_empty() else []

static func hinzufuegen(d: Dictionary, sid: String) -> Dictionary:
	var t := team(d)
	if t.is_empty():
		return {"ok": false, "grund": "Sie betreuen keine Auswahl."}
	var kader: Array = t["kader"]
	if kader.size() >= KADER_MAX:
		return {"ok": false, "grund": "Mehr als %d Spieler dürfen nicht mit." % KADER_MAX}
	if kader.has(sid):
		return {"ok": false, "grund": "Er ist bereits nominiert."}
	var sp: Dictionary = d["spieler"][sid]
	if str(sp["nation"]) != nation(d):
		return {"ok": false, "grund": "Er ist nicht spielberechtigt."}
	kader.append(sid)
	return {"ok": true, "grund": "%s ist nominiert." % Spielerfabrik.voller_name(sp)}

static func streichen(d: Dictionary, sid: String) -> void:
	var t := team(d)
	if t.is_empty():
		return
	(t["kader"] as Array).erase(sid)
	Transfermarkt.aufstellung_saeubern(d, Nationalteam.team_id(nation(d)), sid)

## Der Vorschlag des Verbandsstabs — dieselbe Auswahl, die ein Computertrainer träfe.
static func vorschlag_uebernehmen(d: Dictionary) -> int:
	var nid := nation(d)
	if nid == "":
		return 0
	var cid := Nationalteam.team_id(nid)
	d["vereine"][cid]["kader"] = Nationalteam.kader_vorschlag(d, nid)
	Weltgenerator.setze_standardaufstellung(d, cid)
	return (d["vereine"][cid]["kader"] as Array).size()

## Prüft, ob der Kader turnierfähig ist.
static func kaderpruefung(d: Dictionary) -> Dictionary:
	var kader: Array = nominiert(d)
	if kader.size() < KADER_MIN:
		return {"ok": false, "grund": "Nur %d von mindestens %d Spielern nominiert." % [kader.size(), KADER_MIN]}
	var torhueter := 0
	for sid in kader:
		if bool(d["spieler"][sid]["ist_torwart"]):
			torhueter += 1
	if torhueter < 2:
		return {"ok": false, "grund": "Mindestens zwei Torhüter gehören in den Kader."}
	return {"ok": true, "grund": "Der Kader steht."}

## Ist das eine Partie der Auswahl, die der Spieler betreut?
static func ist_nationalteam_spiel(d: Dictionary, m: Dictionary) -> bool:
	var nid := nation(d)
	if nid == "":
		return false
	var cid := Nationalteam.team_id(nid)
	return str(m["heim"]) == cid or str(m["gast"]) == cid

# ------------------------------------------------------------- Turnier ---

## Eine Turnierpartie der eigenen Auswahl in die Bilanz des Trainers.
static func spiel_verbuchen(d: Dictionary, m: Dictionary) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return
	if not t.has("national_bilanz"):
		t["national_bilanz"] = {"spiele": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0}
	var b: Dictionary = t["national_bilanz"]
	var cid := Nationalteam.team_id(nation(d))
	var eigene: int = int(m["tore_heim"]) if str(m["heim"]) == cid else int(m["tore_gast"])
	var fremde: int = int(m["tore_gast"]) if str(m["heim"]) == cid else int(m["tore_heim"])
	b["spiele"] = int(b["spiele"]) + 1
	if eigene > fremde:
		b["siege"] = int(b["siege"]) + 1
	elif eigene == fremde:
		b["unentschieden"] = int(b["unentschieden"]) + 1
	else:
		b["niederlagen"] = int(b["niederlagen"]) + 1

## Nach dem Turnier: hat der Trainer sein Ziel erreicht?
static func turnier_abrechnen(d: Dictionary) -> void:
	var nid := nation(d)
	if nid == "":
		return
	var t: Dictionary = d["trainer"]
	var turnier: Dictionary = d.get("turnier", {})
	if turnier.is_empty():
		return
	var platz := _erreichte_runde(d, turnier, nid)
	var ziel: String = str(t.get("verbandsziel", "hauptrunde"))
	var soll: int = int(ZIELE.get(ziel, ZIELE["hauptrunde"])["runde"])
	var name: String = str(Namen.KULTUR_NAME.get(nid, nid.to_upper()))
	var erfolg: bool = platz <= soll
	if str(turnier.get("sieger", "")) == nid:
		Trainerkarriere.titel_gewinnen(d, "%s mit %s" % [str(turnier["name"]), name])
		t["ruf"] = clampf(float(t["ruf"]) + 5.0, 1.0, 100.0)
	elif erfolg:
		t["ruf"] = clampf(float(t["ruf"]) + 2.0, 1.0, 100.0)
	else:
		t["ruf"] = clampf(float(t["ruf"]) - 3.0, 1.0, 100.0)
	Welt.nachricht({
		"typ": "karriere", "wichtig": true,
		"betreff": "%s: %s" % [str(turnier["name"]), _rundentext(platz)],
		"text": "%s Der Verband hatte %s erwartet." % [
			"Ziel erreicht." if erfolg else "Das Ziel wurde verfehlt.",
			str(ZIELE.get(ziel, ZIELE["hauptrunde"])["name"]).to_lower()],
	})
	if not erfolg and Namen.zufall() < 0.5:
		Welt.nachricht({
			"typ": "karriere", "wichtig": true,
			"betreff": "Der Verband trennt sich von Ihnen",
			"text": "Nach dem Abschneiden bei %s geht %s einen anderen Weg." % [str(turnier["name"]), name],
		})
		niederlegen(d)

## In welcher Runde die Nation ausgeschieden ist (1 = Sieger, 16 = Vorrunde).
static func _erreichte_runde(d: Dictionary, turnier: Dictionary, nid: String) -> int:
	if str(turnier.get("sieger", "")) == nid:
		return 1
	if str(turnier.get("zweiter", "")) == nid:
		return 2
	if str(turnier.get("dritter", "")) == nid:
		return 3
	# Sonst am letzten Spiel ablesen, an dem die Nation beteiligt war.
	var team_cid := Nationalteam.team_id(nid)
	var letzte := 16
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) != "turnier" or not bool(m.get("gespielt", false)):
			continue
		if str(m["heim"]) != team_cid and str(m["gast"]) != team_cid:
			continue
		if str(m.get("gruppe", "")) != "":
			continue
		letzte = mini(letzte, 8)
	return letzte

static func _rundentext(platz: int) -> String:
	match platz:
		1: return "Turniersieg"
		2: return "Finale erreicht"
		3: return "Dritter Platz"
		4: return "Halbfinale"
		8: return "Viertelfinale"
		_: return "in der Vorrunde ausgeschieden"

static func zieltext(d: Dictionary) -> String:
	var ziel: String = str(d.get("trainer", {}).get("verbandsziel", ""))
	if ziel == "":
		return ""
	return str(ZIELE.get(ziel, ZIELE["hauptrunde"])["name"])
