class_name Vorvertrag
extends RefCounted
## Verträge für die kommende Saison.
##
## Im Handball ist das der Normalfall, nicht die Ausnahme: Wechsel werden
## Monate vor dem Sommer bekanntgegeben, oft schon im Herbst. Ein Spieler,
## dessen Vertrag im Sommer endet, darf vorher woanders unterschreiben und
## spielt die laufende Saison bei seinem alten Verein zu Ende.
##
## Bisher kannte das Spiel nur den sofortigen Wechsel im offenen Fenster. Ein
## Angebot mit der Art "vorvertrag" wurde zwar angenommen, aber nirgends
## anders behandelt — der Spieler wechselte trotzdem sofort. Damit fehlte die
## Ebene, auf der ein Kader tatsächlich geplant wird: man verpflichtet im
## Januar den Rückraumspieler für den Sommer, und der Gegner erfährt es aus
## der Zeitung.
##
## Drei Regeln:
##  1. Möglich nur für Spieler, deren Vertrag am Saisonende ausläuft.
##  2. Ablösefrei — der abgebende Verein bekommt nichts und wird nicht
##     gefragt. Genau das macht die Sache für ihn schmerzhaft.
##  3. Möglich auch bei geschlossenem Transferfenster. Das Fenster regelt,
##     wann jemand die Mannschaft wechselt, nicht wann er unterschreibt.

## Ab diesem Tag der Saison darf für die kommende unterschrieben werden.
## Vorher ist es zu früh — ein Vertrag, der noch anderthalb Jahre läuft, wird
## nicht im August für übermorgen verhandelt.
const AB_TAG_IN_SAISON := 120

static func fenster_offen(d: Dictionary) -> bool:
	return Kalender.tag_in_saison(int(d.get("tag", 0))) >= AB_TAG_IN_SAISON

## Läuft der Vertrag dieses Spielers zum Saisonende aus?
static func laeuft_aus(d: Dictionary, sid: String) -> bool:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty() or str(sp.get("verein", "")) == "":
		return false
	if bool(sp.get("jugendspieler", false)):
		return false
	return int(sp["vertrag"].get("bis_saison", 9)) <= Welt.saison_index()

## Kann für diesen Spieler ein Vorvertrag geschlossen werden — und wenn nicht,
## warum nicht?
static func moeglich(d: Dictionary, sid: String) -> Dictionary:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty():
		return {"ok": false, "grund": "Spieler nicht gefunden."}
	if not (sp.get("vorvertrag", {}) as Dictionary).is_empty():
		return {"ok": false, "grund": "%s hat bereits für die kommende Saison unterschrieben." % Spielerfabrik.kurz_name(sp)}
	if str(sp.get("verein", "")) == "":
		return {"ok": false, "grund": "Vereinslose Spieler unterschreiben sofort, nicht auf Vorrat."}
	if not laeuft_aus(d, sid):
		return {"ok": false, "grund": "Der Vertrag von %s läuft noch. Ein Vorvertrag ist erst im letzten Vertragsjahr möglich." % Spielerfabrik.kurz_name(sp)}
	if not fenster_offen(d):
		var rest: int = AB_TAG_IN_SAISON - Kalender.tag_in_saison(int(d["tag"]))
		return {"ok": false, "grund": "Für die kommende Saison wird erst in %d Tagen verhandelt." % rest}
	if Transfermarkt.unverkaeuflich(d, sid):
		return {"ok": false, "grund": "%s ist der einzige Torwart seines Vereins — dort wird niemand zusehen." % Spielerfabrik.kurz_name(sp)}
	return {"ok": true, "grund": ""}

## Schließt den Vorvertrag. Der Spieler bleibt bis zum Saisonende, wo er ist.
static func schliessen(d: Dictionary, sid: String, nach: String, gehalt: float,
		laufzeit: int, rolle: String) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var alt: String = str(sp["verein"])
	sp["vorvertrag"] = {
		"verein": nach,
		"gehalt": gehalt,
		"laufzeit": maxi(laufzeit, 1),
		"rolle": rolle,
		"saison": Welt.saison_index(),
	}
	# Das ist eine Nachricht wert — für beide Seiten, und für die Presse.
	Medien.artikel(d, "%s wechselt im Sommer zu %s" % [
		Spielerfabrik.voller_name(sp), str(d["vereine"][nach]["name"])],
		"%s hat einen Vertrag für die kommende Saison unterschrieben und verlässt %s am Saisonende ablösefrei. Bis dahin spielt er weiter für seinen bisherigen Verein." % [
			Spielerfabrik.voller_name(sp),
			str(d["vereine"][alt]["name"]) if d["vereine"].has(alt) else "seinen Verein"],
		"neutral", "transfer", {"spieler": sid})
	if alt == Welt.mein_verein_id:
		Welt.nachricht({
			"typ": "transfer", "wichtig": true,
			"betreff": "%s unterschreibt woanders" % Spielerfabrik.voller_name(sp),
			"text": "%s hat für die kommende Saison bei %s unterschrieben. Er bleibt bis zum Saisonende, geht dann aber ablösefrei — eine Ablöse ist nicht mehr zu erzielen.\n\nWer Verträge zu spät verlängert, verliert Spieler auf genau diesem Weg." % [
				Spielerfabrik.voller_name(sp), str(d["vereine"][nach]["name"])],
			"daten": {"spieler": sid},
		})
	elif nach == Welt.mein_verein_id:
		Welt.nachricht({
			"typ": "transfer", "wichtig": true,
			"betreff": "%s kommt im Sommer" % Spielerfabrik.voller_name(sp),
			"text": "%s hat unterschrieben und stößt zum Saisonwechsel ablösefrei zur Mannschaft." % Spielerfabrik.voller_name(sp),
			"daten": {"spieler": sid},
		})
	# Der eigene Verein weiß Bescheid und wird unruhig.
	if d["vereine"].has(alt):
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) - 12.0, 0.0, 100.0)

