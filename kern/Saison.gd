class_name Saison
extends RefCounted
## Saisonabschluss und Saisonwechsel: Meister, Auf- und Abstieg, Ehrungen,
## auslaufende Vertraege, Karriereenden, neuer Jahrgang, neue Spielplaene.

# ------------------------------------------------------------- Abschluss ---

static func abschluss(d: Dictionary, mein: String) -> void:
	var auf_ab: Array = []
	for lid in d["ligen"].keys():
		var liga: Dictionary = d["ligen"][lid]
		var tabelle := Spielplan.tabelle_sortiert(d, lid)
		liga["abschlusstabelle"] = tabelle
		if tabelle.is_empty():
			continue
		var meister: String = str(tabelle[0])
		(liga["meister_historie"] as Array).push_front({"saison": Welt.saison_index(), "verein": meister})
		if int(liga["stufe"]) == 1:
			(d["nationen"][liga["nation"]]["meister_historie"] as Array).push_front({"saison": Welt.saison_index(), "verein": meister})
			d["nationen"][liga["nation"]]["letzter_meister"] = meister
			Chronik.titel_eintragen(d, meister, "Meisterschaft (%s)" % liga["name"])
			_preisgeld(d, tabelle, liga)
			if meister == mein:
				Trainerkarriere.titel_gewinnen(d, "Meister %s" % liga["name"])
				Medien.saisonfazit(d, mein, "%s ist Meister!" % d["vereine"][mein]["name"],
					"Am Ende einer langen Saison steht %s ganz oben in der %s. In der Halle wird gefeiert, als gäbe es kein Morgen." % [d["vereine"][mein]["name"], liga["name"]], "jubel")
		else:
			Chronik.titel_eintragen(d, meister, "Meisterschaft (%s)" % liga["name"])
		_ligaplatzierungen_eintragen(d, lid, tabelle)
		auf_ab.append({"liga": lid, "tabelle": tabelle})
	_ehrungen(d, mein)
	_auf_und_abstieg(d)
	_trainerbilanz(d, mein)
	if mein != "":
		_vorstandsbilanz(d, mein)

static func _preisgeld(d: Dictionary, tabelle: Array, liga: Dictionary) -> void:
	var basis: float = float(liga["ruf"]) * 14000.0
	for i in range(tabelle.size()):
		var anteil: float = 1.0 - float(i) / float(maxi(tabelle.size(), 1)) * 0.75
		Finanzen.buchen(d, str(tabelle[i]), basis * anteil, "Platzierungsprämie %s" % liga["name"], "preisgeld")

static func _ligaplatzierungen_eintragen(d: Dictionary, lid: String, tabelle: Array) -> void:
	var liga: Dictionary = d["ligen"][lid]
	for i in range(tabelle.size()):
		var cid: String = str(tabelle[i])
		var v: Dictionary = d["vereine"][cid]
		var zeile: Dictionary = liga["tabelle"].get(cid, {})
		Chronik.saison_eintragen(d, cid, {
			"saison": Welt.saison_index(),
			"saisontext": Kalender.saison_text(int(d["startjahr"]), Welt.saison_index()),
			"liga": str(liga["name"]),
			"platz": i + 1,
			"punkte": int(zeile.get("punkte", 0)),
			"tore": int(zeile.get("tore", 0)),
			"gegentore": int(zeile.get("gegentore", 0)),
			"zuschauer": int(float(v["saison"]["zuschauer_summe"]) / maxf(float(v["saison"]["heimspiele"]), 1.0)),
		})
		var beste: Dictionary = v["chronik"]["beste_liga_platzierung"]
		if not beste.has(lid) or i + 1 < int(beste[lid]):
			beste[lid] = i + 1
		# Ruf entwickelt sich mit dem Abschneiden
		var erwartet: float = float(v["vorstand"]["ziel_platz"])
		var delta: float = clampf((erwartet - float(i + 1)) * 0.55, -6.0, 6.0)
		v["ruf"] = clampf(float(v["ruf"]) + delta, 5.0, 99.0)

