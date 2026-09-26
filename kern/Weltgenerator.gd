class_name Weltgenerator
extends RefCounted
## Baut eine komplette Handballwelt: Nationen, Ligen, Pokale, internationale Wettbewerbe,
## Vereine mit Wappen, Hallen, Finanzen, Kadern und Personal.

const NATIONEN := [
	{
		"id": "de", "name": "Deutschland", "ruf": 94.0, "reichtum": 1.0,
		"ligen": [
			{"name": "Deutsche Hallenliga", "kurz": "DHL", "stufe": 1, "teams": 14, "ruf": 88.0},
			{"name": "Deutsche Hallenliga 2", "kurz": "DHL2", "stufe": 2, "teams": 14, "ruf": 56.0},
		],
		"pokal": "Deutscher Hallenpokal", "supercup": "Deutscher Supercup",
	},
	{
		"id": "dk", "name": "Dänemark", "ruf": 88.0, "reichtum": 0.82,
		"ligen": [
			{"name": "Dänische Håndboldliga", "kurz": "DHB", "stufe": 1, "teams": 12, "ruf": 82.0},
			{"name": "Dänische 1. Division", "kurz": "D1D", "stufe": 2, "teams": 10, "ruf": 50.0},
		],
		"pokal": "Dänischer Pokal", "supercup": "Dänischer Supercup",
	},
	{
		"id": "fr", "name": "Frankreich", "ruf": 86.0, "reichtum": 0.88,
		"ligen": [
			{"name": "Ligue Handball", "kurz": "LHB", "stufe": 1, "teams": 12, "ruf": 81.0},
			{"name": "Proligue", "kurz": "PRO", "stufe": 2, "teams": 10, "ruf": 48.0},
		],
		"pokal": "Coupe Nationale", "supercup": "Trophée des Champions",
	},
	{
		"id": "es", "name": "Spanien", "ruf": 82.0, "reichtum": 0.74,
		"ligen": [
			{"name": "Liga Asobal", "kurz": "ASO", "stufe": 1, "teams": 12, "ruf": 77.0},
		],
		"pokal": "Copa del Rey", "supercup": "Supercopa",
	},
	{
		"id": "pl", "name": "Polen", "ruf": 74.0, "reichtum": 0.6,
		"ligen": [
			{"name": "Superliga", "kurz": "SUP", "stufe": 1, "teams": 12, "ruf": 68.0},
		],
		"pokal": "Puchar Polski", "supercup": "Polnischer Supercup",
	},
]

const HALLEN_WORT := ["Arena", "Halle", "Sporthalle", "Dome", "Ring", "Forum", "Kuppel", "Hallenpark",
	"Kampfbahn", "Wurfhalle", "Hallenwerk", "Panorama-Halle", "Stadthalle", "Nordhalle"]

const WAPPEN_PALETTEN := [
	["#c8342f", "#f4f1e8"], ["#1f4fa8", "#e8b53a"], ["#1b6b3a", "#ffffff"], ["#2b2f38", "#f0a23c"],
	["#6b2d8c", "#f2e9d8"], ["#0f6d78", "#f4d35e"], ["#b8452c", "#1f2933"], ["#e2b13c", "#2b2f38"],
	["#2f7fd6", "#ffffff"], ["#8c1c2b", "#d9c68a"], ["#3c5a2b", "#e0d6b8"], ["#12324f", "#7fc4e8"],
	["#d1552b", "#2a2118"], ["#4a4f8c", "#f0efe4"], ["#0d5c4e", "#f1a43a"], ["#7a1f3d", "#f3e2c7"],
]

# --------------------------------------------------------------- Aufbau ---

## Baut die Welt auf. Mit echte_welt=true werden Nationen, Ligen, Vereine und
## — soweit hinterlegt — Kader aus dem Datensatz in "daten/" übernommen; alles,
## was dort fehlt, wird erfunden. Mit echte_welt=false entsteht eine rein
## erfundene Welt wie bisher.
static func erzeuge(startjahr: int, saat: int, echte_welt: bool = true) -> Dictionary:
	Namen.setze_saat(saat)
	var d := {
		"version": Welt.DATENVERSION,
		"startjahr": startjahr,
		"saat": saat,
		"tag": 0,
		"nationen": {},
		"ligen": {},
		"pokale": {},
		"international": {},
		"vereine": {},
		"spieler": {},
		"personal": {},
		"trainer": {},
		"spiele": {},
		"plan": {},
		"nachrichten": [],
		"presse": [],
		"social": [],
		"medien": {"outlets": [], "fanaccounts": []},
		"transfermarkt": {"angebote": [], "gerüchte": [], "verlauf": [], "fenster_offen": true},
		"scouting": {"auftraege": [], "berichte": [], "beobachtung": [], "talente": []},
		"chronik": {"saisons": [], "ereignisse": []},
		"rekorde": {},
		"zaehler": {"spieler": 0, "verein": 0, "spiel": 0, "personal": 0, "nachricht": 0, "auftrag": 0},
		"einstellungen": {"autorotation": true, "auto_aufstellung": true, "presse_filter": "alle", "sim_tempo": 2,
			"autospeichern": true, "auto_taktik": true},
		"saison_abgeschlossen": false,
	}
	var echt: bool = echte_welt and Echtdaten.verfuegbar()
	d["echte_welt"] = echt
	d["datenstand"] = Echtdaten.datenstand() if echt else ""

	if echt:
		_nationen_aus_datensatz(d)
	else:
		_erzeuge_nationen(d)
	_erzeuge_vereine(d)
	Sponsoren.erstbelegung(d)
	_erzeuge_wettbewerbe(d)
	_erzeuge_medien(d)
	_erzeuge_rekorde(d)
	Nationalteam.erzeuge_teams(d)
	Schiedsrichter.erzeugen(d, (d["nationen"] as Dictionary).keys())
	# Erst hier steht die Handschrift jedes Vereins fest. Das Vertrautheits-
	# konto muss darauf sitzen, sonst startet die halbe Liga so, als hätte sie
	# gerade umgestellt.
	for cid in clubs(d):
		Vertrautheit.stammformation_setzen(d, str(cid))
		Spielzuege.ki_buch_anlegen(d, str(cid))
	# Kein Verein faengt mit einem leeren Nachwuchszentrum an. Bisher war genau
	# das der Fall: am ersten Tag stand in jeder Akademie der Liga der Satz
	# "derzeit ist kein Talent im Nachwuchszentrum", und der erste Jahrgang kam
	# erst zum Saisonwechsel. Fuer das Jugendzertifikat heisst das ausserdem,
	# dass in der ersten Spielzeit kein Verein die Auflagen erfuellt haette.
	for cid2 in clubs(d):
		var stufe: int = int(d["vereine"][cid2]["infrastruktur"]["jugendarbeit"])
		Jugend.erzeuge_jahrgang(d, str(cid2), 2 + (1 if stufe >= 4 else 0)
			+ (1 if stufe >= 7 else 0) + (1 if Namen.zufall() < 0.4 else 0))
	return d

