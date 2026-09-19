extends Node
## Wie hoch ist eigentlich jede einzelne Zeile?
##
## Die Hoehensonde sagt, dass ein Bildschirm zu hoch ist, und nennt den
## groessten Abschnitt darin. Wenn der aus vierzehn gleichen Zeilen besteht,
## hilft das nicht weiter: man will wissen, was eine Zeile hoch macht, bevor
## man daran dreht. Diese Sonde geht einen Bildschirm Ebene fuer Ebene durch
## und schreibt Mindesthoehe und Mindestbreite jedes Knotens auf.
##
## Aufruf: godot res://werkzeuge/Zeilensonde.tscn -- <bildschirm> [reiter] [tiefe]

const FENSTER := Vector2i(1680, 945)

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	get_window().size = FENSTER
	await get_tree().process_frame
	var vorschau := Weltgenerator.erzeuge(2026, 424242)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	# Der Spielplan mischt mit dem globalen Zufallsgenerator. Ohne feste Saat
	# misst jeder Lauf eine andere Welt, und ein Vergleich vorher/nachher
	# zeigt Unterschiede, die keine sind.
	seed(424242)
	Welt.neues_spiel(cid, {"vorname": "Mira", "nachname": "Halden",
		"hintergrund": "nachwuchs", "nation": "de", "alter": 41}, 424242)
	for i in 60:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)

	var args: Array = OS.get_cmdline_user_args()
	var id: String = str(args[0]) if args.size() > 0 else "taktik"
	var reiter: String = str(args[1]) if args.size() > 1 else ""
	var tiefe: int = int(args[2]) if args.size() > 2 else 6
	app.zeige(id)
	await get_tree().process_frame
	await get_tree().process_frame
	var b: Node = app.bildschirme[id]
	if reiter != "":
		var gruppe := _reiter_finden(b)
		if gruppe != null:
			gruppe.zeige(reiter)
			await get_tree().process_frame
			await get_tree().process_frame
	_log("")
	_log("=== %s%s — Mindestmasse je Knoten ===" % [id, (" · " + reiter) if reiter != "" else ""])
	_zeige(b, 0, tiefe)
	get_tree().quit()

func _zeige(k: Node, stufe: int, max_stufe: int) -> void:
	if not (k is Control) or stufe > max_stufe:
		return
	var c := k as Control
	if not c.visible:
		return
	var m := c.get_combined_minimum_size()
	_log("%s%-18s  h %4d  b %4d   %s" % ["  ".repeat(stufe), c.get_class(),
		int(m.y), int(m.x), _hinweis(c)])
	for kind in c.get_children():
		_zeige(kind, stufe + 1, max_stufe)

func _reiter_finden(k: Node) -> Stil.Reitergruppe:
	if k is Stil.Reitergruppe:
		return k as Stil.Reitergruppe
	for kind in k.get_children():
		var t := _reiter_finden(kind)
		if t != null:
			return t
	return null

func _hinweis(c: Node) -> String:
	if c is Label:
		return (c as Label).text.substr(0, 26)
	if c is Button and str((c as Button).text) != "":
		return (c as Button).text.substr(0, 26)
	if c is OptionButton:
		return "[Auswahl]"
	for kind in c.get_children():
		var t := _hinweis(kind)
		if t != "":
			return t
	return ""
