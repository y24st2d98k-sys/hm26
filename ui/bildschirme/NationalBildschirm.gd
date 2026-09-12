class_name NationalBildschirm
extends Bildschirm
## Nationalmannschaften und das Winterturnier: Gruppen, K.-o.-Runde,
## Torschützen, die eigenen abgestellten Spieler und die Turnierhistorie.

var inhalt: VBoxContainer
var nation_wahl: OptionButton
var gewaehlte_nation: String = ""

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Nationalmannschaften", 0))
	kopf.add_child(Stil.dehner())
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

	var kopf := Bausteine.karte_in(inhalt, str(t["name"]))
	var phasen := {"vorbereitung": "Nominierung steht aus", "gruppe": "Gruppenphase",
		"ko": "K.-o.-Runde", "beendet": "beendet"}
	kopf.add_child(Stil.info_zeile("Stand", str(phasen.get(str(t["phase"]), str(t["phase"])))))
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
