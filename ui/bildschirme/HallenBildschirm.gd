class_name HallenBildschirm
extends Bildschirm
## Halle & Fans: Eintrittspreise, Dauerkarten, die vier Fangruppen und das
## Programm des nächsten Heimspiels.
##
## Hier steht die Frage, die ein Verein jede Woche beantwortet: Für wen wird
## dieser Abend gemacht — und was darf er kosten?

var inhalt: VBoxContainer
## Welcher Reiter offen steht — ueberlebt den Neuaufbau, den jede
## Preisaenderung ausloest.
var reiter := "preise"
var meldung: Label

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Halle & Fans", 0))
	kopf.add_child(Stil.dehner())
	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	kopf.add_child(meldung)
	# Kein Rollbereich um den ganzen Bildschirm: die Reiter bringen ihren
	# eigenen mit.
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(inhalt)

func _melde(text: String, gut: bool = true) -> void:
	if meldung != null:
		meldung.text = text
		meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)

func aktualisieren() -> void:
	if inhalt == null:
		return
	leeren(inhalt)
	if Welt.mein_verein_id == "":
		inhalt.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	_kennzahlen()
	# Die Kennzahlen stehen immer da. Alles Weitere liegt hinter Reitern: der
	# Spieltag, das Gebaeude und das Geld sind drei Entscheidungen, keine
	# Bahn von sieben Karten.
	var gruppe := Stil.reitergruppe([
		{"id": "preise", "name": "Eintrittspreise"},
		{"id": "fans", "name": "Die Fanszene"},
		{"id": "programm", "name": "Spieltagsprogramm"},
		{"id": "gebaeude", "name": "Halle & Lizenz"},
		{"id": "geld", "name": "Darlehen"},
	], reiter)
	gruppe.bei_wechsel = func(id): reiter = str(id)
	inhalt.add_child(gruppe)
	# Preise und Fanszene in getrennten Reitern: nebeneinander ist jede der
	# beiden Karten fuer sich schon so hoch wie das Fenster.
	_preise(gruppe.feld("preise"))
	_fangruppen(gruppe.feld("fans"))
	_programm(gruppe.feld("programm"))
	_halle(gruppe.feld("gebaeude"), gruppe.feld("geld"))

# ------------------------------------------------------------ Kennzahlen ---
func _kennzahlen() -> void:
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)
	var reihe := Stil.hbox(10)
	inhalt.add_child(reihe)
	reihe.add_child(Stil.kachel("Kapazität", Stil.zahl(int(v["halle"]["kapazitaet"])),
		str(v["halle"]["name"])))
	var dk: int = Ticketing.dauerkarten_gesamt(Welt.daten, cid)
	var anteil: int = int(round(float(dk) / maxf(float(v["halle"]["kapazitaet"]), 1.0) * 100.0))
	reihe.add_child(Stil.kachel("Dauerkarten", Stil.zahl(dk), "%d %% der Halle vergeben" % anteil,
		Stil.GRUEN if anteil >= 25 and anteil <= 65 else Stil.GELB))
	var schnitt := 0
	var stats: Dictionary = v["saison"]
	if int(stats["heimspiele"]) > 0:
		schnitt = int(float(stats["zuschauer_summe"]) / float(stats["heimspiele"]))
	reihe.add_child(Stil.kachel("Schnitt", Stil.zahl(schnitt) if schnitt > 0 else "—",
		"%d Heimspiele" % int(stats["heimspiele"])))
	var stimmung: float = Fanszene.gesamtstimmung(Welt.daten, cid)
	reihe.add_child(Stil.kachel("Fanstimmung", "%d" % int(stimmung),
		"Treue %d" % int(float(v["fans"]["treue"])), Stil.prozent_farbe(stimmung)))
	var schuld: float = Darlehen.restschuld(Welt.daten, cid)
	reihe.add_child(Stil.kachel("Restschuld", Stil.geld(schuld) if schuld > 0.0 else "schuldenfrei",
		"%s je Woche" % Stil.geld(Darlehen.wochenlast(Welt.daten, cid)) if schuld > 0.0 else "keine Rate",
		Stil.ROT if schuld > float(v["jahresetat"]) * 0.5 else Stil.TEXT))

