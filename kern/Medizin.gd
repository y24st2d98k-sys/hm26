class_name Medizin
extends RefCounted
## Verletzungen, Genesung und Belastungssteuerung.
##
## Kernidee von Hallenherz: das "Lastkonto". Jede Minute auf dem Feld und jede harte
## Trainingswoche laedt es auf, Regeneration baut es ab. Ein hohes Lastkonto senkt Form
## und Frische und erhoeht das Verletzungsrisiko spuerbar — Rotation ist dadurch keine
## Fleissaufgabe, sondern eine echte Entscheidung.

## Verletzungen nach Koerperregion.
##
## Bisher gab es drei Toepfe — leicht, mittel, schwer — und aus dem passenden
## wurde ein Name gezogen. Das ergab bunte Meldungen, aber kein Muster: ein
## Kreuzbandriss war genauso wahrscheinlich wie ein Mittelfussbruch, und
## Vorgeschichte gab es nicht.
##
## Der VBG-Sportreport, den der Konzeptbericht zitiert, beschreibt das Muster
## genau: das Sprunggelenk ist die haeufigste Verletzung im Handball und
## entsteht bei der Landung nach dem Sprungwurf. Das Knie steht fuer gut ein
## Fuenftel der Faelle, aber fuer ueber vierzig Prozent aller Ausfalltage — der
## Kreuzbandriss ist die schwerste Verletzung des Sports. Die Schulter ist die
## Verletzung des Rueckraumspielers: sie entsteht, wenn ein Abwehrspieler in
## den Wurfarm greift, sie kostet Monate, und sie kommt ohne Operation fast
## immer wieder.
const REGIONEN := {
	"sprunggelenk": {
		"name": "Sprunggelenk", "anteil": 0.16, "wiederholung": 1.9,
		"stufen": [
			{"bis": 0.84, "arten": ["Bänderdehnung im Sprunggelenk", "Sprunggelenkdistorsion",
				"Kapselreizung im Sprunggelenk"], "von": 3, "hoch": 12, "schwere": 1},
			{"bis": 1.00, "arten": ["Syndesmosebandriss", "Außenbandriss im Sprunggelenk"],
				"von": 40, "hoch": 95, "schwere": 3},
		],
	},
	"knie": {
		"name": "Kniegelenk", "anteil": 0.23, "wiederholung": 1.6,
		"stufen": [
			{"bis": 0.64, "arten": ["Knieprellung", "Kapselreizung im Knie"],
				"von": 2, "hoch": 10, "schwere": 1},
			{"bis": 0.82, "arten": ["Meniskusschaden", "Patellasehnenreizung", "Innenbandanriss"],
				"von": 25, "hoch": 70, "schwere": 2},
			{"bis": 1.00, "arten": ["Kreuzbandriss"], "von": 175, "hoch": 285, "schwere": 3,
				"dauerschaden": {"sprungkraft": 1.0, "tempo": 0.7, "beweglichkeit": 0.5}},
		],
	},
	"schulter": {
		"name": "Schulter", "anteil": 0.09, "wiederholung": 3.2,
		"stufen": [
			{"bis": 0.52, "arten": ["Schulterprellung", "Reizung der Rotatorenmanschette"],
				"von": 5, "hoch": 16, "schwere": 1},
			{"bis": 0.84, "arten": ["Schultereckgelenksprengung", "Bizepssehnenreizung"],
				"von": 28, "hoch": 70, "schwere": 2},
			{"bis": 1.00, "arten": ["Schulterluxation"], "von": 110, "hoch": 240, "schwere": 3,
				"dauerschaden": {"wurfkraft": 1.0, "wurfpraezision": 0.5}},
		],
	},
	"muskulatur": {
		"name": "Oberschenkel", "anteil": 0.15, "wiederholung": 1.7,
		"stufen": [
			{"bis": 0.70, "arten": ["Zerrung im Oberschenkel", "Wadenprobleme", "Adduktorenprobleme"],
				"von": 4, "hoch": 14, "schwere": 1},
			{"bis": 1.00, "arten": ["Muskelfaserriss", "Muskelbündelriss"],
				"von": 18, "hoch": 42, "schwere": 2},
		],
	},
	"hand": {
		"name": "Hand und Finger", "anteil": 0.12, "wiederholung": 1.2,
		"stufen": [
			{"bis": 0.76, "arten": ["Fingerprellung", "Bänderdehnung am Daumen", "Handgelenksreizung"],
				"von": 3, "hoch": 14, "schwere": 1},
			{"bis": 1.00, "arten": ["Mittelhandbruch", "Kahnbeinbruch"],
				"von": 26, "hoch": 55, "schwere": 2},
		],
	},
	"kopf": {
		"name": "Kopf und Gesicht", "anteil": 0.09, "wiederholung": 1.4,
		"stufen": [
			{"bis": 0.72, "arten": ["Platzwunde", "Nasenbeinprellung"], "von": 1, "hoch": 7, "schwere": 1},
			{"bis": 1.00, "arten": ["Gehirnerschütterung", "Nasenbeinbruch"],
				"von": 8, "hoch": 24, "schwere": 2},
		],
	},
	"ruecken": {
		"name": "Rücken", "anteil": 0.07, "wiederholung": 2.1,
		"stufen": [
			{"bis": 0.80, "arten": ["Rückenbeschwerden", "Rippenprellung"], "von": 3, "hoch": 14, "schwere": 1},
			{"bis": 1.00, "arten": ["Bandscheibenvorfall", "Rippenbruch"], "von": 30, "hoch": 80, "schwere": 2},
		],
	},
	"fuss": {
		"name": "Fuß und Unterschenkel", "anteil": 0.09, "wiederholung": 1.5,
		"stufen": [
			{"bis": 0.74, "arten": ["Fußprellung", "Schienbeinreizung"], "von": 4, "hoch": 18, "schwere": 1},
			{"bis": 0.94, "arten": ["Mittelfußbruch", "Ermüdungsbruch"], "von": 34, "hoch": 78, "schwere": 2},
			{"bis": 1.00, "arten": ["Achillessehnenriss"], "von": 160, "hoch": 265, "schwere": 3,
				"dauerschaden": {"sprungkraft": 0.8, "tempo": 0.8}},
		],
	},
}

