extends Node
## Was kostet ein Druck auf "Bewerber sichten"?
##
## Der Personalbildschirm erzeugt die Bewerber mit
## Weltgenerator.erzeuge_mitarbeiter() — und die schreibt jeden Erzeugten
## dauerhaft nach d["personal"]. Wer zweimal sichtet, hat acht Bewerber im
## Spielstand, von denen sechs niemand mehr sieht. Und wer lange genug
## drückt, bekommt irgendwann den perfekten Torwarttrainer; das ist kein
## Markt, sondern ein Würfelbecher.
##
## Diese Sonde zählt beides: was im Spielstand liegenbleibt und ob zweimal
## Sichten dieselben Leute zeigt.

var fehler := 0
var geprueft := 0

func _log(t: String) -> void:
	printerr(t)

func _pruefe(name: String, bedingung: bool, bemerkung: String = "") -> void:
	geprueft += 1
	if bedingung:
		_log("   ok   %s" % name)
	else:
		fehler += 1
		_log("   FEHLER %s   %s" % [name, bemerkung])

func _ready() -> void:
	seed(818181)
	var vorschau := Weltgenerator.erzeuge(2026, 818181)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(818181)
	Welt.neues_spiel(cid, {"vorname": "Per", "nachname": "Sonal"}, 818181)
	var d: Dictionary = Welt.daten

	var vorher: int = (d["personal"] as Dictionary).size()
	_log("")
	_log("Personal in der Welt zu Beginn: %d" % vorher)

	# Zwanzigmal sichten, wie es ein Mensch in einer Minute schafft.
	var erste: Array = []
	var letzte: Array = []
	for i in range(20):
		var liste := Personalmarkt.bewerber(d, cid, "torwarttrainer")
		if i == 0:
			erste = liste.duplicate()
		letzte = liste
	var nachher: int = (d["personal"] as Dictionary).size()
	_log("Personal nach zwanzigmal Sichten:  %d   (%+d)" % [nachher, nachher - vorher])
	_log("")

	_pruefe("Zwanzigmal Sichten füllt den Spielstand nicht zu",
		nachher - vorher <= Personalmarkt.BEWERBER,
		"%d neue Einträge für %d Plätze" % [nachher - vorher, Personalmarkt.BEWERBER])
	_pruefe("Zweimal Sichten zeigt dieselben Bewerber", erste == letzte,
		"erst %s, dann %s" % [str(erste), str(letzte)])

	# Nach der Gültigkeitsdauer darf sich der Markt bewegen — und die alten
	# Bewerber müssen verschwinden.
	d["tag"] = int(d["tag"]) + Personalmarkt.GUELTIG_TAGE + 1
	var spaeter := Personalmarkt.bewerber(d, cid, "torwarttrainer")
	_pruefe("Nach zwei Wochen bewerben sich andere", spaeter != letzte,
		"immer noch %s" % str(spaeter))
	var jetzt: int = (d["personal"] as Dictionary).size()
	_pruefe("Die alten Bewerber sind aufgeräumt",
		jetzt - vorher <= Personalmarkt.BEWERBER,
		"%d Einträge über dem Anfang" % (jetzt - vorher))
	for pid in letzte:
		if (d["personal"] as Dictionary).has(str(pid)):
			_pruefe("Ein nicht verpflichteter Bewerber bleibt nicht liegen", false,
				"%s steht noch in der Welt" % str(pid))
			break

	_log("")
	if fehler == 0:
		_log("— Personalsonde bestanden (%d Prüfungen) —" % geprueft)
	else:
		_log("— Personalsonde: %d FEHLER bei %d Prüfungen —" % [fehler, geprueft])
	get_tree().quit(1 if fehler > 0 else 0)
