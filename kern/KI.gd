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
		# Beim Spielerverein nur eingreifen, wenn jemand ausfaellt.
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
			auf["bank"] = Weltgenerator._bank_aus_kader(d, cid, auf)
			return
		Weltgenerator._setze_standardaufstellung(d, cid)
		return
	Weltgenerator._setze_standardaufstellung(d, cid)
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
	for cid in d["vereine"].keys():
		if bool(d["vereine"][cid].get("ist_mensch", false)):
			continue
		_trainingsplan(d, cid)
		if Namen.zufall() < 0.2:
			_vertraege_pflegen(d, cid)
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

static func _vertraege_pflegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var saison: int = Welt.saison_index()
	for sid in (v["kader"] as Array).duplicate():
		var sp: Dictionary = d["spieler"][sid]
		var rest: int = int(sp["vertrag"].get("bis_saison", 9)) - saison
		if rest > 0:
			continue
		var wunsch: float = Spielerfabrik.gehaltsvorstellung(sp, float(v["ruf"]))
		if Finanzen.gehaltsauslastung(d, cid) > 105.0 and Spielerfabrik.gesamt(sp) < 55.0:
			continue
		if Namen.zufall() < 0.65:
			sp["vertrag"]["gehalt"] = wunsch * Namen.bereich(1.0, 1.1)
			sp["vertrag"]["bis_saison"] = saison + Namen.wuerfel(2, 4)

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

## Setzt fuer alle KI-Vereine eine sinnvolle Startaufstellung nach der Saisonpause.
static func saisonvorbereitung(d: Dictionary) -> void:
	for cid in d["vereine"].keys():
		Weltgenerator._setze_standardaufstellung(d, cid)
		if not bool(d["vereine"][cid].get("ist_mensch", false)):
			taktik_anpassen(d, cid)
