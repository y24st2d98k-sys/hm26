extends Node
## Welcher Bildschirm passt nicht auf den Schirm?
##
## Scrollen ist die teuerste Bedienhandlung, die eine Oberflaeche verlangen
## kann: man verliert den Ueberblick, den man gerade aufgebaut hat. Diese Sonde
## misst fuer jeden Bildschirm, wie hoch sein Inhalt wirklich ist und wie viel
## davon ins Fenster passt — und nennt den groessten Brocken darin, damit man
## weiss, wo man ansetzt.

## Die Fenstergroesse laesst sich uebergeben: "1500 940" misst in der Groesse,
## in der das Spiel tatsaechlich startet, nicht in der, die gerade am Schirm
## haengt. Beides gehoert geprueft — ein Kaeufer sieht zuerst die Startgroesse.
var FENSTER := Vector2i(1680, 945)

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

	var liste: Array = OS.get_cmdline_user_args()
	if liste.size() >= 2 and str(liste[0]).is_valid_int() and str(liste[1]).is_valid_int():
		FENSTER = Vector2i(int(liste[0]), int(liste[1]))
		get_window().size = FENSTER
		await get_tree().process_frame
		liste = liste.slice(2)
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
		# Ein Bildschirm mit Reitern hat so viele Lagen, wie er Reiter hat.
		# Gemessen wird die schlechteste — sonst meldet die Sonde "passt",
		# weil zufaellig der kuerzeste Reiter offen stand.
		var gruppe := _reiter_finden(b)
		var reiterzeilen: Array = []
		if gruppe != null:
			var schlimmster := ""
			var hoechster := 0.0
			for o in gruppe.optionen:
				gruppe.zeige(str((o as Dictionary)["id"]))
				await get_tree().process_frame
				await get_tree().process_frame
				var h: float = _inhaltshoehe(b)
				# Je Reiter eine Zeile, wenn der Bildschirm ueberlaeuft: sonst
				# weiss man, dass etwas zu hoch ist, aber nicht welcher Teil.
				reiterzeilen.append("%s %d" % [str((o as Dictionary)["id"]), int(h)])
				if h > hoechster:
					hoechster = h
					schlimmster = str((o as Dictionary)["id"])
			if schlimmster != "":
				gruppe.zeige(schlimmster)
				await get_tree().process_frame
				await get_tree().process_frame
		var rolle := _rolle_finden(b)
		var inhalt: float = 0.0
		var sicht: float = 0.0
		if rolle == null:
			# Kein Rollbereich: dann zaehlt, ob der Bildschirm selbst passt.
			# Die Bildschirmwurzel ist ein nacktes Control und meldet null.
			# Gemessen wird ihr Aufbau — die erste echte Spalte darin.
			for k in (b as Control).get_children():
				if k is Control:
					inhalt = maxf(inhalt, (k as Control).get_combined_minimum_size().y)
			sicht = (b as Control).size.y
		else:
			for k in rolle.get_children():
				if k is Control:
					inhalt = maxf(inhalt, (k as Control).get_combined_minimum_size().y)
			sicht = rolle.size.y
		var ueber: int = int(maxf(inhalt - sicht, 0.0))
		if ueber > 0:
			summe += 1
		_log("%-16s %8d %8d %9s   %s" % [str(id) + (" *" if gruppe != null else ""), int(inhalt), int(sicht),
			("+%d" % ueber) if ueber > 0 else "passt",
			_groesster(rolle) if rolle != null else "(ohne Rollbereich)"])
		if ueber > 0 and not reiterzeilen.is_empty():
			_log("%-16s je Reiter: %s" % ["", ", ".join(reiterzeilen)])
	_log("")
	_log("%d von %d Bildschirmen laufen ueber." % [summe, liste.size()])
	get_tree().quit()

## Die Inhaltshoehe eines Bildschirms in seiner aktuellen Lage.
func _inhaltshoehe(b: Node) -> float:
	var rolle := _rolle_finden(b)
	var hoch := 0.0
	if rolle != null:
		for k in rolle.get_children():
			if k is Control:
				hoch = maxf(hoch, (k as Control).get_combined_minimum_size().y)
		return hoch
	for k in (b as Control).get_children():
		if k is Control:
			hoch = maxf(hoch, (k as Control).get_combined_minimum_size().y)
	return hoch

func _reiter_finden(k: Node) -> Stil.Reitergruppe:
	if k is Stil.Reitergruppe:
		return k as Stil.Reitergruppe
	for kind in k.get_children():
		var t := _reiter_finden(kind)
		if t != null:
			return t
	return null

## Der Rollbereich eines Bildschirms. Jeder Bildschirm hat hoechstens einen.
func _rolle_finden(k: Node) -> ScrollContainer:
	# Nur sichtbare Bereiche zaehlen: ein Bildschirm mit Reitern haelt fuer
	# jeden Reiter einen eigenen, und die ausgeblendeten sagen nichts darueber,
	# was der Nutzer gerade vor sich hat.
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
