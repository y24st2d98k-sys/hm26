extends Node
## Prueft alle Bildschirme, Fenster und die Live-Ansicht auf Laufzeitfehler.

func _log(text: String) -> void:
	printerr(text)

func _ready() -> void:
	_log("— Neues Spiel anlegen —")
	var vorschau := Weltgenerator.erzeuge(2026, 777)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][3])
	Welt.neues_spiel(cid, {"vorname": "Mira", "nachname": "Halden", "hintergrund": "nachwuchs", "nation": "de", "alter": 41}, 777)
	_log("Verein: %s" % Welt.mein_verein()["name"])

	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)
	await get_tree().process_frame

	_log("— Alle Bildschirme aufrufen —")
	for id in app.bildschirme.keys():
		app.zeige(id)
		await get_tree().process_frame
		_log("   %s ok" % id)

	_log("— Fenster testen —")
	var sid: String = str(Welt.mein_verein()["kader"][0])
	var fenster: Node = get_tree().get_first_node_in_group("spielerfenster")
	for reiter in ["uebersicht", "attribute", "statistik", "vertrag", "entwicklung"]:
		fenster.zeige(sid)
		fenster.reiter = reiter
		fenster._zeichne()
		await get_tree().process_frame
	fenster.schliessen()
	get_tree().get_first_node_in_group("vereinsfenster").zeige(cid)
	await get_tree().process_frame
	_log("   Spieler- und Vereinsfenster ok")

	_log("— Tage bis zum ersten eigenen Spiel —")
	var schritte := 0
	while schritte < 90:
		var u := Welt.tag_weiter()
		schritte += 1
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			_log("   Spieltag erreicht nach %d Tagen: %s" % [schritte, Welt.datum_text()])
			break
	var naechstes := Welt.naechstes_spiel(Welt.mein_verein_id)
	if naechstes.is_empty():
		_log("   FEHLER: kein Spiel gefunden")
		get_tree().quit()
		return

	_log("— Live-Ansicht —")
	var live: Node = app.live
	live.visible = true
	live.starte(str(naechstes["id"]))
	await get_tree().process_frame
	for i in range(40):
		live._schritt()
	_log("— Kabinenansprachen —")
	for ton in Matchsim.ANSPRACHEN.keys():
		var erg: Dictionary = live.sim.ansprache_halten(live.sim.heim, str(ton))
		_log("   %s: %s" % [str(ton), str(erg.get("text", erg))])
	live._ansprache_aufbauen(false)
	await get_tree().process_frame
	live._ueberspringen()
	await get_tree().process_frame
	_log("   Endstand: %d:%d" % [int(live.sim.heim["tore"]), int(live.sim.gast["tore"])])
	live._abschliessen()
	await get_tree().process_frame

	_log("— Spielbericht —")
	get_tree().get_first_node_in_group("spielbericht").zeige(str(naechstes["id"]))
	await get_tree().process_frame

	_log("— Weitere 60 Tage —")
	for i in range(25):
		var u2 := Welt.tag_weiter()
		if u2.has("art") and str(u2["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u2["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
	for id2 in app.bildschirme.keys():
		app.zeige(id2)
		await get_tree().process_frame

	_log("— Kaderdaten pflegen —")
	var db: Node = app.bildschirme["daten"]
	app.zeige("daten")
	db.gewaehlt = "THW Kiel"
	db.entwurf = []
	db.aktualisieren()
	await get_tree().process_frame
	var eingelesen := Kaderpflege.csv_einlesen(
		"Vorname;Nachname;Position;Nation;Alter;Staerke\n" +
		"Test;Eins;RM;de;24;80\nTest;Zwei;XX;zz;99;500\nkaputt\n")
	_log("   CSV: %d übernommen, %d Hinweise" % [(eingelesen["eintraege"] as Array).size(),
		(eingelesen["meldungen"] as Array).size()])
	Kaderpflege.setzen("THW Kiel", eingelesen["eintraege"])
	_log("   THW Kiel jetzt %d Spieler, eigen: %s" % [Kaderpflege.kader("THW Kiel").size(),
		str(Kaderpflege.ist_eigen("THW Kiel"))])
	db.entwurf = []
	db.aktualisieren()
	await get_tree().process_frame
	Kaderpflege.alles_verwerfen()
	_log("   nach Verwerfen: %d Spieler" % Kaderpflege.kader("THW Kiel").size())

	_log("— Einzelgespräch —")
	var gsid: String = str(Welt.mein_verein()["kader"][1])
	_log("   angebotene Themen: %s" % str(Gespraech.themen(Welt.daten, gsid)))
	# Zum Pruefen alle Themen durchspielen, nicht nur die gerade angebotenen.
	for t in Gespraech.THEMEN.keys():
		for a in Gespraech.ANTWORTEN[t]:
			var erg := Gespraech.fuehren(Welt.daten, gsid, str(t), str((a as Dictionary)["id"]))
			_log("   %s/%s: %s" % [str(t), str((a as Dictionary)["id"]), str(erg["text"])])
			Welt.spieler(gsid)["letztes_gespraech_tag"] = -999
	fenster.zeige(gsid)
	fenster.reiter = "statistik"
	fenster._zeichne()
	await get_tree().process_frame
	fenster.schliessen()
	_log("   Versprechen offen: %d" % Gespraech.offene(Welt.daten, gsid).size())

	_log("— Spielvorbereitung —")
	var naechstes2 := Welt.naechstes_spiel(Welt.mein_verein_id)
	if not naechstes2.is_empty():
		var gegner2: String = str(naechstes2["gast"]) if str(naechstes2["heim"]) == Welt.mein_verein_id else str(naechstes2["heim"])
		var vf: Node = get_tree().get_first_node_in_group("vorberichtsfenster")
		vf.zeige(gegner2, str(naechstes2["id"]))
		await get_tree().process_frame
		_log("   Vorbericht Stufe %d ok" % int(Vorbericht.stufe(Welt.daten, Welt.mein_verein_id, gegner2)))
		vf.visible = false

	_log("— Statistikzentrum: alle Wertungen —")
	app.zeige("statistik")
	var stat: Node = app.bildschirme["statistik"]
	for kat in Statistik.KATEGORIEN.keys():
		stat.kategorie = str(kat)
		stat._zeichne()
		await get_tree().process_frame
	_log("   %d Wertungen gezeichnet" % Statistik.KATEGORIEN.size())

	_log("— Vorspulen —")
	var vf: Node = get_tree().get_first_node_in_group("vorspulfenster")
	vf.zeige()
	await get_tree().process_frame
	var vorher_tag := Welt.tag()
	Welt.setze_einstellung("vorspulen_simuliert", true)
	var sprung := Welt.vorspulen(Welt.tag() + 21, true)
	_log("   %d Tage vorgespult (%s), Tag %d -> %d" % [int(sprung["tage"]), str(sprung["grund"]),
		vorher_tag, Welt.tag()])
	vf._zeichne()
	await get_tree().process_frame
	vf.visible = false

	_log("— Speichern und Laden —")
	if Welt.speichern(1, "Testlauf"):
		_log("   gespeichert")
	var vorher := Welt.tag()
	var verein_vorher := str(Welt.mein_verein_id)
	if Welt.laden(1):
		_log("   geladen: Tag %d (vorher %d), Verein %s" % [Welt.tag(), vorher, Welt.mein_verein()["name"]])
		if Welt.tag() != vorher or Welt.mein_verein_id != verein_vorher:
			_log("   FEHLER: Spielstand stimmt nicht überein")
	for id3 in app.bildschirme.keys():
		app.zeige(id3)
		await get_tree().process_frame
	_log("— Alles durchlaufen —")
	get_tree().quit()
