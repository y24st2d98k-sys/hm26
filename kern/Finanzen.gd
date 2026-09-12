class_name Finanzen
extends RefCounted
## Einnahmen, Ausgaben, Budgets und Ausbauprojekte.
##
## Einnahmen: Zuschauer, Sponsoren, Fernsehgeld, Preisgelder, Transfererloese, Merchandising.
## Ausgaben: Gehaelter (Spieler + Personal), Hallenbetrieb, Jugend, Reisen, Ablösen.

const AUSBAU_STUFEN := {
	"halle": {"name": "Hallenausbau", "beschreibung": "Mehr Plätze, mehr Eintrittsgeld und mehr Hallenpuls."},
	"trainingszentrum": {"name": "Trainingszentrum", "beschreibung": "Schnellere Entwicklung aller Spieler."},
	"jugendarbeit": {"name": "Jugendarbeit", "beschreibung": "Bessere Talente im jährlichen Nachwuchsjahrgang."},
	"medizin": {"name": "Medizinische Abteilung", "beschreibung": "Kürzere Ausfallzeiten, weniger Rückfälle."},
	"analyse": {"name": "Analysezentrum", "beschreibung": "Genauere Gegnerdaten und bessere Scouting-Berichte."},
	"regeneration": {"name": "Regenerationsbereich", "beschreibung": "Das Lastkonto sinkt schneller."},
}

