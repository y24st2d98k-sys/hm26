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
	liste.add_child(_automatik())
	liste.add_child(_slot(Welt.AUTOSLOT))
	for slot in range(1, Welt.SLOTS + 1):
		liste.add_child(_slot(slot))

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

func _slot(slot: int) -> Control:
	var info := Welt.slot_info(slot)
	var karte := Stil.karte("Platz 0 — Automatik" if slot == Welt.AUTOSLOT else "Platz %d" % slot)
	if info.is_empty():
		karte.add_child(Stil.matt("— leer —"))
	else:
		karte.add_child(Stil.info_zeile("Verein", str(info.get("verein", ""))))
		karte.add_child(Stil.info_zeile("Trainer", str(info.get("trainer", ""))))
		karte.add_child(Stil.info_zeile("Stand", "%s · %s" % [str(info.get("saison", "")), str(info.get("datum", ""))]))
		karte.add_child(Stil.info_zeile("Gespeichert", str(info.get("gespeichert", ""))))
	var zeile := Stil.hbox(8)
	karte.add_child(zeile)
	var speichern := Stil.knopf_primaer("Speichern")
	speichern.pressed.connect(func():
		if Welt.speichern(slot):
			_melde("Auf Platz %d gespeichert." % slot)
		else:
			_melde("Speichern fehlgeschlagen.", false)
		aktualisieren())
	zeile.add_child(speichern)
	if not info.is_empty():
		var laden := Stil.knopf("Laden")
		laden.pressed.connect(func():
			if Welt.laden(slot):
				_melde("Spielstand geladen.")
				Welt.zustand_geaendert.emit()
			else:
				_melde("Laden fehlgeschlagen.", false)
			aktualisieren())
		zeile.add_child(laden)
		var loeschen := Stil.knopf("Löschen")
		loeschen.pressed.connect(func():
			Welt.slot_loeschen(slot)
			_melde("Spielstand gelöscht.")
			aktualisieren())
		zeile.add_child(loeschen)
	return Stil.karte_wurzel(karte)

func _melde(text: String, gut: bool = true) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)
