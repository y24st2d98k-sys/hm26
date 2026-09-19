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
## Der Stern wurde gedrückt: der Bildschirm soll angeheftet oder abgelöst werden.
signal merken_umgeschaltet(id: String)
## Einen Bildschirm zurück beziehungsweise wieder vor.
signal zurueck_gewaehlt()
signal vor_gewaehlt()

## Aufbau: [{"name": "Mannschaft", "eintraege": [{"id":…, "name":…}], "direkt": bool}]
var gruppen: Array = []
var aktiv: String = ""

var _leiste: HBoxContainer
var _zeichenleiste: HBoxContainer
var _stern: Button
var _zurueck: Button
var _vor: Button
var _knoepfe: Dictionary = {}     # Gruppenname -> Button
var _menues: Dictionary = {}      # Gruppenname -> PopupMenu
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
	_leiste.add_child(_pfeile())
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
	_leiste.add_child(_lesezeichenbereich())
	_leiste.add_child(Stil.dehner())
	var rechts := Stil.hbox(9)
	rechts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_leiste.add_child(rechts)
	return rechts

## Vor und zurück wie im Browser.
##
## Fünfundzwanzig Bildschirme, die einander aufrufen: aus dem Kader ins Profil
## eines Spielers, von dort in den Transfermarkt, und zurück findet man nur
## über das Menü. Die beiden Pfeile führen den Weg, den man gegangen ist.
func _pfeile() -> Control:
	var halter := Stil.hbox(0)
	halter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_zurueck = _pfeilknopf("‹", "Einen Bildschirm zurück (Alt + ←)")
	_zurueck.pressed.connect(func(): zurueck_gewaehlt.emit())
	halter.add_child(_zurueck)
	_vor = _pfeilknopf("›", "Wieder vor (Alt + →)")
	_vor.pressed.connect(func(): vor_gewaehlt.emit())
	halter.add_child(_vor)
	var strich := VSeparator.new()
	strich.custom_minimum_size = Vector2(0, 20)
	halter.add_child(strich)
	return halter

func _pfeilknopf(zeichen: String, hinweis: String) -> Button:
	var b := Button.new()
	b.text = zeichen
	b.tooltip_text = hinweis
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 32)
	_stil_setzen(b, false)
	return b

## Ob es einen Weg zurück beziehungsweise wieder vor gibt. Ein Pfeil ins Leere
## wird nicht ausgeblendet, sondern blass: eine Leiste, die ihre Breite
## aendert, springt bei jedem Wechsel.
func setze_verlauf(kann_zurueck: bool, kann_vor: bool) -> void:
	if _zurueck == null:
		return
	_zurueck.disabled = not kann_zurueck
	_vor.disabled = not kann_vor
	for paar in [[_zurueck, kann_zurueck], [_vor, kann_vor]]:
		(paar[0] as Button).add_theme_color_override("font_color",
			Stil.TEXT_MATT if bool(paar[1]) else Stil.TEXT_SCHWACH)

## Die Lesezeichen: ein Stern für den offenen Bildschirm, daneben die
## angehefteten.
##
## Sie stehen in derselben Zeile wie die Gruppen und nicht darunter. Eine
## zweite Zeile hätte jeden Bildschirm um dreißig Pixel nach unten geschoben,
## und dafür ist zu viel Arbeit hineingegangen, dass nirgends mehr gerollt
## werden muss.
func _lesezeichenbereich() -> Control:
	var halter := Stil.hbox(2)
	halter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var strich := VSeparator.new()
	strich.custom_minimum_size = Vector2(0, 20)
	halter.add_child(strich)
	_stern = Button.new()
	_stern.focus_mode = Control.FOCUS_NONE
	_stern.custom_minimum_size = Vector2(0, 32)
	_stil_setzen(_stern, false)
	_stern.pressed.connect(func(): merken_umgeschaltet.emit(aktiv))
	halter.add_child(_stern)
	_zeichenleiste = Stil.hbox(2)
	_zeichenleiste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	halter.add_child(_zeichenleiste)
	return halter

