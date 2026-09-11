class_name Vorstand
extends RefCounted
## Der Vorstand: Saisonziel, Vertrauen, Geduld — und die Konsequenzen.

const ZIELE := [
	{"schluessel": "titel", "text": "Meistertitel", "min": 1, "max": 1},
	{"schluessel": "meisterschaftskampf", "text": "Kampf um die Meisterschaft", "min": 1, "max": 2},
	{"schluessel": "europa", "text": "internationaler Startplatz", "min": 1, "max": 4},
	{"schluessel": "oberes_drittel", "text": "oberes Tabellendrittel", "min": 1, "max": 5},
	{"schluessel": "mittelfeld", "text": "gesicherter Mittelfeldplatz", "min": 1, "max": 9},
	{"schluessel": "klassenerhalt", "text": "Klassenerhalt", "min": 1, "max": 12},
	{"schluessel": "aufstieg", "text": "Aufstieg", "min": 1, "max": 2},
]

static func saisonziel_festlegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var liga: Dictionary = d["ligen"][v["liga"]]
	var rangliste: Array = (liga["vereine"] as Array).duplicate()
	rangliste.sort_custom(func(a, b): return float(d["vereine"][a]["ruf"]) > float(d["vereine"][b]["ruf"]))
	var platz: int = rangliste.find(cid) + 1
	var teams: int = rangliste.size()
	var ehrgeiz: float = float(v["vorstand"]["geduld"]) * 0.0 + Namen.bereich(-1.0, 1.0)
	var ziel := "mittelfeld"
	var ziel_platz: int = platz
	if int(liga["stufe"]) >= 2:
		if platz <= 3:
			ziel = "aufstieg"
			ziel_platz = 2
		elif platz <= teams / 2:
			ziel = "oberes_drittel"
			ziel_platz = maxi(int(teams / 3), 3)
		else:
			ziel = "mittelfeld"
			ziel_platz = maxi(int(teams * 0.6), 5)
	else:
		if platz == 1:
			ziel = "titel"
			ziel_platz = 1
		elif platz <= 3:
			ziel = "meisterschaftskampf"
			ziel_platz = 2
		elif platz <= 6:
			ziel = "europa"
			ziel_platz = 5
		elif platz <= teams * 0.62:
			ziel = "oberes_drittel"
			ziel_platz = maxi(int(teams * 0.45), 4)
		elif platz <= teams * 0.85:
			ziel = "mittelfeld"
			ziel_platz = maxi(int(teams * 0.7), 6)
		else:
			ziel = "klassenerhalt"
			ziel_platz = teams - 2
	if ehrgeiz > 0.75 and ziel_platz > 2:
		ziel_platz -= 1
	v["vorstand"]["saisonziel"] = _zieltext(ziel)
	v["vorstand"]["ziel_schluessel"] = ziel
	v["vorstand"]["ziel_platz"] = ziel_platz
	v["fans"]["erwartung"] = float(ziel_platz)

static func _zieltext(schluessel: String) -> String:
	for z in ZIELE:
		if str(z["schluessel"]) == schluessel:
			return str(z["text"])
	return "gesicherter Mittelfeldplatz"

## Reaktion nach einem Spiel des Spielervereins.
static func nach_spiel(d: Dictionary, cid: String, m: Dictionary) -> void:
	if str(m["art"]) == "test":
		return
	var v: Dictionary = d["vereine"][cid]
	var eigene: int = int(m["tore_heim"]) if str(m["heim"]) == cid else int(m["tore_gast"])
	var fremde: int = int(m["tore_gast"]) if str(m["heim"]) == cid else int(m["tore_heim"])
	var gegner: String = str(m["gast"]) if str(m["heim"]) == cid else str(m["heim"])
	# Erwartet wird an dem gemessen, was der Kader tatsaechlich hergibt — nicht
	# nur am Ruf, der sich langsamer bewegt als die Mannschaft.
	var eigen: float = _staerkeindex(d, cid)
	var fremd: float = _staerkeindex(d, gegner)
	var erwartung: float = clampf(0.5 + (eigen - fremd) / 90.0, 0.12, 0.88)
	var ergebnis: float = 1.0 if eigene > fremde else (0.5 if eigene == fremde else 0.0)
	var delta: float = (ergebnis - erwartung) * 2.8
	if str(m["art"]) == "pokal" and ergebnis == 0.0:
		delta -= 2.2
	v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) + delta, 0.0, 100.0)
	# Fans reagieren staerker auf Emotion als auf Tabellenplatz
	var fan_delta: float = delta * 1.35
	var rivale: float = float((v["rivalen"] as Dictionary).get(gegner, 0.0))
	if rivale > 45.0:
		fan_delta *= 1.9
	v["fans"]["zufriedenheit"] = clampf(float(v["fans"]["zufriedenheit"]) + fan_delta, 0.0, 100.0)
	v["fans"]["treue"] = clampf(float(v["fans"]["treue"]) + delta * 0.25, 0.0, 100.0)
	Trainerkarriere.spiel_verbuchen(d, m, cid)

