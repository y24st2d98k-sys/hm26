extends Control
## Das Hauptfenster von Hallenherz: Kopf, Inhalt, Kommandoleiste.
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

## Wie die Bildschirme zu Ressorts zusammenstehen.
##
## Fünf Ressorts, und in jedem stehen seine Blätter offen nebeneinander. Das
## Menüband davor hatte sieben Knöpfe, hinter denen sich vierundzwanzig
## Einträge versteckten: wer im Kader stand, sah nicht, dass Training und
## Kabine einen Klick entfernt liegen — er musste es wissen. Ein Menü, das
## aufklappen muss, verbirgt genau die Nachbarschaft, die es ordnen soll, und
## kostet für jeden Wechsel zwei Klicks statt einem.
##
## Die Reihenfolge ist die des Arbeitstags: erst der Schreibtisch mit dem, was
## hereinkommt, dann die Mannschaft, dann der Wettbewerb, dann der Markt, dann
## das Haus. Der Spielstand steht in keinem Ressort — er gehört nicht zum
## Verein, sondern zum Spiel, und sitzt als Zahnrad im Kopf.
const RESSORTS := [
	{"id": "schreibtisch", "name": "Schreibtisch",
		"blaetter": ["buero", "nachrichten", "medien", "chronik", "karriere"]},
	{"id": "mannschaft", "name": "Mannschaft",
		"blaetter": ["kader", "taktik", "training", "kabine", "jugend"]},
	{"id": "wettbewerb", "name": "Wettbewerb",
		"blaetter": ["spielplan", "tabellen", "pokale", "national", "statistik", "analyse"]},
	{"id": "markt", "name": "Markt",
		"blaetter": ["transfer", "scouting", "daten"]},
	{"id": "verein", "name": "Verein",
		"blaetter": ["finanzen", "halle", "infrastruktur", "personal", "vorstand"]},
	{"id": "spielstand", "name": "Spielstand", "versteckt": true, "blaetter": ["system"]},
]

var bildschirme: Dictionary = {}
var aktueller: String = ""
var inhalt: MarginContainer
var navi: Navigationskopf
var kommando: Kommandoleiste
## Der Weg durch die Bildschirme, wie im Browser: eine Liste und ein Zeiger
## darauf. Wer zurueckgeht und dann woandershin abbiegt, verwirft den Rest —
## genau wie ein Browser es tut.
var _verlauf: Array = []
var _verlaufsstelle: int = -1
## Die Partie, die auf den Anpfiff wartet, weil der Trainer erst aufstellen
## wollte. Solange sie gesetzt ist, heisst der Weiter-Knopf "Anpfiff".
var _anpfiff_wartet: String = ""
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
const INHALT_RAND_OBEN := 14
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
	add_child(Nachberichtsfenster.new())
	add_child(Anpfifffenster.new())
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
	# Kopf, Inhalt, Fuß. Der Kopf sagt, wo man ist. Der Fuß sagt, was die Welt
	# macht und wie man sie weiterdreht. Dazwischen steht nichts als der
	# Bildschirm — vorher lagen über ihm zwei Leisten, die beide alles wollten.
	rahmen = VBoxContainer.new()
	rahmen.set_anchors_preset(Control.PRESET_FULL_RECT)
	rahmen.add_theme_constant_override("separation", 0)
	add_child(rahmen)

	_baue_navigation(rahmen)

	inhalt = MarginContainer.new()
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inhalt.add_theme_constant_override("margin_left", 26)
	inhalt.add_theme_constant_override("margin_right", 24)
	inhalt.add_theme_constant_override("margin_top", INHALT_RAND_OBEN)
	inhalt.add_theme_constant_override("margin_bottom", 14)
	rahmen.add_child(inhalt)
	_baue_bildschirme()

	_baue_kommandoleiste(rahmen)

