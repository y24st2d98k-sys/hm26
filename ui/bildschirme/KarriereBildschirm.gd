class_name KarriereBildschirm
extends Bildschirm
## Die Trainerkarriere: Stationen, Titel, Handschrift, Prägungen, Jobangebote.

var inhalt: VBoxContainer
var meldung: Label

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Karriere", 0))
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
	if inhalt == null or Welt.daten.is_empty():
		return
	leeren(inhalt)
	var t: Dictionary = Welt.trainer()
	if t.is_empty():
		return
	var kopf := Stil.hbox(14)
	inhalt.add_child(kopf)
	var box := Stil.vbox(2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(box)
	box.add_child(Stil.titel(Trainerkarriere.voller_name(t), 0))
	box.add_child(Stil.matt("%d Jahre · %s · %s" % [int(t["alter"]),
		Namen.KULTUR_NAME.get(str(t["nation"]), ""), str(t.get("hintergrund_name", ""))]))
	box.add_child(Stil.matt("%s — Ruf %d" % [Trainerkarriere.ruf_stufe(float(t["ruf"])), int(float(t["ruf"]))]))

	var oben := Stil.hbox(12)
	inhalt.add_child(oben)

	var bilanz := Bausteine.karte_in(oben, "Bilanz")
	Stil.karte_wurzel(bilanz).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s: Dictionary = t["statistik"]
	var spiele: int = int(s["spiele"])
	bilanz.add_child(Stil.info_zeile("Spiele", str(spiele)))
	bilanz.add_child(Stil.info_zeile("Siege / Unentschieden / Niederlagen", "%d / %d / %d" % [int(s["siege"]), int(s["unentschieden"]), int(s["niederlagen"])]))
	var quote: float = float(s["siege"]) / maxf(float(spiele), 1.0) * 100.0
	bilanz.add_child(Bausteine.wertzeile("Siegquote", quote))
	bilanz.add_child(Stil.info_zeile("Titel", str((t["titel"] as Array).size()), Stil.AKZENT))
	bilanz.add_child(Bausteine.wertzeile("Ruf", float(t["ruf"])))

	var handschrift := Bausteine.karte_in(oben, "Ihre Handschrift")
	Stil.karte_wurzel(handschrift).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	handschrift.add_child(Stil.matt("Die Achsen richten sich langsam danach aus, wie Sie tatsächlich arbeiten — nicht danach, was Sie sagen.", Stil.S_MINI))
	for achse in Trainerkarriere.ACHSEN.keys():
		var a: Dictionary = Trainerkarriere.ACHSEN[achse]
		var wert: float = float(t["handschrift"].get(achse, 50.0))
		var zeile := Stil.hbox(6)
		handschrift.add_child(zeile)
		var links := Stil.matt(str(a["links"]), Stil.S_MINI)
		links.custom_minimum_size = Vector2(120, 0)
		links.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		zeile.add_child(links)
		zeile.add_child(Stil.balken(wert, 100.0, 140, Stil.LILA))
		var rechts := Stil.matt(str(a["rechts"]), Stil.S_MINI)
		rechts.custom_minimum_size = Vector2(120, 0)
		zeile.add_child(rechts)

	var praegungen := Bausteine.karte_in(inhalt, "Prägungen")
	var liste: Array = t.get("praegungen", [])
	if liste.is_empty():
		praegungen.add_child(Stil.matt("Noch keine Prägung erreicht. Prägungen entstehen, wenn eine Achse Ihrer Handschrift einen Extremwert erreicht — und wirken sich dann dauerhaft aus."))
	for p in liste:
		var d: Dictionary = Trainerkarriere.PRAEGUNGEN[p]
		var zeile2 := Stil.hbox(10)
		praegungen.add_child(zeile2)
		zeile2.add_child(Stil.abzeichen(str(d["name"]), Stil.LILA, true))
		zeile2.add_child(Stil.text(str(d["text"]), Stil.S_KLEIN, Stil.TEXT_MATT))

	var stationen := Bausteine.karte_in(inhalt, "Stationen")
	var g := Stil.tabelle(["Verein", "Von", "Bis", "Sp", "S", "U", "N", "Titel"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stationen.add_child(g)
	for st in t["stationen"]:
		g.add_child(Stil.text(str(st.get("vereinsname", "")), Stil.S_KLEIN))
		g.add_child(Stil.matt(Kalender.saison_text(Welt.startjahr(), int(st["von_saison"])), Stil.S_KLEIN))
		g.add_child(Stil.matt("heute" if int(st["bis_saison"]) < 0 else Kalender.saison_text(Welt.startjahr(), int(st["bis_saison"])), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(st["spiele"])), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(st["siege"])), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(st["unentschieden"])), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(st["niederlagen"])), Stil.S_KLEIN))
		g.add_child(Stil.text(str((st["titel"] as Array).size()), Stil.S_KLEIN, Stil.AKZENT))

	var titelkarte := Bausteine.karte_in(inhalt, "Titelsammlung")
	if (t["titel"] as Array).is_empty():
		titelkarte.add_child(Stil.matt("Noch kein Titel gewonnen."))
	for e in t["titel"]:
		titelkarte.add_child(Stil.info_zeile(Kalender.saison_text(Welt.startjahr(), int(e["saison"])),
			"%s (%s)" % [str(e["titel"]), str(Welt.verein(str(e["verein"])).get("name", ""))], Stil.AKZENT))

	var angebote: Array = t.get("jobangebote", [])
	var jobs := Bausteine.karte_in(inhalt, "Angebote anderer Vereine")
	if angebote.is_empty():
		jobs.add_child(Stil.matt("Derzeit liegen keine Angebote vor."))
	for a in angebote:
		var cid: String = str(a["verein"])
		var v2: Dictionary = Welt.verein(cid)
		if v2.is_empty():
			continue
		var zeile3 := Stil.hbox(10)
		jobs.add_child(zeile3)
		zeile3.add_child(Wappen.fuer_verein(cid, 28.0))
		var info := Stil.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile3.add_child(info)
		info.add_child(Stil.text(str(v2["name"]), Stil.S_KLEIN))
		info.add_child(Stil.matt("%s · Ruf %d · Erwartung: %s · %s pro Woche · %d Jahre" % [
			Welt.wettbewerb_name(str(v2["liga"])), int(float(v2["ruf"])), str(a["erwartung"]),
			Stil.geld(float(a["gehalt"])), int(a["jahre"])], Stil.S_MINI))
		var annehmen := Stil.knopf_primaer("Annehmen")
		annehmen.pressed.connect(func():
			Trainerkarriere.verein_wechseln(Welt.daten, cid)
			Welt.daten["trainer"]["jobangebote"] = []
			_melde("Sie übernehmen %s." % v2["name"])
			Welt.zustand_geaendert.emit()
			aktualisieren())
		zeile3.add_child(annehmen)

func _melde(text: String, gut: bool = true) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)
