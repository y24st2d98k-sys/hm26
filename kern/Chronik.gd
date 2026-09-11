class_name Chronik
extends RefCounted
## Vereinsgeschichte, Rekorde, Rivalitaeten und Legenden.
##
## Die emotionale Bindung von Hallenherz haengt an drei Dingen: an Rekorden, die man
## selbst aufgestellt hat, an Rivalitaeten, die mit jedem Duell schaerfer werden, und
## an Spielern, die genug fuer den Verein geleistet haben, um Legende zu werden.

static func spiel_eintragen(d: Dictionary, m: Dictionary) -> void:
	_rekorde_pruefen(d, m)
	_rivalitaet_pflegen(d, m)
	_legenden_pflegen(d, m)

static func _rekorde_pruefen(d: Dictionary, m: Dictionary) -> void:
	var rekorde: Dictionary = d["rekorde"]
	var th: int = int(m["tore_heim"])
	var tg: int = int(m["tore_gast"])
	var gesamt: int = th + tg
	var abstand: int = absi(th - tg)
	var sieger: String = str(m["heim"]) if th > tg else str(m["gast"])
	if abstand > int(rekorde.get("hoechster_sieg", {}).get("wert", 0)):
		rekorde["hoechster_sieg"] = {
			"wert": abstand, "spiel": str(m["id"]), "tag": int(d["tag"]),
			"text": "%s %d:%d %s" % [d["vereine"][m["heim"]]["name"], th, tg, d["vereine"][m["gast"]]["name"]],
			"verein": sieger,
		}
	if gesamt > int(rekorde.get("meiste_tore_spiel", {}).get("wert", 0)):
		rekorde["meiste_tore_spiel"] = {
			"wert": gesamt, "spiel": str(m["id"]), "tag": int(d["tag"]),
			"text": "%s %d:%d %s" % [d["vereine"][m["heim"]]["name"], th, tg, d["vereine"][m["gast"]]["name"]],
		}
	var bericht: Dictionary = m.get("bericht", {})
	for seite in ["heim", "gast"]:
		var tb: Dictionary = bericht.get(seite, {})
		for sid in tb.get("spieler", {}).keys():
			var z: Dictionary = tb["spieler"][sid]
			if int(z["paraden"]) > int(rekorde.get("meiste_paraden", {}).get("wert", 0)):
				rekorde["meiste_paraden"] = {
					"wert": int(z["paraden"]), "spieler": sid, "tag": int(d["tag"]),
					"text": "%s, %d Paraden" % [Spielerfabrik.voller_name(d["spieler"][sid]), int(z["paraden"])],
				}
			if int(z["tore"]) > int(rekorde.get("meiste_tore_spieler", {}).get("wert", 0)):
				rekorde["meiste_tore_spieler"] = {
					"wert": int(z["tore"]), "spieler": sid, "tag": int(d["tag"]),
					"text": "%s, %d Tore" % [Spielerfabrik.voller_name(d["spieler"][sid]), int(z["tore"])],
				}
	# Siegesserien
	for cid in [str(m["heim"]), str(m["gast"])]:
		var v: Dictionary = d["vereine"][cid]
		var kurve: Array = v["formkurve"]
		var serie := 0
		for i in range(kurve.size() - 1, -1, -1):
			if str(kurve[i]) == "S":
				serie += 1
			else:
				break
		if serie > int(rekorde.get("laengste_siegesserie", {}).get("wert", 0)):
			rekorde["laengste_siegesserie"] = {
				"wert": serie, "verein": cid, "tag": int(d["tag"]),
				"text": "%s, %d Siege in Folge" % [v["name"], serie],
			}
		if serie >= 5 and cid == Welt.mein_verein_id and serie % 5 == 0:
			Welt.nachricht({
				"typ": "chronik", "betreff": "%d Siege in Serie" % serie,
				"text": "Ihre Mannschaft hat %d Pflichtspiele nacheinander gewonnen. So etwas bleibt im Verein in Erinnerung." % serie,
			})

static func _rivalitaet_pflegen(d: Dictionary, m: Dictionary) -> void:
	var heim: String = str(m["heim"])
	var gast: String = str(m["gast"])
	var vh: Dictionary = d["vereine"][heim]
	var vg: Dictionary = d["vereine"][gast]
	var abstand: int = absi(int(m["tore_heim"]) - int(m["tore_gast"]))
	var zuwachs: float = 1.2
	if abstand <= 1:
		zuwachs += 1.6
	if str(m["art"]) in ["pokal", "supercup"] or bool(m.get("ko", false)):
		zuwachs += 2.4
	var bericht: Dictionary = m.get("bericht", {})
	var strafen: int = int(bericht.get("heim", {}).get("stats", {}).get("zeitstrafen", 0)) + int(bericht.get("gast", {}).get("stats", {}).get("zeitstrafen", 0))
	zuwachs += float(strafen) * 0.18
	var alt_h: float = float((vh["rivalen"] as Dictionary).get(gast, 0.0))
	var alt_g: float = float((vg["rivalen"] as Dictionary).get(heim, 0.0))
	(vh["rivalen"] as Dictionary)[gast] = clampf(alt_h + zuwachs, 0.0, 100.0)
	(vg["rivalen"] as Dictionary)[heim] = clampf(alt_g + zuwachs, 0.0, 100.0)

