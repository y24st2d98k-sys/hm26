class_name Playoffs
extends RefCounted
## Meisterschaft über Play-offs.
##
## In der Bundesliga und der ASOBAL ist Meister, wer nach der Doppelrunde oben
## steht. In Dänemark, Frankreich (ab 2026/27), Polen, Ungarn, Schweden,
## Norwegen, der Schweiz und Österreich nicht: dort spielen die Besten der
## Hauptrunde den Titel in K.-o.-Runden aus, und der Tabellenerste kann im
## Halbfinale scheitern. Bisher war jede Liga eine Doppelrunde — damit fehlte
## genau der Abend, an dem in diesen Ländern die Saison entschieden wird.
##
## Eine Liga bekommt Play-offs über den Datensatz: `"playoffs": 8` (oder 4)
## in ihrem Eintrag in daten/ligen.json. Die Hauptrunde endet dann früher, und
## im Mai folgen Viertelfinale, Halbfinale und Finale, jeweils mit Hin- und
## Rückspiel. Der besser Platzierte hat im Rückspiel Heimrecht und kommt bei
## Torgleichstand weiter — so belohnt die Hauptrunde, ohne zu entscheiden.
##
## Auf- und Abstieg und die Europapokalplätze bleiben bei der Hauptrunde; nur
## der Meister und der Vizemeister werden nach den Play-offs gesetzt.

## Letzter Tag der Hauptrunde in einer Liga mit Play-offs (Tag der Saison).
const HAUPTRUNDE_ENDE := 286
## Hin- und Rückspieltermine: Viertelfinale, Halbfinale, Finale.
const TERMINE := [294, 298, 305, 309, 316, 321]

static func hat_playoffs(liga: Dictionary) -> bool:
	return int(liga.get("playoffs", 0)) >= 2

## Zu Saisonbeginn: der Stand wird zurückgesetzt.
static func zuruecksetzen(liga: Dictionary) -> void:
	if not hat_playoffs(liga):
		liga.erase("playoff")
		return
	liga["playoff"] = {"phase": "offen", "runde": 0, "paarungen": [], "sieger": "", "finalist": "",
		"basis": 0}

## Nach jedem Spieltag: sind die Voraussetzungen für die nächste Runde da?
static func fortschreiben(d: Dictionary) -> Array:
	var meldungen: Array = []
	for lid in (d.get("ligen", {}) as Dictionary).keys():
		var liga: Dictionary = d["ligen"][lid]
		if not hat_playoffs(liga):
			continue
		var po: Dictionary = liga.get("playoff", {})
		if po.is_empty():
			zuruecksetzen(liga)
			po = liga["playoff"]
		match str(po["phase"]):
			"offen":
				# Vorher lohnt das Nachsehen nicht — die Hauptrunde endet
				# frühestens am letzten Spieltag.
				if Kalender.tag_in_saison(int(d["tag"])) < HAUPTRUNDE_ENDE - 30:
					continue
				if _hauptrunde_fertig(d, str(lid)):
					var tabelle := Spielplan.tabelle_sortiert(d, str(lid))
					var n: int = mini(int(liga["playoffs"]), tabelle.size())
					# Auf eine Zweierpotenz: 8, 4 oder 2.
					var groesse := 2
					while groesse * 2 <= n:
						groesse *= 2
					var setzliste: Array = tabelle.slice(0, groesse)
					po["setzliste"] = setzliste.duplicate()
					po["basis"] = Kalender.saison_index(int(d["tag"])) * Kalender.TAGE_IM_JAHR
					_runde_ansetzen(d, str(lid), _bracket(setzliste))
					po["phase"] = "laeuft"
					meldungen.append({"liga": str(lid), "text": "Die Play-offs beginnen.", "teams": setzliste})
			"laeuft":
				var sieger := _runde_auswerten(d, str(lid))
				if sieger.is_empty():
					continue
				if sieger.size() == 1:
					po["phase"] = "beendet"
					po["sieger"] = str(sieger[0])
					meldungen.append({"liga": str(lid), "text": "Meister", "teams": sieger})
				else:
					_runde_ansetzen(d, str(lid), sieger)
					meldungen.append({"liga": str(lid), "text": "Nächste Runde", "teams": sieger})
	return meldungen

## 1–8, 4–5, 2–7, 3–6: so treffen sich die beiden Besten frühestens im Finale.
static func _bracket(setz: Array) -> Array:
	var n: int = setz.size()
	if n == 8:
		return [setz[0], setz[7], setz[3], setz[4], setz[1], setz[6], setz[2], setz[5]]
	if n == 4:
		return [setz[0], setz[3], setz[1], setz[2]]
	return setz.duplicate()

