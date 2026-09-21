class_name PersonalBildschirm
extends Bildschirm
## Trainerstab und Scouts: Wirkung, Gehälter, Neuverpflichtungen.

var inhalt: VBoxContainer
var meldung: Label
var bewerber: Array = []
var bewerber_rolle: String = ""

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Personal", 0))
	kopf.add_child(Stil.dehner())
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
	var karte := Bausteine.karte_in(inhalt, "Ihr Stab")
	karte.add_child(Stil.matt("Die Werte des Stabs wirken direkt: Training beschleunigt die Entwicklung, Prävention senkt Verletzungen, Urteilsvermögen verengt Scouting-Spannen.", Stil.S_MINI))
	var g := Stil.tabelle(["Rolle", "Name", "Alter", "Kernwerte", "Gehalt", "Vertrag", ""])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for pid in v["personal"]:
		var p: Dictionary = Welt.mitarbeiter(pid)
		if p.is_empty():
			continue
		g.add_child(Stil.text(str(p["rollenname"]), Stil.S_KLEIN, Stil.AKZENT))
		g.add_child(Stil.text("%s %s" % [p["vorname"], p["nachname"]], Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(p["alter"])), Stil.S_KLEIN))
		var werte := Stil.hbox(6)
		for a in (p["attr"] as Dictionary).keys():
			var w: float = float(p["attr"][a])
			var abz := Stil.abzeichen("%s %d" % [str(a).substr(0, 5), Spielerfabrik.anzeige(w)], Stil.wert_farbe(w))
			abz.tooltip_text = str(a).capitalize()
			werte.add_child(abz)
		g.add_child(werte)
		g.add_child(Stil.text(Stil.geld(float(p["gehalt"])), Stil.S_KLEIN))
		g.add_child(Stil.text("%d J." % int(p["vertrag_bis"]), Stil.S_KLEIN))
		var entlassen := Stil.knopf("Entlassen")
		entlassen.pressed.connect(func():
			(v["personal"] as Array).erase(pid)
			Finanzen.buchen(Welt.daten, cid, -float(p["gehalt"]) * 26.0, "Abfindung %s" % p["nachname"], "personal")
			_melde("%s wurde entlassen." % p["nachname"])
			aktualisieren())
		g.add_child(entlassen)

	var suche := Bausteine.karte_in(inhalt, "Neues Personal suchen")
	var zeile := Stil.hbox(8)
	suche.add_child(zeile)
	var wahl := OptionButton.new()
	wahl.custom_minimum_size = Vector2(220, 0)
	var i := 0
	for r in Weltgenerator.PERSONAL_ROLLEN.keys():
		wahl.add_item(str(Weltgenerator.PERSONAL_ROLLEN[r]["name"]))
		wahl.set_item_metadata(i, r)
		i += 1
	zeile.add_child(wahl)
	var suchen := Stil.knopf_primaer("Bewerber sichten")
	suchen.pressed.connect(func():
		bewerber_rolle = str(wahl.get_item_metadata(wahl.selected))
		bewerber = _bewerberliste(bewerber_rolle)
		aktualisieren())
	zeile.add_child(suchen)
	if bewerber_rolle != "":
		var rest: int = Personalmarkt.rest_tage(Welt.daten, bewerber_rolle)
		suche.add_child(Stil.matt("Diese Bewerbungen liegen noch %d Tage vor. Wer heute niemanden findet, wartet auf die nächsten." % rest,
			Stil.S_MINI))
	if not bewerber.is_empty():
		var g2 := Stil.tabelle(["Name", "Alter", "Kernwerte", "Gehaltsforderung", ""])
		g2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		suche.add_child(g2)
		for b in bewerber:
			g2.add_child(Stil.text("%s %s" % [b["vorname"], b["nachname"]], Stil.S_KLEIN))
			g2.add_child(Stil.text(str(int(b["alter"])), Stil.S_KLEIN))
			var werte := Stil.hbox(6)
			for a in (b["attr"] as Dictionary).keys():
				werte.add_child(Stil.abzeichen("%s %d" % [str(a).substr(0, 5), Spielerfabrik.anzeige(float(b["attr"][a]))], Stil.wert_farbe(float(b["attr"][a]))))
			g2.add_child(werte)
			g2.add_child(Stil.text(Stil.geld(float(b["gehalt"])), Stil.S_KLEIN))
			var holen := Stil.knopf_primaer("Verpflichten")
			holen.pressed.connect(func(): _verpflichte(b))
			g2.add_child(holen)

## Die Bewerber, die gerade vorliegen.
##
## Vorher erzeugte jeder Druck vier neue Leute und schrieb sie dauerhaft in
## die Welt: zwanzigmal gesichtet hiess achtzig Einträge im Spielstand,
## gemessen mit werkzeuge/Personalsonde.gd. Schwerer wog, dass man so lange
## sichten konnte, bis der Beste dabei war — ohne Zeit, ohne Kosten, ohne
## Risiko. Jetzt hält Personalmarkt die Liste, und sie gilt zwei Wochen.
func _bewerberliste(rolle: String) -> Array:
	var liste: Array = []
	for pid in Personalmarkt.bewerber(Welt.daten, Welt.mein_verein_id, rolle):
		var p := Welt.mitarbeiter(str(pid))
		if not p.is_empty():
			liste.append(p)
	return liste

func _verpflichte(b: Dictionary) -> void:
	var cid := Welt.mein_verein_id
	var v: Dictionary = Welt.verein(cid)
	var wochenlast := Finanzen.personalgehaelter(Welt.daten, cid) + Finanzen.spielergehaelter(Welt.daten, cid) + float(b["gehalt"])
	if wochenlast > float(v["gehaltsbudget"]) * 1.25:
		_melde("Das Gehaltsbudget lässt diese Verpflichtung nicht zu.", false)
		return
	b["verein"] = cid
	(v["personal"] as Array).append(str(b["id"]))
	bewerber = _bewerberliste(bewerber_rolle) if bewerber_rolle != "" else []
	_melde("%s %s wurde verpflichtet." % [b["vorname"], b["nachname"]])
	aktualisieren()

func _melde(text: String, gut: bool = true) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)
