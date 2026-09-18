extends Node
## Welcher Bildschirm passt nicht auf den Schirm?
##
## Scrollen ist die teuerste Bedienhandlung, die eine Oberflaeche verlangen
## kann: man verliert den Ueberblick, den man gerade aufgebaut hat. Diese Sonde
## misst fuer jeden Bildschirm, wie hoch sein Inhalt wirklich ist und wie viel
## davon ins Fenster passt — und nennt den groessten Brocken darin, damit man
## weiss, wo man ansetzt.

const FENSTER := Vector2i(1680, 945)

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	get_window().size = FENSTER
	await get_tree().process_frame
	var vorschau := Weltgenerator.erzeuge(2026, 424242)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	Welt.neues_spiel(cid, {"vorname": "Mira", "nachname": "Halden",
		"hintergrund": "nachwuchs", "nation": "de", "alter": 41}, 424242)
	for i in 120:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)

	var liste: Array = OS.get_cmdline_user_args()
	if liste.is_empty():
		liste = (app.bildschirme as Dictionary).keys()
		liste.sort()
	_log("")
	_log("=== Wie viel muss gescrollt werden? (Fenster %d x %d) ===" % [FENSTER.x, FENSTER.y])
	_log("")
	_log("%-16s %8s %8s %9s   %s" % ["Bildschirm", "Inhalt", "Fenster", "Ueberhang", "groesster Posten"])
	var summe := 0
	for id in liste:
		app.zeige(str(id))
		await get_tree().process_frame
		await get_tree().process_frame
		var b: Node = app.bildschirme[str(id)]
		var rolle := _rolle_finden(b)
		if rolle == null:
			_log("%-16s %8s" % [str(id), "—"])
			continue
		var inhalt: float = 0.0
		for k in rolle.get_children():
			if k is Control:
				inhalt = maxf(inhalt, (k as Control).get_combined_minimum_size().y)
		var sicht: float = rolle.size.y
		var ueber: int = int(maxf(inhalt - sicht, 0.0))
		if ueber > 0:
			summe += 1
		_log("%-16s %8d %8d %9s   %s" % [str(id), int(inhalt), int(sicht),
			("+%d" % ueber) if ueber > 0 else "passt", _groesster(rolle)])
	_log("")
	_log("%d von %d Bildschirmen laufen ueber." % [summe, liste.size()])
	get_tree().quit()

## Der Rollbereich eines Bildschirms. Jeder Bildschirm hat hoechstens einen.
func _rolle_finden(k: Node) -> ScrollContainer:
	if k is ScrollContainer:
		return k as ScrollContainer
	for kind in k.get_children():
		var t := _rolle_finden(kind)
		if t != null:
			return t
	return null

## Welcher direkte Abschnitt im Rollbereich die meiste Hoehe verlangt.
func _groesster(rolle: ScrollContainer) -> String:
	var best := ""
	var hoch := 0.0
	for k in rolle.get_children():
		if not (k is Control):
			continue
		for abschnitt in (k as Control).get_children():
			if not (abschnitt is Control):
				continue
			var h: float = (abschnitt as Control).get_combined_minimum_size().y
			if h > hoch:
				hoch = h
				best = "%s %d px [%s]" % [(abschnitt as Control).get_class(), int(h), _hinweis(abschnitt)]
	return best

func _hinweis(c: Node) -> String:
	if c is Label:
		return (c as Label).text.substr(0, 24)
	if c is Button and str((c as Button).text) != "":
		return (c as Button).text.substr(0, 24)
	for kind in c.get_children():
		var t := _hinweis(kind)
		if t != "":
			return t
	return ""
