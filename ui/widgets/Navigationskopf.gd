class_name Navigationskopf
extends PanelContainer
## Der Kopf: eine Zeile, die sagt, wo man ist — und sonst nichts.
##
## Dies ist die vierte Form der Navigation in diesem Spiel, und die erste, die
## nicht versucht, das ganze Spiel gleichzeitig anzubieten. Vorher: eine
## Seitenleiste mit vierundzwanzig Einträgen (238 Pixel Breite, immer da).
## Dann ein Menüband mit sieben Aufklappknöpfen (zwei Klicks je Wechsel, und
## die Nachbarn blieben unsichtbar). Dann zwei Zeilen Reiter (die Nachbarn
## sichtbar, dafür achtzig Pixel Höhe, immer da).
##
## Hier steht der Verein, das offene Ressort, die Blätter daneben — und links
## die Tafel, auf der alles andere liegt. Navigation ist kein Möbelstück,
## das dauerhaft im Raum steht; sie ist eine Handlung, die man selten
## ausführt. Also nimmt sie Platz, wenn man sie braucht, und keinen, wenn
## nicht.

signal gewaehlt(id: String)
signal merken_umgeschaltet(id: String)
signal zurueck_gewaehlt()
signal vor_gewaehlt()
signal hilfe_gewuenscht()
signal vorspulen_gewuenscht()
signal tafel_gewuenscht()

## [{"id": "mannschaft", "name": "Mannschaft", "blaetter": [{"id":…, "name":…}], "versteckt": bool}]
var ressorts: Array = []
var aktiv: String = ""

const HOEHE := 44

var _zeile: HBoxContainer
var _blattzeile: HBoxContainer
var _tafelknopf: Button
var _stern: Button
var _zurueck: Button
var _vor: Button
var _glocke: Button
var _zahnrad: Button
var _wappenhalter: Control
var _vereinsname: Label
var _liganame: Label
var _trainerbild: Control
var _trainername: Label

var _zaehler: Dictionary = {}          # Blattkennung -> Zahl
var _ressort_von: Dictionary = {}      # Blattkennung -> Ressortkennung
var _ressortname: Dictionary = {}      # Ressortkennung -> Name
var _name_von: Dictionary = {}         # Blattkennung -> Anzeigename
var _hinweis_von: Dictionary = {}      # Blattkennung -> Hinweistext

func _init() -> void:
	var box := Stil.box(Stil.FLAECHE, 0)
	box.border_color = Stil.TEXT
	box.border_width_bottom = 2
	box.content_margin_left = 22
	box.content_margin_right = 16
	box.content_margin_top = 4
	box.content_margin_bottom = 3
	add_theme_stylebox_override("panel", box)

