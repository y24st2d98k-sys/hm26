class_name DatenBildschirm
extends Bildschirm
## Kaderdaten pflegen — hier lassen sich die echten Spieler eintragen.
##
## Links stehen alle Vereine des Datensatzes mit ihrem Füllstand, rechts der
## Kader des gewählten Vereins: Zeile für Zeile bearbeitbar, dazu ein Feld für
## CSV, mit dem sich ein kompletter Kader in einem Rutsch einfügen lässt.
##
## Änderungen erreichen auch laufende Karrieren: beim nächsten Laden gleicht der
## Spielstand sich mit dem Datensatz ab und zieht nach, was sich geändert hat,
## ohne die Entwicklung aus dem Spiel zu verwerfen (siehe Echtdaten.abgleich()).
##
## Neben den Grunddaten lässt sich hier jedes einzelne Attribut festschreiben.
## Was nicht gesetzt ist, würfelt das Spiel aus der Zielstärke aus — gesetzt
## wird also nur, was einen Spieler wirklich ausmacht, und nicht alles.

var vereinsliste: VBoxContainer
var kaderbereich: VBoxContainer
var kopfzeile: Label
var meldung: Label
var fortschrittsleiste: HBoxContainer
var csv_feld: TextEdit
var gewaehlt: String = ""
var suche: String = ""
var entwurf: Array = []
## Welche Zeile ihren Attributbereich offen hat. -1 heisst: keine.
var offen: int = -1
var plan_feld: TextEdit
var plan_liga: String = ""

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)

	var kopf := Stil.hbox(12)
	v.add_child(kopf)
	kopf.add_child(Stil.kopfzeile("Kaderdaten",
		"Echte Spieler eintragen. Laufende Karrieren ziehen beim nächsten Laden nach."))
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
		offen = -1
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

## Die Vereinsliste — aber nicht alle auf einmal.
##
## Die Welt hat mehrere hundert Vereine. Untereinander sind das gut drei
## Bildschirmhoehen: wer den gesuchten Verein durch Rollen findet, hat Glueck
## gehabt. Deshalb stehen die ersten GRENZE da und der Rest hinter der Suche —
## das Suchfeld ist der schnellere Weg, und jetzt auch der angebotene.
const GRENZE := 14

func _vereine_zeichnen() -> void:
	leeren(vereinsliste)
	var letzte_liga := ""
	var nummer := 0
	var gezeigt := 0
	var uebrig := 0
	for e in Kaderpflege.vereinsliste():
		var eintrag: Dictionary = e
		var name: String = str(eintrag["name"])
		if suche != "" and not name.to_lower().contains(suche):
			continue
		if gezeigt >= GRENZE:
			uebrig += 1
			continue
		gezeigt += 1
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
			offen = -1
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
	if uebrig > 0:
		vereinsliste.add_child(Stil.abstand(6))
		vereinsliste.add_child(Stil.matt("%d weitere Vereine — über die Suche erreichbar." % uebrig,
			Stil.S_MINI))

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
		offen = -1
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
	for spalte in [["Nr", 56], ["Vorname", 140], ["Nachname", 160], ["Pos", 70], ["Nation", 70],
			["Alter", 66], ["Stärke", 74], ["Attribute", 108], ["", 40]]:
		var l := Stil.etikett(str(spalte[0]))
		l.custom_minimum_size = Vector2(float(spalte[1]), 0)
		kopf.add_child(l)
	tabelle.add_child(Stil.trenner())
	for i in range(entwurf.size()):
		tabelle.add_child(_spielerzeile(i))
		if offen == i:
			tabelle.add_child(_attributbereich(entwurf[i]))
	if entwurf.is_empty():
		tabelle.add_child(Stil.matt("Noch keine Spieler eingetragen."))

	_csv_bereich()
	_spielplanbereich()

func _spielerzeile(index: int) -> HBoxContainer:
	var e: Dictionary = entwurf[index]
	var zeile := Stil.hbox(6)
	zeile.add_child(_zahlenfeld(e, "nummer", 0, 99, 56))
	zeile.add_child(_textfeld(e, "vorname", 140))
	zeile.add_child(_textfeld(e, "nachname", 160))

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

	zeile.add_child(_zahlenfeld(e, "alter", 16, 44, 66))
	zeile.add_child(_zahlenfeld(e, "staerke", 20, 99, 74))

	var gesetzt: int = (e.get("attribute", {}) as Dictionary).size()
	var attr := Stil.knopf_geist(
		"%d gesetzt" % gesetzt if gesetzt > 0 else "ausgewürfelt",
		Stil.TUERKIS if gesetzt > 0 else Stil.TEXT_MATT)
	attr.custom_minimum_size = Vector2(108, 0)
	attr.tooltip_text = "Einzelne Attribute festschreiben. Was hier leer bleibt, würfelt das Spiel aus der Zielstärke."
	attr.pressed.connect(func():
		offen = -1 if offen == index else index
		_kader_zeichnen())
	zeile.add_child(attr)

	var weg := Stil.knopf_geist("✕", Stil.ROT)
	weg.custom_minimum_size = Vector2(40, 0)
	weg.tooltip_text = "Spieler entfernen"
	weg.pressed.connect(func():
		entwurf.remove_at(index)
		_kader_zeichnen())
	zeile.add_child(weg)
	return zeile

