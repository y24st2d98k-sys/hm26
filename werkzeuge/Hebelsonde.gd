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
	if nur == "wette":
		_wette(n)
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

## Alle Formationen gleich eingespielt.
##
## Ohne das misst die Sonde die Gewohnheit und nicht den Hebel: die
## Stammformation eines Vereins startet bei Vertrautheit 100, jede andere bei
## 25, und der Faktor darauf reicht von 0,925 bis 1,0. Das sind bis zu
## siebeneinhalb Prozent Wirksamkeit — mehr, als die meisten Hebel überhaupt
## bewegen. Eine Messung ohne diesen Ausgleich sagt nur, welche Formation der
## Verein schon kann.
func _vertrautheit_gleich(cid: String) -> void:
	var k: Dictionary = Vertrautheit.konto(d, cid)
	for bereich in ["abwehr", "angriff"]:
		for f in (k[bereich] as Dictionary).keys():
			k[bereich][f] = 100.0

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
	_log("Alle Werte in Toren aus Sicht der Heimmannschaft. * ist die beste Wahl der Lage.")
	var goldene := 0
	for h in hebel:
		# Jede Möglichkeit in jeder Lage, nicht nur die beste. Wer nur den
		# Sieger nennt, verschweigt, ob er um ein halbes Tor gewonnen hat oder
		# um drei — und genau das ist der Unterschied zwischen "lageabhängig"
		# und "hier liegt der Zufall obenauf".
		_log("")
		_log("%s" % str(h["name"]).to_upper())
		_log("  %-18s %12s %12s %12s" % ["", str(lagen[0]["name"]),
			str(lagen[1]["name"]), str(lagen[2]["name"])])
		var spalten: Array = []
		for lage in lagen:
			gast = str(lage["gast"])
			var m0: Dictionary = d["spiele"][paarung]
			m0["heim"] = heim
			m0["gast"] = gast
			d["vereine"][heim]["taktik"] = Weltgenerator.standard_taktik()
			_vertrautheit_gleich(heim)
			var mittel: Array = []
			for w in (h["werte"] as Array):
				mittel.append(_messe(n, func(): d["vereine"][heim]["taktik"][str(h["feld"])] = w))
			spalten.append(mittel)
		var beste_je_lage: Array = []
		for sp in spalten:
			var b := 0
			for j2 in range((sp as Array).size()):
				if float((sp as Array)[j2]) > float((sp as Array)[b]):
					b = j2
			beste_je_lage.append(b)
		for i2 in (h["werte"] as Array).size():
			var zeile := "  %-18s" % str((h["werte"] as Array)[i2])
			for sl in spalten.size():
				var wert: float = float((spalten[sl] as Array)[i2])
				var mark: String = " *" if int(beste_je_lage[sl]) == i2 else "  "
				zeile += "%10s%s" % ["%+.1f" % wert, mark]
			_log(zeile)
		var verschieden := {}
		for sl2 in spalten.size():
			verschieden[str((h["werte"] as Array)[int(beste_je_lage[sl2])])] = true
		# Der Standardfehler eines Feldes liegt bei rund 7/sqrt(n) Toren. Ein
		# Sieger, der weniger als zwei davon vor dem Zweiten liegt, ist keiner.
		var fehler: float = 7.0 / sqrt(float(n)) * 2.0
		var eindeutig := 0
		for sl3 in spalten.size():
			var sp3: Array = spalten[sl3]
			var b3: int = int(beste_je_lage[sl3])
			# Kein Nullpunkt als Startwert: Tordifferenzen sind oft alle
			# negativ, und dann bliebe der Vergleich am letzten Eintrag
			# haengen statt am zweitbesten.
			var zweiter := -1.0e9
			for i3 in sp3.size():
				if i3 != b3 and float(sp3[i3]) > zweiter:
					zweiter = float(sp3[i3])
			if float(sp3[b3]) - zweiter > fehler:
				eindeutig += 1
		var urteil := "lageabhängig"
		if verschieden.size() == 1 and eindeutig >= 2:
			urteil = "GOLDENE REGEL"
			goldene += 1
		elif verschieden.size() == 1:
			urteil = "immer dieselbe Wahl, aber unter der Auflösung"
		_log("  → %s (Auflösungsgrenze %.1f Tore)" % [urteil, fehler])
	_log("")
	if goldene == 0:
		_log("Keine goldene Regel: jeder Hebel will je nach Gegner etwas anderes.")
	else:
		_log("%d von %d Hebeln haben eine Antwort, die immer stimmt. Die gehören repariert." % [
			goldene, hebel.size()])


