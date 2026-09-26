class_name NationalBildschirm
extends Bildschirm
## Nationalmannschaften und das Winterturnier: Gruppen, K.-o.-Runde,
## Torschützen, die eigenen abgestellten Spieler und die Turnierhistorie.

var inhalt: VBoxContainer
var nation_wahl: OptionButton
var gewaehlte_nation: String = ""
var meldung: Label

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Nationalmannschaften", 0))
	kopf.add_child(Stil.dehner())
	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	kopf.add_child(meldung)
	kopf.add_child(Stil.matt("Auswahl"))
	nation_wahl = OptionButton.new()
	nation_wahl.custom_minimum_size = Vector2(200, 0)
	nation_wahl.item_selected.connect(func(i):
		gewaehlte_nation = str(nation_wahl.get_item_metadata(i))
		_zeichne())
	kopf.add_child(nation_wahl)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)

func aktualisieren() -> void:
	if inhalt == null or not Welt.bereit():
		return
	var t: Dictionary = Welt.daten.get("turnier", {})
	var teilnehmer: Array = t.get("teilnehmer", [])
	var vorher := gewaehlte_nation
	nation_wahl.clear()
	var i := 0
	for nid in teilnehmer:
		nation_wahl.add_item(str(Namen.KULTUR_NAME.get(nid, nid)))
		nation_wahl.set_item_metadata(i, nid)
		i += 1
	if vorher == "" and Welt.mein_verein_id != "":
		vorher = str(Welt.mein_verein().get("nation", ""))
	if not teilnehmer.has(vorher):
		vorher = str(teilnehmer[0]) if not teilnehmer.is_empty() else ""
	gewaehlte_nation = vorher
	var idx: int = teilnehmer.find(gewaehlte_nation)
	if idx >= 0:
		nation_wahl.select(idx)
	_zeichne()

func _zeichne() -> void:
	leeren(inhalt)
	var t: Dictionary = Welt.daten.get("turnier", {})
	if t.is_empty() or str(t.get("phase", "keins")) == "keins":
		inhalt.add_child(Stil.matt("In dieser Saison ist kein Turnier angesetzt."))
		_historie(t)
		return

	_verbandsamt(t)
	var kopf := Bausteine.karte_in(inhalt, str(t["name"]))
	var phasen := {"vorbereitung": "Nominierung steht aus", "gruppe": "Gruppenphase",
		"ko": "K.-o.-Runde", "beendet": "beendet"}
	kopf.add_child(Stil.info_zeile("Stand", str(phasen.get(str(t["phase"]), str(t["phase"])))))
	if str(t.get("gastgeber", "")) != "":
		kopf.add_child(Stil.info_zeile("Gastgeber", str(t["gastgeber"])))
	kopf.add_child(Stil.info_zeile("Teilnehmer", str((t["teilnehmer"] as Array).size())))
	if str(t["phase"]) == "vorbereitung":
		kopf.add_child(Stil.matt("Die Kader werden kurz vor der Winterpause berufen.", Stil.S_KLEIN))
	if str(t.get("sieger", "")) != "":
		var sieger_nid: String = str(t["sieger"])
		kopf.add_child(Stil.info_zeile("Sieger", str(Namen.KULTUR_NAME.get(sieger_nid, sieger_nid)), Stil.AKZENT))

	_eigene_spieler()
	if str(t["phase"]) in ["gruppe", "ko", "beendet"]:
		_gruppen(t)
		_ko(t)
		_kader(t)
		_torjaeger()
	_historie(t)

