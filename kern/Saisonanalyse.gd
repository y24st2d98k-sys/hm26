class_name Saisonanalyse
extends RefCounted
## Auswertung einer ganzen Saison statt einer einzelnen Partie.
##
## Der Spielbericht zeigt eine Wurfkarte für ein Spiel. Ob eine Mannschaft
## über die Saison von außen nicht trifft, in der Schlussviertelstunde
## einbricht oder ihre Zeitstrafen immer in derselben Phase sammelt, sieht man
## dort nicht. Diese Auswertung sammelt es zusammen — aus dem, was ohnehin
## verbucht wird, ohne zusätzliche Datenhaltung im Spielstand.
##
## Gerechnet wird über die Partien, die noch im Archiv liegen; für den eigenen
## Verein sind das die vollständigen Berichte der laufenden und der letzten
## Saison.

## Zeitabschnitte einer Partie, in denen Tore gezählt werden.
const ABSCHNITTE := [
	{"name": "0–15", "von": 0.0, "bis": 900.0},
	{"name": "15–30", "von": 900.0, "bis": 1800.0},
	{"name": "30–45", "von": 1800.0, "bis": 2700.0},
	{"name": "45–60", "von": 2700.0, "bis": 3600.0},
]

## Alle gespielten Partien eines Vereins in der laufenden Saison.
static func partien(d: Dictionary, cid: String, nur_saison: bool = true) -> Array:
	var saison_start: int = Kalender.saison_index(int(d["tag"])) * Kalender.TAGE_IM_JAHR
	var liste: Array = []
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if not bool(m.get("gespielt", false)):
			continue
		if str(m["heim"]) != cid and str(m["gast"]) != cid:
			continue
		if nur_saison and int(m["tag"]) < saison_start:
			continue
		liste.append(mid)
	liste.sort_custom(func(a, b): return int(d["spiele"][a]["tag"]) < int(d["spiele"][b]["tag"]))
	return liste

## Wurfkarte über alle Partien: je Position Tore, Paraden, Fehlwürfe, Blocks.
## `eigene` = die Abschlüsse des Vereins, sonst die des jeweiligen Gegners.
static func wurfkarte(d: Dictionary, cid: String, eigene: bool = true) -> Dictionary:
	var summe := {}
	for mid in partien(d, cid):
		var m: Dictionary = d["spiele"][mid]
		var bericht: Dictionary = m.get("bericht", {})
		if bericht.is_empty():
			continue
		var heim: bool = str(m["heim"]) == cid
		var seite: String = ("heim" if heim else "gast") if eigene else ("gast" if heim else "heim")
		var karte: Dictionary = (bericht.get(seite, {}) as Dictionary).get("wurfkarte", {})
		for pos in karte.keys():
			if not summe.has(pos):
				summe[pos] = {"tor": 0, "parade": 0, "vorbei": 0, "block": 0}
			for art in ["tor", "parade", "vorbei", "block"]:
				summe[pos][art] = int(summe[pos][art]) + int((karte[pos] as Dictionary).get(art, 0))
	return summe

## Trefferquote je Position, absteigend. Liefert [{position, wuerfe, tore, quote}].
static func positionsquoten(karte: Dictionary) -> Array:
	var liste: Array = []
	for pos in karte.keys():
		var e: Dictionary = karte[pos]
		var wuerfe: int = int(e["tor"]) + int(e["parade"]) + int(e["vorbei"]) + int(e["block"])
		if wuerfe == 0:
			continue
		liste.append({
			"position": str(pos), "wuerfe": wuerfe, "tore": int(e["tor"]),
			"quote": float(e["tor"]) / float(wuerfe) * 100.0,
		})
	liste.sort_custom(func(a, b): return int(a["wuerfe"]) > int(b["wuerfe"]))
	return liste

## Tore und Gegentore je Viertel — zeigt, wann eine Mannschaft stark ist.
static func torverlauf(d: Dictionary, cid: String) -> Array:
	var werte: Array = []
	for a in ABSCHNITTE:
		werte.append({"name": str(a["name"]), "tore": 0, "gegentore": 0})
	for mid in partien(d, cid):
		var m: Dictionary = d["spiele"][mid]
		var bericht: Dictionary = m.get("bericht", {})
		var ticker: Array = bericht.get("ticker", [])
		if ticker.is_empty():
			continue
		var heim: bool = str(m["heim"]) == cid
		# Ältere Spielstände führen im Ticker keine Seite mit. Dann verrät der
		# Sprung im Zwischenstand, wer getroffen hat.
		var vorher := [0, 0]
		for e in ticker:
			var stand: Array = e.get("stand", [0, 0])
			if str(e.get("typ", "")) != "tor":
				vorher = stand
				continue
			var seite: String = str(e.get("team", ""))
			if seite == "":
				seite = "heim" if int(stand[0]) > int(vorher[0]) else "gast"
			vorher = stand
			var eigen: bool = (seite == "heim") == heim
			var zeit: float = float(e.get("zeit", 0.0))
			for i in range(ABSCHNITTE.size()):
				if zeit >= float(ABSCHNITTE[i]["von"]) and zeit < float(ABSCHNITTE[i]["bis"]):
					var ziel: Dictionary = werte[i]
					ziel["tore" if eigen else "gegentore"] = int(ziel["tore" if eigen else "gegentore"]) + 1
					break
	return werte