static func _hauptrunde_fertig(d: Dictionary, lid: String) -> bool:
	var gefunden := false
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["wettbewerb"]) != lid or str(m["art"]) != "liga":
			continue
		gefunden = true
		if not bool(m["gespielt"]):
			return false
	return gefunden

## Setzt eine Runde an. `teams` ist paarweise geordnet: [a, b, a, b, …], und
## a ist jeweils der besser Gesetzte.
static func _runde_ansetzen(d: Dictionary, lid: String, teams: Array) -> void:
	var liga: Dictionary = d["ligen"][lid]
	var po: Dictionary = liga["playoff"]
	var runde: int = int(po["runde"])
	# Wie viele Runden noch kommen, entscheidet über den Termin: das Finale
	# liegt immer auf den letzten beiden Terminen.
	var runden_rest: int = 0
	var k: int = teams.size()
	while k > 1:
		runden_rest += 1
		k /= 2
	var idx: int = TERMINE.size() - runden_rest * 2
	idx = clampi(idx, 0, TERMINE.size() - 2)
	var basis: int = int(po.get("basis", 0))
	var frueheste: int = int(d["tag"]) + 3
	var t1: int = maxi(basis + int(TERMINE[idx]), frueheste)
	var t2: int = maxi(basis + int(TERMINE[idx + 1]), t1 + 3)
	var paarungen: Array = []
	var setz: Array = po.get("setzliste", [])
	for i in range(0, teams.size() - 1, 2):
		var a: String = str(teams[i])
		var b: String = str(teams[i + 1])
		# Der besser Gesetzte hat das Rückspiel daheim.
		if setz.find(b) >= 0 and (setz.find(a) < 0 or setz.find(b) < setz.find(a)):
			var tausch := a
			a = b
			b = tausch
		var hin := Spielplan.neues_spiel(d, lid, "playoff", runde + 1, t1, b, a, {"ko": true})
		var rueck := Spielplan.neues_spiel(d, lid, "playoff", runde + 1, t2, a, b,
			{"ko": true, "hinspiel": hin["id"]})
		paarungen.append({"hin": hin["id"], "rueck": rueck["id"], "a": a, "b": b})
	po["paarungen"] = paarungen
	po["runde"] = runde + 1

## Wer weiterkommt. Leer, solange noch ein Rückspiel aussteht.
static func _runde_auswerten(d: Dictionary, lid: String) -> Array:
	var po: Dictionary = d["ligen"][lid]["playoff"]
	var paarungen: Array = po.get("paarungen", [])
	if paarungen.is_empty():
		return []
	var sieger: Array = []
	for p in paarungen:
		var hin: Dictionary = d["spiele"].get(str(p["hin"]), {})
		var rueck: Dictionary = d["spiele"].get(str(p["rueck"]), {})
		if hin.is_empty() or rueck.is_empty() or not bool(rueck["gespielt"]) or not bool(hin["gespielt"]):
			return []
		# a hat das Rückspiel daheim.
		var a_tore: int = int(rueck["tore_heim"]) + int(hin["tore_gast"])
		var b_tore: int = int(rueck["tore_gast"]) + int(hin["tore_heim"])
		if b_tore > a_tore:
			sieger.append(str(p["b"]))
		else:
			sieger.append(str(p["a"]))
		if paarungen.size() == 1:
			po["finalist"] = str(p["b"]) if b_tore <= a_tore else str(p["a"])
	return sieger

## Der Meister einer Liga mit Play-offs — oder "" ohne.
static func meister(liga: Dictionary) -> String:
	var po: Dictionary = liga.get("playoff", {})
	if po.is_empty() or str(po.get("phase", "")) != "beendet":
		return ""
	return str(po.get("sieger", ""))

## Bringt die Abschlusstabelle in die Reihenfolge der Titelvergabe: Meister
## vorn, Finalist dahinter. Der Rest bleibt, wie die Hauptrunde endete.
static func abschlusstabelle(liga: Dictionary, tabelle: Array) -> Array:
	var m := meister(liga)
	if m == "":
		return tabelle
	var neu: Array = tabelle.duplicate()
	var f: String = str(liga["playoff"].get("finalist", ""))
	if f != "" and neu.has(f):
		neu.erase(f)
		neu.push_front(f)
	neu.erase(m)
	neu.push_front(m)
	return neu

static func rundenname(teams: int) -> String:
	match teams:
		2: return "Finale"
		4: return "Halbfinale"
		8: return "Viertelfinale"
	return "Achtelfinale"
