class_name Bausteine
extends RefCounted
## Wiederverwendbare Oberflaechen-Bausteine, die in mehreren Bildschirmen vorkommen.
## Alles baut ausschliesslich auf Stil auf.

## Zeile "Wappen + Vereinsname", anklickbar.
static func vereinszeile(cid: String, groesse: int = 22, kurz: bool = false) -> HBoxContainer:
	var h := Stil.hbox(6)
	var w := Wappen.fuer_verein(cid, float(groesse))
	h.add_child(w)
	var v: Dictionary = Welt.verein(cid)
	var l := Stil.text(str(v.get("kurz", "???")) if kurz else str(v.get("name", "?")), Stil.S_KLEIN)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h

## Farbiges Kuerzel fuer eine Position.
static func positions_abzeichen(position: String) -> PanelContainer:
	var farben := {
		"TW": Stil.GELB, "LA": Stil.BLAU, "RA": Stil.BLAU, "RL": Stil.LILA,
		"RM": Stil.AKZENT, "RR": Stil.LILA, "KM": Stil.TUERKIS,
	}
	return Stil.abzeichen(position, farben.get(position, Stil.TEXT_MATT))

## Formkurve als kleine Buchstabenkette (S/U/N).
static func formkurve(kurve: Array, anzahl: int = 5) -> HBoxContainer:
	var h := Stil.hbox(3)
	var start: int = maxi(kurve.size() - anzahl, 0)
	for i in range(start, kurve.size()):
		var e: String = str(kurve[i])
		var farbe: Color = Stil.GRUEN if e == "S" else (Stil.GELB if e == "U" else Stil.ROT)
		var p := PanelContainer.new()
		var sb := Stil.box(Color(farbe.r, farbe.g, farbe.b, 0.85), 3)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		p.add_theme_stylebox_override("panel", sb)
		var l := Stil.text(e, Stil.S_MINI, Stil.GRUND)
		p.add_child(l)
		h.add_child(p)
	return h

## Kompakte Spielerzeile fuer Listen. spalten bestimmt die angezeigten Felder.
static func spieler_kacheln(sid: String) -> Dictionary:
	var sp: Dictionary = Welt.spieler(sid)
	var kacheln := {}
	kacheln["name"] = Spielerfabrik.voller_name(sp)
	kacheln["position"] = str(sp["position"])
	kacheln["alter"] = int(sp["alter"])
	kacheln["gesamt"] = Scouting.gesamt_text(Welt.daten, sid)
	kacheln["form"] = float(sp["form"])
	kacheln["fitness"] = float(sp["fitness"])
	kacheln["last"] = float(sp["last"])
	kacheln["moral"] = float(sp["moral"])
	kacheln["wert"] = float(sp["wert"])
	return kacheln

## Statuszeichen eines Spielers (verletzt, gesperrt, Transferwunsch ...).
static func status_zeichen(sid: String) -> HBoxContainer:
	var sp: Dictionary = Welt.spieler(sid)
	var h := Stil.hbox(3)
	if not (sp["verletzung"] as Dictionary).is_empty():
		var a := Stil.abzeichen("VERL", Stil.ROT)
		a.tooltip_text = Medizin.verletzungstext(sp)
		h.add_child(a)
	if int(sp["sperre"]) > 0:
		h.add_child(Stil.abzeichen("SPERRE", Stil.ROT))
	if bool(sp.get("transferwunsch", false)):
		var t := Stil.abzeichen("WECHSEL", Stil.GELB)
		t.tooltip_text = "Der Spieler hat um einen Wechsel gebeten."
		h.add_child(t)
	if bool(sp.get("auf_transferliste", false)):
		h.add_child(Stil.abzeichen("LISTE", Stil.LILA))
	if float(sp["last"]) > 72.0:
		var l := Stil.abzeichen("LAST", Stil.AKZENT)
		l.tooltip_text = "Hohes Lastkonto — erhöhtes Verletzungsrisiko."
		h.add_child(l)
	var rest: int = int(sp["vertrag"].get("bis_saison", 9)) - Welt.saison_index()
	if not (sp["vertrag"] as Dictionary).is_empty() and rest <= 0:
		var v := Stil.abzeichen("VERTRAG", Stil.GELB)
		v.tooltip_text = "Vertrag läuft am Saisonende aus."
		h.add_child(v)
	return h

## Wertdarstellung mit Farbe (fuer Attribute 1..20).
static func attributwert(text: String, wert: float) -> Label:
	var l := Stil.text(text, Stil.S_KLEIN, Stil.wert_farbe(wert))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

## Ergebniszeile einer Partie.
static func spielzeile(mid: String, eigener: String = "") -> HBoxContainer:
	var m: Dictionary = Welt.partie(mid)
	var h := Stil.hbox(8)
	h.add_child(Stil.matt(Kalender.kurz(int(m["tag"]), Welt.startjahr()), Stil.S_MINI))
	var wb := Stil.matt(Welt.wettbewerb_name(str(m["wettbewerb"])).substr(0, 22), Stil.S_MINI)
	wb.custom_minimum_size = Vector2(150, 0)
	h.add_child(wb)
	var heim: Dictionary = Welt.verein(str(m["heim"]))
	var gast: Dictionary = Welt.verein(str(m["gast"]))
	var heim_label := Stil.text(str(heim.get("name", "")), Stil.S_KLEIN,
		Stil.AKZENT if str(m["heim"]) == eigener else Stil.TEXT)
	heim_label.custom_minimum_size = Vector2(190, 0)
	heim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(heim_label)
	if bool(m["gespielt"]):
		var erg := Stil.text("%d : %d" % [int(m["tore_heim"]), int(m["tore_gast"])], Stil.S_KLEIN, Stil.TEXT)
		erg.custom_minimum_size = Vector2(56, 0)
		erg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(erg)
	else:
		var uhr := Stil.matt("– : –", Stil.S_KLEIN)
		uhr.custom_minimum_size = Vector2(56, 0)
		uhr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(uhr)
	var gast_label := Stil.text(str(gast.get("name", "")), Stil.S_KLEIN,
		Stil.AKZENT if str(m["gast"]) == eigener else Stil.TEXT)
	gast_label.custom_minimum_size = Vector2(190, 0)
	h.add_child(gast_label)
	return h

## Erzeugt eine Karte mit Ueberschrift und gibt den Inhaltscontainer zurueck.
static func karte_in(eltern: Node, ueberschrift: String, hoch: bool = false) -> VBoxContainer:
	var inhalt := Stil.karte(ueberschrift, hoch)
	eltern.add_child(Stil.karte_wurzel(inhalt))
	return inhalt

## Balken mit Beschriftung (z. B. "Form 72").
static func wertzeile(beschriftung: String, wert: float, maximum: float = 100.0, hinweis: String = "") -> HBoxContainer:
	var h := Stil.hbox(8)
	var l := Stil.matt(beschriftung, Stil.S_KLEIN)
	l.custom_minimum_size = Vector2(96, 0)
	h.add_child(l)
	h.add_child(Stil.balken(wert, maximum, 96))
	var z := Stil.text(str(int(round(wert))), Stil.S_KLEIN, Stil.prozent_farbe(wert / maximum * 100.0))
	z.custom_minimum_size = Vector2(30, 0)
	z.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(z)
	if hinweis != "":
		h.tooltip_text = hinweis
	return h
