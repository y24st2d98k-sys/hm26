class_name TaktikBildschirm
extends Bildschirm
## Aufstellung und Taktik. Hallenherz trennt Angriffs- und Abwehrformation:
## Sie stellen zwei Siebener auf, und die "Wechselintensität" bestimmt, wie
## konsequent zwischen beiden rotiert wird — mit echtem Kraftaufwand als Preis.

var angriff_bereich: VBoxContainer
var abwehr_bereich: VBoxContainer
var taktik_bereich: VBoxContainer
var bank_bereich: VBoxContainer
var feld: Spielfeld
var warnungen_bereich: VBoxContainer
var anweisungs_bereich: VBoxContainer
var profil_bereich: VBoxContainer
var minuten_bereich: VBoxContainer
var vorschau_angriff: bool = true
var meldung: Label

func aufbauen() -> void:
	var wurzel := Stil.vbox(10)
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wurzel)

	var kopf := Stil.hbox(10)
	wurzel.add_child(kopf)
	kopf.add_child(Stil.titel("Aufstellung & Taktik", 0))
	kopf.add_child(Stil.dehner())
	var auto_haken := Stil.schalter("")
	auto_haken.text = "Aufstellung vor jedem Spiel automatisch optimieren"
	auto_haken.tooltip_text = "Der Trainerstab stellt vor jeder Partie die beste verfügbare Sieben auf — nach Form, Fitness und Lastkonto. Ausschalten, wenn Sie selbst aufstellen wollen."
	auto_haken.button_pressed = bool(Welt.einstellung("auto_aufstellung", true))
	auto_haken.toggled.connect(func(an):
		Welt.setze_einstellung("auto_aufstellung", an)
		_melde("Automatische Aufstellung %s." % ("eingeschaltet" if an else "ausgeschaltet"))
		aktualisieren())
	kopf.add_child(auto_haken)
	var auto := Stil.knopf("Beste Aufstellung vorschlagen")
	auto.pressed.connect(func():
		Weltgenerator.setze_standardaufstellung(Welt.daten, Welt.mein_verein_id)
		_melde("Aufstellung automatisch gesetzt.")
		aktualisieren())
	kopf.add_child(auto)
	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	kopf.add_child(meldung)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wurzel.add_child(scroll)
	var inhalt := Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)

	warnungen_bereich = Stil.vbox(4)
	inhalt.add_child(warnungen_bereich)

	var oben := Stil.hbox(12)
	inhalt.add_child(oben)

	var links := Stil.vbox(12)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(links)
	angriff_bereich = Bausteine.karte_in(links, "Angriffsformation")
	abwehr_bereich = Bausteine.karte_in(links, "Abwehrformation")

	var rechts := Stil.vbox(12)
	rechts.custom_minimum_size = Vector2(560, 0)
	oben.add_child(rechts)
	var feldkarte := Bausteine.karte_in(rechts, "Vorschau")
	var umschalter := Stil.hbox(8)
	feldkarte.add_child(umschalter)
	var knopf_angriff := Stil.knopf("Angriff")
	knopf_angriff.pressed.connect(func():
		vorschau_angriff = true
		_feld_auffrischen())
	umschalter.add_child(knopf_angriff)
	var knopf_abwehr := Stil.knopf("Abwehr")
	knopf_abwehr.pressed.connect(func():
		vorschau_angriff = false
		_feld_auffrischen())
	umschalter.add_child(knopf_abwehr)
	feld = Spielfeld.new()
	feld.custom_minimum_size = Vector2(520, 262)
	feldkarte.add_child(feld)
	taktik_bereich = Bausteine.karte_in(rechts, "Spielidee")

	profil_bereich = Bausteine.karte_in(inhalt, "Spielideen")
	anweisungs_bereich = Bausteine.karte_in(inhalt, "Spieleranweisungen")
	minuten_bereich = Bausteine.karte_in(inhalt, "Einsatzzeiten")
	bank_bereich = Bausteine.karte_in(inhalt, "Restlicher Kader")

func _melde(text: String, gut: bool = true) -> void:
	if meldung != null:
		meldung.text = text
		meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)

func aktualisieren() -> void:
	if angriff_bereich == null:
		return
	leeren(angriff_bereich)
	leeren(abwehr_bereich)
	leeren(taktik_bereich)
	leeren(bank_bereich)
	leeren(anweisungs_bereich)
	leeren(profil_bereich)
	leeren(minuten_bereich)
	leeren(warnungen_bereich)
	if Welt.mein_verein_id == "":
		bank_bereich.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	_warnungen()
	_angriff()
	_abwehr()
	_taktik()
	_profile()
	_anweisungen()
	_einsatzzeiten()
	_bank()
	_feld_auffrischen()

