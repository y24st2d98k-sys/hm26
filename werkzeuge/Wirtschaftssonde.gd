extends Node
## Trägt sich die Wirtschaft des Spiels — oder läuft sie aus dem Ruder?
##
## Die halbe Hälfte eines Managerspiels ist Geld, und dafür gab es bisher keine
## einzige Messung. Die Prüfung nennt am Ende eine Summe aller Kassen; ob die
## Vereine davon leben können, ob die Liga über Jahre verarmt oder in Geld
## ertrinkt, ob ein Aufsteiger zahlungsfähig bleibt — nichts davon wurde je
## nachgesehen.
##
## Diese Sonde spielt mehrere Spielzeiten und schreibt für jede auf, woher das
## Geld kommt, wohin es geht und wie viele Vereine am Ende im Minus stehen.
## Verglichen wird mit dem, was in der Bundesliga wirklich gilt: ein Etat
## zwischen vier und zwölf Millionen, Personal als größter Posten bei rund der
## Hälfte davon, Zuschauer und Sponsoren als die beiden tragenden Einnahmen.
##
##     godot --headless res://werkzeuge/Wirtschaftssonde.tscn -- <spielzeiten>

const SAAT := 771155

## Was die Wirklichkeit sagt. Quellen sind die veröffentlichten Etats der
## Handball-Bundesliga; die Spannen sind bewusst weit, weil zwischen Kiel und
## einem Aufsteiger Faktor drei liegt.
const ZIELE := [
	{"feld": "etat", "name": "Jahresetat Ø (Mio.)", "von": 3.5, "bis": 9.0,
		"quelle": "HBL: Aufsteiger rund 3, Spitze über 12"},
	{"feld": "gehaltsanteil", "name": "Gehälter vom Umsatz (%)", "von": 40.0, "bis": 62.0,
		"quelle": "Profisport: Personalquote um 50 Prozent"},
	{"feld": "zuschaueranteil", "name": "Zuschauer vom Ertrag (%)", "von": 18.0, "bis": 40.0,
		"quelle": "HBL: Spieltag ist die zweitgrößte Säule"},
	{"feld": "sponsoranteil", "name": "Sponsoring vom Ertrag (%)", "von": 25.0, "bis": 55.0,
		"quelle": "HBL: Sponsoring ist die größte Säule"},
	{"feld": "minus", "name": "Vereine im Minus (%)", "von": 0.0, "bis": 25.0,
		"quelle": "Einzelne kämpfen, die Mehrheit nicht"},
	{"feld": "ergebnis", "name": "Jahresergebnis Ø (Mio.)", "von": -0.8, "bis": 0.8,
		"quelle": "Ein Verein wirtschaftet ungefähr ausgeglichen"},
]

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var jahre: int = int(args[0]) if args.size() > 0 else 3
	seed(SAAT)
	var vorschau := Weltgenerator.erzeuge(2026, SAAT)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Wirt", "nachname": "Schaft"}, SAAT)
	var d: Dictionary = Welt.daten
	var lid := _erste_liga(d)

	_log("")
	_log("=== Wirtschaft der Bundesliga, %d Spielzeiten ===" % jahre)
	_log("")
	_log("%-8s %9s %9s %9s %9s %9s %8s" % ["Saison", "Etat Mio", "Ertrag", "Aufwand",
		"Ergebnis", "Kasse Ø", "im Minus"])

	# Taeglich mitschreiben, nicht am Jahresende nachsehen.
	#
	# Die Jahressummen in v["saison"]["finanzen"] werden beim Saisonwechsel
	# geleert. Wer nach dreihundertfuenfundsechzig Tagen hineinschaut, sieht
	# die frisch begonnene Saison — beim ersten Versuch stand dort ein
	# Aufwand von null und ein Zuschaueranteil von hundert Prozent, weil
	# genau ein Spieltag verbucht war. Gemessen wird deshalb der letzte Stand
	# vor dem Wechsel.
	var letzte := {}
	var stand := {}
	var saison_vorher: int = Welt.saison_index()
	var jahr_nummer := 0
	var tage := 0
	while jahr_nummer < jahre:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		tage += 1
		var jetzt: int = Welt.saison_index()
		if jetzt != saison_vorher:
			jahr_nummer += 1
			saison_vorher = jetzt
			letzte = _auswerten(d, stand, jahr_nummer)
			stand = {}
		else:
			stand = _sammeln(d, lid)
		if tage > jahre * 420:
			break

	_log("")
	_log("=== Woher das Geld kommt und wohin es geht (letzte Spielzeit, Ø je Verein) ===")
	_log("")
	_log("%-18s %12s   %s" % ["Posten", "Mio. €", "Anteil"])
	var posten: Array = letzte.get("posten", [])
	for e in posten:
		var pe: Dictionary = e
		_log("%-18s %12.2f   %5.1f %%" % [str(pe["name"]), float(pe["betrag"]),
			float(pe["anteil"])])

	_log("")
	_log("=== Jeder Verein einzeln (letzte Spielzeit, nach Etat) ===")
	_log("")
	_log("%-22s %7s %7s %7s %7s %7s %7s %7s %7s %7s" % ["Verein", "Etat",
		"Ertrag", "Aufwand", "Erg.", "Gehalt", "Betrieb", "Amt", "Sptg.", "Ausbau"])
	var reihen: Array = letzte.get("reihen", [])
	reihen.sort_custom(func(a, b): return float((b as Dictionary)["etat"]) > float((a as Dictionary)["etat"]))
	for r in reihen:
		var rd: Dictionary = r
		_log("%-22s %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f%s" % [
			str(rd["name"]).left(22),
			float(rd["etat"]) / 1.0e6, float(rd["ertrag"]) / 1.0e6,
			float(rd["aufwand"]) / 1.0e6,
			(float(rd["ertrag"]) - float(rd["aufwand"])) / 1.0e6,
			float(rd["gehalt"]) / 1.0e6, float(rd["betrieb"]) / 1.0e6,
			float(rd["amt"]) / 1.0e6, float(rd["spieltag"]) / 1.0e6,
			float(rd["ausbau"]) / 1.0e6,
			"  MINUS" if float(rd["kasse"]) < 0.0 else ""])

	_log("")
	_log("=== Abgleich mit der Wirklichkeit ===")
	_log("")
	_log("%-28s %10s %18s   %s" % ["Kennzahl", "gemessen", "Ziel", "Urteil"])
	var fehler := 0
	for z in ZIELE:
		var wert: float = float(letzte.get(str(z["feld"]), 0.0))
		var ok: bool = wert >= float(z["von"]) and wert <= float(z["bis"])
		if not ok:
			fehler += 1
		_log("%-28s %10.2f %8.1f - %7.1f   %-11s (%s)" % [str(z["name"]), wert,
			float(z["von"]), float(z["bis"]),
			"passt" if ok else ("ZU NIEDRIG" if wert < float(z["von"]) else "ZU HOCH"),
			str(z["quelle"])])
	_tiefrot(d)

	_log("")
	_log("%d von %d Kennzahlen liegen im Rahmen." % [ZIELE.size() - fehler, ZIELE.size()])
	get_tree().quit()

