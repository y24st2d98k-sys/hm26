class_name Menueband
extends PanelContainer
## Die Navigation als schmales Band über dem Inhalt.
##
## Vorher stand sie links: vierundzwanzig Einträge untereinander, alle
## gleichzeitig sichtbar, zweihundertachtunddreißig Pixel breit. Wer das Spiel
## kennt, findet darin alles; wer es zum ersten Mal sieht, sieht vor allem
## vierundzwanzig Einträge. Oben sind es sechs Knöpfe, hinter denen dasselbe
## liegt — und der Inhalt bekommt die Breite dazu.
##
## Die Zahlen bleiben sichtbar, ohne dass man ein Menü öffnen muss: eine
## offene Sache färbt den Gruppenknopf und steht als Zahl daneben. Sonst wäre
## die Aufräumaktion damit bezahlt, dass man nicht mehr sieht, was ansteht.

signal gewaehlt(id: String)

## Aufbau: [{"name": "Mannschaft", "eintraege": [{"id":…, "name":…}], "direkt": bool}]
var gruppen: Array = []
var aktiv: String = ""

var _leiste: HBoxContainer
var _knoepfe: Dictionary = {}     # Gruppenname -> Button
var _menues: Dictionary = {}      # Gruppenname -> PopupMenu
var _marken: Dictionary = {}      # Gruppenname -> Label (die Zahl am Knopf)
var _zaehler: Dictionary = {}     # Bildschirmkennung -> Zahl
var _gruppe_von: Dictionary = {}  # Bildschirmkennung -> Gruppenname
var _name_von: Dictionary = {}    # Bildschirmkennung -> Anzeigename

func _init() -> void:
	var box := Stil.box(Stil.FLAECHE, 0)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	box.border_color = Stil.RAND
	box.border_width_bottom = 1
	add_theme_stylebox_override("panel", box)

## Baut das Band. Rechts kann ein eigener Bereich mitlaufen (die Trainerzeile).
func aufbauen(neue_gruppen: Array) -> Control:
	gruppen = neue_gruppen
	_leiste = Stil.hbox(2)
	add_child(_leiste)
	for g in gruppen:
		var gruppe: Dictionary = g
		var name: String = str(gruppe["name"])
		var eintraege: Array = gruppe["eintraege"]
		for e in eintraege:
			var ein: Dictionary = e
			_gruppe_von[str(ein["id"])] = name
			_name_von[str(ein["id"])] = str(ein["name"])
		var knopf := _gruppenknopf(name, eintraege.size() == 1)
		_leiste.add_child(knopf)
		_knoepfe[name] = knopf
		if eintraege.size() == 1:
			var einzel: String = str((eintraege[0] as Dictionary)["id"])
			knopf.pressed.connect(func(): gewaehlt.emit(einzel))
			continue
		var menue := _menue(name, eintraege)
		add_child(menue)
		_menues[name] = menue
		knopf.pressed.connect(func(): _oeffne(name))
	_leiste.add_child(Stil.dehner())
	var rechts := Stil.hbox(9)
	rechts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_leiste.add_child(rechts)
	return rechts

## Ein Gruppenknopf: Name, bei Gruppen ein Pfeil, dazu Platz für die Zahl.
func _gruppenknopf(name: String, einzeln: bool) -> Button:
	var b := Button.new()
	b.text = name if einzeln else name + "  ⌄"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 32)
	_stil_setzen(b, false)
	var marke := Stil.text("", Stil.S_MINI, Stil.SIGNAL)
	marke.add_theme_font_override("font", Stil.schnitt_fett())
	marke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marke.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	marke.offset_left = -22.0
	marke.offset_right = -6.0
	marke.offset_top = 3.0
	marke.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(marke)
	_marken[name] = marke
	return b