func _feld_auffrischen() -> void:
	if feld == null or Welt.mein_verein_id == "":
		return
	feld.angreifer = "heim" if vorschau_angriff else "gast"
	var eigene := Spielfeld.szene_aus_aufstellung(Welt.mein_verein_id, vorschau_angriff)
	var v: Dictionary = Welt.verein(Welt.mein_verein_id)
	feld.heim_farbe = v["wappen"]["a"]
	feld.setze_szene({"heim": eigene, "gast": {}})
	feld.ball = Vector2(26.0, 10.0) if vorschau_angriff else Vector2(14.0, 10.0)

func _verfuegbar(_ausser: Array) -> Array:
	var liste: Array = []
	for sid in Welt.verein(Welt.mein_verein_id)["kader"]:
		var sp: Dictionary = Welt.spieler(sid)
		if not (sp["verletzung"] as Dictionary).is_empty() or int(sp["sperre"]) > 0:
			continue
		liste.append(sid)
	return liste

func _positionswahl(block: String, pos: String, nur_torwart: bool) -> HBoxContainer:
	var v: Dictionary = Welt.verein(Welt.mein_verein_id)
	var auf: Dictionary = v["aufstellung"]
	var aktuell: String = str((auf[block] as Dictionary).get(pos, ""))
	var h := Stil.hbox(8)
	var label := Bausteine.positions_abzeichen(pos if block == "angriff" else pos.replace("A", "Abw "))
	label.custom_minimum_size = Vector2(58, 0)
	h.add_child(label)

	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(220, 0)
	wahl.add_item("— frei —")
	wahl.set_item_metadata(0, "")
	var index := 1
	var kandidaten := _verfuegbar([])
	kandidaten.sort_custom(func(a, b):
		var sa: Dictionary = Welt.spieler(a)
		var sb: Dictionary = Welt.spieler(b)
		if block == "angriff" and pos != "TW":
			return Spielerfabrik.angriff_auf(sa, pos) > Spielerfabrik.angriff_auf(sb, pos)
		return Spielerfabrik.abwehrwert(sa) > Spielerfabrik.abwehrwert(sb))
	for sid in kandidaten:
		var sp: Dictionary = Welt.spieler(sid)
		if bool(sp["ist_torwart"]) != nur_torwart:
			continue
		var wert: float = Spielerfabrik.angriff_auf(sp, pos) if (block == "angriff" and pos != "TW") else (
			Spielerfabrik.gesamt(sp) if nur_torwart else Spielerfabrik.abwehrwert(sp))
		wahl.add_item("%s  %s  (%d)" % [Trikot.text(sp), Spielerfabrik.voller_name(sp), int(wert)])
		wahl.set_item_metadata(index, sid)
		if sid == aktuell:
			wahl.select(index)
		index += 1
	# Steht auf der Position jemand, der gerade nicht spielen kann, taucht er
	# oben nicht in der Kandidatenliste auf. Ohne diesen Eintrag stuende dort
	# "frei", obwohl die Aufstellung ihn weiterhin fuehrt.
	if aktuell != "" and wahl.selected <= 0 and not Welt.spieler(aktuell).is_empty():
		var gesperrt: Dictionary = Welt.spieler(aktuell)
		var grund := "gesperrt" if int(gesperrt["sperre"]) > 0 else "verletzt"
		wahl.add_item("%s  %s  (%s)" % [Trikot.text(gesperrt), Spielerfabrik.voller_name(gesperrt), grund])
		wahl.set_item_metadata(index, aktuell)
		wahl.select(index)
		index += 1
	wahl.item_selected.connect(func(i):
		var gewaehlt: String = str(wahl.get_item_metadata(i))
		_setze(block, pos, gewaehlt))
	h.add_child(wahl)

	if aktuell != "" and not Welt.spieler(aktuell).is_empty():
		var sp2: Dictionary = Welt.spieler(aktuell)
		h.add_child(Stil.balken(Spielerfabrik.einsatzform(sp2), 100.0, 70))
		var e := Stil.matt("Last %d" % int(float(sp2["last"])), Stil.S_MINI)
		e.custom_minimum_size = Vector2(58, 0)
		h.add_child(e)
		if block == "angriff" and pos != "TW":
			var eignung: float = Spielerfabrik.eignung(sp2, pos)
			if eignung < 0.8:
				var warnung := Stil.abzeichen("FREMDE POSITION", Stil.GELB)
				warnung.tooltip_text = "Eignung %d %% — der Spieler verliert auf dieser Position deutlich." % int(eignung * 100.0)
				h.add_child(warnung)
		var info := Stil.knopf_flach("Profil", Stil.BLAU)
		info.pressed.connect(func(): Spielerfenster.oeffnen(self, aktuell))
		h.add_child(info)
	return h

func _setze(block: String, pos: String, sid: String) -> void:
	var auf: Dictionary = Welt.verein(Welt.mein_verein_id)["aufstellung"]
	var b: Dictionary = auf[block]
	# Doppelbelegung im selben Block aufloesen
	if sid != "":
		for p in b.keys():
			if str(b[p]) == sid and p != pos:
				b[p] = ""
	b[pos] = sid
	auf["bank"] = Weltgenerator.bank_aus_kader(Welt.daten, Welt.mein_verein_id, auf)
	aktualisieren()

