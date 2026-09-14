extends Node
## Kommen die hinterlegten Ansetzungen im Spiel an — und faellt das Spiel
## zurueck auf die Auslosung, wenn der Plan nicht aufgeht?
##
## Der zweite Teil ist der wichtigere. Ein Spielplan, der sich nicht zu einer
## vollstaendigen Doppelrunde schliessen laesst, darf keine halbe Saison
## erzeugen, in der einzelne Vereine zwanzig und andere vierzig Spiele haben.

var fehler := 0
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
	var d := Weltgenerator.erzeuge(2026, 4242, true)
	Spielplan.erzeuge_saison(d)
	var lid := "l_de1"
	var liga: Dictionary = d["ligen"][lid]
	_log("Liga: %s" % str(liga["name"]))

	_log("— Die hinterlegten Partien stehen im Spielplan —")
	var hinterlegt: Array = Spielplanpflege.partien(str(liga["name"]))
	_pruefe(not hinterlegt.is_empty(), "Es sind Ansetzungen hinterlegt (%d)" % hinterlegt.size())
	var nach_name := {}
	for cid in liga["vereine"]:
		nach_name[str(d["vereine"][cid]["name"])] = str(cid)
	var getroffen := 0
	for e in hinterlegt:
		var heim: String = str(nach_name.get(str(e["heim"]), ""))
		var gast: String = str(nach_name.get(str(e["gast"]), ""))
		var tag: int = int(e["spieltag"])
		var gefunden := false
		for mid in d["spiele"].keys():
			var m: Dictionary = d["spiele"][mid]
			if str(m.get("wettbewerb", "")) == lid and int(m["runde"]) == tag \
					and str(m["heim"]) == heim and str(m["gast"]) == gast:
				gefunden = true
				break
		if gefunden:
			getroffen += 1
		else:
			_log("      fehlt: %d. Spieltag %s gegen %s" % [tag, str(e["heim"]), str(e["gast"])])
	_pruefe(getroffen == hinterlegt.size(),
		"Alle %d hinterlegten Partien stehen am richtigen Spieltag (%d gefunden)" % [
			hinterlegt.size(), getroffen])

	_log("— Die ergänzte Runde ist trotzdem eine saubere Doppelrunde —")
	_doppelrunde_pruefen(d, lid)

	_log("— Ein Plan, der nicht aufgeht, wird verworfen —")
	var teams: Array = (liga["vereine"] as Array).duplicate()
	var a: String = str(teams[0])
	var b: String = str(teams[1])
	var c: String = str(teams[2])
	# Derselbe Verein zweimal am selben Spieltag: das darf nicht durchgehen.
	var kaputt: Array = [
		{"spieltag": 1, "heim": str(d["vereine"][a]["name"]), "gast": str(d["vereine"][b]["name"])},
		{"spieltag": 1, "heim": str(d["vereine"][a]["name"]), "gast": str(d["vereine"][c]["name"])},
	]
	_pruefe(Spielplan.echte_runden(d, lid, teams).size() > 0,
		"Der echte Plan geht auf")
	_mit_plan(str(liga["name"]), kaputt, func():
		_pruefe(Spielplan.echte_runden(d, lid, teams).is_empty(),
			"Doppelter Einsatz am selben Spieltag wird verworfen"))
	var unbekannt: Array = [{"spieltag": 1, "heim": "TSV Erfunden", "gast": str(d["vereine"][b]["name"])}]
	_mit_plan(str(liga["name"]), unbekannt, func():
		_pruefe(Spielplan.echte_runden(d, lid, teams).is_empty(),
			"Ein unbekannter Vereinsname wird verworfen"))
	var doppelt: Array = [
		{"spieltag": 1, "heim": str(d["vereine"][a]["name"]), "gast": str(d["vereine"][b]["name"])},
		{"spieltag": 3, "heim": str(d["vereine"][a]["name"]), "gast": str(d["vereine"][b]["name"])},
	]
	_mit_plan(str(liga["name"]), doppelt, func():
		_pruefe(Spielplan.echte_runden(d, lid, teams).is_empty(),
			"Dieselbe Paarung zweimal wird verworfen"))
	var zu_spaet: Array = [
		{"spieltag": 99, "heim": str(d["vereine"][a]["name"]), "gast": str(d["vereine"][b]["name"])},
	]
	_mit_plan(str(liga["name"]), zu_spaet, func():
		_pruefe(Spielplan.echte_runden(d, lid, teams).is_empty(),
			"Ein Spieltag außerhalb der Saison wird verworfen"))

	_log("— Ein vollständiger Plan gilt unverändert —")
	# Der Fall, auf den es ankommt: wer den offiziellen Spielplan einspielt,
	# will ihn genau so haben und nicht nachgebaut.
	var vorbild := Spielplan.doppelrunde(teams.duplicate())
	var voll: Array = []
	for r in range(vorbild.size()):
		for paar in vorbild[r]:
			voll.append({"spieltag": r + 1,
				"heim": str(d["vereine"][str(paar[0])]["name"]),
				"gast": str(d["vereine"][str(paar[1])]["name"])})
	_mit_plan(str(liga["name"]), voll, func():
		var runden := Spielplan.echte_runden(d, lid, teams)
		_pruefe(runden.size() == vorbild.size(),
			"Der vollständige Plan liefert %d Spieltage" % runden.size())
		var gleich := true
		for r2 in range(mini(runden.size(), vorbild.size())):
			var soll_paare := {}
			for paar2 in vorbild[r2]:
				soll_paare["%s>%s" % [str(paar2[0]), str(paar2[1])]] = true
			for paar3 in runden[r2]:
				if not soll_paare.has("%s>%s" % [str(paar3[0]), str(paar3[1])]):
					gleich = false
		_pruefe(gleich, "Jede Partie steht unverändert an ihrem Spieltag"))

	_log("— Ohne hinterlegten Plan wird ausgelost —")
	_mit_plan(str(liga["name"]), [], func():
		_pruefe(Spielplan.echte_runden(d, lid, teams).is_empty(),
			"Ohne Ansetzungen liefert echte_runden() nichts"))
	Echtdaten.neu_laden()

	durchgelaufen = true
	_log("")
	if not durchgelaufen:
		_log("— ABGEBROCHEN —")
		get_tree().quit(1)
		return
	if fehler == 0:
		_log("— Spielplan bestanden —")
	else:
		_log("— %d Prüfungen fehlgeschlagen —" % fehler)
	get_tree().quit(1 if fehler > 0 else 0)

