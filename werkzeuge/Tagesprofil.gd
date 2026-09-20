extends Node
## Welcher Schritt im Tageswechsel kostet die Zeit?
##
## Die Leistungsmessung nennt den Tageswechsel als Ganzes: im Mittel knapp
## eine Sekunde, im Höchstfall sechs. Das reicht, um ein Problem zu sehen,
## aber nicht, um es zu beheben. Diese Sonde zerlegt den Tag in seine vier
## Abschnitte und nennt für jeden Summe, Maximum und den teuersten Tag.
##
##     godot --headless res://werkzeuge/Tagesprofil.tscn -- <tage>

const SAAT := 20260913

func _log(t: String) -> void:
	printerr(t)

var summen := {}
var maxima := {}
var spitzentag := {}

func _messen(feld: String, usec: int, tag: int) -> void:
	var ms: float = float(usec) / 1000.0
	summen[feld] = float(summen.get(feld, 0.0)) + ms
	if ms > float(maxima.get(feld, 0.0)):
		maxima[feld] = ms
		spitzentag[feld] = tag

func _ready() -> void:
	var welt := Weltgenerator.erzeuge(2026, SAAT)
	var cid: String = str(welt["ligen"]["l_de1"]["vereine"][0])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Tag", "nachname": "Profil"}, SAAT)
	var args := OS.get_cmdline_user_args()
	var tage: int = int(args[0]) if args.size() > 0 else 120

	for _i in range(tage):
		var t0 := Time.get_ticks_usec()
		var u := Welt.tag_weiter()
		var tag: int = Welt.tag()
		_messen("tag_weiter", Time.get_ticks_usec() - t0, tag)
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			var t1 := Time.get_ticks_usec()
			Welt.partie_simulieren(str(u["spiel"]))
			_messen("eigene_partie", Time.get_ticks_usec() - t1, tag)
		var t2 := Time.get_ticks_usec()
		Welt.spieltag_abwickeln(tag)
		_messen("spieltag_abwickeln", Time.get_ticks_usec() - t2, tag)
		var t3 := Time.get_ticks_usec()
		Welt.wochenrhythmus(tag)
		_messen("wochenrhythmus", Time.get_ticks_usec() - t3, tag)
		var t4 := Time.get_ticks_usec()
		Welt.saison_pruefen(tag)
		_messen("saison_pruefen", Time.get_ticks_usec() - t4, tag)

	_log("")
	_log("=== Tageswechsel über %d Tage, zerlegt ===" % tage)
	_log("")
	_log("%-22s %10s %10s %10s" % ["Abschnitt", "Summe s", "Maximum ms", "an Tag"])
	var felder: Array = summen.keys()
	felder.sort_custom(func(a, b): return float(summen[a]) > float(summen[b]))
	var gesamt := 0.0
	for f in felder:
		gesamt += float(summen[f])
	for f in felder:
		_log("%-22s %10.2f %10.1f %10d   (%4.1f %%)" % [str(f), float(summen[f]) / 1000.0,
			float(maxima[f]), int(spitzentag.get(f, 0)),
			float(summen[f]) / maxf(gesamt, 0.001) * 100.0])
	_log("")
	_log("Zusammen %.2f s für %d Tage — im Mittel %.0f ms je Tag." % [
		gesamt / 1000.0, tage, gesamt / float(tage)])
	get_tree().quit()
