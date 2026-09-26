extends Node
## Hat der Trainer des Außenseiters etwas in der Hand?
##
## Gute Mannschaften sollen gegen schlechte gewinnen, und oft hoch — so ist es
## in der Bundesliga auch. Daraus darf aber nicht folgen, dass der Trainer eines
## Aufsteigers gegen Kiel nichts zu entscheiden hat. Er soll die Partie durch
## Aufstellung und Taktik eng halten können, und wenn ihm das gelingt, soll der
## Favorit es spüren und mehr Fehler machen als sonst.
##
## Diese Sonde misst genau das, und zwar gepaart: dieselbe Paarung, dieselbe
## Saat, einmal mit schlechter und einmal mit guter Vorbereitung des
## Außenseiters. Was dabei herauskommt, muss zwei Bedingungen erfüllen. Die
## Vorbereitung muss etwas bringen — sonst ist der Trainer Zuschauer. Und sie
## darf den Favoriten nicht umdrehen — sonst gewinnt nicht mehr der Bessere.
##
##     godot --headless res://werkzeuge/Aussenseitersonde.tscn -- [partien]

const SAAT := 88231
## Bis zu welchem Abstand eine Partie als eng gilt.
const ENG := 3

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var partien: int = int(args[0]) if args.size() > 0 else 400
	seed(SAAT)
	var d := Weltgenerator.erzeuge(2026, SAAT)
	seed(SAAT)
	Spielplan.erzeuge_saison(d)
	var paarung := _groesster_unterschied(d)
	if paarung.is_empty():
		_log("Keine Paarung gefunden.")
		get_tree().quit()
		return
	var favorit: String = str(paarung["favorit"])
	var aussen: String = str(paarung["aussen"])
	_log("")
	_log("=== %s (Favorit) gegen %s, %d Partien je Vorbereitung ===" % [
		str(d["vereine"][favorit]["name"]), str(d["vereine"][aussen]["name"]), partien])
	_log("")
	_log("Stammsieben %.1f gegen %.1f — %.1f Punkte Unterschied." % [
		paarung["stamm_favorit"], paarung["stamm_aussen"],
		float(paarung["stamm_favorit"]) - float(paarung["stamm_aussen"])])
	_log("")
	_log("%-22s %9s %9s %9s %9s %10s" % ["Vorbereitung", "Abstand", "eng %",
		"Siege %", "Remis %", "nervös %"])
	var schlecht := _reihe(d, favorit, aussen, partien, false)
	var gut := _reihe(d, favorit, aussen, partien, true)
	for r in [schlecht, gut]:
		var e: Dictionary = r
		_log("%-22s %9.2f %9.1f %9.1f %9.1f %10.1f" % [str(e["name"]),
			float(e["abstand"]), float(e["eng"]), float(e["siege"]),
			float(e["remis"]), float(e["nervos"])])
	_log("")
	_log("Durch gute Vorbereitung: %+.2f Tore Abstand, %+.1f Punkte enge Partien, %+.1f Punkte Siege." % [
		float(gut["abstand"]) - float(schlecht["abstand"]),
		float(gut["eng"]) - float(schlecht["eng"]),
		float(gut["siege"]) - float(schlecht["siege"])])
	_log("")
	_log("Der Favorit muss trotzdem der Favorit bleiben: %s gewinnt %.1f %% auch bei guter Gegenwehr." % [
		str(d["vereine"][favorit]["kurz"]), 100.0 - float(gut["siege"]) - float(gut["remis"])])
	get_tree().quit()

## Die ungleichste Paarung der obersten Liga.
func _groesster_unterschied(d: Dictionary) -> Dictionary:
	var lid := ""
	for l in (d["ligen"] as Dictionary).keys():
		if str(d["ligen"][l].get("kurz", "")) == "HBL":
			lid = str(l)
			break
	if lid == "":
		return {}
	var stark := ""
	var schwach := ""
	var hoch := -1.0
	var tief := 999.0
	for c in (d["ligen"][lid]["vereine"] as Array):
		var s: float = _stamm(d, str(c))
		if s > hoch:
			hoch = s
			stark = str(c)
		if s < tief:
			tief = s
			schwach = str(c)
	return {"favorit": stark, "aussen": schwach, "stamm_favorit": hoch, "stamm_aussen": tief}

func _stamm(d: Dictionary, cid: String) -> float:
	var werte: Array = []
	for sid in (d["vereine"][cid]["kader"] as Array):
		werte.append(Spielerfabrik.gesamt(d["spieler"][str(sid)]))
	if werte.is_empty():
		return 70.0
	werte.sort()
	werte.reverse()
	var summe := 0.0
	var k: int = mini(7, werte.size())
	for i in k:
		summe += float(werte[i])
	return summe / maxf(float(k), 1.0)

## Eine Messreihe: der Außenseiter spielt schlecht oder gut vorbereitet.
func _reihe(d: Dictionary, favorit: String, aussen: String, partien: int, gut: bool) -> Dictionary:
	_vorbereiten(d, aussen, gut)
	var abstand := 0.0
	var eng := 0
	var siege := 0
	var remis := 0
	var nervos := 0
	for i in range(partien):
		for sid in (d["spieler"] as Dictionary).keys():
			(d["spieler"][sid] as Dictionary)["verletzung"] = {}
		var m := {
			"id": "m_test_%d" % i, "heim": favorit, "gast": aussen,
			"tag": int(d["tag"]), "art": "liga", "wettbewerb": "l_de1",
			"gespielt": false, "tore_heim": 0, "tore_gast": 0, "zuschauer": 0,
		}
		var sim := Matchsim.new(d, m, 30011 + i * 7)
		sim.vorbereiten()
		sim.schnell_simulieren()
		var diff: int = int(sim.heim["tore"]) - int(sim.gast["tore"])
		abstand += float(diff)
		if absi(diff) <= ENG:
			eng += 1
		if diff < 0:
			siege += 1
		elif diff == 0:
			remis += 1
		if bool(sim.heim.get("nervos_gemeldet", false)):
			nervos += 1
	var n: float = maxf(float(partien), 1.0)
	return {"name": "gut vorbereitet" if gut else "schlecht vorbereitet",
		"abstand": abstand / n, "eng": float(eng) / n * 100.0,
		"siege": float(siege) / n * 100.0, "remis": float(remis) / n * 100.0,
		"nervos": float(nervos) / n * 100.0}

## Was ein Trainer vor der Partie überhaupt in der Hand hat.
func _vorbereiten(d: Dictionary, cid: String, gut: bool) -> void:
	var t: Dictionary = d["vereine"][cid]["taktik"]
	if gut:
		# Tief stehen, den Rückraum zustellen, kein Risiko, dazu die volle
		# Videoarbeit auf den Gegner.
		t["abwehr"] = "6-0"
		t["angriff"] = "positionsangriff"
		t["tempo"] = 35
		t["risiko"] = 30
		t["haerte"] = 55
		t["mentalitaet"] = "defensiv"
		Videostudium.einheiten_setzen(d, cid, 3)
	else:
		t["abwehr"] = "4-2"
		t["angriff"] = "tempospiel"
		t["tempo"] = 85
		t["risiko"] = 75
		t["haerte"] = 20
		t["mentalitaet"] = "offensiv"
		Videostudium.einheiten_setzen(d, cid, 0)
