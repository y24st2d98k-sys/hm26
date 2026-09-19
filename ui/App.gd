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
	{"id": "analyse", "name": "Analyse", "gruppe": "Wettbewerb"},
	{"id": "transfer", "name": "Transfermarkt", "gruppe": "Markt"},
	{"id": "scouting", "name": "Scouting", "gruppe": "Markt"},
	{"id": "finanzen", "name": "Finanzen", "gruppe": "Führung"},
	{"id": "halle", "name": "Halle & Fans", "gruppe": "Führung"},
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
## Läuft gerade ein Tageswechsel? Verhindert doppelte Auslösung.
var _tag_laeuft: bool = false
## Wie viele Partien je Einzelbild gerechnet werden. Vier Partien sind rund
## hundert Millisekunden — spürbar flüssig und trotzdem zügig durch.
const SPIELTAG_SCHEIBE := 4
const WECHSEL_DAUER := 0.14
const WECHSEL_HUB := 10
const INHALT_RAND_OBEN := 22
var _wechsel: Tween = null
var _hilfe_schleier: Control
var _spieltag_schleier: Control
var _spieltag_balken: Control
var _spieltag_text: Label

func _ready() -> void:
	theme = Stil.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Stil.grundflaeche())

	_baue_rahmen()
	_baue_startbildschirm()
	add_child(Spielerfenster.new())
	add_child(Vereinsfenster.new())
	add_child(Spielbericht.new())
	add_child(Pressefenster.new())
	add_child(Vorberichtsfenster.new())
	add_child(Verhandlungsfenster.new())
	add_child(Anliegenfenster.new())
	add_child(Nachrichtenfenster.new())
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
	inhalt.add_theme_constant_override("margin_left", 26)
	inhalt.add_theme_constant_override("margin_right", 24)
	inhalt.add_theme_constant_override("margin_top", INHALT_RAND_OBEN)
	inhalt.add_theme_constant_override("margin_bottom", 20)
	rechts.add_child(inhalt)
	_baue_bildschirme()

