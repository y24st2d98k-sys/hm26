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
	_log("%-28s %12s %12s %10s" % ["Hebel", "Tordiff A", "Tordiff B", "Wirkung"])

	_vergleich("Deckung 6-0 → 3-2-1", n,
		func(): d["vereine"][heim]["taktik"]["abwehr"] = "6-0",
		func(): d["vereine"][heim]["taktik"]["abwehr"] = "3-2-1")
	_vergleich("Angriff Position → Tempo", n,
		func(): d["vereine"][heim]["taktik"]["angriff"] = "positionsangriff",
		func(): d["vereine"][heim]["taktik"]["angriff"] = "tempospiel")
	_vergleich("Tempo 50 → 85", n,
		func(): d["vereine"][heim]["taktik"]["tempo"] = 50,
		func(): d["vereine"][heim]["taktik"]["tempo"] = 85)
	_vergleich("Risiko 45 → 85", n,
		func(): d["vereine"][heim]["taktik"]["risiko"] = 45,
		func(): d["vereine"][heim]["taktik"]["risiko"] = 85)
	_vergleich("Härte 45 → 85", n,
		func(): d["vereine"][heim]["taktik"]["haerte"] = 45,
		func(): d["vereine"][heim]["taktik"]["haerte"] = 85)
	_vergleich("Videostudium ohne → voll", n,
		func(): _video(0.0),
		func(): _video(100.0))

	_log("")
	_log("Wirkung ist die mittlere Differenz je Saat, in Toren aus Sicht der Heimmannschaft.")
	_log("Ein Hebel nahe null bewegt nichts — dann ist er ein Knopf ohne Funktion.")
	get_tree().quit()

func _video(arbeit: float) -> void:
	var s := Videostudium.stand(d, heim)
	s["arbeit"] = arbeit
	s["gegner"] = gast if arbeit > 0.0 else ""

## Zwei Einstellungen gegeneinander, Saat für Saat.
func _vergleich(name: String, n: int, a: Callable, b: Callable) -> void:
	var summe_a := 0.0
	var summe_b := 0.0
	var summe_diff := 0.0
	var quadrate_diff := 0.0
	for i in range(n):
		var saat: int = 810001 + i * 17
		a.call()
		var ab_a: float = _partie(saat)
		b.call()
		var ab_b: float = _partie(saat)
		summe_a += ab_a
		summe_b += ab_b
		var diff: float = ab_b - ab_a
		summe_diff += diff
		quadrate_diff += diff * diff
	var mittel: float = summe_diff / float(n)
	var streuung: float = sqrt(maxf(quadrate_diff / float(n) - mittel * mittel, 0.0))
	# Der Standardfehler sagt, ob die gemessene Wirkung mehr ist als Rauschen.
	var fehler: float = streuung / sqrt(float(n))
	var urteil := "im Rauschen"
	if absf(mittel) > fehler * 2.0:
		urteil = "wirkt"
	_log("%-28s %12.2f %12.2f %+10.2f   (± %.2f, %s)" % [name, summe_a / float(n),
		summe_b / float(n), mittel, fehler * 2.0, urteil])

func _partie(saat: int) -> float:
	for sid in d["spieler"].keys():
		(d["spieler"][sid] as Dictionary)["verletzung"] = {}
	var m2: Dictionary = (d["spiele"][paarung] as Dictionary).duplicate(true)
	var sim := Matchsim.new(d, m2, saat)
	sim.vorbereiten()
	sim.schnell_simulieren()
	return float(int(m2["tore_heim"]) - int(m2["tore_gast"]))
