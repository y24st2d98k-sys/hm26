class_name KI
extends RefCounted
## Die Entscheidungen der Computervereine: Aufstellung, Taktik, Trainingsplan,
## Vertragsverlaengerungen und Personalarbeit. Die Welt lebt dadurch auch dann
## weiter, wenn der Spieler sich um nichts kuemmert.

static func aufstellung_pruefen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var mensch: bool = bool(v.get("ist_mensch", false))
	var auf: Dictionary = v["aufstellung"]
	var neu_aufstellen := false
	if mensch:
		if bool(d["einstellungen"].get("auto_aufstellung", true)):
			# Der Trainerstab stellt vor jeder Partie die beste verfügbare Sieben.
			Weltgenerator.setze_standardaufstellung(d, cid)
			return
		# Sonst nur eingreifen, wenn jemand ausfaellt.
		for block in ["angriff", "abwehr"]:
			for pos in (auf.get(block, {}) as Dictionary).keys():
				var sid: String = str(auf[block][pos])
				if sid == "" or not d["spieler"].has(sid):
					neu_aufstellen = true
					continue
				var sp: Dictionary = d["spieler"][sid]
				if not (sp["verletzung"] as Dictionary).is_empty() or int(sp["sperre"]) > 0 or str(sp["verein"]) != cid:
					neu_aufstellen = true
		if not neu_aufstellen:
			auf["bank"] = Weltgenerator.bank_aus_kader(d, cid, auf)
			return
		Weltgenerator.setze_standardaufstellung(d, cid)
		return
	Weltgenerator.setze_standardaufstellung(d, cid)
	taktik_anpassen(d, cid)

## Taktik nach Gegnerstaerke und eigener Lage.
static func taktik_anpassen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var t: Dictionary = v["taktik"]
	var naechstes: Dictionary = Welt.naechstes_spiel(cid)
	var gegnerruf: float = float(v["ruf"])
	if not naechstes.is_empty():
		var gid: String = str(naechstes["gast"]) if str(naechstes["heim"]) == cid else str(naechstes["heim"])
		gegnerruf = float(d["vereine"][gid]["ruf"])
	var unterschied: float = float(v["ruf"]) - gegnerruf
	if unterschied > 14.0:
		t["mentalitaet"] = "offensiv"
		t["tempo"] = Namen.wuerfel(55, 78)
	elif unterschied < -14.0:
		t["mentalitaet"] = "defensiv"
		t["tempo"] = Namen.wuerfel(28, 48)
	else:
		t["mentalitaet"] = "ausgeglichen"
		t["tempo"] = Namen.wuerfel(42, 62)
	# Abwehrformation passt zur Kaderqualitaet
	var beweglich := 0.0
	var n := 0
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp["ist_torwart"]):
			continue
		beweglich += float(sp["attr"]["beweglichkeit"]) + float(sp["attr"]["antizipation"])
		n += 1
	var schnitt: float = beweglich / maxf(float(n) * 2.0, 1.0)
	if schnitt > 13.5 and Namen.zufall() < 0.5:
		t["abwehr"] = Namen.waehle(["5-1", "3-2-1"])
	elif schnitt < 10.0:
		t["abwehr"] = "6-0"
	elif Namen.zufall() < 0.25:
		t["abwehr"] = Namen.waehle(["6-0", "5-1"])
	# Angriffsausrichtung nach Kaderprofil
	t["angriff"] = _bester_angriffsstil(d, cid)
	t["haerte"] = clampi(int(t["haerte"]) + Namen.wuerfel(-6, 6), 20, 85)
	t["risiko"] = clampi(int(t["risiko"]) + Namen.wuerfel(-8, 8), 15, 85)
	t["wechselspiel"] = clampi(int(t.get("wechselspiel", 55)) + Namen.wuerfel(-6, 6), 20, 90)
	t["siebter_feldspieler"] = "schluss" if Namen.zufall() < 0.45 else "nie"

static func _bester_angriffsstil(d: Dictionary, cid: String) -> String:
	var v: Dictionary = d["vereine"][cid]
	var werte := {"kreisfokus": 0.0, "aussenfokus": 0.0, "rueckraumfokus": 0.0, "tempospiel": 0.0, "positionsangriff": 6.0}
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		var g: float = Spielerfabrik.gesamt(sp)
		match str(sp["position"]):
			"KM":
				werte["kreisfokus"] += g * 0.6
			"LA", "RA":
				werte["aussenfokus"] += g * 0.35
			"RL", "RR":
				werte["rueckraumfokus"] += g * 0.4
			"RM":
				werte["rueckraumfokus"] += g * 0.2
		werte["tempospiel"] += float(sp["attr"]["tempo"]) * 0.6 + float(sp["attr"]["ausdauer"]) * 0.4
	werte["tempospiel"] *= 0.12
	var best := "positionsangriff"
	var bw := -1.0
	for k in werte.keys():
		if float(werte[k]) > bw:
			bw = float(werte[k])
			best = k
	return best