static func _erzeuge_nationen(d: Dictionary) -> void:
	for n in NATIONEN:
		var nid: String = n["id"]
		d["nationen"][nid] = {
			"id": nid,
			"name": n["name"],
			"ruf": n["ruf"],
			"reichtum": n["reichtum"],
			"ligen": [],
			"pokal": "",
			"supercup_name": n["supercup"],
			"meister_historie": [],
		}
		for l in n["ligen"]:
			var lid: String = "l_%s%d" % [nid, int(l["stufe"])]
			d["ligen"][lid] = {
				"id": lid,
				"name": l["name"],
				"kurz": l["kurz"],
				"nation": nid,
				"stufe": int(l["stufe"]),
				"ruf": float(l["ruf"]),
				"teams": int(l["teams"]),
				"vereine": [],
				"tabelle": {},
				"spieltage": 0,
				"aktueller_spieltag": 0,
				"meister_historie": [],
				"aufsteiger": [],
				"absteiger": [],
				"torschuetzen": {},
			}
			(d["nationen"][nid]["ligen"] as Array).append(lid)
		var pid: String = "p_%s" % nid
		d["pokale"][pid] = {
			"id": pid,
			"name": n["pokal"],
			"nation": nid,
			"typ": "pokal",
			"teilnehmer": [],
			"runde": 0,
			"runden_namen": [],
			"paarungen": [],
			"sieger_historie": [],
			"beendet": false,
		}
		d["nationen"][nid]["pokal"] = pid

## Übernimmt Nationen, Ligen und Pokale aus dem Datensatz.
static func _nationen_aus_datensatz(d: Dictionary) -> void:
	for n in Echtdaten.nationen():
		var nid: String = str(n["id"])
		d["nationen"][nid] = {
			"id": nid,
			"name": str(n["name"]),
			"ruf": float(n["ruf"]),
			"reichtum": float(n["reichtum"]),
			"ligen": [],
			"pokal": "",
			"supercup_name": str(n.get("supercup", "Supercup")),
			"meister_historie": [],
		}
		# Europapokalplätze, wenn der Datensatz sie kennt; sonst entscheidet
		# der Ruf der Nation (siehe Spielplan._qualifikanten).
		for feld in ["cl_plaetze", "el_plaetze"]:
			if n.has(feld):
				d["nationen"][nid][feld] = int(n[feld])
		for l in (n["ligen"] as Array):
			var lid: String = str(l["id"])
			var vereine: Array = l.get("vereine", [])
			# Eine Liga kann echte Vereine nennen und trotzdem mehr Mannschaften
			# haben: dann ergänzt das Spiel erfundene bis "teams".
			var anzahl: int = maxi(vereine.size(), int(l.get("teams", 0))) if not vereine.is_empty() else int(l.get("teams", 12))
			d["ligen"][lid] = {
				"id": lid,
				"name": str(l["name"]),
				"kurz": str(l.get("kurz", lid)),
				"nation": nid,
				"stufe": int(l["stufe"]),
				"ruf": float(l["ruf"]),
				"teams": anzahl,
				"vereine": [],
				"tabelle": {},
				"spieltage": 0,
				"aktueller_spieltag": 0,
				"meister_historie": [],
				"aufsteiger": [],
				"absteiger": [],
				"torschuetzen": {},
				"datensatz": vereine,
			}
			# Meisterschaft über Play-offs (siehe kern/Playoffs.gd).
			if int(l.get("playoffs", 0)) >= 2:
				d["ligen"][lid]["playoffs"] = int(l["playoffs"])
			(d["nationen"][nid]["ligen"] as Array).append(lid)
		var pid: String = "p_%s" % nid
		d["pokale"][pid] = {
			"id": pid,
			"name": str(n.get("pokal", "Pokal")),
			"nation": nid,
			"typ": "pokal",
			"teilnehmer": [],
			"runde": 0,
			"runden_namen": [],
			"paarungen": [],
			"sieger_historie": [],
			"beendet": false,
		}
		d["nationen"][nid]["pokal"] = pid

static func _erzeuge_vereine(d: Dictionary) -> void:
	var vergeben := {}
	var index := 0
	for lid in d["ligen"].keys():
		var liga: Dictionary = d["ligen"][lid]
		var nid: String = liga["nation"]
		var nation: Dictionary = d["nationen"][nid]
		var datensatz: Array = liga.get("datensatz", [])
		for i in range(int(liga["teams"])):
			index += 1
			var cid := "c_%03d" % index
			var verein: Dictionary
			if i < datensatz.size():
				verein = _verein_aus_datensatz(d, cid, datensatz[i], nid, lid, vergeben)
			else:
				var vn: Dictionary = Namen.verein(nid, vergeben)
				vergeben[vn["name"]] = true
				vn["kurz"] = _eindeutiges_kuerzel(str(vn["kurz"]), vergeben)
				# Rufverteilung: Spitze der Liga deutlich staerker als Schlusslicht.
				var spanne: float = 18.0 if int(liga["stufe"]) == 1 else 13.0
				var ruf: float = clampf(float(liga["ruf"]) + spanne * (1.0 - float(i) / maxf(float(liga["teams"]) - 1.0, 1.0)) - spanne * 0.45 + Namen.bereich(-4.0, 4.0), 12.0, 99.0)
				verein = _baue_verein(d, cid, vn, nid, lid, ruf, float(nation["reichtum"]))
			d["vereine"][cid] = verein
			(liga["vereine"] as Array).append(cid)
		liga.erase("datensatz")
		liga["spieltage"] = (int(liga["teams"]) - 1) * 2
	d["zaehler"]["verein"] = index

	# Kader und Personal fuer jeden Verein
	for cid in Weltgenerator.clubs(d):
		_fuelle_kader(d, cid)
		_erzeuge_personal(d, cid)
	for cid2 in clubs(d):
		Jugend.erzeuge_jahrgang(d, cid2, Namen.wuerfel(3, 5))
	_vorvertraege_aufloesen(d)
	# Rivalitaeten innerhalb der Ligen
	_erzeuge_rivalitaeten(d)
	# Ein Grundstock an vereinslosen Spielern
	_erzeuge_freie_spieler(d, 90)

## Baut einen Verein aus einem Eintrag des Datensatzes. Fehlende Angaben
## werden wie bei einem erfundenen Verein ergänzt.
## Was einem belegten Kader noch fehlt: die Mindestbesetzung je Position, und
## danach so lange die duennste Position, bis die Mindestgroesse erreicht ist.
static func _echt_soll(belegt: Dictionary, echte: int) -> Dictionary:
	var soll := {}
	var gesamt := echte
	for pos in Spielerfabrik.ECHT_MINDEST.keys():
		var mindest: int = int(Spielerfabrik.ECHT_MINDEST[pos])
		soll[pos] = maxi(int(belegt.get(pos, 0)), mindest)
		gesamt += maxi(mindest - int(belegt.get(pos, 0)), 0)
	# Notfalls auffuellen, bis der Kader eine Saison uebersteht.
	while gesamt < Spielerfabrik.ECHT_GESAMT:
		var duennste := ""
		var wenigste := 999
		for pos2 in soll.keys():
			if pos2 == "TW":
				continue
			if int(soll[pos2]) < wenigste:
				wenigste = int(soll[pos2])
				duennste = str(pos2)
		if duennste == "":
			break
		soll[duennste] = int(soll[duennste]) + 1
		gesamt += 1
	return soll

