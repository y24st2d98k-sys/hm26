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
## Wer gerade auf welcher Position steht — fuer beide Mannschaften.
var aufstellungsleiste: VBoxContainer
var aufstellung_bereich: VBoxContainer
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
## Die rechte Spalte zeigt immer genau einen Abschnitt. Vorher standen alle
## fuenf untereinander in einem Rollbereich: wer zur Halbzeit eine Ansprache
## halten wollte, scrollte waehrend der laufenden Uhr durch Taktik, Aufstellung
## und Statistik. Ein Reiter kostet einen Klick und spart das Suchen.
var reiter: String = "taktik"
var reiter_leiste: Control
var reiter_halter: VBoxContainer
var bereiche: Dictionary = {}
var angepfiffen: bool = false
var wunschtempo: int = 2
## Verbleibende Takte des laufenden Angriffs (siehe _zug_bauen).
var _zug: Array = []

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
	var tafelstil := Stil.box_erhaben(Stil.FLAECHE_TIEF, Stil.R_GROSS, Stil.RAND)
	tafelstil.content_margin_left = 26
	tafelstil.content_margin_right = 26
	tafelstil.content_margin_top = 16
	tafelstil.content_margin_bottom = 16
	tafel.add_theme_stylebox_override("panel", tafelstil)
	v.add_child(tafel)
	var tafelspalte := Stil.vbox(10)
	tafel.add_child(tafelspalte)

	var tafelbox := Stil.hbox(22)
	tafelspalte.add_child(tafelbox)
	heim_seite = _tafelseite(tafelbox, true)
	var mitte := Stil.vbox(0)
	mitte.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tafelbox.add_child(mitte)
	anzeige_stand = Stil.anzeige("0 : 0", Stil.S_ANZEIGE)
	anzeige_stand.add_theme_font_override("font", Stil.schnitt_fett())
	mitte.add_child(anzeige_stand)
	# Die Uhr steht als eigene Flaeche unter dem Stand. Nackt darunter sah sie
	# aus wie eine Fussnote des Ergebnisses; sie ist aber die zweite Zahl, auf
	# die man in einer Live-Ansicht schaut.
	var uhrkasten := PanelContainer.new()
	var uhrstil := Stil.box(Stil.lasur(Stil.AKZENT, 0.16), Stil.R_RUND)
	uhrstil.content_margin_left = 16
	uhrstil.content_margin_right = 16
	uhrstil.content_margin_top = 3
	uhrstil.content_margin_bottom = 4
	uhrkasten.add_theme_stylebox_override("panel", uhrstil)
	uhrkasten.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mitte.add_child(uhrkasten)
	anzeige_zeit = Stil.anzeige("00:00", Stil.S_GROSS, Stil.AKZENT)
	anzeige_zeit.add_theme_font_override("font", Stil.schnitt_halbfett())
	uhrkasten.add_child(anzeige_zeit)
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
	var steuerung := Stil.hbox(12)
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
	# Das Feld ist in der Hoehe begrenzt, nicht in der Breite: vierzig Meter
	# auf zwanzig passen breiter als hoch in jedes Fenster. Wer es groesser
	# haben will, muss ihm Hoehe geben — deshalb nimmt es drei Viertel der
	# linken Spalte und der Ticker den Rest.
	feld.size_flags_stretch_ratio = 3.0
	feld.custom_minimum_size = Vector2(560, 360)
	links.add_child(feld)
	aufstellungsleiste = Stil.vbox(4)
	links.add_child(aufstellungsleiste)
	var tickerkarte := Stil.karte("Ticker")
	Stil.karte_wurzel(tickerkarte).size_flags_vertical = Control.SIZE_EXPAND_FILL
	Stil.karte_wurzel(tickerkarte).size_flags_stretch_ratio = 1.0
	links.add_child(Stil.karte_wurzel(tickerkarte))
	ticker_scroll = ScrollContainer.new()
	ticker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ticker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Kein Rollbalken: der Ticker haelt genau so viele Zeilen, wie hineinpassen.
	ticker_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	ticker_scroll.custom_minimum_size = Vector2(0, 150)
	tickerkarte.add_child(ticker_scroll)
	ticker = Stil.vbox(3)
	ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker_scroll.add_child(ticker)

	var rechtskarte := Stil.karte()
	var rechtswurzel := Stil.karte_wurzel(rechtskarte)
	rechtswurzel.custom_minimum_size = Vector2(452, 0)
	rechtswurzel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	haupt.add_child(rechtswurzel)
	reiter_halter = Stil.vbox(0)
	rechtskarte.add_child(reiter_halter)
	var flaeche := ScrollContainer.new()
	flaeche.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flaeche.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rechtskarte.add_child(flaeche)
	var stapel := Stil.vbox(0)
	stapel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flaeche.add_child(stapel)
	for id in REITER:
		var b := Stil.vbox(7)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.visible = str((id as Dictionary)["id"]) == reiter
		stapel.add_child(b)
		bereiche[str((id as Dictionary)["id"])] = b
	ansprache_bereich = bereiche["ansprache"]
	taktik_bereich = bereiche["taktik"]
	aufstellung_bereich = bereiche["aufstellung"]
	kader_bereich = bereiche["wechsel"]
	stats_bereich = bereiche["statistik"]
	_reiterleiste_bauen()

