class_name Trainerkarriere
extends RefCounted
## Die Laufbahn des Spielers: Vertrag, Ruf, Stationen — und die "Handschrift".
##
## Die Handschrift ist Hallenherz' eigenes Karrieresystem: sechs Achsen, die sich
## langsam danach ausrichten, wie man tatsaechlich arbeitet (nicht danach, was man
## behauptet). Erreicht eine Achse einen Extremwert, entsteht eine Praegung — ein
## dauerhafter, spuerbarer Effekt, der zugleich die Erwartungshaltung von Vorstand,
## Presse und Spielern verschiebt.

const ACHSEN := {
	"tempo": {"name": "Tempo", "links": "Kontrolliert", "rechts": "Tempodiktat"},
	"bollwerk": {"name": "Abwehr", "links": "Offene Deckung", "rechts": "Bollwerk"},
	"jugend": {"name": "Jugend", "links": "Erfahrung zuerst", "rechts": "Talentschmiede"},
	"wagemut": {"name": "Wagemut", "links": "Absicherung", "rechts": "Hasardeur"},
	"rotation": {"name": "Rotation", "links": "Stammformation", "rechts": "Breiter Kader"},
	"strenge": {"name": "Strenge", "links": "Kumpeltyp", "rechts": "Eiserne Hand"},
}

const PRAEGUNGEN := {
	"tempodiktat": {"achse": "tempo", "richtung": 1, "schwelle": 78.0, "name": "Tempodiktat",
		"text": "Ihre Mannschaften laufen. Tempogegenstöße sitzen häufiger."},
	"kontrolleur": {"achse": "tempo", "richtung": -1, "schwelle": 22.0, "name": "Kontrolleur",
		"text": "Geduldige Angriffe: weniger technische Fehler."},
	"betonmischer": {"achse": "bollwerk", "richtung": 1, "schwelle": 78.0, "name": "Bollwerk",
		"text": "Ihre Abwehr steht. Die Abwehrleistung steigt spürbar."},
	"talentfluesterer": {"achse": "jugend", "richtung": 1, "schwelle": 78.0, "name": "Talentflüsterer",
		"text": "Junge Spieler entwickeln sich unter Ihnen deutlich schneller."},
	"hasardeur": {"achse": "wagemut", "richtung": 1, "schwelle": 78.0, "name": "Hasardeur",
		"text": "Das 7-gegen-6 sitzt: weniger Bälle ins leere Tor."},
	"rotationsprinzip": {"achse": "rotation", "richtung": 1, "schwelle": 78.0, "name": "Rotationsprinzip",
		"text": "Ihre Spieler laden das Lastkonto langsamer auf."},
	"eiserne_hand": {"achse": "strenge", "richtung": 1, "schwelle": 78.0, "name": "Eiserne Hand",
		"text": "Disziplin: Die Kabine bleibt auch in Krisen ruhig."},
	"kumpeltyp": {"achse": "strenge", "richtung": -1, "schwelle": 22.0, "name": "Kumpeltyp",
		"text": "Die Spieler mögen Sie. Moral erholt sich schneller."},
}

const HINTERGRUENDE := {
	"exprofi": {"name": "Ehemaliger Profi", "ruf": 46.0, "start": {"strenge": 58.0, "tempo": 58.0},
		"text": "Sie haben selbst 300 Spiele im Rückraum bestritten. Die Kabine hört zu."},
	"taktiker": {"name": "Taktiktüftler", "ruf": 32.0, "start": {"bollwerk": 64.0, "wagemut": 40.0},
		"text": "Videoanalyse statt Spielerkarriere. Sie kennen jede Deckungsvariante."},
	"nachwuchs": {"name": "Nachwuchscoach", "ruf": 26.0, "start": {"jugend": 70.0, "rotation": 60.0},
		"text": "Sie kommen aus der A-Jugend und bringen einen Blick für Talente mit."},
	"quereinsteiger": {"name": "Quereinsteiger", "ruf": 18.0, "start": {"wagemut": 62.0},
		"text": "Niemand kennt Sie. Genau deshalb probieren Sie Dinge, die andere lassen."},
	"auslandsrueckkehrer": {"name": "Auslandsrückkehrer", "ruf": 40.0, "start": {"tempo": 66.0, "rotation": 58.0},
		"text": "Vier Jahre im Ausland haben Ihren Stil geprägt — schnell und breit aufgestellt."},
}

