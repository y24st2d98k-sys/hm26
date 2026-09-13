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

## Echte Spieler eines Vereins aus dem mitgelieferten Datensatz.
## Selbst gepflegte Kader liegen darueber — siehe Kaderpflege.kader().
static func kader_fuer(vereinsname: String) -> Array:
	laden()
	return (_kader.get("kader", {}) as Dictionary).get(vereinsname, [])

## Der komplette mitgelieferte Kaderdatensatz.
static func alle_kader() -> Dictionary:
	laden()
	return _kader.get("kader", {})

## Nach dem Bearbeiten der Daten neu einlesen.
static func neu_laden() -> void:
	_geladen = false
	laden()

static func kader_stand() -> String:
	laden()
	return str(_kader.get("stand", "unbekannt"))

## Ein Kennzeichen fuer beide Dateien zusammen. Aendert sich eine von beiden,
## erkennt der Spielstand beim Laden, dass er nachzuziehen ist.
static func datenstand() -> String:
	return "%s / %s" % [stand(), kader_stand()]

## Zählt, wie viele Vereine überhaupt echte Spieler hinterlegt haben.
static func vereine_mit_kader() -> int:
	laden()
	var namen := {}
	for n in (_kader.get("kader", {}) as Dictionary).keys():
		namen[n] = true
	for n2 in Kaderpflege.eigene().keys():
		namen[n2] = true
	return namen.size()

static func echte_spieler_gesamt() -> int:
	laden()
	var summe := 0
	var gesehen := {}
	for name in Kaderpflege.eigene().keys():
		summe += (Kaderpflege.eigene()[name] as Array).size()
		gesehen[name] = true
	for name2 in (_kader.get("kader", {}) as Dictionary).keys():
		if gesehen.has(name2):
			continue
		summe += ((_kader.get("kader", {}) as Dictionary)[name2] as Array).size()
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

# --------------------------------------------------------------- Abgleich ---
#
# Ein Spielstand laeuft ueber Jahre, der Datensatz wird weitergepflegt. Ohne
# eine Bruecke dazwischen erreicht jede Korrektur nur neue Karrieren: wer eine
# Stärke nachzieht oder ein Attribut ergaenzt, muesste alle Spielstaende
# wegwerfen. Der Abgleich schliesst das. Er laeuft beim Laden, wenn der
# Datenstand der Dateien nicht mehr der des Spielstands ist.
#
# Entscheidend ist, dass er nur nachzieht, was aus den Daten stammt, und
# nichts wegnimmt, was im Spiel entstanden ist. Deshalb merkt sich jeder echte
# Spieler in `datenspur`, mit welchen Angaben er angelegt wurde. Wird die
# Staerke im Datensatz von 78 auf 84 gehoben, verschiebt der Abgleich den
# Spieler um sechs Punkte — nicht auf 84. Ein Spieler, der sich in drei
# Saisons von 78 auf 82 entwickelt hat, steht danach bei 88 und nicht wieder
# bei seinem Ausgangswert.

## Alle Datensatzeintraege nach Namen. Doppelte Namen bleiben aussen vor: bei
## zwei "Magnus Grupe" liesse sich nicht entscheiden, wer gemeint ist.
static func _nach_namen() -> Dictionary:
	laden()
	var index := {}
	var doppelt := {}
	for verein in alle_kader().keys():
		for e in (alle_kader()[verein] as Array):
			var schluessel: String = "%s|%s" % [str(e.get("vorname", "")), str(e.get("nachname", ""))]
			if index.has(schluessel):
				doppelt[schluessel] = true
				continue
			index[schluessel] = e
	for k in doppelt.keys():
		index.erase(k)
	return index

