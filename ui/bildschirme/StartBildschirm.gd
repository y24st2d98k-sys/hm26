class_name StartBildschirm
extends Control
## Startmenue: neue Karriere anlegen (Trainerprofil + Vereinswahl) oder laden.

signal spiel_gestartet()

var seiten: Dictionary = {}
var aktuelle_seite: String = "menue"
var trainer_eingabe: Dictionary = {}
var vereinsliste: VBoxContainer
var slotliste: VBoxContainer
var gewaehlte_liga: String = ""
var feld_vorname: LineEdit
var feld_nachname: LineEdit
var wahl_nation: OptionButton
var wahl_hintergrund: OptionButton
var hintergrund_text: Label
var wahl_alter: HSlider
var alter_label: Label
var vorschau_welt: Dictionary = {}
var echte_welt: bool = true

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	theme = Stil.theme()
	var bg := ColorRect.new()
	bg.color = Stil.GRUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_baue_menue()
	_baue_trainer()
	_baue_vereinswahl()
	_baue_laden()
	_seite("menue")

func aktualisieren() -> void:
	_slots_fuellen()

func _seite(id: String) -> void:
	aktuelle_seite = id
	for k in seiten.keys():
		seiten[k].visible = k == id

func _neue_seite(id: String) -> VBoxContainer:
	var mitte := MarginContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	mitte.add_theme_constant_override("margin_left", 60)
	mitte.add_theme_constant_override("margin_right", 60)
	mitte.add_theme_constant_override("margin_top", 32)
	mitte.add_theme_constant_override("margin_bottom", 32)
	add_child(mitte)
	var v := Stil.vbox(14)
	mitte.add_child(v)
	seiten[id] = mitte
	return v

func _kopf(v: VBoxContainer, untertitel: String) -> void:
	var t := Stil.titel("HALLENHERZ", 0, Stil.AKZENT)
	t.add_theme_font_size_override("font_size", Stil.S_RIESIG)
	v.add_child(t)
	v.add_child(Stil.matt(untertitel, Stil.S_NORMAL))
	v.add_child(Stil.trenner())

# ----------------------------------------------------------------- Menue ---

