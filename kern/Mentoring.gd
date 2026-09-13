class_name Mentoring
extends RefCounted
## Patenschaften: ein erfahrener Spieler nimmt einen jungen unter seine Fittiche.
##
## Das dritte eigene System von Hallenherz. Es verbindet Kabine, Nachwuchs und
## Entwicklung: Ein Talent lernt nicht nur im Training, sondern von einem
## Vorbild — und übernimmt dabei auch dessen Charakter. Wer einen Söldner zum
## Paten macht, bekommt in zwei Jahren einen zweiten Söldner.
##
## Gespeichert wird je Verein in `verein["mentoring"]` als Liste von Paaren.

const MENTOR_ALTER := 27
const SCHUELER_ALTER := 23
const HOECHSTZAHL := 3
## Nach so vielen Tagen wirkt eine Patenschaft voll.
const REIFEZEIT := 84.0
## Charaktereigenschaften, die der Schüler vom Paten übernimmt.
const UEBERTRAGUNG := ["ehrgeiz", "loyalitaet", "temperament", "profitum"]
## Attribute, in denen ein Pate seinen Schüler direkt weiterbringt.
const LEHRATTRIBUTE := ["entscheidung", "uebersicht", "nervenstaerke", "arbeitseinsatz", "antizipation"]

static func paare(d: Dictionary, cid: String) -> Array:
	var v: Dictionary = d["vereine"].get(cid, {})
	if v.is_empty():
		return []
	if not v.has("mentoring"):
		v["mentoring"] = []
	return v["mentoring"]

static func hat_paten(d: Dictionary, cid: String, sid: String) -> bool:
	for paar in paare(d, cid):
		if str(paar["schueler"]) == sid:
			return true
	return false

static func ist_pate(d: Dictionary, cid: String, sid: String) -> bool:
	for paar in paare(d, cid):
		if str(paar["mentor"]) == sid:
			return true
	return false

## Wer kommt als Pate infrage: erfahren, gefestigt, im Verein akzeptiert.
static func kandidaten_mentor(d: Dictionary, cid: String) -> Array:
	var liste: Array = []
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if int(sp["alter"]) < MENTOR_ALTER or ist_pate(d, cid, sid):
			continue
		liste.append(sid)
	liste.sort_custom(func(a, b): return Kabine.einfluss(d, a) > Kabine.einfluss(d, b))
	return liste

static func kandidaten_schueler(d: Dictionary, cid: String) -> Array:
	var liste: Array = []
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if int(sp["alter"]) > SCHUELER_ALTER or hat_paten(d, cid, sid):
			continue
		liste.append(sid)
	liste.sort_custom(func(a, b): return float(d["spieler"][a]["potenzial"]) > float(d["spieler"][b]["potenzial"]))
	return liste

## Wie gut die beiden zusammenpassen (0..100). Fachlich, menschlich, sprachlich.
static func eignung(d: Dictionary, mentor: String, schueler: String) -> float:
	var m: Dictionary = d["spieler"].get(mentor, {})
	var s: Dictionary = d["spieler"].get(schueler, {})
	if m.is_empty() or s.is_empty():
		return 0.0
	var mc: Dictionary = m["charakter"]
	var wert: float = 28.0
	# Führung und Profitum machen den Lehrmeister
	wert += float(m["attr"]["fuehrung"]) * 1.5
	wert += float(mc.get("profitum", 12.0)) * 0.9
	# Ein Hitzkopf ist ein schlechtes Vorbild
	wert -= maxf(float(mc.get("temperament", 10.0)) - 12.0, 0.0) * 1.1
	# Klassenunterschied: vom Besseren lernt man mehr
	wert += clampf(Spielerfabrik.gesamt(m) - Spielerfabrik.gesamt(s), -20.0, 30.0) * 0.35
	# Gleiche Position, gleiche Sprache
	if str(m["position"]) == str(s["position"]):
		wert += 9.0
	elif bool(m["ist_torwart"]) == bool(s["ist_torwart"]):
		wert += 3.0
	if str(m["nation"]) == str(s["nation"]):
		wert += 7.0
	# Altersabstand: zu nah beieinander, und es ist keine Patenschaft
	var abstand: int = int(m["alter"]) - int(s["alter"])
	wert += clampf(float(abstand) - 4.0, -8.0, 6.0)
	# Wer selbst unzufrieden ist, taugt nicht als Vorbild
	wert -= float(m.get("unzufriedenheit", 0.0)) * 0.25
	if bool(m.get("transferwunsch", false)):
		wert -= 12.0
	# Lernwille des Schülers
	wert += (float(s["attr"]["arbeitseinsatz"]) - 10.0) * 0.8
	return clampf(wert, 0.0, 100.0)

