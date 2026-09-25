class_name MedienBildschirm
extends Bildschirm
## Presse und "Hallenfunk" — die Immersionsschicht.

## Die Schlagzeilenliste links, der gewählte Bericht rechts.
var kopfzeilen: VBoxContainer
var bericht: VBoxContainer
var social_bereich: VBoxContainer
## Welcher Bericht offen steht. Dreißig Artikel mit vollem Text untereinander
## waren fünf Bildschirmhöhen — man hat nie mehr als den ersten gelesen.
var offen: Dictionary = {}
var reiter := "presse"
## Wie viele Schlagzeilen die Liste zeigt. Dreissig sind knapp zwei
## Bildschirmhoehen; wer weiter zurueck will, sagt es.
const ZEILEN_START := 15
const ZEILEN_SCHRITT := 15
var sichtbare_zeilen: int = ZEILEN_START
var reiterleiste: HBoxContainer
var presse_halter: HBoxContainer
var funk_halter: ScrollContainer

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(12)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Medien", 0))
	kopf.add_child(Stil.matt("Presse und Fans reagieren auf das, was tatsächlich passiert ist: auf Ergebnisse, Derbys, Serien, Einzelleistungen und die Lage im Verein.", Stil.S_KLEIN))
	# Handgebaute Reiter statt Stil.reitergruppe: die Presseseite ist ein
	# geteiltes Fenster, das die freie Hoehe braucht. In einem Rollbereich —
	# und den bringt die Reitergruppe fuer jeden Abschnitt mit — bekommt ein
	# dehnbarer Behaelter nur seine Mindesthoehe, und die ist hier null.
	reiterleiste = Stil.hbox(0)
	v.add_child(reiterleiste)
	_reiter_bauen()

	var haupt := Stil.hbox(Stil.A_NORMAL)
	haupt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	presse_halter = haupt
	v.add_child(haupt)
	var links := ScrollContainer.new()
	links.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.size_flags_vertical = Control.SIZE_EXPAND_FILL
	links.custom_minimum_size = Vector2(430, 0)
	haupt.add_child(links)
	kopfzeilen = Stil.vbox(3)
	kopfzeilen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_child(kopfzeilen)
	# Der Bericht rollt für sich: ein langer Artikel soll die Schlagzeilen
	# daneben nicht verschieben.
	var rechts := ScrollContainer.new()
	rechts.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rechts.size_flags_stretch_ratio = 1.25
	haupt.add_child(rechts)
	var rahmen := Stil.karte("")
	Stil.karte_wurzel(rahmen).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.add_child(Stil.karte_wurzel(rahmen))
	bericht = rahmen

	var funk := ScrollContainer.new()
	funk.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	funk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	funk.size_flags_vertical = Control.SIZE_EXPAND_FILL
	funk_halter = funk
	v.add_child(funk)
	social_bereich = Stil.vbox(6)
	social_bereich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	funk.add_child(social_bereich)
	_reiter_zeigen()

func _reiter_bauen() -> void:
	leeren(reiterleiste)
	reiterleiste.add_child(Stil.segmente([
		{"id": "presse", "name": "Presse"}, {"id": "funk", "name": "Hallenfunk"}],
		reiter, func(id):
			reiter = str(id)
			_reiter_bauen()
			_reiter_zeigen()))
	reiterleiste.add_child(Stil.dehner())

func _reiter_zeigen() -> void:
	if presse_halter == null:
		return
	presse_halter.visible = reiter == "presse"
	funk_halter.visible = reiter == "funk"

func aktualisieren() -> void:
	if kopfzeilen == null:
		return
	leeren(kopfzeilen)
	leeren(social_bereich)
	var presse: Array = Welt.daten.get("presse", [])
	if presse.is_empty():
		kopfzeilen.add_child(Stil.matt("Noch keine Berichte."))
	var index := 0
	for a in presse.slice(0, sichtbare_zeilen):
		kopfzeilen.add_child(_kopfzeile(a, index))
		index += 1
	var uebrig: int = maxi(mini(presse.size(), 30) - sichtbare_zeilen, 0)
	if uebrig > 0:
		var mehr := Stil.knopf("%d ältere anzeigen" % mini(uebrig, ZEILEN_SCHRITT))
		mehr.pressed.connect(func():
			sichtbare_zeilen += ZEILEN_SCHRITT
			aktualisieren())
		kopfzeilen.add_child(mehr)
	_bericht_zeichnen()
	_hallenfunk()

