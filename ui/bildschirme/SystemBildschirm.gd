class_name SystemBildschirm
extends Bildschirm
## Spielstände speichern und laden.

var liste: VBoxContainer
var meldung: Label

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	v.add_child(Stil.titel("Spielstand", 0))
	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	v.add_child(meldung)
	# Als gewoehnliches Etikett meldete dieser Satz 1199 Pixel Mindestbreite an
	# und machte damit den ganzen Bildschirm breiter als das Fenster.
	v.add_child(Bausteine.fliesstext("Jeder Spielstand enthält den kompletten Zustand der Spielwelt. Beim Laden werden fehlende Felder automatisch ergänzt, damit alte Stände auch nach Erweiterungen des Spiels funktionieren.", Stil.S_KLEIN))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	liste = Stil.vbox(8)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(liste)

func aktualisieren() -> void:
	if liste == null:
		return
	leeren(liste)
	# Gemessen: die Automatik ist 826 Pixel breit, die Spielstände 528.
	# Nebeneinander passen beide.
	var oben := Stil.hbox(Stil.A_NORMAL)
	liste.add_child(oben)
	var links := Stil.vbox(Stil.A_NORMAL)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(links)
	links.add_child(_automatik())
	links.add_child(_ton())
	links.add_child(_verlassen())
	# Ein Platz ist eine Zeile, keine Karte.
	#
	# Vorher trug jeder der sechs Plaetze eine eigene Karte mit vier
	# Beschriftungszeilen: zusammen weit mehr als eine Bildschirmhoehe fuer
	# eine Liste, in der man eine Zeile sucht und einen Knopf drueckt.
	var rechts := Stil.vbox(Stil.A_NORMAL)
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(rechts)
	var plaetze := Bausteine.karte_in(rechts, "Spielstände")
	_slot_zeile(plaetze, Welt.AUTOSLOT)
	for slot in range(1, Welt.SLOTS + 1):
		_slot_zeile(plaetze, slot)


## Der Weg aus der laufenden Karriere heraus.
##
## Bis hierher gab es ihn nicht: Wer einmal im Spiel war, kam ohne das Fenster
## zu schliessen weder zu einer neuen Karriere noch aus dem Programm. Beides
## verwirft, was seit dem letzten Speichern passiert ist — deshalb fragt es
## nach, und deshalb steht daneben, wann zuletzt gespeichert wurde.
func _verlassen() -> Control:
	var karte := Stil.karte("Spiel verlassen")
	karte.add_child(Bausteine.fliesstext(
		"Eine neue Karriere und das Beenden verwerfen alles, was seit dem letzten Speichern passiert ist.",
		Stil.S_KLEIN))
	var stand: Dictionary = Welt.slot_info(Welt.AUTOSLOT)
	if not stand.is_empty():
		karte.add_child(Stil.matt("Letzte automatische Sicherung: %s" % str(stand.get("gespeichert", "—")),
			Stil.S_MINI))
	karte.add_child(_verlassenzeile(karte, "Zum Startbildschirm",
		"Dort liegen neue Karriere, Spielstand laden und Beenden.", Stil.AKZENT, false))
	karte.add_child(_verlassenzeile(karte, "Hallenherz beenden",
		"Schließt das Programm.", Stil.ROT, true))
	return Stil.karte_wurzel(karte)

## Eine Zeile, die beim ersten Druck nachfragt und beim zweiten handelt.
func _verlassenzeile(karte: Node, beschriftung: String, hinweis: String,
		farbe: Color, beenden: bool) -> Control:
	var zeile := Stil.hbox(10)
	var knopf := Stil.knopf(beschriftung)
	knopf.disabled = Welt.daten.is_empty()
	zeile.add_child(knopf)
	var frage := Stil.text("Sicher? Ungesichertes geht verloren.", Stil.S_KLEIN, farbe)
	frage.visible = false
	zeile.add_child(frage)
	var ja := Stil.knopf_flach("Ja", farbe)
	ja.visible = false
	zeile.add_child(ja)
	var nein := Stil.knopf_flach("Abbrechen", Stil.TEXT_MATT)
	nein.visible = false
	zeile.add_child(nein)
	var hilfe := Stil.matt(hinweis, Stil.S_MINI)
	hilfe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(hilfe)
	knopf.pressed.connect(func():
		knopf.visible = false
		hilfe.visible = false
		frage.visible = true
		ja.visible = true
		nein.visible = true)
	nein.pressed.connect(func():
		knopf.visible = true
		hilfe.visible = true
		frage.visible = false
		ja.visible = false
		nein.visible = false)
	ja.pressed.connect(func():
		if beenden:
			get_tree().quit()
			return
		var app := _app()
		if app != null:
			app.zum_start())
	return zeile

## Die App über der Bildschirmhierarchie — sie hält den Startbildschirm.
func _app() -> Node:
	var knoten: Node = self
	while knoten != null:
		if knoten.has_method("zum_start"):
			return knoten
		knoten = knoten.get_parent()
	return null