func aufbauen(neue_ressorts: Array) -> void:
	ressorts = neue_ressorts
	for r in ressorts:
		var res: Dictionary = r
		_ressortname[str(res["id"])] = str(res["name"])
		for b in (res["blaetter"] as Array):
			var blatt: Dictionary = b
			_ressort_von[str(blatt["id"])] = str(res["id"])
			_name_von[str(blatt["id"])] = str(blatt["name"])

	_zeile = Stil.hbox(12)
	_zeile.custom_minimum_size = Vector2(0, HOEHE - 7)
	add_child(_zeile)

	_wappenhalter = Stil.hbox(0)
	_wappenhalter.custom_minimum_size = Vector2(28, 28)
	_wappenhalter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_zeile.add_child(_wappenhalter)

	var namen := Stil.vbox(0)
	namen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_zeile.add_child(namen)
	_vereinsname = Stil.text("", Stil.S_KLEIN, Stil.TEXT)
	_vereinsname.add_theme_font_override("font", Stil.schnitt_halbfett())
	namen.add_child(_vereinsname)
	_liganame = Stil.matt("", Stil.S_ETIKETT)
	namen.add_child(_liganame)

	_zeile.add_child(Stil.marke_strich(Stil.RAND_HELL, 1, 24))

	# Die Tafel. Sie trägt den Namen des offenen Ressorts, damit der Knopf
	# nicht nur eine Tür ist, sondern auch ein Ortsschild.
	_tafelknopf = Button.new()
	_tafelknopf.focus_mode = Control.FOCUS_NONE
	_tafelknopf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tafelknopf.tooltip_text = "Alle Bildschirme auf einer Seite (Tab)"
	var tn := Stil.box(Color(0, 0, 0, 0), Stil.R_MINI, Stil.RAND_HELL)
	tn.content_margin_left = 10
	tn.content_margin_right = 12
	tn.content_margin_top = 5
	tn.content_margin_bottom = 6
	var th := tn.duplicate() as StyleBoxFlat
	th.bg_color = Stil.FLAECHE_GLAS
	th.border_color = Stil.TEXT
	_tafelknopf.add_theme_stylebox_override("normal", tn)
	_tafelknopf.add_theme_stylebox_override("hover", th)
	_tafelknopf.add_theme_stylebox_override("pressed", th)
	_tafelknopf.add_theme_stylebox_override("focus", Stil.box_leer())
	_tafelknopf.pressed.connect(func(): tafel_gewuenscht.emit())
	_zeile.add_child(_tafelknopf)
	var tz := Stil.hbox(8)
	tz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tafelknopf.add_child(tz)
	var balken := Symbol.neu("tafel", 14.0, Stil.TEXT)
	balken.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tz.add_child(balken)
	var tl := Stil.text("Tafel", Stil.S_MINI, Stil.TEXT)
	tl.add_theme_font_override("font", Stil.schnitt_gesperrt())
	tz.add_child(tl)
	tz.resized.connect(func(): _tafelknopf.custom_minimum_size = Vector2(
		tz.get_combined_minimum_size().x + 24.0, 0))

	_blattzeile = Stil.hbox(0)
	_blattzeile.size_flags_vertical = Control.SIZE_FILL
	_zeile.add_child(_blattzeile)

	_zeile.add_child(Stil.dehner())

	_stern = Button.new()
	_stern.focus_mode = Control.FOCUS_NONE
	_stern.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_blattstil(_stern, false)
	_stern.pressed.connect(func(): merken_umgeschaltet.emit(aktiv))
	_zeile.add_child(_stern)

	_zurueck = _sinnbildknopf("pfeil_links", "Einen Bildschirm zurück (Alt + ←)")
	_zurueck.pressed.connect(func(): zurueck_gewaehlt.emit())
	_zeile.add_child(_zurueck)
	_vor = _sinnbildknopf("pfeil_rechts", "Wieder vor (Alt + →)")
	_vor.pressed.connect(func(): vor_gewaehlt.emit())
	_zeile.add_child(_vor)
	_glocke = _sinnbildknopf("glocke", "Nachrichten")
	_glocke.pressed.connect(func(): gewaehlt.emit("nachrichten"))
	_zeile.add_child(_glocke)
	var spulen := _sinnbildknopf("doppelpfeil", "Zu einem Datum vorspulen")
	spulen.pressed.connect(func(): vorspulen_gewuenscht.emit())
	_zeile.add_child(spulen)
	_zahnrad = _sinnbildknopf("zahnrad", "Spielstand, Einstellungen")
	_zahnrad.pressed.connect(func(): gewaehlt.emit("system"))
	_zeile.add_child(_zahnrad)
	var hilfe := _sinnbildknopf("frage", "Kurzanleitung und Tastenkürzel (F1)")
	hilfe.pressed.connect(func(): hilfe_gewuenscht.emit())
	_zeile.add_child(hilfe)

	_zeile.add_child(Stil.marke_strich(Stil.RAND_HELL, 1, 24))

	var trainer := Button.new()
	trainer.focus_mode = Control.FOCUS_NONE
	trainer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trainer.tooltip_text = "Ihre Laufbahn"
	trainer.add_theme_stylebox_override("normal", Stil.box_leer())
	trainer.add_theme_stylebox_override("hover", Stil.box(Stil.FLAECHE_GLAS, Stil.R_MINI))
	trainer.add_theme_stylebox_override("pressed", Stil.box(Stil.AKZENT_DUNKEL, Stil.R_MINI))
	trainer.add_theme_stylebox_override("focus", Stil.box_leer())
	trainer.pressed.connect(func(): gewaehlt.emit("karriere"))
	_zeile.add_child(trainer)
	var trz := Stil.hbox(8)
	trz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trz.set_anchors_preset(Control.PRESET_FULL_RECT)
	trainer.add_child(trz)
	_trainerbild = Stil.hbox(0)
	_trainerbild.custom_minimum_size = Vector2(24, 24)
	_trainerbild.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trz.add_child(_trainerbild)
	_trainername = Stil.text("", Stil.S_MINI, Stil.TEXT_MATT)
	_trainername.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trz.add_child(_trainername)
	trz.resized.connect(func(): trainer.custom_minimum_size = Vector2(
		trz.get_combined_minimum_size().x + 16.0, 0))