static func neu(eingabe: Dictionary, verein_id: String, d: Dictionary) -> Dictionary:
	var hintergrund: String = str(eingabe.get("hintergrund", "taktiker"))
	var hg: Dictionary = HINTERGRUENDE.get(hintergrund, HINTERGRUENDE["taktiker"])
	var handschrift := {}
	for a in ACHSEN.keys():
		handschrift[a] = float((hg["start"] as Dictionary).get(a, 50.0))
	return {
		"vorname": str(eingabe.get("vorname", "Alex")),
		"nachname": str(eingabe.get("nachname", "Bergmann")),
		"nation": str(eingabe.get("nation", "de")),
		"alter": int(eingabe.get("alter", 38)),
		"hintergrund": hintergrund,
		"hintergrund_name": hg["name"],
		"ruf": float(hg["ruf"]),
		"nationalteam": "",
		"verbandsangebote": [],
		"verein": verein_id,
		"vertrag": {
			"bis_saison": 2,
			"gehalt": 1800.0 + float(d["vereine"][verein_id]["ruf"]) * 55.0,
			"abfindung_faktor": 0.5,
		},
		"handschrift": handschrift,
		"praegungen": [],
		"stationen": [{
			"verein": verein_id,
			"vereinsname": str(d["vereine"][verein_id]["name"]),
			"von_saison": 0,
			"bis_saison": -1,
			"spiele": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0,
			"titel": [],
		}],
		"titel": [],
		"statistik": {"spiele": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0, "tore": 0, "gegentore": 0},
		"jobangebote": [],
		"auszeichnungen": [],
	}

static func station(t: Dictionary) -> Dictionary:
	if (t["stationen"] as Array).is_empty():
		return {}
	return (t["stationen"] as Array)[-1]

## Verbucht eine Partie in der Trainerbilanz.
static func spiel_verbuchen(d: Dictionary, m: Dictionary, cid: String) -> void:
	var t: Dictionary = d["trainer"]
	if t.is_empty() or str(t.get("verein", "")) != cid:
		return
	var eigene: int = int(m["tore_heim"]) if str(m["heim"]) == cid else int(m["tore_gast"])
	var fremde: int = int(m["tore_gast"]) if str(m["heim"]) == cid else int(m["tore_heim"])
	var st: Dictionary = station(t)
	for ziel in [t["statistik"], st]:
		ziel["spiele"] = int(ziel["spiele"]) + 1
		if eigene > fremde:
			ziel["siege"] = int(ziel["siege"]) + 1
		elif eigene == fremde:
			ziel["unentschieden"] = int(ziel["unentschieden"]) + 1
		else:
			ziel["niederlagen"] = int(ziel["niederlagen"]) + 1
	t["statistik"]["tore"] = int(t["statistik"].get("tore", 0)) + eigene
	t["statistik"]["gegentore"] = int(t["statistik"].get("gegentore", 0)) + fremde
	# Ruf: Siege gegen starke Gegner zaehlen mehr
	var gegner: String = str(m["gast"]) if str(m["heim"]) == cid else str(m["heim"])
	var gegnerruf: float = float(d["vereine"][gegner]["ruf"])
	var eigenruf: float = float(d["vereine"][cid]["ruf"])
	var delta := 0.0
	if eigene > fremde:
		delta = 0.12 + clampf((gegnerruf - eigenruf) / 100.0, -0.06, 0.35)
	elif eigene < fremde:
		# Eine Niederlage gegen einen uebermaechtigen Gegner faellt kaum ins
		# Gewicht — den Ruf heben darf sie aber nie.
		delta = -0.1 + clampf((gegnerruf - eigenruf) / 140.0, -0.05, 0.09)
	t["ruf"] = clampf(float(t["ruf"]) + delta, 1.0, 100.0)
	handschrift_pflegen(d, cid)

## Richtet die Handschrift langsam an der tatsaechlichen Arbeitsweise aus.
static func handschrift_pflegen(d: Dictionary, cid: String) -> void:
	var t: Dictionary = d["trainer"]
	if t.is_empty():
		return
	var v: Dictionary = d["vereine"][cid]
	var taktik: Dictionary = v["taktik"]
	var h: Dictionary = t["handschrift"]
	_ziehe(h, "tempo", float(taktik["tempo"]))
	_ziehe(h, "bollwerk", 100.0 - float(taktik["risiko"]) * 0.5 - (30.0 if str(taktik["abwehr"]) in ["3-2-1", "4-2"] else 0.0))
	_ziehe(h, "wagemut", float(taktik["risiko"]) * 0.7 + (30.0 if str(taktik["siebter_feldspieler"]) != "nie" else 0.0))
	_ziehe(h, "rotation", float(taktik.get("wechselspiel", 50)))
	_ziehe(h, "strenge", float(taktik["haerte"]))
	# Jugendachse aus dem tatsaechlichen Einsatz junger Spieler
	var jung := 0.0
	var gesamt := 0.0
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		var minuten: float = float(sp["stats"]["saison"]["minuten"])
		gesamt += minuten
		if int(sp["alter"]) <= 21:
			jung += minuten
	if gesamt > 200.0:
		_ziehe(h, "jugend", clampf(jung / gesamt * 320.0, 0.0, 100.0))
	praegungen_pruefen(d)

