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

	_log("— Statistikzentrum: alle Wertungen —")
	app.zeige("statistik")
	var stat: Node = app.bildschirme["statistik"]
	for kat in Statistik.KATEGORIEN.keys():
		stat.kategorie = str(kat)
		stat._zeichne()
		await get_tree().process_frame
	_log("   %d Wertungen gezeichnet" % Statistik.KATEGORIEN.size())

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