# --------------------------------------------------------------- Preise ---

func _preise(eltern: Node) -> void:
	var cid := Welt.mein_verein_id
	var karte := Bausteine.karte_in(eltern, "Eintrittspreise")
	# Beide Karten teilen sich die Breite nach Verhältnis statt nach Mindestmaß:
	# so bleibt die Fanszene auch dann lesbar, wenn links viel Platz gebraucht wird.
	var wurzel := Stil.karte_wurzel(karte)
	wurzel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wurzel.size_flags_stretch_ratio = 1.55
	karte.add_child(Bausteine.fliesstext("Ein hoher Preis bringt je Karte mehr und je Abend weniger. Die Kurve merkt es zuerst."))
	var sitze := Ticketing.plaetze(Welt.daten, cid)
	for k in Ticketing.KATEGORIEN:
		var kat: String = str(k)
		var info: Dictionary = Ticketing.KATEGORIE[kat]
		karte.add_child(Stil.trenner())
		# Name, Platzzahl und Preisfeld in einer Zeile: zwei Zeilen je Kategorie
		# waren vier Kategorien lang eine halbe Bildschirmhoehe nur fuer
		# Beschriftungen.
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		var name := Stil.text(str(info["name"]), Stil.S_NORMAL)
		name.custom_minimum_size = Vector2(120, 0)
		zeile.add_child(name)
		zeile.add_child(Stil.abzeichen("%s PLÄTZE" % Stil.zahl(int(sitze[kat])), Stil.TEXT_SCHWACH))
		var dk: int = Ticketing.dauerkarten(Welt.daten, cid, kat)
		if dk > 0:
			zeile.add_child(Stil.abzeichen("%s DAUERKARTEN" % Stil.zahl(dk), Stil.BLAU))

		var steuerung := zeile
		var feld := SpinBox.new()
		feld.min_value = 1
		feld.max_value = int(Ticketing.referenzpreis(Welt.daten, cid, kat) * 2.5)
		feld.step = 1
		feld.value = Ticketing.preis(Welt.daten, cid, kat)
		feld.custom_minimum_size = Vector2(110, 0)
		feld.suffix = " €"
		steuerung.add_child(feld)
		var lage := Stil.text("", Stil.S_KLEIN)
		lage.custom_minimum_size = Vector2(150, 0)
		steuerung.add_child(lage)
		var wirkung := Stil.matt("", Stil.S_MINI)
		wirkung.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		steuerung.add_child(wirkung)
		var auffrischen := func():
			Ticketing.preis_setzen(Welt.daten, cid, kat, feld.value)
			var text := Ticketing.preistext(Welt.daten, cid, kat)
			lage.text = "%s (Markt %s)" % [text, Stil.geld(Ticketing.referenzpreis(Welt.daten, cid, kat))]
			lage.add_theme_color_override("font_color", _preisfarbe(text))
			var f: float = Ticketing.nachfragefaktor(Welt.daten, cid, kat)
			wirkung.text = "Nachfrage %+d %%" % int(round((f - 1.0) * 100.0))
		auffrischen.call()
		feld.value_changed.connect(func(_w): auffrischen.call())
		var markt := Stil.knopf_flach("Marktpreis", Stil.AKZENT)
		markt.pressed.connect(func():
			feld.value = roundf(Ticketing.referenzpreis(Welt.daten, cid, kat)))
		steuerung.add_child(markt)
		karte.add_child(Bausteine.fliesstext(str(info["text"])))

	karte.add_child(Stil.trenner())
	_dauerkarten(karte)

func _preisfarbe(text: String) -> Color:
	match text:
		"deutlich zu teuer":
			return Stil.ROT
		"teuer":
			return Stil.GELB
		"marktüblich":
			return Stil.GRUEN
		"günstig":
			return Stil.TUERKIS
	return Stil.BLAU