func _angriff() -> void:
	angriff_bereich.add_child(Stil.matt("Wer steht im Angriff auf dem Feld? Die Zahl zeigt die Stärke auf genau dieser Position.", Stil.S_MINI))
	for pos in ["TW", "LA", "RL", "RM", "RR", "RA", "KM"]:
		angriff_bereich.add_child(_positionswahl("angriff", pos, pos == "TW"))
	var staerke := _formationsstaerke("angriff")
	angriff_bereich.add_child(Stil.trenner())
	angriff_bereich.add_child(Stil.info_zeile("Angriffsstärke der Sieben", "%d" % int(staerke),
		Stil.wert_farbe(staerke, 100.0)))

func _abwehr() -> void:
	abwehr_bereich.add_child(Stil.matt("Die Abwehrformation darf komplett anders besetzt sein — Abwehrspezialisten lohnen sich.", Stil.S_MINI))
	var auf: Dictionary = Welt.verein(Welt.mein_verein_id)["aufstellung"]
	if not (auf["abwehr"] as Dictionary).has("TW"):
		auf["abwehr"]["TW"] = str((auf["angriff"] as Dictionary).get("TW", ""))
	for pos in ["TW", "A1", "A2", "A3", "A4", "A5", "A6"]:
		if not (auf["abwehr"] as Dictionary).has(pos):
			auf["abwehr"][pos] = ""
		abwehr_bereich.add_child(_positionswahl("abwehr", pos, pos == "TW"))
	var staerke := _formationsstaerke("abwehr")
	abwehr_bereich.add_child(Stil.trenner())
	abwehr_bereich.add_child(Stil.info_zeile("Abwehrstärke der Sieben", "%d" % int(staerke),
		Stil.wert_farbe(staerke, 100.0)))
	var ueberschneidung := _ueberschneidung()
	abwehr_bereich.add_child(Stil.info_zeile("Spieler in beiden Formationen", "%d von 6" % ueberschneidung,
		Stil.GRUEN if ueberschneidung >= 4 else Stil.GELB))
	abwehr_bereich.add_child(Stil.matt("Je weniger Überschneidung, desto mehr Wechsel — das kostet Kraft und birgt Wechselfehler.", Stil.S_MINI))

func _formationsstaerke(block: String) -> float:
	var auf: Dictionary = Welt.verein(Welt.mein_verein_id)["aufstellung"]
	var b: Dictionary = auf.get(block, {})
	var summe := 0.0
	var n := 0
	for pos in b.keys():
		var sid: String = str(b[pos])
		if sid == "" or Welt.spieler(sid).is_empty():
			continue
		var sp: Dictionary = Welt.spieler(sid)
		if pos == "TW":
			continue
		summe += Spielerfabrik.angriff_auf(sp, pos) if block == "angriff" else Spielerfabrik.abwehrwert(sp)
		n += 1
	return summe / maxf(float(n), 1.0)

func _ueberschneidung() -> int:
	var auf: Dictionary = Welt.verein(Welt.mein_verein_id)["aufstellung"]
	var angriff := {}
	for pos in (auf["angriff"] as Dictionary).keys():
		if pos != "TW":
			angriff[str(auf["angriff"][pos])] = true
	var z := 0
	for pos in (auf["abwehr"] as Dictionary).keys():
		if pos == "TW":
			continue
		if angriff.has(str(auf["abwehr"][pos])):
			z += 1
	return z

