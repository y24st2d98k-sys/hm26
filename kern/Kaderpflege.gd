class_name Kaderpflege
extends RefCounted
## Pflege der echten Kaderdaten aus dem Spiel heraus.
##
## Der mitgelieferte Datensatz in `daten/kader.json` deckt nur einen Teil der
## Vereine ab. Wer die echten Kader vollständig haben will, trägt sie hier ein —
## einzeln über den Datenbildschirm oder in einem Rutsch über CSV.
##
## Geschrieben wird nach `user://kader_eigen.json`. Diese Datei liegt außerhalb
## des Projekts und überlebt jede Aktualisierung des Spiels; beim Laden wird sie
## über den mitgelieferten Datensatz gelegt. Wer seine Arbeit ins Projekt
## übernehmen will, exportiert sie mit `in_projekt_schreiben()` nach
## `daten/kader.json`.

const EIGENE_DATEI := "user://kader_eigen.json"
const PROJEKTDATEI := "res://daten/kader.json"

const POSITIONEN := ["TW", "LA", "RL", "RM", "RR", "RA", "KM"]
const FELDER := ["vorname", "nachname", "position", "nation", "alter", "staerke"]
## Angaben ueber die CSV-Grundfelder hinaus. Sie kommen nicht aus der CSV,
## sondern aus dem Datenbildschirm oder aus daten/kader.json, und duerfen beim
## Normieren nicht verlorengehen.
const ZUSATZFELDER := ["nummer", "attribute", "stammschuetze", "bild"]

static var _eigene: Dictionary = {}
static var _geladen: bool = false

# ------------------------------------------------------------------ Laden ---

static func laden() -> void:
	if _geladen:
		return
	_geladen = true
	_eigene = {}
	if not FileAccess.file_exists(EIGENE_DATEI):
		return
	var f := FileAccess.open(EIGENE_DATEI, FileAccess.READ)
	if f == null:
		return
	var roh := f.get_as_text()
	f.close()
	var erg: Variant = JSON.parse_string(roh)
	if typeof(erg) == TYPE_DICTIONARY:
		_eigene = (erg as Dictionary).get("kader", {})

## Alle selbst gepflegten Kader (Vereinsname -> Liste).
static func eigene() -> Dictionary:
	laden()
	return _eigene

## Der wirksame Kader eines Vereins: eigene Angaben schlagen den Datensatz.
static func kader(vereinsname: String) -> Array:
	laden()
	if _eigene.has(vereinsname):
		return _eigene[vereinsname]
	return Echtdaten.kader_fuer(vereinsname)

static func ist_eigen(vereinsname: String) -> bool:
	laden()
	return _eigene.has(vereinsname)

# ---------------------------------------------------------------- Ändern ---

## Kader eines Vereins ersetzen. Eine leere Liste löscht die eigene Angabe,
## sodass wieder der mitgelieferte Datensatz gilt.
static func setzen(vereinsname: String, liste: Array) -> void:
	laden()
	if liste.is_empty():
		_eigene.erase(vereinsname)
	else:
		_eigene[vereinsname] = liste
	speichern()

static func speichern() -> bool:
	laden()
	var f := FileAccess.open(EIGENE_DATEI, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({
		"version": 1,
		"stand": Time.get_datetime_string_from_system(false, true),
		"hinweis": "Selbst gepflegte Kaderdaten. Überschreibt daten/kader.json je Verein.",
		"kader": _eigene,
	}, "\t"))
	f.close()
	Echtdaten.neu_laden()
	return true

## Alles zurücksetzen — es gilt wieder allein der mitgelieferte Datensatz.
static func alles_verwerfen() -> void:
	laden()
	_eigene = {}
	speichern()