func _dauerkarten(karte: Node) -> void:
	var cid := Welt.mein_verein_id
	var t := Ticketing.daten(Welt.daten, cid)
	karte.add_child(Stil.etikett("Dauerkarten"))
	var verkauft: bool = int(t.get("verkauft_saison", -1)) == Welt.saison_index()
	var zeile := Stil.hbox(8)
	karte.add_child(zeile)
	var l := Stil.matt("Rabatt auf 17 Heimspiele", Stil.S_KLEIN)
	l.custom_minimum_size = Vector2(200, 0)
	zeile.add_child(l)
	var schieber := HSlider.new()
	schieber.min_value = Ticketing.DAUERKARTE_MIN * 100.0
	schieber.max_value = Ticketing.DAUERKARTE_MAX * 100.0
	schieber.step = 1
	schieber.value = float(t["dauerkarte_faktor"]) * 100.0
	schieber.custom_minimum_size = Vector2(180, 0)
	schieber.editable = not verkauft
	zeile.add_child(schieber)
	var anzeige := Stil.text("", Stil.S_KLEIN, Stil.AKZENT)
	anzeige.custom_minimum_size = Vector2(220, 0)
	zeile.add_child(anzeige)
	var zeigen := func():
		var f: float = schieber.value / 100.0
		anzeige.text = "%d %% des Einzelpreises · Stehplatz %s" % [
			int(schieber.value), Stil.geld(Ticketing.preis(Welt.daten, cid, "steh") * float(Ticketing.HEIMSPIELE) * f)]
	zeigen.call()
	schieber.value_changed.connect(func(_w):
		Ticketing.faktor_setzen(Welt.daten, cid, schieber.value / 100.0)
		zeigen.call())
	if verkauft:
		karte.add_child(Bausteine.fliesstext("Der Vorverkauf dieser Saison ist abgeschlossen — %s Karten sind vergeben. Der Rabatt gilt wieder ab dem nächsten Sommer." % Stil.zahl(Ticketing.dauerkarten_gesamt(Welt.daten, cid))))
	else:
		karte.add_child(Bausteine.fliesstext("Der Vorverkauf läuft zum Saisonstart. Was Sie jetzt einstellen, entscheidet, wie viele Plätze für die ganze Saison weggehen.", Stil.S_MINI, Stil.GELB))

# ------------------------------------------------------------ Fangruppen ---

func _fangruppen(eltern: Node) -> void:
	var cid := Welt.mein_verein_id
	var karte := Bausteine.karte_in(eltern, "Die Fanszene")
	var wurzel := Stil.karte_wurzel(karte)
	wurzel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wurzel.size_flags_stretch_ratio = 1.0
	wurzel.custom_minimum_size = Vector2(360, 0)
	karte.add_child(Bausteine.fliesstext("Vier Gruppen, vier Erwartungen. Wer es allen recht macht, macht es niemandem recht."))
	var gruende := Fanszene.begruendungen(Welt.daten, cid)
	for g in Fanszene.GRUPPEN:
		var gruppe: String = str(g)
		var info: Dictionary = Fanszene.GRUPPE[gruppe]
		karte.add_child(Stil.trenner())
		var wert: float = Fanszene.stimmung(Welt.daten, cid, gruppe)
		var kopf := Stil.hbox(8)
		karte.add_child(kopf)
		# Kurzname in der Kopfzeile, der volle Name steht im Beschreibungstext
		# und in den Meldungen — sonst wird die Zeile abgeschnitten.
		var name := Stil.text(str(info.get("kurzname", info["name"])), Stil.S_NORMAL)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		kopf.add_child(name)
		kopf.add_child(Stil.balken(wert, 100.0, 90, Stil.prozent_farbe(wert)))
		kopf.add_child(Stil.text("%d" % int(wert), Stil.S_KLEIN, Stil.prozent_farbe(wert)))
		kopf.add_child(Stil.dehner())
		if wert <= Fanszene.PROTEST:
			kopf.add_child(Stil.abzeichen("UNMUT", Stil.ROT, true))
		elif wert >= Fanszene.BEGEISTERT:
			kopf.add_child(Stil.abzeichen("GESCHLOSSEN", Stil.GRUEN))
		karte.add_child(Bausteine.fliesstext(str(info["text"])))
		# Was diese Gruppe gerade bewegt — die drei stärksten Gründe.
		var liste: Array = (gruende[gruppe] as Array).duplicate()
		liste.sort_custom(func(a, b): return absf(float(a["wert"])) > absf(float(b["wert"])))
		for e in liste.slice(0, 3):
			var w: float = float(e["wert"])
			var z := Stil.hbox(6)
			karte.add_child(z)
			var punkt := Stil.text("%+d" % int(round(w)), Stil.S_MINI, Stil.GRUEN if w > 0.0 else Stil.ROT)
			punkt.custom_minimum_size = Vector2(34, 0)
			punkt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			z.add_child(punkt)
			z.add_child(Bausteine.fliesstext(str(e["grund"]), Stil.S_MINI, null, 150.0))

