class_name Trainingslager
extends RefCounted
## Trainingslager und Positionsumschulung — die beiden langfristigen Werkzeuge
## der Trainingsarbeit.
##
## Der Wochenplan wirkt in Wochen. Ein Trainingslager wirkt in Monaten: Man
## fährt in der Sommer- oder Winterpause weg, zahlt dafür, verliert Erholung
## und bekommt dafür etwas, das im Alltag nicht zu haben ist — Grundlagen,
## Automatismen oder eine Mannschaft, die sich kennt.
##
## Die Umschulung ist die zweite Sorte Geduld: Ein Rückraumspieler wird nicht
## über Nacht zum Kreisläufer. Über Monate wächst seine Eignung auf der neuen
## Position, bis sie als Zweitposition trägt.

## Wohin man fahren kann. `tage` ist die Dauer, `kosten_pro_tag` je Spieler.
const ORTE := {
	"heim": {
		"name": "Zu Hause bleiben", "tage": 0, "kosten_pro_tag": 0.0,
		"text": "Kein Lager. Der Alltag geht weiter.",
	},
	"mittelgebirge": {
		"name": "Mittelgebirge", "tage": 8, "kosten_pro_tag": 95.0,
		"text": "Höhenluft und lange Läufe. Hart für die Beine, gut für die Lunge.",
	},
	"sportschule": {
		"name": "Sportschule", "tage": 7, "kosten_pro_tag": 120.0,
		"text": "Zwei Hallen, ein Videoraum, kein Ablenkung. Taktik von morgens bis abends.",
	},
	"kueste": {
		"name": "Küste", "tage": 6, "kosten_pro_tag": 140.0,
		"text": "Sand, Wasser, gemeinsame Abende. Weniger Einheiten, mehr Mannschaft.",
	},
	"ausland": {
		"name": "Turnier im Ausland", "tage": 10, "kosten_pro_tag": 210.0,
		"text": "Testspiele gegen fremde Gegner. Teuer, anstrengend — und man lernt viel.",
	},
}

## Was ein Lager bewirkt. Werte sind Zielgrößen für die volle Dauer.
const WIRKUNG := {
	"mittelgebirge": {"attr": ["ausdauer", "physis", "arbeitseinsatz"], "zuwachs": 0.55,
		"fitness": 9.0, "last": 16.0, "teamgeist": 2.0, "verletzung": 1.5},
	"sportschule": {"attr": ["uebersicht", "entscheidung", "deckungsarbeit", "antizipation"], "zuwachs": 0.5,
		"fitness": 3.0, "last": 10.0, "teamgeist": 3.0, "verletzung": 0.9},
	"kueste": {"attr": ["teamgeist", "nervenstaerke"], "zuwachs": 0.35,
		"fitness": 4.0, "last": 5.0, "teamgeist": 9.0, "verletzung": 0.5},
	"ausland": {"attr": ["taeuschung", "ballsicherheit", "zweikampf", "wurfpraezision"], "zuwachs": 0.62,
		"fitness": 6.0, "last": 20.0, "teamgeist": 6.0, "verletzung": 1.9},
}

## Nur in der Sommer- und der Winterpause ist Platz für ein Lager.
static func fenster_offen(d: Dictionary) -> bool:
	var tis: int = Kalender.tag_in_saison(int(d["tag"]))
	return tis <= 45 or (tis >= 160 and tis <= 205)

static func fenstername(d: Dictionary) -> String:
	var tis: int = Kalender.tag_in_saison(int(d["tag"]))
	if tis <= 45:
		return "Sommervorbereitung"
	if tis >= 160 and tis <= 205:
		return "Winterpause"
	return ""

static func laufend(d: Dictionary, cid: String) -> Dictionary:
	return (d["vereine"][cid] as Dictionary).get("trainingslager", {})

static func kosten(d: Dictionary, cid: String, ort: String) -> float:
	var o: Dictionary = ORTE.get(ort, ORTE["heim"])
	var kader: int = (d["vereine"][cid]["kader"] as Array).size()
	return float(o["kosten_pro_tag"]) * float(o["tage"]) * float(kader)

