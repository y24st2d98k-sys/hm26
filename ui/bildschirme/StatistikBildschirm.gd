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

	var unten := Stil.hbox(12)
	inhalt.add_child(unten)
	for schluessel in TEAM_KATEGORIEN.keys():
		_teamkarte(unten, str(schluessel))

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
		karte.add_child(Stil.matt("Mindestens %d Spiele nötig." % int(info["min_spiele"]), Stil.S_MINI))

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