## Lautstärke. Ein Regler, kein Mischpult.
##
## Es gibt genau eine Tonquelle im Spiel — die Halle während der Live-Partie
## samt Pfiff und Jubel. Drei Regler für Musik, Effekte und Sprache wären drei
## Regler für nichts.
func _ton() -> Control:
	var karte := Stil.karte("Ton")
	karte.add_child(Stil.matt(
		"Halle, Pfiff und Jubel während der Live-Partie. Alle Klänge werden beim Start erzeugt — das Spiel bringt keine Audiodateien mit. Ganz links ist aus.",
		Stil.S_KLEIN))
	var zeile := Stil.hbox(12)
	karte.add_child(zeile)
	var regler := HSlider.new()
	regler.min_value = 0.0
	regler.max_value = 100.0
	regler.step = 5.0
	regler.value = float(Welt.einstellung("lautstaerke", 0.55)) * 100.0
	regler.custom_minimum_size = Vector2(260, 0)
	regler.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(regler)
	var wert := Stil.text("%d %%" % int(regler.value), Stil.S_KLEIN, Stil.TEXT)
	wert.custom_minimum_size = Vector2(56, 0)
	zeile.add_child(wert)
	var probe := Stil.knopf("Probe")
	probe.tooltip_text = "Einen Pfiff und einen Torjubel abspielen."
	probe.pressed.connect(func():
		Klang.spiele("pfiff", -2.0)
		Klang.spiele("jubel", 0.0))
	zeile.add_child(probe)
	regler.value_changed.connect(func(v):
		wert.text = "%d %%" % int(v)
		Klang.pegel_setzen(v / 100.0)
		if not Welt.daten.is_empty():
			(Welt.daten["einstellungen"] as Dictionary)["lautstaerke"] = v / 100.0)
	return Stil.karte_wurzel(karte)

## Schalter für die wöchentliche Sicherung.
func _automatik() -> Control:
	var karte := Stil.karte("Automatische Sicherung")
	karte.add_child(Stil.matt("Jeden Montag und zu jedem Saisonwechsel legt das Spiel eine Sicherung auf Platz 0 an. Der Platz wird dabei überschrieben.", Stil.S_KLEIN))
	var an := Stil.schalter("")
	an.text = "Automatisch sichern"
	an.button_pressed = bool(Welt.einstellung("autospeichern", true))
	an.disabled = Welt.daten.is_empty()
	an.toggled.connect(func(wert):
		if Welt.daten.is_empty():
			return
		(Welt.daten["einstellungen"] as Dictionary)["autospeichern"] = wert)
	karte.add_child(an)
	var jetzt := Stil.knopf("Jetzt sichern")
	jetzt.disabled = Welt.daten.is_empty()
	jetzt.pressed.connect(func():
		if Welt.speichern(Welt.AUTOSLOT, "Automatisch"):
			_melde("Sicherung angelegt.")
		else:
			_melde("Sicherung fehlgeschlagen.", false)
		aktualisieren())
	karte.add_child(jetzt)
	return Stil.karte_wurzel(karte)

func _slot_zeile(eltern: Node, slot: int) -> void:
	var info := Welt.slot_info(slot)
	var zeile := Stil.hbox(10)
	eltern.add_child(zeile)
	zeile.add_child(Stil.abzeichen("PLATZ 0 · AUTOMATIK" if slot == Welt.AUTOSLOT else "PLATZ %d" % slot,
		Stil.TUERKIS if slot == Welt.AUTOSLOT else Stil.TEXT_SCHWACH))
	if info.is_empty():
		zeile.add_child(Stil.matt("— leer —", Stil.S_KLEIN))
		zeile.add_child(Stil.dehner())
	else:
		var verein := Stil.text("%s · %s" % [str(info.get("verein", "")), str(info.get("trainer", ""))],
			Stil.S_KLEIN)
		zeile.add_child(Stil.beschnitten(verein, 20.0))
		zeile.add_child(Stil.dehner())
		var stand := Stil.matt("%s · %s" % [str(info.get("saison", "")),
			str(info.get("datum", ""))], Stil.S_MINI)
		stand.tooltip_text = "Gespeichert am %s" % str(info.get("gespeichert", ""))
		zeile.add_child(stand)
	var speichern := Stil.knopf_flach("Speichern", Stil.AKZENT)
	speichern.pressed.connect(func():
		if Welt.speichern(slot):
			_melde("Auf Platz %d gespeichert." % slot)
		else:
			_melde("Speichern fehlgeschlagen.", false)
		aktualisieren())
	zeile.add_child(speichern)
	if info.is_empty():
		return
	var laden := Stil.knopf_flach("Laden")
	laden.pressed.connect(func():
		if Welt.laden(slot):
			_melde("Spielstand geladen.")
			Welt.zustand_geaendert.emit()
		else:
			# Den Grund nennen: "fehlgeschlagen" hilft niemandem weiter.
			_melde(Welt.ladefehler if Welt.ladefehler != "" else "Laden fehlgeschlagen.", false)
		aktualisieren())
	zeile.add_child(laden)
	var loeschen := Stil.knopf_flach("Löschen", Stil.ROT)
	loeschen.pressed.connect(func():
		Welt.slot_loeschen(slot)
		_melde("Spielstand gelöscht.")
		aktualisieren())
	zeile.add_child(loeschen)

func _melde(text: String, gut: bool = true) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)
