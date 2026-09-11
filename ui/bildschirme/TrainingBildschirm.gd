class_name TrainingBildschirm
extends Bildschirm
## Trainingswoche und Belastungssteuerung.
##
## Der Kern ist der Zielkonflikt: harte Einheiten entwickeln schneller, füllen aber
## das Lastkonto. Das Regenerationsbudget nimmt Last heraus — kostet aber in dieser
## Woche fast die gesamte Entwicklung des betreffenden Spielers.

var plan_bereich: VBoxContainer
var last_bereich: VBoxContainer
var entwicklung_bereich: VBoxContainer
var budget_anzeige: Label

func aufbauen() -> void:
	var wurzel := Stil.vbox(10)
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wurzel)
	wurzel.add_child(Stil.titel("Training & Belastung", 0))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wurzel.add_child(scroll)
	var inhalt := Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)
	var oben := Stil.hbox(12)
	inhalt.add_child(oben)
	plan_bereich = Bausteine.karte_in(oben, "Wochenplan")
	Stil.karte_wurzel(plan_bereich).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entwicklung_bereich = Bausteine.karte_in(oben, "Entwicklung im Kader")
	Stil.karte_wurzel(entwicklung_bereich).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	last_bereich = Bausteine.karte_in(inhalt, "Lastkonto & Regenerationsbudget")

func aktualisieren() -> void:
	if plan_bereich == null:
		return
	leeren(plan_bereich)
	leeren(last_bereich)
	leeren(entwicklung_bereich)
	if Welt.mein_verein_id == "":
		plan_bereich.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	_plan()
	_entwicklung()
	_lastkonto()

func _plan() -> void:
	var cid := Welt.mein_verein_id
	var p: Dictionary = Training.plan(Welt.daten, cid)
	var intensitaet := Stil.hbox(8)
	plan_bereich.add_child(intensitaet)
	var l := Stil.matt("Intensität", Stil.S_KLEIN)
	l.custom_minimum_size = Vector2(120, 0)
	intensitaet.add_child(l)
	var s := HSlider.new()
	s.min_value = 20
	s.max_value = 95
	s.value = int(p["intensitaet"])
	s.custom_minimum_size = Vector2(200, 0)
	intensitaet.add_child(s)
	var wert := Stil.text(str(int(p["intensitaet"])), Stil.S_KLEIN, Stil.AKZENT)
	wert.custom_minimum_size = Vector2(34, 0)
	intensitaet.add_child(wert)
	var folge := Stil.matt("", Stil.S_MINI)
	plan_bereich.add_child(folge)
	var beschreibe := func(w: int) -> String:
		if w < 38:
			return "Schonprogramm: kaum Entwicklung, dafür sinkt die Last deutlich."
		elif w < 58:
			return "Ausgewogen: solide Fortschritte bei überschaubarem Risiko."
		elif w < 78:
			return "Fordernd: gute Entwicklung, das Lastkonto steigt spürbar."
		return "Am Limit: schnelle Entwicklung, deutlich erhöhte Verletzungsgefahr."
	folge.text = beschreibe.call(int(p["intensitaet"]))
	s.value_changed.connect(func(w):
		p["intensitaet"] = int(w)
		wert.text = str(int(w))
		folge.text = beschreibe.call(int(w)))

	var schwerpunkt := Stil.hbox(8)
	plan_bereich.add_child(schwerpunkt)
	var l2 := Stil.matt("Schwerpunkt", Stil.S_KLEIN)
	l2.custom_minimum_size = Vector2(120, 0)
	schwerpunkt.add_child(l2)
	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(210, 0)
	var i := 0
	for k in Training.SCHWERPUNKTE.keys():
		wahl.add_item(str(Training.SCHWERPUNKTE[k]["name"]))
		wahl.set_item_metadata(i, k)
		if str(p["schwerpunkt"]) == str(k):
			wahl.select(i)
		i += 1
	wahl.item_selected.connect(func(idx): p["schwerpunkt"] = str(wahl.get_item_metadata(idx)))
	schwerpunkt.add_child(wahl)

	plan_bereich.add_child(Stil.trenner())
	var qualitaet := Training.trainerqualitaet(Welt.daten, cid)
	plan_bereich.add_child(Bausteine.wertzeile("Trainingsqualität", qualitaet, 100.0,
		"Ergibt sich aus Trainerstab, Trainingszentrum und Ihrem eigenen Ruf."))
	var v: Dictionary = Welt.verein(cid)
	plan_bereich.add_child(Stil.info_zeile("Trainingszentrum", "Stufe %d" % int(v["infrastruktur"]["trainingszentrum"])))
	plan_bereich.add_child(Stil.info_zeile("Regenerationsbereich", "Stufe %d" % int(v["infrastruktur"]["regeneration"])))
	if Trainerkarriere.hat_praegung(Welt.daten, "talentfluesterer"):
		plan_bereich.add_child(Stil.abzeichen("PRÄGUNG: TALENTFLÜSTERER", Stil.LILA))
	if Trainerkarriere.hat_praegung(Welt.daten, "rotationsprinzip"):
		plan_bereich.add_child(Stil.abzeichen("PRÄGUNG: ROTATIONSPRINZIP", Stil.LILA))

