class_name Lizenzierung
extends RefCounted
## Das Lizenzierungsverfahren — Halle, Beleuchtung, Jugendzertifikat, Harz.
##
## Im deutschen Profihandball entscheidet nicht nur die Tabelle darüber, ob ein
## Verein oben spielen darf. Der Lizenzierungsausschuss prüft jedes Jahr die
## wirtschaftliche und die bauliche Leistungsfähigkeit, und die Auflagen sind
## hart: Mindestkapazität, Längstribünen auf beiden Seiten, eine Beleuchtung,
## die für die Fernsehproduktion taugt, abschließbare Kabinen, ein
## Dopingkontrollraum, Arbeitsplätze für die Daten-Scouts.
##
## Für den Aufsteiger ist das der eigentliche Aufstieg. Eine Mannschaft kann
## sich sportlich qualifizieren und trotzdem an der Halle scheitern — und wer
## die Auflagen nur mit einer Ausnahmegenehmigung erfüllt, zahlt jedes Jahr
## dafür.
##
## Dazu kommt eine Besonderheit, die es in keiner anderen Sportart gibt: das
## Haftmittel. Ohne Harz sind die Wurfgeschwindigkeiten und einhändigen
## Fangaktionen des Profihandballs nicht möglich, der DHB schreibt es von der
## ersten bis zur dritten Liga vor — und gleichzeitig verbieten viele
## kommunale Hallen es, weil die Rückstände den Boden ruinieren. Genau dort
## trainieren aber die A-Jugend und die Zweite.

# ------------------------------------------------------------ Hallenstandard ---

## Mindestkapazität nach Spielklasse. Erste Liga der Männer: 1.500 Zuschauer,
## dazu Längstribünen auf beiden Seiten des Spielfelds.
const KAPAZITAET_MIN := {1: 1500, 2: 1000}
## Kamerabeleuchtungsstärke auf dem Spielfeld, in Lux.
const LUX_FELD := 1500
## Im Zuschauerbereich, gemessen in der fünfzehnten Reihe.
const LUX_RANG := 600
## Gleichmäßigkeit der Ausleuchtung. Darunter wirft die Halle Schatten, und
## die Fernsehproduktion beanstandet das Bild.
const GLEICHMAESSIGKEIT_MIN := 0.80

## Was eine Nachrüstung kostet, als Anteil des Jahresetats. Für einen
## Aufsteiger ist das eine Investitionshürde, für einen Spitzenclub eine
## Rechnung.
const LICHT_KOSTEN_ANTEIL := 0.055
const LICHT_KOSTEN_MIN := 160000.0

## Gästekontingent: fünf Prozent der Gesamttickets, mindestens 100, höchstens
## 200 Plätze — kostenlos, dazu vier VIP-Karten.
const GAESTE_ANTEIL := 0.05
const GAESTE_MIN := 100
const GAESTE_MAX := 200

## Geschulte Scouts je Pflichtspiel, die über die Ligasoftware die
## Live-Statistik erfassen.
const SCOUTS_JE_SPIEL := 3

# --------------------------------------------------------- Jugendzertifikat ---

## Das Jugendzertifikat der HBL. Wer es nicht bekommt, zahlt in einen
## Solidarfonds, der an die zertifizierten Vereine ausgeschüttet wird — das
## ist die Abwägung, vor der der Manager steht: teure Jugendtrainer oder
## Strafzahlung und das Geld in den Profikader.
## Stufe der Jugendabteilung: steht fuer die Meldung von der A- bis zur
## F-Jugend, die das Zertifikat verlangt.
const ZERT_JUGENDARBEIT := 4
## Guete der Nachwuchsarbeit: steht dafuer, dass die A-Jugend sich fuer die
## Jugendbundesliga qualifiziert. Sie haengt an der Ausbaustufe *und* an einem
## Nachwuchskoordinator — ohne den ist die Huerde nicht zu schaffen.
const ZERT_ARBEITSQUALITAET := 42.0
## Der Nachwuchs muss ueberhaupt bestehen. Das Spiel fuehrt nicht sechzehn
## A-Jugendliche je Verein, sondern die Talente, um die es geht — ein
## Jahrgang bringt einen bis drei.
const ZERT_JUGENDKADER := 3
## Die zweite Mannschaft muss im Wettkampfbetrieb stehen.
const ZERT_ZWEITE_SPIELE := 10
## Die Strafzahlung, als Anteil des Jahresetats.
const ZERT_STRAFE_ANTEIL := 0.022

