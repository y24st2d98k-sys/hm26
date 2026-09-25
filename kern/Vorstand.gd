class_name Vorstand
extends RefCounted
## Der Vorstand: Saisonziel, Vertrauen, Geduld — und die Konsequenzen.

## Vertrauen, mit dem ein neu verpflichteter Trainer startet.
const NEUSTART_VERTRAUEN := 58.0

## Ab welchem Anteil der Spielzeit für eigene Akademiespieler der Vorstand
## ausdrücklich lobt. Ein Bundesligist, der ein Fünftel seiner Minuten an
## Eigengewächse gibt, arbeitet nach den Maßstäben der Liga gut.
const EIGENGEWAECHS_ANTEIL := 0.22
## Was dieses Lob an Vertrauen wert ist, bevor die Haltung des Vorstands zur
## Jugend es verstärkt oder dämpft.
const EIGENGEWAECHS_VERTRAUEN := 3.0

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
	# Erwartet wird an derselben Groesse gemessen, an der auch jedes einzelne
	# Spiel bewertet wird. Sonst bekommt ein Verein mit gutem Ruf und duennem
	# Kader ein Ziel, das seine Mannschaft nicht einloesen kann — und der
	# Trainer verliert das Vertrauen fuer etwas, das er gar nicht steuert.
	# Einmal je Verein rechnen, dann sortieren: staerkeindex geht über den
	# ganzen Kader, und ein Vergleich in sort_custom liefe n·log n mal.
	rangliste = Spielerfabrik.nach_kennzahl(rangliste, func(cid_r): return staerkeindex(d, str(cid_r)))
	var platz: int = rangliste.find(cid) + 1
	var teams: int = rangliste.size()
	var ehrgeiz: float = Namen.bereich(-1.0, 1.0)
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
	if str(m["art"]) == "test" or str(m["art"]) == "turnier":
		return
	var v: Dictionary = d["vereine"][cid]
	var eigene: int = int(m["tore_heim"]) if str(m["heim"]) == cid else int(m["tore_gast"])
	var fremde: int = int(m["tore_gast"]) if str(m["heim"]) == cid else int(m["tore_heim"])
	var gegner: String = str(m["gast"]) if str(m["heim"]) == cid else str(m["heim"])
	# Erwartet wird an dem gemessen, was der Kader tatsaechlich hergibt — nicht
	# nur am Ruf, der sich langsamer bewegt als die Mannschaft.
	var eigen: float = staerkeindex(d, cid)
	var fremd: float = staerkeindex(d, gegner)
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
	# Das Vertrauen zieht langsam zur Mitte: eine Krise ist aufholbar, aber
	# auch Rueckenwind haelt nicht ewig ohne neue Ergebnisse.
	var neuer_wert: float = float(v["vorstand"]["vertrauen"]) + abweichung * 0.22 * gewicht
	v["vorstand"]["vertrauen"] = clampf(lerpf(neuer_wert, 45.0, 0.02), 0.0, 100.0)
	v["fans"]["zufriedenheit"] = clampf(float(v["fans"]["zufriedenheit"]) + abweichung * 0.3 * gewicht, 0.0, 100.0)
	if Trainerkarriere.hat_praegung(d, "eiserne_hand"):
		v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) + 0.15, 0.0, 100.0)
	_jugendlob_pruefen(d, cid)
	_konsequenzen(d, cid, platz, gewicht)

## Welcher Anteil der gespielten Minuten auf Spieler aus der eigenen Akademie
## entfaellt.
static func eigengewaechsanteil(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"].get(cid, {})
	if v.is_empty():
		return 0.0
	var gesamt := 0.0
	var eigen := 0.0
	for sid in (v.get("kader", []) as Array):
		var sp: Dictionary = d["spieler"].get(str(sid), {})
		if sp.is_empty():
			continue
		var minuten: float = float(((sp["stats"] as Dictionary)["saison"] as Dictionary).get("minuten", 0.0))
		gesamt += minuten
		if str(sp.get("ausbildungsverein", "")) == cid:
			eigen += minuten
	if gesamt <= 0.0:
		return 0.0
	return eigen / gesamt

## Der Vorstand lobt ausdrücklich, wer auf die eigene Jugend setzt.
##
## Bis hierher war Nachwuchsarbeit ein reines Kostenthema: die Akademie zahlte
## man, und wer aufstieg, brachte einmalig ein bisschen Vertrauen. Ob er dann
## spielte, war dem Präsidium gleich. Damit war die teure Entscheidung, einen
## Achtzehnjährigen den Sommer über aufzubauen statt einen fertigen Mann zu
## kaufen, sportlich riskant und sonst folgenlos.
static func _jugendlob_pruefen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var saison: Dictionary = v.get("saison", {})
	if saison.is_empty() or bool(saison.get("jugendlob", false)):
		return
	if eigengewaechsanteil(d, cid) < EIGENGEWAECHS_ANTEIL:
		return
	saison["jugendlob"] = true
	var jugendfokus: float = float(v["vorstand"].get("jugendfokus", 50.0)) / 100.0
	v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"])
		+ EIGENGEWAECHS_VERTRAUEN * (0.4 + jugendfokus), 0.0, 100.0)
	if cid == Welt.mein_verein_id:
		Welt.nachricht({
			"typ": "vorstand",
			"betreff": "Der Vorstand lobt die Nachwuchsarbeit",
			"text": "%s Ein Blick auf die Einsatzzeiten zeigt: %d Prozent der Spielzeit gehen an Spieler aus der eigenen Akademie." % [
				Namen.waehle(Textbank.VORSTAND_LOB_JUGEND),
				int(roundf(eigengewaechsanteil(d, cid) * 100.0))],
		})