func _stil_setzen(b: Button, hervorgehoben: bool) -> void:
	var ruhe: StyleBox = Stil.box(Stil.AKZENT, Stil.R_KLEIN) if hervorgehoben else Stil.box_leer()
	if ruhe is StyleBoxFlat:
		(ruhe as StyleBoxFlat).content_margin_left = 13
		(ruhe as StyleBoxFlat).content_margin_right = 13
	b.add_theme_stylebox_override("normal", ruhe)
	b.add_theme_stylebox_override("hover", Stil.box(
		Stil.AKZENT if hervorgehoben else Stil.lasur(Stil.TEXT, 0.08), Stil.R_KLEIN))
	b.add_theme_stylebox_override("pressed", Stil.box(Stil.lasur(Stil.AKZENT, 0.30), Stil.R_KLEIN))
	b.add_theme_stylebox_override("focus", Stil.box_leer())
	b.add_theme_color_override("font_color", Color.WHITE if hervorgehoben else Stil.TEXT_MATT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_font_override("font", Stil.schnitt_halbfett() if hervorgehoben else Stil.grundschrift())
	b.add_theme_font_size_override("font_size", Stil.S_KLEIN)

func _menue(name: String, eintraege: Array) -> PopupMenu:
	var m := PopupMenu.new()
	m.set_meta("gruppe", name)
	for i in range(eintraege.size()):
		var ein: Dictionary = eintraege[i]
		m.add_item(str(ein["name"]), i)
		m.set_item_metadata(i, str(ein["id"]))
	m.id_pressed.connect(func(i):
		gewaehlt.emit(str(m.get_item_metadata(i))))
	return m

func _oeffne(name: String) -> void:
	var m: PopupMenu = _menues[name]
	var b: Button = _knoepfe[name]
	var ecke: Vector2 = b.get_screen_position() + Vector2(0.0, b.size.y + 4.0)
	m.reset_size()
	m.position = Vector2i(ecke)
	m.popup()

## Welcher Bildschirm gerade offen ist. Der Knopf seiner Gruppe wird gefüllt
## und nennt ihn beim Namen — sonst sieht man der Leiste nicht an, wo man ist.
func setze_aktiv(id: String) -> void:
	aktiv = id
	for g in gruppen:
		var gruppe: Dictionary = g
		var name: String = str(gruppe["name"])
		var knopf: Button = _knoepfe[name]
		var eigen: bool = str(_gruppe_von.get(id, "")) == name
		var einzeln: bool = (gruppe["eintraege"] as Array).size() == 1
		if eigen and not einzeln:
			knopf.text = "%s · %s  ⌄" % [name, str(_name_von.get(id, ""))]
		else:
			knopf.text = name if einzeln else name + "  ⌄"
		_stil_setzen(knopf, eigen)

## Die Zahl an einem Bildschirm — sie summiert sich am Knopf seiner Gruppe.
func setze_zaehler(id: String, wert: int) -> void:
	_zaehler[id] = wert
	_marken_auffrischen()
	_menues_auffrischen()

func _marken_auffrischen() -> void:
	for g in gruppen:
		var gruppe: Dictionary = g
		var name: String = str(gruppe["name"])
		var summe := 0
		for e in (gruppe["eintraege"] as Array):
			summe += int(_zaehler.get(str((e as Dictionary)["id"]), 0))
		var marke: Label = _marken[name]
		marke.text = "%d" % summe if summe > 0 else ""

## Im Menü steht die Zahl hinter dem Eintrag: "Kabine (1)".
func _menues_auffrischen() -> void:
	for name in _menues.keys():
		var m: PopupMenu = _menues[name]
		for i in range(m.item_count):
			var id: String = str(m.get_item_metadata(i))
			var anzahl: int = int(_zaehler.get(id, 0))
			var klar: String = str(_name_von.get(id, id))
			m.set_item_text(i, "%s  (%d)" % [klar, anzahl] if anzahl > 0 else klar)

## Hinweisfenster eines Eintrags — die Gruppe erbt den Text, damit die Zahl am
## Knopf erklärt ist, ohne dass man das Menü öffnen muss.
func setze_hinweis(id: String, text: String) -> void:
	var name: String = str(_gruppe_von.get(id, ""))
	if name != "" and _knoepfe.has(name):
		(_knoepfe[name] as Button).tooltip_text = text
