extends Node
## Misst, was die Simulation statistisch ausspuckt — und haelt daneben, was im
## echten Handball herauskommt.
##
## Die Vorgaben stammen aus dem Konzeptbericht und aus den veroeffentlichten
## Zahlen der Handball-Bundesliga. Jede Zeile nennt den gemessenen Wert, den
## Zielbereich und ob beides zusammenpasst. Erst danach wird geschraubt.

const RUNDEN := 306

## Zielbereiche. Quelle jeweils in der Beschreibung.
const ZIELE := {
	"tore_spiel":      {"von": 58.0, "bis": 63.0, "quelle": "HBL-Schnitt 60,4 Tore je Partie"},
	"angriffe":        {"von": 52.0, "bis": 62.0, "quelle": "Konzept: ueber 50 bis 60 Angriffe je Mannschaft"},
	"wurfquote":       {"von": 0.60, "bis": 0.65, "quelle": "HBL-Wurfquote rund 62 %"},
	"paradenquote":    {"von": 0.28, "bis": 0.33, "quelle": "Konzept: Torhueterquote rund 30 %"},
	"siebenmeter":     {"von": 3.2, "bis": 4.6, "quelle": "HBL: knapp vier Siebenmeter je Mannschaft"},
	"siebenmeterquote":{"von": 0.72, "bis": 0.79, "quelle": "Konzept: 0,75 xG am Strich"},
	"fehler":          {"von": 9.0, "bis": 13.0, "quelle": "HBL: rund elf technische Fehler"},
	"zeitstrafen":     {"von": 3.0, "bis": 4.5, "quelle": "HBL: dreieinhalb Zeitstrafen je Mannschaft"},
	"verwarnungen":    {"von": 2.0, "bis": 4.0, "quelle": "Regelwerk: hoechstens drei Gelbe je Mannschaft"},
	"rote":            {"von": 0.03, "bis": 0.14, "quelle": "HBL: rund jede zehnte Partie eine Disqualifikation"},
	"blocks":          {"von": 2.5, "bis": 5.0, "quelle": "HBL: drei bis vier Blocks je Mannschaft"},
	"einsatzzeit":     {"von": 38.0, "bis": 45.0, "quelle": "Konzept: 41,7 Minuten je eingesetztem Spieler"},
	"eingesetzt":      {"von": 9.0, "bis": 12.0, "quelle": "HBL: zehn bis zwoelf Feldspieler je Partie"},
	"unentschieden":   {"von": 0.10, "bis": 0.16, "quelle": "HBL 2025/26: 13,4 % der Partien"},
	"heimsiege":       {"von": 0.52, "bis": 0.60, "quelle": "HBL: rund 56 % Heimsiege"},
}

## Trefferquoten je Wurfposition. Der Konzeptbericht nennt sie als xG-Werte,
## die Liga veroeffentlicht sie als Wurfquoten — beides meint dasselbe.
const ZIELE_POSITION := {
	"LA": {"von": 0.57, "bis": 0.67, "quelle": "Aussen: 0,62 bis 0,66 xG"},
	"RA": {"von": 0.57, "bis": 0.67, "quelle": "Aussen: 0,62 bis 0,66 xG"},
	"KM": {"von": 0.66, "bis": 0.78, "quelle": "Kreis unbedraengt bis 0,83 xG"},
	"RL": {"von": 0.42, "bis": 0.54, "quelle": "Fernrueckraum ueber den Block: 0,30 bis 0,45 xG"},
	"RM": {"von": 0.42, "bis": 0.56, "quelle": "Fernrueckraum ueber den Block: 0,30 bis 0,45 xG"},
	"RR": {"von": 0.42, "bis": 0.54, "quelle": "Fernrueckraum ueber den Block: 0,30 bis 0,45 xG"},
	"7M": {"von": 0.72, "bis": 0.79, "quelle": "Siebenmeter: 0,75 xG"},
	"TG": {"von": 0.80, "bis": 0.90, "quelle": "Tempogegenstoss: 0,82 bis 0,83 xG"},
}

var s := {}
var pos_karte := {}

func _log(t: String) -> void:
	printerr(t)

## Wie viele Spielzeiten gemessen werden. Eine einzelne Runde ist fuer die
## Randwerte — Unentschieden, klare Ergebnisse — zu klein: dort schwankt eine
## Saison um mehrere Prozentpunkte, und dann misst man das Rauschen statt der
## Aenderung.
const SPIELZEITEN := 4

