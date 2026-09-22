class_name Navigationskopf
extends PanelContainer
## Der Kopf der Kanzel: zwei Zeilen, die nur eine Frage beantworten — wo bin ich?
##
## Vorher standen hier zwei Leisten, die beide alles wollten: eine Kopfzeile
## mit Wortmarke, Verein, drei Werten, zwei Terminkacheln, vier Sinnbildern und
## dem Weiter-Knopf, darunter ein Menüband mit sieben Aufklappknöpfen, den
## Verlaufspfeilen, den Lesezeichen und dem Trainer. Dreizehn Dinge über
## einundzwanzig Dingen, und keines davon sagte, wo man gerade ist.
##
## Jetzt trägt der Kopf die Navigation und sonst nichts. Der Zustand der Welt
## und der einzige Knopf, der die Zeit bewegt, sind nach unten gewandert — in
## die Kommandoleiste. Was oben bleibt, ist der Ort: fünf Ressorts in der
## ersten Zeile, die Blätter des offenen Ressorts in der zweiten.
##
## Der wichtigste Unterschied ist nicht die Zahl der Knöpfe, sondern dass
## nichts mehr aufklappt. Ein Menü, das man öffnen muss, verbirgt seine
## Nachbarn: wer im Kader stand, sah nie, dass Training und Kabine daneben
## liegen. Hier stehen sie da, und ein Wechsel kostet einen Klick statt zwei.

signal gewaehlt(id: String)
signal merken_umgeschaltet(id: String)
signal zurueck_gewaehlt()
signal vor_gewaehlt()
signal hilfe_gewuenscht()
signal vorspulen_gewuenscht()

## [{"id": "mannschaft", "name": "Mannschaft", "blaetter": [{"id":…, "name":…}], "versteckt": bool}]
var ressorts: Array = []
var aktiv: String = ""

const ZEILE_OBEN := 46
const ZEILE_UNTEN := 34

var _ressortzeile: HBoxContainer
var _blattzeile: HBoxContainer
var _blattknoepfe: HBoxContainer
var _zeichenleiste: HBoxContainer
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
var _trainerruf: Label

var _ressortknoepfe: Dictionary = {}   # Ressortkennung -> Button
var _zaehler: Dictionary = {}          # Blattkennung -> Zahl
var _ressort_von: Dictionary = {}      # Blattkennung -> Ressortkennung
var _name_von: Dictionary = {}         # Blattkennung -> Anzeigename
var _hinweis_von: Dictionary = {}      # Blattkennung -> Hinweistext

func _init() -> void:
	var box := Stil.box(Stil.FLAECHE, 0)
	box.shadow_color = Color(0, 0, 0, 0.42)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	add_theme_stylebox_override("panel", box)

func aufbauen(neue_ressorts: Array) -> void:
	ressorts = neue_ressorts
	for r in ressorts:
		var res: Dictionary = r
		for b in (res["blaetter"] as Array):
			var blatt: Dictionary = b
			_ressort_von[str(blatt["id"])] = str(res["id"])
			_name_von[str(blatt["id"])] = str(blatt["name"])
	var spalte := Stil.vbox(0)
	add_child(spalte)
	spalte.add_child(_obere_zeile())
	spalte.add_child(_untere_zeile())

# ------------------------------------------------------------- erste Zeile ---

