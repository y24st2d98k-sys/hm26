class_name Echtdaten
extends RefCounted
## Lädt die echten Liga- und Kaderdaten aus dem Ordner "daten/".
##
## Grundgedanke: Alles, was die Wirklichkeit vorgibt, steht in JSON-Dateien und
## nicht im Code. Was dort fehlt, erfindet der Weltgenerator — dadurch ist die
## Welt immer vollständig bespielbar, egal wie lückenhaft der Datensatz ist.
## Wer die Daten korrigieren oder erweitern will, bearbeitet nur die JSON-Dateien.

const PFAD_LIGEN := "res://daten/ligen.json"
const PFAD_KADER := "res://daten/kader.json"

static var _ligen: Dictionary = {}
static var _kader: Dictionary = {}
static var _geladen: bool = false

static func laden() -> void:
	if _geladen:
		return
	_geladen = true
	_ligen = _lies(PFAD_LIGEN)
	_kader = _lies(PFAD_KADER)

static func _lies(pfad: String) -> Dictionary:
	if not FileAccess.file_exists(pfad):
		push_warning("Datensatz fehlt: %s — es wird eine erfundene Welt erzeugt." % pfad)
		return {}
	var f := FileAccess.open(pfad, FileAccess.READ)
	if f == null:
		return {}
	var roh := f.get_as_text()
	f.close()
	var erg: Variant = JSON.parse_string(roh)
	if typeof(erg) != TYPE_DICTIONARY:
		push_warning("Datensatz unlesbar: %s" % pfad)
		return {}
	return erg

## Steht ein brauchbarer Ligadatensatz zur Verfügung?
static func verfuegbar() -> bool:
	laden()
	return not (_ligen.get("nationen", []) as Array).is_empty()

static func stand() -> String:
	laden()
	return str(_ligen.get("stand", "unbekannt"))

static func hinweis() -> String:
	laden()
	return str(_ligen.get("hinweis", ""))

static func nationen() -> Array:
	laden()
	return _ligen.get("nationen", [])

## Echte Spieler eines Vereins (leer, wenn keine hinterlegt sind).
static func kader_fuer(vereinsname: String) -> Array:
	laden()
	return (_kader.get("kader", {}) as Dictionary).get(vereinsname, [])

static func kader_stand() -> String:
	laden()
	return str(_kader.get("stand", "unbekannt"))

## Zählt, wie viele Vereine überhaupt echte Spieler hinterlegt haben.
static func vereine_mit_kader() -> int:
	laden()
	return (_kader.get("kader", {}) as Dictionary).size()

static func echte_spieler_gesamt() -> int:
	laden()
	var summe := 0
	for liste in (_kader.get("kader", {}) as Dictionary).values():
		summe += (liste as Array).size()
	return summe

## Wie vollständig ist die Welt mit echten Daten gefüllt?
## Liefert je Liga: Vereine gesamt, davon echt, Spieler gesamt, davon echt.
static func abdeckung(d: Dictionary) -> Array:
	var bericht: Array = []
	for lid in d.get("ligen", {}).keys():
		var liga: Dictionary = d["ligen"][lid]
		var vereine_echt := 0
		var spieler_gesamt := 0
		var spieler_echt := 0
		for cid in liga["vereine"]:
			var v: Dictionary = d["vereine"][cid]
			if bool(v.get("echt", false)):
				vereine_echt += 1
			for sid in v["kader"]:
				spieler_gesamt += 1
				if bool(d["spieler"][sid].get("echt", false)):
					spieler_echt += 1
		bericht.append({
			"liga": str(liga["name"]),
			"nation": str(liga["nation"]),
			"vereine": (liga["vereine"] as Array).size(),
			"vereine_echt": vereine_echt,
			"spieler": spieler_gesamt,
			"spieler_echt": spieler_echt,
		})
	bericht.sort_custom(func(a, b): return str(a["liga"]) < str(b["liga"]))
	return bericht