## Der eigene Verbandsjob: Ziel, Bilanz und die Kaderwahl vor dem Turnier.
func _verbandsamt(t: Dictionary) -> void:
	if not Nationaltrainer.ist_nationaltrainer(Welt.daten):
		return
	var nid: String = Nationaltrainer.nation(Welt.daten)
	var name: String = str(Namen.KULTUR_NAME.get(nid, nid.to_upper()))
	var karte := Bausteine.karte_in(inhalt, "Ihr Verbandsamt — %s" % name)
	var kopf := Stil.hbox(10)
	karte.add_child(kopf)
	kopf.add_child(Flagge.fuer(nid, 28.0))
	var spalte := Stil.vbox(1)
	spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(spalte)
	spalte.add_child(Stil.text("Nationaltrainer von %s" % name, Stil.S_NORMAL, Stil.AKZENT))
	spalte.add_child(Stil.matt("Erwartung des Verbands: %s" % Nationaltrainer.zieltext(Welt.daten), Stil.S_MINI))
	var b: Dictionary = Welt.daten["trainer"].get("national_bilanz", {})
	if not b.is_empty():
		spalte.add_child(Stil.matt("%d Turnierspiele · %d Siege, %d Unentschieden, %d Niederlagen" % [
			int(b["spiele"]), int(b["siege"]), int(b["unentschieden"]), int(b["niederlagen"])], Stil.S_MINI))
	var weg := Stil.knopf_flach("Amt niederlegen", Stil.ROT)
	weg.pressed.connect(func():
		Nationaltrainer.niederlegen(Welt.daten)
		Welt.zustand_geaendert.emit()
		aktualisieren())
	kopf.add_child(weg)

	# Kaderwahl nur, solange das Turnier noch nicht läuft
	var kader: Array = Nationaltrainer.nominiert(Welt.daten)
	var phase: String = str(t.get("phase", "keins"))
	if phase == "beendet" or phase == "keins":
		return
	karte.add_child(Stil.trenner())
	var pruefung := Nationaltrainer.kaderpruefung(Welt.daten)
	var zeile := Stil.hbox(10)
	karte.add_child(zeile)
	zeile.add_child(Stil.text("Aufgebot: %d von %d" % [kader.size(), Nationaltrainer.KADER_MAX],
		Stil.S_KLEIN, Stil.GRUEN if bool(pruefung["ok"]) else Stil.ROT))
	zeile.add_child(Stil.matt(str(pruefung["grund"]), Stil.S_MINI))
	zeile.add_child(Stil.dehner())
	var auto := Stil.knopf("Vorschlag des Stabs")
	auto.pressed.connect(func():
		var n := Nationaltrainer.vorschlag_uebernehmen(Welt.daten)
		_melde("Der Stab hat %d Spieler nominiert." % n)
		Welt.zustand_geaendert.emit()
		aktualisieren())
	zeile.add_child(auto)

	var spalten := Stil.hbox(12)
	karte.add_child(spalten)
	var links := Bausteine.karte_in(spalten, "Nominiert", true)
	Stil.karte_wurzel(links).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kader.is_empty():
		links.add_child(Stil.matt("Noch niemand nominiert."))
	for sid in kader:
		var sp: Dictionary = Welt.spieler(sid)
		if sp.is_empty():
			continue
		var z := Stil.hbox(6)
		links.add_child(z)
		z.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		var knopf := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		knopf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		knopf.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		z.add_child(knopf)
		z.add_child(Stil.text("%d" % int(Spielerfabrik.gesamt(sp)), Stil.S_KLEIN,
			Stil.wert_farbe(Spielerfabrik.gesamt(sp), 100.0)))
		var raus := Stil.knopf_flach("Streichen", Stil.ROT)
		raus.pressed.connect(func():
			Nationaltrainer.streichen(Welt.daten, sid)
			aktualisieren())
		z.add_child(raus)

	var rechts := Bausteine.karte_in(spalten, "Spielberechtigt", true)
	Stil.karte_wurzel(rechts).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var offen := 0
	for sid2 in Nationaltrainer.kandidaten(Welt.daten, nid):
		if kader.has(sid2):
			continue
		offen += 1
		if offen > 14:
			break
		var sp2: Dictionary = Welt.spieler(sid2)
		var z2 := Stil.hbox(6)
		rechts.add_child(z2)
		z2.add_child(Bausteine.positions_abzeichen(str(sp2["position"])))
		var knopf2 := Stil.knopf_flach(Spielerfabrik.voller_name(sp2))
		knopf2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		knopf2.pressed.connect(func(): Spielerfenster.oeffnen(self, sid2))
		z2.add_child(knopf2)
		z2.add_child(Stil.matt("Form %d" % int(float(sp2["form"])), Stil.S_MINI))
		z2.add_child(Stil.text("%d" % int(Spielerfabrik.gesamt(sp2)), Stil.S_KLEIN,
			Stil.wert_farbe(Spielerfabrik.gesamt(sp2), 100.0)))
		var rein := Stil.knopf_flach("Nominieren", Stil.GRUEN)
		rein.pressed.connect(func():
			var erg := Nationaltrainer.hinzufuegen(Welt.daten, sid2)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			aktualisieren())
		z2.add_child(rein)
	if offen == 0:
		rechts.add_child(Stil.matt("Alle verfügbaren Spieler sind nominiert."))

