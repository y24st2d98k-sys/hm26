class_name SpielplanBildschirm
extends Bildschirm
## Terminkalender: alle Partien des eigenen Vereins plus Wochenansicht der Liga.

var liste: VBoxContainer
var kalender: VBoxContainer
var nur_eigene: bool = true
## "termine" oder "saison". Die naechsten drei Wochen und der ganze
## Spielplan standen untereinander: zusammen zwei Bildschirmhoehen, von denen
## man immer nur eine braucht.
## In wie vielen Spalten die Saison steht. Eine Saison hat rund vierzig
## Termine; untereinander sind das zwei Bildschirmhoehen.
const SPALTEN := 3
var reiter := "termine"
var gruppe: Stil.Reitergruppe

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	var umschalter := Stil.knopf("Alle Partien der Liga anzeigen")
	umschalter.pressed.connect(func():
		nur_eigene = not nur_eigene
		umschalter.text = "Alle Partien der Liga anzeigen" if nur_eigene else "Nur eigene Partien anzeigen"
		aktualisieren())
	kopf.add_child(umschalter)
	gruppe = Stil.reitergruppe([
		{"id": "termine", "name": "Die nächsten drei Wochen"},
		{"id": "saison", "name": "Ganze Saison"},
	], reiter)
	gruppe.bei_wechsel = func(id): reiter = str(id)
	v.add_child(gruppe)
	kalender = Bausteine.karte_in(gruppe.feld("termine"), "Was ansteht")
	liste = Stil.vbox(4)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gruppe.feld("saison").add_child(liste)

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
	# Eine Saison hat rund vierzig Termine. Untereinander sind das zwei
	# Bildschirmhoehen; in zwei Spalten ist es eine — und ein Spielplan, den
	# man ganz sieht, ist der halbe Zweck eines Spielplans.
	var reihe := Stil.hbox(Stil.A_NORMAL)
	reihe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_child(reihe)
	var spalten: Array = []
	for i in SPALTEN:
		var sp := Stil.vbox(4)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reihe.add_child(sp)
		spalten.append(sp)
	var pro_spalte: int = int(ceil(float(partien.size()) / float(SPALTEN)))
	var letzter_monat := -1
	var nummer := 0
	var zaehler := 0
	for m in partien:
		var spalte: int = mini(zaehler / maxi(pro_spalte, 1), SPALTEN - 1)
		var ziel: VBoxContainer = spalten[spalte]
		var neue_spalte: bool = zaehler > 0 and zaehler % maxi(pro_spalte, 1) == 0
		var d := Kalender.datum(int(m["tag"]), Welt.startjahr())
		if int(d["monat"]) != letzter_monat or neue_spalte:
			letzter_monat = int(d["monat"])
			if zaehler > 0 and not neue_spalte:
				ziel.add_child(Stil.abstand(6))
			ziel.add_child(Stil.band("%s %d" % [Kalender.MONATSNAMEN[letzter_monat - 1], int(d["jahr"])]))
			nummer = 0
		ziel.add_child(_zeile(m, cid, nummer))
		nummer += 1
		zaehler += 1

func _zeile(m: Dictionary, cid: String, index: int = 0) -> Control:
	var eigenes: bool = str(m["heim"]) == cid or str(m["gast"]) == cid
	var knopf := Stil.zeilen_knopf(index, eigenes and int(m["tag"]) >= Welt.tag(), 30)
	var h := Bausteine.spielzeile_kurz(str(m["id"]), cid)
	# Die Zeile nimmt keine Maus an, damit der Knopf darunter den Klick
	# bekommt — also traegt der Knopf auch den Hinweis mit den ganzen Namen.
	knopf.tooltip_text = h.tooltip_text
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
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
	elif str(m["heim"]) == cid or str(m["gast"]) == cid:
		# Noch offene eigene Partie: direkt in die Spielvorbereitung springen.
		var gegner: String = str(m["gast"]) if str(m["heim"]) == cid else str(m["heim"])
		knopf.pressed.connect(func(): Vorberichtsfenster.oeffnen(self, gegner, str(m["id"])))
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
			if m.is_empty() or (str(m["heim"]) != cid and str(m["gast"]) != cid):
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
