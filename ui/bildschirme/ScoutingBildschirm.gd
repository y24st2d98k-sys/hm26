class_name ScoutingBildschirm
extends Bildschirm
## Scouting: Aufträge vergeben, Berichte lesen, das Gespür der eigenen Scouts verfolgen.

var inhalt: VBoxContainer
var meldung: Label

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Scouting", 0))
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
	if Welt.mein_verein_id == "":
		inhalt.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	inhalt.add_child(Stil.matt("Was Sie nicht beobachtet haben, kennen Sie nur ungefähr. Jeder Bericht verengt die Spannen — und jeder Scout wird über die Jahre an seinen eigenen Einschätzungen gemessen.", Stil.S_KLEIN))
	_scouts()
	_auftraege()
	_berichte()

func _scouts() -> void:
	var karte := Bausteine.karte_in(inhalt, "Ihre Scouts")
	var scouts := Scouting.scouts(Welt.daten, Welt.mein_verein_id)
	if scouts.is_empty():
		karte.add_child(Stil.matt("Sie haben keinen Scout unter Vertrag. Über den Personalbildschirm können Sie einen einstellen."))
		return
	for pid in scouts:
		var s: Dictionary = Welt.mitarbeiter(pid)
		var g: float = Scouting.gespuer(Welt.daten, pid)
		var zeile := Stil.hbox(10)
		karte.add_child(zeile)
		var scoutname := Stil.text("%s %s" % [s["vorname"], s["nachname"]], Stil.S_KLEIN)
		scoutname.custom_minimum_size = Vector2(180, 0)
		zeile.add_child(scoutname)
		zeile.add_child(Stil.balken(g, 100.0, 110))
		var t := Stil.text(Scouting.gespuer_text(g), Stil.S_KLEIN, Stil.wert_farbe(g, 100.0))
		t.custom_minimum_size = Vector2(170, 0)
		zeile.add_child(t)
		zeile.add_child(Stil.matt("%d Berichte, %d bestätigt" % [int(s.get("berichte", 0)), int(s.get("treffer", 0))], Stil.S_MINI))
		zeile.add_child(Stil.dehner())
		var beschaeftigt := false
		for a in Welt.daten["scouting"]["auftraege"]:
			if str(a["scout"]) == pid and not bool(a.get("fertig", false)):
				beschaeftigt = true
				zeile.add_child(Stil.abzeichen("UNTERWEGS", Stil.GELB))
		if not beschaeftigt:
			zeile.add_child(_auftragswahl(pid))

func _auftragswahl(pid: String) -> HBoxContainer:
	var h := Stil.hbox(6)
	var art := OptionButton.new()
	art.custom_minimum_size = Vector2(180, 0)
	for k in Scouting.AUFTRAGSARTEN.keys():
		if k == "spieler":
			continue
		art.add_item(str(Scouting.AUFTRAGSARTEN[k]["name"]))
		art.set_item_metadata(art.item_count - 1, k)
	h.add_child(art)
	var ziel := OptionButton.new()
	ziel.custom_minimum_size = Vector2(200, 0)
	var fuelle := func():
		ziel.clear()
		var gewaehlt: String = str(art.get_item_metadata(art.selected)) if art.selected >= 0 else "liga"
		match gewaehlt:
			"liga":
				for lid in Welt.daten["ligen"].keys():
					ziel.add_item(str(Welt.daten["ligen"][lid]["name"]))
					ziel.set_item_metadata(ziel.item_count - 1, lid)
			"position":
				for p in Spielerfabrik.POSITIONEN:
					ziel.add_item(str(Spielerfabrik.POSITION_NAME[p]))
					ziel.set_item_metadata(ziel.item_count - 1, p)
			"gegner":
				var naechstes: Dictionary = Welt.naechstes_spiel(Welt.mein_verein_id)
				if not naechstes.is_empty():
					var gid: String = str(naechstes["gast"]) if str(naechstes["heim"]) == Welt.mein_verein_id else str(naechstes["heim"])
					ziel.add_item(str(Welt.verein(gid).get("name", "")))
					ziel.set_item_metadata(0, gid)
	fuelle.call()
	art.item_selected.connect(func(_i): fuelle.call())
	h.add_child(ziel)
	var los := Stil.knopf_primaer("Beauftragen")
	los.pressed.connect(func():
		if ziel.selected < 0:
			_melde("Kein Ziel ausgewählt.", false)
			return
		var erg := Scouting.auftrag_erteilen(Welt.daten, pid,
			str(art.get_item_metadata(art.selected)), str(ziel.get_item_metadata(ziel.selected)))
		_melde(str(erg["grund"]), bool(erg["ok"]))
		aktualisieren())
	h.add_child(los)
	return h