## Linke Spalte: Wortmarke, Navigation nach Gruppen, Trainerzeile unten.
func _baue_seitenleiste() -> void:
	var navpanel := PanelContainer.new()
	navpanel.custom_minimum_size = Vector2(238, 0)
	# Kein Strich nach rechts: die Leiste liegt tiefer als der Inhalt, und der
	# Schatten sagt das deutlicher als eine Linie.
	var navbox := Stil.box(Stil.FLAECHE_TIEF, 0)
	navbox.shadow_color = Color(0, 0, 0, 0.6)
	navbox.shadow_size = 22
	navbox.shadow_offset = Vector2(4, 0)
	navpanel.add_theme_stylebox_override("panel", navbox)
	rahmen.add_child(navpanel)

	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 0)
	navpanel.add_child(spalte)

	# Wortmarke
	var marke := PanelContainer.new()
	var mbox := Stil.box(Color(0, 0, 0, 0), 0)
	mbox.content_margin_left = 20
	mbox.content_margin_right = 16
	mbox.content_margin_top = 20
	mbox.content_margin_bottom = 18
	marke.add_theme_stylebox_override("panel", mbox)
	spalte.add_child(marke)
	var mzeile := Stil.hbox(11)
	marke.add_child(mzeile)
	var puls := Stil.wortzeichen()
	puls.custom_minimum_size = Vector2(32, 32)
	puls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mzeile.add_child(puls)
	var mtext := Stil.vbox(1)
	mtext.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mzeile.add_child(mtext)
	var wort := Stil.text("HALLENHERZ", Stil.S_GROSS, Stil.TEXT)
	wort.add_theme_font_override("font", Stil.schnitt_fett())
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
	var fbox := Stil.box(Stil.lasur(Stil.TEXT, 0.035), 0)
	fbox.content_margin_left = 18
	fbox.content_margin_right = 14
	fbox.content_margin_top = 13
	fbox.content_margin_bottom = 14
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
			navigation.add_child(Stil.abstand(14))
			var rubrik := Stil.etikett("    " + letzte_gruppe, Stil.TEXT_SCHWACH)
			navigation.add_child(rubrik)
			navigation.add_child(Stil.abstand(4))
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
	var kopfbox := Stil.box(Stil.FLAECHE, 0)
	# Der Kopf soll über dem Inhalt liegen, nicht neben ihm. Ein Schatten nach
	# unten trennt die Zone deutlicher als jede Linie und kostet nichts.
	kopfbox.shadow_color = Color(0, 0, 0, 0.45)
	kopfbox.shadow_size = 12
	kopfbox.shadow_offset = Vector2(0, 4)
	kopfbox.content_margin_left = 24
	kopfbox.content_margin_right = 22
	kopfbox.content_margin_top = 14
	kopfbox.content_margin_bottom = 14
	kopfpanel.add_theme_stylebox_override("panel", kopfbox)
	eltern.add_child(kopfpanel)
	kopf = kopfpanel

	var zeile := Stil.hbox(16)
	kopfpanel.add_child(zeile)

	kopf_wappen_halter = Stil.hbox(0)
	kopf_wappen_halter.custom_minimum_size = Vector2(42, 42)
	zeile.add_child(kopf_wappen_halter)

	var namen := Stil.vbox(0)
	namen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(namen)
	kopf_verein = Stil.text("", Stil.S_GROSS, Stil.TEXT)
	kopf_verein.add_theme_font_override("font", Stil.schnitt_halbfett())
	namen.add_child(kopf_verein)
	kopf_liga = Stil.matt("", Stil.S_MINI)
	namen.add_child(kopf_liga)

	zeile.add_child(Stil.dehner())

	kopf_kasse = _kopf_wert(zeile, "Kasse")
	kopf_datum = _kopf_wert(zeile, "Spieltag")
	kopf_saison = _kopf_wert(zeile, "Saison")
	zeile.add_child(Stil.abstand(6))

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

	# Hilfe muss sichtbar sein, sonst findet F1 niemand.
	var hilfe := Button.new()
	hilfe.flat = true
	hilfe.text = "?"
	hilfe.custom_minimum_size = Vector2(34, 34)
	hilfe.focus_mode = Control.FOCUS_NONE
	hilfe.tooltip_text = "Kurzanleitung und Tastenkürzel (F1)"
	hilfe.add_theme_stylebox_override("normal", Stil.box_leer())
	hilfe.add_theme_stylebox_override("hover", Stil.box(Stil.lasur(Stil.TEXT, 0.07), Stil.R_KLEIN))
	hilfe.add_theme_stylebox_override("pressed", Stil.box(Stil.lasur(Stil.AKZENT, 0.14), Stil.R_KLEIN))
	hilfe.add_theme_color_override("font_color", Stil.TEXT_MATT)
	hilfe.pressed.connect(func(): _hilfe_umschalten())
	zeile.add_child(hilfe)

	weiter_knopf = Stil.knopf_primaer("Weiter")
	weiter_knopf.pressed.connect(_weiter)
	weiter_knopf.tooltip_text = "Einen Tag weiterschalten (Leertaste)"
	zeile.add_child(weiter_knopf)

## Etikett ueber Wert — die Statusanzeigen der Kopfzeile.
## Eine Statusanzeige der Kopfzeile.
##
## Vorher standen die drei Werte nackt nebeneinander, getrennt durch senkrechte
## Striche. Als abgesetzte Flaechen lesen sie sich als das, was sie sind: drei
## Anzeigen, nicht ein Satz — und die Striche fallen weg.
func _kopf_wert(eltern: Node, beschriftung: String) -> Label:
	var p := PanelContainer.new()
	var sb := Stil.box(Stil.FLAECHE_HOCH, Stil.R_KLEIN)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eltern.add_child(p)
	var v := Stil.vbox(1)
	p.add_child(v)
	v.add_child(Stil.etikett(beschriftung))
	var l := Stil.text("—", Stil.S_KLEIN, Stil.TEXT)
	l.add_theme_font_override("font", Stil.schnitt_halbfett())
	v.add_child(l)
	return l


