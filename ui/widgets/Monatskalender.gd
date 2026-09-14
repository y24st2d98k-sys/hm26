class_name Monatskalender
extends VBoxContainer
## Der Monat auf einen Blick.
##
## Bis hierher wusste man immer nur, was als Nächstes ansteht. Ob zwischen zwei
## Heimspielen elf Tage liegen oder drei, ob das Trainingslager mitten in die
## englische Woche fällt, ob der Deadline Day vor oder nach dem Auswärtsspiel
## in Kiel liegt — das musste man sich zusammenreimen. Ein Monatsblatt
## beantwortet das in einer Sekunde.
##
## Eingetragen wird, was den Verein des Trainers betrifft: eigene Partien mit
## Gegner und Heimrecht, fremde Partien der eigenen Liga nur als Spieltag,
## Trainingslager, Transferfenster, Pflichttermine und die Tage, an denen
## trainiert wird.

## Wie ein Tag markiert wird.
enum Art { EIGENES_SPIEL, LIGASPIEL, LAGER, TRAINING, FREI, TERMIN }

const FARBEN := {
	Art.EIGENES_SPIEL: "akzent",
	Art.LIGASPIEL: "matt",
	Art.LAGER: "lila",
	Art.TRAINING: "blau",
	Art.FREI: "matt",
	Art.TERMIN: "gelb",
}

## Angezeigter Monat und Jahr. Beim Aufbau der heutige.
var monat: int = 0
var jahr: int = 0

var _gitter: GridContainer
var _kopf: Label
var _legende: HBoxContainer

func _init() -> void:
	add_theme_constant_override("separation", 8)

static func fuer(_eltern: Node = null) -> Monatskalender:
	var k := Monatskalender.new()
	return k

func _ready() -> void:
	if monat <= 0:
		var heute := Kalender.datum(Welt.tag(), Welt.startjahr())
		monat = int(heute["monat"])
		jahr = int(heute["jahr"])
	_aufbauen()

func _aufbauen() -> void:
	for kind in get_children():
		kind.queue_free()

	var leiste := Stil.hbox(8)
	add_child(leiste)
	var zurueck := Stil.knopf_geist("‹")
	zurueck.custom_minimum_size = Vector2(34, 0)
	zurueck.tooltip_text = "Vorheriger Monat"
	zurueck.pressed.connect(func(): _blaettern(-1))
	leiste.add_child(zurueck)
	_kopf = Stil.text("", Stil.S_NORMAL, Stil.TEXT)
	_kopf.custom_minimum_size = Vector2(170, 0)
	_kopf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leiste.add_child(_kopf)
	var vor := Stil.knopf_geist("›")
	vor.custom_minimum_size = Vector2(34, 0)
	vor.tooltip_text = "Nächster Monat"
	vor.pressed.connect(func(): _blaettern(1))
	leiste.add_child(vor)
	leiste.add_child(Stil.dehner())
	var heute_knopf := Stil.knopf_geist("Heute")
	heute_knopf.pressed.connect(func():
		var h := Kalender.datum(Welt.tag(), Welt.startjahr())
		monat = int(h["monat"])
		jahr = int(h["jahr"])
		_aufbauen())
	leiste.add_child(heute_knopf)

	_gitter = GridContainer.new()
	_gitter.columns = 7
	_gitter.add_theme_constant_override("h_separation", 4)
	_gitter.add_theme_constant_override("v_separation", 4)
	add_child(_gitter)

	_legende = Stil.hbox(10)
	add_child(_legende)
	for e in [["Eigene Partie", Stil.AKZENT], ["Liga", Stil.TEXT_MATT], ["Lager", Stil.LILA],
			["Training", Stil.BLAU], ["Termin", Stil.GELB]]:
		_legende.add_child(Stil.abzeichen(str(e[0]), e[1]))

	_zeichnen()

func _blaettern(richtung: int) -> void:
	monat += richtung
	if monat > 12:
		monat = 1
		jahr += 1
	elif monat < 1:
		monat = 12
		jahr -= 1
	_aufbauen()

func _zeichnen() -> void:
	_kopf.text = "%s %d" % [Kalender.MONATSNAMEN[clampi(monat, 1, 12) - 1], jahr]
	for wt in Kalender.WOCHENTAG_KURZ:
		var l := Stil.matt(str(wt), Stil.S_MINI)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(92, 0)
		_gitter.add_child(l)

	var erster: int = Kalender.tag_aus_datum(1, monat, jahr, Welt.startjahr())
	var vorlauf: int = Kalender.wochentag(erster)
	for i in range(vorlauf):
		_gitter.add_child(Control.new())
	for tag_im_monat in range(1, Kalender.tage_im_monat(monat) + 1):
		_gitter.add_child(_tagfeld(erster + tag_im_monat - 1, tag_im_monat))

