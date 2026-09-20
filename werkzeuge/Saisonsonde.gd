extends Node
## Wie stark schwankt eine Spielzeit, wenn sich am Kader nichts ändert?
##
## Die Langzeitsonde hat einen Verein von Platz 4 (45 Punkte) auf Platz 16
## (23 Punkte) fallen sehen, bei praktisch unveränderter Mannschaft. Das sind
## rund vier Standardabweichungen, wenn man die Streuung einer einzelnen
## Partie hochrechnet — entweder stimmt die Hochrechnung nicht, oder zwischen
## den Spielzeiten ändert sich etwas Systematisches.
##
## Diese Sonde beantwortet den ersten Teil: dieselbe Welt, derselbe Kader,
## dieselbe Ausgangslage, nur andere Würfel. Was dabei herauskommt, ist die
## reine Saisonstreuung. Alles, was darüber hinausgeht, hat eine Ursache.

const SAAT := 4242
const WIEDERHOLUNGEN := 8

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var laeufe: int = int(args[0]) if args.size() > 0 else WIEDERHOLUNGEN
	var punkte: Array = []
	var plaetze: Array = []
	var name := ""
	for lauf in laeufe:
		var erg := _saison(lauf)
		if erg.is_empty():
			continue
		punkte.append(float(erg["punkte"]))
		plaetze.append(float(erg["platz"]))
		name = str(erg["name"])
		_log("   Lauf %d: Platz %2d, %2d Punkte" % [lauf + 1, int(erg["platz"]), int(erg["punkte"])])
	if punkte.is_empty():
		get_tree().quit()
		return
	_log("")
	_log("=== %d Spielzeiten desselben Kaders: %s ===" % [punkte.size(), name])
	_log("Punkte  Mittel %.1f  Streuung %.2f  von %d bis %d" % [
		_mittel(punkte), _streuung(punkte), int(punkte.min()), int(punkte.max())])
	_log("Platz   Mittel %.1f  Streuung %.2f  von %d bis %d" % [
		_mittel(plaetze), _streuung(plaetze), int(plaetze.min()), int(plaetze.max())])
	_log("")
	_log("Zwei Spielzeiten, die weiter auseinanderliegen als etwa das Doppelte")
	_log("dieser Streuung, haben eine Ursache und sind kein Zufall.")
	get_tree().quit()

## Eine vollständige Ligasaison mit frischem Kader, nur die Würfel wechseln.
func _saison(lauf: int) -> Dictionary:
	var d := Weltgenerator.erzeuge(2026, SAAT)
	Welt.daten = d
	Welt.mein_verein_id = ""
	seed(SAAT)
	Spielplan.erzeuge_saison(d)
	var liste: Array = d["ligen"]["l_de1"]["vereine"]
	var cid: String = str(liste[int(liste.size() / 2)])
	var partien: Array = []
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) == "liga" and str(m.get("wettbewerb", "")) == "l_de1":
			partien.append(str(mid))
	partien.sort()
	var punkte := 0
	var n := 0
	for mid in partien:
		# Verletzungen zuruecksetzen: gemessen wird der Spielverlauf, nicht
		# das Lazarett. Wie oft sich jemand verletzt, misst die
		# Verletzungssonde.
		for sid in d["spieler"].keys():
			(d["spieler"][sid] as Dictionary)["verletzung"] = {}
		var m2: Dictionary = d["spiele"][mid]
		var sim := Matchsim.new(d, m2, 500001 + n * 7 + lauf * 9973)
		sim.vorbereiten()
		sim.schnell_simulieren()
		n += 1
		var heim: bool = str(m2["heim"]) == cid
		if not heim and str(m2["gast"]) != cid:
			continue
		var eigen: int = int(m2["tore_heim"] if heim else m2["tore_gast"])
		var fremd: int = int(m2["tore_gast"] if heim else m2["tore_heim"])
		punkte += 2 if eigen > fremd else (1 if eigen == fremd else 0)
	# Den Platz aus den Ergebnissen aller Partien bestimmen.
	var tab := {}
	for c in liste:
		tab[str(c)] = 0
	for mid2 in partien:
		var m3: Dictionary = d["spiele"][mid2]
		var th: int = int(m3["tore_heim"])
		var tg: int = int(m3["tore_gast"])
		var h: String = str(m3["heim"])
		var g: String = str(m3["gast"])
		if not tab.has(h) or not tab.has(g):
			continue
		tab[h] = int(tab[h]) + (2 if th > tg else (1 if th == tg else 0))
		tab[g] = int(tab[g]) + (2 if tg > th else (1 if th == tg else 0))
	var sortiert: Array = tab.keys()
	sortiert.sort_custom(func(a, b): return int(tab[a]) > int(tab[b]))
	return {"punkte": punkte, "platz": sortiert.find(cid) + 1,
		"name": str(d["vereine"][cid]["name"])}

func _mittel(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / maxf(float(a.size()), 1.0)

func _streuung(a: Array) -> float:
	var m: float = _mittel(a)
	var q := 0.0
	for x in a:
		q += (float(x) - m) * (float(x) - m)
	return sqrt(q / maxf(float(a.size()), 1.0))
