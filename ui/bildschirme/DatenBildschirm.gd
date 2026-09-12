class_name DatenBildschirm
extends Bildschirm
## Kaderdaten pflegen — hier lassen sich die echten Spieler eintragen.
##
## Links stehen alle Vereine des Datensatzes mit ihrem Füllstand, rechts der
## Kader des gewählten Vereins: Zeile für Zeile bearbeitbar, dazu ein Feld für
## CSV, mit dem sich ein kompletter Kader in einem Rutsch einfügen lässt.
##
## Änderungen gelten für **neu angelegte** Karrieren. Eine laufende Karriere hat
## ihre Spieler bereits im Spielstand und bleibt unberührt.

var vereinsliste: VBoxContainer
var kaderbereich: VBoxContainer
var kopfzeile: Label
var meldung: Label
var fortschrittsleiste: HBoxContainer
var csv_feld: TextEdit
var gewaehlt: String = ""
var suche: String = ""
var entwurf: Array = []

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)

	var kopf := Stil.hbox(12)
	v.add_child(kopf)
	kopf.add_child(Stil.kopfzeile("Kaderdaten",
		"Echte Spieler eintragen. Wirkt auf neu angelegte Karrieren."))
	kopf.add_child(Stil.dehner())
	var projekt := Stil.knopf_geist("Ins Projekt schreiben", Stil.TUERKIS)
	projekt.tooltip_text = "Übernimmt Ihre Pflege in den Projektdatensatz. Nur möglich, wenn das Spiel aus dem Projektordner läuft."
	projekt.pressed.connect(func():
		var erg := Kaderpflege.in_projekt_schreiben()
		_melde(str(erg["grund"]), bool(erg["ok"])))
	kopf.add_child(projekt)
	var verwerfen := Stil.knopf_geist("Pflege verwerfen", Stil.ROT)
	verwerfen.tooltip_text = "Löscht alle selbst eingetragenen Kader. Der mitgelieferte Datensatz bleibt."
	verwerfen.pressed.connect(func():
		Kaderpflege.alles_verwerfen()
		entwurf = []
		_melde("Eigene Pflege verworfen.")
		aktualisieren())
	kopf.add_child(verwerfen)

	fortschrittsleiste = Stil.hbox(16)
	v.add_child(fortschrittsleiste)

	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	v.add_child(meldung)

	var haupt := Stil.hbox(12)
	haupt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(haupt)

	# Linke Spalte: Vereine
	var links := Stil.vbox(8)
	links.custom_minimum_size = Vector2(340, 0)
	haupt.add_child(links)
	var suchfeld := LineEdit.new()
	suchfeld.placeholder_text = "Verein suchen …"
	suchfeld.text_changed.connect(func(t):
		suche = str(t).to_lower()
		_vereine_zeichnen())
	links.add_child(suchfeld)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	links.add_child(scroll)
	vereinsliste = Stil.vbox(1)
	vereinsliste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vereinsliste)

	# Rechte Spalte: Kader des gewählten Vereins
	var rechts := Stil.vbox(8)
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haupt.add_child(rechts)
	kopfzeile = Stil.titel("Kein Verein gewählt", 1)
	rechts.add_child(kopfzeile)
	var scroll2 := ScrollContainer.new()
	scroll2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rechts.add_child(scroll2)
	kaderbereich = Stil.vbox(10)
	kaderbereich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll2.add_child(kaderbereich)

func aktualisieren() -> void:
	if vereinsliste == null:
		return
	_fortschritt_zeichnen()
	_vereine_zeichnen()
	_kader_zeichnen()

func _melde(text: String, gut: bool = true) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)

# --------------------------------------------------------------- Übersicht ---

func _fortschritt_zeichnen() -> void:
	leeren(fortschrittsleiste)
	var f := Kaderpflege.fortschritt()
	fortschrittsleiste.add_child(Stil.kachel("Vereine", str(int(f["vereine"]))))
	fortschrittsleiste.add_child(Stil.kachel("Vollständig",
		"%d" % int(f["voll"]), "ab %d Spielern" % Kaderpflege.SOLL,
		Stil.GRUEN if int(f["voll"]) > 0 else Stil.TEXT_MATT))
	fortschrittsleiste.add_child(Stil.kachel("Spieler", Stil.zahl(int(f["spieler"]))))
	fortschrittsleiste.add_child(Stil.kachel("Selbst gepflegt",
		str(Kaderpflege.eigene().size()), "Vereine", Stil.TUERKIS))

