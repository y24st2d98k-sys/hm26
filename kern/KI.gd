class_name KI
extends RefCounted
## Die Entscheidungen der Computervereine: Aufstellung, Taktik, Trainingsplan,
## Vertragsverlaengerungen und Personalarbeit. Die Welt lebt dadurch auch dann
## weiter, wenn der Spieler sich um nichts kuemmert.

static func aufstellung_pruefen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if bool(v.get("ist_nationalteam", false)):
		# Betreut der Spieler diese Auswahl, bleibt seine Aufstellung stehen.
		if not bool(v.get("ist_mensch", false)):
			Weltgenerator.setze_standardaufstellung(d, cid)
		elif not (v["aufstellung"].get("angriff", {}) as Dictionary).has("TW"):
			Weltgenerator.setze_standardaufstellung(d, cid)
		return
	# Vor jeder Partie: jeder im Kader traegt eine eindeutige Rueckennummer.
	Trikot.kader_nummerieren(d, cid)
	var mensch: bool = bool(v.get("ist_mensch", false))
	if mensch:
		# Gespeicherte Spielidee zur Lage gegen diesen Gegner ziehen.
		var naechstes: Dictionary = Welt.naechstes_spiel(cid)
		if not naechstes.is_empty():
			var gegner: String = str(naechstes["gast"]) if str(naechstes["heim"]) == cid else str(naechstes["heim"])
			var gezogen := Taktikprofile.automatisch_anwenden(d, cid, gegner)
			if gezogen != "" and str(v.get("letztes_profil", "")) != gezogen:
				v["letztes_profil"] = gezogen
				Welt.nachricht({
					"typ": "taktik",
					"betreff": "Spielidee gewechselt: %s" % gezogen,
					"text": "Gegen %s greift Ihre hinterlegte Regel für die Lage „%s“." % [
						str(d["vereine"].get(gegner, {}).get("name", "den Gegner")),
						str(Taktikprofile.LAGEN[Taktikprofile.lage_gegen(d, cid, gegner)]["name"])],
				})
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

## Legt die Handschrift eines Vereins fest: welche Deckung er spielt und
## worauf sein Angriff ausgerichtet ist.
##
## Das passiert einmal in der Saisonvorbereitung und sonst nie. Ein Verein,
## der seine Deckung staendig wechselt, bekommt sie nie eingeschliffen — das
## gilt fuer die Computertrainer genauso wie fuer den Spieler.
static func formation_festlegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if bool(v.get("ist_mensch", false)):
		return
	var t: Dictionary = v["taktik"]
	var beweglich := 0.0
	var n := 0
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp["ist_torwart"]):
			continue
		beweglich += float(sp["attr"]["beweglichkeit"]) + float(sp["attr"]["antizipation"])
		n += 1
	var schnitt: float = beweglich / maxf(float(n) * 2.0, 1.0)
	var wunsch: String = str(t.get("abwehr", "6-0"))
	if schnitt > 13.5 and Namen.zufall() < 0.5:
		wunsch = str(Namen.waehle(["5-1", "3-2-1"]))
	elif schnitt < 10.0:
		wunsch = "6-0"
	elif Namen.zufall() < 0.25:
		wunsch = str(Namen.waehle(["6-0", "5-1"]))
	# Eine eingespielte Deckung gibt man nicht leichtfertig auf. Nur wenn der
	# Kader wirklich nicht mehr dazu passt — oder das System ohnehin noch nicht
	# sitzt — wird umgestellt.
	var sitzt: float = Vertrautheit.wert(d, cid, "abwehr", str(t.get("abwehr", "6-0")))
	if wunsch != str(t.get("abwehr", "6-0")) and sitzt >= 80.0 and Namen.zufall() < 0.72:
		wunsch = str(t.get("abwehr", "6-0"))
	t["abwehr"] = wunsch
	t["angriff"] = _bester_angriffsstil(d, cid)
	v["stammabwehr"] = wunsch
	v["stammangriff"] = str(t["angriff"])

