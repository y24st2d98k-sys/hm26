class_name BueroBildschirm
extends Bildschirm
## Das Büro — die tägliche Übersicht: nächstes Spiel, Tabellenlage, Kaderprobleme,
## Vorstandsstimmung, Presse und Finanzen auf einen Blick.

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
		_ohne_verein()
		return
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)

	_kennzahlen(v)

	for e in Anliegen.offene(Welt.daten):
		var eintrag: Dictionary = e
		var asid: String = str(eintrag["spieler"])
		if not Welt.daten["spieler"].has(asid):
			continue
		var asp: Dictionary = Welt.spieler(asid)
		var karte := Bausteine.karte_in(bereich, "%s möchte Sie sprechen" % Spielerfabrik.voller_name(asp))
		var zeile := Stil.hbox(12)
		karte.add_child(zeile)
		zeile.add_child(Portraet.fuer_spieler(asid, 44.0))
		var spalte := Stil.vbox(2)
		spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zeile.add_child(spalte)
		spalte.add_child(Stil.text(str((Anliegen.ARTEN[str(eintrag["art"])] as Dictionary)["titel"]),
			Stil.S_NORMAL, Stil.AKZENT))
		var rest: int = int(eintrag["frist"]) - Welt.tag()
		spalte.add_child(Stil.matt("Antwort binnen %d Tag(en)" % maxi(rest, 0)))
		var knopf := Stil.knopf_primaer("Anhören")
		knopf.pressed.connect(func(): Anliegenfenster.oeffnen(self, asid))
		zeile.add_child(knopf)

	if Presse.offen(Welt.daten):
		var pk := Bausteine.karte_in(bereich, "Pressekonferenz steht an")
		pk.add_child(Stil.text("Die Journalisten warten auf Ihre Einschätzung vor dem nächsten Spiel.", Stil.S_KLEIN))
		var pk_knopf := Stil.knopf_primaer("Zur Pressekonferenz")
		pk_knopf.pressed.connect(func(): Pressefenster.oeffnen(self))
		pk.add_child(pk_knopf)

	var oben := Stil.hbox(12)
	bereich.add_child(oben)
	_naechstes_spiel(oben)
	_tabellenlage(oben)
	_vorstand(oben)

	var mitte := Stil.hbox(12)
	bereich.add_child(mitte)
	_kaderlage(mitte)
	_letzte_spiele(mitte)

	var unten := Stil.hbox(12)
	bereich.add_child(unten)
	_presse(unten)
	_finanzen(unten)

## Kennzahlenband: die sechs Zahlen, die den Zustand des Vereins beschreiben.
func _kennzahlen(v: Dictionary) -> void:
	var reihe := Stil.hbox(10)
	bereich.add_child(reihe)
	var lid: String = str(v["liga"])
	var tabelle := Spielplan.tabelle_sortiert(Welt.daten, lid)
	var platz: int = tabelle.find(Welt.mein_verein_id) + 1
	var zeile: Dictionary = (Welt.daten["ligen"][lid]["tabelle"] as Dictionary).get(
		Welt.mein_verein_id, Spielplan.leere_tabellenzeile())
	var ziel: int = int(v["vorstand"]["ziel_platz"])
	reihe.add_child(Stil.kachel("Tabellenplatz", "%d." % platz if platz > 0 else "—",
		"Ziel: Platz %d" % ziel,
		Stil.GRUEN if platz > 0 and platz <= ziel else (Stil.GELB if platz <= ziel + 2 else Stil.ROT)))
	reihe.add_child(Stil.kachel("Punkte", str(int(zeile["punkte"])),
		"%d Spiele · %+d Tore" % [int(zeile["sp"]), int(zeile["tore"]) - int(zeile["gegentore"])]))

	var serie: Array = v["formkurve"]
	var letzte: Array = serie.slice(maxi(serie.size() - 5, 0))
	var siege := 0
	var remis := 0
	for e in letzte:
		if str(e) == "S":
			siege += 1
		elif str(e) == "U":
			remis += 1
	var formkachel := Stil.kachel("Form (5 Spiele)",
		"%dS %dU %dN" % [siege, remis, letzte.size() - siege - remis], "")
	(formkachel.get_child(0) as Node).add_child(Bausteine.formkurve(serie, 5))
	reihe.add_child(formkachel)

	var summe := 0.0
	var anzahl := 0
	for sid in v["kader"]:
		summe += Spielerfabrik.gesamt(Welt.spieler(sid))
		anzahl += 1
	reihe.add_child(Stil.kachel("Kaderstärke", "%d" % int(round(summe / maxf(float(anzahl), 1.0))),
		"%d Spieler · Ruf %d" % [anzahl, int(float(v["ruf"]))]))
	reihe.add_child(Stil.kachel("Kasse", Stil.geld(float(v["kasse"])),
		"Transferbudget %s" % Stil.geld(float(v["transferbudget"])),
		Stil.TEXT if float(v["kasse"]) >= 0.0 else Stil.ROT))
	var vertrauen: float = float(v["vorstand"]["vertrauen"])
	reihe.add_child(Stil.kachel("Vorstand", "%d" % int(vertrauen),
		str(v["vorstand"]["saisonziel"]), Stil.prozent_farbe(vertrauen)))