static func _verein_aus_datensatz(d: Dictionary, cid: String, eintrag: Dictionary,
		nid: String, lid: String, vergeben: Dictionary) -> Dictionary:
	var nation: Dictionary = d["nationen"][nid]
	var liga: Dictionary = d["ligen"][lid]
	var name: String = str(eintrag["name"])
	var ort: String = str(eintrag.get("ort", Namen.ort(nid)))
	var ruf: float = float(eintrag.get("ruf", liga["ruf"]))
	var vn := {
		"name": name,
		"kurz": _eindeutiges_kuerzel(str(eintrag.get("kurz", Namen.kuerzel(name))), vergeben),
		"ort": ort,
		"beiname": "",
	}
	vergeben[name] = true
	var verein := _baue_verein(d, cid, vn, nid, lid, ruf, float(nation["reichtum"]))
	verein["echt"] = true
	verein["gegruendet"] = int(eintrag.get("gegruendet", verein["gegruendet"]))
	verein["halle"]["name"] = str(eintrag.get("halle", verein["halle"]["name"]))
	verein["halle"]["kapazitaet"] = int(eintrag.get("kapazitaet", verein["halle"]["kapazitaet"]))
	_wappen_setzen(verein, eintrag)
	# Echte Rivalitaeten stehen im Datensatz, als Kuerzel. Aufgeloest wird das
	# erst, wenn alle Vereine angelegt sind — vorher gibt es die IDs nicht.
	if eintrag.has("rivalen"):
		verein["rivalen_kurz"] = (eintrag["rivalen"] as Dictionary).duplicate()
	# Der Cheftrainer. Gegnertrainer.erzeuge() setzt ihn auf die Bank.
	var tr: Variant = eintrag.get("trainer", null)
	if typeof(tr) == TYPE_STRING and str(tr) != "":
		var teile: PackedStringArray = str(tr).split(" ", false, 1)
		tr = {"vorname": teile[0], "nachname": teile[1] if teile.size() > 1 else ""}
	if typeof(tr) == TYPE_DICTIONARY and not (tr as Dictionary).is_empty():
		verein["trainer_datensatz"] = (tr as Dictionary).duplicate()
	# Die Namen im Trainerstab; die Fähigkeiten würfelt das Spiel.
	if typeof(eintrag.get("stab", null)) == TYPE_DICTIONARY:
		verein["stab_datensatz"] = (eintrag["stab"] as Dictionary).duplicate()
	# Etat: der tatsächliche Jahresetat in Euro. Das Spiel merkt sich nur das
	# Verhältnis zum eigenen Richtwert — so bleibt er richtig, wenn der Verein
	# absteigt oder an Ruf gewinnt (siehe Finanzen.grundetat).
	if float(eintrag.get("etat", 0.0)) > 0.0:
		var etat: float = float(eintrag["etat"])
		var formel: float = Finanzen.grundetat_formel(d, verein)
		verein["etat_faktor"] = clampf(etat / maxf(formel, 1.0), 0.35, 3.0)
		var anteil: float = etat / maxf(float(verein["jahresetat"]), 1.0)
		for feld in ["kasse", "transferbudget", "gehaltsbudget"]:
			verein[feld] = float(verein[feld]) * anteil
		verein["jahresetat"] = etat
		verein["etat_datensatz"] = etat
	if typeof(eintrag.get("sponsoren", null)) == TYPE_DICTIONARY:
		verein["sponsoren_datensatz"] = (eintrag["sponsoren"] as Dictionary).duplicate()
	# Zuschauerschnitt der Vorsaison: eine volle Halle heißt treue Fans.
	if int(eintrag.get("zuschauerschnitt", 0)) > 0:
		var kap: float = maxf(float(verein["halle"]["kapazitaet"]), 1.0)
		var auslastung: float = clampf(float(eintrag["zuschauerschnitt"]) / kap, 0.15, 1.0)
		verein["zuschauerschnitt_datensatz"] = int(eintrag["zuschauerschnitt"])
		verein["fans"]["treue"] = clampf(25.0 + auslastung * 68.0, 20.0, 95.0)
		verein["fans"]["zufriedenheit"] = clampf(40.0 + auslastung * 45.0, 35.0, 88.0)
		verein["fans"]["mitglieder"] = int(float(eintrag["zuschauerschnitt"]) * 1.4)
	for feld2 in ["homepage", "liga_seit", "meistertitel", "pokalsiege"]:
		if eintrag.has(feld2):
			verein[feld2] = eintrag[feld2]
	return verein

## Das Wappen eines echten Vereins: seine tatsaechlichen Farben, sein Kuerzel und
## eine Form, die sich aus dem Namen ergibt — damit derselbe Verein in jeder
## Karriere gleich aussieht. Der Datensatz kann Form und Teilung vorgeben.
static func _wappen_setzen(verein: Dictionary, eintrag: Dictionary) -> void:
	var w: Dictionary = verein["wappen"]
	var farben: Array = eintrag.get("farben", [])
	if farben.size() >= 2:
		w["a"] = Color(str(farben[0]))
		w["b"] = Color(str(farben[1]))
	if farben.size() >= 3:
		w["c"] = Color(str(farben[2]))
	w["text"] = str(eintrag.get("kuerzel_wappen", verein["kurz"]))
	var vorgabe: Dictionary = eintrag.get("wappen", {})
	var streu: int = _namenszahl(str(eintrag.get("name", verein["name"])))
	w["form"] = int(vorgabe.get("form", streu % 8))
	w["muster"] = int(vorgabe.get("muster", (streu / 8) % 10))
	w["symbol"] = int(vorgabe.get("symbol", (streu / 80) % 8))

## Stabile Zahl aus einem Namen — unabhaengig von Zufallssaat und Reihenfolge.
static func _namenszahl(name: String) -> int:
	var summe := 0
	for i in range(name.length()):
		summe = (summe * 31 + name.unicode_at(i)) % 100003
	return summe

## Alle echten Vereine — ohne die Nationalmannschaften, die technisch
## ebenfalls als Verein gefuehrt werden, aber keinen Ligabetrieb haben.
static func clubs(d: Dictionary) -> Array:
	var liste: Array = []
	for cid in d["vereine"].keys():
		if bool(d["vereine"][cid].get("ist_nationalteam", false)):
			continue
		liste.append(cid)
	return liste

## Sorgt dafuer, dass kein Kuerzel doppelt vergeben wird.
static func _eindeutiges_kuerzel(vorschlag: String, vergeben: Dictionary) -> String:
	var schluessel := "kurz:" + vorschlag
	if not vergeben.has(schluessel):
		vergeben[schluessel] = true
		return vorschlag
	var buchstaben := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for i in range(buchstaben.length()):
		var neu := vorschlag.substr(0, 2) + buchstaben[i]
		if not vergeben.has("kurz:" + neu):
			vergeben["kurz:" + neu] = true
			return neu
	for i in range(100):
		var neu2 := vorschlag.substr(0, 2) + str(i % 10)
		if not vergeben.has("kurz:" + neu2):
			vergeben["kurz:" + neu2] = true
			return neu2
	return vorschlag

