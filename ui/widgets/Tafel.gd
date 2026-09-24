class_name Tafel
extends Control
## Das Register: alle Bildschirme auf einer Seite, aufgeschlagen statt aufgeklappt.
##
## Vorher hing die Navigation dauerhaft über dem Inhalt — erst als Seitenleiste
## mit vierundzwanzig Einträgen, dann als Menüband mit Aufklappknöpfen, dann als
## zwei Zeilen Reiter. Jede dieser Formen bezahlt denselben Preis: sie ist immer
## da, auch in den neunundneunzig Prozent der Zeit, in denen man nicht
## navigiert, und sie ist trotzdem zu klein, um mehr zu zeigen als Namen.
##
## Die Tafel dreht das um. Im Kopf steht nur, wo man gerade ist und was
## daneben liegt. Wer woanders hin will, schlägt einmal auf — und sieht dann
## nicht eine Liste, sondern die Lage: alle fünf Ressorts nebeneinander, jeder
## Bildschirm mit seiner Zahl, die zuletzt besuchten und die angehefteten oben.
## Was ein Menü nie konnte, kann eine Seite.

signal gewaehlt(id: String)
signal geschlossen()

var _spalten: HBoxContainer
var _zuletzt: HBoxContainer
var _ressorts: Array = []
var _zaehler: Dictionary = {}
var _aktiv: String = ""

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

func aufbauen(ressorts: Array) -> void:
	_ressorts = ressorts
	var grund := ColorRect.new()
	grund.color = Stil.GRUND
	grund.set_anchors_preset(Control.PRESET_FULL_RECT)
	grund.mouse_filter = Control.MOUSE_FILTER_STOP
	grund.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			schliessen())
	add_child(grund)

	var rand := MarginContainer.new()
	rand.set_anchors_preset(Control.PRESET_FULL_RECT)
	rand.add_theme_constant_override("margin_left", 48)
	rand.add_theme_constant_override("margin_right", 44)
	rand.add_theme_constant_override("margin_top", 30)
	rand.add_theme_constant_override("margin_bottom", 26)
	add_child(rand)
	var spalte := Stil.vbox(18)
	rand.add_child(spalte)

	var kopf := Stil.hbox(14)
	spalte.add_child(kopf)
	var wort := Stil.titel("Tafel", 0)
	kopf.add_child(wort)
	kopf.add_child(Stil.matt("Alles, was das Spiel zu bieten hat — auf einer Seite.", Stil.S_KLEIN))
	kopf.add_child(Stil.dehner())
	var zu := Stil.knopf_geist("Schließen (Tab)", Stil.TEXT_MATT)
	zu.pressed.connect(schliessen)
	kopf.add_child(zu)

	var linie := PanelContainer.new()
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Stil.TEXT
	linie.custom_minimum_size = Vector2(0, 2)
	linie.add_theme_stylebox_override("panel", lsb)
	spalte.add_child(linie)

	_zuletzt = Stil.hbox(10)
	spalte.add_child(_zuletzt)

	_spalten = Stil.hbox(26)
	_spalten.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spalte.add_child(_spalten)

	var fuss := Stil.matt(
		"Tastenkürzel: 1–0 für die zehn häufigsten Bildschirme · B K A T F N S Z J V M · Alt + ←/→ durch den Weg zurück",
		Stil.S_MINI)
	spalte.add_child(fuss)

func setze_zaehler(id: String, wert: int) -> void:
	_zaehler[id] = wert

func oeffnen(aktiv: String) -> void:
	_aktiv = aktiv
	_zeichnen()
	visible = true

func schliessen() -> void:
	visible = false
	geschlossen.emit()

func umschalten(aktiv: String) -> void:
	if visible:
		schliessen()
	else:
		oeffnen(aktiv)

# ------------------------------------------------------------------ Inhalt ---

