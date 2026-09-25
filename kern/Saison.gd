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
		# Die Abschlusstabelle bleibt über den Saisonwechsel hinaus stehen —
		# das internationale Startfeld der neuen Saison wird daraus gebildet.
		# Wer sie als "aktuelle Tabelle" liest, urteilt im ganzen neuen Jahr
		# nach der Platzierung des Vorjahres. Der Stempel sagt, wann sie galt.
		liga["abschluss_saison"] = Welt.saison_index()
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
	# Der Lizenzierungsausschuss urteilt ueber die Saison, die gerade zu Ende
	# gegangen ist: den Nachwuchskader, den es gab, und die Pflichtspiele, die
	# die Zweite wirklich bestritten hat. Nach dem Saisonumbruch ist beides
	# zurueckgesetzt — dort geprueft, erfuellte kein einziger Verein die
	# Auflagen, weil nichts mehr dastand, was man pruefen koennte.
	Lizenzierung.jahreslauf(d, mein)
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
		Laufbahn.torjaeger(d, sid, str(liga["name"]), int(torjaeger[0]["tore"]))
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
		Auszeichnungen.saisonehrungen(d, lid, mein)

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
			Laufbahn.allstar(d, best, str(d["ligen"][lid]["name"]))
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
			Klauseln.abstieg_pruefen(d, str(cid))
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

## In welcher Liga der Verein die abgelaufene Saison gespielt hat.
##
## Der Saisonabschluss verschiebt die Vereine zuerst zwischen den Ligen und
## zieht danach Bilanz. Danach zeigt verein["liga"] schon auf die neue Liga,
## und deren Abschlusstabelle kennt den Absteiger nicht. Wer von dort liest,
## findet Platz 0 — und schweigt genau in der Saison, in der es am meisten zu
## sagen gab. Darum wird die Liga über die Abschlusstabelle gesucht.
static func _saisonliga(d: Dictionary, cid: String) -> Dictionary:
	for lid in (d["ligen"] as Dictionary).keys():
		var liga: Dictionary = d["ligen"][lid]
		if (liga.get("abschlusstabelle", []) as Array).has(cid):
			return liga
	var jetzt: String = str((d["vereine"] as Dictionary).get(cid, {}).get("liga", ""))
	return (d["ligen"] as Dictionary).get(jetzt, {})

static func _trainerbilanz(d: Dictionary, mein: String) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return
	var st := Trainerkarriere.station(t)
	if st.is_empty():
		return
	if mein != "" and d["vereine"].has(mein):
		var liga: Dictionary = _saisonliga(d, mein)
		var tabelle: Array = liga.get("abschlusstabelle", [])
		var platz: int = tabelle.find(mein) + 1
		var ziel: int = int(d["vereine"][mein]["vorstand"]["ziel_platz"])
		if platz > 0 and platz <= ziel:
			t["ruf"] = clampf(float(t["ruf"]) + 3.5, 1.0, 100.0)
		elif platz > 0:
			t["ruf"] = clampf(float(t["ruf"]) - 2.0, 1.0, 100.0)

## Das Urteil des Vorstands am Saisonende.
##
## Es war binär: Ziel erreicht hiess plus vierzehn, Ziel verfehlt minus
## sechzehn — egal ob um einen Platz oder um zehn, und egal, was der Kader
## hergab. Wer mit dem zwölftbesten Kader Zehnter wurde und Platz acht als
## Ziel hatte, verlor genauso viel Vertrauen wie einer, der mit dem besten
## Kader abstieg. Das ist keine Strenge, das ist Blindheit, und sie hat in
## der Langzeitsonde reihenweise Trainer nach einer durchschnittlichen
## Spielzeit gekostet.
##
## Jetzt wird zweimal gemessen: am Ziel, das im Juli ausgegeben wurde, und an
## dem, was die Mannschaft hergab. Das Ziel wiegt doppelt — es bleibt das
## Versprechen —, aber ein Vorstand, der sieht, dass mit diesem Kader nicht
## mehr drin war, zieht das in Betracht.
const ZIEL_GEWICHT := 3.2
const STAERKE_GEWICHT := 1.6
const HOECHSTABZUG := 26.0
## Wie viel Pech dem Vorstand vom Abzug hoechstens abhandelt.
const PECH_MILDERUNG := 0.33