func _baue_menue() -> void:
	var v := _neue_seite("menue")
	_kopf(v, "Handball-Manager — Ihre Karriere an der Seitenlinie")
	v.add_child(Stil.abstand(10))
	var box := Stil.vbox(10)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.custom_minimum_size = Vector2(320, 0)
	v.add_child(box)
	var neu := Stil.knopf_primaer("Neue Karriere beginnen")
	neu.pressed.connect(func(): _seite("trainer"))
	box.add_child(neu)
	var laden := Stil.knopf("Spielstand laden")
	laden.pressed.connect(func():
		_slots_fuellen()
		_seite("laden"))
	box.add_child(laden)
	var ende := Stil.knopf("Beenden")
	ende.pressed.connect(func(): get_tree().quit())
	box.add_child(ende)
	v.add_child(Stil.abstand(24))
	if Echtdaten.verfuegbar():
		var quelle := Stil.karte("Datenbestand")
		v.add_child(Stil.karte_wurzel(quelle))
		quelle.add_child(Stil.info_zeile("Ligen und Vereine", "Stand %s" % Echtdaten.stand(), Stil.GRUEN))
		quelle.add_child(Stil.info_zeile("Echte Spieler hinterlegt", "%d bei %d Vereinen" % [
			Echtdaten.echte_spieler_gesamt(), Echtdaten.vereine_mit_kader()]))
		var h := Stil.text(Echtdaten.hinweis(), Stil.S_MINI, Stil.TEXT_MATT)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.custom_minimum_size = Vector2(700, 0)
		quelle.add_child(h)
	var info := Stil.karte("Was Sie erwartet")
	v.add_child(Stil.karte_wurzel(info))
	for zeile in [
		"Fünf Nationen, acht Ligen, 96 Vereine mit echtem Auf- und Abstieg, nationalen Pokalen und zwei europäischen Wettbewerben.",
		"Eine Spielsimulation mit Zeitstrafen, Unterzahl, 7-gegen-6, getrennten Angriffs- und Abwehrformationen — und dem Hallenpuls, der Ihre Halle zum Mitspieler macht.",
		"Ein Lastkonto, das jede Minute Spielzeit festhält und Rotation zu einer echten Entscheidung macht.",
		"Eine Trainer-Handschrift, die sich über Jahre aus Ihrer tatsächlichen Arbeitsweise formt — mit spürbaren Folgen.",
		"Eine Kabine mit Wortführern, Gruppen und Reibung, die Ihre Mannschaft trägt oder zerlegt.",
	]:
		var l := Stil.text("•  " + zeile, Stil.S_KLEIN, Stil.TEXT_MATT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(l)

# --------------------------------------------------------- Trainerprofil ---

func _baue_trainer() -> void:
	var v := _neue_seite("trainer")
	_kopf(v, "Wer sind Sie?")
	var karte := Stil.karte("Trainerprofil")
	karte.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(Stil.karte_wurzel(karte))
	var raster := GridContainer.new()
	raster.columns = 2
	raster.add_theme_constant_override("h_separation", 14)
	raster.add_theme_constant_override("v_separation", 10)
	karte.add_child(raster)

	raster.add_child(Stil.matt("Vorname"))
	feld_vorname = LineEdit.new()
	feld_vorname.custom_minimum_size = Vector2(240, 0)
	feld_vorname.text = Namen.vorname("de")
	raster.add_child(feld_vorname)

	raster.add_child(Stil.matt("Nachname"))
	feld_nachname = LineEdit.new()
	feld_nachname.custom_minimum_size = Vector2(240, 0)
	feld_nachname.text = Namen.nachname("de")
	raster.add_child(feld_nachname)

	raster.add_child(Stil.matt("Nation"))
	wahl_nation = OptionButton.new()
	for k in Namen.KULTUREN:
		wahl_nation.add_item(str(Namen.KULTUR_NAME.get(k, k)))
		wahl_nation.set_item_metadata(wahl_nation.item_count - 1, k)
	raster.add_child(wahl_nation)

	raster.add_child(Stil.matt("Alter"))
	var alterbox := Stil.hbox(8)
	wahl_alter = HSlider.new()
	wahl_alter.min_value = 28
	wahl_alter.max_value = 62
	wahl_alter.value = 38
	wahl_alter.custom_minimum_size = Vector2(190, 0)
	alter_label = Stil.text("38 Jahre", Stil.S_KLEIN)
	wahl_alter.value_changed.connect(func(w): alter_label.text = "%d Jahre" % int(w))
	alterbox.add_child(wahl_alter)
	alterbox.add_child(alter_label)
	raster.add_child(alterbox)

	raster.add_child(Stil.matt("Werdegang"))
	wahl_hintergrund = OptionButton.new()
	for k in Trainerkarriere.HINTERGRUENDE.keys():
		wahl_hintergrund.add_item(str(Trainerkarriere.HINTERGRUENDE[k]["name"]))
		wahl_hintergrund.set_item_metadata(wahl_hintergrund.item_count - 1, k)
	wahl_hintergrund.item_selected.connect(func(_i): _hintergrund_text())
	raster.add_child(wahl_hintergrund)

	hintergrund_text = Stil.text("", Stil.S_KLEIN, Stil.TEXT_MATT)
	hintergrund_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hintergrund_text.custom_minimum_size = Vector2(460, 0)
	karte.add_child(hintergrund_text)
	_hintergrund_text()

	var knopfzeile := Stil.hbox(10)
	v.add_child(knopfzeile)
	var zurueck := Stil.knopf("Zurück")
	zurueck.pressed.connect(func(): _seite("menue"))
	knopfzeile.add_child(zurueck)
	var weiter := Stil.knopf_primaer("Verein wählen")
	weiter.pressed.connect(_zur_vereinswahl)
	knopfzeile.add_child(weiter)

func _hintergrund_text() -> void:
	var k: String = str(wahl_hintergrund.get_item_metadata(wahl_hintergrund.selected)) if wahl_hintergrund.selected >= 0 else "exprofi"
	var hg: Dictionary = Trainerkarriere.HINTERGRUENDE.get(k, {})
	hintergrund_text.text = "%s  (Startruf: %d)" % [str(hg.get("text", "")), int(hg.get("ruf", 30))]

# ---------------------------------------------------------- Vereinswahl ---

func _baue_vereinswahl() -> void:
	var v := _neue_seite("vereinswahl")
	_kopf(v, "Welchen Verein übernehmen Sie?")
	var filterzeile := Stil.hbox(10)
	v.add_child(filterzeile)
	filterzeile.add_child(Stil.matt("Liga"))
	var liga_wahl := OptionButton.new()
	liga_wahl.name = "LigaWahl"
	filterzeile.add_child(liga_wahl)
	liga_wahl.item_selected.connect(func(i):
		gewaehlte_liga = str(liga_wahl.get_item_metadata(i))
		_vereine_fuellen())
	filterzeile.add_child(Stil.dehner())
	var welt_haken := CheckBox.new()
	welt_haken.text = "Echte Vereine"
	welt_haken.button_pressed = true
	welt_haken.tooltip_text = "Angehakt: echte Ligen, Vereine und — soweit hinterlegt — echte Spieler aus daten/ligen.json und daten/kader.json.\nAbgehakt: eine vollständig erfundene Welt."
	welt_haken.toggled.connect(func(an):
		echte_welt = an
		vorschau_welt = {}
		_zur_vereinswahl())
	filterzeile.add_child(welt_haken)
	var neu_wuerfeln := Stil.knopf("Andere Welt erzeugen")
	neu_wuerfeln.pressed.connect(func():
		vorschau_welt = {}
		_zur_vereinswahl())
	filterzeile.add_child(neu_wuerfeln)
	var zurueck := Stil.knopf("Zurück")
	zurueck.pressed.connect(func(): _seite("trainer"))
	filterzeile.add_child(zurueck)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	vereinsliste = Stil.vbox(6)
	vereinsliste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vereinsliste)
	set_meta("liga_wahl", liga_wahl)

