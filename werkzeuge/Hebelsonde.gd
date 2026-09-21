extends Node
## Bewirken die Entscheidungen vor der Partie etwas — und wie viel?
##
## Die Entscheidungssonde misst die Trainingsarbeit über Monate. Die Hebel,
## die man vor jeder einzelnen Partie zieht, misst bisher nichts: Deckung,
## Angriffsstil, Tempo, Risiko, Videostudium, Einzelanweisungen. Genau die
## zieht man am häufigsten, und genau bei ihnen ist am schwersten zu sehen,
## ob sie wirken — eine Partie schwankt um sechs Tore, ein Hebel bewegt
## vielleicht einen.
##
## Deshalb wird gepaart gemessen: dieselbe Paarung, dieselbe Saat, einmal so
## und einmal anders. Die Differenz je Saat hebt den Spielverlauf heraus und
## lässt nur den Hebel übrig. Was dabei herauskommt, ist keine Meinung mehr:
## ein Hebel, der null bewegt, ist ein Knopf ohne Funktion.
##
##     godot --headless res://werkzeuge/Hebelsonde.tscn -- <wiederholungen>

const SAAT := 20260

func _log(t: String) -> void:
	printerr(t)

var d: Dictionary = {}
var paarung: String = ""
var heim: String = ""
var gast: String = ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 240
	# Ein einzelner Vergleich lässt sich mit viel mehr Wiederholungen rechnen
	# als alle zusammen. Nötig wurde das beim Tempo: dort lagen die Spannen
	# mit 1,0 und 1,5 Toren an der Schwelle, ab der eine Zahl überhaupt etwas
	# bedeutet.
	var nur: String = str(args[1]) if args.size() > 1 else ""
	Welt.daten = Weltgenerator.erzeuge(2026, SAAT)
	Welt.mein_verein_id = ""
	d = Welt.daten
	seed(SAAT)
	Spielplan.erzeuge_saison(d)
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) == "liga" and str(m.get("wettbewerb", "")) == "l_de1":
			paarung = str(mid)
			heim = str(m["heim"])
			gast = str(m["gast"])
			break
	if paarung == "":
		_log("Keine Ligapartie gefunden.")
		get_tree().quit(1)
		return

	_log("")
	_log("=== Was die Hebel vor der Partie bewegen (%d Paarungen je Vergleich) ===" % n)
	_log("")
	_log("%s gegen %s, gepaart gemessen: dieselbe Saat, einmal so und einmal anders." % [
		str(d["vereine"][heim]["name"]), str(d["vereine"][gast]["name"])])
	_log("")
	if nur == "tempo":
		_tempoprobe(n)
		get_tree().quit()
		return
	if nur == "goldregel":
		_goldregel(n)
		get_tree().quit()
		return
	_log("%-26s %10s %10s %10s %10s" % ["Hebel", "schlechtest", "beste", "Spanne", "Urteil"])

	_wahl("Deckung", n, "abwehr", ["6-0", "5-1", "3-2-1", "4-2"])
	_wahl("Angriffsstil", n, "angriff", ["positionsangriff", "tempospiel", "kreisfokus"])
	_zahl("Tempo", n, "tempo", [25, 50, 75, 90])
	_zahl("Risiko", n, "risiko", [20, 45, 70, 90])
	_zahl("Härte", n, "haerte", [20, 45, 70, 90])
	_videovergleich(n)
	_tempoprobe(n)
	_stilprobe(n)

	_log("")
	_log("Alle Werte in Toren aus Sicht der Heimmannschaft, gemittelt über dieselben Saaten.")
	_log("Die Spanne ist der Abstand zwischen der besten und der schlechtesten Wahl —")
	_log("also das, was eine richtige Entscheidung überhaupt wert sein kann.")
	get_tree().quit()

func _video(arbeit: float) -> void:
	var s := Videostudium.stand(d, heim)
	s["arbeit"] = arbeit
	s["gegner"] = gast if arbeit > 0.0 else ""

