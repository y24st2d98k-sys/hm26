class_name KabinenBildschirm
extends Bildschirm
## Die Kabine: Klima, Wortführer, Gruppen und Unzufriedenheit.

var bereich: VBoxContainer

func aufbauen() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	bereich = Stil.vbox(12)
	bereich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bereich)

func aktualisieren() -> void:
	if bereich == null:
		return
	leeren(bereich)
	if Welt.mein_verein_id == "":
		bereich.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)
	bereich.add_child(Stil.titel("Die Kabine", 0))
	bereich.add_child(Stil.matt("Eine Mannschaft ist kein Attributdurchschnitt. Wortführer, Gruppen und persönliche Zufriedenheit entscheiden mit, wie viel vom Kader auf dem Feld ankommt.", Stil.S_KLEIN))

	var oben := Stil.hbox(12)
	bereich.add_child(oben)

	var klima := Bausteine.karte_in(oben, "Kabinenklima")
	Stil.karte_wurzel(klima).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wert: float = float(v.get("stimmung_kabine", 50.0))
	klima.add_child(Bausteine.wertzeile("Klima", wert))
	klima.add_child(Stil.info_zeile("Leistungswirkung", "%+.1f %%" % ((Kabine.teamfaktor(Welt.daten, cid) - 1.0) * 100.0),
		Stil.GRUEN if Kabine.teamfaktor(Welt.daten, cid) >= 1.0 else Stil.ROT))
	var moral := 0.0
	var teamgeist := 0.0
	for sid in v["kader"]:
		moral += float(Welt.spieler(sid)["moral"])
		teamgeist += float(Welt.spieler(sid)["attr"]["teamgeist"])
	var n: float = maxf(float((v["kader"] as Array).size()), 1.0)
	klima.add_child(Bausteine.wertzeile("Ø Moral", moral / n))
	klima.add_child(Bausteine.wertzeile("Ø Teamgeist", teamgeist / n * 5.0))
	klima.add_child(Stil.matt(_klimatext(wert), Stil.S_KLEIN))

	var fuehrung := Bausteine.karte_in(oben, "Wortführer")
	Stil.karte_wurzel(fuehrung).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kapitaen: String = str(v["aufstellung"].get("kapitaen", ""))
	for sid in Kabine.wortfuehrer(Welt.daten, cid, 4):
		var sp: Dictionary = Welt.spieler(sid)
		var zeile := Stil.hbox(8)
		fuehrung.add_child(zeile)
		zeile.add_child(Portraet.fuer_spieler(sid, 26.0))
		var k := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		zeile.add_child(k)
		if sid == kapitaen:
			zeile.add_child(Stil.abzeichen("KAPITÄN", Stil.AKZENT))
		zeile.add_child(Stil.dehner())
		zeile.add_child(Stil.matt("Einfluss %d" % int(Kabine.einfluss(Welt.daten, sid)), Stil.S_MINI))
		zeile.add_child(Stil.abzeichen(str(sp["persoenlichkeit"]), Stil.LILA))
	fuehrung.add_child(Stil.trenner())
	var kapzeile := Stil.hbox(8)
	fuehrung.add_child(kapzeile)
	kapzeile.add_child(Stil.matt("Kapitän"))
	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(200, 0)
	var i := 0
	for sid2 in Welt.kader(cid):
		var sp2: Dictionary = Welt.spieler(sid2)
		wahl.add_item("%s (Führung %d)" % [Spielerfabrik.voller_name(sp2), int(float(sp2["attr"]["fuehrung"]))])
		wahl.set_item_metadata(i, sid2)
		if sid2 == kapitaen:
			wahl.select(i)
		i += 1
	wahl.item_selected.connect(func(idx):
		v["aufstellung"]["kapitaen"] = str(wahl.get_item_metadata(idx))
		aktualisieren())
	kapzeile.add_child(wahl)

	var gruppen := Kabine.gruppen(Welt.daten, cid)
	var gruppenkarte := Bausteine.karte_in(bereich, "Gruppen in der Mannschaft")
	if gruppen.is_empty():
		gruppenkarte.add_child(Stil.matt("Derzeit bilden sich keine erkennbaren Gruppen — der Kader ist gemischt."))
	else:
		for g in gruppen:
			var zeile := Stil.hbox(8)
			gruppenkarte.add_child(zeile)
			zeile.add_child(Stil.abzeichen(str(g["bezeichnung"]), Stil.TUERKIS))
			var namen: Array = []
			for sid3 in (g["mitglieder"] as Array).slice(0, 8):
				namen.append(Spielerfabrik.kurz_name(Welt.spieler(sid3)))
			zeile.add_child(Stil.matt(", ".join(namen), Stil.S_KLEIN))

	_patenschaften(cid, v)

	var unzufrieden := Bausteine.karte_in(bereich, "Zufriedenheit im Kader")
	var g2 := Stil.tabelle(["Spieler", "Rolle", "Minuten/Spiel", "Moral", "Unzufriedenheit", "Status"])
	g2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unzufrieden.add_child(g2)
	var kader: Array = (v["kader"] as Array).duplicate()
	kader.sort_custom(func(a, b): return float(Welt.spieler(a)["unzufriedenheit"]) > float(Welt.spieler(b)["unzufriedenheit"]))
	for sid4 in kader:
		var sp3: Dictionary = Welt.spieler(sid4)
		var k2 := Stil.knopf_flach(Spielerfabrik.kurz_name(sp3))
		k2.pressed.connect(func(): Spielerfenster.oeffnen(self, sid4))
		g2.add_child(k2)
		g2.add_child(Stil.matt(str(Transfermarkt.ROLLEN_NAME.get(str(sp3["vertrag"].get("rolle", "rotation")), "—")), Stil.S_KLEIN))
		var spiele: int = maxi(int(sp3["stats"]["saison"]["spiele"]), 1)
		g2.add_child(Stil.text("%d" % int(float(sp3["stats"]["saison"]["minuten"]) / float(spiele)), Stil.S_KLEIN))
		g2.add_child(Stil.balken(float(sp3["moral"]), 100.0, 80))
		g2.add_child(Stil.balken(float(sp3["unzufriedenheit"]), 100.0, 80, Stil.prozent_farbe(100.0 - float(sp3["unzufriedenheit"]))))
		g2.add_child(Bausteine.status_zeichen(sid4))

