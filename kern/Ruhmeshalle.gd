class_name Ruhmeshalle
extends RefCounted
## Die Lebensleistung des Trainers.
##
## Rekorde der Vereine liegen in der Chronik, Ehrungen für Spieler im
## Auszeichnungswesen — nur für den, der das alles entschieden hat, gab es
## nichts. Die Karriereseite zeigte Bilanz und Stationen, aber nichts, worauf
## man hinarbeitet. Ein Sportmanager lebt über zwanzig Jahre von genau dieser
## Kurve: das hundertste Spiel, der erste Titel, die Serie, die nicht reißt.
##
## Zwei Teile, absichtlich getrennt:
##  * **Meilensteine** — feste Marken, die man erreicht und die dann stehen.
##    Sie kommen einmal, mit Datum und Verein, und verschwinden nie wieder.
##  * **Bestmarken** — laufende Rekorde, die überboten werden können: der
##    höchste Sieg, die längste Serie ohne Niederlage.

const MEILENSTEINE := [
	{"id": "spiele_50", "feld": "spiele", "wert": 50, "name": "50 Spiele als Cheftrainer",
		"text": "Ein halbes Hundert Partien an der Seitenlinie."},
	{"id": "spiele_100", "feld": "spiele", "wert": 100, "name": "100 Spiele als Cheftrainer",
		"text": "Die Marke, ab der niemand mehr von einem Anfänger spricht."},
	{"id": "spiele_250", "feld": "spiele", "wert": 250, "name": "250 Spiele als Cheftrainer",
		"text": "Ein Jahrzehnt Arbeit, in Partien gerechnet."},
	{"id": "spiele_500", "feld": "spiele", "wert": 500, "name": "500 Spiele als Cheftrainer",
		"text": "Eine Zahl, die in diesem Beruf kaum jemand erreicht."},
	{"id": "siege_25", "feld": "siege", "wert": 25, "name": "25 Siege",
		"text": "Die ersten fünfundzwanzig."},
	{"id": "siege_100", "feld": "siege", "wert": 100, "name": "100 Siege",
		"text": "Hundertmal ist die Rechnung aufgegangen."},
	{"id": "siege_300", "feld": "siege", "wert": 300, "name": "300 Siege",
		"text": "Eine Bilanz, die für sich spricht."},
	{"id": "tore_5000", "feld": "tore", "wert": 5000, "name": "5.000 Tore der eigenen Mannschaften",
		"text": "Fünftausend Treffer, geworfen von Mannschaften, die Sie aufgestellt haben."},
]

## Marken, die nicht an der Bilanz hängen, sondern an Ereignissen.
const EREIGNIS_MEILENSTEINE := {
	"erster_titel": {"name": "Der erste Titel", "text": "Der erste Titel als Cheftrainer."},
	"fuenfter_titel": {"name": "Fünf Titel", "text": "Fünf Titel in der Vitrine."},
	"zehnter_titel": {"name": "Zehn Titel", "text": "Zehn Titel — das ist eine Ära."},
	"zweite_station": {"name": "Der zweite Verein", "text": "Eine neue Aufgabe, ein neues Umfeld."},
	"nationaltrainer": {"name": "Nationaltrainer", "text": "Ein Verband hat Sie geholt."},
}

static func leer() -> Dictionary:
	return {
		"meilensteine": [],
		"bestmarken": {
			"hoechster_sieg": {}, "hoechste_niederlage": {},
			"serie": 0, "beste_serie": 0, "beste_serie_saison": -1,
		},
	}

static func halle(d: Dictionary) -> Dictionary:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return leer()
	if not t.has("ruhmeshalle") or (t["ruhmeshalle"] as Dictionary).is_empty():
		t["ruhmeshalle"] = leer()
	return t["ruhmeshalle"]

static func erreicht(d: Dictionary, id: String) -> bool:
	for m in (halle(d).get("meilensteine", []) as Array):
		if str((m as Dictionary)["id"]) == id:
			return true
	return false

## Trägt einen Meilenstein ein — einmal und nie wieder.
static func eintragen(d: Dictionary, id: String, name: String, text: String) -> void:
	if erreicht(d, id):
		return
	var t: Dictionary = d["trainer"]
	(halle(d)["meilensteine"] as Array).append({
		"id": id, "name": name, "text": text,
		"saison": Welt.saison_index(), "tag": int(d["tag"]),
		"verein": str(t.get("verein", "")),
	})
	Welt.nachricht({
		"typ": "karriere", "wichtig": true,
		"betreff": "Meilenstein: %s" % name,
		"text": "%s\n\nNachzulesen in Ihrer Ruhmeshalle auf der Karriereseite." % text,
	})

# --------------------------------------------------------------- Prüfung ---

## Nach jeder Partie: neue Marken eintragen, Bestmarken fortschreiben.
static func nach_spiel(d: Dictionary, m: Dictionary, cid: String) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty() or str(t.get("verein", "")) != cid:
		return
	var s: Dictionary = t["statistik"]
	for eintrag in MEILENSTEINE:
		var e: Dictionary = eintrag
		if int(s.get(str(e["feld"]), 0)) >= int(e["wert"]):
			eintragen(d, str(e["id"]), str(e["name"]), str(e["text"]))
	_bestmarken(d, m, cid)