func _obere_zeile() -> Control:
	var rand := MarginContainer.new()
	rand.add_theme_constant_override("margin_left", 20)
	rand.add_theme_constant_override("margin_right", 16)
	rand.add_theme_constant_override("margin_top", 5)
	rand.add_theme_constant_override("margin_bottom", 3)
	var zeile := Stil.hbox(12)
	zeile.custom_minimum_size = Vector2(0, ZEILE_OBEN - 8)
	rand.add_child(zeile)

	_wappenhalter = Stil.hbox(0)
	_wappenhalter.custom_minimum_size = Vector2(30, 30)
	_wappenhalter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(_wappenhalter)

	var namen := Stil.vbox(0)
	namen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(namen)
	_vereinsname = Stil.text("", Stil.S_KLEIN, Stil.TEXT)
	_vereinsname.add_theme_font_override("font", Stil.schnitt_halbfett())
	namen.add_child(_vereinsname)
	_liganame = Stil.matt("", Stil.S_ETIKETT)
	namen.add_child(_liganame)

	zeile.add_child(Stil.marke_strich(Stil.RAND_HELL, 1, 24))

	_ressortzeile = Stil.hbox(2)
	_ressortzeile.size_flags_vertical = Control.SIZE_FILL
	zeile.add_child(_ressortzeile)
	for r in ressorts:
		var res: Dictionary = r
		if bool(res.get("versteckt", false)):
			continue
		var kennung: String = str(res["id"])
		var knopf := _ressortknopf(str(res["name"]))
		knopf.pressed.connect(func(): _ressort_oeffnen(kennung))
		_ressortzeile.add_child(knopf)
		_ressortknoepfe[kennung] = knopf

	zeile.add_child(Stil.dehner())

	_zurueck = _sinnbildknopf("pfeil_links", "Einen Bildschirm zurück (Alt + ←)")
	_zurueck.pressed.connect(func(): zurueck_gewaehlt.emit())
	zeile.add_child(_zurueck)
	_vor = _sinnbildknopf("pfeil_rechts", "Wieder vor (Alt + →)")
	_vor.pressed.connect(func(): vor_gewaehlt.emit())
	zeile.add_child(_vor)
	_glocke = _sinnbildknopf("glocke", "Nachrichten")
	_glocke.pressed.connect(func(): gewaehlt.emit("nachrichten"))
	zeile.add_child(_glocke)
	var spulen := _sinnbildknopf("doppelpfeil", "Zu einem Datum vorspulen")
	spulen.pressed.connect(func(): vorspulen_gewuenscht.emit())
	zeile.add_child(spulen)
	_zahnrad = _sinnbildknopf("zahnrad", "Spielstand, Einstellungen")
	_zahnrad.pressed.connect(func(): gewaehlt.emit("system"))
	zeile.add_child(_zahnrad)
	var hilfe := _sinnbildknopf("frage", "Kurzanleitung und Tastenkürzel (F1)")
	hilfe.pressed.connect(func(): hilfe_gewuenscht.emit())
	zeile.add_child(hilfe)

	zeile.add_child(Stil.marke_strich(Stil.RAND_HELL, 1, 24))

	# Wer hier arbeitet. Ein Klick führt in die eigene Laufbahn — der Trainer
	# ist eine Figur im Spiel und kein Wasserzeichen.
	var trainer := Button.new()
	trainer.focus_mode = Control.FOCUS_NONE
	trainer.tooltip_text = "Ihre Laufbahn"
	trainer.add_theme_stylebox_override("normal", Stil.box_leer())
	trainer.add_theme_stylebox_override("hover", Stil.box(Stil.lasur(Stil.TEXT, 0.07), Stil.R_KLEIN))
	trainer.add_theme_stylebox_override("pressed", Stil.box(Stil.lasur(Stil.AKZENT, 0.14), Stil.R_KLEIN))
	trainer.add_theme_stylebox_override("focus", Stil.box_leer())
	trainer.pressed.connect(func(): gewaehlt.emit("karriere"))
	zeile.add_child(trainer)
	var tz := Stil.hbox(8)
	tz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tz.set_anchors_preset(Control.PRESET_FULL_RECT)
	trainer.add_child(tz)
	_trainerbild = Stil.hbox(0)
	_trainerbild.custom_minimum_size = Vector2(26, 26)
	_trainerbild.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tz.add_child(_trainerbild)
	var tn := Stil.vbox(0)
	tn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tz.add_child(tn)
	_trainername = Stil.text("", Stil.S_MINI, Stil.TEXT)
	tn.add_child(_trainername)
	_trainerruf = Stil.matt("", Stil.S_ETIKETT)
	tn.add_child(_trainerruf)
	tz.resized.connect(func(): trainer.custom_minimum_size = Vector2(
		tz.get_combined_minimum_size().x + 16.0, 0))
	return rand

