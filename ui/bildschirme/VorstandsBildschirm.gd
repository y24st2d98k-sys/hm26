class_name VorstandsBildschirm
extends Bildschirm
## Vorstand: Erwartungen, Vertrauen, Fanstimmung.

var inhalt: VBoxContainer

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
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
	var lage := Vorstand.lagebericht(Welt.daten, cid)

	var oben := Stil.hbox(12)
	inhalt.add_child(oben)
	var ziel := Bausteine.karte_in(oben, "Saisonziel")
	Stil.karte_wurzel(ziel).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ziel.add_child(Stil.text(str(lage["saisonziel"]), Stil.S_GROSS, Stil.AKZENT))
	ziel.add_child(Stil.info_zeile("Erwarteter Platz", "Rang %d oder besser" % int(lage["ziel_platz"])))
	ziel.add_child(Stil.info_zeile("Aktueller Platz", "Rang %d" % int(lage["platz"]),
		Stil.GRUEN if int(lage["platz"]) <= int(lage["ziel_platz"]) else Stil.ROT))
	ziel.add_child(Stil.info_zeile("Stimmung im Vorstand", str(lage["stimmung"]).capitalize()))
	if int(lage["warnstufe"]) == 1:
		ziel.add_child(Stil.abzeichen("VERWARNT", Stil.GELB, true))
	elif int(lage["warnstufe"]) >= 2:
		ziel.add_child(Stil.abzeichen("LETZTE WARNUNG", Stil.ROT, true))

	var vertrauen := Bausteine.karte_in(oben, "Vertrauen")
	Stil.karte_wurzel(vertrauen).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertrauen.add_child(Bausteine.wertzeile("Vorstand", float(lage["vertrauen"])))
	vertrauen.add_child(Bausteine.wertzeile("Fanzufriedenheit", float(lage["fans"])))
	vertrauen.add_child(Bausteine.wertzeile("Fantreue", float(v["fans"]["treue"]), 100.0,
		"Treue Fans kommen auch bei Misserfolg — und tragen den Hallenpuls."))
	vertrauen.add_child(Stil.info_zeile("Mitglieder", Stil.zahl(int(v["fans"]["mitglieder"]))))
	vertrauen.add_child(Stil.matt("Fans reagieren stärker auf Emotionen — Derbys, Serien, Aufholjagden — als auf den reinen Tabellenplatz.", Stil.S_MINI))

	var haltung := Bausteine.karte_in(inhalt, "Haltung des Vorstands")
	haltung.add_child(Bausteine.wertzeile("Finanzstrenge", float(lage["finanzstrenge"]), 100.0,
		"Hohe Strenge bedeutet kleinere Budgets, aber mehr Rückhalt bei roten Zahlen."))
	haltung.add_child(Bausteine.wertzeile("Wunsch nach Jugendarbeit", float(lage["jugendfokus"]), 100.0,
		"Je höher, desto mehr Anerkennung bringt der Einsatz eigener Talente."))
	haltung.add_child(Bausteine.wertzeile("Geduld", float(v["vorstand"]["geduld"])))

	var vertrag := Bausteine.karte_in(inhalt, "Ihr Vertrag")
	var t: Dictionary = Welt.trainer()
	vertrag.add_child(Stil.info_zeile("Laufzeit", "bis Saison %s" % Kalender.saison_text(Welt.startjahr(), int(t["vertrag"]["bis_saison"]))))
	vertrag.add_child(Stil.info_zeile("Wochengehalt", Stil.geld(float(t["vertrag"]["gehalt"]))))
	vertrag.add_child(Stil.info_zeile("Ihr Ruf", "%d — %s" % [int(float(t["ruf"])), Trainerkarriere.ruf_stufe(float(t["ruf"]))]))
