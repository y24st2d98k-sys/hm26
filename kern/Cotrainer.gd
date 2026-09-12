class_name Cotrainer
extends RefCounted
## Der Co-Trainer: was zwischen zwei Spielen auffällt.
##
## Vor der Partie gibt es den Vorbericht, danach den Spielbericht. Dazwischen
## sagte bisher niemand etwas — dabei liegen die meisten Fehler eines Managers
## genau dort: eine faule Aufstellung, ein auslaufender Vertrag, ein Talent
## ohne Einsatzzeit, eine Position ohne Ersatzmann.
##
## Der Co-Trainer sieht nur, was sein Stab hergibt: Wie viele Punkte er findet
## und wie tief er schaut, hängt an der Qualität des Personals. Ein Verein ohne
## Analysten bekommt die groben Dinge zu hören, keine Feinheiten.

const STUFE_HINWEIS := 0
const STUFE_WARNUNG := 1
const STUFE_DRINGEND := 2

## Wie gut der Stab hinschaut (0..100).
static func kompetenz(d: Dictionary, cid: String) -> float:
	var taktik: float = Training.trainerqualitaet(d, cid, "taktik")
	var analyse: float = Training.trainerqualitaet(d, cid, "analyse")
	var menschen: float = Training.trainerqualitaet(d, cid, "menschenfuehrung")
	return clampf((taktik + analyse + menschen) / 3.0, 0.0, 100.0)

static func kompetenz_text(wert: float) -> String:
	if wert >= 78.0:
		return "Ihr Stab arbeitet auf höchstem Niveau."
	if wert >= 60.0:
		return "Ihr Stab arbeitet gründlich."
	if wert >= 42.0:
		return "Ihr Stab schaut auf das Wesentliche."
	return "Ihr Stab kommt kaum hinterher — mehr als das Grobe ist nicht drin."

## Alle Befunde, wichtigste zuerst.
static func befunde(d: Dictionary, cid: String) -> Array:
	if cid == "" or not d["vereine"].has(cid):
		return []
	var liste: Array = []
	_aufstellung(d, cid, liste)
	_kaderlage(d, cid, liste)
	_vertraege(d, cid, liste)
	_stimmung(d, cid, liste)
	_belastung(d, cid, liste)
	_wirtschaft(d, cid, liste)
	_nachwuchs(d, cid, liste)
	_feinheiten(d, cid, liste)
	liste.sort_custom(func(a, b): return int(a["stufe"]) > int(b["stufe"]))
	# Ein schwacher Stab übersieht die hinteren Punkte.
	var sicht: int = 2 + int(kompetenz(d, cid) / 14.0)
	return liste.slice(0, maxi(sicht, 3))

static func _melden(liste: Array, stufe: int, bereich: String, titel: String, text: String,
		ziel: String = "", sid: String = "") -> void:
	liste.append({"stufe": stufe, "bereich": bereich, "titel": titel, "text": text,
		"ziel": ziel, "spieler": sid})

# ---------------------------------------------------------------- Prüfungen ---

