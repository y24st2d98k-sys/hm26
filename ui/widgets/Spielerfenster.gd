class_name Spielerfenster
extends Control
## Detailfenster eines Spielers. Es liegt dauerhaft im Baum (Gruppe "spielerfenster")
## und wird nur ein- und ausgeblendet — dadurch gibt es keine zu spaet erzeugten Knoten.
## Der Inhaltsbereich wird bei jedem Oeffnen geleert und neu aufgebaut; dauerhafte
## Elemente (Rahmen, Reiterleiste) liegen ausserhalb dieses Bereichs.

var sid: String = ""
var gespraech_thema: String = ""
var vergleich_sid: String = ""
var reiter: String = "uebersicht"
var inhalt: VBoxContainer
var kopfbereich: VBoxContainer
var reiterleiste: HBoxContainer
var meldung: Label

const REITER := [["uebersicht", "Übersicht"], ["attribute", "Attribute"], ["statistik", "Statistik"],
	["vertrag", "Vertrag & Rolle"], ["entwicklung", "Entwicklung"]]

static func oeffnen(von: Node, spieler_id: String) -> void:
	var f = von.get_tree().get_first_node_in_group("spielerfenster")
	if f != null:
		f.zeige(spieler_id)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("spielerfenster")

func _ready() -> void:
	theme = Stil.theme()
	var schleier := ColorRect.new()
	schleier.color = Color(0, 0, 0, 0.62)
	schleier.set_anchors_preset(Control.PRESET_FULL_RECT)
	schleier.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			schliessen())
	add_child(schleier)

	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mitte)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 760)
	panel.add_theme_stylebox_override("panel", Stil.box(Stil.FLAECHE, Stil.R_GROSS, Stil.RAND_HELL))
	mitte.add_child(panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(m)

	var v := Stil.vbox(10)
	m.add_child(v)

	kopfbereich = Stil.vbox(6)
	v.add_child(kopfbereich)

	reiterleiste = Stil.hbox(6)
	v.add_child(reiterleiste)
	_reiter_aufbauen()
	reiterleiste.add_child(Stil.dehner())
	var zu := Stil.knopf("Schließen")
	zu.pressed.connect(schliessen)
	reiterleiste.add_child(zu)

	meldung = Stil.text("", Stil.S_KLEIN, Stil.AKZENT)
	v.add_child(meldung)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	inhalt = Stil.vbox(10)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)

func zeige(spieler_id: String) -> void:
	sid = spieler_id
	reiter = "uebersicht"
	gespraech_thema = ""
	vergleich_sid = ""
	meldung.text = ""
	visible = true
	_reiter_aufbauen()
	_zeichne()

func schliessen() -> void:
	visible = false
	Welt.zustand_geaendert.emit()

func _melde(text: String, gut: bool = true) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)

func _zeichne() -> void:
	if sid == "" or not Welt.daten.get("spieler", {}).has(sid):
		visible = false
		return
	Bildschirm.leeren(kopfbereich)
	Bildschirm.leeren(inhalt)
	var sp: Dictionary = Welt.spieler(sid)
	_kopf(sp)
	match reiter:
		"attribute":
			_attribute(sp)
		"statistik":
			_statistik(sp)
		"vertrag":
			_vertrag(sp)
		"entwicklung":
			_entwicklung(sp)
		_:
			_uebersicht(sp)

func _kopf(sp: Dictionary) -> void:
	var h := Stil.hbox(14)
	kopfbereich.add_child(h)
	h.add_child(Portraet.fuer_spieler(sid, 72.0))
	if str(sp["verein"]) != "":
		h.add_child(Wappen.fuer_verein(str(sp["verein"]), 46.0))
	var links := Stil.vbox(2)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(links)
	var namenszeile := Stil.hbox(8)
	links.add_child(namenszeile)
	var nummer: int = int(sp.get("nummer", 0))
	if nummer > 0:
		var rueckennummer := Stil.titel(str(nummer), 1)
		rueckennummer.add_theme_color_override("font_color", Stil.AKZENT)
		rueckennummer.tooltip_text = "Rückennummer"
		namenszeile.add_child(rueckennummer)
	namenszeile.add_child(Stil.titel(Spielerfabrik.voller_name(sp), 1))
	var zeile := Stil.hbox(8)
	links.add_child(zeile)
	zeile.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
	for zp in sp["zweitpositionen"]:
		zeile.add_child(Stil.abzeichen(str(zp), Stil.TEXT_SCHWACH))
	zeile.add_child(Flagge.fuer(str(sp["nation"]), 20.0))
	zeile.add_child(Stil.matt("%d Jahre · %s · %s" % [
		int(sp["alter"]), Namen.KULTUR_NAME.get(str(sp["nation"]), str(sp["nation"])),
		str(Welt.verein(str(sp["verein"])).get("name", "vereinslos"))]))
	zeile.add_child(Bausteine.status_zeichen(sid))

	var rechts := Stil.vbox(2)
	rechts.custom_minimum_size = Vector2(230, 0)
	h.add_child(rechts)
	rechts.add_child(Stil.info_zeile("Gesamtstärke", Scouting.gesamt_text(Welt.daten, sid), Stil.wert_farbe(Spielerfabrik.gesamt(sp), 100.0)))
	rechts.add_child(Stil.info_zeile("Perspektive", Scouting.potenzial_text(Welt.daten, sid), Stil.LILA))
	rechts.add_child(Stil.info_zeile("Marktwert", Stil.geld(float(sp["wert"]))))
	rechts.add_child(Stil.info_zeile("Kenntnis", Scouting.kenntnis_text(float(sp["kenntnis"])), Stil.TEXT_MATT))
	kopfbereich.add_child(Stil.trenner())