## Woechentliche Bewertung: Tabellenstand gegen Saisonziel.
static func wochenpruefung(d: Dictionary, cid: String) -> void:
	if cid == "" or not d["vereine"].has(cid):
		return
	var v: Dictionary = d["vereine"][cid]
	var liga: Dictionary = d["ligen"][v["liga"]]
	var tabelle := Spielplan.tabelle_sortiert(d, str(liga["id"]))
	var platz: int = tabelle.find(cid) + 1
	if platz <= 0:
		return
	var ziel_platz: int = int(v["vorstand"]["ziel_platz"])
	var abweichung: float = float(ziel_platz - platz)
	var gespielt: int = int(liga["tabelle"].get(cid, {}).get("sp", 0))
	if gespielt < 3:
		return
	var gewicht: float = clampf(float(gespielt) / float(maxi(int(liga["spieltage"]), 1)), 0.1, 1.0)
	v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) + abweichung * 0.22 * gewicht, 0.0, 100.0)
	v["fans"]["zufriedenheit"] = clampf(float(v["fans"]["zufriedenheit"]) + abweichung * 0.3 * gewicht, 0.0, 100.0)
	if Trainerkarriere.hat_praegung(d, "eiserne_hand"):
		v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) + 0.15, 0.0, 100.0)
	_konsequenzen(d, cid, platz, gewicht)

## Mischung aus Ruf und tatsaechlicher Kaderstaerke.
static func _staerkeindex(d: Dictionary, cid: String) -> float:
	var kader: Array = d["vereine"][cid]["kader"]
	if kader.is_empty():
		return float(d["vereine"][cid]["ruf"])
	var werte: Array = []
	for sid in kader:
		werte.append(Spielerfabrik.gesamt(d["spieler"][sid]))
	werte.sort()
	werte.reverse()
	var summe := 0.0
	var n: int = mini(10, werte.size())
	for i in range(n):
		summe += float(werte[i])
	return float(d["vereine"][cid]["ruf"]) * 0.45 + (summe / float(n)) * 0.55

static func _konsequenzen(d: Dictionary, cid: String, platz: int, gewicht: float) -> void:
	var v: Dictionary = d["vereine"][cid]
	var vertrauen: float = float(v["vorstand"]["vertrauen"])
	var warnstufe: int = int(v["vorstand"].get("warnstufe", 0))
	if vertrauen < 26.0 and warnstufe < 1:
		v["vorstand"]["warnstufe"] = 1
		Welt.nachricht({
			"typ": "vorstand", "wichtig": true,
			"betreff": "Der Vorstand ist unzufrieden",
			"text": "Platz %d entspricht nicht dem Saisonziel (%s). Der Vorstand erwartet in den nächsten Wochen eine deutliche Reaktion." % [platz, v["vorstand"]["saisonziel"]],
		})
	elif vertrauen < 14.0 and warnstufe < 2:
		v["vorstand"]["warnstufe"] = 2
		Welt.nachricht({
			"typ": "vorstand", "wichtig": true,
			"betreff": "Letzte Warnung",
			"text": "Der Vorstand hat eine Krisensitzung einberufen. Ohne Ergebnisse in den nächsten Partien wird über Ihre Zukunft entschieden.",
		})
	elif vertrauen > 45.0 and warnstufe > 0:
		v["vorstand"]["warnstufe"] = 0
		Welt.nachricht({
			"typ": "vorstand",
			"betreff": "Rückendeckung",
			"text": "Der Vorstand stellt sich öffentlich hinter Sie. Die Krise gilt als überwunden.",
		})
	# Entlassen wird nur, wer nach ausdruecklicher Warnung nicht reagiert.
	if vertrauen < 8.0 and gewicht > 0.3 and warnstufe >= 2:
		entlassung(d, cid)