static func _aufstellung(d: Dictionary, cid: String, liste: Array) -> void:
	if bool(d["einstellungen"].get("auto_aufstellung", true)):
		return
	var auf: Dictionary = d["vereine"][cid].get("aufstellung", {})
	for block in ["angriff", "abwehr"]:
		for pos in (auf.get(block, {}) as Dictionary).keys():
			var sid: String = str(auf[block][pos])
			if sid == "" or not d["spieler"].has(sid):
				_melden(liste, STUFE_DRINGEND, "aufstellung", "Eine Position ist unbesetzt",
					"Im %s fehlt auf %s ein Spieler." % ["Angriff" if block == "angriff" else "Abwehrblock", str(pos)],
					"taktik")
				return
			var sp: Dictionary = d["spieler"][sid]
			if not (sp["verletzung"] as Dictionary).is_empty() or int(sp["sperre"]) > 0:
				_melden(liste, STUFE_DRINGEND, "aufstellung", "%s kann nicht spielen" % Spielerfabrik.kurz_name(sp),
					"Er steht in der Aufstellung, ist aber %s." % ("gesperrt" if int(sp["sperre"]) > 0 else "verletzt"),
					"taktik", sid)
				return
			if block == "angriff" and str(pos) != "TW" and Spielerfabrik.eignung(sp, str(pos)) < 0.72:
				_melden(liste, STUFE_WARNUNG, "aufstellung", "%s spielt auf einer fremden Position" % Spielerfabrik.kurz_name(sp),
					"Auf %s bringt er nur %d %% seiner Stärke auf die Platte." % [
						str(pos), int(Spielerfabrik.eignung(sp, str(pos)) * 100.0)], "taktik", sid)
	# Ein deutlich besserer Mann auf der Bank
	var bank_beste := ""
	var vorsprung := 0.0
	var pos_beste := ""
	for pos2 in (auf.get("angriff", {}) as Dictionary).keys():
		if str(pos2) == "TW":
			continue
		var drin: String = str(auf["angriff"][pos2])
		if drin == "" or not d["spieler"].has(drin):
			continue
		var wert_drin: float = Spielerfabrik.angriff_auf(d["spieler"][drin], str(pos2))
		for sid2 in d["vereine"][cid]["kader"]:
			if (auf["angriff"] as Dictionary).values().has(sid2):
				continue
			var kandidat: Dictionary = d["spieler"][sid2]
			if bool(kandidat["ist_torwart"]) or not (kandidat["verletzung"] as Dictionary).is_empty() or int(kandidat["sperre"]) > 0:
				continue
			var wert: float = Spielerfabrik.angriff_auf(kandidat, str(pos2))
			if wert - wert_drin > vorsprung:
				vorsprung = wert - wert_drin
				bank_beste = sid2
				pos_beste = str(pos2)
	if vorsprung >= 6.0:
		_melden(liste, STUFE_WARNUNG, "aufstellung", "%s sitzt draußen" % Spielerfabrik.kurz_name(d["spieler"][bank_beste]),
			"Auf %s wäre er %d Punkte stärker als der aufgestellte Spieler." % [pos_beste, int(vorsprung)],
			"taktik", bank_beste)

static func _kaderlage(d: Dictionary, cid: String, liste: Array) -> void:
	var v: Dictionary = d["vereine"][cid]
	var frei := {}
	for p in Spielerfabrik.POSITIONEN:
		frei[p] = 0
	var torhueter := 0
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if not (sp["verletzung"] as Dictionary).is_empty() or int(sp["sperre"]) > 0:
			continue
		frei[str(sp["position"])] = int(frei[str(sp["position"])]) + 1
		if bool(sp["ist_torwart"]):
			torhueter += 1
	if torhueter < 2:
		_melden(liste, STUFE_DRINGEND if torhueter == 0 else STUFE_WARNUNG, "kader",
			"Nur %d einsatzfähiger Torwart" % torhueter,
			"Fällt er aus, steht das Tor leer. Auf dem Transfermarkt sind vereinslose Torhüter ablösefrei zu haben.",
			"transfer")
	for p2 in Spielerfabrik.POSITIONEN:
		if p2 == "TW":
			continue
		if int(frei[p2]) == 0:
			_melden(liste, STUFE_DRINGEND, "kader", "Kein Spieler für %s" % Spielerfabrik.POSITION_NAME[p2],
				"Auf dieser Position ist derzeit niemand einsatzfähig.", "transfer")
		elif int(frei[p2]) == 1:
			_melden(liste, STUFE_HINWEIS, "kader", "%s ohne Ersatz" % Spielerfabrik.POSITION_NAME[p2],
				"Eine Verletzung dort, und Sie müssen umstellen.", "kader")

