extends Node
## Steuert die Einsatzrolle wirklich die Spielzeit in der Zweiten?
##
## Die Rolle ist eine Zusage an den Trainer: "gesetzt" heißt, der Spieler steht
## in den ersten Sieben und spielt rund zweiundfünfzig Minuten. Eine Zusage,
## die eine Sonde nicht nachprüft, ist eine Hoffnung. Hier steht sie auf dem
## Prüfstand — zusammen mit der Frage, ob ein Akademiespieler wirklich nichts
## verdient.

const SAAT := 33991

var fehler: int = 0

func _log(t: String) -> void:
	printerr(t)

func _pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		_log("   ok    %s" % text)
	else:
		fehler += 1
		_log("   FEHLER %s" % text)

func _ready() -> void:
	var welt := Weltgenerator.erzeuge(2026, SAAT)
	var cid: String = str(welt["ligen"]["l_de1"]["vereine"][0])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Ein", "nachname": "Satz"}, SAAT)
	var d: Dictionary = Welt.daten
	_log("")
	_log("=== Einsatzplanung der Zweiten ===")
	_log("")

	# --- Akademie: kein Gehalt ---
	var jugend: Array = d["vereine"][cid].get("jugend", [])
	_pruefe(not jugend.is_empty(), "Der Verein hat eine Akademie (%d Spieler)" % jugend.size())
	var mit_gehalt := 0
	for sid in jugend:
		if float((d["spieler"][str(sid)]["vertrag"] as Dictionary).get("gehalt", 0.0)) > 0.0:
			mit_gehalt += 1
	_pruefe(mit_gehalt == 0, "Kein Akademiespieler hat ein Gehalt (%d mit)" % mit_gehalt)

	var kandidaten := Zweite.kandidaten(d, cid)
	_pruefe(kandidaten.size() >= 8, "Genug Kandidaten für die Zweite (%d)" % kandidaten.size())
	if kandidaten.size() < 8:
		_ende()
		return

	# --- Der Schwächste, gesetzt, steht vorn ---
	var nach_staerke: Array = Spielerfabrik.nach_staerke(d, kandidaten.duplicate())
	var feldspieler: Array = []
	for sid2 in nach_staerke:
		if not bool(d["spieler"][str(sid2)]["ist_torwart"]):
			feldspieler.append(str(sid2))
	var schwaechster: String = str(feldspieler[feldspieler.size() - 1])
	for sid3 in kandidaten:
		Zweite.rolle_setzen(d, str(sid3), "normal")
	var ohne := Zweite.aufgebot(d, cid)
	_pruefe(ohne.find(schwaechster) < 0 or ohne.find(schwaechster) >= 7,
		"Ohne Vorgabe steht der Schwächste nicht in den ersten Sieben (Platz %d)" % ohne.find(schwaechster))

	Zweite.rolle_setzen(d, schwaechster, "gesetzt")
	var mit := Zweite.aufgebot(d, cid)
	var platz: int = mit.find(schwaechster)
	_pruefe(platz >= 0 and platz < 7,
		"Als gesetzt steht er in den ersten Sieben (Platz %d)" % platz)

	# --- "gar nicht" heißt gar nicht ---
	Zweite.rolle_setzen(d, schwaechster, "nie")
	var ohne2 := Zweite.aufgebot(d, cid)
	_pruefe(ohne2.find(schwaechster) < 0, "Als „gar nicht“ steht er nicht im Aufgebot")
	_pruefe(Zweite.kandidaten(d, cid).find(schwaechster) < 0,
		"Als „gar nicht“ ist er auch kein Kandidat mehr")

	# --- "selten" rangiert hinter "Rotation" ---
	#
	# Geprueft wird der Unterschied, nicht der Zustand: derselbe Spieler
	# einmal als Rotation und einmal als selten. Steht er beide Male nicht im
	# Aufgebot, sagt der Vergleich nichts — und genau so ist diese Pruefung
	# beim ersten Versuch durchgegangen, ohne etwas zu pruefen.
	Zweite.rolle_setzen(d, schwaechster, "normal")
	var staerkster: String = str(feldspieler[0])
	Zweite.rolle_setzen(d, staerkster, "normal")
	var vorher := Zweite.aufgebot(d, cid)
	var p_vorher: int = vorher.find(staerkster)
	_pruefe(p_vorher >= 0 and p_vorher < 7,
		"Der Staerkste steht als Rotation in den ersten Sieben (Platz %d)" % p_vorher)
	Zweite.rolle_setzen(d, staerkster, "selten")
	var nachher := Zweite.aufgebot(d, cid)
	var p_nachher: int = nachher.find(staerkster)
	_pruefe(p_nachher < 0 or p_nachher >= 7,
		"Als selten steht derselbe Spieler nicht mehr in den ersten Sieben (Platz %d)" % p_nachher)
	_pruefe(p_nachher != p_vorher,
		"Die Rolle hat den Platz wirklich verschoben (%d auf %d)" % [p_vorher, p_nachher])

	# --- Alter Spielstand: der Sperrschalter wirkt weiter ---
	d["spieler"][schwaechster].erase("zweite_rolle")
	d["spieler"][schwaechster]["nicht_zweite"] = true
	_pruefe(Zweite.rolle(d, schwaechster) == "nie",
		"Ein alter Spielstand mit nicht_zweite ergibt die Rolle „gar nicht“")

	_ende()

func _ende() -> void:
	_log("")
	if fehler == 0:
		_log("— Einsatzplanung bestanden —")
	else:
		_log("— Einsatzplanung: %d Fehler —" % fehler)
	get_tree().quit()
