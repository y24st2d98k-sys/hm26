class_name Training
extends RefCounted
## Trainingsalltag, Spielerentwicklung und das Regenerationsbudget.
##
## Der Wochenplan ist eine echte Entscheidung: harte Einheiten entwickeln schneller,
## treiben aber das Lastkonto hoch und damit das Verletzungsrisiko. Das
## Regenerationsbudget (abhaengig von Physio und Regenerationsbereich) kann einzelnen
## Spielern zugeteilt werden — wer regeneriert, entwickelt sich in dieser Woche kaum.

const SCHWERPUNKTE := {
	"ausgeglichen": {"name": "Ausgeglichen", "attr": [], "last": 1.0},
	"athletik": {"name": "Athletik", "attr": ["tempo", "sprungkraft", "physis", "ausdauer", "beweglichkeit"], "last": 1.25},
	"wurf": {"name": "Wurf & Abschluss", "attr": ["wurfkraft", "wurfpraezision", "siebenmeter", "taeuschung"], "last": 1.05},
	"abwehr": {"name": "Abwehrarbeit", "attr": ["block", "deckungsarbeit", "zweikampf", "antizipation"], "last": 1.18},
	"spielaufbau": {"name": "Spielaufbau", "attr": ["passspiel", "uebersicht", "ballsicherheit", "entscheidung"], "last": 0.95},
	"torwart": {"name": "Torwartblock", "attr": ["reflexe", "tw_stellung", "rueckraumabwehr", "fluegelabwehr", "eins_gegen_eins", "siebenmeterabwehr"], "last": 0.9},
	"taktik": {"name": "Taktikschulung", "attr": ["entscheidung", "uebersicht", "deckungsarbeit", "teamgeist"], "last": 0.85},
	"regeneration": {"name": "Regeneration", "attr": [], "last": 0.35},
}

const INDIVIDUALFOKUS := {
	"": "kein Sonderprogramm",
	"wurf": "Wurfschule",
	"athletik": "Athletikprogramm",
	"abwehr": "Abwehrschulung",
	"spielaufbau": "Spielverständnis",
	"torwart": "Torwartprogramm",
	"mental": "Mentalcoaching",
}

const FOKUS_ATTRIBUTE := {
	"wurf": ["wurfkraft", "wurfpraezision", "siebenmeter", "taeuschung"],
	"athletik": ["tempo", "sprungkraft", "physis", "ausdauer", "beweglichkeit"],
	"abwehr": ["block", "deckungsarbeit", "zweikampf", "antizipation"],
	"spielaufbau": ["passspiel", "uebersicht", "ballsicherheit", "entscheidung"],
	"torwart": ["reflexe", "tw_stellung", "rueckraumabwehr", "fluegelabwehr", "eins_gegen_eins", "siebenmeterabwehr"],
	"mental": ["nervenstaerke", "fuehrung", "arbeitseinsatz", "teamgeist"],
}

static func standard_plan() -> Dictionary:
	return {"intensitaet": 55, "schwerpunkt": "ausgeglichen", "regeneration_zuteilung": {}, "jugendfokus": 40}