## Stellt vor einer Partie die festgelegte Formation wieder her. Legt sie beim
## ersten Mal an, damit auch aeltere Spielstaende sofort eine haben.
static func formation_sichern(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if str(v.get("stammabwehr", "")) == "":
		formation_festlegen(d, cid)
		return
	v["taktik"]["abwehr"] = str(v["stammabwehr"])
	v["taktik"]["angriff"] = str(v["stammangriff"])

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
	# Die Formation wird hier ausdruecklich nicht angefasst.
	#
	# Vor der Vertrautheit war es folgerichtig, die Deckung vor jedem Spiel neu
	# zu wuerfeln — sie kostete ja nichts. Jetzt kostet sie: eine Mannschaft,
	# die woechentlich zwischen 6-0 und 3-2-1 springt, steht dauerhaft wie
	# frisch umgestellt da. Genau das soll der Spieler spueren, und genau
	# deshalb duerfen die Computertrainer es nicht tun. Die Formation ist die
	# Handschrift eines Vereins; sie faellt in der Saisonvorbereitung
	# (formation_festlegen) und gilt dann.
	formation_sichern(d, cid)
	t["haerte"] = clampi(int(t["haerte"]) + Namen.wuerfel(-6, 6), 20, 85)
	t["risiko"] = clampi(int(t["risiko"]) + Namen.wuerfel(-8, 8), 15, 85)
	t["wechselspiel"] = clampi(int(t.get("wechselspiel", 55)) + Namen.wuerfel(-6, 6), 20, 90)
	t["siebter_feldspieler"] = "schluss" if Namen.zufall() < 0.45 else "nie"
	# Auch die Computertrainer geben ihren Spielern Rollen — sonst waere die
	# Anweisungstafel ein Vorteil, den nur der Mensch hat.
	Anweisungen.automatisch(d, cid)

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
		# Guenstig und sichert die Zusage, dass jede Nummer im Kader
		# eindeutig ist — unabhaengig davon, wie ein Spieler hereinkam.
		Trikot.kader_nummerieren(d, cid)
		# Die Fanszene lebt in jedem Verein, auch in denen der KI: sie
		# bestimmt Zuschauer, Merchandising und Hallenpuls.
		Fanszene.wochenwechsel(d, cid)
		if bool(d["vereine"][cid].get("ist_mensch", false)):
			Fanszene.meldungen_pruefen(d, cid)
			continue
		if Namen.zufall() < 0.06:
			Ticketing.ki_preise(d, cid)
		if Namen.zufall() < 0.12:
			Darlehen.ki_pruefen(d, cid)
		_trainingsplan(d, cid)
		_vertraege_pflegen(d, cid)
		kader_auffuellen(d, cid)
		if Namen.zufall() < 0.05:
			Mentoring.automatisch(d, cid)
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
		var wunsch: float = Finanzen.gehaltswunsch(d, cid, sp)
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
	# Eine Nationalmannschaft nominiert, sie verpflichtet nicht: sonst wuerden
	# ihr vereinslose Spieler zugeschlagen, die danach keinem Verein mehr
	# gehoeren und aus dem Transfermarkt verschwinden.
	if bool(v.get("ist_mensch", false)) or bool(v.get("ist_nationalteam", false)):
		return
	for _versuch in range(8):
		var kader: Array = v["kader"]
		var luecke := _fehlende_position(d, cid)
		if luecke == "" and kader.size() >= 18:
			return
		var pos: String = luecke if luecke != "" else schwaechste_position(d, cid)
		# Eine Position ganz ohne Spieler ist immer eine Notlage — sonst stuende
		# ein Verein ohne Torwart da, weil gerade kein bezahlbarer frei ist.
		var notlage: bool = kader.size() < 15 or (luecke != "" and _anzahl_auf(d, cid, luecke) == 0)
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
		var gehalt: float = Finanzen.gehaltswunsch(d, cid, sp)
		Transfermarkt.transfer_durchfuehren(d, kandidat, cid, 0.0, gehalt, Namen.wuerfel(1, 3), "rotation")

## Wie viele Spieler der Verein auf einer Position hat.
static func _anzahl_auf(d: Dictionary, cid: String, pos: String) -> int:
	var n := 0
	for sid in d["vereine"][cid]["kader"]:
		if str(d["spieler"][sid]["position"]) == pos:
			n += 1
	return n

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
	# Ruf und Lohnniveau einmal holen: die Schleife laeuft ueber alle Spieler
	# der Welt und wird oefter durchlaufen, als es auf den ersten Blick aussieht.
	var ruf: float = float(v["ruf"])
	var niveau: float = Finanzen.lohnniveau(d, cid)
	var best := ""
	var bw := -1.0
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["verein"]) != "" or str(sp["position"]) != pos:
			continue
		# Ein gesichtetes Nachwuchstalent ist kein vereinsloser Profi: es
		# gehoert in eine Akademie und nicht in einen Profikader.
		if bool(sp.get("jugendspieler", false)):
			continue
		var w: float = Spielerfabrik.gesamt(sp)
		if w <= bw:
			continue
		if Spielerfabrik.gehaltsvorstellung(sp, ruf, niveau) > grenze:
			continue
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
		Finanzen.gehaltswunsch(d, cid, sp), Namen.wuerfel(1, 2), "ergaenzung")
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
			# Der eine Punkt im Jahr, an dem eine Deckung wirklich neu gewaehlt
			# wird — mit dem ganzen Sommer Zeit, sie einzuschleifen.
			formation_festlegen(d, cid)
			taktik_anpassen(d, cid)
