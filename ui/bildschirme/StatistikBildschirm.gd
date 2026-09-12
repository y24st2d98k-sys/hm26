class_name StatistikBildschirm
extends Bildschirm
## Statistikzentrum: Spieler- und Mannschaftsranglisten je Liga.

const TEAM_KATEGORIEN := {
	"angriff": {"name": "Bester Angriff", "einheit": " Tore/Spiel", "kommas": 1},
	"abwehr": {"name": "Beste Abwehr", "einheit": " Gegentore/Spiel", "kommas": 1},
	"zuschauer": {"name": "Zuschauerschnitt", "einheit": "", "kommas": 0},
	"zeitstrafen": {"name": "Zeitstrafen je Spiel", "einheit": "", "kommas": 2},
}

var liga_wahl: OptionButton
var kategorie_wahl: OptionButton
var inhalt: VBoxContainer
var gewaehlt: String = ""
var kategorie: String = "tore"

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)

	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Statistikzentrum", 0))
	kopf.add_child(Stil.dehner())

	kategorie_wahl = OptionButton.new()
	kategorie_wahl.custom_minimum_size = Vector2(230, 0)
	var i := 0
	for schluessel in Statistik.KATEGORIEN.keys():
		kategorie_wahl.add_item(str((Statistik.KATEGORIEN[schluessel] as Dictionary)["name"]))
		kategorie_wahl.set_item_metadata(i, schluessel)
		i += 1
	kategorie_wahl.item_selected.connect(func(idx):
		kategorie = str(kategorie_wahl.get_item_metadata(idx))
		_zeichne())
	kopf.add_child(kategorie_wahl)

	liga_wahl = OptionButton.new()
	liga_wahl.custom_minimum_size = Vector2(250, 0)
	liga_wahl.item_selected.connect(func(idx):
		gewaehlt = str(liga_wahl.get_item_metadata(idx))
		_zeichne())
	kopf.add_child(liga_wahl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inhalt)

func aktualisieren() -> void:
	if liga_wahl == null or Welt.daten.is_empty():
		return
	var vorher := gewaehlt
	liga_wahl.clear()
	var ids: Array = Welt.daten["ligen"].keys()
	ids.sort_custom(func(a, b):
		var la: Dictionary = Welt.daten["ligen"][a]
		var lb: Dictionary = Welt.daten["ligen"][b]
		if str(la["nation"]) != str(lb["nation"]):
			return float(Welt.daten["nationen"][la["nation"]]["ruf"]) > float(Welt.daten["nationen"][lb["nation"]]["ruf"])
		return int(la["stufe"]) < int(lb["stufe"]))
	var i := 0
	for lid in ids:
		var l: Dictionary = Welt.daten["ligen"][lid]
		liga_wahl.add_item("%s — %s" % [Namen.KULTUR_NAME.get(str(l["nation"]), ""), str(l["name"])])
		liga_wahl.set_item_metadata(i, lid)
		i += 1
	if vorher == "" and Welt.mein_verein_id != "":
		vorher = str(Welt.verein(Welt.mein_verein_id).get("liga", ""))
	if vorher == "" or not Welt.daten["ligen"].has(vorher):
		vorher = str(ids[0]) if not ids.is_empty() else ""
	gewaehlt = vorher
	var idx: int = ids.find(gewaehlt)
	if idx >= 0:
		liga_wahl.select(idx)
	_zeichne()

func _zeichne() -> void:
	leeren(inhalt)
	if gewaehlt == "" or not Welt.daten.get("ligen", {}).has(gewaehlt):
		return
	var liga: Dictionary = Welt.daten["ligen"][gewaehlt]
	var info: Dictionary = Statistik.KATEGORIEN.get(kategorie, Statistik.KATEGORIEN["tore"])

	var oben := Stil.hbox(12)
	inhalt.add_child(oben)
	_bestenliste(oben, liga, info)
	_eigene_karte(oben, liga, info)

	_team_der_woche(liga)
	_allstar(liga)
	_ehrungen(liga)

	var unten := Stil.hbox(12)
	inhalt.add_child(unten)
	for schluessel in TEAM_KATEGORIEN.keys():
		_teamkarte(unten, str(schluessel))

## Die beste Sieben des letzten Spieltags.
func _team_der_woche(liga: Dictionary) -> void:
	var w: Dictionary = Auszeichnungen.team_der_woche(Welt.daten, str(liga["id"]))
	if w.is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "Team der Woche — Spieltag vom %s" % Kalender.text(int(w["tag"]), Welt.startjahr()))
	var zeile := Stil.hbox(10)
	karte.add_child(zeile)
	var noten: Dictionary = w.get("noten", {})
	for pos in Spielerfabrik.POSITIONEN:
		if not (w["spieler"] as Dictionary).has(pos):
			continue
		var sid: String = str(w["spieler"][pos])
		if not Welt.daten["spieler"].has(sid):
			continue
		var sp: Dictionary = Welt.spieler(sid)
		var spalte := Stil.vbox(3)
		spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(spalte)
		spalte.add_child(Bausteine.positions_abzeichen(pos))
		var knopf := Stil.knopf_flach(Spielerfabrik.kurz_name(sp))
		knopf.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		spalte.add_child(knopf)
		spalte.add_child(Stil.matt(str(Welt.verein(str(sp["verein"])).get("kurz", "")), Stil.S_MINI))
		var note: float = float(noten.get(sid, 0.0))
		spalte.add_child(Stil.text(Stil.komma(note, 2) if note > 0.0 else "—", Stil.S_MINI,
			Stil.wert_farbe(6.0 - note, 5.0)))

