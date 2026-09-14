extends Node
## Die beiden Wege, auf denen der Trainer selbst verhandelt: Anfrage bei einem
## abgebenden Verein und Partnersuche fuer einen freien Werbeplatz.
##
## Beides sind Gespraeche mit Gegenueber, und beide koennen schiefgehen. Der
## Test prueft vor allem, dass sie sich nicht ausnutzen lassen: keine Anfrage
## im Tagestakt, keine Nachverhandlung ohne Risiko, kein Angebot fuer einen
## Platz, der schon vergeben ist.

var fehler := 0
## Ein Laufzeitfehler bricht die Funktion ab, in der er passiert — die
## restlichen Pruefungen laufen dann nie, und ohne diese Marke haette der Test
## am Ende trotzdem "bestanden" gemeldet. Genau das ist beim ersten Lauf
## passiert.
var durchgelaufen := false

func _log(t: String) -> void:
	printerr(t)

func _pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		_log("   ok    %s" % text)
	else:
		fehler += 1
		_log("   FEHLT  %s" % text)

func _ready() -> void:
	Welt.neues_spiel(_erster_verein(), {"vorname": "Test", "nachname": "Trainer",
		"hintergrund": "taktiker"}, 4711)
	var d := Welt.daten
	var mein: String = Welt.mein_verein_id
	_log("Mein Verein: %s" % str(d["vereine"][mein]["name"]))

	_anfrage(d, mein)
	_log("")
	_sponsoren(d, mein)

	_log("")
	if not durchgelaufen:
		_log("— ABGEBROCHEN: der Test ist nicht bis zum Ende gekommen —")
		get_tree().quit(1)
		return
	if fehler == 0:
		_log("— Verhandlungen bestanden —")
	else:
		_log("— %d Prüfungen fehlgeschlagen —" % fehler)
	get_tree().quit(1 if fehler > 0 else 0)

# ---------------------------------------------------------------- Anfrage ---

func _anfrage(d: Dictionary, mein: String) -> void:
	_log("— Anfrage bei einem abgebenden Verein —")
	var fremd := ""
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["verein"]) != "" and str(sp["verein"]) != mein \
				and not bool(sp.get("jugendspieler", false)) \
				and not Transfermarkt.unverkaeuflich(d, str(sid)):
			fremd = str(sid)
			break
	if fremd == "":
		_pruefe(false, "Es gibt einen fremden Spieler zum Anfragen")
		return
	var sp2: Dictionary = d["spieler"][fremd]
	_log("   Ziel: %s (%s)" % [Spielerfabrik.voller_name(sp2),
		str(d["vereine"][str(sp2["verein"])]["name"])])

	_pruefe(Transfermarkt.anfrage_moeglich(d, fremd) == 0, "Vor der ersten Anfrage ist nichts gesperrt")
	var erste := Transfermarkt.anfrage(d, fremd, mein)
	_log("   Antwort: %s" % str(erste["text"]))
	_pruefe(bool(erste["ok"]), "Die Anfrage kommt durch")
	_pruefe(erste.has("haltung"), "Der Verein nennt eine Haltung")

	var zweite := Transfermarkt.anfrage(d, fremd, mein)
	_pruefe(not bool(zweite["ok"]), "Eine zweite Anfrage am selben Tag wird abgewiesen")
	_pruefe(Transfermarkt.anfrage_moeglich(d, fremd) > 0, "Die Sperre läuft")

	# Die genannte Forderung muss dieselbe sein, die die Verhandlung anlegt.
	# Sonst sagt die Anfrage etwas anderes, als der Verein hinterher tut.
	if str(erste.get("haltung", "")) != "unverkaeuflich":
		var genannt: float = float(erste["forderung"])
		var echt: float = Transfermarkt.verkaufsschwelle(d, fremd)
		_pruefe(is_equal_approx(genannt, echt),
			"Die genannte Forderung ist die, die auch gilt (%s gegen %s)" % [
				Stil.geld(genannt), Stil.geld(echt)])
		_pruefe(genannt > 0.0, "Die Forderung ist eine Zahl über null")

	var eigener := ""
	for sid2 in d["vereine"][mein]["kader"]:
		eigener = str(sid2)
		break
	_pruefe(not bool(Transfermarkt.anfrage(d, eigener, mein)["ok"]),
		"Nach einem eigenen Spieler fragt man nicht an")