func _ready() -> void:
	for i in SPIELZEITEN:
		_lauf(4711 + i * 101)
	_bericht()
	_streuungstest()
	get_tree().quit()

func _zu(feld: String, wert: float) -> void:
	s[feld] = float(s.get(feld, 0.0)) + wert

func _lauf(saat: int) -> void:
	Welt.daten = Weltgenerator.erzeuge(2026, saat)
	Welt.mein_verein_id = ""
	var d := Welt.daten
	Spielplan.erzeuge_saison(d)
	var partien: Array = []
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) == "liga" and str(m.get("wettbewerb", "")) == "l_de1":
			partien.append(mid)
	_log("Simuliere %d Bundesligapartien ..." % partien.size())
	partien.sort()
	var n := 0
	for mid in partien:
		var m2: Dictionary = d["spiele"][mid]
		# Feste Saat je Partie: sonst misst jeder Lauf eine andere Stichprobe,
		# und ein Vergleich vorher/nachher sagt nichts.
		var sim := Matchsim.new(d, m2, 90001 + n * 7 + saat)
		sim.vorbereiten()
		sim.schnell_simulieren()
		n += 1
		_partie_auswerten(sim)
	s["partien"] = float(s.get("partien", 0.0)) + float(n)
	_log("Saat %d: %d Partien gerechnet." % [saat, n])

func _partie_auswerten(sim: Matchsim) -> void:
	var h: Dictionary = sim.heim
	var g: Dictionary = sim.gast
	_zu("tore", float(int(h["tore"]) + int(g["tore"])))
	var abstand: int = absi(int(h["tore"]) - int(g["tore"]))
	_zu("abstand", float(abstand))
	_zu("abstand2", float(abstand * abstand))
	if abstand <= 2:
		_zu("eng", 1.0)
	if abstand >= 10:
		_zu("klar", 1.0)
	if int(h["tore"]) == int(g["tore"]):
		_zu("unentschieden", 1.0)
	elif int(h["tore"]) > int(g["tore"]):
		_zu("heimsiege", 1.0)
	for t in [h, g]:
		var st: Dictionary = t["stats"]
		var gegner: Dictionary = g if t == h else h
		_zu("wuerfe", float(st["wuerfe"]))
		_zu("feldtore", float(int(st["tore"]) - int(st["siebenmeter_tore"])))
		_zu("siebenmeter", float(st["siebenmeter"]))
		_zu("siebenmeter_tore", float(st["siebenmeter_tore"]))
		_zu("fehler", float(st["technische_fehler"]))
		_zu("zeitstrafen", float(st["zeitstrafen"]))
		_zu("rote", float(st["rote"]))
		_zu("verwarnungen", float(st.get("verwarnungen", 0)))
		_zu("passiv", float(st.get("vorwarnungen_passiv", 0)))
		_zu("blocks", float(st["blocks"]))
		_zu("paraden", float(st["paraden"]))
		_zu("gegentore", float(gegner["tore"]))
		_zu("gegenstoss_tore", float(st["gegenstoss_tore"]))
		_zu("gegenstoss_wuerfe", float(st["gegenstoss_wuerfe"]))
		_zu("siebter", float(st["sieben_gegen_sechs"]))
		_zu("angriffe", float(int(st["wuerfe"]) + int(st["technische_fehler"]) + int(st["siebenmeter"])))
		var eingesetzt := 0
		var sekunden := 0.0
		for sid in t["zustand"].keys():
			var z: Dictionary = t["zustand"][sid]
			if float(z["sekunden"]) <= 0.0:
				continue
			if bool(Welt.daten["spieler"][sid]["ist_torwart"]):
				continue
			eingesetzt += 1
			sekunden += float(z["sekunden"])
		_zu("eingesetzt", float(eingesetzt))
		_zu("einsatzzeit", sekunden / maxf(float(eingesetzt), 1.0) / 60.0)
		for pos in (t["wurfkarte"] as Dictionary).keys():
			var e: Dictionary = t["wurfkarte"][pos]
			if not pos_karte.has(pos):
				pos_karte[pos] = {"tor": 0, "parade": 0, "vorbei": 0, "block": 0}
			for k in e.keys():
				pos_karte[pos][k] = int(pos_karte[pos].get(k, 0)) + int(e[k])
			if pos != "7M":
				_zu("vorbei", float(e.get("vorbei", 0)))
				_zu("geblockt", float(e.get("block", 0)))
				_zu("paraden_feld", float(e.get("parade", 0)))

