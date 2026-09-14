extends Node
## Wie alt wird man in diesem Spiel, und was ist man dann noch wert?
##
## Zwei Fragen: taugen alte Spieler noch etwas, oder faellt man mit 33 aus dem
## Kader — und bewegt sich das Potenzial junger Spieler ueberhaupt, oder steht
## am ersten Tag fest, wie weit einer kommt.

const JAHRE := 5

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	Welt.neues_spiel(_erster_verein(), {"vorname": "Test", "nachname": "Trainer",
		"hintergrund": "taktiker"}, 4711)
	var d := Welt.daten

	var vorher := {}
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if int(sp["alter"]) <= 21:
			vorher[sid] = {"potenzial": float(sp["potenzial"]), "staerke": Spielerfabrik.gesamt(sp),
				"alter": int(sp["alter"])}

	_bericht(d, "Ausgangslage")

	var tage := 0
	while tage < JAHRE * 365:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		tage += 1
	_log("")
	_bericht(d, "Nach %d Jahren (%s)" % [JAHRE, Welt.datum_text()])

	_log("")
	_log("— Bewegt sich das Potenzial? —")
	var hoch := 0
	var runter := 0
	var gleich := 0
	var noch_da := 0
	for sid in vorher.keys():
		if not (d["spieler"] as Dictionary).has(sid):
			continue
		noch_da += 1
		var jetzt: float = float(d["spieler"][sid]["potenzial"])
		var alt: float = float(vorher[sid]["potenzial"])
		if jetzt > alt + 0.5:
			hoch += 1
		elif jetzt < alt - 0.5:
			runter += 1
		else:
			gleich += 1
	_log("   %d von %d damals hoechstens 21-Jaehrigen sind noch da." % [noch_da, vorher.size()])
	_log("   Potenzial gestiegen: %d, gefallen: %d, unveraendert: %d" % [hoch, runter, gleich])

func _bericht(d: Dictionary, titel: String) -> void:
	_log("— %s —" % titel)
	var nach_alter := {}
	var im_kader := {}
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		if str(d["ligen"][v["liga"]].get("kurz", "")) != "HBL":
			continue
		for sid in v["kader"]:
			var sp: Dictionary = d["spieler"][sid]
			var a: int = int(sp["alter"])
			var eimer: int = clampi(a, 18, 40)
			if not nach_alter.has(eimer):
				nach_alter[eimer] = []
			(nach_alter[eimer] as Array).append(Spielerfabrik.gesamt(sp))
			im_kader[eimer] = int(im_kader.get(eimer, 0)) + 1
	var alter_liste: Array = nach_alter.keys()
	alter_liste.sort()
	_log("   %5s %8s %8s %8s" % ["Alter", "Spieler", "Schnitt", "Bester"])
	for a in alter_liste:
		var werte: Array = nach_alter[a]
		werte.sort()
		var summe := 0.0
		for w in werte:
			summe += float(w)
		_log("   %5d %8d %8.1f %8.1f" % [int(a), werte.size(), summe / float(werte.size()),
			float(werte[werte.size() - 1])])

func _erster_verein() -> String:
	var d := Weltgenerator.erzeuge(2026, 4711)
	return str(d["ligen"]["l_de1"]["vereine"][0])
