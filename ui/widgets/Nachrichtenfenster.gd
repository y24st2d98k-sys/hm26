class_name Nachrichtenfenster
extends Control
## Eine Nachricht als Artikel, nicht als Listenzeile.
##
## Der Posteingang war bisher eine Wand aus Text: alles stand gleichzeitig da,
## alles war damit automatisch gelesen, und was man tun konnte, hing als
## Knopfreihe unten dran. Ein Artikel dreht das um — in der Liste steht die
## Schlagzeile, geöffnet steht der ganze Text, und darunter genau die Wege,
## die aus dieser Meldung tatsächlich herausführen: zum Spieler, zum Verein,
## zum Spielbericht, zum zuständigen Bildschirm.

var inhalt: VBoxContainer
var nachricht: Dictionary = {}

## Welcher Bildschirm zu einer Nachrichtenart gehört. Eine Meldung ohne Ziel
## ist eine Meldung, bei der man sich fragt, was man denn nun tun soll.
const ZIELBILDSCHIRM := {
	"vorstand": {"id": "vorstand", "name": "Zum Vorstand"},
	"transfer": {"id": "transfer", "name": "Zum Transfermarkt"},
	"medizin": {"id": "training", "name": "Zur Trainingssteuerung"},
	"kabine": {"id": "kabine", "name": "Zur Kabine"},
	"scouting": {"id": "scouting", "name": "Zum Scouting"},
	"training": {"id": "training", "name": "Zum Training"},
	"jugend": {"id": "jugend", "name": "Zum Nachwuchs"},
	"finanzen": {"id": "finanzen", "name": "Zu den Finanzen"},
	"wettbewerb": {"id": "tabellen", "name": "Zur Tabelle"},
	"karriere": {"id": "karriere", "name": "Zur Laufbahn"},
	"auszeichnung": {"id": "statistik", "name": "Zu den Statistiken"},
	"national": {"id": "national", "name": "Zum Nationalteam"},
	"presse": {"id": "medien", "name": "Zur Medienlage"},
	"chronik": {"id": "chronik", "name": "Zur Chronik"},
}

static func oeffnen(von: Node, n: Dictionary) -> void:
	var f = von.get_tree().get_first_node_in_group("nachrichtenfenster")
	if f != null:
		f.zeige(n)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("nachrichtenfenster")

func _ready() -> void:
	theme = Stil.theme()
	var schleier := ColorRect.new()
	schleier.color = Color(0, 0, 0, 0.68)
	schleier.set_anchors_preset(Control.PRESET_FULL_RECT)
	schleier.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			visible = false)
	add_child(schleier)
	var mitte := CenterContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mitte)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", Stil.box_erhaben(Stil.FLAECHE, Stil.R_GROSS, Stil.RAND_HELL))
	mitte.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(m)
	inhalt = Stil.vbox(12)
	m.add_child(inhalt)

func zeige(n: Dictionary) -> void:
	nachricht = n
	# Gelesen wird eine Nachricht erst, wenn man sie geöffnet hat — nicht,
	# wenn man am Posteingang vorbeigelaufen ist.
	n["gelesen"] = true
	visible = true
	_zeichne()
	Welt.zustand_geaendert.emit()

func _zeichne() -> void:
	Bildschirm.leeren(inhalt)
	if nachricht.is_empty():
		visible = false
		return
	artikel_bauen(inhalt, nachricht, self, func(): visible = false, 700.0)

