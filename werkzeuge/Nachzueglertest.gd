extends Node
## Bleibt eine übersprungene eigene Partie liegen?
##
## Partien werden nur an ihrem eigenen Tag angesetzt. Was einmal übersprungen
## ist, bleibt ungespielt, und in der Tabelle fehlt für immer ein Ergebnis.
## Überspringen lässt sich seit dem Anpfifffenster: wer davor speichert und neu
## lädt oder zum Startbildschirm geht, lässt die Partie stehen.
##
## Dieser Test baut genau diesen Fall nach — Unterbrechung entgegennehmen, die
## Partie nicht spielen, weiterschalten — und prüft, dass sie danach trotzdem
## an die Reihe kommt.

var fehler: int = 0

func _pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("   ok: %s" % text)
	else:
		fehler += 1
		print("   FEHLER: %s" % text)

func _ready() -> void:
	var vorschau := Weltgenerator.erzeuge(2026, 5150)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(5150)
	Welt.neues_spiel(cid, {"vorname": "Nach", "nachname": "Zügler"}, 5150)
	print("— Übersprungene eigene Partie —")

	# Bis zur ersten eigenen Partie schalten, ohne sie zu spielen.
	var mid := ""
	for i in range(400):
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			mid = str(u["spiel"])
			break
	_pruefe(mid != "", "eine eigene Partie wird fällig")
	if mid == "":
		get_tree().quit()
		return
	var tag_der_partie: int = Welt.tag()
	print("   Partie %s am Tag %d — sie wird bewusst nicht gespielt." % [mid, tag_der_partie])

	# Nicht spielen, einfach weiterschalten: die Partie muss erneut kommen.
	var u2 := Welt.tag_weiter()
	_pruefe(u2.has("art") and str(u2["art"]) == "eigenes_spiel" and str(u2["spiel"]) == mid,
		"dieselbe Partie wird beim nächsten Weiterschalten erneut fällig")
	_pruefe(Welt.tag() == tag_der_partie, "der Tag ist dabei nicht weitergelaufen")

	# Jetzt simulieren und weiterschalten: sie darf nicht noch einmal kommen.
	Welt.partie_simulieren(mid)
	Welt.spieltag_abwickeln(Welt.tag())
	var u3 := Welt.tag_weiter()
	_pruefe(not (u3.has("art") and str(u3["art"]) == "eigenes_spiel" and str(u3["spiel"]) == mid),
		"nach dem Spielen kommt sie nicht wieder")
	_pruefe(bool(Welt.partie(mid)["gespielt"]), "die Partie ist als gespielt vermerkt")

	# Und über eine halbe Saison darf keine eigene Partie ungespielt bleiben.
	for j in range(160):
		var u4 := Welt.tag_weiter()
		if u4.has("art") and str(u4["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u4["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
	var offen := 0
	for m in Welt.daten["spiele"].keys():
		var p: Dictionary = Welt.daten["spiele"][m]
		if bool(p["gespielt"]) or int(p["tag"]) > Welt.tag():
			continue
		if str(p["heim"]) == Welt.mein_verein_id or str(p["gast"]) == Welt.mein_verein_id:
			offen += 1
	_pruefe(offen == 0, "nach 160 Tagen ist keine eigene Partie liegengeblieben (%d offen)" % offen)

	print("— %s —" % ("Nachzüglertest bestanden" if fehler == 0 else "%d Fehler" % fehler))
	get_tree().quit()
