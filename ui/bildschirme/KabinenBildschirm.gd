class_name KabinenBildschirm
extends Bildschirm
## Die Kabine: Klima, Wortführer, Gruppen und Unzufriedenheit.

var bereich: VBoxContainer
## Die letzte Rueckmeldung als Text, nicht als Knoten. Eine Aussprache baut
## den Bildschirm neu auf, und ein Label, das dabei mitgeloescht wird,
## verschwaende genau in dem Moment, in dem es etwas zu sagen hat.
var meldungstext := ""
var meldung_gut := true
## Welcher Reiter offen steht. Eine Aussprache baut den Bildschirm neu auf;
## wer dabei zurueck auf den ersten Reiter geworfen wird, sucht sich seine
## Stelle jedes Mal neu.
var reiter := "klima"

func aufbauen() -> void:
	# Kein Rollbereich um den ganzen Bildschirm: die Reiter bringen ihren
	# eigenen mit, und zwei ineinander sind einer zu viel.
	bereich = Stil.vbox(12)
	bereich.set_anchors_preset(Control.PRESET_FULL_RECT)
	bereich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bereich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(bereich)

func aktualisieren() -> void:
	if bereich == null:
		return
	leeren(bereich)
	if Welt.mein_verein_id == "":
		bereich.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)
	var titelzeile := Stil.hbox(12)
	bereich.add_child(titelzeile)
	if meldungstext != "":
		titelzeile.add_child(Stil.text(meldungstext, Stil.S_KLEIN,
			Stil.GRUEN if meldung_gut else Stil.ROT))
	bereich.add_child(Stil.matt("Eine Mannschaft ist kein Attributdurchschnitt. Wortführer, Gruppen und persönliche Zufriedenheit entscheiden mit, wie viel vom Kader auf dem Feld ankommt.", Stil.S_KLEIN))

	# Wer etwas auf dem Herzen hat, steht vorn — und der Reiter sagt, wie
	# viele es sind.
	#
	# Die Zahl am Menuepunkt "Kabine" zaehlt genau diese Gespraeche. Sie stand
	# da, und auf dem Bildschirm dahinter war nichts zu finden, was man
	# daraufhin haette tun koennen: das Anliegen selbst lag nur im Buero. Jetzt
	# fuehrt die Zahl dorthin, wo man sie wegarbeitet.
	var anliegen: Array = Anliegen.offene(Welt.daten)
	var gespraechsname: String = "Gespräche"
	if not anliegen.is_empty():
		gespraechsname = "Gespräche (%d)" % anliegen.size()
	var gruppe := Stil.reitergruppe([
		{"id": "gespraeche", "name": gespraechsname},
		{"id": "klima", "name": "Klima & Hierarchie"},
		{"id": "geflecht", "name": "Das Geflecht"},
		{"id": "kader", "name": "Zufriedenheit"},
		{"id": "paten", "name": "Patenschaften"},
	], "gespraeche" if not anliegen.is_empty() else reiter)
	gruppe.bei_wechsel = func(id): reiter = str(id)
	bereich.add_child(gruppe)
	_gespraeche(gruppe.feld("gespraeche"), anliegen)
	var f_klima := gruppe.feld("klima")

	var oben := Stil.hbox(12)
	f_klima.add_child(oben)

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
		wahl.add_item("%s (Führung %d)" % [Spielerfabrik.voller_name(sp2), Spielerfabrik.anzeige(float(sp2["attr"]["fuehrung"]))])
		wahl.set_item_metadata(i, sid2)
		if sid2 == kapitaen:
			wahl.select(i)
		i += 1
	wahl.item_selected.connect(func(idx):
		v["aufstellung"]["kapitaen"] = str(wahl.get_item_metadata(idx))
		aktualisieren())
	kapzeile.add_child(wahl)

	_geflecht(cid, gruppe.feld("geflecht"))
	_patenschaften(cid, v, gruppe.feld("paten"))

	var unzufrieden := Bausteine.karte_in(gruppe.feld("kader"), "Zufriedenheit im Kader")
	var g2 := Stil.tabelle(["Spieler", "Rolle", "Minuten/Spiel", "Moral", "Unzufriedenheit", "Status"], true)
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
func _patenschaften(cid: String, _v: Dictionary, eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, "Patenschaften")
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


