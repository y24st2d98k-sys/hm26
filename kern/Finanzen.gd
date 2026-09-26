class_name Finanzen
extends RefCounted
## Einnahmen, Ausgaben, Budgets und Ausbauprojekte.
##
## Einnahmen: Zuschauer, Sponsoren, Fernsehgeld, Preisgelder, Transfererloese, Merchandising.
## Ausgaben: Gehaelter (Spieler + Personal), Hallenbetrieb, Jugend, Reisen, Ablösen.

## Jahresetat, an dem sich das volle Marktgehalt bemisst.
const LOHN_REFERENZ := 8000000.0

## Wie viele Buchungszeilen ein Verein mitfuehrt.
const LOG_EIGEN := 200
const LOG_FREMD := 12

const AUSBAU_STUFEN := {
	"halle": {"name": "Hallenausbau", "beschreibung": "Mehr Plätze, mehr Eintrittsgeld und mehr Hallenpuls."},
	"trainingszentrum": {"name": "Trainingszentrum", "beschreibung": "Schnellere Entwicklung aller Spieler."},
	"jugendarbeit": {"name": "Jugendarbeit", "beschreibung": "Bessere Talente im jährlichen Nachwuchsjahrgang."},
	"medizin": {"name": "Medizinische Abteilung", "beschreibung": "Kürzere Ausfallzeiten, weniger Rückfälle."},
	"analyse": {"name": "Analysezentrum", "beschreibung": "Genauere Gegnerdaten und bessere Scouting-Berichte."},
	"regeneration": {"name": "Regenerationsbereich", "beschreibung": "Das Lastkonto sinkt schneller."},
}

## Was ein Zuschauer am Spieltag an Betrieb kostet: Ordner, Sanitätsdienst,
## Kassen, Reinigung, Catering-Personal.
## Von 4,50 auf 7,00 gehoben. Gemessen mit werkzeuge/Wirtschaftssonde.gd lagen
## die Nicht-Personalkosten bei 38 Prozent des Ertrags, waehrend Personal 37
## ausmachte — zusammen 75, und der Rest war Gewinn. Ein Verein der Wirklichkeit
## kommt zusammen auf annaehernd hundert.
const SPIELTAGSKOSTEN_JE_GAST := 7.0
## Anteil des Jahresetats, der in Geschäftsstelle und Marketing geht.
## Von 0,20 auf 0,32 des Jahresetats gehoben, aus demselben Grund. Eine
## Geschaeftsstelle mit Marketing, Buchhaltung und Rechtsberatung ist in der
## Wirklichkeit ein Fuenftel bis ein Viertel des Umsatzes.
const VERWALTUNGSQUOTE := 0.32
## Anteil des Jahresetats für Lizenz und Verbandsabgaben.
const LIGAQUOTE := 0.04

## Wie stark der Etat dem folgt, was der Verein im Vorjahr eingenommen hat.
##
## Gemessen mit werkzeuge/Wirtschaftssonde.gd: der Etat kam allein aus dem Ruf,
## der Ertrag aber vor allem aus der Halle. Hamburg nahm 18,68 Mio. bei einem
## Etat von 6,32 ein, Lemgo 8,31 bei 6,47 — gleicher Etat, zweieinhalbfacher
## Ertrag. Weil alle grossen Kosten am Etat haengen, zahlte Lemgo Gehaelter,
## die es nie einnahm: neununddreissig Prozent der Liga standen im Minus.
## Ein Verein plant in Wirklichkeit mit dem, was er verdient.
## Von 0,65 auf 0,82 gehoben. Der Rest — der Anker am Ruf — traf genau die
## Vereine mit grossem Namen und kleiner Halle: MT Melsungen spielt vor
## viertausenddreihundert Zuschauern und plante mit dem Etat eines
## Spitzenklubs. In der Prüfung war es nach mehreren Spielzeiten der letzte
## Verein unter zwei Millionen Minus.
const ETAT_AUS_UMSATZ := 0.82
## Welcher Anteil des Umsatzes zum Etat wird. Der Rest ist Betrieb, Halle,
## Verwaltung und Abgaben.
##
## Von 0,52 auf 0,62 gehoben. Gemessen mit werkzeuge/Wirtschaftssonde.gd nahm
## ein Verein 15,42 Mio. ein und gab 13,32 aus — zwei Millionen Gewinn, und die
## Personalquote lag bei 37 Prozent statt bei den fuenfzig, die der Profisport
## kennt. Das Geld war da und wurde nicht ausgegeben, weil der Etat es nicht
## abholte.
const ETAT_VOM_UMSATZ := 0.62
## Wie schnell der gemerkte Umsatz einem neuen Jahr folgt. Ein glücklicher
## Pokallauf soll den Etat nicht um die Hälfte verschieben.
const UMSATZ_GLAETTUNG := 0.55