static func _vorstandsbilanz(d: Dictionary, mein: String) -> void:
	var v: Dictionary = d["vereine"][mein]
	var liga: Dictionary = _saisonliga(d, mein)
	var tabelle: Array = liga.get("abschlusstabelle", [])
	var platz: int = tabelle.find(mein) + 1
	if platz <= 0:
		return
	var ziel: int = int(v["vorstand"]["ziel_platz"])
	var erwartet: int = _staerkeplatz(d, mein, tabelle)
	# Negativ heisst besser als erwartet.
	var ab_ziel: int = platz - ziel
	var ab_kader: int = platz - erwartet
	var wandel: float = -float(ab_ziel) * ZIEL_GEWICHT - float(ab_kader) * STAERKE_GEWICHT
	# Ein Vorstand, der nur auf die Tabelle sieht, bestraft Pech wie Unfaehigkeit.
	# Deshalb rechnet er nach, was die Tordifferenz an Punkten hergegeben haette
	# — und nimmt vom Abzug hoechstens ein Drittel zurueck. Mehr nicht: die
	# Tabelle bleibt das Urteil, die Rechnung ist nur ein Argument.
	var erwartung: Dictionary = Saisonanalyse.punkteerwartung(d, mein, str(liga.get("id", "")))
	var pech: float = 0.0
	if not erwartung.is_empty():
		pech = -float(erwartung["differenz"])
	if wandel < 0.0 and pech >= Saisonanalyse.GLUECK_SCHWELLE:
		wandel *= 1.0 - clampf(pech / 30.0, 0.0, PECH_MILDERUNG)
	wandel = clampf(wandel, -HOECHSTABZUG, 20.0)
	v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) + wandel, 0.0, 100.0)

	var text := ""
	if ab_ziel <= 0:
		text = "Das Saisonziel (%s) wurde erreicht: Platz %d." % [v["vorstand"]["saisonziel"], platz]
		if ab_kader < -1:
			text += " Mit diesem Kader war das nicht selbstverständlich — der Vorstand weiß das."
		else:
			text += " Der Vorstand bedankt sich ausdrücklich."
	else:
		text = "Mit Platz %d wurde das Saisonziel (%s) verfehlt." % [platz, v["vorstand"]["saisonziel"]]
		if ab_kader <= -2:
			text += " Der Vorstand sieht allerdings, dass die Mannschaft nach ihrer Stärke auf Platz %d gehört hätte. Das rechnet er Ihnen an." % erwartet
		elif ab_kader >= 3:
			text += " Und das mit einem Kader, der für Platz %d gereicht hätte. Das wiegt schwer." % erwartet
		else:
			text += " Der Vorstand erwartet in der kommenden Saison eine deutliche Steigerung."
	if pech >= Saisonanalyse.GLUECK_SCHWELLE:
		text += " Eine Rechnung legt er dazu: Mit dieser Tordifferenz wären %d Punkte zu erwarten gewesen, es sind %d geworden. Die engen Spiele sind gegen Sie ausgegangen." % [
			int(round(float(erwartung["erwartet"]))), int(round(float(erwartung["tatsaechlich"])))]
	elif pech <= -Saisonanalyse.GLUECK_SCHWELLE:
		text += " Eine Rechnung hält er allerdings fest: Die Tordifferenz hätte für %d Punkte gesprochen, es sind %d geworden. So knapp muss es nicht wieder aufgehen." % [
			int(round(float(erwartung["erwartet"]))), int(round(float(erwartung["tatsaechlich"])))]
	Welt.nachricht({"typ": "vorstand", "wichtig": true, "betreff": "Saisonbilanz des Vorstands", "text": text})
	if float(v["vorstand"]["vertrauen"]) < 18.0:
		Vorstand.entlassung(d, mein)

