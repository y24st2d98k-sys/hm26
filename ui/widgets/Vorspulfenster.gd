class_name Vorspulfenster
extends Control
## Zu einem Datum vorspulen.
##
## Entweder über eine der festen Marken der Saison — Saisonstart, Winterpause,
## Transferschluss, Saisonende — oder über ein frei gewähltes Datum. Das Spiel
## schaltet dann Tag für Tag weiter und hält an, sobald etwas passiert, das eine
## Entscheidung verlangt: eine eigene Partie (sofern sie nicht mitsimuliert
## werden soll), der Saisonwechsel oder der Verlust des Vereins.

signal vorgespult()

var inhalt: VBoxContainer
var meldung: Label
var tagfeld: SpinBox
var monatfeld: OptionButton
var jahrfeld: SpinBox
var schalter_simulieren: Button

static func oeffnen(von: Node) -> void:
	var f = von.get_tree().get_first_node_in_group("vorspulfenster")
	if f != null:
		f.zeige()

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_to_group("vorspulfenster")

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
	panel.custom_minimum_size = Vector2(720, 0)
	panel.add_theme_stylebox_override("panel", Stil.box_erhaben(Stil.FLAECHE, Stil.R_GROSS, Stil.RAND_HELL))
	mitte.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(m)
	var v := Stil.vbox(12)
	m.add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Vorspulen", 1))
	kopf.add_child(Stil.dehner())
	var zu := Stil.knopf("Schließen")
	zu.pressed.connect(func(): visible = false)
	kopf.add_child(zu)
	inhalt = Stil.vbox(12)
	v.add_child(inhalt)
	meldung = Stil.text("", Stil.S_KLEIN, Stil.AKZENT)
	meldung.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(meldung)

func zeige() -> void:
	visible = true
	meldung.text = ""
	_zeichne()

# ------------------------------------------------------------- Aufbau ---

func _zeichne() -> void:
	Bildschirm.leeren(inhalt)
	if not Welt.bereit():
		inhalt.add_child(Stil.matt("Kein Spielstand geladen."))
		return
	inhalt.add_child(Stil.info_zeile("Heute", Welt.datum_text(true), Stil.TEXT))

	var wahl := Bausteine.karte_in(inhalt, "Feste Marken")
	var raster := Stil.raster(2, 8)
	wahl.add_child(raster)
	for ziel in _marken():
		var eintrag: Dictionary = ziel
		var knopf := Stil.knopf("%s — %s" % [str(eintrag["name"]),
			Kalender.kurz(int(eintrag["tag"]), Welt.startjahr())])
		knopf.alignment = HORIZONTAL_ALIGNMENT_LEFT
		knopf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		knopf.tooltip_text = "%d Tag(e) vorspulen" % (int(eintrag["tag"]) - Welt.tag())
		var zieltag: int = int(eintrag["tag"])
		knopf.pressed.connect(func(): _springen(zieltag))
		raster.add_child(knopf)

	var frei := Bausteine.karte_in(inhalt, "Freies Datum")
	var zeile := Stil.hbox(8)
	frei.add_child(zeile)
	var heute := Kalender.datum(Welt.tag(), Welt.startjahr())
	tagfeld = SpinBox.new()
	tagfeld.min_value = 1
	tagfeld.max_value = 31
	tagfeld.value = int(heute["tag"])
	tagfeld.custom_minimum_size = Vector2(80, 0)
	zeile.add_child(tagfeld)
	monatfeld = OptionButton.new()
	monatfeld.custom_minimum_size = Vector2(150, 0)
	for i in range(12):
		monatfeld.add_item(Kalender.MONATSNAMEN[i])
	monatfeld.select(int(heute["monat"]) - 1)
	monatfeld.item_selected.connect(func(i):
		tagfeld.max_value = Kalender.tage_im_monat(i + 1))
	zeile.add_child(monatfeld)
	jahrfeld = SpinBox.new()
	jahrfeld.min_value = int(heute["jahr"])
	jahrfeld.max_value = int(heute["jahr"]) + 1
	jahrfeld.value = int(heute["jahr"])
	jahrfeld.custom_minimum_size = Vector2(100, 0)
	zeile.add_child(jahrfeld)
	var los := Stil.knopf_primaer("Dorthin springen")
	los.pressed.connect(func():
		_springen(Kalender.tag_aus_datum(int(tagfeld.value), monatfeld.selected + 1,
			int(jahrfeld.value), Welt.startjahr())))
	zeile.add_child(los)

	schalter_simulieren = Stil.schalter("Eigene Spiele mitsimulieren, statt anzuhalten",
		bool(Welt.einstellung("vorspulen_simuliert", false)))
	schalter_simulieren.tooltip_text = "Aus: Das Vorspulen endet vor Ihrer nächsten Partie, damit Sie sie selbst leiten können."
	schalter_simulieren.toggled.connect(func(an): Welt.setze_einstellung("vorspulen_simuliert", an))
	inhalt.add_child(schalter_simulieren)