# ------------------------------------------------------------------- Harz ---

## Was das Haftmittel samt Spezialreiniger und Reinigungsmaschine im Jahr
## kostet, als Anteil des Jahresetats. Klingt nach wenig und ist es auch —
## der Posten steht hier, weil es ihn wirklich gibt und weil er erklärt,
## warum kommunale Hallen Harz verbieten.
const HARZ_ANTEIL := 0.006
## Wie viele Vereine ihre Jugend und ihre Zweite in einer Halle mit
## Harzverbot trainieren lassen müssen.
const HARZVERBOT_WAHRSCHEINLICHKEIT := 0.35
## Was das den Übergang in den Profikader kostet. Wer mit einem kleineren,
## harzfreien Ball aufwächst, muss die Ballbehandlung neu lernen.
const HARZVERBOT_UEBERGANG := 0.86

# ------------------------------------------------------------------ Stand ---

static func stand(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("lizenz"):
		v["lizenz"] = {"auflagen": [], "zertifikat": false, "letzte_pruefung": -1}
	return v["lizenz"]

static func halle(d: Dictionary, cid: String) -> Dictionary:
	var h: Dictionary = d["vereine"][cid]["halle"]
	# Ältere Spielstände kennen die Lichtwerte noch nicht.
	if not h.has("licht_feld"):
		var ruf: float = float(d["vereine"][cid].get("ruf", 50.0))
		h["licht_feld"] = int(clampf(1300.0 + ruf * 6.2, 800.0, 2400.0))
		h["gleichmaessigkeit"] = clampf(0.62 + ruf * 0.0028, 0.55, 0.95)
	# Der Zuschauerbereich hängt an derselben Anlage wie das Spielfeld: wer
	# dort hell ausleuchtet, tut es auch auf den Rängen.
	if int(h.get("licht_rang", 0)) <= 0:
		h["licht_rang"] = int(float(h["licht_feld"]) * 0.42)
	return h

static func stufe(d: Dictionary, cid: String) -> int:
	var lid: String = str(d["vereine"][cid].get("liga", ""))
	if lid == "" or not d["ligen"].has(lid):
		return 3
	return int(d["ligen"][lid].get("stufe", 3))

## Wie viele Plätze dem Gastverein zustehen — kostenlos.
static func gaestekontingent(d: Dictionary, cid: String) -> int:
	var kap: int = int(d["vereine"][cid]["halle"]["kapazitaet"])
	return clampi(int(round(float(kap) * GAESTE_ANTEIL)), GAESTE_MIN, GAESTE_MAX)

# --------------------------------------------------------------- Auflagen ---

## Was an dieser Halle nicht den Vorgaben entspricht. Leere Liste heißt: alles
## in Ordnung.
static func auflagen(d: Dictionary, cid: String) -> Array:
	var liste: Array = []
	var st: int = stufe(d, cid)
	if st > 2:
		return liste
	var h := halle(d, cid)
	var mindest: int = int(KAPAZITAET_MIN.get(st, 1000))
	if int(h["kapazitaet"]) < mindest:
		liste.append({"feld": "kapazitaet",
			"text": "Die Halle fasst %d Zuschauer. Vorgeschrieben sind %d." % [
				int(h["kapazitaet"]), mindest]})
	if int(h["licht_feld"]) < LUX_FELD:
		liste.append({"feld": "licht",
			"text": "Die Spielfeldbeleuchtung erreicht %d Lux. Für die Fernsehproduktion sind %d Lux vorgeschrieben." % [
				int(h["licht_feld"]), LUX_FELD]})
	elif int(h["licht_rang"]) < LUX_RANG:
		liste.append({"feld": "licht",
			"text": "Im Zuschauerbereich werden nur %d Lux erreicht; gefordert sind %d." % [
				int(h["licht_rang"]), LUX_RANG]})
	elif float(h["gleichmaessigkeit"]) < GLEICHMAESSIGKEIT_MIN:
		liste.append({"feld": "licht",
			"text": "Die Ausleuchtung ist mit %s ungleichmäßig; gefordert sind %s." % [
				Stil.komma(float(h["gleichmaessigkeit"]), 2), Stil.komma(GLEICHMAESSIGKEIT_MIN, 2)]})
	return liste

## Was eine Nachrüstung der Beleuchtung kostet.
static func lichtkosten(d: Dictionary, cid: String) -> float:
	var etat: float = float(d["vereine"][cid].get("jahresetat", 3000000.0))
	return maxf(etat * LICHT_KOSTEN_ANTEIL, LICHT_KOSTEN_MIN)

## Die Beleuchtung auf Ligastandard bringen.
static func licht_nachruesten(d: Dictionary, cid: String) -> Dictionary:
	var h := halle(d, cid)
	if int(h["licht_feld"]) >= LUX_FELD and int(h["licht_rang"]) >= LUX_RANG \
			and float(h["gleichmaessigkeit"]) >= GLEICHMAESSIGKEIT_MIN:
		return {"ok": false, "grund": "Die Beleuchtung erfüllt die Vorgaben bereits."}
	var kosten := lichtkosten(d, cid)
	var v: Dictionary = d["vereine"][cid]
	if float(v["kasse"]) < kosten:
		return {"ok": false, "grund": "Dafür reicht die Kasse nicht: %s werden gebraucht." % Stil.geld(kosten)}
	Finanzen.buchen(d, cid, -kosten, "Neue Hallenbeleuchtung", "ausbau")
	h["licht_feld"] = maxi(int(h["licht_feld"]), LUX_FELD + 120)
	h["licht_rang"] = maxi(int(h["licht_rang"]), LUX_RANG + 60)
	h["gleichmaessigkeit"] = maxf(float(h["gleichmaessigkeit"]), 0.84)
	return {"ok": true, "grund": "Die Halle ist neu ausgeleuchtet — %s." % Stil.geld(kosten)}

# ------------------------------------------------------- Jugendzertifikat ---

## Die Kriterien, jeweils mit Stand und Urteil.
static func zertifikatskriterien(d: Dictionary, cid: String) -> Array:
	var v: Dictionary = d["vereine"][cid]
	var jugendarbeit: int = int(v["infrastruktur"]["jugendarbeit"])
	var kader: int = (v["jugend"] as Array).size()
	var b: Dictionary = Zweite.bilanz(d, cid)
	var spiele: int = int(b["spiele"])
	var guete: float = Jugend.arbeitsqualitaet(d, cid)
	return [
		{"text": "Mannschaften von der A- bis zur F-Jugend", "erfuellt": jugendarbeit >= ZERT_JUGENDARBEIT,
			"stand": "Jugendabteilung Stufe %d, gefordert %d" % [jugendarbeit, ZERT_JUGENDARBEIT]},
		{"text": "A-Jugend in der Jugendbundesliga", "erfuellt": guete >= ZERT_ARBEITSQUALITAET,
			"stand": "Nachwuchsarbeit %d von 100, gefordert %d" % [int(guete), int(ZERT_ARBEITSQUALITAET)]},
		{"text": "Talente im Nachwuchszentrum", "erfuellt": kader >= ZERT_JUGENDKADER,
			"stand": "%d Talente, gefordert %d" % [kader, ZERT_JUGENDKADER]},
		{"text": "Zweite Mannschaft im Wettkampfbetrieb", "erfuellt": spiele >= ZERT_ZWEITE_SPIELE,
			"stand": "%d Pflichtspiele der Zweiten, gefordert %d" % [spiele, ZERT_ZWEITE_SPIELE]},
	]

static func zertifikat_erfuellt(d: Dictionary, cid: String) -> bool:
	for k in zertifikatskriterien(d, cid):
		if not bool((k as Dictionary)["erfuellt"]):
			return false
	return true

static func hat_zertifikat(d: Dictionary, cid: String) -> bool:
	return bool(stand(d, cid).get("zertifikat", false))

# ------------------------------------------------------------------- Harz ---

## Ob die Jugend und die Zweite dieses Vereins in einer Halle mit Harzverbot
## trainieren.
static func harzverbot(d: Dictionary, cid: String) -> bool:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("harzverbot"):
		# Wer eine eigene Halle betreibt, hat das Problem nicht. Als Maßstab
		# dient die Hallengröße: eine Zweitausenderhalle ist in aller Regel
		# eine kommunale Sporthalle.
		var eigen: bool = int(v["halle"]["kapazitaet"]) >= 4000
		v["harzverbot"] = (not eigen) and Namen.zufall() < HARZVERBOT_WAHRSCHEINLICHKEIT
	return bool(v["harzverbot"])

## Faktor auf die Entwicklung eines Nachwuchsspielers.
static func nachwuchsfaktor(d: Dictionary, cid: String) -> float:
	return HARZVERBOT_UEBERGANG if harzverbot(d, cid) else 1.0

## Was Haftmittel, Spezialreiniger und Reinigungsmaschine je Woche kosten.
static func harzkosten(d: Dictionary, cid: String) -> float:
	var etat: float = float(d["vereine"][cid].get("jahresetat", 2000000.0))
	return etat * HARZ_ANTEIL / 52.0

# ----------------------------------------------------------- Jahresverfahren ---

## Läuft einmal je Spielzeit, nach Auf- und Abstieg.
##
## Die Halle bringt Auflagen, das Jugendzertifikat bringt Geld oder kostet
## welches. Der Solidarfonds ist kein Buchungstrick: was die einen als Strafe
## zahlen, bekommen die anderen ausgeschüttet.
static func jahreslauf(d: Dictionary, mein: String) -> void:
	var topf := 0.0
	var zertifiziert: Array = []
	for cid in Weltgenerator.clubs(d):
		var c := str(cid)
		if stufe(d, c) > 2:
			continue
		var s := stand(d, c)
		s["letzte_pruefung"] = int(d["tag"])
		s["auflagen"] = auflagen(d, c)
		var erfuellt := zertifikat_erfuellt(d, c)
		s["zertifikat"] = erfuellt
		if erfuellt:
			zertifiziert.append(c)
		else:
			var strafe: float = float(d["vereine"][c].get("jahresetat", 2000000.0)) * ZERT_STRAFE_ANTEIL
			Finanzen.buchen(d, c, -strafe, "Strafzahlung Jugendzertifikat", "betrieb")
			topf += strafe
			if c == mein:
				Welt.nachricht({
					"typ": "verein", "wichtig": true,
					"betreff": "Jugendzertifikat verweigert",
					"text": "Die Liga hat das Jugendzertifikat nicht erteilt. %s gehen in den Solidarfonds, der an die zertifizierten Vereine ausgeschüttet wird. %s" % [
						Stil.geld(strafe), _zertifikatshinweis(d, c)],
					"daten": {"verein": c},
				})
	if not zertifiziert.is_empty() and topf > 0.0:
		var anteil: float = topf / float(zertifiziert.size())
		for c2 in zertifiziert:
			Finanzen.buchen(d, str(c2), anteil, "Ausschüttung Solidarfonds", "sonstiges")
		if mein != "" and mein in zertifiziert:
			Welt.nachricht({
				"typ": "finanzen",
				"betreff": "Jugendzertifikat erteilt",
				"text": "Die Nachwuchsarbeit erfüllt alle Auflagen. Aus dem Solidarfonds der Liga kommen %s." % Stil.geld(anteil),
				"daten": {"verein": mein},
			})
	if mein == "" or stufe(d, mein) > 2:
		return
	var offen: Array = auflagen(d, mein)
	if offen.is_empty():
		return
	var text := "Der Lizenzierungsausschuss hat die Lizenz unter Auflagen erteilt:"
	for a in offen:
		text += "\n• %s" % str((a as Dictionary)["text"])
	text += "\n\nWerden die Auflagen bis zur nächsten Prüfung nicht erfüllt, droht der Entzug der Lizenz."
	Welt.nachricht({
		"typ": "verein", "wichtig": true,
		"betreff": "Lizenz nur unter Auflagen",
		"text": text,
		"daten": {"verein": mein},
	})

static func _zertifikatshinweis(d: Dictionary, cid: String) -> String:
	for k in zertifikatskriterien(d, cid):
		if not bool((k as Dictionary)["erfuellt"]):
			return "Es fehlt: %s (%s)." % [str((k as Dictionary)["text"]), str((k as Dictionary)["stand"])]
	return ""