## Kennzahlen der Saison gegen den Ligaschnitt.
static func kennzahlen(d: Dictionary, cid: String) -> Array:
	var eigene := _mittelwerte(d, cid)
	var lid: String = str(d["vereine"][cid]["liga"])
	var liga := {}
	var n := 0
	for anderer in d["ligen"][lid]["vereine"]:
		var w := _mittelwerte(d, str(anderer))
		if int(w["spiele"]) == 0:
			continue
		for k in w.keys():
			liga[k] = float(liga.get(k, 0.0)) + float(w[k])
		n += 1
	var liste: Array = []
	if n == 0:
		return liste
	for schluessel in [["tore", "Tore je Spiel", false], ["gegentore", "Gegentore je Spiel", true],
			["wurfquote", "Wurfquote in %", false], ["fehler", "Technische Fehler", true],
			["zeitstrafen", "Zeitstrafen", true], ["paraden", "Paraden des Torwarts", false]]:
		var k2: String = str(schluessel[0])
		liste.append({
			"name": str(schluessel[1]),
			"eigen": float(eigene.get(k2, 0.0)),
			"liga": float(liga.get(k2, 0.0)) / float(n),
			"niedriger_besser": bool(schluessel[2]),
		})
	return liste

static func _mittelwerte(d: Dictionary, cid: String) -> Dictionary:
	var s: Dictionary = d["vereine"][cid].get("saison", {})
	var spiele: int = int(s.get("spiele", 0))
	if spiele == 0:
		return {"spiele": 0}
	# Wurfquote, Fehler und Paraden stehen nicht in der Vereinsstatistik —
	# sie werden aus den Spielerwerten des Kaders zusammengezählt.
	var tore := 0
	var wuerfe := 0
	var fehler := 0
	var zeitstrafen := 0
	var paraden := 0
	for sid in d["vereine"][cid]["kader"]:
		var st: Dictionary = d["spieler"][sid]["stats"]["saison"]
		tore += int(st["tore"])
		wuerfe += int(st["wuerfe"])
		fehler += int(st["technische_fehler"])
		zeitstrafen += int(st["zeitstrafen"])
		paraden += int(st["paraden"])
	return {
		"spiele": spiele,
		"tore": float(s.get("tore", 0)) / float(spiele),
		"gegentore": float(s.get("gegentore", 0)) / float(spiele),
		"wurfquote": float(tore) / maxf(float(wuerfe), 1.0) * 100.0,
		"fehler": float(fehler) / float(spiele),
		"zeitstrafen": float(zeitstrafen) / float(spiele),
		"paraden": float(paraden) / float(spiele),
	}

## Notenverlauf der Stammspieler: wer wird besser, wer fällt ab.
## Liefert [{sid, schnitt, letzte_drei, tendenz}], sortiert nach Schnitt.
static func formtabelle(d: Dictionary, cid: String) -> Array:
	var noten := {}
	var reihenfolge: Array = partien(d, cid)
	for mid in reihenfolge:
		var m: Dictionary = d["spiele"][mid]
		var bericht: Dictionary = m.get("bericht", {})
		if bericht.is_empty():
			continue
		var seite: String = "heim" if str(m["heim"]) == cid else "gast"
		var spieler: Dictionary = (bericht.get(seite, {}) as Dictionary).get("spieler", {})
		for sid in spieler.keys():
			if float((spieler[sid] as Dictionary).get("sekunden", 0.0)) < 600.0:
				continue
			if not noten.has(sid):
				noten[sid] = []
			(noten[sid] as Array).append(float((spieler[sid] as Dictionary).get("bewertung", 3.5)))
	var liste: Array = []
	for sid2 in noten.keys():
		var werte: Array = noten[sid2]
		if werte.size() < 3 or not d["spieler"].has(sid2):
			continue
		var summe := 0.0
		for w in werte:
			summe += float(w)
		var schnitt: float = summe / float(werte.size())
		var letzte: Array = werte.slice(maxi(werte.size() - 3, 0))
		var lsumme := 0.0
		for w2 in letzte:
			lsumme += float(w2)
		var jung: float = lsumme / float(letzte.size())
		liste.append({
			"spieler": sid2, "spiele": werte.size(), "schnitt": schnitt,
			"zuletzt": jung, "tendenz": schnitt - jung,
		})
	liste.sort_custom(func(a, b): return float(a["schnitt"]) < float(b["schnitt"]))
	return liste