# ---------------------------------------------------------- Spieltag ---

func _programm(eltern: Node) -> void:
	var cid := Welt.mein_verein_id
	var karte := Bausteine.karte_in(eltern, "Programm des nächsten Heimspiels")
	var naechstes := _naechstes_heimspiel()
	var kopf := Stil.hbox(10)
	karte.add_child(kopf)
	if naechstes.is_empty():
		kopf.add_child(Stil.matt("Derzeit ist kein Heimspiel angesetzt.", Stil.S_KLEIN))
	else:
		var gid: String = str(naechstes["gast"])
		kopf.add_child(Stil.text("gegen %s · %s" % [
			str(Welt.verein(gid).get("name", "?")), Kalender.text(int(naechstes["tag"]), Welt.startjahr())], Stil.S_KLEIN, Stil.AKZENT))
		kopf.add_child(Stil.dehner())
		var rat: String = Spieltagsprogramm.vorschlag(Welt.daten, cid, gid)
		var vorschlag := Stil.knopf("Vorschlag: %s" % str((Spieltagsprogramm.PROGRAMME[rat] as Dictionary)["name"]))
		vorschlag.tooltip_text = "Der Stab schlägt vor, was gerade am dringendsten gebraucht wird."
		vorschlag.pressed.connect(func():
			var erg := Spieltagsprogramm.waehlen(Welt.daten, cid, rat)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			aktualisieren())
		kopf.add_child(vorschlag)
	karte.add_child(Bausteine.fliesstext("Das Programm gilt für das nächste Heimspiel und wird danach zurückgesetzt. Bezahlt wird am Spieltag."))

	var aktuell: String = Spieltagsprogramm.gewaehlt(Welt.daten, cid)
	var g := Stil.tabelle(["Programm", "Kosten", "Wirkung auf das Publikum", "Fangruppen", ""])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for p in Spieltagsprogramm.REIHE:
		var schluessel: String = str(p)
		var info: Dictionary = Spieltagsprogramm.PROGRAMME[schluessel]
		var name := Stil.text(str(info["name"]), Stil.S_KLEIN, Stil.AKZENT if schluessel == aktuell else Stil.TEXT)
		name.tooltip_text = str(info["text"])
		g.add_child(name)
		var preis: float = Spieltagsprogramm.kosten(Welt.daten, cid, schluessel)
		g.add_child(Stil.text(Stil.geld(preis) if preis > 0.0 else "—", Stil.S_KLEIN,
			Stil.TEXT_MATT if preis <= 0.0 else Stil.TEXT))
		var reiz := Stil.hbox(4)
		for k in Ticketing.KATEGORIEN:
			var f: float = float((info["reiz"] as Dictionary).get(str(k), 1.0))
			if absf(f - 1.0) < 0.01:
				continue
			reiz.add_child(Stil.abzeichen("%s %+d %%" % [
				str((Ticketing.KATEGORIE[str(k)] as Dictionary)["kurz"]), int(round((f - 1.0) * 100.0))],
				Stil.GRUEN if f > 1.0 else Stil.ROT))
		var puls: float = float(info["puls"])
		if absf(puls) > 0.01:
			reiz.add_child(Stil.abzeichen("PULS %+d" % int(puls), Stil.AKZENT if puls > 0.0 else Stil.ROT))
		g.add_child(reiz)
		var fans := Stil.hbox(4)
		for gruppe in (info["fans"] as Dictionary).keys():
			var w: float = float((info["fans"] as Dictionary)[gruppe])
			if absf(w) < 0.3:
				continue
			fans.add_child(Stil.abzeichen("%s %+d" % [
				str((Fanszene.GRUPPE[str(gruppe)] as Dictionary)["kurz"]), int(round(w))],
				Stil.GRUEN if w > 0.0 else Stil.ROT))
		g.add_child(fans)
		if schluessel == aktuell:
			g.add_child(Stil.abzeichen("ANGESETZT", Stil.GRUEN, true))
		else:
			var knopf := Stil.knopf("Ansetzen")
			knopf.pressed.connect(func():
				var erg := Spieltagsprogramm.waehlen(Welt.daten, cid, schluessel)
				_melde(str(erg["grund"]), bool(erg["ok"]))
				aktualisieren())
			g.add_child(knopf)