static func buchen(d: Dictionary, cid: String, ort: String) -> Dictionary:
	if not ORTE.has(ort) or ort == "heim":
		return {"ok": false, "grund": "Dieses Ziel gibt es nicht."}
	if not fenster_offen(d):
		return {"ok": false, "grund": "Ein Lager ist nur in der Sommervorbereitung oder der Winterpause möglich."}
	if not laufend(d, cid).is_empty():
		return {"ok": false, "grund": "Ihre Mannschaft ist bereits unterwegs."}
	var v: Dictionary = d["vereine"][cid]
	if int(v.get("lager_saison", -1)) == Welt.saison_index() and Kalender.tag_in_saison(int(d["tag"])) > 60:
		return {"ok": false, "grund": "In dieser Saison waren Sie schon im Lager."}
	var preis := kosten(d, cid, ort)
	if float(v["kasse"]) < preis:
		return {"ok": false, "grund": "Das Lager kostet %s — so viel ist nicht in der Kasse." % Stil.geld(preis)}
	var o: Dictionary = ORTE[ort]
	Finanzen.buchen(d, cid, -preis, "Trainingslager %s" % str(o["name"]), "betrieb")
	v["trainingslager"] = {
		"ort": ort, "beginn": int(d["tag"]), "bis": int(d["tag"]) + int(o["tage"]),
		"tage_gesamt": int(o["tage"]), "tage_gelaufen": 0,
	}
	v["lager_saison"] = Welt.saison_index()
	return {"ok": true, "grund": "%s: %d Tage %s für %s." % [str(o["name"]), int(o["tage"]),
		"im Mittelgebirge" if ort == "mittelgebirge" else "gebucht", Stil.geld(preis)]}

static func abbrechen(d: Dictionary, cid: String) -> void:
	(d["vereine"][cid] as Dictionary)["trainingslager"] = {}