static func _vertraege(d: Dictionary, cid: String, liste: Array) -> void:
	var saison: int = Welt.saison_index()
	var auslaufend: Array = []
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if int(sp["vertrag"].get("bis_saison", 9)) > saison:
			continue
		auslaufend.append(sid)
	if auslaufend.is_empty():
		return
	auslaufend.sort_custom(func(a, b): return Spielerfabrik.gesamt(d["spieler"][a]) > Spielerfabrik.gesamt(d["spieler"][b]))
	var bester: Dictionary = d["spieler"][auslaufend[0]]
	var stufe: int = STUFE_WARNUNG if Spielerfabrik.gesamt(bester) >= 68.0 else STUFE_HINWEIS
	_melden(liste, stufe, "vertrag", "%d Vertrag/Verträge laufen aus" % auslaufend.size(),
		"Am wichtigsten: %s (Stärke %d). Ab dem Winter darf er frei verhandeln." % [
			Spielerfabrik.voller_name(bester), int(Spielerfabrik.gesamt(bester))], "kader", str(auslaufend[0]))

static func _stimmung(d: Dictionary, cid: String, liste: Array) -> void:
	var v: Dictionary = d["vereine"][cid]
	var klima: float = float(v.get("stimmung_kabine", 50.0))
	if klima < 38.0:
		_melden(liste, STUFE_WARNUNG, "kabine", "Das Kabinenklima kippt",
			"Bei %d von 100 zieht die Mannschaft nicht mehr mit. Gespräche und Einsatzzeit helfen mehr als Training." % int(klima),
			"kabine")
	var unzufrieden: Array = []
	for sid in v["kader"]:
		if float(d["spieler"][sid].get("unzufriedenheit", 0.0)) >= 55.0:
			unzufrieden.append(sid)
	if not unzufrieden.is_empty():
		var sp: Dictionary = d["spieler"][unzufrieden[0]]
		_melden(liste, STUFE_WARNUNG if unzufrieden.size() >= 3 else STUFE_HINWEIS, "kabine",
			"%d Spieler sind deutlich unzufrieden" % unzufrieden.size(),
			"Allen voran %s. Ein Gespräch kostet nichts, ein Wechselwunsch später schon." % Spielerfabrik.voller_name(sp),
			"kabine", str(unzufrieden[0]))

static func _belastung(d: Dictionary, cid: String, liste: Array) -> void:
	var v: Dictionary = d["vereine"][cid]
	var summe := 0.0
	var n := 0
	var verletzte := 0
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		summe += float(sp["last"])
		n += 1
		if not (sp["verletzung"] as Dictionary).is_empty():
			verletzte += 1
	var schnitt: float = summe / maxf(float(n), 1.0)
	if schnitt >= 62.0:
		_melden(liste, STUFE_WARNUNG, "training", "Die Mannschaft ist ausgelaugt",
			"Durchschnittliche Last %d. Weniger Intensität oder mehr Rotation, sonst kommen die Verletzungen von selbst." % int(schnitt),
			"training")
	if verletzte >= 4:
		_melden(liste, STUFE_WARNUNG, "medizin", "%d Spieler im Lazarett" % verletzte,
			"So viele Ausfälle auf einmal sind ein Zeichen: Trainingsintensität senken, Regenerationsbudget umverteilen.",
			"training")

static func _wirtschaft(d: Dictionary, cid: String, liste: Array) -> void:
	var v: Dictionary = d["vereine"][cid]
	if float(v["kasse"]) < 0.0:
		_melden(liste, STUFE_DRINGEND, "finanzen", "Das Konto ist im Minus",
			"%s fehlen in der Kasse. Der Vorstand rechnet mit Verkäufen oder einer kleineren Gehaltsliste." % Stil.geld(-float(v["kasse"])),
			"finanzen")
	var auslastung: float = Finanzen.gehaltsauslastung(d, cid)
	if auslastung > 108.0:
		_melden(liste, STUFE_WARNUNG, "finanzen", "Die Gehaltsliste ist überzogen",
			"Sie liegen bei %d %% des Budgets. Jede Verlängerung macht es enger." % int(auslastung), "finanzen")
	var angebote: Array = Sponsoren.offene_angebote(d, cid)
	if not angebote.is_empty():
		var summe := 0.0
		for a in angebote:
			summe += float(a["wert"])
		_melden(liste, STUFE_WARNUNG, "finanzen", "%d Sponsorenplätze sind unbesetzt" % angebote.size(),
			"Das sind %s im Jahr, die Ihr Verein liegen lässt." % Stil.geld(summe), "finanzen")