static func _ehrungen(d: Dictionary, mein: String) -> void:
	for lid in d["ligen"].keys():
		var liga: Dictionary = d["ligen"][lid]
		if int(liga["stufe"]) != 1:
			continue
		var torjaeger := Statistik.torjaeger(d, lid, 1)
		if torjaeger.is_empty():
			continue
		var sid: String = str(torjaeger[0]["sid"])
		if not d["spieler"].has(sid):
			continue
		var sp: Dictionary = d["spieler"][sid]
		(sp["stats"]["karriere"] as Dictionary)["titel"] = int(sp["stats"]["karriere"].get("titel", 0)) + 1
		liga["torschuetzenkoenig"] = {"saison": Welt.saison_index(), "spieler": sid, "tore": int(torjaeger[0]["tore"])}
		if str(sp["verein"]) == mein:
			Welt.nachricht({
				"typ": "auszeichnung", "wichtig": true,
				"betreff": "Torschützenkönig: %s" % Spielerfabrik.voller_name(sp),
				"text": "%s ist mit %d Treffern bester Werfer der %s." % [Spielerfabrik.voller_name(sp), int(torjaeger[0]["tore"]), liga["name"]],
			})
		# Wertvollster Spieler und bester Torwart nach Durchschnittsnote
		var mvp := _bester_der_liga(d, lid, false)
		var bester_tw := _bester_der_liga(d, lid, true)
		liga["mvp"] = mvp
		liga["bester_torwart"] = bester_tw
		if mvp != "" and str(d["spieler"][mvp]["verein"]) == mein:
			Welt.nachricht({"typ": "auszeichnung", "wichtig": true,
				"betreff": "Spieler der Saison: %s" % Spielerfabrik.voller_name(d["spieler"][mvp]),
				"text": "Die Trainer der Liga haben %s zum wertvollsten Spieler gewählt." % Spielerfabrik.voller_name(d["spieler"][mvp])})
		_allstar(d, lid, mein)

## Die beste Sieben einer Liga: je Position der Spieler mit der besten
## Durchschnittsnote, der genug gespielt hat.
static func _allstar(d: Dictionary, lid: String, mein: String) -> void:
	var sieben: Dictionary = {}
	for pos in Spielerfabrik.POSITIONEN:
		var best := ""
		var bw := 9.0
		for cid in d["ligen"][lid]["vereine"]:
			for sid in d["vereine"][cid]["kader"]:
				var sp: Dictionary = d["spieler"][sid]
				if str(sp["position"]) != pos:
					continue
				if int(sp["stats"]["saison"]["spiele"]) < 12:
					continue
				var note: float = Spielerfabrik.note(sp)
				if note > 0.0 and note < bw:
					bw = note
					best = sid
		if best != "":
			sieben[pos] = best
			(d["spieler"][best]["stats"]["karriere"] as Dictionary)["allstar"] = \
				int((d["spieler"][best]["stats"]["karriere"] as Dictionary).get("allstar", 0)) + 1
	if sieben.is_empty():
		return
	d["ligen"][lid]["allstar"] = {"saison": Welt.saison_index(), "spieler": sieben}
	var eigene: Array = []
	for pos in sieben.keys():
		if str(d["spieler"][sieben[pos]]["verein"]) == mein:
			eigene.append(Spielerfabrik.voller_name(d["spieler"][sieben[pos]]))
	if eigene.is_empty():
		return
	Welt.nachricht({
		"typ": "auszeichnung", "wichtig": true,
		"betreff": "Team der Saison: %d Spieler von uns" % eigene.size(),
		"text": "In die beste Sieben der %s wurden berufen: %s." % [
			str(d["ligen"][lid]["name"]), ", ".join(eigene)],
	})

static func _bester_der_liga(d: Dictionary, lid: String, torwart: bool) -> String:
	var best := ""
	var bw := 9.0
	for cid in d["ligen"][lid]["vereine"]:
		for sid in d["vereine"][cid]["kader"]:
			var sp: Dictionary = d["spieler"][sid]
			if bool(sp["ist_torwart"]) != torwart:
				continue
			if int(sp["stats"]["saison"]["spiele"]) < 12:
				continue
			var note: float = Spielerfabrik.note(sp)
			if note > 0.0 and note < bw:
				bw = note
				best = sid
	return best

