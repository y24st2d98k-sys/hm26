class_name Spielbericht
extends Control
## Nachbericht einer gespielten Partie: Ergebnis, Ticker, Mannschaftswerte und
## Einzelbewertungen. Liegt dauerhaft im Baum (Gruppe "spielbericht").

var mid: String = ""
var inhalt: VBoxContainer

static func oeffnen(von: Node, spiel_id: String) -> void:
	var f = von.get_tree().get_first_node_in_group("spielbericht")
	if f != null:
		f.zeige(spiel_id)

## Der Scrollbereich. Oeffentlich, damit Werkzeuge auch den unteren Teil des
## Berichts aufnehmen koennen — sonst sieht man nie, was unter dem Falz steht.
var rolle: ScrollContainer

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("spielbericht")

func _ready() -> void:
	theme = Stil.theme()
	var schleier := ColorRect.new()
	schleier.color = Color(0, 0, 0, 0.62)
	schleier.set_anchors_preset(Control.PRESET_FULL_RECT)
	schleier.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			visible = false)
	add_child(schleier)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mitte)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 800)
	panel.add_theme_stylebox_override("panel", Stil.box(Stil.FLAECHE, Stil.R_GROSS, Stil.RAND_HELL))
	mitte.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(m)
	var v := Stil.vbox(10)
	m.add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Spielbericht", 1))
	kopf.add_child(Stil.dehner())
	var zu := Stil.knopf("Schließen")
	zu.pressed.connect(func(): visible = false)
	kopf.add_child(zu)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	rolle = scroll
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)

func zeige(spiel_id: String) -> void:
	mid = spiel_id
	visible = true
	_zeichne()