## Die Abschnitte der rechten Spalte, in der Reihenfolge der Leiste.
const REITER := [
	{"id": "ansprache", "name": "Ansprache"},
	{"id": "taktik", "name": "Taktik"},
	{"id": "aufstellung", "name": "Aufstellung"},
	{"id": "wechsel", "name": "Wechsel"},
	{"id": "statistik", "name": "Statistik"},
]

func _reiterleiste_bauen() -> void:
	if reiter_halter == null:
		return
	Bildschirm.leeren(reiter_halter)
	reiter_leiste = Stil.segmente(REITER, reiter, func(id): zeige_reiter(str(id)))
	reiter_leiste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reiter_halter.add_child(reiter_leiste)

func zeige_reiter(id: String) -> void:
	if not bereiche.has(id):
		return
	reiter = id
	for k in bereiche.keys():
		(bereiche[k] as Control).visible = str(k) == id
	_reiterleiste_bauen()

# ------------------------------------------------------------------ Start ---

func starte(spiel_id: String) -> void:
	mid = spiel_id
	fertig = false
	abschluss_knopf.visible = false
	gewaehlt_raus = ""
	Bildschirm.leeren(ticker)
	var m: Dictionary = Welt.partie(mid)
	KI.aufstellung_pruefen(Welt.daten, str(m["heim"]))
	KI.aufstellung_pruefen(Welt.daten, str(m["gast"]))
	sim = Matchsim.new(Welt.daten, m)
	sim.live = true
	sim.vorbereiten()
	# Bei einem Turnierspiel der eigenen Auswahl ist nicht der Verein gemeint.
	var meine_cid: String = Welt.mein_verein_id
	if Nationaltrainer.ist_nationalteam_spiel(Welt.daten, m):
		meine_cid = Nationalteam.team_id(Nationaltrainer.nation(Welt.daten))
	var heim_ist_mein: bool = str(m["heim"]) == meine_cid
	mein_team = sim.heim if heim_ist_mein else sim.gast
	gegner_team = sim.gast if heim_ist_mein else sim.heim
	feld.lebendig = true
	_zug.clear()
	# Trikotfarben — und zwar unterscheidbare.
	#
	# Zwei Vereine mit gruenem Wappen ergaben zwei gruene Mannschaften, und
	# damit war auf dem Feld nicht mehr zu sehen, wer zu wem gehoert. In
	# Wirklichkeit loest das der Ausweichsatz; hier tut es dasselbe.
	var heim_f: Color = _mindesthelligkeit(Welt.verein(str(m["heim"]))["wappen"]["a"])
	var gast_f: Color = _ausweichfarbe(heim_f, Welt.verein(str(m["gast"]))["wappen"])
	feld.heim_farbe = heim_f
	feld.gast_farbe = gast_f
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
	_aufstellung_aufbauen()
	_stats_aufbauen()
	_szene_auffrischen()
	_anzeige_auffrischen()

func _anpfiff() -> void:
	angepfiffen = true
	Klang.spiele("pfiff", -2.0)
	Klang.halle_an(sim.hallenpuls if sim != null else 50.0)
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

## Ereignisse, die als Angriff gespielt werden: erst ein paar Stationen,
## dann der Abschluss. Alles andere (Zeitstrafe, Wechsel, Pause) erscheint sofort.
const ANGRIFFSAUSGANG := ["tor", "fehlwurf", "parade", "block", "ballverlust"]

func _schritt() -> void:
	if sim == null or fertig:
		return
	# Ein Angriff besteht aus mehreren Takten. Solange noch welche offen sind,
	# wird gespielt und kein neues Ereignis geholt.
	if not _zug.is_empty():
		_takt_ausfuehren(_zug.pop_front())
		return
	var e := sim.naechstes_ereignis()
	if e.is_empty():
		_ende()
		return
	_zug = _zug_bauen(e)
	if _zug.is_empty():
		_ereignis_abschliessen(e)
	else:
		# Die Simulation hat den Angriff schon zu Ende gerechnet und das
		# Angriffsrecht weitergegeben. Das Feld muss den Angriff zeigen, von dem
		# das Ereignis handelt — sonst laufen Bild und Ticker auseinander.
		_szene_auffrischen({}, str(e["team"]))