static func entlassung(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var t: Dictionary = d["trainer"]
	var abfindung: float = float(t["vertrag"]["gehalt"]) * 12.0 * float(t["vertrag"].get("abfindung_faktor", 0.5))
	Welt.nachricht({
		"typ": "vorstand", "wichtig": true, "aktion": "entlassen",
		"betreff": "Sie sind freigestellt",
		"text": "Der Vorstand von %s hat sich von Ihnen getrennt. Abfindung: %s. Sie sind ab sofort vereinslos — Angebote anderer Klubs erreichen Sie über den Karrierebildschirm." % [v["name"], Stil.geld(abfindung)],
	})
	Trainerkarriere.verein_wechseln(d, "")
	t["ruf"] = clampf(float(t["ruf"]) - 7.0, 1.0, 100.0)
	t["vereinslos_seit"] = int(d["tag"])
	Welt.mein_verein_id = ""

## Einschaetzung fuer den Vorstandsbildschirm.
static func lagebericht(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var liga: Dictionary = d["ligen"][v["liga"]]
	var tabelle := Spielplan.tabelle_sortiert(d, str(liga["id"]))
	var platz: int = tabelle.find(cid) + 1
	var vertrauen: float = float(v["vorstand"]["vertrauen"])
	var stimmung := "hervorragend"
	if vertrauen < 20.0:
		stimmung = "alarmierend"
	elif vertrauen < 35.0:
		stimmung = "angespannt"
	elif vertrauen < 55.0:
		stimmung = "abwartend"
	elif vertrauen < 75.0:
		stimmung = "zufrieden"
	return {
		"platz": platz,
		"ziel_platz": int(v["vorstand"]["ziel_platz"]),
		"saisonziel": str(v["vorstand"]["saisonziel"]),
		"vertrauen": vertrauen,
		"stimmung": stimmung,
		"fans": float(v["fans"]["zufriedenheit"]),
		"finanzstrenge": float(v["vorstand"]["finanzstrenge"]),
		"jugendfokus": float(v["vorstand"]["jugendfokus"]),
		"warnstufe": int(v["vorstand"].get("warnstufe", 0)),
	}

## Prueft zum Saisonwechsel den Trainervertrag: verlaengern, auslaufen lassen
## oder — bei schlechter Arbeit — nicht mehr weiterbeschaeftigen.
static func vertragsangebot_pruefen(d: Dictionary, cid: String) -> void:
	var t: Dictionary = d["trainer"]
	if t.is_empty() or str(t["verein"]) != cid:
		return
	var rest: int = int(t["vertrag"]["bis_saison"]) - Welt.saison_index()
	var v: Dictionary = d["vereine"][cid]
	var vertrauen: float = float(v["vorstand"]["vertrauen"])
	if rest < 0:
		# Vertrag ist ausgelaufen — der Vorstand entscheidet.
		if vertrauen >= 42.0:
			_angebot_speichern(d, cid, 2)
			Welt.nachricht({
				"typ": "vorstand", "wichtig": true,
				"betreff": "Ihr Vertrag ist ausgelaufen",
				"text": "%s bietet Ihnen eine Verlängerung an. Sie finden das Angebot auf dem Karrierebildschirm." % v["name"],
			})
		else:
			Welt.nachricht({
				"typ": "vorstand", "wichtig": true,
				"betreff": "Vertrag wird nicht verlängert",
				"text": "%s verzichtet auf eine Weiterbeschäftigung. Sie sind ab sofort vereinslos." % v["name"],
			})
			Trainerkarriere.verein_wechseln(d, "")
			Welt.mein_verein_id = ""
		return
	if rest > 1 or vertrauen < 55.0:
		return
	_angebot_speichern(d, cid, 2)
	Welt.nachricht({
		"typ": "vorstand", "wichtig": true,
		"betreff": "Vertragsverlängerung angeboten",
		"text": "%s möchte mit Ihnen verlängern: zwei weitere Jahre, %s pro Woche. Das Angebot liegt auf dem Karrierebildschirm." % [
			v["name"], Stil.geld(float(t["vertrag"]["gehalt"]) * 1.2)],
	})

static func _angebot_speichern(d: Dictionary, cid: String, jahre: int) -> void:
	var t: Dictionary = d["trainer"]
	var ruf_bonus: float = 1.0 + clampf((float(t["ruf"]) - 40.0) / 160.0, -0.1, 0.4)
	t["eigenes_angebot"] = {
		"verein": cid,
		"gehalt": float(t["vertrag"]["gehalt"]) * 1.2 * ruf_bonus,
		"jahre": jahre,
		"tag": int(d["tag"]),
	}

## Nimmt das Angebot des eigenen Vereins an.
static func vertrag_verlaengern(d: Dictionary) -> Dictionary:
	var t: Dictionary = d["trainer"]
	var angebot: Dictionary = t.get("eigenes_angebot", {})
	if angebot.is_empty():
		return {"ok": false, "grund": "Es liegt kein Angebot vor."}
	var cid: String = str(angebot["verein"])
	if str(t["verein"]) == "":
		Trainerkarriere.verein_wechseln(d, cid)
	t["vertrag"]["bis_saison"] = Welt.saison_index() + int(angebot["jahre"])
	t["vertrag"]["gehalt"] = float(angebot["gehalt"])
	t["eigenes_angebot"] = {}
	d["vereine"][cid]["vorstand"]["vertrauen"] = clampf(float(d["vereine"][cid]["vorstand"]["vertrauen"]) + 4.0, 0.0, 100.0)
	return {"ok": true, "grund": "Vertrag bis Saison %s unterschrieben." % Kalender.saison_text(int(d["startjahr"]), int(t["vertrag"]["bis_saison"]))}

static func angebot_ablehnen(d: Dictionary) -> void:
	d["trainer"]["eigenes_angebot"] = {}