func _auftraege() -> void:
	var offen: Array = []
	for a in Welt.daten["scouting"]["auftraege"]:
		if not bool(a.get("fertig", false)):
			offen.append(a)
	if offen.is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "Laufende Aufträge")
	for a in offen:
		var s: Dictionary = Welt.mitarbeiter(str(a["scout"]))
		var zeile := Stil.hbox(10)
		karte.add_child(zeile)
		zeile.add_child(Stil.text("%s %s" % [s.get("vorname", ""), s.get("nachname", "")], Stil.S_KLEIN))
		zeile.add_child(Stil.matt(str(Scouting.AUFTRAGSARTEN[str(a["art"])]["name"]), Stil.S_KLEIN))
		zeile.add_child(Stil.matt(_zieltext(str(a["art"]), str(a["ziel"])), Stil.S_KLEIN))
		zeile.add_child(Stil.dehner())
		var rest: int = int(a["ende"]) - Welt.tag()
		zeile.add_child(Stil.text("noch %d Tage" % maxi(rest, 0), Stil.S_KLEIN, Stil.AKZENT))
		var abbruch := Stil.knopf("Abbrechen")
		abbruch.pressed.connect(func():
			Scouting.auftrag_abbrechen(Welt.daten, str(a["id"]))
			aktualisieren())
		zeile.add_child(abbruch)

func _zieltext(art: String, ziel: String) -> String:
	match art:
		"liga":
			return str(Welt.daten["ligen"].get(ziel, {}).get("name", ziel))
		"position":
			return str(Spielerfabrik.POSITION_NAME.get(ziel, ziel))
		"spieler":
			return Spielerfabrik.voller_name(Welt.spieler(ziel)) if Welt.daten["spieler"].has(ziel) else ziel
		"gegner":
			return str(Welt.verein(ziel).get("name", ziel))
	return ziel

func _berichte() -> void:
	var karte := Bausteine.karte_in(inhalt, "Berichte")
	var liste: Array = Welt.daten["scouting"]["berichte"]
	if liste.is_empty():
		karte.add_child(Stil.matt("Noch keine Berichte eingegangen."))
		return
	for b in liste.slice(0, 14):
		var block := Stil.vbox(4)
		karte.add_child(block)
		var kopf := Stil.hbox(8)
		block.add_child(kopf)
		kopf.add_child(Stil.text(str(Scouting.AUFTRAGSARTEN[str(b["art"])]["name"]), Stil.S_KLEIN, Stil.AKZENT))
		kopf.add_child(Stil.matt("%s · %s" % [str(b["scoutname"]), Kalender.text(int(b["tag"]), Welt.startjahr())], Stil.S_MINI))
		kopf.add_child(Stil.dehner())
		kopf.add_child(Stil.abzeichen(Scouting.gespuer_text(float(b["gespuer"])), Stil.wert_farbe(float(b["gespuer"]), 100.0)))
		var text := Stil.text(str(b["text"]), Stil.S_KLEIN, Stil.TEXT_MATT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(text)
		var reihe := Stil.hbox(6)
		block.add_child(reihe)
		for sid in (b.get("spieler", []) as Array):
			if not Welt.daten["spieler"].has(sid):
				continue
			var sp: Dictionary = Welt.spieler(sid)
			var k := Stil.knopf("%s (%s)" % [Spielerfabrik.kurz_name(sp), Scouting.gesamt_text(Welt.daten, sid)])
			k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
			reihe.add_child(k)
		karte.add_child(Stil.trenner())

func _melde(text: String, gut: bool = true) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)