## Alle Möglichkeiten eines Hebels gegeneinander, Saat für Saat.
##
## Nicht "bewegt diese Einstellung Tore" ist die Frage — ein Angriffsstil
## verteilt die Würfe um und bringt für sich genommen keine dazu. Die Frage
## ist, ob die zum Kader passende Wahl die unpassende schlägt. Ist die Spanne
## null, sind alle Möglichkeiten dasselbe, und die Auswahl ist Zierde.
func _wahl(name: String, n: int, feld: String, werte: Array) -> void:
	var mittel: Array = []
	for w in werte:
		mittel.append(_messe(n, func(): d["vereine"][heim]["taktik"][feld] = w))
	_ausgabe(name, werte, mittel, n)

func _zahl(name: String, n: int, feld: String, werte: Array) -> void:
	var mittel: Array = []
	for w in werte:
		mittel.append(_messe(n, func(): d["vereine"][heim]["taktik"][feld] = int(w)))
	_ausgabe(name, werte, mittel, n)

func _videovergleich(n: int) -> void:
	var mittel: Array = []
	for a in [0.0, 100.0]:
		mittel.append(_messe(n, func(): _video(a)))
	_ausgabe("Videostudium", ["ohne", "voll"], mittel, n)

func _messe(n: int, setzen: Callable) -> float:
	var summe := 0.0
	for i in range(n):
		setzen.call()
		summe += _partie(810001 + i * 17)
	return summe / float(n)

## Der Standardfehler einer einzelnen Partie liegt bei rund sieben Toren
## Streuung; über n Saaten schrumpft er auf 7/sqrt(n). Zwei Mittelwerte
## unterscheiden sich erst dann verlässlich, wenn die Spanne das Doppelte
## davon übersteigt — weil dieselben Saaten verwendet werden, ist der Test
## strenger als nötig, also vorsichtig.
func _ausgabe(name: String, werte: Array, mittel: Array, n: int) -> void:
	var beste := 0
	var schlechteste := 0
	for i in range(mittel.size()):
		if float(mittel[i]) > float(mittel[beste]):
			beste = i
		if float(mittel[i]) < float(mittel[schlechteste]):
			schlechteste = i
	var spanne: float = float(mittel[beste]) - float(mittel[schlechteste])
	var schwelle: float = 2.0 * 7.0 / sqrt(float(n)) * 1.41
	var urteil := "Zierde" if spanne < schwelle else "wirkt"
	_log("%-26s %10s %10s %10.2f %10s" % [name,
		"%s %.1f" % [str(werte[schlechteste]), float(mittel[schlechteste])],
		"%s %.1f" % [str(werte[beste]), float(mittel[beste])],
		spanne, urteil])

func _partie(saat: int) -> float:
	for sid in d["spieler"].keys():
		(d["spieler"][sid] as Dictionary)["verletzung"] = {}
	var m2: Dictionary = (d["spiele"][paarung] as Dictionary).duplicate(true)
	var sim := Matchsim.new(d, m2, saat)
	sim.vorbereiten()
	sim.schnell_simulieren()
	return float(int(m2["tore_heim"]) - int(m2["tore_gast"]))