static func _baue_verein(d: Dictionary, cid: String, vn: Dictionary, nid: String, lid: String, ruf: float, reichtum: float) -> Dictionary:
	var palette: Array = Namen.waehle(WAPPEN_PALETTEN)
	var kap: int = int(clampf(600.0 + pow(ruf, 1.95) * 0.95 + Namen.bereich(-350.0, 600.0), 700.0, 13500.0))
	var jahresetat: float = pow(maxf(ruf, 10.0), 2.62) * 52.0 * reichtum
	return {
		"id": cid,
		"name": vn["name"],
		"kurz": vn["kurz"],
		"ort": vn["ort"],
		"beiname": vn["beiname"],
		"nation": nid,
		"liga": lid,
		"gegruendet": Namen.wuerfel(1893, 1998),
		"wappen": {
			"form": Namen.wuerfel(0, 7),
			"muster": Namen.wuerfel(0, 9),
			"symbol": Namen.wuerfel(0, 7),
			"text": vn["kurz"],
			"a": Color(palette[0]),
			"b": Color(palette[1]),
		},
		"ruf": ruf,
		"kasse": jahresetat * Namen.bereich(0.08, 0.3),
		"transferbudget": jahresetat * Namen.bereich(0.06, 0.16),
		"gehaltsbudget": jahresetat * 0.88 / 52.0,
		"jahresetat": jahresetat,
		"sponsoren": [],
		"sponsorangebote": [],
		"halle": {
			"name": "%s %s" % [vn["ort"], Namen.waehle(HALLEN_WORT)],
			"kapazitaet": kap,
			"ausbau": 0,
			"komfort": int(clampf(ruf / 14.0 + Namen.bereich(-1.0, 1.5), 1.0, 8.0)),
			# Die Beleuchtung ist eine Lizenzauflage: 1.500 Lux auf dem
			# Spielfeld, 600 im Zuschauerbereich, Gleichmaessigkeit 0,8.
			# Nicht jede Halle schafft das — siehe kern/Lizenzierung.gd.
			"licht_feld": int(clampf(1300.0 + ruf * 6.2 + Namen.bereich(-150.0, 200.0), 800.0, 2400.0)),
			"licht_rang": 0,
			"gleichmaessigkeit": clampf(0.62 + ruf * 0.0028 + Namen.bereich(-0.06, 0.08), 0.55, 0.95),
			"bauprojekt": {},
		},
		# Trainieren Jugend und Zweite in einer Halle mit Harzverbot?
		"harzverbot": int(kap) < 4000 and Namen.zufall() < 0.35,
		"infrastruktur": {
			"trainingszentrum": int(clampf(ruf / 12.0 + Namen.bereich(-1.5, 1.5), 1.0, 9.0)),
			"jugendarbeit": int(clampf(ruf / 13.0 + Namen.bereich(-2.0, 2.0), 1.0, 9.0)),
			"medizin": int(clampf(ruf / 13.5 + Namen.bereich(-1.5, 1.5), 1.0, 9.0)),
			"analyse": int(clampf(ruf / 16.0 + Namen.bereich(-1.5, 1.5), 1.0, 9.0)),
			"regeneration": int(clampf(ruf / 15.0 + Namen.bereich(-1.5, 1.5), 1.0, 9.0)),
		},
		"kader": [],
		"jugend": [],
		"personal": [],
		"taktik": standard_taktik(),
		# Die Stammformation sitzt von Anfang an, alles andere nicht. Ohne das
		# stünde die ganze Liga am ersten Spieltag wie frisch umgestellt da.
		"vertrautheit": {},
		"spielbuch": {},
		"gegnerplan": {},
		# Das Beziehungsgeflecht wird nur fuer den Verein des Spielers
		# gefuehrt und entsteht dort beim ersten Zugriff.
		"beziehungen": {},
		"aufstellung": {"angriff": {}, "abwehr": {}, "bank": [], "kapitaen": "", "siebenmeter": "", "anweisungen": {}, "minuten": {}},
		"mentoring": [],
		"trainingslager": {},
		"taktikprofile": [],
		"taktikregeln": {},
		"vorstand": {
			"vertrauen": Namen.glocke(62.0, 8.0, 40.0, 85.0),
			"saisonziel": "",
			"ziel_platz": 0,
			"geduld": Namen.glocke(58.0, 12.0, 25.0, 90.0),
			"finanzstrenge": Namen.glocke(55.0, 15.0, 20.0, 90.0),
			"jugendfokus": Namen.glocke(50.0, 18.0, 10.0, 92.0),
		},
		"fans": {
			"zufriedenheit": Namen.glocke(62.0, 9.0, 35.0, 88.0),
			"treue": Namen.glocke(55.0, 14.0, 20.0, 95.0),
			"mitglieder": int(kap * Namen.bereich(0.7, 2.4)),
			"erwartung": ruf,
		},
		"hallenpuls_basis": clampf(38.0 + ruf * 0.35 + Namen.bereich(-6.0, 8.0), 25.0, 88.0),
		"rivalen": {},
		"chronik": {
			"titel": [],
			"beste_liga_platzierung": {},
			"saisons": [],
			"ewige_bilanz": {"spiele": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0, "tore": 0, "gegentore": 0},
			"legenden": [],
		},
		"saison": leere_vereinsstats(),
		"finanz_log": [],
		"ist_mensch": false,
		"trainer": "",
		"stimmung_kabine": Namen.glocke(65.0, 8.0, 40.0, 90.0),
		"formkurve": [], "siegesserie": 0, "serie_gemeldet": 0,
		# Eintrittspreise, Fanszene, Kredite und Spieltagsprogramm werden
		# beim ersten Zugriff gefüllt — sie brauchen den fertigen Verein.
		"darlehen": [],
		"spieltag": {"programm": Spieltagsprogramm.STANDARD, "letztes": Spieltagsprogramm.STANDARD, "kosten": 0.0},
	}

static func leere_vereinsstats() -> Dictionary:
	return {
		"spiele": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0,
		"tore": 0, "gegentore": 0, "zuschauer_summe": 0, "heimspiele": 0,
		"zeitstrafen": 0, "serie": [], "verkaufte_stammspieler": 0,
		# Saisonbuchhaltung je Kategorie — Einnahmen positiv, Ausgaben negativ.
		"finanzen": {},
	}

static func standard_taktik() -> Dictionary:
	return {
		"abwehr": "6-0",
		"angriff": "positionsangriff",
		"tempo": 50,
		"risiko": 45,
		"haerte": 45,
		"mentalitaet": "ausgeglichen",
		"siebter_feldspieler": "unterzahl",
		"wechselspiel": 55,
		"siebenmeter_schuetze": "",

		"auszeit_automatik": true,
	}

## Sponsoring ist die groesste Einnahmequelle eines Handballvereins —
## zusammen decken die Partner rund ein Drittel des Jahresetats.
static func _erzeuge_sponsoren(ruf: float, jahresetat: float) -> Array:
	var arten := ["Trikotbrust", "Ärmel", "Hallenname", "Ausrüster", "Rückenpartner"]
	var liste := []
	var anzahl: int = 2 + int(ruf / 30.0)
	for i in range(anzahl):
		liste.append({
			"name": Namen.sponsor(),
			"art": arten[i % arten.size()],
			"wert": jahresetat * Namen.bereich(0.05, 0.12),
			"bis_saison": Namen.wuerfel(0, 3),
			"bonus_titel": Namen.bereich(0.05, 0.2),
		})
	return liste

