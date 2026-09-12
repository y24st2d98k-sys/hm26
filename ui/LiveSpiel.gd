class_name LiveSpiel
extends Control
## Die Live-Ansicht einer Partie.
##
## Sie zeigt dasselbe Spiel, das die Engine auch still durchrechnet — nur Ereignis
## für Ereignis, mit Spielfeld, Ticker, Hallenpuls und allen Eingriffsmöglichkeiten:
## Wechsel, Auszeit, Abwehrformation, Mentalität, 7-gegen-6.

signal beendet(spiel_id: String)

const TEMPI := [
	{"name": "Pause", "sekunden": 0.0},
	{"name": "Langsam", "sekunden": 0.75},
	{"name": "Normal", "sekunden": 0.30},
	{"name": "Schnell", "sekunden": 0.10},
]

var sim: Matchsim = null
var mid: String = ""
var mein_team: Dictionary = {}
var gegner_team: Dictionary = {}
var tempo: int = 2
var uhr: Timer
var fertig: bool = false

var feld: Spielfeld
var anzeige_stand: Label
var anzeige_zeit: Label
var anzeige_wettbewerb: Label
var puls_balken: Control
var puls_text: Label
var ticker: VBoxContainer
var ticker_scroll: ScrollContainer
var kader_bereich: VBoxContainer
var stats_bereich: VBoxContainer
var taktik_bereich: VBoxContainer
var knopf_auszeit: Button
var tempo_knoepfe: Array = []
var tempo_leiste: HBoxContainer
var heim_seite: Dictionary = {}
var gast_seite: Dictionary = {}
var abschluss_knopf: Button
var gewaehlt_raus: String = ""
var hinweis: Label
var anpfiff_knopf: Button
var ansprache_bereich: VBoxContainer
var angepfiffen: bool = false
var wunschtempo: int = 2

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	theme = Stil.theme()
	var bg := ColorRect.new()
	bg.color = Stil.GRUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	uhr = Timer.new()
	uhr.one_shot = false
	uhr.timeout.connect(_schritt)
	add_child(uhr)
	_baue()