func _baue_bildschirme() -> void:
	var liste := {
		"buero": BueroBildschirm, "kader": KaderBildschirm, "taktik": TaktikBildschirm,
		"training": TrainingBildschirm, "kabine": KabinenBildschirm, "jugend": JugendBildschirm, "spielplan": SpielplanBildschirm,
		"tabellen": TabellenBildschirm, "pokale": PokalBildschirm, "national": NationalBildschirm,
		"statistik": StatistikBildschirm, "transfer": TransferBildschirm,
		"scouting": ScoutingBildschirm, "finanzen": FinanzBildschirm,
		"infrastruktur": InfrastrukturBildschirm, "personal": PersonalBildschirm,
		"halle": HallenBildschirm,
		"vorstand": VorstandsBildschirm, "karriere": KarriereBildschirm, "medien": MedienBildschirm,
		"chronik": ChronikBildschirm, "nachrichten": NachrichtenBildschirm, "system": SystemBildschirm,
		"analyse": AnalyseBildschirm, "daten": DatenBildschirm,
	}
	add_to_group("app")
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
	_einblenden(bildschirme[id])

## Bildschirmwechsel mit kurzer Bewegung.
##
## Ein harter Schnitt liest sich wie ein Formularwechsel: der Inhalt ist
## plötzlich ein anderer, und das Auge muss sich neu sortieren. 140 ms
## Aufblenden mit einem Hauch Aufwärtsbewegung genügen, damit der Wechsel als
## Handlung wahrgenommen wird. Länger wäre Selbstzweck — in einer Saison
## klickt man hier hunderte Male.
func _einblenden(bildschirm: CanvasItem) -> void:
	if _wechsel != null and _wechsel.is_valid():
		_wechsel.kill()
	bildschirm.modulate = Color(1, 1, 1, 0)
	inhalt.add_theme_constant_override("margin_top", INHALT_RAND_OBEN + WECHSEL_HUB)
	_wechsel = create_tween()
	_wechsel.set_parallel(true)
	_wechsel.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_wechsel.tween_property(bildschirm, "modulate:a", 1.0, WECHSEL_DAUER)
	_wechsel.tween_method(_wechsel_hub, WECHSEL_HUB, 0, WECHSEL_DAUER)

func _wechsel_hub(hub: int) -> void:
	inhalt.add_theme_constant_override("margin_top", INHALT_RAND_OBEN + hub)

## Beendet laufende Übergänge sofort. Werkzeuge, die Bilder aufnehmen oder
## Geometrie vermessen, dürfen keinen halben Frame erwischen.
func bewegung_beenden() -> void:
	if _wechsel != null and _wechsel.is_valid():
		_wechsel.custom_step(WECHSEL_DAUER * 2.0)
		_wechsel.kill()
	_wechsel_hub(0)
	if aktueller != "" and bildschirme.has(aktueller):
		bildschirme[aktueller].modulate = Color(1, 1, 1, 1)

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
		nav_knoepfe["nachrichten"].tooltip_text = ("%d ungelesene Nachricht(en)" % offen) if offen > 0 else "Posteingang"
	if nav_knoepfe.has("kabine"):
		var gespraeche: int = Anliegen.anzahl(Welt.daten)
		nav_knoepfe["kabine"].setze_zaehler(gespraeche)
		# Eine Zahl ohne Erklaerung ist eine Aufgabe ohne Anleitung.
		nav_knoepfe["kabine"].tooltip_text = ("%d Spieler möchten Sie sprechen — in der Kabine unter „Gespräche“" % gespraeche) if gespraeche > 0 else "Kabinenklima, Wortführer, Gruppen"
	if kopf_glocke.has_meta("symbol"):
		(kopf_glocke.get_meta("symbol") as Symbol).setze_farbe(Stil.AKZENT if offen > 0 else Stil.TEXT_MATT)
	kopf_glocke.tooltip_text = "%d ungelesene Nachricht(en)" % offen if offen > 0 else "Nachrichten"

	var naechstes: Dictionary = Welt.naechstes_spiel(Welt.mein_verein_id) if Welt.mein_verein_id != "" else {}
	if not naechstes.is_empty() and int(naechstes["tag"]) == Welt.tag():
		weiter_knopf.text = "Zum Spiel"
	else:
		weiter_knopf.text = "Weiter"