func _vereine_zeichnen() -> void:
	leeren(vereinsliste)
	var letzte_liga := ""
	var nummer := 0
	for e in Kaderpflege.vereinsliste():
		var eintrag: Dictionary = e
		var name: String = str(eintrag["name"])
		if suche != "" and not name.to_lower().contains(suche):
			continue
		if str(eintrag["liga"]) != letzte_liga:
			letzte_liga = str(eintrag["liga"])
			vereinsliste.add_child(Stil.abstand(6))
			vereinsliste.add_child(Stil.band(letzte_liga))
			nummer = 0
		var knopf := Stil.zeilen_knopf(nummer, name == gewaehlt, 30)
		nummer += 1
		knopf.pressed.connect(func():
			gewaehlt = name
			entwurf = []
			_vereine_zeichnen()
			_kader_zeichnen())
		var h := Stil.hbox(8)
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 8
		h.offset_right = -8
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		knopf.add_child(h)
		h.add_child(Stil.text(name, Stil.S_KLEIN))
		h.add_child(Stil.dehner())
		var anzahl: int = int(eintrag["anzahl"])
		var farbe: Color = Stil.GRUEN if anzahl >= Kaderpflege.SOLL else (
			Stil.GELB if anzahl > 0 else Stil.TEXT_SCHWACH)
		if bool(eintrag["eigen"]):
			h.add_child(Stil.abzeichen("EIGEN", Stil.TUERKIS))
		h.add_child(Stil.text(str(anzahl), Stil.S_KLEIN, farbe))
		vereinsliste.add_child(knopf)

# ------------------------------------------------------------------ Kader ---

func _kader_zeichnen() -> void:
	leeren(kaderbereich)
	if gewaehlt == "":
		kopfzeile.text = "Kein Verein gewählt"
		kaderbereich.add_child(Stil.leerzustand(
			"Wählen Sie links einen Verein aus.",
			"Grün heißt: genug Spieler hinterlegt. Gelb: angefangen. Grau: bisher nichts."))
		return
	if entwurf.is_empty():
		entwurf = []
		for e in Kaderpflege.kader(gewaehlt):
			entwurf.append((e as Dictionary).duplicate())
	kopfzeile.text = "%s — %d Spieler" % [gewaehlt, entwurf.size()]

	var werkzeuge := Stil.hbox(8)
	kaderbereich.add_child(werkzeuge)
	var neu := Stil.knopf_primaer("Spieler hinzufügen")
	neu.pressed.connect(func():
		entwurf.append(Kaderpflege.leerer_eintrag())
		_kader_zeichnen())
	werkzeuge.add_child(neu)
	var sichern := Stil.knopf("Kader sichern")
	sichern.pressed.connect(_sichern)
	werkzeuge.add_child(sichern)
	werkzeuge.add_child(Stil.dehner())
	var fehlend: int = maxi(Kaderpflege.SOLL - entwurf.size(), 0)
	if fehlend > 0:
		werkzeuge.add_child(Stil.abzeichen("NOCH %d BIS VOLLSTÄNDIG" % fehlend, Stil.GELB))
	else:
		werkzeuge.add_child(Stil.abzeichen("VOLLSTÄNDIG", Stil.GRUEN))

	var tabelle := Bausteine.karte_in(kaderbereich, "Spieler")
	var kopf := Stil.hbox(6)
	tabelle.add_child(kopf)
	for spalte in [["Vorname", 150], ["Nachname", 170], ["Pos", 70], ["Nation", 70],
			["Alter", 70], ["Stärke", 80], ["", 40]]:
		var l := Stil.etikett(str(spalte[0]))
		l.custom_minimum_size = Vector2(float(spalte[1]), 0)
		kopf.add_child(l)
	tabelle.add_child(Stil.trenner())
	for i in range(entwurf.size()):
		tabelle.add_child(_spielerzeile(i))
	if entwurf.is_empty():
		tabelle.add_child(Stil.matt("Noch keine Spieler eingetragen."))

	_csv_bereich()

func _spielerzeile(index: int) -> HBoxContainer:
	var e: Dictionary = entwurf[index]
	var zeile := Stil.hbox(6)
	zeile.add_child(_textfeld(e, "vorname", 150))
	zeile.add_child(_textfeld(e, "nachname", 170))

	var pos := OptionButton.new()
	pos.custom_minimum_size = Vector2(70, 0)
	for p in Kaderpflege.POSITIONEN:
		pos.add_item(str(p))
		pos.set_item_metadata(pos.item_count - 1, p)
		if str(e.get("position", "")) == str(p):
			pos.select(pos.item_count - 1)
	pos.item_selected.connect(func(i): e["position"] = str(pos.get_item_metadata(i)))
	zeile.add_child(pos)

	var nation := OptionButton.new()
	nation.custom_minimum_size = Vector2(70, 0)
	var schluessel: Array = Namen.KULTUR_NAME.keys()
	schluessel.sort()
	for n in schluessel:
		nation.add_item(str(n).to_upper())
		nation.set_item_metadata(nation.item_count - 1, n)
		if str(e.get("nation", "")) == str(n):
			nation.select(nation.item_count - 1)
	nation.item_selected.connect(func(i): e["nation"] = str(nation.get_item_metadata(i)))
	zeile.add_child(nation)

	zeile.add_child(_zahlenfeld(e, "alter", 16, 44, 70))
	zeile.add_child(_zahlenfeld(e, "staerke", 20, 99, 80))

	var weg := Stil.knopf_geist("✕", Stil.ROT)
	weg.custom_minimum_size = Vector2(40, 0)
	weg.tooltip_text = "Spieler entfernen"
	weg.pressed.connect(func():
		entwurf.remove_at(index)
		_kader_zeichnen())
	zeile.add_child(weg)
	return zeile