## Hängt der beste Angriffsstil am Kader?
##
## Ein Stil verteilt die Würfe um — Kreis, Außen, Rückraum. Gemessen an einer
## Paarung bewegt er kaum etwas, und das sagt für sich genommen wenig: es
## könnte sein, dass die Auswahl Zierde ist, oder dass dieser eine Kader eben
## keinen Stil bevorzugt. Der Unterschied ist zu sehen, wenn mehrere Vereine
## dieselbe Frage beantworten. Gewinnt überall derselbe Stil, ist es keine
## Passung, sondern ein bester Knopf.
func _stilprobe(n: int) -> void:
	var stile: Array = ["positionsangriff", "tempospiel", "kreisfokus"]
	var vereine: Array = (d["ligen"]["l_de1"]["vereine"] as Array)
	_log("")
	_log("— Hängt der beste Angriffsstil am Kader? —")
	_log("   %-28s %14s %10s" % ["Verein", "bester Stil", "Spanne"])
	var gewinner := {}
	var geprueft := 0
	for i in range(mini(5, vereine.size())):
		var cid: String = str(vereine[i])
		if cid == gast:
			continue
		heim = cid
		var m0: Dictionary = d["spiele"][paarung]
		m0["heim"] = cid
		# Die Regler aus den Läufen davor stehen noch auf den Extremwerten,
		# mit denen sie zuletzt gemessen wurden. Ohne Zurücksetzen misst diese
		# Probe für den ersten Verein etwas anderes als für die übrigen — im
		# ersten Lauf stand Kiel dadurch allein da.
		d["vereine"][cid]["taktik"] = Weltgenerator.standard_taktik()
		var mittel: Array = []
		for st in stile:
			mittel.append(_messe(n, func(): d["vereine"][cid]["taktik"]["angriff"] = st))
		var beste := 0
		var schlecht := 0
		for j in range(mittel.size()):
			if float(mittel[j]) > float(mittel[beste]):
				beste = j
			if float(mittel[j]) < float(mittel[schlecht]):
				schlecht = j
		gewinner[str(stile[beste])] = int(gewinner.get(str(stile[beste]), 0)) + 1
		geprueft += 1
		_log("   %-28s %14s %10.2f" % [str(d["vereine"][cid]["name"]).substr(0, 26),
			str(stile[beste]), float(mittel[beste]) - float(mittel[schlecht])])
	_log("")
	_log("   Das misst vor allem die Vertrautheit: jeder Verein startet in seiner")
	_log("   Stammformation eingespielt und in allen anderen fremd, und das sind")
	_log("   bis zu zehn Prozent auf die Angriffsbasis. Ein Wechsel kostet also")
	_log("   erst einmal — wie er soll.")
	_log("")
	_log("— Und bei gleicher Vertrautheit? —")
	_log("   %-28s %14s %10s" % ["Verein", "bester Stil", "Spanne"])
	var gewinner2 := {}
	var geprueft2 := 0
	for i2 in range(mini(5, vereine.size())):
		var cid2: String = str(vereine[i2])
		if cid2 == gast:
			continue
		heim = cid2
		var m1: Dictionary = d["spiele"][paarung]
		m1["heim"] = cid2
		d["vereine"][cid2]["taktik"] = Weltgenerator.standard_taktik()
		# Alle Stile gleich eingespielt: was jetzt übrig bleibt, ist der Stil
		# selbst — passt er zum Kader oder nicht.
		var k: Dictionary = Vertrautheit.konto(d, cid2)
		for f in (k["angriff"] as Dictionary).keys():
			k["angriff"][f] = 100.0
		var mittel2: Array = []
		for st2 in stile:
			mittel2.append(_messe(n, func(): d["vereine"][cid2]["taktik"]["angriff"] = st2))
		var beste2 := 0
		var schlecht2 := 0
		for j2 in range(mittel2.size()):
			if float(mittel2[j2]) > float(mittel2[beste2]):
				beste2 = j2
			if float(mittel2[j2]) < float(mittel2[schlecht2]):
				schlecht2 = j2
		gewinner2[str(stile[beste2])] = int(gewinner2.get(str(stile[beste2]), 0)) + 1
		geprueft2 += 1
		_log("   %-28s %14s %10.2f" % [str(d["vereine"][cid2]["name"]).substr(0, 26),
			str(stile[beste2]), float(mittel2[beste2]) - float(mittel2[schlecht2])])
	_log("")
	if gewinner2.size() <= 1 and geprueft2 > 1:
		_log("   Überall derselbe Stil — dann ist der Stil selbst ein bester Knopf,")
		_log("   und nur die Vertrautheit hält davon ab, ihn immer zu wählen.")
	else:
		_log("   Verschiedene Vereine, verschiedene Stile — der Kader entscheidet.")