func _ohne_verein() -> void:
	var karte := Bausteine.karte_in(bereich, "Ohne Verein")
	karte.add_child(Stil.text("Sie sind derzeit vereinslos. Auf dem Karrierebildschirm finden Sie offene Angebote.", Stil.S_NORMAL))
	var t: Dictionary = Welt.trainer()
	karte.add_child(Stil.info_zeile("Ruf", "%d — %s" % [int(float(t.get("ruf", 0.0))), Trainerkarriere.ruf_stufe(float(t.get("ruf", 0.0)))]))
	karte.add_child(Stil.info_zeile("Angebote", str((t.get("jobangebote", []) as Array).size())))

func _naechstes_spiel(eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, "Nächstes Spiel")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m: Dictionary = Welt.naechstes_spiel(Welt.mein_verein_id)
	if m.is_empty():
		karte.add_child(Stil.matt("Kein weiteres Spiel angesetzt."))
		return
	var gegner: String = str(m["gast"]) if str(m["heim"]) == Welt.mein_verein_id else str(m["heim"])
	var heimspiel: bool = str(m["heim"]) == Welt.mein_verein_id
	karte.add_child(Stil.text(Welt.wettbewerb_name(str(m["wettbewerb"])), Stil.S_KLEIN, Stil.AKZENT))
	var zeile := Stil.hbox(10)
	karte.add_child(zeile)
	zeile.add_child(Wappen.fuer_verein(gegner, 38.0))
	var box := Stil.vbox(2)
	zeile.add_child(box)
	box.add_child(Stil.text("%s %s" % ["gegen" if heimspiel else "bei", Welt.verein(gegner).get("name", "")], Stil.S_NORMAL))
	box.add_child(Stil.matt(Kalender.text(int(m["tag"]), Welt.startjahr(), true)))
	var tage: int = int(m["tag"]) - Welt.tag()
	box.add_child(Stil.matt("in %d Tag(en)" % tage if tage > 0 else "heute"))
	var rivalitaet: float = float((Welt.verein(Welt.mein_verein_id)["rivalen"] as Dictionary).get(gegner, 0.0))
	if rivalitaet > 25.0:
		karte.add_child(Stil.abzeichen(Chronik.rivalitaet_stufe(rivalitaet).to_upper(), Stil.ROT))
	var gv: Dictionary = Welt.verein(gegner)
	karte.add_child(Stil.info_zeile("Ruf des Gegners", "%d" % int(float(gv["ruf"])), Stil.wert_farbe(float(gv["ruf"]), 100.0)))
	karte.add_child(Stil.info_zeile("Deren Form", "", Stil.TEXT))
	karte.add_child(Bausteine.formkurve(gv["formkurve"], 6))
	if Scouting.gegnervorteil(Welt.daten, Welt.mein_verein_id, gegner) > 0.0:
		karte.add_child(Stil.abzeichen("GEGNER ANALYSIERT", Stil.GRUEN))
	var mid: String = str(m["id"])
	var vorbereitung := Stil.knopf_primaer("Spielvorbereitung öffnen")
	vorbereitung.pressed.connect(func(): Vorberichtsfenster.oeffnen(self, gegner, mid))
	karte.add_child(vorbereitung)