# -------------------------------------------------------- Das Geflecht ---

## Cliquen und Konflikte.
##
## Die alte Gruppeneinteilung kam aus Nationalität und Alter — also aus
## Etiketten. Sie behauptete, drei Dänen bildeten eine Gruppe, weil sie Dänen
## sind. Was hier steht, kommt aus tatsächlichen Bindungen; dass die oft
## entlang der Sprache verlaufen, ist ein Ergebnis und keine Annahme.
func _geflecht(cid: String, eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, "Das Geflecht")
	var geschlossen := Beziehungen.geschlossenheit(Welt.daten, cid)
	var kopf := Stil.hbox(10)
	karte.add_child(kopf)
	kopf.add_child(Stil.etikett("Geschlossenheit"))
	kopf.add_child(Stil.balken(geschlossen, 100.0, 140, Stil.prozent_farbe(geschlossen)))
	kopf.add_child(Stil.text("%d" % int(geschlossen), Stil.S_KLEIN, Stil.prozent_farbe(geschlossen)))
	kopf.add_child(Stil.dehner())
	kopf.add_child(Stil.matt("Geht in das Kabinenklima ein — und damit in die Leistung auf dem Feld.",
		Stil.S_MINI))

	var cliquen := Beziehungen.cliquen(Welt.daten, cid)
	if cliquen.is_empty():
		karte.add_child(Stil.matt(
			"Es haben sich keine festen Kreise gebildet. Das ist kein Mangel — eine Mannschaft ohne Cliquen hat auch keine Lager.",
			Stil.S_KLEIN))
	else:
		karte.add_child(Stil.trenner())
		for c in cliquen:
			var g: Dictionary = c
			var zeile := Stil.hbox(8)
			karte.add_child(zeile)
			var chef: Dictionary = Welt.spieler(str(g["anfuehrer"]))
			zeile.add_child(Stil.abzeichen("%d Spieler" % (g["mitglieder"] as Array).size(), Stil.TUERKIS))
			var knopf := Stil.knopf_flach("um %s" % Spielerfabrik.kurz_name(chef))
			var chef_id: String = str(g["anfuehrer"])
			knopf.pressed.connect(func(): Spielerfenster.oeffnen(self, chef_id))
			zeile.add_child(knopf)
			var namen: Array = []
			for sid in (g["mitglieder"] as Array):
				if str(sid) != chef_id:
					namen.append(Spielerfabrik.kurz_name(Welt.spieler(str(sid))))
			zeile.add_child(Bausteine.fliesstext("mit " + ", ".join(namen), Stil.S_KLEIN))
			zeile.add_child(Stil.abzeichen(Beziehungen.stufe_text(float(g["staerke"])),
				Stil.prozent_farbe(50.0 + float(g["staerke"]) * 0.5)))

	var konflikte := Beziehungen.konflikte(Welt.daten, cid)
	if konflikte.is_empty():
		return
	karte.add_child(Stil.trenner())
	karte.add_child(Stil.etikett("Offene Zerwürfnisse"))
	karte.add_child(Stil.matt(
		"Zwei Zerstrittene in derselben Sieben kosten Abstimmung: die Fehlerquote steigt. Eine Aussprache kann helfen — oder entgleisen.",
		Stil.S_MINI))
	for k in konflikte:
		var e: Dictionary = k
		var a: String = str(e["a"])
		var b: String = str(e["b"])
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		zeile.add_child(Stil.marke_strich(Stil.ROT, 3, 20))
		var spalte := Stil.vbox(1)
		spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(spalte)
		spalte.add_child(Stil.text("%s und %s" % [
			Spielerfabrik.voller_name(Welt.spieler(a)),
			Spielerfabrik.voller_name(Welt.spieler(b))], Stil.S_KLEIN, Stil.ROT))
		spalte.add_child(Stil.matt(str(e["grund"]), Stil.S_MINI))
		var reden := Stil.knopf_primaer("Aussprache")
		reden.tooltip_text = "Beide an einen Tisch. Gelingt sie, ist es besprochen; misslingt sie, steht es schlechter als vorher."
		reden.pressed.connect(func():
			var erg := Beziehungen.aussprache(Welt.daten, cid, a, b)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			Welt.zustand_geaendert.emit()
			aktualisieren())
		zeile.add_child(reden)
		var trennen := Stil.knopf("Getrennt halten")
		trennen.tooltip_text = "Kein Kontakt im Training. Entschärft die Lage, und keiner der beiden findet es gut."
		trennen.pressed.connect(func():
			var erg2 := Beziehungen.getrennt_halten(Welt.daten, cid, a, b)
			_melde(str(erg2["grund"]), true)
			aktualisieren())
		zeile.add_child(trennen)