func _uebersicht(sp: Dictionary) -> void:
	var spalten := Stil.hbox(14)
	inhalt.add_child(spalten)

	var links := Stil.vbox(10)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spalten.add_child(links)
	var zustand := Bausteine.karte_in(links, "Zustand")
	zustand.add_child(Bausteine.wertzeile("Form", float(sp["form"]), 100.0, "Aktuelle Tagesform."))
	zustand.add_child(Bausteine.wertzeile("Fitness", float(sp["fitness"]), 100.0, "Körperliche Frische."))
	zustand.add_child(Bausteine.wertzeile("Moral", float(sp["moral"]), 100.0, "Zufriedenheit mit der eigenen Lage."))
	zustand.add_child(Bausteine.wertzeile("Lastkonto", float(sp["last"]), 100.0,
		"Angesammelte Belastung. Hohe Werte senken Leistung und erhöhen das Verletzungsrisiko."))
	zustand.add_child(Bausteine.wertzeile("Einsatzform", Spielerfabrik.einsatzform(sp), 100.0,
		"Gesamteinschätzung aus Fitness, Form und Lastkonto."))
	if not (sp["verletzung"] as Dictionary).is_empty():
		zustand.add_child(Stil.text("Verletzt: " + Medizin.verletzungstext(sp), Stil.S_KLEIN, Stil.ROT))

	var typ := Bausteine.karte_in(links, "Persönlichkeit")
	typ.add_child(Stil.text(str(sp["persoenlichkeit"]), Stil.S_NORMAL, Stil.AKZENT))
	var ch: Dictionary = sp["charakter"]
	for k in [["ehrgeiz", "Ehrgeiz"], ["loyalitaet", "Loyalität"], ["temperament", "Temperament"], ["profitum", "Professionalität"]]:
		typ.add_child(Bausteine.wertzeile(str(k[1]), float(ch.get(str(k[0]), 10.0)) * 5.0, 100.0))
	typ.add_child(Stil.info_zeile("Einfluss in der Kabine", "%d" % int(Kabine.einfluss(Welt.daten, sid))))

	var rechts := Stil.vbox(10)
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spalten.add_child(rechts)

	var saison := Bausteine.karte_in(rechts, "Diese Saison")
	var st: Dictionary = sp["stats"]["saison"]
	saison.add_child(Stil.info_zeile("Spiele", str(int(st["spiele"]))))
	saison.add_child(Stil.info_zeile("Minuten", "%d" % int(st["minuten"])))
	if bool(sp["ist_torwart"]):
		saison.add_child(Stil.info_zeile("Paraden", str(int(st["paraden"]))))
	else:
		saison.add_child(Stil.info_zeile("Tore", str(int(st["tore"]))))
		saison.add_child(Stil.info_zeile("Würfe", str(int(st["wuerfe"]))))
		var quote: float = float(st["tore"]) / maxf(float(st["wuerfe"]), 1.0) * 100.0
		saison.add_child(Stil.info_zeile("Wurfquote", "%.0f %%" % quote, Stil.prozent_farbe(quote)))
		saison.add_child(Stil.info_zeile("Vorlagen", str(int(st["assists"]))))
	saison.add_child(Stil.info_zeile("Zeitstrafen", str(int(st["zeitstrafen"]))))
	var note: float = Spielerfabrik.note(sp)
	saison.add_child(Stil.info_zeile("Durchschnittsnote", Stil.komma(note, 2) if note > 0.0 else "—",
		Stil.wert_farbe(6.0 - note, 5.0) if note > 0.0 else Stil.TEXT_MATT))

	if str(sp["verein"]) == Welt.mein_verein_id:
		_gespraechskarte(rechts, sp)
		var fokus := Bausteine.karte_in(rechts, "Individuelle Förderung")
		fokus.add_child(Stil.matt("Ein Sonderprogramm beschleunigt die Entwicklung in einem Bereich.", Stil.S_MINI))
		var wahl := OptionButton.new()
		var i := 0
		for k2 in Training.INDIVIDUALFOKUS.keys():
			wahl.add_item(str(Training.INDIVIDUALFOKUS[k2]))
			wahl.set_item_metadata(i, k2)
			if str(sp.get("trainingsfokus", "")) == str(k2):
				wahl.select(i)
			i += 1
		wahl.item_selected.connect(func(idx):
			Welt.spieler(sid)["trainingsfokus"] = str(wahl.get_item_metadata(idx))
			_melde("Förderprogramm gesetzt."))
		fokus.add_child(wahl)
		_nummernkarte(rechts, sp)

## Rückennummer ändern. Doppelte Nummern lehnt der Zeugwart ab.
func _nummernkarte(eltern: VBoxContainer, sp: Dictionary) -> void:
	var karte := Bausteine.karte_in(eltern, "Rückennummer")
	karte.add_child(Stil.matt("Die Nummer gehört dem Spieler, solange er im Verein ist.", Stil.S_MINI))
	var zeile := Stil.hbox(8)
	karte.add_child(zeile)
	var feld := SpinBox.new()
	feld.min_value = 1
	feld.max_value = Trikot.HOECHSTE
	feld.step = 1
	feld.value = maxi(int(sp.get("nummer", 0)), 1)
	feld.custom_minimum_size = Vector2(90, 0)
	zeile.add_child(feld)
	var setzen := Stil.knopf("Übernehmen")
	setzen.pressed.connect(func():
		var erg := Trikot.setzen(Welt.daten, Welt.mein_verein_id, sid, int(feld.value))
		_melde(str(erg["grund"]), bool(erg["ok"]))
		if bool(erg["ok"]):
			Welt.zustand_geaendert.emit()
			_zeichne())
	zeile.add_child(setzen)