func _eigene_spieler() -> void:
	if Welt.mein_verein_id == "":
		return
	var abwesend := Nationalteam.abwesende(Welt.daten, Welt.mein_verein_id)
	var karte := Bausteine.karte_in(inhalt, "Abgestellte Spieler")
	if abwesend.is_empty():
		karte.add_child(Stil.matt("Derzeit ist kein Spieler Ihres Vereins abgestellt."))
		return
	karte.add_child(Stil.matt("Diese Spieler fehlen im Vereinstraining und kehren mit erhöhtem Lastkonto zurück.", Stil.S_MINI))
	for sid in abwesend:
		var sp: Dictionary = Welt.spieler(sid)
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		zeile.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		var k := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		k.custom_minimum_size = Vector2(220, 0)
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		zeile.add_child(k)
		zeile.add_child(Stil.matt(str(Namen.KULTUR_NAME.get(str(sp["nation"]), "")), Stil.S_KLEIN))
		zeile.add_child(Stil.dehner())
		zeile.add_child(Stil.matt("Lastkonto %d" % int(float(sp["last"])), Stil.S_MINI))

func _gruppen(t: Dictionary) -> void:
	var gruppen: Array = t.get("gruppen", [])
	if gruppen.is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "Gruppenphase")
	var gnamen := ["A", "B", "C", "D"]
	var reihe := Stil.hbox(12)
	karte.add_child(reihe)
	for gi in range(gruppen.size()):
		var gk := Bausteine.karte_in(reihe, "Gruppe %s" % gnamen[gi], true)
		Stil.karte_wurzel(gk).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sortiert := Spielplan.gruppen_tabelle_sortiert(t, gruppen[gi])
		var g := Stil.tabelle(["#", "Nation", "Sp", "P", "Diff"])
		gk.add_child(g)
		for i in range(sortiert.size()):
			var nid: String = str(sortiert[i])
			var z: Dictionary = t["tabelle"].get(nid, Spielplan.leere_tabellenzeile())
			var farbe: Color = Stil.AKZENT if nid == gewaehlte_nation else (Stil.GRUEN if i < 2 else Stil.TEXT)
			g.add_child(Stil.text(str(i + 1), Stil.S_MINI, farbe))
			g.add_child(Stil.text(str(Namen.KULTUR_KUERZEL.get(nid, nid)), Stil.S_MINI, farbe))
			g.add_child(Stil.text(str(int(z["sp"])), Stil.S_MINI, farbe))
			g.add_child(Stil.text(str(int(z["punkte"])), Stil.S_MINI, farbe))
			g.add_child(Stil.text("%+d" % (int(z["tore"]) - int(z["gegentore"])), Stil.S_MINI, farbe))

