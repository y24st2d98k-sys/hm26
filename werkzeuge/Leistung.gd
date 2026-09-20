extends Node
## Misst, wo Zeit verloren geht: Tageswechsel, Bildschirmaufbau, Speichern.
##
## Ein Managerspiel darf nicht ruckeln, wenn man auf "Weiter" drückt. Diese
## Szene beziffert, was jeder Schritt kostet — damit Optimierung eine Messung
## und keine Vermutung ist.
## Aufruf: godot --headless res://werkzeuge/Leistung.tscn

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var welt := Weltgenerator.erzeuge(2026, 20260913)
	var cid: String = str(welt["ligen"]["l_de1"]["vereine"][0])
	var start := Time.get_ticks_msec()
	Welt.neues_spiel(cid, {"vorname": "Leis", "nachname": "Tung",
		"hintergrund": "spieler", "nation": "de", "alter": 44}, 20260913)
	_log("Neues Spiel anlegen: %d ms" % (Time.get_ticks_msec() - start))
	# Der Spielstand am ersten Tag als Bezugsgroesse: waechst er im Lauf einer
	# Saison stark, liegt es an den Partien; ist er von Anfang an gross, an
	# der Welt selbst. Ohne beide Zahlen raet man.
	var t_erst := Time.get_ticks_msec()
	Welt.speichern(9, "Leistungstest")
	_log("Speichern am ersten Tag: %d ms, %.1f MB" % [Time.get_ticks_msec() - t_erst,
		_slotgroesse() / 1048576.0])
	_log("Spieler in der Welt: %d, Vereine: %d" % [
		(Welt.daten["spieler"] as Dictionary).size(), (Welt.daten["vereine"] as Dictionary).size()])

	# --- Tageswechsel: der Knopf, den man am häufigsten drückt.
	var tage: Array = []
	var spieltage: Array = []
	for i in range(120):
		var t0 := Time.get_ticks_usec()
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
		Welt.spieltag_abwickeln(Welt.tag())
		Welt.wochenrhythmus(Welt.tag())
		Welt.saison_pruefen(Welt.tag())
		var dauer: float = float(Time.get_ticks_usec() - t0) / 1000.0
		tage.append(dauer)
		if dauer > 60.0:
			spieltage.append({"tag": Welt.tag(), "ms": dauer})
	_log("")
	_log("Tageswechsel über 120 Tage:")
	_kennzahlen(tage, "ms")
	_log("  Ausreißer über 60 ms: %d" % spieltage.size())
	for e in spieltage.slice(0, 6):
		_log("    Tag %d: %.1f ms" % [int(e["tag"]), float(e["ms"])])

	# --- Bildschirmaufbau: jeder Wechsel baut den Baum neu.
	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)
	await get_tree().process_frame
	_log("")
	_log("Bildschirmaufbau (aktualisieren, Mittel aus 3 Läufen):")
	var messwerte: Array = []
	for id in app.bildschirme.keys():
		var b = app.bildschirme[id]
		# Erst sichtbar schalten und ein Bild abwarten, dann messen: sonst
		# steckt der Umschaltvorgang mit in der Zahl.
		app.zeige(str(id))
		await get_tree().process_frame
		var summe := 0.0
		for _i in range(3):
			var t1 := Time.get_ticks_usec()
			b.aktualisieren()
			summe += float(Time.get_ticks_usec() - t1) / 1000.0
			await get_tree().process_frame
		messwerte.append({"id": str(id), "ms": summe / 3.0})
	messwerte.sort_custom(func(a, b): return float(a["ms"]) > float(b["ms"]))
	for m in messwerte:
		var marke := ""
		if float(m["ms"]) > 100.0:
			marke = "   << spürbar"
		elif float(m["ms"]) > 40.0:
			marke = "   < grenzwertig"
		_log("  %-16s %7.1f ms%s" % [str(m["id"]), float(m["ms"]), marke])

	# --- Speichern und Laden.
	var t2 := Time.get_ticks_msec()
	Welt.speichern(9, "Leistungstest")
	_log("")
	_log("Speichern: %d ms" % (Time.get_ticks_msec() - t2))
	var t3 := Time.get_ticks_msec()
	Welt.laden(9)
	_log("Laden: %d ms" % (Time.get_ticks_msec() - t3))
	_log("Spielstandgröße: %.1f MB" % (_slotgroesse() / 1048576.0))
	Welt.slot_loeschen(9)
	get_tree().quit()

func _kennzahlen(werte: Array, einheit: String) -> void:
	if werte.is_empty():
		return
	var sortiert: Array = werte.duplicate()
	sortiert.sort()
	var summe := 0.0
	for w in sortiert:
		summe += float(w)
	_log("  Mittel %.1f %s · Median %.1f %s · 95. Perzentil %.1f %s · Maximum %.1f %s" % [
		summe / float(sortiert.size()), einheit,
		float(sortiert[sortiert.size() / 2]), einheit,
		float(sortiert[mini(int(float(sortiert.size()) * 0.95), sortiert.size() - 1)]), einheit,
		float(sortiert[sortiert.size() - 1]), einheit])


func _slotgroesse() -> float:
	var f := FileAccess.open(Welt.slot_pfad(9), FileAccess.READ)
	if f == null:
		return 0.0
	var g: int = f.get_length()
	f.close()
	return float(g)