## Mischung aus Ruf und tatsaechlicher Kaderstaerke. Dieselbe Groesse misst
## das Saisonziel, jedes einzelne Spiel und die Lage vor einer Partie.
static func staerkeindex(d: Dictionary, cid: String) -> float:
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
			"text": "Platz %d entspricht nicht dem Saisonziel (%s). %s" % [platz,
				v["vorstand"]["saisonziel"], Namen.waehle(Textbank.VORSTAND_MAHNUNG)],
		})
	elif vertrauen < 14.0 and warnstufe < 2:
		v["vorstand"]["warnstufe"] = 2
		Welt.nachricht({
			"typ": "vorstand", "wichtig": true,
			"betreff": "Letzte Warnung",
			"text": "%s Ohne Ergebnisse in den nächsten Partien wird über Ihre Zukunft entschieden." % Namen.waehle(Textbank.VORSTAND_WARNUNG),
		})
	elif vertrauen > 45.0 and warnstufe > 0:
		v["vorstand"]["warnstufe"] = 0
		Welt.nachricht({
			"typ": "vorstand",
			"betreff": "Rückendeckung",
			"text": "%s Die Krise gilt als überwunden." % Namen.waehle(Textbank.VORSTAND_ZUFRIEDEN),
		})
	# Entlassen wird nur, wer nach ausdruecklicher Warnung nicht reagiert.
	if vertrauen < 8.0 and gewicht > 0.3 and warnstufe >= 2:
		entlassung(d, cid)

## Ein neuer Trainer bekommt Zeit. Der Vorstand setzt das Vertrauen zurueck
## und formuliert das Ziel neu — wer eine Mannschaft auf einem Abstiegsplatz
## uebernimmt, wird nicht an der Meisterschaft gemessen.
static func amtsantritt(d: Dictionary, cid: String) -> void:
	if cid == "" or not d["vereine"].has(cid):
		return
	var v: Dictionary = d["vereine"][cid]
	var vs: Dictionary = v["vorstand"]
	vs["vertrauen"] = maxf(float(vs.get("vertrauen", 50.0)), NEUSTART_VERTRAUEN)
	vs["warnstufe"] = 0
	saisonziel_festlegen(d, cid)
	# Mitten in der Saison zaehlt die Lage, die er vorfindet: das Ziel darf
	# hoechstens ein paar Plaetze ueber dem aktuellen Stand liegen.
	var liga: Dictionary = d["ligen"][v["liga"]]
	var gespielt: int = int((liga["tabelle"] as Dictionary).get(cid, {}).get("sp", 0))
	if gespielt >= 4:
		var tabelle := Spielplan.tabelle_sortiert(d, str(liga["id"]))
		var platz: int = tabelle.find(cid) + 1
		if platz > 0:
			var anteil: float = clampf(float(gespielt) / float(maxi(int(liga["spieltage"]), 1)), 0.0, 1.0)
			# Je weiter die Saison, desto weniger laesst sich noch gutmachen.
			var spielraum: int = int(round(lerpf(6.0, 2.0, anteil)))
			var rettungsziel: int = maxi(platz - spielraum, 1)
			vs["ziel_platz"] = maxi(int(vs["ziel_platz"]), rettungsziel)
			v["fans"]["erwartung"] = float(vs["ziel_platz"])

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
	Talentsuche.aufraeumen(d)

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
			Talentsuche.aufraeumen(d)
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
