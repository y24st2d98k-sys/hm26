class_name Spielplanpflege
extends RefCounted
## Echte Ansetzungen aus dem Spiel heraus einspielen.
##
## Der mitgelieferte Datensatz in `daten/spielplan.json` enthält so viel, wie
## sich belegen ließ. Wer den vollständigen offiziellen Spielplan hat — als
## Export der Liga, aus einem Kalenderabo oder aus einer Tabelle —, fügt ihn
## hier als CSV ein.
##
## Geschrieben wird nach `user://spielplan_eigen.json`. Diese Datei liegt
## außerhalb des Projekts und überlebt jede Aktualisierung des Spiels; beim
## Laden wird sie über den mitgelieferten Datensatz gelegt.
##
## Wirksam wird ein Plan beim Anlegen einer neuen Karriere. Eine laufende
## Saison behält ihren Spielplan — eine Runde mitten im Oktober neu anzusetzen
## hieße, gespielte Partien zu verwerfen.

const EIGENE_DATEI := "user://spielplan_eigen.json"
const PROJEKTDATEI := "res://daten/spielplan.json"

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
		_eigene = (erg as Dictionary).get("spielplaene", {})

## Alle selbst gepflegten Spielpläne (Liganame -> Partienliste).
static func eigene() -> Dictionary:
	laden()
	return _eigene

## Der wirksame Plan einer Liga: eigene Angaben schlagen den Datensatz.
static func partien(liganame: String) -> Array:
	laden()
	if _eigene.has(liganame):
		return _eigene[liganame]
	return Echtdaten.spielplan_fuer(liganame)

static func ist_eigen(liganame: String) -> bool:
	laden()
	return _eigene.has(liganame)

# ---------------------------------------------------------------- Ändern ---

static func setzen(liganame: String, liste: Array) -> void:
	laden()
	if liste.is_empty():
		_eigene.erase(liganame)
	else:
		_eigene[liganame] = liste
	speichern()

static func speichern() -> bool:
	var f := FileAccess.open(EIGENE_DATEI, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "spielplaene": _eigene}, "  "))
	f.close()
	return true

static func alles_verwerfen() -> void:
	laden()
	_eigene = {}
	speichern()

# -------------------------------------------------------------------- CSV ---

## Zeilenformat: Spieltag ; Datum ; Zeit ; Heim ; Gast
##
## Zeit darf fehlen, Datum auch — gebraucht werden Spieltag, Heim und Gast.
## Trennzeichen darf Semikolon, Tabulator oder Komma sein. Eine Kopfzeile wird
## erkannt und übersprungen, Leerzeilen und Zeilen mit # werden ignoriert.
##
## Vereinsnamen müssen denen aus `ligen.json` entsprechen. Ein Name, den die
## Liga nicht kennt, wird gemeldet statt stillschweigend verworfen: ein Plan
## mit fehlenden Partien sähe echt aus und wäre es nicht.
static func csv_einlesen(text: String, bekannte_vereine: Array = []) -> Dictionary:
	var eintraege: Array = []
	var meldungen: Array = []
	var unbekannt := {}
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
		if nummer <= 2 and not str(teile[0]).strip_edges().is_valid_int():
			continue
		# Fünf Spalten: Spieltag, Datum, Zeit, Heim, Gast.
		# Drei Spalten: Spieltag, Heim, Gast.
		var spieltag_roh: String = str(teile[0]).strip_edges()
		var datum := ""
		var zeit := ""
		var heim := ""
		var gast := ""
		if teile.size() >= 5:
			datum = str(teile[1]).strip_edges()
			zeit = str(teile[2]).strip_edges()
			heim = str(teile[3]).strip_edges()
			gast = str(teile[4]).strip_edges()
		elif teile.size() == 4:
			datum = str(teile[1]).strip_edges()
			heim = str(teile[2]).strip_edges()
			gast = str(teile[3]).strip_edges()
		else:
			heim = str(teile[1]).strip_edges()
			gast = str(teile[2]).strip_edges()
		if not spieltag_roh.is_valid_int():
			meldungen.append("Zeile %d: „%s\" ist keine Spieltagsnummer." % [nummer, spieltag_roh])
			continue
		if heim == "" or gast == "" or heim == gast:
			meldungen.append("Zeile %d: Heim und Gast fehlen oder sind gleich." % nummer)
			continue
		if not bekannte_vereine.is_empty():
			if not bekannte_vereine.has(heim):
				unbekannt[heim] = true
			if not bekannte_vereine.has(gast):
				unbekannt[gast] = true
		eintraege.append({"spieltag": int(spieltag_roh), "datum": datum, "zeit": zeit,
			"heim": heim, "gast": gast})
	for name in unbekannt.keys():
		meldungen.append("Unbekannter Verein: „%s\" — Name muss dem in ligen.json entsprechen." % str(name))
	return {"eintraege": eintraege, "meldungen": meldungen,
		"unbekannt": not unbekannt.is_empty()}

static func _spalten(zeile: String) -> PackedStringArray:
	if zeile.contains(";"):
		return zeile.split(";")
	if zeile.contains("\t"):
		return zeile.split("\t")
	return zeile.split(",")

static func csv_ausgeben(liganame: String) -> String:
	var zeilen: Array = ["# Spieltag;Datum;Zeit;Heim;Gast"]
	for e in partien(liganame):
		zeilen.append("%d;%s;%s;%s;%s" % [int((e as Dictionary).get("spieltag", 0)),
			str((e as Dictionary).get("datum", "")), str((e as Dictionary).get("zeit", "")),
			str((e as Dictionary).get("heim", "")), str((e as Dictionary).get("gast", ""))])
	return "\n".join(zeilen)

# ------------------------------------------------------------------ Probe ---

## Sagt vorab, was aus diesem Plan wird: gilt er unverändert, wird er ergänzt,
## oder geht er nicht auf? Ohne diese Auskunft müsste man eine neue Karriere
## anlegen, um zu sehen, ob der Import etwas gebracht hat.
static func beurteilen(liste: Array, anzahl_vereine: int) -> String:
	if liste.is_empty():
		return "Kein Plan hinterlegt — die Saison wird ausgelost."
	var voll: int = anzahl_vereine * (anzahl_vereine - 1)
	var je_spieltag: int = int(anzahl_vereine / 2)
	if liste.size() >= voll:
		return "Vollständig (%d Partien). Der Plan gilt unverändert." % liste.size()
	var je_tag := {}
	for e in liste:
		var t: int = int((e as Dictionary).get("spieltag", 0))
		je_tag[t] = int(je_tag.get(t, 0)) + 1
	var ganze := 0
	for t2 in je_tag.keys():
		if int(je_tag[t2]) == je_spieltag:
			ganze += 1
	if ganze == 0:
		return "%d Partien, aber kein vollständiger Spieltag — so lässt sich nichts verankern, es wird ausgelost." % liste.size()
	return "%d Partien auf %d Spieltagen, davon %d vollständig. Diese stehen fest, der Rest wird ergänzt." % [
		liste.size(), je_tag.size(), ganze]