## Der aufgeklappte Attributbereich eines Spielers.
##
## Nur was gesetzt ist, steht im Datensatz. Ein Feld auf 0 loescht den Eintrag
## wieder — dann wuerfelt das Spiel den Wert aus der Zielstaerke, so wie bei
## jedem anderen. Das ist wichtig: wer alle 20 Attribute festschreibt, nimmt
## dem Spieler jede Streuung und macht aus zwei gleich starken Spielern
## dieselbe Person.
func _attributbereich(e: Dictionary) -> Control:
	var rahmen := Stil.vbox(8)
	rahmen.add_theme_constant_override("margin_left", 16)
	var werte: Dictionary = e.get("attribute", {})
	var ist_tw: bool = str(e.get("position", "")) == "TW"

	var kopf := Stil.hbox(8)
	kopf.add_child(Stil.matt("Gesetzte Werte gelten unverändert, leere Felder würfelt das Spiel aus."))
	kopf.add_child(Stil.dehner())
	if str(e.get("position", "")) != "TW":
		var stamm := CheckBox.new()
		stamm.text = "Siebenmeterschütze"
		stamm.tooltip_text = "Er wirft die Siebenmeter seines Vereins, solange er auf dem Feld steht."
		stamm.button_pressed = bool(e.get("stammschuetze", false))
		stamm.toggled.connect(func(an):
			if an:
				e["stammschuetze"] = true
			else:
				e.erase("stammschuetze"))
		kopf.add_child(stamm)
	var leeren := Stil.knopf_geist("Alle zurücksetzen", Stil.ROT)
	leeren.pressed.connect(func():
		e.erase("attribute")
		_kader_zeichnen())
	kopf.add_child(leeren)
	rahmen.add_child(kopf)

	var gruppen: Array = [["Technik", Spielerfabrik.ATTR_TECHNIK], ["Athletik", Spielerfabrik.ATTR_ATHLETIK],
		["Mental", Spielerfabrik.ATTR_MENTAL]]
	if ist_tw:
		gruppen.push_front(["Torwart", Spielerfabrik.ATTR_TORWART])
	else:
		gruppen.insert(2, ["Abwehr", Spielerfabrik.ATTR_DEFENSIV])
	for gruppe in gruppen:
		rahmen.add_child(Stil.etikett(str(gruppe[0])))
		var gitter := GridContainer.new()
		gitter.columns = 3
		gitter.add_theme_constant_override("h_separation", 12)
		gitter.add_theme_constant_override("v_separation", 4)
		for name in (gruppe[1] as Array):
			gitter.add_child(_attributfeld(e, werte, str(name)))
		rahmen.add_child(gitter)
	rahmen.add_child(Stil.trenner())
	return rahmen

func _attributfeld(e: Dictionary, werte: Dictionary, name: String) -> Control:
	var reihe := Stil.hbox(6)
	var l := Stil.matt(str(Spielerfabrik.ATTR_LABEL.get(name, name)))
	l.custom_minimum_size = Vector2(150, 0)
	reihe.add_child(l)
	var feld := SpinBox.new()
	feld.min_value = 0
	feld.max_value = 20
	feld.step = 1
	feld.custom_minimum_size = Vector2(74, 0)
	feld.value = float(werte.get(name, 0.0))
	feld.tooltip_text = "0 heißt: nicht gesetzt."
	feld.value_changed.connect(func(w):
		var tabelle: Dictionary = e.get("attribute", {})
		if w <= 0.0:
			tabelle.erase(name)
		else:
			tabelle[name] = w
		if tabelle.is_empty():
			e.erase("attribute")
		else:
			e["attribute"] = tabelle)
	reihe.add_child(feld)
	return reihe

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


# ------------------------------------------------------------- Spielplan ---
#
# Eine ausgeloste Doppelrunde ist eine Doppelrunde, aber nicht die richtige.
# Der mitgelieferte Datensatz enthaelt so viel, wie sich belegen liess; den
# vollstaendigen offiziellen Plan fuegt man hier ein.