## Hängt das richtige Tempo davon ab, ob man Favorit ist?
##
## Das Tempo tauscht Angriffe gegen Kraft: kürzere Angriffe heißen mehr
## Ballbesitze für beide Mannschaften und mehr Verbrauch. Mehr Ballbesitze
## nützen dem Stärkeren — über viele Angriffe setzt sich Klasse durch, über
## wenige entscheidet der Zufall. Für den Außenseiter müsste also das
## Gegenteil gelten. Gemessen an einer einzigen Paarung ist das nicht zu
## sehen; deshalb einmal als Favorit und einmal als Außenseiter.
func _tempoprobe(n: int) -> void:
	var vereine: Array = (d["ligen"]["l_de1"]["vereine"] as Array)
	var stark: String = ""
	var schwach: String = ""
	var bester := -1.0
	var schlechtester := 999.0
	for c in vereine:
		var w: float = _kaderwert(str(c))
		if w > bester:
			bester = w
			stark = str(c)
		if w < schlechtester:
			schlechtester = w
			schwach = str(c)
	if stark == "" or schwach == "" or stark == schwach:
		return
	_log("")
	_log("— Hängt das richtige Tempo an der Rolle? —")
	_log("   %-34s %10s %10s" % ["Lage", "bestes Tempo", "Spanne"])
	for lage in [{"heim": stark, "gast": schwach, "name": "Favorit zu Hause"},
			{"heim": schwach, "gast": stark, "name": "Außenseiter zu Hause"}]:
		heim = str(lage["heim"])
		gast = str(lage["gast"])
		var m0: Dictionary = d["spiele"][paarung]
		m0["heim"] = heim
		m0["gast"] = gast
		d["vereine"][heim]["taktik"] = Weltgenerator.standard_taktik()
		var werte: Array = [25, 50, 75, 90]
		var mittel: Array = []
		for w2 in werte:
			mittel.append(_messe(n, func(): d["vereine"][heim]["taktik"]["tempo"] = int(w2)))
		var b := 0
		var sc := 0
		for j in range(mittel.size()):
			if float(mittel[j]) > float(mittel[b]):
				b = j
			if float(mittel[j]) < float(mittel[sc]):
				sc = j
		_log("   %-34s %10s %10.2f" % ["%s (%s)" % [str(lage["name"]),
			str(d["vereine"][heim]["name"]).substr(0, 14)], str(werte[b]),
			float(mittel[b]) - float(mittel[sc])])
	_log("")
	_log("   Verschiebt sich das beste Tempo zwischen den beiden Lagen, ist der")
	_log("   Regler eine Lagefrage und keine feste Zahl.")

func _kaderwert(cid: String) -> float:
	var beste: Array = []
	for sid in (d["vereine"][cid].get("kader", []) as Array):
		beste.append(Spielerfabrik.gesamt(d["spieler"][str(sid)]))
	beste.sort()
	beste.reverse()
	var summe := 0.0
	var k: int = mini(8, beste.size())
	for i in k:
		summe += float(beste[i])
	return summe / maxf(float(k), 1.0)