func _attribute(sp: Dictionary) -> void:
	# Profil zuerst: das Netz sagt in einem Blick mehr als 29 Einzelwerte.
	var oben := Stil.hbox(12)
	inhalt.add_child(oben)
	var profil := Bausteine.karte_in(oben, "Profil")
	Stil.karte_wurzel(profil).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vergleichspieler: Dictionary = {}
	if vergleich_sid != "" and Welt.daten["spieler"].has(vergleich_sid):
		vergleichspieler = Welt.spieler(vergleich_sid)
	var netz := Radar.fuer(sp, vergleichspieler, 300.0)
	netz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profil.add_child(netz)
	var legende := Stil.hbox(10)
	profil.add_child(legende)
	legende.add_child(Stil.abzeichen(Spielerfabrik.kurz_name(sp), Stil.AKZENT))
	if not vergleichspieler.is_empty():
		legende.add_child(Stil.abzeichen(Spielerfabrik.kurz_name(vergleichspieler), Stil.BLAU))
	legende.add_child(Stil.dehner())
	_vergleichswahl(profil, sp)

	var kennzahlen := Bausteine.karte_in(oben, "Eignung nach Position")
	Stil.karte_wurzel(kennzahlen).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pos in Spielerfabrik.POSITIONEN:
		if bool(sp["ist_torwart"]) != (pos == "TW"):
			continue
		var eignung: float = Spielerfabrik.eignung(sp, pos)
		var wert: float = Spielerfabrik.angriff_auf(sp, pos) if pos != "TW" else Spielerfabrik.gesamt(sp)
		var zeile := Stil.hbox(8)
		kennzahlen.add_child(zeile)
		zeile.add_child(Bausteine.positions_abzeichen(pos))
		var l := Stil.matt(str(Spielerfabrik.POSITION_NAME[pos]))
		l.custom_minimum_size = Vector2(150, 0)
		zeile.add_child(l)
		zeile.add_child(Stil.balken(wert, 100.0, 110))
		var w := Stil.text("%d" % int(wert), Stil.S_KLEIN, Stil.wert_farbe(wert, 100.0))
		w.custom_minimum_size = Vector2(32, 0)
		zeile.add_child(w)
		if pos != "TW" and eignung < 0.85:
			zeile.add_child(Stil.matt("%d %% Eignung" % int(eignung * 100.0), Stil.S_MINI))
	kennzahlen.add_child(Stil.trenner())
	_staerken_schwaechen(kennzahlen, sp)

	var gruppen: Array = []
	if bool(sp["ist_torwart"]):
		gruppen = [["Torwartspiel", Spielerfabrik.ATTR_TORWART], ["Athletik", Spielerfabrik.ATTR_ATHLETIK],
			["Mental", Spielerfabrik.ATTR_MENTAL]]
	else:
		gruppen = [["Technik", Spielerfabrik.ATTR_TECHNIK], ["Athletik", Spielerfabrik.ATTR_ATHLETIK],
			["Abwehr", Spielerfabrik.ATTR_DEFENSIV], ["Mental", Spielerfabrik.ATTR_MENTAL]]
	var reihe := Stil.hbox(12)
	inhalt.add_child(reihe)
	for g in gruppen:
		var karte := Stil.karte(str(g[0]))
		karte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reihe.add_child(Stil.karte_wurzel(karte))
		for a in (g[1] as Array):
			var z := Stil.hbox(6)
			var l := Stil.matt(str(Spielerfabrik.ATTR_LABEL.get(a, a)), Stil.S_KLEIN)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			z.add_child(l)
			var wert: float = float(sp["attr"].get(a, 1.0))
			z.add_child(Stil.balken(wert, 20.0, 64))
			var t := Stil.text(Scouting.attributtext(Welt.daten, sid, str(a)), Stil.S_KLEIN, Stil.wert_farbe(wert))
			t.custom_minimum_size = Vector2(44, 0)
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			z.add_child(t)
			karte.add_child(z)
	if float(sp["kenntnis"]) < 97.0:
		inhalt.add_child(Stil.matt("Die Werte sind Schätzungen. Ein Scoutauftrag verengt die Spannen.", Stil.S_KLEIN))

	var eignung := Bausteine.karte_in(inhalt, "Positionseignung")
	var raster := Stil.hbox(10)
	eignung.add_child(raster)
	for pos in Spielerfabrik.POSITIONEN:
		if bool(sp["ist_torwart"]) != (pos == "TW"):
			continue
		var sp_box := Stil.vbox(3)
		sp_box.add_child(Bausteine.positions_abzeichen(pos))
		var e: float = Spielerfabrik.eignung(sp, pos)
		sp_box.add_child(Stil.balken(e * 100.0, 100.0, 62))
		raster.add_child(sp_box)

func _statistik(sp: Dictionary) -> void:
	var karriere := Bausteine.karte_in(inhalt, "Karriere insgesamt")
	var k: Dictionary = sp["stats"]["karriere"]
	var raster := Stil.hbox(24)
	karriere.add_child(raster)
	var links := Stil.vbox(3)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raster.add_child(links)
	links.add_child(Stil.info_zeile("Pflichtspiele", str(int(k["spiele"]))))
	links.add_child(Stil.info_zeile("Tore", str(int(k["tore"]))))
	links.add_child(Stil.info_zeile("Vorlagen", str(int(k["assists"]))))
	links.add_child(Stil.info_zeile("Paraden", str(int(k["paraden"]))))
	var rechts := Stil.vbox(3)
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raster.add_child(rechts)
	rechts.add_child(Stil.info_zeile("Zeitstrafen", str(int(k["zeitstrafen"]))))
	rechts.add_child(Stil.info_zeile("Rote Karten", str(int(k["rote"]))))
	rechts.add_child(Stil.info_zeile("Spieler des Spiels", str(int(k["spieler_des_spiels"]))))
	rechts.add_child(Stil.info_zeile("Team der Saison", str(int(k.get("allstar", 0))),
		Stil.AKZENT if int(k.get("allstar", 0)) > 0 else Stil.TEXT))
	rechts.add_child(Stil.info_zeile("Blocks", str(int(k["blocks"]))))

	var verlauf: Array = sp["stats"]["verlauf"]
	if verlauf.is_empty():
		inhalt.add_child(Stil.matt("Noch keine abgeschlossene Saison."))
		return
	var tabelle := Bausteine.karte_in(inhalt, "Saison für Saison")
	var g := Stil.tabelle(["Saison", "Verein", "Sp", "Tore", "Vorl.", "Paraden", "Note"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabelle.add_child(g)
	for e in verlauf:
		g.add_child(Stil.text(str(e.get("saisontext", "")), Stil.S_KLEIN))
		g.add_child(Stil.matt(str(Welt.verein(str(e.get("verein", ""))).get("kurz", "—")), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(e.get("spiele", 0))), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(e.get("tore", 0))), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(e.get("assists", 0))), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(e.get("paraden", 0))), Stil.S_KLEIN))
		g.add_child(Stil.text(Stil.komma(float(e.get("note", 0.0)), 2), Stil.S_KLEIN))

