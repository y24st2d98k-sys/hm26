class_name Anpfifffenster
extends Control
## Der letzte Blick vor dem Anpfiff.
##
## Bis hierher lief eine Partie einfach los. Der Stab hatte aufgestellt, die
## Taktik stand, und der Trainer sah das Ergebnis. Das ist bequem und der
## Grund, warum sich das Spiel anfühlte, als müsse man nichts entscheiden.
##
## Dieses Fenster nimmt niemandem die Automatik weg — es zeigt, was sie
## entschieden hat, und lässt die Wahl: so spielen oder selbst aufstellen. Wer
## es nicht braucht, schaltet es mit einem Haken ab.

var mid: String = ""
var inhalt: VBoxContainer
var bei_anpfiff: Callable = func(_id): pass
var bei_aufstellen: Callable = func(): pass

static func oeffnen(von: Node, spiel_id: String, anpfiff: Callable, aufstellen: Callable) -> void:
	var f = von.get_tree().get_first_node_in_group("anpfifffenster")
	if f == null:
		anpfiff.call(spiel_id)
		return
	f.bei_anpfiff = anpfiff
	f.bei_aufstellen = aufstellen
	f.zeige(spiel_id)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("anpfifffenster")

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
	# Gemessen mit Warnbanner: der Inhalt braucht bis 560 Pixel.
	panel.custom_minimum_size = Vector2(820, 640)
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
	var rollen := ScrollContainer.new()
	rollen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rollen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rollen.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(rollen)
	inhalt = Stil.vbox(10)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rollen.add_child(inhalt)
	# Die Knoepfe stehen ausserhalb des Rollbereichs. Innen sind sie beim
	# ersten langen Bericht nach unten gerutscht, und ein Fenster, dessen
	# einziger Ausgang weggescrollt ist, ist eine Sackgasse.
	v.add_child(_fussleiste())

func zeige(spiel_id: String) -> void:
	mid = spiel_id
	visible = true
	_zeichne()
	# Der Haken steht in der Fussleiste, die nur einmal gebaut wird — sein
	# Zustand kann sich anderswo geaendert haben.
	for k in get_tree().get_nodes_in_group("anpfiff_haken"):
		(k as Button).set_pressed_no_signal(bool(Welt.einstellung("anpfiff_fragen", true)))

func _zeichne() -> void:
	for k in inhalt.get_children():
		inhalt.remove_child(k)
		k.queue_free()
	var m: Dictionary = Welt.partie(mid)
	var cid: String = Welt.mein_verein_id
	if m.is_empty() or cid == "":
		visible = false
		bei_anpfiff.call(mid)
		return
	var heim: bool = str(m["heim"]) == cid
	var gid: String = str(m["gast"]) if heim else str(m["heim"])

	var kopf := Stil.hbox(12)
	inhalt.add_child(kopf)
	kopf.add_child(Wappen.fuer_verein(gid, 38.0))
	var spalte := Stil.vbox(1)
	spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kopf.add_child(spalte)
	spalte.add_child(Stil.titel("%s %s" % ["Heimspiel gegen" if heim else "Auswärts bei",
		str(Welt.verein(gid).get("name", "?"))], 1))
	spalte.add_child(Stil.matt("%s · %s" % [Welt.wettbewerb_name(str(m["wettbewerb"])),
		Kalender.text(int(m["tag"]), Welt.startjahr(), true)], Stil.S_MINI))
	kopf.add_child(Stil.dehner())

	var automatisch: bool = bool(Welt.einstellung("auto_aufstellung", true))
	inhalt.add_child(Stil.banner(
		"Der Trainerstab hat aufgestellt — nach Form, Fitness und Lastkonto." if automatisch
		else "Sie stellen selbst auf. Der Stab hält sich heraus.",
		"info" if automatisch else "erfolg"))

	var v: Dictionary = Welt.verein(cid)
	var reihe := Stil.hbox(Stil.A_NORMAL)
	inhalt.add_child(reihe)
	_block(reihe, "Im Angriff", (v.get("aufstellung", {}) as Dictionary).get("angriff", {}),
		Spielerfabrik.POSITIONEN)
	# Die Abwehrplaetze heissen im Spielstand A1 bis A6; wie sie im
	# eingestellten System genannt werden, weiss das Spielfeld.
	_block(reihe, "In der Abwehr (%s)" % str((v.get("taktik", {}) as Dictionary).get("abwehr", "6-0")),
		(v.get("aufstellung", {}) as Dictionary).get("abwehr", {}),
		["TW", "A1", "A2", "A3", "A4", "A5", "A6"],
		str((v.get("taktik", {}) as Dictionary).get("abwehr", "6-0")))

	_taktik(inhalt, v)
	_warnungen(inhalt, v)


