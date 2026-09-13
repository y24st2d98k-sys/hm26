extends Node
## Prueft, ob ein nachgelieferter Datensatz einen laufenden Spielstand erreicht,
## ohne die Entwicklung aus dem Spiel zu verwerfen.
##
## Der Ablauf bildet nach, was beim Ausrollen eines Updates passiert: eine
## Karriere laeuft, die Spieler haben sich verschoben, dann kommt eine neue
## daten/kader.json. Danach muss die Korrektur aus den Daten sichtbar sein und
## die Entwicklung trotzdem drinstecken.

var fehler := 0

func _log(t: String) -> void:
	printerr(t)

func _pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		_log("   ok    %s" % text)
	else:
		fehler += 1
		_log("   FEHLT  %s" % text)

func _ready() -> void:
	var d := Weltgenerator.erzeuge(2026, 4242, true)
	d["echte_welt"] = true

	var sid := ""
	for kandidat in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][kandidat]
		if str(sp["nachname"]) == "Häfner" and str(sp["vorname"]) == "Kai":
			sid = str(kandidat)
			break
	if sid == "":
		_log("Kai Häfner nicht gefunden — der Test braucht ihn.")
		get_tree().quit(1)
		return
	var spieler: Dictionary = d["spieler"][sid]

	_log("— Ausgangslage —")
	var start: float = Spielerfabrik.gesamt(spieler)
	_log("   Kai Häfner: Stärke %.1f, Siebenmeter %.1f, Nr. %d, %s" % [
		start, float(spieler["attr"]["siebenmeter"]), int(spieler["nummer"]), str(spieler["position"])])
	_pruefe(spieler.has("datenspur"), "Datenspur ist hinterlegt")

	_log("— Drei Saisons Entwicklung (simuliert: +3 auf die Wurfattribute) —")
	for a in ["wurfkraft", "wurfpraezision", "taeuschung"]:
		spieler["attr"][a] = clampf(float(spieler["attr"][a]) + 3.0, 1.0, 20.0)
	Spielerfabrik.staerke_verwerfen(spieler)
	var entwickelt: float = Spielerfabrik.gesamt(spieler)
	_log("   Stärke nach Entwicklung: %.1f (%+.1f)" % [entwickelt, entwickelt - start])
	_pruefe(entwickelt > start + 0.5, "Entwicklung ist angekommen")

	_log("— Jetzt kommt ein neuer Datensatz —")
	var eintrag: Dictionary = {}
	for verein in Echtdaten.alle_kader().keys():
		for e in (Echtdaten.alle_kader()[verein] as Array):
			if str(e.get("nachname", "")) == "Häfner" and str(e.get("vorname", "")) == "Kai":
				eintrag = e
	if eintrag.is_empty():
		_log("Kein Datensatzeintrag für Kai Häfner.")
		get_tree().quit(1)
		return
	var alt_staerke: float = float(eintrag["staerke"])
	eintrag["staerke"] = alt_staerke + 5.0
	eintrag["attribute"] = {"siebenmeter": 11.0}
	eintrag["nummer"] = 77
	d["datenstand"] = "alter Stand"

	var bericht := Echtdaten.abgleich(d)
	_log("   Bericht: %d Spieler, %d Stärken, %d Attribute, %d Nummern" % [
		int(bericht["spieler"]), int(bericht["staerke"]),
		int(bericht["attribute"]), int(bericht["nummer"])])

	var nachher: float = Spielerfabrik.gesamt(spieler)
	_log("   Stärke nach Abgleich: %.1f (erwartet rund %.1f)" % [nachher, entwickelt + 5.0])
	_pruefe(absf(nachher - (entwickelt + 5.0)) < 1.5,
		"Datensatzänderung wurde verschoben, nicht gesetzt")
	_pruefe(nachher > start + 5.0,
		"Entwicklung aus dem Spiel ist erhalten geblieben")
	_pruefe(is_equal_approx(float(spieler["attr"]["siebenmeter"]), 11.0),
		"Einzelattribut gilt unmittelbar")
	_pruefe(int(spieler["nummer"]) == 77, "Rückennummer nachgezogen")
	_pruefe(str(d["datenstand"]) == Echtdaten.datenstand(), "Datenstand ist fortgeschrieben")

	_log("— Zweiter Abgleich ohne Änderung darf nichts tun —")
	var zweiter := Echtdaten.abgleich(d)
	_pruefe(int(zweiter["spieler"]) == 0, "Ein Abgleich ohne neue Daten ändert nichts")
	var stabil: float = Spielerfabrik.gesamt(spieler)
	_pruefe(is_equal_approx(stabil, nachher), "Die Stärke bleibt stehen")

	_log("— Erfundene Spieler bleiben unberührt —")
	var erfunden := 0
	for k in d["spieler"].keys():
		if not bool((d["spieler"][k] as Dictionary).get("echt", false)):
			erfunden += 1
	_pruefe(erfunden > 0, "Es gibt erfundene Spieler (%d)" % erfunden)

	# Datensatz wieder in den Auslieferungszustand, sonst schleppt der naechste
	# Lauf im selben Prozess die Testwerte mit.
	eintrag["staerke"] = alt_staerke
	Echtdaten.neu_laden()

	_log("— Kaderpflege darf beim Sichern nichts wegwerfen —")
	var roh := {"vorname": "Kai", "nachname": "Häfner", "position": "RR", "nation": "de",
		"alter": 36, "staerke": 84, "nummer": 34, "stammschuetze": true,
		"attribute": {"siebenmeter": 15.6, "unsinn": 12.0}}
	var normiert := Kaderpflege.normieren(roh)
	_pruefe(int(normiert.get("nummer", 0)) == 34, "Rückennummer überlebt das Normieren")
	_pruefe(bool(normiert.get("stammschuetze", false)), "Siebenmeterschütze überlebt das Normieren")
	_pruefe((normiert.get("attribute", {}) as Dictionary).has("siebenmeter"),
		"Gesetztes Attribut überlebt das Normieren")
	_pruefe(not (normiert.get("attribute", {}) as Dictionary).has("unsinn"),
		"Ein erfundener Attributname fällt raus")
	var leer := Kaderpflege.normieren({"vorname": "A", "nachname": "B", "position": "LA",
		"nation": "de", "alter": 25, "staerke": 60})
	_pruefe(not leer.has("attribute"), "Ohne gesetzte Attribute bleibt das Feld weg")
	_pruefe(not leer.has("nummer"), "Ohne Nummer bleibt das Feld weg")

	_log("")
	if fehler == 0:
		_log("— Datenabgleich bestanden —")
	else:
		_log("— %d Prüfungen fehlgeschlagen —" % fehler)
	get_tree().quit(1 if fehler > 0 else 0)