func _vertrag(sp: Dictionary) -> void:
	var vertrag: Dictionary = sp["vertrag"]
	var karte := Bausteine.karte_in(inhalt, "Aktueller Vertrag")
	if vertrag.is_empty():
		karte.add_child(Stil.text("Vereinslos — ablösefrei verpflichtbar.", Stil.S_NORMAL, Stil.GRUEN))
	else:
		karte.add_child(Stil.info_zeile("Wochengehalt", Stil.geld(float(vertrag.get("gehalt", 0.0)))))
		var rest: int = int(vertrag.get("bis_saison", 0)) - Welt.saison_index()
		karte.add_child(Stil.info_zeile("Laufzeit", "bis Saison %s (noch %d Jahr(e))" % [
			Kalender.saison_text(Welt.startjahr(), int(vertrag.get("bis_saison", 0))), maxi(rest, 0)],
			Stil.ROT if rest <= 0 else Stil.TEXT))
		karte.add_child(Stil.info_zeile("Rolle", str(Transfermarkt.ROLLEN_NAME.get(str(vertrag.get("rolle", "rotation")), "—"))))
		var pt: float = float(vertrag.get("praemie_tor", 0.0))
		var ps: float = float(vertrag.get("praemie_sieg", 0.0))
		if pt > 0.0 or ps > 0.0:
			karte.add_child(Stil.info_zeile("Erfolgsprämien", "%s je Tor · %s je Sieg" % [
				Stil.geld(pt), Stil.geld(ps)], Stil.GELB))
			karte.add_child(Stil.info_zeile("Davon in dieser Saison",
				Stil.geld(float((sp["stats"]["saison"] as Dictionary).get("praemien", 0.0)))))
		else:
			karte.add_child(Stil.info_zeile("Erfolgsprämien", "keine"))
		var klausel: float = float(vertrag.get("ablöseklausel", 0.0))
		if klausel > 0.0 and klausel <= 1.0:
			karte.add_child(Stil.info_zeile("Ablöseklausel", "ablösefrei (Ausstiegsklausel)", Stil.ROT))
		elif klausel > 0.0:
			karte.add_child(Stil.info_zeile("Ablöseklausel", Stil.geld(klausel), Stil.ROT))
			karte.add_child(Stil.matt("Jeder Verein, der diese Summe zahlt, kann ihn verpflichten — ohne Verhandlung.", Stil.S_MINI))
		else:
			karte.add_child(Stil.info_zeile("Ablöseklausel", "keine"))
		karte.add_child(Stil.info_zeile("Zusatzklauseln", Klauseln.beschreibung(Klauseln.lesen(sp)),
			Stil.AKZENT if Klauseln.beschreibung(Klauseln.lesen(sp)) != "keine Zusatzklauseln" else Stil.TEXT_MATT))
		var beteiligt: Array = Klauseln.beteiligte(sp)
		for b in beteiligt:
			karte.add_child(Stil.info_zeile("Beteiligt am Weiterverkauf",
				"%s (%d %%)" % [str(Welt.verein(str(b["verein"])).get("name", "?")), int(float(b["anteil"]) * 100.0)],
				Stil.GELB))
		karte.add_child(Stil.info_zeile("Unzufriedenheit", "%d" % int(sp["unzufriedenheit"]),
			Stil.ROT if float(sp["unzufriedenheit"]) > 55.0 else Stil.TEXT))

	if str(sp["verein"]) == Welt.mein_verein_id:
		var neu := Bausteine.karte_in(inhalt, "Vertrag verlängern")
		var wunsch: float = Spielerfabrik.gehaltsvorstellung(sp, float(Welt.mein_verein().get("ruf", 50.0)))
		neu.add_child(Stil.matt("Gehaltsvorstellung des Spielers: etwa %s pro Woche." % Stil.geld(wunsch), Stil.S_KLEIN))
		var zeile := Stil.hbox(8)
		neu.add_child(zeile)
		zeile.add_child(Stil.matt("Gehalt"))
		var gehalt := SpinBox.new()
		gehalt.min_value = 100
		gehalt.max_value = 200000
		gehalt.step = 50
		gehalt.value = round(wunsch)
		gehalt.custom_minimum_size = Vector2(130, 0)
		zeile.add_child(gehalt)
		zeile.add_child(Stil.matt("Jahre"))
		var jahre := SpinBox.new()
		jahre.min_value = 1
		jahre.max_value = 6
		jahre.value = 3
		zeile.add_child(jahre)
		zeile.add_child(Stil.matt("Rolle"))
		var rolle := OptionButton.new()
		for i in range(Transfermarkt.ROLLEN.size()):
			rolle.add_item(str(Transfermarkt.ROLLEN_NAME[Transfermarkt.ROLLEN[i]]))
			rolle.set_item_metadata(i, Transfermarkt.ROLLEN[i])
			if str(sp["vertrag"].get("rolle", "")) == str(Transfermarkt.ROLLEN[i]):
				rolle.select(i)
		zeile.add_child(rolle)
		var praemien := _praemienzeile(neu, sp,
			float(sp["vertrag"].get("praemie_tor", 0.0)), float(sp["vertrag"].get("praemie_sieg", 0.0)))
		var klauselfeld := _klauselzeile(neu, sp, float(sp["vertrag"].get("ablöseklausel", 0.0)))
		var zusatz := _zusatzklauseln(neu, sp)
		var verhandeln := Stil.knopf_primaer("An den Verhandlungstisch")
		verhandeln.tooltip_text = "Führt die Verlängerung als Gespräch über mehrere Runden."
		verhandeln.pressed.connect(func():
			schliessen()
			Verhandlungsfenster.oeffnen(self, sid, "verlaengerung"))
		neu.add_child(verhandeln)
		var anbieten := Stil.knopf("Direktangebot")
		anbieten.pressed.connect(func():
			var werte := {
				"weiterverkauf": (zusatz["weiterverkauf"] as SpinBox).value / 100.0,
				"abstiegsklausel": (zusatz["abstieg"] as Button).button_pressed,
				"einsatzpraemie": (zusatz["einsatz"] as SpinBox).value,
				"treuepraemie": (zusatz["treue"] as SpinBox).value,
			}
			var erg := Transfermarkt.vertrag_verlaengern(Welt.daten, sid, gehalt.value, int(jahre.value),
				str(rolle.get_item_metadata(rolle.selected)),
				(praemien["tor"] as SpinBox).value, (praemien["sieg"] as SpinBox).value,
				klauselfeld.value, werte)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			_zeichne())
		neu.add_child(anbieten)

		var markt := Bausteine.karte_in(inhalt, "Vermarktung")
		var mzeile := Stil.hbox(8)
		markt.add_child(mzeile)
		var liste := Stil.knopf("Auf die Transferliste setzen" if not bool(sp.get("auf_transferliste", false)) else "Von der Transferliste nehmen")
		liste.pressed.connect(func():
			Transfermarkt.auf_transferliste(Welt.daten, sid, not bool(Welt.spieler(sid).get("auf_transferliste", false)))
			_zeichne())
		mzeile.add_child(liste)
		var aufloesen := Stil.knopf("Vertrag auflösen")
		aufloesen.pressed.connect(func():
			var erg := Transfermarkt.vertrag_aufloesen(Welt.daten, sid)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			if bool(erg["ok"]):
				schliessen()
			else:
				_zeichne())
		mzeile.add_child(aufloesen)
	elif Welt.mein_verein_id != "":
		_angebotsbereich(sp)

