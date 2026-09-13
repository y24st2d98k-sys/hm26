class_name Schluesselszenen
extends RefCounted
## Was von einer Partie hängen bleibt.
##
## Nach dem Abpfiff gab es einen Bericht mit Zahlen und einen Ticker mit
## siebzig Zeilen. Beides stimmt und beides erzählt nichts: man sieht, dass es
## 29:28 stand, aber nicht, woran es lag. Ein Spiel hat fünf bis acht Momente,
## an denen es gekippt ist — der gehaltene Siebenmeter, die dritte Zeitstrafe,
## der Ausgleich in der 58. Diese Momente herauszufiltern ist billig, weil die
## Ereignisliste ohnehin entsteht; sie wegzuwerfen war die Verschwendung.
##
## Bewertet wird jedes Ereignis nach drei Größen, die sich multiplizieren:
##  * Gewicht der Art (ein Siebenmeter wiegt mehr als ein Feldtor)
##  * Enge des Spielstands (bei zwölf Toren Abstand ist nichts mehr wichtig)
##  * Zeitpunkt (die letzten zehn Minuten zählen doppelt)

## So viele Szenen kommen in den Bericht. Weniger wäre keine Erzählung, mehr
## wäre wieder ein Ticker.
const ANZAHL := 7

const GEWICHT := {
	"tor": 1.0,
	"parade": 1.15,
	"siebenmeter": 1.9,
	"zeitstrafe": 1.1,
	"rot": 3.4,
	"lauf": 2.2,
	"auszeit": 0.9,
	"verletzung": 2.0,
	"siebenmeterwerfen": 3.0,
}

## Filtert die Szenen aus der vollständigen Ereignisliste einer Partie.
static func auswaehlen(ereignisse: Array, spielzeit: float) -> Array:
	var bewertet: Array = []
	for e in ereignisse:
		var typ: String = str((e as Dictionary).get("typ", ""))
		if not GEWICHT.has(typ):
			continue
		var wert := _gewichten(e as Dictionary, typ, spielzeit)
		if wert <= 0.0:
			continue
		bewertet.append({"wert": wert, "ereignis": e})
	# Reine Bestenauswahl reicht nicht. Weil Spielstände auseinandergehen,
	# steht die eng umkämpfte Phase fast immer am Anfang — und dann liegen
	# sieben Szenen in den ersten zwanzig Minuten und die zweite Halbzeit
	# kommt gar nicht vor. Das ist kein Rückblick, das ist ein Ausschnitt.
	#
	# Deshalb wird nach jeder Wahl die Umgebung gedämpft: zeitlich, damit die
	# Auswahl das Spiel abdeckt, und nach Art, damit nicht dreimal derselbe
	# Torlauf dasteht. Beides zusammen ergibt eine Auswahl, die sich liest wie
	# eine Zusammenfassung und nicht wie eine Rangliste.
	var auswahl: Array = []
	# Erst ein Pflichtplatz je Viertel. Die Dämpfung allein reicht nicht: weil
	# Spielstände auseinandergehen, sitzt die eng umkämpfte Phase fast immer am
	# Anfang, und dann läge die ganze Auswahl in den ersten zwanzig Minuten.
	# Vier Viertel, vier garantierte Plätze — der Rest geht an die Wichtigkeit.
	for viertel in range(VIERTEL):
		var von: float = spielzeit / float(VIERTEL) * float(viertel)
		var bis: float = spielzeit / float(VIERTEL) * float(viertel + 1)
		var i := _bester(bewertet, von, bis)
		if i < 0:
			continue
		_nehmen(bewertet, i, auswahl, spielzeit)
	# Dann die freien Plätze, unabhängig von der Phase.
	while auswahl.size() < ANZAHL:
		var frei := _bester(bewertet, 0.0, spielzeit + 1.0)
		if frei < 0:
			break
		_nehmen(bewertet, frei, auswahl, spielzeit)
	auswahl.sort_custom(func(a, b): return float(a["zeit"]) < float(b["zeit"]))
	return auswahl

## In wie viele Abschnitte die Partie für die Pflichtplätze zerfällt.
const VIERTEL := 4

static func _bester(bewertet: Array, von: float, bis: float) -> int:
	var bester := -1
	var bestwert := 0.0
	for i in range(bewertet.size()):
		var e: Dictionary = bewertet[i]
		if bool(e.get("vergeben", false)):
			continue
		var t: float = float((e["ereignis"] as Dictionary).get("zeit", 0.0))
		if t < von or t >= bis:
			continue
		if float(e["wert"]) > bestwert:
			bestwert = float(e["wert"])
			bester = i
	return bester

