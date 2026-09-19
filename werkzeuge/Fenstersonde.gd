extends Node
## Welches Fenster passt nicht in sein Fenster?
##
## Die Hoehensonde misst die Bildschirme. Die Fenster, die darüber aufgehen —
## Spielerprofil, Spielbericht, Vorbericht — sind aber die Stellen, an denen
## man im Spiel am häufigsten liest. Ein Rollbalken darin ist genauso teuer:
## man verliert den Überblick, den man gerade aufgebaut hat. Diese Sonde öffnet
## jedes Fenster mit einem plausiblen Gegenstand und meldet, wie viel von
## seinem Inhalt über den Rand hinausläuft.

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
	await get_tree().process_frame

	var mid := ""
	for m in Welt.daten["spiele"].keys():
		var p: Dictionary = Welt.daten["spiele"][m]
		if bool(p["gespielt"]) and (str(p["heim"]) == Welt.mein_verein_id or str(p["gast"]) == Welt.mein_verein_id):
			mid = str(m)
	var naechste := ""
	var gegner := ""
	for m2 in Welt.daten["spiele"].keys():
		var p2: Dictionary = Welt.daten["spiele"][m2]
		if bool(p2["gespielt"]):
			continue
		if str(p2["heim"]) == Welt.mein_verein_id or str(p2["gast"]) == Welt.mein_verein_id:
			naechste = str(m2)
			gegner = str(p2["gast"]) if str(p2["heim"]) == Welt.mein_verein_id else str(p2["heim"])
			break
	var sid: String = str(Welt.kader(Welt.mein_verein_id)[0])
	var nachrichten: Array = Welt.daten.get("nachrichten", [])

	_log("")
	_log("=== Wie viel muss in den Fenstern gescrollt werden? (%d x %d) ===" % [FENSTER.x, FENSTER.y])
	_log("")
	_log("%-20s %8s %8s %9s %8s   %s" % ["Fenster", "Inhalt", "Sicht", "Ueberhang", "Breite", "groesster Posten"])
	var summe := 0
	var gezaehlt := 0
	for fall in [
			{"gruppe": "spielerfenster", "ruf": func(f): f.zeige(sid)},
			{"gruppe": "vereinsfenster", "ruf": func(f): f.zeige(Welt.mein_verein_id)},
			{"gruppe": "spielbericht", "ruf": func(f): f.zeige(mid)},
			{"gruppe": "vorberichtsfenster", "ruf": func(f): f.zeige(gegner, naechste)},
			{"gruppe": "nachberichtsfenster", "ruf": func(f): f.zeige(mid)},
			{"gruppe": "anpfifffenster", "ruf": func(f): f.zeige(naechste)},
			{"gruppe": "nachrichtenfenster", "ruf": func(f):
				if not nachrichten.is_empty():
					f.zeige(nachrichten[0])},
			{"gruppe": "vorspulfenster", "ruf": func(f): f.zeige()},
		]:
		var name: String = str((fall as Dictionary)["gruppe"])
		var f: Node = get_tree().get_first_node_in_group(name)
		if f == null:
			_log("%-20s  — nicht vorhanden" % name)
			continue
		((fall as Dictionary)["ruf"] as Callable).call(f)
		await get_tree().process_frame
		await get_tree().process_frame
		if not (f as Control).visible:
			_log("%-20s  — liess sich nicht oeffnen" % name)
			continue
		var gruppe := _reiter_finden(f)
		var hoechster := 0.0
		var sicht := 0.0
		var posten := ""
		var zu_breit := 0
		if gruppe != null:
			for o in gruppe.optionen:
				gruppe.zeige(str((o as Dictionary)["id"]))
				await get_tree().process_frame
				await get_tree().process_frame
				var messung := _messen(f)
				zu_breit = maxi(zu_breit, int(messung["zu_breit"]))
				if float(messung["inhalt"]) > hoechster:
					hoechster = float(messung["inhalt"])
					sicht = float(messung["sicht"])
					posten = str(messung["posten"])
		else:
			var messung2 := _messen(f)
			hoechster = float(messung2["inhalt"])
			sicht = float(messung2["sicht"])
			posten = str(messung2["posten"])
			zu_breit = int(messung2["zu_breit"])
		var ueber: int = int(maxf(hoechster - sicht, 0.0))
		gezaehlt += 1
		if ueber > 0:
			summe += 1
		_log("%-20s %8d %8d %9s %8s   %s" % [name + (" *" if gruppe != null else ""),
			int(hoechster), int(sicht), ("+%d" % ueber) if ueber > 0 else "passt",
			("+%d" % zu_breit) if zu_breit > 0 else "passt", posten])
		(f as Control).visible = false
		await get_tree().process_frame
	_log("")
	_log("%d von %d Fenstern laufen ueber." % [summe, gezaehlt])
	get_tree().quit()

## Inhaltshoehe, Sichthoehe und groesster Posten eines Fensters.
func _messen(f: Node) -> Dictionary:
	var rolle := _rolle_finden(f)
	if rolle == null:
		return {"inhalt": 0.0, "sicht": 0.0, "zu_breit": 0, "posten": "(ohne Rollbereich)"}
	var hoch := 0.0
	# Waagerecht wird nicht gerollt: was breiter ist als der Bereich, ist
	# abgeschnitten und damit unsichtbar — schlimmer als ein Rollbalken.
	var breit := 0.0
	for k in rolle.get_children():
		if k is Control:
			hoch = maxf(hoch, (k as Control).get_combined_minimum_size().y)
			breit = maxf(breit, (k as Control).get_combined_minimum_size().x)
	return {"inhalt": hoch, "sicht": rolle.size.y,
		"zu_breit": int(maxf(breit - rolle.size.x, 0.0)), "posten": _groesster(rolle)}

func _reiter_finden(k: Node) -> Stil.Reitergruppe:
	if k is Stil.Reitergruppe:
		return k as Stil.Reitergruppe
	for kind in k.get_children():
		var t := _reiter_finden(kind)
		if t != null:
			return t
	return null

## Nur sichtbare Rollbereiche zaehlen: ein Fenster mit Reitern haelt fuer jeden
## einen eigenen, und die ausgeblendeten sagen nichts ueber die Lage aus.
func _rolle_finden(k: Node) -> ScrollContainer:
	# Gesucht ist der Rollbereich, der die freie Hoehe besitzt — der also
	# waechst, wenn das Fenster waechst. Erst nach innen sehen: liegt in einem
	# Rollbereich noch einer, weil ein Reiter seinen eigenen mitbringt, zaehlt
	# der innere; der aeussere rollt dann ohnehin nicht.
	var t := _rolle_suchen(k, true)
	if t != null:
		return t
	# Kein dehnbarer dabei: dann zaehlt eben irgendeiner.
	return _rolle_suchen(k, false)

## Eine Liste mit fester Hoehe (etwa der Ticker im Spielbericht) rollt
## absichtlich und ist kein Befund: sie waechst nicht mit dem Fenster.
func _rolle_suchen(k: Node, nur_dehnbar: bool) -> ScrollContainer:
	for kind in k.get_children():
		if kind is Control and not (kind as Control).visible:
			continue
		var t := _rolle_suchen(kind, nur_dehnbar)
		if t != null:
			return t
	if k is ScrollContainer and (k as Control).visible:
		var dehnbar: bool = ((k as Control).size_flags_vertical & Control.SIZE_EXPAND) != 0
		if dehnbar or not nur_dehnbar:
			return k as ScrollContainer
	return null

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