func _ko(t: Dictionary) -> void:
	var paarungen: Array = t.get("paarungen", [])
	if paarungen.is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "K.-o.-Runde")
	for p in paarungen:
		var m: Dictionary = Welt.partie(str(p["spiel"]))
		if m.is_empty():
			continue
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		var a_nid: String = str(p["a"])
		var b_nid: String = str(p["b"])
		var links := Stil.text(str(Namen.KULTUR_NAME.get(a_nid, a_nid)), Stil.S_KLEIN)
		links.custom_minimum_size = Vector2(160, 0)
		links.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		zeile.add_child(links)
		var erg := Stil.text("%d : %d" % [int(m["tore_heim"]), int(m["tore_gast"])] if bool(m["gespielt"]) else "– : –",
			Stil.S_KLEIN, Stil.AKZENT)
		erg.custom_minimum_size = Vector2(60, 0)
		erg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zeile.add_child(erg)
		var rechts := Stil.text(str(Namen.KULTUR_NAME.get(b_nid, b_nid)), Stil.S_KLEIN)
		rechts.custom_minimum_size = Vector2(160, 0)
		zeile.add_child(rechts)

func _kader(t: Dictionary) -> void:
	if gewaehlte_nation == "":
		return
	var cid := Nationalteam.team_id(gewaehlte_nation)
	var team: Dictionary = Welt.verein(cid)
	if team.is_empty() or (team["kader"] as Array).is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "Aufgebot %s" % str(Namen.KULTUR_NAME.get(gewaehlte_nation, gewaehlte_nation)))
	var g := Stil.tabelle(["Pos", "Spieler", "Verein", "Alter", "Stärke", "Turniertore"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for sid in Welt.kader(cid):
		var sp: Dictionary = Welt.spieler(sid)
		g.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		var k := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(k)
		var eigen: bool = str(sp["verein"]) == Welt.mein_verein_id
		g.add_child(Stil.text(str(Welt.verein(str(sp["verein"])).get("kurz", "—")), Stil.S_KLEIN,
			Stil.AKZENT if eigen else Stil.TEXT_MATT))
		g.add_child(Stil.text(str(int(sp["alter"])), Stil.S_KLEIN))
		g.add_child(Stil.text("%d" % int(Spielerfabrik.gesamt(sp)), Stil.S_KLEIN,
			Stil.wert_farbe(Spielerfabrik.gesamt(sp), 100.0)))
		g.add_child(Stil.text(str(int(t.get("torschuetzen", {}).get(sid, 0))), Stil.S_KLEIN))

func _torjaeger() -> void:
	var liste := Nationalteam.torjaeger(Welt.daten, 10)
	if liste.is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "Turnier-Torschützen")
	var g := Stil.tabelle(["#", "Spieler", "Nation", "Verein", "Tore"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for i in range(liste.size()):
		var sid: String = str(liste[i]["sid"])
		var sp: Dictionary = Welt.spieler(sid)
		if sp.is_empty():
			continue
		g.add_child(Stil.matt(str(i + 1), Stil.S_KLEIN))
		var k := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(k)
		g.add_child(Stil.matt(str(Namen.KULTUR_KUERZEL.get(str(sp["nation"]), "")), Stil.S_KLEIN))
		g.add_child(Stil.matt(str(Welt.verein(str(sp["verein"])).get("kurz", "—")), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(liste[i]["tore"])), Stil.S_KLEIN, Stil.AKZENT))

func _historie(t: Dictionary) -> void:
	var historie: Array = t.get("historie", [])
	if historie.is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "Frühere Turniere")
	for e in historie:
		karte.add_child(Stil.info_zeile(str(e["name"]),
			"%s (vor %s)" % [Namen.KULTUR_NAME.get(str(e["sieger"]), ""),
				Namen.KULTUR_NAME.get(str(e["zweiter"]), "")], Stil.AKZENT))

func _melde(text: String, gut: bool = true) -> void:
	if meldung != null:
		meldung.text = text
		meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)
