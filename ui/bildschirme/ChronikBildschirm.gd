class_name ChronikBildschirm
extends Bildschirm
## Vereinsgeschichte, Rekorde, Legenden und Rivalitäten.

var inhalt: VBoxContainer

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	v.add_child(Stil.titel("Chronik", 0))
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
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)

	var oben := Stil.hbox(12)
	inhalt.add_child(oben)
	var titel := Bausteine.karte_in(oben, "Titel")
	Stil.karte_wurzel(titel).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var liste: Array = v["chronik"]["titel"]
	if liste.is_empty():
		titel.add_child(Stil.matt("Noch kein Titel in Ihrer Amtszeit."))
	for t in liste:
		titel.add_child(Stil.info_zeile(str(t.get("saisontext", "")), str(t["titel"]), Stil.AKZENT))

	var ewig := Bausteine.karte_in(oben, "Ewige Bilanz")
	Stil.karte_wurzel(ewig).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var e: Dictionary = v["chronik"]["ewige_bilanz"]
	ewig.add_child(Stil.info_zeile("Pflichtspiele", str(int(e["spiele"]))))
	ewig.add_child(Stil.info_zeile("Siege", str(int(e["siege"])), Stil.GRUEN))
	ewig.add_child(Stil.info_zeile("Unentschieden", str(int(e["unentschieden"]))))
	ewig.add_child(Stil.info_zeile("Niederlagen", str(int(e["niederlagen"])), Stil.ROT))
	ewig.add_child(Stil.info_zeile("Tore", "%d : %d" % [int(e["tore"]), int(e["gegentore"])]))

	var rivalen := Bausteine.karte_in(inhalt, "Rivalitäten")
	rivalen.add_child(Stil.matt("Rivalität wächst mit jedem Duell — besonders bei knappen Ergebnissen, K.-o.-Spielen und vielen Zeitstrafen.", Stil.S_MINI))
	for r in Chronik.rivalen(Welt.daten, cid, 6):
		var zeile := Stil.hbox(8)
		rivalen.add_child(zeile)
		zeile.add_child(Wappen.fuer_verein(str(r["verein"]), 22.0))
		var rivalenknopf := Stil.knopf_flach(str(Welt.verein(str(r["verein"])).get("name", "")))
		rivalenknopf.custom_minimum_size = Vector2(230, 0)
		var rid: String = str(r["verein"])
		rivalenknopf.pressed.connect(func(): Vereinsfenster.oeffnen(self, rid))
		zeile.add_child(rivalenknopf)
		zeile.add_child(Stil.balken(float(r["intensitaet"]), 100.0, 160, Stil.ROT))
		zeile.add_child(Stil.abzeichen(Chronik.rivalitaet_stufe(float(r["intensitaet"])), Stil.ROT))

	var legenden := Bausteine.karte_in(inhalt, "Legenden des Vereins")
	var top := Chronik.bestenliste(Welt.daten, cid, "tore", 10)
	var g := Stil.tabelle(["Spieler", "Spiele", "Tore", "Paraden"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legenden.add_child(g)
	for l in top:
		g.add_child(Stil.text(str(l["name"]), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(l["spiele"])), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(l["tore"])), Stil.S_KLEIN, Stil.AKZENT))
		g.add_child(Stil.text(str(int(l["paraden"])), Stil.S_KLEIN))

	var rekorde := Bausteine.karte_in(inhalt, "Rekorde der Spielwelt")
	var r_daten: Dictionary = Welt.daten.get("rekorde", {})
	var namen := {
		"hoechster_sieg": "Höchster Sieg", "meiste_tore_spiel": "Torreichste Partie",
		"laengste_siegesserie": "Längste Siegesserie", "meiste_paraden": "Meiste Paraden in einer Partie",
		"meiste_tore_spieler": "Meiste Tore eines Spielers", "teuerster_transfer": "Teuerster Transfer",
	}
	var leer := true
	for k in namen.keys():
		var eintrag: Dictionary = r_daten.get(k, {})
		if eintrag.is_empty():
			continue
		leer = false
		rekorde.add_child(Stil.info_zeile(str(namen[k]), "%s (%s)" % [
			str(eintrag.get("text", "")), Kalender.kurz(int(eintrag.get("tag", 0)), Welt.startjahr())]))
	if leer:
		rekorde.add_child(Stil.matt("Noch keine Rekorde aufgestellt."))

	var saisons := Bausteine.karte_in(inhalt, "Saison für Saison")
	var verlauf: Array = v["chronik"]["saisons"]
	if verlauf.is_empty():
		saisons.add_child(Stil.matt("Noch keine abgeschlossene Saison."))
	else:
		var g2 := Stil.tabelle(["Saison", "Liga", "Platz", "Punkte", "Tore", "Zuschauer", "Besonderes"])
		g2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		saisons.add_child(g2)
		for s in verlauf:
			g2.add_child(Stil.text(str(s.get("saisontext", "")), Stil.S_KLEIN))
			g2.add_child(Stil.matt(str(s.get("liga", "—")), Stil.S_KLEIN))
			g2.add_child(Stil.text(str(s.get("platz", "—")), Stil.S_KLEIN))
			g2.add_child(Stil.text(str(s.get("punkte", "—")), Stil.S_KLEIN))
			g2.add_child(Stil.text("%s : %s" % [str(s.get("tore", "—")), str(s.get("gegentore", "—"))], Stil.S_KLEIN))
			g2.add_child(Stil.text(Stil.zahl(int(s.get("zuschauer", 0))), Stil.S_KLEIN))
			g2.add_child(Stil.text(str(s.get("ereignis", "")), Stil.S_KLEIN, Stil.AKZENT))
