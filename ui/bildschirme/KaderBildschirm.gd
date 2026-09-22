class_name KaderBildschirm
extends Bildschirm
## Kaderübersicht mit sortierbaren Spalten, Filtern und Kadertiefe je Position.

## Zahlen stehen rechtsbuendig, Text linksbuendig.
##
## Eine Spalte Zahlen liest man an der Einerstelle. Stehen sie links, muss das
## Auge bei jeder Zeile neu suchen, wo die Zahl aufhoert — bei "6,8 Tsd. €"
## neben "1,01 Mio. €" ist das jede Zeile eine kleine Rechenaufgabe.
const RECHTS := ["alter", "gesamt", "spiele", "tore", "note", "gehalt", "vertrag", "wert"]

const SPALTEN := [
	{"id": "nummer", "name": "#", "breite": 32},
	{"id": "position", "name": "Pos", "breite": 44},
	# 226 Pixel reichten fuer die meisten Namen, aber nicht fuer die langen:
	# "Oskar Vind Rasmussen" und "Antonio Serradilla Cuenca" standen
	# abgeschnitten da. Die Layoutpruefung hat beide gemeldet.
	{"id": "name", "name": "Name", "breite": 252},
	{"id": "alter", "name": "Alter", "breite": 52},
	{"id": "gesamt", "name": "Stärke", "breite": 60},
	{"id": "form", "name": "Form", "breite": 74},
	{"id": "fitness", "name": "Fitness", "breite": 74},
	{"id": "last", "name": "Last", "breite": 74},
	{"id": "moral", "name": "Moral", "breite": 74},
	{"id": "spiele", "name": "Sp", "breite": 38},
	{"id": "tore", "name": "Tore", "breite": 44},
	{"id": "note", "name": "Note", "breite": 46},
	{"id": "gehalt", "name": "Gehalt", "breite": 82},
	{"id": "vertrag", "name": "Vertrag", "breite": 64},
	{"id": "wert", "name": "Wert", "breite": 86},
]

var sortierung: String = "gesamt"
var absteigend: bool = true
var liste: VBoxContainer
var kopfzeile: HBoxContainer
var zusammenfassung: HBoxContainer
var filter_position: String = ""
## "liste" zeigt den Kader von heute, "planung" den Blick auf die nächsten Jahre.
var modus: String = "liste"
var modusleiste: HBoxContainer

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)

	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	modusleiste = Stil.hbox(0)
	kopf.add_child(modusleiste)
	_baue_modusleiste()
	kopf.add_child(Stil.dehner())
	kopf.add_child(Stil.matt("Position"))
	var wahl := OptionButton.new()
	wahl.add_item("alle")
	wahl.set_item_metadata(0, "")
	for p in Spielerfabrik.POSITIONEN:
		wahl.add_item(str(Spielerfabrik.POSITION_NAME[p]))
		wahl.set_item_metadata(wahl.item_count - 1, p)
	wahl.item_selected.connect(func(i):
		filter_position = str(wahl.get_item_metadata(i))
		aktualisieren())
	kopf.add_child(wahl)

	zusammenfassung = Stil.hbox(18)
	v.add_child(zusammenfassung)

	# Der Kopf sitzt in denselben Spaltenfassungen wie die Zeilen.
	#
	# Vorher standen hier nackte Buttons mit custom_minimum_size. Ein Button
	# wird aber nie schmaler als sein Text plus Rand: bei "#" (30 px), "Sp"
	# (40) und "Tore" (46) war er breiter als seine Spalte, und der Fehler
	# summierte sich nach rechts auf. Dazu sind die Datenzeilen um sechs
	# Pixel eingerueckt und der Kopf war es nicht. Auf dem Bildschirm stand
	# "Note" ueber den Toren und "Tore" ueber den Spielen.
	var kopfrahmen := Stil.hbox(0)
	v.add_child(kopfrahmen)
	kopfrahmen.add_child(_abstand(6.0))
	kopfzeile = Stil.hbox(6)
	kopfzeile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopfrahmen.add_child(kopfzeile)
	for s in SPALTEN:
		kopfzeile.add_child(_kopfzelle(str(s["id"]), str(s["name"]), float(s["breite"])))
	v.add_child(Stil.trenner())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	liste = Stil.vbox(1)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(liste)

