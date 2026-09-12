extends Control
## Das Hauptfenster von Hallenherz: Seitenleiste, Kopfzeile und Bildschirmbereich.
##
## Alle Bildschirme werden einmalig erzeugt und bleiben im Baum haengen; gewechselt
## wird ausschliesslich ueber "visible". Dadurch ist jeder Bildschirm von Anfang an
## ansprechbar und es gibt keine doppelt freigegebenen Knoten.

const BEREICHE := [
	{"id": "buero", "name": "Büro", "gruppe": "Verein"},
	{"id": "kader", "name": "Kader", "gruppe": "Verein"},
	{"id": "taktik", "name": "Aufstellung", "gruppe": "Verein"},
	{"id": "training", "name": "Training", "gruppe": "Verein"},
	{"id": "kabine", "name": "Kabine", "gruppe": "Verein"},
	{"id": "jugend", "name": "Nachwuchs", "gruppe": "Verein"},
	{"id": "spielplan", "name": "Spielplan", "gruppe": "Wettbewerb"},
	{"id": "tabellen", "name": "Tabellen", "gruppe": "Wettbewerb"},
	{"id": "pokale", "name": "Pokale & Europa", "gruppe": "Wettbewerb"},
	{"id": "national", "name": "Nationalteams", "gruppe": "Wettbewerb"},
	{"id": "statistik", "name": "Statistiken", "gruppe": "Wettbewerb"},
	{"id": "transfer", "name": "Transfermarkt", "gruppe": "Markt"},
	{"id": "scouting", "name": "Scouting", "gruppe": "Markt"},
	{"id": "finanzen", "name": "Finanzen", "gruppe": "Führung"},
	{"id": "infrastruktur", "name": "Infrastruktur", "gruppe": "Führung"},
	{"id": "personal", "name": "Personal", "gruppe": "Führung"},
	{"id": "vorstand", "name": "Vorstand", "gruppe": "Führung"},
	{"id": "karriere", "name": "Karriere", "gruppe": "Führung"},
	{"id": "medien", "name": "Medien", "gruppe": "Umfeld"},
	{"id": "chronik", "name": "Chronik", "gruppe": "Umfeld"},
	{"id": "nachrichten", "name": "Nachrichten", "gruppe": "Umfeld"},
	{"id": "system", "name": "Spielstand", "gruppe": "Umfeld"},
	{"id": "daten", "name": "Kaderdaten", "gruppe": "Umfeld"},
]

var bildschirme: Dictionary = {}
var aktueller: String = ""
var inhalt: MarginContainer
var navigation: VBoxContainer
var kopf: Control
var kopf_wappen: Control
var kopf_wappen_halter: Control
var kopf_verein: Label
var kopf_liga: Label
var kopf_kasse: Label
var kopf_datum: Label
var kopf_saison: Label
var kopf_glocke: Button
var seitenfuss: Label
var trainerbild: Control
var seitenfuss_ruf: Label
var weiter_knopf: Button
var nav_knoepfe: Dictionary = {}
var startbildschirm: Control
var rahmen: Control
var live: Control

func _ready() -> void:
	theme = Stil.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var hintergrund := ColorRect.new()
	hintergrund.color = Stil.GRUND
	hintergrund.set_anchors_preset(Control.PRESET_FULL_RECT)
	hintergrund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hintergrund)

	_baue_rahmen()
	_baue_startbildschirm()
	add_child(Spielerfenster.new())
	add_child(Vereinsfenster.new())
	add_child(Spielbericht.new())
	add_child(Pressefenster.new())
	add_child(Vorberichtsfenster.new())
	add_child(Verhandlungsfenster.new())
	var vorspulen := Vorspulfenster.new()
	vorspulen.vorgespult.connect(_auffrischen)
	add_child(vorspulen)
	live = LiveSpiel.new()
	live.visible = false
	add_child(live)
	live.beendet.connect(_auf_live_ende)

	Welt.zustand_geaendert.connect(_auffrischen)
	Welt.nachricht_eingegangen.connect(func(_n): _kopf_auffrischen())
	Welt.live_spiel_faellig.connect(_starte_live)
	_zeige_start(true)

# ------------------------------------------------------------------ Rahmen ---

func _baue_rahmen() -> void:
	rahmen = HBoxContainer.new()
	rahmen.set_anchors_preset(Control.PRESET_FULL_RECT)
	rahmen.add_theme_constant_override("separation", 0)
	add_child(rahmen)

	_baue_seitenleiste()

	var rechts := VBoxContainer.new()
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rechts.add_theme_constant_override("separation", 0)
	rahmen.add_child(rechts)

	_baue_kopfzeile(rechts)

	inhalt = MarginContainer.new()
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inhalt.add_theme_constant_override("margin_left", 18)
	inhalt.add_theme_constant_override("margin_right", 18)
	inhalt.add_theme_constant_override("margin_top", 16)
	inhalt.add_theme_constant_override("margin_bottom", 16)
	rechts.add_child(inhalt)
	_baue_bildschirme()