## Monats- und Saisonehrungen dieser Liga.
func _ehrungen(liga: Dictionary) -> void:
	var lid: String = str(liga["id"])
	var monate: Array = Auszeichnungen.monatsliste(Welt.daten, lid)
	var saisons: Array = Auszeichnungen.saisonliste(Welt.daten, lid)
	if monate.is_empty() and saisons.is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "Auszeichnungen")
	if not monate.is_empty():
		karte.add_child(Stil.text("Monatsehrungen", Stil.S_KLEIN, Stil.AKZENT))
		var g := Stil.tabelle(["Monat", "Spieler des Monats", "Verein", "Mannschaft des Monats"])
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		karte.add_child(g)
		for e in monate.slice(0, 10):
			g.add_child(Stil.matt(str(e["monat"]), Stil.S_KLEIN))
			var sid: String = str(e["spieler"])
			if sid != "" and Welt.daten["spieler"].has(sid):
				var k := Stil.knopf_flach(Spielerfabrik.voller_name(Welt.spieler(sid)))
				k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
				g.add_child(k)
				g.add_child(Stil.matt(str(Welt.verein(str(Welt.spieler(sid)["verein"])).get("kurz", "")), Stil.S_KLEIN))
			else:
				g.add_child(Stil.matt("—", Stil.S_KLEIN))
				g.add_child(Stil.matt("—", Stil.S_KLEIN))
			g.add_child(Stil.text(str(Welt.verein(str(e["verein"])).get("name", "—")), Stil.S_KLEIN, Stil.GRUEN))
	if saisons.is_empty():
		return
	karte.add_child(Stil.trenner())
	karte.add_child(Stil.text("Saisonehrungen", Stil.S_KLEIN, Stil.AKZENT))
	for e2 in saisons.slice(0, 4):
		var zeile := Stil.hbox(10)
		karte.add_child(zeile)
		zeile.add_child(Stil.abzeichen(Kalender.saison_text(Welt.startjahr(), int(e2["saison"])), Stil.TEXT_SCHWACH))
		var teile: Array = []
		for paar in [["neuzugang", "Neuzugang"], ["talent", "Nachwuchsspieler"]]:
			var sid2: String = str(e2[str(paar[0])])
			if sid2 != "" and Welt.daten["spieler"].has(sid2):
				teile.append("%s der Saison: %s" % [str(paar[1]), Spielerfabrik.voller_name(Welt.spieler(sid2))])
		var tv: String = str(e2.get("trainerverein", ""))
		if tv != "" and Welt.daten["vereine"].has(tv):
			teile.append("Trainer der Saison: %s" % str(Welt.verein(tv)["name"]))
		zeile.add_child(Stil.matt(" · ".join(teile) if not teile.is_empty() else "keine Ehrung vergeben", Stil.S_KLEIN))

## Die beste Sieben der zuletzt abgeschlossenen Saison.
func _allstar(liga: Dictionary) -> void:
	var a: Dictionary = liga.get("allstar", {})
	if a.is_empty():
		return
	var karte := Bausteine.karte_in(inhalt, "Team der Saison %s" % Kalender.saison_text(
		Welt.startjahr(), int(a["saison"])))
	var reihe := Stil.hbox(10)
	karte.add_child(reihe)
	var sieben: Dictionary = a["spieler"]
	for pos in Spielerfabrik.POSITIONEN:
		if not sieben.has(pos):
			continue
		var sid: String = str(sieben[pos])
		if not Welt.daten["spieler"].has(sid):
			continue
		var sp: Dictionary = Welt.spieler(sid)
		var spalte := Stil.vbox(2)
		spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reihe.add_child(spalte)
		spalte.add_child(Bausteine.positions_abzeichen(str(pos)))
		var k := Stil.knopf_flach(Spielerfabrik.kurz_name(sp),
			Stil.AKZENT if str(sp["verein"]) == Welt.mein_verein_id else Stil.TEXT)
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		spalte.add_child(k)
		spalte.add_child(Wappen.fuer_verein(str(sp["verein"]), 16.0))