# ------------------------------------------------------------- Zeitablauf ---

## Ein Spieltag sind bis zu 68 Partien. Am Stück gerechnet stünde das Bild
## anderthalb Sekunden still — und ein stehendes Bild nach einem Knopfdruck
## fühlt sich nach Absturz an. Deshalb wird der Tag in Scheiben gerechnet,
## zwischen denen die Oberfläche atmen und den Fortschritt zeigen kann.
func _weiter() -> void:
	if not Welt.laeuft or _tag_laeuft:
		return
	_tag_laeuft = true
	weiter_knopf.disabled = true
	Klang.spiele("klick", 0.6)

	var unterbrechung := Welt.tag_beginnen()
	if unterbrechung.is_empty():
		var t: int = Welt.tag()
		var anzahl: int = Welt.spieltag_starten(t)
		if anzahl > 0:
			await _spieltag_rechnen(anzahl)
			Welt.spieltag_beenden()
		unterbrechung = Welt.tag_abschliessen(t)

	_tag_laeuft = false
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

## Rechnet den Spieltag in Scheiben und hält die Anzeige dabei am Leben.
## Kleine Spieltage laufen ohne Anzeige durch — ein Balken, der für 80
## Millisekunden aufblitzt, ist schlimmer als keiner.
func _spieltag_rechnen(anzahl: int) -> void:
	var mit_anzeige: bool = anzahl > 8
	if mit_anzeige:
		_spieltag_anzeige_zeigen()
	while true:
		var offen: int = Welt.spieltag_scheibe(SPIELTAG_SCHEIBE)
		if mit_anzeige:
			_spieltag_anzeige_stand(Welt.spieltag_fortschritt())
		if offen <= 0:
			break
		await get_tree().process_frame
	if mit_anzeige:
		_spieltag_anzeige_verbergen()

# ------------------------------------------------------------- Hilfe (F1) ---
#
# Hallenherz hat fünfundzwanzig Bildschirme. Wer zum ersten Mal hereinkommt,
# sieht eine Seitenleiste und weiß nicht, wo er anfangen soll. F1 beantwortet
# beides: was zuerst zu tun ist und welche Taste wohin führt.

const HILFE_ERSTE_SCHRITTE := [
	["Aufstellung prüfen", "Wer spielt im Angriff, wer in der Abwehr? Der Stab stellt automatisch auf — Sie überstimmen ihn, wo Sie es besser wissen.", "taktik"],
	["Trainingsplan setzen", "Intensität, Schwerpunkt und wer geregeneriert wird. Das Lastkonto entscheidet über Verletzungen.", "training"],
	["Kader ansehen", "Stärken, Verträge, Perspektive. Wer läuft aus, wer wird noch besser?", "kader"],
	["Preise und Fans", "Eintrittspreise, Dauerkarten und das Programm des nächsten Heimspiels.", "halle"],
	["Weiter drücken", "Leertaste schaltet einen Tag weiter. Vor Ihrem Spiel hält das Spiel von selbst an.", ""],
]

func _hilfe_offen() -> bool:
	return _hilfe_schleier != null and _hilfe_schleier.visible

func _hilfe_umschalten() -> void:
	if _hilfe_schleier == null:
		_hilfe_schleier = _hilfe_bauen()
		add_child(_hilfe_schleier)
	_hilfe_schleier.visible = not _hilfe_schleier.visible
	if _hilfe_schleier.visible:
		move_child(_hilfe_schleier, get_child_count() - 1)