## Wie stark eine ueberstandene Verletzung derselben Region wiederkommt, bleibt
## in `vorgeschichte` des Spielers stehen. Der Konzeptbericht nennt fuer die
## Schulter eine "nahezu hundertprozentige Rezidivwahrscheinlichkeit" — das ist
## der hoechste Wiederholungsfaktor in der Tabelle oben.
const VORGESCHICHTE_MAX := 3

static func erzeuge_verletzung(d: Dictionary, sid: String, im_spiel: bool) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var region := _region_ziehen(sp)
	var daten_region: Dictionary = REGIONEN[region]
	var stufe := _stufe_ziehen(daten_region)
	var art: String = str(Namen.waehle(stufe["arten"] as Array))
	var tage: int = Namen.wuerfel(int(stufe["von"]), int(stufe["hoch"]))
	var schwere: int = int(stufe["schwere"])
	var verein: String = str(sp["verein"])
	if verein != "" and d["vereine"].has(verein):
		var medizin: int = int(d["vereine"][verein]["infrastruktur"]["medizin"])
		tage = int(float(tage) * clampf(1.18 - float(medizin) * 0.026, 0.7, 1.2))
	sp["verletzung"] = {
		"art": art, "tage": tage, "rest": tage, "schwere": schwere,
		"region": region, "im_spiel": im_spiel, "seit_tag": int(d["tag"]),
	}
	_vorgeschichte_merken(sp, region)
	if stufe.has("dauerschaden"):
		_dauerschaden(d, sid, stufe["dauerschaden"] as Dictionary)
	sp["fitness"] = clampf(float(sp["fitness"]) - float(schwere) * 12.0, 20.0, 100.0)
	sp["moral"] = clampf(float(sp["moral"]) - float(schwere) * 5.0, 5.0, 100.0)
	Laufbahn.schwere_verletzung(d, sid, art, tage)
	return sp["verletzung"]

