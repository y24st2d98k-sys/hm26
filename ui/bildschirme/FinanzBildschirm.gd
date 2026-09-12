class_name FinanzBildschirm
extends Bildschirm
## Finanzübersicht: Wochenbilanz, Sponsoren, Buchungen.

var inhalt: VBoxContainer

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	v.add_child(Stil.titel("Finanzen", 0))
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
	var u := Finanzen.wochenuebersicht(Welt.daten, cid)

	var oben := Stil.hbox(12)
	inhalt.add_child(oben)
	var lage := Bausteine.karte_in(oben, "Lage")
	Stil.karte_wurzel(lage).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lage.add_child(Stil.info_zeile("Kasse", Stil.geld(float(v["kasse"])), Stil.GRUEN if float(v["kasse"]) > 0.0 else Stil.ROT))
	lage.add_child(Stil.info_zeile("Transferbudget", Stil.geld(float(v["transferbudget"]))))
	lage.add_child(Stil.info_zeile("Gehaltsbudget (Woche)", Stil.geld(float(v["gehaltsbudget"]))))
	var auslastung := Finanzen.gehaltsauslastung(Welt.daten, cid)
	lage.add_child(Bausteine.wertzeile("Gehaltsauslastung", minf(auslastung, 150.0), 150.0))
	lage.add_child(Stil.info_zeile("Jahresetat", Stil.geld(float(v["jahresetat"]))))

	var einnahmen := Bausteine.karte_in(oben, "Wöchentliche Einnahmen")
	Stil.karte_wurzel(einnahmen).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	einnahmen.add_child(Stil.info_zeile("Sponsoring", Stil.geld(float(u["sponsoring"])), Stil.GRUEN))
	einnahmen.add_child(Stil.info_zeile("Medienerlöse", Stil.geld(float(u["tv"])), Stil.GRUEN))
	einnahmen.add_child(Stil.info_zeile("Merchandising", Stil.geld(float(u["merch"])), Stil.GRUEN))
	einnahmen.add_child(Stil.trenner())
	einnahmen.add_child(Stil.info_zeile("Zuschauerschnitt", Stil.zahl(int(float(u["zuschauer_schnitt"])))))
	einnahmen.add_child(Stil.info_zeile("Hallenkapazität", Stil.zahl(int(v["halle"]["kapazitaet"]))))

	var ausgaben := Bausteine.karte_in(oben, "Wöchentliche Ausgaben")
	Stil.karte_wurzel(ausgaben).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ausgaben.add_child(Stil.info_zeile("Spielergehälter", Stil.geld(-float(u["gehalt_spieler"])), Stil.ROT))
	ausgaben.add_child(Stil.info_zeile("Personalgehälter", Stil.geld(-float(u["gehalt_personal"])), Stil.ROT))
	ausgaben.add_child(Stil.info_zeile("Betriebskosten", Stil.geld(-float(u["betrieb"])), Stil.ROT))
	var praemien_zugesagt := 0.0
	for sid in v["kader"]:
		var vertrag: Dictionary = Welt.spieler(sid).get("vertrag", {})
		praemien_zugesagt += Praemien.erwartete_wochenkosten(Welt.spieler(sid),
			float(vertrag.get("praemie_tor", 0.0)), float(vertrag.get("praemie_sieg", 0.0)),
			Praemien.siegquote(Welt.daten, cid))
	ausgaben.add_child(Stil.info_zeile("Erfolgsprämien (Erwartung)", Stil.geld(-praemien_zugesagt),
		Stil.ROT if praemien_zugesagt > 0.0 else Stil.TEXT_MATT))
	ausgaben.add_child(Stil.info_zeile("Prämien diese Saison",
		Stil.geld(-Praemien.saisonsumme(Welt.daten, cid))))
	ausgaben.add_child(Stil.trenner())
	var saldo: float = float(u["sponsoring"]) + float(u["tv"]) + float(u["merch"]) - float(u["gehalt_spieler"]) - float(u["gehalt_personal"]) - float(u["betrieb"]) - praemien_zugesagt
	ausgaben.add_child(Stil.info_zeile("Saldo ohne Spieltage", Stil.geld(saldo), Stil.GRUEN if saldo > 0.0 else Stil.ROT))

	var sponsoren := Bausteine.karte_in(inhalt, "Sponsoren")
	var g := Stil.tabelle(["Partner", "Art", "Jahreswert", "Laufzeit"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sponsoren.add_child(g)
	for s in v["sponsoren"]:
		g.add_child(Stil.text(str(s["name"]), Stil.S_KLEIN))
		g.add_child(Stil.matt(str(s["art"]), Stil.S_KLEIN))
		g.add_child(Stil.text(Stil.geld(float(s["wert"])), Stil.S_KLEIN, Stil.GRUEN))
		var rest: int = int(s["bis_saison"]) - Welt.saison_index()
		g.add_child(Stil.text("%d Jahr(e)" % maxi(rest, 0), Stil.S_KLEIN, Stil.ROT if rest <= 0 else Stil.TEXT_MATT))

	var buchungen := Bausteine.karte_in(inhalt, "Letzte Buchungen")
	var buchungsliste: Array = v["finanz_log"]
	if buchungsliste.is_empty():
		buchungen.add_child(Stil.matt("Noch keine Buchungen."))
	else:
		var g2 := Stil.tabelle(["Datum", "Vorgang", "Kategorie", "Betrag"])
		g2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buchungen.add_child(g2)
		for e in buchungsliste.slice(0, 30):
			g2.add_child(Stil.matt(Kalender.kurz(int(e["tag"]), Welt.startjahr()), Stil.S_KLEIN))
			g2.add_child(Stil.text(str(e["grund"]), Stil.S_KLEIN))
			g2.add_child(Stil.matt(str(e["kategorie"]), Stil.S_KLEIN))
			var betrag: float = float(e["betrag"])
			g2.add_child(Stil.text(Stil.geld(betrag), Stil.S_KLEIN, Stil.GRUEN if betrag > 0.0 else Stil.ROT))