## Gleicht einen laufenden Spielstand mit dem aktuellen Datensatz ab.
## Liefert einen Bericht: was sich geaendert hat und bei wem.
static func abgleich(d: Dictionary) -> Dictionary:
	var bericht := {"stand_alt": str(d.get("datenstand", "")), "stand_neu": datenstand(),
		"spieler": 0, "staerke": 0, "attribute": 0, "position": 0, "nummer": 0, "namen": []}
	if not bool(d.get("echte_welt", false)):
		return bericht
	var index := _nach_namen()
	if index.is_empty():
		return bericht
	for sid in d.get("spieler", {}).keys():
		var sp: Dictionary = d["spieler"][sid]
		if not bool(sp.get("echt", false)):
			continue
		var e: Dictionary = index.get("%s|%s" % [str(sp["vorname"]), str(sp["nachname"])], {})
		if e.is_empty():
			continue
		var spur: Dictionary = sp.get("datenspur", {})
		var geaendert := false

		# Staerke: die Aenderung im Datensatz wird verschoben, nicht gesetzt.
		var alt_ziel: float = float(spur.get("staerke", -1.0))
		var neu_ziel: float = float(e.get("staerke", -1.0))
		if alt_ziel >= 0.0 and neu_ziel >= 0.0 and absf(neu_ziel - alt_ziel) >= 0.5:
			var jetzt: float = Spielerfabrik.gesamt(sp)
			Spielerfabrik.auf_staerke_ziehen(sp, clampf(jetzt + (neu_ziel - alt_ziel), 20.0, 99.0))
			spur["staerke"] = neu_ziel
			bericht["staerke"] = int(bericht["staerke"]) + 1
			geaendert = true

		# Einzelattribute: hier gilt der Datensatz unmittelbar, denn wer einen
		# Wert von Hand setzt, meint genau diesen Wert.
		var neu_attr: Dictionary = e.get("attribute", {})
		var alt_attr: Dictionary = spur.get("attribute", {})
		for name in neu_attr.keys():
			if not (sp["attr"] as Dictionary).has(name):
				continue
			if alt_attr.has(name) and is_equal_approx(float(alt_attr[name]), float(neu_attr[name])):
				continue
			sp["attr"][name] = clampf(float(neu_attr[name]), 1.0, 20.0)
			Spielerfabrik.staerke_verwerfen(sp)
			bericht["attribute"] = int(bericht["attribute"]) + 1
			geaendert = true
		spur["attribute"] = neu_attr.duplicate()

		if bool(e.get("stammschuetze", false)) != bool(sp.get("stammschuetze", false)):
			sp["stammschuetze"] = bool(e.get("stammschuetze", false))
			geaendert = true

		var neu_pos: String = str(e.get("position", ""))
		if neu_pos != "" and neu_pos != str(sp["position"]) and Spielerfabrik.POSITIONEN.has(neu_pos):
			sp["position"] = neu_pos
			bericht["position"] = int(bericht["position"]) + 1
			geaendert = true

		var neu_nr: int = int(e.get("nummer", 0))
		if neu_nr > 0 and neu_nr != int(sp.get("nummer", 0)) and _nummer_frei(d, sp, neu_nr):
			sp["nummer"] = neu_nr
			bericht["nummer"] = int(bericht["nummer"]) + 1
			geaendert = true

		if geaendert:
			sp["datenspur"] = spur
			sp["wert"] = Spielerfabrik.marktwert(sp)
			bericht["spieler"] = int(bericht["spieler"]) + 1
			if (bericht["namen"] as Array).size() < 12:
				(bericht["namen"] as Array).append(Spielerfabrik.voller_name(sp))
	d["datenstand"] = datenstand()
	return bericht

## Traegt schon jemand im selben Verein diese Nummer?
static func _nummer_frei(d: Dictionary, sp: Dictionary, nummer: int) -> bool:
	var cid: String = str(sp.get("verein", ""))
	if cid == "" or not (d.get("vereine", {}) as Dictionary).has(cid):
		return true
	for sid in d["vereine"][cid]["kader"]:
		if int((d["spieler"][sid] as Dictionary).get("nummer", 0)) == nummer:
			return false
	return true