static func _fuelle_kader(d: Dictionary, cid: String) -> void:
	var verein: Dictionary = d["vereine"][cid]
	var ruf: float = float(verein["ruf"])
	var lohnniveau: float = Finanzen.lohnniveau(d, cid)
	var nid: String = verein["nation"]
	# Zuerst die hinterlegten echten Spieler, danach wird auf Sollstärke ergänzt.
	var belegt := {}
	for pos in Spielerfabrik.POSITIONEN:
		belegt[pos] = 0
	var echt_spitze := 0.0
	for eintrag in Kaderpflege.kader(str(verein["name"])):
		var pos_e: String = str(eintrag.get("position", "RM"))
		if not belegt.has(pos_e):
			pos_e = "RM"
		var sid_e := neue_spieler_id(d)
		var sp_e := Spielerfabrik.erzeuge_mit_namen(sid_e, eintrag, pos_e, int(d["startjahr"]))
		sp_e["verein"] = cid
		sp_e["kenntnis"] = 100.0
		sp_e["vertrag"] = {
			"bis_saison": Namen.wuerfel(1, 4),
			"gehalt": Spielerfabrik.gehaltsvorstellung(sp_e, ruf, lohnniveau) * Namen.bereich(0.9, 1.15),
			"rolle": "rotation",
			"ablöseklausel": 0.0,
			"unterschrieben_saison": -Namen.wuerfel(0, 3),
		}
		_startpraemien_setzen(sp_e, ruf, lohnniveau)
		sp_e["wert"] = Spielerfabrik.marktwert(sp_e)
		# Erst nach dem Marktwert — die Klausel rechnet damit.
		_klausel_setzen(sp_e)
		_vertrag_aus_datensatz(d, sp_e, eintrag)
		d["spieler"][sid_e] = sp_e
		(verein["kader"] as Array).append(sid_e)
		belegt[pos_e] = int(belegt[pos_e]) + 1
		echt_spitze = maxf(echt_spitze, Spielerfabrik.gesamt(sp_e))
	# Ein belegter Kader wird nur noch auf das Noetige ergaenzt, ein leerer auf
	# volle Sollstaerke.
	var echte: int = (verein["kader"] as Array).size()
	var soll: Dictionary = Spielerfabrik.KADER_SOLL
	if echte >= Spielerfabrik.ECHT_AB:
		soll = _echt_soll(belegt, echte)
	for pos in soll.keys():
		var anzahl: int = maxi(int(soll[pos]) - int(belegt.get(pos, 0)), 0)
		for i in range(anzahl):
			# Stammspieler stark, Ersatz schwaecher, dazu ein Talent. Echte Spieler
			# besetzen bereits die vorderen Ränge, Ergänzungen rücken dahinter.
			var rang: int = int(belegt.get(pos, 0)) + i
			var rang_abzug: float = float(rang) * (7.0 if pos != "TW" else 9.0)
			var ziel: float = clampf(ruf * 0.70 + 21.0 - rang_abzug + Namen.bereich(-5.0, 5.0), 18.0, 95.0)
			# Wo echte Spieler hinterlegt sind, ergaenzen erfundene den Kader —
			# sie sollen die Leistungstraeger nicht ueberstrahlen.
			if echt_spitze > 0.0:
				ziel = minf(ziel, echt_spitze - 3.0)
			var alter_jahre: int = _zufalls_alter(rang, anzahl)
			if alter_jahre <= 20:
				ziel = clampf(ziel - Namen.bereich(4.0, 12.0), 16.0, 80.0)
			var kultur: String = Namen.kultur_zufall(nid, 0.62 if ruf < 70.0 else 0.42)
			var sid := neue_spieler_id(d)
			var sp := Spielerfabrik.erzeuge(sid, kultur, alter_jahre, ziel, pos, int(d["startjahr"]))
			sp["verein"] = cid
			sp["kenntnis"] = 100.0
			sp["vertrag"] = {
				"bis_saison": Namen.wuerfel(0, 4),
				"gehalt": Spielerfabrik.gehaltsvorstellung(sp, ruf, lohnniveau) * Namen.bereich(0.85, 1.12),
				"rolle": "rotation",
				"ablöseklausel": 0.0,
				"unterschrieben_saison": -Namen.wuerfel(0, 3),
			}
			_startpraemien_setzen(sp, ruf, lohnniveau)
			sp["wert"] = Spielerfabrik.marktwert(sp)
			_klausel_setzen(sp)
			d["spieler"][sid] = sp
			(verein["kader"] as Array).append(sid)
	_verteile_rollen(d, cid)
	Trikot.kader_nummerieren(d, cid)
	setze_standardaufstellung(d, cid)

## Was der Datensatz über Vertrag und Zustand eines echten Spielers weiß.
##
##  * `vertrag_bis`  — Jahr, in dem der Vertrag am 30. Juni endet (2028 heißt:
##    er läuft bis zum Ende der Saison 2027/28)
##  * `gehalt`       — Jahresgehalt in Euro, brutto
##  * `ablöse` / `klausel` — festgeschriebene Ausstiegsklausel in Euro
##  * `verletzt`     — {"art": "Kreuzbandriss", "tage": 120} oder mit "bis": "2027-01-15"
##  * `vorvertrag`   — Name des Vereins, bei dem er für die nächste Saison
##    unterschrieben hat. Aufgelöst wird das erst, wenn alle Vereine stehen.
##  * `kapitaen`     — true: er führt die Mannschaft aufs Feld
static func _vertrag_aus_datensatz(d: Dictionary, sp: Dictionary, eintrag: Dictionary) -> void:
	var startjahr: int = int(d["startjahr"])
	var vertrag: Dictionary = sp["vertrag"]
	if int(eintrag.get("vertrag_bis", 0)) > startjahr:
		vertrag["bis_saison"] = int(eintrag["vertrag_bis"]) - startjahr - 1
		vertrag["unterschrieben_saison"] = mini(int(vertrag.get("unterschrieben_saison", 0)), 0)
	if float(eintrag.get("gehalt", 0.0)) > 0.0:
		# Das Spiel rechnet Gehälter je Woche.
		vertrag["gehalt"] = float(eintrag["gehalt"]) / 52.0
	var klausel: float = float(eintrag.get("klausel", eintrag.get("ablöse", 0.0)))
	if klausel > 0.0:
		vertrag["ablöseklausel"] = klausel
	var verletzt: Variant = eintrag.get("verletzt", null)
	if typeof(verletzt) == TYPE_DICTIONARY and not (verletzt as Dictionary).is_empty():
		var v: Dictionary = verletzt
		var tage: int = int(v.get("tage", 0))
		if tage <= 0 and str(v.get("bis", "")) != "":
			var teile: PackedStringArray = str(v["bis"]).split("-")
			if teile.size() == 3:
				tage = Kalender.tag_aus_datum(int(teile[2]), int(teile[1]), int(teile[0]), startjahr)
		if tage > 0:
			var schwere: int = 3 if tage > 90 else (2 if tage > 21 else 1)
			sp["verletzung"] = {
				"art": str(v.get("art", "Verletzung")), "tage": tage, "rest": tage, "schwere": schwere,
				"region": str(v.get("region", "knie")), "im_spiel": false, "seit_tag": 0,
			}
			sp["fitness"] = clampf(float(sp["fitness"]) - float(schwere) * 12.0, 20.0, 100.0)
	if str(eintrag.get("vorvertrag", "")) != "":
		sp["vorvertrag_name"] = str(eintrag["vorvertrag"])
	if bool(eintrag.get("kapitaen", false)):
		sp["kapitaen_datensatz"] = true

## Löst die Vorverträge aus dem Datensatz auf, sobald alle Vereine stehen.
static func _vorvertraege_aufloesen(d: Dictionary) -> void:
	var nach_name := {}
	for cid in clubs(d):
		nach_name[str(d["vereine"][cid]["name"])] = str(cid)
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if not sp.has("vorvertrag_name"):
			continue
		var ziel: String = str(nach_name.get(str(sp["vorvertrag_name"]), ""))
		sp.erase("vorvertrag_name")
		if ziel == "" or ziel == str(sp.get("verein", "")):
			continue
		# Ein Vorvertrag setzt voraus, dass der alte Vertrag im Sommer endet.
		sp["vertrag"]["bis_saison"] = 0
		var ruf: float = float(d["vereine"][ziel]["ruf"])
		sp["vorvertrag"] = {
			"verein": ziel,
			"gehalt": Spielerfabrik.gehaltsvorstellung(sp, ruf, Finanzen.lohnniveau(d, ziel)),
			"laufzeit": 3,
			"rolle": "rotation",
			"saison": 0,
		}

static func _zufalls_alter(rang: int, _gesamt: int) -> int:
	var w: float = Namen.zufall()
	if rang == 0:
		return Namen.wuerfel(24, 32)
	if w < 0.18:
		return Namen.wuerfel(17, 20)
	elif w < 0.45:
		return Namen.wuerfel(21, 25)
	elif w < 0.8:
		return Namen.wuerfel(26, 31)
	return Namen.wuerfel(32, 37)

