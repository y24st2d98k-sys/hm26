extends Control
## Das Hauptfenster von Hallenherz: Kopfzeile, Navigation und Bildschirmbereich.
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
	{"id": "spielplan", "name": "Spielplan", "gruppe": "Wettbewerb"},
	{"id": "tabellen", "name": "Tabellen", "gruppe": "Wettbewerb"},
	{"id": "pokale", "name": "Pokale & Europa", "gruppe": "Wettbewerb"},
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
]

var bildschirme: Dictionary = {}
var aktueller: String = ""
var inhalt: MarginContainer
var navigation: VBoxContainer
var kopf: Control
var kopf_verein: Label
var kopf_datum: Label
var kopf_kasse: Label
var kopf_nachrichten: Button
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
	rahmen = VBoxContainer.new()
	rahmen.set_anchors_preset(Control.PRESET_FULL_RECT)
	rahmen.add_theme_constant_override("separation", 0)
	add_child(rahmen)

	# Kopfzeile
	var kopfpanel := PanelContainer.new()
	var kopfbox := Stil.box(Stil.FLAECHE, 0, Stil.RAND)
	kopfbox.content_margin_left = 16
	kopfbox.content_margin_right = 16
	kopfbox.content_margin_top = 10
	kopfbox.content_margin_bottom = 10
	kopfpanel.add_theme_stylebox_override("panel", kopfbox)
	rahmen.add_child(kopfpanel)
	kopf = kopfpanel
	var kopfzeile := Stil.hbox(16)
	kopfpanel.add_child(kopfzeile)

	var marke := Stil.titel("HALLENHERZ", 1, Stil.AKZENT)
	marke.add_theme_font_size_override("font_size", Stil.S_GROSS)
	kopfzeile.add_child(marke)
	kopfzeile.add_child(VSeparator.new())
	kopf_verein = Stil.text("", Stil.S_NORMAL)
	kopfzeile.add_child(kopf_verein)
	kopfzeile.add_child(Stil.dehner())
	kopf_kasse = Stil.text("", Stil.S_KLEIN, Stil.TEXT_MATT)
	kopfzeile.add_child(kopf_kasse)
	kopf_datum = Stil.text("", Stil.S_KLEIN, Stil.TEXT_MATT)
	kopfzeile.add_child(kopf_datum)
	kopf_nachrichten = Stil.knopf("Nachrichten")
	kopf_nachrichten.pressed.connect(func(): zeige("nachrichten"))
	kopfzeile.add_child(kopf_nachrichten)
	weiter_knopf = Stil.knopf_primaer("Weiter ▶")
	weiter_knopf.pressed.connect(_weiter)
	kopfzeile.add_child(weiter_knopf)

	# Hauptbereich: Navigation + Inhalt
	var haupt := HBoxContainer.new()
	haupt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	haupt.add_theme_constant_override("separation", 0)
	rahmen.add_child(haupt)

	var navpanel := PanelContainer.new()
	navpanel.custom_minimum_size = Vector2(186, 0)
	navpanel.add_theme_stylebox_override("panel", Stil.box(Stil.FLAECHE_TIEF, 0, Stil.RAND))
	haupt.add_child(navpanel)
	var navscroll := ScrollContainer.new()
	navscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	navpanel.add_child(navscroll)
	navigation = Stil.vbox(2)
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navscroll.add_child(navigation)
	_baue_navigation()

	inhalt = MarginContainer.new()
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inhalt.add_theme_constant_override("margin_left", 14)
	inhalt.add_theme_constant_override("margin_right", 14)
	inhalt.add_theme_constant_override("margin_top", 12)
	inhalt.add_theme_constant_override("margin_bottom", 12)
	haupt.add_child(inhalt)
	_baue_bildschirme()

