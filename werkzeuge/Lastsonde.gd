extends Node
## Kostet hohe Trainingsintensität etwas — und bringt sie etwas?
##
## Der Trainer stellt eine Zahl von null bis hundert ein, und das Spiel
## verspricht ihm einen Tausch: mehr Intensität bedeutet schnellere
## Entwicklung, aber mehr Last und mehr Verletzungen. Ob dieser Tausch
## existiert, stand nie fest. Die Entscheidungssonde hat für sorgfältige und
## für rücksichtslose Arbeit genau dieselbe Zahl an Verletzten gemessen —
## 1,4 zu 1,4 —, und das wäre ein leerer Hebel.
##
## Diese Sonde fährt dieselbe Welt mit fünf Intensitäten und schreibt auf, was
## jede kostet und was sie bringt.
##
##     godot --headless res://werkzeuge/Lastsonde.tscn -- [tage]

const SAAT := 4411
const STUFEN := [30, 50, 65, 80, 100]

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var tage: int = int(args[0]) if args.size() > 0 else 200
	_log("")
	_log("=== Was Trainingsintensität kostet und bringt (%d Tage, ganze Liga) ===" % tage)
	_log("")
	# Der Kaderschnitt ist die falsche Nutzenspalte, und das war beim ersten
	# Lauf mein Fehler: er mischt wachsende Junge mit abbauenden Alten und
	# bewegte sich zwischen Intensität 30 und 100 um 0,30 Punkte. Die
	# Entscheidungssonde hatte das schon gezeigt — beim Kader 0,37, bei den
	# unter 23-Jährigen 2,54. Gemessen wird deshalb beides.
	_log("%-12s %8s %9s %11s %9s %9s %9s" % ["Intensität", "Last Ø",
		"Verletzt", "Ausfalltage", "Kader", "u23", "beste u23"])
	_log("%-12s %8s %9s %11s %9s %9s %9s" % ["", "", "Ø je Tag", "gesamt",
		"Zuwachs", "Zuwachs", "Zuwachs"])
	var reihen: Array = []
	for stufe in STUFEN:
		reihen.append(_lauf(int(stufe), tage))
	for r in reihen:
		var rd: Dictionary = r
		_log("%-12d %8.1f %9.2f %11d %+9.2f %+9.2f %+9.2f" % [int(rd["stufe"]),
			float(rd["last"]), float(rd["verletzt"]),
			int(rd["ausfalltage"]), float(rd["zuwachs"]),
			float(rd["jung"]), float(rd["bester"])])
	_log("")
	var leicht: Dictionary = reihen[0]
	var hart: Dictionary = reihen[STUFEN.size() - 1]
	_log("Von Intensität %d auf %d: %+.2f Punkte im Kader, %+.2f bei den u23, %+.2f beim besten — und %+d Ausfalltage." % [
		int(leicht["stufe"]), int(hart["stufe"]),
		float(hart["zuwachs"]) - float(leicht["zuwachs"]),
		float(hart["jung"]) - float(leicht["jung"]),
		float(hart["bester"]) - float(leicht["bester"]),
		int(hart["ausfalltage"]) - int(leicht["ausfalltage"])])
	_log("")
	_log("Ein Hebel ist nur dann einer, wenn beide Spalten sich bewegen.")
	get_tree().quit()

## Ein Lauf: dieselbe Welt, dieselbe Saat, eine Intensität für die ganze
## oberste Liga.
##
## Gemessen wurde zuerst nur der eigene Verein, und das war zu wenig: zwei
## Läufe mit denselben Stufen gaben 726 zu 1534 Ausfalltage und 1519 zu 1047 —
## entgegengesetzte Vorzeichen. Achtzehn Mannschaften statt einer kosten keine
## zusätzliche Rechenzeit, weil die Liga ohnehin mitgerechnet wird.
func _lauf(stufe: int, tage: int) -> Dictionary:
	var vorschau := Weltgenerator.erzeuge(2026, SAAT)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Last", "nachname": "Sonde"}, SAAT)
	var d: Dictionary = Welt.daten
	var vereine: Array = (d["ligen"]["l_de1"]["vereine"] as Array).duplicate()

	var vorher := {}
	var jung := {}
	for c in vereine:
		for sid in (d["vereine"][str(c)]["kader"] as Array):
			vorher[str(sid)] = Spielerfabrik.gesamt(d["spieler"][str(sid)])
			jung[str(sid)] = int(d["spieler"][str(sid)]["alter"]) <= 23
		var p: Dictionary = Training.plan(d, str(c))
		p["intensitaet"] = stufe
		p["schwerpunkt"] = "ausgeglichen"
		p["regeneration_zuteilung"] = {}

	var last_summe := 0.0
	var last_tage := 0
	var last_max := 0.0
	var verletzt_summe := 0.0
	var ausfalltage := 0
	var trainingsverletzungen := 0
	var war_verletzt := {}

	for i in range(tage):
		# Die KI schreibt ihren Trainingsplan jede Woche neu. Ohne das
		# Nachsetzen messe man die Vorgabewerte und nicht die Stufe.
		for c2 in vereine:
			var p2: Dictionary = Training.plan(d, str(c2))
			p2["intensitaet"] = stufe
			p2["schwerpunkt"] = "ausgeglichen"
		var gespielt := false
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
			gespielt = true
		if Welt.mein_verein_id == "":
			break
		var summe := 0.0
		var koepfe := 0
		for c3 in vereine:
			for sid3 in (d["vereine"][str(c3)]["kader"] as Array):
				var sp: Dictionary = d["spieler"][str(sid3)]
				summe += float(sp["last"])
				koepfe += 1
				last_max = maxf(last_max, float(sp["last"]))
				var jetzt: bool = not (sp["verletzung"] as Dictionary).is_empty()
				if jetzt and not bool(war_verletzt.get(str(sid3), false)):
					ausfalltage += int((sp["verletzung"] as Dictionary).get("tage", 0))
					if not gespielt:
						trainingsverletzungen += 1
				war_verletzt[str(sid3)] = jetzt
			verletzt_summe += float(Medizin.lazarett(d, str(c3)).size())
		last_summe += summe / maxf(float(koepfe), 1.0)
		last_tage += 1

	var zuwachs := 0.0
	var anzahl := 0
	var jung_summe := 0.0
	var jung_anzahl := 0
	var bester := -99.0
	for c4 in vereine:
		for sid4 in (d["vereine"][str(c4)]["kader"] as Array):
			if not vorher.has(str(sid4)):
				continue
			var delta: float = Spielerfabrik.gesamt(d["spieler"][str(sid4)]) - float(vorher[str(sid4)])
			zuwachs += delta
			anzahl += 1
			# Wer beim Start unter 23 war — nicht heute, sonst wandert die Gruppe.
			if bool(jung.get(str(sid4), false)):
				jung_summe += delta
				jung_anzahl += 1
				bester = maxf(bester, delta)
	return {
		"stufe": stufe,
		"last": last_summe / maxf(float(last_tage), 1.0),
		"last_max": last_max,
		"verletzt": verletzt_summe / maxf(float(last_tage), 1.0) / maxf(float(vereine.size()), 1.0),
		"ausfalltage": ausfalltage,
		"trainingsverletzungen": trainingsverletzungen,
		"zuwachs": zuwachs / maxf(float(anzahl), 1.0),
		"jung": jung_summe / maxf(float(jung_anzahl), 1.0),
		"bester": bester if bester > -98.0 else 0.0,
	}