## Die Marken der Saison, jeweils als absoluter Tagindex.
func _marken() -> Array:
	var heute: int = Welt.tag()
	var saison: int = Welt.saison_index()
	var liste: Array = []
	var naechstes := Welt.naechstes_spiel(Welt.mein_verein_id)
	if not naechstes.is_empty():
		liste.append({"name": "Nächstes eigenes Spiel", "tag": int(naechstes["tag"])})
	liste.append({"name": "Nächster Montag", "tag": Kalender.naechster_wochentag(heute + 1, 0)})
	liste.append({"name": "In einer Woche", "tag": heute + 7})
	liste.append({"name": "In einem Monat", "tag": heute + 30})
	for marke in [
		["Ligastart", Spielplan.LIGA_START],
		["Winterpause", Spielplan.WINTERPAUSE_VON],
		["Ende der Winterpause", Spielplan.WINTERPAUSE_BIS],
		["Wintertransferfenster", Transfermarkt.WINTER_VON],
		["Letzter Spieltag", Spielplan.LIGA_ENDE],
		["Saisonende", Spielplan.SAISON_ABSCHLUSS],
	]:
		var tis: int = int(marke[1])
		var ziel: int = saison * Kalender.TAGE_IM_JAHR + tis
		if ziel <= heute:
			ziel += Kalender.TAGE_IM_JAHR
		liste.append({"name": str(marke[0]), "tag": ziel})
	liste.sort_custom(func(a, b): return int(a["tag"]) < int(b["tag"]))
	return liste

# ---------------------------------------------------------------- Springen ---

## Wie viele Tage zwischen zwei Bildern gerechnet werden. Klein genug, dass der
## Balken laeuft; gross genug, dass das Zeichnen nicht mehr kostet als das
## Rechnen.
const SCHEIBE := 3

## Springt in Scheiben und zeigt dabei, wie weit es ist.
func _mit_ladeschirm(zieltag: int, simulieren: bool) -> Dictionary:
	var start: int = Welt.tag()
	var strecke: int = maxi(zieltag - start, 1)
	var schirm := Ladeschirm.oeffnen(self, "Die Zeit läuft weiter",
		"bis %s" % Kalender.text(zieltag, Welt.startjahr()))
	await schirm.atmen()
	var summe := 0
	var erg := {"tage": 0, "grund": "ziel_erreicht", "weiter": false}
	while true:
		erg = Welt.vorspulen_schritt(zieltag, simulieren, SCHEIBE)
		summe += int(erg["tage"])
		schirm.fortschritt(float(summe) / float(strecke),
			"%s · noch %s" % [Welt.datum_text(true), Stil.anzahl_mit(maxi(zieltag - Welt.tag(), 0), "Tag", "Tage")])
		await schirm.atmen()
		if not bool(erg.get("weiter", false)):
			break
	erg["tage"] = summe
	schirm.schliessen()
	return erg

func _springen(zieltag: int) -> void:
	if zieltag <= Welt.tag():
		meldung.text = "Dieses Datum liegt nicht in der Zukunft."
		meldung.add_theme_color_override("font_color", Stil.ROT)
		return
	var simulieren: bool = bool(Welt.einstellung("vorspulen_simuliert", false))
	var erg := await _mit_ladeschirm(zieltag, simulieren)
	var text := ""
	match str(erg["grund"]):
		"ziel_erreicht":
			text = "%d Tage vorgespult — jetzt ist %s." % [int(erg["tage"]), Welt.datum_text(true)]
		"eigenes_spiel":
			text = "Nach %d Tagen angehalten: Ihre Partie steht an (%s)." % [
				int(erg["tage"]), Welt.datum_text(true)]
		"saisonende":
			text = "Nach %d Tagen angehalten: Die Saison ist zu Ende." % int(erg["tage"])
		"neue_saison":
			text = "Nach %d Tagen angehalten: Eine neue Saison hat begonnen." % int(erg["tage"])
		"verein_verloren":
			text = "Nach %d Tagen angehalten: Sie haben Ihren Verein verloren." % int(erg["tage"])
		_:
			text = "Kein Spielstand."
	meldung.text = text
	meldung.add_theme_color_override("font_color",
		Stil.GRUEN if str(erg["grund"]) == "ziel_erreicht" else Stil.AKZENT)
	vorgespult.emit()
	if str(erg["grund"]) == "eigenes_spiel":
		visible = false
	else:
		_zeichne()