## Die Knopfleiste am Fuß — sie wird einmal gebaut und nicht neu gezeichnet.
func _fussleiste() -> Control:
	var fuss := Stil.hbox(10)
	var haken := Stil.schalter("Vor jedem Spiel zeigen")
	haken.button_pressed = bool(Welt.einstellung("anpfiff_fragen", true))
	haken.add_to_group("anpfiff_haken")
	haken.tooltip_text = "Aus: die Partie läuft künftig ohne Rückfrage los. Wieder einschalten unter Aufstellung & Taktik."
	haken.toggled.connect(func(an): Welt.setze_einstellung("anpfiff_fragen", an))
	fuss.add_child(haken)
	fuss.add_child(Stil.dehner())
	var aendern := Stil.knopf("Ich stelle selbst auf")
	aendern.tooltip_text = "Führt zur Aufstellung. Der Anpfiff wartet — der Knopf oben rechts heißt dann „Anpfiff“."
	aendern.pressed.connect(func():
		visible = false
		bei_aufstellen.call())
	fuss.add_child(aendern)
	var los := Stil.knopf_primaer("Anpfiff ›")
	los.pressed.connect(func():
		visible = false
		bei_anpfiff.call(mid))
	fuss.add_child(los)
	return fuss

## Eine Formation als Liste: Platz, Name, Zustand.
func _block(eltern: Node, titel: String, belegung: Dictionary, reihenfolge: Array,
		system: String = "") -> void:
	var karte := Bausteine.karte_in(eltern, titel)
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := Stil.tabelle(["Platz", "Spieler", "Form", "Fit"], true)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for pos in reihenfolge:
		var platz: String = str(pos)
		var sid: String = str(belegung.get(platz, ""))
		var beschriftung: String = platz
		if system != "" and Spielfeld.ist_abwehrplatz(platz):
			var kuerzel: Array = Spielfeld.ABWEHR_KUERZEL.get(system, Spielfeld.ABWEHR_KUERZEL["6-0"])
			beschriftung = str(kuerzel[Spielfeld.abwehr_index(platz)])
		g.add_child(Stil.matt(beschriftung, Stil.S_KLEIN))
		if sid == "" or not Welt.daten["spieler"].has(sid):
			g.add_child(Stil.text("— nicht besetzt —", Stil.S_KLEIN, Stil.ROT))
			g.add_child(Stil.matt("—", Stil.S_KLEIN))
			g.add_child(Stil.matt("—", Stil.S_KLEIN))
			continue
		var sp: Dictionary = Welt.spieler(sid)
		var k := Stil.knopf_flach(Spielerfabrik.kurz_name(sp))
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(k)
		g.add_child(Stil.text("%d" % int(float(sp["form"])), Stil.S_KLEIN,
			Stil.prozent_farbe(float(sp["form"]))))
		g.add_child(Stil.text("%d" % int(float(sp["fitness"])), Stil.S_KLEIN,
			Stil.prozent_farbe(float(sp["fitness"]))))

func _taktik(eltern: Node, v: Dictionary) -> void:
	var t: Dictionary = v.get("taktik", {})
	var zeile := Stil.hbox(10)
	eltern.add_child(zeile)
	for paar in [["Angriff", str(t.get("angriff", "—"))], ["Abwehr", str(t.get("abwehr", "—"))],
			["Mentalität", str(t.get("mentalitaet", "—"))], ["Tempo", "%d" % int(float(t.get("tempo", 50.0)))],
			["Härte", "%d" % int(float(t.get("haerte", 50.0)))]]:
		zeile.add_child(Stil.abzeichen("%s: %s" % [str(paar[0]), str(paar[1])], Stil.TUERKIS))

## Wer aufgestellt ist, aber nicht spielen kann — der Grund, warum es diese
## Rückfrage überhaupt gibt.
func _warnungen(eltern: Node, v: Dictionary) -> void:
	var betroffen: Array = []
	for block in ["angriff", "abwehr"]:
		for pos in (v.get("aufstellung", {}).get(block, {}) as Dictionary).keys():
			var sid: String = str(v["aufstellung"][block][pos])
			if sid == "" or not Welt.daten["spieler"].has(sid) or betroffen.has(sid):
				continue
			var sp: Dictionary = Welt.spieler(sid)
			if not (sp["verletzung"] as Dictionary).is_empty() or int(sp["sperre"]) > 0:
				betroffen.append(sid)
	if betroffen.is_empty():
		return
	var namen: Array = []
	for sid2 in betroffen:
		namen.append(Spielerfabrik.kurz_name(Welt.spieler(str(sid2))))
	eltern.add_child(Stil.banner("Nicht einsatzfähig und trotzdem aufgestellt: %s. Beim Anpfiff steht dort eine Lücke." % ", ".join(
		PackedStringArray(namen)), "warnung"))