func _zur_vereinswahl() -> void:
	if vorschau_welt.is_empty():
		vorschau_welt = Weltgenerator.erzeuge(2026, int(Time.get_unix_time_from_system()) % 2147483647, echte_welt)
	var liga_wahl: OptionButton = get_meta("liga_wahl")
	liga_wahl.clear()
	var ids: Array = vorschau_welt["ligen"].keys()
	ids.sort_custom(func(a, b):
		var la: Dictionary = vorschau_welt["ligen"][a]
		var lb: Dictionary = vorschau_welt["ligen"][b]
		if int(la["stufe"]) != int(lb["stufe"]):
			return int(la["stufe"]) < int(lb["stufe"])
		return float(la["ruf"]) > float(lb["ruf"]))
	for lid in ids:
		liga_wahl.add_item(str(vorschau_welt["ligen"][lid]["name"]))
		liga_wahl.set_item_metadata(liga_wahl.item_count - 1, lid)
	gewaehlte_liga = str(ids[0])
	_vereine_fuellen()
	_seite("vereinswahl")

func _vereine_fuellen() -> void:
	Bildschirm.leeren(vereinsliste)
	if gewaehlte_liga == "":
		return
	var liga: Dictionary = vorschau_welt["ligen"][gewaehlte_liga]
	var vereine: Array = (liga["vereine"] as Array).duplicate()
	vereine.sort_custom(func(a, b): return float(vorschau_welt["vereine"][a]["ruf"]) > float(vorschau_welt["vereine"][b]["ruf"]))
	for cid in vereine:
		vereinsliste.add_child(_vereinskarte(cid))

