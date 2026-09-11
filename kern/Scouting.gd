class_name Scouting
extends RefCounted
## Scouting mit echter Unsicherheit — und Scouts, die selbst einen Ruf haben.
##
## Spielerwerte sind nur so genau bekannt, wie sie beobachtet wurden ("Kenntnis").
## Jeder Scout hat ein "Gespür", das sich ueber die Jahre an seinen Einschaetzungen
## misst: Wer Talente empfiehlt, die sich wirklich entwickeln, wird zuverlaessiger —
## und seine Berichte werden enger und glaubwuerdiger dargestellt.

const AUFTRAGSARTEN := {
	"spieler": {"name": "Einzelbeobachtung", "dauer": 10, "beschreibung": "Ein Spieler wird über mehrere Partien beobachtet."},
	"liga": {"name": "Ligascreening", "dauer": 24, "beschreibung": "Der Scout sichtet eine komplette Liga nach Talenten."},
	"position": {"name": "Positionssuche", "dauer": 18, "beschreibung": "Gezielte Suche nach Spielern einer Position."},
	"gegner": {"name": "Gegnerbeobachtung", "dauer": 5, "beschreibung": "Analyse des nächsten Gegners für einen Taktikvorteil."},
}

static func scouts(d: Dictionary, cid: String) -> Array:
	var liste: Array = []
	for pid in d["vereine"][cid]["personal"]:
		if str(d["personal"].get(pid, {}).get("rolle", "")) == "scout":
			liste.append(pid)
	return liste

## Gespuer eines Scouts: 0..100, aus Attributen und bestaetigten Empfehlungen.
static func gespuer(d: Dictionary, pid: String) -> float:
	var s: Dictionary = d["personal"][pid]
	var attr: Dictionary = s["attr"]
	var basis: float = (float(attr.get("urteilsvermoegen", 8.0)) * 3.0 + float(attr.get("netzwerk", 8.0)) * 1.4) / 4.4 * 5.0
	var berichte: int = int(s.get("berichte", 0))
	var treffer: int = int(s.get("treffer", 0))
	if berichte >= 4:
		var quote: float = float(treffer) / float(berichte)
		basis += (quote - 0.5) * 30.0
	return clampf(basis, 5.0, 100.0)

static func gespuer_text(wert: float) -> String:
	if wert >= 85.0:
		return "außergewöhnliches Gespür"
	elif wert >= 70.0:
		return "sehr verlässlich"
	elif wert >= 55.0:
		return "solide Einschätzungen"
	elif wert >= 40.0:
		return "schwankend"
	return "häufig danebengelegen"

# ------------------------------------------------------------- Auftraege ---

static func auftrag_erteilen(d: Dictionary, pid: String, art: String, ziel: String) -> Dictionary:
	var cid: String = Welt.mein_verein_id
	if cid == "":
		return {"ok": false, "grund": "Kein Verein."}
	for a in d["scouting"]["auftraege"]:
		if str(a["scout"]) == pid and not bool(a.get("fertig", false)):
			return {"ok": false, "grund": "Dieser Scout ist bereits unterwegs."}
	var s: Dictionary = d["personal"][pid]
	var reise: float = float(s["attr"].get("ausdauer_reise", 10.0)) / 20.0
	var dauer: int = int(float(AUFTRAGSARTEN[art]["dauer"]) * (1.35 - 0.5 * reise))
	d["zaehler"]["auftrag"] = int(d["zaehler"]["auftrag"]) + 1
	(d["scouting"]["auftraege"] as Array).append({
		"id": "sc_%05d" % int(d["zaehler"]["auftrag"]),
		"scout": pid,
		"verein": cid,
		"art": art,
		"ziel": ziel,
		"start": int(d["tag"]),
		"ende": int(d["tag"]) + dauer,
		"fertig": false,
	})
	return {"ok": true, "grund": "%s reist ab. Bericht in %d Tagen." % [_name(s), dauer]}

static func auftrag_abbrechen(d: Dictionary, auftrags_id: String) -> void:
	var neu: Array = []
	for a in d["scouting"]["auftraege"]:
		if str(a["id"]) != auftrags_id:
			neu.append(a)
	d["scouting"]["auftraege"] = neu

static func _name(s: Dictionary) -> String:
	return "%s %s" % [s.get("vorname", ""), s.get("nachname", "")]