func _baue() -> void:
	var wurzel := MarginContainer.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.add_theme_constant_override("margin_left", 14)
	wurzel.add_theme_constant_override("margin_right", 14)
	wurzel.add_theme_constant_override("margin_top", 10)
	wurzel.add_theme_constant_override("margin_bottom", 10)
	add_child(wurzel)
	var v := Stil.vbox(10)
	wurzel.add_child(v)

	# Anzeigetafel — Heimseite, Spielstand mit Uhr, Gastseite, darunter der Puls
	var tafel := PanelContainer.new()
	var tafelstil := Stil.box(Stil.FLAECHE_TIEF, Stil.R_NORMAL, Stil.RAND_HELL)
	tafelstil.content_margin_left = 18
	tafelstil.content_margin_right = 18
	tafelstil.content_margin_top = 10
	tafelstil.content_margin_bottom = 10
	tafel.add_theme_stylebox_override("panel", tafelstil)
	v.add_child(tafel)
	var tafelspalte := Stil.vbox(6)
	tafel.add_child(tafelspalte)

	var tafelbox := Stil.hbox(14)
	tafelspalte.add_child(tafelbox)
	heim_seite = _tafelseite(tafelbox, true)
	var mitte := Stil.vbox(0)
	mitte.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tafelbox.add_child(mitte)
	anzeige_stand = Stil.anzeige("0 : 0", Stil.S_ANZEIGE)
	mitte.add_child(anzeige_stand)
	anzeige_zeit = Stil.anzeige("00:00", Stil.S_GROSS, Stil.AKZENT)
	mitte.add_child(anzeige_zeit)
	gast_seite = _tafelseite(tafelbox, false)

	var fusszeile := Stil.hbox(12)
	tafelspalte.add_child(fusszeile)
	anzeige_wettbewerb = Stil.matt("", Stil.S_MINI)
	fusszeile.add_child(anzeige_wettbewerb)
	fusszeile.add_child(Stil.dehner())
	puls_text = Stil.etikett("Hallenpuls 50")
	fusszeile.add_child(puls_text)
	puls_balken = Stil.balken(50.0, 100.0, 190)
	puls_balken.custom_minimum_size = Vector2(190, 10)
	fusszeile.add_child(puls_balken)

	# Steuerleiste
	var steuerung := Stil.hbox(10)
	v.add_child(steuerung)
	tempo_leiste = Stil.hbox(0)
	steuerung.add_child(tempo_leiste)
	_baue_tempoleiste()
	anpfiff_knopf = Stil.knopf_primaer("Anpfiff")
	anpfiff_knopf.pressed.connect(_anpfiff)
	steuerung.add_child(anpfiff_knopf)
	var ueberspringen := Stil.knopf_geist("Zum Ende springen")
	ueberspringen.pressed.connect(_ueberspringen)
	steuerung.add_child(ueberspringen)
	knopf_auszeit = Stil.knopf_geist("Auszeit nehmen", Stil.BLAU)
	knopf_auszeit.pressed.connect(_auszeit)
	steuerung.add_child(knopf_auszeit)
	steuerung.add_child(Stil.dehner())
	hinweis = Stil.text("", Stil.S_KLEIN, Stil.AKZENT)
	steuerung.add_child(hinweis)
	abschluss_knopf = Stil.knopf_primaer("Spiel beenden")
	abschluss_knopf.visible = false
	abschluss_knopf.pressed.connect(_abschliessen)
	steuerung.add_child(abschluss_knopf)

	# Hauptbereich
	var haupt := Stil.hbox(12)
	haupt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(haupt)

	var links := Stil.vbox(10)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haupt.add_child(links)
	feld = Spielfeld.new()
	feld.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feld.custom_minimum_size = Vector2(560, 300)
	links.add_child(feld)
	var tickerkarte := Stil.karte("Ticker")
	Stil.karte_wurzel(tickerkarte).size_flags_vertical = Control.SIZE_EXPAND_FILL
	links.add_child(Stil.karte_wurzel(tickerkarte))
	ticker_scroll = ScrollContainer.new()
	ticker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ticker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ticker_scroll.custom_minimum_size = Vector2(0, 150)
	tickerkarte.add_child(ticker_scroll)
	ticker = Stil.vbox(3)
	ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker_scroll.add_child(ticker)

	var rechts := ScrollContainer.new()
	rechts.custom_minimum_size = Vector2(430, 0)
	rechts.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	haupt.add_child(rechts)
	var rechtsbox := Stil.vbox(10)
	rechtsbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.add_child(rechtsbox)
	ansprache_bereich = Bausteine.karte_in(rechtsbox, "Ansprache")
	taktik_bereich = Bausteine.karte_in(rechtsbox, "Taktik im Spiel")
	kader_bereich = Bausteine.karte_in(rechtsbox, "Mannschaft & Wechsel")
	stats_bereich = Bausteine.karte_in(rechtsbox, "Statistik")

# ------------------------------------------------------------------ Start ---

