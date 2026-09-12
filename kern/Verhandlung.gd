class_name Verhandlung
extends RefCounted
## Vertragsverhandlung als Gespräch über mehrere Runden.
##
## Der Spieler (beziehungsweise sein Berater) stellt eine Forderung, man macht
## ein Angebot, er reagiert: annehmen, nachbessern lassen oder aufstehen. Jede
## Runde kostet Geduld, ein schlechtes Angebot kostet viel davon.
##
## Bewertet wird nicht nur das Gehalt. Rolle im Kader, Laufzeit, Erfolgsprämien,
## eine Ablöseklausel und das Verhältnis zum Trainer gehen alle in denselben
## Vergleichswert ein — deshalb lässt sich ein zu niedriges Gehalt mit anderen
## Zugeständnissen ausgleichen.

const RUNDEN_MAX := 6

## Was eine Rolle dem Spieler wert ist, gemessen an seinem Gehaltswunsch.
const ROLLENWERT := {
	"leistungstraeger": 0.12, "stammspieler": 0.05, "rotation": 0.0,
	"ergaenzung": -0.10, "talent": 0.02,
}

# --------------------------------------------------------------- Beginn ---

static func laeuft(d: Dictionary) -> bool:
	return not (d.get("verhandlung", {}) as Dictionary).is_empty() \
		and str((d["verhandlung"] as Dictionary).get("status", "")) == "laeuft"

static func aktuelle(d: Dictionary) -> Dictionary:
	return d.get("verhandlung", {})

static func abbrechen(d: Dictionary) -> void:
	d["verhandlung"] = {}

## Eine Verhandlung eröffnen. art ist "verlaengerung" oder "verpflichtung".
static func starten(d: Dictionary, sid: String, art: String) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var cid: String = Welt.mein_verein_id
	if cid == "":
		return {"ok": false, "grund": "Sie haben derzeit keinen Verein."}
	var ruf: float = float(d["vereine"][cid]["ruf"])
	var wunsch: float = Finanzen.gehaltswunsch(d, cid, sp)
	# Wer wechseln soll, verlangt mehr als wer bleibt.
	if art == "verpflichtung":
		wunsch *= 1.12
	# Unzufriedene und schlecht behandelte Spieler fordern mehr.
	wunsch *= 1.0 + float(sp["unzufriedenheit"]) / 300.0
	wunsch *= clampf(1.12 - Gespraech.beziehung(sp) / 500.0, 0.92, 1.12)

	var jahre: int = 3
	if int(sp["alter"]) >= 33:
		jahre = 1
	elif int(sp["alter"]) >= 30:
		jahre = 2
	elif int(sp["alter"]) <= 21:
		jahre = 4

	var geduld: float = 55.0 + float(sp["charakter"].get("profitum", 12.0)) * 1.6 \
		- float(sp["charakter"].get("temperament", 12.0)) * 1.2 + Gespraech.beziehung(sp) * 0.25
	var forderung := {
		"gehalt": roundf(wunsch / 50.0) * 50.0,
		"jahre": jahre,
		"rolle": _wunschrolle(d, sp),
		"praemie_tor": 0.0,
		"praemie_sieg": 0.0,
		"klausel": 0.0,
	}
	d["verhandlung"] = {
		"spieler": sid,
		"art": art,
		"runde": 1,
		"geduld": clampf(geduld, 25.0, 100.0),
		"laune": clampf(45.0 + Gespraech.beziehung(sp) * 0.4, 10.0, 90.0),
		"forderung": forderung,
		"status": "laeuft",
		"verlauf": [{"wer": "spieler", "text": _eroeffnung(sp, art, forderung)}],
	}
	return {"ok": true, "grund": ""}

static func _wunschrolle(d: Dictionary, sp: Dictionary) -> String:
	var staerke: float = Spielerfabrik.gesamt(sp)
	var kader: float = _kaderschnitt(d, Welt.mein_verein_id)
	if staerke >= kader + 6.0:
		return "leistungstraeger"
	if staerke >= kader:
		return "stammspieler"
	if int(sp["alter"]) <= 21:
		return "talent"
	return "rotation"

static func _kaderschnitt(d: Dictionary, cid: String) -> float:
	if cid == "" or not d["vereine"].has(cid):
		return 60.0
	var summe := 0.0
	var n := 0
	for sid in d["vereine"][cid]["kader"]:
		summe += Spielerfabrik.gesamt(d["spieler"][sid])
		n += 1
	return summe / maxf(float(n), 1.0)

