extends Node
## Startet die Anwendung genau so, wie der Spieler sie startet: ohne geladenen
## Spielstand. Alle Bildschirme müssen sich in diesem Zustand aufbauen und
## anzeigen lassen, ohne auf Weltdaten zuzugreifen, die es noch nicht gibt.

func _log(text: String) -> void:
	printerr(text)

func _ready() -> void:
	_log("— Kaltstart: App ohne Spielstand —")
	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	# Zuerst: ist die App ueberhaupt da?
	#
	# Ein Parse-Fehler in irgendeiner Klasse laesst App.gd nicht laden. Die
	# Szene haengt dann als nacktes Control im Baum, jeder Zugriff auf ein
	# Feld schlaegt fehl, und der Test lief in eine Warteschleife, aus der er
	# nicht mehr herauskam — sieben Minuten, in denen die eigentliche
	# Meldung ("There is already a variable named kopf") schon dastand und
	# niemand sie las. Deshalb hier ein Abbruch mit klarer Ansage.
	if not ("startbildschirm" in app):
		_log("   FEHLER: App.gd liess sich nicht laden. Weiter oben steht, warum —")
		_log("   meist ein Parse-Fehler in einer Klasse, die App.gd benutzt.")
		get_tree().quit()
		return
	_log("   App aufgebaut, Startbildschirm sichtbar: %s" % str(app.startbildschirm.visible))

	_log("— Alle Bildschirme ohne Spielstand anzeigen —")
	app._zeige_start(false)
	for id in app.bildschirme.keys():
		app.zeige(id)
		await get_tree().process_frame
	_log("   alle %d Bildschirme ohne Spielstand ok" % app.bildschirme.size())

	_log("— Fenster ohne Spielstand —")
	get_tree().get_first_node_in_group("spielerfenster").zeige("gibt_es_nicht")
	get_tree().get_first_node_in_group("vereinsfenster").zeige("gibt_es_nicht")
	get_tree().get_first_node_in_group("spielbericht").zeige("gibt_es_nicht")
	await get_tree().process_frame
	_log("   ok")

	_log("— Weiterschalten ohne Spielstand —")
	app._weiter()
	await get_tree().process_frame
	_log("   ok")

	_log("— Jetzt neues Spiel über den Startbildschirm —")
	app._zeige_start(true)
	app.startbildschirm._seite("trainer")
	app.startbildschirm._zur_vereinswahl()
	await get_tree().process_frame
	var cid: String = str(app.startbildschirm.vorschau_welt["ligen"]["l_de1"]["vereine"][2])
	app.startbildschirm._starte(cid)
	await get_tree().process_frame
	_log("   Verein: %s" % Welt.mein_verein()["name"])

	for id2 in app.bildschirme.keys():
		app.zeige(id2)
		await get_tree().process_frame
	_log("   alle Bildschirme mit Spielstand ok")
	_log("— Kaltstart bestanden —")
	get_tree().quit()