func starte(spiel_id: String) -> void:
	mid = spiel_id
	fertig = false
	Klang.musik_stop()
	Klang.atmo_start()
	Klang.atmo_puls(55.0)
	abschluss_knopf.visible = false
	gewaehlt_raus = ""
	Bildschirm.leeren(ticker)
	var m: Dictionary = Welt.partie(mid)
	KI.aufstellung_pruefen(Welt.daten, str(m["heim"]))
	KI.aufstellung_pruefen(Welt.daten, str(m["gast"]))
	sim = Matchsim.new(Welt.daten, m)
	sim.live = true
	sim.vorbereiten()
	var heim_ist_mein: bool = str(m["heim"]) == Welt.mein_verein_id
	mein_team = sim.heim if heim_ist_mein else sim.gast
	gegner_team = sim.gast if heim_ist_mein else sim.heim
	feld.heim_farbe = Welt.verein(str(m["heim"]))["wappen"]["a"]
	feld.gast_farbe = Welt.verein(str(m["gast"]))["wappen"]["a"]
	feld.heim_kurz = str(Welt.verein(str(m["heim"])).get("kurz", ""))
	feld.gast_kurz = str(Welt.verein(str(m["gast"])).get("kurz", ""))
	anzeige_wettbewerb.text = "%s · %s · %s" % [Welt.wettbewerb_name(str(m["wettbewerb"])),
		Kalender.text(int(m["tag"]), Welt.startjahr(), true), Welt.verein(str(m["heim"]))["halle"]["name"]]
	_tafel_beschriften(m)
	wunschtempo = int(Welt.daten["einstellungen"].get("sim_tempo", 2))
	angepfiffen = false
	anpfiff_knopf.visible = true
	_setze_tempo(0)
	hinweis.text = "Aufstellung und Taktik prüfen — dann Anpfiff."
	_taktik_aufbauen()
	_ansprache_aufbauen()
	_kader_aufbauen()
	_stats_aufbauen()
	_szene_auffrischen()
	_anzeige_auffrischen()

func _anpfiff() -> void:
	angepfiffen = true
	Klang.spiele("anpfiff", 0.85)
	_ansprache_aufbauen(false)
	anpfiff_knopf.visible = false
	hinweis.text = ""
	_setze_tempo(wunschtempo)

func _setze_tempo(i: int) -> void:
	tempo = i
	if i > 0:
		wunschtempo = i
		Welt.daten["einstellungen"]["sim_tempo"] = i
		if not angepfiffen:
			angepfiffen = true
			anpfiff_knopf.visible = false
	_baue_tempoleiste()
	var sekunden: float = float(TEMPI[i]["sekunden"])
	if sekunden <= 0.0 or fertig:
		uhr.stop()
	else:
		uhr.wait_time = sekunden
		uhr.start()

# ----------------------------------------------------------------- Ablauf ---

func _schritt() -> void:
	if sim == null or fertig:
		return
	var e := sim.naechstes_ereignis()
	if e.is_empty():
		_ende()
		return
	_ereignis_anzeigen(e)
	_anzeige_auffrischen()
	_szene_auffrischen(e)
	if str(e["typ"]) == "halbzeit":
		_setze_tempo(0)
		hinweis.text = "Halbzeit — Ansprache halten, wechseln, umstellen."
		_ansprache_aufbauen(true)
	if str(e["typ"]) == "ende":
		_ende()

func _ueberspringen() -> void:
	if sim == null or fertig:
		return
	angepfiffen = true
	anpfiff_knopf.visible = false
	uhr.stop()
	while not sim.beendet:
		var e := sim.naechstes_ereignis()
		if e.is_empty():
			break
		if str(e["typ"]) in ["tor", "zeitstrafe", "rot", "auszeit", "halbzeit", "ende", "verletzung", "siebenmeterwerfen"]:
			_ereignis_anzeigen(e)
	_anzeige_auffrischen()
	_szene_auffrischen()
	_ende()

func _ende() -> void:
	if fertig:
		return
	fertig = true
	Klang.spiele("sirene", 0.9)
	Klang.atmo_stop()
	uhr.stop()
	abschluss_knopf.visible = true
	hinweis.text = "Abpfiff."
	_ansprache_aufbauen(false)
	_stats_auffrischen()

func _abschliessen() -> void:
	if sim == null:
		return
	Welt.partie_abschliessen(mid, sim)
	Klang.atmo_stop()
	var id := mid
	sim = null
	beendet.emit(id)

# --------------------------------------------------------------- Anzeigen ---