static func _nachwuchs(d: Dictionary, cid: String, liste: Array) -> void:
	var v: Dictionary = d["vereine"][cid]
	var bester := ""
	var bw := 0.0
	for sid in v.get("jugend", []):
		var sp: Dictionary = d["spieler"].get(sid, {})
		if sp.is_empty():
			continue
		var w: float = Spielerfabrik.gesamt(sp)
		if w > bw:
			bw = w
			bester = sid
	if bester == "" or bw < 52.0:
		return
	_melden(liste, STUFE_HINWEIS, "jugend", "%s ist so weit" % Spielerfabrik.kurz_name(d["spieler"][bester]),
		"Aus dem Nachwuchs drängt einer in den Profikader (Stärke %d)." % int(bw), "jugend", bester)

## Feinheiten, die nur ein guter Stab sieht.
static func _feinheiten(d: Dictionary, cid: String, liste: Array) -> void:
	if kompetenz(d, cid) < 48.0:
		return
	if Anweisungen.gesetzt(d, cid) == 0:
		_melden(liste, STUFE_HINWEIS, "taktik", "Niemand hat eine eigene Rolle",
			"Wer den Abschluss sucht, wer eröffnet, wer vorschiebt — das liegt alles noch auf Voreinstellung.", "taktik")
	var paare: Array = Mentoring.paare(d, cid)
	if paare.size() < Mentoring.HOECHSTZAHL:
		var schueler: Array = Mentoring.kandidaten_schueler(d, cid)
		var mentoren: Array = Mentoring.kandidaten_mentor(d, cid)
		if not schueler.is_empty() and not mentoren.is_empty():
			var wert: float = Mentoring.eignung(d, str(mentoren[0]), str(schueler[0]))
			if wert >= 58.0:
				_melden(liste, STUFE_HINWEIS, "kabine", "Eine Patenschaft würde passen",
					"%s könnte %s an die Hand nehmen (%s)." % [
						Spielerfabrik.kurz_name(d["spieler"][mentoren[0]]),
						Spielerfabrik.kurz_name(d["spieler"][schueler[0]]),
						Mentoring.eignung_text(wert)], "kabine")
	# Spieler ohne Einsatzzeit, die dafür zu gut sind
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		var st: Dictionary = sp["stats"]["saison"]
		if int(st["spiele"]) >= 5 or Spielerfabrik.gesamt(sp) < 62.0:
			continue
		if int(d["vereine"][cid]["saison"]["spiele"]) < 8:
			continue
		_melden(liste, STUFE_HINWEIS, "kader", "%s spielt nicht" % Spielerfabrik.kurz_name(sp),
			"Bei Stärke %d und %d Einsätzen wird er sich bald melden." % [
				int(Spielerfabrik.gesamt(sp)), int(st["spiele"])], "kader", sid)
		return

## Farbe zur Dringlichkeit.
static func farbe(stufe: int) -> Color:
	match stufe:
		STUFE_DRINGEND:
			return Stil.ROT
		STUFE_WARNUNG:
			return Stil.GELB
		_:
			return Stil.BLAU

static func stufentext(stufe: int) -> String:
	match stufe:
		STUFE_DRINGEND:
			return "DRINGEND"
		STUFE_WARNUNG:
			return "ACHTUNG"
		_:
			return "HINWEIS"