## Baut aus einem Ereignis die Takte eines Angriffs. Der letzte Takt traegt das
## Ereignis selbst — dort erscheint der Text im Ticker.
##
## Ein Angriff ist hier keine Abfolge von Pässen mehr, sondern hat eine Form:
## Aufbau, ein Kreuzen oder ein Anspiel an den Kreis, dann der Abschluss. Zu
## jedem Takt gehören Laufwege — deshalb steht im Takt auch, wer den Ball
## abgibt und nicht nur, wer ihn bekommt.
func _zug_bauen(e: Dictionary) -> Array:
	var typ: String = str(e["typ"])
	if not ANGRIFFSAUSGANG.has(typ):
		return []
	var seite: String = str(e["team"])
	if seite != "heim" and seite != "gast":
		return []
	var takte: Array = []
	var mannschaft: Dictionary = sim.heim if seite == "heim" else sim.gast
	var schuetze: String = str(e.get("spieler", ""))
	var stationen := _anspielstationen(mannschaft, schuetze)
	var vorher := ""
	for i in range(stationen.size()):
		var sid: String = str(stationen[i])
		var letzter: bool = i == stationen.size() - 1
		takte.append({"art": "pass", "sid": sid, "von": vorher, "seite": seite})
		vorher = sid
		# Zwischen zwei Stationen loest sich gelegentlich der Kreisläufer oder
		# es kreuzen zwei Rückraumspieler — die Bewegung, die eine Deckung
		# tatsächlich in Schwierigkeiten bringt.
		if not letzter and randf() < 0.42:
			takte.append({"art": "bewegung", "seite": seite, "traeger": sid})
	if typ == "ballverlust":
		takte.append({"art": "ereignis", "ereignis": e})
		return takte
	takte.append({"art": "wurf", "seite": seite, "typ": typ, "spieler": schuetze})
	takte.append({"art": "ereignis", "ereignis": e})
	return takte

## Zwei bis drei Mitspieler, über die der Ball vor dem Abschluss läuft.
func _anspielstationen(mannschaft: Dictionary, schuetze: String) -> Array:
	var feldspieler: Array = []
	for pos in (mannschaft["angriff_auf"] as Dictionary).keys():
		if str(pos) == "TW":
			continue
		var sid: String = str(mannschaft["angriff_auf"][pos])
		if sid != "" and sid != schuetze:
			feldspieler.append(sid)
	feldspieler.shuffle()
	var anzahl: int = mini(feldspieler.size(), 2 if randf() < 0.6 else 3)
	var kette: Array = feldspieler.slice(0, anzahl)
	if schuetze != "":
		kette.append(schuetze)
	return kette

func _takt_ausfuehren(takt: Dictionary) -> void:
	var dauer: float = maxf(uhr.wait_time, 0.08)
	match str(takt["art"]):
		"pass":
			var empfaenger: String = str(takt["sid"])
			var seite_p: String = str(takt.get("seite", ""))
			var ziel_p: Vector2 = feld.spielerpunkt(empfaenger)
			# Wer den Ball erwartet, geht ihm entgegen — ein Pass wird
			# angenommen und nicht abgewartet.
			var tor_p: Vector2 = feld.tormitte(seite_p) if seite_p != "" else ziel_p
			feld.vorstossen(empfaenger, (tor_p - ziel_p) * Vector2(1.0, 0.35), 1.1, 1.5)
			feld.ball_spielen(feld.spielerpunkt(empfaenger), dauer * 0.85)
			# Der abgebende Spieler loest sich nach dem Pass von seiner Stelle.
			var von: String = str(takt.get("von", ""))
			if von != "":
				feld.vorstossen(von, Vector2(0.0, 1.0 if randf() < 0.5 else -1.0), 1.3, 1.4)
			# Der Ring wandert mit dem Ball — so ist immer zu sehen, wer ihn hat.
			feld.hervorgehoben = empfaenger
			if seite_p != "":
				feld.abwehr_verschieben("gast" if seite_p == "heim" else "heim", ziel_p, 1.0)
		"bewegung":
			_bewegung_spielen(str(takt["seite"]), str(takt.get("traeger", "")))
		"wurf":
			var seite: String = str(takt["seite"])
			var ziel: Vector2 = feld.tormitte(seite)
			var typ: String = str(takt["typ"])
			var schuetze: String = str(takt["spieler"])
			# Anlauf: drei Schritte auf das Tor zu, dann der Sprung.
			var von_s: Vector2 = feld.spielerpunkt(schuetze)
			feld.laufweg(schuetze, von_s.lerp(ziel, 0.22), 1.6, 11.0)
			# Ein Fehlwurf geht sichtbar daneben.
			if typ == "fehlwurf":
				ziel.y += 3.2 if randf() < 0.5 else -3.2
			elif typ == "block":
				ziel = von_s.lerp(ziel, 0.35)
			feld.hervorgehoben = schuetze
			# Die Deckung stellt sich in die Wurfbahn.
			feld.abwehr_verschieben("gast" if seite == "heim" else "heim", von_s, 1.25)
			feld.ball_werfen(ziel, dauer * 0.8, 1.8)
		"ereignis":
			_ereignis_abschliessen(takt["ereignis"])