func _anzeige_auffrischen() -> void:
	if sim == null:
		return
	anzeige_stand.text = "%d : %d" % [int(sim.heim["tore"]), int(sim.gast["tore"])]
	anzeige_zeit.text = sim.zeittext(sim.zeit)
	puls_text.text = "Hallenpuls %d — %s" % [int(sim.hallenpuls), _pulstext(sim.hallenpuls)]
	puls_text.add_theme_color_override("font_color", Stil.prozent_farbe(sim.hallenpuls))
	Klang.atmo_puls(sim.hallenpuls)
	if puls_balken.has_method("setze"):
		puls_balken.setze(sim.hallenpuls)
	knopf_auszeit.text = "Auszeit nehmen (%d übrig)" % int(mein_team.get("auszeiten", 0))
	knopf_auszeit.disabled = int(mein_team.get("auszeiten", 0)) <= 0 or fertig
	_kader_auffrischen()
	_stats_auffrischen()

func _pulstext(wert: float) -> String:
	if wert >= 82.0:
		return "die Halle kocht"
	elif wert >= 66.0:
		return "laute Unterstützung"
	elif wert >= 48.0:
		return "normale Stimmung"
	elif wert >= 32.0:
		return "es wird still"
	return "eisige Stimmung"

func _ereignis_anzeigen(e: Dictionary) -> void:
	_klang_zu(e)
	var zeile := Stil.hbox(8)
	var zeit := Stil.matt(sim.zeittext(float(e["zeit"])), Stil.S_MINI)
	zeit.custom_minimum_size = Vector2(44, 0)
	zeile.add_child(zeit)
	var stand: Array = e.get("stand", [0, 0])
	var s := Stil.matt("%d:%d" % [int(stand[0]), int(stand[1])], Stil.S_MINI)
	s.custom_minimum_size = Vector2(40, 0)
	zeile.add_child(s)
	var text := Stil.text(str(e["text"]), Stil.S_KLEIN, _ereignisfarbe(e))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zeile.add_child(text)
	ticker.add_child(zeile)
	while ticker.get_child_count() > 120:
		var alt := ticker.get_child(0)
		ticker.remove_child(alt)
		alt.queue_free()
	await get_tree().process_frame
	if is_instance_valid(ticker_scroll):
		ticker_scroll.scroll_vertical = int(ticker_scroll.get_v_scroll_bar().max_value)

func _ereignisfarbe(e: Dictionary) -> Color:
	var eigene: bool = str(e["team"]) == ("heim" if mein_team == sim.heim else "gast")
	match str(e["typ"]):
		"tor":
			return Stil.GRUEN if eigene else Stil.ROT
		"parade":
			return Stil.BLAU if eigene else Stil.TEXT_MATT
		"zeitstrafe", "rot", "verletzung", "wechselfehler":
			return Stil.ROT if eigene else Stil.GELB
		"auszeit", "taktik", "lauf":
			return Stil.AKZENT
		"halbzeit", "ende", "anwurf":
			return Stil.LILA
	return Stil.TEXT_MATT

func _szene_auffrischen(e: Dictionary = {}) -> void:
	if sim == null:
		return
	feld.angreifer = sim.angriffsrecht
	feld.setze_szene({
		"heim": _team_szene(sim.heim, sim.angriffsrecht == "heim"),
		"gast": _team_szene(sim.gast, sim.angriffsrecht == "gast"),
	})
	if not e.is_empty() and e.has("position"):
		var pos: String = str(e["position"])
		var basis: Vector2 = Spielfeld.ANGRIFF_RECHTS.get(pos, Vector2(26.0, 10.0))
		feld.ball = basis if str(e["team"]) == "heim" else Vector2(Spielfeld.LAENGE - basis.x, basis.y)
		feld.hervorgehoben = str(e.get("spieler", ""))
	feld.queue_redraw()

func _team_szene(t: Dictionary, greift_an: bool) -> Dictionary:
	var block: Dictionary = t["angriff_auf"] if greift_an else t["abwehr_auf"]
	var eintraege := {}
	var i := 0
	for pos in block.keys():
		var sid: String = str(block[pos])
		if sid == "":
			continue
		if pos == "TW" and bool(t["sieben_gegen_sechs"]) and greift_an:
			continue
		var sp: Dictionary = Welt.spieler(sid)
		eintraege[pos] = {"sid": sid, "kurz": str(sp["nachname"]).substr(0, 9), "index": 0 if pos == "TW" else i}
		if pos != "TW":
			i += 1
	return eintraege