# ------------------------------------------------------------------ Blätter ---

## Die Nachbarn des offenen Bildschirms — als Wörter auf einer Linie, nicht
## als Reiter in einer Schale.
func _blaetter_zeichnen(ressort: String) -> void:
	for kind in _blattzeile.get_children():
		_blattzeile.remove_child(kind)
		kind.queue_free()
	for r in ressorts:
		var res: Dictionary = r
		if str(res["id"]) != ressort:
			continue
		for b in (res["blaetter"] as Array):
			var kennung: String = str((b as Dictionary)["id"])
			var knopf := Button.new()
			knopf.focus_mode = Control.FOCUS_NONE
			knopf.size_flags_vertical = Control.SIZE_FILL
			knopf.pressed.connect(func(): gewaehlt.emit(kennung))
			knopf.set_meta("blatt", kennung)
			_blattzeile.add_child(knopf)
	_blattbeschriftung()

func _blattbeschriftung() -> void:
	if _blattzeile == null:
		return
	for kind in _blattzeile.get_children():
		var knopf: Button = kind
		var kennung: String = str(knopf.get_meta("blatt", ""))
		var anzahl: int = int(_zaehler.get(kennung, 0))
		var name: String = str(_name_von.get(kennung, kennung))
		knopf.text = "%s  %d" % [name, anzahl] if anzahl > 0 else name
		knopf.tooltip_text = str(_hinweis_von.get(kennung, name))
		_blattstil(knopf, kennung == aktiv)
		if kennung != aktiv and anzahl > 0:
			knopf.add_theme_color_override("font_color", Stil.SIGNAL)

func _blattstil(b: Button, offen: bool) -> void:
	b.add_theme_stylebox_override("normal", _unterstrich(
		Stil.TEXT if offen else Color(0, 0, 0, 0), 2 if offen else 0))
	b.add_theme_stylebox_override("hover", _unterstrich(
		Stil.TEXT if offen else Stil.RAND_HELL, 2))
	b.add_theme_stylebox_override("pressed", _unterstrich(Stil.AKZENT, 2))
	b.add_theme_stylebox_override("focus", Stil.box_leer())
	b.add_theme_color_override("font_color", Stil.TEXT if offen else Stil.TEXT_SCHWACH)
	b.add_theme_color_override("font_hover_color", Stil.TEXT)
	b.add_theme_font_override("font",
		Stil.schnitt_halbfett() if offen else Stil.grundschrift())
	b.add_theme_font_size_override("font_size", Stil.S_KLEIN)

