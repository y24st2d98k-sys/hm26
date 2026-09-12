class_name JugendBildschirm
extends Bildschirm
## Das Nachwuchszentrum: Talente einschätzen, fördern, befördern oder gehen lassen.

var inhalt: VBoxContainer
var meldung: Label

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Nachwuchszentrum", 0))
	kopf.add_child(Stil.dehner())
	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	kopf.add_child(meldung)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)

func aktualisieren() -> void:
	if inhalt == null:
		return
	leeren(inhalt)
	if Welt.mein_verein_id == "" or not Welt.bereit():
		inhalt.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)

	var oben := Stil.hbox(12)
	inhalt.add_child(oben)
	var lage := Bausteine.karte_in(oben, "Die Akademie")
	Stil.karte_wurzel(lage).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var qualitaet := Jugend.arbeitsqualitaet(Welt.daten, cid)
	lage.add_child(Bausteine.wertzeile("Nachwuchsarbeit", qualitaet, 100.0,
		"Aus Jugendabteilung, Nachwuchskoordinator und Ihrer eigenen Handschrift."))
	lage.add_child(Stil.info_zeile("Ausbaustufe Jugend", "Stufe %d von 10" % int(v["infrastruktur"]["jugendarbeit"])))
	var koordinator := "—"
	for pid in v["personal"]:
		var mp: Dictionary = Welt.mitarbeiter(pid)
		if str(mp.get("rolle", "")) == "nachwuchs":
			koordinator = "%s %s" % [mp["vorname"], mp["nachname"]]
	lage.add_child(Stil.info_zeile("Koordinator", koordinator))
	lage.add_child(Stil.info_zeile("Talente im Zentrum", str(Welt.jugend(cid).size())))
	lage.add_child(Stil.matt("Ein Talent verlässt den Verein, wenn es mit %d Jahren noch nicht befördert wurde." % Jugend.HOECHSTALTER, Stil.S_MINI))

	var wirkung := Bausteine.karte_in(oben, "Was hier entschieden wird")
	Stil.karte_wurzel(wirkung).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Ohne Umbruch schiebt dieser Satz die Karte über den Bildschirmrand hinaus.
	var wirkungstext := Stil.matt("Talente entwickeln sich im Nachwuchs schneller als im Profikader — aber ohne Spielpraxis irgendwann nicht mehr weiter. Wer zu früh befördert wird, blockiert einen Kaderplatz; wer zu spät kommt, ist weg.", Stil.S_KLEIN)
	wirkungstext.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wirkungstext.custom_minimum_size = Vector2(360, 0)
	wirkung.add_child(wirkungstext)
	wirkung.add_child(Stil.info_zeile("Profikader", "%d von %d Plätzen belegt" % [
		(v["kader"] as Array).size(), Jugend.KADER_GRENZE]))
	var jugendfokus: float = float(v["vorstand"].get("jugendfokus", 50.0))
	wirkung.add_child(Bausteine.wertzeile("Vorstand wünscht Jugend", jugendfokus, 100.0,
		"Je höher, desto mehr Anerkennung bringt eine Beförderung."))

	var talente := Welt.jugend(cid)
	var karte := Bausteine.karte_zu(inhalt, "Talente", "scouting",
		"Zum Scouting — dort holt man Nachwuchs von außerhalb in die Akademie")
	var platz := Stil.hbox(8)
	karte.add_child(platz)
	platz.add_child(Stil.matt("Neben dem eigenen Jahrgang kann ein Scout Talente aus sechs Regionen sichten.", Stil.S_MINI))
	platz.add_child(Stil.dehner())
	platz.add_child(Stil.abzeichen("AKADEMIE %d / %d" % [talente.size(), Talentsuche.AKADEMIE_GRENZE],
		Stil.GRUEN if talente.size() < Talentsuche.AKADEMIE_GRENZE else Stil.GELB))
	if talente.is_empty():
		karte.add_child(Stil.matt("Derzeit ist kein Talent im Nachwuchszentrum. Der nächste Jahrgang kommt zum Saisonwechsel."))
		return
	var g := Stil.tabelle(["Pos", "Name", "Alter", "Stärke", "Einschätzung", "Kenntnis", "Förderung", "", ""])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for sid in talente:
		var sp: Dictionary = Welt.spieler(sid)
		g.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		var namenszeile := Stil.hbox(4)
		var k := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		namenszeile.add_child(k)
		# Woher er kommt: eigene Jugend oder aus der Sichtung geholt.
		if not bool(sp.get("aus_eigener_jugend", false)):
			var her := Stil.abzeichen("GESICHTET", Stil.BLAU)
			her.tooltip_text = "Über die Nachwuchssichtung aus %s geholt." % Namen.KULTUR_NAME.get(str(sp["nation"]), "dem Ausland")
			namenszeile.add_child(her)
		g.add_child(namenszeile)
		g.add_child(Stil.text(str(int(sp["alter"])), Stil.S_KLEIN,
			Stil.GELB if int(sp["alter"]) >= Jugend.HOECHSTALTER - 1 else Stil.TEXT))
		g.add_child(Stil.text(Scouting.gesamt_text(Welt.daten, sid), Stil.S_KLEIN,
			Stil.wert_farbe(Spielerfabrik.gesamt(sp), 100.0)))
		g.add_child(Stil.text(Jugend.einschaetzung(Welt.daten, sid), Stil.S_KLEIN, Stil.LILA))
		g.add_child(Stil.balken(float(sp["kenntnis"]), 100.0, 70))
		var fokus := OptionButton.new()
		fokus.custom_minimum_size = Vector2(150, 0)
		var i := 0
		for schluessel in Training.INDIVIDUALFOKUS.keys():
			fokus.add_item(str(Training.INDIVIDUALFOKUS[schluessel]))
			fokus.set_item_metadata(i, schluessel)
			if str(sp.get("trainingsfokus", "")) == str(schluessel):
				fokus.select(i)
			i += 1
		fokus.item_selected.connect(func(idx):
			Welt.spieler(sid)["trainingsfokus"] = str(fokus.get_item_metadata(idx)))
		g.add_child(fokus)
		var hoch := Stil.knopf_primaer("Befördern")
		hoch.pressed.connect(func():
			var erg := Jugend.befoerdern(Welt.daten, sid)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			Welt.zustand_geaendert.emit()
			aktualisieren())
		g.add_child(hoch)
		var weg := Stil.knopf("Freigeben")
		weg.pressed.connect(func():
			var erg := Jugend.freigeben(Welt.daten, sid)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			aktualisieren())
		g.add_child(weg)

func _melde(text: String, gut: bool = true) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)