func _angebotsbereich(sp: Dictionary) -> void:
	var karte := Bausteine.karte_in(inhalt, "Verpflichten")
	var frei: bool = str(sp["verein"]) == ""
	var forderung: float = Transfermarkt.ablösevorstellung(Welt.daten, sid)
	var gehaltswunsch: float = Spielerfabrik.gehaltsvorstellung(sp, float(Welt.mein_verein().get("ruf", 50.0)))
	karte.add_child(Stil.matt("Geschätzte Ablöseforderung: %s · Gehaltsvorstellung: %s pro Woche" % [
		"ablösefrei" if frei else Stil.geld(forderung), Stil.geld(gehaltswunsch)], Stil.S_KLEIN))
	if not Transfermarkt.fenster_offen(Welt.daten):
		karte.add_child(Stil.text("Das Transferfenster ist derzeit geschlossen.", Stil.S_KLEIN, Stil.ROT))
		return
	var zeile := Stil.hbox(8)
	karte.add_child(zeile)
	zeile.add_child(Stil.matt("Ablöse"))
	var abloese := SpinBox.new()
	abloese.min_value = 0
	abloese.max_value = 90000000
	abloese.step = 5000
	abloese.value = round(forderung)
	abloese.custom_minimum_size = Vector2(150, 0)
	abloese.editable = not frei
	zeile.add_child(abloese)
	zeile.add_child(Stil.matt("Gehalt"))
	var gehalt := SpinBox.new()
	gehalt.min_value = 100
	gehalt.max_value = 200000
	gehalt.step = 50
	gehalt.value = round(gehaltswunsch * 1.05)
	gehalt.custom_minimum_size = Vector2(130, 0)
	zeile.add_child(gehalt)
	zeile.add_child(Stil.matt("Jahre"))
	var jahre := SpinBox.new()
	jahre.min_value = 1
	jahre.max_value = 5
	jahre.value = 3
	zeile.add_child(jahre)
	zeile.add_child(Stil.matt("Rolle"))
	var rolle := OptionButton.new()
	for i in range(Transfermarkt.ROLLEN.size()):
		rolle.add_item(str(Transfermarkt.ROLLEN_NAME[Transfermarkt.ROLLEN[i]]))
		rolle.set_item_metadata(i, Transfermarkt.ROLLEN[i])
	rolle.select(1)
	zeile.add_child(rolle)
	var praemien := _praemienzeile(karte, sp, 0.0, 0.0)
	var knopfzeile := Stil.hbox(8)
	karte.add_child(knopfzeile)
	var senden := Stil.knopf_primaer("Angebot abgeben")
	senden.pressed.connect(func():
		var erg := Transfermarkt.angebot_abgeben(Welt.daten, sid, abloese.value, gehalt.value,
			int(jahre.value), str(rolle.get_item_metadata(rolle.selected)), "kauf",
			(praemien["tor"] as SpinBox).value, (praemien["sieg"] as SpinBox).value)
		_melde(str(erg["grund"]), bool(erg["ok"])))
	knopfzeile.add_child(senden)
	if not frei:
		var leihe := Stil.knopf("Ausleihen")
		leihe.pressed.connect(func():
			var erg := Transfermarkt.angebot_abgeben(Welt.daten, sid, 0.0, gehalt.value,
				1, str(rolle.get_item_metadata(rolle.selected)), "leihe")
			_melde(str(erg["grund"]), bool(erg["ok"])))
		knopfzeile.add_child(leihe)
	var beobachten := Stil.knopf("Scout beauftragen")
	beobachten.pressed.connect(func():
		var scouts := Scouting.scouts(Welt.daten, Welt.mein_verein_id)
		if scouts.is_empty():
			_melde("Sie haben keinen Scout unter Vertrag.", false)
			return
		var erg := Scouting.auftrag_erteilen(Welt.daten, str(scouts[0]), "spieler", sid)
		_melde(str(erg["grund"]), bool(erg["ok"])))
	knopfzeile.add_child(beobachten)