## Welche Region es trifft. Wer dort schon einmal verletzt war, trifft es
## wieder haeufiger — bei der Schulter am staerksten.
static func _region_ziehen(sp: Dictionary) -> String:
	var vor: Dictionary = sp.get("vorgeschichte", {})
	var gewichte := {}
	var summe := 0.0
	for r in REGIONEN.keys():
		var g: float = float((REGIONEN[r] as Dictionary)["anteil"])
		var schon: int = int(vor.get(r, 0))
		if schon > 0:
			g *= 1.0 + (float((REGIONEN[r] as Dictionary)["wiederholung"]) - 1.0) * mini(schon, VORGESCHICHTE_MAX)
		gewichte[r] = g
		summe += g
	var wurf: float = Namen.zufall() * summe
	for r in gewichte.keys():
		wurf -= float(gewichte[r])
		if wurf <= 0.0:
			return str(r)
	return str(REGIONEN.keys()[0])

static func _stufe_ziehen(region: Dictionary) -> Dictionary:
	var w: float = Namen.zufall()
	for stufe in region["stufen"]:
		if w <= float((stufe as Dictionary)["bis"]):
			return stufe as Dictionary
	return (region["stufen"] as Array)[(region["stufen"] as Array).size() - 1] as Dictionary

static func _vorgeschichte_merken(sp: Dictionary, region: String) -> void:
	if not sp.has("vorgeschichte"):
		sp["vorgeschichte"] = {}
	var vor: Dictionary = sp["vorgeschichte"]
	vor[region] = int(vor.get(region, 0)) + 1

## Was eine schwere Verletzung dauerhaft kostet.
##
## Ein Kreuzbandriss nimmt Sprungkraft und Antritt, eine Schulterluxation die
## Wurfgeschwindigkeit — beides steht so im Konzeptbericht, und beides bleibt.
## Der Spieler kehrt zurueck, aber nicht als derselbe.
static func _dauerschaden(d: Dictionary, sid: String, felder: Dictionary) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var attr: Dictionary = sp["attr"]
	var alter: float = float(sp["alter"])
	# Mit dreissig steckt man einen Kreuzbandriss schlechter weg als mit
	# zweiundzwanzig.
	var altersfaktor: float = clampf(0.6 + maxf(alter - 24.0, 0.0) * 0.075, 0.6, 1.6)
	var verloren := {}
	for feld in felder.keys():
		if not attr.has(feld):
			continue
		var abzug: float = float(felder[feld]) * altersfaktor * Namen.bereich(0.5, 1.5)
		if abzug < 0.25:
			continue
		var neu: float = maxf(float(attr[feld]) - abzug, 1.0)
		verloren[feld] = float(attr[feld]) - neu
		attr[feld] = neu
	if verloren.is_empty():
		return
	sp["potenzial"] = maxf(float(sp["potenzial"]) - 1.5 * altersfaktor, Spielerfabrik.gesamt(sp))
	Spielerfabrik.staerke_verwerfen(sp)
	if str(sp["verein"]) != Welt.mein_verein_id:
		return
	var namen: Array = []
	for feld2 in verloren.keys():
		namen.append(str(Spielerfabrik.ATTR_LABEL.get(feld2, feld2)))
	Welt.nachricht({
		"typ": "medizin", "wichtig": true,
		"betreff": "Bleibender Schaden bei %s" % Spielerfabrik.voller_name(sp),
		"text": "Die Ärzte sind deutlich: %s wird zurückkommen, aber nicht als derselbe. Betroffen sind %s. Solche Verletzungen hinterlassen etwas — das ist im Handball die Regel, nicht die Ausnahme." % [
			Spielerfabrik.kurz_name(sp), " und ".join(namen)],
		"daten": {"spieler": str(sp["id"])},
	})

