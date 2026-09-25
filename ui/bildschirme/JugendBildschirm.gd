class_name JugendBildschirm
extends Bildschirm
## Das Nachwuchszentrum: Talente einschätzen, fördern, befördern oder gehen lassen.

var inhalt: VBoxContainer
var meldung: Label
## "akademie", "talente" oder "zweite". Das gehört alles zusammen — ein Talent
## ohne Spielpraxis ist eine halbe Entscheidung — aber nicht auf denselben
## Schirm: die Übersicht und eine Tabelle mit zwölf Namen passen nicht
## zugleich ins Fenster, und dann scrollt man an der Übersicht vorbei.
var reiter := "akademie"
var reiterleiste: HBoxContainer

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Nachwuchszentrum", 0))
	reiterleiste = Stil.hbox(0)
	kopf.add_child(reiterleiste)
	_baue_reiter()
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

func _baue_reiter() -> void:
	leeren(reiterleiste)
	reiterleiste.add_child(Stil.segmente([
		{"id": "akademie", "name": "Akademie"}, {"id": "talente", "name": "Talente"},
		{"id": "zweite", "name": "Die Zweite"}],
		reiter, func(id):
			reiter = str(id)
			_baue_reiter()
			aktualisieren()))

func aktualisieren() -> void:
	if inhalt == null:
		return
	if reiterleiste != null:
		_baue_reiter()
	leeren(inhalt)
	if Welt.mein_verein_id == "" or not Welt.bereit():
		inhalt.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	if reiter == "zweite":
		_zweite()
		return
	if reiter == "talente":
		_talente()
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

	var zweite_reihe := Stil.hbox(12)
	inhalt.add_child(zweite_reihe)
	_zertifikat(zweite_reihe)


## Der Jahrgang selbst: eine Tabelle, die für sich eine Bildschirmhöhe füllt.
func _talente() -> void:
	var cid := Welt.mein_verein_id
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


# ------------------------------------------------------------- Die Zweite ---

