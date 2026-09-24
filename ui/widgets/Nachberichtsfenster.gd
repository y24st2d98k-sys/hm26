class_name Nachberichtsfenster
extends Control
## Der Abend danach: was passiert ist, was es gekostet hat, was jetzt zu tun ist.
##
## Es öffnet sich von selbst nach dem Schlusspfiff der eigenen Partie. Nicht,
## weil ein Fenster schöner wäre als ein Bildschirm, sondern weil es der einzige
## Moment ist, in dem man sicher hinsieht — und weil hier zwei Entscheidungen
## stehen, die sonst niemand trifft.

var mid: String = ""
var inhalt: VBoxContainer
var kopftitel: Label
var meldung: String = ""
var meldung_gut: bool = true

static func oeffnen(von: Node, spiel_id: String) -> void:
	var f = von.get_tree().get_first_node_in_group("nachberichtsfenster")
	if f != null:
		f.zeige(spiel_id)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("nachberichtsfenster")

func _ready() -> void:
	theme = Stil.theme()
	var schleier := ColorRect.new()
	schleier.color = Stil.lasur(Stil.TEXT, 0.45)
	schleier.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schleier)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mitte)
	var panel := PanelContainer.new()
	# Gemessen: der Inhalt braucht 700 Pixel, das Fenster hat 945. Bei 660 lief
	# er 130 Pixel ueber.
	panel.custom_minimum_size = Vector2(1020, 830)
	panel.add_theme_stylebox_override("panel", Stil.box_fenster(Stil.FLAECHE))
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
	kopftitel = Stil.titel("Nach dem Spiel", 1)
	kopf.add_child(kopftitel)
	kopf.add_child(Stil.dehner())
	# Kein Klick auf den Schleier: hier stehen Entscheidungen, und ein Fenster,
	# das sich beim Danebenklicken schliesst, verschluckt sie.
	var zu := Stil.knopf_primaer("Weiter zum Büro")
	zu.pressed.connect(func(): visible = false)
	kopf.add_child(zu)
	# Ein Rollbereich, obwohl nichts rollen soll: nur so kann die Fenstersonde
	# messen, ob der Inhalt in das Fenster passt. Ohne ihn waere ein zu langer
	# Bericht stillschweigend abgeschnitten.
	var rollen := ScrollContainer.new()
	rollen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rollen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rollen.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(rollen)
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rollen.add_child(inhalt)

func zeige(spiel_id: String) -> void:
	mid = spiel_id
	meldung = ""
	visible = true
	_zeichne()

func _zeichne() -> void:
	for k in inhalt.get_children():
		inhalt.remove_child(k)
		k.queue_free()
	var b: Dictionary = Nachbericht.lesen(Welt.daten, mid, Welt.mein_verein_id)
	if b.is_empty():
		inhalt.add_child(Stil.leerzustand("Zu dieser Partie liegt kein Bericht vor."))
		return
	kopftitel.text = "Nach dem Spiel"
	inhalt.add_child(_ergebniszeile(b))
	var reihe := Stil.hbox(Stil.A_NORMAL)
	inhalt.add_child(reihe)
	var links := Stil.vbox(Stil.A_NORMAL)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.size_flags_stretch_ratio = 1.35
	reihe.add_child(links)
	_erzaehlung(links, b)
	_szenen(links, b)
	var rechts := Stil.vbox(Stil.A_NORMAL)
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reihe.add_child(rechts)
	_noten(rechts, b)
	_kosten(rechts, b)
	_ansprache(rechts, b)