## Wird von der Simulation aufgerufen, wenn sich jemand im Spiel verletzt.
## Blessuren: die kurzen Sachen, die jeder Profi mehrmals im Jahr hat.
##
## Gemessen mit werkzeuge/Verletzungssonde.gd: nur 44,7 Prozent der
## Bundesligaspieler verletzten sich ueberhaupt einmal in einer Spielzeit, der
## VBG-Sportreport nennt fast drei Viertel. Die Ausfalltage lagen dabei fast
## richtig (29,4 gegen 34). Das Spiel hatte also zu wenige und dafuer zu lange
## Verletzungen: ein paar Kreuzbaender, und sonst war der Kader gesund.
##
## In Wirklichkeit ist das Gegenteil der Normalfall — die Prellung, die zwei
## Trainingstage kostet, der verdrehte Knoechel, der Infekt. Fuer den Manager
## ist genau diese Sorte die interessante: sie zwingt zur Rotation, ohne eine
## Saison zu entscheiden. Wer keinen zweiten Mann auf der Position hat, merkt
## das dann jede zweite Woche und nicht einmal in drei Jahren.
const BLESSUREN := [
	{"art": "Prellung", "region": "muskulatur", "von": 2, "hoch": 5},
	{"art": "Muskelverhaertung", "region": "muskulatur", "von": 3, "hoch": 7},
	{"art": "Umgeknickt", "region": "sprunggelenk", "von": 2, "hoch": 6},
	{"art": "Fingerverletzung", "region": "hand", "von": 3, "hoch": 8},
	{"art": "Schlag auf das Knie", "region": "knie", "von": 2, "hoch": 5},
	{"art": "Rueckenbeschwerden", "region": "ruecken", "von": 2, "hoch": 6},
	{"art": "Schulterprellung", "region": "schulter", "von": 2, "hoch": 6},
	{"art": "Infekt", "region": "kopf", "von": 3, "hoch": 7},
]

## Wie oft jemand sich etwas Kleines zuzieht — je Minute auf der Platte.
##
## Das Lastkonto entscheidet mit: wer ausgelaugt spielt, holt sich die
## Prellung, die ein frischer Spieler wegsteckt. Die medizinische Abteilung
## senkt es wie bei den grossen Verletzungen auch.
const BLESSUR_GRUND := 0.00046