func _taktik() -> void:
	var v: Dictionary = Welt.verein(Welt.mein_verein_id)
	var t: Dictionary = v["taktik"]

	taktik_bereich.add_child(_auswahl("Abwehrformation", ["6-0", "5-1", "3-2-1", "4-2"],
		str(t["abwehr"]), func(w): t["abwehr"] = w,
		"6-0 blockt Rückraumwürfe, 3-2-1 und 4-2 erzwingen Ballgewinne — kosten aber Kraft und Zeitstrafen."))
	taktik_bereich.add_child(_auswahl("Angriffsausrichtung",
		["positionsangriff", "tempospiel", "kreisfokus", "aussenfokus", "rueckraumfokus"],
		str(t["angriff"]), func(w): t["angriff"] = w,
		"Bestimmt, wer wirft — und wie gut das gegen die gegnerische Deckung funktioniert."))
	taktik_bereich.add_child(_auswahl("Mentalität", ["defensiv", "ausgeglichen", "offensiv", "all-in"],
		str(t["mentalitaet"]), func(w): t["mentalitaet"] = w,
		"Verschiebt Tempo, Risiko und die Gewichtung zwischen Angriff und Abwehr."))
	taktik_bereich.add_child(_auswahl("Siebter Feldspieler", ["nie", "unterzahl", "rueckstand", "schluss", "immer"],
		str(t["siebter_feldspieler"]), func(w): t["siebter_feldspieler"] = w,
		"Torwart raus, ein Feldspieler mehr. Stärkt den Angriff — ein Ballverlust landet aber leicht im leeren Tor."))
	taktik_bereich.add_child(Stil.trenner())
	# Jeder Regler zeigt, was er in Zahlen bewirkt. Die Werte kommen aus
	# denselben Formeln wie die Simulation — siehe kern/Matchsim.gd.
	taktik_bereich.add_child(_schieber("Tempo", int(t["tempo"]), func(w): t["tempo"] = int(w),
		"Hohes Tempo verkürzt jeden Angriff und bringt beiden Mannschaften mehr Ballbesitze. Kostet Kraft.",
		func(w): return "≈ %d Angriffe je Mannschaft" % Matchsim.angriffe_bei_tempo(w, str(t["mentalitaet"]))))
	taktik_bereich.add_child(_schieber("Risiko", int(t["risiko"]), func(w): t["risiko"] = int(w),
		"Mehr Risiko im Aufbau: bessere Abschlüsse, aber mehr technische Fehler.",
		func(w): return "≈ %d %% Ballverluste" % int(round(Matchsim.fehlerquote_bei_risiko(w, str(t["mentalitaet"])) * 100.0))))
	taktik_bereich.add_child(_schieber("Härte in der Abwehr", int(t["haerte"]), func(w): t["haerte"] = int(w),
		"Harte Deckung bremst den Gegner — und produziert Zeitstrafen und Siebenmeter.",
		func(w): return "≈ %.1f %% Zeitstrafen, %.1f %% Siebenmeter" % [
			Matchsim.zeitstrafenquote_bei_haerte(w) * 100.0, Matchsim.siebenmeterquote_bei_haerte(w) * 100.0]))
	taktik_bereich.add_child(_schieber("Wechselintensität", int(t.get("wechselspiel", 55)), func(w): t["wechselspiel"] = int(w),
		"Wie konsequent zwischen Angriffs- und Abwehrformation rotiert wird. Kostet Kraft, erhöht das Risiko von Wechselfehlern.",
		func(w): return "+%d %% Kraftverbrauch" % int(round(Matchsim.kraftaufschlag_bei_wechselspiel(w)))))

	var schuetze := Stil.hbox(8)
	taktik_bereich.add_child(schuetze)
	schuetze.add_child(Stil.matt("Siebenmeter"))
	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(210, 0)
	var auf: Dictionary = v["aufstellung"]
	var i := 0
	for sid in Welt.kader(Welt.mein_verein_id):
		var sp: Dictionary = Welt.spieler(sid)
		if bool(sp["ist_torwart"]):
			continue
		wahl.add_item("%s (%d)" % [Spielerfabrik.voller_name(sp), Spielerfabrik.anzeige(float(sp["attr"]["siebenmeter"]))])
		wahl.set_item_metadata(i, sid)
		if str(auf.get("siebenmeter", "")) == sid:
			wahl.select(i)
		i += 1
	wahl.item_selected.connect(func(idx): auf["siebenmeter"] = str(wahl.get_item_metadata(idx)))
	schuetze.add_child(wahl)

	var haken := Stil.schalter("")
	haken.text = "Auszeiten automatisch nehmen"
	haken.button_pressed = bool(t.get("auszeit_automatik", true))
	haken.toggled.connect(func(an): t["auszeit_automatik"] = an)
	taktik_bereich.add_child(haken)
	var haken2 := Stil.schalter("")
	haken2.text = "Automatische Rotation im Spiel (Kräftehaushalt)"
	haken2.button_pressed = bool(Welt.einstellung("autorotation", true))
	haken2.toggled.connect(func(gesetzt): Welt.setze_einstellung("autorotation", gesetzt))
	taktik_bereich.add_child(haken2)

func _auswahl(beschriftung: String, werte: Array, aktuell: String, rueckruf: Callable, hinweis: String) -> HBoxContainer:
	var h := Stil.hbox(8)
	var l := Stil.matt(beschriftung, Stil.S_KLEIN)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(190, 0)
	for i in range(werte.size()):
		wahl.add_item(str(werte[i]).capitalize())
		wahl.set_item_metadata(i, werte[i])
		if str(werte[i]) == aktuell:
			wahl.select(i)
	wahl.item_selected.connect(func(i): rueckruf.call(str(wahl.get_item_metadata(i))))
	h.add_child(wahl)
	h.tooltip_text = hinweis
	return h

## Ein Regler mit Zahlenwert und, wenn vorhanden, der Wirkung im Klartext.
func _schieber(beschriftung: String, wert: int, rueckruf: Callable, hinweis: String,
		wirkung: Variant = null) -> HBoxContainer:
	var h := Stil.hbox(8)
	var l := Stil.matt(beschriftung, Stil.S_KLEIN)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.value = wert
	s.custom_minimum_size = Vector2(140, 0)
	h.add_child(s)
	var anzeige := Stil.text(str(wert), Stil.S_KLEIN, Stil.AKZENT)
	anzeige.custom_minimum_size = Vector2(30, 0)
	anzeige.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(anzeige)
	var folge := Stil.matt("", Stil.S_MINI)
	folge.custom_minimum_size = Vector2(210, 0)
	folge.clip_text = true
	h.add_child(folge)
	if wirkung != null:
		folge.text = str((wirkung as Callable).call(float(wert)))
	s.value_changed.connect(func(w):
		anzeige.text = str(int(w))
		if wirkung != null:
			folge.text = str((wirkung as Callable).call(w))
		rueckruf.call(w))
	h.tooltip_text = hinweis
	return h

