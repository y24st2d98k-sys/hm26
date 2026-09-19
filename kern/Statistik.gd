class_name Statistik
extends RefCounted
## Verbucht Spielergebnisse in Tabellen, Vereins- und Spielerstatistiken.

## Alle Wurfversuche eines Statistikblocks — Siebenmeter zaehlen mit.
##
## Bei den Toren stand der Strafwurf immer drin, bei den Wuerfen nie: ein
## Fluegel, der die Siebenmeter schiesst, kam damit in der Rangliste auf eine
## Wurfquote von 240 Prozent. Gezaehlt wird jetzt, was geworfen wurde.
##
## Waehrend einer Partie heisst das Feld "siebenmeter", in der Saisonbilanz
## "siebenmeter_wuerfe" — beide Schreibweisen werden gelesen, damit dieselbe
## Rechnung fuer den Spielbericht und fuer die Saison gilt.
static func wuerfe_gesamt(st: Dictionary) -> int:
	var sieben: int = int(st.get("siebenmeter_wuerfe", st.get("siebenmeter", 0)))
	return int(st.get("wuerfe", 0)) + sieben

## Wurfquote in Prozent. Ohne Wurf keine Quote: dann null.
static func wurfquote(st: Dictionary) -> float:
	var versuche: int = wuerfe_gesamt(st)
	if versuche <= 0:
		return 0.0
	return float(st.get("tore", 0)) / float(versuche) * 100.0

static func spiel_verbuchen(d: Dictionary, m: Dictionary) -> void:
	var heim: String = str(m["heim"])
	var gast: String = str(m["gast"])
	var th: int = int(m["tore_heim"])
	var tg: int = int(m["tore_gast"])
	var art: String = str(m["art"])
	if art == "test" or art == "turnier":
		# Vorbereitungs- und Turnierpartien zaehlen nicht in die Vereinswertung:
		# keine Tabelle, keine Statistik, keine Formkurve. Nur Kraefte und
		# Verletzungen wirken nach.
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
			var vorher := {
				"spiele": int(sp["stats"]["karriere"]["spiele"]),
				"tore": int(sp["stats"]["karriere"]["tore"]),
				"paraden": int(sp["stats"]["karriere"]["paraden"]),
			}
			if not (sp["stats"] as Dictionary).has("monat"):
				sp["stats"]["monat"] = Spielerfabrik.leere_saisonstats()
			for ziel in [sp["stats"]["saison"], sp["stats"]["monat"], sp["stats"]["karriere"]]:
				ziel["spiele"] = int(ziel["spiele"]) + 1
				ziel["minuten"] = float(ziel["minuten"]) + float(z["sekunden"]) / 60.0
				ziel["tore"] = int(ziel["tore"]) + int(z["tore"])
				ziel["wuerfe"] = int(ziel["wuerfe"]) + int(z["wuerfe"])
				ziel["assists"] = int(ziel["assists"]) + int(z["assists"])
				ziel["paraden"] = int(ziel["paraden"]) + int(z["paraden"])
				ziel["gegentore"] = int(ziel["gegentore"]) + int(z.get("gegentore", 0))
				ziel["blocks"] = int(ziel["blocks"]) + int(z["blocks"])
				ziel["ballgewinne"] = int(ziel["ballgewinne"]) + int(z["ballgewinne"])
				ziel["technische_fehler"] = int(ziel["technische_fehler"]) + int(z["fehler"])
				ziel["zeitstrafen"] = int(ziel["zeitstrafen"]) + int(z["zeitstrafen"])
				ziel["verwarnungen"] = int(ziel.get("verwarnungen", 0)) + int(z.get("verwarnungen", 0))
				ziel["gegenstoss_tore"] = int(ziel.get("gegenstoss_tore", 0)) + int(z.get("gegenstoss_tore", 0))
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
			Laufbahn.debuet_pruefen(d, sid)
			Laufbahn.marken_pruefen(d, sid, vorher)
			if str(m["art"]) == "liga" and float(z["sekunden"]) >= 900.0:
				Auszeichnungen.leistung_merken(d, str(m["wettbewerb"]), sid,
					float(z["bewertung"]), int(z["tore"]))
			# Torschuetzenliste der Liga
			if str(m["art"]) == "liga" and int(z["tore"]) > 0:
				var liste: Dictionary = d["ligen"][m["wettbewerb"]]["torschuetzen"]
				liste[sid] = int(liste.get(sid, 0)) + int(z["tore"])

