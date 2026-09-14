extends Node
## Wie oft wiederholt sich, was in Presse und Hallenfunk steht?
##
## Die Frage laesst sich zaehlen: wie viele verschiedene Texte kommen ueber
## eine Saison zusammen, wie oft steht derselbe Satz doppelt, und wie viele
## Absender kommen ueberhaupt zu Wort.

const TAGE := 330

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	Welt.neues_spiel(_erster_verein(), {"vorname": "Test", "nachname": "Trainer",
		"hintergrund": "taktiker"}, 4711)
	var d := Welt.daten
	var tage := 0
	while tage < TAGE:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		tage += 1

	_log("Nach %d Tagen (%s)" % [TAGE, Welt.datum_text()])
	_auswerten("Hallenfunk", d["social"], "text", "handle")
	_auswerten("Presse", d["presse"], "schlagzeile", "outlet")

	_log("")
	_log("— Medienlandschaft —")
	var gattungen := {}
	var lokal := 0
	for o in d["medien"]["outlets"]:
		gattungen[str(o.get("gattung", "?"))] = int(gattungen.get(str(o.get("gattung", "?")), 0)) + 1
		if str(o.get("verein", "")) != "":
			lokal += 1
	_log("   %d Redaktionen, davon %d Lokalblätter" % [(d["medien"]["outlets"] as Array).size(), lokal])
	for g in gattungen.keys():
		_log("      %-16s %d" % [str(g), int(gattungen[g])])
	_log("   %d Fanaccounts" % (d["medien"]["fanaccounts"] as Array).size())

	_log("")
	_log("— Zehn Stimmen aus dem Hallenfunk —")
	var gezeigt := 0
	for e in d["social"]:
		_log("   %-18s (%-12s) %s" % [str(e["handle"]), str(e["typ"]), str(e["text"])])
		gezeigt += 1
		if gezeigt >= 10:
			break
	get_tree().quit()

func _auswerten(titel: String, liste: Array, feld: String, absender: String) -> void:
	_log("")
	_log("— %s —" % titel)
	if liste.is_empty():
		_log("   nichts erschienen")
		return
	var zaehler := {}
	var absender_zaehler := {}
	for e in liste:
		var t: String = str((e as Dictionary).get(feld, ""))
		zaehler[t] = int(zaehler.get(t, 0)) + 1
		var a: String = str((e as Dictionary).get(absender, ""))
		absender_zaehler[a] = int(absender_zaehler.get(a, 0)) + 1
	var haeufigste := ""
	var hoechste := 0
	for t2 in zaehler.keys():
		if int(zaehler[t2]) > hoechste:
			hoechste = int(zaehler[t2])
			haeufigste = str(t2)
	_log("   %d Einträge, %d verschiedene Texte (%.0f %% eigenständig)" % [
		liste.size(), zaehler.size(), float(zaehler.size()) / float(liste.size()) * 100.0])
	_log("   %d verschiedene Absender" % absender_zaehler.size())
	_log("   Häufigster Text: %dx „%s\"" % [hoechste, haeufigste.substr(0, 60)])

func _erster_verein() -> String:
	var d := Weltgenerator.erzeuge(2026, 4711)
	return str(d["ligen"]["l_de1"]["vereine"][0])
