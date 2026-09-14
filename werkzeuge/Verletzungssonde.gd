extends Node
## Wie oft, wie lange und woran verletzen sich die Spieler?
##
## Die Vorgaben stammen aus dem VBG-Sportreport, den der Konzeptbericht
## zitiert: fast drei Viertel aller Profis verletzen sich mindestens einmal je
## Spielzeit, im Schnitt fehlt ein Spieler rund 34 Tage. Das Sprunggelenk ist
## die haeufigste Verletzung (15 bis 19 Prozent), das Knie steht fuer 22
## Prozent der Verletzungen, aber fuer 43,1 Prozent aller Ausfalltage.

const JAHRE := 2

var _hbl := {}
var faelle := {}
var tage_region := {}
var spieler_tage := {}
var spieler_faelle := {}
var gesehen := {}
## Nur die Kader der Handball-Bundesliga. Der VBG-Sportreport zaehlt Profis,
## und die spielen dreissig Pflichtspiele und mehr — ein Zweitligatalent, das
## in der Reserverunde eingesetzt wird, gehoert nicht in dieselbe Rechnung.
var profi := {}

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	Welt.neues_spiel(_erster_verein(), {"vorname": "Test", "nachname": "Trainer",
		"hintergrund": "taktiker"}, 7301)
	var d := Welt.daten
	for cid in d["ligen"]["l_de1"]["vereine"]:
		_hbl[str(cid)] = true
	var offen := {}
	var tage := 0
	while tage < JAHRE * 365:
		for sid in d["spieler"].keys():
			var sp: Dictionary = d["spieler"][sid]
			if str(sp["verein"]) == "":
				continue
			gesehen[sid] = true
			if _hbl.has(str(sp["verein"])):
				profi[sid] = true
			var vl: Dictionary = sp["verletzung"]
			if vl.is_empty():
				offen.erase(sid)
				continue
			var kennung := "%s|%d" % [str(vl.get("art", "")), int(vl.get("seit_tag", 0))]
			if str(offen.get(sid, "")) == kennung:
				continue
			offen[sid] = kennung
			var region: String = str(vl.get("region", "unbekannt"))
			faelle[region] = int(faelle.get(region, 0)) + 1
			tage_region[region] = int(tage_region.get(region, 0)) + int(vl.get("tage", 0))
			spieler_tage[sid] = int(spieler_tage.get(sid, 0)) + int(vl.get("tage", 0))
			spieler_faelle[sid] = int(spieler_faelle.get(sid, 0)) + 1
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		tage += 1
	_bericht()
	get_tree().quit()

func _erster_verein() -> String:
	var d := Weltgenerator.erzeuge(2026, 7301)
	return str(d["ligen"]["l_de1"]["vereine"][0])

func _bericht() -> void:
	var n: float = float(gesehen.size())
	var jahre: float = float(JAHRE)
	var faelle_gesamt := 0
	var tage_gesamt := 0
	for r in faelle.keys():
		faelle_gesamt += int(faelle[r])
		tage_gesamt += int(tage_region[r])
	var betroffen := 0
	for sid in spieler_faelle.keys():
		if int(spieler_faelle[sid]) >= int(round(jahre)):
			betroffen += 1
	_log("")
	_log("=== Verletzungen, %d Spielzeiten, %d Spieler ===" % [JAHRE, int(n)])
	_log("")
	_log("Faelle je Spieler und Spielzeit: %5.2f" % (float(faelle_gesamt) / n / jahre))
	_log("Ausfalltage je Spieler/Spielzeit:%5.1f   (VBG: rund 34)" % (float(tage_gesamt) / n / jahre))
	_log("Mindestens einmal je Spielzeit:  %5.1f %%   (VBG: fast 75 %%)" % (
		_anteil_mit_einer_je_saison() * 100.0))
	_log("Mittlere Ausfallzeit je Fall:   %5.1f Tage" % (
		float(tage_gesamt) / maxf(float(faelle_gesamt), 1.0)))
	_log("")
	_log("Nur die %d Bundesligaspieler:" % profi.size())
	var p_faelle := 0
	var p_tage := 0
	for sid2 in profi.keys():
		p_faelle += int(spieler_faelle.get(sid2, 0))
		p_tage += int(spieler_tage.get(sid2, 0))
	var pn: float = maxf(float(profi.size()), 1.0)
	_log("  Faelle je Spieler/Spielzeit:  %5.2f" % (float(p_faelle) / pn / jahre))
	_log("  Ausfalltage je Spielzeit:     %5.1f   (VBG: rund 34)" % (float(p_tage) / pn / jahre))
	_log("  Mindestens einmal je Spielzeit:%5.1f %%   (VBG: fast 75 %%)" % (
		_anteil_mit_einer_je_saison(profi) * 100.0))
	_log("")
	_log("%-16s %8s %8s %8s %8s" % ["Region", "Faelle", "Anteil", "Tage", "Tageant."])
	var regionen: Array = faelle.keys()
	regionen.sort()
	for r in regionen:
		_log("%-16s %8d %7.1f %% %8d %7.1f %%" % [r, int(faelle[r]),
			float(faelle[r]) / float(faelle_gesamt) * 100.0, int(tage_region[r]),
			float(tage_region[r]) / float(tage_gesamt) * 100.0])

## Wie viele Spieler in einer typischen Spielzeit mindestens einmal ausfallen.
func _anteil_mit_einer_je_saison(menge: Dictionary = {}) -> float:
	var welche: Dictionary = menge if not menge.is_empty() else gesehen
	var schnitt: float = 0.0
	for sid in welche.keys():
		var f: float = float(int(spieler_faelle.get(sid, 0))) / float(JAHRE)
		# Poisson: die Wahrscheinlichkeit, in einer Spielzeit nicht leer
		# auszugehen.
		schnitt += 1.0 - exp(-f)
	return schnitt / maxf(float(welche.size()), 1.0)
