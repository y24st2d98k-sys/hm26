extends Node
## Wie viel bringt Videostudium wirklich?
##
## Die Forderung war ausdruecklich: es soll sich auf das Ergebnis auswirken,
## aber man soll nicht jedes Spiel damit gewinnen. Beides laesst sich zaehlen —
## dieselbe Bundesligarunde einmal ohne Videoarbeit auf beiden Seiten, einmal
## mit voller Arbeit auf einer Seite und keiner auf der anderen.

const RUNDEN := 306

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	_lauf("Beide Seiten ohne Videoarbeit", 0.0, 0.0)
	_lauf("Heim voll vorbereitet, Gast gar nicht", 4.0, 0.0)
	_lauf("Beide voll vorbereitet", 4.0, 4.0)
	get_tree().quit()

func _lauf(titel: String, heim_arbeit: float, gast_arbeit: float) -> void:
	Welt.daten = Weltgenerator.erzeuge(2026, 999)
	Welt.mein_verein_id = ""
	var d := Welt.daten
	Spielplan.erzeuge_saison(d)
	var partien: Array = []
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) == "liga" and str(m.get("wettbewerb", "")) == "l_de1":
			partien.append(mid)
	var heimsiege := 0
	var tore := 0
	var abstand := 0
	for mid2 in partien:
		var m2: Dictionary = d["spiele"][mid2]
		# Die Vorbereitung beider Seiten genau setzen, damit der Vergleich
		# nur an dieser einen Groesse haengt.
		var sh := Videostudium.stand(d, str(m2["heim"]))
		sh["gegner"] = str(m2["gast"])
		sh["arbeit"] = heim_arbeit
		var sg := Videostudium.stand(d, str(m2["gast"]))
		sg["gegner"] = str(m2["heim"])
		sg["arbeit"] = gast_arbeit
		var sim := Matchsim.new(d, m2, 0)
		sim.vorbereiten()
		sim.schnell_simulieren()
		var h: int = int(m2["tore_heim"])
		var g: int = int(m2["tore_gast"])
		tore += h + g
		abstand += h - g
		if h > g:
			heimsiege += 1
	var n := float(partien.size())
	_log("%-42s Heimsiege %5.1f %%   Tore %5.1f   Tordifferenz Heim %+5.2f" % [
		titel, float(heimsiege) / n * 100.0, float(tore) / n, float(abstand) / n])