## Gespeicherte Spielideen und die Regeln, wann sie gezogen werden.
func _profile() -> void:
	var cid: String = Welt.mein_verein_id
	var kopf := Stil.hbox(10)
	profil_bereich.add_child(kopf)
	kopf.add_child(Stil.matt("Eine Spielidee hält die komplette Einstellung fest — Deckung, Ausrichtung, Mentalität und alle Regler. Hinterlegen Sie je Lage eine, wird sie vor der Partie automatisch gezogen.", Stil.S_MINI))
	kopf.add_child(Stil.dehner())
	var haken := Stil.schalter("")
	haken.text = "Automatisch nach Lage ziehen"
	haken.button_pressed = bool(Welt.einstellung("auto_taktik", true))
	haken.toggled.connect(func(an):
		Welt.setze_einstellung("auto_taktik", an)
		_melde("Automatische Spielidee %s." % ("eingeschaltet" if an else "ausgeschaltet"))
		aktualisieren())
	kopf.add_child(haken)

	var neu := Stil.hbox(8)
	profil_bereich.add_child(neu)
	neu.add_child(Stil.matt("Aktuelle Einstellung sichern als", Stil.S_KLEIN))
	var feld := LineEdit.new()
	feld.placeholder_text = "z. B. Bollwerk auswärts"
	feld.custom_minimum_size = Vector2(220, 0)
	neu.add_child(feld)
	var sichern := Stil.knopf_primaer("Speichern")
	sichern.pressed.connect(func():
		var erg := Taktikprofile.speichern(Welt.daten, cid, feld.text)
		_melde(str(erg["grund"]), bool(erg["ok"]))
		aktualisieren())
	neu.add_child(sichern)

	var liste: Array = Taktikprofile.profile(Welt.daten, cid)
	if liste.is_empty():
		profil_bereich.add_child(Stil.leerzustand("Noch keine Spielidee gespeichert."))
		return
	for p in liste:
		var name: String = str(p["name"])
		var zeile := Stil.hbox(10)
		profil_bereich.add_child(zeile)
		var spalte := Stil.vbox(1)
		spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(spalte)
		spalte.add_child(Stil.text(name, Stil.S_KLEIN, Stil.AKZENT))
		spalte.add_child(Stil.matt(Taktikprofile.beschreibung(p["taktik"]), Stil.S_MINI))
		var laden := Stil.knopf("Übernehmen")
		laden.pressed.connect(func():
			var erg2 := Taktikprofile.anwenden(Welt.daten, cid, name)
			_melde(str(erg2["grund"]), bool(erg2["ok"]))
			Welt.zustand_geaendert.emit()
			aktualisieren())
		zeile.add_child(laden)
		var weg := Stil.knopf_flach("Löschen", Stil.ROT)
		weg.pressed.connect(func():
			Taktikprofile.loeschen(Welt.daten, cid, name)
			_melde("Profil gelöscht.")
			aktualisieren())
		zeile.add_child(weg)

	profil_bereich.add_child(Stil.trenner())
	profil_bereich.add_child(Stil.text("Welche Idee gegen wen?", Stil.S_KLEIN))
	var regeln: Dictionary = Taktikprofile.regeln(Welt.daten, cid)
	for lage in Taktikprofile.LAGEN_REIHE:
		var info: Dictionary = Taktikprofile.LAGEN[lage]
		var z := Stil.hbox(8)
		profil_bereich.add_child(z)
		var l := Stil.matt(str(info["name"]), Stil.S_KLEIN)
		l.custom_minimum_size = Vector2(210, 0)
		z.add_child(l)
		var wahl := OptionButton.new()
		wahl.custom_minimum_size = Vector2(230, 0)
		wahl.add_item("— keine Regel —")
		wahl.set_item_metadata(0, "")
		var i := 1
		for name2 in Taktikprofile.namen(Welt.daten, cid):
			wahl.add_item(str(name2))
			wahl.set_item_metadata(i, name2)
			if str(regeln.get(lage, "")) == str(name2):
				wahl.select(i)
			i += 1
		var lage_id := str(lage)
		wahl.item_selected.connect(func(idx):
			Taktikprofile.regel_setzen(Welt.daten, cid, lage_id, str(wahl.get_item_metadata(idx)))
			_melde("Regel gesetzt.")
			aktualisieren())
		z.add_child(wahl)
		z.add_child(Stil.matt(str(info["text"]), Stil.S_MINI))
	var naechstes: Dictionary = Welt.naechstes_spiel(cid)
	if not naechstes.is_empty():
		var gegner: String = str(naechstes["gast"]) if str(naechstes["heim"]) == cid else str(naechstes["heim"])
		var lage2 := Taktikprofile.lage_gegen(Welt.daten, cid, gegner)
		profil_bereich.add_child(Stil.info_zeile("Nächster Gegner: %s" % str(Welt.verein(gegner).get("name", "")),
			str(Taktikprofile.LAGEN[lage2]["name"]), Stil.AKZENT))