func _unterstrich(farbe: Color, breite: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = farbe
	sb.border_width_bottom = breite
	sb.content_margin_left = 11
	sb.content_margin_right = 11
	sb.content_margin_top = 5
	sb.content_margin_bottom = 4
	return sb

func _sinnbildknopf(zeichen: String, hinweis: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(28, 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = hinweis
	b.add_theme_stylebox_override("normal", Stil.box_leer())
	b.add_theme_stylebox_override("hover", Stil.box(Stil.FLAECHE_GLAS, Stil.R_MINI))
	b.add_theme_stylebox_override("pressed", Stil.box(Stil.AKZENT_DUNKEL, Stil.R_MINI))
	b.add_theme_stylebox_override("focus", Stil.box_leer())
	var s := Symbol.neu(zeichen, 16.0, Stil.TEXT_MATT)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(s)
	b.set_meta("symbol", s)
	return b

func _sinnbildfarbe(b: Button, farbe: Color) -> void:
	if b != null and b.has_meta("symbol"):
		(b.get_meta("symbol") as Symbol).setze_farbe(farbe)

# --------------------------------------------------------------- Zustaende ---

func setze_aktiv(id: String) -> void:
	aktiv = id
	var ressort: String = str(_ressort_von.get(id, ""))
	if _tafelknopf != null:
		_tafelknopf.tooltip_text = "%s — alle Bildschirme auf einer Seite (Tab)" % str(
			_ressortname.get(ressort, "Tafel"))
	_sinnbildfarbe(_zahnrad, Stil.AKZENT if id == "system" else Stil.TEXT_MATT)
	_blaetter_zeichnen(ressort)
	_zaehler_zeichnen()
	_lesezeichen_zeichnen()

func setze_zaehler(id: String, wert: int) -> void:
	_zaehler[id] = wert
	_zaehler_zeichnen()

func _zaehler_zeichnen() -> void:
	_blattbeschriftung()

func setze_hinweis(id: String, text: String) -> void:
	_hinweis_von[id] = text
	_blattbeschriftung()

func setze_verlauf(kann_zurueck: bool, kann_vor: bool) -> void:
	if _zurueck == null:
		return
	_zurueck.disabled = not kann_zurueck
	_vor.disabled = not kann_vor
	_sinnbildfarbe(_zurueck, Stil.TEXT_MATT if kann_zurueck else Stil.TEXT_SCHWACH)
	_sinnbildfarbe(_vor, Stil.TEXT_MATT if kann_vor else Stil.TEXT_SCHWACH)

func setze_post(offen: int) -> void:
	_sinnbildfarbe(_glocke, Stil.SIGNAL if offen > 0 else Stil.TEXT_MATT)
	if _glocke != null:
		_glocke.tooltip_text = "%s ungelesen" % Stil.anzahl_mit(
			offen, "Nachricht", "Nachrichten") if offen > 0 else "Nachrichten"

func setze_verein(name: String, liga: String, wappen: Control) -> void:
	_vereinsname.text = name
	_liganame.text = liga
	for k in _wappenhalter.get_children():
		k.queue_free()
	if wappen != null:
		_wappenhalter.add_child(wappen)

func setze_trainer(bild: Control, name: String, _ruf: String) -> void:
	for k in _trainerbild.get_children():
		k.queue_free()
	if bild != null:
		_trainerbild.add_child(bild)
	_trainername.text = name

# ------------------------------------------------------------ Lesezeichen ---

var _gemerkt: Array = []
var _voll: bool = false
var _abgelehnt: bool = false

func setze_lesezeichen(ids: Array, voll: bool, abgelehnt: bool = false) -> void:
	_gemerkt = ids
	_voll = voll
	_abgelehnt = abgelehnt
	_lesezeichen_zeichnen()

## Nur noch der Stern, keine Marken mehr: die angehefteten Bildschirme stehen
## auf der Tafel, wo Platz für ihren Namen ist. Im Kopf hätten sie wieder eine
## zweite Leiste gebraucht.
func _lesezeichen_zeichnen() -> void:
	if _stern == null:
		return
	var gemerkt: bool = _gemerkt.has(aktiv)
	_stern.text = "★" if gemerkt else "☆"
	_blattstil(_stern, false)
	_stern.add_theme_color_override("font_color",
		Stil.SIGNAL if _abgelehnt else (Stil.AKZENT if gemerkt else Stil.TEXT_SCHWACH))
	if _abgelehnt:
		_stern.tooltip_text = "Es sind schon %d Bildschirme angeheftet — erst einen ablösen." % _gemerkt.size()
	elif gemerkt:
		_stern.tooltip_text = "Angeheftet — steht auf der Tafel ganz oben. Nochmal drücken löst ab. (L)"
	elif _voll:
		_stern.tooltip_text = "Es sind schon fünf Bildschirme angeheftet. Erst einen ablösen."
	else:
		_stern.tooltip_text = "Diesen Bildschirm anheften — er steht dann auf der Tafel ganz oben. (L)"
