extends Node
## Ändert die Arbeit des Trainers etwas — und wenn ja, wie viel?
##
## Ein Managerspiel lebt von der Überzeugung, dass die eigenen Entscheidungen
## den Unterschied machen. Das ist keine Geschmacksfrage, sondern eine
## messbare: dieselbe Welt, dieselbe Saat, verschiedene Trainingsarbeit —
## und danach dieselben Spieler nebeneinander.
##
## Gemessen wird nicht die Tabelle (die hängt an hundert Dingen), sondern was
## direkt in der Hand des Trainers liegt: wie sich der Kader entwickelt.

const SAAT := 7788
const TAGE := 700

## Die Spielweisen, die verglichen werden.
const WEISEN := [
	{"id": "gut", "name": "Gute Arbeit",
		"intensitaet": 62, "schwerpunkt": "ausgeglichen", "regeneration": true, "fokus": true,
		"beschreibung": "mittlere Intensität, Regeneration verteilt, Talente mit Sonderprogramm"},
	{"id": "standard", "name": "Wie es kommt",
		"intensitaet": 55, "schwerpunkt": "ausgeglichen", "regeneration": false, "fokus": false,
		"beschreibung": "Vorgabewerte, nichts angefasst"},
	{"id": "schlecht", "name": "Schlechte Arbeit",
		"intensitaet": 95, "schwerpunkt": "athletik", "regeneration": false, "fokus": false,
		"beschreibung": "Dauerschinden ohne Regeneration"},
]

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	_log("")
	_log("=== Was die Trainingsarbeit ausmacht (%d Tage, dieselbe Welt) ===" % TAGE)
	_log("")
	var ergebnisse: Array = []
	for w in WEISEN:
		ergebnisse.append(_lauf(w))
	_log("%-16s %9s %9s %9s %9s %9s" % ["Spielweise", "Kader Ø", "u23 Ø", "beste u23", "Verletzt", "Punkte"])
	for e in ergebnisse:
		var r: Dictionary = e
		_log("%-16s %+9.2f %+9.2f %+9.2f %9.1f %9d" % [str(r["name"]), float(r["kader"]),
			float(r["jung"]), float(r["bester"]), float(r["verletzt"]), int(r["punkte"])])
	_log("")
	for w2 in WEISEN:
		_log("   %-16s %s" % [str((w2 as Dictionary)["name"]), str((w2 as Dictionary)["beschreibung"])])
	_log("")
	var gut: Dictionary = ergebnisse[0]
	var schlecht: Dictionary = ergebnisse[2]
	_log("Unterschied zwischen guter und schlechter Arbeit: %.2f Punkte Kaderstärke, %.2f bei den Jungen." % [
		float(gut["kader"]) - float(schlecht["kader"]), float(gut["jung"]) - float(schlecht["jung"])])
	get_tree().quit()

func _lauf(weise: Dictionary) -> Dictionary:
	var vorschau := Weltgenerator.erzeuge(2026, SAAT)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Test", "nachname": "Trainer"}, SAAT)
	var d: Dictionary = Welt.daten
	var v: Dictionary = d["vereine"][cid]

	# Ausgangsstand festhalten.
	var vorher := {}
	for sid in (v["kader"] as Array):
		vorher[str(sid)] = Spielerfabrik.gesamt(d["spieler"][str(sid)])

	var p: Dictionary = Training.plan(d, cid)
	p["intensitaet"] = int(weise["intensitaet"])
	p["schwerpunkt"] = str(weise["schwerpunkt"])
	if bool(weise["fokus"]):
		for sid2 in (v["kader"] as Array):
			var sp: Dictionary = d["spieler"][str(sid2)]
			if int(sp["alter"]) <= 23:
				sp["trainingsfokus"] = "athletik" if int(sp["alter"]) <= 20 else "wurf"

	var verletzt_tage := 0.0
	for i in range(TAGE):
		if bool(weise["regeneration"]):
			_regeneration_verteilen(d, cid)
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		if Welt.mein_verein_id == "":
			break
		verletzt_tage += float(Medizin.lazarett(d, cid).size())

	# Nur die Spieler vergleichen, die noch da sind.
	var summe := 0.0
	var anzahl := 0
	var jung_summe := 0.0
	var jung_anzahl := 0
	var bester := -99.0
	for sid3 in (d["vereine"][cid]["kader"] as Array):
		var kennung: String = str(sid3)
		if not vorher.has(kennung):
			continue
		var sp2: Dictionary = d["spieler"][kennung]
		var delta: float = Spielerfabrik.gesamt(sp2) - float(vorher[kennung])
		summe += delta
		anzahl += 1
		# Alter beim Start: heute sind alle zwei Jahre aelter.
		if int(sp2["alter"]) <= 25:
			jung_summe += delta
			jung_anzahl += 1
			bester = maxf(bester, delta)
	var lid: String = str(d["vereine"][cid]["liga"])
	var zeile: Dictionary = (d["ligen"][lid]["tabelle"] as Dictionary).get(cid,
		Spielplan.leere_tabellenzeile())
	return {
		"name": str(weise["name"]),
		"kader": summe / maxf(float(anzahl), 1.0),
		"jung": jung_summe / maxf(float(jung_anzahl), 1.0),
		"bester": bester,
		"verletzt": verletzt_tage / float(TAGE),
		"punkte": int(zeile["punkte"]),
	}

## Die Regeneration an die am stärksten belasteten Spieler.
func _regeneration_verteilen(d: Dictionary, cid: String) -> void:
	var p: Dictionary = Training.plan(d, cid)
	var budget: int = Training.regenerationsbudget(d, cid)
	var kader: Array = (d["vereine"][cid]["kader"] as Array).duplicate()
	kader.sort_custom(func(a, b): return float(d["spieler"][str(a)]["last"]) > float(d["spieler"][str(b)]["last"]))
	var zuteilung := {}
	for i in range(mini(budget, kader.size())):
		if float(d["spieler"][str(kader[i])]["last"]) > 40.0:
			zuteilung[str(kader[i])] = 1
	p["regeneration_zuteilung"] = zuteilung
