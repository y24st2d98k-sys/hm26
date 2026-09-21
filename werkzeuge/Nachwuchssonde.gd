extends Node
## Verrottet der Nachwuchs der KI-Vereine über die Jahre?
##
## Die Langzeitsonde hat einen Verein acht Spielzeiten begleitet. Nach der
## Entlassung führte die KI ihn weiter — und der Schnitt seiner unter
## Dreiundzwanzigjährigen fiel von 65 auf 50, während der Kaderschnitt bei 79
## blieb. Gelesen heißt das: die KI hält die erste Mannschaft mit fertigen
## Spielern zusammen und lässt die Jungen liegen.
##
## Das wäre ein stilles Ungleichgewicht. Wer als Mensch Talente entwickelt,
## stünde nach ein paar Spielzeiten allein da — nicht weil er gut ist, sondern
## weil sonst niemand es tut. Ein Verein sagt darüber nichts; deshalb misst
## diese Sonde die ganze oberste Liga, Spielzeit für Spielzeit.
##
##     godot --headless res://werkzeuge/Nachwuchssonde.tscn -- <spielzeiten>

const SAAT := 5151

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var spielzeiten: int = int(args[0]) if args.size() > 0 else 8
	var vorschau := Weltgenerator.erzeuge(2026, SAAT)
	var liste: Array = vorschau["ligen"]["l_de1"]["vereine"]
	var cid: String = str(liste[int(liste.size() / 2)])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Nach", "nachname": "Wuchs"}, SAAT)
	var d: Dictionary = Welt.daten
	var lid: String = str(d["vereine"][cid]["liga"])
	_log("")
	_log("=== Die oberste Liga über %d Spielzeiten, alle Vereine von der KI geführt ===" % spielzeiten)
	_log("")
	# Kann und Decke getrennt: fällt beides, kommen zu schwache Jahrgänge
	# nach. Fällt nur das Können, entwickelt die Liga ihre Talente nicht.
	# Ohne diese Trennung rät man, woran es liegt — und repariert das
	# Falsche, wie zweimal geschehen.
	_log("%-8s %9s %9s %8s %9s %9s %8s %9s" % ["Saison", "Kader Ø", "Streuung",
		"u23 Ø", "u23 Decke", "u20 Decke", "Alter Ø", "Talente"])
	_bericht(0, d, lid)

	var saison := 0
	var tage := 0
	var wochentag := -1
	var saison_index: int = Welt.saison_index()
	while saison < spielzeiten and tage < spielzeiten * 380:
		var u := Welt.tag_weiter()
		tage += 1
		# Auch der eigene Verein wird von der KI geführt: gemessen wird die
		# Liga, nicht ein Mensch darin.
		var wt: int = Kalender.wochentag(Welt.tag())
		if wt == 0 and wt != wochentag and Welt.mein_verein_id != "":
			KI.verein_fuehren(d, cid)
		wochentag = wt
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		var jetzt: int = Welt.saison_index()
		if jetzt != saison_index:
			saison_index = jetzt
			saison += 1
			_bericht(saison, d, lid)
	_log("")
	_log("Ein u23-Schnitt, der über die Jahre fällt, heißt: nur der Mensch entwickelt noch.")
	get_tree().quit()

## Eine Zeile über die ganze Liga.
func _bericht(saison: int, d: Dictionary, lid: String) -> void:
	var vereine: Array = (d["ligen"][lid]["vereine"] as Array)
	if vereine.is_empty():
		return
	var staerken: Array = []
	var jung_summe := 0.0
	var jung_anzahl := 0
	var decke_summe := 0.0
	var u20_decke := 0.0
	var u20_anzahl := 0
	var alter_summe := 0.0
	var spieler_anzahl := 0
	var talente := 0
	for c in vereine:
		staerken.append(_staerke(d, str(c)))
		for sid in (d["vereine"][str(c)].get("kader", []) as Array):
			var sp: Dictionary = d["spieler"][str(sid)]
			alter_summe += float(int(sp["alter"]))
			spieler_anzahl += 1
			if int(sp["alter"]) <= 20:
				u20_decke += float(sp.get("potenzial", 0.0))
				u20_anzahl += 1
			if int(sp["alter"]) <= 23:
				jung_summe += Spielerfabrik.gesamt(sp)
				decke_summe += float(sp.get("potenzial", 0.0))
				jung_anzahl += 1
				if Spielerfabrik.gesamt(sp) >= 70.0:
					talente += 1
	var summe := 0.0
	for s in staerken:
		summe += float(s)
	var mittel: float = summe / float(staerken.size())
	var quadrate := 0.0
	for s2 in staerken:
		quadrate += (float(s2) - mittel) * (float(s2) - mittel)
	_log("%-8d %9.1f %9.2f %8.1f %9.1f %9.1f %8.1f %9d" % [saison, mittel,
		sqrt(quadrate / float(staerken.size())),
		jung_summe / maxf(float(jung_anzahl), 1.0),
		decke_summe / maxf(float(jung_anzahl), 1.0),
		u20_decke / maxf(float(u20_anzahl), 1.0),
		alter_summe / maxf(float(spieler_anzahl), 1.0), talente])

## Die acht Stärksten beschreiben eine Mannschaft besser als der Kaderschnitt.
func _staerke(d: Dictionary, cid: String) -> float:
	var v: Dictionary = (d.get("vereine", {}) as Dictionary).get(cid, {})
	if v.is_empty():
		return 0.0
	var beste: Array = []
	for sid in (v.get("kader", []) as Array):
		beste.append(Spielerfabrik.gesamt(d["spieler"][str(sid)]))
	beste.sort()
	beste.reverse()
	var summe := 0.0
	var k: int = mini(8, beste.size())
	for i in k:
		summe += float(beste[i])
	return summe / maxf(float(k), 1.0)