## Eine Schlagzeile als Zeile: Blatt, Titel, Datum. Der Text steht rechts.
func _kopfzeile(a: Dictionary, index: int) -> Control:
	var knopf := Stil.zeilen_knopf(index, is_same(offen, a), 38)
	var h := Stil.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knopf.add_child(h)
	var spalte := Stil.vbox(0)
	spalte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var titel := Stil.text(str(a["schlagzeile"]), Stil.S_KLEIN, Stil.tonfarbe(str(a["tonfall"])))
	titel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spalte.add_child(Stil.beschnitten(titel, 18.0))
	var unter := Stil.matt("%s · %s" % [str(a["outlet"]),
		Kalender.kurz(int(a["tag"]), Welt.startjahr())], Stil.S_MINI)
	unter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spalte.add_child(Stil.beschnitten(unter, 14.0))
	h.add_child(spalte)
	knopf.pressed.connect(func():
		offen = a
		aktualisieren())
	return knopf

func _bericht_zeichnen() -> void:
	leeren(bericht)
	if offen.is_empty():
		bericht.add_child(Stil.matt("Wählen Sie links eine Schlagzeile."))
		return
	var kopf := Stil.hbox(8)
	bericht.add_child(kopf)
	kopf.add_child(Stil.text(str(offen["outlet"]), Stil.S_KLEIN, Stil.AKZENT))
	kopf.add_child(Stil.matt("· %s · %s · %s" % [
		str(offen.get("gattung", "Tageszeitung")), str(offen["haltung"]),
		Kalender.text(int(offen["tag"]), Welt.startjahr())], Stil.S_MINI))
	var titel := Stil.text(str(offen["schlagzeile"]), Stil.S_TITEL - 6, Stil.tonfarbe(str(offen["tonfall"])))
	titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titel.custom_minimum_size = Vector2(420, 0)
	bericht.add_child(titel)
	bericht.add_child(Stil.trenner())
	var text := Stil.text(str(offen["text"]), Stil.S_NORMAL, Stil.TEXT_MATT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(420, 0)
	bericht.add_child(text)

## Der Hallenfunk in drei Spalten. Ein Beitrag ist drei Zeilen lang; vierzig
## davon untereinander sind drei Bildschirmhöhen, achtzehn nebeneinander eine.
func _hallenfunk() -> void:
	var social: Array = Welt.daten.get("social", [])
	if social.is_empty():
		social_bereich.add_child(Stil.matt("Noch keine Beiträge."))
		return
	var reihe := Stil.hbox(Stil.A_NORMAL)
	reihe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	social_bereich.add_child(reihe)
	var spalten: Array = []
	for i in 3:
		var sp := Stil.vbox(6)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reihe.add_child(sp)
		spalten.append(sp)
	var gezeigt: Array = social.slice(0, 18)
	var pro: int = int(ceil(float(gezeigt.size()) / 3.0))
	var nummer := 0
	for b in gezeigt:
		var ziel: VBoxContainer = spalten[mini(nummer / maxi(pro, 1), 2)]
		nummer += 1
		var karte := Stil.karte("", true)
		ziel.add_child(Stil.karte_wurzel(karte))
		var kopf := Stil.hbox(6)
		karte.add_child(kopf)
		var handle := Stil.text(str(b["handle"]), Stil.S_KLEIN, Stil.BLAU)
		kopf.add_child(Stil.beschnitten(handle, 18.0))
		kopf.add_child(Stil.matt("· %s" % str(b["typ"]), Stil.S_MINI))
		kopf.add_child(Stil.dehner())
		kopf.add_child(Stil.matt("%s ♥" % Stil.zahl(int(b["gefaellt"])), Stil.S_MINI))
		var t2 := Stil.text(str(b["text"]), Stil.S_KLEIN, Stil.tonfarbe(str(b["tonfall"])))
		t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t2.custom_minimum_size = Vector2(260, 0)
		karte.add_child(t2)