func _zeichnen() -> void:
	for k in _spalten.get_children():
		_spalten.remove_child(k)
		k.queue_free()
	for k in _zuletzt.get_children():
		_zuletzt.remove_child(k)
		k.queue_free()

	var gemerkt: Array = Welt.lesezeichen()
	if gemerkt.is_empty():
		_zuletzt.add_child(Stil.matt(
			"Noch nichts angeheftet. Der Stern im Kopf heftet den offenen Bildschirm hier an.",
			Stil.S_MINI))
	else:
		_zuletzt.add_child(Stil.etikett("Angeheftet"))
		for id in gemerkt:
			_zuletzt.add_child(_marke(str(id)))
	_zuletzt.add_child(Stil.dehner())

	for r in _ressorts:
		var res: Dictionary = r
		if bool(res.get("versteckt", false)):
			continue
		var sp := Stil.vbox(0)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_spalten.add_child(sp)

		var kopfleiste := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Stil.TEXT
		sb.border_width_top = 2
		sb.content_margin_top = 8
		sb.content_margin_bottom = 10
		kopfleiste.add_theme_stylebox_override("panel", sb)
		sp.add_child(kopfleiste)
		kopfleiste.add_child(Stil.etikett(str(res["name"]), Stil.TEXT))

		for b in (res["blaetter"] as Array):
			sp.add_child(_eintrag(b as Dictionary))

## Ein Bildschirm im Register: Name, darunter der Satz, der ihn erklärt, und
## rechts die Zahl, wenn dort etwas offen ist.
func _eintrag(blatt: Dictionary) -> Control:
	var kennung: String = str(blatt["id"])
	var offen: bool = kennung == _aktiv
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := StyleBoxFlat.new()
	n.bg_color = Stil.AKZENT_DUNKEL if offen else Color(0, 0, 0, 0)
	n.content_margin_left = 8
	n.content_margin_right = 8
	n.content_margin_top = 6
	n.content_margin_bottom = 7
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Stil.FLAECHE_GLAS
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_stylebox_override("focus", Stil.box_leer())
	b.pressed.connect(func(): gewaehlt.emit(kennung))
	var z := Stil.hbox(8)
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(z)
	var spalte := Stil.vbox(1)
	spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	z.add_child(spalte)
	var name := Stil.text(str(blatt["name"]), Stil.S_NORMAL,
		Stil.AKZENT if offen else Stil.TEXT)
	name.add_theme_font_override("font", Stil.schnitt_halbfett())
	spalte.add_child(name)
	var satz: String = str(blatt.get("satz", ""))
	if satz != "":
		var s := Stil.matt(satz, Stil.S_MINI)
		s.clip_text = true
		spalte.add_child(s)
	var anzahl: int = int(_zaehler.get(kennung, 0))
	if anzahl > 0:
		z.add_child(Stil.abzeichen(str(anzahl), Stil.SIGNAL, true))
	var hoehe: float = 44.0 if satz != "" else 30.0
	z.resized.connect(func(): b.custom_minimum_size = Vector2(0, hoehe))
	b.custom_minimum_size = Vector2(0, hoehe)
	return b

## Ein angehefteter Bildschirm als Marke über den Spalten.
func _marke(kennung: String) -> Button:
	var name: String = kennung
	for r in _ressorts:
		for b in ((r as Dictionary)["blaetter"] as Array):
			if str((b as Dictionary)["id"]) == kennung:
				name = str((b as Dictionary)["name"])
	var k := Button.new()
	k.text = name
	k.focus_mode = Control.FOCUS_NONE
	k.add_theme_font_size_override("font_size", Stil.S_MINI)
	var n := Stil.box(Color(0, 0, 0, 0), Stil.R_RUND, Stil.RAND_HELL)
	n.content_margin_left = 12
	n.content_margin_right = 12
	n.content_margin_top = 3
	n.content_margin_bottom = 4
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Stil.FLAECHE_GLAS
	k.add_theme_stylebox_override("normal", n)
	k.add_theme_stylebox_override("hover", h)
	k.add_theme_stylebox_override("pressed", h)
	k.add_theme_stylebox_override("focus", Stil.box_leer())
	k.add_theme_color_override("font_color", Stil.TEXT_MATT)
	k.add_theme_color_override("font_hover_color", Stil.TEXT)
	k.pressed.connect(func(): gewaehlt.emit(kennung))
	return k
