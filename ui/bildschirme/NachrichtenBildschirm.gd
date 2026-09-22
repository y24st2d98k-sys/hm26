class_name NachrichtenBildschirm
extends Bildschirm
## Posteingang: alle Meldungen aus Verein, Medizin, Transfer, Vorstand und Karriere.

var liste: VBoxContainer
## Der Lesebereich rechts neben der Liste.
var artikel: VBoxContainer
var filter: String = ""
## Die offene Meldung. Ein Posteingang, der jede Nachricht als Karte mit
## Anreisser ausbreitet, ist vier Bildschirmhoehen lang; schmale Zeilen links
## und der ganze Text rechts sind eine.
var offen: Dictionary = {}
## Wie viele Zeilen die Liste zeigt. Achtzig Meldungen sind eineinhalb
## Bildschirmhoehen; wer weiter zurueck will, sagt es.
const ZEILEN_START := 17
const ZEILEN_SCHRITT := 25
var sichtbare_zeilen: int = ZEILEN_START

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
	var wahl := OptionButton.new()
	var i := 0
	for k in TYPEN.keys():
		wahl.add_item(str(TYPEN[k]))
		wahl.set_item_metadata(i, k)
		i += 1
	wahl.item_selected.connect(func(idx):
		filter = str(wahl.get_item_metadata(idx))
		sichtbare_zeilen = ZEILEN_START
		aktualisieren())
	kopf.add_child(wahl)
	var alle := Stil.knopf("Alle als gelesen markieren")
	alle.pressed.connect(func():
		for n in Welt.daten.get("nachrichten", []):
			n["gelesen"] = true
		Welt.zustand_geaendert.emit()
		aktualisieren())
	kopf.add_child(alle)
	var haupt := Stil.hbox(Stil.A_NORMAL)
	haupt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(haupt)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.0
	scroll.custom_minimum_size = Vector2(430, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	haupt.add_child(scroll)
	liste = Stil.vbox(3)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(liste)
	# Der Lesebereich rollt fuer sich: ein langer Artikel soll die Liste
	# daneben nicht verschieben.
	var rechts := ScrollContainer.new()
	rechts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.size_flags_stretch_ratio = 1.25
	rechts.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	haupt.add_child(rechts)
	var rahmen := Stil.karte("")
	Stil.karte_wurzel(rahmen).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.add_child(Stil.karte_wurzel(rahmen))
	artikel = rahmen

func aktualisieren() -> void:
	if liste == null:
		return
	leeren(liste)
	var nachrichten: Array = Welt.daten.get("nachrichten", [])
	var gezeigt := 0
	var uebrig := 0
	for n in nachrichten:
		if filter != "" and str(n["typ"]) != filter:
			continue
		if gezeigt >= sichtbare_zeilen:
			uebrig += 1
			continue
		liste.add_child(_eintrag(n, gezeigt))
		gezeigt += 1
	if gezeigt == 0:
		liste.add_child(Stil.matt("Keine Nachrichten in dieser Kategorie."))
	if uebrig > 0:
		var mehr := Stil.knopf("%d ältere anzeigen" % mini(uebrig, ZEILEN_SCHRITT))
		mehr.pressed.connect(func():
			sichtbare_zeilen += ZEILEN_SCHRITT
			aktualisieren())
		liste.add_child(mehr)
	_artikel_zeichnen()

## Die gewählte Meldung als Artikel — oder ein Hinweis, wenn keine gewählt ist.
func _artikel_zeichnen() -> void:
	leeren(artikel)
	if offen.is_empty():
		artikel.add_child(Stil.matt("Wählen Sie links eine Meldung."))
		return
	Nachrichtenfenster.artikel_bauen(artikel, offen, self, Callable(), 420.0)

## Öffnet eine Meldung im Lesebereich. Gelesen ist sie erst hier — wer an der
## Liste vorbeigelaufen ist, hat nichts gelesen.
func _oeffne(n: Dictionary) -> void:
	offen = n
	n["gelesen"] = true
	Welt.zustand_geaendert.emit()
	aktualisieren()

## Eine Nachricht in der Liste: eine Zeile, kein Aufsatz.
##
## Vorher stand jede Meldung als Karte mit Anreisser und Fussleiste da — bei
## achtzig Meldungen vier Bildschirmhoehen, von denen man drei nie gesehen
## hat. Jetzt traegt die Zeile das, wonach man sucht (Art, Schlagzeile,
## Datum), und der Rest steht rechts.
func _eintrag(n: Dictionary, index: int) -> Control:
	# Auf Gleichheit der Verweise, nicht des Inhalts: zwei Meldungen mit
	# demselben Wortlaut sind zwei Meldungen.
	var ausgewaehlt: bool = is_same(offen, n)
	var knopf := Stil.zeilen_knopf(index, ausgewaehlt, 34)
	var h := Stil.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knopf.add_child(h)
	var typ := Stil.abzeichen(str(TYPEN.get(str(n["typ"]), str(n["typ"]))), _farbe(str(n["typ"])))
	typ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(typ)
	var betreff := Stil.text(str(n["betreff"]), Stil.S_KLEIN,
		Stil.AKZENT if bool(n["wichtig"]) else (Stil.TEXT if not bool(n["gelesen"]) else Stil.TEXT_MATT))
	betreff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Stil.beschnitten(betreff, 20.0))
	h.add_child(Stil.dehner())
	if not bool(n["gelesen"]):
		var neu_abz := Stil.abzeichen("NEU", Stil.AKZENT, true)
		neu_abz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(neu_abz)
	var datum := Stil.matt(Kalender.kurz(int(n["tag"]), Welt.startjahr()), Stil.S_MINI)
	datum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(datum)
	knopf.pressed.connect(func(): _oeffne(n))
	return knopf


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
