class_name Kommandoleiste
extends PanelContainer
## Der Fuß der Kanzel: was in der Welt steht und der eine Knopf, der sie bewegt.
##
## Diese fünf Angaben standen bisher oben, als abgesetzte Kacheln zwischen
## Vereinswappen und Sinnbildern. Dort lagen sie auf dem Weg: man liest eine
## Oberfläche von oben nach unten und stößt zuerst auf Zahlen, die man nur
## nebenbei braucht. Vor allem aber stand der Weiter-Knopf zwischen ihnen — die
## Handlung, die man am häufigsten ausführt, oben rechts hinter vier
## Sinnbildern versteckt.
##
## Unten ist ihr Platz. Der Blick endet dort, wenn er mit dem Inhalt fertig
## ist, und genau dort steht die Frage, die dann ansteht: weiterschalten oder
## nicht. Alles davor — Datum, Saison, nächstes Spiel, offene Sachen, Kasse —
## ist die Begründung für diese eine Entscheidung und liest sich als ein Satz.
##
## Keine Kacheln mehr, sondern eine Zeile. Fünf Werte in fünf Kästen behaupten
## fünf gleich wichtige Dinge; es sind aber nicht fünf Dinge, sondern ein
## Zustand.

signal gewaehlt(id: String)
signal weiter_gedrueckt()

var _datum: Label
var _saison: Label
var _kasse: Label
var _spiel: Label
var _draengt: Label
var _spielknopf: Button
var _draengtknopf: Button
var weiter: Button

const HOEHE := 48

func _init() -> void:
	var box := Stil.box(Stil.FLAECHE, 0)
	box.border_color = Stil.RAND
	box.border_width_top = 1
	box.content_margin_left = 20
	box.content_margin_right = 16
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	add_theme_stylebox_override("panel", box)

func aufbauen() -> void:
	var zeile := Stil.hbox(10)
	zeile.custom_minimum_size = Vector2(0, HOEHE - 8)
	add_child(zeile)

	var uhr := Symbol.neu("uhr", 15.0, Stil.TEXT_SCHWACH)
	uhr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(uhr)
	_datum = Stil.text("—", Stil.S_KLEIN, Stil.TEXT)
	_datum.add_theme_font_override("font", Stil.schnitt_halbfett())
	_datum.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(_datum)
	_saison = Stil.matt("", Stil.S_MINI)
	_saison.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(_saison)

	zeile.add_child(Stil.marke_strich(Stil.RAND_HELL, 1, 22))

	var paar_spiel := _angabe(zeile, "Nächstes Spiel", "spielplan")
	_spielknopf = paar_spiel["knopf"]
	_spiel = paar_spiel["wert"]
	var paar_draengt := _angabe(zeile, "Offen", "buero")
	_draengtknopf = paar_draengt["knopf"]
	_draengt = paar_draengt["wert"]

	zeile.add_child(Stil.dehner())

	var kassenzeile := Stil.hbox(7)
	kassenzeile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(kassenzeile)
	kassenzeile.add_child(Stil.matt("Kasse", Stil.S_MINI))
	_kasse = Stil.text("—", Stil.S_KLEIN, Stil.TEXT)
	_kasse.add_theme_font_override("font", Stil.schnitt_halbfett())
	kassenzeile.add_child(_kasse)

	zeile.add_child(Stil.marke_strich(Stil.RAND_HELL, 1, 22))

	weiter = Stil.knopf_primaer("Weiter")
	weiter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weiter.custom_minimum_size = Vector2(132, 0)
	weiter.pressed.connect(func(): weiter_gedrueckt.emit())
	zeile.add_child(weiter)

## Eine anklickbare Angabe: blasse Beschriftung, dahinter der Wert.
##
## Der Wert steht hinter der Beschriftung und nicht darunter. Zwei Zeilen
## hätten die Leiste siebzehn Pixel höher gemacht, und die gehören dem Inhalt.
func _angabe(eltern: Node, beschriftung: String, ziel: String) -> Dictionary:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ruhe := Stil.box(Color(0, 0, 0, 0), Stil.R_MINI)
	ruhe.content_margin_left = 10
	ruhe.content_margin_right = 10
	ruhe.content_margin_top = 5
	ruhe.content_margin_bottom = 5
	b.add_theme_stylebox_override("normal", ruhe)
	b.add_theme_stylebox_override("hover", Stil.box(Stil.lasur(Stil.TEXT, 0.08), Stil.R_MINI))
	b.add_theme_stylebox_override("pressed", Stil.box(Stil.lasur(Stil.AKZENT, 0.16), Stil.R_MINI))
	b.add_theme_stylebox_override("focus", Stil.box_leer())
	var kennung := ziel
	b.pressed.connect(func(): gewaehlt.emit(kennung))
	eltern.add_child(b)
	var z := Stil.hbox(7)
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(z)
	z.add_child(Stil.matt(beschriftung, Stil.S_MINI))
	var wert := Stil.text("—", Stil.S_KLEIN, Stil.TEXT)
	wert.add_theme_font_override("font", Stil.schnitt_halbfett())
	z.add_child(wert)
	# Der Inhalt liegt freigestellt im Knopf und meldet von sich aus keine
	# Groesse an — der Knopf muss sie von ihm erfragen.
	z.resized.connect(func(): b.custom_minimum_size = Vector2(
		z.get_combined_minimum_size().x + 20.0, z.get_combined_minimum_size().y + 10.0))
	return {"knopf": b, "wert": wert}

# ------------------------------------------------------------------ Werte ---

func setze_zeit(datum: String, saison: String) -> void:
	_datum.text = datum
	_saison.text = saison

func setze_kasse(betrag: String, farbe: Color) -> void:
	_kasse.text = betrag
	_kasse.add_theme_color_override("font_color", farbe)

func setze_spiel(wert: String, farbe: Color, hinweis: String) -> void:
	_spiel.text = wert
	_spiel.add_theme_color_override("font_color", farbe)
	_spielknopf.tooltip_text = hinweis

func setze_draengt(wert: String, farbe: Color, hinweis: String) -> void:
	_draengt.text = wert
	_draengt.add_theme_color_override("font_color", farbe)
	_draengtknopf.tooltip_text = hinweis

func setze_weiter(beschriftung: String, hinweis: String) -> void:
	weiter.text = beschriftung
	weiter.tooltip_text = hinweis