## Patenschaften: wer nimmt wen unter seine Fittiche.
func _patenschaften(cid: String, _v: Dictionary) -> void:
	var karte := Bausteine.karte_in(bereich, "Patenschaften")
	karte.add_child(Stil.matt("Ein erfahrener Spieler nimmt ein Talent an die Hand. Der Junge lernt schneller — und übernimmt mit der Zeit den Charakter seines Vorbilds. Auch den schlechten.", Stil.S_MINI))
	var liste: Array = Mentoring.paare(Welt.daten, cid)
	if liste.is_empty():
		karte.add_child(Stil.matt("Derzeit besteht keine Patenschaft."))
	for i in range(liste.size()):
		var paar: Dictionary = liste[i]
		var m: Dictionary = Welt.spieler(str(paar["mentor"]))
		var s2: Dictionary = Welt.spieler(str(paar["schueler"]))
		if m.is_empty() or s2.is_empty():
			continue
		var zeile := Stil.hbox(10)
		karte.add_child(zeile)
		zeile.add_child(Portraet.fuer_spieler(str(paar["mentor"]), 30.0))
		var info := Stil.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(info)
		info.add_child(Stil.text("%s → %s" % [Spielerfabrik.voller_name(m), Spielerfabrik.voller_name(s2)], Stil.S_KLEIN))
		var wert: float = Mentoring.eignung(Welt.daten, str(paar["mentor"]), str(paar["schueler"]))
		info.add_child(Stil.matt("%s · %s" % [Mentoring.eignung_text(wert), Mentoring.beschreibung(Welt.daten, paar)], Stil.S_MINI))
		zeile.add_child(Portraet.fuer_spieler(str(paar["schueler"]), 30.0))
		zeile.add_child(Stil.balken(Mentoring.reife(Welt.daten, paar) * 100.0, 100.0, 90))
		var weg := Stil.knopf_flach("Beenden", Stil.ROT)
		var index := i
		weg.pressed.connect(func():
			Mentoring.aufloesen(Welt.daten, cid, index)
			aktualisieren())
		zeile.add_child(weg)

	var mentoren: Array = Mentoring.kandidaten_mentor(Welt.daten, cid)
	var schueler: Array = Mentoring.kandidaten_schueler(Welt.daten, cid)
	if liste.size() >= Mentoring.HOECHSTZAHL:
		karte.add_child(Stil.matt("Mehr als %d Patenschaften trägt eine Kabine nicht." % Mentoring.HOECHSTZAHL, Stil.S_MINI))
		return
	if mentoren.is_empty() or schueler.is_empty():
		karte.add_child(Stil.matt("Dafür fehlt es an erfahrenen Spielern (ab %d) oder an Talenten (bis %d)." % [
			Mentoring.MENTOR_ALTER, Mentoring.SCHUELER_ALTER], Stil.S_MINI))
		return
	karte.add_child(Stil.trenner())
	var neu := Stil.hbox(8)
	karte.add_child(neu)
	var mwahl := OptionButton.new()
	mwahl.custom_minimum_size = Vector2(230, 0)
	for j in range(mentoren.size()):
		var mp: Dictionary = Welt.spieler(str(mentoren[j]))
		mwahl.add_item("%s (%d)" % [Spielerfabrik.voller_name(mp), int(mp["alter"])])
		mwahl.set_item_metadata(j, str(mentoren[j]))
	neu.add_child(mwahl)
	neu.add_child(Stil.matt("nimmt", Stil.S_KLEIN))
	var swahl := OptionButton.new()
	swahl.custom_minimum_size = Vector2(230, 0)
	for k in range(schueler.size()):
		var spp: Dictionary = Welt.spieler(str(schueler[k]))
		swahl.add_item("%s (%d)" % [Spielerfabrik.voller_name(spp), int(spp["alter"])])
		swahl.set_item_metadata(k, str(schueler[k]))
	neu.add_child(swahl)
	var hinweis := Stil.matt("", Stil.S_MINI)
	var pruefen := func():
		var w: float = Mentoring.eignung(Welt.daten, str(mwahl.get_item_metadata(maxi(mwahl.selected, 0))),
			str(swahl.get_item_metadata(maxi(swahl.selected, 0))))
		hinweis.text = "Passung: %s (%d)" % [Mentoring.eignung_text(w), int(w)]
	mwahl.item_selected.connect(func(_i): pruefen.call())
	swahl.item_selected.connect(func(_i): pruefen.call())
	var los := Stil.knopf_primaer("Patenschaft schließen")
	los.pressed.connect(func():
		var erg := Mentoring.anlegen(Welt.daten, cid,
			str(mwahl.get_item_metadata(maxi(mwahl.selected, 0))),
			str(swahl.get_item_metadata(maxi(swahl.selected, 0))))
		if bool(erg["ok"]):
			Welt.zustand_geaendert.emit()
			aktualisieren()
		else:
			hinweis.text = str(erg["grund"]))
	neu.add_child(los)
	neu.add_child(hinweis)
	pruefen.call()

func _klimatext(wert: float) -> String:
	if wert >= 78.0:
		return "Die Mannschaft zieht an einem Strang. Rückschläge werden aufgefangen, statt sie zu diskutieren."
	elif wert >= 60.0:
		return "Ein gesundes Klima. Es gibt Reibung, aber sie bleibt sachlich."
	elif wert >= 42.0:
		return "Angespannt. Einzelne Spieler ziehen sich zurück, die Hierarchie wackelt."
	return "Die Kabine ist zerfallen. Ohne Eingriff wird das auf dem Feld sichtbar."