static func buchen(d: Dictionary, cid: String, betrag: float, grund: String, kategorie: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	v["kasse"] = float(v["kasse"]) + betrag
	var buchungen: Array = v["finanz_log"]
	buchungen.push_front({"tag": int(d["tag"]), "betrag": betrag, "grund": grund, "kategorie": kategorie})
	if buchungen.size() > 200:
		buchungen.resize(200)

## Eintrittsgelder und Preisgelder nach einer Partie.
static func spieltag_abrechnen(d: Dictionary, m: Dictionary) -> void:
	if str(m["art"]) == "turnier":
		return
	var heim: Dictionary = d["vereine"][m["heim"]]
	var zuschauer: int = int(m["zuschauer"])
	var preis: float = 10.0 + float(heim["halle"]["komfort"]) * 2.0 + float(heim["ruf"]) * 0.14
	var einnahme: float = float(zuschauer) * preis
	if str(m["art"]) == "international":
		einnahme *= 1.25
	elif str(m["art"]) == "test":
		einnahme *= 0.45
	buchen(d, str(m["heim"]), einnahme, "Eintritt %s" % Welt.wettbewerb_name(str(m["wettbewerb"])), "zuschauer")
	# Auswaertsteam: Reisekosten
	buchen(d, str(m["gast"]), -(1400.0 + float(d["vereine"][m["gast"]]["ruf"]) * 60.0), "Reisekosten", "reise")
	if str(m["art"]) == "international":
		var wb: Dictionary = d["international"][m["wettbewerb"]]
		var preisgeld: float = float(wb.get("preisgeld_runde", 100000.0)) * 0.25
		buchen(d, str(m["heim"]), preisgeld, "Antrittsprämie %s" % wb["name"], "preisgeld")
		buchen(d, str(m["gast"]), preisgeld, "Antrittsprämie %s" % wb["name"], "preisgeld")

## Woechentliche Abrechnung aller Vereine.
static func wochenabrechnung(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var gehaelter: float = spielergehaelter(d, cid) + personalgehaelter(d, cid)
		buchen(d, cid, -gehaelter, "Gehälter", "gehalt")
		var sponsoring := 0.0
		for s in v["sponsoren"]:
			sponsoring += float(s["wert"]) / 52.0
		buchen(d, cid, sponsoring, "Sponsoring", "sponsor")
		var tv: float = medienerloese(d, cid) 
		buchen(d, cid, tv, "Medienerlöse", "tv")
		var betrieb: float = betriebskosten(d, cid)
		buchen(d, cid, -betrieb, "Betriebskosten", "betrieb")
		var merch: float = float(v["fans"]["mitglieder"]) * 0.55 * (0.6 + float(v["fans"]["zufriedenheit"]) / 150.0)
		buchen(d, cid, merch, "Merchandising", "merch")
		_bauprojekt_fortschritt(d, cid)
		if float(v["kasse"]) < 0.0:
			_finanznot(d, cid)

## Medienerloese je Woche — abhaengig vom Ligaansehen und vom eigenen Ruf.
static func medienerloese(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var liga: Dictionary = d["ligen"][v["liga"]]
	return float(v["jahresetat"]) * 0.15 / 52.0 * (0.6 + float(liga["ruf"]) / 150.0)

## Laufende Kosten je Woche: Halle, Trainingsbetrieb, Jugend, Verwaltung.
static func betriebskosten(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	return float(v["halle"]["kapazitaet"]) * 1.6 \
		+ float(v["infrastruktur"]["trainingszentrum"]) * 900.0 \
		+ float(v["infrastruktur"]["jugendarbeit"]) * 700.0 \
		+ float(v["infrastruktur"]["medizin"]) * 520.0 \
		+ float(v["infrastruktur"]["analyse"]) * 420.0 \
		+ float(v["infrastruktur"]["regeneration"]) * 380.0

static func spielergehaelter(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	for sid in d["vereine"][cid]["kader"]:
		summe += float(d["spieler"][sid]["vertrag"].get("gehalt", 0.0))
	return summe

static func personalgehaelter(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	for pid in d["vereine"][cid]["personal"]:
		if d["personal"].has(pid):
			summe += float(d["personal"][pid]["gehalt"])
	return summe

static func _finanznot(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) - 0.8, 0.0, 100.0)
	if cid == Welt.mein_verein_id and int(d["tag"]) % 7 == 0:
		Welt.nachricht({
			"typ": "finanzen", "wichtig": true,
			"betreff": "Das Konto ist im Minus",
			"text": "Die Kasse weist %s aus. Der Vorstand erwartet, dass Sie die Gehaltslast senken oder Spieler verkaufen." % Stil.geld(float(v["kasse"])),
		})

## Legt zu Saisonbeginn Transfer- und Gehaltsbudget fest.
static func saison_budgets(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var liga: Dictionary = d["ligen"][v["liga"]]
		var etat: float = pow(maxf(float(v["ruf"]), 10.0), 2.62) * 52.0 * float(d["nationen"][v["nation"]]["reichtum"])
		etat *= 0.75 + float(liga["ruf"]) / 200.0
		v["jahresetat"] = etat
		var strenge: float = float(v["vorstand"]["finanzstrenge"]) / 100.0
		v["gehaltsbudget"] = etat * (0.66 - 0.1 * strenge) / 52.0
		v["transferbudget"] = maxf(etat * (0.16 - 0.06 * strenge) + maxf(float(v["kasse"]), 0.0) * 0.25, 0.0)

static func gehaltsauslastung(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var budget: float = maxf(float(v["gehaltsbudget"]), 1.0)
	return (spielergehaelter(d, cid) + personalgehaelter(d, cid)) / budget * 100.0

# ------------------------------------------------------------ Ausbauten ---

static func ausbaukosten(d: Dictionary, cid: String, bereich: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	if bereich == "halle":
		var kap: int = int(v["halle"]["kapazitaet"])
		return 480.0 * float(kap) * 0.22 + 260000.0
	var stufe: int = int(v["infrastruktur"].get(bereich, 1))
	return pow(float(stufe + 1), 2.1) * 130000.0

static func ausbau_starten(d: Dictionary, cid: String, bereich: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not (v["halle"]["bauprojekt"] as Dictionary).is_empty():
		return {"ok": false, "grund": "Es läuft bereits ein Bauprojekt."}
	var kosten: float = ausbaukosten(d, cid, bereich)
	if float(v["kasse"]) < kosten:
		return {"ok": false, "grund": "Die Kasse reicht nicht (%s nötig)." % Stil.geld(kosten)}
	if bereich != "halle" and int(v["infrastruktur"].get(bereich, 1)) >= 10:
		return {"ok": false, "grund": "Höchste Ausbaustufe bereits erreicht."}
	buchen(d, cid, -kosten, "Ausbau: %s" % AUSBAU_STUFEN[bereich]["name"], "ausbau")
	v["halle"]["bauprojekt"] = {
		"bereich": bereich,
		"fertig_tag": int(d["tag"]) + (120 if bereich == "halle" else 70),
		"kosten": kosten,
	}
	return {"ok": true, "grund": "Bauarbeiten beginnen."}

static func _bauprojekt_fortschritt(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var projekt: Dictionary = v["halle"]["bauprojekt"]
	if projekt.is_empty():
		return
	if int(d["tag"]) < int(projekt["fertig_tag"]):
		return
	var bereich: String = str(projekt["bereich"])
	if bereich == "halle":
		var alt: int = int(v["halle"]["kapazitaet"])
		v["halle"]["kapazitaet"] = int(float(alt) * 1.25 + 500.0)
		v["halle"]["ausbau"] = int(v["halle"]["ausbau"]) + 1
		v["halle"]["komfort"] = mini(int(v["halle"]["komfort"]) + 1, 10)
		v["hallenpuls_basis"] = clampf(float(v["hallenpuls_basis"]) + 2.0, 20.0, 95.0)
	else:
		v["infrastruktur"][bereich] = mini(int(v["infrastruktur"][bereich]) + 1, 10)
	v["halle"]["bauprojekt"] = {}
	if cid == Welt.mein_verein_id:
		Welt.nachricht({
			"typ": "verein", "betreff": "Bauprojekt abgeschlossen",
			"text": "%s ist fertiggestellt. %s" % [AUSBAU_STUFEN[bereich]["name"], AUSBAU_STUFEN[bereich]["beschreibung"]],
		})

## Zusammenfassung fuer den Finanzbildschirm: Wochenwerte je Kategorie.
static func wochenuebersicht(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var sponsoring := 0.0
	for s in v["sponsoren"]:
		sponsoring += float(s["wert"]) / 52.0
	var zuschauer_schnitt: float = 0.0
	if int(v["saison"]["heimspiele"]) > 0:
		zuschauer_schnitt = float(v["saison"]["zuschauer_summe"]) / float(v["saison"]["heimspiele"])
	return {
		"gehalt_spieler": spielergehaelter(d, cid),
		"gehalt_personal": personalgehaelter(d, cid),
		"sponsoring": sponsoring,
		"tv": medienerloese(d, cid),
		"betrieb": betriebskosten(d, cid),
		"merch": float(v["fans"]["mitglieder"]) * 0.55 * (0.6 + float(v["fans"]["zufriedenheit"]) / 150.0),
		"zuschauer_schnitt": zuschauer_schnitt,
	}