static func blessurrisiko(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = d["spieler"][sid]
	var last: float = float(sp["last"]) / 100.0
	var fit: float = float(sp["fitness"]) / 100.0
	var wert: float = BLESSUR_GRUND * (0.65 + 0.7 * last) * (1.3 - 0.4 * fit)
	var verein: String = str(sp["verein"])
	if verein != "" and d["vereine"].has(verein):
		wert *= praeventionsfaktor(d, verein)
	return wert

## Eine Blessur zuziehen. Keine Vorgeschichte, kein Dauerschaden, kein Eintrag
## in der Laufbahn — das hier ist kein Karriereereignis, sondern ein Ausfall.
static func blessur(d: Dictionary, sid: String) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var e: Dictionary = Namen.waehle(BLESSUREN)
	var tage: int = Namen.wuerfel(int(e["von"]), int(e["hoch"]))
	sp["verletzung"] = {
		"art": str(e["art"]), "tage": tage, "rest": tage, "schwere": 1,
		"region": str(e["region"]), "im_spiel": true, "seit_tag": int(d["tag"]),
		"leicht": true,
	}
	sp["fitness"] = clampf(float(sp["fitness"]) - 4.0, 20.0, 100.0)
	return sp["verletzung"]

static func verletzung_im_spiel(d: Dictionary, sid: String) -> Dictionary:
	return erzeuge_verletzung(d, sid, true)

## Wahrscheinlichkeit, dass sich ein Spieler gerade verletzt (pro Angriff auf dem Feld).
static func risiko(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = d["spieler"][sid]
	var basis: float = risiko_roh(sp)
	var verein: String = str(sp["verein"])
	if verein != "" and d["vereine"].has(verein):
		basis *= praeventionsfaktor(d, verein)
	return basis

## Nur der Spieleranteil des Risikos, ohne den Verein. Getrennt, damit die
## Spielsimulation ihn einmal je Partie vorrechnen kann statt bei jedem
## Angriff für jeden Spieler auf der Platte erneut.
static func risiko_roh(sp: Dictionary) -> float:
	var neigung: float = float(sp["verletzungsneigung"]) / 20.0
	var last: float = float(sp["last"]) / 100.0
	var fit: float = float(sp["fitness"]) / 100.0
	var alter_mod: float = 1.0 + maxf(float(sp["alter"]) - 29.0, 0.0) * 0.05
	# Gemessen mit werkzeuge/Verletzungssonde.gd: mit dem alten Grundwert fiel
	# ein Spieler 15 Tage je Spielzeit aus und nur gut ein Viertel der Kader
	# verletzte sich ueberhaupt einmal. Der VBG-Sportreport nennt 34 Ausfalltage
	# und fast drei Viertel aller Profis.
	# Ein schmalerer Spann bei der Neigung waere denkbar — anfaellige und
	# robuste Spieler liegen heute um das Dreifache auseinander, und es trifft
	# dadurch immer dieselben. Gemessen gebracht hat es 1,3 Punkte mehr
	# Betroffene (48,0 auf 49,3 Prozent) und fuenf Ausfalltage weniger (33,1
	# auf 28,3, Ziel 34). Das ist der schlechtere Tausch, also bleibt es, wie
	# es ist.
	return 0.00105 * (0.5 + neigung) * (0.7 + 1.5 * last) * (1.5 - 0.6 * fit) * alter_mod

## Wie stark die medizinische Abteilung eines Vereins das Risiko senkt.
static func praeventionsfaktor(d: Dictionary, cid: String) -> float:
	if cid == "" or not d["vereine"].has(cid):
		return 1.0
	return clampf(1.25 - _praeventionswert(d, cid) / 120.0, 0.55, 1.25)

static func _praeventionswert(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var wert: float = float(v["infrastruktur"]["medizin"]) * 5.0 + float(v["infrastruktur"]["regeneration"]) * 4.0
	for pid in v["personal"]:
		var mp: Dictionary = d["personal"].get(pid, {})
		if str(mp.get("rolle", "")) in ["physio", "athletiktrainer"]:
			wert += float((mp["attr"] as Dictionary).get("praevention", 8.0)) * 1.6
	return wert

## Taegliche Genesung und Lastabbau.
static func tageswechsel(d: Dictionary) -> void:
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		var verletzung: Dictionary = sp["verletzung"]
		if not verletzung.is_empty():
			var tempo: float = 1.0
			var verein: String = str(sp["verein"])
			if verein != "" and d["vereine"].has(verein):
				tempo = 1.0 + float(d["vereine"][verein]["infrastruktur"]["medizin"]) * 0.035
			verletzung["rest"] = float(verletzung["rest"]) - tempo
			if float(verletzung["rest"]) <= 0.0:
				sp["verletzung"] = {}
				sp["fitness"] = clampf(float(sp["fitness"]) + 8.0, 30.0, 92.0)
				sp["last"] = clampf(float(sp["last"]) - 20.0, 0.0, 100.0)
				if verein == Welt.mein_verein_id:
					Welt.nachricht({
						"typ": "medizin", "betreff": "%s ist wieder fit" % Spielerfabrik.voller_name(sp),
						"text": "Die medizinische Abteilung gibt %s nach überstandener Verletzung (%s) wieder frei." % [
							Spielerfabrik.kurz_name(sp), verletzung["art"]],
						"daten": {"spieler": sid},
					})
			continue
		# Lastabbau und Fitnessaufbau
		var regeneration: float = 1.6
		var verein2: String = str(sp["verein"])
		if verein2 != "" and d["vereine"].has(verein2):
			var v: Dictionary = d["vereine"][verein2]
			regeneration += float(v["infrastruktur"]["regeneration"]) * 0.28
			var zuteilung: Dictionary = v.get("training", {}).get("regeneration_zuteilung", {})
			if int(zuteilung.get(sid, 0)) > 0:
				regeneration += float(zuteilung[sid]) * 1.1
		sp["last"] = clampf(float(sp["last"]) - regeneration, 0.0, 100.0)
		sp["fitness"] = clampf(float(sp["fitness"]) + 1.4 - float(sp["last"]) * 0.012, 25.0, 100.0)
		if int(sp["sperre"]) > 0 and Kalender.wochentag(int(d["tag"])) == 0:
			sp["sperre"] = maxi(int(sp["sperre"]) - 1, 0)

## Nach einer Partie: Last aufbauen, Fitness senken, Nachwirkungen pruefen.
static func spiel_nachwirkung(d: Dictionary, m: Dictionary) -> void:
	var bericht: Dictionary = m.get("bericht", {})
	if bericht.is_empty():
		return
	for seite in ["heim", "gast"]:
		var tb: Dictionary = bericht.get(seite, {})
		for sid in tb.get("spieler", {}).keys():
			if not d["spieler"].has(sid):
				continue
			var sp: Dictionary = d["spieler"][sid]
			var minuten: float = float(tb["spieler"][sid]["sekunden"]) / 60.0
			if minuten <= 0.0:
				continue
			var ausdauer: float = float(sp["attr"]["ausdauer"]) / 20.0
			sp["last"] = clampf(float(sp["last"]) + minuten * (0.42 - 0.18 * ausdauer) + 2.0, 0.0, 100.0)
			sp["fitness"] = clampf(float(sp["fitness"]) - minuten * 0.16, 25.0, 100.0)
			# Erst das Schwere, dann das Kleine. Ein Spieler, der sich das
			# Kreuzband gerissen hat, zieht sich am selben Abend keine
			# Prellung mehr zu.
			if sp["verletzung"].is_empty() and Namen.zufall() < blessurrisiko(d, sid) * minuten:
				var bl := blessur(d, sid)
				if str(sp["verein"]) == Welt.mein_verein_id:
					Welt.nachricht({
						"typ": "medizin", "wichtig": false,
						"betreff": "Angeschlagen: %s" % Spielerfabrik.voller_name(sp),
						"text": "%s hat sich eine Blessur zugezogen (%s). Ausfall: etwa %d Tage." % [
							Spielerfabrik.kurz_name(sp), str(bl["art"]), int(bl["tage"])],
						"daten": {"spieler": sid},
					})
			# Nachwirkende Verletzungen
			if sp["verletzung"].is_empty() and Namen.zufall() < risiko(d, sid) * minuten * 0.22:
				var v := erzeuge_verletzung(d, sid, true)
				if str(sp["verein"]) == Welt.mein_verein_id:
					Welt.nachricht({
						"typ": "medizin", "wichtig": int(v["schwere"]) >= 2,
						"betreff": "Verletzung: %s" % Spielerfabrik.voller_name(sp),
						"text": "%s hat sich eine Verletzung zugezogen (%s). Ausfall: etwa %d Tage." % [
							Spielerfabrik.kurz_name(sp), v["art"], int(v["tage"])],
						"daten": {"spieler": sid},
					})

## Die Verletzungsgeschichte in einem Satz.
##
## Sie ist keine Randnotiz: wer sich zweimal dieselbe Schulter ausgerenkt hat,
## renkt sie wieder aus. Der Manager soll das sehen koennen, bevor er einen
## Spieler verpflichtet oder mit hohem Lastkonto aufstellt.
static func vorgeschichtstext(sp: Dictionary) -> String:
	var vor: Dictionary = sp.get("vorgeschichte", {})
	if vor.is_empty():
		return ""
	var teile: Array = []
	var sortiert: Array = vor.keys()
	sortiert.sort_custom(func(a, b): return int(vor[a]) > int(vor[b]))
	for r in sortiert:
		if not REGIONEN.has(r):
			continue
		var anzahl: int = int(vor[r])
		var wort: String = "einmal" if anzahl == 1 else ("zweimal" if anzahl == 2 else "%dmal" % anzahl)
		teile.append("%s %s" % [wort, str((REGIONEN[r] as Dictionary)["name"])])
	if teile.is_empty():
		return ""
	return ", ".join(teile)

## Wie stark eine Region durch die Vorgeschichte belastet ist — fuer die
## Anzeige. Null heisst: unauffaellig.
static func wiederholungsrisiko(sp: Dictionary) -> float:
	var vor: Dictionary = sp.get("vorgeschichte", {})
	var hoechster: float = 1.0
	for r in vor.keys():
		if not REGIONEN.has(r):
			continue
		var w: float = 1.0 + (float((REGIONEN[r] as Dictionary)["wiederholung"]) - 1.0) \
			* mini(int(vor[r]), VORGESCHICHTE_MAX)
		hoechster = maxf(hoechster, w)
	return hoechster

static func verletzungstext(sp: Dictionary) -> String:
	var v: Dictionary = sp["verletzung"]
	if v.is_empty():
		return ""
	return "%s (noch %d Tage)" % [v["art"], int(ceil(float(v["rest"])))]

## Alle angeschlagenen Spieler eines Vereins.
static func lazarett(d: Dictionary, cid: String) -> Array:
	var liste: Array = []
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if not (sp["verletzung"] as Dictionary).is_empty():
			liste.append(sid)
	liste.sort_custom(func(a, b): return float(d["spieler"][a]["verletzung"]["rest"]) > float(d["spieler"][b]["verletzung"]["rest"]))
	return liste
