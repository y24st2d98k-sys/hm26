class_name Spielerfenster
extends Control
## Detailfenster eines Spielers. Es liegt dauerhaft im Baum (Gruppe "spielerfenster")
## und wird nur ein- und ausgeblendet — dadurch gibt es keine zu spaet erzeugten Knoten.
## Der Inhaltsbereich wird bei jedem Oeffnen geleert und neu aufgebaut; dauerhafte
## Elemente (Rahmen, Reiterleiste) liegen ausserhalb dieses Bereichs.

var sid: String = ""
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
	panel.custom_minimum_size = Vector2(880, 620)
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
	for r in REITER:
		var k := Stil.knopf(str(r[1]))
		var id: String = str(r[0])
		k.pressed.connect(func():
			reiter = id
			_zeichne())
		reiterleiste.add_child(k)
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
	meldung.text = ""
	visible = true
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
	if str(sp["verein"]) != "":
		h.add_child(Wappen.fuer_verein(str(sp["verein"]), 46.0))
	var links := Stil.vbox(2)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(links)
	links.add_child(Stil.titel(Spielerfabrik.voller_name(sp), 1))
	var zeile := Stil.hbox(8)
	links.add_child(zeile)
	zeile.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
	for zp in sp["zweitpositionen"]:
		zeile.add_child(Stil.abzeichen(str(zp), Stil.TEXT_SCHWACH))
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
		var aktionen := Bausteine.karte_in(rechts, "Einzelgespräch")
		aktionen.add_child(Stil.matt("Die Wirkung hängt von Charakter und Situation ab.", Stil.S_MINI))
		var reihe := Stil.hbox(6)
		aktionen.add_child(reihe)
		for g in [["lob", "Loben"], ["kritik", "Kritisieren"], ["vertrauen", "Vertrauen zusichern"], ["druck", "Druck machen"]]:
			var k := Stil.knopf(str(g[1]))
			var ton: String = str(g[0])
			k.pressed.connect(func():
				var erg := Kabine.gespraech(Welt.daten, sid, ton)
				_melde(str(erg["text"]), bool(erg["gelungen"]))
				_zeichne())
			reihe.add_child(k)
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

func _attribute(sp: Dictionary) -> void:
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
		var anbieten := Stil.knopf_primaer("Angebot machen")
		anbieten.pressed.connect(func():
			var erg := Transfermarkt.vertrag_verlaengern(Welt.daten, sid, gehalt.value, int(jahre.value),
				str(rolle.get_item_metadata(rolle.selected)),
				(praemien["tor"] as SpinBox).value, (praemien["sieg"] as SpinBox).value)
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
	var verlaufsliste: Array = sp.get("entwicklung_log", [])
	if verlaufsliste.is_empty():
		karte.add_child(Stil.matt("Noch keine auffälligen Entwicklungssprünge festgehalten."))
		return
	var verlauf := Bausteine.karte_in(inhalt, "Entwicklungssprünge")
	for e in verlaufsliste.slice(0, 12):
		verlauf.add_child(Stil.info_zeile(Kalender.text(int(e["tag"]), Welt.startjahr()),
			"+%s auf %d" % [Stil.komma(float(e["delta"]), 2), int(float(e["gesamt"]))], Stil.GRUEN))

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