func _urteil(wert: float, ziel: Dictionary) -> String:
	if wert < float(ziel["von"]):
		return "ZU NIEDRIG"
	if wert > float(ziel["bis"]):
		return "ZU HOCH"
	return "passt"

func _zeile(name: String, wert: float, schluessel: String, form: String = "%6.2f") -> void:
	var ziel: Dictionary = ZIELE[schluessel]
	var urteil := _urteil(wert, ziel)
	_log("%-26s %s   Ziel %5.2f - %5.2f   %-10s  (%s)" % [
		name, form % wert, ziel["von"], ziel["bis"], urteil, ziel["quelle"]])

func _bericht() -> void:
	var p: float = float(s["partien"])
	var m: float = p * 2.0  # Mannschaftspartien
	_log("")
	_log("=== Realismusabgleich, %d Bundesligapartien ===" % int(p))
	_log("")
	_zeile("Tore je Partie", float(s["tore"]) / p, "tore_spiel")
	_zeile("Angriffe je Mannschaft", float(s["angriffe"]) / m, "angriffe")
	_zeile("Wurfquote gesamt", (float(s["feldtore"]) + float(s["siebenmeter_tore"]))
		/ maxf(float(s["wuerfe"]) + float(s["siebenmeter"]), 1.0), "wurfquote")
	_log("%-26s %6.2f   (davon aus dem Feld, ohne Siebenmeter)" % ["Wurfquote Feld",
		float(s["feldtore"]) / maxf(float(s["wuerfe"]), 1.0)])
	_log("%-26s %6.2f   (HBL: rund 50 Wuerfe je Mannschaft)" % ["Wuerfe je Mannschaft",
		(float(s["wuerfe"]) + float(s["siebenmeter"])) / m])
	_zeile("Paradenquote", float(s["paraden"]) / maxf(float(s["paraden"]) + float(s["gegentore"]), 1.0), "paradenquote")
	_zeile("Siebenmeter je Mannschaft", float(s["siebenmeter"]) / m, "siebenmeter")
	_zeile("Siebenmeterquote", float(s["siebenmeter_tore"]) / maxf(float(s["siebenmeter"]), 1.0), "siebenmeterquote")
	_zeile("Techn. Fehler je Mannsch.", float(s["fehler"]) / m, "fehler")
	_zeile("Zeitstrafen je Mannschaft", float(s["zeitstrafen"]) / m, "zeitstrafen")
	_zeile("Verwarnungen je Mannsch.", float(s["verwarnungen"]) / m, "verwarnungen")
	_zeile("Rote Karten je Partie", float(s["rote"]) / p, "rote")
	_zeile("Blocks je Mannschaft", float(s["blocks"]) / m, "blocks")
	_zeile("Eingesetzte Feldspieler", float(s["eingesetzt"]) / m, "eingesetzt")
	_zeile("Einsatzzeit in Minuten", float(s["einsatzzeit"]) / m, "einsatzzeit")
	_zeile("Unentschieden", float(s["unentschieden"]) / p, "unentschieden")
	_zeile("Heimsiege", float(s["heimsiege"]) / p, "heimsiege")
	_log("")
	_log("Torabstand im Mittel: %.2f   (Wirklichkeit rund 5,4)" % (float(s["abstand"]) / p))
	_log("Streuung des Abstands:%.2f   (Wirklichkeit rund 6,8)" % sqrt(float(s["abstand2"]) / p))
	_log("Hoechstens zwei Tore:  %.1f %%   (Wirklichkeit rund 36 %%)" % (float(s["eng"]) / p * 100.0))
	_log("Zehn Tore und mehr:    %.1f %%   (Wirklichkeit rund 15 %%)" % (float(s["klar"]) / p * 100.0))
	_log("")
	_log("Tempogegenstoss je Mannschaft: %.2f Wuerfe, %.2f Tore, Quote %.1f %%   (HBL: rund 85 %%)" % [
		float(s["gegenstoss_wuerfe"]) / m, float(s["gegenstoss_tore"]) / m,
		float(s["gegenstoss_tore"]) / maxf(float(s["gegenstoss_wuerfe"]), 1.0) * 100.0])
	_log("Vorwarnzeichen passives Spiel: %.2f je Partie   (HBL: rund vier bis acht)" % (float(s["passiv"]) / p))
	_log("Sieben gegen Sechs je Partie:  %.2f Umstellungen   (Konzept: 5,7 Einsaetze)" % (float(s["siebter"]) / p))
	var ges_w: float = maxf(float(s["wuerfe"]), 1.0)
	_log("Wurfausgang: %.1f %% Tor, %.1f %% Parade, %.1f %% vorbei, %.1f %% geblockt" % [
		float(s["feldtore"]) / ges_w * 100.0, float(s["paraden_feld"]) / ges_w * 100.0,
		float(s["vorbei"]) / ges_w * 100.0, float(s["geblockt"]) / ges_w * 100.0])
	_log("")
	_log("=== Trefferquote je Wurfposition ===")
	_log("")
	var reihenfolge := ["LA", "RL", "RM", "RR", "RA", "KM", "TG", "7M"]
	for pos in reihenfolge:
		if not pos_karte.has(pos):
			continue
		var e: Dictionary = pos_karte[pos]
		var ges: int = int(e["tor"]) + int(e["parade"]) + int(e["vorbei"]) + int(e["block"])
		if ges <= 0:
			continue
		var quote: float = float(e["tor"]) / float(ges)
		var anteil: float = float(ges) / maxf(float(s["wuerfe"]) + float(s["siebenmeter"]), 1.0)
		var ziel: Dictionary = ZIELE_POSITION.get(pos, {"von": 0.0, "bis": 1.0, "quelle": "-"})
		_log("%-4s Anteil %5.1f %%   Quote %5.1f %%   Ziel %4.0f - %4.0f %%   %-10s (%s)" % [
			pos, anteil * 100.0, quote * 100.0, float(ziel["von"]) * 100.0, float(ziel["bis"]) * 100.0,
			_urteil(quote, ziel), ziel["quelle"]])


