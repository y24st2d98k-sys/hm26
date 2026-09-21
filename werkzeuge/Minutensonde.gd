extends Node
## Bekommt ein Talent seine Zielminuten wirklich?
##
## Die Minutenzuweisung ist die Ansage des Trainers: dieser Junge soll zwanzig
## Minuten spielen. Umgesetzt wird sie in Matchsim._minutenplan_pruefen — und
## dort stand eine Bedingung, die sie aushebelte: ausgewechselt wurde nur, wer
## selbst ein Ziel hatte und es übererfüllte. Wer seinen Stammspielern kein
## Ziel gibt, bei dem wird also nie jemand für den Jungen Platz machen, und
## das Ziel des Jungen bleibt ein Wunsch.
##
## Diese Sonde setzt genau das: ein Ziel für einen Bankspieler, sonst für
## niemanden — und zählt nach der Partie seine Minuten.

const ZIEL := 20.0

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
	seed(919191)
	var vorschau := Weltgenerator.erzeuge(2026, 919191)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(919191)
	Welt.neues_spiel(cid, {"vorname": "Minuten", "nachname": "Sonde"}, 919191)
	var d: Dictionary = Welt.daten

	# Bis kurz vor die erste eigene Partie, damit eine Aufstellung steht.
	var gesamt := 0.0
	var partien := 0
	var sid := ""
	var name := ""
	for _tag in range(200):
		var u := Welt.tag_weiter()
		if not (u.has("art") and str(u["art"]) == "eigenes_spiel"):
			continue
		# Vorbereitungsspiele zaehlen bewusst nicht in die Saisonstatistik.
		# Der erste Anlauf dieser Sonde hat genau die gemessen und daraus
		# geschlossen, der Spieler bekomme keine Minuten — er bekam sie, sie
		# wurden nur nirgends gebucht.
		if str(d["spiele"][str(u["spiel"])].get("art", "")) == "test":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
			continue
		if sid == "":
			sid = _bankspieler(d, cid)
			if sid == "":
				_log("Kein geeigneter Bankspieler gefunden.")
				get_tree().quit(1)
				return
			name = Spielerfabrik.voller_name(d["spieler"][sid])
			Einsatzzeit.setzen(d, cid, sid, ZIEL)
			_log("")
			_log("Zielminuten für %s: %d — sonst für niemanden." % [name, int(ZIEL)])
			_log("")
		var vorher: float = float(d["spieler"][sid]["stats"]["saison"]["minuten"])
		Welt.partie_simulieren(str(u["spiel"]))
		Welt.spieltag_abwickeln(Welt.tag())
		Welt.wochenrhythmus(Welt.tag())
		Welt.saison_pruefen(Welt.tag())
		var dazu: float = float(d["spieler"][sid]["stats"]["saison"]["minuten"]) - vorher
		gesamt += dazu
		partien += 1
		_log("   Partie %d: %.0f Minuten" % [partien, dazu])
		if partien >= 6:
			break

	var schnitt: float = gesamt / maxf(float(partien), 1.0)
	_log("")
	_log("Im Schnitt %.1f von %d Zielminuten." % [schnitt, int(ZIEL)])
	_log("")
	_pruefe("Das Ziel wird überhaupt eingelöst", schnitt >= ZIEL * 0.5,
		"nur %.1f von %d Minuten" % [schnitt, int(ZIEL)])
	_pruefe("Und nicht maßlos übererfüllt", schnitt <= ZIEL * 1.6,
		"%.1f von %d Minuten" % [schnitt, int(ZIEL)])

	_log("")
	if fehler == 0:
		_log("— Minutensonde bestanden (%d Prüfungen) —" % geprueft)
	else:
		_log("— Minutensonde: %d FEHLER bei %d Prüfungen —" % [fehler, geprueft])
	get_tree().quit(1 if fehler > 0 else 0)

## Der schwächste Feldspieler auf der Bank.
##
## Nicht irgendein Spieler ausserhalb der Sieben: die Bank umfasst nur die
## besten vierzehn des Kaders, und wer nicht daraufsteht, kann auch mit dem
## schönsten Minutenziel nicht eingewechselt werden. Genau daran ist der
## erste Anlauf dieser Sonde gescheitert — sie mass ihren eigenen Fehler.
func _bankspieler(d: Dictionary, cid: String) -> String:
	var auf: Dictionary = d["vereine"][cid]["aufstellung"]
	var bank: Array = auf.get("bank", [])
	for i in range(bank.size() - 1, -1, -1):
		var sp: Dictionary = d["spieler"][str(bank[i])]
		if bool(sp["ist_torwart"]):
			continue
		if not (sp["verletzung"] as Dictionary).is_empty() or int(sp["sperre"]) > 0:
			continue
		return str(bank[i])
	return ""