# ------------------------------------------------------------- Eingriffe ---

func _auszeit() -> void:
	if sim == null or fertig:
		return
	if sim.auszeit(mein_team):
		hinweis.text = "Auszeit genommen — jetzt zählt, was Sie sagen."
		_setze_tempo(0)
		_ansprache_aufbauen(true)
		_anzeige_auffrischen()

## Ansprachebereich. "dringend" hebt ihn optisch hervor (Halbzeit, Auszeit).
func _ansprache_aufbauen(dringend: bool = false) -> void:
	if ansprache_bereich == null or sim == null:
		return
	Bildschirm.leeren(ansprache_bereich)
	if fertig:
		ansprache_bereich.add_child(Stil.matt("Das Spiel ist beendet."))
		return
	var gelegenheit: bool = dringend or not angepfiffen
	if not gelegenheit:
		ansprache_bereich.add_child(Stil.matt(
			"Ansprachen sind vor dem Anpfiff, in der Halbzeit und in einer Auszeit möglich.", Stil.S_MINI))
		var letzte: Array = mein_team.get("ansprachen", [])
		if not letzte.is_empty():
			var e: Dictionary = letzte[-1]
			ansprache_bereich.add_child(Stil.info_zeile(
				str(Matchsim.ANSPRACHEN[str(e["tonlage"])]["name"]),
				"Wirkung %+.0f %%" % (float(e["wirkung"]) * 100.0),
				Stil.GRUEN if float(e["wirkung"]) > 0.0 else Stil.ROT))
		return
	ansprache_bereich.add_child(Stil.text("Was sagen Sie der Mannschaft?", Stil.S_NORMAL, Stil.AKZENT))
	var lage := Stil.matt(_lagetext(), Stil.S_MINI)
	lage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ansprache_bereich.add_child(lage)
	for tonlage in Matchsim.ANSPRACHEN.keys():
		var eintrag: Dictionary = Matchsim.ANSPRACHEN[tonlage]
		var k := Stil.knopf("%s — %s" % [str(eintrag["name"]), str(eintrag["beschreibung"])])
		k.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var ton: String = str(tonlage)
		k.pressed.connect(func():
			var erg := sim.ansprache_halten(mein_team, ton)
			hinweis.text = str(erg["text"])
			_ansprache_aufbauen(false)
			_kader_auffrischen())
		ansprache_bereich.add_child(k)

func _lagetext() -> String:
	if sim == null:
		return ""
	var eigene: int = int(mein_team["tore"])
	var fremde: int = int(gegner_team["tore"])
	var abstand: int = eigene - fremde
	var klima: float = float(Welt.verein(str(mein_team["cid"])).get("stimmung_kabine", 60.0))
	var lage := ""
	if abstand >= 5:
		lage = "Klar vorn — die Gefahr ist Nachlässigkeit."
	elif abstand > 0:
		lage = "Knapp vorn, das Spiel kann noch kippen."
	elif abstand == 0:
		lage = "Alles offen."
	elif abstand > -5:
		lage = "Knapp hinten, es ist noch alles drin."
	else:
		lage = "Deutlich hinten — jetzt braucht es etwas Außergewöhnliches."
	if klima < 45.0:
		lage += " Die Kabine ist angespannt, harte Worte sind riskant."
	elif klima > 72.0:
		lage += " Die Mannschaft steht geschlossen hinter Ihnen."
	return lage

