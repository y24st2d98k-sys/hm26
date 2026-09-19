class_name TabellenBildschirm
extends Bildschirm
## Tabellen aller Ligen samt Torjägerliste und Formkurven.

var liga_wahl: OptionButton
var inhalt: VBoxContainer
var gewaehlt: String = ""

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Tabellen", 0))
	kopf.add_child(Stil.dehner())
	liga_wahl = OptionButton.new()
	liga_wahl.custom_minimum_size = Vector2(250, 0)
	liga_wahl.item_selected.connect(func(i):
		gewaehlt = str(liga_wahl.get_item_metadata(i))
		_zeichne())
	kopf.add_child(liga_wahl)
	# Kein Rollbereich um den ganzen Bildschirm: die Reiter bringen ihren
	# eigenen mit, und zwei ineinander sind einer zu viel.
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(inhalt)

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
		vorher = str(Welt.verein(Welt.mein_verein_id)["liga"])
	if vorher == "":
		vorher = str(ids[0])
	gewaehlt = vorher
	var idx: int = ids.find(gewaehlt)
	if idx >= 0:
		liga_wahl.select(idx)
	_zeichne()

func _zeichne() -> void:
	leeren(inhalt)
	if gewaehlt == "" or not Welt.daten["ligen"].has(gewaehlt):
		return
	var liga: Dictionary = Welt.daten["ligen"][gewaehlt]
	var tabelle := Spielplan.tabelle_sortiert(Welt.daten, gewaehlt)
	# Die Tabelle fuellt fuer sich schon eine Bildschirmhoehe. Torjaeger,
	# Prognose und Meisterhistorie gehoeren daneben, nicht darunter — sonst
	# scrollt man an achtzehn Zeilen vorbei, um zu sehen, wer trifft.
	var reiter := Stil.reitergruppe([
		{"id": "tabelle", "name": "Tabelle"},
		{"id": "listen", "name": "Torjäger & Prognose"},
	])
	inhalt.add_child(reiter)
	var karte := Bausteine.karte_in(reiter.feld("tabelle"), "%s — Spieltag %d von %d" % [
		str(liga["name"]), int(liga["aktueller_spieltag"]), int(liga["spieltage"])])
	var g := Stil.tabelle(["#", "", "Verein", "Sp", "S", "U", "N", "Tore", "Diff", "P", "Form"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	var aufstieg: int = 2 if int(liga["stufe"]) > 1 else 0
	var abstieg: int = tabelle.size() - 2 if _hat_unterbau(liga) else tabelle.size()
	for i in range(tabelle.size()):
		var cid: String = str(tabelle[i])
		var z: Dictionary = liga["tabelle"].get(cid, Spielplan.leere_tabellenzeile())
		var eigen: bool = cid == Welt.mein_verein_id
		var farbe: Color = Stil.AKZENT if eigen else Stil.TEXT
		# Die Zone steht als farbige Kante am Zeilenanfang, nicht in der
		# Platzziffer. Eine eingefaerbte Zahl las sich wie eine Wertung des
		# Vereins; die Kante sagt, was sie meint — hier endet Europa, hier
		# beginnt der Abstieg.
		if int(liga["stufe"]) == 1 and i < 3:
			g.setze_zone(i, Stil.TUERKIS)
		elif i < aufstieg:
			g.setze_zone(i, Stil.GRUEN)
		elif i >= abstieg:
			g.setze_zone(i, Stil.ROT)
		if eigen:
			g.hebe_zeile(i)
		g.add_child(Stil.text(str(i + 1), Stil.S_KLEIN, farbe))
		g.add_child(Wappen.fuer_verein(cid, 18.0))
		var vereinsknopf := Stil.knopf_flach(str(Welt.verein(cid).get("name", "")), farbe)
		vereinsknopf.pressed.connect(func(): Vereinsfenster.oeffnen(self, cid))
		g.add_child(vereinsknopf)
		g.add_child(Stil.text(str(int(z["sp"])), Stil.S_KLEIN, farbe))
		g.add_child(Stil.text(str(int(z["s"])), Stil.S_KLEIN, farbe))
		g.add_child(Stil.text(str(int(z["u"])), Stil.S_KLEIN, farbe))
		g.add_child(Stil.text(str(int(z["n"])), Stil.S_KLEIN, farbe))
		g.add_child(Stil.text("%d:%d" % [int(z["tore"]), int(z["gegentore"])], Stil.S_KLEIN, farbe))
		var diff: int = int(z["tore"]) - int(z["gegentore"])
		g.add_child(Stil.text("%+d" % diff, Stil.S_KLEIN, Stil.GRUEN if diff > 0 else (Stil.ROT if diff < 0 else Stil.TEXT_MATT)))
		g.add_child(Stil.text(str(int(z["punkte"])), Stil.S_KLEIN, farbe))
		g.add_child(Bausteine.formkurve(z["serie"], 5))

	var unten := Stil.hbox(12)
	reiter.feld("listen").add_child(unten)
	var torjaeger := Bausteine.karte_in(unten, "Torjägerliste")
	Stil.karte_wurzel(torjaeger).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var liste := Statistik.torjaeger(Welt.daten, gewaehlt, 12)
	if liste.is_empty():
		torjaeger.add_child(Stil.matt("Noch keine Tore erzielt."))
	else:
		var g2 := Stil.tabelle(["#", "Spieler", "Verein", "Tore"])
		g2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		torjaeger.add_child(g2)
		for i in range(liste.size()):
			var sid: String = str(liste[i]["sid"])
			if not Welt.daten["spieler"].has(sid):
				continue
			var sp: Dictionary = Welt.spieler(sid)
			g2.add_child(Stil.matt(str(i + 1), Stil.S_KLEIN))
			var k := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
			k.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
			g2.add_child(k)
			g2.add_child(Stil.matt(str(Welt.verein(str(sp["verein"])).get("kurz", "—")), Stil.S_KLEIN))
			g2.add_child(Stil.text(str(int(liste[i]["tore"])), Stil.S_KLEIN, Stil.AKZENT))

	var prognose := Bausteine.karte_in(unten, "Saisonprognose der Buchmacher")
	Stil.karte_wurzel(prognose).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pliste: Array = liga.get("prognose", [])
	if pliste.is_empty():
		prognose.add_child(Stil.leerzustand("Für diese Liga liegt keine Prognose vor."))
	else:
		var tabelle_jetzt := Spielplan.tabelle_sortiert(Welt.daten, gewaehlt)
		var g3 := Stil.tabelle(["#", "", "Verein", "Quote", "Jetzt"])
		g3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prognose.add_child(g3)
		for i in range(mini(pliste.size(), 8)):
			var e: Dictionary = pliste[i]
			var pcid: String = str(e["verein"])
			var eigen2: bool = pcid == Welt.mein_verein_id
			g3.add_child(Stil.matt(str(i + 1), Stil.S_KLEIN))
			g3.add_child(Wappen.fuer_verein(pcid, 16.0))
			var pk := Stil.knopf_flach(str(Welt.verein(pcid).get("name", "")),
				Stil.AKZENT if eigen2 else Stil.TEXT)
			pk.pressed.connect(func(): Vereinsfenster.oeffnen(self, pcid))
			g3.add_child(pk)
			g3.add_child(Stil.text(Stil.komma(float(e["quote"]), 1), Stil.S_KLEIN, Stil.TUERKIS))
			# Wo der Verein tatsaechlich steht — der Vergleich ist die Pointe
			var ist: int = tabelle_jetzt.find(pcid) + 1
			var abweichung: int = (i + 1) - ist
			g3.add_child(Stil.text("%d." % ist if ist > 0 else "—", Stil.S_KLEIN,
				Stil.GRUEN if abweichung > 1 else (Stil.ROT if abweichung < -1 else Stil.TEXT_MATT)))

	var historie := Bausteine.karte_in(unten, "Meisterhistorie")
	Stil.karte_wurzel(historie).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h: Array = liga.get("meister_historie", [])
	if h.is_empty():
		historie.add_child(Stil.matt("Noch keine abgeschlossene Saison."))
	else:
		for e in h.slice(0, 10):
			historie.add_child(Stil.info_zeile(Kalender.saison_text(Welt.startjahr(), int(e["saison"])),
				str(Welt.verein(str(e["verein"])).get("name", ""))))

func _hat_unterbau(liga: Dictionary) -> bool:
	var nation: Dictionary = Welt.daten["nationen"][liga["nation"]]
	return (nation["ligen"] as Array).size() > int(liga["stufe"])