## Auf welchem Platz die Mannschaft nach ihrer Kaderstärke stünde.
static func _staerkeplatz(d: Dictionary, cid: String, tabelle: Array) -> int:
	var rang: Array = []
	for c in tabelle:
		rang.append({"verein": str(c), "wert": _kaderwert(d, str(c))})
	rang.sort_custom(func(a, b): return float(a["wert"]) > float(b["wert"]))
	for i in rang.size():
		if str((rang[i] as Dictionary)["verein"]) == cid:
			return i + 1
	return tabelle.size()

## Die acht Staerksten — sie beschreiben eine Mannschaft besser als der
## Kaderschnitt, in dem der dritte Torwart mitzaehlt.
static func _kaderwert(d: Dictionary, cid: String) -> float:
	var beste: Array = []
	for sid in (d["vereine"][cid].get("kader", []) as Array):
		var sp: Dictionary = (d["spieler"] as Dictionary).get(str(sid), {})
		if not sp.is_empty():
			beste.append(Spielerfabrik.gesamt(sp))
	beste.sort()
	beste.reverse()
	var summe := 0.0
	var k: int = mini(8, beste.size())
	for i in k:
		summe += float(beste[i])
	return summe / maxf(float(k), 1.0)

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
	# Zuerst die Zusagen fuer die kommende Saison einloesen, dann die
	# Vertraege ablaufen lassen. Andersherum waere der Spieler schon
	# vereinslos und die Zusage ginge ins Leere.
	Vorvertrag.einloesen(d)
	# Ausgemustert wird VOR dem Vertragsablauf. Danach waeren die gerade
	# freigewordenen Spieler ebenfalls vereinslos, und ein Mann, dessen
	# Vertrag heute endet, haette keinen Sommer Zeit, einen neuen zu finden —
	# er flöge im selben Atemzug aus dem Spiel. So trifft es nur die, die
	# schon eine ganze Saison lang keinen Verein gefunden haben.
	_vereinslose_ausmustern(d)
	_vertraege_ablaufen(d)
	_karriereenden(d)
	_nachwuchs(d)
	_statistiken_umlegen(d)
	attributstand_festhalten(d)
	_wettbewerbe_zuruecksetzen(d)
	Zweite.zuruecksetzen(d)
	Zweite.saison_zuruecksetzen(d)
	Finanzen.saison_budgets(d)
	# Erst das Budget, dann der Plan: ein Verein entscheidet im Sommer im
	# Wissen, was er ausgeben kann.
	Gegnertrainer.sicherstellen(d)
	Vereinsplan.neu_fassen(d)
	Sponsoren.jahreswechsel(d, mein)
	_dauerkarten(d, mein)
	for cid in Weltgenerator.clubs(d):
		Vorstand.saisonziel_festlegen(d, cid)
		# Was die Liga vorhat, liest man am besten vor dem ersten Spieltag.
		if cid != mein and Namen.zufall() < 0.55:
			Vereinsplan.melden(d, cid)
		d["vereine"][cid]["vorstand"]["warnstufe"] = 0
	KI.saisonvorbereitung(d)
	# Acht Wochen Vorbereitung: was jetzt eingestellt ist, sitzt zum Auftakt
	# ordentlich. Wer im Sommer umstellt, zahlt dafür fast nichts — wer es im
	# November tut, umso mehr.
	for cid3 in Weltgenerator.clubs(d):
		Vertrautheit.sommervorbereitung(d, str(cid3))
	# Nach Abgängen, Aufrückern und Neuzugängen sitzt jede Nummer wieder
	# eindeutig — der Saisonumbruch ist der eine Punkt, an dem sich jeder
	# Kader verändert hat.
	for cid2 in Weltgenerator.clubs(d):
		Trikot.kader_nummerieren(d, cid2)
	Spielplan.erzeuge_saison(d)
	if mein != "" and (d["vereine"][mein]["kader"] as Array).size() < 15:
		Welt.nachricht({
			"typ": "verein", "wichtig": true,
			"betreff": "Der Kader ist zu klein",
			"text": "Nur noch %d Spieler stehen unter Vertrag. Auf dem Transfermarkt finden Sie vereinslose Spieler, die ablösefrei zu haben sind." % (d["vereine"][mein]["kader"] as Array).size(),
		})
	Klauseln.treuepraemien(d)
	Nationaltrainer.angebote_pruefen(d)
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