## Klartext fuer die Kategorien der Buchungsliste.
const KATEGORIE_NAME := {
	"zuschauer": "Zuschauer", "sponsor": "Sponsoring", "tv": "Medien", "merch": "Merchandising",
	"gehalt": "Gehälter", "betrieb": "Betrieb", "transfer": "Transfer", "reise": "Reise",
	"preisgeld": "Preisgeld", "praemie": "Erfolgsprämien", "ausbau": "Ausbau",
	"darlehen": "Darlehen", "spieltag": "Spieltag", "sonstiges": "Sonstiges",
	"verwaltung": "Verwaltung & Marketing", "liga": "Ligaabgaben",
}

static func kategorie_name(schluessel: String) -> String:
	return str(KATEGORIE_NAME.get(schluessel, schluessel.capitalize()))

static func buchen(d: Dictionary, cid: String, betrag: float, grund: String, kategorie: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	v["kasse"] = float(v["kasse"]) + betrag
	# Saisonsumme je Kategorie mitfuehren: die Einzelbuchungen unten sind
	# gedeckelt, die Jahresbilanz soll trotzdem vollstaendig sein.
	var saison: Dictionary = v.get("saison", {})
	if not saison.is_empty():
		var jahr: Dictionary = saison.get("finanzen", {})
		if jahr.is_empty():
			jahr = {}
			saison["finanzen"] = jahr
		jahr[kategorie] = float(jahr.get(kategorie, 0.0)) + betrag
	var buchungen: Array = v["finanz_log"]
	buchungen.push_front({"tag": int(d["tag"]), "betrag": betrag, "grund": grund, "kategorie": kategorie})
	# Zweihundert Zeilen fuer den eigenen Verein, zwoelf fuer alle anderen.
	#
	# Das Buchungsprotokoll steht genau an einer Stelle auf dem Bildschirm: im
	# Finanzbildschirm des eigenen Vereins. Trotzdem fuehrten alle
	# hundertsechsundfuenfzig Vereine der Welt zweihundert Zeilen mit, und
	# gemessen mit werkzeuge/Speichersonde.gd waren das fast zwanzig Kilobyte
	# je Verein und knapp drei Megabyte im Spielstand — elf Prozent von allem,
	# und niemand liest davon eine Zeile. Ein kurzer Rest bleibt, damit ein
	# Vereinswechsel des Trainers nicht vor einem leeren Konto steht.
	var deckel: int = LOG_EIGEN if str(cid) == Welt.mein_verein_id else LOG_FREMD
	if buchungen.size() > deckel:
		buchungen.resize(deckel)

## Eintrittsgelder und Preisgelder nach einer Partie.
static func spieltag_abrechnen(d: Dictionary, m: Dictionary) -> void:
	if str(m["art"]) == "turnier":
		return
	var cid_heim: String = str(m["heim"])
	var zuschauer: int = int(m["zuschauer"])
	# Tageskarten zu den selbst gesetzten Preisen. Dauerkarten sind vor der
	# Saison bezahlt worden und tauchen hier bewusst nicht mehr auf.
	var aufschluesselung: Dictionary = m.get("tickets", {})
	var einnahme := 0.0
	if aufschluesselung.is_empty():
		# Turnier- oder Altspielstandpartie ohne Aufschlüsselung.
		einnahme = float(zuschauer) * Ticketing.schnittpreis(d, cid_heim)
	else:
		einnahme = Ticketing.tageseinnahme(d, cid_heim, aufschluesselung)
	if str(m["art"]) == "international":
		einnahme *= 1.25
	elif str(m["art"]) == "test":
		einnahme *= 0.45
	# Dem Gastverein stehen fuenf Prozent der Tickets kostenlos zu, mindestens
	# hundert und hoechstens zweihundert Plaetze, dazu vier VIP-Karten. Das
	# Geld dafuer sieht der Heimverein nicht.
	if str(m["art"]) != "test":
		var kontingent: float = float(Lizenzierung.gaestekontingent(d, cid_heim))
		einnahme = maxf(einnahme - kontingent * Ticketing.schnittpreis(d, cid_heim), 0.0)
	buchen(d, cid_heim, einnahme, "Eintritt %s" % Welt.wettbewerb_name(str(m["wettbewerb"])), "zuschauer")
	# Ein Heimspiel kostet Geld, bevor der erste Ball fliegt.
	#
	# Ordner, Sanitätsdienst, Kassen, Reinigung, Hallenmiete für den Spieltag,
	# Catering-Personal: das skaliert mit der Zahl der Leute im Haus und stand
	# bisher nirgends. Gemessen mit werkzeuge/Wirtschaftssonde.gd nahm jeder
	# Verein im Schnitt 10,1 Millionen ein und gab 7,9 aus — zwei Komma zwei
	# Millionen Gewinn, jedes Jahr, für jeden Verein. Die Struktur der
	# Einnahmen stimmte, es fehlten schlicht die Kosten daneben.
	if str(m["art"]) != "test":
		# Ordner, Kassen und Catering kosten dort weniger, wo auch die Spieler
		# weniger verdienen — dasselbe Prinzip wie bei den Abteilungen in
		# betriebskosten. Sieben Euro je Gast sind der Satz einer
		# Bundesligaarena, nicht der einer Zweitligahalle.
		buchen(d, cid_heim, -float(zuschauer) * SPIELTAGSKOSTEN_JE_GAST
			* lohnniveau(d, cid_heim), "Spieltagsbetrieb", "spieltag")
	# Die Liga verlangt fuer jedes Pflichtspiel geschulte Scouts, die ueber
	# die Ligasoftware die Live-Statistik erfassen. Der Heimverein stellt sie.
	if str(m["art"]) != "test":
		buchen(d, cid_heim, -float(Lizenzierung.SCOUTS_JE_SPIEL) * 180.0,
			"Spieltagsscouts", "spieltag")
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
		# Haftmittel, Spezialreiniger, Reinigungsmaschine. Ein kleiner Posten
		# mit einer eigenen Geschichte — siehe kern/Lizenzierung.gd.
		var harz: float = Lizenzierung.harzkosten(d, str(cid))
		if harz > 0.0:
			buchen(d, cid, -harz, "Haftmittel und Hallenreinigung", "betrieb")
		var merch: float = float(v["fans"]["mitglieder"]) * 0.55 * (0.6 + float(v["fans"]["zufriedenheit"]) / 150.0)
		buchen(d, cid, merch, "Merchandising", "merch")
		# Geschäftsstelle, Marketing, Buchhaltung, Rechtsberatung — der Teil
		# eines Vereins, der nie auf der Platte steht und trotzdem bezahlt
		# werden muss. Er wächst mit der Größe des Hauses, nicht mit der
		# Zuschauerzahl eines einzelnen Abends.
		var etat: float = maxf(float(v.get("jahresetat", LOHN_REFERENZ)), 100000.0)
		# Eine Geschaeftsstelle ist Personal, und drei Leute in Ringsted kosten
		# nicht so viel wie dreissig in Kiel. Ohne diese Skalierung frassen
		# Gehaelter und Verwaltung zusammen sechsundachtzig Prozent des Umsatzes
		# eines kleinen Vereins, und fuer Halle, Spieltag und Reisen blieben
		# vierzehn — gemessen an der Prüfung rutschten dadurch neun bis zehn
		# Vereine der kleineren Ligen unter zwei Millionen Minus, waehrend die
		# Bundesliga sauber war.
		buchen(d, cid, -etat * VERWALTUNGSQUOTE * lohnniveau(d, cid) / 52.0,
			"Verwaltung und Marketing", "verwaltung")
		# Lizenzgebühr, Verbandsabgaben, Anteil an der Ligaproduktion.
		buchen(d, cid, -etat * LIGAQUOTE / 52.0, "Ligaabgaben", "liga")
		Darlehen.wochenwechsel(d, cid)
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
	# Der Betrieb der Abteilungen ist vor allem Personal — und das kostet dort
	# weniger, wo auch die Spieler weniger verdienen.
	var abteilungen: float = float(v["infrastruktur"]["trainingszentrum"]) * 900.0 \
		+ float(v["infrastruktur"]["jugendarbeit"]) * 700.0 \
		+ float(v["infrastruktur"]["medizin"]) * 520.0 \
		+ float(v["infrastruktur"]["analyse"]) * 420.0 \
		+ float(v["infrastruktur"]["regeneration"]) * 380.0
	# Auch der Hallenbetrieb ist ueberwiegend Personal: Hausmeister, Technik,
	# Reinigung. Bisher war nur der Abteilungsteil skaliert.
	return (float(v["halle"]["kapazitaet"]) * 1.6 + abteilungen) * lohnniveau(d, cid)

## Lohnniveau eines Vereins, gemessen an seiner wirtschaftlichen Grösse.
## Ein Spitzenverein der stärksten Liga zahlt das volle Marktgehalt, ein
## Zweitligist oder ein Verein in einem ärmeren Verband deutlich weniger.
static func lohnniveau(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"].get(cid, {})
	if v.is_empty():
		return 1.0
	var etat: float = maxf(float(v.get("jahresetat", LOHN_REFERENZ)), 50000.0)
	return clampf(pow(etat / LOHN_REFERENZ, 0.35), 0.30, 1.05)

## Was ein Spieler bei diesem Verein an Wochengehalt verlangt.
static func gehaltswunsch(d: Dictionary, cid: String, sp: Dictionary) -> float:
	var v: Dictionary = d["vereine"].get(cid, {})
	if v.is_empty():
		return Spielerfabrik.gehaltsvorstellung(sp, 50.0)
	return Spielerfabrik.gehaltsvorstellung(sp, float(v["ruf"]), lohnniveau(d, cid))

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
			"text": "Die Kasse weist %s aus. %s" % [Stil.geld(float(v["kasse"])),
				Namen.waehle(Textbank.VORSTAND_FINANZEN)],
		})