static func neue_spieler_id(d: Dictionary) -> String:
	d["zaehler"]["spieler"] = int(d["zaehler"]["spieler"]) + 1
	return "s_%05d" % int(d["zaehler"]["spieler"])

static func _neue_personal_id(d: Dictionary) -> String:
	d["zaehler"]["personal"] = int(d["zaehler"]["personal"]) + 1
	return "t_%05d" % int(d["zaehler"]["personal"])

## Vergibt Kaderrollen (Leistungstraeger, Stammspieler, Rotation, Ergaenzung, Talent).
static func _verteile_rollen(d: Dictionary, cid: String) -> void:
	var verein: Dictionary = d["vereine"][cid]
	var liste: Array = (verein["kader"] as Array).duplicate()
	liste = Spielerfabrik.nach_staerke(d, liste)
	for i in range(liste.size()):
		var sp: Dictionary = d["spieler"][liste[i]]
		var rolle := "ergaenzung"
		if i < 2:
			rolle = "leistungstraeger"
		elif i < 7:
			rolle = "stammspieler"
		elif i < 12:
			rolle = "rotation"
		if int(sp["alter"]) <= 20 and float(sp["potenzial"]) - Spielerfabrik.gesamt(sp) > 12.0:
			rolle = "talent"
		(sp["vertrag"] as Dictionary)["rolle"] = rolle
	# Kapitaen: hoechste Fuehrung
	var kap := ""
	var best := -1.0
	for sid in liste:
		var f: float = float((d["spieler"][sid]["attr"] as Dictionary)["fuehrung"]) + float(d["spieler"][sid]["alter"]) * 0.2
		# Der echte Kapitän aus dem Datensatz trägt die Binde.
		if bool(d["spieler"][sid].get("kapitaen_datensatz", false)):
			f += 1000.0
		if f > best:
			best = f
			kap = sid
	(verein["aufstellung"] as Dictionary)["kapitaen"] = kap

## Stellt Angriffs- und Abwehrsieben automatisch auf.
static func setze_standardaufstellung(d: Dictionary, cid: String) -> void:
	var verein: Dictionary = d["vereine"][cid]
	var auf: Dictionary = verein["aufstellung"]
	auf["angriff"] = beste_angriffsformation(d, cid)
	auf["abwehr"] = beste_abwehrformation(d, cid, auf["angriff"])
	auf["bank"] = bank_aus_kader(d, cid, auf)
	if str(auf.get("siebenmeter", "")) == "":
		auf["siebenmeter"] = _bester_siebenmeter(d, cid)