func _vereinskarte(cid: String) -> Control:
	var v: Dictionary = vorschau_welt["vereine"][cid]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Stil.box(Stil.FLAECHE, Stil.R_NORMAL, Stil.RAND))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	p.add_child(m)
	var h := Stil.hbox(14)
	m.add_child(h)

	var w := Wappen.new()
	w.custom_minimum_size = Vector2(42, 42)
	w.setze(v["wappen"])
	h.add_child(w)

	var links := Stil.vbox(2)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(links)
	links.add_child(Stil.text(str(v["name"]), Stil.S_NORMAL))
	var kader_staerke := 0.0
	for sid in v["kader"]:
		kader_staerke += Spielerfabrik.gesamt(vorschau_welt["spieler"][sid])
	kader_staerke /= maxf(float((v["kader"] as Array).size()), 1.0)
	links.add_child(Stil.matt("%s · gegründet %d · %s (%s Plätze)" % [
		v["ort"], int(v["gegruendet"]), v["halle"]["name"], Stil.zahl(int(v["halle"]["kapazitaet"]))], Stil.S_MINI))

	var rechts := Stil.vbox(2)
	rechts.custom_minimum_size = Vector2(260, 0)
	h.add_child(rechts)
	rechts.add_child(Stil.info_zeile("Ruf", "%d" % int(v["ruf"]), Stil.wert_farbe(float(v["ruf"]), 100.0)))
	rechts.add_child(Stil.info_zeile("Kaderstärke", "%d" % int(kader_staerke), Stil.wert_farbe(kader_staerke, 100.0)))
	rechts.add_child(Stil.info_zeile("Transferbudget", Stil.geld(float(v["transferbudget"]))))
	rechts.add_child(Stil.info_zeile("Erwartung", str(v["vorstand"]["saisonziel"])))

	var knopf := Stil.knopf_primaer("Übernehmen")
	knopf.pressed.connect(func(): _starte(cid))
	var knopfbox := Stil.vbox(0)
	knopfbox.alignment = BoxContainer.ALIGNMENT_CENTER
	knopfbox.add_child(knopf)
	h.add_child(knopfbox)
	return p

func _starte(cid: String) -> void:
	var nation: String = str(wahl_nation.get_item_metadata(wahl_nation.selected)) if wahl_nation.selected >= 0 else "de"
	var hintergrund: String = str(wahl_hintergrund.get_item_metadata(wahl_hintergrund.selected)) if wahl_hintergrund.selected >= 0 else "exprofi"
	Welt.neues_spiel(cid, {
		"vorname": feld_vorname.text.strip_edges() if feld_vorname.text.strip_edges() != "" else "Alex",
		"nachname": feld_nachname.text.strip_edges() if feld_nachname.text.strip_edges() != "" else "Bergmann",
		"nation": nation,
		"alter": int(wahl_alter.value),
		"hintergrund": hintergrund,
	}, int(vorschau_welt.get("saat", 0)), echte_welt)
	spiel_gestartet.emit()

# ------------------------------------------------------------------ Laden ---

func _baue_laden() -> void:
	var v := _neue_seite("laden")
	_kopf(v, "Gespeicherte Karrieren")
	slotliste = Stil.vbox(8)
	v.add_child(slotliste)
	var zurueck := Stil.knopf("Zurück")
	zurueck.pressed.connect(func(): _seite("menue"))
	v.add_child(zurueck)

func _slots_fuellen() -> void:
	if slotliste == null:
		return
	Bildschirm.leeren(slotliste)
	var plaetze: Array[int] = [Welt.AUTOSLOT]
	for nr in range(1, Welt.SLOTS + 1):
		plaetze.append(nr)
	for slot in plaetze:
		var info := Welt.slot_info(slot)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Stil.box(Stil.FLAECHE, Stil.R_NORMAL, Stil.RAND))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 12)
		m.add_theme_constant_override("margin_right", 12)
		m.add_theme_constant_override("margin_top", 8)
		m.add_theme_constant_override("margin_bottom", 8)
		p.add_child(m)
		var h := Stil.hbox(12)
		m.add_child(h)
		h.add_child(Stil.text("Automatik" if slot == Welt.AUTOSLOT else "Platz %d" % slot,
			Stil.S_NORMAL, Stil.TUERKIS if slot == Welt.AUTOSLOT else Stil.AKZENT))
		if info.is_empty():
			h.add_child(Stil.matt("— leer —"))
			h.add_child(Stil.dehner())
		else:
			var v2 := Stil.vbox(1)
			v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v2.add_child(Stil.text("%s — %s" % [str(info.get("verein", "?")), str(info.get("trainer", "?"))], Stil.S_KLEIN))
			v2.add_child(Stil.matt("Saison %s · %s · gespeichert %s" % [
				str(info.get("saison", "")), str(info.get("datum", "")), str(info.get("gespeichert", ""))], Stil.S_MINI))
			h.add_child(v2)
			var laden := Stil.knopf_primaer("Laden")
			var s := slot
			laden.pressed.connect(func():
				if Welt.laden(s):
					spiel_gestartet.emit())
			h.add_child(laden)
		slotliste.add_child(p)