## Linke Spalte: Wortmarke, Navigation nach Gruppen, Trainerzeile unten.
func _baue_seitenleiste() -> void:
	var navpanel := PanelContainer.new()
	navpanel.custom_minimum_size = Vector2(212, 0)
	navpanel.add_theme_stylebox_override("panel",
		Stil.box_kante(Stil.FLAECHE_TIEF, "rechts", Stil.RAND))
	rahmen.add_child(navpanel)

	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 0)
	navpanel.add_child(spalte)

	# Wortmarke
	var marke := PanelContainer.new()
	var mbox := Stil.box_kante(Color(0, 0, 0, 0), "unten", Stil.RAND)
	mbox.content_margin_left = 16
	mbox.content_margin_right = 14
	mbox.content_margin_top = 12
	mbox.content_margin_bottom = 12
	marke.add_theme_stylebox_override("panel", mbox)
	spalte.add_child(marke)
	var mzeile := Stil.hbox(9)
	marke.add_child(mzeile)
	var puls := Stil.Marke.new()
	puls.custom_minimum_size = Vector2(4, 24)
	puls.farbe = Stil.AKZENT
	mzeile.add_child(puls)
	var mtext := Stil.vbox(0)
	mzeile.add_child(mtext)
	var wort := Stil.text("HALLENHERZ", Stil.S_GROSS, Stil.TEXT)
	mtext.add_child(wort)
	mtext.add_child(Stil.etikett("Handball Manager"))

	var navscroll := ScrollContainer.new()
	navscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	navscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spalte.add_child(navscroll)
	navigation = Stil.vbox(1)
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navscroll.add_child(navigation)
	_baue_navigation()

	# Fusszeile: wer hier eigentlich arbeitet
	var fuss := PanelContainer.new()
	var fbox := Stil.box_kante(Color(0, 0, 0, 0), "oben", Stil.RAND)
	fbox.content_margin_left = 16
	fbox.content_margin_right = 14
	fbox.content_margin_top = 10
	fbox.content_margin_bottom = 11
	fuss.add_theme_stylebox_override("panel", fbox)
	spalte.add_child(fuss)
	var fzeile := Stil.hbox(9)
	fuss.add_child(fzeile)
	trainerbild = Stil.hbox(0)
	trainerbild.custom_minimum_size = Vector2(34, 34)
	fzeile.add_child(trainerbild)
	var fspalte := Stil.vbox(1)
	fspalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fzeile.add_child(fspalte)
	seitenfuss = Stil.text("", Stil.S_KLEIN, Stil.TEXT)
	fspalte.add_child(seitenfuss)
	seitenfuss_ruf = Stil.matt("", Stil.S_MINI)
	fspalte.add_child(seitenfuss_ruf)

func _baue_navigation() -> void:
	var letzte_gruppe := ""
	for b in BEREICHE:
		if str(b["gruppe"]) != letzte_gruppe:
			letzte_gruppe = str(b["gruppe"])
			navigation.add_child(Stil.abstand(9))
			navigation.add_child(Stil.etikett("   " + letzte_gruppe))
			navigation.add_child(Stil.abstand(1))
		var id: String = str(b["id"])
		var knopf := NavKnopf.neu(id, str(b["name"]))
		knopf.pressed.connect(func():
			Klang.spiele("blaettern", 0.5)
			zeige(id))
		navigation.add_child(knopf)
		nav_knoepfe[id] = knopf
	navigation.add_child(Stil.abstand(8))

