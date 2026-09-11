extends Node
## Kalibrierungswerkzeug: simuliert Partien und Saisons ohne Oberflaeche
## und gibt Kennzahlen aus. Aufruf:
##   godot --headless --script res://werkzeuge/Testlauf.gd -- <modus>
## Modi: spiele, saison, welt

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var modus: String = str(args[0]) if args.size() > 0 else "spiele"
	var start := Time.get_ticks_msec()
	match modus:
		"welt":
			_welt_test()
		"saison":
			_saison_test(730)
		"halbsaison":
			_saison_test(300)
		_:
			_spiele_test()
	print("Dauer: %d ms" % (Time.get_ticks_msec() - start))
	get_tree().quit()

func _neues_spiel() -> void:
	Welt.neues_spiel(_erster_verein(), {"vorname": "Test", "nachname": "Trainer", "hintergrund": "taktiker"}, 4711)

func _erster_verein() -> String:
	var d := Weltgenerator.erzeuge(2026, 4711)
	var lid: String = "l_de1"
	return str(d["ligen"][lid]["vereine"][0])

func _welt_test() -> void:
	var d := Weltgenerator.erzeuge(2026, 12345)
	print("Vereine: %d, Spieler: %d, Personal: %d" % [d["vereine"].size(), d["spieler"].size(), d["personal"].size()])
	var staerken: Array = []
	for sid in d["spieler"].keys():
		staerken.append(Spielerfabrik.gesamt(d["spieler"][sid]))
	staerken.sort()
	print("Staerke: min %.1f / median %.1f / max %.1f" % [staerken[0], staerken[staerken.size() / 2], staerken[-1]])
	var namen := {}
	for sid in d["spieler"].keys():
		namen[Spielerfabrik.voller_name(d["spieler"][sid])] = true
	print("Eindeutige Spielernamen: %d von %d" % [namen.size(), d["spieler"].size()])
	var beispiel: Array = []
	var i := 0
	for cid in d["vereine"].keys():
		beispiel.append("%s (%s)" % [d["vereine"][cid]["name"], d["vereine"][cid]["kurz"]])
		i += 1
		if i >= 10:
			break
	print("Beispielvereine: %s" % ", ".join(beispiel))

func _spiele_test() -> void:
	Welt.daten = Weltgenerator.erzeuge(2026, 999)
	Welt.mein_verein_id = ""
	var d := Welt.daten
	Spielplan.erzeuge_saison(d)
	var partien: Array = []
	for mid in d["spiele"].keys():
		if str(d["spiele"][mid]["art"]) == "liga":
			partien.append(mid)
		if partien.size() >= 300:
			break
	var tore := 0
	var heimtore := 0
	var zeitstrafen := 0
	var siebenmeter := 0
	var fehler := 0
	var paraden := 0
	var hoechstes := 0
	var unentschieden := 0
	var heimsiege := 0
	for mid in partien:
		var m: Dictionary = d["spiele"][mid]
		var sim := Matchsim.new(d, m, 0)
		sim.vorbereiten()
		sim.schnell_simulieren()
		var b := sim.bericht()
		tore += int(m["tore_heim"]) + int(m["tore_gast"])
		heimtore += int(m["tore_heim"])
		zeitstrafen += int(b["heim"]["stats"]["zeitstrafen"]) + int(b["gast"]["stats"]["zeitstrafen"])
		siebenmeter += int(b["heim"]["stats"]["siebenmeter"]) + int(b["gast"]["stats"]["siebenmeter"])
		fehler += int(b["heim"]["stats"]["technische_fehler"]) + int(b["gast"]["stats"]["technische_fehler"])
		paraden += int(b["heim"]["stats"]["paraden"]) + int(b["gast"]["stats"]["paraden"])
		hoechstes = maxi(hoechstes, maxi(int(m["tore_heim"]), int(m["tore_gast"])))
		if int(m["tore_heim"]) == int(m["tore_gast"]):
			unentschieden += 1
		elif int(m["tore_heim"]) > int(m["tore_gast"]):
			heimsiege += 1
	var n := float(partien.size())
	print("Partien: %d" % partien.size())
	print("Tore pro Spiel gesamt: %.1f  (Heim %.1f / Gast %.1f)" % [tore / n, heimtore / n, (tore - heimtore) / n])
	print("Zeitstrafen pro Spiel: %.1f" % (zeitstrafen / n))
	print("Siebenmeter pro Spiel: %.1f" % (siebenmeter / n))
	print("Technische Fehler pro Spiel: %.1f" % (fehler / n))
	print("Paraden pro Spiel: %.1f" % (paraden / n))
	print("Heimsiegquote: %.1f %%   Unentschieden: %.1f %%" % [heimsiege / n * 100.0, unentschieden / n * 100.0])
	print("Hoechste Torzahl einer Mannschaft: %d" % hoechstes)

func _saison_test(dauer: int) -> void:
	Welt.neues_spiel("c_001", {"vorname": "Test", "nachname": "Trainer", "hintergrund": "taktiker"}, 2024)
	var d := Welt.daten
	print("Mein Verein: %s" % d["vereine"][Welt.mein_verein_id]["name"])
	var tage := 0
	while tage < dauer:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.spieltag_abwickeln(Welt.tag())
			Welt._wochenrhythmus(Welt.tag())
			Welt._saison_pruefen(Welt.tag())
		tage += 1
	print("Datum: %s, Saison %s" % [Welt.datum_text(), Welt.saison_text()])
	var lid: String = str(d["vereine"][Welt.mein_verein_id]["liga"]) if Welt.mein_verein_id != "" else "l_de1"
	var tabelle := Spielplan.tabelle_sortiert(d, lid)
	print("Tabelle %s:" % d["ligen"][lid]["name"])
	for i in range(mini(6, tabelle.size())):
		var z: Dictionary = d["ligen"][lid]["tabelle"][tabelle[i]]
		print("  %d. %-32s %2d Sp %2d P %3d:%3d" % [i + 1, d["vereine"][tabelle[i]]["name"], int(z["sp"]), int(z["punkte"]), int(z["tore"]), int(z["gegentore"])])
	var tj := Statistik.torjaeger(d, lid, 5)
	print("Torjaeger:")
	for e in tj:
		if d["spieler"].has(e["sid"]):
			print("  %-28s %d" % [Spielerfabrik.voller_name(d["spieler"][e["sid"]]), int(e["tore"])])
	print("Spieler gesamt: %d, Nachrichten: %d, Presse: %d" % [d["spieler"].size(), (d["nachrichten"] as Array).size(), (d["presse"] as Array).size()])
	if Welt.mein_verein_id != "":
		var v: Dictionary = d["vereine"][Welt.mein_verein_id]
		print("Kasse: %s, Vorstandsvertrauen: %.0f, Kabine: %.0f" % [Stil.geld(float(v["kasse"])), float(v["vorstand"]["vertrauen"]), float(v["stimmung_kabine"])])
		print("Trainerruf: %.1f, Praegungen: %s" % [float(d["trainer"]["ruf"]), str(d["trainer"]["praegungen"])])