## Setzt einen Plan ein, fuehrt die Pruefung aus und raeumt wieder auf.
func _mit_plan(liganame: String, partien: Array, pruefung: Callable) -> void:
	var eigene: Dictionary = Spielplanpflege.eigene()
	var vorher: Variant = eigene.get(liganame, null)
	if partien.is_empty():
		# Ein leerer eigener Plan bedeutet "geloescht" — fuer den Test muss
		# aber auch der mitgelieferte Datensatz aus dem Weg.
		eigene[liganame] = [{"spieltag": 0, "heim": "", "gast": ""}]
		pruefung.call()
	else:
		eigene[liganame] = partien
		pruefung.call()
	if vorher == null:
		eigene.erase(liganame)
	else:
		eigene[liganame] = vorher

func _doppelrunde_pruefen(d: Dictionary, lid: String) -> void:
	var liga: Dictionary = d["ligen"][lid]
	var teams: Array = liga["vereine"]
	var soll: int = (teams.size() - 1) * 2
	var heimspiele := {}
	var auswaerts := {}
	var paarungen := {}
	var je_tag := {}
	for cid in teams:
		heimspiele[str(cid)] = 0
		auswaerts[str(cid)] = 0
	var gesamt := 0
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m.get("wettbewerb", "")) != lid or str(m["art"]) != "liga":
			continue
		gesamt += 1
		var h: String = str(m["heim"])
		var g: String = str(m["gast"])
		heimspiele[h] = int(heimspiele[h]) + 1
		auswaerts[g] = int(auswaerts[g]) + 1
		var schluessel: String = "%s>%s" % [h, g]
		paarungen[schluessel] = int(paarungen.get(schluessel, 0)) + 1
		var tag: int = int(m["runde"])
		if not je_tag.has(tag):
			je_tag[tag] = {}
		var belegt: Dictionary = je_tag[tag]
		if belegt.has(h) or belegt.has(g):
			_pruefe(false, "Doppelter Einsatz am %d. Spieltag" % tag)
		belegt[h] = true
		belegt[g] = true
	_pruefe(gesamt == teams.size() * soll / 2,
		"%d Partien insgesamt (erwartet %d)" % [gesamt, teams.size() * soll / 2])
	_pruefe(liga["spieltage"] == soll, "%d Spieltage" % int(liga["spieltage"]))
	var heim_ok := true
	for cid2 in teams:
		if int(heimspiele[str(cid2)]) != teams.size() - 1 or int(auswaerts[str(cid2)]) != teams.size() - 1:
			heim_ok = false
			_log("      %s: %d Heim, %d Auswärts" % [str(d["vereine"][cid2]["name"]),
				int(heimspiele[str(cid2)]), int(auswaerts[str(cid2)])])
	_pruefe(heim_ok, "Jeder Verein hat %d Heim- und %d Auswärtsspiele" % [
		teams.size() - 1, teams.size() - 1])
	var einmal := true
	for k in paarungen.keys():
		if int(paarungen[k]) != 1:
			einmal = false
	_pruefe(einmal, "Jede Paarung kommt genau einmal vor")
	_pruefe(je_tag.size() == soll, "Es gibt %d bespielte Spieltage" % je_tag.size())