func _hilfe_bauen() -> Control:
	var wurzel := Control.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dunkel := ColorRect.new()
	dunkel.color = Color(0, 0, 0, 0.72)
	dunkel.set_anchors_preset(Control.PRESET_FULL_RECT)
	dunkel.mouse_filter = Control.MOUSE_FILTER_STOP
	dunkel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_hilfe_umschalten())
	wurzel.add_child(dunkel)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.add_child(mitte)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 0)
	panel.add_theme_stylebox_override("panel", Stil.box_erhaben(Stil.FLAECHE, Stil.R_GROSS, Stil.RAND_HELL))
	mitte.add_child(panel)
	var rand := MarginContainer.new()
	for seite in ["left", "right", "top", "bottom"]:
		rand.add_theme_constant_override("margin_%s" % seite, 24)
	panel.add_child(rand)
	var spalte := Stil.vbox(14)
	rand.add_child(spalte)

	var kopf := Stil.hbox(10)
	spalte.add_child(kopf)
	kopf.add_child(Stil.titel("Hallenherz — Kurzanleitung", 1))
	kopf.add_child(Stil.dehner())
	var zu := Stil.knopf_flach("Schließen (Esc)", Stil.TEXT_MATT)
	zu.pressed.connect(func(): _hilfe_umschalten())
	kopf.add_child(zu)
	spalte.add_child(Stil.trenner())

	var reihe := Stil.hbox(24)
	spalte.add_child(reihe)

	var links := Stil.vbox(8)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reihe.add_child(links)
	links.add_child(Stil.etikett("Die ersten Schritte"))
	for e in HILFE_ERSTE_SCHRITTE:
		var block := Stil.vbox(2)
		links.add_child(block)
		var titelzeile := Stil.hbox(8)
		block.add_child(titelzeile)
		titelzeile.add_child(Stil.text(str(e[0]), Stil.S_NORMAL, Stil.AKZENT))
		if str(e[2]) != "":
			var hin := Stil.knopf_flach("Hin ›", Stil.BLAU)
			var ziel: String = str(e[2])
			hin.pressed.connect(func():
				_hilfe_umschalten()
				zeige(ziel))
			titelzeile.add_child(hin)
		block.add_child(Bausteine.fliesstext(str(e[1]), Stil.S_KLEIN, null, 260.0))

	var rechts := Stil.vbox(6)
	rechts.custom_minimum_size = Vector2(330, 0)
	reihe.add_child(rechts)
	rechts.add_child(Stil.etikett("Tastenkürzel"))
	for e2 in [["Leertaste", "Einen Tag weiter"], ["F1", "Diese Hilfe"],
			["1 – 0", "Die zehn häufigsten Bildschirme"],
			["B / K / A", "Büro, Kader, Aufstellung"],
			["T / F / N", "Transfermarkt, Finanzen, Nachrichten"],
			["S / Z / J", "Spielplan, Scouting, Nachwuchs"],
			["V / M", "Vorstand, Medien"]]:
		var z := Stil.hbox(10)
		rechts.add_child(z)
		var taste := Stil.abzeichen(str(e2[0]), Stil.AKZENT)
		taste.custom_minimum_size = Vector2(110, 0)
		z.add_child(taste)
		z.add_child(Stil.matt(str(e2[1]), Stil.S_KLEIN))
	rechts.add_child(Stil.trenner())
	rechts.add_child(Bausteine.fliesstext(
		"Jede Karte mit einem „Öffnen ›“ führt weiter. Fast jeder Wert hat einen Tooltip, der erklärt, woher er kommt.",
		Stil.S_MINI, null, 260.0))
	return wurzel

# ------------------------------------------------- Anzeige des Spieltags ---

## Ein schmaler Streifen über dem Bild: Wappen weg, Balken hin. Bewusst kein
## voller Schleier — man soll sehen, dass das Spiel weiterläuft, nicht das
## Gefühl bekommen, es sei stehengeblieben.
func _spieltag_anzeige_zeigen() -> void:
	if _spieltag_schleier == null:
		_spieltag_schleier = _spieltag_anzeige_bauen()
		add_child(_spieltag_schleier)
	_spieltag_schleier.visible = true
	move_child(_spieltag_schleier, get_child_count() - 1)