## Risiko und Härte: Falle oder Wette?
##
## Die Tabelle oben misst jeden Hebel in Toren, und in Toren gemessen ist beim
## Risiko wie bei der Härte der niedrigste Wert der beste — Spanne 1,85 und
## 1,73 bei 800 Paarungen, beides deutlich über der Auflösungsgrenze von 0,70.
## Damit wäre die Sache entschieden: zwei Regler, deren Optimum am Anschlag
## liegt, also zwei Fallen.
##
## Nur ist der Mittelwert für diese zwei Regler das falsche Maß. Wer als
## Außenseiter nach Kiel fährt, will nicht die Tordifferenz verbessern, er will
## Punkte; und wenn man ohnehin mit sechs Toren Rückstand verliert, ist eine
## Wette, die einen im Mittel sieben verlieren lässt, aber jede achte Partie
## gewinnt, die bessere Wahl. Der Trainer maximiert Siegwahrscheinlichkeit,
## nicht Erwartungswert.
##
## Deshalb hier vier Zahlen statt einer: Mittel, Streuung, Siegquote und wie oft
## es eng blieb. Erst zusammen sagen sie, ob ein Regler eine Wette ist.
func _wette(n: int) -> void:
	var stark := ""
	var schwach := ""
	var bester := -1.0
	var schlechtester := 999.0
	for c in (d["ligen"]["l_de1"]["vereine"] as Array):
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
	_log("=== Risiko und Härte: Falle oder Wette? (%d Paarungen je Feld) ===" % n)
	_log("")
	_log("Nicht der Mittelwert entscheidet, sondern die Siegquote. Ein Regler, der")
	_log("im Mittel kostet und trotzdem häufiger gewinnt, ist eine Wette.")
	for lage in [
			{"name": "Außenseiter zu Hause", "heim": schwach, "gast": stark},
			{"name": "Favorit zu Hause", "heim": stark, "gast": schwach}]:
		heim = str(lage["heim"])
		gast = str(lage["gast"])
		var m0: Dictionary = d["spiele"][paarung]
		m0["heim"] = heim
		m0["gast"] = gast
		_log("")
		_log("— %s: %s gegen %s —" % [str(lage["name"]),
			str(d["vereine"][heim]["name"]), str(d["vereine"][gast]["name"])])
		for h in [{"name": "Risiko", "feld": "risiko"}, {"name": "Härte", "feld": "haerte"}]:
			_log("   %-8s %8s %10s %10s %10s %10s" % [str(h["name"]), "Wert",
				"Mittel", "Streuung", "Siegquote", "eng (<=2)"])
			var siegquoten: Array = []
			for w2 in [20, 45, 70, 90]:
				d["vereine"][heim]["taktik"] = Weltgenerator.standard_taktik()
				_vertrautheit_gleich(heim)
				var abst: Array = []
				for i in range(n):
					d["vereine"][heim]["taktik"][str(h["feld"])] = int(w2)
					abst.append(_partie(810001 + i * 17))
				var mittel := 0.0
				for a in abst:
					mittel += float(a)
				mittel /= float(abst.size())
				var varianz := 0.0
				var siege := 0
				var eng := 0
				for a2 in abst:
					varianz += pow(float(a2) - mittel, 2.0)
					if float(a2) > 0.0:
						siege += 1
					if absf(float(a2)) <= 2.0:
						eng += 1
				varianz /= maxf(float(abst.size() - 1), 1.0)
				var sq: float = float(siege) / float(abst.size()) * 100.0
				siegquoten.append(sq)
				_log("   %-8s %8d %10.2f %10.2f %9.1f%% %9.1f%%" % ["", w2, mittel,
					sqrt(varianz), sq, float(eng) / float(abst.size()) * 100.0])
			# Der Standardfehler einer Quote aus n Partien liegt bei
			# sqrt(p(1-p)/n); bei p um 0,2 und n=400 sind das 2,0 Prozentpunkte.
			# Zwei Quoten unterscheiden sich erst ab dem Doppelten verlässlich.
			var schwelle: float = 2.0 * sqrt(0.2 * 0.8 / float(n)) * 100.0 * 1.41
			var hoch: float = float(siegquoten[3])
			var tief: float = float(siegquoten[0])
			var urteil := "kein Unterschied in der Siegquote"
			if hoch - tief > schwelle:
				urteil = "hoher Wert gewinnt öfter — eine Wette"
			elif tief - hoch > schwelle:
				urteil = "niedriger Wert gewinnt öfter — in dieser Lage eine Falle"
			_log("   → %s (Auflösung %.1f Punkte)" % [urteil, schwelle])
	_log("")
	_log("Ein Regler, der beim Außenseiter als Wette und beim Favoriten als Falle")
	_log("erscheint, ist genau richtig gebaut: dann entscheidet die Lage.")
