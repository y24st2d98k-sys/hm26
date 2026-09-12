class_name Trikot
extends RefCounted
## Rückennummern.
##
## Jede Nummer gibt es in einem Kader nur einmal. Vergeben wird nach der
## Gewohnheit des Handballs: die Eins gehört dem Torwart, die Sieben dem
## Linksaußen, die Zehn dem Spielmacher. Wer eine Nummer schon trägt, behält
## sie beim Vereinswechsel — wenn sie im neuen Kader frei ist.

const HOECHSTE := 99

## Wunschnummern je Position, in absteigender Vorliebe.
const WUNSCH := {
	"TW": [1, 12, 16, 31, 30],
	"LA": [7, 24, 17, 14, 27],
	"RL": [3, 4, 23, 44, 15],
	"RM": [10, 8, 13, 18, 26],
	"RR": [5, 6, 21, 25, 29],
	"RA": [11, 22, 28, 20, 34],
	"KM": [9, 19, 2, 33, 32],
}

## Nummern, die Feldspieler nur im Notfall bekommen — sie gehören den Torhütern.
const TORWARTNUMMERN := [1, 12, 16, 31, 30]

## Alle im Kader vergebenen Nummern (Nummer -> Spieler-ID).
static func belegt(d: Dictionary, cid: String) -> Dictionary:
	var karte := {}
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"].get(sid, {})
		if sp.is_empty():
			continue
		var n: int = int(sp.get("nummer", 0))
		if n > 0 and not karte.has(n):
			karte[n] = sid
	return karte

## Freie Nummer für einen Spieler — erst der Positionswunsch, dann der Rest.
static func frei_fuer(d: Dictionary, cid: String, sp: Dictionary) -> int:
	var vergeben: Dictionary = belegt(d, cid)
	var ist_tw: bool = bool(sp.get("ist_torwart", false))
	var wunsch: Array = WUNSCH.get(str(sp.get("position", "RM")), WUNSCH["RM"])
	if ist_tw:
		wunsch = WUNSCH["TW"]
	for n in wunsch:
		if not vergeben.has(int(n)):
			return int(n)
	# Danach der Reihe nach — Torwartnummern bleiben für Feldspieler gesperrt,
	# solange es noch andere gibt.
	for durchgang in [false, true]:
		for n2 in range(2, HOECHSTE + 1):
			if vergeben.has(n2):
				continue
			if not durchgang and not ist_tw and TORWARTNUMMERN.has(n2):
				continue
			if not durchgang and ist_tw and not TORWARTNUMMERN.has(n2):
				continue
			return n2
	return 0

## Gibt einem Spieler eine Nummer, falls er keine gültige hat.
static func vergeben(d: Dictionary, cid: String, sid: String) -> int:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty():
		return 0
	var vergeben_karte: Dictionary = belegt(d, cid)
	var n: int = int(sp.get("nummer", 0))
	if n > 0 and str(vergeben_karte.get(n, sid)) == sid:
		return n
	sp["nummer"] = frei_fuer(d, cid, sp)
	return int(sp["nummer"])

## Sorgt dafür, dass jeder im Kader eine eindeutige Nummer trägt.
## Wird vor jedem Spieltag aufgerufen und heilt damit auch alte Spielstände.
static func kader_nummerieren(d: Dictionary, cid: String) -> void:
	var verein: Dictionary = d["vereine"].get(cid, {})
	if verein.is_empty():
		return
	var gesehen := {}
	var offen: Array = []
	for sid in verein["kader"]:
		var sp: Dictionary = d["spieler"].get(sid, {})
		if sp.is_empty():
			continue
		var n: int = int(sp.get("nummer", 0))
		if n <= 0 or n > HOECHSTE or gesehen.has(n):
			sp["nummer"] = 0
			offen.append(sid)
			continue
		gesehen[n] = sid
	for sid2 in offen:
		vergeben(d, cid, str(sid2))

## Manuelle Vergabe. Gibt zurück, ob es geklappt hat, und warum nicht.
static func setzen(d: Dictionary, cid: String, sid: String, nummer: int) -> Dictionary:
	if nummer < 1 or nummer > HOECHSTE:
		return {"ok": false, "grund": "Erlaubt sind Nummern von 1 bis %d." % HOECHSTE}
	var vergeben_karte: Dictionary = belegt(d, cid)
	if vergeben_karte.has(nummer) and str(vergeben_karte[nummer]) != sid:
		var anderer: Dictionary = d["spieler"][str(vergeben_karte[nummer])]
		return {"ok": false, "grund": "Die %d trägt bereits %s." % [nummer, Spielerfabrik.voller_name(anderer)]}
	d["spieler"][sid]["nummer"] = nummer
	return {"ok": true, "grund": "Nummer %d vergeben." % nummer}

## Zwei Spieler tauschen ihre Nummern.
static func tauschen(d: Dictionary, sid_a: String, sid_b: String) -> void:
	var a: int = int(d["spieler"][sid_a].get("nummer", 0))
	d["spieler"][sid_a]["nummer"] = int(d["spieler"][sid_b].get("nummer", 0))
	d["spieler"][sid_b]["nummer"] = a

static func text(sp: Dictionary) -> String:
	var n: int = int(sp.get("nummer", 0))
	return str(n) if n > 0 else "—"