## Der Dauerkartenverkauf vor der Saison. Die KI stellt vorher ihre Preise
## auf, der Mensch hat seine im Sommer selbst gesetzt — was er dort entscheidet,
## bestimmt hier, wie viel Geld im Voraus hereinkommt.
static func _dauerkarten(d: Dictionary, mein: String) -> void:
	for cid in Weltgenerator.clubs(d):
		if cid != mein:
			Ticketing.ki_preise(d, cid)
		var erg := Ticketing.verkauf(d, cid)
		if cid != mein or erg.is_empty():
			continue
		Welt.nachricht({
			"typ": "finanzen", "wichtig": true,
			"betreff": "Dauerkarten verkauft: %s" % Stil.zahl(int(erg["anzahl"])),
			"text": "Der Vorverkauf ist abgeschlossen. %s Dauerkarten bringen %s in die Kasse. Diese Plätze sind für die Saison vergeben — an Spitzenspielen verdienen Sie dort nichts mehr dazu." % [
				Stil.zahl(int(erg["anzahl"])), Stil.geld(float(erg["einnahme"]))],
			"daten": {"verein": cid},
		})

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
				Trikot.vergeben(d, stamm, sid)
			else:
				sp["verein"] = ""
				KI.freie_leeren()  # er steht jetzt im Markt der Vereinslosen
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
		KI.freie_leeren()  # er steht jetzt im Markt der Vereinslosen
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
		KI.freie_leeren()  # er steht jetzt im Markt der Vereinslosen
		sp["karriereende"] = Welt.saison_index()
		spieler_entfernen(d, sid)

## Wer eine ganze Saison keinen Verein gefunden hat, hoert auf.
##
## Ohne das waere der Markt der Vereinslosen eine Schublade ohne Boden. Ein
## Karriereende gab es erst ab zweiunddreissig; ein Sechsundzwanzigjaehriger
## mit Wert 55, den niemand mehr holt, blieb bis in alle Ewigkeit darin
## liegen und wurde mit jedem Jahr zu einem weiteren Namen, den die Suche
## durchgehen muss. Im Profihandball ist das anders: wer ein Jahr ohne
## Vertrag ist, spielt danach in der Regel nicht mehr oben.
##
## Die Wahrscheinlichkeit steigt mit schwaecherer Leistung und mit dem Alter.
## Ein junger Starker bleibt fast sicher drin — er hat nur noch keinen Verein
## gefunden, und das ist kein Karriereende.
const VEREINSLOS_GRUNDRISIKO := 0.40

static func _vereinslose_ausmustern(d: Dictionary) -> void:
	for sid in d["spieler"].keys().duplicate():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["verein"]) != "" or bool(sp.get("jugendspieler", false)):
			continue
		var g: float = Spielerfabrik.gesamt(sp)
		var p: float = clampf(VEREINSLOS_GRUNDRISIKO
			+ (62.0 - g) * 0.02
			+ (float(sp["alter"]) - 27.0) * 0.04, 0.05, 0.95)
		# Wer jung ist, hoert nicht auf, nur weil ihn diesen Sommer niemand
		# wollte.
		#
		# Die Regel war fuer den Sechsundzwanzigjaehrigen gedacht, den niemand
		# mehr holt. Sie traf aber auch den Zwanzigjaehrigen, und der ist keine
		# gescheiterte Karriere, sondern ein Spaetzuender — er spielt eine
		# Klasse tiefer und kommt mit dreiundzwanzig wieder. Gemessen mit
		# werkzeuge/Alterssonde.gd: nach fuenf Jahren standen in der ganzen
		# Welt noch zwei Neunzehnjaehrige und acht Zwanzigjaehrige, zu Beginn
		# waren es dreizehn und dreizehn. Ein Spiel, dem die Jugend ausgeht,
		# wird mit jeder Spielzeit schwaecher.
		if int(sp["alter"]) <= 22:
			p *= 0.22
		if Namen.zufall() > p:
			continue
		sp["karriereende"] = Welt.saison_index()
		spieler_entfernen(d, sid)