func _baue_modusleiste() -> void:
	leeren(modusleiste)
	modusleiste.add_child(Stil.segmente([
		{"id": "liste", "name": "Kader"}, {"id": "planung", "name": "Planung"}],
		modus, func(id):
			modus = str(id)
			_baue_modusleiste()
			aktualisieren()))

func aktualisieren() -> void:
	if liste == null:
		return
	leeren(liste)
	leeren(zusammenfassung)
	kopfzeile.visible = modus == "liste"
	if Welt.mein_verein_id == "":
		liste.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	if modus == "planung":
		_planung()
		return
	var kader: Array = (Welt.verein(Welt.mein_verein_id)["kader"] as Array).duplicate()
	if filter_position != "":
		var gefiltert: Array = []
		for sid in kader:
			if str(Welt.spieler(sid)["position"]) == filter_position:
				gefiltert.append(sid)
		kader = gefiltert
	kader.sort_custom(_vergleich)
	_zusammenfassung(kader)
	var zeilennummer := 0
	for sid in kader:
		liste.add_child(_zeile(sid, zeilennummer))
		zeilennummer += 1

func _vergleich(a, b) -> bool:
	var wa: Variant = _sortwert(str(a))
	var wb: Variant = _sortwert(str(b))
	if typeof(wa) == TYPE_STRING:
		return (str(wa) > str(wb)) if absteigend else (str(wa) < str(wb))
	return (float(wa) > float(wb)) if absteigend else (float(wa) < float(wb))

func _sortwert(sid: String) -> Variant:
	var sp: Dictionary = Welt.spieler(sid)
	match sortierung:
		"nummer":
			var nr: int = int(sp.get("nummer", 0))
			return -float(nr if nr > 0 else 999)
		"position":
			return -float(Spielerfabrik.POSITIONEN.find(str(sp["position"])))
		"name":
			return str(sp["nachname"])
		"alter":
			return -float(sp["alter"])
		"form":
			return float(sp["form"])
		"fitness":
			return float(sp["fitness"])
		"last":
			return float(sp["last"])
		"moral":
			return float(sp["moral"])
		"spiele":
			return float(sp["stats"]["saison"]["spiele"])
		"tore":
			return float(sp["stats"]["saison"]["tore"])
		"note":
			var n: float = Spielerfabrik.note(sp)
			return -n if n > 0.0 else -9.0
		"gehalt":
			return float(sp["vertrag"].get("gehalt", 0.0))
		"vertrag":
			return float(sp["vertrag"].get("bis_saison", 0))
		"wert":
			return float(sp["wert"])
	return Spielerfabrik.gesamt(sp)

func _zusammenfassung(kader: Array) -> void:
	var staerke := 0.0
	var alter_summe := 0.0
	var gehalt := 0.0
	for sid in kader:
		var sp: Dictionary = Welt.spieler(sid)
		staerke += Spielerfabrik.gesamt(sp)
		alter_summe += float(sp["alter"])
		gehalt += float(sp["vertrag"].get("gehalt", 0.0))
	var n: float = maxf(float(kader.size()), 1.0)
	zusammenfassung.add_child(Stil.matt("%d Spieler" % kader.size()))
	zusammenfassung.add_child(Stil.matt("Ø Stärke %d" % int(staerke / n)))
	zusammenfassung.add_child(Stil.matt("Ø Alter %.1f" % (alter_summe / n)))
	zusammenfassung.add_child(Stil.matt("Gehaltssumme %s / Woche" % Stil.geld(gehalt)))
	zusammenfassung.add_child(Stil.dehner())
	# Kadertiefe
	var tiefe := {}
	for p in Spielerfabrik.POSITIONEN:
		tiefe[p] = 0
	for sid in Welt.verein(Welt.mein_verein_id)["kader"]:
		var pos: String = str(Welt.spieler(sid)["position"])
		tiefe[pos] = int(tiefe.get(pos, 0)) + 1
	for p in Spielerfabrik.POSITIONEN:
		var anzahl: int = int(tiefe[p])
		var soll: int = int(Spielerfabrik.KADER_SOLL[p])
		var farbe: Color = Stil.GRUEN if anzahl >= soll - 1 else (Stil.GELB if anzahl >= 2 else Stil.ROT)
		var b := Stil.abzeichen("%s %d" % [p, anzahl], farbe)
		b.tooltip_text = "%s: %d im Kader (empfohlen: %d)" % [Spielerfabrik.POSITION_NAME[p], anzahl, soll]
		zusammenfassung.add_child(b)