## Ein Tag im Lager. Wird vom Tageswechsel für jeden Verein aufgerufen.
static func tageswechsel(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var lager: Dictionary = laufend(d, cid)
		if lager.is_empty():
			continue
		_tag_wirken(d, cid, lager)
		lager["tage_gelaufen"] = int(lager["tage_gelaufen"]) + 1
		if int(d["tag"]) >= int(lager["bis"]):
			_abschluss(d, cid, lager)
			(d["vereine"][cid] as Dictionary)["trainingslager"] = {}

static func _tag_wirken(d: Dictionary, cid: String, lager: Dictionary) -> void:
	var ort: String = str(lager["ort"])
	var w: Dictionary = WIRKUNG.get(ort, WIRKUNG["sportschule"])
	var tage: float = maxf(float(lager["tage_gesamt"]), 1.0)
	var qualitaet: float = Training.trainerqualitaet(d, cid) / 100.0
	var v: Dictionary = d["vereine"][cid]
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if not (sp["verletzung"] as Dictionary).is_empty():
			continue
		# Grundlagenarbeit: die Zielattribute wachsen spürbar schneller als
		# im Alltag, dafür steigt die Last und das Risiko.
		var a: String = str(Namen.waehle(w["attr"]))
		if (sp["attr"] as Dictionary).has(a):
			var jung: float = 1.35 if int(sp["alter"]) <= 23 else (0.7 if int(sp["alter"]) >= 31 else 1.0)
			sp["attr"][a] = clampf(float(sp["attr"][a]) + float(w["zuwachs"]) / tage
				* (0.6 + 0.7 * qualitaet) * jung * Namen.bereich(0.6, 1.5), 1.0, 20.0)
		sp["fitness"] = clampf(float(sp["fitness"]) + float(w["fitness"]) / tage, 20.0, 100.0)
		sp["last"] = clampf(float(sp["last"]) + float(w["last"]) / tage, 0.0, 100.0)
		sp["attr"]["teamgeist"] = clampf(float(sp["attr"]["teamgeist"]) + float(w["teamgeist"]) / tage * 0.12, 1.0, 20.0)
		Spielerfabrik.staerke_verwerfen(sp)
		sp["moral"] = clampf(float(sp["moral"]) + 0.25, 5.0, 100.0)
		if Namen.zufall() < Medizin.risiko(d, sid) * float(w["verletzung"]) * 8.0:
			var vl := Medizin.erzeuge_verletzung(d, sid, false)
			if cid == Welt.mein_verein_id:
				Welt.nachricht({
					"typ": "medizin", "wichtig": int(vl["schwere"]) >= 2,
					"betreff": "Verletzung im Trainingslager: %s" % Spielerfabrik.voller_name(sp),
					"text": "%s hat sich im Lager verletzt (%s). Ausfall: etwa %d Tage." % [
						Spielerfabrik.kurz_name(sp), vl["art"], int(vl["tage"])],
				})
	v["stimmung_kabine"] = clampf(float(v.get("stimmung_kabine", 50.0))
		+ float(w["teamgeist"]) / tage * 0.5, 0.0, 100.0)

static func _abschluss(d: Dictionary, cid: String, lager: Dictionary) -> void:
	if cid != Welt.mein_verein_id:
		return
	var o: Dictionary = ORTE.get(str(lager["ort"]), ORTE["heim"])
	Welt.nachricht({
		"typ": "training", "wichtig": true,
		"betreff": "Zurück aus dem Trainingslager",
		"text": "%d Tage %s liegen hinter der Mannschaft. %s" % [
			int(lager["tage_gesamt"]), str(o["name"]), str(o["text"])],
	})

# ------------------------------------------------------- Umschulung ---

## So viele Punkte braucht eine Umschulung, bis die neue Position trägt.
const UMSCHULUNG_ZIEL := 100.0

static func umschulung(sp: Dictionary) -> Dictionary:
	return sp.get("umschulung", {})

static func umschulung_starten(d: Dictionary, sid: String, position: String) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	if not Spielerfabrik.POSITIONEN.has(position):
		return {"ok": false, "grund": "Diese Position gibt es nicht."}
	if position == str(sp["position"]):
		return {"ok": false, "grund": "Dort spielt er bereits."}
	if bool(sp["ist_torwart"]) != (position == "TW"):
		return {"ok": false, "grund": "Zwischen Tor und Feld wird nicht umgeschult."}
	if (sp["zweitpositionen"] as Array).has(position):
		return {"ok": false, "grund": "Diese Position beherrscht er schon."}
	if int(sp["alter"]) > 29:
		return {"ok": false, "grund": "Mit %d Jahren lernt niemand mehr eine neue Position." % int(sp["alter"])}
	sp["umschulung"] = {"position": position, "fortschritt": 0.0, "seit": int(d["tag"])}
	return {"ok": true, "grund": "%s wird auf %s umgeschult." % [Spielerfabrik.kurz_name(sp),
		Spielerfabrik.POSITION_NAME[position]]}

static func umschulung_abbrechen(d: Dictionary, sid: String) -> void:
	d["spieler"][sid].erase("umschulung")

## Wöchentlicher Fortschritt. Junge, lernwillige Spieler auf verwandten
## Positionen sind schneller fertig als alte auf fremden.
static func umschulung_wochenwechsel(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var qualitaet: float = Training.trainerqualitaet(d, cid) / 100.0
		for sid in d["vereine"][cid]["kader"]:
			var sp: Dictionary = d["spieler"][sid]
			var u: Dictionary = umschulung(sp)
			if u.is_empty():
				continue
			var ziel: String = str(u["position"])
			var naehe: float = float((Spielerfabrik.POSITION_NAEHE[str(sp["position"])] as Dictionary).get(ziel, 0.3))
			var lern: float = float(sp["attr"]["arbeitseinsatz"]) / 20.0
			var jung: float = 1.4 if int(sp["alter"]) <= 22 else (0.65 if int(sp["alter"]) >= 27 else 1.0)
			u["fortschritt"] = float(u["fortschritt"]) + 3.2 * (0.4 + naehe) * (0.6 + 0.7 * qualitaet) \
				* (0.7 + 0.6 * lern) * jung
			if float(u["fortschritt"]) < UMSCHULUNG_ZIEL:
				continue
			(sp["zweitpositionen"] as Array).append(ziel)
			sp.erase("umschulung")
			Laufbahn.eintragen(d, sid, "meilenstein", "Umschulung auf %s abgeschlossen" % Spielerfabrik.POSITION_NAME[ziel])
			if cid == Welt.mein_verein_id:
				Welt.nachricht({
					"typ": "training", "wichtig": true,
					"betreff": "Umschulung abgeschlossen: %s" % Spielerfabrik.voller_name(sp),
					"text": "%s kann jetzt auch auf %s eingesetzt werden." % [
						Spielerfabrik.kurz_name(sp), Spielerfabrik.POSITION_NAME[ziel]],
				})

## Wie lange die Umschulung noch dauert, in Wochen (Schätzung).
static func restwochen(d: Dictionary, sp: Dictionary) -> int:
	var u := umschulung(sp)
	if u.is_empty():
		return 0
	var cid: String = str(sp["verein"])
	var qualitaet: float = Training.trainerqualitaet(d, cid) / 100.0 if cid != "" else 0.5
	var naehe: float = float((Spielerfabrik.POSITION_NAEHE[str(sp["position"])] as Dictionary).get(str(u["position"]), 0.3))
	var lern: float = float(sp["attr"]["arbeitseinsatz"]) / 20.0
	var jung: float = 1.4 if int(sp["alter"]) <= 22 else (0.65 if int(sp["alter"]) >= 27 else 1.0)
	var pro_woche: float = maxf(3.2 * (0.4 + naehe) * (0.6 + 0.7 * qualitaet) * (0.7 + 0.6 * lern) * jung, 0.3)
	return int(ceil((UMSCHULUNG_ZIEL - float(u["fortschritt"])) / pro_woche))