## Wieviel der Ergebnisstreuung ist Zufall, wieviel ist Kaderqualitaet?
##
## Dieselbe Paarung sechshundertmal: was dabei streut, ist reiner Spielverlauf.
## Der Rest der Streuung einer Spielzeit geht auf die Unterschiede zwischen den
## Mannschaften. Ohne diese Trennung schraubt man blind — eine zu breite
## Ergebnisverteilung kann an beidem liegen, und die Gegenmittel sind
## gegenlaeufig.
func _streuungstest() -> void:
	Welt.daten = Weltgenerator.erzeuge(2026, 20260)
	Welt.mein_verein_id = ""
	var d := Welt.daten
	Spielplan.erzeuge_saison(d)
	var paarung := ""
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) == "liga" and str(m.get("wettbewerb", "")) == "l_de1":
			paarung = str(mid)
			break
	if paarung == "":
		return
	var summe := 0.0
	var quadrate := 0.0
	var unentschieden := 0
	var n := 600
	for i in n:
		# Verletzungen bleiben im Datensatz stehen. Ohne Ruecksetzen stuenden
		# nach ein paar hundert Wiederholungen halbe Kader auf der Liste, und
		# gemessen waere nicht der Spielverlauf, sondern das Lazarett.
		for sid in d["spieler"].keys():
			(d["spieler"][sid] as Dictionary)["verletzung"] = {}
		var m2: Dictionary = (d["spiele"][paarung] as Dictionary).duplicate(true)
		var sim := Matchsim.new(d, m2, 700001 + i * 13)
		sim.vorbereiten()
		sim.schnell_simulieren()
		var ab: float = float(int(m2["tore_heim"]) - int(m2["tore_gast"]))
		summe += ab
		quadrate += ab * ab
		if is_zero_approx(ab):
			unentschieden += 1
	var mittel: float = summe / float(n)
	var streuung: float = sqrt(quadrate / float(n) - mittel * mittel)
	_log("")
	_log("=== Dieselbe Paarung %d mal ===" % n)
	_log("Mittlerer Ausgang: %+0.2f Tore   Streuung: %.2f   Unentschieden: %.1f %%" % [
		mittel, streuung, float(unentschieden) / float(n) * 100.0])
	var gesamt: float = sqrt(float(s["abstand2"]) / float(s["partien"]))
	var kader: float = sqrt(maxf(gesamt * gesamt - streuung * streuung, 0.0))
	_log("Davon Spielverlauf: %.2f   Kaderunterschiede: %.2f   (Gesamtstreuung %.2f)" % [
		streuung, kader, gesamt])