## Eine Bewegung ohne Ball: Kreuzen im Rückraum oder ein Kreisläufer, der sich
## auf die andere Seite absetzt. Das ist der Unterschied zwischen sieben
## Kreisen, die Bälle tauschen, und einem Angriff.
func _bewegung_spielen(seite: String, traeger: String) -> void:
	if sim == null or seite == "":
		return
	var mannschaft: Dictionary = sim.heim if seite == "heim" else sim.gast
	var auf: Dictionary = mannschaft["angriff_auf"]
	var tor: Vector2 = feld.tormitte(seite)
	if randf() < 0.45:
		# Kreisläufer setzt sich ab: er wechselt die Seite vor der Deckung.
		var km: String = str(auf.get("KM", ""))
		if km != "":
			var jetzt: Vector2 = feld.spielerpunkt(km)
			var hin: float = 4.5 if jetzt.y < 10.0 else -4.5
			feld.laufweg(km, jetzt + Vector2((tor.x - jetzt.x) * 0.15, hin), 1.8, 8.5)
			return
	# Kreuzen: zwei Rückraumspieler tauschen die Wege.
	var kandidaten: Array = []
	for pos in ["RL", "RM", "RR"]:
		var sid: String = str(auf.get(pos, ""))
		if sid != "" and sid != traeger:
			kandidaten.append(sid)
	if kandidaten.size() < 2:
		return
	kandidaten.shuffle()
	var a: String = str(kandidaten[0])
	var b: String = str(kandidaten[1])
	var pa: Vector2 = feld.spielerpunkt(a)
	var pb: Vector2 = feld.spielerpunkt(b)
	feld.laufweg(a, pb, 1.7, 9.0)
	feld.laufweg(b, pa, 1.7, 9.0)

func _ereignis_abschliessen(e: Dictionary) -> void:
	_ereignis_anzeigen(e)
	_anzeige_auffrischen()
	_szene_auffrischen(e)
	_wirkung_zeigen(e)
	_ton_zu(e)
	if sim != null:
		Klang.halle_pegel(sim.hallenpuls)
	if str(e["typ"]) == "halbzeit":
		_setze_tempo(0)
		hinweis.text = "Halbzeit — Ansprache halten, wechseln, umstellen."
		_ansprache_aufbauen(true)
	if str(e["typ"]) == "ende":
		_ende()

## Der Ton zum Ereignis.
##
## Bewusst nicht zu jedem: ein Spiel, das bei jedem Fehlpass etwas sagt, sagt
## nach fünf Minuten nichts mehr. Es pfeift, es jubelt, und bei einer Parade
## geht ein Raunen durch die Halle. Der Rest bleibt still.
func _ton_zu(e: Dictionary) -> void:
	var typ: String = str(e["typ"])
	var eigen: bool = str(e.get("team", "")) == _meine_seite()
	match typ:
		"tor":
			# Ein Heimtor ist lauter als eines der Gäste — die Halle gehört
			# dem Heimverein, und das soll man hören.
			Klang.spiele("jubel", 0.0 if eigen else -9.0)
		"parade", "block":
			Klang.spiele("raunen", -4.0 if eigen else -10.0)
		"fehlwurf":
			if eigen:
				Klang.spiele("raunen", -12.0)
		"zeitstrafe", "rot", "siebenmeter":
			Klang.spiele("pfiff", -4.0)
		"halbzeit", "ende":
			Klang.spiele("pfiff_lang", -2.0)

## Welche Seite dem Trainer gehört — für die Lautstärke des Jubels.
func _meine_seite() -> String:
	if sim == null:
		return "heim"
	return "heim" if str(sim.spiel.get("heim", "")) == Welt.mein_verein_id else "gast"

## Ein kurzer Lichtblitz dort, wo etwas passiert ist.
func _wirkung_zeigen(e: Dictionary) -> void:
	var typ: String = str(e["typ"])
	var seite: String = str(e.get("team", ""))
	match typ:
		"tor":
			feld.aufblitzen(feld.tormitte(seite), Stil.GRUEN, 0.9)
		"parade":
			feld.aufblitzen(feld.tormitte(seite), Stil.BLAU, 0.7)
		"block":
			feld.aufblitzen(feld.spielerpunkt(str(e.get("spieler", ""))), Stil.TUERKIS, 0.6)
		"zeitstrafe", "rot":
			feld.aufblitzen(feld.spielerpunkt(str(e.get("spieler", ""))), Stil.ROT, 0.9)
		"verwarnung":
			feld.aufblitzen(feld.spielerpunkt(str(e.get("spieler", ""))), Stil.GELB, 0.7)
		"ballverlust":
			feld.aufblitzen(feld._ballpunkt(), Stil.GELB, 0.6)

func _ueberspringen() -> void:
	if sim == null or fertig:
		return
	angepfiffen = true
	anpfiff_knopf.visible = false
	uhr.stop()
	_zug.clear()
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
	Klang.halle_aus()
	uhr.stop()
	abschluss_knopf.visible = true
	hinweis.text = "Abpfiff."
	_ansprache_aufbauen(false)
	_stats_auffrischen()

func _abschliessen() -> void:
	if sim == null:
		return
	Welt.partie_abschliessen(mid, sim)
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

## Wie viele Ereignisse gleichzeitig im Ticker stehen.
const TICKER_ZEILEN := 7

