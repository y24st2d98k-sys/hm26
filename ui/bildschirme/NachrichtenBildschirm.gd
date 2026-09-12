class_name NachrichtenBildschirm
extends Bildschirm
## Posteingang: alle Meldungen aus Verein, Medizin, Transfer, Vorstand und Karriere.

var liste: VBoxContainer
var filter: String = ""

const TYPEN := {
	"": "alle", "verein": "Verein", "vorstand": "Vorstand", "transfer": "Transfer",
	"medizin": "Medizin", "kabine": "Kabine", "scouting": "Scouting", "training": "Training",
	"wettbewerb": "Wettbewerb", "karriere": "Karriere", "auszeichnung": "Ehrungen",
	"finanzen": "Finanzen", "jugend": "Jugend", "chronik": "Chronik",
	"presse": "Presse", "national": "Nationalteam",
}

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Nachrichten", 0))
	kopf.add_child(Stil.dehner())
	var wahl := OptionButton.new()
	var i := 0
	for k in TYPEN.keys():
		wahl.add_item(str(TYPEN[k]))
		wahl.set_item_metadata(i, k)
		i += 1
	wahl.item_selected.connect(func(idx):
		filter = str(wahl.get_item_metadata(idx))
		aktualisieren())
	kopf.add_child(wahl)
	var alle := Stil.knopf("Alle als gelesen markieren")
	alle.pressed.connect(func():
		for n in Welt.daten.get("nachrichten", []):
			n["gelesen"] = true
		Welt.zustand_geaendert.emit()
		aktualisieren())
	kopf.add_child(alle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	liste = Stil.vbox(8)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(liste)

func aktualisieren() -> void:
	if liste == null:
		return
	leeren(liste)
	var nachrichten: Array = Welt.daten.get("nachrichten", [])
	var gezeigt := 0
	for n in nachrichten:
		if filter != "" and str(n["typ"]) != filter:
			continue
		liste.add_child(_eintrag(n))
		gezeigt += 1
		if gezeigt >= 80:
			break
	if gezeigt == 0:
		liste.add_child(Stil.matt("Keine Nachrichten in dieser Kategorie."))

## Eine Nachricht in der Liste: Schlagzeile, Anreisser, ein Klick aufs Ganze.
## Gelesen wird sie erst im Artikel — vorher hat sie niemand gelesen.
func _eintrag(n: Dictionary) -> Control:
	var karte := Stil.karte("", not bool(n["gelesen"]))
	var kopf := Stil.hbox(8)
	karte.add_child(kopf)
	var typ := Stil.abzeichen(str(TYPEN.get(str(n["typ"]), str(n["typ"]))), _farbe(str(n["typ"])))
	kopf.add_child(typ)
	var betreff := Stil.text(str(n["betreff"]), Stil.S_NORMAL, Stil.AKZENT if bool(n["wichtig"]) else Stil.TEXT)
	betreff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(betreff)
	kopf.add_child(Stil.matt(Kalender.text(int(n["tag"]), Welt.startjahr()), Stil.S_MINI))
	if not bool(n["gelesen"]):
		kopf.add_child(Stil.abzeichen("NEU", Stil.AKZENT, true))
	karte.add_child(Stil.matt(_anreisser(str(n["text"])), Stil.S_KLEIN))
	var fuss := Stil.hbox(8)
	karte.add_child(fuss)
	var hinweise: Array = _wegweiser(n)
	for hw in hinweise:
		fuss.add_child(Stil.abzeichen(str(hw), Stil.TEXT_SCHWACH))
	fuss.add_child(Stil.dehner())
	var lesen := Stil.knopf_flach("Lesen ›", Stil.AKZENT)
	lesen.pressed.connect(func():
		Nachrichtenfenster.oeffnen(self, n)
		aktualisieren())
	fuss.add_child(lesen)
	# Die ganze Karte ist anklickbar: wer eine Schlagzeile liest, will den
	# Artikel und nicht erst den passenden Knopf suchen.
	var wurzel := Stil.karte_wurzel(karte)
	wurzel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wurzel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Nachrichtenfenster.oeffnen(self, n)
			aktualisieren())
	return wurzel

## Erster Satz als Anreisser — der ganze Text steht im Artikel.
func _anreisser(text: String) -> String:
	var eine_zeile: String = text.replace("\n", " ").strip_edges()
	if eine_zeile.length() <= 170:
		return eine_zeile
	var schnitt: int = eine_zeile.rfind(" ", 170)
	return eine_zeile.substr(0, maxi(schnitt, 120)) + " …"

## Was aus dieser Meldung herausführt — als Vorschau, damit man vor dem
## Klick weiß, ob sich das Öffnen lohnt.
func _wegweiser(n: Dictionary) -> Array:
	var aus: Array = []
	var daten: Dictionary = n.get("daten", {})
	var aktion: String = str(n.get("aktion", ""))
	if aktion == "anliegen":
		aus.append("GESPRÄCH")
	if aktion == "pressekonferenz":
		aus.append("PRESSEKONFERENZ")
	if str(daten.get("spieler", "")) != "" and Welt.daten["spieler"].has(str(daten["spieler"])):
		aus.append("SPIELER")
	if str(daten.get("verein", "")) != "" and Welt.daten["vereine"].has(str(daten["verein"])):
		aus.append("VEREIN")
	if str(daten.get("spiel", "")) != "":
		aus.append("SPIELBERICHT")
	return aus

func _farbe(typ: String) -> Color:
	match typ:
		"vorstand":
			return Stil.ROT
		"transfer":
			return Stil.BLAU
		"medizin":
			return Stil.ROT
		"karriere", "auszeichnung":
			return Stil.LILA
		"kabine":
			return Stil.TUERKIS
		"wettbewerb":
			return Stil.AKZENT
		"jugend":
			return Stil.GRUEN
	return Stil.TEXT_MATT