func _spieltag_anzeige_bauen() -> Control:
	var wurzel := Control.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dunkel := ColorRect.new()
	dunkel.color = Color(0, 0, 0, 0.45)
	dunkel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.add_child(dunkel)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.add_child(mitte)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", Stil.box_erhaben(Stil.FLAECHE, Stil.R_GROSS, Stil.RAND_HELL))
	mitte.add_child(panel)
	var rand := MarginContainer.new()
	for seite in ["left", "right", "top", "bottom"]:
		rand.add_theme_constant_override("margin_%s" % seite, 20)
	panel.add_child(rand)
	var spalte := Stil.vbox(10)
	rand.add_child(spalte)
	spalte.add_child(Stil.titel("Spieltag", 2))
	_spieltag_text = Stil.matt("", Stil.S_KLEIN)
	spalte.add_child(_spieltag_text)
	_spieltag_balken = Stil.balken(0.0, 100.0, 380, Stil.AKZENT)
	spalte.add_child(_spieltag_balken)
	return wurzel

func _spieltag_anzeige_stand(fortschritt: Dictionary) -> void:
	if _spieltag_schleier == null or not _spieltag_schleier.visible:
		return
	var gesamt: int = maxi(int(fortschritt["gesamt"]), 1)
	var fertig: int = int(fortschritt["fertig"])
	_spieltag_text.text = "%d von %d Partien abgepfiffen" % [fertig, gesamt]
	_spieltag_balken.wert = float(fertig) / float(gesamt) * 100.0
	_spieltag_balken.queue_redraw()

func _spieltag_anzeige_verbergen() -> void:
	if _spieltag_schleier != null:
		_spieltag_schleier.visible = false

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
	# Beim allerersten Mal die Kurzanleitung von selbst öffnen. Fünfundzwanzig
	# Bildschirme ohne ein Wort dazu sind keine Tiefe, sondern eine Wand.
	if Welt.laeuft and not bool(Welt.einstellung("hilfe_gesehen", false)):
		Welt.setze_einstellung("hilfe_gesehen", true)
		_hilfe_umschalten()

## Tastenkürzel. Ein Managerspiel wird mit den Händen auf der Tastatur
## gespielt, nicht mit der Maus auf Wanderschaft durch eine Seitenleiste —
## wer täglich zwischen Kader, Aufstellung und Transfermarkt springt, will
## das in einem Anschlag tun.
const TASTENKUERZEL := {
	KEY_1: "buero", KEY_2: "kader", KEY_3: "taktik", KEY_4: "training",
	KEY_5: "spielplan", KEY_6: "tabellen", KEY_7: "transfer", KEY_8: "finanzen",
	KEY_9: "halle", KEY_0: "nachrichten",
	KEY_B: "buero", KEY_K: "kader", KEY_A: "taktik", KEY_T: "transfer",
	KEY_F: "finanzen", KEY_N: "nachrichten", KEY_S: "spielplan", KEY_Z: "scouting",
	KEY_J: "jugend", KEY_V: "vorstand", KEY_M: "medien",
}

func _unhandled_input(ereignis: InputEvent) -> void:
	if not Welt.laeuft or not rahmen.visible:
		return
	if not (ereignis is InputEventKey and ereignis.pressed and not ereignis.echo):
		return
	var taste: int = ereignis.keycode
	# Modifikatoren gehören den Bildschirmen, nicht der Navigation.
	if ereignis.ctrl_pressed or ereignis.alt_pressed or ereignis.meta_pressed:
		return
	if taste == KEY_SPACE:
		_weiter()
		get_viewport().set_input_as_handled()
		return
	if taste == KEY_F1:
		_hilfe_umschalten()
		get_viewport().set_input_as_handled()
		return
	if taste == KEY_ESCAPE and _hilfe_offen():
		_hilfe_umschalten()
		get_viewport().set_input_as_handled()
		return
	if TASTENKUERZEL.has(taste):
		var ziel: String = str(TASTENKUERZEL[taste])
		if bildschirme.has(ziel):
			zeige(ziel)
			get_viewport().set_input_as_handled()