## Wer tief im Minus steht — und warum.
##
## Die Prüfung meldet seit dem Umbau der Wirtschaft zwei Vereine unter minus
## zwei Millionen, immer dieselben, und nennt nur Name und Betrag. Damit ist
## nicht zu sehen, ob der Etat zu hoch angesetzt war, die Gehaltslast nicht
## gesenkt wurde oder die Einnahmen einfach nicht reichen. Hier stehen alle
## Zahlen nebeneinander, und zwar über alle Ligen: der zweite Fall der Prüfung
## war ein dänischer Verein, und die Tabellen oben sehen nur die Bundesliga.
func _tiefrot(d: Dictionary) -> void:
	var liste: Array = []
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][str(cid)]
		if float(v.get("kasse", 0.0)) >= 0.0:
			continue
		liste.append({
			"name": str(v.get("name", str(cid))),
			"liga": str((d["ligen"] as Dictionary).get(str(v.get("liga", "")), {}).get("kurz", "?")),
			"kasse": float(v["kasse"]),
			"etat": float(v.get("jahresetat", 0.0)),
			"budget": float(v.get("gehaltsbudget", 0.0)),
			"last": Finanzen.gehaltsauslastung(d, str(cid)),
			"umsatz": float(v.get("umsatz_vorjahr", 0.0)),
			"gehalt": Finanzen.spielergehaelter(d, str(cid)) + Finanzen.personalgehaelter(d, str(cid)),
			"ruf": float(v.get("ruf", 0.0)),
			"kader": (v.get("kader", []) as Array).size(),
		})
	liste.sort_custom(func(a, b): return float((a as Dictionary)["kasse"]) < float((b as Dictionary)["kasse"]))
	_log("")
	_log("=== Wer im Minus steht (alle Ligen, die zehn tiefsten) ===")
	_log("")
	if liste.is_empty():
		_log("Kein Verein im Minus.")
		return
	_log("%-22s %5s %9s %8s %8s %8s %8s %6s %6s" % ["Verein", "Liga", "Kasse Mio",
		"Etat", "Umsatz", "Gehalt/J", "Last %", "Ruf", "Kader"])
	for e in liste.slice(0, 10):
		var r: Dictionary = e
		_log("%-22s %5s %9.2f %8.2f %8.2f %8.2f %8.0f %6.0f %6d" % [
			str(r["name"]).left(22), str(r["liga"]),
			float(r["kasse"]) / 1.0e6, float(r["etat"]) / 1.0e6,
			float(r["umsatz"]) / 1.0e6, float(r["gehalt"]) * 52.0 / 1.0e6,
			float(r["last"]), float(r["ruf"]), int(r["kader"])])
	_log("")
	_log("Gehalt/J ist die heutige Wochenlast auf ein Jahr gerechnet, Last der")
	_log("Anteil am Gehaltsbudget. Liegt die Last unter hundert und die Kasse")
	_log("trotzdem tief im Minus, war nicht das Gehalt das Problem, sondern der")
	_log("Etat oder die Einnahmen.")

