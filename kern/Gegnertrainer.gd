class_name Gegnertrainer
extends RefCounted
## Auf den anderen Bänken sitzt jetzt auch jemand.
##
## Bis hierher hatten die siebzehn anderen Vereine keinen Trainer. `daten`
## kannte genau einen, den des Menschen; alle übrigen Klubs waren eine Menge
## Wartungsroutinen mit unterschiedlichem Etat. Deshalb spielten sie alle
## gleich — und deshalb passierte in einer Liga nie etwas, das nicht aus einer
## Tabellenzeile ablesbar war.
##
## Ein Gegnertrainer ist kein zweites Spiel. Er ist ein Name, sechs Achsen und
## eine Laufbahn. Aber die sechs Achsen steuern, wie sein Verein aufstellt,
## trainiert und verteidigt — und damit wird aus siebzehn austauschbaren
## Gegnern eine Liga mit Gesichtern: einer, der seine Jugend spielen lässt,
## einer, der mauert, einer, der jeden Zweikampf sucht.

## Die Achsen sind dieselben wie beim Menschen (Trainerkarriere.ACHSEN) —
## schon damit man sie im Vorbericht nebeneinander lesen kann.
const ARCHETYPEN := [
	{"id": "techniker", "name": "Techniker",
		"achsen": {"tempo": 34, "bollwerk": 58, "jugend": 52, "wagemut": 38, "rotation": 46, "strenge": 40},
		"satz": "Lässt kontrolliert aufbauen und sucht den sicheren Abschluss."},
	{"id": "tempomacher", "name": "Tempomacher",
		"achsen": {"tempo": 84, "bollwerk": 36, "jugend": 60, "wagemut": 70, "rotation": 66, "strenge": 46},
		"satz": "Läuft jeden Ball an und sucht die zweite Welle."},
	{"id": "betonmischer", "name": "Abwehrfanatiker",
		"achsen": {"tempo": 32, "bollwerk": 88, "jugend": 34, "wagemut": 26, "rotation": 34, "strenge": 74},
		"satz": "Baut die Partie von hinten auf. Wer gegen ihn drei Tore macht, hat gut gespielt."},
	{"id": "jugendtrainer", "name": "Talentförderer",
		"achsen": {"tempo": 58, "bollwerk": 48, "jugend": 88, "wagemut": 60, "rotation": 74, "strenge": 38},
		"satz": "Stellt Achtzehnjährige auf und nimmt die Fehler in Kauf."},
	{"id": "hasardeur", "name": "Hasardeur",
		"achsen": {"tempo": 72, "bollwerk": 30, "jugend": 56, "wagemut": 86, "rotation": 52, "strenge": 60},
		"satz": "Geht ins Risiko, auch wenn es zweimal im Jahr schiefgeht."},
	{"id": "zuchtmeister", "name": "Zuchtmeister",
		"achsen": {"tempo": 50, "bollwerk": 70, "jugend": 30, "wagemut": 40, "rotation": 28, "strenge": 88},
		"satz": "Führt mit harter Hand und einer festen Sieben."},
	{"id": "verwalter", "name": "Verwalter",
		"achsen": {"tempo": 50, "bollwerk": 52, "jugend": 46, "wagemut": 48, "rotation": 50, "strenge": 50},
		"satz": "Macht wenig falsch und wenig anders."},
	{"id": "rotierer", "name": "Rotationsverfechter",
		"achsen": {"tempo": 62, "bollwerk": 50, "jugend": 66, "wagemut": 54, "rotation": 88, "strenge": 42},
		"satz": "Lässt den halben Kader spielen und hält alle bei Laune."},
]

## Wie weit die Achsen eines einzelnen Trainers vom Archetyp abweichen dürfen.
## Ohne diese Streuung gäbe es acht Trainer und siebzehn Vereine.
const STREUUNG := 9.0