## Gibt es eine Einstellung, die in jeder Lage gewinnt?
##
## Das ist die eigentliche Frage an ein Managerspiel, und sie ist schärfer als
## "wirkt der Hebel". Ein Hebel darf ruhig stark wirken — er darf nur keine
## Antwort haben, die immer stimmt. Sonst stellt man sie einmal ein, fasst sie
## nie wieder an, und jeder Spielstand läuft gleich.
##
## Deshalb wird jeder Hebel in drei Lagen gemessen: gegen einen deutlich
## stärkeren Gegner, gegen einen gleich starken und gegen einen deutlich
## schwächeren. Gewinnt überall derselbe Wert, steht hier eine goldene Regel
## — und die gehört repariert.
func _goldregel(n: int) -> void:
	var vereine: Array = (d["ligen"]["l_de1"]["vereine"] as Array)
	var sortiert: Array = []
	for c in vereine:
		sortiert.append({"cid": str(c), "wert": _kaderwert(str(c))})
	sortiert.sort_custom(func(a, b): return float(a["wert"]) > float(b["wert"]))
	if sortiert.size() < 6:
		return
	# Der Verein aus der Mitte tritt gegen oben, Mitte und unten an.
	var mitte: int = int(sortiert.size() / 2)
	heim = str((sortiert[mitte] as Dictionary)["cid"])
	var lagen: Array = [
		{"name": "gegen den Stärksten", "gast": str((sortiert[0] as Dictionary)["cid"])},
		{"name": "gegen Augenhöhe", "gast": str((sortiert[mitte + 1] as Dictionary)["cid"])},
		{"name": "gegen den Schwächsten", "gast": str((sortiert[sortiert.size() - 1] as Dictionary)["cid"])},
	]
	var hebel: Array = [
		{"name": "Deckung", "feld": "abwehr", "werte": ["6-0", "5-1", "3-2-1", "4-2"]},
		{"name": "Angriffsstil", "feld": "angriff", "werte": ["positionsangriff", "tempospiel", "kreisfokus"]},
		{"name": "Tempo", "feld": "tempo", "werte": [25, 50, 75, 90]},
		{"name": "Risiko", "feld": "risiko", "werte": [20, 45, 70, 90]},
		{"name": "Härte", "feld": "haerte", "werte": [20, 45, 70, 90]},
	]
	_log("")
	_log("=== Gibt es eine Einstellung, die in jeder Lage gewinnt? ===")
	_log("")
	_log("%s zu Hause, %d Partien je Feld." % [str(d["vereine"][heim]["name"]), n])
	_log("")
	_log("%-16s %-22s %-22s %-22s %s" % ["Hebel", str(lagen[0]["name"]),
		str(lagen[1]["name"]), str(lagen[2]["name"]), "Urteil"])
	var goldene := 0
	for h in hebel:
		var beste_je_lage: Array = []
		for lage in lagen:
			gast = str(lage["gast"])
			var m0: Dictionary = d["spiele"][paarung]
			m0["heim"] = heim
			m0["gast"] = gast
			d["vereine"][heim]["taktik"] = Weltgenerator.standard_taktik()
			var mittel: Array = []
			for w in (h["werte"] as Array):
				mittel.append(_messe(n, func(): d["vereine"][heim]["taktik"][str(h["feld"])] = w))
			var b := 0
			for j in range(mittel.size()):
				if float(mittel[j]) > float(mittel[b]):
					b = j
			beste_je_lage.append({"wert": str((h["werte"] as Array)[b]),
				"diff": float(mittel[b])})
		var verschieden := {}
		for e in beste_je_lage:
			verschieden[str(e["wert"])] = true
		var urteil := "goldene Regel" if verschieden.size() == 1 else "lageabhängig"
		if verschieden.size() == 1:
			goldene += 1
		_log("%-16s %-22s %-22s %-22s %s" % [str(h["name"]),
			"%s (%+.1f)" % [str(beste_je_lage[0]["wert"]), float(beste_je_lage[0]["diff"])],
			"%s (%+.1f)" % [str(beste_je_lage[1]["wert"]), float(beste_je_lage[1]["diff"])],
			"%s (%+.1f)" % [str(beste_je_lage[2]["wert"]), float(beste_je_lage[2]["diff"])],
			urteil])
	_log("")
	if goldene == 0:
		_log("Keine goldene Regel: jeder Hebel will je nach Gegner etwas anderes.")
	else:
		_log("%d von %d Hebeln haben eine Antwort, die immer stimmt. Die gehören repariert." % [
			goldene, hebel.size()])