func _zeichne() -> void:
	Bildschirm.leeren(inhalt)
	var m: Dictionary = Welt.partie(mid)
	if m.is_empty():
		return
	var bericht: Dictionary = m.get("bericht", {})
	var kopf := Stil.hbox(18)
	inhalt.add_child(kopf)
	kopf.add_child(Wappen.fuer_verein(str(m["heim"]), 50.0))
	var mitte := Stil.vbox(2)
	mitte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(mitte)
	var ergebnis := Stil.titel("%s  %d : %d  %s" % [
		Welt.verein(str(m["heim"])).get("kurz", ""), int(m["tore_heim"]), int(m["tore_gast"]),
		Welt.verein(str(m["gast"])).get("kurz", "")], 0)
	ergebnis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(ergebnis)
	var unter := Stil.matt("%s · %s · Halbzeit %d:%d · %s Zuschauer" % [
		Welt.wettbewerb_name(str(m["wettbewerb"])), Kalender.text(int(m["tag"]), Welt.startjahr(), true),
		int((m["halbzeit"] as Array)[0]), int((m["halbzeit"] as Array)[1]),
		Stil.zahl(int(m.get("zuschauer", 0)))])
	unter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(unter)
	if str(m.get("entscheidung", "")) != "":
		var e := Stil.matt("Entscheidung: %s" % str(m["entscheidung"]).capitalize(), Stil.S_KLEIN)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mitte.add_child(e)
	kopf.add_child(Wappen.fuer_verein(str(m["gast"]), 50.0))

	if bericht.is_empty():
		inhalt.add_child(Stil.matt("Zu dieser Partie liegt kein ausführlicher Bericht vor."))
		return

	_torverlauf(m, bericht)

	var spalten := Stil.hbox(12)
	inhalt.add_child(spalten)
	var werte := Bausteine.karte_in(spalten, "Mannschaftswerte")
	Stil.karte_wurzel(werte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hs: Dictionary = bericht["heim"]["stats"]
	var gs: Dictionary = bericht["gast"]["stats"]
	for zeile in [["Würfe", "wuerfe"], ["Tore", "tore"], ["Paraden", "paraden"], ["Blocks", "blocks"],
			["Technische Fehler", "technische_fehler"], ["Ballgewinne", "ballgewinne"],
			["Siebenmeter", "siebenmeter"], ["Zeitstrafen", "zeitstrafen"],
			["Tore nach Gegenstoß", "gegenstoss_tore"], ["Wechsel", "wechsel"]]:
		var h := Stil.hbox(8)
		var a := Stil.text(str(int(hs.get(str(zeile[1]), 0))), Stil.S_KLEIN)
		a.custom_minimum_size = Vector2(44, 0)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(a)
		var l := Stil.matt(str(zeile[0]), Stil.S_KLEIN)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(l)
		var b := Stil.text(str(int(gs.get(str(zeile[1]), 0))), Stil.S_KLEIN)
		b.custom_minimum_size = Vector2(44, 0)
		h.add_child(b)
		werte.add_child(h)
	werte.add_child(Stil.trenner())
	werte.add_child(Stil.info_zeile("Hallenpuls am Ende", "%d" % int(float(bericht.get("hallenpuls", 50.0))),
		Stil.prozent_farbe(float(bericht.get("hallenpuls", 50.0)))))
	var bester: String = str(bericht.get("spieler_des_spiels", ""))
	if bester != "" and Welt.daten["spieler"].has(bester):
		werte.add_child(Stil.info_zeile("Spieler des Spiels", Spielerfabrik.voller_name(Welt.spieler(bester)), Stil.AKZENT))
	var gespann: String = str(bericht.get("gespann", ""))
	if gespann != "":
		werte.add_child(Stil.info_zeile("Gespann", gespann, Stil.TEXT_MATT))

	# Von fremden Partien hebt der Spielstand nur das Ergebnis und die
	# Mannschaftswerte auf. Das steht hier, damit die leeren Karten unten
	# nicht wie ein Fehler aussehen.
	var knapp: bool = bool(bericht.get("knapp", false))
	if knapp:
		inhalt.add_child(Stil.banner("Von Partien ohne eigene Beteiligung bewahrt das Archiv nur Ergebnis und Mannschaftswerte auf — Einzelbewertungen, Wurfkarte und Spielverlauf werden nicht dauerhaft gespeichert.", "info"))
	for seite2 in ["heim", "gast"]:
		var cid2: String = str(bericht[seite2]["cid"])
		var wk: Dictionary = bericht[seite2].get("wurfkarte", {})
		var kk := Bausteine.karte_in(spalten, "Würfe — %s" % Welt.verein(cid2).get("kurz", ""))
		Stil.karte_wurzel(kk).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if wk.is_empty():
			kk.add_child(Stil.leerzustand("Keine Wurfkarte aufgezeichnet."))
			continue
		var w := Wurfkarte.neu(wk, Welt.verein(cid2).get("wappen", {}).get("a", Stil.AKZENT), 300.0)
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kk.add_child(w)
		kk.add_child(Stil.matt("Kreisgröße: Würfe · Füllung: Trefferquote", Stil.S_MINI))

	_szenen(bericht)

	if knapp:
		return
	var ticker := Bausteine.karte_in(inhalt, "Spielverlauf")
	var tickerscroll := ScrollContainer.new()
	tickerscroll.custom_minimum_size = Vector2(0, 260)
	tickerscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ticker.add_child(tickerscroll)
	var tickerliste := Stil.vbox(2)
	tickerliste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tickerscroll.add_child(tickerliste)
	ticker = tickerliste
	for e in bericht.get("ticker", []):
		var h2 := Stil.hbox(8)
		ticker.add_child(h2)
		var zeit := Stil.matt(_zeit(float(e["zeit"])), Stil.S_MINI)
		zeit.custom_minimum_size = Vector2(44, 0)
		h2.add_child(zeit)
		var stand: Array = e.get("stand", [0, 0])
		var s := Stil.matt("%d:%d" % [int(stand[0]), int(stand[1])], Stil.S_MINI)
		s.custom_minimum_size = Vector2(42, 0)
		h2.add_child(s)
		var t := Stil.text(str(e["text"]), Stil.S_KLEIN, _farbe(str(e["typ"])))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(t)

	for seite in ["heim", "gast"]:
		var cid: String = str(bericht[seite]["cid"])
		var karte := Bausteine.karte_in(inhalt, "Einzelbewertungen — %s" % Welt.verein(cid).get("name", ""))
		var g := Stil.tabelle(["Spieler", "Min", "Tore", "Würfe", "Paraden", "Vorl.", "Fehler", "2min", "Note"])
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		karte.add_child(g)
		var spieler: Dictionary = bericht[seite]["spieler"]
		var ids: Array = spieler.keys()
		ids.sort_custom(func(a, b): return float(spieler[a]["sekunden"]) > float(spieler[b]["sekunden"]))
		for sid in ids:
			if not Welt.daten["spieler"].has(sid):
				continue
			var z: Dictionary = spieler[sid]
			var sp: Dictionary = Welt.spieler(sid)
			var k := Stil.knopf_flach(Spielerfabrik.kurz_name(sp))
			k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
			g.add_child(k)
			g.add_child(Stil.text("%d" % int(float(z["sekunden"]) / 60.0), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["tore"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["wuerfe"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["paraden"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["assists"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["fehler"])), Stil.S_KLEIN))
			g.add_child(Stil.text(str(int(z["zeitstrafen"])), Stil.S_KLEIN))
			var note: float = float(z["bewertung"])
			g.add_child(Stil.text(Stil.komma(note, 2), Stil.S_KLEIN, Stil.wert_farbe(6.0 - note, 5.0)))

func _zeit(sekunden: float) -> String:
	return "%02d:%02d" % [int(sekunden / 60.0), int(sekunden) % 60]

func _farbe(typ: String) -> Color:
	match typ:
		"tor":
			return Stil.GRUEN
		"zeitstrafe", "rot":
			return Stil.ROT
		"verwarnung":
			return Stil.GELB
		"auszeit", "lauf":
			return Stil.AKZENT
		"halbzeit", "ende":
			return Stil.BLAU
	return Stil.TEXT

## Der Torverlauf über der Nulllinie, direkt unter dem Ergebnis.
func _torverlauf(m: Dictionary, bericht: Dictionary) -> void:
	var verlauf := Bausteine.karte_in(inhalt, "Torverlauf")
	var heim_f: Color = Welt.verein(str(m["heim"])).get("wappen", {}).get("a", Stil.AKZENT)
	var gast_f: Color = Welt.verein(str(m["gast"])).get("wappen", {}).get("a", Stil.BLAU)
	var kurve := Torverlauf.new()
	kurve.punkte = _verlaufspunkte(bericht)
	kurve.heim_farbe = heim_f
	kurve.gast_farbe = gast_f
	kurve.custom_minimum_size = Vector2(0, 104)
	kurve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	verlauf.add_child(kurve)
	var legende := Stil.hbox(10)
	verlauf.add_child(legende)
	legende.add_child(Stil.abzeichen(str(Welt.verein(str(m["heim"])).get("kurz", "")), heim_f))
	legende.add_child(Stil.matt("oben in Führung", Stil.S_MINI))
	legende.add_child(Stil.dehner())
	legende.add_child(Stil.matt("Mittellinie: Halbzeit", Stil.S_MINI))
	legende.add_child(Stil.dehner())
	legende.add_child(Stil.matt("unten in Führung", Stil.S_MINI))
	legende.add_child(Stil.abzeichen(str(Welt.verein(str(m["gast"])).get("kurz", "")), gast_f))

## Aus dem Kurzticker die Tordifferenz über die Zeit ableiten.
func _verlaufspunkte(bericht: Dictionary) -> Array:
	var punkte: Array = [Vector2(0.0, 0.0)]
	for e in bericht.get("ticker", []):
		var eintrag: Dictionary = e
		if not eintrag.has("stand"):
			continue
		var stand: Array = eintrag["stand"]
		punkte.append(Vector2(float(eintrag.get("zeit", 0.0)),
			float(int(stand[0]) - int(stand[1]))))
	return punkte

## Die Tordifferenz als Fläche um die Nulllinie — wer oben liegt, führt.
class Torverlauf extends Control:
	var punkte: Array = []
	var heim_farbe: Color = Color.WHITE
	var gast_farbe: Color = Color.WHITE

	func _draw() -> void:
		if size.x < 20.0 or size.y < 20.0:
			return
		var null_y: float = size.y * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Stil.FLAECHE_TIEF, true)
		draw_line(Vector2(0, null_y), Vector2(size.x, null_y), Stil.RAND_HELL, 1.0)
		if punkte.size() < 2:
			return
		var groesste := 1.0
		for p in punkte:
			groesste = maxf(groesste, absf((p as Vector2).y))
		var dauer: float = maxf(float((punkte[punkte.size() - 1] as Vector2).x), 1.0)
		# Halbzeitmarke
		draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y),
			Color(1, 1, 1, 0.06), 1.0)
		var vorher := Vector2(0.0, null_y)
		var letzte_diff := 0.0
		for p in punkte:
			var punkt: Vector2 = p
			var x: float = punkt.x / dauer * size.x
			var y: float = null_y - punkt.y / groesste * (size.y * 0.44)
			# Treppenform: der Stand haelt bis zum naechsten Tor und springt dann.
			var ecke := Vector2(x, vorher.y)
			if letzte_diff != 0.0 and x > vorher.x:
				var vorfarbe: Color = heim_farbe if letzte_diff > 0.0 else gast_farbe
				draw_colored_polygon(PackedVector2Array([
					Vector2(vorher.x, null_y), vorher, ecke, Vector2(x, null_y)]),
					Color(vorfarbe.r, vorfarbe.g, vorfarbe.b, 0.22))
			var farbe: Color = heim_farbe if letzte_diff > 0.0 else (
				gast_farbe if letzte_diff < 0.0 else Stil.TEXT_MATT)
			draw_line(vorher, ecke, farbe, 1.8, true)
			var neufarbe: Color = heim_farbe if punkt.y > 0.0 else (
				gast_farbe if punkt.y < 0.0 else Stil.TEXT_MATT)
			draw_line(ecke, Vector2(x, y), neufarbe, 1.8, true)
			vorher = Vector2(x, y)
			letzte_diff = punkt.y
		# Bis zum Schlusspfiff ausziehen
		if vorher.x < size.x - 1.0:
			if letzte_diff != 0.0:
				var endfarbe: Color = heim_farbe if letzte_diff > 0.0 else gast_farbe
				draw_colored_polygon(PackedVector2Array([
					Vector2(vorher.x, null_y), vorher, Vector2(size.x, vorher.y),
					Vector2(size.x, null_y)]),
					Color(endfarbe.r, endfarbe.g, endfarbe.b, 0.22))
			draw_line(vorher, Vector2(size.x, vorher.y),
				heim_farbe if letzte_diff > 0.0 else (gast_farbe if letzte_diff < 0.0 else Stil.TEXT_MATT),
				1.8, true)


