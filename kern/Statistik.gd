class_name Statistik
extends RefCounted
## Verbucht Spielergebnisse in Tabellen, Vereins- und Spielerstatistiken.

static func spiel_verbuchen(d: Dictionary, m: Dictionary) -> void:
	var heim: String = str(m["heim"])
	var gast: String = str(m["gast"])
	var th: int = int(m["tore_heim"])
	var tg: int = int(m["tore_gast"])
	var art: String = str(m["art"])
	if art == "test":
		# Vorbereitungsspiele zaehlen nicht: keine Tabelle, keine Statistik,
		# keine Formkurve. Nur Kraefte und Verletzungen wirken nach.
		return

	if art == "liga":
		_tabelle_eintragen(d["ligen"][m["wettbewerb"]]["tabelle"], heim, th, tg)
		_tabelle_eintragen(d["ligen"][m["wettbewerb"]]["tabelle"], gast, tg, th)
		var liga: Dictionary = d["ligen"][m["wettbewerb"]]
		liga["aktueller_spieltag"] = maxi(int(liga["aktueller_spieltag"]), int(m["runde"]))
	elif art == "international":
		var wb: Dictionary = d["international"][m["wettbewerb"]]
		if str(wb["phase"]) == "gruppe":
			_tabelle_eintragen(wb["tabelle"], heim, th, tg)
			_tabelle_eintragen(wb["tabelle"], gast, tg, th)

	_vereinsstats(d, heim, th, tg, true, m)
	_vereinsstats(d, gast, tg, th, false, m)
	_spielerstats(d, m)

static func _tabelle_eintragen(tabelle: Dictionary, cid: String, eigene: int, fremde: int) -> void:
	if not tabelle.has(cid):
		tabelle[cid] = Spielplan.leere_tabellenzeile()
	var z: Dictionary = tabelle[cid]
	z["sp"] = int(z["sp"]) + 1
	z["tore"] = int(z["tore"]) + eigene
	z["gegentore"] = int(z["gegentore"]) + fremde
	var serie: Array = z["serie"]
	if eigene > fremde:
		z["s"] = int(z["s"]) + 1
		z["punkte"] = int(z["punkte"]) + 2
		serie.append("S")
	elif eigene == fremde:
		z["u"] = int(z["u"]) + 1
		z["punkte"] = int(z["punkte"]) + 1
		serie.append("U")
	else:
		z["n"] = int(z["n"]) + 1
		serie.append("N")
	if serie.size() > 8:
		serie.remove_at(0)

static func _vereinsstats(d: Dictionary, cid: String, eigene: int, fremde: int, ist_heim: bool, m: Dictionary) -> void:
	var v: Dictionary = d["vereine"][cid]
	var s: Dictionary = v["saison"]
	s["spiele"] = int(s["spiele"]) + 1
	s["tore"] = int(s["tore"]) + eigene
	s["gegentore"] = int(s["gegentore"]) + fremde
	if eigene > fremde:
		s["siege"] = int(s["siege"]) + 1
	elif eigene == fremde:
		s["unentschieden"] = int(s["unentschieden"]) + 1
	else:
		s["niederlagen"] = int(s["niederlagen"]) + 1
	if ist_heim:
		s["heimspiele"] = int(s["heimspiele"]) + 1
		s["zuschauer_summe"] = int(s["zuschauer_summe"]) + int(m["zuschauer"])
	var bericht: Dictionary = m.get("bericht", {})
	var seite: String = "heim" if ist_heim else "gast"
	if bericht.has(seite):
		s["zeitstrafen"] = int(s["zeitstrafen"]) + int(bericht[seite]["stats"]["zeitstrafen"])
	var formkurve: Array = v["formkurve"]
	formkurve.append("S" if eigene > fremde else ("U" if eigene == fremde else "N"))
	if formkurve.size() > 10:
		formkurve.remove_at(0)
	var ewig: Dictionary = v["chronik"]["ewige_bilanz"]
	ewig["spiele"] = int(ewig["spiele"]) + 1
	ewig["tore"] = int(ewig["tore"]) + eigene
	ewig["gegentore"] = int(ewig["gegentore"]) + fremde
	if eigene > fremde:
		ewig["siege"] = int(ewig["siege"]) + 1
	elif eigene == fremde:
		ewig["unentschieden"] = int(ewig["unentschieden"]) + 1
	else:
		ewig["niederlagen"] = int(ewig["niederlagen"]) + 1