## Individuelle Rollen fuer die Spieler auf dem Feld. Die Mannschaftstaktik
## oben gibt den Rahmen vor — hier steht, was der Einzelne darin tun soll.
func _anweisungen() -> void:
	var cid: String = Welt.mein_verein_id
	var auf: Dictionary = Welt.verein(cid)["aufstellung"]
	var kopf := Stil.hbox(10)
	anweisungs_bereich.add_child(kopf)
	kopf.add_child(Stil.matt("Wer sucht den Abschluss, wer eröffnet, wer schiebt in der Abwehr vor? Jede Rolle hat einen Preis.", Stil.S_MINI))
	kopf.add_child(Stil.dehner())
	var gesetzt: int = Anweisungen.gesetzt(Welt.daten, cid)
	kopf.add_child(Stil.abzeichen("%d MIT ROLLE" % gesetzt, Stil.AKZENT if gesetzt > 0 else Stil.TEXT_MATT))
	var vorschlag := Stil.knopf("Vorschlag des Trainerstabs")
	vorschlag.tooltip_text = "Setzt für den gesamten Kader die Rolle, die zu Position und Stärken des Spielers passt."
	vorschlag.pressed.connect(func():
		Anweisungen.automatisch(Welt.daten, cid)
		_melde("Der Trainerstab hat die Rollen verteilt.")
		aktualisieren())
	kopf.add_child(vorschlag)
	var zuruecksetzen := Stil.knopf_flach("Zurücksetzen", Stil.TEXT_MATT)
	zuruecksetzen.pressed.connect(func():
		auf["anweisungen"] = {}
		_melde("Alle Rollen zurückgesetzt.")
		aktualisieren())
	kopf.add_child(zuruecksetzen)
	anweisungs_bereich.add_child(Stil.trenner())

	var angriff_auf: Dictionary = auf.get("angriff", {})
	var abwehr_auf: Dictionary = auf.get("abwehr", {})
	var reihenfolge: Array = []
	for pos in ["LA", "RL", "RM", "RR", "RA", "KM"]:
		var sid: String = str(angriff_auf.get(pos, ""))
		if sid != "" and not reihenfolge.has(sid):
			reihenfolge.append(sid)
	for pos in ["A1", "A2", "A3", "A4", "A5", "A6"]:
		var sid2: String = str(abwehr_auf.get(pos, ""))
		if sid2 != "" and not reihenfolge.has(sid2):
			reihenfolge.append(sid2)
	if reihenfolge.is_empty():
		anweisungs_bereich.add_child(Stil.matt("Stellen Sie zuerst eine Formation auf."))
		return

	var kopfzeile := Stil.hbox(10)
	anweisungs_bereich.add_child(kopfzeile)
	var k1 := Stil.matt("Spieler", Stil.S_MINI)
	k1.custom_minimum_size = Vector2(220, 0)
	kopfzeile.add_child(k1)
	var k2 := Stil.matt("Im Angriff", Stil.S_MINI)
	k2.custom_minimum_size = Vector2(210, 0)
	kopfzeile.add_child(k2)
	var k3 := Stil.matt("In der Abwehr", Stil.S_MINI)
	k3.custom_minimum_size = Vector2(210, 0)
	kopfzeile.add_child(k3)
	kopfzeile.add_child(Stil.matt("Was das bedeutet", Stil.S_MINI))

	for sid in reihenfolge:
		var sp: Dictionary = Welt.spieler(sid)
		if sp.is_empty():
			continue
		var im_angriff: bool = (angriff_auf.values() as Array).has(sid)
		var im_abwehr: bool = (abwehr_auf.values() as Array).has(sid)
		var akt: Dictionary = Anweisungen.fuer(Welt.daten, cid, sid)
		var zeile := Stil.hbox(10)
		anweisungs_bereich.add_child(zeile)
		var name := Stil.hbox(6)
		name.custom_minimum_size = Vector2(220, 0)
		zeile.add_child(name)
		var nr := Stil.matt(Trikot.text(sp), Stil.S_KLEIN)
		nr.custom_minimum_size = Vector2(22, 0)
		nr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name.add_child(nr)
		name.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		name.add_child(Stil.text(Spielerfabrik.kurz_name(sp), Stil.S_KLEIN))
		zeile.add_child(_rollenwahl(Anweisungen.ANGRIFF, str(akt["angriff"]), im_angriff,
			func(w): _rolle_setzen(sid, "angriff", w)))
		zeile.add_child(_rollenwahl(Anweisungen.ABWEHR, str(akt["abwehr"]), im_abwehr,
			func(w): _rolle_setzen(sid, "abwehr", w)))
		var beschreibung: String = ""
		if im_angriff and str(akt["angriff"]) != "normal":
			beschreibung = str(Anweisungen.ANGRIFF[str(akt["angriff"])]["text"])
		elif im_abwehr and str(akt["abwehr"]) != "normal":
			beschreibung = str(Anweisungen.ABWEHR[str(akt["abwehr"])]["text"])
		var txt := Stil.matt(beschreibung, Stil.S_MINI)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(txt)