func _naechstes_heimspiel() -> Dictionary:
	var cid := Welt.mein_verein_id
	var bestes := {}
	for mid in Welt.daten["spiele"].keys():
		var m: Dictionary = Welt.partie(str(mid))
		if bool(m["gespielt"]) or str(m["heim"]) != cid:
			continue
		if int(m["tag"]) < Welt.tag():
			continue
		if bestes.is_empty() or int(m["tag"]) < int(bestes["tag"]):
			bestes = m
	return bestes

# ---------------------------------------------------------------- Halle ---

func _halle(eltern: Node, geldfeld: Node) -> void:
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)
	var reihe := Stil.hbox(12)
	eltern.add_child(reihe)

	var karte := Bausteine.karte_in(reihe, "Die Halle")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(Stil.info_zeile("Name", str(v["halle"]["name"])))
	karte.add_child(Stil.info_zeile("Kapazität", Stil.zahl(int(v["halle"]["kapazitaet"]))))
	karte.add_child(Stil.info_zeile("Komfort", "Stufe %d von 10" % int(v["halle"]["komfort"])))
	karte.add_child(Stil.info_zeile("Hallenpuls-Grundwert", "%d" % int(float(v["hallenpuls_basis"])),
		Stil.prozent_farbe(float(v["hallenpuls_basis"]))))
	karte.add_child(Bausteine.fliesstext("Der Komfort entscheidet, wie viele Sitz- und Logenplätze die Halle überhaupt hat — und damit, wie viel ein Abend einbringen kann."))
	var projekt: Dictionary = v["halle"]["bauprojekt"]
	if projekt.is_empty():
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		var kosten := Finanzen.ausbaukosten(Welt.daten, cid, "halle")
		zeile.add_child(Stil.matt("Ausbau: %s" % Stil.geld(kosten), Stil.S_KLEIN))
		var knopf := Stil.knopf_primaer("Halle ausbauen")
		knopf.pressed.connect(func():
			var erg := Finanzen.ausbau_starten(Welt.daten, cid, "halle")
			_melde(str(erg["grund"]), bool(erg["ok"]))
			aktualisieren())
		zeile.add_child(knopf)
	else:
		karte.add_child(Stil.text("Bauprojekt läuft: %s, fertig %s." % [
			str(Finanzen.AUSBAU_STUFEN[str(projekt["bereich"])]["name"]),
			Kalender.text(int(projekt["fertig_tag"]), Welt.startjahr(), true)], Stil.S_KLEIN, Stil.GELB))

	_lizenz(reihe)
	var reihe2 := Stil.hbox(12)
	geldfeld.add_child(reihe2)
	_darlehen(reihe2)