## Die zweite Mannschaft: Tabelle, letzte Ergebnisse, Aufgebot und was jeder
## dort tatsächlich geleistet hat.
##
## Der Sinn steht in der ersten Zeile des Bildschirms: ohne Spielpraxis ist
## jede Einschätzung eines Talents geraten. Hier stehen die Zahlen, die eine
## Beförderung begründen oder verhindern.
func _zweite() -> void:
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)
	var b := Zweite.bilanz(Welt.daten, cid)

	var oben := Stil.hbox(12)
	inhalt.add_child(oben)

	var lage := Bausteine.karte_in(oben, "Saisonbilanz")
	Stil.karte_wurzel(lage).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lage.add_child(Bausteine.fliesstext(
		"Die Zweite spielt die Reserverunde: immer dann, wenn die Erste ein Ligaspiel hat, tritt sie gegen die Zweite desselben Gegners an. Hier bekommen Talente die Minuten, die im Profikader nicht frei sind.",
		Stil.S_MINI))
	if int(b["spiele"]) == 0:
		lage.add_child(Stil.leerzustand("In dieser Saison hat die Zweite noch nicht gespielt."))
	else:
		var zahlen := Stil.hbox(18)
		lage.add_child(zahlen)
		zahlen.add_child(_zahl("Spiele", str(int(b["spiele"])), Stil.TEXT))
		zahlen.add_child(_zahl("Punkte", str(int(b["punkte"])), Stil.AKZENT))
		zahlen.add_child(_zahl("Bilanz", "%d–%d–%d" % [int(b["siege"]), int(b["unentschieden"]), int(b["niederlagen"])], Stil.TEXT))
		var diff: int = int(b["tore"]) - int(b["gegentore"])
		zahlen.add_child(_zahl("Tore", "%d:%d" % [int(b["tore"]), int(b["gegentore"])],
			Stil.GRUEN if diff >= 0 else Stil.ROT))
		var letzte: Array = (v.get("zweite", {}) as Dictionary).get("letzte", [])
		if not letzte.is_empty():
			lage.add_child(Stil.trenner())
			lage.add_child(Stil.etikett("Zuletzt"))
			for e in letzte:
				var eig: int = int((e as Dictionary)["eigene"])
				var fre: int = int((e as Dictionary)["fremde"])
				var farbe: Color = Stil.GRUEN if eig > fre else (Stil.GELB if eig == fre else Stil.ROT)
				lage.add_child(Stil.info_zeile(
					"gegen %s II" % str(Welt.verein(str((e as Dictionary)["gegner"])).get("name", "?")),
					"%d:%d" % [eig, fre], farbe))

	var tab := Bausteine.karte_in(oben, "Reservetabelle")
	Stil.karte_wurzel(tab).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var zeilen := Zweite.tabelle(Welt.daten, str(v["liga"]))
	if zeilen.is_empty():
		tab.add_child(Stil.matt("Für diese Liga gibt es keine Reserverunde."))
	else:
		var gt := Stil.tabelle(["#", "Verein", "SP", "P", "Tore", "Diff"])
		gt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_child(gt)
		var platz := 0
		for z in zeilen:
			platz += 1
			var eigen: bool = str((z as Dictionary)["verein"]) == cid
			var farbe: Color = Stil.AKZENT if eigen else Stil.TEXT
			gt.add_child(Stil.text(str(platz), Stil.S_KLEIN, farbe))
			gt.add_child(Stil.text("%s II" % str(Welt.verein(str((z as Dictionary)["verein"]))["name"]),
				Stil.S_KLEIN, farbe))
			gt.add_child(Stil.matt(str(int((z as Dictionary)["spiele"])), Stil.S_KLEIN))
			gt.add_child(Stil.text(str(int((z as Dictionary)["punkte"])), Stil.S_KLEIN, farbe))
			gt.add_child(Stil.matt("%d:%d" % [int((z as Dictionary)["tore"]), int((z as Dictionary)["gegentore"])], Stil.S_KLEIN))
			var dz: int = int((z as Dictionary)["diff"])
			gt.add_child(Stil.text("%+d" % dz, Stil.S_KLEIN, Stil.GRUEN if dz >= 0 else Stil.ROT))

	var kader := Bausteine.karte_in(inhalt, "Einsatzplanung")
	var aufgebot := Zweite.aufgebot(Welt.daten, cid)
	var alle := Zweite.kandidaten(Welt.daten, cid)
	kader.add_child(Bausteine.fliesstext(
		"Sie bestimmen, wer viel spielt. Gesetzt heißt: in den ersten Sieben, also rund zweiundfünfzig Minuten. Rotation heißt: nach Stärke, wenn Platz ist. Die Reihenfolge im Aufgebot ist die Einsatzzeit — es sind %d Plätze, und wer weiter hinten steht, kommt in Abschnitten." % Zweite.AUFGEBOT,
		Stil.S_MINI))
	if alle.is_empty():
		kader.add_child(Stil.leerzustand("Niemand kommt derzeit für die Zweite in Frage."))
		return
	# Zwei Gruppen, eine Mannschaft.
	#
	# Der Trainer denkt in Akademie und Profikader, und genau so steht es
	# hier. Auflaufen tun beide für dieselbe Zweite: eine eigene
	# Jugendrunde mit eigenem Spielplan gibt es im Spiel nicht.
	var akademie: Array = []
	var profis: Array = []
	for sid0 in alle:
		if bool(Welt.spieler(str(sid0)).get("jugendspieler", false)):
			akademie.append(str(sid0))
		else:
			profis.append(str(sid0))
	var geordnet: Array = []
	if not akademie.is_empty():
		geordnet.append({"kopf": "Aus der Akademie", "ids": akademie})
	if not profis.is_empty():
		geordnet.append({"kopf": "Aus dem Profikader", "ids": profis})
	for gruppe in geordnet:
		kader.add_child(Stil.band(str((gruppe as Dictionary)["kopf"])))
		var gg := Stil.tabelle(["Pos", "Name", "Alter", "Stärke", "Spiele", "Minuten", "Tore", "Note", "Einsatz"])
		gg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kader.add_child(gg)
		_einsatzzeilen(gg, (gruppe as Dictionary)["ids"], aufgebot)
	return

## Eine Gruppe von Spielern als Tabellenzeilen.
func _einsatzzeilen(g: GridContainer, ids: Array, aufgebot: Array) -> void:
	for sid in ids:
		var sp: Dictionary = Welt.spieler(sid)
		var k := Zweite.statistik(sp)
		var dabei: bool = aufgebot.has(sid)
		g.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		var zeile := Stil.hbox(4)
		var knopf := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		knopf.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		zeile.add_child(knopf)
		if not bool(sp.get("jugendspieler", false)):
			zeile.add_child(Stil.abzeichen("PROFI", Stil.TEXT_SCHWACH))
		# Freigegeben heißt "kommt in Frage", im Aufgebot heißt "läuft am
		# Wochenende wirklich auf". Bei zwölf Plätzen und zwanzig Kandidaten
		# ist das nicht dasselbe.
		if dabei:
			zeile.add_child(Stil.abzeichen("AUFGEBOT", Stil.GRUEN))
		g.add_child(zeile)
		g.add_child(Stil.matt(str(int(sp["alter"])), Stil.S_KLEIN))
		g.add_child(Stil.text(Scouting.gesamt_text(Welt.daten, sid), Stil.S_KLEIN,
			Stil.wert_farbe(Spielerfabrik.gesamt(sp), 100.0)))
		g.add_child(Stil.matt(str(int(k["spiele"])), Stil.S_KLEIN))
		g.add_child(Stil.matt("%d" % int(float(k["minuten"])), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(k["tore"])), Stil.S_KLEIN, Stil.AKZENT if int(k["tore"]) > 0 else Stil.TEXT_MATT))
		var n: float = Zweite.note(sp)
		g.add_child(Stil.text("—" if n <= 0.0 else "%.2f" % n, Stil.S_KLEIN,
			Stil.prozent_farbe(n * 10.0) if n > 0.0 else Stil.TEXT_MATT))
		g.add_child(_einsatzwahl(sid, dabei))