static func _legenden_pflegen(d: Dictionary, m: Dictionary) -> void:
	var bericht: Dictionary = m.get("bericht", {})
	for seite in ["heim", "gast"]:
		var tb: Dictionary = bericht.get(seite, {})
		var cid: String = str(tb.get("cid", ""))
		if cid == "" or not d["vereine"].has(cid):
			continue
		var v: Dictionary = d["vereine"][cid]
		var legenden: Array = v["chronik"]["legenden"]
		for sid in tb.get("spieler", {}).keys():
			if not d["spieler"].has(sid):
				continue
			var sp: Dictionary = d["spieler"][sid]
			var eintrag := _legende_finden(legenden, sid)
			if eintrag.is_empty():
				eintrag = {"spieler": sid, "spiele": 0, "tore": 0, "paraden": 0, "name": Spielerfabrik.voller_name(sp)}
				legenden.append(eintrag)
			var z: Dictionary = tb["spieler"][sid]
			eintrag["spiele"] = int(eintrag["spiele"]) + 1
			eintrag["tore"] = int(eintrag["tore"]) + int(z["tore"])
			eintrag["paraden"] = int(eintrag["paraden"]) + int(z["paraden"])
			if int(eintrag["spiele"]) == 100 and cid == Welt.mein_verein_id:
				Welt.nachricht({
					"typ": "chronik", "betreff": "100 Spiele für den Verein",
					"text": "%s hat heute sein 100. Pflichtspiel für %s bestritten." % [Spielerfabrik.voller_name(sp), v["name"]],
				})

static func _legende_finden(legenden: Array, sid: String) -> Dictionary:
	for e in legenden:
		if str(e["spieler"]) == sid:
			return e
	return {}

static func bestenliste(d: Dictionary, cid: String, feld: String, anzahl: int = 10) -> Array:
	var legenden: Array = (d["vereine"][cid]["chronik"]["legenden"] as Array).duplicate()
	legenden.sort_custom(func(a, b): return int(a.get(feld, 0)) > int(b.get(feld, 0)))
	return legenden.slice(0, anzahl)

static func transfer_pruefen(d: Dictionary, sid: String, ablöse: float) -> void:
	var rekorde: Dictionary = d["rekorde"]
	if ablöse > float(rekorde.get("teuerster_transfer", {}).get("wert", 0.0)):
		rekorde["teuerster_transfer"] = {
			"wert": ablöse, "spieler": sid, "tag": int(d["tag"]),
			"text": "%s für %s" % [Spielerfabrik.voller_name(d["spieler"][sid]), Stil.geld(ablöse)],
		}

## Rivalen eines Vereins, nach Intensitaet sortiert.
static func rivalen(d: Dictionary, cid: String, anzahl: int = 5) -> Array:
	var r: Dictionary = d["vereine"][cid]["rivalen"]
	var ids: Array = r.keys()
	ids.sort_custom(func(a, b): return float(r[a]) > float(r[b]))
	var erg: Array = []
	for i in range(mini(anzahl, ids.size())):
		erg.append({"verein": ids[i], "intensitaet": float(r[ids[i]])})
	return erg

static func rivalitaet_stufe(wert: float) -> String:
	if wert >= 85.0:
		return "Erzrivale"
	elif wert >= 65.0:
		return "große Rivalität"
	elif wert >= 45.0:
		return "Derbycharakter"
	elif wert >= 25.0:
		return "angespannt"
	return "unbelastet"

static func titel_eintragen(d: Dictionary, cid: String, titel: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	(v["chronik"]["titel"] as Array).append({"saison": Welt.saison_index(), "titel": titel,
		"saisontext": Kalender.saison_text(int(d["startjahr"]), Welt.saison_index())})
	(d["chronik"]["ereignisse"] as Array).push_front({
		"tag": int(d["tag"]), "verein": cid, "text": "%s gewinnt %s" % [v["name"], titel],
	})

static func saison_eintragen(d: Dictionary, cid: String, eintrag: Dictionary) -> void:
	(d["vereine"][cid]["chronik"]["saisons"] as Array).push_front(eintrag)