static func tageswechsel(d: Dictionary) -> void:
	for a in d["scouting"]["auftraege"]:
		if bool(a.get("fertig", false)):
			continue
		if int(d["tag"]) < int(a["ende"]):
			continue
		a["fertig"] = true
		_bericht_erstellen(d, a)

static func _bericht_erstellen(d: Dictionary, a: Dictionary) -> void:
	var pid: String = str(a["scout"])
	var s: Dictionary = d["personal"][pid]
	var qualitaet: float = gespuer(d, pid)
	var art: String = str(a["art"])
	var gefunden: Array = []
	match art:
		"spieler":
			gefunden = [str(a["ziel"])]
		"liga":
			gefunden = _talente_in_liga(d, str(a["ziel"]), qualitaet)
		"position":
			gefunden = _talente_auf_position(d, str(a["ziel"]), qualitaet)
		"gegner":
			_gegnerbericht(d, a, qualitaet)
			return
	for sid in gefunden:
		if not d["spieler"].has(sid):
			continue
		var sp: Dictionary = d["spieler"][sid]
		var zuwachs: float = 18.0 + qualitaet * 0.55
		if art == "spieler":
			zuwachs = 32.0 + qualitaet * 0.6
		sp["kenntnis"] = clampf(float(sp["kenntnis"]) + zuwachs, 0.0, 100.0)
	s["berichte"] = int(s.get("berichte", 0)) + 1
	var eintrag := {
		"id": str(a["id"]),
		"tag": int(d["tag"]),
		"scout": pid,
		"scoutname": _name(s),
		"art": art,
		"ziel": str(a["ziel"]),
		"spieler": gefunden,
		"gespuer": qualitaet,
		"text": _berichtstext(d, gefunden, art, str(a["ziel"]), qualitaet),
	}
	(d["scouting"]["berichte"] as Array).push_front(eintrag)
	if (d["scouting"]["berichte"] as Array).size() > 80:
		(d["scouting"]["berichte"] as Array).resize(80)
	# Empfehlung merken, um das Gespuer spaeter zu bewerten
	for sid in gefunden:
		if d["spieler"].has(sid) and int(d["spieler"][sid]["alter"]) <= 22:
			(d["scouting"]["beobachtung"] as Array).append({
				"scout": pid, "spieler": sid, "saison": Welt.saison_index(),
				"prognose": float(d["spieler"][sid]["potenzial"]), "start": Spielerfabrik.gesamt(d["spieler"][sid]),
			})
	Welt.nachricht({
		"typ": "scouting",
		"betreff": "Scoutbericht: %s" % AUFTRAGSARTEN[art]["name"],
		"text": str(eintrag["text"]),
		"daten": {"bericht": str(a["id"])},
	})

static func _talente_in_liga(d: Dictionary, lid: String, qualitaet: float) -> Array:
	if not d["ligen"].has(lid):
		return []
	var kandidaten: Array = []
	for cid in d["ligen"][lid]["vereine"]:
		for sid in d["vereine"][cid]["kader"]:
			kandidaten.append(sid)
	kandidaten.sort_custom(func(a, b):
		return _rohbewertung(d, a, qualitaet) > _rohbewertung(d, b, qualitaet))
	return kandidaten.slice(0, 6)

static func _talente_auf_position(d: Dictionary, position: String, qualitaet: float) -> Array:
	var kandidaten: Array = []
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["position"]) != position:
			continue
		if str(sp["verein"]) == Welt.mein_verein_id:
			continue
		kandidaten.append(sid)
	kandidaten.sort_custom(func(a, b):
		return _rohbewertung(d, a, qualitaet) > _rohbewertung(d, b, qualitaet))
	return kandidaten.slice(0, 6)

## Was der Scout zu sehen glaubt — mit Fehler je nach Gespuer.
static func _rohbewertung(d: Dictionary, sid: String, qualitaet: float) -> float:
	var sp: Dictionary = d["spieler"][sid]
	var echt: float = Spielerfabrik.gesamt(sp) * 0.55 + float(sp["potenzial"]) * 0.45
	var fehler: float = (100.0 - qualitaet) / 100.0 * 16.0
	return echt + Namen.bereich(-fehler, fehler)