func _entwicklung() -> void:
	var cid := Welt.mein_verein_id
	var kader: Array = (Welt.verein(cid)["kader"] as Array).duplicate()
	kader.sort_custom(func(a, b):
		var sa: Dictionary = Welt.spieler(a)
		var sb: Dictionary = Welt.spieler(b)
		return (float(sa["potenzial"]) - Spielerfabrik.gesamt(sa)) > (float(sb["potenzial"]) - Spielerfabrik.gesamt(sb)))
	entwicklung_bereich.add_child(Stil.matt("Spieler mit dem größten verbleibenden Entwicklungsraum.", Stil.S_MINI))
	var g := Stil.tabelle(["Spieler", "Alter", "Stärke", "Perspektive", "Förderung"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entwicklung_bereich.add_child(g)
	for sid in kader.slice(0, 9):
		var sp: Dictionary = Welt.spieler(sid)
		var k := Stil.knopf_flach(Spielerfabrik.kurz_name(sp))
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(k)
		g.add_child(Stil.text(str(int(sp["alter"])), Stil.S_KLEIN))
		g.add_child(Stil.text("%d" % int(Spielerfabrik.gesamt(sp)), Stil.S_KLEIN, Stil.wert_farbe(Spielerfabrik.gesamt(sp), 100.0)))
		g.add_child(Stil.text(Scouting.potenzial_text(Welt.daten, sid), Stil.S_KLEIN, Stil.LILA))
		g.add_child(Stil.matt(str(Training.INDIVIDUALFOKUS.get(str(sp.get("trainingsfokus", "")), "—")), Stil.S_KLEIN))

func _lastkonto() -> void:
	var cid := Welt.mein_verein_id
	var p: Dictionary = Training.plan(Welt.daten, cid)
	var budget: int = Training.regenerationsbudget(Welt.daten, cid)
	var vergeben: int = Training.vergebene_regeneration(Welt.daten, cid)
	var kopf := Stil.hbox(10)
	last_bereich.add_child(kopf)
	budget_anzeige = Stil.text("Regenerationsbudget: %d von %d vergeben" % [vergeben, budget], Stil.S_NORMAL,
		Stil.ROT if vergeben > budget else Stil.GRUEN)
	kopf.add_child(budget_anzeige)
	kopf.add_child(Stil.dehner())
	var auto := Stil.knopf("Automatisch verteilen")
	auto.pressed.connect(func():
		var kader: Array = (Welt.verein(cid)["kader"] as Array).duplicate()
		kader.sort_custom(func(a, b): return float(Welt.spieler(a)["last"]) > float(Welt.spieler(b)["last"]))
		var zuteilung := {}
		for i in range(mini(budget, kader.size())):
			if float(Welt.spieler(kader[i])["last"]) > 40.0:
				zuteilung[kader[i]] = 1
		p["regeneration_zuteilung"] = zuteilung
		aktualisieren())
	kopf.add_child(auto)
	var leer := Stil.knopf("Alle zurücksetzen")
	leer.pressed.connect(func():
		p["regeneration_zuteilung"] = {}
		aktualisieren())
	kopf.add_child(leer)
	last_bereich.add_child(Stil.matt("Ein Regenerationsplatz senkt das Lastkonto deutlich schneller — der Spieler entwickelt sich in dieser Woche aber kaum.", Stil.S_MINI))

	var g := Stil.tabelle(["Spieler", "Pos", "Lastkonto", "Fitness", "Minuten/Spiel", "Verletzungsrisiko", "Regeneration"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	last_bereich.add_child(g)
	var kader2: Array = (Welt.verein(cid)["kader"] as Array).duplicate()
	kader2.sort_custom(func(a, b): return float(Welt.spieler(a)["last"]) > float(Welt.spieler(b)["last"]))
	var zuteilung2: Dictionary = p.get("regeneration_zuteilung", {})
	for sid in kader2:
		var sp: Dictionary = Welt.spieler(sid)
		var k := Stil.knopf_flach(Spielerfabrik.kurz_name(sp))
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(k)
		g.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		var lastbalken := Stil.balken(float(sp["last"]), 100.0, 90, Stil.prozent_farbe(100.0 - float(sp["last"])))
		g.add_child(lastbalken)
		g.add_child(Stil.balken(float(sp["fitness"]), 100.0, 90))
		var spiele: int = maxi(int(sp["stats"]["saison"]["spiele"]), 1)
		g.add_child(Stil.text("%d" % int(float(sp["stats"]["saison"]["minuten"]) / float(spiele)), Stil.S_KLEIN))
		var risiko: float = Medizin.risiko(Welt.daten, sid) * 10000.0
		g.add_child(Stil.text("%s" % _risikotext(risiko), Stil.S_KLEIN, Stil.wert_farbe(10.0 - clampf(risiko, 0.0, 10.0), 10.0)))
		var haken := CheckBox.new()
		haken.button_pressed = int(zuteilung2.get(sid, 0)) > 0
		haken.toggled.connect(func(an):
			if an:
				zuteilung2[sid] = 1
			else:
				zuteilung2.erase(sid)
			p["regeneration_zuteilung"] = zuteilung2
			var neu: int = Training.vergebene_regeneration(Welt.daten, cid)
			budget_anzeige.text = "Regenerationsbudget: %d von %d vergeben" % [neu, budget]
			budget_anzeige.add_theme_color_override("font_color", Stil.ROT if neu > budget else Stil.GRUEN))
		g.add_child(haken)

func _risikotext(wert: float) -> String:
	if wert < 2.0:
		return "gering"
	elif wert < 4.0:
		return "erhöht"
	elif wert < 7.0:
		return "hoch"
	return "sehr hoch"