static func beste_angriffsformation(d: Dictionary, cid: String) -> Dictionary:
	var verein: Dictionary = d["vereine"][cid]
	var frei: Array = []
	for sid in verein["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if sp["verletzung"].is_empty() and int(sp["sperre"]) <= 0:
			frei.append(sid)
	var auf := {}
	# Torwart zuerst
	var tw := ""
	var best := -1.0
	for sid in frei:
		var sp: Dictionary = d["spieler"][sid]
		if not bool(sp["ist_torwart"]):
			continue
		var w: float = Spielerfabrik.gesamt(sp) * Spielerfabrik.tagesform(sp)
		if w > best:
			best = w
			tw = sid
	if tw != "":
		auf["TW"] = tw
		frei.erase(tw)
	for pos in ["RM", "RL", "RR", "KM", "LA", "RA"]:
		var wahl := ""
		var bestw := -1.0
		for sid in frei:
			var sp: Dictionary = d["spieler"][sid]
			if bool(sp["ist_torwart"]):
				continue
			var w: float = Spielerfabrik.angriff_auf(sp, pos) * Spielerfabrik.tagesform(sp)
			if w > bestw:
				bestw = w
				wahl = sid
		if wahl != "":
			auf[pos] = wahl
			frei.erase(wahl)
	return auf

static func beste_abwehrformation(d: Dictionary, cid: String, angriff: Dictionary) -> Dictionary:
	var verein: Dictionary = d["vereine"][cid]
	var frei: Array = []
	for sid in verein["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if sp["verletzung"].is_empty() and int(sp["sperre"]) <= 0 and not bool(sp["ist_torwart"]):
			frei.append(sid)
	var auf := {"TW": angriff.get("TW", "")}
	# Erst die Innenblocker, dann aussen, dann die Halbpositionen: so bekommt
	# jeder Platz den Spieler, der dort tatsaechlich hingehoert. Vorher wurde
	# rein nach Abwehrwert von A1 bis A6 durchgereicht — dann verteidigte auch
	# schon mal ein Kreislaeufer aussen und ein Aussen im Innenblock.
	var reihenfolge := ["A3", "A4", "A1", "A6", "A2", "A5"]
	for platz in reihenfolge:
		var best := ""
		var bw := -1.0
		for sid in frei:
			var sp: Dictionary = d["spieler"][sid]
			var wert: float = Spielerfabrik.abwehrwert(sp) * Spielerfabrik.abwehr_eignung(sp, platz)
			if wert > bw:
				bw = wert
				best = sid
		if best == "":
			break
		auf[platz] = best
		frei.erase(best)
	return auf

## Am Spieltag darf ein Verein hoechstens so viele Spieler aufbieten.
const SPIELTAGSKADER := 14

static func bank_aus_kader(d: Dictionary, cid: String, auf: Dictionary) -> Array:
	var verein: Dictionary = d["vereine"][cid]
	var drin := {}
	for k in auf.keys():
		if k == "bank" or k == "kapitaen" or k == "siebenmeter":
			continue
		if typeof(auf[k]) == TYPE_STRING:
			drin[auf[k]] = true
	var bank: Array = []
	for sid in verein["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if drin.has(sid) or not sp["verletzung"].is_empty() or int(sp["sperre"]) > 0:
			continue
		bank.append(sid)
	bank = Spielerfabrik.nach_staerke(d, bank)
	# Im Handball stehen am Spieltag hoechstens 14 Spieler im Aufgebot.
	return bank.slice(0, maxi(SPIELTAGSKADER - drin.size(), 0))

static func _bester_siebenmeter(d: Dictionary, cid: String) -> String:
	var verein: Dictionary = d["vereine"][cid]
	var best := ""
	var bw := -1.0
	for sid in verein["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp["ist_torwart"]):
			continue
		var w: float = float(sp["attr"]["siebenmeter"]) * 2.0 + float(sp["attr"]["nervenstaerke"])
		if w > bw:
			bw = w
			best = sid
	return best

# ---------------------------------------------------------------- Personal ---

const PERSONAL_ROLLEN := {
	"cotrainer": {"name": "Co-Trainer", "attr": ["taktik", "training", "menschenfuehrung"]},
	"torwarttrainer": {"name": "Torwarttrainer", "attr": ["torwarttraining", "training", "menschenfuehrung"]},
	"athletiktrainer": {"name": "Athletiktrainer", "attr": ["athletik", "praevention", "training"]},
	"physio": {"name": "Physiotherapeut", "attr": ["heilung", "praevention", "diagnose"]},
	"analyst": {"name": "Spielanalyst", "attr": ["analyse", "taktik", "gegnerbeobachtung"]},
	"nachwuchs": {"name": "Nachwuchskoordinator", "attr": ["jugendarbeit", "training", "menschenkenntnis"]},
	"scout": {"name": "Scout", "attr": ["urteilsvermoegen", "netzwerk", "ausdauer_reise"]},
}

static func _erzeuge_personal(d: Dictionary, cid: String) -> void:
	var verein: Dictionary = d["vereine"][cid]
	var ruf: float = float(verein["ruf"])
	for rolle in ["cotrainer", "torwarttrainer", "athletiktrainer", "physio", "analyst", "nachwuchs"]:
		var pid := erzeuge_mitarbeiter(d, rolle, ruf, verein["nation"])
		d["personal"][pid]["verein"] = cid
		(verein["personal"] as Array).append(pid)
	_stab_benennen(d, cid)
	var scouts: int = 1 + int(ruf / 34.0)
	for i in range(scouts):
		var pid := erzeuge_mitarbeiter(d, "scout", ruf - float(i) * 6.0, verein["nation"])
		d["personal"][pid]["verein"] = cid
		(verein["personal"] as Array).append(pid)

## Gibt dem Trainerstab die echten Namen aus dem Datensatz:
## {"cotrainer": "Christian Sprenger", "torwarttrainer": {"vorname": …, "nation": "dk"}}
static func _stab_benennen(d: Dictionary, cid: String) -> void:
	var verein: Dictionary = d["vereine"][cid]
	var stab: Dictionary = verein.get("stab_datensatz", {})
	if stab.is_empty():
		return
	for pid in verein["personal"]:
		var p: Dictionary = d["personal"][pid]
		var vorgabe: Variant = stab.get(str(p["rolle"]), null)
		if vorgabe == null:
			continue
		if typeof(vorgabe) == TYPE_STRING:
			var teile: PackedStringArray = str(vorgabe).split(" ", false, 1)
			vorgabe = {"vorname": teile[0], "nachname": teile[1] if teile.size() > 1 else ""}
		var e: Dictionary = vorgabe
		p["vorname"] = str(e.get("vorname", p["vorname"]))
		p["nachname"] = str(e.get("nachname", p["nachname"]))
		p["nation"] = str(e.get("nation", p["nation"]))
		if int(e.get("alter", 0)) > 0:
			p["alter"] = int(e["alter"])
		p["echt"] = true
	verein.erase("stab_datensatz")

static func erzeuge_mitarbeiter(d: Dictionary, rolle: String, ruf: float, nation: String) -> String:
	var pid := _neue_personal_id(d)
	var kultur: String = Namen.kultur_zufall(nation, 0.7)
	var p: Dictionary = Namen.person(kultur)
	var attr := {}
	for a in (PERSONAL_ROLLEN[rolle]["attr"] as Array):
		attr[a] = clampf(Namen.glocke(ruf / 6.2, 3.0, 1.0, 20.0), 1.0, 20.0)
	var mitarbeiter := {
		"id": pid,
		"vorname": p["vorname"],
		"nachname": p["nachname"],
		"nation": kultur,
		"alter": Namen.wuerfel(30, 63),
		"rolle": rolle,
		"rollenname": PERSONAL_ROLLEN[rolle]["name"],
		"attr": attr,
		"gehalt": pow(maxf(ruf, 8.0), 1.75) * Namen.bereich(0.35, 0.7) + 220.0,
		"vertrag_bis": Namen.wuerfel(1, 4),
		"verein": "",
		"ruf": clampf(ruf * Namen.bereich(0.82, 1.1), 5.0, 99.0),
		"spezialgebiet": Namen.kultur_zufall(nation, 0.5) if rolle == "scout" else "",
		"erfahrung": Namen.wuerfel(1, 25),
		"berichte": 0,
		"treffer": 0,
	}
	d["personal"][pid] = mitarbeiter
	return pid

static func _erzeuge_freie_spieler(d: Dictionary, anzahl: int) -> void:
	var positionen: Array = Spielerfabrik.POSITIONEN
	for i in range(anzahl):
		var pos: String = positionen[i % positionen.size()]
		var ziel: float = Namen.glocke(43.0, 11.0, 18.0, 76.0)
		var alter_jahre: int = Namen.wuerfel(18, 36)
		var kultur: String = Namen.kultur_zufall("", 0.0)
		var sid := neue_spieler_id(d)
		var sp := Spielerfabrik.erzeuge(sid, kultur, alter_jahre, ziel, pos, int(d["startjahr"]))
		sp["kenntnis"] = Namen.bereich(25.0, 70.0)
		d["spieler"][sid] = sp

static func _erzeuge_rivalitaeten(d: Dictionary) -> void:
	_echte_rivalitaeten(d)
	for lid in d["ligen"].keys():
		var vereine: Array = (d["ligen"][lid]["vereine"] as Array).duplicate()
		vereine.shuffle()
		for i in range(0, vereine.size() - 1, 2):
			var a: String = vereine[i]
			var b: String = vereine[i + 1]
			# Wo schon eine echte Rivalitaet steht, wird nicht gewuerfelt.
			if (d["vereine"][a]["rivalen"] as Dictionary).has(b):
				continue
			var staerke: float = Namen.bereich(45.0, 85.0)
			(d["vereine"][a]["rivalen"] as Dictionary)[b] = staerke
			(d["vereine"][b]["rivalen"] as Dictionary)[a] = staerke
		# Zusaetzlich: geografische Nachbarschaft ueber gleiche Ortsendung
		for i in range(vereine.size()):
			for j in range(i + 1, vereine.size()):
				var va: Dictionary = d["vereine"][vereine[i]]
				var vb: Dictionary = d["vereine"][vereine[j]]
				if str(va["ort"]).substr(0, 4) == str(vb["ort"]).substr(0, 4):
					(va["rivalen"] as Dictionary)[vb["id"]] = maxf(float((va["rivalen"] as Dictionary).get(vb["id"], 0.0)), 70.0)
					(vb["rivalen"] as Dictionary)[va["id"]] = maxf(float((vb["rivalen"] as Dictionary).get(va["id"], 0.0)), 70.0)

## Loest die im Datensatz hinterlegten Rivalitaeten auf.
##
## Bis hierher wuerfelte das Spiel Rivalitaeten aus: zufaellige Paare je Liga
## plus gleiche Ortsendung. Fuer eine erfundene Welt ist das richtig, fuer eine
## echte falsch — dort ist das Nordderby zwischen Kiel und Flensburg keine
## Frage des Zufalls. Und es hat Folgen: an der Rivalitaet haengt, ob ein
## Fuehrungsspieler zum Konkurrenten wechselt (siehe kern/Wechselbereitschaft.gd),
## wie viele Zuschauer kommen und wie die Halle klingt.
static func _echte_rivalitaeten(d: Dictionary) -> void:
	var nach_kurz := {}
	for cid in d["vereine"].keys():
		nach_kurz[str(d["vereine"][cid]["kurz"])] = str(cid)
	for cid2 in d["vereine"].keys():
		var v: Dictionary = d["vereine"][cid2]
		var vorgabe: Dictionary = v.get("rivalen_kurz", {})
		if vorgabe.is_empty():
			continue
		for kurz in vorgabe.keys():
			var ziel: String = str(nach_kurz.get(str(kurz), ""))
			if ziel == "" or ziel == str(cid2):
				continue
			var staerke: float = float(vorgabe[kurz])
			(v["rivalen"] as Dictionary)[ziel] = staerke
			(d["vereine"][ziel]["rivalen"] as Dictionary)[str(cid2)] = staerke
		v.erase("rivalen_kurz")

# ----------------------------------------------------------- Wettbewerbe ---

static func _erzeuge_wettbewerbe(d: Dictionary) -> void:
	_erzeuge_wettbewerbe_roh(d)
	# In der echten Welt tragen die Wettbewerbe ihre echten Namen.
	if bool(d.get("echte_welt", false)):
		d["international"]["i_krone"]["name"] = "EHF Champions League"
		d["international"]["i_challenge"]["name"] = "EHF European League"
		# Seit 2026/27: 24 Teams in sechs Vierergruppen, am Ende ein Final4.
		d["international"]["i_krone"]["teilnehmer_soll"] = 24
		d["international"]["i_krone"]["final4"] = true

static func _erzeuge_wettbewerbe_roh(d: Dictionary) -> void:
	d["international"] = {
		"i_krone": {
			"id": "i_krone",
			"name": "Kontinentalkrone",
			"typ": "international",
			"stufe": 1,
			"teilnehmer": [],
			"gruppen": [],
			"tabelle": {},
			"phase": "vorbereitung",
			"paarungen": [],
			"runde": 0,
			"sieger_historie": [],
			"preisgeld_runde": 260000.0,
		},
		"i_challenge": {
			"id": "i_challenge",
			"name": "Challenge-Trophäe",
			"typ": "international",
			"stufe": 2,
			"teilnehmer": [],
			"gruppen": [],
			"tabelle": {},
			"phase": "vorbereitung",
			"paarungen": [],
			"runde": 0,
			"sieger_historie": [],
			"preisgeld_runde": 95000.0,
		},
	}

## Die Medienlandschaft.
##
## Frueher waren es vier Redaktionen je Nation, alle vom selben Schlag, dazu
## sechzig Fanaccounts. Damit las sich die Presse ueber Jahre gleich: dieselben
## Namen, dieselbe Machart, und niemand, der auf einen bestimmten Verein schaut.
##
## Jetzt hat jedes Medium eine Gattung, die bestimmt, worueber es schreibt und
## wie laut. Und jeder Erstligist bekommt sein Lokalblatt — das Medium, das nur
## ueber ihn berichtet und ihn deshalb anders behandelt als eine ueberregionale
## Zeitung.
const MEDIENGATTUNGEN := ["Tageszeitung", "Boulevard", "Fachmagazin", "Onlineportal",
	"Podcast", "Vereinsfunk", "Sportschau"]
const HALTUNGEN := ["nüchtern", "reißerisch", "wohlwollend", "kritisch", "analytisch"]
## Welche Haltung zu einer Gattung passt. Ein Boulevardblatt ist nicht nüchtern.
const GATTUNG_HALTUNG := {
	"Tageszeitung": ["nüchtern", "kritisch", "analytisch"],
	"Boulevard": ["reißerisch", "reißerisch", "kritisch"],
	"Fachmagazin": ["analytisch", "nüchtern"],
	"Onlineportal": ["reißerisch", "nüchtern", "wohlwollend"],
	"Podcast": ["analytisch", "wohlwollend", "kritisch"],
	"Vereinsfunk": ["wohlwollend", "wohlwollend", "nüchtern"],
	"Sportschau": ["nüchtern", "analytisch"],
}

static func _erzeuge_medien(d: Dictionary) -> void:
	var outlets: Array = []
	for nid in d["nationen"].keys():
		for gattung in MEDIENGATTUNGEN:
			if str(gattung) == "Vereinsfunk":
				continue
			# Zwei je Gattung: mit einer einzigen Tageszeitung je Land bliebe
			# die Auswahl so klein, dass ueber eine Saison doch wieder
			# dieselben Namen ueber jedem Bericht stehen.
			for _zwei in range(2):
				outlets.append({
					"name": Namen.medium(nid),
					"nation": nid,
					"gattung": str(gattung),
					"verein": "",
					"haltung": Namen.waehle(GATTUNG_HALTUNG.get(gattung, HALTUNGEN)),
					"reichweite": Namen.bereich(20.0, 100.0),
				})
	# Das Lokalblatt jedes Erstligisten. Es schreibt nur ueber seinen Verein,
	# haelt zu ihm und weiss trotzdem, wann es unangenehm werden muss.
	for lid in d["ligen"].keys():
		if int(d["ligen"][lid]["stufe"]) != 1:
			continue
		for cid in d["ligen"][lid]["vereine"]:
			var v: Dictionary = d["vereine"][cid]
			outlets.append({
				"name": "%s Rundschau" % str(v["ort"]),
				"nation": str(v["nation"]),
				"gattung": "Vereinsfunk",
				"verein": str(cid),
				"haltung": Namen.waehle(["wohlwollend", "wohlwollend", "nüchtern"]),
				"reichweite": Namen.bereich(12.0, 45.0),
			})
	d["medien"]["outlets"] = outlets
	var fans: Array = []
	for i in range(120):
		fans.append({
			"handle": Namen.fan_handle(),
			"typ": Namen.waehle(["dauerkarte", "ultra", "nörgler", "statistiker", "optimist", "neutral", "insider"]),
			"folgen": Namen.wuerfel(80, 42000),
		})
	d["medien"]["fanaccounts"] = fans

static func _erzeuge_rekorde(d: Dictionary) -> void:
	d["rekorde"] = {
		"hoechster_sieg": {},
		"meiste_tore_spiel": {},
		"laengste_siegesserie": {},
		"meiste_paraden": {},
		"teuerster_transfer": {},
		"schnellstes_tor": {},
	}


## Ein Teil der Startverträge enthält Erfolgsprämien — je besser zahlend der
## Verein, desto eher wird variabel vergütet. Das Festgehalt sinkt entsprechend.
## `niveau` ist das Lohnniveau des Vereins: Prämien gehören zum Gehalt und
## dürfen einen kleinen Verein nicht dasselbe kosten wie einen Spitzenklub.
static func _startpraemien_setzen(sp: Dictionary, ruf: float, niveau: float = 1.0) -> void:
	var vertrag: Dictionary = sp["vertrag"]
	vertrag["praemie_tor"] = 0.0
	vertrag["praemie_sieg"] = 0.0
	if Namen.zufall() > clampf(0.14 + ruf / 320.0, 0.14, 0.45):
		return
	var mass: float = clampf(ruf / 100.0, 0.2, 1.0) * Namen.bereich(0.35, 1.0) * niveau
	if not bool(sp["ist_torwart"]) and Namen.zufall() < 0.7:
		vertrag["praemie_tor"] = roundf(Praemien.TOR_MAX * mass * 0.55 / 50.0) * 50.0
	if Namen.zufall() < 0.75:
		vertrag["praemie_sieg"] = roundf(Praemien.SIEG_MAX * mass * 0.5 / 100.0) * 100.0
	var ersatz: float = Praemien.erwartete_wochenkosten(sp, float(vertrag["praemie_tor"]),
		float(vertrag["praemie_sieg"]), clampf(ruf / 130.0, 0.25, 0.78)) * Praemien.anrechnungsfaktor(sp)
	vertrag["gehalt"] = maxf(float(vertrag["gehalt"]) - ersatz, float(vertrag["gehalt"]) * 0.5)

## Ein Teil der Startverträge trägt eine Ablöseklausel — vor allem bei jungen
## Spielern, die sie sich bei der Unterschrift haben zusichern lassen.
static func _klausel_setzen(sp: Dictionary) -> void:
	sp["vertrag"]["ablöseklausel"] = 0.0
	var jung: bool = int(sp["alter"]) <= 24
	if Namen.zufall() > (0.16 if jung else 0.07):
		return
	var faktor: float = Namen.bereich(1.2, 3.4) if not jung else Namen.bereich(1.4, 4.5)
	sp["vertrag"]["ablöseklausel"] = roundf(maxf(float(sp["wert"]), 1000.0) * faktor / 25000.0) * 25000.0