func _tagfeld(tag_abs: int, tag_im_monat: int) -> Control:
	var eintraege := eintraege_am_tag(tag_abs)
	var ist_heute: bool = tag_abs == Welt.tag()
	var vergangen: bool = tag_abs < Welt.tag()

	var rahmen := PanelContainer.new()
	rahmen.custom_minimum_size = Vector2(92, 66)
	var stil := StyleBoxFlat.new()
	stil.bg_color = Stil.FLAECHE
	if ist_heute:
		stil.bg_color = Stil.FLAECHE.lerp(Stil.AKZENT, 0.18)
		stil.border_color = Stil.AKZENT
		stil.set_border_width_all(1)
	elif vergangen:
		stil.bg_color = Stil.FLAECHE.darkened(0.35)
	stil.set_corner_radius_all(4)
	stil.set_content_margin_all(4)
	rahmen.add_theme_stylebox_override("panel", stil)

	var box := Stil.vbox(1)
	rahmen.add_child(box)
	var kopfzeile := Stil.hbox(4)
	box.add_child(kopfzeile)
	var nummer := Stil.text("%d" % tag_im_monat, Stil.S_MINI,
		Stil.AKZENT if ist_heute else (Stil.TEXT_MATT if vergangen else Stil.TEXT))
	kopfzeile.add_child(nummer)
	kopfzeile.add_child(Stil.dehner())

	var tooltip: Array = []
	for e in eintraege:
		var zeile := Stil.text(str(e["kurz"]), Stil.S_MINI, e["farbe"])
		zeile.clip_text = true
		box.add_child(zeile)
		tooltip.append(str(e["lang"]))
	if eintraege.is_empty():
		box.add_child(Stil.matt("—", Stil.S_MINI))
	rahmen.tooltip_text = "%s\n%s" % [Kalender.text(tag_abs, Welt.startjahr(), true),
		"\n".join(tooltip) if not tooltip.is_empty() else "Nichts angesetzt."]
	return rahmen

## Was an diesem Tag ansteht. Oeffentlich, damit auch andere Bildschirme
## denselben Kalender lesen koennen, ohne die Regeln zu wiederholen.
func eintraege_am_tag(tag_abs: int) -> Array:
	var aus: Array = []
	var mein: String = Welt.mein_verein_id
	var d: Dictionary = Welt.daten
	if d.is_empty():
		return aus

	# Partien.
	var fremde := 0
	for mid in Welt.spiele_am_tag(tag_abs):
		var m: Dictionary = d["spiele"].get(mid, {})
		if m.is_empty():
			continue
		var heim: String = str(m["heim"])
		var gast: String = str(m["gast"])
		if mein != "" and (heim == mein or gast == mein):
			var gegner: String = gast if heim == mein else heim
			var daheim: bool = heim == mein
			var kurz: String = "%s %s" % ["H" if daheim else "A",
				str(Welt.verein(gegner).get("kurz", "?"))]
			var ergebnis := ""
			if bool(m.get("gespielt", false)):
				ergebnis = " %d:%d" % [int(m["tore_heim"]), int(m["tore_gast"])]
			aus.append({"kurz": kurz + ergebnis, "farbe": Stil.AKZENT,
				"lang": "%s %s%s (%s)" % ["Heimspiel gegen" if daheim else "Auswärts bei",
					str(Welt.verein(gegner).get("name", "?")), ergebnis,
					Welt.wettbewerb_name(str(m["wettbewerb"]))]})
		elif mein != "" and str(d["vereine"][mein]["liga"]) == str(m.get("wettbewerb", "")):
			fremde += 1
	if fremde > 0:
		aus.append({"kurz": "%d Ligaspiele" % fremde, "farbe": Stil.TEXT_MATT,
			"lang": "%d weitere Partien in Ihrer Liga." % fremde})

	if mein == "":
		return aus

	# Trainingslager.
	var lager: Dictionary = Trainingslager.laufend(d, mein)
	if not lager.is_empty() and tag_abs >= int(lager["beginn"]) and tag_abs <= int(lager["bis"]):
		var ort: Dictionary = Trainingslager.ORTE.get(str(lager["ort"]), {})
		aus.append({"kurz": "Lager", "farbe": Stil.LILA,
			"lang": "Trainingslager: %s" % str(ort.get("name", lager["ort"]))})

	# Feste Termine der Saison.
	var tis: int = Kalender.tag_in_saison(tag_abs)
	if tis == Transfermarkt.SOMMER_VON or tis == Transfermarkt.WINTER_VON:
		aus.append({"kurz": "Fenster auf", "farbe": Stil.GELB,
			"lang": "Das Transferfenster öffnet."})
	if tis == Transfermarkt.SOMMER_BIS or tis == Transfermarkt.WINTER_BIS:
		aus.append({"kurz": "Deadline", "farbe": Stil.GELB,
			"lang": "Letzter Tag des Transferfensters."})

	# Training. Am Montag wird die Woche ausgewertet; an Spieltagen und am Tag
	# danach wird nicht trainiert, und im Lager steht ohnehin etwas anderes da.
	if aus.is_empty() or (aus.size() == 1 and str(aus[0]["farbe"]) == str(Stil.TEXT_MATT)):
		var spiel_heute: bool = _eigenes_spiel_am(tag_abs)
		var spiel_gestern: bool = _eigenes_spiel_am(tag_abs - 1)
		if not spiel_heute and not spiel_gestern:
			var wt: int = Kalender.wochentag(tag_abs)
			if wt == 0:
				var plan: Dictionary = Training.plan(d, mein)
				var schwerpunkt: Dictionary = Training.SCHWERPUNKTE.get(
					str(plan.get("schwerpunkt", "ausgeglichen")), {})
				aus.append({"kurz": "Training", "farbe": Stil.BLAU,
					"lang": "Wocheneinheit — Schwerpunkt %s" % str(schwerpunkt.get("name", "Ausgeglichen"))})
			elif wt <= 4:
				aus.append({"kurz": "Training", "farbe": Stil.BLAU, "lang": "Trainingstag"})
		elif spiel_gestern and not spiel_heute:
			aus.append({"kurz": "frei", "farbe": Stil.TEXT_MATT, "lang": "Regeneration nach der Partie"})
	return aus

func _eigenes_spiel_am(tag_abs: int) -> bool:
	var mein: String = Welt.mein_verein_id
	if mein == "":
		return false
	for mid in Welt.spiele_am_tag(tag_abs):
		var m: Dictionary = Welt.daten["spiele"].get(mid, {})
		if m.is_empty():
			continue
		if str(m["heim"]) == mein or str(m["gast"]) == mein:
			return true
	return false