## Löst alle Vorverträge ein. Läuft im Saisonwechsel, und zwar *vor* dem
## Ablaufen der Verträge — sonst wäre der Spieler schon vereinslos und die
## Zusage ginge ins Leere.
static func einloesen(d: Dictionary) -> void:
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		var vv: Dictionary = sp.get("vorvertrag", {})
		if vv.is_empty():
			continue
		var nach: String = str(vv["verein"])
		if not d["vereine"].has(nach):
			sp["vorvertrag"] = {}
			continue
		Transfermarkt.transfer_durchfuehren(d, sid, nach, 0.0, float(vv["gehalt"]),
			int(vv["laufzeit"]), str(vv["rolle"]))
		sp["vorvertrag"] = {}

## Alle Spieler mit einer Zusage für die kommende Saison — für die Oberfläche.
static func offene(d: Dictionary, cid: String) -> Array:
	var liste: Array = []
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		var vv: Dictionary = sp.get("vorvertrag", {})
		if vv.is_empty():
			continue
		if str(vv["verein"]) == cid or str(sp.get("verein", "")) == cid:
			liste.append({"spieler": str(sid), "nach": str(vv["verein"]),
				"gehalt": float(vv["gehalt"]), "abgang": str(sp.get("verein", "")) == cid})
	return liste

# ------------------------------------------------------- Computertrainer ---

## Die Computervereine sichern sich auslaufende Verträge ebenfalls — sonst
## waere der Vorvertrag ein Werkzeug, das nur einer benutzt, und ablösefreie
## Spitzenspieler laegen jeden Sommer als Geschenk herum.
static func ki_runde(d: Dictionary) -> void:
	if not fenster_offen(d):
		return
	if Namen.zufall() > 0.22:
		return
	var vereine: Array = Weltgenerator.clubs(d)
	vereine.shuffle()
	for cid in vereine:
		var v: Dictionary = d["vereine"][cid]
		if bool(v.get("ist_mensch", false)) or bool(v.get("ist_nationalteam", false)):
			continue
		if (v["kader"] as Array).size() >= 22:
			continue
		var pos := KI.schwaechste_position(d, cid)
		if pos == "":
			continue
		var bester := ""
		var bestwert := 0.0
		for sid in suchbare(d, pos):
			var sp: Dictionary = d["spieler"][sid]
			if str(sp["verein"]) == cid:
				continue
			var gehalt: float = Finanzen.gehaltswunsch(d, cid, sp)
			if gehalt * 52.0 > float(v["gehaltsbudget"]) * 52.0 * 0.16:
				continue
			if not Wechselbereitschaft.ansprechbar(d, str(sid), cid, "stammspieler", gehalt):
				continue
			# Auch ein abloesefreier Wechsel darf einen Verein nicht ohne
			# Torwart dastehen lassen.
			if Transfermarkt.unverkaeuflich(d, str(sid)):
				continue
			var w: float = Spielerfabrik.gesamt(sp)
			if w > bestwert:
				bestwert = w
				bester = str(sid)
		if bester != "":
			var sp2: Dictionary = d["spieler"][bester]
			schliessen(d, bester, cid, Finanzen.gehaltswunsch(d, cid, sp2),
				Namen.wuerfel(2, 4), "stammspieler")
			return

## Spieler auf einer Position, deren Vertrag ausläuft und die noch frei sind.
static func suchbare(d: Dictionary, pos: String) -> Array:
	var liste: Array = []
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp.get("position", "")) != pos:
			continue
		if not (sp.get("vorvertrag", {}) as Dictionary).is_empty():
			continue
		if laeuft_aus(d, str(sid)):
			liste.append(str(sid))
	return liste