static func _nehmen(bewertet: Array, i: int, auswahl: Array, spielzeit: float) -> void:
	var gewaehlt: Dictionary = bewertet[i]
	gewaehlt["vergeben"] = true
	auswahl.append(_verdichten(gewaehlt["ereignis"], float(gewaehlt["wert"])))
	_daempfen(bewertet, gewaehlt, spielzeit)

## Wie weit eine gewählte Szene ihre Nachbarn verdrängt, in Sekunden.
const ABSTAND := 420.0

static func _daempfen(bewertet: Array, gewaehlt: Dictionary, spielzeit: float) -> void:
	var g: Dictionary = gewaehlt["ereignis"]
	var zeit: float = float(g.get("zeit", 0.0))
	var typ: String = str(g.get("typ", ""))
	for e in bewertet:
		var eintrag: Dictionary = e
		if bool(eintrag.get("vergeben", false)):
			continue
		var andere: Dictionary = eintrag["ereignis"]
		var naehe: float = absf(float(andere.get("zeit", 0.0)) - zeit)
		if naehe < ABSTAND:
			# Volle Dämpfung direkt daneben, gar keine ab sieben Minuten
			# Abstand — dazwischen linear.
			eintrag["wert"] = float(eintrag["wert"]) * (0.22 + 0.78 * naehe / ABSTAND)
		if str(andere.get("typ", "")) == typ:
			# Zweimal dieselbe Art ist selten zweimal interessant. Der dritte
			# Torlauf einer Partie erzählt nichts Neues mehr.
			eintrag["wert"] = float(eintrag["wert"]) * 0.62

static func _gewichten(e: Dictionary, typ: String, spielzeit: float) -> float:
	var wert: float = float(GEWICHT[typ])
	if typ == "tor" and bool(e.get("siebenmeter", false)):
		wert = float(GEWICHT["siebenmeter"])
	if typ == "tor" and bool(e.get("leeres_tor", false)):
		wert *= 2.4
	if typ == "tor" and bool(e.get("gegenstoss", false)):
		wert *= 1.2
	var stand: Array = e.get("stand", [0, 0])
	var abstand: float = absf(float(stand[0]) - float(stand[1]))
	# Bei drei Toren Abstand ist noch alles offen, bei zehn nichts mehr.
	var enge: float = clampf(1.35 - abstand * 0.11, 0.16, 1.35)
	var zeit: float = float(e.get("zeit", 0.0))
	var phase: float = 1.0
	if zeit > spielzeit - 600.0:
		phase = 1.4 + (zeit - (spielzeit - 600.0)) / 600.0 * 0.8
	elif zeit < 300.0:
		# Der Anfang zählt ein wenig, weil er den Ton setzt.
		phase = 1.12
	return wert * enge * phase

## Reduziert ein Ereignis auf das, was der Bericht braucht. Der Spielstand
## kommt mit, sonst müsste die Oberfläche ihn aus dem Ticker zurückrechnen.
static func _verdichten(e: Dictionary, wert: float) -> Dictionary:
	return {
		"zeit": float(e.get("zeit", 0.0)),
		"typ": str(e.get("typ", "")),
		"team": str(e.get("team", "")),
		"spieler": str(e.get("spieler", "")),
		"text": str(e.get("text", "")),
		"stand": (e.get("stand", [0, 0]) as Array).duplicate(),
		"position": str(e.get("position", "")),
		"siebenmeter": bool(e.get("siebenmeter", false)),
		"gewicht": wert,
	}

## Ein kurzes Etikett für die Zeitleiste.
static func etikett(szene: Dictionary) -> String:
	match str(szene.get("typ", "")):
		"tor":
			return "Siebenmeter" if bool(szene.get("siebenmeter", false)) else "Tor"
		"parade": return "Parade"
		"siebenmeter": return "Siebenmeter"
		"zeitstrafe": return "Zeitstrafe"
		"rot": return "Rote Karte"
		"lauf": return "Lauf"
		"auszeit": return "Auszeit"
		"verletzung": return "Verletzung"
		"siebenmeterwerfen": return "Siebenmeterwerfen"
	return "Szene"

## Ein Satz darüber, warum das Spiel so ausging — aus der wichtigsten Szene.
static func fazit(szenen: Array) -> String:
	if szenen.is_empty():
		return ""
	var beste: Dictionary = szenen[0]
	for s in szenen:
		if float((s as Dictionary)["gewicht"]) > float(beste["gewicht"]):
			beste = s
	return "Die Szene des Spiels: %s" % str(beste["text"])
