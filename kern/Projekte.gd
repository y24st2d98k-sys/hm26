class_name Projekte
extends RefCounted
## Die Spieler, für die der Trainer persönlich geradesteht.
##
## Ein Manager-Spiel hält einen nicht durch Termine, sondern durch eine
## unaufgelöste Wette: du hast etwas geglaubt und gehandelt, und du weißt noch
## nicht, ob es richtig war. Genau das fehlte. Das Spiel rechnete Entwicklung
## längst — nur hatte niemand darauf gesetzt.
##
## Ein Projekt ist diese Wette. Höchstens drei, weil Aufmerksamkeit die
## knappste Ressource eines Trainers ist. Wer eines annimmt, bekommt einen
## kleinen Entwicklungsvorteil und dafür einen Faden im Büro, der von da an
## mitläuft: seit wann, wie viele Spiele, welche Note, wie viel Stärke.
##
## Der Vorteil ist bewusst klein. Er soll den Ausgang nicht kaufen, sondern
## bezeugen, dass man sich gekümmert hat — und wenn es schiefgeht, soll es
## auch schiefgehen dürfen.

const HOECHSTENS := 3
## Wie viel schneller ein Schützling lernt. Zehn Prozent sind über zwei Jahre
## etwa ein Stärkepunkt — spürbar, aber keine Abkürzung.
const VORTEIL := 1.10
## Älter als das nimmt niemand mehr als Projekt an.
const HOECHSTALTER := 24

static func liste(d: Dictionary, cid: String) -> Array:
	if d.is_empty() or cid == "" or not (d.get("vereine", {}) as Dictionary).has(cid):
		return []
	return (d["vereine"][cid].get("projekte", []) as Array)

static func ist_projekt(d: Dictionary, cid: String, sid: String) -> bool:
	for e in liste(d, cid):
		if str((e as Dictionary)["spieler"]) == sid:
			return true
	return false

## Darf dieser Spieler ein Projekt werden — und wenn nicht, warum?
static func moeglich(d: Dictionary, cid: String, sid: String) -> Dictionary:
	var sp: Dictionary = (d.get("spieler", {}) as Dictionary).get(sid, {})
	if sp.is_empty() or str(sp.get("verein", "")) != cid:
		return {"ok": false, "grund": "Er spielt nicht für Sie."}
	if ist_projekt(d, cid, sid):
		return {"ok": false, "grund": "Er ist bereits Ihr Projekt."}
	if int(sp["alter"]) > HOECHSTALTER:
		return {"ok": false, "grund": "Mit %d Jahren ist er kein Projekt mehr, sondern ein fertiger Spieler." % int(sp["alter"])}
	if liste(d, cid).size() >= HOECHSTENS:
		return {"ok": false, "grund": "Drei Projekte sind genug. Mehr Aufmerksamkeit hat niemand."}
	return {"ok": true, "grund": "Sie nehmen sich seiner an."}

## Annehmen. Der Ausgangsstand wird festgehalten — ohne ihn gäbe es später
## nichts zu vergleichen.
static func annehmen(d: Dictionary, cid: String, sid: String) -> Dictionary:
	var erlaubt := moeglich(d, cid, sid)
	if not bool(erlaubt["ok"]):
		return erlaubt
	var sp: Dictionary = d["spieler"][sid]
	var v: Dictionary = d["vereine"][cid]
	if not v.has("projekte"):
		v["projekte"] = []
	(v["projekte"] as Array).append({
		"spieler": sid,
		"seit_tag": int(d.get("tag", 0)),
		"start_staerke": Spielerfabrik.gesamt(sp),
		"start_potenzial": float(sp["potenzial"]),
		"start_wert": float(sp["wert"]),
		"start_spiele": int(sp["stats"]["karriere"]["spiele"]),
		"start_tore": int(sp["stats"]["karriere"]["tore"]),
	})
	return {"ok": true, "grund": "%s ist jetzt Ihr Projekt." % Spielerfabrik.kurz_name(sp)}

static func aufgeben(d: Dictionary, cid: String, sid: String) -> void:
	var v: Dictionary = d["vereine"].get(cid, {})
	if v.is_empty() or not v.has("projekte"):
		return
	var behalten: Array = []
	for e in (v["projekte"] as Array):
		if str((e as Dictionary)["spieler"]) != sid:
			behalten.append(e)
	v["projekte"] = behalten

## Wie es steht. [{spieler, name, tage, staerke_delta, potenzial_delta,
## wert_delta, spiele, tore, note, urteil}]
static func stand(d: Dictionary, cid: String) -> Array:
	var aus: Array = []
	for e in liste(d, cid):
		var eintrag: Dictionary = e
		var sid: String = str(eintrag["spieler"])
		var sp: Dictionary = (d["spieler"] as Dictionary).get(sid, {})
		if sp.is_empty():
			continue
		var karriere: Dictionary = sp["stats"]["karriere"]
		var spiele: int = int(karriere["spiele"]) - int(eintrag.get("start_spiele", 0))
		var staerke: float = Spielerfabrik.gesamt(sp) - float(eintrag["start_staerke"])
		aus.append({
			"spieler": sid,
			"fort": str(sp.get("verein", "")) != cid,
			"tage": int(d.get("tag", 0)) - int(eintrag["seit_tag"]),
			"staerke": staerke,
			"potenzial": float(sp["potenzial"]) - float(eintrag.get("start_potenzial", 0.0)),
			"wert": float(sp["wert"]) - float(eintrag.get("start_wert", 0.0)),
			"spiele": spiele,
			"tore": int(karriere["tore"]) - int(eintrag.get("start_tore", 0)),
			"note": Spielerfabrik.note(sp),
			"urteil": _urteil(staerke, spiele),
		})
	return aus

## Ein Satz zum Stand. Er ist absichtlich zurückhaltend: eine Wette, die noch
## läuft, soll sich nicht wie ein Ergebnis lesen.
static func _urteil(staerke: float, spiele: int) -> String:
	if spiele < 5:
		return "Zu früh für ein Urteil — er braucht Spiele."
	if staerke >= 4.0:
		return "Der Weg stimmt. Das ist Ihre Arbeit."
	if staerke >= 1.5:
		return "Es geht voran, langsam."
	if staerke >= -0.5:
		return "Steht still. Mehr Einsatzzeit oder ein anderes Sonderprogramm?"
	return "Er fällt zurück. Vielleicht war es der falsche Junge — oder die falsche Rolle."

## Der Entwicklungsvorteil eines Schützlings.
static func vorteil(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = (d.get("spieler", {}) as Dictionary).get(sid, {})
	if sp.is_empty():
		return 1.0
	return VORTEIL if ist_projekt(d, str(sp.get("verein", "")), sid) else 1.0