## Eigene Arbeit in den Projektdatensatz übernehmen. Klappt nur, wenn das Spiel
## aus dem Projektordner läuft (also nicht aus einem exportierten Paket).
static func in_projekt_schreiben() -> Dictionary:
	laden()
	var zusammen: Dictionary = {}
	for name in Echtdaten.alle_kader().keys():
		zusammen[name] = Echtdaten.alle_kader()[name]
	for name2 in _eigene.keys():
		zusammen[name2] = _eigene[name2]
	var pfad := ProjectSettings.globalize_path(PROJEKTDATEI)
	var f := FileAccess.open(pfad, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "grund": "Konnte %s nicht schreiben. Läuft das Spiel aus einem exportierten Paket?" % pfad}
	var spieler := 0
	for liste in zusammen.values():
		spieler += (liste as Array).size()
	f.store_string(JSON.stringify({
		"version": 1,
		"stand": Time.get_datetime_string_from_system(false, true),
		"hinweis": "Echte Spieler je Verein. Alter und Stärke sind Schätzwerte für die Simulation.",
		"kader": zusammen,
	}, "\t"))
	f.close()
	return {"ok": true, "grund": "%d Spieler bei %d Vereinen nach %s geschrieben." % [
		spieler, zusammen.size(), PROJEKTDATEI]}

# ------------------------------------------------------------- Einzeleintrag ---

static func leerer_eintrag() -> Dictionary:
	return {"vorname": "", "nachname": "", "position": "RM", "nation": "de",
		"alter": 25, "staerke": 60}

## Prüft einen Eintrag und gibt eine Liste von Beanstandungen zurück (leer = gut).
static func pruefen(e: Dictionary) -> Array:
	var fehler: Array = []
	if str(e.get("nachname", "")).strip_edges() == "":
		fehler.append("Nachname fehlt")
	if not POSITIONEN.has(str(e.get("position", ""))):
		fehler.append("Position muss eine von %s sein" % ", ".join(POSITIONEN))
	var alter: int = int(e.get("alter", 0))
	if alter < 16 or alter > 44:
		fehler.append("Alter muss zwischen 16 und 44 liegen")
	var staerke: int = int(e.get("staerke", 0))
	if staerke < 20 or staerke > 99:
		fehler.append("Stärke muss zwischen 20 und 99 liegen")
	if not Namen.KULTUR_NAME.has(str(e.get("nation", ""))):
		fehler.append("Nation '%s' ist unbekannt" % str(e.get("nation", "")))
	return fehler

## Einen Eintrag in die erwartete Form bringen.
static func normieren(e: Dictionary) -> Dictionary:
	var n := {
		"vorname": str(e.get("vorname", "")).strip_edges(),
		"nachname": str(e.get("nachname", "")).strip_edges(),
		"position": str(e.get("position", "RM")).strip_edges().to_upper(),
		"nation": str(e.get("nation", "de")).strip_edges().to_lower(),
		"alter": clampi(int(e.get("alter", 25)), 16, 44),
		"staerke": clampi(int(e.get("staerke", 60)), 20, 99),
	}
	# Alles, was ueber die sechs Grundangaben hinausgeht, muss das Normieren
	# ueberleben. Sonst loescht ein Klick auf "Kader sichern" die Rueckennummer
	# und jedes von Hand gesetzte Attribut — genau die Arbeit also, die man
	# hier vorher gemacht hat.
	var nummer: int = clampi(int(e.get("nummer", 0)), 0, 99)
	if nummer > 0:
		n["nummer"] = nummer
	if bool(e.get("stammschuetze", false)) and n["position"] != "TW":
		n["stammschuetze"] = true
	if str(e.get("bild", "")).strip_edges() != "":
		n["bild"] = str(e["bild"]).strip_edges()
	var werte: Dictionary = e.get("attribute", {})
	var sauber := {}
	for name in werte.keys():
		if Spielerfabrik.ATTR_LABEL.has(str(name)):
			sauber[str(name)] = clampf(float(werte[name]), 1.0, 20.0)
	if not sauber.is_empty():
		n["attribute"] = sauber
	return n

# ----------------------------------------------------------------- CSV ---