func _taktik_aufbauen() -> void:
	Bildschirm.leeren(taktik_bereich)
	taktik_bereich.add_child(Stil.matt("Änderungen gelten nur für diese Partie.", Stil.S_MINI))
	var t: Dictionary = mein_team["taktik"]
	taktik_bereich.add_child(_wahl("Abwehr", ["6-0", "5-1", "3-2-1", "4-2"], str(t["abwehr"]), func(w): t["abwehr"] = w))
	taktik_bereich.add_child(_wahl("Angriff", ["positionsangriff", "tempospiel", "kreisfokus", "aussenfokus", "rueckraumfokus"],
		str(t["angriff"]), func(w): t["angriff"] = w))
	taktik_bereich.add_child(_wahl("Mentalität", ["defensiv", "ausgeglichen", "offensiv", "all-in"],
		str(t["mentalitaet"]), func(w): t["mentalitaet"] = w))
	taktik_bereich.add_child(_wahl("7 gegen 6", ["nie", "unterzahl", "rueckstand", "schluss", "immer"],
		str(t["siebter_feldspieler"]), func(w):
			t["siebter_feldspieler"] = w
			sim.sieben_gegen_sechs_pruefen(mein_team)))
	taktik_bereich.add_child(_schieber("Tempo", int(t["tempo"]), func(w): t["tempo"] = int(w)))
	taktik_bereich.add_child(_schieber("Risiko", int(t["risiko"]), func(w): t["risiko"] = int(w)))
	taktik_bereich.add_child(_schieber("Härte", int(t["haerte"]), func(w): t["haerte"] = int(w)))

func _wahl(beschriftung: String, werte: Array, aktuell: String, rueckruf: Callable) -> HBoxContainer:
	var h := Stil.hbox(8)
	var l := Stil.matt(beschriftung, Stil.S_KLEIN)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(180, 0)
	for i in range(werte.size()):
		wahl.add_item(str(werte[i]).capitalize())
		wahl.set_item_metadata(i, werte[i])
		if str(werte[i]) == aktuell:
			wahl.select(i)
	wahl.item_selected.connect(func(i):
		rueckruf.call(str(wahl.get_item_metadata(i)))
		hinweis.text = "Taktik angepasst.")
	h.add_child(wahl)
	return h

func _schieber(beschriftung: String, wert: int, rueckruf: Callable) -> HBoxContainer:
	var h := Stil.hbox(8)
	var l := Stil.matt(beschriftung, Stil.S_KLEIN)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.value = wert
	s.custom_minimum_size = Vector2(140, 0)
	h.add_child(s)
	var anzeige := Stil.text(str(wert), Stil.S_KLEIN, Stil.AKZENT)
	anzeige.custom_minimum_size = Vector2(32, 0)
	h.add_child(anzeige)
	s.value_changed.connect(func(w):
		anzeige.text = str(int(w))
		rueckruf.call(w))
	return h

func _kader_aufbauen() -> void:
	_kader_auffrischen()

func _kader_auffrischen() -> void:
	if sim == null or kader_bereich == null:
		return
	Bildschirm.leeren(kader_bereich)
	kader_bereich.add_child(Stil.matt("Erst einen Spieler auf dem Feld wählen, dann den Ersatzmann.", Stil.S_MINI))
	var auf_platz: Array = sim.alle_auf_platz(mein_team)
	kader_bereich.add_child(Stil.text("Auf dem Feld", Stil.S_KLEIN, Stil.AKZENT))
	for sid in auf_platz:
		kader_bereich.add_child(_spielerzeile(sid, true))
	kader_bereich.add_child(Stil.trenner())
	kader_bereich.add_child(Stil.text("Bank", Stil.S_KLEIN, Stil.AKZENT))
	for sid in mein_team["bank"]:
		kader_bereich.add_child(_spielerzeile(sid, false))
	var strafen: Array = mein_team["gesperrt"]
	if not strafen.is_empty():
		kader_bereich.add_child(Stil.trenner())
		kader_bereich.add_child(Stil.text("Zeitstrafen", Stil.S_KLEIN, Stil.ROT))
		for e in strafen:
			var sid2: String = str(e["sid"])
			var bestrafter: String = Spielerfabrik.kurz_name(Welt.spieler(sid2)) if sid2 != "" and not Welt.spieler(sid2).is_empty() else "Disqualifikation"
			kader_bereich.add_child(Stil.info_zeile(bestrafter, "noch %d s" % int(maxf(float(e["bis"]) - sim.zeit, 0.0)), Stil.ROT))