static func eignung_text(wert: float) -> String:
	if wert >= 78.0:
		return "ideal"
	if wert >= 62.0:
		return "sehr passend"
	if wert >= 46.0:
		return "passend"
	if wert >= 30.0:
		return "mäßig"
	return "ungeeignet"

static func anlegen(d: Dictionary, cid: String, mentor: String, schueler: String) -> Dictionary:
	var liste: Array = paare(d, cid)
	if liste.size() >= HOECHSTZAHL:
		return {"ok": false, "grund": "Mehr als %d Patenschaften trägt eine Kabine nicht." % HOECHSTZAHL}
	if mentor == "" or schueler == "" or mentor == schueler:
		return {"ok": false, "grund": "Bitte Paten und Schützling auswählen."}
	if hat_paten(d, cid, schueler):
		return {"ok": false, "grund": "Dieser Spieler hat bereits einen Paten."}
	if ist_pate(d, cid, mentor):
		return {"ok": false, "grund": "Ein Pate kümmert sich nur um einen Schützling."}
	var wert: float = eignung(d, mentor, schueler)
	if wert < 25.0:
		return {"ok": false, "grund": "Die beiden werden nicht warm miteinander."}
	liste.append({"mentor": mentor, "schueler": schueler, "seit": int(d["tag"]), "fortschritt": 0.0})
	var m: Dictionary = d["spieler"][mentor]
	m["moral"] = clampf(float(m["moral"]) + 3.0, 5.0, 100.0)
	return {"ok": true, "grund": "%s nimmt %s unter seine Fittiche (%s)." % [
		Spielerfabrik.kurz_name(m), Spielerfabrik.kurz_name(d["spieler"][schueler]), eignung_text(wert)]}

static func aufloesen(d: Dictionary, cid: String, index: int) -> void:
	var liste: Array = paare(d, cid)
	if index < 0 or index >= liste.size():
		return
	liste.remove_at(index)

## Wie weit die Patenschaft gereift ist (0..1). Etwas passiert vom ersten Tag
## an, die volle Wirkung braucht aber eine gemeinsame Vorbereitung.
static func reife(d: Dictionary, paar: Dictionary) -> float:
	var tage: float = float(int(d["tag"]) - int(paar["seit"]))
	return clampf(0.12 + tage / REIFEZEIT * 0.88, 0.0, 1.0)

# ------------------------------------------------------------- Wochenlauf ---

