extends Node
## Rendert die Oberflaeche in eine PNG-Datei je Bildschirm.
## Aufruf: godot res://werkzeuge/Bildschirmfoto.tscn -- <ziel_ordner> [bildschirm …]
## Ohne Angabe werden die wichtigsten Bildschirme aufgenommen.

const STANDARD := ["buero", "kader", "taktik", "tabellen", "spielplan", "transfer",
	"statistik", "finanzen", "training", "kabine"]

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ordner: String = str(args[0]) if args.size() > 0 else "/tmp/hallenherz"
	var welche: Array = args.slice(1) if args.size() > 1 else STANDARD
	DirAccess.make_dir_recursive_absolute(ordner)
	get_window().size = Vector2i(1680, 945)
	await get_tree().process_frame

	var vorschau := Weltgenerator.erzeuge(2026, 424242)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	Welt.neues_spiel(cid, {"vorname": "Mira", "nachname": "Halden",
		"hintergrund": "nachwuchs", "nation": "de", "alter": 41}, 424242)
	_log("Verein: %s" % Welt.mein_verein()["name"])

	# Erst simulieren, dann die Oberflaeche bauen: sonst faengt die App das
	# Signal "eigenes Spiel faellig" ab und die Live-Ansicht uebernimmt.
	var schritte := 0
	while schritte < 120:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		schritte += 1
	_log("Simuliert bis %s" % Welt.datum_text())

	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)

	for id in welche:
		if str(id) == "live":
			await _live(app, ordner)
			continue
		if str(id) == "planung":
			app.zeige("kader")
			app.bildschirme["kader"].modus = "planung"
			app.bildschirme["kader"].aktualisieren()
			await _foto("%s/planung.png" % ordner)
			app.bildschirme["kader"].modus = "liste"
			app.bildschirme["kader"].aktualisieren()
			continue
		if str(id) == "anliegen":
			Welt.spieler(str(Welt.mein_verein()["kader"][5]))["unzufriedenheit"] = 62.0
			Anliegen.wochenpruefung(Welt.daten)
			var liste := Anliegen.offene(Welt.daten)
			if not liste.is_empty():
				var af: Node = get_tree().get_first_node_in_group("anliegenfenster")
				af.zeige(str((liste[0] as Dictionary)["spieler"]))
				await _foto("%s/anliegen.png" % ordner)
				af.visible = false
			continue
		if str(id) == "verhandlung":
			var vsid: String = str(Welt.mein_verein()["kader"][2])
			Verhandlung.starten(Welt.daten, vsid, "verlaengerung")
			var vw: Node = get_tree().get_first_node_in_group("verhandlungsfenster")
			vw.zeige()
			await get_tree().process_frame
			await get_tree().process_frame
			await _foto("%s/verhandlung.png" % ordner)
			# Ein zu niedriges Angebot, damit auch die Reaktion im Bild ist
			vw._senden()
			await get_tree().process_frame
			await _foto("%s/verhandlung2.png" % ordner)
			vw.visible = false
			Verhandlung.abbrechen(Welt.daten)
			continue
		if str(id) == "vorspulen":
			app.zeige("spielplan")
			var vf: Node = get_tree().get_first_node_in_group("vorspulfenster")
			vf.zeige()
			await _foto("%s/vorspulen.png" % ordner)
			vf.visible = false
			continue
		if str(id) == "daten":
			app.zeige("daten")
			var db: Node = app.bildschirme["daten"]
			db.gewaehlt = "SC Magdeburg"
			db.entwurf = []
			db.aktualisieren()
			await _foto("%s/daten.png" % ordner)
			continue
		if str(id) == "bericht":
			var gespielt := ""
			for mid2 in Welt.daten["spiele"].keys():
				var m: Dictionary = Welt.partie(str(mid2))
				if bool(m["gespielt"]) and not (m.get("bericht", {}) as Dictionary).is_empty() \
						and (str(m["heim"]) == Welt.mein_verein_id or str(m["gast"]) == Welt.mein_verein_id):
					gespielt = str(mid2)
			if gespielt != "":
				var sb: Node = get_tree().get_first_node_in_group("spielbericht")
				sb.zeige(gespielt)
				await _foto("%s/bericht.png" % ordner)
				sb.visible = false
			continue
		if str(id) == "spieler":
			var sid: String = str(Welt.mein_verein()["kader"][0])
			var f: Node = get_tree().get_first_node_in_group("spielerfenster")
			f.zeige(sid)
			await _foto("%s/spieler.png" % ordner)
			# Zweiter Blick: Attributreiter mit Netzdiagramm und Vergleich
			f.reiter = "attribute"
			for kandidat in Welt.mein_verein()["kader"]:
				var k: Dictionary = Welt.spieler(str(kandidat))
				if str(kandidat) != sid and bool(k["ist_torwart"]) == bool(Welt.spieler(sid)["ist_torwart"]):
					f.vergleich_sid = str(kandidat)
					break
			f._reiter_aufbauen()
			f._zeichne()
			await _foto("%s/spieler_attribute.png" % ordner)
			f.schliessen()
			continue
		if str(id) == "pokal":
			await _pokal(app, ordner)
			continue
		if str(id) == "gesichter":
			await _gesichter(app, ordner)
			continue
		if str(id) == "start":
			app._zeige_start(true)
			await _foto("%s/start.png" % ordner)
			app._zeige_start(false)
			continue
		if not app.bildschirme.has(str(id)):
			_log("unbekannt: %s" % str(id))
			continue
		app.zeige(str(id))
		await _foto("%s/%s.png" % [ordner, str(id)])
	get_tree().quit()