func _spielerzeile(sid: String, auf_platz: bool) -> Control:
	var sp: Dictionary = Welt.spieler(sid)
	var z: Dictionary = mein_team["zustand"].get(sid, {})
	var knopf := Button.new()
	knopf.flat = true
	knopf.custom_minimum_size = Vector2(0, 24)
	if gewaehlt_raus == sid:
		knopf.add_theme_color_override("font_color", Stil.AKZENT)
	knopf.pressed.connect(func():
		if auf_platz:
			gewaehlt_raus = sid
			hinweis.text = "%s markiert — jetzt Ersatzspieler wählen." % Spielerfabrik.kurz_name(sp)
			_kader_auffrischen()
		else:
			if gewaehlt_raus == "":
				hinweis.text = "Zuerst einen Spieler auf dem Feld wählen."
				return
			if sim.wechsel(mein_team, gewaehlt_raus, sid):
				hinweis.text = "Wechsel durchgeführt."
				gewaehlt_raus = ""
				_kader_auffrischen()
				_szene_auffrischen()
			else:
				hinweis.text = "Dieser Wechsel ist nicht möglich.")
	var h := Stil.hbox(6)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knopf.add_child(h)
	var pos := Bausteine.positions_abzeichen(str(sp["position"]))
	pos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pos)
	var namensfeld := Stil.text(Spielerfabrik.kurz_name(sp), Stil.S_KLEIN, Stil.AKZENT if gewaehlt_raus == sid else Stil.TEXT)
	namensfeld.custom_minimum_size = Vector2(130, 0)
	namensfeld.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(namensfeld)
	var kraft := Stil.balken(float(z.get("kraft", 100.0)), 100.0, 70)
	kraft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(kraft)
	var tore := Stil.matt("%d T" % int(z.get("tore", 0)) if not bool(sp["ist_torwart"]) else "%d P" % int(z.get("paraden", 0)), Stil.S_MINI)
	tore.custom_minimum_size = Vector2(36, 0)
	tore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tore)
	var note := Stil.text(Stil.komma(float(z.get("bewertung", 3.4)), 1), Stil.S_MINI,
		Stil.wert_farbe(6.0 - float(z.get("bewertung", 3.4)), 5.0))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(note)
	return knopf

func _stats_aufbauen() -> void:
	_stats_auffrischen()

func _stats_auffrischen() -> void:
	if sim == null or stats_bereich == null:
		return
	Bildschirm.leeren(stats_bereich)
	var hs: Dictionary = sim.heim["stats"]
	var gs: Dictionary = sim.gast["stats"]
	for zeile in [["Würfe", "wuerfe"], ["Paraden", "paraden"], ["Technische Fehler", "technische_fehler"],
			["Zeitstrafen", "zeitstrafen"], ["Siebenmeter", "siebenmeter"], ["Gegenstoß-Tore", "gegenstoss_tore"],
			["Blocks", "blocks"], ["Wechsel", "wechsel"]]:
		var h := Stil.hbox(8)
		var a := Stil.text(str(int(hs.get(str(zeile[1]), 0))), Stil.S_KLEIN)
		a.custom_minimum_size = Vector2(38, 0)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(a)
		var l := Stil.matt(str(zeile[0]), Stil.S_KLEIN)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(l)
		var b := Stil.text(str(int(gs.get(str(zeile[1]), 0))), Stil.S_KLEIN)
		b.custom_minimum_size = Vector2(38, 0)
		h.add_child(b)
		stats_bereich.add_child(h)
	var lauf: Dictionary = sim.lauf
	if int(lauf.get("tore", 0)) >= 2:
		var team: String = str(lauf["team"])
		var laufteam: String = str(sim.heim["kurz"]) if team == "heim" else str(sim.gast["kurz"])
		stats_bereich.add_child(Stil.abzeichen("LAUF: %d Tore für %s" % [int(lauf["tore"]), laufteam], Stil.AKZENT))