## Die angehefteten Bildschirme neu zeichnen.
##
## `abgelehnt` faerbt den Stern rot: der Balken war voll, und ohne dieses
## Zeichen drueckt man dreimal und haelt ihn fuer kaputt. Die Farbe bleibt bis
## zum naechsten Bildschirmwechsel stehen — lange genug zum Lesen, kurz genug,
## um nicht zu stoeren.
func setze_lesezeichen(ids: Array, voll: bool, abgelehnt: bool = false) -> void:
	if _zeichenleiste == null:
		return
	for kind in _zeichenleiste.get_children():
		_zeichenleiste.remove_child(kind)
		kind.queue_free()
	for id in ids:
		var kennung: String = str(id)
		var b := Button.new()
		b.text = str(_name_von.get(kennung, kennung))
		b.focus_mode = Control.FOCUS_NONE
		# Kein clip_text: bei einem Knopf senkt es die Mindestbreite auf null,
		# und in einer Zeile ohne Dehner bleibt davon ein leeres Kaestchen
		# uebrig. Fuenf kurze Bildschirmnamen passen auch so.
		b.custom_minimum_size = Vector2(0, 32)
		b.tooltip_text = "%s — angeheftet. Zum Ablösen dort den Stern drücken." % str(
			_name_von.get(kennung, kennung))
		_stil_setzen(b, kennung == aktiv)
		b.add_theme_color_override("font_color",
			Color.WHITE if kennung == aktiv else Stil.TUERKIS)
		b.pressed.connect(func(): gewaehlt.emit(kennung))
		_zeichenleiste.add_child(b)
	var gemerkt: bool = ids.has(aktiv)
	# Solange nichts angeheftet ist, steht das Wort dabei. Ein einzelner
	# blasser Stern zwischen sieben Knoepfen erklaert sich niemandem; sobald
	# das erste Lesezeichen steht, erklaert es sich von selbst.
	_stern.text = "★" if gemerkt else ("☆" if not ids.is_empty() else "☆ Anheften")
	_stern.add_theme_color_override("font_color",
		Stil.ROT if abgelehnt else (Stil.TUERKIS if gemerkt else Stil.TEXT_SCHWACH))
	if abgelehnt:
		_stern.tooltip_text = "Es sind schon %d Bildschirme angeheftet — mehr passen nicht ins Band. Erst einen ablösen." % ids.size()
	elif gemerkt:
		_stern.tooltip_text = "„%s“ ist angeheftet. Nochmal drücken löst es ab. (L)" % str(
			_name_von.get(aktiv, aktiv))
	elif voll:
		_stern.tooltip_text = "Es sind schon fünf Bildschirme angeheftet. Erst einen ablösen."
	elif ids.is_empty():
		_stern.tooltip_text = "Diesen Bildschirm anheften — er steht dann hier oben und ist einen Klick entfernt. (L)"
	else:
		_stern.tooltip_text = "„%s“ anheften. (L)" % str(_name_von.get(aktiv, aktiv))

## Ein Gruppenknopf: Name, bei Gruppen ein Pfeil, dazu Platz für die Zahl.
func _gruppenknopf(name: String, einzeln: bool) -> Button:
	var b := Button.new()
	b.text = name if einzeln else name + "  ▾"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 32)
	_stil_setzen(b, false)
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
			knopf.text = "%s · %s  ▾" % [name, str(_name_von.get(id, ""))]
		else:
			knopf.text = name if einzeln else name + "  ▾"
		_stil_setzen(knopf, eigen)
	_marken_auffrischen()

## Die Zahl an einem Bildschirm — sie summiert sich am Knopf seiner Gruppe.
func setze_zaehler(id: String, wert: int) -> void:
	_zaehler[id] = wert
	_marken_auffrischen()
	_menues_auffrischen()

## Die Zahl steht im Knopftext, nicht als Aufkleber darueber.
##
## Ein frei gesetztes Etikett hat sich bei schmalen Knoepfen ueber den
## Nachbarn geschoben — "Umfeld³⁰ Spiel". Im Text nimmt es Platz ein, und die
## Leiste rueckt selbst zur Seite.
func _marken_auffrischen() -> void:
	for g in gruppen:
		var gruppe: Dictionary = g
		var name: String = str(gruppe["name"])
		var einzeln: bool = (gruppe["eintraege"] as Array).size() == 1
		var summe := 0
		for e in (gruppe["eintraege"] as Array):
			summe += int(_zaehler.get(str((e as Dictionary)["id"]), 0))
		var knopf: Button = _knoepfe[name]
		var eigen: bool = str(_gruppe_von.get(aktiv, "")) == name
		var grund: String = name
		if eigen and not einzeln:
			grund = "%s · %s" % [name, str(_name_von.get(aktiv, ""))]
		if summe > 0:
			grund += "  %d" % summe
		knopf.text = grund if einzeln else grund + "  ▾"
		# Magenta, solange etwas offen ist: die Farbe ist im ganzen Spiel das
		# Zeichen fuer "hier steht etwas an".
		if not eigen:
			knopf.add_theme_color_override("font_color",
				Stil.SIGNAL if summe > 0 else Stil.TEXT_MATT)

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