func _ereignis_anzeigen(e: Dictionary) -> void:
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
	# Der Ticker haelt nur, was hineinpasst. Vorher standen hundertzwanzig
	# Zeilen in einem Rollbereich, der bei jedem Ereignis ans Ende sprang: die
	# oberste Zeile war dabei immer halb abgeschnitten, und gescrollt hat
	# waehrend eines laufenden Spiels ohnehin niemand. Der vollstaendige
	# Verlauf steht nach dem Schlusspfiff im Spielbericht.
	while ticker.get_child_count() > TICKER_ZEILEN:
		var alt := ticker.get_child(0)
		ticker.remove_child(alt)
		alt.queue_free()

func _ereignisfarbe(e: Dictionary) -> Color:
	var eigene: bool = str(e["team"]) == ("heim" if mein_team == sim.heim else "gast")
	match str(e["typ"]):
		"tor":
			return Stil.GRUEN if eigene else Stil.ROT
		"parade":
			return Stil.BLAU if eigene else Stil.TEXT_MATT
		"zeitstrafe", "rot", "verletzung", "wechselfehler":
			return Stil.ROT if eigene else Stil.GELB
		"verwarnung", "passiv":
			return Stil.GELB
		"auszeit", "taktik", "lauf", "matchplan":
			return Stil.AKZENT
		"halbzeit", "ende", "anwurf":
			return Stil.LILA
	return Stil.TEXT_MATT

## `seite` überschreibt, wer gerade angreift — nötig, weil die Engine dem
## Ticker immer einen Angriff voraus ist.
func _szene_auffrischen(e: Dictionary = {}, seite: String = "") -> void:
	if sim == null:
		return
	var angreift: String = seite if seite != "" else _angreifer_zu(e)
	feld.angreifer = angreift
	feld.setze_szene({
		"heim": _team_szene(sim.heim, angreift == "heim"),
		"gast": _team_szene(sim.gast, angreift == "gast"),
	})
	_aufstellungsleiste_auffrischen(angreift)
	if not e.is_empty() and str(e.get("spieler", "")) != "":
		feld.hervorgehoben = str(e["spieler"])
	if e.is_empty():
		# Neuer Angriff: beide Mannschaften stehen wieder in ihrer Formation,
		# alte Laufwege sind erledigt.
		feld.laufwege_loesen()
		# Der Ball geht zum Aufbauspieler der angreifenden Mannschaft.
		var angreifer: Dictionary = sim.heim if angreift == "heim" else sim.gast
		var aufbau: String = str((angreifer["angriff_auf"] as Dictionary).get("RM", ""))
		if aufbau != "":
			feld.ball_spielen(feld.spielerpunkt(aufbau), maxf(uhr.wait_time, 0.1) * 0.8)
	feld.queue_redraw()

## Wer greift im gezeigten Bild an? Bei einem Angriffsereignis die Mannschaft
## des Ereignisses, sonst das aktuelle Angriffsrecht der Engine.
func _angreifer_zu(e: Dictionary) -> String:
	if not e.is_empty() and ANGRIFFSAUSGANG.has(str(e.get("typ", ""))):
		var seite: String = str(e.get("team", ""))
		if seite == "heim" or seite == "gast":
			return seite
	return sim.angriffsrecht

## Eine Gastfarbe, die sich von der Heimfarbe abhebt.
##
## Zuerst wird die zweite Wappenfarbe versucht — das ist der Ausweichsatz, den
## der Verein ohnehin hat. Taugt auch die nicht, wird aufgehellt oder
## abgedunkelt, je nachdem, wohin mehr Abstand ist.
func _ausweichfarbe(heim: Color, wappen: Dictionary) -> Color:
	var erste: Color = _mindesthelligkeit(wappen.get("a", Color("#4fa8f5")))
	if _farbabstand(heim, erste) >= FARBABSTAND_MIN:
		return erste
	var zweite: Color = _mindesthelligkeit(wappen.get("b", erste))
	if _farbabstand(heim, zweite) >= FARBABSTAND_MIN:
		return zweite
	# Beide zu nah: in die Richtung ausweichen, in der mehr Luft ist.
	var heller: Color = erste.lightened(0.55)
	var dunkler: Color = erste.darkened(0.45)
	var gewaehlt: Color = heller if _farbabstand(heim, heller) > _farbabstand(heim, dunkler) else dunkler
	return _mindesthelligkeit(gewaehlt)

## Ein Trikot darf nicht so dunkel sein, dass es auf dem Parkett verschwindet
## und in der Aufstellungsleiste gar nicht mehr zu lesen ist. Schwarz war als
## Ausweichfarbe rechnerisch am weitesten weg von Gruen — und praktisch
## unbrauchbar.
const HELLIGKEIT_MIN := 0.24

func _mindesthelligkeit(f: Color) -> Color:
	var aus: Color = f
	var schutz := 0
	while aus.get_luminance() < HELLIGKEIT_MIN and schutz < 12:
		aus = aus.lightened(0.14)
		schutz += 1
	return aus

## Wie weit zwei Farben auseinanderliegen. Helligkeit zaehlt doppelt: auf einem
## dunklen Parkett unterscheidet das Auge hell von dunkel zuverlaessiger als
## Blau von Gruen.
const FARBABSTAND_MIN := 0.42

