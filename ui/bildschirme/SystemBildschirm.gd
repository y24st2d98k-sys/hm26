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
	v.add_child(Stil.matt("Jeder Spielstand enthält den kompletten Zustand der Spielwelt. Beim Laden werden fehlende Felder automatisch ergänzt, damit alte Stände auch nach Erweiterungen des Spiels funktionieren.", Stil.S_KLEIN))
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
	# Ton und Automatik nebeneinander, die Spielstände darunter über die volle
	# Breite: die Spielstandkarte trägt Verein, Trainer, Datum und drei Knöpfe
	# je Zeile und ist damit breiter als eine halbe Seite.
	var oben := Stil.hbox(Stil.A_NORMAL)
	liste.add_child(oben)
	var ton := _ton()
	ton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(ton)
	var auto := _automatik()
	auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(auto)
	# Ein Platz ist eine Zeile, keine Karte.
	#
	# Vorher trug jeder der sechs Plaetze eine eigene Karte mit vier
	# Beschriftungszeilen: zusammen weit mehr als eine Bildschirmhoehe fuer
	# eine Liste, in der man eine Zeile sucht und einen Knopf drueckt.
	var plaetze := Bausteine.karte_in(liste, "Spielstände")
	_slot_zeile(plaetze, Welt.AUTOSLOT)
	for slot in range(1, Welt.SLOTS + 1):
		_slot_zeile(plaetze, slot)


## Ton: Hauptschalter und drei Regler. Alle Klänge werden beim Start berechnet,
## es liegt keine Audiodatei im Projekt.
func _ton() -> Control:
	var karte := Stil.karte("Ton")
	karte.add_child(Stil.matt("Musik, Hallenatmosphäre und Effekte werden im Spiel selbst erzeugt. Die Atmosphäre folgt dem Hallenpuls der laufenden Partie.", Stil.S_KLEIN))
	var an := Stil.schalter("Ton eingeschaltet", bool(Welt.einstellung("ton_an", true)))
	an.disabled = Welt.daten.is_empty()
	an.toggled.connect(func(wert):
		if Welt.daten.is_empty():
			return
		Welt.setze_einstellung("ton_an", wert)
		if wert:
			Klang.spiele("klick", 0.7)
			if Welt.mein_verein_id == "":
				Klang.musik_start()
		else:
			Klang.musik_stop()
			Klang.atmo_stop())
	karte.add_child(an)
	for regler in [["lautstaerke_musik", "Musik", 55.0], ["lautstaerke_effekte", "Effekte", 75.0],
			["lautstaerke_atmo", "Hallenatmosphäre", 65.0]]:
		karte.add_child(_regler(str(regler[0]), str(regler[1]), float(regler[2])))
	var eigene: Array = Klang.eigene_klaenge()
	if eigene.is_empty():
		karte.add_child(Stil.matt("Eigene Dateien in assets/klang/ ersetzen einzelne Klänge — siehe assets/README.md.", Stil.S_MINI))
	else:
		karte.add_child(Stil.banner("Aus eigenen Dateien: %s" % ", ".join(eigene), "erfolg"))
	var probe := Stil.knopf_geist("Klangprobe")
	probe.disabled = Welt.daten.is_empty()
	probe.pressed.connect(func():
		Klang.spiele("anpfiff", 0.8)
		Klang.spiele("tor", 0.9))
	karte.add_child(probe)
	return Stil.karte_wurzel(karte)

func _regler(schluessel: String, beschriftung: String, standard: float) -> HBoxContainer:
	var zeile := Stil.hbox(10)
	var l := Stil.matt(beschriftung)
	l.custom_minimum_size = Vector2(150, 0)
	zeile.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = float(Welt.einstellung(schluessel, standard))
	s.custom_minimum_size = Vector2(240, 0)
	s.editable = not Welt.daten.is_empty()
	zeile.add_child(s)
	var wert := Stil.text("%d" % int(s.value), Stil.S_KLEIN, Stil.AKZENT)
	wert.custom_minimum_size = Vector2(36, 0)
	zeile.add_child(wert)
	s.value_changed.connect(func(v):
		wert.text = "%d" % int(v)
		if Welt.daten.is_empty():
			return
		Welt.setze_einstellung(schluessel, v)
		if schluessel == "lautstaerke_musik":
			Klang.musik_start())
	return zeile

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