static func _bestmarken(d: Dictionary, m: Dictionary, cid: String) -> void:
	var b: Dictionary = halle(d)["bestmarken"]
	var heim: bool = str(m["heim"]) == cid
	var eigene: int = int(m["tore_heim"]) if heim else int(m["tore_gast"])
	var fremde: int = int(m["tore_gast"]) if heim else int(m["tore_heim"])
	var gegner: String = str(m["gast"]) if heim else str(m["heim"])
	var abstand: int = eigene - fremde
	var beschreibung := {
		"gegner": gegner, "eigene": eigene, "fremde": fremde,
		"saison": Welt.saison_index(), "tag": int(d["tag"]),
	}
	var hoechster: Dictionary = b.get("hoechster_sieg", {})
	if abstand > 0 and (hoechster.is_empty()
			or abstand > int(hoechster["eigene"]) - int(hoechster["fremde"])):
		b["hoechster_sieg"] = beschreibung
	var tiefste: Dictionary = b.get("hoechste_niederlage", {})
	if abstand < 0 and (tiefste.is_empty()
			or abstand < int(tiefste["eigene"]) - int(tiefste["fremde"])):
		b["hoechste_niederlage"] = beschreibung
	# Die Serie ohne Niederlage. Sie reißt bei jeder Niederlage — auch bei
	# einer, die nach einem Trainerwechsel gar nicht mehr die eigene wäre;
	# das ist der Preis dafür, dass die Zahl einfach bleibt.
	if abstand >= 0:
		b["serie"] = int(b.get("serie", 0)) + 1
		if int(b["serie"]) > int(b.get("beste_serie", 0)):
			b["beste_serie"] = int(b["serie"])
			b["beste_serie_saison"] = Welt.saison_index()
	else:
		b["serie"] = 0

## Nach einem Titelgewinn.
static func nach_titel(d: Dictionary) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return
	var anzahl: int = (t.get("titel", []) as Array).size()
	if anzahl >= 1:
		_ereignis(d, "erster_titel")
	if anzahl >= 5:
		_ereignis(d, "fuenfter_titel")
	if anzahl >= 10:
		_ereignis(d, "zehnter_titel")

## Nach einem Vereinswechsel.
static func nach_wechsel(d: Dictionary) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return
	if (t.get("stationen", []) as Array).size() >= 2:
		_ereignis(d, "zweite_station")

static func nach_verbandsjob(d: Dictionary) -> void:
	_ereignis(d, "nationaltrainer")

static func _ereignis(d: Dictionary, id: String) -> void:
	var e: Dictionary = EREIGNIS_MEILENSTEINE.get(id, {})
	if e.is_empty():
		return
	eintragen(d, id, str(e["name"]), str(e["text"]))

# ---------------------------------------------------------------- Ansicht ---

## Die Lebensbilanz in Zahlen, fertig für die Oberfläche.
static func bilanz(d: Dictionary) -> Array:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return []
	var s: Dictionary = t["statistik"]
	var spiele: int = int(s.get("spiele", 0))
	var siege: int = int(s.get("siege", 0))
	var b: Dictionary = halle(d)["bestmarken"]
	var zeilen: Array = [
		{"name": "Spiele als Cheftrainer", "wert": str(spiele)},
		{"name": "Siege", "wert": str(siege)},
		{"name": "Siegquote", "wert": "%.1f %%" % (float(siege) / maxf(float(spiele), 1.0) * 100.0)},
		{"name": "Tore je Spiel", "wert": "%.1f" % (float(s.get("tore", 0)) / maxf(float(spiele), 1.0))},
		{"name": "Gegentore je Spiel", "wert": "%.1f" % (float(s.get("gegentore", 0)) / maxf(float(spiele), 1.0))},
		{"name": "Titel", "wert": str((t.get("titel", []) as Array).size())},
		{"name": "Stationen", "wert": str((t.get("stationen", []) as Array).size())},
		{"name": "Längste Serie ohne Niederlage", "wert": "%d Spiele" % int(b.get("beste_serie", 0))},
		{"name": "Aktuelle Serie", "wert": "%d Spiele" % int(b.get("serie", 0))},
	]
	var hs: Dictionary = b.get("hoechster_sieg", {})
	if not hs.is_empty():
		zeilen.append({"name": "Höchster Sieg",
			"wert": "%d:%d gegen %s" % [int(hs["eigene"]), int(hs["fremde"]),
				str((d["vereine"].get(str(hs["gegner"]), {}) as Dictionary).get("kurz", "?"))]})
	var hn: Dictionary = b.get("hoechste_niederlage", {})
	if not hn.is_empty():
		zeilen.append({"name": "Höchste Niederlage",
			"wert": "%d:%d gegen %s" % [int(hn["eigene"]), int(hn["fremde"]),
				str((d["vereine"].get(str(hn["gegner"]), {}) as Dictionary).get("kurz", "?"))]})
	return zeilen

## Alle Meilensteine, neueste zuerst.
static func meilensteine(d: Dictionary) -> Array:
	var liste: Array = (halle(d).get("meilensteine", []) as Array).duplicate()
	liste.reverse()
	return liste

## Was als Nächstes ansteht — die Marke, der man am nächsten ist.
##
## Ohne diese Zeile ist eine Ruhmeshalle ein Rückblick. Mit ihr ist sie ein
## Ziel, und das ist der Unterschied zwischen einer Vitrine und einer Karriere.
static func naechste_marke(d: Dictionary) -> Dictionary:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return {}
	var s: Dictionary = t["statistik"]
	var beste := {}
	var bester_anteil := -1.0
	for eintrag in MEILENSTEINE:
		var e: Dictionary = eintrag
		if erreicht(d, str(e["id"])):
			continue
		var ist: int = int(s.get(str(e["feld"]), 0))
		var anteil: float = float(ist) / maxf(float(e["wert"]), 1.0)
		if anteil > bester_anteil:
			bester_anteil = anteil
			beste = {"name": str(e["name"]), "ist": ist, "ziel": int(e["wert"]), "anteil": anteil}
	return beste
