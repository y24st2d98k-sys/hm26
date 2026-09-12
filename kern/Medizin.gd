class_name Medizin
extends RefCounted
## Verletzungen, Genesung und Belastungssteuerung.
##
## Kernidee von Hallenherz: das "Lastkonto". Jede Minute auf dem Feld und jede harte
## Trainingswoche laedt es auf, Regeneration baut es ab. Ein hohes Lastkonto senkt Form
## und Frische und erhoeht das Verletzungsrisiko spuerbar — Rotation ist dadurch keine
## Fleissaufgabe, sondern eine echte Entscheidung.

const LEICHT := ["Prellung", "Zerrung", "Bänderdehnung", "Kapselreizung", "Handverletzung", "Wadenprobleme"]
const MITTEL := ["Muskelfaserriss", "Bänderanriss", "Schulterverletzung", "Sprunggelenkverletzung",
	"Rippenbruch", "Sehnenreizung", "Gehirnerschütterung"]
const SCHWER := ["Kreuzbandriss", "Schulterluxation", "Achillessehnenriss", "Bandscheibenvorfall",
	"Mittelfußbruch", "Syndesmosebandriss"]

static func erzeuge_verletzung(d: Dictionary, sid: String, im_spiel: bool) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var w: float = Namen.zufall()
	var art := ""
	var tage := 0
	var schwere := 1
	if w < 0.62:
		art = str(Namen.waehle(LEICHT))
		tage = Namen.wuerfel(3, 16)
		schwere = 1
	elif w < 0.92:
		art = str(Namen.waehle(MITTEL))
		tage = Namen.wuerfel(17, 55)
		schwere = 2
	else:
		art = str(Namen.waehle(SCHWER))
		tage = Namen.wuerfel(70, 230)
		schwere = 3
	var verein: String = str(sp["verein"])
	if verein != "" and d["vereine"].has(verein):
		var medizin: int = int(d["vereine"][verein]["infrastruktur"]["medizin"])
		tage = int(float(tage) * clampf(1.18 - float(medizin) * 0.026, 0.7, 1.2))
	sp["verletzung"] = {
		"art": art, "tage": tage, "rest": tage, "schwere": schwere,
		"im_spiel": im_spiel, "seit_tag": int(d["tag"]),
	}
	sp["fitness"] = clampf(float(sp["fitness"]) - float(schwere) * 12.0, 20.0, 100.0)
	sp["moral"] = clampf(float(sp["moral"]) - float(schwere) * 5.0, 5.0, 100.0)
	Laufbahn.schwere_verletzung(d, sid, art, tage)
	return sp["verletzung"]

## Wird von der Simulation aufgerufen, wenn sich jemand im Spiel verletzt.
static func verletzung_im_spiel(d: Dictionary, sid: String) -> Dictionary:
	return erzeuge_verletzung(d, sid, true)

## Wahrscheinlichkeit, dass sich ein Spieler gerade verletzt (pro Angriff auf dem Feld).
static func risiko(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = d["spieler"][sid]
	var neigung: float = float(sp["verletzungsneigung"]) / 20.0
	var last: float = float(sp["last"]) / 100.0
	var fit: float = float(sp["fitness"]) / 100.0
	var alter_mod: float = 1.0 + maxf(float(sp["alter"]) - 29.0, 0.0) * 0.05
	var basis: float = 0.00042 * (0.5 + neigung) * (0.7 + 1.5 * last) * (1.5 - 0.6 * fit) * alter_mod
	var verein: String = str(sp["verein"])
	if verein != "" and d["vereine"].has(verein):
		var praevention: float = _praeventionswert(d, verein)
		basis *= clampf(1.25 - praevention / 120.0, 0.55, 1.25)
	return basis

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
			# Nachwirkende Blessuren
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