static func _eroeffnung(sp: Dictionary, art: String, f: Dictionary) -> String:
	var n: String = Spielerfabrik.kurz_name(sp)
	var rolle: String = str(Transfermarkt.ROLLEN_NAME.get(str(f["rolle"]), "Rotationsspieler"))
	if art == "verpflichtung":
		return "Guten Tag. %s hört sich Ihr Angebot gerne an — aber wir sprechen über %s die Woche, %d Jahre und die Rolle als %s. Darunter wird es schwierig." % [
			n, Stil.geld(float(f["gehalt"])), int(f["jahre"]), rolle]
	return "%s bleibt gern. Die Vorstellung sind %s pro Woche, %d Jahre Laufzeit und die Rolle als %s." % [
		n, Stil.geld(float(f["gehalt"])), int(f["jahre"]), rolle]

# --------------------------------------------------------------- Runden ---

## Wert eines Angebots aus Sicht des Spielers, gemessen an seiner Forderung.
## 1.0 heißt: genau getroffen. Darunter zu wenig, darüber großzügig.
static func bewerten(d: Dictionary, sp: Dictionary, forderung: Dictionary, angebot: Dictionary) -> float:
	var soll: float = maxf(float(forderung["gehalt"]), 1.0)
	var ist: float = float(angebot.get("gehalt", 0.0))
	# Prämien und Klausel rechnet er sich aufs Gehalt an.
	ist += Praemien.gehaltsersatz(d, sp, float(angebot.get("praemie_tor", 0.0)),
		float(angebot.get("praemie_sieg", 0.0)), Welt.mein_verein_id)
	var klausel: float = float(angebot.get("klausel", 0.0))
	if klausel > 0.0:
		ist += soll * Transfermarkt.klausel_rabatt(d, sp, maxf(klausel, Transfermarkt.klausel_untergrenze(sp)))
	var wert: float = ist / soll

	# Rolle: eine größere Rolle als erwartet wiegt bares Geld auf.
	var soll_rolle: float = float(ROLLENWERT.get(str(forderung["rolle"]), 0.0))
	var ist_rolle: float = float(ROLLENWERT.get(str(angebot.get("rolle", "rotation")), 0.0))
	wert += (ist_rolle - soll_rolle)

	# Laufzeit: ältere Spieler wollen Sicherheit, junge wollen sich nicht binden.
	var jahre: int = int(angebot.get("jahre", 3))
	var soll_jahre: int = int(forderung["jahre"])
	var abweichung: int = jahre - soll_jahre
	if int(sp["alter"]) >= 30:
		wert += float(abweichung) * 0.035
	elif int(sp["alter"]) <= 22:
		wert -= float(abweichung) * 0.025
	else:
		wert -= absf(float(abweichung)) * 0.012
	return wert

## Ein Angebot machen. Liefert {"status", "text", "wert"}.
static func anbieten(d: Dictionary, angebot: Dictionary) -> Dictionary:
	if not laeuft(d):
		return {"status": "keine", "text": "Es läuft keine Verhandlung."}
	var v: Dictionary = d["verhandlung"]
	var sp: Dictionary = d["spieler"][str(v["spieler"])]
	var wert: float = bewerten(d, sp, v["forderung"], angebot)
	v["verlauf"].append({"wer": "trainer", "text": _angebotstext(angebot)})

	# Was er annimmt, hängt von Laune und Geduld ab: wer gut gelaunt ist,
	# lässt eher mit sich reden.
	var schwelle: float = 1.0 - float(v["laune"]) / 900.0 - Gespraech.beziehung(sp) / 1200.0
	if wert >= schwelle:
		v["status"] = "angenommen"
		v["angebot"] = angebot.duplicate()
		var text := "%s ist einverstanden. Wir machen das so." % Spielerfabrik.kurz_name(sp)
		v["verlauf"].append({"wer": "spieler", "text": text})
		return {"status": "angenommen", "text": text, "wert": wert}

	# Zu weit weg: Geduld bricht ein
	var abstand: float = clampf(schwelle - wert, 0.0, 1.0)
	var kosten: float = 8.0 + abstand * 120.0
	v["geduld"] = clampf(float(v["geduld"]) - kosten, 0.0, 100.0)
	v["laune"] = clampf(float(v["laune"]) - abstand * 55.0 + 3.0, 0.0, 100.0)
	v["runde"] = int(v["runde"]) + 1

	if float(v["geduld"]) <= 0.0 or int(v["runde"]) > RUNDEN_MAX:
		v["status"] = "geplatzt"
		var aus := "%s steht auf. \"So kommen wir nicht zusammen.\"" % Spielerfabrik.kurz_name(sp)
		v["verlauf"].append({"wer": "spieler", "text": aus})
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) + 8.0, 0.0, 100.0)
		return {"status": "geplatzt", "text": aus, "wert": wert}

	# Nachbessern: Die Forderung sinkt ein wenig, wenn das Angebot nah dran war.
	var f: Dictionary = v["forderung"]
	var nachgeben: float = clampf(0.05 - abstand * 0.06, -0.02, 0.05)
	f["gehalt"] = maxf(roundf(float(f["gehalt"]) * (1.0 - nachgeben) / 50.0) * 50.0, 180.0)
	var text2 := _gegentext(sp, abstand, f, angebot)
	v["verlauf"].append({"wer": "spieler", "text": text2})
	return {"status": "laeuft", "text": text2, "wert": wert}

