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
		"langzeit":
			_langzeit_test(1100)
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

## Drei Saisons am Stück: prüft Auf-/Abstieg, Titel, Alterung und Karriere.
func _langzeit_test(dauer: int) -> void:
	Welt.neues_spiel("c_005", {"vorname": "Test", "nachname": "Trainer", "hintergrund": "exprofi"}, 31337)
	var d := Welt.daten
	printerr("Start: %s in %s" % [d["vereine"][Welt.mein_verein_id]["name"], Welt.wettbewerb_name(str(d["vereine"][Welt.mein_verein_id]["liga"]))])
	var tage := 0
	while tage < dauer:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt._wochenrhythmus(Welt.tag())
			Welt._saison_pruefen(Welt.tag())
		tage += 1
		if tage % 365 == 0:
			printerr("  ... Tag %d, %s" % [tage, Welt.datum_text()])
	printerr("Ende: %s, Saison %s" % [Welt.datum_text(), Welt.saison_text()])
	printerr("")
	printerr("Meister je Nation:")
	for nid in d["nationen"].keys():
		var nation: Dictionary = d["nationen"][nid]
		var h: Array = nation.get("meister_historie", [])
		var namen: Array = []
		for e in h:
			namen.append("%s: %s" % [Kalender.saison_text(Welt.startjahr(), int(e["saison"])),
				str(d["vereine"].get(str(e["verein"]), {}).get("name", "?"))])
		printerr("  %-14s %s" % [nation["name"], " | ".join(namen)])
	printerr("")
	printerr("Auf- und Abstieg (Deutschland):")
	var oben: Dictionary = d["ligen"]["l_de1"]
	var unten: Dictionary = d["ligen"]["l_de2"]
	printerr("  1. Liga: %d Vereine, 2. Liga: %d Vereine" % [(oben["vereine"] as Array).size(), (unten["vereine"] as Array).size()])
	var auf: Array = []
	for cid in unten.get("aufsteiger", []):
		auf.append(str(d["vereine"][cid]["name"]))
	var ab: Array = []
	for cid in oben.get("absteiger", []):
		ab.append(str(d["vereine"][cid]["name"]))
	printerr("  Letzte Aufsteiger: %s" % ", ".join(auf))
	printerr("  Letzte Absteiger:  %s" % ", ".join(ab))
	printerr("")
	printerr("Pokal- und Europasieger:")
	for pid in d["pokale"].keys():
		var pokal: Dictionary = d["pokale"][pid]
		var h2: Array = pokal.get("sieger_historie", [])
		if h2.is_empty():
			continue
		printerr("  %-24s %s" % [pokal["name"], str(d["vereine"].get(str(h2[0]["verein"]), {}).get("name", "?"))])
	for wid in d["international"].keys():
		var wb: Dictionary = d["international"][wid]
		var h3: Array = wb.get("sieger_historie", [])
		var namen3: Array = []
		for e in h3:
			namen3.append(str(d["vereine"].get(str(e["verein"]), {}).get("name", "?")))
		printerr("  %-24s %s" % [wb["name"], " | ".join(namen3)])
	printerr("")
	var t: Dictionary = d["trainer"]
	printerr("Trainerkarriere:")
	printerr("  Verein: %s" % str(d["vereine"].get(str(t["verein"]), {}).get("name", "vereinslos")))
	printerr("  Ruf %.1f (%s), %d Spiele, %d Siege, %d Titel" % [float(t["ruf"]), Trainerkarriere.ruf_stufe(float(t["ruf"])),
		int(t["statistik"]["spiele"]), int(t["statistik"]["siege"]), (t["titel"] as Array).size()])
	printerr("  Prägungen: %s" % str(t["praegungen"]))
	var hs: Dictionary = t["handschrift"]
	var achsen: Array = []
	for a in hs.keys():
		achsen.append("%s %d" % [a, int(float(hs[a]))])
	printerr("  Handschrift: %s" % ", ".join(achsen))
	printerr("  Stationen: %d" % (t["stationen"] as Array).size())
	printerr("")
	printerr("Welt:")
	printerr("  Spieler: %d, davon vereinslos: %d" % [d["spieler"].size(), _vereinslos(d)])
	var alt := 0.0
	for sid in d["spieler"].keys():
		alt += float(d["spieler"][sid]["alter"])
	printerr("  Durchschnittsalter: %.1f" % (alt / maxf(float(d["spieler"].size()), 1.0)))
	var kadergroessen: Array = []
	var kleinster := 99
	for cid in d["vereine"].keys():
		var n: int = (d["vereine"][cid]["kader"] as Array).size()
		kadergroessen.append(n)
		kleinster = mini(kleinster, n)
	var summe := 0
	for n2 in kadergroessen:
		summe += int(n2)
	printerr("  Kadergröße: Ø %.1f, kleinster Kader %d" % [float(summe) / maxf(float(kadergroessen.size()), 1.0), kleinster])
	printerr("  Transfers gesamt: %d" % (d["transfermarkt"]["verlauf"] as Array).size())
	printerr("  Presse: %d, Hallenfunk: %d, Nachrichten: %d" % [(d["presse"] as Array).size(), (d["social"] as Array).size(), (d["nachrichten"] as Array).size()])
	printerr("  Rekorde:")
	for k in d["rekorde"].keys():
		var r: Dictionary = d["rekorde"][k]
		if not r.is_empty():
			printerr("    %-24s %s" % [k, str(r.get("text", ""))])
	if Welt.mein_verein_id != "":
		var v: Dictionary = d["vereine"][Welt.mein_verein_id]
		printerr("  Eigener Verein: Kasse %s, Ruf %d, Kabine %d, Vorstand %d" % [
			Stil.geld(float(v["kasse"])), int(float(v["ruf"])), int(float(v["stimmung_kabine"])), int(float(v["vorstand"]["vertrauen"]))])
		var rivalen := Chronik.rivalen(d, Welt.mein_verein_id, 3)
		for r2 in rivalen:
			printerr("    Rivale: %-30s %d (%s)" % [str(d["vereine"][str(r2["verein"])]["name"]),
				int(float(r2["intensitaet"])), Chronik.rivalitaet_stufe(float(r2["intensitaet"]))])

func _vereinslos(d: Dictionary) -> int:
	var z := 0
	for sid in d["spieler"].keys():
		if str(d["spieler"][sid]["verein"]) == "":
			z += 1
	return z