static func _auf_und_abstieg(d: Dictionary) -> void:
	for nid in d["nationen"].keys():
		var ligen: Array = d["nationen"][nid]["ligen"]
		if ligen.size() < 2:
			continue
		var oben: Dictionary = d["ligen"][ligen[0]]
		var unten: Dictionary = d["ligen"][ligen[1]]
		var t_oben: Array = oben.get("abschlusstabelle", [])
		var t_unten: Array = unten.get("abschlusstabelle", [])
		if t_oben.size() < 3 or t_unten.size() < 3:
			continue
		var absteiger: Array = [t_oben[-1], t_oben[-2]]
		var aufsteiger: Array = [t_unten[0], t_unten[1]]
		oben["absteiger"] = absteiger
		unten["aufsteiger"] = aufsteiger
		for cid in absteiger:
			(oben["vereine"] as Array).erase(cid)
			(unten["vereine"] as Array).append(cid)
			d["vereine"][cid]["liga"] = str(unten["id"])
			d["vereine"][cid]["ruf"] = clampf(float(d["vereine"][cid]["ruf"]) - 6.0, 5.0, 99.0)
			Chronik.saison_eintragen(d, cid, {"saison": Welt.saison_index(), "ereignis": "Abstieg",
				"saisontext": Kalender.saison_text(int(d["startjahr"]), Welt.saison_index())})
			if cid == Welt.mein_verein_id:
				Medien.saisonfazit(d, cid, "Abstieg besiegelt",
					"%s muss den Gang in die %s antreten. Im Umfeld wird die Aufarbeitung bereits eingefordert." % [d["vereine"][cid]["name"], unten["name"]], "verriss")
		for cid2 in aufsteiger:
			(unten["vereine"] as Array).erase(cid2)
			(oben["vereine"] as Array).append(cid2)
			d["vereine"][cid2]["liga"] = str(oben["id"])
			d["vereine"][cid2]["ruf"] = clampf(float(d["vereine"][cid2]["ruf"]) + 6.0, 5.0, 99.0)
			Chronik.saison_eintragen(d, cid2, {"saison": Welt.saison_index(), "ereignis": "Aufstieg",
				"saisontext": Kalender.saison_text(int(d["startjahr"]), Welt.saison_index())})
			if cid2 == Welt.mein_verein_id:
				Trainerkarriere.titel_gewinnen(d, "Aufstieg in die %s" % oben["name"])
				Medien.saisonfazit(d, cid2, "Aufstieg geschafft!",
					"%s spielt in der kommenden Saison in der %s. Der Verein feiert bis in die Nacht." % [d["vereine"][cid2]["name"], oben["name"]], "jubel")

static func _trainerbilanz(d: Dictionary, mein: String) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return
	var st := Trainerkarriere.station(t)
	if st.is_empty():
		return
	if mein != "" and d["vereine"].has(mein):
		var liga: Dictionary = d["ligen"][d["vereine"][mein]["liga"]]
		var tabelle: Array = liga.get("abschlusstabelle", [])
		var platz: int = tabelle.find(mein) + 1
		var ziel: int = int(d["vereine"][mein]["vorstand"]["ziel_platz"])
		if platz > 0 and platz <= ziel:
			t["ruf"] = clampf(float(t["ruf"]) + 3.5, 1.0, 100.0)
		elif platz > 0:
			t["ruf"] = clampf(float(t["ruf"]) - 2.0, 1.0, 100.0)

static func _vorstandsbilanz(d: Dictionary, mein: String) -> void:
	var v: Dictionary = d["vereine"][mein]
	var liga: Dictionary = d["ligen"][v["liga"]]
	var tabelle: Array = liga.get("abschlusstabelle", [])
	var platz: int = tabelle.find(mein) + 1
	var ziel: int = int(v["vorstand"]["ziel_platz"])
	var text := ""
	if platz > 0 and platz <= ziel:
		text = "Das Saisonziel (%s) wurde erreicht: Platz %d. Der Vorstand bedankt sich ausdrücklich." % [v["vorstand"]["saisonziel"], platz]
		v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) + 14.0, 0.0, 100.0)
	else:
		text = "Mit Platz %d wurde das Saisonziel (%s) verfehlt. Der Vorstand erwartet in der kommenden Saison eine deutliche Steigerung." % [platz, v["vorstand"]["saisonziel"]]
		v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) - 16.0, 0.0, 100.0)
	Welt.nachricht({"typ": "vorstand", "wichtig": true, "betreff": "Saisonbilanz des Vorstands", "text": text})
	if float(v["vorstand"]["vertrauen"]) < 18.0:
		Vorstand.entlassung(d, mein)

# ------------------------------------------------------------ Pokal/Europa ---

