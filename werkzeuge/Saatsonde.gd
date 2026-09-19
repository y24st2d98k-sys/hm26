extends Node
## Wie verschieden sind zwei Spielstaende?

func _ready() -> void:
	var welten: Array = []
	for saat in [111, 222, 333]:
		var d := Weltgenerator.erzeuge(2026, saat)
		welten.append(d)
	var d0: Dictionary = welten[0]
	var cid: String = str(d0["ligen"]["l_de1"]["vereine"][0])
	printerr("Verein: %s" % str(d0["vereine"][cid]["name"]))
	printerr("%-26s %-22s %-22s %-22s" % ["Spieler", "Saat 111", "Saat 222", "Saat 333"])
	var namen0: Array = []
	for sid in (d0["vereine"][cid]["kader"] as Array):
		namen0.append(Spielerfabrik.voller_name(d0["spieler"][str(sid)]))
	for i in mini(10, namen0.size()):
		var zeile := "%-26s" % str(namen0[i]).substr(0, 25)
		for d in welten:
			var gefunden := {}
			for sid2 in (d["vereine"][cid]["kader"] as Array):
				var sp: Dictionary = d["spieler"][str(sid2)]
				if Spielerfabrik.voller_name(sp) == str(namen0[i]):
					gefunden = sp
					break
			if gefunden.is_empty():
				zeile += " %-22s" % "— nicht im Kader —"
			else:
				zeile += " St %2d Pot %2d Lern %.2f" % [int(Spielerfabrik.gesamt(gefunden)),
					int(float(gefunden["potenzial"])), float(gefunden.get("lernkurve", 1.0))]
		printerr(zeile)
	# Wie viele Spieler sind ueberhaupt dieselben?
	var gleich := 0
	for n in namen0:
		for sid3 in (welten[1]["vereine"][cid]["kader"] as Array):
			if Spielerfabrik.voller_name(welten[1]["spieler"][str(sid3)]) == str(n):
				gleich += 1
				break
	printerr("")
	printerr("%d von %d Spielern stehen in beiden Spielstaenden im selben Kader." % [gleich, namen0.size()])
	get_tree().quit()