func _entwicklung(sp: Dictionary) -> void:
	_laufbahn(sp)
	var karte := Bausteine.karte_in(inhalt, "Entwicklung")
	karte.add_child(Stil.info_zeile("Aktuelle Stärke", "%d" % int(Spielerfabrik.gesamt(sp))))
	karte.add_child(Stil.info_zeile("Einschätzung", Scouting.potenzial_text(Welt.daten, sid), Stil.LILA))
	karte.add_child(Stil.info_zeile("Förderprogramm", str(Training.INDIVIDUALFOKUS.get(str(sp.get("trainingsfokus", "")), "—"))))
	karte.add_child(Stil.info_zeile("Arbeitseinsatz", "%d" % int(float(sp["attr"]["arbeitseinsatz"])),
		Stil.wert_farbe(float(sp["attr"]["arbeitseinsatz"]))))
	karte.add_child(Stil.info_zeile("Verletzungsanfälligkeit", "%d" % int(float(sp["verletzungsneigung"])),
		Stil.wert_farbe(20.0 - float(sp["verletzungsneigung"]))))
	if bool(sp.get("aus_eigener_jugend", false)):
		karte.add_child(Stil.text("Aus der eigenen Jugend.", Stil.S_KLEIN, Stil.GRUEN))
	var kurve: Array = sp.get("staerke_verlauf", [])
	if kurve.size() >= 3:
		var chart := Bausteine.karte_in(inhalt, "Stärkeverlauf")
		var tief := 999.0
		var hoch := 0.0
		for w in kurve:
			tief = minf(tief, float(w))
			hoch = maxf(hoch, float(w))
		var linie := Stil.linie(kurve, 520, 96, Stil.LILA)
		linie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chart.add_child(linie)
		var achse := Stil.hbox(8)
		chart.add_child(achse)
		achse.add_child(Stil.matt("vor %d Monaten" % kurve.size(), Stil.S_MINI))
		achse.add_child(Stil.dehner())
		achse.add_child(Stil.matt("Spanne %s bis %s" % [Stil.komma(tief, 1), Stil.komma(hoch, 1)], Stil.S_MINI))
		achse.add_child(Stil.dehner())
		achse.add_child(Stil.matt("heute", Stil.S_MINI))
		var delta: float = float(kurve[kurve.size() - 1]) - float(kurve[0])
		chart.add_child(Stil.info_zeile("Veränderung im gezeigten Zeitraum",
			"%s%s Punkte" % ["+" if delta >= 0.0 else "", Stil.komma(delta, 1)],
			Stil.GRUEN if delta > 0.5 else (Stil.ROT if delta < -0.5 else Stil.TEXT_MATT)))

	var verlaufsliste: Array = sp.get("entwicklung_log", [])
	if verlaufsliste.is_empty():
		karte.add_child(Stil.matt("Noch keine auffälligen Entwicklungssprünge festgehalten."))
		return
	var verlauf := Bausteine.karte_in(inhalt, "Entwicklungssprünge")
	for e in verlaufsliste.slice(0, 12):
		verlauf.add_child(Stil.info_zeile(Kalender.text(int(e["tag"]), Welt.startjahr()),
			"+%s auf %d" % [Stil.komma(float(e["delta"]), 2), int(float(e["gesamt"]))], Stil.GRUEN))

## Die Laufbahn: was in diesem Sportlerleben passiert ist.
func _laufbahn(sp: Dictionary) -> void:
	var eintraege: Array = Laufbahn.liste(sp)
	var karte := Bausteine.karte_in(inhalt, "Laufbahn")
	if eintraege.is_empty():
		karte.add_child(Stil.leerzustand("Noch nichts eingetragen — die Laufbahn füllt sich mit Debüt, Wechseln, Titeln und Meilensteinen."))
		return
	var letzte_saison := -999
	for e in eintraege:
		var saison: int = int(e.get("saison", 0))
		if saison != letzte_saison:
			letzte_saison = saison
			var kopf := Stil.hbox(8)
			karte.add_child(kopf)
			kopf.add_child(Stil.abzeichen(Kalender.saison_text(Welt.startjahr(), saison), Stil.TEXT_SCHWACH))
			var linie := Stil.trenner()
			linie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			linie.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			kopf.add_child(linie)
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		var datum := Stil.matt(Kalender.kurz(int(e["tag"]), Welt.startjahr()), Stil.S_MINI)
		datum.custom_minimum_size = Vector2(52, 0)
		zeile.add_child(datum)
		var punkt := Stil.text("●", Stil.S_MINI, Laufbahn.farbe(str(e.get("art", ""))))
		zeile.add_child(punkt)
		var text := Stil.text(str(e["text"]), Stil.S_KLEIN, Laufbahn.farbe(str(e.get("art", ""))))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(text)

## Zwei Eingabefelder für Erfolgsprämien samt Wirkungshinweis.
## Liefert {"tor": SpinBox, "sieg": SpinBox}.
func _praemienzeile(eltern: Node, sp: Dictionary, start_tor: float, start_sieg: float) -> Dictionary:
	var zeile := Stil.hbox(8)
	eltern.add_child(zeile)
	zeile.add_child(Stil.matt("Prämie je Tor"))
	var tor := SpinBox.new()
	tor.min_value = 0
	tor.max_value = Praemien.TOR_MAX
	tor.step = 50
	tor.value = start_tor
	tor.custom_minimum_size = Vector2(110, 0)
	tor.editable = not bool(sp.get("ist_torwart", false))
	zeile.add_child(tor)
	zeile.add_child(Stil.matt("je Sieg"))
	var sieg := SpinBox.new()
	sieg.min_value = 0
	sieg.max_value = Praemien.SIEG_MAX
	sieg.step = 100
	sieg.value = start_sieg
	sieg.custom_minimum_size = Vector2(110, 0)
	zeile.add_child(sieg)
	var hinweis := Stil.matt("", Stil.S_MINI)
	eltern.add_child(hinweis)
	var auffrischen := func():
		hinweis.text = Praemien.beschreibung(Welt.daten, sp, tor.value, sieg.value, Welt.mein_verein_id)
	auffrischen.call()
	tor.value_changed.connect(func(_w): auffrischen.call())
	sieg.value_changed.connect(func(_w): auffrischen.call())
	return {"tor": tor, "sieg": sieg}