## Der Kopf: Ressorts oben, die Blätter des offenen Ressorts darunter.
func _baue_navigation(eltern: Node) -> void:
	var namen := {}
	for b in BEREICHE:
		namen[str(b["id"])] = str(b["name"])
	var ressorts: Array = []
	for r in RESSORTS:
		var blaetter: Array = []
		for id in (r["blaetter"] as Array):
			blaetter.append({"id": str(id), "name": str(namen.get(str(id), str(id)))})
		ressorts.append({"id": str(r["id"]), "name": str(r["name"]),
			"versteckt": bool(r.get("versteckt", false)), "blaetter": blaetter})
	navi = Navigationskopf.new()
	eltern.add_child(navi)
	navi.aufbauen(ressorts)
	navi.gewaehlt.connect(func(id): zeige(str(id)))
	navi.merken_umgeschaltet.connect(func(id): _lesezeichen_umschalten(str(id)))
	navi.zurueck_gewaehlt.connect(_verlauf_zurueck)
	navi.vor_gewaehlt.connect(_verlauf_vor)
	navi.hilfe_gewuenscht.connect(_hilfe_umschalten)
	navi.vorspulen_gewuenscht.connect(func(): Vorspulfenster.oeffnen(self))

## Der Fuß: Datum, Saison, nächstes Spiel, offene Sachen, Kasse, Weiter.
func _baue_kommandoleiste(eltern: Node) -> void:
	kommando = Kommandoleiste.new()
	eltern.add_child(kommando)
	kommando.aufbauen()
	kommando.gewaehlt.connect(func(id): zeige(str(id)))
	kommando.weiter_gedrueckt.connect(_weiter)

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

## Zurueck zum Startbildschirm — dort liegen neue Karriere, Laden und Beenden.
##
## Der Verlauf wird geleert: der Weg durch die alte Karriere hat im naechsten
## Spielstand nichts zu suchen.
func zum_start() -> void:
	_verlauf = []
	_verlaufsstelle = -1
	aktueller = ""
	_zeige_start(true)

func _zeige_start(an: bool) -> void:
	startbildschirm.visible = an
	rahmen.visible = not an
	if an:
		startbildschirm.aktualisieren()

# --------------------------------------------------------------- Wechsel ---

func zeige(id: String, aus_verlauf: bool = false) -> void:
	if not bildschirme.has(id):
		return
	if not aus_verlauf and id != aktueller:
		_verlauf = _verlauf.slice(0, _verlaufsstelle + 1)
		_verlauf.append(id)
		# Der Weg wird nicht unendlich lang. Wer dreißig Bildschirme zurück
		# will, sucht ihn im Menü, nicht mit dreißig Klicks.
		if _verlauf.size() > VERLAUF_LAENGE:
			_verlauf = _verlauf.slice(_verlauf.size() - VERLAUF_LAENGE)
		_verlaufsstelle = _verlauf.size() - 1
	if aktueller != "" and bildschirme.has(aktueller):
		bildschirme[aktueller].visible = false
	aktueller = id
	Welt.merke_besuch(id)
	bildschirme[id].visible = true
	bildschirme[id].aktualisieren()
	if navi != null:
		navi.setze_aktiv(id)
		navi.setze_lesezeichen(Welt.lesezeichen(), Welt.lesezeichen_voll())
		navi.setze_verlauf(_verlaufsstelle > 0, _verlaufsstelle < _verlauf.size() - 1)
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
	navi.setze_trainer(Portraet.fuer_trainer(t, 26.0),
		Trainerkarriere.voller_name(t),
		Trainerkarriere.ruf_stufe(float(t.get("ruf", 0.0))))

	var v: Dictionary = Welt.mein_verein()
	if v.is_empty():
		navi.setze_verein("Ohne Verein", "auf Vereinssuche", null)
		kommando.setze_kasse("—", Stil.TEXT_MATT)
	else:
		navi.setze_verein(str(v["name"]), Welt.wettbewerb_name(str(v["liga"])),
			Wappen.fuer_verein(Welt.mein_verein_id, 30.0))
		kommando.setze_kasse(Stil.geld(float(v["kasse"])),
			Stil.TEXT if float(v["kasse"]) >= 0.0 else Stil.ROT)
	kommando.setze_zeit(Welt.datum_text(), Welt.saison_text())
	_kopf_termine()

	var offen: int = Welt.ungelesene_nachrichten()
	navi.setze_post(offen)
	navi.setze_zaehler("nachrichten", offen)
	navi.setze_hinweis("nachrichten",
		("%d ungelesene Nachricht(en)" % offen) if offen > 0 else "Posteingang")
	# Eine Zahl ohne Erklaerung ist eine Aufgabe ohne Anleitung.
	var gespraeche: int = Anliegen.anzahl(Welt.daten)
	navi.setze_zaehler("kabine", gespraeche)
	navi.setze_hinweis("kabine",
		("%d Spieler möchten Sie sprechen — Reiter „Gespräche“" % gespraeche) if gespraeche > 0
		else "Stimmung, Hierarchie, Gespräche")

	var naechstes: Dictionary = Welt.naechstes_spiel(Welt.mein_verein_id) if Welt.mein_verein_id != "" else {}
	if _anpfiff_wartet != "":
		kommando.setze_weiter("Anpfiff ›",
			"Die Partie wartet. Wenn die Aufstellung steht: anpfeifen.")
	elif not naechstes.is_empty() and int(naechstes["tag"]) == Welt.tag():
		kommando.setze_weiter("Zum Spiel", "Einen Tag weiterschalten (Leertaste)")
	else:
		kommando.setze_weiter("Weiter", "Einen Tag weiterschalten (Leertaste)")