## Zeilenformat: Vorname ; Nachname ; Position ; Nation ; Alter ; Stärke
## Trennzeichen darf Semikolon, Tabulator oder Komma sein. Eine Kopfzeile wird
## erkannt und übersprungen, Leerzeilen und Zeilen mit # werden ignoriert.
static func csv_einlesen(text: String) -> Dictionary:
	var eintraege: Array = []
	var meldungen: Array = []
	var nummer := 0
	for rohzeile in text.split("\n"):
		nummer += 1
		var zeile: String = str(rohzeile).strip_edges()
		if zeile == "" or zeile.begins_with("#"):
			continue
		var teile := _spalten(zeile)
		if teile.size() < 3:
			meldungen.append("Zeile %d: zu wenige Spalten — übersprungen." % nummer)
			continue
		# Kopfzeile erkennen
		if nummer <= 2 and str(teile[0]).to_lower() in ["vorname", "first", "name"]:
			continue
		var e := {
			"vorname": str(teile[0]),
			"nachname": str(teile[1]),
			"position": str(teile[2]),
			"nation": str(teile[3]) if teile.size() > 3 else "de",
			"alter": int(str(teile[4])) if teile.size() > 4 and str(teile[4]).is_valid_int() else 25,
			"staerke": int(str(teile[5])) if teile.size() > 5 and str(teile[5]).is_valid_int() else 60,
		}
		var normiert := normieren(e)
		var fehler := pruefen(normiert)
		if fehler.is_empty():
			eintraege.append(normiert)
			continue
		# Reparieren, was sich reparieren lässt, statt die Zeile wegzuwerfen
		if not POSITIONEN.has(normiert["position"]):
			normiert["position"] = "RM"
		if not Namen.KULTUR_NAME.has(str(normiert["nation"])):
			normiert["nation"] = "de"
		var rest := pruefen(normiert)
		if rest.is_empty():
			eintraege.append(normiert)
			meldungen.append("Zeile %d (%s): %s — ersetzt." % [nummer, normiert["nachname"], ", ".join(fehler)])
		else:
			meldungen.append("Zeile %d: %s — übersprungen." % [nummer, ", ".join(rest)])
	return {"eintraege": eintraege, "meldungen": meldungen}

static func _spalten(zeile: String) -> Array:
	for trenner in [";", "\t", ","]:
		if zeile.contains(trenner):
			var teile: Array = []
			for t in zeile.split(trenner):
				teile.append(str(t).strip_edges())
			return teile
	return [zeile]

static func csv_ausgeben(vereinsname: String) -> String:
	var zeilen: Array = ["# %s" % vereinsname, "Vorname;Nachname;Position;Nation;Alter;Staerke"]
	for e in kader(vereinsname):
		var eintrag: Dictionary = e
		zeilen.append("%s;%s;%s;%s;%d;%d" % [
			str(eintrag.get("vorname", "")), str(eintrag.get("nachname", "")),
			str(eintrag.get("position", "")), str(eintrag.get("nation", "")),
			int(eintrag.get("alter", 25)), int(eintrag.get("staerke", 60))])
	return "\n".join(zeilen)

# ------------------------------------------------------------- Übersicht ---

## Alle Vereine des Datensatzes mit Angabe, wie viele Spieler hinterlegt sind.
## Sortiert nach Nation und Liga, damit die Bundesliga oben steht.
static func vereinsliste() -> Array:
	var liste: Array = []
	for nation in Echtdaten.nationen():
		for liga in (nation as Dictionary).get("ligen", []):
			for verein in (liga as Dictionary).get("vereine", []):
				var name: String = str((verein as Dictionary).get("name", ""))
				if name == "":
					continue
				liste.append({
					"name": name,
					"kurz": str((verein as Dictionary).get("kurz", "")),
					"liga": str((liga as Dictionary).get("name", "")),
					"nation": str((nation as Dictionary).get("kuerzel", "")),
					"anzahl": kader(name).size(),
					"eigen": ist_eigen(name),
				})
	return liste

## Wie viele Spieler ein vollständiger Kader haben sollte.
const SOLL := 16

static func fortschritt() -> Dictionary:
	var vereine := vereinsliste()
	var voll := 0
	var spieler := 0
	for v in vereine:
		spieler += int((v as Dictionary)["anzahl"])
		if int((v as Dictionary)["anzahl"]) >= SOLL:
			voll += 1
	return {"vereine": vereine.size(), "voll": voll, "spieler": spieler}