static func pokalsieger_feiern(d: Dictionary, pid: String) -> void:
	var pokal: Dictionary = d["pokale"][pid]
	var sieger: String = str(pokal.get("sieger", ""))
	if sieger == "":
		return
	(pokal["sieger_historie"] as Array).push_front({"saison": Welt.saison_index(), "verein": sieger})
	d["nationen"][pokal["nation"]]["letzter_pokalsieger"] = sieger
	Chronik.titel_eintragen(d, sieger, str(pokal["name"]))
	Finanzen.buchen(d, sieger, 280000.0, "Pokalsieg", "preisgeld")
	if sieger == Welt.mein_verein_id:
		Trainerkarriere.titel_gewinnen(d, str(pokal["name"]))
		Medien.saisonfazit(d, sieger, "Pokalsieg für %s!" % d["vereine"][sieger]["name"],
			"%s gewinnt den %s. Ein Titel, der im Verein lange nachhallen wird." % [d["vereine"][sieger]["name"], pokal["name"]], "jubel")
		Welt.nachricht({"typ": "wettbewerb", "wichtig": true, "betreff": "Pokalsieg",
			"text": "Sie haben den %s gewonnen." % pokal["name"]})

static func europapokal_feiern(d: Dictionary, wid: String) -> void:
	var wb: Dictionary = d["international"][wid]
	var sieger: String = str(wb.get("sieger", ""))
	if sieger == "":
		return
	(wb["sieger_historie"] as Array).push_front({"saison": Welt.saison_index(), "verein": sieger})
	Chronik.titel_eintragen(d, sieger, str(wb["name"]))
	Finanzen.buchen(d, sieger, float(wb.get("preisgeld_runde", 200000.0)) * 4.0, "Sieg %s" % wb["name"], "preisgeld")
	d["vereine"][sieger]["ruf"] = clampf(float(d["vereine"][sieger]["ruf"]) + 4.0, 5.0, 99.0)
	if sieger == Welt.mein_verein_id:
		Trainerkarriere.titel_gewinnen(d, str(wb["name"]))
		Medien.saisonfazit(d, sieger, "%s gewonnen!" % wb["name"],
			"%s holt den Titel auf internationaler Bühne. Größer wird es für diesen Verein kaum." % d["vereine"][sieger]["name"], "jubel")

# ---------------------------------------------------------- Neue Saison ---

static func neue_saison(d: Dictionary, mein: String) -> void:
	KI.vertragsrunde(d)
	_vertraege_ablaufen(d)
	_karriereenden(d)
	_nachwuchs(d)
	_statistiken_umlegen(d)
	_wettbewerbe_zuruecksetzen(d)
	Finanzen.saison_budgets(d)
	for cid in Weltgenerator.clubs(d):
		Vorstand.saisonziel_festlegen(d, cid)
		d["vereine"][cid]["vorstand"]["warnstufe"] = 0
	KI.saisonvorbereitung(d)
	Spielplan.erzeuge_saison(d)
	if mein != "" and (d["vereine"][mein]["kader"] as Array).size() < 15:
		Welt.nachricht({
			"typ": "verein", "wichtig": true,
			"betreff": "Der Kader ist zu klein",
			"text": "Nur noch %d Spieler stehen unter Vertrag. Auf dem Transfermarkt finden Sie vereinslose Spieler, die ablösefrei zu haben sind." % (d["vereine"][mein]["kader"] as Array).size(),
		})
	if mein != "":
		Vorstand.vertragsangebot_pruefen(d, mein)
		Medien.saisonauftakt(d, mein)
		var v: Dictionary = d["vereine"][mein]
		Welt.nachricht({
			"typ": "verein", "wichtig": true,
			"betreff": "Saison %s beginnt" % Welt.saison_text(),
			"text": "Die Vorbereitung ist abgeschlossen. Saisonziel: %s. Transferbudget: %s, Gehaltsbudget: %s pro Woche." % [
				v["vorstand"]["saisonziel"], Stil.geld(float(v["transferbudget"])), Stil.geld(float(v["gehaltsbudget"]))],
		})
	jobangebote_erzeugen(d, mein)
	prognose_erstellen(d, mein)

