class_name Kabine
extends RefCounted
## Die Kabine — Hallenherz' zweites eigenes System.
##
## Eine Mannschaft ist kein Attributdurchschnitt. Es gibt Wortfuehrer, Gruppen
## (nach Herkunft, Alter oder Spielzeit) und Reibung. Aus Hierarchie, Gruppenbildung
## und individueller Zufriedenheit entsteht das "Kabinenklima", das direkt in die
## Mannschaftsleistung eingeht und eigene Ereignisse erzeugt.

## Gewichteter Einfluss eines Spielers in der Kabine.
static func einfluss(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = d["spieler"][sid]
	var fuehrung: float = float(sp["attr"]["fuehrung"])
	var erfahrung: float = clampf(float(sp["alter"]) - 20.0, 0.0, 16.0)
	var leistung: float = Spielerfabrik.gesamt(sp) / 100.0
	var rolle: String = str(sp["vertrag"].get("rolle", "rotation"))
	var rollenwert: float = {"leistungstraeger": 1.35, "stammspieler": 1.1, "rotation": 0.85, "ergaenzung": 0.6, "talent": 0.7}.get(rolle, 0.9)
	return (fuehrung * 2.4 + erfahrung * 1.1 + leistung * 22.0) * rollenwert

## Die drei einflussreichsten Spieler eines Kaders.
static func wortfuehrer(d: Dictionary, cid: String, anzahl: int = 3) -> Array:
	var liste: Array = (d["vereine"][cid]["kader"] as Array).duplicate()
	liste.sort_custom(func(a, b): return einfluss(d, a) > einfluss(d, b))
	return liste.slice(0, anzahl)

## Gruppen in der Kabine.
##
## Fuer den eigenen Verein kommen sie aus dem Beziehungsgeflecht — aus
## tatsaechlichen Bindungen also. Fuer fremde Vereine bleibt es bei der
## Einteilung nach Herkunft und Alter: dort gibt es kein Netz, und fuer eine
## Zeile im Scoutingbericht reicht das Etikett.
static func gruppen(d: Dictionary, cid: String) -> Array:
	if cid == Welt.mein_verein_id:
		var aus_netz: Array = []
		for c in Beziehungen.cliquen(d, cid):
			var anfuehrer: String = str((c as Dictionary)["anfuehrer"])
			aus_netz.append({
				"art": "clique",
				"bezeichnung": "Der Kreis um %s" % Spielerfabrik.kurz_name(d["spieler"][anfuehrer]),
				"mitglieder": (c as Dictionary)["mitglieder"],
			})
		if not aus_netz.is_empty():
			return aus_netz
	return _gruppen_nach_etikett(d, cid)

static func _gruppen_nach_etikett(d: Dictionary, cid: String) -> Array:
	var nach_nation := {}
	var jung: Array = []
	var alt: Array = []
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		var n: String = str(sp["nation"])
		if not nach_nation.has(n):
			nach_nation[n] = []
		(nach_nation[n] as Array).append(sid)
		if int(sp["alter"]) <= 22:
			jung.append(sid)
		elif int(sp["alter"]) >= 30:
			alt.append(sid)
	var ergebnis: Array = []
	for n in nach_nation.keys():
		if (nach_nation[n] as Array).size() >= 3:
			ergebnis.append({
				"art": "herkunft",
				"bezeichnung": "Gruppe %s" % Namen.KULTUR_NAME.get(n, n),
				"mitglieder": nach_nation[n],
			})
	if jung.size() >= 4:
		ergebnis.append({"art": "alter", "bezeichnung": "Die Jungen", "mitglieder": jung})
	if alt.size() >= 4:
		ergebnis.append({"art": "alter", "bezeichnung": "Die Etablierten", "mitglieder": alt})
	return ergebnis

## Kabinenklima 0..100 — Mischung aus Moral, Hierarchie und Unzufriedenheit.
static func klima_berechnen(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var kader: Array = v["kader"]
	if kader.is_empty():
		return 50.0
	var moral := 0.0
	var teamgeist := 0.0
	var unzufrieden := 0.0
	for sid in kader:
		var sp: Dictionary = d["spieler"][sid]
		moral += float(sp["moral"])
		teamgeist += float(sp["attr"]["teamgeist"])
		unzufrieden += float(sp["unzufriedenheit"])
	var n: float = float(kader.size())
	var basis: float = moral / n * 0.55 + (teamgeist / n) * 1.4 - (unzufrieden / n) * 0.6
	# Wortfuehrer mit hohem Teamgeist stabilisieren, Hitzkoepfe destabilisieren
	for sid in wortfuehrer(d, cid):
		var sp2: Dictionary = d["spieler"][sid]
		basis += (float(sp2["attr"]["teamgeist"]) - 10.0) * 0.55
		basis -= maxf(float(sp2["charakter"].get("temperament", 10.0)) - 14.0, 0.0) * 0.5
	if Trainerkarriere.bonus_fuer(d, cid, "kumpeltyp"):
		basis += 3.0
	if Trainerkarriere.bonus_fuer(d, cid, "eiserne_hand"):
		basis += 2.0
	# Das Beziehungsgeflecht — aber nur fuer den eigenen Verein. Fuer 135
	# fremde Kabinen ein Netz aus je 190 Paaren zu fuehren waere Rechenzeit
	# und Speicher fuer etwas, das niemand anschaut.
	if cid == Welt.mein_verein_id:
		basis += (Beziehungen.geschlossenheit(d, cid) - 50.0) * 0.30
	return clampf(basis, 5.0, 100.0)

## Leistungsfaktor, den die Simulation auf die Mannschaft anwendet.
static func teamfaktor(d: Dictionary, cid: String) -> float:
	var klima: float = float(d["vereine"][cid].get("stimmung_kabine", 60.0))
	return clampf(0.94 + (klima - 55.0) * 0.0022, 0.9, 1.06)

## Woechentliche Kabinenereignisse.
static func wochenpuls(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		v["stimmung_kabine"] = lerpf(float(v.get("stimmung_kabine", 60.0)), klima_berechnen(d, cid), 0.3)
		_unzufriedenheit_pflegen(d, cid)
		if cid == Welt.mein_verein_id:
			Beziehungen.wochenwechsel(d, cid)
			_ereignis_pruefen(d, cid)
			_konflikt_melden(d, cid)

static func _unzufriedenheit_pflegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		var rolle: String = str(sp["vertrag"].get("rolle", "rotation"))
		var erwartet: float = {"leistungstraeger": 46.0, "stammspieler": 36.0, "rotation": 20.0, "ergaenzung": 8.0, "talent": 12.0}.get(rolle, 20.0)
		var spiele: int = int(sp["stats"]["saison"]["spiele"])
		var delta := 0.0
		if spiele >= 4:
			var schnitt: float = float(sp["stats"]["saison"]["minuten"]) / float(spiele)
			if schnitt < erwartet * 0.6:
				delta += 1.4
			elif schnitt > erwartet * 0.9:
				delta -= 1.1
		var ehrgeiz: float = float(sp["charakter"].get("ehrgeiz", 12.0)) / 20.0
		var loyalitaet: float = float(sp["charakter"].get("loyalitaet", 12.0)) / 20.0
		delta *= 0.6 + ehrgeiz
		delta -= loyalitaet * 0.35
		# Vertragsende naht
		var rest: int = int(sp["vertrag"].get("bis_saison", 3)) - Welt.saison_index()
		if rest <= 0:
			delta += 0.5
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) + delta, 0.0, 100.0)
		if float(sp["unzufriedenheit"]) > 72.0 and not bool(sp["transferwunsch"]):
			sp["transferwunsch"] = true
			if cid == Welt.mein_verein_id:
				Welt.nachricht({
					"typ": "kabine", "wichtig": true,
					"betreff": "%s bittet um einen Wechsel" % Spielerfabrik.voller_name(sp),
					"text": "%s ist mit seiner Rolle unzufrieden und hat den Verein um die Freigabe für einen Wechsel gebeten. %s" % [
						Spielerfabrik.kurz_name(sp),
						str(Namen.waehle(Textbank.SPIELER_TRANSFERWUNSCH)) % Spielerfabrik.kurz_name(sp)],
					"daten": {"spieler": sid},
				})
		elif float(sp["unzufriedenheit"]) < 30.0 and bool(sp["transferwunsch"]):
			sp["transferwunsch"] = false

static func _ereignis_pruefen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var klima: float = float(v["stimmung_kabine"])
	if Namen.zufall() > 0.34:
		return
	var fuehrende := wortfuehrer(d, cid, 3)
	if fuehrende.is_empty():
		return
	var sprecher: Dictionary = d["spieler"][fuehrende[Namen.wuerfel(0, fuehrende.size() - 1)]]
	if klima < 40.0:
		var gruppen_liste := gruppen(d, cid)
		var text := "%s hat in der Kabine deutliche Worte gefunden. Die Stimmung ist angespannt." % Spielerfabrik.voller_name(sprecher)
		if not gruppen_liste.is_empty():
			var g: Dictionary = gruppen_liste[Namen.wuerfel(0, gruppen_liste.size() - 1)]
			text = "Zwischen %s und dem Rest der Mannschaft knirscht es. %s versucht zu vermitteln." % [g["bezeichnung"], Spielerfabrik.voller_name(sprecher)]
		Welt.nachricht({"typ": "kabine", "betreff": "Unruhe in der Kabine", "text": text})
		for sid in v["kader"]:
			d["spieler"][sid]["moral"] = clampf(float(d["spieler"][sid]["moral"]) - Namen.bereich(0.5, 2.5), 5.0, 100.0)
	elif klima > 72.0:
		Welt.nachricht({
			"typ": "kabine",
			"betreff": "Gute Stimmung im Team",
			"text": "%s berichtet von einer geschlossenen Mannschaft. Die Einheiten laufen konzentriert, niemand zieht sich zurück." % Spielerfabrik.voller_name(sprecher),
		})
		for sid in v["kader"]:
			d["spieler"][sid]["moral"] = clampf(float(d["spieler"][sid]["moral"]) + Namen.bereich(0.3, 1.8), 5.0, 100.0)

## Meldet einen neuen offenen Konflikt — einmal je Paar, nicht jede Woche.
##
## Ein Zerwuerfnis, das woechentlich dieselbe Nachricht erzeugt, liest man
## zweimal und ueberblaettert es danach. Es soll einmal auffallen und dann in
## der Kabine stehen, bis man etwas tut.
static func _konflikt_melden(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var gemeldet: Array = v.get("konflikte_gemeldet", [])
	var noch_offen: Array = []
	for k in Beziehungen.konflikte(d, cid):
		var eintrag: Dictionary = k
		var schluessel := Beziehungen.schluessel(str(eintrag["a"]), str(eintrag["b"]))
		noch_offen.append(schluessel)
		if gemeldet.has(schluessel):
			continue
		var sa: Dictionary = d["spieler"][str(eintrag["a"])]
		var sb: Dictionary = d["spieler"][str(eintrag["b"])]
		Welt.nachricht({
			"typ": "kabine", "wichtig": true,
			"betreff": "Zerwürfnis: %s und %s" % [Spielerfabrik.kurz_name(sa), Spielerfabrik.kurz_name(sb)],
			"text": "%s\n\nIn der Kabine gehen die beiden einander aus dem Weg. Auf dem Feld kostet das Abstimmung. In der Kabine können Sie eine Aussprache ansetzen oder die beiden vorerst trennen." % str(eintrag["grund"]),
		})
	# Beigelegte Konflikte duerfen wieder gemeldet werden, wenn sie
	# zurueckkommen.
	var behalten: Array = []
	for s2 in gemeldet:
		if noch_offen.has(str(s2)):
			behalten.append(str(s2))
	v["konflikte_gemeldet"] = behalten + noch_offen.filter(func(x): return not behalten.has(x))

## Einzelgespraech mit einem Spieler (vier Tonlagen mit unterschiedlichem Risiko).
static func gespraech(d: Dictionary, sid: String, tonlage: String) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var temperament: float = float(sp["charakter"].get("temperament", 10.0)) / 20.0
	var profitum: float = float(sp["charakter"].get("profitum", 12.0)) / 20.0
	var erfolg := 0.5
	match tonlage:
		"lob":
			erfolg = 0.55 + profitum * 0.2 - temperament * 0.1
		"kritik":
			erfolg = 0.35 + profitum * 0.45 - temperament * 0.35
		"vertrauen":
			erfolg = 0.5 + float(sp["charakter"].get("loyalitaet", 12.0)) / 40.0
		"druck":
			erfolg = 0.3 + profitum * 0.4 - temperament * 0.3
	var gelungen: bool = Namen.zufall() < clampf(erfolg, 0.08, 0.92)
	var moral_delta := 0.0
	var unzufrieden_delta := 0.0
	var text := ""
	if gelungen:
		match tonlage:
			"lob":
				moral_delta = 6.0
				text = str(Namen.waehle(Textbank.SPIELER_LOB_ANGENOMMEN)) % Spielerfabrik.kurz_name(sp)
			"kritik":
				moral_delta = -2.0
				unzufrieden_delta = -14.0
				text = str(Namen.waehle(Textbank.SPIELER_KRITIK_ANGENOMMEN)) % Spielerfabrik.kurz_name(sp)
			"vertrauen":
				moral_delta = 9.0
				unzufrieden_delta = -18.0
				text = "%s fühlt sich ernst genommen." % Spielerfabrik.kurz_name(sp)
			"druck":
				moral_delta = 3.0
				unzufrieden_delta = -8.0
				text = "%s reagiert trotzig — aber im positiven Sinn." % Spielerfabrik.kurz_name(sp)
	else:
		match tonlage:
			"lob":
				moral_delta = 1.0
				text = str(Namen.waehle(Textbank.SPIELER_LOB_ABGEPRALLT)) % Spielerfabrik.kurz_name(sp)
			"kritik":
				moral_delta = -9.0
				unzufrieden_delta = 12.0
				text = str(Namen.waehle(Textbank.SPIELER_KRITIK_ABGEPRALLT)) % Spielerfabrik.kurz_name(sp)
			"vertrauen":
				moral_delta = -2.0
				text = "%s bleibt skeptisch." % Spielerfabrik.kurz_name(sp)
			"druck":
				moral_delta = -12.0
				unzufrieden_delta = 16.0
				text = "%s nimmt die Ansage persönlich." % Spielerfabrik.kurz_name(sp)
	sp["moral"] = clampf(float(sp["moral"]) + moral_delta, 5.0, 100.0)
	sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) + unzufrieden_delta, 0.0, 100.0)
	sp["letztes_gespraech_tag"] = int(d["tag"])
	return {"gelungen": gelungen, "text": text}