static func _berichtstext(d: Dictionary, spieler_liste: Array, art: String, ziel: String, qualitaet: float) -> String:
	if spieler_liste.is_empty():
		return "Der Bericht blieb ohne verwertbares Ergebnis."
	if art == "spieler":
		var sp: Dictionary = d["spieler"][spieler_liste[0]]
		return "%s: %s. %s" % [Spielerfabrik.voller_name(sp), einschaetzung(d, str(spieler_liste[0])), _zusatz(qualitaet)]
	var namen: Array = []
	for sid in spieler_liste.slice(0, 3):
		namen.append(Spielerfabrik.voller_name(d["spieler"][sid]))
	var wo: String = str(d["ligen"].get(ziel, {}).get("name", ziel))
	return "Aus %s werden %d Spieler empfohlen, darunter %s. %s" % [wo, spieler_liste.size(), ", ".join(namen), _zusatz(qualitaet)]

## Textliche Einschaetzung eines beobachteten Spielers.
static func einschaetzung(d: Dictionary, sid: String) -> String:
	var sp: Dictionary = d["spieler"][sid]
	var g: float = Spielerfabrik.gesamt(sp)
	var teile: Array = []
	teile.append("%d Jahre, %s" % [int(sp["alter"]), Spielerfabrik.POSITION_NAME[str(sp["position"])]])
	teile.append("Stärke %s" % gesamt_text(d, sid))
	teile.append("Perspektive: %s" % potenzial_text(d, sid))
	# Auffaelligste Staerke und Schwaeche
	var beste := ""
	var bester_wert := -1.0
	var schwaechste := ""
	var schwaechster_wert := 99.0
	var relevant: Array = Spielerfabrik.ATTR_TORWART if bool(sp["ist_torwart"]) else (Spielerfabrik.ANGRIFF_GEWICHTE[str(sp["position"])] as Dictionary).keys()
	for a in relevant:
		var w: float = float((sp["attr"] as Dictionary).get(a, 1.0))
		if w > bester_wert:
			bester_wert = w
			beste = a
		if w < schwaechster_wert:
			schwaechster_wert = w
			schwaechste = a
	if beste != "":
		teile.append("stark in: %s" % Spielerfabrik.ATTR_LABEL.get(beste, beste))
	if schwaechste != "" and schwaechste != beste:
		teile.append("Schwäche: %s" % Spielerfabrik.ATTR_LABEL.get(schwaechste, schwaechste))
	var charakter: String = str(sp["persoenlichkeit"])
	teile.append("Typ: %s" % charakter)
	if str(sp["verein"]) != "" and d["vereine"].has(str(sp["verein"])):
		var rest: int = int(sp["vertrag"].get("bis_saison", 0)) - Welt.saison_index()
		teile.append("Vertrag bei %s noch %d Jahr(e)" % [d["vereine"][str(sp["verein"])]["name"], maxi(rest, 0)])
	else:
		teile.append("derzeit vereinslos")
	return ", ".join(teile)

static func _zusatz(qualitaet: float) -> String:
	if qualitaet >= 78.0:
		return "Der Scout ist sich seiner Sache sehr sicher."
	elif qualitaet >= 55.0:
		return "Die Einschätzung ist belastbar, aber nicht endgültig."
	return "Die Angaben sind mit Vorsicht zu genießen."

# ------------------------------------------------------- Gegnerbeobachtung ---

static func _gegnerbericht(d: Dictionary, a: Dictionary, qualitaet: float) -> void:
	var cid: String = str(a["verein"])
	var gegner: String = str(a["ziel"])
	if not d["vereine"].has(gegner):
		return
	var v: Dictionary = d["vereine"][cid]
	if not v.has("gegnerberichte"):
		v["gegnerberichte"] = {}
	var wirkung: float = clampf(qualitaet / 100.0 * 0.05 + float(v["infrastruktur"]["analyse"]) * 0.004, 0.01, 0.07)
	v["gegnerberichte"][gegner] = {"bis_tag": int(d["tag"]) + 30, "wirkung": wirkung}
	var g: Dictionary = d["vereine"][gegner]
	var taktik: Dictionary = g["taktik"]
	Welt.nachricht({
		"typ": "scouting",
		"betreff": "Gegnerbericht: %s" % g["name"],
		"text": "%s spielt derzeit %s in der Abwehr und setzt im Angriff auf %s. Tempo: %d, Härte: %d. Ihre Mannschaft ist im nächsten Duell besser vorbereitet." % [
			g["name"], taktik["abwehr"], taktik["angriff"], int(taktik["tempo"]), int(taktik["haerte"])],
	})