func _baue_navigation() -> void:
	var letzte_gruppe := ""
	for b in BEREICHE:
		if str(b["gruppe"]) != letzte_gruppe:
			letzte_gruppe = str(b["gruppe"])
			var l := Stil.matt("  " + letzte_gruppe.to_upper(), Stil.S_MINI)
			l.add_theme_color_override("font_color", Stil.TEXT_SCHWACH)
			navigation.add_child(Stil.abstand(8))
			navigation.add_child(l)
		var knopf := Button.new()
		knopf.text = "  " + str(b["name"])
		knopf.alignment = HORIZONTAL_ALIGNMENT_LEFT
		knopf.flat = true
		knopf.add_theme_color_override("font_color", Stil.TEXT_MATT)
		knopf.add_theme_color_override("font_hover_color", Stil.AKZENT)
		var id: String = str(b["id"])
		knopf.pressed.connect(func(): zeige(id))
		navigation.add_child(knopf)
		nav_knoepfe[id] = knopf

func _baue_bildschirme() -> void:
	var liste := {
		"buero": BueroBildschirm, "kader": KaderBildschirm, "taktik": TaktikBildschirm,
		"training": TrainingBildschirm, "kabine": KabinenBildschirm, "spielplan": SpielplanBildschirm,
		"tabellen": TabellenBildschirm, "pokale": PokalBildschirm, "transfer": TransferBildschirm,
		"scouting": ScoutingBildschirm, "finanzen": FinanzBildschirm,
		"infrastruktur": InfrastrukturBildschirm, "personal": PersonalBildschirm,
		"vorstand": VorstandsBildschirm, "karriere": KarriereBildschirm, "medien": MedienBildschirm,
		"chronik": ChronikBildschirm, "nachrichten": NachrichtenBildschirm, "system": SystemBildschirm,
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

# --------------------------------------------------------------- Wechsel ---

func zeige(id: String) -> void:
	if not bildschirme.has(id):
		return
	if aktueller != "" and bildschirme.has(aktueller):
		bildschirme[aktueller].visible = false
		if nav_knoepfe.has(aktueller):
			nav_knoepfe[aktueller].add_theme_color_override("font_color", Stil.TEXT_MATT)
	aktueller = id
	bildschirme[id].visible = true
	bildschirme[id].aktualisieren()
	if nav_knoepfe.has(id):
		nav_knoepfe[id].add_theme_color_override("font_color", Stil.AKZENT)
	_kopf_auffrischen()

func _auffrischen() -> void:
	_kopf_auffrischen()
	if aktueller != "" and bildschirme.has(aktueller):
		bildschirme[aktueller].aktualisieren()

func _kopf_auffrischen() -> void:
	if not Welt.laeuft:
		return
	var v: Dictionary = Welt.mein_verein()
	if v.is_empty():
		kopf_verein.text = "%s — ohne Verein" % Trainerkarriere.voller_name(Welt.trainer())
		kopf_kasse.text = ""
	else:
		kopf_verein.text = "%s  ·  %s" % [v["name"], Welt.wettbewerb_name(str(v["liga"]))]
		kopf_kasse.text = "Kasse: %s" % Stil.geld(float(v["kasse"]))
	kopf_datum.text = "%s  ·  Saison %s" % [Welt.datum_text(), Welt.saison_text()]
	var offen: int = Welt.ungelesene_nachrichten()
	kopf_nachrichten.text = "Nachrichten (%d)" % offen if offen > 0 else "Nachrichten"
	kopf_nachrichten.add_theme_color_override("font_color", Stil.AKZENT if offen > 0 else Stil.TEXT)
	var naechstes: Dictionary = Welt.naechstes_spiel(Welt.mein_verein_id) if Welt.mein_verein_id != "" else {}
	if not naechstes.is_empty() and int(naechstes["tag"]) == Welt.tag():
		weiter_knopf.text = "Zum Spiel ▶"
	else:
		weiter_knopf.text = "Weiter ▶"

# ------------------------------------------------------------- Zeitablauf ---

func _weiter() -> void:
	if not Welt.laeuft:
		return
	weiter_knopf.disabled = true
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

func _auf_live_ende(spiel_id: String) -> void:
	live.visible = false
	rahmen.visible = true
	Welt.spieltag_abwickeln(Welt.tag())
	Welt._wochenrhythmus(Welt.tag())
	Welt._saison_pruefen(Welt.tag())
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