# ------------------------------------------------------------ zweite Zeile ---

func _untere_zeile() -> Control:
	var panel := PanelContainer.new()
	var box := Stil.box(Stil.FLAECHE_TIEF, 0)
	box.border_color = Stil.RAND
	box.border_width_bottom = 1
	box.content_margin_left = 20
	box.content_margin_right = 16
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", box)
	_blattzeile = Stil.hbox(0)
	_blattzeile.custom_minimum_size = Vector2(0, ZEILE_UNTEN)
	panel.add_child(_blattzeile)

	_blattknoepfe = Stil.hbox(2)
	_blattknoepfe.size_flags_vertical = Control.SIZE_FILL
	_blattzeile.add_child(_blattknoepfe)
	_blattzeile.add_child(Stil.dehner())

	_stern = Button.new()
	_stern.focus_mode = Control.FOCUS_NONE
	_stern.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_blattstil(_stern, false)
	_stern.pressed.connect(func(): merken_umgeschaltet.emit(aktiv))
	_blattzeile.add_child(_stern)
	_zeichenleiste = Stil.hbox(2)
	_zeichenleiste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_blattzeile.add_child(_zeichenleiste)
	return panel

## Die Blätter des offenen Ressorts neu setzen.
func _blaetter_zeichnen(ressort: String) -> void:
	for kind in _blattknoepfe.get_children():
		_blattknoepfe.remove_child(kind)
		kind.queue_free()
	for r in ressorts:
		var res: Dictionary = r
		if str(res["id"]) != ressort:
			continue
		for b in (res["blaetter"] as Array):
			var blatt: Dictionary = b
			var kennung: String = str(blatt["id"])
			var knopf := Button.new()
			knopf.focus_mode = Control.FOCUS_NONE
			knopf.size_flags_vertical = Control.SIZE_FILL
			knopf.pressed.connect(func(): gewaehlt.emit(kennung))
			_blattknoepfe.add_child(knopf)
			knopf.set_meta("blatt", kennung)
	_blattbeschriftung()

## Beschriftung, Zahl und Markierung aller sichtbaren Blätter.
func _blattbeschriftung() -> void:
	if _blattknoepfe == null:
		return
	for kind in _blattknoepfe.get_children():
		var knopf: Button = kind
		var kennung: String = str(knopf.get_meta("blatt", ""))
		var anzahl: int = int(_zaehler.get(kennung, 0))
		var name: String = str(_name_von.get(kennung, kennung))
		knopf.text = "%s  %d" % [name, anzahl] if anzahl > 0 else name
		knopf.tooltip_text = str(_hinweis_von.get(kennung, name))
		_blattstil(knopf, kennung == aktiv)
		if kennung != aktiv and anzahl > 0:
			knopf.add_theme_color_override("font_color", Stil.SIGNAL)

# ------------------------------------------------------------------ Knöpfe ---

## Ein Ressort in der ersten Zeile: Text, darunter die Markierung.
##
## Kein gefülltes Rechteck wie früher, sondern ein Strich unter dem Wort. Eine
## Fläche in der Handlungsfarbe sagt „hier drücken“; das offene Ressort ist
## aber keine Handlung, sondern ein Ort — und Orte werden markiert, nicht
## angeboten.
func _ressortknopf(name: String) -> Button:
	var b := Button.new()
	b.text = name
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_FILL
	_ressortstil(b, false)
	return b

func _ressortstil(b: Button, offen: bool) -> void:
	b.add_theme_stylebox_override("normal", _unterstrich(
		Stil.AKZENT if offen else Color(0, 0, 0, 0), 14, 2 if offen else 0))
	b.add_theme_stylebox_override("hover", _unterstrich(
		Stil.AKZENT if offen else Stil.RAND_HELL, 14, 2))
	b.add_theme_stylebox_override("pressed", _unterstrich(Stil.AKZENT_TIEF, 14, 2))
	b.add_theme_stylebox_override("focus", Stil.box_leer())
	b.add_theme_color_override("font_color", Stil.TEXT if offen else Stil.TEXT_MATT)
	b.add_theme_color_override("font_hover_color", Stil.TEXT)
	b.add_theme_font_override("font",
		Stil.schnitt_halbfett() if offen else Stil.grundschrift())
	b.add_theme_font_size_override("font_size", Stil.S_KLEIN)