func _erste_liga(d: Dictionary) -> String:
	for l in (d["ligen"] as Dictionary).keys():
		if str(d["ligen"][l].get("kurz", "")) == "HBL":
			return str(l)
	return str((d["ligen"] as Dictionary).keys()[0])

## Eine Spielzeit auswerten. Gerechnet wird über die Jahressummen je
## Kategorie, die Finanzen.buchen mitführt — nicht über das gedeckelte
## Buchungsprotokoll, das nur die letzten zweihundert Zeilen behält.
## Der Stand von heute: je Verein die Jahressummen und die Kasse.
func _sammeln(d: Dictionary, lid: String) -> Dictionary:
	var aus := {"vereine": [], "kasse": []}
	for c in (d["ligen"][lid]["vereine"] as Array):
		var v: Dictionary = d["vereine"][str(c)]
		(aus["vereine"] as Array).append({
			"name": str(v.get("name", str(c))),
			"etat": float(v.get("jahresetat", 0.0)),
			"kasse": float(v.get("kasse", 0.0)),
			"finanzen": ((v.get("saison", {}) as Dictionary).get("finanzen", {}) as Dictionary).duplicate(),
		})
	return aus

func _auswerten(d: Dictionary, stand: Dictionary, nummer: int) -> Dictionary:
	var liste: Array = stand.get("vereine", [])
	if liste.is_empty():
		return {}
	var etat := 0.0
	var ertrag := 0.0
	var aufwand := 0.0
	var kasse := 0.0
	var minus := 0
	var zuschauer := 0.0
	var sponsor := 0.0
	var gehalt := 0.0
	var reihen: Array = []
	for e in liste:
		var v: Dictionary = e
		var v_ertrag := 0.0
		var v_aufwand := 0.0
		for kv in (v["finanzen"] as Dictionary).keys():
			var bv: float = float((v["finanzen"] as Dictionary)[kv])
			if bv >= 0.0:
				v_ertrag += bv
			else:
				v_aufwand += -bv
		var f: Dictionary = v["finanzen"]
		reihen.append({
			"name": str(v.get("name", "?")),
			"etat": float(v["etat"]),
			"ertrag": v_ertrag,
			"aufwand": v_aufwand,
			"kasse": float(v["kasse"]),
			"gehalt": -minf(float(f.get("gehalt", 0.0)), 0.0),
			"betrieb": -minf(float(f.get("betrieb", 0.0)), 0.0),
			"amt": -minf(float(f.get("verwaltung", 0.0)), 0.0)
				- minf(float(f.get("liga", 0.0)), 0.0),
			"spieltag": -minf(float(f.get("spieltag", 0.0)), 0.0),
			"ausbau": -minf(float(f.get("ausbau", 0.0)), 0.0),
		})
		etat += float(v["etat"])
		kasse += float(v["kasse"])
		if float(v["kasse"]) < 0.0:
			minus += 1
		for k in (v["finanzen"] as Dictionary).keys():
			var b: float = float((v["finanzen"] as Dictionary)[k])
			if b >= 0.0:
				ertrag += b
			else:
				aufwand += -b
			match str(k):
				"zuschauer", "spieltag":
					zuschauer += maxf(b, 0.0)
				"sponsor":
					sponsor += maxf(b, 0.0)
				"gehalt":
					gehalt += -minf(b, 0.0)
	var n: float = maxf(float(liste.size()), 1.0)
	_log("%-8d %9.2f %9.2f %9.2f %9.2f %9.2f %7.0f %%" % [nummer,
		etat / n / 1.0e6, ertrag / n / 1.0e6, aufwand / n / 1.0e6,
		(ertrag - aufwand) / n / 1.0e6, kasse / n / 1.0e6,
		float(minus) / n * 100.0])
	# Jede Kategorie einzeln — sonst weiss man, dass die Bilanz nicht stimmt,
	# aber nicht, an welchem Posten.
	var je_kategorie := {}
	for e2 in liste:
		for k2 in ((e2 as Dictionary)["finanzen"] as Dictionary).keys():
			je_kategorie[str(k2)] = float(je_kategorie.get(str(k2), 0.0)) \
				+ float(((e2 as Dictionary)["finanzen"] as Dictionary)[k2])
	var posten: Array = []
	for k3 in je_kategorie.keys():
		var b3: float = float(je_kategorie[k3]) / n / 1.0e6
		posten.append({"name": Finanzen.kategorie_name(str(k3)), "betrag": b3,
			"anteil": absf(float(je_kategorie[k3])) / maxf(ertrag if float(je_kategorie[k3]) >= 0.0 else aufwand, 1.0) * 100.0})
	posten.sort_custom(func(a, b): return absf(float((a as Dictionary)["betrag"])) > absf(float((b as Dictionary)["betrag"])))
	return {
		"etat": etat / n / 1.0e6,
		"ergebnis": (ertrag - aufwand) / n / 1.0e6,
		"gehaltsanteil": gehalt / maxf(ertrag, 1.0) * 100.0,
		"zuschaueranteil": zuschauer / maxf(ertrag, 1.0) * 100.0,
		"sponsoranteil": sponsor / maxf(ertrag, 1.0) * 100.0,
		"minus": float(minus) / n * 100.0,
		"posten": posten,
		"reihen": reihen,
	}

