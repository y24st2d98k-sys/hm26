extends Node
## Welche Zeile eines Bildschirms ist zu breit?
##
## Die Layoutpruefung meldet, dass etwas ueber den Rand ragt, aber nicht, wer
## die Breite erzwingt. Hier steht die Mindestbreite jedes Kindes untereinander.

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	get_window().size = Vector2i(1680, 945)
	await get_tree().process_frame
	var vorschau := Weltgenerator.erzeuge(2026, 424242)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	# Der Spielplan mischt mit dem globalen Zufallsgenerator. Ohne feste Saat
	# misst jeder Lauf eine andere Welt, und ein Vergleich vorher/nachher
	# zeigt Unterschiede, die keine sind.
	seed(424242)
	Welt.neues_spiel(cid, {"vorname": "Mira", "nachname": "Halden",
		"hintergrund": "nachwuchs", "nation": "de", "alter": 41}, 424242)
	for i in 90:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)
	var welche: Array = OS.get_cmdline_user_args()
	if welche.is_empty():
		welche = ["buero"]
	for id in welche:
		app.zeige(str(id))
		await get_tree().process_frame
		await get_tree().process_frame
		_log("=== %s ===" % str(id))
		var b: Node = app.bildschirme[str(id)]
		_zeige_baum(b, 0, 8)
	get_tree().quit()

## Der erste Text, den dieses Element enthaelt — damit man die Zeile wiederfindet.
func _hinweis(c: Node) -> String:
	if c is Label:
		return (c as Label).text.substr(0, 28)
	if c is Button and str((c as Button).text) != "":
		return (c as Button).text.substr(0, 28)
	for kind in c.get_children():
		var t := _hinweis(kind)
		if t != "":
			return t
	return ""

func _zeige_baum(k: Node, tiefe: int, max_tiefe: int) -> void:
	if not (k is Control) or tiefe > max_tiefe:
		return
	var c := k as Control
	var mb: float = c.get_combined_minimum_size().x
	if mb > 900.0 or tiefe <= 1:
		_log("%s%s  min %.0f  ist %.0f   [%s]" % ["    ".repeat(tiefe), c.get_class(), mb, c.size.x, _hinweis(c)])
	for kind in c.get_children():
		_zeige_baum(kind, tiefe + 1, max_tiefe)