## Die Schlüsselszenen.
##
## Steht bewusst vor dem Spielverlauf und außerhalb der Kurzfassung: auch von
## einer fremden Partie, von der der Spielstand nur noch das Ergebnis
## aufhebt, bleiben die sieben Momente erhalten. Sie kosten fast nichts und
## sind das Einzige, was man sich von einem Spiel merkt.
func _szenen(bericht: Dictionary) -> void:
	var liste: Array = bericht.get("szenen", [])
	if liste.is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "Schlüsselszenen")
	karte.add_child(Stil.matt(Schluesselszenen.fazit(liste), Stil.S_KLEIN))
	var leiste := Szenenleiste.new()
	leiste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leiste.setze(liste)
	karte.add_child(leiste)
	var zeilen: Array = []
	for i in range(liste.size()):
		var s: Dictionary = liste[i]
		var zeile := Stil.hbox(8)
		# Der Balken links markiert die gewählte Szene. Ohne ihn verliert man
		# nach einem Klick auf die Leiste sofort wieder, welche Zeile gemeint war.
		var marke := Stil.marke_strich(Stil.RAND_HELL, 3, 18)
		zeile.add_child(marke)
		var zeit := Stil.matt(_zeit(float(s["zeit"])), Stil.S_MINI)
		zeit.custom_minimum_size = Vector2(44, 0)
		zeile.add_child(zeit)
		var stand: Array = s.get("stand", [0, 0])
		var st := Stil.text("%d:%d" % [int(stand[0]), int(stand[1])], Stil.S_MINI)
		st.custom_minimum_size = Vector2(42, 0)
		zeile.add_child(st)
		zeile.add_child(Stil.abzeichen(Schluesselszenen.etikett(s), _farbe(str(s["typ"]))))
		var t := Stil.text(str(s["text"]), Stil.S_KLEIN)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(t)
		var sid: String = str(s.get("spieler", ""))
		if sid != "" and Welt.daten["spieler"].has(sid):
			var k := Stil.knopf_flach("Profil")
			k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
			zeile.add_child(k)
		karte.add_child(zeile)
		zeilen.append(marke)
	leiste.szene_gewaehlt.connect(func(index: int):
		for j in range(zeilen.size()):
			(zeilen[j] as Control).farbe = Stil.AKZENT if j == index else Stil.RAND_HELL
			(zeilen[j] as Control).queue_redraw())