## Die Einsatzrolle eines Spielers in der Zweiten.
##
## Vorher stand hier ein Haken: mitspielen ja oder nein. Damit war die
## einzige Entscheidung, die ein Trainer über seine Reserve treffen konnte,
## "gar nicht" — und genau die trifft man fast nie. Die eigentliche Frage
## einer zweiten Mannschaft ist, wer viel spielt und wer wenig: der
## Siebzehnjährige, den man aufbauen will, gehört in die ersten Sieben, der
## Profi auf dem Weg zurück braucht dreißig Minuten, und der Torwart Nummer
## drei soll nicht dem Talent den Platz wegnehmen.
##
## Die Rolle ist genau dieser Hebel: Zweite.aufgebot sortiert danach, und die
## Reihenfolge im Aufgebot ist die Einsatzzeit — die ersten sieben spielen
## zweiundfünfzig Minuten, der Rest wird nach hinten abgestuft.
func _einsatzwahl(sid: String, dabei: bool) -> Control:
	var jetzt := Zweite.rolle(Welt.daten, sid)
	var optionen: Array = []
	for r in Zweite.ROLLEN:
		optionen.append({"id": str((r as Dictionary)["id"]), "name": str((r as Dictionary)["name"])})
	var wahl := OptionButton.new()
	for i in optionen.size():
		wahl.add_item(str((optionen[i] as Dictionary)["name"]), i)
		wahl.set_item_metadata(i, str((optionen[i] as Dictionary)["id"]))
		if str((optionen[i] as Dictionary)["id"]) == jetzt:
			wahl.selected = i
	var hinweis := ""
	for r2 in Zweite.ROLLEN:
		if str((r2 as Dictionary)["id"]) == jetzt:
			hinweis = str((r2 as Dictionary)["satz"])
	wahl.tooltip_text = "%s\n\n%s" % [hinweis,
		"Steht an diesem Wochenende im Aufgebot." if dabei
		else "Steht an diesem Wochenende nicht im Aufgebot — es sind nur %d Plätze." % Zweite.AUFGEBOT]
	wahl.item_selected.connect(func(i):
		Zweite.rolle_setzen(Welt.daten, sid, str(wahl.get_item_metadata(i)))
		aktualisieren())
	return wahl

func _zahl(beschriftung: String, wert: String, farbe: Color) -> Control:
	var v := Stil.vbox(1)
	v.add_child(Stil.etikett(beschriftung))
	v.add_child(Stil.text(wert, Stil.S_GROSS, farbe))
	return v


## Das Jugendzertifikat der Liga.
##
## Es ist kein Abzeichen, sondern eine Rechnung: wer die Auflagen nicht
## erfuellt, zahlt in einen Solidarfonds, aus dem die zertifizierten Vereine
## bedient werden. Deshalb steht hier nicht nur, ob es erteilt ist, sondern
## auch, woran es haengt.
func _zertifikat(eltern: Node) -> void:
	var cid := Welt.mein_verein_id
	var karte := Bausteine.karte_in(eltern, "Jugendzertifikat")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Lizenzierung.stufe(Welt.daten, cid) > 2:
		karte.add_child(Bausteine.fliesstext("Das Jugendzertifikat vergibt die Liga nur an Erst- und Zweitligisten."))
		return
	var erteilt := Lizenzierung.hat_zertifikat(Welt.daten, cid)
	var erfuellt := Lizenzierung.zertifikat_erfuellt(Welt.daten, cid)
	karte.add_child(Stil.text("Zuletzt erteilt" if erteilt else "Zuletzt verweigert",
		Stil.S_NORMAL, Stil.GRUEN if erteilt else Stil.ROT))
	for k in Lizenzierung.zertifikatskriterien(Welt.daten, cid):
		var e: Dictionary = k
		var zeile := Stil.info_zeile(str(e["text"]), str(e["stand"]),
			Stil.GRUEN if bool(e["erfuellt"]) else Stil.ROT)
		karte.add_child(zeile)
	if erfuellt:
		karte.add_child(Bausteine.fliesstext("Bei der nächsten Prüfung sind alle Auflagen erfüllt. Der Verein wird aus dem Solidarfonds bedient."))
	else:
		var strafe: float = float(Welt.verein(cid).get("jahresetat", 2000000.0)) * Lizenzierung.ZERT_STRAFE_ANTEIL
		karte.add_child(Bausteine.fliesstext("Bei der nächsten Prüfung fehlt etwas. Das kostet rund %s Strafzahlung — Geld, das an die zertifizierten Vereine geht." % Stil.geld(strafe)))
