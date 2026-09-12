class_name TrainingBildschirm
extends Bildschirm
## Trainingswoche und Belastungssteuerung.
##
## Der Kern ist der Zielkonflikt: harte Einheiten entwickeln schneller, füllen aber
## das Lastkonto. Das Regenerationsbudget nimmt Last heraus — kostet aber in dieser
## Woche fast die gesamte Entwicklung des betreffenden Spielers.

var plan_bereich: VBoxContainer
var last_bereich: VBoxContainer
var lager_bereich: VBoxContainer
var umschulung_bereich: VBoxContainer
var meldung: Label
var entwicklung_bereich: VBoxContainer
var budget_anzeige: Label

func aufbauen() -> void:
	var wurzel := Stil.vbox(10)
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wurzel)
	var kopf := Stil.hbox(10)
	wurzel.add_child(kopf)
	kopf.add_child(Stil.titel("Training & Belastung", 0))
	kopf.add_child(Stil.dehner())
	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	kopf.add_child(meldung)
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
	lager_bereich = Bausteine.karte_in(inhalt, "Trainingslager")
	umschulung_bereich = Bausteine.karte_in(inhalt, "Umschulungen")
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
	_lager()
	_umschulungen()
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
	var g := Stil.tabelle(["Spieler", "Alter", "Stärke", "Perspektive", "Entwicklung", "Förderung"])
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
		g.add_child(Stil.matt(Scouting.tempo_text(Welt.daten, sid), Stil.S_KLEIN))
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
		var haken := Stil.schalter("")
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

func _melde(text: String, gut: bool = true) -> void:
	if meldung != null:
		meldung.text = text
		meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)

## Trainingslager: nur in den Pausen buchbar, wirkt über mehrere Tage.
func _lager() -> void:
	leeren(lager_bereich)
	var cid: String = Welt.mein_verein_id
	var laufend := Trainingslager.laufend(Welt.daten, cid)
	if not laufend.is_empty():
		var o: Dictionary = Trainingslager.ORTE[str(laufend["ort"])]
		lager_bereich.add_child(Stil.text("Die Mannschaft ist im Lager: %s" % str(o["name"]),
			Stil.S_NORMAL, Stil.AKZENT))
		lager_bereich.add_child(Stil.matt(str(o["text"]), Stil.S_MINI))
		var zeile := Stil.hbox(10)
		lager_bereich.add_child(zeile)
		zeile.add_child(Stil.matt("Tag %d von %d" % [int(laufend["tage_gelaufen"]) + 1,
			int(laufend["tage_gesamt"])], Stil.S_KLEIN))
		zeile.add_child(Stil.balken(float(laufend["tage_gelaufen"]), float(laufend["tage_gesamt"]), 160))
		var ab := Stil.knopf_flach("Abbrechen", Stil.ROT)
		ab.pressed.connect(func():
			Trainingslager.abbrechen(Welt.daten, cid)
			_melde("Das Lager wurde abgebrochen.", false)
			aktualisieren())
		zeile.add_child(ab)
		return
	if not Trainingslager.fenster_offen(Welt.daten):
		lager_bereich.add_child(Stil.leerzustand("Ein Lager ist nur in der Sommervorbereitung oder in der Winterpause möglich."))
		return
	lager_bereich.add_child(Stil.matt("%s — jetzt ist Platz für ein Lager. Es kostet Geld und Erholung und bringt dafür etwas, das im Wochenrhythmus nicht zu haben ist." % Trainingslager.fenstername(Welt.daten), Stil.S_MINI))
	for schluessel in Trainingslager.ORTE.keys():
		if str(schluessel) == "heim":
			continue
		var ort: Dictionary = Trainingslager.ORTE[schluessel]
		var z := Stil.hbox(10)
		lager_bereich.add_child(z)
		var spalte := Stil.vbox(1)
		spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		z.add_child(spalte)
		spalte.add_child(Stil.text("%s · %d Tage" % [str(ort["name"]), int(ort["tage"])], Stil.S_KLEIN))
		spalte.add_child(Stil.matt(str(ort["text"]), Stil.S_MINI))
		var preis: float = Trainingslager.kosten(Welt.daten, cid, str(schluessel))
		z.add_child(Stil.text(Stil.geld(preis), Stil.S_KLEIN,
			Stil.GRUEN if float(Welt.mein_verein()["kasse"]) >= preis else Stil.ROT))
		var knopf := Stil.knopf_primaer("Buchen")
		var id := str(schluessel)
		knopf.pressed.connect(func():
			var erg := Trainingslager.buchen(Welt.daten, cid, id)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			Welt.zustand_geaendert.emit()
			aktualisieren())
		z.add_child(knopf)