func _bestenliste(eltern: Node, liga: Dictionary, info: Dictionary) -> void:
	var karte := Bausteine.karte_in(eltern, "%s — %s" % [str(info["name"]), str(liga["name"])])
	var wurzel := Stil.karte_wurzel(karte)
	wurzel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wurzel.size_flags_stretch_ratio = 2.0
	var liste := Statistik.rangliste(Welt.daten, gewaehlt, kategorie, 15)
	if liste.is_empty():
		karte.add_child(Stil.matt("Noch zu wenige Spiele für eine aussagekräftige Wertung."))
		return
	var g := Stil.tabelle(["#", "", "Spieler", "Pos", "Verein", str(info["name"]), ""])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for i in range(liste.size()):
		var e: Dictionary = liste[i]
		var sid: String = str(e["sid"])
		if not Welt.daten["spieler"].has(sid):
			continue
		var sp: Dictionary = Welt.spieler(sid)
		var cid: String = str(sp["verein"])
		var eigen: bool = cid == Welt.mein_verein_id
		var farbe: Color = Stil.AKZENT if eigen else Stil.TEXT
		g.add_child(Stil.matt(str(i + 1), Stil.S_KLEIN))
		g.add_child(Wappen.fuer_verein(cid, 16.0))
		var k := Stil.knopf_flach(Spielerfabrik.voller_name(sp), farbe)
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(k)
		g.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		var vk := Stil.knopf_flach(str(Welt.verein(cid).get("kurz", "—")), Stil.TEXT_MATT)
		vk.pressed.connect(func(): Vereinsfenster.oeffnen(self, cid))
		g.add_child(vk)
		g.add_child(Stil.text(_wert_text(float(e["wert"])), Stil.S_KLEIN, Stil.AKZENT))
		g.add_child(Stil.matt(str(e.get("zusatz", "")), Stil.S_MINI))

func _eigene_karte(eltern: Node, liga: Dictionary, info: Dictionary) -> void:
	var karte := Bausteine.karte_in(eltern, "Mein Kader in dieser Wertung")
	var wurzel := Stil.karte_wurzel(karte)
	wurzel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Welt.mein_verein_id == "":
		karte.add_child(Stil.matt("Kein Verein gewählt."))
		return
	var mein: Dictionary = Welt.verein(Welt.mein_verein_id)
	if str(mein.get("liga", "")) != gewaehlt:
		karte.add_child(Stil.matt("%s spielt nicht in dieser Liga." % str(mein.get("name", ""))))
		return
	var voll := Statistik.rangliste(Welt.daten, gewaehlt, kategorie, 9999)
	var treffer := 0
	for i in range(voll.size()):
		var sid: String = str(voll[i]["sid"])
		if not Welt.daten["spieler"].has(sid):
			continue
		var sp: Dictionary = Welt.spieler(sid)
		if str(sp["verein"]) != Welt.mein_verein_id:
			continue
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		zeile.add_child(Stil.matt("%d." % (i + 1), Stil.S_KLEIN))
		var k := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		zeile.add_child(k)
		zeile.add_child(Stil.dehner())
		zeile.add_child(Stil.text(_wert_text(float(voll[i]["wert"])), Stil.S_KLEIN, Stil.AKZENT))
		treffer += 1
		if treffer >= 8:
			break
	if treffer == 0:
		karte.add_child(Stil.matt("Noch kein Spieler des Kaders in dieser Wertung."))
	else:
		var mindest: int = int(info["min_spiele"])
		karte.add_child(Stil.matt("Mindestens %d %s nötig." % [mindest, "Spiel" if mindest == 1 else "Spiele"],
			Stil.S_MINI))

func _teamkarte(eltern: Node, schluessel: String) -> void:
	var info: Dictionary = TEAM_KATEGORIEN[schluessel]
	var karte := Bausteine.karte_in(eltern, str(info["name"]))
	Stil.karte_wurzel(karte).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var liste := Statistik.team_rangliste(Welt.daten, gewaehlt, schluessel)
	if liste.is_empty():
		karte.add_child(Stil.matt("Noch keine Daten."))
		return
	for i in range(mini(6, liste.size())):
		var cid: String = str(liste[i]["cid"])
		var roh: float = float(liste[i]["wert"])
		if schluessel == "abwehr":
			roh = -roh
		var wert_text: String = Stil.zahl(int(roundf(roh))) if int(info["kommas"]) == 0 else Stil.komma(roh, int(info["kommas"]))
		var zeile := Stil.hbox(8)
		karte.add_child(zeile)
		zeile.add_child(Stil.matt("%d." % (i + 1), Stil.S_MINI))
		zeile.add_child(Wappen.fuer_verein(cid, 15.0))
		var farbe: Color = Stil.AKZENT if cid == Welt.mein_verein_id else Stil.TEXT
		var k := Stil.knopf_flach(str(Welt.verein(cid).get("kurz", "—")), farbe)
		k.pressed.connect(func(): Vereinsfenster.oeffnen(self, cid))
		zeile.add_child(k)
		zeile.add_child(Stil.dehner())
		zeile.add_child(Stil.text(wert_text, Stil.S_KLEIN, Stil.AKZENT))

func _wert_text(wert: float) -> String:
	var info: Dictionary = Statistik.KATEGORIEN.get(kategorie, Statistik.KATEGORIEN["tore"])
	var einheit: String = str(info["einheit"])
	match kategorie:
		"note":
			return Stil.komma(7.0 - wert, 2)
		"tore_pro_spiel":
			return Stil.komma(wert, 2)
		"wurfquote", "paradenquote":
			return Stil.komma(wert, 1) + einheit
		_:
			return Stil.zahl(int(roundf(wert))) + einheit
