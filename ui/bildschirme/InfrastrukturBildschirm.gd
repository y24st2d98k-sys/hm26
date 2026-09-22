class_name InfrastrukturBildschirm
extends Bildschirm
## Halle und Infrastruktur ausbauen.

var inhalt: VBoxContainer
var meldung: Label

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	kopf.add_child(meldung)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)

func aktualisieren() -> void:
	if inhalt == null:
		return
	leeren(inhalt)
	if Welt.mein_verein_id == "":
		inhalt.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)
	var projekt: Dictionary = v["halle"]["bauprojekt"]
	if not projekt.is_empty():
		var lauf := Bausteine.karte_in(inhalt, "Laufendes Bauprojekt")
		lauf.add_child(Stil.text(str(Finanzen.AUSBAU_STUFEN[str(projekt["bereich"])]["name"]), Stil.S_NORMAL, Stil.AKZENT))
		lauf.add_child(Stil.info_zeile("Fertigstellung", Kalender.text(int(projekt["fertig_tag"]), Welt.startjahr(), true)))
		lauf.add_child(Stil.info_zeile("Kosten", Stil.geld(float(projekt["kosten"]))))
		lauf.add_child(Stil.matt("Solange ein Projekt läuft, kann kein zweites begonnen werden.", Stil.S_MINI))

	var halle := Bausteine.karte_in(inhalt, "Halle: %s" % str(v["halle"]["name"]))
	halle.add_child(Stil.info_zeile("Kapazität", Stil.zahl(int(v["halle"]["kapazitaet"]))))
	halle.add_child(Stil.info_zeile("Komfort", "Stufe %d" % int(v["halle"]["komfort"])))
	halle.add_child(Stil.info_zeile("Hallenpuls-Grundwert", "%d" % int(float(v["hallenpuls_basis"])),
		Stil.prozent_farbe(float(v["hallenpuls_basis"]))))
	halle.add_child(Stil.matt("Der Hallenpuls beschreibt, wie stark Ihr Publikum die Mannschaft trägt. Er wächst mit Ausbau, Auslastung und Fantreue.", Stil.S_MINI))
	halle.add_child(_ausbauzeile(cid, "halle"))

	var karte := Bausteine.karte_in(inhalt, "Ausbaustufen")
	for bereich in ["trainingszentrum", "jugendarbeit", "medizin", "analyse", "regeneration"]:
		var block := Stil.vbox(4)
		karte.add_child(block)
		var kopf := Stil.hbox(10)
		block.add_child(kopf)
		var bezeichnung := Stil.text(str(Finanzen.AUSBAU_STUFEN[bereich]["name"]), Stil.S_NORMAL)
		bezeichnung.custom_minimum_size = Vector2(230, 0)
		kopf.add_child(bezeichnung)
		var stufe: int = int(v["infrastruktur"][bereich])
		kopf.add_child(Stil.balken(float(stufe), 10.0, 140))
		kopf.add_child(Stil.text("Stufe %d / 10" % stufe, Stil.S_KLEIN, Stil.wert_farbe(float(stufe), 10.0)))
		kopf.add_child(Stil.dehner())
		kopf.add_child(_ausbauzeile(cid, bereich))
		block.add_child(Stil.matt(str(Finanzen.AUSBAU_STUFEN[bereich]["beschreibung"]), Stil.S_MINI))
		karte.add_child(Stil.trenner())

func _ausbauzeile(cid: String, bereich: String) -> HBoxContainer:
	var h := Stil.hbox(8)
	var kosten := Finanzen.ausbaukosten(Welt.daten, cid, bereich)
	h.add_child(Stil.matt(Stil.geld(kosten), Stil.S_KLEIN))
	var knopf := Stil.knopf_primaer("Ausbauen")
	knopf.disabled = not (Welt.verein(cid)["halle"]["bauprojekt"] as Dictionary).is_empty()
	knopf.pressed.connect(func():
		var erg := Finanzen.ausbau_starten(Welt.daten, cid, bereich)
		meldung.text = str(erg["grund"])
		meldung.add_theme_color_override("font_color", Stil.GRUEN if bool(erg["ok"]) else Stil.ROT)
		aktualisieren())
	h.add_child(knopf)
	return h
