class_name Szenenleiste
extends Control
## Die Zeitleiste der Schlüsselszenen einer Partie.
##
## Eine Liste von sieben Zeilen sagt, *was* passiert ist. Diese Leiste sagt
## zusätzlich *wann* — und das ist die halbe Geschichte: drei Szenen in den
## letzten sechs Minuten sind ein Krimi, drei in den ersten zehn eine frühe
## Entscheidung. Man sieht die Form des Spiels, bevor man ein Wort liest.
##
## Jede Szene ist ein Punkt auf der Minutenachse, oben die Heimseite, unten
## die Gastseite. Ein Klick wählt sie aus; die Auswahl wird als Signal
## gemeldet, die Darstellung der Einzelheiten liegt beim Bericht.

signal szene_gewaehlt(index: int)

const SPIELZEIT := 3600.0
const HOEHE := 88.0
const PUNKT := 6.0

var szenen: Array = []
var gewaehlt: int = -1
var heim_farbe: Color = Stil.AKZENT
var gast_farbe: Color = Stil.BLAU

func _init() -> void:
	custom_minimum_size = Vector2(0, HOEHE)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setze(neue: Array) -> void:
	szenen = neue
	gewaehlt = -1
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var treffer := _treffer((e as InputEventMouseButton).position)
	if treffer >= 0:
		gewaehlt = treffer
		queue_redraw()
		szene_gewaehlt.emit(treffer)

func _treffer(punkt: Vector2) -> int:
	for i in range(szenen.size()):
		if _punkt_von(i).distance_to(punkt) <= PUNKT * 2.4:
			return i
	return -1

func _punkt_von(i: int) -> Vector2:
	var s: Dictionary = szenen[i]
	var t: float = clampf(float(s.get("zeit", 0.0)) / SPIELZEIT, 0.0, 1.0)
	var x: float = 12.0 + t * maxf(size.x - 24.0, 1.0)
	# Heim oben, Gast unten. Szenen ohne Seite (Halbzeit, Auszeit) sitzen
	# genau auf der Achse.
	var seite: String = str(s.get("team", ""))
	var y: float = (size.y - 14.0) * 0.5
	if seite == "heim":
		y -= 16.0
	elif seite == "gast":
		y += 16.0
	return Vector2(x, y)

func _draw() -> void:
	var mitte: float = (size.y - 14.0) * 0.5
	# Die Achse mit Minutenmarken. Alle zehn Minuten ein Strich — mehr wäre
	# ein Lineal, weniger keine Orientierung.
	draw_line(Vector2(12, mitte), Vector2(size.x - 12, mitte), Stil.RAND_HELL, 1.0)
	# Die Minutenbeschriftung steht ganz unten, nicht direkt unter der Achse:
	# dort sitzen die Punkte der Gastmannschaft und würden sie überdecken.
	var schrift := ThemeDB.fallback_font
	for m in range(0, 61, 10):
		var x: float = 12.0 + float(m) / 60.0 * maxf(size.x - 24.0, 1.0)
		draw_line(Vector2(x, mitte - 4), Vector2(x, mitte + 4), Stil.RAND_HELL, 1.0)
		draw_string(schrift, Vector2(x - 8, size.y - 2), "%d'" % m,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Stil.TEXT_SCHWACH)
	# Halbzeitmarke: sie teilt die Geschichte in zwei Hälften, das darf man
	# sehen.
	var hz: float = 12.0 + 0.5 * maxf(size.x - 24.0, 1.0)
	draw_line(Vector2(hz, 4), Vector2(hz, size.y - 16), Stil.RAND, 1.0)
	for i in range(szenen.size()):
		var s: Dictionary = szenen[i]
		var p := _punkt_von(i)
		var f := _farbe(s)
		draw_line(Vector2(p.x, mitte), p, f.lerp(Stil.GRUND, 0.45), 1.0)
		var r: float = PUNKT * (1.45 if i == gewaehlt else 1.0)
		if i == gewaehlt:
			draw_circle(p, r + 3.5, Color(f.r, f.g, f.b, 0.25))
		draw_circle(p, r, f)
		draw_arc(p, r, 0.0, TAU, 18, Stil.GRUND.lerp(f, 0.35), 1.4, true)

func _farbe(s: Dictionary) -> Color:
	match str(s.get("typ", "")):
		"tor":
			return Stil.GELB if bool(s.get("siebenmeter", false)) else Stil.GRUEN
		"parade": return Stil.TUERKIS
		"zeitstrafe": return Stil.GELB
		"rot": return Stil.ROT
		"lauf": return Stil.AKZENT
		"verletzung": return Stil.ROT
		"auszeit": return Stil.LILA
	return Stil.BLAU