func _textfeld(e: Dictionary, schluessel: String, breite: float) -> LineEdit:
	var f := LineEdit.new()
	f.text = str(e.get(schluessel, ""))
	f.custom_minimum_size = Vector2(breite, 0)
	f.text_changed.connect(func(t): e[schluessel] = str(t))
	return f

func _zahlenfeld(e: Dictionary, schluessel: String, von: int, bis: int, breite: float) -> SpinBox:
	var f := SpinBox.new()
	f.min_value = von
	f.max_value = bis
	f.value = int(e.get(schluessel, von))
	f.custom_minimum_size = Vector2(breite, 0)
	f.value_changed.connect(func(w): e[schluessel] = int(w))
	return f

func _sichern() -> void:
	var sauber: Array = []
	var fehler: Array = []
	for e in entwurf:
		var normiert := Kaderpflege.normieren(e)
		var beanstandung := Kaderpflege.pruefen(normiert)
		if beanstandung.is_empty():
			sauber.append(normiert)
		else:
			fehler.append("%s: %s" % [str(normiert["nachname"]), ", ".join(beanstandung)])
	if not fehler.is_empty():
		_melde("Nicht gesichert — %s" % fehler[0], false)
		return
	Kaderpflege.setzen(gewaehlt, sauber)
	entwurf = []
	_melde("%s gesichert (%d Spieler)." % [gewaehlt, sauber.size()])
	aktualisieren()

# -------------------------------------------------------------------- CSV ---

func _csv_bereich() -> void:
	var karte := Bausteine.karte_in(kaderbereich, "Ganzen Kader auf einmal einfügen")
	karte.add_child(Stil.matt("Eine Zeile je Spieler: Vorname ; Nachname ; Position ; Nation ; Alter ; Stärke. "
		+ "Trennzeichen darf Semikolon, Tabulator oder Komma sein. Eine Kopfzeile wird erkannt. "
		+ "Position ist TW, LA, RL, RM, RR, RA oder KM; Nation ist das Länderkürzel wie de, dk, fr.", Stil.S_MINI))
	csv_feld = TextEdit.new()
	csv_feld.custom_minimum_size = Vector2(0, 150)
	csv_feld.placeholder_text = "Mathias;Gidsel;RM;dk;27;92\nHans;Lindberg;RA;dk;40;78"
	csv_feld.add_theme_font_size_override("font_size", Stil.S_KLEIN)
	karte.add_child(csv_feld)
	var knoepfe := Stil.hbox(8)
	karte.add_child(knoepfe)
	var ersetzen := Stil.knopf_primaer("Einlesen und ersetzen")
	ersetzen.pressed.connect(func(): _csv_uebernehmen(true))
	knoepfe.add_child(ersetzen)
	var anhaengen := Stil.knopf("Einlesen und anhängen")
	anhaengen.pressed.connect(func(): _csv_uebernehmen(false))
	knoepfe.add_child(anhaengen)
	knoepfe.add_child(Stil.dehner())
	var ausgeben := Stil.knopf_geist("Aktuellen Kader als CSV zeigen")
	ausgeben.pressed.connect(func():
		csv_feld.text = Kaderpflege.csv_ausgeben(gewaehlt)
		_melde("Kader als CSV ausgegeben — zum Kopieren markieren."))
	knoepfe.add_child(ausgeben)

func _csv_uebernehmen(ersetzen: bool) -> void:
	if csv_feld == null or csv_feld.text.strip_edges() == "":
		_melde("Das Feld ist leer.", false)
		return
	var erg := Kaderpflege.csv_einlesen(csv_feld.text)
	var neue: Array = erg["eintraege"]
	if neue.is_empty():
		_melde("Keine brauchbare Zeile gefunden.", false)
		return
	if ersetzen:
		entwurf = neue
	else:
		entwurf.append_array(neue)
	var text := "%d Spieler übernommen." % neue.size()
	var meldungen: Array = erg["meldungen"]
	if not meldungen.is_empty():
		text += " %d Hinweis(e): %s" % [meldungen.size(), str(meldungen[0])]
	_melde(text, meldungen.is_empty())
	_kader_zeichnen()
