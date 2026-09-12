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
	var text := Stil.text(str(n["text"]), Stil.S_KLEIN, Stil.TEXT_MATT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	karte.add_child(text)
	if str(n.get("aktion", "")) == "pressekonferenz" and Presse.offen(Welt.daten):
		var pk := Stil.knopf_primaer("Zur Pressekonferenz")
		pk.pressed.connect(func(): Pressefenster.oeffnen(self))
		karte.add_child(pk)
	var daten: Dictionary = n.get("daten", {})
	if daten.has("spieler") and Welt.daten["spieler"].has(str(daten["spieler"])):
		var k := Stil.knopf_flach("Spielerprofil öffnen")
		var sid: String = str(daten["spieler"])
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		karte.add_child(k)
	n["gelesen"] = true
	return Stil.karte_wurzel(karte)

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