static func _angebotstext(a: Dictionary) -> String:
	var teile: Array = ["%s pro Woche" % Stil.geld(float(a.get("gehalt", 0.0))),
		"%d Jahre" % int(a.get("jahre", 3)),
		str(Transfermarkt.ROLLEN_NAME.get(str(a.get("rolle", "rotation")), "Rotation"))]
	if float(a.get("praemie_tor", 0.0)) > 0.0 or float(a.get("praemie_sieg", 0.0)) > 0.0:
		teile.append("Prämien")
	if float(a.get("klausel", 0.0)) > 0.0:
		teile.append("Klausel %s" % Stil.geld(float(a["klausel"])))
	return "Unser Angebot: " + ", ".join(teile) + "."

static func _gegentext(sp: Dictionary, abstand: float, f: Dictionary, angebot: Dictionary) -> String:
	var n: String = Spielerfabrik.kurz_name(sp)
	if abstand < 0.04:
		return "Fast. Legen Sie beim Gehalt noch etwas drauf — %s die Woche, dann unterschreibt %s." % [
			Stil.geld(float(f["gehalt"])), n]
	if abstand < 0.12:
		if str(angebot.get("rolle", "")) != str(f["rolle"]):
			return "Über das Geld ließe sich reden, aber nicht über die Rolle. %s will als %s spielen." % [
				n, str(Transfermarkt.ROLLEN_NAME.get(str(f["rolle"]), ""))]
		return "Das liegt noch auseinander. %s die Woche wären das Mindeste." % Stil.geld(float(f["gehalt"]))
	if abstand < 0.28:
		return "Das ist deutlich zu wenig. %s hat andere Möglichkeiten." % n
	return "Ehrlich gesagt: Damit brauchen Sie bei %s nicht anzufangen." % n

## Ein angenommenes Ergebnis in einen Vertrag gießen.
static func abschliessen(d: Dictionary) -> Dictionary:
	var v: Dictionary = d.get("verhandlung", {})
	if v.is_empty() or str(v.get("status", "")) != "angenommen":
		return {"ok": false, "grund": "Es liegt kein angenommenes Angebot vor."}
	var sid: String = str(v["spieler"])
	var a: Dictionary = v["angebot"]
	var sp: Dictionary = d["spieler"][sid]
	if str(v["art"]) == "verlaengerung":
		sp["vertrag"]["gehalt"] = float(a["gehalt"])
		sp["vertrag"]["bis_saison"] = Welt.saison_index() + maxi(int(a["jahre"]), 1)
		sp["vertrag"]["rolle"] = str(a["rolle"])
		var grenzen := Praemien.begrenzen(float(a.get("praemie_tor", 0.0)), float(a.get("praemie_sieg", 0.0)))
		sp["vertrag"]["praemie_tor"] = grenzen["praemie_tor"]
		sp["vertrag"]["praemie_sieg"] = grenzen["praemie_sieg"]
		var k: float = float(a.get("klausel", 0.0))
		sp["vertrag"]["ablöseklausel"] = 0.0 if k <= 0.0 else maxf(k, Transfermarkt.klausel_untergrenze(sp))
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) - 25.0, 0.0, 100.0)
		sp["moral"] = clampf(float(sp["moral"]) + 8.0, 5.0, 100.0)
		sp["beziehung"] = clampf(Gespraech.beziehung(sp) + 6.0, 0.0, 100.0)
		d["verhandlung"] = {}
		return {"ok": true, "grund": "%s hat verlängert." % Spielerfabrik.voller_name(sp)}
	# Verpflichtung: das Gehaltspaket geht als Angebot an den abgebenden Verein
	var erg := Transfermarkt.angebot_abgeben(d, sid, Transfermarkt.ablösevorstellung(d, sid),
		float(a["gehalt"]), int(a["jahre"]), str(a["rolle"]), "kauf",
		float(a.get("praemie_tor", 0.0)), float(a.get("praemie_sieg", 0.0)))
	d["verhandlung"] = {}
	return erg