## Der Artikel in einen beliebigen Behälter — nicht nur in dieses Fenster.
##
## Der Posteingang zeigt die gewählte Meldung gleich neben der Liste: ein
## Klick, kein Fenster, kein Rollen. Damit dort nicht derselbe Artikel ein
## zweites Mal steht, baut ihn beides über diese Funktion.
##
## knoten ist der Knoten, von dem aus Fenster geöffnet werden (er muss im
## Baum hängen); schliessen wird vorher gerufen, sofern gesetzt.
static func artikel_bauen(eltern: Node, n: Dictionary, knoten: Node,
		schliessen: Callable, breite: float = 700.0) -> void:
	var typ: String = str(n.get("typ", "info"))
	var kopf := Stil.hbox(10)
	eltern.add_child(kopf)
	kopf.add_child(Stil.abzeichen(str(NachrichtenBildschirm.TYPEN.get(typ, typ)).to_upper(), farbe_zu(typ), true))
	kopf.add_child(Stil.matt(Kalender.text(int(n.get("tag", 0)), Welt.startjahr()), Stil.S_MINI))
	kopf.add_child(Stil.dehner())
	if bool(n.get("wichtig", false)):
		kopf.add_child(Stil.abzeichen("WICHTIG", Stil.AKZENT))
	if schliessen.is_valid():
		var zu := Stil.knopf_flach("Schließen", Stil.TEXT_MATT)
		zu.pressed.connect(func(): schliessen.call())
		kopf.add_child(zu)

	var schlagzeile := Stil.titel(str(n.get("betreff", "")), 1)
	schlagzeile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eltern.add_child(schlagzeile)
	eltern.add_child(Stil.trenner())

	var daten: Dictionary = n.get("daten", {})
	var sid: String = str(daten.get("spieler", ""))
	if sid != "" and Welt.daten["spieler"].has(sid):
		var zeile := Stil.hbox(12)
		eltern.add_child(zeile)
		zeile.add_child(Portraet.fuer_spieler(sid, 64.0))
		var sp: Dictionary = Welt.spieler(sid)
		var spalte := Stil.vbox(2)
		spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		zeile.add_child(spalte)
		spalte.add_child(Stil.text(Spielerfabrik.voller_name(sp), Stil.S_GROSS))
		spalte.add_child(Stil.matt("%s · %d Jahre · %s" % [
			Spielerfabrik.POSITION_NAME.get(str(sp["position"]), str(sp["position"])),
			int(sp["alter"]), str(Welt.verein(str(sp["verein"])).get("name", "vereinslos"))], Stil.S_KLEIN))

	var text := Stil.text(str(n.get("text", "")), Stil.S_NORMAL, Stil.TEXT_MATT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(breite, 0)
	eltern.add_child(text)

	var wege := Stil.hbox(8)
	wege.custom_minimum_size = Vector2(0, 34)
	eltern.add_child(wege)
	_wege_bauen(wege, n, typ, daten, knoten, schliessen)

## Die Wege aus der Meldung heraus. Erst die Sonderfälle, die wirklich etwas
## auslösen, dann Profile, dann der zuständige Bildschirm.
static func _wege_bauen(wege: HBoxContainer, nachricht: Dictionary, typ: String,
		daten: Dictionary, knoten: Node, schliessen: Callable) -> void:
	var zu := func():
		if schliessen.is_valid():
			schliessen.call()
	var aktion: String = str(nachricht.get("aktion", ""))
	var sid: String = str(daten.get("spieler", ""))
	if aktion == "anliegen" and not Anliegen.fuer_spieler(Welt.daten, sid).is_empty():
		var ak := Stil.knopf_primaer("Anhören")
		ak.pressed.connect(func():
			zu.call()
			Anliegenfenster.oeffnen(knoten, sid))
		wege.add_child(ak)
	if aktion == "pressekonferenz" and Presse.offen(Welt.daten):
		var pk := Stil.knopf_primaer("Zur Pressekonferenz")
		pk.pressed.connect(func():
			zu.call()
			Pressefenster.oeffnen(knoten))
		wege.add_child(pk)
	if sid != "" and Welt.daten["spieler"].has(sid):
		var k := Stil.knopf("Spielerprofil")
		k.pressed.connect(func():
			zu.call()
			Spielerfenster.oeffnen(knoten, sid))
		wege.add_child(k)
	var vid: String = str(daten.get("verein", ""))
	if vid != "" and Welt.daten["vereine"].has(vid):
		var kv := Stil.knopf("Verein ansehen")
		kv.pressed.connect(func():
			zu.call()
			Vereinsfenster.oeffnen(knoten, vid))
		wege.add_child(kv)
	var spid: String = str(daten.get("spiel", ""))
	if spid != "":
		var ks := Stil.knopf("Spielbericht")
		ks.pressed.connect(func():
			zu.call()
			Spielbericht.oeffnen(knoten, spid))
		wege.add_child(ks)
	wege.add_child(Stil.dehner())
	var ziel: Dictionary = ZIELBILDSCHIRM.get(typ, {})
	if not ziel.is_empty():
		var kb := Stil.knopf_primaer(str(ziel["name"]))
		kb.pressed.connect(func():
			zu.call()
			var app := knoten.get_tree().get_first_node_in_group("app")
			if app != null:
				app.zeige(str(ziel["id"])))
		wege.add_child(kb)

static func farbe_zu(typ: String) -> Color:
	match typ:
		"vorstand", "medizin":
			return Stil.ROT
		"transfer":
			return Stil.BLAU
		"karriere", "auszeichnung":
			return Stil.LILA
		"kabine":
			return Stil.TUERKIS
		"wettbewerb":
			return Stil.AKZENT
		"jugend":
			return Stil.GRUEN
	return Stil.TEXT_MATT