static func plan(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("training"):
		v["training"] = standard_plan()
	return v["training"]

## Gesamtes Regenerationsbudget eines Vereins (Punkte pro Woche).
static func regenerationsbudget(d: Dictionary, cid: String) -> int:
	var v: Dictionary = d["vereine"][cid]
	var punkte: float = 2.0 + float(v["infrastruktur"]["regeneration"]) * 0.7
	for pid in v["personal"]:
		var mp: Dictionary = d["personal"].get(pid, {})
		if str(mp.get("rolle", "")) == "physio":
			punkte += float((mp["attr"] as Dictionary).get("heilung", 8.0)) * 0.18
	return int(round(punkte))

static func vergebene_regeneration(d: Dictionary, cid: String) -> int:
	var zuteilung: Dictionary = plan(d, cid).get("regeneration_zuteilung", {})
	var summe := 0
	for k in zuteilung.keys():
		summe += int(zuteilung[k])
	return summe

## Qualitaet der Trainingsarbeit eines Vereins (0..100).
static func trainerqualitaet(d: Dictionary, cid: String, bereich: String = "training") -> float:
	var v: Dictionary = d["vereine"][cid]
	var summe := 0.0
	var anzahl := 0
	for pid in v["personal"]:
		var mp: Dictionary = d["personal"].get(pid, {})
		var attr: Dictionary = mp.get("attr", {})
		if attr.has(bereich):
			summe += float(attr[bereich])
			anzahl += 1
	var basis: float = (summe / maxf(float(anzahl), 1.0)) * 5.0 if anzahl > 0 else 40.0
	basis += float(v["infrastruktur"]["trainingszentrum"]) * 2.6
	if cid == Welt.mein_verein_id:
		basis += float(Welt.trainer().get("ruf", 40.0)) * 0.12
	return clampf(basis, 10.0, 100.0)

# ------------------------------------------------------------- Tagesablauf ---

static func tageswechsel(d: Dictionary) -> void:
	# Form pendelt taeglich leicht Richtung eines Zielwerts aus Leistung und Moral.
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if not (sp["verletzung"] as Dictionary).is_empty():
			sp["form"] = clampf(float(sp["form"]) - 0.5, 12.0, 100.0)
			continue
		var ziel: float = 45.0 + float(sp["moral"]) * 0.22 + (100.0 - float(sp["last"])) * 0.18
		var note: float = Spielerfabrik.note(sp)
		if note > 0.0:
			ziel += (3.4 - note) * 12.0
		sp["form"] = clampf(lerpf(float(sp["form"]), clampf(ziel, 15.0, 98.0), 0.06) + Namen.bereich(-1.2, 1.2), 12.0, 100.0)

# ------------------------------------------------------------ Wochenablauf ---

static func wochenwechsel(d: Dictionary) -> void:
	for cid in d["vereine"].keys():
		_verein_trainieren(d, cid)
	_alterung_pruefen(d)

static func _verein_trainieren(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var p: Dictionary = plan(d, cid)
	var intensitaet: float = float(p["intensitaet"]) / 100.0
	var schwerpunkt: String = str(p["schwerpunkt"])
	var sp_daten: Dictionary = SCHWERPUNKTE.get(schwerpunkt, SCHWERPUNKTE["ausgeglichen"])
	var qualitaet: float = trainerqualitaet(d, cid) / 100.0
	var zuteilung: Dictionary = p.get("regeneration_zuteilung", {})

	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		var regeneriert: bool = int(zuteilung.get(sid, 0)) > 0
		var verletzt: bool = not (sp["verletzung"] as Dictionary).is_empty()
		# Belastung durch Training
		if not verletzt:
			var last_zuwachs: float = intensitaet * 7.0 * float(sp_daten["last"])
			if regeneriert:
				last_zuwachs *= 0.25
			sp["last"] = clampf(float(sp["last"]) + last_zuwachs - 2.0, 0.0, 100.0)
			# Verletzungsgefahr im Training
			if Namen.zufall() < Medizin.risiko(d, sid) * intensitaet * 28.0:
				var vl := Medizin.erzeuge_verletzung(d, sid, false)
				if cid == Welt.mein_verein_id:
					Welt.nachricht({
						"typ": "medizin", "wichtig": int(vl["schwere"]) >= 2,
						"betreff": "Trainingsverletzung: %s" % Spielerfabrik.voller_name(sp),
						"text": "%s hat sich im Training verletzt (%s). Ausfall: etwa %d Tage." % [
							Spielerfabrik.kurz_name(sp), vl["art"], int(vl["tage"])],
					})
				continue
		_entwickeln(d, sp, cid, intensitaet, qualitaet, sp_daten, regeneriert, verletzt)
		_moral_anpassen(d, sp, cid)

static func _entwickeln(d: Dictionary, sp: Dictionary, cid: String, intensitaet: float, qualitaet: float,
		sp_daten: Dictionary, regeneriert: bool, verletzt: bool) -> void:
	var gesamt: float = Spielerfabrik.gesamt(sp)
	var potenzial: float = float(sp["potenzial"])
	var luft: float = (potenzial - gesamt) / maxf(potenzial, 1.0)
	var alter_jahre: int = int(sp["alter"])
	var charakter: Dictionary = sp["charakter"]
	var arbeitseinsatz: float = float(sp["attr"]["arbeitseinsatz"]) / 20.0
	var ehrgeiz: float = float(charakter.get("ehrgeiz", 12.0)) / 20.0

	var alters_tempo: float = 1.0
	if alter_jahre <= 19:
		alters_tempo = 1.9
	elif alter_jahre <= 22:
		alters_tempo = 1.5
	elif alter_jahre <= 25:
		alters_tempo = 1.0
	elif alter_jahre <= 28:
		alters_tempo = 0.55
	elif alter_jahre <= 31:
		alters_tempo = 0.2
	else:
		alters_tempo = 0.0

	var spielzeit: float = clampf(float(sp["stats"]["saison"]["minuten"]) / maxf(float(sp["stats"]["saison"]["spiele"]) * 42.0, 1.0), 0.0, 1.3)
	var zuwachs: float = 0.052 * alters_tempo * (0.4 + 1.1 * luft) * (0.45 + 0.75 * qualitaet) \
		* (0.5 + 0.9 * intensitaet) * (0.6 + 0.5 * arbeitseinsatz) * (0.75 + 0.45 * ehrgeiz) \
		* (0.7 + 0.45 * spielzeit)
	if regeneriert:
		zuwachs *= 0.3
	if verletzt:
		zuwachs *= 0.15
	# Individualfoerderung des Trainers
	var fokus: String = str(sp.get("trainingsfokus", ""))
	var attr_liste: Array = (sp_daten["attr"] as Array).duplicate()
	if fokus != "" and FOKUS_ATTRIBUTE.has(fokus):
		attr_liste.append_array(FOKUS_ATTRIBUTE[fokus])
		zuwachs *= 1.22
	if attr_liste.is_empty():
		attr_liste = _positionsattribute(sp)

	# Altersbedingter Abbau
	if alter_jahre >= 31:
		var abbau: float = (float(alter_jahre) - 30.0) * 0.028
		for a in ["tempo", "sprungkraft", "beweglichkeit", "ausdauer"]:
			sp["attr"][a] = clampf(float(sp["attr"][a]) - abbau * Namen.bereich(0.4, 1.4), 1.0, 20.0)

	if zuwachs <= 0.0001:
		return
	var vorher: float = gesamt
	for i in range(2):
		if attr_liste.is_empty():
			break
		var a: String = str(Namen.waehle(attr_liste))
		if not (sp["attr"] as Dictionary).has(a):
			continue
		if Spielerfabrik.gesamt(sp) >= potenzial and Namen.zufall() < 0.8:
			break
		sp["attr"][a] = clampf(float(sp["attr"][a]) + zuwachs * Namen.bereich(0.5, 1.6), 1.0, 20.0)
	var nachher: float = Spielerfabrik.gesamt(sp)
	sp["wert"] = Spielerfabrik.marktwert(sp)
	if nachher - vorher > 0.45 and cid == Welt.mein_verein_id and int(sp["alter"]) <= 23:
		(sp["entwicklung_log"] as Array).push_front({"tag": int(d["tag"]), "delta": nachher - vorher, "gesamt": nachher})
		if Namen.zufall() < 0.3:
			Welt.nachricht({
				"typ": "training", "betreff": "Entwicklungssprung: %s" % Spielerfabrik.voller_name(sp),
				"text": "%s hat im Training deutlich zugelegt. Der Trainerstab ist beeindruckt." % Spielerfabrik.kurz_name(sp),
			})

static func _positionsattribute(sp: Dictionary) -> Array:
	if bool(sp["ist_torwart"]):
		return Spielerfabrik.ATTR_TORWART.duplicate()
	var gew: Dictionary = Spielerfabrik.ANGRIFF_GEWICHTE.get(str(sp["position"]), {})
	var liste: Array = gew.keys()
	liste.append_array(["block", "deckungsarbeit", "zweikampf"])
	return liste

static func _moral_anpassen(d: Dictionary, sp: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var ziel: float = 50.0
	# Erfolg der Mannschaft
	var formkurve: Array = v["formkurve"]
	var punkte := 0.0
	for e in formkurve:
		punkte += 8.0 if str(e) == "S" else (2.0 if str(e) == "U" else -6.0)
	ziel += clampf(punkte, -22.0, 26.0)
	# Spielzeit im Verhaeltnis zur erwarteten Rolle
	var rolle: String = str(sp["vertrag"].get("rolle", "rotation"))
	var erwartet: float = {"leistungstraeger": 48.0, "stammspieler": 38.0, "rotation": 22.0, "ergaenzung": 10.0, "talent": 12.0}.get(rolle, 20.0)
	var spiele: int = maxi(int(sp["stats"]["saison"]["spiele"]), 1)
	var schnitt: float = float(sp["stats"]["saison"]["minuten"]) / float(spiele)
	if int(sp["stats"]["saison"]["spiele"]) >= 3:
		ziel += clampf((schnitt - erwartet) * 0.75, -20.0, 14.0)
	ziel += float(v["stimmung_kabine"]) * 0.12
	ziel -= float(sp["unzufriedenheit"]) * 0.4
	var loyalitaet: float = float(sp["charakter"].get("loyalitaet", 12.0)) / 20.0
	sp["moral"] = clampf(lerpf(float(sp["moral"]), clampf(ziel, 8.0, 98.0), 0.12 + 0.06 * (1.0 - loyalitaet)), 5.0, 100.0)

static func _alterung_pruefen(d: Dictionary) -> void:
	var tis: int = Kalender.tag_in_saison(int(d["tag"]))
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		var doy: int = int(sp.get("geburtstag_doy", 0))
		if abs(tis - doy) <= 3 and not bool(sp.get("hatte_geburtstag", false)):
			sp["alter"] = int(sp["alter"]) + 1
			sp["hatte_geburtstag"] = true
			sp["wert"] = Spielerfabrik.marktwert(sp)
		elif abs(tis - doy) > 7:
			sp["hatte_geburtstag"] = false