## Einzelgespräch: Thema wählen, Antwort wählen, Folgen tragen.
func _gespraechskarte(eltern: Node, sp: Dictionary) -> void:
	var karte := Bausteine.karte_in(eltern, "Einzelgespräch")
	var wert: float = Gespraech.beziehung(sp)
	karte.add_child(Stil.info_zeile("Verhältnis zu Ihnen",
		"%d — %s" % [int(wert), Gespraech.beziehung_text(wert)], Stil.prozent_farbe(wert)))
	for e in Gespraech.offene(Welt.daten, sid):
		var rest: int = int(e["faellig"]) - Welt.tag()
		karte.add_child(Stil.banner("%s — Prüfung in %d Tag(en)" % [
			Gespraech.versprechen_text(e), maxi(rest, 0)], "warnung"))
	var sperre: int = Gespraech.sperre_rest(Welt.daten, sp)
	if sperre > 0:
		karte.add_child(Stil.matt("Zuletzt vor Kurzem gesprochen — %d Tag(e) Ruhe." % sperre, Stil.S_MINI))
		return

	var themen := Gespraech.themen(Welt.daten, sid)
	if gespraech_thema == "" or not themen.has(gespraech_thema):
		gespraech_thema = str(themen[0])
	var optionen: Array = []
	for t in themen:
		optionen.append({"id": str(t), "name": str((Gespraech.THEMEN[t] as Dictionary)["name"])})
	karte.add_child(Stil.segmente(optionen, gespraech_thema, func(id):
		gespraech_thema = str(id)
		_zeichne()))
	karte.add_child(Stil.text(str((Gespraech.THEMEN[gespraech_thema] as Dictionary)["frage"])
		% Spielerfabrik.kurz_name(sp), Stil.S_KLEIN, Stil.AKZENT))
	for a in Gespraech.ANTWORTEN[gespraech_thema]:
		var eintrag: Dictionary = a
		var k := Stil.knopf(str(eintrag["text"]))
		k.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if eintrag.has("versprechen"):
			k.tooltip_text = "Das ist ein Versprechen. Es wird in einigen Wochen geprüft."
		k.pressed.connect(func():
			var erg := Gespraech.fuehren(Welt.daten, sid, gespraech_thema, str(eintrag["id"]))
			_melde(str(erg["text"]), bool(erg.get("gelungen", false)))
			Klang.spiele("klick", 0.5)
			_zeichne())
		karte.add_child(k)

## Die Reiterleiste als segmentierte Umschaltleiste — sie muss bei jedem
## Wechsel neu gebaut werden, damit der aktive Reiter markiert ist.
func _reiter_aufbauen() -> void:
	if reiterleiste == null:
		return
	if reiterleiste.get_child_count() > 0 and reiterleiste.get_child(0).has_meta("segmente"):
		reiterleiste.get_child(0).queue_free()
		reiterleiste.remove_child(reiterleiste.get_child(0))
	var optionen: Array = []
	for r in REITER:
		optionen.append({"id": str(r[0]), "name": str(r[1])})
	var leiste := Stil.segmente(optionen, reiter, func(id):
		reiter = str(id)
		_reiter_aufbauen()
		_zeichne())
	leiste.set_meta("segmente", true)
	reiterleiste.add_child(leiste)
	reiterleiste.move_child(leiste, 0)

## Auswahl eines zweiten Spielers, der im Netzdiagramm daruebergelegt wird.
func _vergleichswahl(eltern: Node, sp: Dictionary) -> void:
	if Welt.mein_verein_id == "":
		return
	var zeile := Stil.hbox(8)
	eltern.add_child(zeile)
	zeile.add_child(Stil.matt("Vergleichen mit"))
	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(200, 0)
	wahl.add_item("— niemandem —")
	wahl.set_item_metadata(0, "")
	var i := 1
	for kandidat in Welt.verein(Welt.mein_verein_id)["kader"]:
		if str(kandidat) == sid:
			continue
		var k: Dictionary = Welt.spieler(str(kandidat))
		# Nur sinnvolle Paare: Torhueter gegen Torhueter, Feldspieler gegen Feldspieler
		if bool(k["ist_torwart"]) != bool(sp["ist_torwart"]):
			continue
		wahl.add_item("%s (%s)" % [Spielerfabrik.voller_name(k), str(k["position"])])
		wahl.set_item_metadata(i, str(kandidat))
		if str(kandidat) == vergleich_sid:
			wahl.select(i)
		i += 1
	wahl.item_selected.connect(func(index):
		vergleich_sid = str(wahl.get_item_metadata(index))
		_zeichne())
	zeile.add_child(wahl)

## Die drei stärksten und die drei schwächsten Attribute — das, worüber in
## einer Kaderbesprechung tatsächlich geredet wird.
func _staerken_schwaechen(eltern: Node, sp: Dictionary) -> void:
	var attr: Dictionary = sp["attr"]
	# Nur Attribute, die für diese Rolle überhaupt zählen — sonst stünde bei
	# jedem Torwart "Schwäche: Zweikampf", was nichts über ihn aussagt.
	var relevant: Array = []
	if bool(sp["ist_torwart"]):
		relevant.append_array(Spielerfabrik.ATTR_TORWART)
	else:
		relevant.append_array(Spielerfabrik.ATTR_TECHNIK)
		relevant.append_array(Spielerfabrik.ATTR_DEFENSIV)
	relevant.append_array(Spielerfabrik.ATTR_ATHLETIK)
	relevant.append_array(Spielerfabrik.ATTR_MENTAL)
	var liste: Array = []
	for schluessel in relevant:
		if attr.has(schluessel):
			liste.append({"id": str(schluessel), "wert": float(attr[schluessel])})
	liste.sort_custom(func(a, b): return float(a["wert"]) > float(b["wert"]))
	eltern.add_child(Stil.etikett("Stärken"))
	for e in liste.slice(0, 3):
		eltern.add_child(Stil.info_zeile(
			str(Spielerfabrik.ATTR_LABEL.get(str(e["id"]), str(e["id"]))),
			"%d" % int(float(e["wert"])), Stil.wert_farbe(float(e["wert"]))))
	eltern.add_child(Stil.etikett("Schwächen"))
	for e2 in liste.slice(maxi(liste.size() - 3, 0)):
		eltern.add_child(Stil.info_zeile(
			str(Spielerfabrik.ATTR_LABEL.get(str(e2["id"]), str(e2["id"]))),
			"%d" % int(float(e2["wert"])), Stil.wert_farbe(float(e2["wert"]))))