# --------------------------------------------------------------- Wochenlauf ---

static func wochenlogik(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		if bool(d["vereine"][cid].get("ist_mensch", false)):
			continue
		_trainingsplan(d, cid)
		_vertraege_pflegen(d, cid)
		kader_auffuellen(d, cid)
		if Namen.zufall() < 0.08:
			_personal_pflegen(d, cid)
		if Namen.zufall() < 0.1:
			_infrastruktur(d, cid)

static func _trainingsplan(d: Dictionary, cid: String) -> void:
	var p: Dictionary = Training.plan(d, cid)
	var lazarett := Medizin.lazarett(d, cid)
	if lazarett.size() >= 4:
		p["intensitaet"] = clampi(int(p["intensitaet"]) - 8, 25, 90)
		p["schwerpunkt"] = "regeneration"
	else:
		p["intensitaet"] = clampi(int(p["intensitaet"]) + Namen.wuerfel(-5, 6), 35, 85)
		if Namen.zufall() < 0.3:
			p["schwerpunkt"] = Namen.waehle(["ausgeglichen", "athletik", "wurf", "abwehr", "spielaufbau", "taktik"])
	# Regenerationsbudget auf die am staerksten belasteten Spieler verteilen
	var budget: int = Training.regenerationsbudget(d, cid)
	var kader: Array = (d["vereine"][cid]["kader"] as Array).duplicate()
	kader.sort_custom(func(a, b): return float(d["spieler"][a]["last"]) > float(d["spieler"][b]["last"]))
	var zuteilung := {}
	for i in range(mini(budget, kader.size())):
		if float(d["spieler"][kader[i]]["last"]) > 45.0:
			zuteilung[kader[i]] = 1
	p["regeneration_zuteilung"] = zuteilung

## Verlaengert auslaufende Vertraege. Ein Verein laesst nur gehen, wen er wirklich
## nicht braucht — sonst wuerde die Liga binnen weniger Saisons ausbluten.
static func _vertraege_pflegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var saison: int = Welt.saison_index()
	var kaderstaerke := _kaderschnitt(d, cid)
	for sid in (v["kader"] as Array).duplicate():
		var sp: Dictionary = d["spieler"][sid]
		var rest: int = int(sp["vertrag"].get("bis_saison", 9)) - saison
		if rest > 0:
			continue
		var staerke: float = Spielerfabrik.gesamt(sp)
		var wunsch: float = Spielerfabrik.gehaltsvorstellung(sp, float(v["ruf"]))
		var auslastung := Finanzen.gehaltsauslastung(d, cid)
		# Zu teuer und zu schwach: der Verein laesst ihn ziehen.
		if auslastung > 112.0 and staerke < kaderstaerke - 6.0:
			continue
		if int(sp["alter"]) >= 35 and staerke < kaderstaerke - 4.0:
			continue
		if (v["kader"] as Array).size() > 24 and staerke < kaderstaerke - 10.0:
			continue
		sp["vertrag"]["gehalt"] = wunsch * Namen.bereich(1.0, 1.12)
		sp["vertrag"]["bis_saison"] = saison + Namen.wuerfel(2, 4)

static func _kaderschnitt(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	var n := 0
	for sid in d["vereine"][cid]["kader"]:
		summe += Spielerfabrik.gesamt(d["spieler"][sid])
		n += 1
	return summe / maxf(float(n), 1.0)

## Fuellt Luecken im Kader mit vereinslosen Spielern.
## Ohne das wuerde der Markt sich mit Spielern fuellen, die niemand mehr holt.
static func kader_auffuellen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if bool(v.get("ist_mensch", false)):
		return
	for _versuch in range(8):
		var kader: Array = v["kader"]
		var luecke := _fehlende_position(d, cid)
		if luecke == "" and kader.size() >= 18:
			return
		var notlage: bool = kader.size() < 15
		var pos: String = luecke if luecke != "" else schwaechste_position(d, cid)
		var kandidat := _bester_freier(d, cid, pos, notlage)
		if kandidat == "":
			if not notlage:
				if luecke == "":
					return
				continue
			# Notlage: der Verein verpflichtet, wen er kriegen kann.
			kandidat = _notverpflichtung(d, cid, pos)
			if kandidat == "":
				return
		var sp: Dictionary = d["spieler"][kandidat]
		var gehalt: float = Spielerfabrik.gehaltsvorstellung(sp, float(v["ruf"]))
		Transfermarkt.transfer_durchfuehren(d, kandidat, cid, 0.0, gehalt, Namen.wuerfel(1, 3), "rotation")

## Position, auf der dem Verein ein einsatzfaehiger Spieler fehlt.
static func _fehlende_position(d: Dictionary, cid: String) -> String:
	var zaehler := {}
	for p in Spielerfabrik.POSITIONEN:
		zaehler[p] = 0
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		zaehler[str(sp["position"])] = int(zaehler[str(sp["position"])]) + 1
	for p in Spielerfabrik.POSITIONEN:
		var soll: int = 3 if p == "TW" else 2
		if int(zaehler[p]) < soll:
			return p
	return ""

static func schwaechste_position(d: Dictionary, cid: String) -> String:
	return Transfermarkt.schwaechste_position(d, cid)

## Bester vereinsloser Spieler auf einer Position, den der Verein bezahlen kann.
## Bei Notlage (zu kleiner Kader) wird die Gehaltsgrenze deutlich gelockert.
static func _bester_freier(d: Dictionary, cid: String, pos: String, notlage: bool = false) -> String:
	var v: Dictionary = d["vereine"][cid]
	var spielraum: float = float(v["gehaltsbudget"]) * 1.1 - Finanzen.spielergehaelter(d, cid) - Finanzen.personalgehaelter(d, cid)
	var grenze: float = float(v["gehaltsbudget"]) * (0.16 if notlage else 0.06)
	grenze = maxf(grenze, spielraum)
	var best := ""
	var bw := -1.0
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["verein"]) != "" or str(sp["position"]) != pos:
			continue
		if Spielerfabrik.gehaltsvorstellung(sp, float(v["ruf"])) > grenze:
			continue
		var w: float = Spielerfabrik.gesamt(sp)
		if w > bw:
			bw = w
			best = sid
	return best

## Letzter Ausweg: ein Verein, dem sonst die Spieler ausgehen, holt einen
## Spieler aus dem Umfeld. Damit kann keine Mannschaft unbesetzt antreten.
static func _notverpflichtung(d: Dictionary, cid: String, pos: String) -> String:
	var v: Dictionary = d["vereine"][cid]
	var ziel: float = clampf(float(v["ruf"]) * 0.5 + Namen.bereich(-6.0, 6.0), 14.0, 55.0)
	var sid := Weltgenerator.neue_spieler_id(d)
	var sp := Spielerfabrik.erzeuge(sid, Namen.kultur_zufall(str(v["nation"]), 0.85),
		Namen.wuerfel(18, 30), ziel, pos, int(d["startjahr"]))
	sp["kenntnis"] = 45.0
	d["spieler"][sid] = sp
	Transfermarkt.transfer_durchfuehren(d, sid, cid, 0.0,
		Spielerfabrik.gehaltsvorstellung(sp, float(v["ruf"])), Namen.wuerfel(1, 2), "ergaenzung")
	return sid

static func _personal_pflegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	for pid in (v["personal"] as Array).duplicate():
		var mp: Dictionary = d["personal"].get(pid, {})
		if mp.is_empty():
			continue
		if int(mp["alter"]) > 66:
			(v["personal"] as Array).erase(pid)
			var neu := Weltgenerator.erzeuge_mitarbeiter(d, str(mp["rolle"]), float(v["ruf"]), str(v["nation"]))
			d["personal"][neu]["verein"] = cid
			(v["personal"] as Array).append(neu)

static func _infrastruktur(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if not (v["halle"]["bauprojekt"] as Dictionary).is_empty():
		return
	var bereiche := ["trainingszentrum", "jugendarbeit", "medizin", "analyse", "regeneration", "halle"]
	var bereich: String = str(Namen.waehle(bereiche))
	var kosten: float = Finanzen.ausbaukosten(d, cid, bereich)
	if float(v["kasse"]) > kosten * 2.5:
		Finanzen.ausbau_starten(d, cid, bereich)

## Alle KI-Vereine verlaengern auslaufende Vertraege — muss VOR dem
## Vertragsablauf zum Saisonwechsel laufen.
static func vertragsrunde(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		if bool(d["vereine"][cid].get("ist_mensch", false)):
			continue
		_vertraege_pflegen(d, cid)

## Setzt fuer alle KI-Vereine eine sinnvolle Startaufstellung nach der Saisonpause.
static func saisonvorbereitung(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		kader_auffuellen(d, cid)
	for cid in Weltgenerator.clubs(d):
		Weltgenerator.setze_standardaufstellung(d, cid)
		if not bool(d["vereine"][cid].get("ist_mensch", false)):
			taktik_anpassen(d, cid)