## Was der Lizenzierungsausschuss an dieser Halle zu beanstanden hat — und was
## das Haftmittel im Verein anrichtet.
func _lizenz(eltern: Node) -> void:
	var cid := Welt.mein_verein_id
	var karte := Bausteine.karte_in(eltern, "Lizenzauflagen")
	var wurzel := Stil.karte_wurzel(karte)
	wurzel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wurzel.custom_minimum_size = Vector2(420, 0)
	var h := Lizenzierung.halle(Welt.daten, cid)
	var stufe := Lizenzierung.stufe(Welt.daten, cid)
	if stufe > 2:
		karte.add_child(Bausteine.fliesstext("In dieser Spielklasse prüft der Lizenzierungsausschuss die Halle nicht."))
		return
	var mindest: int = int(Lizenzierung.KAPAZITAET_MIN.get(stufe, 1000))
	karte.add_child(Stil.info_zeile("Mindestkapazität", "%s von %s" % [
		Stil.zahl(int(h["kapazitaet"])), Stil.zahl(mindest)],
		Stil.GRUEN if int(h["kapazitaet"]) >= mindest else Stil.ROT))
	karte.add_child(Stil.info_zeile("Licht Spielfeld", "%d von %d Lux" % [
		int(h["licht_feld"]), Lizenzierung.LUX_FELD],
		Stil.GRUEN if int(h["licht_feld"]) >= Lizenzierung.LUX_FELD else Stil.ROT))
	karte.add_child(Stil.info_zeile("Licht Zuschauerbereich", "%d von %d Lux" % [
		int(h["licht_rang"]), Lizenzierung.LUX_RANG],
		Stil.GRUEN if int(h["licht_rang"]) >= Lizenzierung.LUX_RANG else Stil.ROT))
	karte.add_child(Stil.info_zeile("Gleichmäßigkeit", "%s von %s" % [
		Stil.komma(float(h["gleichmaessigkeit"]), 2), Stil.komma(Lizenzierung.GLEICHMAESSIGKEIT_MIN, 2)],
		Stil.GRUEN if float(h["gleichmaessigkeit"]) >= Lizenzierung.GLEICHMAESSIGKEIT_MIN else Stil.ROT))
	karte.add_child(Stil.info_zeile("Gästekontingent", "%d Plätze kostenlos" % Lizenzierung.gaestekontingent(Welt.daten, cid)))
	var offen: Array = Lizenzierung.auflagen(Welt.daten, cid)
	if offen.is_empty():
		karte.add_child(Stil.text("Die Halle erfüllt alle Vorgaben.", Stil.S_KLEIN, Stil.GRUEN))
	else:
		for a in offen:
			karte.add_child(Bausteine.fliesstext(str((a as Dictionary)["text"])))
		var braucht_licht := false
		for a2 in offen:
			if str((a2 as Dictionary)["feld"]) == "licht":
				braucht_licht = true
		if braucht_licht:
			var zeile2 := Stil.hbox(8)
			karte.add_child(zeile2)
			zeile2.add_child(Stil.matt("Nachrüstung: %s" % Stil.geld(Lizenzierung.lichtkosten(Welt.daten, cid)), Stil.S_KLEIN))
			var knopf2 := Stil.knopf_primaer("Beleuchtung nachrüsten")
			knopf2.pressed.connect(func():
				var erg := Lizenzierung.licht_nachruesten(Welt.daten, cid)
				_melde(str(erg["grund"]), bool(erg["ok"]))
				aktualisieren())
			zeile2.add_child(knopf2)
	if Lizenzierung.harzverbot(Welt.daten, cid):
		karte.add_child(Stil.text("Harzverbot in der Trainingshalle", Stil.S_KLEIN, Stil.GELB))
		karte.add_child(Bausteine.fliesstext("Jugend und Zweite trainieren in einer kommunalen Halle, in der kein Haftmittel erlaubt ist. Sie weichen auf kleinere, harzfreie Bälle aus — der Übergang in den Profikader wird dadurch spürbar schwerer."))
	else:
		karte.add_child(Bausteine.fliesstext("In der Trainingshalle ist Haftmittel erlaubt. Nachwuchs und Zweite spielen mit demselben Ball wie die Profis."))