## Rückmeldung neben der Überschrift. Sie überlebt den Neuaufbau des
## Bildschirms, weil sie sonst genau in dem Moment verschwände, in dem sie
## etwas zu sagen hat: eine Aussprache baut den Bildschirm neu auf.
func _melde(text: String, gut: bool = true) -> void:
	meldungstext = text
	meldung_gut = gut


## Die Spieler, die von sich aus an die Tür klopfen.
##
## Jedes Anliegen hat eine Frist; wer sie verstreichen lässt, zahlt dafür mit
## Unzufriedenheit. Deshalb steht hier nicht nur, wer etwas will, sondern auch,
## wie lange man noch Zeit hat — und der Knopf, der das Gespräch öffnet.
func _gespraeche(eltern: Node, anliegen: Array) -> void:
	var karte := Bausteine.karte_in(eltern, "Spieler möchten Sie sprechen")
	if anliegen.is_empty():
		karte.add_child(Stil.leerzustand(
			"Derzeit hat niemand ein Anliegen.",
			"Wer zu wenig spielt, auf eine Vertragsverlängerung wartet oder sich über einen Mitspieler ärgert, kommt von selbst auf Sie zu. Dann steht es hier."))
		return
	Stil.karte_betonen(karte)
	karte.add_child(Stil.matt(
		"Ein Gespräch dauert eine Minute und entscheidet, ob ein Spieler weiter mitzieht. Wer die Frist verstreichen lässt, bekommt die Antwort auf dem Feld.",
		Stil.S_KLEIN))
	for e in anliegen:
		var eintrag: Dictionary = e
		var asid: String = str(eintrag["spieler"])
		if not Welt.daten["spieler"].has(asid):
			continue
		var asp: Dictionary = Welt.spieler(asid)
		var art: Dictionary = Anliegen.ARTEN.get(str(eintrag["art"]), {})
		var zeile := Stil.hbox(12)
		karte.add_child(zeile)
		zeile.add_child(Portraet.fuer_spieler(asid, 40.0))
		var spalte := Stil.vbox(2)
		spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zeile.add_child(spalte)
		spalte.add_child(Stil.text("%s — %s" % [Spielerfabrik.voller_name(asp),
			str(art.get("titel", "möchte Sie sprechen"))], Stil.S_NORMAL, Stil.AKZENT))
		spalte.add_child(Stil.beschnitten(Stil.matt("„%s“" % str(art.get("frage", "")), Stil.S_KLEIN), 20.0))
		var rest: int = maxi(int(eintrag["frist"]) - Welt.tag(), 0)
		zeile.add_child(Stil.abzeichen("NOCH %d TAG(E)" % rest,
			Stil.ROT if rest <= 3 else Stil.GELB))
		var knopf := Stil.knopf_primaer("Anhören")
		knopf.pressed.connect(func(): Anliegenfenster.oeffnen(self, asid))
		zeile.add_child(knopf)