func _live(app: Node, ordner: String) -> void:
	var naechstes := Welt.naechstes_spiel(Welt.mein_verein_id)
	if naechstes.is_empty():
		return
	app.rahmen.visible = false
	app.live.visible = true
	app.live.starte(str(naechstes["id"]))
	await get_tree().process_frame
	for i in range(140):
		app.live._schritt()
		app.live.feld._process(0.2)
	app.live.feld.laufwege_loesen()
	await get_tree().process_frame
	await _foto("%s/live.png" % ordner)
	# Mehrere Aufnahmen mitten im Angriff: nur so ist zu sehen, ob sich das
	# Feld tatsächlich bewegt und der Ball unterwegs ist.
	for n in range(4):
		app.live._schritt()
		# Der Bildschirmfoto-Lauf hat keine laufende Zeit: das Feld muss von
		# Hand weitergedreht werden, sonst verharren Ball und Blitze. Eine
		# Sekunde in kleinen Schritten — so viel Zeit hat die Ansicht im Spiel
		# zwischen zwei Takten auch, sonst zeigt das Bild nur Spieler auf
		# halbem Weg.
		for _f in range(20):
			app.live.feld._process(0.05)
		await get_tree().process_frame
		await _foto("%s/live_zug%d.png" % [ordner, n + 1])
	app.live.visible = false
	app.rahmen.visible = true

func _foto(pfad: String) -> void:
	# Übergänge zu Ende laufen lassen — sonst landet ein halb aufgeblendeter
	# Bildschirm im Bild und man beurteilt eine Animation statt eines Entwurfs.
	var app: Node = get_tree().get_first_node_in_group("app")
	if app != null and app.has_method("bewegung_beenden"):
		app.bewegung_beenden()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var bild := get_viewport().get_texture().get_image()
	bild.save_png(pfad)
	_log("→ %s" % pfad)

## Kontaktbogen aller Gesichter: zum Beurteilen der prozeduralen Portraets.
func _gesichter(app: Node, ordner: String) -> void:
	var tafel := PanelContainer.new()
	tafel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tafel.add_theme_stylebox_override("panel", Stil.box(Stil.GRUND, 0))
	app.add_child(tafel)
	var rand := MarginContainer.new()
	rand.add_theme_constant_override("margin_left", 24)
	rand.add_theme_constant_override("margin_top", 20)
	tafel.add_child(rand)
	var v := Stil.vbox(14)
	rand.add_child(v)
	v.add_child(Stil.titel("Gesichter", 0))
	var gross := Stil.hbox(12)
	v.add_child(gross)
	var alle: Array = Welt.daten["spieler"].keys()
	for i in range(8):
		var sid: String = str(alle[i * 37 % alle.size()])
		var sp: Dictionary = Welt.spieler(sid)
		var spalte := Stil.vbox(3)
		gross.add_child(spalte)
		spalte.add_child(Portraet.fuer_spieler(sid, 108.0))
		spalte.add_child(Stil.matt("%s (%d, %s)" % [Spielerfabrik.kurz_name(sp),
			int(sp["alter"]), str(sp["nation"])], Stil.S_MINI))
	var raster := Stil.raster(20, 6)
	v.add_child(raster)
	for i in range(120):
		raster.add_child(Portraet.fuer_spieler(str(alle[i * 13 % alle.size()]), 52.0))
	var klein := Stil.hbox(6)
	v.add_child(klein)
	for i in range(24):
		klein.add_child(Portraet.fuer_spieler(str(alle[i * 91 % alle.size()]), 26.0))
	await _foto("%s/gesichter.png" % ordner)
	tafel.queue_free()

## Schaubild der Trophaee in drei Metallen.
func _pokal(app: Node, ordner: String) -> void:
	var tafel := PanelContainer.new()
	tafel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tafel.add_theme_stylebox_override("panel", Stil.box(Stil.GRUND, 0))
	app.add_child(tafel)
	var mitte := CenterContainer.new()
	tafel.add_child(mitte)
	var reihe := Stil.hbox(40)
	mitte.add_child(reihe)
	for f in [Color("#e6b64c"), Color("#d8dde3"), Color("#c0703a")]:
		reihe.add_child(Pokal3D.neu(300.0, f))
	await get_tree().process_frame
	await get_tree().process_frame
	await _foto("%s/pokal.png" % ordner)
	tafel.queue_free()