## Eingabefeld für die Ablöseklausel samt Wirkungshinweis.
func _klauselzeile(eltern: Node, sp: Dictionary, start: float) -> SpinBox:
	var untergrenze: float = Transfermarkt.klausel_untergrenze(sp)
	var zeile := Stil.hbox(8)
	eltern.add_child(zeile)
	zeile.add_child(Stil.matt("Ablöseklausel"))
	var feld := SpinBox.new()
	feld.min_value = 0
	feld.max_value = 90000000
	feld.step = 25000
	feld.value = start
	feld.custom_minimum_size = Vector2(170, 0)
	zeile.add_child(feld)
	var aus := Stil.knopf_geist("Keine")
	aus.pressed.connect(func(): feld.value = 0)
	zeile.add_child(aus)
	var hinweis := Stil.matt("", Stil.S_MINI)
	eltern.add_child(hinweis)
	var auffrischen := func():
		if feld.value <= 0.0:
			hinweis.text = "Ohne Klausel bestimmen Sie allein, ob und für wie viel er geht."
			return
		var wirksam: float = maxf(feld.value, untergrenze)
		var rabatt: float = Transfermarkt.klausel_rabatt(Welt.daten, sp, wirksam)
		hinweis.text = "Mindestens %s. Senkt die Gehaltsforderung um rund %d %%, gibt aber jedem Verein das Recht, ihn für diese Summe zu holen." % [
			Stil.geld(untergrenze), int(rabatt * 100.0)]
	auffrischen.call()
	feld.value_changed.connect(func(_w): auffrischen.call())
	return feld

## Vier Zusatzklauseln samt Wirkungshinweis. Liefert die Eingabefelder.
func _zusatzklauseln(eltern: Node, sp: Dictionary) -> Dictionary:
	var werte := Klauseln.lesen(sp)
	var karte := Stil.vbox(4)
	eltern.add_child(karte)
	karte.add_child(Stil.matt("Zusatzklauseln — der Spieler rechnet sie gegen sein Festgehalt auf.", Stil.S_MINI))
	var zeile := Stil.hbox(8)
	karte.add_child(zeile)
	zeile.add_child(Stil.matt("Weiterverkauf %"))
	var verkauf := SpinBox.new()
	verkauf.min_value = 0
	verkauf.max_value = int(Klauseln.WEITERVERKAUF_MAX * 100.0)
	verkauf.step = 5
	verkauf.value = float(werte["weiterverkauf"]) * 100.0
	verkauf.custom_minimum_size = Vector2(90, 0)
	verkauf.tooltip_text = "Anteil, den Ihr Verein beim nächsten Weiterverkauf dieses Spielers erhält."
	zeile.add_child(verkauf)
	zeile.add_child(Stil.matt("je Einsatz"))
	var einsatz := SpinBox.new()
	einsatz.min_value = 0
	einsatz.max_value = Klauseln.EINSATZ_MAX
	einsatz.step = 50
	einsatz.value = float(werte["einsatzpraemie"])
	einsatz.custom_minimum_size = Vector2(110, 0)
	einsatz.tooltip_text = "Wird nach jedem Pflichtspiel mit mindestens 20 Minuten ausgezahlt."
	zeile.add_child(einsatz)
	var zeile2 := Stil.hbox(8)
	karte.add_child(zeile2)
	zeile2.add_child(Stil.matt("Treueprämie je Saison"))
	var treue := SpinBox.new()
	treue.min_value = 0
	treue.max_value = 250000
	treue.step = 5000
	treue.value = float(werte["treuepraemie"])
	treue.custom_minimum_size = Vector2(130, 0)
	treue.tooltip_text = "Einmalzahlung am Saisonende, solange der Vertrag weiterläuft."
	zeile2.add_child(treue)
	var abstieg := Stil.schalter("")
	abstieg.text = "Ablösefrei bei Abstieg"
	abstieg.button_pressed = bool(werte["abstiegsklausel"])
	abstieg.tooltip_text = "Steigt der Verein ab, darf er ohne Ablöse gehen."
	zeile2.add_child(abstieg)
	var hinweis := Stil.matt("", Stil.S_MINI)
	karte.add_child(hinweis)
	var rechnen := func():
		var aktuell := {
			"weiterverkauf": verkauf.value / 100.0,
			"abstiegsklausel": abstieg.button_pressed,
			"einsatzpraemie": einsatz.value,
			"treuepraemie": treue.value,
		}
		var rabatt: float = Klauseln.gehaltsersatz(Welt.daten, sp, aktuell)
		if rabatt <= 0.001:
			hinweis.text = "Keine Zugeständnisse — der Spieler verlangt das volle Gehalt."
		else:
			hinweis.text = "Er rechnet das mit %d %% seines Gehaltswunsches auf." % int(rabatt * 100.0)
	verkauf.value_changed.connect(func(_w): rechnen.call())
	einsatz.value_changed.connect(func(_w): rechnen.call())
	treue.value_changed.connect(func(_w): rechnen.call())
	abstieg.toggled.connect(func(_an): rechnen.call())
	rechnen.call()
	return {"weiterverkauf": verkauf, "einsatz": einsatz, "treue": treue, "abstieg": abstieg}
