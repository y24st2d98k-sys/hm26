extends Node
## Wie oft liest der Spieler denselben Satz?
##
## Der Live-Ticker ist der Bildschirm, auf den man in diesem Spiel am längsten
## schaut: über zweihundert Einträge je Partie, vierunddreißig Partien in der
## Liga. Die Medienarbeit wurde gemessen (werkzeuge/Mediensonde.gd), der Ticker
## nie — und dabei war er der schlechtere Teil. Zwei Ereignisarten zogen
## überhaupt nicht aus der Textbank: der Block überschrieb den gezogenen Satz
## mit einer festen Form, und der Ballverlust nannte nur "Grund: Name". Bei
## knapp acht Blocks und elf technischen Fehlern je Mannschaft und Partie stand
## damit ein Fünftel aller Tickerzeilen in genau zwei Satzbauten.
##
## Gemessen wird je Ereignisart: wie viele Einträge, wie viele verschiedene
## Texte, und wie oft der häufigste vorkommt. Namen werden dabei
## herausgerechnet — sonst sähe jede Zeile eigenständig aus, nur weil ein
## anderer Spieler darin steht.
##
##     godot --headless res://werkzeuge/Tickersonde.tscn -- [partien]

const SAAT := 60413

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var anzahl: int = int(args[0]) if args.size() > 0 else 34
	Welt.daten = Weltgenerator.erzeuge(2026, SAAT)
	Welt.mein_verein_id = ""
	var d: Dictionary = Welt.daten
	# Der Spielplan mischt mit dem globalen Zufallsgenerator.
	seed(SAAT)
	Spielplan.erzeuge_saison(d)
	var partien: Array = []
	for mid in (d["spiele"] as Dictionary).keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) == "liga" and str(m.get("wettbewerb", "")) == "l_de1":
			partien.append(str(mid))
	partien.sort()
	if partien.size() > anzahl:
		partien.resize(anzahl)

	var namen := _namen_sammeln(d)
	var je_art := {}
	var zeilen := 0
	for i in range(partien.size()):
		var m2: Dictionary = d["spiele"][partien[i]]
		var sim := Matchsim.new(d, m2, 50021 + i * 11)
		sim.vorbereiten()
		sim.schnell_simulieren()
		for e in sim.ereignisse:
			var art: String = str((e as Dictionary).get("typ", "?"))
			var text: String = _muster(str((e as Dictionary).get("text", "")), namen)
			if text == "":
				continue
			zeilen += 1
			if not je_art.has(art):
				je_art[art] = {}
			var topf: Dictionary = je_art[art]
			topf[text] = int(topf.get(text, 0)) + 1

	_log("")
	_log("=== Textvielfalt im Live-Ticker, %d Partien, %d Zeilen ===" % [partien.size(), zeilen])
	_log("")
	_log("%-14s %8s %9s %9s %9s   %s" % ["Ereignis", "Zeilen", "Muster",
		"je Muster", "häufigst", "der häufigste Satz"])
	var arten: Array = je_art.keys()
	arten.sort_custom(func(a, b): return _summe(je_art[a]) > _summe(je_art[b]))
	var mager: Array = []
	for art in arten:
		var topf: Dictionary = je_art[art]
		var summe: int = _summe(topf)
		var haeufigster := ""
		var hoechste := 0
		for t in topf.keys():
			if int(topf[t]) > hoechste:
				hoechste = int(topf[t])
				haeufigster = str(t)
		var je: float = float(summe) / maxf(float(topf.size()), 1.0)
		_log("%-14s %8d %9d %9.1f %9d   %s" % [str(art), summe, topf.size(), je,
			hoechste, haeufigster.left(46)])
		# Ein Satz, der in vierunddreissig Partien mehr als zwanzigmal
		# gleich dasteht, faellt auf.
		if summe >= 40 and je > 20.0:
			mager.append(str(art))

	_log("")
	if mager.is_empty():
		_log("Keine Ereignisart wiederholt sich im Schnitt öfter als zwanzigmal je Muster.")
	else:
		_log("Zu wenige Muster bei: %s" % ", ".join(mager))
	get_tree().quit()

func _summe(topf: Dictionary) -> int:
	var s := 0
	for k in topf.keys():
		s += int(topf[k])
	return s

func _namen_sammeln(d: Dictionary) -> Dictionary:
	var namen := {}
	for sid in (d["spieler"] as Dictionary).keys():
		var sp: Dictionary = d["spieler"][sid]
		# Auch Wort fuer Wort: ein Nachname wie "Þorgeir Kristjánsson" steht im
		# Ticker in zwei Teilen, und nur der ganze Name als Schluessel hat ihn
		# nicht getroffen.
		for wort in (str(sp["nachname"]) + " " + str(sp["vorname"])).split(" "):
			if str(wort) != "":
				namen[str(wort)] = true
	for cid in (d["vereine"] as Dictionary).keys():
		var v: Dictionary = d["vereine"][cid]
		namen[str(v["name"])] = true
		namen[str(v["kurz"])] = true
		for wort in str(v["name"]).split(" "):
			namen[str(wort)] = true
	namen["Der"] = false
	return namen

func _muster(text: String, namen: Dictionary) -> String:
	var neu: PackedStringArray = PackedStringArray()
	for t in text.split(" "):
		var wort: String = str(t)
		var nackt: String = wort
		while nackt.length() > 0 and nackt[nackt.length() - 1] in [".", ",", "!", ":", "?", ";"]:
			nackt = nackt.substr(0, nackt.length() - 1)
		# Ein Initial wie "M." gehoert zum Namen und wird mit ihm maskiert.
		# Ohne das zaehlte "M. Müller" und "J. Müller" als zwei Satzbauten, und
		# die Musterzahl log um den Faktor zehn.
		if nackt.length() == 1 and nackt[0] == nackt[0].to_upper() \
				and nackt[0] != nackt[0].to_lower():
			continue
		if nackt != "" and bool(namen.get(nackt, false)):
			neu.append("*" + wort.substr(nackt.length()))
		elif nackt.is_valid_int():
			neu.append("#" + wort.substr(nackt.length()))
		else:
			neu.append(wort)
	return " ".join(neu)