static func wochenwechsel(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		_verein(d, cid)

static func _verein(d: Dictionary, cid: String) -> void:
	var liste: Array = paare(d, cid)
	var kader: Array = d["vereine"][cid]["kader"]
	for i in range(liste.size() - 1, -1, -1):
		var paar: Dictionary = liste[i]
		# Wer den Verein verlassen hat, kann niemanden mehr anleiten
		if not kader.has(str(paar["mentor"])) or not kader.has(str(paar["schueler"])):
			liste.remove_at(i)
			continue
		_wirkung(d, cid, paar)

static func _wirkung(d: Dictionary, cid: String, paar: Dictionary) -> void:
	var m: Dictionary = d["spieler"][str(paar["mentor"])]
	var s: Dictionary = d["spieler"][str(paar["schueler"])]
	var staerke: float = eignung(d, str(paar["mentor"]), str(paar["schueler"])) / 100.0 * reife(d, paar)
	if staerke <= 0.0:
		return
	# Verletzte oder abwesende Paten lehren nicht
	if not (m["verletzung"] as Dictionary).is_empty() or bool(m.get("bei_nationalmannschaft", false)):
		staerke *= 0.35

	# Fachlich: der Schüler wächst in den Lehrattributen
	var potenzial: float = float(s["potenzial"])
	if Spielerfabrik.gesamt(s) < potenzial:
		var a: String = str(Namen.waehle(LEHRATTRIBUTE))
		if (s["attr"] as Dictionary).has(a):
			s["attr"][a] = clampf(float(s["attr"][a]) + 0.045 * staerke * Namen.bereich(0.6, 1.5), 1.0, 20.0)
			Spielerfabrik.staerke_verwerfen(s)
	# Menschlich: der Charakter zieht in Richtung des Paten
	var sc: Dictionary = s["charakter"]
	var mc: Dictionary = m["charakter"]
	for k in UEBERTRAGUNG:
		var ziel: float = float(mc.get(k, 12.0))
		sc[k] = clampf(lerpf(float(sc.get(k, 12.0)), ziel, 0.016 * staerke), 1.0, 20.0)
	# Der Schützling fühlt sich gesehen, der Pate gebraucht
	s["moral"] = clampf(float(s["moral"]) + 0.9 * staerke, 5.0, 100.0)
	s["unzufriedenheit"] = maxf(float(s.get("unzufriedenheit", 0.0)) - 0.7 * staerke, 0.0)
	s["kenntnis"] = clampf(float(s["kenntnis"]) + 0.6 * staerke, 0.0, 100.0)
	m["moral"] = clampf(float(m["moral"]) + 0.35 * staerke, 5.0, 100.0)

	var vorher: float = float(paar["fortschritt"])
	paar["fortschritt"] = vorher + staerke
	# Meilensteine melden — sonst bleibt das System unsichtbar
	for schwelle in [6.0, 16.0, 30.0]:
		if vorher < schwelle and float(paar["fortschritt"]) >= schwelle and cid == Welt.mein_verein_id:
			Welt.nachricht({
				"typ": "kabine",
				"betreff": "Patenschaft: %s und %s" % [Spielerfabrik.kurz_name(m), Spielerfabrik.kurz_name(s)],
				"text": _meilenstein(m, s, schwelle),
			})

static func _meilenstein(m: Dictionary, s: Dictionary, schwelle: float) -> String:
	if schwelle <= 6.0:
		return "%s hat %s in den letzten Wochen kaum von der Seite gelassen. Der Junge hört zu." % [
			Spielerfabrik.kurz_name(m), Spielerfabrik.kurz_name(s)]
	if schwelle <= 16.0:
		return "%s trifft auf dem Feld inzwischen Entscheidungen, die man von %s kennt." % [
			Spielerfabrik.kurz_name(s), Spielerfabrik.kurz_name(m)]
	return "In der Kabine sagen sie, %s sei ein kleiner %s geworden — im Guten wie im Schlechten." % [
		Spielerfabrik.kurz_name(s), Spielerfabrik.kurz_name(m)]

## Kurzbeschreibung eines Paares für die Oberfläche.
static func beschreibung(d: Dictionary, paar: Dictionary) -> String:
	var tage: int = int(d["tag"]) - int(paar["seit"])
	var r: float = reife(d, paar) * 100.0
	return "seit %d Tagen · eingespielt zu %d %%" % [tage, int(r)]

## Setzt für einen Computerverein sinnvolle Patenschaften.
static func automatisch(d: Dictionary, cid: String) -> void:
	var liste: Array = paare(d, cid)
	if liste.size() >= HOECHSTZAHL:
		return
	var schueler: Array = kandidaten_schueler(d, cid)
	if schueler.is_empty():
		return
	var jung: String = str(schueler[0])
	var bester := ""
	var bw := 0.0
	for mid in kandidaten_mentor(d, cid):
		var w: float = eignung(d, str(mid), jung)
		if w > bw:
			bw = w
			bester = str(mid)
	if bester != "" and bw >= 45.0:
		anlegen(d, cid, bester, jung)