static func _vertraege_ablaufen(d: Dictionary) -> void:
	var saison: int = Welt.saison_index()
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		var cid: String = str(sp["verein"])
		if cid == "":
			continue
		# Leihen enden
		var leihe: Dictionary = sp.get("leihe", {})
		if not leihe.is_empty() and int(leihe.get("bis_saison", 0)) <= saison:
			var stamm: String = str(leihe["stammverein"])
			(d["vereine"][cid]["kader"] as Array).erase(sid)
			Transfermarkt.aufstellung_saeubern(d, cid, sid)
			if d["vereine"].has(stamm):
				(d["vereine"][stamm]["kader"] as Array).append(sid)
				sp["verein"] = stamm
			else:
				sp["verein"] = ""
			sp["leihe"] = {}
			continue
		if int(sp["vertrag"].get("bis_saison", 9)) > saison:
			continue
		if bool(sp.get("jugendspieler", false)):
			# Jugendvertraege verlaengern sich stillschweigend bis zum Hoechstalter.
			sp["vertrag"]["bis_saison"] = saison + 2
			continue
		# Vertrag laeuft aus
		if cid == Welt.mein_verein_id:
			Welt.nachricht({
				"typ": "transfer", "wichtig": true,
				"betreff": "Vertrag ausgelaufen: %s" % Spielerfabrik.voller_name(sp),
				"text": "%s verlässt den Verein ablösefrei." % Spielerfabrik.voller_name(sp),
			})
		(d["vereine"][cid]["kader"] as Array).erase(sid)
		Transfermarkt.aufstellung_saeubern(d, cid, sid)
		sp["verein"] = ""
		sp["vertrag"] = {}

static func _karriereenden(d: Dictionary) -> void:
	for sid in d["spieler"].keys().duplicate():
		var sp: Dictionary = d["spieler"][sid]
		var alter_jahre: int = int(sp["alter"])
		if alter_jahre < 32:
			continue
		var g: float = Spielerfabrik.gesamt(sp)
		var wahrscheinlichkeit: float = clampf((float(alter_jahre) - 32.0) * 0.16 + (60.0 - g) * 0.012, 0.0, 0.95)
		if alter_jahre >= 40:
			wahrscheinlichkeit = 1.0
		if Namen.zufall() > wahrscheinlichkeit:
			continue
		var cid: String = str(sp["verein"])
		if cid != "" and d["vereine"].has(cid):
			(d["vereine"][cid]["kader"] as Array).erase(sid)
			Transfermarkt.aufstellung_saeubern(d, cid, sid)
			if cid == Welt.mein_verein_id:
				Welt.nachricht({
					"typ": "verein", "wichtig": true,
					"betreff": "Karriereende: %s" % Spielerfabrik.voller_name(sp),
					"text": "%s beendet mit %d Jahren seine Laufbahn. In %d Pflichtspielen erzielte er %d Tore." % [
						Spielerfabrik.voller_name(sp), alter_jahre,
						int(sp["stats"]["karriere"]["spiele"]), int(sp["stats"]["karriere"]["tore"])],
				})
		sp["verein"] = ""
		sp["karriereende"] = Welt.saison_index()
		d["spieler"].erase(sid)

static func _nachwuchs(d: Dictionary) -> void:
	Jugend.jahreswechsel(d)
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var jugend: int = int(v["infrastruktur"]["jugendarbeit"])
		var anzahl: int = 1 + (1 if jugend >= 5 else 0) + (1 if Namen.zufall() < 0.45 else 0)
		var neue := Jugend.erzeuge_jahrgang(d, cid, anzahl)
		if cid != Welt.mein_verein_id or neue.is_empty():
			continue
		var namen: Array = []
		for sid in neue:
			var sp: Dictionary = d["spieler"][sid]
			namen.append("%s (%d, %s — %s)" % [Spielerfabrik.voller_name(sp), int(sp["alter"]),
				Spielerfabrik.POSITION_NAME[str(sp["position"])], Jugend.einschaetzung(d, sid)])
		Welt.nachricht({
			"typ": "jugend", "wichtig": true,
			"betreff": "Neuer Jahrgang im Nachwuchszentrum",
			"text": "Diese Talente sind aufgenommen worden:\n• %s" % "\n• ".join(PackedStringArray(namen)),
		})