func _darlehen(eltern: Node) -> void:
	var cid := Welt.mein_verein_id
	var karte := Bausteine.karte_in(eltern, "Darlehen")
	var wurzel := Stil.karte_wurzel(karte)
	wurzel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wurzel.size_flags_stretch_ratio = 1.3
	wurzel.custom_minimum_size = Vector2(420, 0)
	var laufende: Array = Darlehen.liste(Welt.daten, cid)
	if laufende.is_empty():
		karte.add_child(Bausteine.fliesstext("Sie sind schuldenfrei. Ein Kredit bringt Geld für einen Ausbau, den die Kasse nicht hergibt — und kostet danach jede Woche."))
	else:
		for i in range(laufende.size()):
			var k: Dictionary = laufende[i]
			var zeile := Stil.hbox(8)
			karte.add_child(zeile)
			var text := Stil.text("%s · %s" % [Stil.geld(float(k["betrag"])), str(k["zweck"])], Stil.S_KLEIN)
			text.custom_minimum_size = Vector2(230, 0)
			zeile.add_child(text)
			zeile.add_child(Stil.matt("%.1f %%" % (float(k["zins"]) * 100.0), Stil.S_MINI))
			zeile.add_child(Stil.matt("Rest %s" % Stil.geld(float(k["rest"])), Stil.S_MINI))
			zeile.add_child(Stil.matt("%s/Woche" % Stil.geld(float(k["rate"])), Stil.S_MINI))
			zeile.add_child(Stil.dehner())
			var index := i
			var ab := Stil.knopf("Ablösen")
			ab.tooltip_text = "Vorzeitig zurückzahlen. Die Bank verzichtet dabei auf die Hälfte der offenen Zinsen."
			ab.pressed.connect(func():
				var erg := Darlehen.abloesen(Welt.daten, cid, index)
				_melde(str(erg["grund"]), bool(erg["ok"]))
				aktualisieren())
			zeile.add_child(ab)
		karte.add_child(Stil.trenner())

	var moeglich: float = Darlehen.hoechstbetrag(Welt.daten, cid)
	if moeglich < 25000.0:
		karte.add_child(Stil.text("Die Bank gibt Ihnen derzeit nichts mehr.", Stil.S_KLEIN, Stil.ROT))
		return
	karte.add_child(Stil.etikett("Neues Darlehen"))
	var eingabe := Stil.hbox(8)
	karte.add_child(eingabe)
	var betrag := SpinBox.new()
	betrag.min_value = 25000
	betrag.max_value = int(moeglich)
	betrag.step = 25000
	betrag.value = mini(int(moeglich), 250000)
	betrag.custom_minimum_size = Vector2(150, 0)
	eingabe.add_child(betrag)
	var dauer := OptionButton.new()
	dauer.custom_minimum_size = Vector2(140, 0)
	for i in range(Darlehen.LAUFZEITEN.size()):
		var jahre: int = int(Darlehen.LAUFZEITEN[i])
		dauer.add_item("%d Saison%s" % [jahre, "" if jahre == 1 else "s"])
		dauer.set_item_metadata(i, jahre)
	dauer.select(1)
	eingabe.add_child(dauer)
	var vorschau := Bausteine.fliesstext("")
	karte.add_child(vorschau)
	var rechnen := func():
		var jahre: int = int(dauer.get_item_metadata(dauer.selected))
		var zins: float = Darlehen.zinssatz(Welt.daten, cid, betrag.value, jahre)
		var rate: float = Darlehen.rate(betrag.value, zins, jahre)
		var geprueft := Darlehen.pruefen(Welt.daten, cid, betrag.value, jahre)
		vorschau.text = "%.1f %% Zinsen · %s je Woche · %s Zinskosten insgesamt. %s" % [
			zins * 100.0, Stil.geld(rate),
			Stil.geld(Darlehen.gesamtkosten(betrag.value, zins, jahre)),
			"" if bool(geprueft["ok"]) else str(geprueft["grund"])]
	rechnen.call()
	betrag.value_changed.connect(func(_w): rechnen.call())
	dauer.item_selected.connect(func(_i): rechnen.call())
	var zweck := LineEdit.new()
	zweck.placeholder_text = "Verwendungszweck (z. B. Hallenausbau)"
	zweck.custom_minimum_size = Vector2(240, 0)
	eingabe.add_child(zweck)
	var holen := Stil.knopf_primaer("Darlehen aufnehmen")
	holen.pressed.connect(func():
		var jahre: int = int(dauer.get_item_metadata(dauer.selected))
		var erg := Darlehen.aufnehmen(Welt.daten, cid, betrag.value, jahre, zweck.text.strip_edges())
		_melde(str(erg["grund"]), bool(erg["ok"]))
		aktualisieren())
	eingabe.add_child(holen)