static func _spielerstats(d: Dictionary, m: Dictionary) -> void:
	var bericht: Dictionary = m.get("bericht", {})
	if bericht.is_empty():
		return
	var bester: String = str(bericht.get("spieler_des_spiels", ""))
	for seite in ["heim", "gast"]:
		var tb: Dictionary = bericht.get(seite, {})
		for sid in tb.get("spieler", {}).keys():
			if not d["spieler"].has(sid):
				continue
			var sp: Dictionary = d["spieler"][sid]
			var z: Dictionary = tb["spieler"][sid]
			for ziel in [sp["stats"]["saison"], sp["stats"]["karriere"]]:
				ziel["spiele"] = int(ziel["spiele"]) + 1
				ziel["minuten"] = float(ziel["minuten"]) + float(z["sekunden"]) / 60.0
				ziel["tore"] = int(ziel["tore"]) + int(z["tore"])
				ziel["wuerfe"] = int(ziel["wuerfe"]) + int(z["wuerfe"])
				ziel["assists"] = int(ziel["assists"]) + int(z["assists"])
				ziel["paraden"] = int(ziel["paraden"]) + int(z["paraden"])
				ziel["blocks"] = int(ziel["blocks"]) + int(z["blocks"])
				ziel["ballgewinne"] = int(ziel["ballgewinne"]) + int(z["ballgewinne"])
				ziel["technische_fehler"] = int(ziel["technische_fehler"]) + int(z["fehler"])
				ziel["zeitstrafen"] = int(ziel["zeitstrafen"]) + int(z["zeitstrafen"])
				ziel["siebenmeter_wuerfe"] = int(ziel["siebenmeter_wuerfe"]) + int(z["siebenmeter"])
				ziel["siebenmeter_tore"] = int(ziel["siebenmeter_tore"]) + int(z["siebenmeter_tore"])
				ziel["note_summe"] = float(ziel["note_summe"]) + float(z["bewertung"])
				ziel["noten"] = int(ziel["noten"]) + 1
				if int(z["rot"]) != 0:
					ziel["rote"] = int(ziel["rote"]) + 1
				if sid == bester:
					ziel["spieler_des_spiels"] = int(ziel["spieler_des_spiels"]) + 1
			if int(z["rot"]) != 0:
				sp["sperre"] = 1
			# Torschuetzenliste der Liga
			if str(m["art"]) == "liga" and int(z["tore"]) > 0:
				var liste: Dictionary = d["ligen"][m["wettbewerb"]]["torschuetzen"]
				liste[sid] = int(liste.get(sid, 0)) + int(z["tore"])

## Torschuetzenliste einer Liga, absteigend sortiert.
static func torjaeger(d: Dictionary, lid: String, anzahl: int = 20) -> Array:
	var liste: Dictionary = d["ligen"][lid].get("torschuetzen", {})
	var ids: Array = liste.keys()
	ids.sort_custom(func(a, b): return int(liste[a]) > int(liste[b]))
	var erg: Array = []
	for i in range(mini(anzahl, ids.size())):
		erg.append({"sid": ids[i], "tore": int(liste[ids[i]])})
	return erg

## Beste Spieler eines Kaders nach Durchschnittsnote.
static func kader_bestenliste(d: Dictionary, cid: String) -> Array:
	var liste: Array = []
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if int(sp["stats"]["saison"]["noten"]) < 3:
			continue
		liste.append({"sid": sid, "note": Spielerfabrik.note(sp)})
	liste.sort_custom(func(a, b): return float(a["note"]) < float(b["note"]))
	return liste