# ------------------------------------------------------------- Zeitablauf ---

## Ein Spieltag sind bis zu 68 Partien. Am Stück gerechnet stünde das Bild
## anderthalb Sekunden still — und ein stehendes Bild nach einem Knopfdruck
## fühlt sich nach Absturz an. Deshalb wird der Tag in Scheiben gerechnet,
## zwischen denen die Oberfläche atmen und den Fortschritt zeigen kann.
func _weiter() -> void:
	if not Welt.laeuft or _tag_laeuft:
		return
	# Eine wartende Partie geht vor: der Tag darf nicht weiterlaufen, solange
	# sie nicht gespielt ist.
	if _anpfiff_wartet != "":
		_live_starten(_anpfiff_wartet)
		return
	_tag_laeuft = true
	kommando.weiter.disabled = true

	var unterbrechung := Welt.tag_beginnen()
	if unterbrechung.is_empty():
		var t: int = Welt.tag()
		var anzahl: int = Welt.spieltag_starten(t)
		if anzahl > 0:
			await _spieltag_rechnen(anzahl)
			Welt.spieltag_beenden()
		unterbrechung = Welt.tag_abschliessen(t)

	_tag_laeuft = false
	kommando.weiter.disabled = false
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
# sieht fünf Ressorts und weiß nicht, wo er anfangen soll. F1 beantwortet
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
			["V / M", "Vorstand, Medien"],
			["L", "Diesen Bildschirm anheften"],
			["Alt + ← / →", "Einen Bildschirm zurück und wieder vor"]]:
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

## Vor dem Anpfiff wird gefragt — es sei denn, der Trainer hat abgewinkt.
##
## Der Stab stellt auf, und bis hierher lief die Partie einfach los. Das ist
## bequem und der Grund, warum man nie etwas entscheiden musste. Jetzt zeigt
## das Spiel einmal, was der Stab entschieden hat, und laesst die Wahl.
func _starte_live(spiel_id: String) -> void:
	if not bool(Welt.einstellung("anpfiff_fragen", true)):
		_live_starten(spiel_id)
		return
	_anpfiff_wartet = spiel_id
	_auffrischen()
	Anpfifffenster.oeffnen(self, spiel_id,
		func(id): _live_starten(str(id)),
		func():
			zeige("taktik")
			_auffrischen())

func _live_starten(spiel_id: String) -> void:
	_anpfiff_wartet = ""
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
	# Der Abend danach. Er steht nach dem Abwickeln, nicht davor: die
	# Verletzung aus der Partie entsteht erst in Medizin.spiel_nachwirkung,
	# und der Nachbericht soll sie nennen koennen.
	Nachberichtsfenster.oeffnen(self, _spiel_id)
	# Beim allerersten Mal die Kurzanleitung von selbst öffnen. Fünfundzwanzig
	# Bildschirme ohne ein Wort dazu sind keine Tiefe, sondern eine Wand.
	if Welt.laeuft and not bool(Welt.einstellung("hilfe_gesehen", false)):
		Welt.setze_einstellung("hilfe_gesehen", true)
		_hilfe_umschalten()

## Tastenkürzel. Ein Managerspiel wird mit den Händen auf der Tastatur
## gespielt, nicht mit der Maus auf Wanderschaft durch ein Menü —
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

## Wie viele Schritte der Weg zurueckreicht.
const VERLAUF_LAENGE := 30

func _verlauf_zurueck() -> void:
	if _verlaufsstelle <= 0:
		return
	_verlaufsstelle -= 1
	zeige(str(_verlauf[_verlaufsstelle]), true)

