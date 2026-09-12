extends Node
## Zeigt, wie vollständig die Welt mit echten Daten gefüllt ist — und wo
## erfundene Spieler einspringen. Damit ist sofort sichtbar, welche Vereine
## in daten/kader.json noch Arbeit brauchen.

func _log(text: String) -> void:
	printerr(text)

func _ready() -> void:
	if not Echtdaten.verfuegbar():
		_log("Kein Datensatz gefunden — es würde eine erfundene Welt erzeugt.")
		get_tree().quit()
		return
	_log("Datenstand Ligen: %s" % Echtdaten.stand())
	_log("Datenstand Kader: %s" % Echtdaten.kader_stand())
	_log("")
	var d := Weltgenerator.erzeuge(2026, 4242, true)
	_log("Welt: %d Vereine, %d Spieler" % [d["vereine"].size(), d["spieler"].size()])
	_log("")
	_log("%-30s %-14s %8s %8s %10s %10s" % ["Liga", "Nation", "Vereine", "davon echt", "Spieler", "davon echt"])
	_log("%s" % "-".repeat(88))
	var summe_v := 0
	var summe_ve := 0
	var summe_s := 0
	var summe_se := 0
	for z in Echtdaten.abdeckung(d):
		_log("%-30s %-14s %8d %8d %10d %10d" % [
			str(z["liga"]).substr(0, 30), str(d["nationen"][z["nation"]]["name"]),
			int(z["vereine"]), int(z["vereine_echt"]), int(z["spieler"]), int(z["spieler_echt"])])
		summe_v += int(z["vereine"])
		summe_ve += int(z["vereine_echt"])
		summe_s += int(z["spieler"])
		summe_se += int(z["spieler_echt"])
	_log("%s" % "-".repeat(88))
	_log("%-30s %-14s %8d %8d %10d %10d" % ["Gesamt", "", summe_v, summe_ve, summe_s, summe_se])
	_log("")
	_log("Vereine mit echten Spielern (Kader wird auf Sollstärke ergänzt):")
	var vereine: Array = d["vereine"].keys()
	vereine.sort_custom(func(a, b): return _echte(d, a) > _echte(d, b))
	for cid in vereine:
		var echt: int = _echte(d, cid)
		if echt <= 0:
			continue
		var v: Dictionary = d["vereine"][cid]
		_log("   %-34s %2d von %2d Spielern echt" % [str(v["name"]), echt, (v["kader"] as Array).size()])
	_log("")
	_log("Stichprobe THW Kiel:")
	for cid2 in d["vereine"].keys():
		if str(d["vereine"][cid2]["name"]) != "THW Kiel":
			continue
		var v2: Dictionary = d["vereine"][cid2]
		_log("   %s, %s (%s Plätze), Ruf %d" % [v2["name"], v2["halle"]["name"],
			Stil.zahl(int(v2["halle"]["kapazitaet"])), int(float(v2["ruf"]))])
		for sid in Welt_kader(d, cid2):
			var sp: Dictionary = d["spieler"][sid]
			_log("   %-4s %-30s %-16s %2d Jahre  Stärke %2d  %s" % [
				str(sp["position"]), Spielerfabrik.voller_name(sp),
				Namen.KULTUR_NAME.get(str(sp["nation"]), "?"), int(sp["alter"]),
				int(Spielerfabrik.gesamt(sp)), "echt" if bool(sp.get("echt", false)) else "erfunden"])
	get_tree().quit()

func _echte(d: Dictionary, cid: String) -> int:
	var z := 0
	for sid in d["vereine"][cid]["kader"]:
		if bool(d["spieler"][sid].get("echt", false)):
			z += 1
	return z

func Welt_kader(d: Dictionary, cid: String) -> Array:
	var liste: Array = (d["vereine"][cid]["kader"] as Array).duplicate()
	liste.sort_custom(func(a, b):
		var pa: int = Spielerfabrik.POSITIONEN.find(str(d["spieler"][a]["position"]))
		var pb: int = Spielerfabrik.POSITIONEN.find(str(d["spieler"][b]["position"]))
		if pa != pb:
			return pa < pb
		return Spielerfabrik.gesamt(d["spieler"][a]) > Spielerfabrik.gesamt(d["spieler"][b]))
	return liste