# -------------------------------------------------------------- Sponsoren ---

func _sponsoren(d: Dictionary, mein: String) -> void:
	_log("— Partnersuche und Nachverhandlung —")
	var v: Dictionary = d["vereine"][mein]
	# Einen Platz freiraeumen, damit es etwas zu suchen gibt.
	var laufende: Array = v["sponsoren"]
	if laufende.is_empty():
		_pruefe(false, "Der Verein hat Partner, von denen einer weichen kann")
		return
	var platz: String = str((laufende[0] as Dictionary)["art"])
	laufende.remove_at(0)
	v["sponsorangebote"] = []
	_log("   Freigeräumt: %s" % platz)
	_pruefe(Sponsoren.freie_plaetze(d, mein).has(platz), "Der Platz gilt als frei")

	# Einmal fragen legt die Merkliste der Versuche an; ohne sie gaebe es
	# darunter nichts zurueckzusetzen.
	Sponsoren.akquise_sperre(d, mein, platz)
	var chance: float = Sponsoren.akquise_chance(d, mein, platz)
	_log("   Aussicht: %.0f %%" % (chance * 100.0))
	_pruefe(chance > 0.0 and chance < 1.0, "Die Aussicht liegt zwischen null und sicher")

	# So lange versuchen, bis einer anbeisst — die Sperre dazwischen wegnehmen,
	# denn geprueft wird hier die Verhandlung, nicht die Geduld.
	var angebot := {}
	for versuch in range(40):
		(v["sponsorakquise"] as Dictionary)[platz] = -9999
		var erg := Sponsoren.akquise(d, mein, platz)
		if bool(erg["ok"]):
			angebot = erg["angebot"]
			_log("   Nach %d Versuch(en): %s" % [versuch + 1, str(erg["grund"])])
			break
	if angebot.is_empty():
		_pruefe(false, "Die Akquise findet irgendwann jemanden")
		return
	_pruefe(true, "Die Akquise findet einen Partner")
	(v["sponsorakquise"] as Dictionary)[platz] = -9999
	_pruefe(not bool(Sponsoren.akquise(d, mein, platz)["ok"]),
		"Für einen Platz mit offenem Angebot wird nicht zweimal gesucht")

	var start: float = float(angebot["wert"])
	var bescheiden := Sponsoren.nachverhandeln(d, mein, 0, start * 1.05, int(angebot["jahre"]))
	_log("   Bescheiden (+5 %%): %s" % str(bescheiden["grund"]))
	_pruefe(bool(bescheiden["ok"]), "Eine bescheidene Nachforderung geht durch")
	_pruefe(float((Sponsoren.offene_angebote(d, mein)[0] as Dictionary)["wert"]) > start,
		"Der Jahreswert ist gestiegen")

	var jetzt: float = float((Sponsoren.offene_angebote(d, mein)[0] as Dictionary)["wert"])
	var dreist := Sponsoren.nachverhandeln(d, mein, 0, jetzt * 3.0, 1)
	_log("   Dreist (dreifach): %s" % str(dreist["grund"]))
	_pruefe(not bool(dreist["ok"]), "Eine dreiste Nachforderung geht nicht durch")

	# Nach zwei Runden ist Schluss, egal wie das Angebot ausging.
	if not Sponsoren.offene_angebote(d, mein).is_empty():
		var dritte := Sponsoren.nachverhandeln(d, mein, 0, jetzt, 2)
		_pruefe(not bool(dritte["ok"]), "Nach zwei Runden ist Schluss")

	var vorher: int = (v["sponsoren"] as Array).size()
	if not Sponsoren.offene_angebote(d, mein).is_empty():
		var erg2 := Sponsoren.annehmen(d, mein, 0)
		_pruefe(bool(erg2["ok"]), "Das Angebot lässt sich unterschreiben")
		_pruefe((v["sponsoren"] as Array).size() == vorher + 1, "Der Partner steht unter Vertrag")
		_pruefe(not Sponsoren.freie_plaetze(d, mein).has(platz), "Der Platz ist nicht mehr frei")
	durchgelaufen = true

func _erster_verein() -> String:
	var d := Weltgenerator.erzeuge(2026, 4711)
	return str(d["ligen"]["l_de1"]["vereine"][0])