## Sorgt dafür, dass jeder Verein außer dem des Menschen einen Trainer hat.
##
## Wird aus der Wochenlogik gerufen und nicht aus der Welterzeugung: so
## bekommen auch alte Spielstände ihre Trainer, ohne dass jemand etwas
## umwandeln muss.
static func sicherstellen(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		if bool(v.get("ist_mensch", false)):
			v.erase("trainer_ki")
			continue
		if (v.get("trainer_ki", {}) as Dictionary).is_empty():
			v["trainer_ki"] = erzeuge(d, cid)

## Ein neuer Trainer für einen Verein. Der Archetyp richtet sich lose nach
## dem Verein: ein reicher Klub holt selten einen Talentförderer, ein armer
## selten einen, der nur auf Erfahrung setzt.
static func erzeuge(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var ruf: float = float(v.get("ruf", 60.0))
	var moegliche: Array = []
	for a in ARCHETYPEN:
		var arch: Dictionary = a
		var gewicht := 3
		if str(arch["id"]) == "jugendtrainer" and ruf > 82.0:
			gewicht = 1
		if str(arch["id"]) == "zuchtmeister" and ruf < 68.0:
			gewicht = 5
		if str(arch["id"]) == "verwalter" and ruf > 85.0:
			gewicht = 1
		for i in gewicht:
			moegliche.append(arch)
	var archetyp: Dictionary = Namen.waehle(moegliche)
	var achsen := {}
	for achse in (archetyp["achsen"] as Dictionary).keys():
		achsen[achse] = clampf(float(archetyp["achsen"][achse])
			+ Namen.bereich(-STREUUNG, STREUUNG), 12.0, 94.0)
	var nation: String = str(v.get("nation", "de"))
	return {
		"vorname": Namen.vorname(nation),
		"nachname": Namen.nachname(nation),
		"nation": nation,
		"alter": Namen.wuerfel(36, 62),
		"archetyp": str(archetyp["id"]),
		"archetyp_name": str(archetyp["name"]),
		"satz": str(archetyp["satz"]),
		"achsen": achsen,
		"seit_saison": Welt.saison_index(),
		"spiele": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0,
		"stationen": 1,
	}

static func fuer(d: Dictionary, cid: String) -> Dictionary:
	return (d.get("vereine", {}) as Dictionary).get(cid, {}).get("trainer_ki", {})

static func voller_name(t: Dictionary) -> String:
	if t.is_empty():
		return ""
	return "%s %s" % [str(t.get("vorname", "")), str(t.get("nachname", ""))]

## Eine Achse als Anteil von 0 bis 1 — so rechnen die Stellen, die sie lesen.
static func achse(d: Dictionary, cid: String, name: String) -> float:
	var t := fuer(d, cid)
	if t.is_empty():
		return 0.5
	return clampf(float((t.get("achsen", {}) as Dictionary).get(name, 50.0)) / 100.0, 0.0, 1.0)

## Ein Satz über den Trainer für den Vorbericht.
static func beschreibung(d: Dictionary, cid: String) -> String:
	var t := fuer(d, cid)
	if t.is_empty():
		return ""
	var jahre: int = Welt.saison_index() - int(t.get("seit_saison", 0))
	var dauer := "im ersten Jahr" if jahre <= 0 else "seit %d Jahren" % (jahre + 1)
	return "%s, %d, %s. %s" % [voller_name(t), int(t.get("alter", 45)), dauer, str(t.get("satz", ""))]

## Die Bilanz eines Trainers nach einer Partie fortschreiben.
static func spiel_verbuchen(d: Dictionary, m: Dictionary) -> void:
	for seite in ["heim", "gast"]:
		var cid: String = str(m[seite])
		var t := fuer(d, cid)
		if t.is_empty():
			continue
		t["spiele"] = int(t.get("spiele", 0)) + 1
		var eigen: int = int(m["tore_heim"] if seite == "heim" else m["tore_gast"])
		var fremd: int = int(m["tore_gast"] if seite == "heim" else m["tore_heim"])
		if eigen > fremd:
			t["siege"] = int(t.get("siege", 0)) + 1
		elif eigen == fremd:
			t["unentschieden"] = int(t.get("unentschieden", 0)) + 1
		else:
			t["niederlagen"] = int(t.get("niederlagen", 0)) + 1

## Wird ein Trainer entlassen?
##
## Gemessen wird am Abstand zwischen Tabellenplatz und dem, was der Ruf des
## Vereins erwarten ließe. Wer mit dem drittbesten Kader Sechzehnter ist,
## fliegt; wer mit dem schlechtesten Vierzehnter ist, bleibt. Geprüft wird
## erst ab der zehnten Partie — vorher ist es Rauschen.
const ENTLASSUNGSSCHWELLE := 6.0
const FRUEHESTENS := 10

## Nur alle vier Wochen und nur in der eigenen Liga.
##
## Die erste Fassung lief jede Woche ueber alle Ligen und sortierte jede davon
## zweimal. Das hat den Kaltstarttest von zwei Minuten auf ueber sieben
## getrieben — eine Trainerentlassung ist kein Vorgang, der woechentliche
## Rechenzeit rechtfertigt. Ausserhalb der eigenen Liga sieht sie ohnehin
## niemand.
const PRUEFABSTAND := 28

static func entlassungen_pruefen(d: Dictionary) -> void:
	if int(d.get("tag", 0)) % PRUEFABSTAND != 0:
		return
	var eigen: Dictionary = (d.get("vereine", {}) as Dictionary).get(Welt.mein_verein_id, {})
	var eigene_liga: String = str(eigen.get("liga", ""))
	if eigene_liga == "":
		return
	for lid in [eigene_liga]:
		var liga: Dictionary = (d.get("ligen", {}) as Dictionary).get(lid, {})
		if liga.is_empty():
			continue
		var tabelle: Array = Spielplan.tabelle_sortiert(d, str(lid))
		if tabelle.size() < 6:
			continue
		# Die Erwartung: nach Ruf sortiert. Wer weit darunter steht, wackelt.
		var nach_ruf: Array = tabelle.duplicate()
		nach_ruf.sort_custom(func(a, b):
			return float(d["vereine"][str(a)]["ruf"]) > float(d["vereine"][str(b)]["ruf"]))
		for i in tabelle.size():
			var cid: String = str(tabelle[i])
			var v: Dictionary = d["vereine"][cid]
			if bool(v.get("ist_mensch", false)):
				continue
			var t := fuer(d, cid)
			if t.is_empty() or int(t.get("spiele", 0)) < FRUEHESTENS:
				continue
			var erwartet: int = nach_ruf.find(cid)
			if float(i - erwartet) < ENTLASSUNGSSCHWELLE:
				continue
			# Nicht jeder, der wackelt, fliegt auch. Sonst wechselt eine Liga
			# im Januar geschlossen die Bank.
			if Namen.zufall() > 0.22:
				continue
			_entlassen(d, cid, i + 1, erwartet + 1)

static func _entlassen(d: Dictionary, cid: String, platz: int, erwartet: int) -> void:
	var v: Dictionary = d["vereine"][cid]
	var alt := fuer(d, cid)
	v["trainer_ki"] = erzeuge(d, cid)
	var neu := fuer(d, cid)
	if cid == Welt.mein_verein_id:
		return
	Welt.nachricht({
		"typ": "medien",
		"betreff": "Trainerwechsel bei %s" % str(v["name"]),
		"text": "%s ist als Trainer von %s zurückgetreten — Platz %d, erwartet war Platz %d. Nachfolger wird %s. %s" % [
			voller_name(alt), str(v["name"]), platz, erwartet, voller_name(neu), str(neu.get("satz", ""))],
	})