## Entfernt einen Spieler restlos aus der Welt. Ohne das blieben Angebote,
## Anliegen, Gerüchte und Beobachtungslisten mit Verweisen auf jemanden
## zurück, den es nicht mehr gibt — und die Oberfläche stolpert darüber.
static func spieler_entfernen(d: Dictionary, sid: String) -> void:
	d["spieler"].erase(sid)
	var markt: Dictionary = d.get("transfermarkt", {})
	for schluessel in ["angebote", "gerüchte", "verlauf"]:
		var liste: Array = markt.get(schluessel, [])
		for i in range(liste.size() - 1, -1, -1):
			if str((liste[i] as Dictionary).get("spieler", "")) == sid:
				liste.remove_at(i)
	var scouting: Dictionary = d.get("scouting", {})
	for schluessel2 in ["auftraege", "berichte"]:
		var liste2: Array = scouting.get(schluessel2, [])
		for i2 in range(liste2.size() - 1, -1, -1):
			var e: Dictionary = liste2[i2]
			if str(e.get("ziel", "")) == sid or str(e.get("spieler", "")) == sid:
				liste2.remove_at(i2)
	(scouting.get("beobachtung", []) as Array).erase(sid)
	for schluessel3 in ["anliegen", "versprechen"]:
		var liste3: Array = d.get(schluessel3, [])
		for i3 in range(liste3.size() - 1, -1, -1):
			if str((liste3[i3] as Dictionary).get("spieler", "")) == sid:
				liste3.remove_at(i3)
	# Eine laufende Verhandlung über diesen Spieler ist gegenstandslos.
	if str((d.get("verhandlung", {}) as Dictionary).get("spieler", "")) == sid:
		d["verhandlung"] = {}
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		if (v["kader"] as Array).has(sid):
			(v["kader"] as Array).erase(sid)
			Transfermarkt.aufstellung_saeubern(d, cid, sid)
		(v.get("jugend", []) as Array).erase(sid)
		var anweisungen: Dictionary = (v.get("aufstellung", {}) as Dictionary).get("anweisungen", {})
		anweisungen.erase(sid)
		var minutenziele: Dictionary = (v.get("aufstellung", {}) as Dictionary).get("minuten", {})
		minutenziele.erase(sid)
		var paare: Array = v.get("mentoring", [])
		for i4 in range(paare.size() - 1, -1, -1):
			var paar: Dictionary = paare[i4]
			if str(paar["mentor"]) == sid or str(paar["schueler"]) == sid:
				paare.remove_at(i4)

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

## Haelt zu Saisonbeginn fest, wo jeder Spieler steht.
##
## Ohne diesen Abzug laesst sich nicht sagen, ob einer sich entwickelt hat.
## Das Spiel rechnet jede Woche an den Attributen, aber der Unterschied zum
## letzten Sommer stand nirgends — man sah eine Zahl und wusste nicht, ob sie
## gestiegen oder gefallen ist. Mit dem Abzug wird aus "Wurfkraft 14" ein
## "Wurfkraft 14, plus zwei seit Juli".
## Gehalten wird der Abzug nur fuer die eigenen Spieler.
##
## Er lag fuer alle 3624 Spieler der Welt im Spielstand und kostete dort 943
## Byte je Spieler — 3,4 MB von 32, gemessen mit werkzeuge/Spielstandsonde.gd.
## Gebraucht wird er an genau zwei Stellen im Spielerfenster.
##
## Fuer fremde Spieler gehoert er ohnehin nicht dorthin: "plus zwei Wurfkraft
## seit Juli" ist eine Aussage, die man ueber einen Spieler, den man nicht
## jeden Tag im Training sieht, gar nicht treffen koennte. Das Spiel schaetzt
## bei fremden Spielern sogar den Gesamtwert nur in einer Spanne — und nennt
## daneben die Entwicklung auf das Zehntel genau. Beides zusammen geht nicht.
static func attributstand_festhalten(d: Dictionary) -> void:
	var mein: String = Welt.mein_verein_id
	for sid in d.get("spieler", {}).keys():
		var sp: Dictionary = d["spieler"][sid]
		if mein != "" and str(sp.get("verein", "")) == mein:
			sp["attr_saisonstart"] = (sp["attr"] as Dictionary).duplicate()
		else:
			sp.erase("attr_saisonstart")