func _zeile(sid: String, index: int) -> Control:
	var sp: Dictionary = Welt.spieler(sid)
	var knopf := Stil.zeilen_knopf(index)
	knopf.tooltip_text = "%s öffnen" % Spielerfabrik.voller_name(sp)
	knopf.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
	var h := Stil.hbox(6)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knopf.add_child(h)

	var st: Dictionary = sp["stats"]["saison"]
	var eintraege := [
		{"art": "nummer", "wert": Trikot.text(sp)},
		{"art": "abzeichen", "wert": str(sp["position"])},
		{"art": "name", "wert": Spielerfabrik.voller_name(sp)},
		{"art": "text", "wert": str(int(sp["alter"]))},
		{"art": "farbe", "wert": Scouting.gesamt_text(Welt.daten, sid), "zahl": Spielerfabrik.gesamt(sp), "max": 100.0},
		{"art": "balken", "wert": float(sp["form"])},
		{"art": "balken", "wert": float(sp["fitness"])},
		{"art": "balken_invers", "wert": float(sp["last"])},
		{"art": "balken", "wert": float(sp["moral"])},
		{"art": "text", "wert": str(int(st["spiele"]))},
		{"art": "text", "wert": str(int(st["paraden"])) if bool(sp["ist_torwart"]) else str(int(st["tore"]))},
		{"art": "note", "wert": Spielerfabrik.note(sp)},
		{"art": "text", "wert": Stil.geld(float(sp["vertrag"].get("gehalt", 0.0)))},
		{"art": "vertrag", "wert": int(sp["vertrag"].get("bis_saison", 0))},
		{"art": "text", "wert": Stil.geld(float(sp["wert"]))},
	]
	for i in range(SPALTEN.size()):
		var breite: float = float(SPALTEN[i]["breite"])
		var e: Dictionary = eintraege[i]
		var zelle: Control
		match str(e["art"]):
			"nummer":
				var nz := Stil.text(str(e["wert"]), Stil.S_KLEIN, Stil.TEXT_MATT)
				nz.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				zelle = nz
			"abzeichen":
				zelle = Bausteine.positions_abzeichen(str(e["wert"]))
			"name":
				var box := Stil.hbox(5)
				box.add_child(Portraet.fuer_spieler(sid, 22.0))
				box.add_child(Flagge.fuer(str(sp["nation"]), 16.0))
				# Der Name gibt nach, die Abzeichen nicht: lieber ein
				# abgeschnittener Name als eine verrutschte Zeile.
				var nl := Stil.text(str(e["wert"]), Stil.S_KLEIN)
				nl.clip_text = true
				nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				box.add_child(nl)
				box.add_child(Bausteine.status_zeichen(sid))
				zelle = box
			"balken":
				zelle = Stil.balken(float(e["wert"]), 100.0, int(breite) - 8)
			"balken_invers":
				var b := Stil.balken(float(e["wert"]), 100.0, int(breite) - 8, Stil.prozent_farbe(100.0 - float(e["wert"])))
				zelle = b
			"farbe":
				zelle = Stil.text(str(e["wert"]), Stil.S_KLEIN, Stil.wert_farbe(float(e["zahl"]), float(e["max"])))
			"note":
				var n: float = float(e["wert"])
				zelle = Stil.text(Stil.komma(n, 2) if n > 0.0 else "—", Stil.S_KLEIN,
					Stil.wert_farbe(6.0 - n, 5.0) if n > 0.0 else Stil.TEXT_SCHWACH)
			"vertrag":
				var rest: int = int(e["wert"]) - Welt.saison_index()
				zelle = Stil.text("%d J." % maxi(rest, 0), Stil.S_KLEIN, Stil.ROT if rest <= 0 else Stil.TEXT_MATT)
			_:
				zelle = Stil.text(str(e["wert"]), Stil.S_KLEIN)
		zelle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if zelle is Label and str(SPALTEN[i]["id"]) in RECHTS:
			(zelle as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(_gefasst(zelle, breite))
	return knopf

## Fasst eine Zelle auf genau die Spaltenbreite ein.
##
## custom_minimum_size allein reicht nicht: es ist ein Minimum, und eine HBox
## laesst ein Kind darueber hinauswachsen, wenn dessen Inhalt mehr verlangt.
## Bei einem Spieler mit zwei Statusabzeichen sprengte die Namenszelle damit
## ihre Spalte und schob die ganze Zeile nach rechts — im Kaderbildschirm
## standen einzelne Zeilen sichtbar versetzt zu allen anderen.
##
## Ein blosses Control uebernimmt die Mindestgroesse seiner Kinder nicht. Es
## haelt die Breite also fest, egal was darin liegt, und schneidet ab, was
## nicht hineinpasst.
## Eine Spaltenueberschrift: Beschriftung, Sortierpfeil, Klickflaeche.
##
## Die Beschriftung ist ein Label und kein Knopftext. Ein Button haelt einen
## Rand um seinen Text, und bei einer Spalte von achtunddreissig Pixeln bleibt
## davon nichts uebrig — mit clip_text stand "No" statt "Note" und "S" statt
## "Sp" da. Der Knopf liegt jetzt unsichtbar dahinter und traegt nur den
## Klick.
func _kopfzelle(id: String, name: String, breite: float) -> Control:
	var fassung := Control.new()
	fassung.custom_minimum_size = Vector2(breite, 20.0)
	fassung.clip_contents = true
	var knopf := Button.new()
	knopf.flat = true
	knopf.set_anchors_preset(Control.PRESET_FULL_RECT)
	knopf.add_theme_stylebox_override("normal", Stil.box_leer())
	knopf.add_theme_stylebox_override("focus", Stil.box_leer())
	knopf.tooltip_text = "Nach %s sortieren" % name
	knopf.pressed.connect(func():
		if sortierung == id:
			absteigend = not absteigend
		else:
			sortierung = id
			absteigend = true
		aktualisieren())
	fassung.add_child(knopf)
	var l := Label.new()
	l.text = name + ("  ▾" if sortierung == id and absteigend else ("  ▴" if sortierung == id else ""))
	l.add_theme_font_size_override("font_size", Stil.S_MINI)
	l.add_theme_color_override("font_color",
		Stil.TEXT if sortierung == id else Stil.TEXT_SCHWACH)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if id in RECHTS else HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	fassung.add_child(l)
	return fassung

## Ein leerer Platzhalter fester Breite.
func _abstand(breite: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(breite, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _gefasst(zelle: Control, breite: float) -> Control:
	var fassung := Control.new()
	fassung.custom_minimum_size = Vector2(breite, zelle.get_combined_minimum_size().y)
	fassung.clip_contents = true
	fassung.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zelle.set_anchors_preset(Control.PRESET_FULL_RECT)
	fassung.add_child(zelle)
	return fassung

# ------------------------------------------------------------- Planung ---

## Der Blick über die laufende Saison hinaus: Altersstruktur, Kadertiefe in den
## kommenden Jahren, auslaufende Verträge und die Gehaltslast, die daraus folgt.
func _planung() -> void:
	var cid: String = Welt.mein_verein_id
	var oben := Stil.hbox(12)
	liste.add_child(oben)

	var alter := Bausteine.karte_in(oben, "Altersstruktur")
	Stil.karte_wurzel(alter).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gruppen := Kaderplanung.altersgruppen(Welt.daten, cid)
	var groesste := 1
	for k in gruppen.keys():
		groesste = maxi(groesste, int(gruppen[k]))
	for k2 in ["talent", "aufbau", "beste", "erfahren", "veteran"]:
		var zeile := Stil.hbox(8)
		alter.add_child(zeile)
		var l := Stil.matt(str(Kaderplanung.GRUPPENNAME[k2]), Stil.S_KLEIN)
		l.custom_minimum_size = Vector2(64, 0)
		zeile.add_child(l)
		zeile.add_child(Stil.balken(float(gruppen[k2]), float(groesste), 150,
			Stil.AKZENT if k2 == "beste" else Stil.BLAU))
		zeile.add_child(Stil.text(str(int(gruppen[k2])), Stil.S_KLEIN))
	alter.add_child(Stil.trenner())
	var urteil := Stil.matt(Kaderplanung.altersurteil(Welt.daten, cid), Stil.S_MINI)
	urteil.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alter.add_child(urteil)

	var last := Bausteine.karte_in(oben, "Gehaltslast, wenn nichts geschieht")
	Stil.karte_wurzel(last).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var verlauf := Kaderplanung.gehaltsverlauf(Welt.daten, cid)
	var budget: float = float(Welt.verein(cid)["gehaltsbudget"])
	for j in range(verlauf.size()):
		var beschriftung: String = "diese Saison" if j == 0 else Kalender.saison_text(Welt.startjahr(), Welt.saison_index() + j)
		var anteil: float = float(verlauf[j]) / maxf(budget, 1.0) * 100.0
		last.add_child(Stil.info_zeile(beschriftung, "%s je Woche (%d %% des Budgets)" % [
			Stil.geld(float(verlauf[j])), int(anteil)],
			Stil.ROT if anteil > 100.0 else Stil.GRUEN))
	last.add_child(Stil.matt("Gerechnet mit den heutigen Verträgen: Wer ausläuft, fällt heraus.", Stil.S_MINI))

	var tiefe := Bausteine.karte_in(liste, "Kadertiefe in den nächsten Jahren")
	tiefe.add_child(Stil.matt("Gezählt werden Spieler unter Vertrag, die dann noch nicht zu alt sind. Rot heißt: unter der Sollbesetzung.", Stil.S_MINI))
	var kopf: Array = ["Position", "heute"]
	for j2 in range(1, Kaderplanung.HORIZONT + 1):
		kopf.append(Kalender.saison_text(Welt.startjahr(), Welt.saison_index() + j2))
	var g := Stil.tabelle(kopf)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiefe.add_child(g)
	var werte := Kaderplanung.tiefe(Welt.daten, cid)
	for pos in Spielerfabrik.POSITIONEN:
		g.add_child(Stil.text(str(Spielerfabrik.POSITION_NAME[pos]), Stil.S_KLEIN))
		var soll: int = int(Kaderplanung.SOLLTIEFE.get(pos, 2))
		for j3 in range(Kaderplanung.HORIZONT + 1):
			var ist: int = int((werte[pos] as Array)[j3])
			g.add_child(Stil.text(str(ist), Stil.S_KLEIN,
				Stil.ROT if ist < soll else (Stil.GRUEN if ist > soll else Stil.TEXT_MATT)))
	var luecken := Kaderplanung.luecken(Welt.daten, cid)
	if luecken.is_empty():
		tiefe.add_child(Stil.text("Auf keiner Position droht in den nächsten drei Jahren eine Lücke.", Stil.S_KLEIN, Stil.GRUEN))
	for l2 in luecken:
		var wann: String = "schon jetzt" if int(l2["in_jahren"]) == 0 else "in %s" % Stil.anzahl_mit(int(l2["in_jahren"]), "Jahr", "Jahren")
		tiefe.add_child(Stil.text("%s: %s nur %d von %d." % [
			Spielerfabrik.POSITION_NAME[str(l2["position"])], wann, int(l2["ist"]), int(l2["soll"])],
			Stil.S_KLEIN, Stil.GELB))

	var vertraege := Bausteine.karte_in(liste, "Verträge und Perspektive")
	var g2 := Stil.tabelle(["#", "Spieler", "Pos", "Alter", "Stärke", "in 3 Jahren", "Gehalt", "Vertrag bis"])
	g2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertraege.add_child(g2)
	for sid in Kaderplanung.vertragsuebersicht(Welt.daten, cid):
		var sp: Dictionary = Welt.spieler(sid)
		g2.add_child(Stil.matt(Trikot.text(sp), Stil.S_KLEIN))
		var knopf := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		knopf.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g2.add_child(knopf)
		g2.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		g2.add_child(Stil.text(str(int(sp["alter"])), Stil.S_KLEIN))
		var jetzt: float = Spielerfabrik.gesamt(sp)
		g2.add_child(Stil.text("%d" % int(jetzt), Stil.S_KLEIN, Stil.wert_farbe(jetzt, 100.0)))
		var dann: float = Kaderplanung.prognose(sp, 3)
		g2.add_child(Stil.text("%d (%s%d)" % [int(dann), "+" if dann >= jetzt else "", int(dann - jetzt)],
			Stil.S_KLEIN, Stil.GRUEN if dann > jetzt + 1.0 else (Stil.ROT if dann < jetzt - 1.0 else Stil.TEXT_MATT)))
		g2.add_child(Stil.matt(Stil.geld(float(sp["vertrag"].get("gehalt", 0.0))), Stil.S_KLEIN))
		var rest: int = int(sp["vertrag"].get("bis_saison", 0)) - Welt.saison_index()
		g2.add_child(Stil.text(Kalender.saison_text(Welt.startjahr(), int(sp["vertrag"].get("bis_saison", 0))),
			Stil.S_KLEIN, Stil.ROT if rest <= 0 else (Stil.GELB if rest == 1 else Stil.TEXT_MATT)))