## Eine Seite der Anzeigetafel: Wappen, Vereinsname, Kürzel.
## Die Heimmannschaft steht links, der Gast rechts — wie auf jeder Hallenanzeige.
func _tafelseite(eltern: Node, ist_heim: bool) -> Dictionary:
	var box := Stil.hbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_END if ist_heim else BoxContainer.ALIGNMENT_BEGIN
	eltern.add_child(box)
	var halter := Stil.hbox(0)
	halter.custom_minimum_size = Vector2(46, 46)
	var namen := Stil.vbox(0)
	namen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name := Stil.text("", Stil.S_GROSS)
	var ort := Stil.etikett("")
	if ist_heim:
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ort.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		namen.add_child(name)
		namen.add_child(ort)
		box.add_child(namen)
		box.add_child(halter)
	else:
		namen.add_child(name)
		namen.add_child(ort)
		box.add_child(halter)
		box.add_child(namen)
	return {"halter": halter, "name": name, "ort": ort}

## Trägt Wappen und Namen beider Mannschaften in die Anzeigetafel ein.
func _tafel_beschriften(m: Dictionary) -> void:
	for paar in [[heim_seite, str(m["heim"])], [gast_seite, str(m["gast"])]]:
		var seite: Dictionary = paar[0]
		var cid: String = str(paar[1])
		var halter: Node = seite["halter"]
		for k in halter.get_children():
			k.queue_free()
		halter.add_child(Wappen.fuer_verein(cid, 44.0))
		var v: Dictionary = Welt.verein(cid)
		(seite["name"] as Label).text = str(v.get("name", "?"))
		(seite["ort"] as Label).text = str(v.get("ort", ""))
		if cid == Welt.mein_verein_id:
			(seite["name"] as Label).add_theme_color_override("font_color", Stil.AKZENT)

## Die Tempowahl als segmentierte Leiste statt loser Knöpfe.
func _baue_tempoleiste() -> void:
	for k in tempo_leiste.get_children():
		k.queue_free()
	tempo_knoepfe.clear()
	var optionen: Array = []
	for t in TEMPI:
		optionen.append({"id": str(t["name"]), "name": str(t["name"])})
	var leiste := Stil.segmente(optionen, str(TEMPI[tempo]["name"]), func(id):
		for i in range(TEMPI.size()):
			if str(TEMPI[i]["name"]) == id:
				_setze_tempo(i)
				return)
	tempo_leiste.add_child(leiste)

## Welcher Klang zu welchem Ereignis gehört. Die Lautstärke des Jubels haengt
## davon ab, ob die eigene Halle jubelt oder verstummt.
func _klang_zu(e: Dictionary) -> void:
	var typ := str(e.get("typ", ""))
	var seite := str(e.get("seite", ""))
	var eigene: bool = mein_team.is_empty() or seite == _seite_von_mir()
	var puls: float = clampf(sim.hallenpuls / 100.0, 0.2, 1.0) if sim != null else 0.6
	match typ:
		"tor":
			Klang.spiele("tor" if eigene else "tor_gegen", (0.55 + 0.45 * puls) * (1.0 if eigene else 0.8))
		"parade":
			Klang.spiele("parade" if eigene else "raunen", 0.5 + 0.3 * puls)
		"zeitstrafe", "rot":
			Klang.spiele("pfiff", 0.75)
		"siebenmeter":
			Klang.spiele("pfiff", 0.6, 1.08)
		"fehler", "block":
			Klang.spiele("ball", 0.5)
		"auszeit", "halbzeit":
			Klang.spiele("pfiff", 0.7, 0.94)
		"ende":
			Klang.spiele("sirene", 0.9)

func _seite_von_mir() -> String:
	if sim == null:
		return "heim"
	return "heim" if str(sim.heim.get("cid", "")) == Welt.mein_verein_id else "gast"