## Ranglisten einer Liga über verschiedene Kategorien.
## Jede Kategorie liefert [{sid, wert, zusatz}] absteigend sortiert.
const KATEGORIEN := {
	"tore": {"name": "Tore", "einheit": "", "min_spiele": 1, "torwart": false},
	"tore_pro_spiel": {"name": "Tore je Spiel", "einheit": "", "min_spiele": 5, "torwart": false},
	"assists": {"name": "Vorlagen", "einheit": "", "min_spiele": 1, "torwart": false},
	"wurfquote": {"name": "Wurfquote", "einheit": "%", "min_spiele": 5, "torwart": false},
	"siebenmeter": {"name": "Siebenmetertore", "einheit": "", "min_spiele": 1, "torwart": false},
	# Die Handball-Bundesliga fuehrt drei Torschuetzenlisten nebeneinander:
	# alle Tore, nur die aus dem Feld und nur die vom Siebenmeterstrich. Wer
	# zwanzig Tore wirft, davon achtzehn vom Strich, steht in der einen Liste
	# weit oben und in der anderen gar nicht — und genau das ist die
	# Unterscheidung, auf die es im Handball ankommt.
	"feldtore": {"name": "Feldtore", "einheit": "", "min_spiele": 1, "torwart": false},
	"gegenstosstore": {"name": "Tempogegenstoßtore", "einheit": "", "min_spiele": 1, "torwart": false},
	"technische_fehler": {"name": "Technische Fehler", "einheit": "", "min_spiele": 5, "torwart": false},
	"paraden": {"name": "Paraden", "einheit": "", "min_spiele": 1, "torwart": true},
	"paradenquote": {"name": "Paradenquote", "einheit": "%", "min_spiele": 5, "torwart": true},
	"note": {"name": "Beste Durchschnittsnote", "einheit": "", "min_spiele": 8, "torwart": false},
	"minuten": {"name": "Einsatzzeit", "einheit": " min", "min_spiele": 1, "torwart": false},
	"zeitstrafen": {"name": "Zeitstrafen", "einheit": "", "min_spiele": 1, "torwart": false},
	"ballgewinne": {"name": "Ballgewinne", "einheit": "", "min_spiele": 1, "torwart": false},
	"blocks": {"name": "Blocks", "einheit": "", "min_spiele": 1, "torwart": false},
}

static func rangliste(d: Dictionary, lid: String, kategorie: String, anzahl: int = 15) -> Array:
	var info: Dictionary = KATEGORIEN.get(kategorie, KATEGORIEN["tore"])
	var liste: Array = []
	for cid in d["ligen"][lid]["vereine"]:
		for sid in d["vereine"][cid]["kader"]:
			var sp: Dictionary = d["spieler"][sid]
			if bool(sp["ist_torwart"]) != bool(info["torwart"]):
				continue
			var st: Dictionary = sp["stats"]["saison"]
			var spiele: int = int(st["spiele"])
			if spiele < int(info["min_spiele"]):
				continue
			var wert := 0.0
			var zusatz := ""
			match kategorie:
				"tore":
					wert = float(st["tore"])
				"tore_pro_spiel":
					wert = float(st["tore"]) / float(spiele)
					zusatz = "%d Tore in %d Spielen" % [int(st["tore"]), spiele]
				"assists":
					wert = float(st["assists"])
				"wurfquote":
					var versuche: int = wuerfe_gesamt(st)
					if versuche < 25:
						continue
					wert = wurfquote(st)
					zusatz = "%d von %d" % [int(st["tore"]), versuche]
				"siebenmeter":
					wert = float(st["siebenmeter_tore"])
					zusatz = "von %d Versuchen" % int(st["siebenmeter_wuerfe"])
				"feldtore":
					wert = float(int(st["tore"]) - int(st["siebenmeter_tore"]))
					zusatz = "%d Tore insgesamt" % int(st["tore"])
				"gegenstosstore":
					wert = float(int(st.get("gegenstoss_tore", 0)))
					zusatz = "%d Tore insgesamt" % int(st["tore"])
				"technische_fehler":
					wert = float(st["technische_fehler"])
					zusatz = "in %d Spielen" % spiele
				"paraden":
					wert = float(st["paraden"])
				"paradenquote":
					var wuerfe_aufs_tor: float = float(st["paraden"]) + float(st.get("gegentore", 0))
					if wuerfe_aufs_tor < 40.0:
						continue
					wert = float(st["paraden"]) / wuerfe_aufs_tor * 100.0
					zusatz = "%d Paraden" % int(st["paraden"])
				"note":
					var n: float = Spielerfabrik.note(sp)
					if n <= 0.0:
						continue
					wert = 7.0 - n
					zusatz = Stil.komma(n, 2)
				"minuten":
					wert = float(st["minuten"])
				"zeitstrafen":
					wert = float(st["zeitstrafen"])
				"ballgewinne":
					wert = float(st["ballgewinne"])
				"blocks":
					wert = float(st["blocks"])
			if wert <= 0.0:
				continue
			liste.append({"sid": sid, "wert": wert, "zusatz": zusatz})
	liste.sort_custom(func(a, b): return float(a["wert"]) > float(b["wert"]))
	return liste.slice(0, anzahl)

## Mannschaftsranglisten einer Liga.
static func team_rangliste(d: Dictionary, lid: String, kategorie: String) -> Array:
	var liste: Array = []
	for cid in d["ligen"][lid]["vereine"]:
		var v: Dictionary = d["vereine"][cid]
		var s: Dictionary = v["saison"]
		var spiele: int = maxi(int(s["spiele"]), 1)
		var wert := 0.0
		match kategorie:
			"angriff":
				wert = float(s["tore"]) / float(spiele)
			"abwehr":
				wert = -float(s["gegentore"]) / float(spiele)
			"zuschauer":
				if int(s["heimspiele"]) <= 0:
					continue
				wert = float(s["zuschauer_summe"]) / float(s["heimspiele"])
			"zeitstrafen":
				wert = float(s["zeitstrafen"]) / float(spiele)
		if kategorie != "abwehr" and wert <= 0.0:
			continue
		liste.append({"cid": cid, "wert": wert})
	liste.sort_custom(func(a, b): return float(a["wert"]) > float(b["wert"]))
	return liste

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