## Zielminuten je Spieler. Das ist die Antwort auf die Frage, die sich jeder
## Trainer stellt, der einen jungen Spieler aufbauen will: wie kommt er zu
## Spielzeit, ohne dass ich jeden Wechsel von Hand mache?
func _einsatzzeiten() -> void:
	var cid: String = Welt.mein_verein_id
	var kopf := Stil.hbox(10)
	minuten_bereich.add_child(kopf)
	kopf.add_child(Stil.matt("Zielminuten pro Spiel. Wer sein Pensum hat, macht Platz für den, der hinterherhängt — auch wenn er noch frisch ist.", Stil.S_MINI))
	kopf.add_child(Stil.dehner())
	var bilanz := Einsatzzeit.bilanz(Welt.daten, cid)
	var farbe: Color = Stil.GRUEN if bool(bilanz["passt"]) else (Stil.GELB if int(bilanz["anzahl"]) > 0 else Stil.TEXT_MATT)
	var abz := Stil.abzeichen("%d VERGEBEN · %d VON %d MIN" % [
		int(bilanz["anzahl"]), int(bilanz["summe"]), int(bilanz["machbar"])], farbe)
	abz.tooltip_text = "Sechs Feldpositionen mal sechzig Minuten sind %d Minuten, die zu verteilen sind. Deutlich mehr zu versprechen, geht nicht auf." % int(bilanz["machbar"])
	kopf.add_child(abz)
	var uebernehmen := Stil.knopf("Aus Vertragsrollen ableiten")
	uebernehmen.tooltip_text = "Setzt für jeden Feldspieler die Minuten, die seine Vertragsrolle erwarten lässt."
	uebernehmen.pressed.connect(func():
		Einsatzzeit.aus_vertraegen(Welt.daten, cid)
		_melde("Zielminuten aus den Vertragsrollen übernommen.")
		aktualisieren())
	kopf.add_child(uebernehmen)
	var frei := Stil.knopf_flach("Alle aufheben", Stil.TEXT_MATT)
	frei.tooltip_text = "Ohne Ziele entscheidet allein der Kraftstand — wie vorher."
	frei.pressed.connect(func():
		Einsatzzeit.loeschen(Welt.daten, cid)
		_melde("Alle Zielminuten aufgehoben.")
		aktualisieren())
	kopf.add_child(frei)
	if not bool(bilanz["passt"]) and int(bilanz["anzahl"]) > 0:
		var ueber: bool = float(bilanz["summe"]) > float(bilanz["machbar"])
		minuten_bereich.add_child(Stil.text(
			"Sie versprechen %s Spielzeit, als es gibt. Die Ziele lassen sich nicht alle einhalten." % ("mehr" if ueber else "weniger"),
			Stil.S_MINI, Stil.GELB))
	minuten_bereich.add_child(Stil.trenner())

	var kader: Array = (Welt.verein(cid)["kader"] as Array).duplicate()
	kader.sort_custom(func(a, b):
		return Einsatzzeit.ziel(Welt.daten, cid, str(a)) > Einsatzzeit.ziel(Welt.daten, cid, str(b)))
	var g := Stil.tabelle(["Spieler", "Rolle", "Ziel", "Zielminuten", "Bisher", "Stand"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minuten_bereich.add_child(g)
	for sid_roh in kader:
		var sid: String = str(sid_roh)
		var sp: Dictionary = Welt.spieler(sid)
		if sp.is_empty() or bool(sp["ist_torwart"]):
			continue
		var k := Stil.knopf_flach("%s %s" % [Trikot.text(sp), Spielerfabrik.kurz_name(sp)])
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(k)
		var rolle: String = str((sp.get("vertrag", {}) as Dictionary).get("rolle", "rotation"))
		g.add_child(Stil.matt(rolle.capitalize(), Stil.S_KLEIN))
		var soll: float = Einsatzzeit.ziel(Welt.daten, cid, sid)
		g.add_child(Stil.text("%d min" % int(soll) if soll > 0.0 else "—", Stil.S_KLEIN,
			Stil.AKZENT if soll > 0.0 else Stil.TEXT_SCHWACH))
		var schieber := HSlider.new()
		schieber.min_value = 0
		schieber.max_value = Einsatzzeit.SPIELDAUER
		schieber.step = 2
		schieber.value = soll
		schieber.custom_minimum_size = Vector2(180, 0)
		schieber.tooltip_text = "0 heißt: kein Ziel, es entscheidet die Kraft. Vorschlag nach Vertragsrolle: %d Minuten." % int(Einsatzzeit.vorschlag(sp))
		schieber.drag_ended.connect(func(_geaendert):
			Einsatzzeit.setzen(Welt.daten, cid, sid, schieber.value)
			aktualisieren())
		g.add_child(schieber)
		var e := Einsatzzeit.erfuellung(Welt.daten, cid, sid)
		var spiele: int = int(sp["stats"]["saison"]["spiele"])
		g.add_child(Stil.matt("%d min in %d Spielen" % [int(e["ist"]), spiele] if spiele > 0 else "noch kein Spiel", Stil.S_KLEIN))
		var stand: String = Einsatzzeit.erfuellungstext(e)
		var standfarbe: Color = Stil.TEXT_MATT
		if bool(e["gilt"]):
			standfarbe = Stil.GRUEN if absf(float(e["abweichung"])) < 4.0 else Stil.GELB
		g.add_child(Stil.text(stand, Stil.S_KLEIN, standfarbe))

## Ein Auswahlfeld ueber einen Anweisungskatalog.
func _rollenwahl(katalog: Dictionary, aktuell: String, aktiv: bool, rueckruf: Callable) -> OptionButton:
	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(210, 0)
	wahl.disabled = not aktiv
	var i := 0
	for schluessel in katalog.keys():
		var e: Dictionary = katalog[schluessel]
		wahl.add_item(str(e["name"]))
		wahl.set_item_metadata(i, schluessel)
		wahl.set_item_tooltip(i, str(e["text"]))
		if str(schluessel) == aktuell:
			wahl.select(i)
		i += 1
	if not aktiv:
		wahl.tooltip_text = "Der Spieler steht in dieser Formation nicht auf dem Feld."
	wahl.item_selected.connect(func(idx): rueckruf.call(str(wahl.get_item_metadata(idx))))
	return wahl

func _rolle_setzen(sid: String, bereich: String, wert: String) -> void:
	Anweisungen.setzen(Welt.daten, Welt.mein_verein_id, sid, bereich, wert)
	var katalog: Dictionary = Anweisungen.ANGRIFF if bereich == "angriff" else Anweisungen.ABWEHR
	_melde("%s: %s" % [Spielerfabrik.kurz_name(Welt.spieler(sid)), str(katalog[wert]["name"])])
	aktualisieren()

func _bank() -> void:
	var auf: Dictionary = Welt.verein(Welt.mein_verein_id)["aufstellung"]
	var bank: Array = auf.get("bank", [])
	if bank.is_empty():
		bank_bereich.add_child(Stil.matt("Keine weiteren einsatzfähigen Spieler."))
		return
	bank_bereich.add_child(Stil.matt("Diese Spieler stehen für Wechsel bereit.", Stil.S_MINI))
	var reihe := Stil.hbox(8)
	reihe.custom_minimum_size = Vector2(0, 0)
	bank_bereich.add_child(reihe)
	var zaehler := 0
	for sid in bank:
		if zaehler > 0 and zaehler % 5 == 0:
			reihe = Stil.hbox(8)
			bank_bereich.add_child(reihe)
		var sp: Dictionary = Welt.spieler(sid)
		var k := Stil.knopf("%s %s (%d)" % [str(sp["position"]), Spielerfabrik.kurz_name(sp), int(Spielerfabrik.gesamt(sp))])
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		reihe.add_child(k)
		zaehler += 1

## Weist auf Spieler in der Aufstellung hin, die nicht in Verfassung sind.
func _warnungen() -> void:
	if bool(Welt.einstellung("auto_aufstellung", true)):
		return
	var auf: Dictionary = Welt.verein(Welt.mein_verein_id)["aufstellung"]
	var betroffen: Array = []
	var gesehen := {}
	for block in ["angriff", "abwehr"]:
		for pos in (auf.get(block, {}) as Dictionary).keys():
			var sid: String = str(auf[block][pos])
			if sid == "" or gesehen.has(sid) or Welt.spieler(sid).is_empty():
				continue
			gesehen[sid] = true
			var sp: Dictionary = Welt.spieler(sid)
			var form: float = Spielerfabrik.einsatzform(sp)
			if form < 52.0:
				betroffen.append({"sid": sid, "form": form})
	if betroffen.is_empty():
		return
	var karte := Bausteine.karte_in(warnungen_bereich, "")
	for e in betroffen:
		var sp2: Dictionary = Welt.spieler(str(e["sid"]))
		var zeile := Stil.hbox(8)
		zeile.add_child(Stil.abzeichen("ACHTUNG", Stil.GELB))
		zeile.add_child(Stil.text("%s ist nicht in Verfassung (Einsatzform %d, Last %d)." % [
			Spielerfabrik.voller_name(sp2), int(float(e["form"])), int(float(sp2["last"]))], Stil.S_KLEIN, Stil.GELB))
		karte.add_child(zeile)