## Das Ergebnis, groß und in der Farbe des Ausgangs.
func _ergebniszeile(b: Dictionary) -> Control:
	var ausgang: String = str(b["ausgang"])
	var farbe: Color = Stil.GRUEN if ausgang == "sieg" else (
		Stil.GELB if ausgang == "remis" else Stil.ROT)
	var p := PanelContainer.new()
	var sb := Stil.box_kante(Stil.lasur(farbe, 0.10), "links", farbe, 3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	sb.corner_radius_top_right = Stil.R_KLEIN
	sb.corner_radius_bottom_right = Stil.R_KLEIN
	p.add_theme_stylebox_override("panel", sb)
	var zeile := Stil.hbox(12)
	p.add_child(zeile)
	zeile.add_child(Wappen.fuer_verein(str(b["gegner"]), 34.0))
	var spalte := Stil.vbox(1)
	spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(spalte)
	var m: Dictionary = b["spiel"]
	spalte.add_child(Stil.text("%s %s" % ["gegen" if bool(b["heimspiel"]) else "bei",
		str(Welt.verein(str(b["gegner"])).get("name", "?"))], Stil.S_NORMAL, Stil.TEXT))
	spalte.add_child(Stil.matt("%s · %s · %s Zuschauer" % [
		Welt.wettbewerb_name(str(m["wettbewerb"])),
		Kalender.text(int(m["tag"]), Welt.startjahr(), true),
		Stil.zahl(int(b["zuschauer"]))], Stil.S_MINI))
	zeile.add_child(Stil.dehner())
	var stand := Stil.titel("%d : %d" % [int(b["tore"]), int(b["gegentore"])], 0, farbe)
	stand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zeile.add_child(stand)
	return p

func _erzaehlung(eltern: Node, b: Dictionary) -> void:
	var karte := Bausteine.karte_in(eltern, "So lief es")
	for satz in (b["saetze"] as Array):
		karte.add_child(Bausteine.fliesstext(str(satz), Stil.S_KLEIN, Stil.TEXT, 240.0))

func _szenen(eltern: Node, b: Dictionary) -> void:
	var szenen: Array = b["szenen"]
	var karte := Bausteine.karte_zu(eltern, "Die Momente", "spielplan", "Zu allen Ergebnissen")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if szenen.is_empty():
		karte.add_child(Stil.matt("Keine Szene hat die Partie geprägt."))
		return
	for s in szenen.slice(0, 5):
		var szene: Dictionary = s
		var zeile := Stil.hbox(10)
		karte.add_child(zeile)
		# Die Minute und nicht die Art der Szene: zwei Siebenmeter desselben
		# Werfers ergeben denselben Satz, und untereinander sah das aus wie ein
		# Fehler. Mit der Minute davor ist es ein Verlauf.
		var minute: int = int(float(szene.get("zeit", 0.0)) / 60.0) + 1
		var marke := Stil.abzeichen("%d′" % minute, Stil.AKZENT)
		marke.tooltip_text = Schluesselszenen.etikett(szene)
		zeile.add_child(marke)
		# Umbruch statt Abschnitt: hier ist der Satz der Inhalt, nicht eine
		# Beschriftung neben einer Zahl.
		zeile.add_child(Bausteine.fliesstext(str(szene.get("text", "")), Stil.S_KLEIN, null, 220.0))
		var stand: Array = szene.get("stand", [])
		if stand.size() >= 2:
			var s2 := Stil.matt("%d:%d" % [int(stand[0]), int(stand[1])], Stil.S_MINI)
			s2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			zeile.add_child(s2)

func _noten(eltern: Node, b: Dictionary) -> void:
	var noten: Array = b["noten"]
	var karte := Bausteine.karte_in(eltern, "Die Einzelnoten")
	if noten.is_empty():
		karte.add_child(Stil.matt("Keine Einsatzzeit über zehn Minuten."))
		return
	var bester: String = str(b["spieler_des_spiels"])
	var g := Stil.tabelle(["Spieler", "Min", "Tore", "Note"], true)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for e in noten.slice(0, 7):
		var eintrag: Dictionary = e
		var sid: String = str(eintrag["id"])
		var sp: Dictionary = Welt.spieler(sid)
		var name: String = Spielerfabrik.kurz_name(sp)
		if sid == bester:
			name = "★ " + name
		var k := Stil.knopf_flach(name)
		k.tooltip_text = "Profil von %s öffnen" % Spielerfabrik.voller_name(sp)
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(k)
		g.add_child(Stil.matt(str(int(eintrag["minuten"])), Stil.S_KLEIN))
		g.add_child(Stil.matt(str(int(eintrag["tore"])), Stil.S_KLEIN))
		var note: float = float(eintrag["note"])
		g.add_child(Stil.text(Stil.komma(note, 1), Stil.S_KLEIN,
			Stil.wert_farbe(6.0 - note, 5.0)))

func _kosten(eltern: Node, b: Dictionary) -> void:
	var k: Dictionary = b["kosten"]
	var verletzt: Array = k["verletzt"]
	var dauer: Array = k["dauerlaeufer"]
	if verletzt.is_empty() and dauer.is_empty() and int(k["zeitstrafen"]) < 5 and int(k["rote"]) == 0:
		return
	var karte := Bausteine.karte_zu(eltern, "Was es gekostet hat", "kader", "Zum Kader")
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for v in verletzt:
		var e: Dictionary = v
		var sp: Dictionary = Welt.spieler(str(e["id"]))
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		zeile.add_child(Stil.abzeichen("VERLETZT", Stil.ROT, true))
		zeile.add_child(Bausteine.fliesstext("%s — %s, etwa %d Tage" % [
			Spielerfabrik.kurz_name(sp), str(e["art"]), int(e["tage"])],
			Stil.S_KLEIN, Stil.ROT, 180.0))
	if int(k["rote"]) > 0:
		karte.add_child(Stil.text("%d rote Karte(n) — das zieht eine Sperre nach sich." % int(k["rote"]),
			Stil.S_KLEIN, Stil.ROT))
	if int(k["zeitstrafen"]) >= 5:
		karte.add_child(Stil.matt("%d Zeitstrafen. Wer so verteidigt, spielt ein Sechstel der Partie in Unterzahl." % int(k["zeitstrafen"]), Stil.S_MINI))
	if not dauer.is_empty():
		var namen: Array = []
		for sid in dauer:
			namen.append(Spielerfabrik.kurz_name(Welt.spieler(str(sid))))
		var zeile2 := Stil.hbox(8)
		karte.add_child(zeile2)
		zeile2.add_child(Stil.abzeichen("DURCHGESPIELT", Stil.GELB))
		zeile2.add_child(Bausteine.fliesstext("%s. Das steht am Montag im Lastkonto." % ", ".join(
			PackedStringArray(namen)), Stil.S_MINI, null, 150.0))
		var hin := Stil.knopf_flach("Regeneration", Stil.AKZENT)
		hin.tooltip_text = "Zum Trainingsplan — dort wird das Regenerationsbudget verteilt."
		hin.pressed.connect(func():
			visible = false
			_wechsel("training"))
		zeile2.add_child(hin)

## Die zwei Entscheidungen, die es sonst nirgends gibt.
##
## Der Co-Trainer schlägt vor, wen man ansprechen sollte; die Tonlage wählt der
## Trainer. Beides kann schiefgehen — misslungene Kritik kostet neun Punkte
## Moral und macht unzufrieden. Genau deshalb ist es eine Entscheidung und
## nicht ein Knopf, den man immer drückt.
func _ansprache(eltern: Node, b: Dictionary) -> void:
	var karte := Bausteine.karte_in(eltern, "Ein Wort danach")
	var vorschlag: Dictionary = Nachbericht.ansprache_vorschlag(b["noten"])
	if meldung != "":
		karte.add_child(Stil.banner(meldung, "erfolg" if meldung_gut else "warnung"))
		return
	if vorschlag.is_empty():
		karte.add_child(Stil.matt("Der Stab sieht keinen Anlass für ein Einzelgespräch. Niemand ist herausgestochen, niemand hat abgebaut."))
		return
	for paar in [["lob", "loben", Stil.GRUEN, "Hebt die Moral. Wer es zu oft tut, wird nicht mehr gehört."],
			["kritik", "kritisieren", Stil.ROT, "Senkt die Unzufriedenheit — wenn es ankommt. Sonst kostet es Moral."]]:
		var schluessel: String = str(paar[0])
		if not vorschlag.has(schluessel):
			continue
		var e: Dictionary = vorschlag[schluessel]
		var sid: String = str(e["id"])
		var sp: Dictionary = Welt.spieler(sid)
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		var spalte := Stil.vbox(1)
		spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(spalte)
		spalte.add_child(Stil.text("%s (Note %s)" % [Spielerfabrik.kurz_name(sp),
			Stil.komma(float(e["note"]), 1)], Stil.S_KLEIN, paar[2]))
		spalte.add_child(Bausteine.fliesstext(str(paar[3]), Stil.S_MINI, null, 160.0))
		var k := Stil.knopf_flach(str(paar[1]).capitalize(), paar[2])
		k.pressed.connect(func():
			var erg := Kabine.gespraech(Welt.daten, sid, schluessel)
			meldung = str(erg["text"])
			meldung_gut = bool(erg.get("gelungen", false))
			Welt.zustand_geaendert.emit()
			_zeichne())
		zeile.add_child(k)

func _wechsel(ziel: String) -> void:
	var knoten: Node = self
	while knoten != null:
		if knoten.has_method("zeige") and knoten.has_method("zum_start"):
			knoten.zeige(ziel)
			return
		knoten = knoten.get_parent()
