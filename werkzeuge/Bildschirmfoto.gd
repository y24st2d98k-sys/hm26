extends Node
## Rendert die Oberflaeche in eine PNG-Datei je Bildschirm.
## Aufruf: godot res://werkzeuge/Bildschirmfoto.tscn -- <ziel_ordner> [bildschirm …]
## Ohne Angabe werden die wichtigsten Bildschirme aufgenommen.

const STANDARD := ["buero", "kader", "taktik", "tabellen", "spielplan", "transfer",
	"statistik", "finanzen", "training", "kabine"]

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ordner: String = str(args[0]) if args.size() > 0 else "/tmp/hallenherz"
	var welche: Array = args.slice(1) if args.size() > 1 else STANDARD
	DirAccess.make_dir_recursive_absolute(ordner)
	get_window().size = Vector2i(1680, 945)
	await get_tree().process_frame

	var vorschau := Weltgenerator.erzeuge(2026, 424242)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	Welt.neues_spiel(cid, {"vorname": "Mira", "nachname": "Halden",
		"hintergrund": "nachwuchs", "nation": "de", "alter": 41}, 424242)
	_log("Verein: %s" % Welt.mein_verein()["name"])

	# Erst simulieren, dann die Oberflaeche bauen: sonst faengt die App das
	# Signal "eigenes Spiel faellig" ab und die Live-Ansicht uebernimmt.
	var schritte := 0
	while schritte < 120:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		schritte += 1
	_log("Simuliert bis %s" % Welt.datum_text())

	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)

	for id in welche:
		if str(id) == "live":
			await _live(app, ordner)
			continue
		if str(id) == "start":
			app._zeige_start(true)
			await _foto("%s/start.png" % ordner)
			app._zeige_start(false)
			continue
		if not app.bildschirme.has(str(id)):
			_log("unbekannt: %s" % str(id))
			continue
		app.zeige(str(id))
		await _foto("%s/%s.png" % [ordner, str(id)])
	get_tree().quit()

func _live(app: Node, ordner: String) -> void:
	var naechstes := Welt.naechstes_spiel(Welt.mein_verein_id)
	if naechstes.is_empty():
		return
	app.rahmen.visible = false
	app.live.visible = true
	app.live.starte(str(naechstes["id"]))
	await get_tree().process_frame
	for i in range(140):
		app.live._schritt()
	await get_tree().process_frame
	await _foto("%s/live.png" % ordner)
	app.live.visible = false
	app.rahmen.visible = true

func _foto(pfad: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var bild := get_viewport().get_texture().get_image()
	bild.save_png(pfad)
	_log("→ %s" % pfad)