static func _statistiken_umlegen(d: Dictionary) -> void:
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		var saisonstats: Dictionary = sp["stats"]["saison"]
		if int(saisonstats["spiele"]) > 0:
			(sp["stats"]["verlauf"] as Array).push_front({
				"saison": Welt.saison_index(),
				"saisontext": Kalender.saison_text(int(d["startjahr"]), Welt.saison_index()),
				"verein": str(sp["verein"]),
				"spiele": int(saisonstats["spiele"]),
				"tore": int(saisonstats["tore"]),
				"assists": int(saisonstats["assists"]),
				"paraden": int(saisonstats["paraden"]),
				"note": Spielerfabrik.note(sp),
			})
		sp["stats"]["saison"] = Spielerfabrik.leere_saisonstats()
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) * 0.6, 0.0, 100.0)
		sp["last"] = clampf(float(sp["last"]) * 0.35, 0.0, 100.0)
		sp["fitness"] = clampf(float(sp["fitness"]) + 14.0, 40.0, 100.0)
		sp["wert"] = Spielerfabrik.marktwert(sp)
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		v["saison"] = Weltgenerator.leere_vereinsstats()
		v["formkurve"] = []

static func _wettbewerbe_zuruecksetzen(d: Dictionary) -> void:
	for lid in d["ligen"].keys():
		var liga: Dictionary = d["ligen"][lid]
		liga["tabelle"] = {}
		liga["torschuetzen"] = {}
		liga["aktueller_spieltag"] = 0
		liga["teams"] = (liga["vereine"] as Array).size()
	for pid in d["pokale"].keys():
		var pokal: Dictionary = d["pokale"][pid]
		pokal["runde"] = 0
		pokal["beendet"] = false
		pokal["paarungen"] = []
		pokal["freilose"] = []
		pokal["sieger"] = ""
	for wid in d["international"].keys():
		var wb: Dictionary = d["international"][wid]
		wb["phase"] = "vorbereitung"
		wb["gruppen"] = []
		wb["tabelle"] = {}
		wb["paarungen"] = []
		wb["runde"] = 0
		wb["sieger"] = ""
	# Alte Partien ausduennen: nur die letzte Saison bleibt vollstaendig erhalten
	var grenze: int = int(d["tag"]) - 400
	var behalten := {}
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if int(m["tag"]) >= grenze:
			behalten[mid] = m
	d["spiele"] = behalten

## Vor jeder Saison schaetzen Presse und Buchmacher, wer den Titel holt.
## Grundlage sind Vereinsruf und die tatsaechliche Staerke der zehn besten
## Spieler — nicht nur der Name. Die Quoten sind das, woran der Verein
## anschliessend gemessen wird, und sie geben der Tabelle einen Bezugspunkt.
static func prognose_erstellen(d: Dictionary, mein: String = "") -> void:
	for lid in d["ligen"].keys():
		var liga: Dictionary = d["ligen"][lid]
		var werte: Array = []
		var summe := 0.0
		for cid in liga["vereine"]:
			var index: float = _prognoseindex(d, cid) * Namen.bereich(0.94, 1.06)
			werte.append({"verein": cid, "index": index})
			# Erst den Sockel abziehen: die Indexwerte liegen nah beieinander,
			# ohne das waeren selbst Favoriten mit Quote 10 notiert.
			summe += pow(maxf(index - 48.0, 1.0), 6.0)
		if werte.is_empty():
			continue
		werte.sort_custom(func(a, b): return float(a["index"]) > float(b["index"]))
		for e in werte:
			# Aus dem Staerkeindex eine Siegwahrscheinlichkeit und daraus eine Quote
			var p: float = pow(maxf(float(e["index"]) - 48.0, 1.0), 6.0) / maxf(summe, 0.001)
			e["quote"] = clampf(1.0 / maxf(p, 0.0006), 1.15, 999.0)
		liga["prognose"] = werte
	if mein == "" or not d["vereine"].has(mein):
		return
	var lid2: String = str(d["vereine"][mein]["liga"])
	var liste: Array = d["ligen"][lid2].get("prognose", [])
	for i in range(liste.size()):
		if str((liste[i] as Dictionary)["verein"]) != mein:
			continue
		var platz: int = i + 1
		var ton := "Die Buchmacher sehen Sie auf Rang %d." % platz
		if platz == 1:
			ton = "Die Buchmacher machen Sie zum Favoriten."
		elif platz <= 3:
			ton = "Die Buchmacher zählen Sie zum engsten Titelkreis (Rang %d)." % platz
		elif platz >= liste.size() - 2:
			ton = "Die Buchmacher sehen Sie als Abstiegskandidat (Rang %d von %d)." % [platz, liste.size()]
		Welt.nachricht({
			"typ": "medien",
			"betreff": "Saisonprognose: %s" % str(d["ligen"][lid2]["name"]),
			"text": "%s Quote auf den Titel: %s." % [ton,
				Stil.komma(float((liste[i] as Dictionary)["quote"]), 1)],
		})
		return

