class_name SpielplanBildschirm
extends Bildschirm
## Terminkalender: alle Partien des eigenen Vereins plus Wochenansicht der Liga.

var liste: VBoxContainer
var kalender: VBoxContainer
var nur_eigene: bool = true

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Spielplan", 0))
	kopf.add_child(Stil.dehner())
	var umschalter := Stil.knopf("Alle Partien der Liga anzeigen")
	umschalter.pressed.connect(func():
		nur_eigene = not nur_eigene
		umschalter.text = "Alle Partien der Liga anzeigen" if nur_eigene else "Nur eigene Partien anzeigen"
		aktualisieren())
	kopf.add_child(umschalter)
	kalender = Bausteine.karte_in(v, "Die nächsten drei Wochen")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	liste = Stil.vbox(4)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(liste)

func aktualisieren() -> void:
	if liste == null:
		return
	leeren(liste)
	leeren(kalender)
	_kalender()
	if Welt.mein_verein_id == "":
		liste.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	var cid := Welt.mein_verein_id
	var lid: String = str(Welt.verein(cid)["liga"])
	var partien: Array = []
	for mid in Welt.daten["spiele"].keys():
		var m: Dictionary = Welt.daten["spiele"][mid]
		if int(m["tag"]) < Welt.tag() - 400:
			continue
		var beteiligt: bool = str(m["heim"]) == cid or str(m["gast"]) == cid
		if nur_eigene and not beteiligt:
			continue
		if not nur_eigene and not beteiligt and str(m["wettbewerb"]) != lid:
			continue
		partien.append(m)
	partien.sort_custom(func(a, b): return int(a["tag"]) < int(b["tag"]))
	var letzter_monat := -1
	for m in partien:
		var d := Kalender.datum(int(m["tag"]), Welt.startjahr())
		if int(d["monat"]) != letzter_monat:
			letzter_monat = int(d["monat"])
			liste.add_child(Stil.abstand(6))
			liste.add_child(Stil.titel("%s %d" % [Kalender.MONATSNAMEN[letzter_monat - 1], int(d["jahr"])], 1, Stil.AKZENT))
			liste.add_child(Stil.trenner())
		var zeile := _zeile(m, cid)
		liste.add_child(zeile)

func _zeile(m: Dictionary, cid: String) -> Control:
	var knopf := Button.new()
	knopf.flat = true
	knopf.custom_minimum_size = Vector2(0, 30)
	var h := Bausteine.spielzeile(str(m["id"]), cid)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for kind in h.get_children():
		kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(m["gespielt"]) and (str(m["heim"]) == cid or str(m["gast"]) == cid):
		var eigene: int = int(m["tore_heim"]) if str(m["heim"]) == cid else int(m["tore_gast"])
		var fremde: int = int(m["tore_gast"]) if str(m["heim"]) == cid else int(m["tore_heim"])
		var ergebnis := "S" if eigene > fremde else ("U" if eigene == fremde else "N")
		var farbe: Color = Stil.GRUEN if ergebnis == "S" else (Stil.GELB if ergebnis == "U" else Stil.ROT)
		var abz := Stil.abzeichen(ergebnis, farbe)
		abz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(abz)
	if int(m["tag"]) == Welt.tag():
		var heute := Stil.abzeichen("HEUTE", Stil.AKZENT, true)
		heute.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(heute)
	knopf.add_child(h)
	if bool(m["gespielt"]):
		knopf.pressed.connect(func(): Spielbericht.oeffnen(self, str(m["id"])))
	return knopf

## Tagesübersicht: was in den nächsten 21 Tagen ansteht — Spiele, feste
## Wochentermine, Fristen und laufende Vorgänge.
func _kalender() -> void:
	if Welt.mein_verein_id == "":
		kalender.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)
	var gefunden := 0
	for versatz in range(0, 22):
		var tag: int = Welt.tag() + versatz
		var eintraege: Array = []
		for mid in Welt.spiele_am_tag(tag):
			var m: Dictionary = Welt.partie(mid)
			if str(m["heim"]) != cid and str(m["gast"]) != cid:
				continue
			var gegner: String = str(m["gast"]) if str(m["heim"]) == cid else str(m["heim"])
			eintraege.append({"text": "%s %s (%s)" % ["gegen" if str(m["heim"]) == cid else "bei",
				Welt.verein(gegner).get("name", ""), Welt.wettbewerb_name(str(m["wettbewerb"]))],
				"farbe": Stil.AKZENT})
		var wt: int = Kalender.wochentag(tag)
		if wt == 0:
			eintraege.append({"text": "Wochenbericht: Training, Abrechnung, Presse, Vorstand", "farbe": Stil.TEXT_MATT})
		elif wt == 3:
			eintraege.append({"text": "Kabinengespräche und Gerüchteküche", "farbe": Stil.TEXT_MATT})
		for a in Welt.daten["scouting"]["auftraege"]:
			if not bool(a.get("fertig", false)) and int(a["ende"]) == tag:
				eintraege.append({"text": "Scoutbericht erwartet: %s" % Scouting.AUFTRAGSARTEN[str(a["art"])]["name"], "farbe": Stil.BLAU})
		var projekt: Dictionary = v["halle"]["bauprojekt"]
		if not projekt.is_empty() and int(projekt["fertig_tag"]) == tag:
			eintraege.append({"text": "Bauprojekt fertig: %s" % Finanzen.AUSBAU_STUFEN[str(projekt["bereich"])]["name"], "farbe": Stil.GRUEN})
		var tis: int = Kalender.tag_in_saison(tag)
		if tis == Transfermarkt.SOMMER_BIS or tis == Transfermarkt.WINTER_BIS:
			eintraege.append({"text": "Letzter Tag des Transferfensters", "farbe": Stil.ROT})
		if tis == Transfermarkt.WINTER_VON:
			eintraege.append({"text": "Das Transferfenster öffnet", "farbe": Stil.GRUEN})
		if tis == Spielplan.WINTERPAUSE_VON:
			eintraege.append({"text": "Beginn der Winterpause", "farbe": Stil.TEXT_MATT})
		if tis == Spielplan.SAISON_ABSCHLUSS:
			eintraege.append({"text": "Saisonabschluss: Titel, Auf- und Abstieg, Ehrungen", "farbe": Stil.LILA})
		if eintraege.is_empty():
			continue
		gefunden += 1
		var zeile := Stil.hbox(10)
		kalender.add_child(zeile)
		var datum := Stil.text(Kalender.text(tag, Welt.startjahr()), Stil.S_KLEIN,
			Stil.AKZENT if versatz == 0 else Stil.TEXT_MATT)
		datum.custom_minimum_size = Vector2(120, 0)
		zeile.add_child(datum)
		var box := Stil.vbox(1)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(box)
		for e in eintraege:
			box.add_child(Stil.text(str(e["text"]), Stil.S_KLEIN, e["farbe"]))
		if versatz == 0:
			zeile.add_child(Stil.abzeichen("HEUTE", Stil.AKZENT, true))
	if gefunden == 0:
		kalender.add_child(Stil.matt("In den nächsten drei Wochen steht nichts an."))