func _verlauf_vor() -> void:
	if _verlaufsstelle >= _verlauf.size() - 1:
		return
	_verlaufsstelle += 1
	zeige(str(_verlauf[_verlaufsstelle]), true)

## Die beiden Angaben im Fuß, die sagen, worauf es zuläuft.
func _kopf_termine() -> void:
	if kommando == null:
		return
	var m: Dictionary = Welt.naechstes_spiel(Welt.mein_verein_id) if Welt.mein_verein_id != "" else {}
	if m.is_empty():
		kommando.setze_spiel("keins angesetzt", Stil.TEXT_MATT, "Zum Spielplan")
	else:
		var tage: int = int(m["tag"]) - Welt.tag()
		var heim: bool = str(m["heim"]) == Welt.mein_verein_id
		var gid: String = str(m["gast"]) if heim else str(m["heim"])
		var gegner: String = str(Welt.verein(gid).get("name", "?"))
		var wann: String = "heute" if tage <= 0 else ("morgen" if tage == 1 else "in %d Tagen" % tage)
		kommando.setze_spiel("%s · %s %s" % [wann, "gegen" if heim else "bei", gegner.substr(0, 20)],
			Stil.SIGNAL if tage <= 1 else Stil.TEXT,
			"%s %s — %s. Zum Spielplan." % ["gegen" if heim else "bei", gegner,
				Kalender.text(int(m["tag"]), Welt.startjahr(), true)])

	var posten: Array = Aufgaben.offene(Welt.daten, Welt.mein_verein_id)
	if posten.is_empty():
		kommando.setze_draengt("nichts", Stil.GRUEN, "Keine offene Entscheidung. Zum Büro.")
		return
	var erster: Dictionary = posten[0]
	var stufe: int = int(erster["stufe"])
	var rest: String = "  +%d" % (posten.size() - 1) if posten.size() > 1 else ""
	kommando.setze_draengt(str(erster["titel"]).substr(0, 30) + rest,
		Stil.ROT if stufe == Aufgaben.EILIG else (Stil.GELB if stufe == Aufgaben.OFFEN else Stil.TEXT),
		"%s\n%s\n\nInsgesamt %d offene Sachen — zum Büro." % [
			str(erster["titel"]), str(erster["text"]), posten.size()])

## Den offenen Bildschirm anheften oder ablösen.
##
## Ein voller Balken lehnt still ab — deshalb sagt es hier jemand. Ohne
## Rückmeldung drückt man dreimal und hält den Stern für kaputt.
func _lesezeichen_umschalten(id: String) -> void:
	if Welt.daten.is_empty() or id == "":
		return
	var abgelehnt: bool = Welt.lesezeichen_voll() and not Welt.ist_lesezeichen(id)
	Welt.lesezeichen_umschalten(id)
	if navi != null:
		navi.setze_lesezeichen(Welt.lesezeichen(), Welt.lesezeichen_voll(), abgelehnt)

func _unhandled_input(ereignis: InputEvent) -> void:
	if not Welt.laeuft or not rahmen.visible:
		return
	# Die Seitentasten der Maus sind an jedem Rechner „zurueck" und „vor".
	if ereignis is InputEventMouseButton and ereignis.pressed:
		var knopf: int = (ereignis as InputEventMouseButton).button_index
		if knopf == MOUSE_BUTTON_XBUTTON1:
			_verlauf_zurueck()
			get_viewport().set_input_as_handled()
			return
		if knopf == MOUSE_BUTTON_XBUTTON2:
			_verlauf_vor()
			get_viewport().set_input_as_handled()
			return
	if not (ereignis is InputEventKey and ereignis.pressed and not ereignis.echo):
		return
	var taste: int = ereignis.keycode
	# Alt + Pfeil geht durch den Verlauf — das steht vor der Regel darunter,
	# sonst faengt sie es ab.
	if ereignis.alt_pressed and (taste == KEY_LEFT or taste == KEY_RIGHT):
		if taste == KEY_LEFT:
			_verlauf_zurueck()
		else:
			_verlauf_vor()
		get_viewport().set_input_as_handled()
		return
	# Modifikatoren gehören den Bildschirmen, nicht der Navigation.
	if ereignis.ctrl_pressed or ereignis.alt_pressed or ereignis.meta_pressed:
		return
	if taste == KEY_SPACE:
		_weiter()
		get_viewport().set_input_as_handled()
		return
	if taste == KEY_L:
		_lesezeichen_umschalten(aktueller)
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