## Haelt fest, was jeder Verein in der abgelaufenen Spielzeit eingenommen hat.
##
## Muss vor Saison._statistiken_umlegen laufen — das leert v["saison"] und
## damit die Jahressummen, aus denen hier gerechnet wird.
static func umsatz_festhalten(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var f: Dictionary = (v.get("saison", {}) as Dictionary).get("finanzen", {})
		var ertrag := 0.0
		for k in f.keys():
			var b: float = float(f[k])
			if b > 0.0:
				ertrag += b
		if ertrag <= 0.0:
			continue
		var alt: float = float(v.get("umsatz_vorjahr", 0.0))
		if alt <= 0.0:
			v["umsatz_vorjahr"] = ertrag
		else:
			v["umsatz_vorjahr"] = alt * (1.0 - UMSATZ_GLAETTUNG) + ertrag * UMSATZ_GLAETTUNG

## Die wirtschaftliche Groesse eines Vereins aus Ruf, Liga und Land — ohne
## einen einzigen Blick auf seine Buchhaltung.
##
## Steht als eigene Funktion da, weil sie an zwei Stellen gebraucht wird: als
## Anker fuer den Jahresetat und als Marktgroesse fuer das Sponsoring. Dort
## darf der Etat selbst nicht vorkommen, sonst rechnet es im Kreis.
static func grundetat(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"].get(cid, {})
	if v.is_empty():
		return LOHN_REFERENZ
	# Ein echter Etat aus dem Datensatz verschiebt den Richtwert dauerhaft —
	# als Verhältnis, damit Auf- und Abstieg und Rufgewinn weiter wirken.
	return grundetat_formel(d, v) * float(v.get("etat_faktor", 1.0))

## Der Richtwert allein aus Ruf, Liga und Reichtum der Nation.
static func grundetat_formel(d: Dictionary, v: Dictionary) -> float:
	var liga: Dictionary = d["ligen"].get(str(v["liga"]), {})
	var reichtum: float = float((d["nationen"] as Dictionary).get(str(v["nation"]), {}).get("reichtum", 1.0))
	var wert: float = pow(maxf(float(v["ruf"]), 10.0), 2.62) * 52.0 * reichtum
	return wert * (0.75 + float(liga.get("ruf", 50.0)) / 200.0)

## Legt zu Saisonbeginn Transfer- und Gehaltsbudget fest.
static func saison_budgets(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		# Der Ruf sagt, was ein Verein sich zutraut; der Umsatz sagt, was er sich
		# leisten kann. Das erste Jahr kennt nur den Ruf, danach zaehlt beides.
		var grund: float = grundetat(d, str(cid))
		var etat: float = grund
		var umsatz: float = float(v.get("umsatz_vorjahr", 0.0))
		if umsatz > 0.0:
			etat = grund * (1.0 - ETAT_AUS_UMSATZ) + umsatz * ETAT_VOM_UMSATZ * ETAT_AUS_UMSATZ
			# Kein Verein wird ueber Nacht zum Spitzenklub und keiner
			# verschwindet in der Bedeutungslosigkeit, weil eine Saison
			# schlecht lief.
			# Der Deckel nach oben war zu eng: die Vereine mit den groessten
			# Hallen erwirtschafteten mehr, als sie ausgeben durften, und
			# hamsterten es (gemessen: 2,92 Mio. je Verein und Jahr allein an
			# Ausbauprojekten, weil das Geld sonst nirgends hinkonnte).
			etat = clampf(etat, grund * 0.5, grund * 2.4)
		v["jahresetat"] = etat
		var strenge: float = float(v["vorstand"]["finanzstrenge"]) / 100.0
		# Das Budget ist nur dann eine brauchbare Kennzahl, wenn eine normal
		# besetzte Mannschaft es ungefähr ausschöpft. Mit dem alten Anteil stand
		# die Gehaltsauslastung dauerhaft bei rund 146 % und sagte nichts mehr.
		# Sanierung: wer im Minus steht, plant kleiner, bis die Kasse stimmt.
		#
		# Ohne diesen Term gab es keinen Weg zurueck. Ein Verein konnte seine
		# Gehaltslast senken, bis er ausgeglichen wirtschaftete — aber ein
		# ausgeglichenes Jahr zahlt kein altes Minus zurueck. Die Prüfung sieht
		# den Kassenstand und nicht den Jahresfluss, und deshalb stand ein
		# Verein, der einmal bei zweieinhalb Millionen Minus gelandet war, dort
		# fuer immer. Ein Vorstand in dieser Lage verlangt einen Ueberschuss,
		# und genau das steht hier.
		var notlage: float = clampf(-float(v["kasse"]) / maxf(etat, 1.0), 0.0, 0.7)
		v["gehaltsbudget"] = etat * (0.94 - 0.12 * strenge - 0.45 * notlage) / 52.0
		v["transferbudget"] = maxf(etat * (0.16 - 0.06 * strenge) + maxf(float(v["kasse"]), 0.0) * 0.25, 0.0)

static func gehaltsauslastung(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var budget: float = maxf(float(v["gehaltsbudget"]), 1.0)
	return (spielergehaelter(d, cid) + personalgehaelter(d, cid)) / budget * 100.0

# ------------------------------------------------------------ Ausbauten ---

## Die groesste Halle, die ein Verein aus eigener Kraft erreicht.
##
## Hier stand keine Grenze. Abteilungen enden bei Stufe zehn, die Halle wuchs je
## Ausbau um ein Viertel und weiter ohne Ende — und weil mehr Plaetze mehr
## Eintrittsgeld bringen und mehr Eintrittsgeld den naechsten Ausbau bezahlt,
## war das eine Schleife, die sich selbst antreibt. Gemessen mit
## werkzeuge/Wirtschaftssonde.gd stand der THW Kiel nach drei Spielzeiten bei
## einem Ertrag von 31,97 Mio. und einem Gewinn von 12,12 — bei Spieltagskosten,
## die auf rund vierhundertzwanzigtausend Zuschauer im Jahr hinausliefen. Die
## groesste Handballhalle der Bundesliga hat dreizehntausenddreihundert Plaetze.
const HALLE_MAX := 14000
## Ab welcher Auslastung ein Ausbau sich fuer die KI rechnet. Sitze, die
## niemand fuellt, kosten Betrieb und bringen nichts.
const HALLE_AUSLASTUNG_AB := 0.88

## Lohnt sich fuer diesen Verein ein Hallenausbau? Die Entscheidungsregel der
## KI; der Mensch darf auch auf Vorrat bauen, aber nicht ueber HALLE_MAX.
static func halle_lohnt(d: Dictionary, cid: String) -> bool:
	var v: Dictionary = d["vereine"].get(cid, {})
	if v.is_empty():
		return false
	var kapazitaet: float = float((v.get("halle", {}) as Dictionary).get("kapazitaet", 0))
	if kapazitaet >= float(HALLE_MAX):
		return false
	var saison: Dictionary = v.get("saison", {})
	var spiele: float = float(saison.get("heimspiele", 0))
	if spiele < 3.0:
		# Noch keine Auskunft. Wer nichts weiss, baut nicht.
		return false
	var schnitt: float = float(saison.get("zuschauer_summe", 0.0)) / spiele
	return schnitt / maxf(kapazitaet, 1.0) >= HALLE_AUSLASTUNG_AB

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
	if bereich == "halle" and int(v["halle"]["kapazitaet"]) >= HALLE_MAX:
		return {"ok": false, "grund": "Mehr als %d Plätze gibt der Standort nicht her. Ein größeres Haus wäre ein Umzug, keine Baustelle." % HALLE_MAX}
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