func _tabellenlage(eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, "Tabellenlage")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: Dictionary = Welt.mein_verein()
	var lid: String = str(v["liga"])
	var tabelle := Spielplan.tabelle_sortiert(Welt.daten, lid)
	var platz: int = tabelle.find(Welt.mein_verein_id) + 1
	var von: int = maxi(platz - 3, 1)
	var bis: int = mini(von + 5, tabelle.size())
	var g := Stil.tabelle(["#", "Verein", "Sp", "P", "Diff"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for i in range(von - 1, bis):
		var cid: String = str(tabelle[i])
		var z: Dictionary = Welt.daten["ligen"][lid]["tabelle"].get(cid, Spielplan.leere_tabellenzeile())
		var eigen: bool = cid == Welt.mein_verein_id
		var farbe: Color = Stil.AKZENT if eigen else Stil.TEXT
		g.add_child(Stil.text(str(i + 1), Stil.S_KLEIN, farbe))
		g.add_child(Stil.text(str(Welt.verein(cid).get("name", "")).substr(0, 24), Stil.S_KLEIN, farbe))
		g.add_child(Stil.text(str(int(z["sp"])), Stil.S_KLEIN, farbe))
		g.add_child(Stil.text(str(int(z["punkte"])), Stil.S_KLEIN, farbe))
		var diff: int = int(z["tore"]) - int(z["gegentore"])
		g.add_child(Stil.text("%+d" % diff, Stil.S_KLEIN, Stil.GRUEN if diff > 0 else (Stil.ROT if diff < 0 else Stil.TEXT_MATT)))

func _vorstand(eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, "Vorstand & Umfeld")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lage := Vorstand.lagebericht(Welt.daten, Welt.mein_verein_id)
	karte.add_child(Stil.info_zeile("Saisonziel", str(lage["saisonziel"])))
	karte.add_child(Bausteine.wertzeile("Vertrauen", float(lage["vertrauen"])))
	karte.add_child(Bausteine.wertzeile("Fanstimmung", float(lage["fans"])))
	karte.add_child(Bausteine.wertzeile("Kabinenklima", float(Welt.mein_verein().get("stimmung_kabine", 50.0)), 100.0,
		"Ergibt sich aus Moral, Hierarchie und Unzufriedenheit im Kader."))
	if int(lage["warnstufe"]) > 0:
		karte.add_child(Stil.abzeichen("WARNUNG DES VORSTANDS", Stil.ROT, true))

func _kaderlage(eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, "Kaderlage")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lazarett := Medizin.lazarett(Welt.daten, Welt.mein_verein_id)
	if lazarett.is_empty():
		karte.add_child(Stil.text("Keine Verletzten — der gesamte Kader steht zur Verfügung.", Stil.S_KLEIN, Stil.GRUEN))
	else:
		karte.add_child(Stil.text("Verletzt (%d):" % lazarett.size(), Stil.S_KLEIN, Stil.ROT))
		for sid in lazarett.slice(0, 6):
			var sp: Dictionary = Welt.spieler(sid)
			var k := Stil.knopf_flach("%s — %s" % [Spielerfabrik.voller_name(sp), Medizin.verletzungstext(sp)], Stil.TEXT_MATT)
			k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
			karte.add_child(k)
	var belastet: Array = []
	var unzufrieden: Array = []
	for sid in Welt.kader(Welt.mein_verein_id):
		var sp: Dictionary = Welt.spieler(sid)
		if float(sp["last"]) > 70.0:
			belastet.append(sid)
		if float(sp["unzufriedenheit"]) > 55.0:
			unzufrieden.append(sid)
	if not belastet.is_empty():
		karte.add_child(Stil.trenner())
		karte.add_child(Stil.text("Hohes Lastkonto (%d):" % belastet.size(), Stil.S_KLEIN, Stil.AKZENT))
		for sid2 in belastet.slice(0, 5):
			var sp2: Dictionary = Welt.spieler(sid2)
			var k2 := Stil.knopf_flach("%s — Last %d" % [Spielerfabrik.voller_name(sp2), int(float(sp2["last"]))], Stil.TEXT_MATT)
			k2.pressed.connect(func(): Spielerfenster.oeffnen(self, sid2))
			karte.add_child(k2)
	if not unzufrieden.is_empty():
		karte.add_child(Stil.trenner())
		karte.add_child(Stil.text("Unzufrieden (%d):" % unzufrieden.size(), Stil.S_KLEIN, Stil.GELB))
		for sid3 in unzufrieden.slice(0, 5):
			var sp3: Dictionary = Welt.spieler(sid3)
			var k3 := Stil.knopf_flach(Spielerfabrik.voller_name(sp3), Stil.TEXT_MATT)
			k3.pressed.connect(func(): Spielerfenster.oeffnen(self, sid3))
			karte.add_child(k3)

func _letzte_spiele(eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, "Zuletzt gespielt")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var liste := Welt.letzte_spiele(Welt.mein_verein_id, 6)
	if liste.is_empty():
		karte.add_child(Stil.matt("Noch keine Partien in dieser Saison."))
		return
	for m in liste:
		karte.add_child(Bausteine.spielzeile(str(m["id"]), Welt.mein_verein_id))

func _presse(eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, "Aus der Presse")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var presse: Array = Welt.daten.get("presse", [])
	if presse.is_empty():
		karte.add_child(Stil.matt("Noch keine Berichte."))
		return
	for a in presse.slice(0, 4):
		var z := Stil.vbox(1)
		karte.add_child(z)
		z.add_child(Stil.text(str(a["schlagzeile"]), Stil.S_KLEIN, _tonfarbe(str(a["tonfall"]))))
		z.add_child(Stil.matt("%s · %s" % [str(a["outlet"]), Kalender.kurz(int(a["tag"]), Welt.startjahr())], Stil.S_MINI))

func _tonfarbe(tonfall: String) -> Color:
	match tonfall:
		"jubel", "lob":
			return Stil.GRUEN
		"kritik":
			return Stil.GELB
		"verriss":
			return Stil.ROT
	return Stil.TEXT

func _finanzen(eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, "Finanzen")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: Dictionary = Welt.mein_verein()
	var u := Finanzen.wochenuebersicht(Welt.daten, Welt.mein_verein_id)
	karte.add_child(Stil.info_zeile("Kasse", Stil.geld(float(v["kasse"])),
		Stil.GRUEN if float(v["kasse"]) > 0.0 else Stil.ROT))
	karte.add_child(Stil.info_zeile("Transferbudget", Stil.geld(float(v["transferbudget"]))))
	var auslastung := Finanzen.gehaltsauslastung(Welt.daten, Welt.mein_verein_id)
	karte.add_child(Stil.info_zeile("Gehaltsauslastung", "%.0f %%" % auslastung,
		Stil.ROT if auslastung > 100.0 else Stil.GRUEN))
	karte.add_child(Stil.info_zeile("Zuschauerschnitt", Stil.zahl(int(float(u["zuschauer_schnitt"])))))
	var saldo: float = float(u["sponsoring"]) + float(u["tv"]) + float(u["merch"]) - float(u["gehalt_spieler"]) - float(u["gehalt_personal"]) - float(u["betrieb"])
	karte.add_child(Stil.info_zeile("Wochensaldo (ohne Spieltag)", Stil.geld(saldo), Stil.GRUEN if saldo > 0.0 else Stil.ROT))