## Positionsumschulungen: laufende und mögliche.
func _umschulungen() -> void:
	leeren(umschulung_bereich)
	var cid: String = Welt.mein_verein_id
	umschulung_bereich.add_child(Stil.matt("Eine Umschulung dauert Monate. Danach zählt die neue Position als Zweitposition — der Spieler verliert dort deutlich weniger Stärke.", Stil.S_MINI))
	var laufende := 0
	for sid in Welt.verein(cid)["kader"]:
		var sp: Dictionary = Welt.spieler(sid)
		var u := Trainingslager.umschulung(sp)
		if u.is_empty():
			continue
		laufende += 1
		var z := Stil.hbox(10)
		umschulung_bereich.add_child(z)
		z.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		var knopf := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		knopf.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		z.add_child(knopf)
		z.add_child(Stil.matt("→", Stil.S_KLEIN))
		z.add_child(Bausteine.positions_abzeichen(str(u["position"])))
		z.add_child(Stil.balken(float(u["fortschritt"]), Trainingslager.UMSCHULUNG_ZIEL, 140))
		z.add_child(Stil.matt("noch etwa %d Wochen" % Trainingslager.restwochen(Welt.daten, sp), Stil.S_MINI))
		var ab := Stil.knopf_flach("Abbrechen", Stil.ROT)
		ab.pressed.connect(func():
			Trainingslager.umschulung_abbrechen(Welt.daten, sid)
			_melde("Umschulung abgebrochen.", false)
			aktualisieren())
		z.add_child(ab)
	if laufende == 0:
		umschulung_bereich.add_child(Stil.matt("Derzeit wird niemand umgeschult."))
	umschulung_bereich.add_child(Stil.trenner())
	var neu := Stil.hbox(8)
	umschulung_bereich.add_child(neu)
	neu.add_child(Stil.matt("Neu beginnen", Stil.S_KLEIN))
	var swahl := OptionButton.new()
	swahl.custom_minimum_size = Vector2(230, 0)
	var kandidaten: Array = []
	for sid2 in Welt.verein(cid)["kader"]:
		var sp2: Dictionary = Welt.spieler(sid2)
		if int(sp2["alter"]) > 29 or not Trainingslager.umschulung(sp2).is_empty():
			continue
		kandidaten.append(sid2)
	for i in range(kandidaten.size()):
		var sp3: Dictionary = Welt.spieler(str(kandidaten[i]))
		swahl.add_item("%s (%s, %d)" % [Spielerfabrik.voller_name(sp3), str(sp3["position"]), int(sp3["alter"])])
		swahl.set_item_metadata(i, str(kandidaten[i]))
	if kandidaten.is_empty():
		neu.add_child(Stil.matt("Kein Spieler unter 30 ohne laufende Umschulung.", Stil.S_MINI))
		return
	neu.add_child(swahl)
	var pwahl := OptionButton.new()
	pwahl.custom_minimum_size = Vector2(170, 0)
	for j in range(Spielerfabrik.POSITIONEN.size()):
		var p2: String = str(Spielerfabrik.POSITIONEN[j])
		pwahl.add_item(str(Spielerfabrik.POSITION_NAME[p2]))
		pwahl.set_item_metadata(j, p2)
	neu.add_child(pwahl)
	var los := Stil.knopf_primaer("Umschulung beginnen")
	los.pressed.connect(func():
		var erg := Trainingslager.umschulung_starten(Welt.daten,
			str(swahl.get_item_metadata(maxi(swahl.selected, 0))),
			str(pwahl.get_item_metadata(maxi(pwahl.selected, 0))))
		_melde(str(erg["grund"]), bool(erg["ok"]))
		aktualisieren())
	neu.add_child(los)
