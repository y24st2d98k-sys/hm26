extends Node
## Wie aus Kaderstaerke Tabellenpunkte werden.
##
## Zwischen "die Einzelpartie stimmt statistisch" und "die Tabelle sieht aus
## wie eine Bundesligatabelle" liegt eine Rechnung, die keine der anderen
## Sonden anstellt: wie viele Tore Vorsprung ein Staerkepunkt wert ist, und
## wie viel Zufall daneben steht. Aus diesen beiden Zahlen folgt alles andere
## — wie oft der Favorit gewinnt, und wie weit der Meister davonzieht.
##
## Gemessen wird an gespielten Spielzeiten, nicht an einer Formel: eine
## Regression des Torabstands auf den Staerkeunterschied. Die Steigung ist der
## Ertrag eines Staerkepunkts, die Streuung der Abweichung ist der Zufall.

## Wie viele Spielzeiten gerechnet werden, und ab welcher.
##
## Eine Spielzeit schwankt um vier bis fuenf Punkte an der Tabellenspitze: wer
## an drei Spielzeiten misst, misst zur Haelfte das Rauschen. Beide Zahlen sind
## Aufrufparameter, damit mehrere Laeufe nebeneinander verschiedene Spielzeiten
## uebernehmen koennen — acht Spielzeiten am Stueck dauern eine Viertelstunde,
## zweimal vier nebeneinander die Haelfte.
##
##     godot --headless res://werkzeuge/Tabellensonde.tscn -- 4 0
const SPIELZEITEN := 8

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var anzahl: int = int(args[0]) if args.size() > 0 else SPIELZEITEN
	var versatz: int = int(args[1]) if args.size() > 1 else 0
	var xs: Array = []
	var ys: Array = []
	var meister: Array = []
	var letzte: Array = []
	var streuungen: Array = []
	for i in anzahl:
		var lauf: int = versatz + i
		var d := Weltgenerator.erzeuge(2026, 4711 + lauf * 101)
		Welt.daten = d
		Welt.mein_verein_id = ""
		# Der Spielplan mischt mit dem globalen Zufallsgenerator, und der wird
		# beim Start des Programms zufaellig gesetzt. Ohne diese Zeile spielt
		# jeder Lauf einen anderen Spielplan — zwei Messungen derselben
		# Einstellung lagen dadurch sechs Punkte auseinander, und jeder
		# Vergleich vorher/nachher mass das Rauschen mit.
		seed(4711 + lauf * 101)
		Spielplan.erzeuge_saison(d)
		var staerke := {}
		for cid in d["vereine"].keys():
			var v: Dictionary = d["vereine"][cid]
			if str(v.get("liga", "")) != "l_de1":
				continue
			staerke[cid] = _top8(d, v)
		var punkte := {}
		var partien: Array = []
		for mid in d["spiele"].keys():
			var m: Dictionary = d["spiele"][mid]
			if str(m["art"]) == "liga" and str(m.get("wettbewerb", "")) == "l_de1":
				partien.append(str(mid))
		partien.sort()
		var n := 0
		for mid in partien:
			for sid in d["spieler"].keys():
				(d["spieler"][sid] as Dictionary)["verletzung"] = {}
			var m2: Dictionary = d["spiele"][mid]
			var sim := Matchsim.new(d, m2, 90001 + n * 7 + lauf * 1013)
			sim.vorbereiten()
			sim.schnell_simulieren()
			n += 1
			var hid: String = str(m2["heim"])
			var gid: String = str(m2["gast"])
			var th: int = int(m2["tore_heim"])
			var tg: int = int(m2["tore_gast"])
			xs.append(float(staerke[hid]) - float(staerke[gid]))
			ys.append(float(th - tg))
			punkte[hid] = int(punkte.get(hid, 0)) + (2 if th > tg else (1 if th == tg else 0))
			punkte[gid] = int(punkte.get(gid, 0)) + (2 if tg > th else (1 if th == tg else 0))
		var stand: Array = []
		for cid in punkte.keys():
			stand.append(int(punkte[cid]))
		stand.sort()
		stand.reverse()
		meister.append(float(stand[0]))
		letzte.append(float(stand[stand.size() - 1]))
		streuungen.append(_streuung(stand))
		printerr("Spielzeit %d: Meister %d, Letzter %d, Streuung %.1f" % [
			lauf + 1, int(stand[0]), int(stand[stand.size() - 1]), _streuung(stand)])
	var mx: float = _mittel(xs)
	var my: float = _mittel(ys)
	var kov := 0.0
	var varx := 0.0
	for i in xs.size():
		kov += (float(xs[i]) - mx) * (float(ys[i]) - my)
		varx += (float(xs[i]) - mx) * (float(xs[i]) - mx)
	var steigung: float = kov / maxf(varx, 0.0001)
	var achse: float = my - steigung * mx
	var rest := 0.0
	for i in xs.size():
		var vorhersage: float = achse + steigung * float(xs[i])
		rest += (float(ys[i]) - vorhersage) * (float(ys[i]) - vorhersage)
	var restlich: float = sqrt(rest / float(xs.size()))
	printerr("")
	printerr("=== Staerke, Zufall und Tabelle (Spielzeit %d bis %d, %d Partien) ===" % [
		versatz + 1, versatz + anzahl, xs.size()])
	printerr("Ertrag je Staerkepunkt   %.3f Tore   (Ziel rund 0,85 bis 0,95)" % steigung)
	printerr("Heimvorteil              %.2f Tore   (HBL rund 1,4)" % achse)
	printerr("Zufall je Partie         %.2f Tore   (Ziel rund 5,0 bis 5,5)" % restlich)
	printerr("Streuung Torabstand      %.2f Tore   (HBL rund 6,8)" % _streuung(ys))
	printerr("Punkte des Meisters      %.1f        (HBL 58 bis 64)" % _mittel(meister))
	printerr("Punkte des Letzten       %.1f        (HBL 8 bis 16)" % _mittel(letzte))
	printerr("Streuung der Punkte      %.2f        (HBL rund 14,5)" % _mittel(streuungen))
	var remis := 0
	var klar := 0
	var eng := 0
	for y in ys:
		if is_zero_approx(float(y)):
			remis += 1
		if absf(float(y)) >= 10.0:
			klar += 1
		if absf(float(y)) <= 2.0:
			eng += 1
	printerr("Unentschieden            %.1f %%      (HBL 13,4)" % (float(remis) / float(ys.size()) * 100.0))
	printerr("Zehn Tore und mehr       %.1f %%      (HBL rund 15)" % (float(klar) / float(ys.size()) * 100.0))
	printerr("Hoechstens zwei Tore     %.1f %%      (HBL rund 36)" % (float(eng) / float(ys.size()) * 100.0))
	get_tree().quit()

func _top8(d: Dictionary, v: Dictionary) -> float:
	var beste: Array = []
	for sid in (v["kader"] as Array):
		beste.append(Spielerfabrik.gesamt(d["spieler"][str(sid)]))
	beste.sort()
	beste.reverse()
	var summe := 0.0
	var k: int = mini(8, beste.size())
	for i in k:
		summe += float(beste[i])
	return summe / maxf(float(k), 1.0)

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
