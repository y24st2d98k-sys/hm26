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
	_log("%-26s %10s %10s %10s %10s" % ["Hebel", "schlechtest", "beste", "Spanne", "Urteil"])

	_wahl("Deckung", n, "abwehr", ["6-0", "5-1", "3-2-1", "4-2"])
	_wahl("Angriffsstil", n, "angriff", ["positionsangriff", "tempospiel", "kreisfokus"])
	_zahl("Tempo", n, "tempo", [25, 50, 75, 90])
	_zahl("Risiko", n, "risiko", [20, 45, 70, 90])
	_zahl("Härte", n, "haerte", [20, 45, 70, 90])
	_videovergleich(n)
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
	if gewinner.size() <= 1 and geprueft > 1:
		_log("   Überall derselbe Stil — das ist keine Passung, sondern ein bester Knopf.")
	else:
		_log("   Verschiedene Vereine, verschiedene Stile — der Kader entscheidet.")
