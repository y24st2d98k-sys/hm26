extends Node
## Sucht Layoutfehler automatisch, statt sie auf Bildschirmfotos zu suchen.
##
## Ein abgeschnittener Text fällt auf einem Screenshot nur auf, wenn man
## genau hinsieht — und bei fünfundzwanzig Bildschirmen sieht irgendwann
## niemand mehr genau hin. Dieses Werkzeug geht jeden Bildschirm durch,
## vermisst jeden Knoten und meldet drei Dinge:
##
##   * Inhalt, der über den sichtbaren Bereich hinausragt
##   * Beschriftungen, die breiter sind als ihr Platz (also abgeschnitten)
##   * Knöpfe, die zu klein zum Treffen sind
##
## Aufruf: godot --headless res://werkzeuge/Layoutpruefung.tscn

## Mindestgröße einer anklickbaren Fläche. Alles darunter trifft man nicht
## zuverlässig — auch nicht mit der Maus.
const KLICKFLAECHE_MIN := 22.0  # etwas unter Stil.KLICKFLAECHE_MIN, damit Rundung nicht meldet

## Wie viel Überstand als Rundungsrest durchgeht.
const TOLERANZ := 1.5

var fehler: int = 0
var warnungen: int = 0

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var welt := Weltgenerator.erzeuge(2026, 90909)
	var cid: String = str(welt["ligen"]["l_de1"]["vereine"][0])
	Welt.neues_spiel(cid, {"vorname": "Lay", "nachname": "Out",
		"hintergrund": "spieler", "nation": "de", "alter": 45}, 90909)
	# Ein Stück Saison spielen, damit die Bildschirme echte Inhalte zeigen:
	# eine leere Tabelle hat noch nie ein Layout gesprengt.
	for i in range(90):
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
	_log("Geprüft am %s" % Welt.datum_text())

	get_window().size = Vector2i(1680, 945)
	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)
	await get_tree().process_frame

	var breite: float = float(get_window().size.x)
	for id in app.bildschirme.keys():
		app.zeige(str(id))
		app.bewegung_beenden()
		# Zwei Bilder abwarten: Container brauchen einen Durchlauf, um ihre
		# Kinder zu setzen, und einen zweiten für verschachtelte Container.
		await get_tree().process_frame
		await get_tree().process_frame
		var befunde: Array = []
		_pruefe(app.bildschirme[id], breite, befunde)
		if befunde.is_empty():
			continue
		_log("")
		_log("— %s —" % str(id))
		for b in befunde.slice(0, 8):
			_log("   %s" % str(b))
		if befunde.size() > 8:
			_log("   … und %d weitere" % (befunde.size() - 8))

	_log("")
	_log("%d Layoutfehler, %d Hinweise." % [fehler, warnungen])
	get_tree().quit()

func _pruefe(knoten: Node, fensterbreite: float, befunde: Array) -> void:
	for kind in knoten.get_children():
		if kind is Control and kind.visible:
			_pruefe_control(kind, fensterbreite, befunde)
		_pruefe(kind, fensterbreite, befunde)

func _pruefe_control(c: Control, fensterbreite: float, befunde: Array) -> void:
	var rechts: float = c.global_position.x + c.size.x
	# Überstand nach rechts: der Inhalt ist außerhalb des Fensters.
	if rechts > fensterbreite + TOLERANZ and c.size.x > 4.0:
		fehler += 1
		befunde.append("FEHLER  ragt %d px über den rechten Rand: %s" % [
			int(rechts - fensterbreite), _beschreibe(c)])
	# Abgeschnittene Beschriftung.
	if c is Label:
		var l: Label = c
		if l.text.strip_edges() != "" and l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var noetig: float = l.get_theme_font("font").get_string_size(
				l.text, l.horizontal_alignment, -1, l.get_theme_font_size("font_size")).x
			if noetig > l.size.x + TOLERANZ:
				if l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
					warnungen += 1
					befunde.append("Hinweis abgeschnitten (bewusst): „%s“" % _kurz(l.text))
				else:
					fehler += 1
					befunde.append("FEHLER  Text passt nicht (%d von %d px): „%s“" % [
						int(l.size.x), int(noetig), _kurz(l.text)])
	# Zu kleine Klickfläche.
	if c is Button and c.visible and not c.disabled:
		if c.size.y > 0.5 and c.size.y < KLICKFLAECHE_MIN:
			warnungen += 1
			befunde.append("Hinweis Klickfläche nur %d px hoch: „%s“" % [int(c.size.y), _kurz(c.text)])

func _beschreibe(c: Control) -> String:
	if c is Label:
		return "Label „%s“" % _kurz((c as Label).text)
	if c is Button:
		return "Knopf „%s“" % _kurz((c as Button).text)
	return c.get_class()

func _kurz(t: String) -> String:
	var eine_zeile := t.replace("\n", " ")
	return eine_zeile if eine_zeile.length() <= 42 else eine_zeile.substr(0, 40) + "…"