static func gegnervorteil(d: Dictionary, cid: String, gegner: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var berichte: Dictionary = v.get("gegnerberichte", {})
	if not berichte.has(gegner):
		return 0.0
	var b: Dictionary = berichte[gegner]
	if int(d["tag"]) > int(b["bis_tag"]):
		return 0.0
	return float(b["wirkung"])

# ---------------------------------------------------------- Darstellung ---

## Unschaerfe eines Attributs: liefert {min, max, sicher}
static func schaetzung(d: Dictionary, sid: String, attribut: String) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var wert: float = float((sp["attr"] as Dictionary).get(attribut, 1.0))
	var kenntnis: float = float(sp["kenntnis"])
	if kenntnis >= 97.0:
		return {"min": wert, "max": wert, "sicher": true}
	var spanne: float = (100.0 - kenntnis) / 100.0 * 7.0
	var versatz: float = Namen.bereich(-spanne * 0.3, spanne * 0.3)
	return {
		"min": clampf(wert - spanne + versatz, 1.0, 20.0),
		"max": clampf(wert + spanne + versatz, 1.0, 20.0),
		"sicher": false,
	}

static func attributtext(d: Dictionary, sid: String, attribut: String) -> String:
	var s := schaetzung(d, sid, attribut)
	if bool(s["sicher"]):
		return str(int(round(float(s["min"]))))
	return "%d–%d" % [int(round(float(s["min"]))), int(round(float(s["max"])))]

static func gesamt_text(d: Dictionary, sid: String) -> String:
	var sp: Dictionary = d["spieler"][sid]
	var kenntnis: float = float(sp["kenntnis"])
	var g: float = Spielerfabrik.gesamt(sp)
	if kenntnis >= 97.0:
		return "%d" % int(round(g))
	var spanne: float = (100.0 - kenntnis) / 100.0 * 14.0
	return "%d–%d" % [int(round(maxf(g - spanne, 1.0))), int(round(minf(g + spanne, 99.0)))]

## Potenzialbeschreibung statt nackter Zahl.
static func potenzial_text(d: Dictionary, sid: String) -> String:
	var sp: Dictionary = d["spieler"][sid]
	var kenntnis: float = float(sp["kenntnis"])
	var pot: float = float(sp["potenzial"])
	if kenntnis < 35.0:
		return "kaum einzuschätzen"
	var unschaerfe: float = (100.0 - kenntnis) / 100.0 * 18.0
	var geschaetzt: float = pot + Namen.bereich(-unschaerfe, unschaerfe)
	if geschaetzt >= 88.0:
		return "Weltklassepotenzial"
	elif geschaetzt >= 78.0:
		return "Nationalmannschaftsformat"
	elif geschaetzt >= 68.0:
		return "klarer Erstligaspieler"
	elif geschaetzt >= 56.0:
		return "solider Erstligakader"
	elif geschaetzt >= 44.0:
		return "Zweitliganiveau"
	return "begrenzt"

static func kenntnis_text(kenntnis: float) -> String:
	if kenntnis >= 97.0:
		return "vollständig bekannt"
	elif kenntnis >= 75.0:
		return "gut beobachtet"
	elif kenntnis >= 50.0:
		return "grob eingeschätzt"
	elif kenntnis >= 25.0:
		return "kaum beobachtet"
	return "nur vom Hörensagen"

# ------------------------------------------------------------- Wochenlauf ---

static func wochenbericht(d: Dictionary, cid: String) -> void:
	if cid == "":
		return
	# Bewertung alter Empfehlungen: hat sich das Talent entwickelt?
	var offen: Array = []
	for b in d["scouting"]["beobachtung"]:
		if Welt.saison_index() - int(b["saison"]) < 2:
			offen.append(b)
			continue
		if not d["spieler"].has(str(b["spieler"])):
			continue
		var sp: Dictionary = d["spieler"][str(b["spieler"])]
		var fortschritt: float = Spielerfabrik.gesamt(sp) - float(b["start"])
		var s: Dictionary = d["personal"].get(str(b["scout"]), {})
		if s.is_empty():
			continue
		if fortschritt >= 6.0:
			s["treffer"] = int(s.get("treffer", 0)) + 1
	d["scouting"]["beobachtung"] = offen
