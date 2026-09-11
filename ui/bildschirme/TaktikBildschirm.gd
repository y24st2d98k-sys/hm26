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
	var auto_haken := CheckBox.new()
	auto_haken.text = "Aufstellung vor jedem Spiel automatisch optimieren"
	auto_haken.tooltip_text = "Der Trainerstab stellt vor jeder Partie die beste verfügbare Sieben auf — nach Form, Fitness und Lastkonto. Ausschalten, wenn Sie selbst aufstellen wollen."
	auto_haken.button_pressed = bool(Welt.daten["einstellungen"].get("auto_aufstellung", true))
	auto_haken.toggled.connect(func(an):
		Welt.daten["einstellungen"]["auto_aufstellung"] = an
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
	var an := Stil.knopf("Angriff")
	an.pressed.connect(func():
		vorschau_angriff = true
		_feld_auffrischen())
	umschalter.add_child(an)
	var ab := Stil.knopf("Abwehr")
	ab.pressed.connect(func():
		vorschau_angriff = false
		_feld_auffrischen())
	umschalter.add_child(ab)
	feld = Spielfeld.new()
	feld.custom_minimum_size = Vector2(520, 262)
	feldkarte.add_child(feld)
	taktik_bereich = Bausteine.karte_in(rechts, "Spielidee")

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
	leeren(warnungen_bereich)
	if Welt.mein_verein_id == "":
		bank_bereich.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	_warnungen()
	_angriff()
	_abwehr()
	_taktik()
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

func _verfuegbar(ausser: Array) -> Array:
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
		wahl.add_item("%s  (%d)" % [Spielerfabrik.voller_name(sp), int(wert)])
		wahl.set_item_metadata(index, sid)
		if sid == aktuell:
			wahl.select(index)
		index += 1
	wahl.item_selected.connect(func(i):
		var gewaehlt: String = str(wahl.get_item_metadata(i))
		_setze(block, pos, gewaehlt))
	h.add_child(wahl)

	if aktuell != "" and Welt.daten["spieler"].has(aktuell):
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
		var info := Stil.knopf_flach("Profil")
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
		if sid == "" or not Welt.daten["spieler"].has(sid):
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
	taktik_bereich.add_child(_schieber("Tempo", int(t["tempo"]), func(w): t["tempo"] = int(w),
		"Hohes Tempo bedeutet mehr Angriffe für beide Mannschaften."))
	taktik_bereich.add_child(_schieber("Risiko", int(t["risiko"]), func(w): t["risiko"] = int(w),
		"Mehr Risiko im Aufbau: bessere Abschlüsse, aber mehr technische Fehler."))
	taktik_bereich.add_child(_schieber("Härte in der Abwehr", int(t["haerte"]), func(w): t["haerte"] = int(w),
		"Harte Deckung bremst den Gegner — und produziert Zeitstrafen."))
	taktik_bereich.add_child(_schieber("Wechselintensität", int(t.get("wechselspiel", 55)), func(w): t["wechselspiel"] = int(w),
		"Wie konsequent zwischen Angriffs- und Abwehrformation rotiert wird. Kostet Kraft, erhöht das Risiko von Wechselfehlern."))

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
		wahl.add_item("%s (%d)" % [Spielerfabrik.voller_name(sp), int(float(sp["attr"]["siebenmeter"]))])
		wahl.set_item_metadata(i, sid)
		if str(auf.get("siebenmeter", "")) == sid:
			wahl.select(i)
		i += 1
	wahl.item_selected.connect(func(idx): auf["siebenmeter"] = str(wahl.get_item_metadata(idx)))
	schuetze.add_child(wahl)

	var haken := CheckBox.new()
	haken.text = "Auszeiten automatisch nehmen"
	haken.button_pressed = bool(t.get("auszeit_automatik", true))
	haken.toggled.connect(func(an): t["auszeit_automatik"] = an)
	taktik_bereich.add_child(haken)
	var haken2 := CheckBox.new()
	haken2.text = "Automatische Rotation im Spiel (Kräftehaushalt)"
	haken2.button_pressed = bool(Welt.daten["einstellungen"].get("autorotation", true))
	haken2.toggled.connect(func(an): Welt.daten["einstellungen"]["autorotation"] = an)
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

func _schieber(beschriftung: String, wert: int, rueckruf: Callable, hinweis: String) -> HBoxContainer:
	var h := Stil.hbox(8)
	var l := Stil.matt(beschriftung, Stil.S_KLEIN)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.value = wert
	s.custom_minimum_size = Vector2(160, 0)
	h.add_child(s)
	var anzeige := Stil.text(str(wert), Stil.S_KLEIN, Stil.AKZENT)
	anzeige.custom_minimum_size = Vector2(34, 0)
	h.add_child(anzeige)
	s.value_changed.connect(func(w):
		anzeige.text = str(int(w))
		rueckruf.call(w))
	h.tooltip_text = hinweis
	return h

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
	if bool(Welt.daten["einstellungen"].get("auto_aufstellung", true)):
		return
	var auf: Dictionary = Welt.verein(Welt.mein_verein_id)["aufstellung"]
	var betroffen: Array = []
	var gesehen := {}
	for block in ["angriff", "abwehr"]:
		for pos in (auf.get(block, {}) as Dictionary).keys():
			var sid: String = str(auf[block][pos])
			if sid == "" or gesehen.has(sid) or not Welt.daten["spieler"].has(sid):
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