## Obere Leiste: Vereinsidentitaet links, Lage und Aktionen rechts.
func _baue_kopfzeile(eltern: Node) -> void:
	var kopfpanel := PanelContainer.new()
	var kopfbox := Stil.box_kante(Stil.FLAECHE, "unten", Stil.RAND)
	kopfbox.content_margin_left = 18
	kopfbox.content_margin_right = 18
	kopfbox.content_margin_top = 10
	kopfbox.content_margin_bottom = 10
	kopfpanel.add_theme_stylebox_override("panel", kopfbox)
	eltern.add_child(kopfpanel)
	kopf = kopfpanel

	var zeile := Stil.hbox(14)
	kopfpanel.add_child(zeile)

	kopf_wappen_halter = Stil.hbox(0)
	kopf_wappen_halter.custom_minimum_size = Vector2(36, 36)
	zeile.add_child(kopf_wappen_halter)

	var namen := Stil.vbox(0)
	namen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(namen)
	kopf_verein = Stil.text("", Stil.S_GROSS, Stil.TEXT)
	namen.add_child(kopf_verein)
	kopf_liga = Stil.matt("", Stil.S_MINI)
	namen.add_child(kopf_liga)

	zeile.add_child(Stil.dehner())

	kopf_kasse = _kopf_wert(zeile, "Kasse")
	zeile.add_child(_kopf_strich())
	kopf_datum = _kopf_wert(zeile, "Spieltag")
	zeile.add_child(_kopf_strich())
	kopf_saison = _kopf_wert(zeile, "Saison")
	zeile.add_child(Stil.abstand(4))

	kopf_glocke = Button.new()
	kopf_glocke.flat = true
	kopf_glocke.custom_minimum_size = Vector2(38, 34)
	kopf_glocke.focus_mode = Control.FOCUS_NONE
	kopf_glocke.tooltip_text = "Nachrichten"
	kopf_glocke.add_theme_stylebox_override("normal", Stil.box_leer())
	kopf_glocke.add_theme_stylebox_override("hover", Stil.box(Stil.lasur(Stil.TEXT, 0.07), Stil.R_KLEIN))
	kopf_glocke.add_theme_stylebox_override("pressed", Stil.box(Stil.lasur(Stil.AKZENT, 0.14), Stil.R_KLEIN))
	kopf_glocke.pressed.connect(func(): zeige("nachrichten"))
	var g := Symbol.neu("glocke", 19.0, Stil.TEXT_MATT)
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	kopf_glocke.add_child(g)
	kopf_glocke.set_meta("symbol", g)
	zeile.add_child(kopf_glocke)

	var spulen := Button.new()
	spulen.flat = true
	spulen.custom_minimum_size = Vector2(38, 34)
	spulen.focus_mode = Control.FOCUS_NONE
	spulen.tooltip_text = "Zu einem Datum vorspulen"
	spulen.add_theme_stylebox_override("normal", Stil.box_leer())
	spulen.add_theme_stylebox_override("hover", Stil.box(Stil.lasur(Stil.TEXT, 0.07), Stil.R_KLEIN))
	spulen.add_theme_stylebox_override("pressed", Stil.box(Stil.lasur(Stil.AKZENT, 0.14), Stil.R_KLEIN))
	spulen.pressed.connect(func(): Vorspulfenster.oeffnen(self))
	var ssym := Symbol.neu("doppelpfeil", 19.0, Stil.TEXT_MATT)
	ssym.set_anchors_preset(Control.PRESET_FULL_RECT)
	spulen.add_child(ssym)
	zeile.add_child(spulen)

	weiter_knopf = Stil.knopf_primaer("Weiter")
	weiter_knopf.pressed.connect(_weiter)
	weiter_knopf.tooltip_text = "Einen Tag weiterschalten (Leertaste)"
	zeile.add_child(weiter_knopf)