func _farbabstand(a: Color, b: Color) -> float:
	var helligkeit: float = absf(a.get_luminance() - b.get_luminance()) * 2.0
	var farbe: float = (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
	return helligkeit + farbe

## Die Aufstellungsleiste unter dem Feld.
##
## Auf dem Feld selbst ist fuer sechs Abwehrnamen kein Platz — sechs Mann auf
## elf Metern ergeben einen Block, in dem man nichts mehr liest. Hier steht
## dafuer beides vollstaendig: wer angreift und wer verteidigt, mit Position,
## Nummer und Namen, in den Farben der Mannschaften.
func _aufstellungsleiste_auffrischen(angreift: String) -> void:
	if aufstellungsleiste == null or sim == null:
		return
	Bildschirm.leeren(aufstellungsleiste)
	for t in [sim.heim, sim.gast]:
		var greift_an: bool = (angreift == "heim") == (t == sim.heim)
		var farbe: Color = feld.heim_farbe if t == sim.heim else feld.gast_farbe
		var reihe := Stil.hbox(6)
		reihe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reihe.custom_minimum_size = Vector2(0, 22)
		aufstellungsleiste.add_child(reihe)
		var marke := Stil.abzeichen(str(t["kurz"]), farbe)
		marke.custom_minimum_size = Vector2(52, 0)
		reihe.add_child(marke)
		var lage := Stil.matt("Angriff" if greift_an else "Abwehr", Stil.S_MINI)
		lage.custom_minimum_size = Vector2(52, 0)
		reihe.add_child(lage)
		var block: Dictionary = t["angriff_auf"] if greift_an else t["abwehr_auf"]
		for pos in block.keys():
			var sid: String = str(block[pos])
			if sid == "":
				continue
			var sp: Dictionary = Welt.spieler(sid)
			if sp.is_empty():
				continue
			var kuerzel: String = str(Spielerfabrik.ABWEHR_KURZ.get(str(pos), str(pos)))
			var zelle := Stil.hbox(3)
			zelle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			zelle.add_child(Stil.text(kuerzel, Stil.S_MINI, farbe))
			var name := Stil.text("%d %s" % [int(sp.get("nummer", 0)), str(sp["nachname"])], Stil.S_MINI)
			name.clip_text = true
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			zelle.add_child(name)
			reihe.add_child(zelle)

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
		# Der volle Nachname. Frueher stand hier substr(0, 9) — daher "Vind
		# Rasm" und "Wasielews" auf dem Feld. Wie viel Platz ist, weiss das
		# Spielfeld, nicht diese Stelle; gekuerzt wird deshalb erst beim
		# Zeichnen und dann mit Auslassungspunkten.
		# Wo einer steht, sagt sein Abwehrplatz — nicht die Reihenfolge, in der
		# das Woerterbuch seine Schluessel hergibt. Vorher stand der Spieler von
		# A3 auf dem Platz von A1, wenn A3 zufaellig zuerst eingetragen war:
		# auf dem Feld war die Abwehr damit falsch herum aufgereiht.
		var platz: int = i
		if not greift_an and str(pos).begins_with("A") and str(pos).substr(1).is_valid_int():
			platz = clampi(int(str(pos).substr(1)) - 1, 0, 5)
		eintraege[pos] = {"sid": sid, "kurz": str(sp["nachname"]),
			"pos": str(Spielerfabrik.ABWEHR_KURZ.get(str(pos), str(pos))),
			"nummer": int(sp.get("nummer", 0)), "index": 0 if pos == "TW" else platz}
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
##
## Ist eine Ansprache faellig, springt die rechte Spalte selbst dorthin. Eine
## Auszeit zu nehmen und dann den richtigen Reiter suchen zu muessen, waere
## genau die Handgriff-Suche, die eine laufende Uhr nicht verzeiht.
func _ansprache_aufbauen(dringend: bool = false) -> void:
	if ansprache_bereich == null or sim == null:
		return
	if dringend:
		zeige_reiter("ansprache")
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
	# Nach jeder Umstellung muss die Engine ihre vorgerechneten Deckungswerte
	# wegwerfen, sonst spielte die Mannschaft weiter nach der alten Anweisung.
	var umstellen := func(): sim.cache_verwerfen(mein_team)
	taktik_bereich.add_child(_wahl("Abwehr", ["6-0", "5-1", "3-2-1", "4-2"], str(t["abwehr"]), func(w):
		t["abwehr"] = w
		umstellen.call()))
	taktik_bereich.add_child(_wahl("Angriff", ["positionsangriff", "tempospiel", "kreisfokus", "aussenfokus", "rueckraumfokus"],
		str(t["angriff"]), func(w):
			t["angriff"] = w
			umstellen.call()))
	taktik_bereich.add_child(_wahl("Mentalität", ["defensiv", "ausgeglichen", "offensiv", "all-in"],
		str(t["mentalitaet"]), func(w):
			t["mentalitaet"] = w
			umstellen.call()))
	taktik_bereich.add_child(_wahl("7 gegen 6", ["nie", "unterzahl", "rueckstand", "schluss", "immer"],
		str(t["siebter_feldspieler"]), func(w):
			t["siebter_feldspieler"] = w
			sim.sieben_gegen_sechs_pruefen(mein_team)))
	taktik_bereich.add_child(_schieber("Tempo", int(t["tempo"]), func(w): t["tempo"] = int(w)))
	taktik_bereich.add_child(_schieber("Risiko", int(t["risiko"]), func(w): t["risiko"] = int(w)))
	taktik_bereich.add_child(_schieber("Härte", int(t["haerte"]), func(w): t["haerte"] = int(w)))
	_anweisungen_aufbauen()

## Rollen einzelner Spieler auch während der Partie ändern. Platzsparend:
## erst den Spieler wählen, dann seine beiden Anweisungen.
func _anweisungen_aufbauen() -> void:
	var auf_platz: Array = sim.alle_auf_platz(mein_team)
	if auf_platz.is_empty():
		return
	taktik_bereich.add_child(Stil.trenner())
	taktik_bereich.add_child(Stil.matt("Anweisung an einen Spieler", Stil.S_MINI))
	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(272, 0)
	var i := 0
	for sid in auf_platz:
		var sp: Dictionary = Welt.spieler(sid)
		if sp.is_empty() or bool(sp["ist_torwart"]):
			continue
		wahl.add_item("%s %s" % [Trikot.text(sp), Spielerfabrik.kurz_name(sp)])
		wahl.set_item_metadata(i, sid)
		i += 1
	if i == 0:
		return
	var zeile := Stil.hbox(8)
	taktik_bereich.add_child(zeile)
	var l := Stil.matt("Spieler", Stil.S_KLEIN)
	l.custom_minimum_size = Vector2(90, 0)
	zeile.add_child(l)
	zeile.add_child(wahl)
	var felder := Stil.vbox(4)
	taktik_bereich.add_child(felder)
	var zeichnen := func():
		Bildschirm.leeren(felder)
		var sid2: String = str(wahl.get_item_metadata(maxi(wahl.selected, 0)))
		var gesetzt: Dictionary = (mein_team["anweisungen"] as Dictionary).get(sid2, {})
		for bereich in ["angriff", "abwehr"]:
			var katalog: Dictionary = Anweisungen.ANGRIFF if bereich == "angriff" else Anweisungen.ABWEHR
			var namen: Array = []
			var schluessel: Array = katalog.keys()
			for k in schluessel:
				namen.append(str(katalog[k]["name"]))
			var aktuell: String = str(gesetzt.get(bereich, "normal"))
			var z := Stil.hbox(8)
			felder.add_child(z)
			var lb := Stil.matt("Angriff" if bereich == "angriff" else "Abwehr", Stil.S_KLEIN)
			lb.custom_minimum_size = Vector2(90, 0)
			z.add_child(lb)
			var ow := OptionButton.new()
			ow.custom_minimum_size = Vector2(272, 0)
			for j in range(schluessel.size()):
				ow.add_item(str(namen[j]))
				ow.set_item_metadata(j, schluessel[j])
				ow.set_item_tooltip(j, str(katalog[schluessel[j]]["text"]))
				if str(schluessel[j]) == aktuell:
					ow.select(j)
			ow.item_selected.connect(func(idx):
				var neu: String = str(ow.get_item_metadata(idx))
				if not (mein_team["anweisungen"] as Dictionary).has(sid2):
					mein_team["anweisungen"][sid2] = {"angriff": "normal", "abwehr": "normal"}
				(mein_team["anweisungen"][sid2] as Dictionary)[bereich] = neu
				# Die Engine rechnet Anweisungswirkungen nur einmal je
				# Aufstellung aus — nach einer Änderung muss sie neu rechnen.
				sim.cache_verwerfen(mein_team)
				# Auch dauerhaft merken, sonst gilt sie nur diese Partie.
				Anweisungen.setzen(Welt.daten, str(mein_team["cid"]), sid2, bereich, neu)
				hinweis.text = "%s: %s" % [Spielerfabrik.kurz_name(Welt.spieler(sid2)), str(katalog[neu]["name"])])
			z.add_child(ow)
	wahl.item_selected.connect(func(_i): zeichnen.call())
	zeichnen.call()

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

## Angriff und Abwehr getrennt umstellen, mitten in der Partie.
##
## Beide Aufstellungen gab es im Datenmodell laengst, aendern liess sich vor
## dem Anpfiff aber nur die eine und waehrend der Partie gar keine. Wer merkte,
## dass sein Kreislaeufer in der Abwehr auf dem Aussenplatz untergeht, sah
## sechzig Minuten zu.
func _aufstellung_aufbauen() -> void:
	_aufstellung_auffrischen()

func _aufstellung_auffrischen() -> void:
	if sim == null or aufstellung_bereich == null:
		return
	Bildschirm.leeren(aufstellung_bereich)
	aufstellung_bereich.add_child(Stil.matt(
		"Angriff und Abwehr stellen sich getrennt auf. Wer schon im selben Block steht, tauscht die Plätze.",
		Stil.S_MINI))
	var auf_platz: Array = sim.alle_auf_platz(mein_team)
	for block in ["angriff", "abwehr"]:
		var feldname: String = "angriff_auf" if block == "angriff" else "abwehr_auf"
		var auf: Dictionary = mein_team[feldname]
		aufstellung_bereich.add_child(Stil.etikett("Angriff" if block == "angriff" else "Abwehr"))
		var plaetze: Array = auf.keys()
		plaetze.sort()
		for pos in plaetze:
			var zeile := Stil.hbox(6)
			aufstellung_bereich.add_child(zeile)
			var kuerzel: String = str(Spielerfabrik.ABWEHR_KURZ.get(str(pos), str(pos)))
			var l := Stil.text(kuerzel, Stil.S_KLEIN, Stil.AKZENT)
			l.custom_minimum_size = Vector2(38, 0)
			l.tooltip_text = str(Spielerfabrik.ABWEHR_NAME.get(str(pos),
				Spielerfabrik.POSITION_NAME.get(str(pos), str(pos))))
			zeile.add_child(l)
			var wahl := OptionButton.new()
			wahl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var gewaehlt := 0
			var i := 0
			for sid in auf_platz:
				var sp: Dictionary = Welt.spieler(sid)
				if sp.is_empty():
					continue
				# Ein Feldspieler gehoert nicht ins Tor und umgekehrt.
				if (str(pos) == "TW") != bool(sp["ist_torwart"]):
					continue
				var eignung: float = Spielerfabrik.abwehr_eignung(sp, str(pos)) if str(pos).begins_with("A") \
					else (1.0 if str(pos) == "TW" else Spielerfabrik.eignung(sp, str(pos)))
				wahl.add_item("%d %s · %d %%" % [int(sp.get("nummer", 0)), str(sp["nachname"]),
					int(round(eignung * 100.0))])
				wahl.set_item_metadata(i, str(sid))
				if str(sid) == str(auf[pos]):
					gewaehlt = i
				i += 1
			if wahl.item_count == 0:
				zeile.add_child(Stil.matt("niemand verfügbar", Stil.S_MINI))
				continue
			wahl.select(gewaehlt)
			var welcher_block := str(block)
			var welche_pos := str(pos)
			wahl.item_selected.connect(func(idx):
				var erg := sim.position_besetzen(mein_team, welcher_block, welche_pos,
					str(wahl.get_item_metadata(idx)))
				hinweis.text = str(erg["grund"])
				_aufstellung_auffrischen()
				_szene_auffrischen())
			zeile.add_child(wahl)

func _kader_aufbauen() -> void:
	_kader_auffrischen()

func _kader_auffrischen() -> void:
	if sim == null or kader_bereich == null:
		return
	Bildschirm.leeren(kader_bereich)
	kader_bereich.add_child(Stil.matt("Erst einen Spieler auf dem Feld wählen, dann den Ersatzmann.", Stil.S_MINI))
	# Auf der Platte stehen sieben. Wer nur in der anderen Formation steht,
	# gehört zur Rotation und wechselt beim Ballwechsel ein.
	var auf_platz: Array = sim.aktuell_auf_platz(mein_team)
	var rotation: Array = []
	for sid_r in sim.alle_auf_platz(mein_team):
		if not auf_platz.has(sid_r):
			rotation.append(sid_r)
	kader_bereich.add_child(Stil.text("Auf der Platte (%d)" % auf_platz.size(), Stil.S_KLEIN, Stil.AKZENT))
	for sid in auf_platz:
		kader_bereich.add_child(_spielerzeile(sid, true))
	if not rotation.is_empty():
		kader_bereich.add_child(Stil.trenner())
		kader_bereich.add_child(Stil.text("In der Rotation (%d)" % rotation.size(), Stil.S_KLEIN, Stil.TUERKIS))
		for sid_r2 in rotation:
			kader_bereich.add_child(_spielerzeile(sid_r2, true))
	kader_bereich.add_child(Stil.trenner())
	kader_bereich.add_child(Stil.text("Bank (%d)" % (mein_team["bank"] as Array).size(), Stil.S_KLEIN, Stil.AKZENT))
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
	h.add_child(Portraet.fuer_spieler(sid, 21.0))
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
	var box := Stil.hbox(14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_END if ist_heim else BoxContainer.ALIGNMENT_BEGIN
	eltern.add_child(box)
	var halter := Stil.hbox(0)
	halter.custom_minimum_size = Vector2(58, 58)
	var namen := Stil.vbox(2)
	namen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name := Stil.text("", Stil.S_TITEL - 4)
	name.add_theme_font_override("font", Stil.schnitt_halbfett())
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
		halter.add_child(Wappen.fuer_verein(cid, 56.0))
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
func _seite_von_mir() -> String:
	if sim == null:
		return "heim"
	return "heim" if str(sim.heim.get("cid", "")) == Welt.mein_verein_id else "gast"