## Was sich seit Saisonbeginn getan hat: Attributname -> Veraenderung.
## Nur Werte, die sich sichtbar bewegt haben — ein Zehntel ist kein Fortschritt,
## sondern Rechenrauschen.
static func attributveraenderung(sp: Dictionary, mindestens: float = 0.5) -> Dictionary:
	var start: Dictionary = sp.get("attr_saisonstart", {})
	var aus := {}
	if start.is_empty():
		return aus
	for a in (sp["attr"] as Dictionary).keys():
		if not start.has(a):
			continue
		var diff: float = float(sp["attr"][a]) - float(start[a])
		if absf(diff) >= mindestens:
			aus[a] = diff
	return aus

## Dieselbe Veraenderung, aber in Anzeigepunkten.
##
## Die Attribute laufen intern von 1 bis 20, auf dem Schirm stehen sie von 5
## bis 100 — ein Punkt Anzeige ist ein Fuenftel intern. Gerechnet wurde bisher
## in der internen Einheit mit einer Schwelle von einem halben Punkt: das sind
## zweieinhalb Punkte Anzeige, und darunter blieb jede Verbesserung
## unsichtbar. Eine Saison Krafttraining bewegt aber genau diese kleinen
## Betraege.
static func attributveraenderung_anzeige(sp: Dictionary) -> Dictionary:
	var start: Dictionary = sp.get("attr_saisonstart", {})
	var aus := {}
	if start.is_empty():
		return aus
	for a in (sp["attr"] as Dictionary).keys():
		if not start.has(a):
			continue
		var diff: int = Spielerfabrik.anzeige(float(sp["attr"][a])) - Spielerfabrik.anzeige(float(start[a]))
		if diff != 0:
			aus[a] = diff
	return aus

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
		sp["stats"]["monat"] = Spielerfabrik.leere_saisonstats()
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
	# Alte Partien ausduennen: nur die letzte Saison bleibt erhalten, und von
	# der nur noch Ergebnis und Mannschaftswerte. Die Einzelbewertungen einer
	# abgeschlossenen Saison schlaegt niemand mehr auf, sie machen aber den
	# groessten Teil des Spielstands aus.
	var grenze: int = int(d["tag"]) - 400
	var behalten := {}
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if int(m["tag"]) < grenze:
			continue
		if bool(m.get("gespielt", false)) and not (m["bericht"] as Dictionary).is_empty():
			m["bericht"] = Matchsim.bericht_schlank(m["bericht"])
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
		var tabelle: Array = []
		if not vereinslos and int(liga.get("abschluss_saison", -1)) == Welt.saison_index():
			liga = _saisonliga(d, cid)
			tabelle = liga.get("abschlusstabelle", [])
		if tabelle.is_empty():
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
	# Ein vereinsloser Trainer darf nicht ins Leere laufen. Findet sich im
	# passenden Rufbereich niemand, wird die Suche geöffnet — und zwar ohne
	# harte Schranke: sonst sitzt ein Trainer mit schwachem Ruf dauerhaft ohne
	# Verein da, weil kein einziger Klub unter seiner Grenze liegt.
	if vereinslos and kandidaten.is_empty():
		var alle: Array = Weltgenerator.clubs(d)
		alle.sort_custom(func(a, b):
			return float(d["vereine"][a]["ruf"]) < float(d["vereine"][b]["ruf"]))
		for cid in alle:
			if float(d["vereine"][cid]["ruf"]) <= ruf + 12.0:
				kandidaten.append(cid)
		# Im Zweifel die schwächsten Vereine der Welt — irgendwo fängt
		# jede zweite Trainerkarriere wieder an.
		if kandidaten.is_empty():
			kandidaten = alle.slice(0, 6)
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