static func _ziehe(h: Dictionary, achse: String, ziel: float) -> void:
	h[achse] = clampf(lerpf(float(h.get(achse, 50.0)), clampf(ziel, 0.0, 100.0), 0.012), 0.0, 100.0)

static func praegungen_pruefen(d: Dictionary) -> void:
	var t: Dictionary = d["trainer"]
	var h: Dictionary = t["handschrift"]
	var vorhanden: Array = t["praegungen"]
	for schluessel in PRAEGUNGEN.keys():
		if vorhanden.has(schluessel):
			continue
		var p: Dictionary = PRAEGUNGEN[schluessel]
		var wert: float = float(h.get(p["achse"], 50.0))
		var erreicht: bool = wert >= float(p["schwelle"]) if int(p["richtung"]) > 0 else wert <= float(p["schwelle"])
		if erreicht:
			vorhanden.append(schluessel)
			t["ruf"] = clampf(float(t["ruf"]) + 1.5, 1.0, 100.0)
			Welt.nachricht({
				"typ": "karriere", "wichtig": true,
				"betreff": "Neue Prägung: %s" % p["name"],
				"text": "%s Ihre Handschrift als Trainer wird sichtbar — und die Liga nimmt es zur Kenntnis." % p["text"],
			})

static func hat_praegung(d: Dictionary, schluessel: String) -> bool:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return false
	return (t.get("praegungen", []) as Array).has(schluessel)

## Praegungswirkung nur fuer den Verein des Spielers.
static func bonus_fuer(d: Dictionary, cid: String, schluessel: String) -> bool:
	if cid != str(d.get("trainer", {}).get("verein", "")):
		return false
	return hat_praegung(d, schluessel)

static func titel_gewinnen(d: Dictionary, bezeichnung: String) -> void:
	var t: Dictionary = d["trainer"]
	(t["titel"] as Array).append({"saison": Welt.saison_index(), "titel": bezeichnung, "verein": str(t["verein"])})
	var st: Dictionary = station(t)
	if not st.is_empty():
		(st["titel"] as Array).append(bezeichnung)
	t["ruf"] = clampf(float(t["ruf"]) + 6.0, 1.0, 100.0)

## Wechselt den Verein: alte Station schliessen, neue eroeffnen.
static func verein_wechseln(d: Dictionary, neuer_verein: String) -> void:
	var t: Dictionary = d["trainer"]
	var alt: Dictionary = station(t)
	if not alt.is_empty():
		alt["bis_saison"] = Welt.saison_index()
	if str(t["verein"]) != "" and d["vereine"].has(str(t["verein"])):
		d["vereine"][str(t["verein"])]["ist_mensch"] = false
		d["vereine"][str(t["verein"])]["trainer"] = ""
	t["verein"] = neuer_verein
	if neuer_verein != "":
		Vorstand.amtsantritt(d, neuer_verein)
		d["vereine"][neuer_verein]["ist_mensch"] = true
		d["vereine"][neuer_verein]["trainer"] = "mensch"
		(t["stationen"] as Array).append({
			"verein": neuer_verein,
			"vereinsname": str(d["vereine"][neuer_verein]["name"]),
			"von_saison": Welt.saison_index(),
			"bis_saison": -1,
			"spiele": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0,
			"titel": [],
		})
		t["vertrag"] = {
			"bis_saison": Welt.saison_index() + 3,
			"gehalt": 1800.0 + float(d["vereine"][neuer_verein]["ruf"]) * 55.0 + float(t["ruf"]) * 30.0,
			"abfindung_faktor": 0.5,
		}
	Welt.mein_verein_id = neuer_verein
	# Gesichtete Talente des alten Vereins bleiben dort.
	Talentsuche.aufraeumen(d)

static func voller_name(t: Dictionary) -> String:
	return "%s %s" % [t.get("vorname", ""), t.get("nachname", "")]

## Textuelle Einordnung des Rufs.
static func ruf_stufe(ruf: float) -> String:
	if ruf >= 88.0:
		return "Weltklasse-Trainer"
	elif ruf >= 74.0:
		return "international gefragt"
	elif ruf >= 58.0:
		return "etablierter Erstligatrainer"
	elif ruf >= 42.0:
		return "solider Fachmann"
	elif ruf >= 26.0:
		return "Hoffnungsträger"
	return "unbeschriebenes Blatt"