## Etikett ueber Wert — die Statusanzeigen der Kopfzeile.
func _kopf_wert(eltern: Node, beschriftung: String) -> Label:
	var v := Stil.vbox(0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eltern.add_child(v)
	v.add_child(Stil.etikett(beschriftung))
	var l := Stil.text("—", Stil.S_KLEIN, Stil.TEXT)
	v.add_child(l)
	return l

func _kopf_strich() -> Control:
	var s := VSeparator.new()
	s.add_theme_constant_override("separation", 10)
	return s

func _baue_bildschirme() -> void:
	var liste := {
		"buero": BueroBildschirm, "kader": KaderBildschirm, "taktik": TaktikBildschirm,
		"training": TrainingBildschirm, "kabine": KabinenBildschirm, "jugend": JugendBildschirm, "spielplan": SpielplanBildschirm,
		"tabellen": TabellenBildschirm, "pokale": PokalBildschirm, "national": NationalBildschirm,
		"statistik": StatistikBildschirm, "transfer": TransferBildschirm,
		"scouting": ScoutingBildschirm, "finanzen": FinanzBildschirm,
		"infrastruktur": InfrastrukturBildschirm, "personal": PersonalBildschirm,
		"vorstand": VorstandsBildschirm, "karriere": KarriereBildschirm, "medien": MedienBildschirm,
		"chronik": ChronikBildschirm, "nachrichten": NachrichtenBildschirm, "system": SystemBildschirm,
		"daten": DatenBildschirm,
	}
	for id in liste.keys():
		var b = liste[id].new()
		b.visible = false
		inhalt.add_child(b)
		b.bereit()
		bildschirme[id] = b

# ------------------------------------------------------------ Startmenue ---

func _baue_startbildschirm() -> void:
	startbildschirm = StartBildschirm.new()
	add_child(startbildschirm)
	startbildschirm.spiel_gestartet.connect(func():
		_zeige_start(false)
		zeige("buero"))

func _zeige_start(an: bool) -> void:
	startbildschirm.visible = an
	rahmen.visible = not an
	if an:
		startbildschirm.aktualisieren()
		Klang.musik_start()
	else:
		Klang.musik_stop()

# --------------------------------------------------------------- Wechsel ---

func zeige(id: String) -> void:
	if not bildschirme.has(id):
		return
	if aktueller != "" and bildschirme.has(aktueller):
		bildschirme[aktueller].visible = false
		if nav_knoepfe.has(aktueller):
			nav_knoepfe[aktueller].setze_aktiv(false)
	aktueller = id
	bildschirme[id].visible = true
	bildschirme[id].aktualisieren()
	if nav_knoepfe.has(id):
		nav_knoepfe[id].setze_aktiv(true)
	_kopf_auffrischen()

func _auffrischen() -> void:
	_kopf_auffrischen()
	if aktueller != "" and bildschirme.has(aktueller):
		bildschirme[aktueller].aktualisieren()

func _kopf_auffrischen() -> void:
	if not Welt.laeuft:
		return
	var t: Dictionary = Welt.trainer()
	seitenfuss.text = Trainerkarriere.voller_name(t)
	seitenfuss_ruf.text = Trainerkarriere.ruf_stufe(float(t.get("ruf", 0.0)))
	for k in trainerbild.get_children():
		k.queue_free()
	trainerbild.add_child(Portraet.fuer_trainer(t, 32.0))

	var v: Dictionary = Welt.mein_verein()
	if kopf_wappen != null:
		kopf_wappen.queue_free()
		kopf_wappen = null
	if v.is_empty():
		kopf_verein.text = "Ohne Verein"
		kopf_liga.text = "auf Vereinssuche"
		kopf_kasse.text = "—"
	else:
		kopf_wappen = Wappen.fuer_verein(Welt.mein_verein_id, 34.0)
		kopf_wappen_halter.add_child(kopf_wappen)
		kopf_verein.text = str(v["name"])
		kopf_liga.text = Welt.wettbewerb_name(str(v["liga"]))
		kopf_kasse.text = Stil.geld(float(v["kasse"]))
		kopf_kasse.add_theme_color_override("font_color",
			Stil.TEXT if float(v["kasse"]) >= 0.0 else Stil.ROT)
	kopf_datum.text = Welt.datum_text()
	kopf_saison.text = Welt.saison_text()

	var offen: int = Welt.ungelesene_nachrichten()
	if nav_knoepfe.has("nachrichten"):
		nav_knoepfe["nachrichten"].setze_zaehler(offen)
	if kopf_glocke.has_meta("symbol"):
		(kopf_glocke.get_meta("symbol") as Symbol).setze_farbe(Stil.AKZENT if offen > 0 else Stil.TEXT_MATT)
	kopf_glocke.tooltip_text = "%d ungelesene Nachricht(en)" % offen if offen > 0 else "Nachrichten"

	var naechstes: Dictionary = Welt.naechstes_spiel(Welt.mein_verein_id) if Welt.mein_verein_id != "" else {}
	if not naechstes.is_empty() and int(naechstes["tag"]) == Welt.tag():
		weiter_knopf.text = "Zum Spiel"
	else:
		weiter_knopf.text = "Weiter"

# ------------------------------------------------------------- Zeitablauf ---

func _weiter() -> void:
	if not Welt.laeuft:
		return
	weiter_knopf.disabled = true
	Klang.spiele("klick", 0.6)
	var unterbrechung := Welt.tag_weiter()
	weiter_knopf.disabled = false
	if unterbrechung.has("art"):
		match str(unterbrechung["art"]):
			"eigenes_spiel":
				_starte_live(str(unterbrechung["spiel"]))
				return
			"saisonende":
				zeige("tabellen")
			"neue_saison":
				zeige("buero")
	_auffrischen()

func _starte_live(spiel_id: String) -> void:
	rahmen.visible = false
	live.visible = true
	live.starte(spiel_id)

func _auf_live_ende(_spiel_id: String) -> void:
	live.visible = false
	rahmen.visible = true
	Welt.spieltag_abwickeln(Welt.tag())
	Welt.wochenrhythmus(Welt.tag())
	Welt.saison_pruefen(Welt.tag())
	_auffrischen()
	if bildschirme.has("buero"):
		zeige("buero")

func _unhandled_input(ereignis: InputEvent) -> void:
	if not Welt.laeuft or not rahmen.visible:
		return
	if ereignis is InputEventKey and ereignis.pressed and not ereignis.echo:
		if ereignis.keycode == KEY_SPACE:
			_weiter()
			get_viewport().set_input_as_handled()