## Mischung aus Vereinsruf und der Staerke der zehn besten Spieler.
static func _prognoseindex(d: Dictionary, cid: String) -> float:
	var werte: Array = []
	for sid in d["vereine"][cid]["kader"]:
		werte.append(Spielerfabrik.gesamt(d["spieler"][sid]))
	werte.sort()
	werte.reverse()
	var summe := 0.0
	var n := 0
	for w in werte.slice(0, 10):
		summe += float(w)
		n += 1
	var kader: float = summe / maxf(float(n), 1.0)
	return float(d["vereine"][cid]["ruf"]) * 0.45 + kader * 0.55

## Jobangebote fuer den Trainer — auch dann, wenn er gerade unter Vertrag steht.
static func jobangebote_erzeugen(d: Dictionary, mein: String) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return
	t["jobangebote"] = []
	var ruf: float = float(t["ruf"])
	var kandidaten: Array = []
	var vereinslos: bool = mein == ""
	for cid in Weltgenerator.clubs(d):
		if cid == mein:
			continue
		var v: Dictionary = d["vereine"][cid]
		var passend: float = float(v["ruf"])
		if passend > ruf + 14.0 or passend < ruf - 30.0:
			continue
		# Vereine, die ihr Ziel verfehlt haben, suchen einen neuen Trainer.
		# Waehrend der Saison zaehlt der aktuelle Stand, danach die Abschlusstabelle.
		var liga: Dictionary = d["ligen"][v["liga"]]
		var tabelle: Array = liga.get("abschlusstabelle", [])
		if tabelle.is_empty() or vereinslos:
			tabelle = Spielplan.tabelle_sortiert(d, str(liga["id"]))
		var platz: int = tabelle.find(cid) + 1
		if platz <= 0:
			continue
		var verfehlt: bool = platz > int(v["vorstand"]["ziel_platz"]) + 2
		if vereinslos:
			verfehlt = verfehlt or float(v["vorstand"]["vertrauen"]) < 40.0
		if not verfehlt and Namen.zufall() > 0.12:
			continue
		kandidaten.append(cid)
	# Ein vereinsloser Trainer darf nicht ins Leere laufen: findet sich im
	# passenden Rufbereich niemand, wird die Suche stufenweise geöffnet.
	if vereinslos and kandidaten.is_empty():
		for cid in Weltgenerator.clubs(d):
			var v3: Dictionary = d["vereine"][cid]
			if float(v3["ruf"]) <= ruf + 6.0:
				kandidaten.append(cid)
		kandidaten.sort_custom(func(a, b):
			return float(d["vereine"][a]["ruf"]) > float(d["vereine"][b]["ruf"]))
		kandidaten = kandidaten.slice(0, 6)
	kandidaten.shuffle()
	var anzahl: int = mini(kandidaten.size(), 1 + int(ruf / 30.0))
	if mein == "":
		# Ohne Verein soll immer etwas auf dem Tisch liegen — aber nie mehr
		# Angebote, als es Kandidaten gibt.
		anzahl = mini(maxi(anzahl, 2), kandidaten.size())
	for i in range(anzahl):
		var cid: String = str(kandidaten[i])
		var v2: Dictionary = d["vereine"][cid]
		(t["jobangebote"] as Array).append({
			"verein": cid,
			"gehalt": 1800.0 + float(v2["ruf"]) * 55.0 + ruf * 30.0,
			"jahre": Namen.wuerfel(2, 4),
			"erwartung": str(v2["vorstand"]["saisonziel"]),
			"tag": int(d["tag"]),
		})
	if not (t["jobangebote"] as Array).is_empty():
		Welt.nachricht({
			"typ": "karriere", "wichtig": mein == "",
			"betreff": "%d Vereine zeigen Interesse" % (t["jobangebote"] as Array).size(),
			"text": "Auf dem Karrierebildschirm liegen neue Angebote vor.",
		})
