extends Node
## Warum geht der Verein unter, sobald die KI ihn führt?

func _ready() -> void:
	for fuehren in [false, true]:
		_lauf(fuehren)
	get_tree().quit()

func _lauf(fuehren: bool) -> void:
	var vorschau := Weltgenerator.erzeuge(2026, 4242)
	var liste: Array = vorschau["ligen"]["l_de1"]["vereine"]
	var cid: String = str(liste[liste.size() - 4])
	seed(4242)
	Welt.neues_spiel(cid, {"vorname": "Diag", "nachname": "Nose"}, 4242)
	var d: Dictionary = Welt.daten
	printerr("")
	printerr("--- KI.verein_fuehren fuer den eigenen Verein: %s ---" % ("an" if fuehren else "aus"))
	var wochentag := -1
	for i in range(330):
		var u := Welt.tag_weiter()
		var wt: int = Kalender.wochentag(Welt.tag())
		if fuehren and wt == 0 and wt != wochentag and Welt.mein_verein_id != "":
			KI.verein_fuehren(d, cid)
		wochentag = wt
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		if Welt.mein_verein_id == "":
			printerr("   Tag %d: entlassen." % i)
			return
		if i % 110 == 109:
			_zeigen(d, cid, i + 1)
	_zeigen(d, cid, 330)

func _zeigen(d: Dictionary, cid: String, tag: int) -> void:
	var v: Dictionary = d["vereine"][cid]
	var lid: String = str(v["liga"])
	var z: Dictionary = (d["ligen"][lid]["tabelle"] as Dictionary).get(cid, Spielplan.leere_tabellenzeile())
	printerr("   Tag %3d: %d Spiele, %d Punkte, Kader %d, Kasse %s, Vertrauen %.0f" % [
		tag, int(z["sp"]), int(z["punkte"]), (v["kader"] as Array).size(),
		Stil.geld(float(v["kasse"])), float(v["vorstand"]["vertrauen"])])
