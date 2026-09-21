extends Node
## Woraus besteht ein Spielstand — und was davon muss wirklich hinein?
##
## Gemessen kostet der wöchentliche Sicherungspunkt 1,1 Sekunden und liegt
## mitten im Montag, also mitten im Knopfdruck. Das sind 19 der 22 Sekunden,
## die der Wochenrhythmus über 120 Tage braucht. Bevor man daran etwas dreht,
## muss man wissen, wo die Bytes liegen: 7,4 MB stehen schon am ersten Tag da,
## 10,7 MB nach 120 Tagen.
##
## Diese Sonde wiegt jeden Zweig einzeln.

func _log(t: String) -> void:
	printerr(t)

func _groesse(wert: Variant) -> int:
	return var_to_bytes(wert).size()

func _ready() -> void:
	seed(4242)
	var vorschau := Weltgenerator.erzeuge(2026, 4242)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(4242)
	Welt.neues_spiel(cid, {"vorname": "Spiel", "nachname": "Stand"}, 4242)
	_bericht("Am ersten Tag")

	for _i in range(140):
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
	_bericht("Nach 140 Tagen")
	get_tree().quit()

func _bericht(titel: String) -> void:
	var d: Dictionary = Welt.daten
	var gesamt: int = _groesse(d)
	_log("")
	_log("=== %s: %.2f MB ===" % [titel, float(gesamt) / 1048576.0])
	var zweige: Array = []
	for k in d.keys():
		zweige.append({"name": str(k), "bytes": _groesse(d[k])})
	zweige.sort_custom(func(a, b): return int(a["bytes"]) > int(b["bytes"]))
	for z in zweige.slice(0, 10):
		_log("   %-18s %8.2f MB   (%4.1f %%)" % [str(z["name"]),
			float(z["bytes"]) / 1048576.0, float(z["bytes"]) / float(gesamt) * 100.0])
	_spielerzweige(d)
	_spielzweige(d)

## Was an einem einzelnen Spieler hängt — dreitausend Mal.
func _spielerzweige(d: Dictionary) -> void:
	var spieler: Dictionary = d.get("spieler", {})
	if spieler.is_empty():
		return
	var felder := {}
	var n := 0
	for sid in spieler.keys():
		var sp: Dictionary = spieler[sid]
		for f in sp.keys():
			felder[str(f)] = int(felder.get(str(f), 0)) + _groesse(sp[f])
		n += 1
		if n >= 400:
			break
	var liste: Array = []
	for f2 in felder.keys():
		liste.append({"name": str(f2), "bytes": int(felder[f2])})
	liste.sort_custom(func(a, b): return int(a["bytes"]) > int(b["bytes"]))
	var summe := 0
	for e in liste:
		summe += int(e["bytes"])
	_log("   davon je Spieler (Stichprobe %d, zusammen %.2f MB hochgerechnet):" % [
		n, float(summe) / float(n) * float(spieler.size()) / 1048576.0])
	for e2 in liste.slice(0, 6):
		_log("      %-16s %6.1f Byte je Spieler" % [str(e2["name"]),
			float(e2["bytes"]) / float(n)])

## Und was an einer Partie hängt.
func _spielzweige(d: Dictionary) -> void:
	var spiele: Dictionary = d.get("spiele", {})
	if spiele.is_empty():
		return
	var mit := 0
	var ohne := 0
	var bytes_mit := 0
	var bytes_ohne := 0
	for mid in spiele.keys():
		var m: Dictionary = spiele[mid]
		var b: int = _groesse(m)
		if not (m.get("bericht", {}) as Dictionary).is_empty():
			mit += 1
			bytes_mit += b
		else:
			ohne += 1
			bytes_ohne += b
	_log("   Partien: %d mit Bericht (%.1f kB je Stück), %d ohne (%.1f kB)" % [
		mit, float(bytes_mit) / maxf(float(mit), 1.0) / 1024.0,
		ohne, float(bytes_ohne) / maxf(float(ohne), 1.0) / 1024.0])
	# Und woraus ein Bericht besteht. Fremde Partien werden schlank gespeichert
	# — die Frage ist, was an einem schlanken Bericht noch schwer ist.
	var beispiel: Dictionary = {}
	for mid2 in spiele.keys():
		var m2: Dictionary = spiele[mid2]
		var b2: Dictionary = m2.get("bericht", {})
		if not b2.is_empty() and bool(b2.get("knapp", false)):
			beispiel = b2
			break
	if beispiel.is_empty():
		return
	var teile: Array = []
	for k in beispiel.keys():
		teile.append({"name": str(k), "bytes": _groesse(beispiel[k])})
	teile.sort_custom(func(a, b): return int(a["bytes"]) > int(b["bytes"]))
	_log("   ein schlanker Bericht (%.1f kB):" % (float(_groesse(beispiel)) / 1024.0))
	for t2 in teile.slice(0, 5):
		_log("      %-16s %6.2f kB" % [str(t2["name"]), float(t2["bytes"]) / 1024.0])