func _spielplanbereich() -> void:
	var ligen: Array = _ligennamen()
	if ligen.is_empty():
		return
	var karte := Bausteine.karte_in(kaderbereich, "Spielplan einspielen")
	karte.add_child(Stil.matt(
		"Eine Zeile je Partie: Spieltag ; Datum ; Zeit ; Heim ; Gast. Datum und Zeit dürfen leer bleiben. "
		+ "Vereinsnamen müssen genau so geschrieben sein wie in der Ligaübersicht. "
		+ "Ein vollständiger Plan gilt unverändert; ein angefangener wird ergänzt, "
		+ "solange mindestens ein Spieltag komplett ist.", Stil.S_MINI))

	var wahlzeile := Stil.hbox(8)
	karte.add_child(wahlzeile)
	wahlzeile.add_child(Stil.matt("Liga"))
	var wahl := OptionButton.new()
	for i in range(ligen.size()):
		wahl.add_item(str(ligen[i]))
		wahl.set_item_metadata(i, str(ligen[i]))
		if str(ligen[i]) == plan_liga:
			wahl.select(i)
	if plan_liga == "":
		plan_liga = str(ligen[0])
		wahl.select(0)
	wahl.item_selected.connect(func(i):
		plan_liga = str(wahl.get_item_metadata(i))
		_kader_zeichnen())
	wahlzeile.add_child(wahl)
	wahlzeile.add_child(Stil.dehner())
	var vereine: int = _vereinszahl(plan_liga)
	wahlzeile.add_child(Stil.matt(
		Spielplanpflege.beurteilen(Spielplanpflege.partien(plan_liga), vereine), Stil.S_KLEIN))

	plan_feld = TextEdit.new()
	plan_feld.custom_minimum_size = Vector2(0, 150)
	plan_feld.placeholder_text = "1;2026-08-27;19:00;THW Kiel;TBV Lemgo Lippe\n1;2026-08-27;20:00;Füchse Berlin;MT Melsungen"
	plan_feld.add_theme_font_size_override("font_size", Stil.S_KLEIN)
	karte.add_child(plan_feld)

	var knoepfe := Stil.hbox(8)
	karte.add_child(knoepfe)
	var einlesen := Stil.knopf_primaer("Einlesen und ersetzen")
	einlesen.pressed.connect(_spielplan_uebernehmen)
	knoepfe.add_child(einlesen)
	knoepfe.add_child(Stil.dehner())
	var zeigen := Stil.knopf_geist("Aktuellen Plan als CSV zeigen")
	zeigen.pressed.connect(func():
		plan_feld.text = Spielplanpflege.csv_ausgeben(plan_liga)
		_melde("Spielplan als CSV ausgegeben — zum Kopieren markieren."))
	knoepfe.add_child(zeigen)
	if Spielplanpflege.ist_eigen(plan_liga):
		var weg := Stil.knopf_geist("Eigenen Plan verwerfen", Stil.ROT)
		weg.tooltip_text = "Danach gilt wieder der mitgelieferte Datensatz."
		weg.pressed.connect(func():
			Spielplanpflege.setzen(plan_liga, [])
			_melde("Eigener Spielplan verworfen.")
			_kader_zeichnen())
		knoepfe.add_child(weg)

func _spielplan_uebernehmen() -> void:
	if plan_feld == null or plan_feld.text.strip_edges() == "":
		_melde("Das Feld ist leer.", false)
		return
	var erg := Spielplanpflege.csv_einlesen(plan_feld.text, _vereinsnamen(plan_liga))
	var neue: Array = erg["eintraege"]
	if neue.is_empty():
		_melde("Keine brauchbare Zeile gefunden.", false)
		return
	# Unbekannte Vereinsnamen sind kein Hinweis, sondern ein Abbruchgrund: der
	# ganze Plan wuerde spaeter verworfen, und zwar stillschweigend.
	if bool(erg["unbekannt"]):
		_melde("Nicht übernommen — %s" % str((erg["meldungen"] as Array)[-1]), false)
		return
	Spielplanpflege.setzen(plan_liga, neue)
	var text := "%d Partien übernommen. %s" % [neue.size(),
		Spielplanpflege.beurteilen(neue, _vereinszahl(plan_liga))]
	var meldungen: Array = erg["meldungen"]
	if not meldungen.is_empty():
		text += " %d Hinweis(e): %s" % [meldungen.size(), str(meldungen[0])]
	_melde(text, meldungen.is_empty())
	_kader_zeichnen()

func _ligennamen() -> Array:
	var namen: Array = []
	for n in Echtdaten.nationen():
		for l in (n as Dictionary).get("ligen", []):
			if not (l as Dictionary).get("vereine", []).is_empty():
				namen.append(str((l as Dictionary)["name"]))
	return namen

func _vereinsnamen(liganame: String) -> Array:
	for n in Echtdaten.nationen():
		for l in (n as Dictionary).get("ligen", []):
			if str((l as Dictionary).get("name", "")) != liganame:
				continue
			var namen: Array = []
			for v in (l as Dictionary).get("vereine", []):
				namen.append(str((v as Dictionary)["name"]))
			return namen
	return []

func _vereinszahl(liganame: String) -> int:
	return _vereinsnamen(liganame).size()