func _blattstil(b: Button, offen: bool) -> void:
	b.add_theme_stylebox_override("normal", _unterstrich(
		Stil.TUERKIS if offen else Color(0, 0, 0, 0), 11, 2 if offen else 0))
	b.add_theme_stylebox_override("hover", _unterstrich(
		Stil.TUERKIS if offen else Stil.RAND_HELL, 11, 2))
	b.add_theme_stylebox_override("pressed", _unterstrich(Stil.TUERKIS, 11, 2))
	b.add_theme_stylebox_override("focus", Stil.box_leer())
	b.add_theme_color_override("font_color", Stil.TEXT if offen else Stil.TEXT_MATT)
	b.add_theme_color_override("font_hover_color", Stil.TEXT)
	b.add_theme_font_override("font",
		Stil.schnitt_halbfett() if offen else Stil.grundschrift())
	b.add_theme_font_size_override("font_size", Stil.S_MINI if not offen else Stil.S_KLEIN)

## Ein durchsichtiger Kasten, der nur unten eine Kante hat.
func _unterstrich(farbe: Color, rand: int, breite: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = farbe
	sb.border_width_bottom = breite
	sb.content_margin_left = rand
	sb.content_margin_right = rand
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _sinnbildknopf(zeichen: String, hinweis: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(32, 30)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = hinweis
	b.add_theme_stylebox_override("normal", Stil.box_leer())
	b.add_theme_stylebox_override("hover", Stil.box(Stil.lasur(Stil.TEXT, 0.08), Stil.R_KLEIN))
	b.add_theme_stylebox_override("pressed", Stil.box(Stil.lasur(Stil.AKZENT, 0.16), Stil.R_KLEIN))
	b.add_theme_stylebox_override("focus", Stil.box_leer())
	var s := Symbol.neu(zeichen, 17.0, Stil.TEXT_MATT)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(s)
	b.set_meta("symbol", s)
	return b

func _sinnbildfarbe(b: Button, farbe: Color) -> void:
	if b != null and b.has_meta("symbol"):
		(b.get_meta("symbol") as Symbol).setze_farbe(farbe)

# --------------------------------------------------------------- Zustaende ---

func _ressort_oeffnen(kennung: String) -> void:
	for r in ressorts:
		var res: Dictionary = r
		if str(res["id"]) != kennung:
			continue
		var blaetter: Array = res["blaetter"]
		if blaetter.is_empty():
			return
		# Wer das Ressort wechselt, landet auf seinem ersten Blatt — es sei
		# denn, er war schon einmal drin. Dann zählt, wo er aufgehört hat.
		var ziel: String = str(res.get("zuletzt", str((blaetter[0] as Dictionary)["id"])))
		gewaehlt.emit(ziel)
		return

func setze_aktiv(id: String) -> void:
	aktiv = id
	var ressort: String = str(_ressort_von.get(id, ""))
	for r in ressorts:
		var res: Dictionary = r
		if str(res["id"]) == ressort:
			res["zuletzt"] = id
	for kennung in _ressortknoepfe.keys():
		_ressortstil(_ressortknoepfe[kennung], str(kennung) == ressort)
	_sinnbildfarbe(_zahnrad, Stil.TEXT if id == "system" else Stil.TEXT_MATT)
	_blaetter_zeichnen(ressort)
	_zaehler_zeichnen()
	_lesezeichen_zeichnen()

## Die Zahl an einem Blatt. Sie steht am Blatt und summiert sich am Ressort —
## damit man eine offene Sache auch dann sieht, wenn man woanders steht.
func setze_zaehler(id: String, wert: int) -> void:
	_zaehler[id] = wert
	_zaehler_zeichnen()

func _zaehler_zeichnen() -> void:
	for r in ressorts:
		var res: Dictionary = r
		var kennung: String = str(res["id"])
		if not _ressortknoepfe.has(kennung):
			continue
		var summe := 0
		for b in (res["blaetter"] as Array):
			summe += int(_zaehler.get(str((b as Dictionary)["id"]), 0))
		var knopf: Button = _ressortknoepfe[kennung]
		var offen: bool = str(_ressort_von.get(aktiv, "")) == kennung
		knopf.text = "%s  %d" % [str(res["name"]), summe] if summe > 0 else str(res["name"])
		if not offen and summe > 0:
			knopf.add_theme_color_override("font_color", Stil.SIGNAL)
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
	_sinnbildfarbe(_glocke, Stil.AKZENT if offen > 0 else Stil.TEXT_MATT)
	if _glocke != null:
		_glocke.tooltip_text = "%s ungelesen" % Stil.anzahl_mit(offen, "Nachricht", "Nachrichten") if offen > 0 else "Nachrichten"

func setze_verein(name: String, liga: String, wappen: Control) -> void:
	_vereinsname.text = name
	_liganame.text = liga
	for k in _wappenhalter.get_children():
		k.queue_free()
	if wappen != null:
		_wappenhalter.add_child(wappen)

func setze_trainer(bild: Control, name: String, ruf: String) -> void:
	for k in _trainerbild.get_children():
		k.queue_free()
	if bild != null:
		_trainerbild.add_child(bild)
	_trainername.text = name
	_trainerruf.text = ruf

# ------------------------------------------------------------ Lesezeichen ---

var _gemerkt: Array = []
var _voll: bool = false
var _abgelehnt: bool = false

func setze_lesezeichen(ids: Array, voll: bool, abgelehnt: bool = false) -> void:
	_gemerkt = ids
	_voll = voll
	_abgelehnt = abgelehnt
	_lesezeichen_zeichnen()

func _lesezeichen_zeichnen() -> void:
	if _zeichenleiste == null:
		return
	for kind in _zeichenleiste.get_children():
		_zeichenleiste.remove_child(kind)
		kind.queue_free()
	for id in _gemerkt:
		var kennung: String = str(id)
		var b := Button.new()
		b.text = str(_name_von.get(kennung, kennung))
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = "%s — angeheftet. Zum Ablösen dort den Stern drücken." % str(
			_name_von.get(kennung, kennung))
		_zeichenstil(b, kennung == aktiv)
		b.pressed.connect(func(): gewaehlt.emit(kennung))
		_zeichenleiste.add_child(b)
	var gemerkt: bool = _gemerkt.has(aktiv)
	_stern.text = "★" if gemerkt else ("☆" if not _gemerkt.is_empty() else "☆ Anheften")
	_blattstil(_stern, false)
	_stern.add_theme_color_override("font_color",
		Stil.ROT if _abgelehnt else (Stil.TUERKIS if gemerkt else Stil.TEXT_SCHWACH))
	if _abgelehnt:
		_stern.tooltip_text = "Es sind schon %d Bildschirme angeheftet — mehr passen nicht. Erst einen ablösen." % _gemerkt.size()
	elif gemerkt:
		_stern.tooltip_text = "Angeheftet. Nochmal drücken löst ab. (L)"
	elif _voll:
		_stern.tooltip_text = "Es sind schon fünf Bildschirme angeheftet. Erst einen ablösen."
	else:
		_stern.tooltip_text = "Diesen Bildschirm anheften — er steht dann hier und ist von überall einen Klick entfernt. (L)"

func _zeichenstil(b: Button, offen: bool) -> void:
	var sb := Stil.box(Stil.lasur(Stil.TUERKIS, 0.16 if offen else 0.08), Stil.R_MINI)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", Stil.box(Stil.lasur(Stil.TUERKIS, 0.24), Stil.R_MINI))
	b.add_theme_stylebox_override("pressed", Stil.box(Stil.lasur(Stil.TUERKIS, 0.32), Stil.R_MINI))
	b.add_theme_stylebox_override("focus", Stil.box_leer())
	b.add_theme_color_override("font_color", Stil.TUERKIS)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", Stil.S_MINI)
