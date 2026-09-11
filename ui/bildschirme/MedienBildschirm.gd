class_name MedienBildschirm
extends Bildschirm
## Presse und "Hallenfunk" — die Immersionsschicht.

var presse_bereich: VBoxContainer
var social_bereich: VBoxContainer

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	v.add_child(Stil.titel("Medien", 0))
	v.add_child(Stil.matt("Presse und Fans reagieren auf das, was tatsächlich passiert ist: auf Ergebnisse, Derbys, Serien, Einzelleistungen und die Lage im Verein.", Stil.S_KLEIN))
	var spalten := HSplitContainer.new()
	spalten.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spalten)
	var links := ScrollContainer.new()
	links.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	links.custom_minimum_size = Vector2(640, 0)
	spalten.add_child(links)
	presse_bereich = Stil.vbox(10)
	presse_bereich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_child(presse_bereich)
	var rechts := ScrollContainer.new()
	rechts.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	spalten.add_child(rechts)
	social_bereich = Stil.vbox(6)
	social_bereich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.add_child(social_bereich)

func aktualisieren() -> void:
	if presse_bereich == null:
		return
	leeren(presse_bereich)
	leeren(social_bereich)
	presse_bereich.add_child(Stil.titel("Presse", 1))
	var presse: Array = Welt.daten.get("presse", [])
	if presse.is_empty():
		presse_bereich.add_child(Stil.matt("Noch keine Berichte."))
	for a in presse.slice(0, 30):
		var karte := Stil.karte("")
		presse_bereich.add_child(Stil.karte_wurzel(karte))
		var kopf := Stil.hbox(8)
		karte.add_child(kopf)
		kopf.add_child(Stil.text(str(a["outlet"]), Stil.S_MINI, Stil.AKZENT))
		kopf.add_child(Stil.matt("· %s · %s" % [str(a["haltung"]), Kalender.text(int(a["tag"]), Welt.startjahr())], Stil.S_MINI))
		var titel := Stil.text(str(a["schlagzeile"]), Stil.S_GROSS, _farbe(str(a["tonfall"])))
		titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		karte.add_child(titel)
		var text := Stil.text(str(a["text"]), Stil.S_KLEIN, Stil.TEXT_MATT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		karte.add_child(text)

	social_bereich.add_child(Stil.titel("Hallenfunk", 1))
	var social: Array = Welt.daten.get("social", [])
	if social.is_empty():
		social_bereich.add_child(Stil.matt("Noch keine Beiträge."))
	for b in social.slice(0, 40):
		var karte2 := Stil.karte("", true)
		social_bereich.add_child(Stil.karte_wurzel(karte2))
		var kopf2 := Stil.hbox(6)
		karte2.add_child(kopf2)
		kopf2.add_child(Stil.text(str(b["handle"]), Stil.S_KLEIN, Stil.BLAU))
		kopf2.add_child(Stil.matt("· %s" % str(b["typ"]), Stil.S_MINI))
		kopf2.add_child(Stil.dehner())
		kopf2.add_child(Stil.matt("%s ♥" % Stil.zahl(int(b["gefaellt"])), Stil.S_MINI))
		var t2 := Stil.text(str(b["text"]), Stil.S_KLEIN, _farbe(str(b["tonfall"])))
		t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		karte2.add_child(t2)

func _farbe(tonfall: String) -> Color:
	match tonfall:
		"jubel", "lob":
			return Stil.GRUEN
		"kritik":
			return Stil.GELB
		"verriss":
			return Stil.ROT
	return Stil.TEXT
