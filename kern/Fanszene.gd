class_name Fanszene
extends RefCounted
## Die Fans sind keine Zahl, sondern vier Gruppen mit eigenen Interessen.
##
## Bisher hatte ein Verein "Zufriedenheit" und "Treue" — zwei Regler, die immer
## in dieselbe Richtung zeigten. In Wahrheit will die Kurve etwas anderes als
## die Loge: Die Ultras wollen Einsatz, eigene Leute und billige Karten; die
## Logengäste wollen Erfolg, Komfort und Ansehen. Wer es allen recht macht,
## macht es niemandem recht — und genau darin liegt die Entscheidung.
##
## Gespeichert je Verein in `verein["fanszene"]`. Der Mittelwert schreibt
## weiterhin `fans.zufriedenheit` fort, damit alles Bestehende gültig bleibt.

const GRUPPEN := ["ultras", "treue", "familien", "geschaeft"]

const GRUPPE := {
	"ultras": {
		"name": "Die Kurve",
		"kurzname": "Die Kurve",
		"kurz": "ULTRAS",
		"text": "Steht die ganze Partie, singt bei Rückstand lauter. Erwartet Einsatz, eigene Leute und bezahlbare Karten.",
		"gewicht": 0.22, "puls": 1.6,
	},
	"treue": {
		"name": "Dauerkartenbesitzer",
		"kurzname": "Dauerkarten",
		"kurz": "TREUE",
		"text": "Seit Jahren derselbe Platz. Erwartet Verlässlichkeit, keine Experimente und dass die Karte ihr Geld wert ist.",
		"gewicht": 0.31, "puls": 1.0,
	},
	"familien": {
		"name": "Familien und Gelegenheitspublikum",
		"kurzname": "Familien",
		"kurz": "FAMILIEN",
		"text": "Kommt, wenn es sich lohnt. Erwartet Unterhaltung, Komfort und Preise, die eine vierköpfige Familie verkraftet.",
		"gewicht": 0.29, "puls": 0.6,
	},
	"geschaeft": {
		"name": "Loge und Geschäftspartner",
		"kurzname": "Loge & Geschäft",
		"kurz": "GESCHÄFT",
		"text": "Zahlt viel und redet mit Sponsoren. Erwartet Erfolg, Ansehen und eine Halle, in der man Gäste empfangen kann.",
		"gewicht": 0.18, "puls": 0.25,
	},
}

## Ab welcher Stimmung eine Gruppe von sich aus laut wird.
const PROTEST := 32.0
const BEGEISTERT := 78.0

static func szene(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("fanszene"):
		var start: float = float(v["fans"]["zufriedenheit"])
		var neu := {}
		for g in GRUPPEN:
			neu[g] = {"stimmung": clampf(start + Namen.bereich(-8.0, 8.0), 10.0, 95.0), "gemeldet": 0}
		v["fanszene"] = neu
	return v["fanszene"]

static func stimmung(d: Dictionary, cid: String, gruppe: String) -> float:
	return float((szene(d, cid).get(gruppe, {}) as Dictionary).get("stimmung", 50.0))

## Gewichteter Mittelwert — das, was nach außen als "die Fans" gilt.
static func gesamtstimmung(d: Dictionary, cid: String) -> float:
	var s := szene(d, cid)
	var summe := 0.0
	var gewicht := 0.0
	for g in GRUPPEN:
		var w: float = float((GRUPPE[g] as Dictionary)["gewicht"])
		summe += float((s.get(g, {}) as Dictionary).get("stimmung", 50.0)) * w
		gewicht += w
	return summe / maxf(gewicht, 0.01)

# ------------------------------------------------------------ Wochenlauf ---

## Jede Gruppe zieht ihre eigene Bilanz. Dieselbe Woche kann die Kurve
## begeistern und die Loge verstimmen — das ist der Sinn der Sache.
static func wochenwechsel(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var s := szene(d, cid)
	var ziel := ziele(d, cid)
	for g in GRUPPEN:
		var e: Dictionary = s[g]
		# Stimmung folgt dem Ziel träge: eine Kurve dreht nicht in einer Woche.
		e["stimmung"] = clampf(lerpf(float(e["stimmung"]), float(ziel[g]), 0.16), 3.0, 100.0)
	# Der Mittelwert bleibt die Größe, mit der der Rest des Spiels rechnet.
	var fans: Dictionary = v["fans"]
	fans["zufriedenheit"] = clampf(gesamtstimmung(d, cid), 3.0, 100.0)
	# Treue wächst langsam mit anhaltender Zufriedenheit und fällt schneller.
	var abstand: float = float(fans["zufriedenheit"]) - float(fans["treue"])
	fans["treue"] = clampf(float(fans["treue"]) + clampf(abstand * 0.035, -0.9, 0.5), 10.0, 99.0)

## Wohin jede Gruppe gerade strebt. Getrennt berechnet, damit die Oberfläche
## erklären kann, woran es liegt.
static func ziele(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var gruende := begruendungen(d, cid)
	var aus := {}
	for g in GRUPPEN:
		var basis := 50.0
		for e in (gruende[g] as Array):
			basis += float((e as Dictionary)["wert"])
		aus[g] = clampf(basis, 3.0, 100.0)
	return aus

## Was jede Gruppe gerade bewegt, als Liste aus Grund und Gewicht. Genau diese
## Liste steht später im Bildschirm — niemand soll raten müssen.
static func begruendungen(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var aus := {}
	for g in GRUPPEN:
		aus[g] = []

	# --- Sportlicher Verlauf: zählt für alle, aber unterschiedlich stark.
	var punkte := 0.0
	for e in (v["formkurve"] as Array):
		punkte += 4.0 if str(e) == "S" else (1.0 if str(e) == "U" else -3.5)
	var form: float = clampf(punkte * 1.5, -22.0, 24.0)
	_eintrag(aus, "ultras", "Ergebnisse der letzten Spiele", form * 0.75)
	_eintrag(aus, "treue", "Ergebnisse der letzten Spiele", form)
	_eintrag(aus, "familien", "Ergebnisse der letzten Spiele", form * 0.8)
	_eintrag(aus, "geschaeft", "Ergebnisse der letzten Spiele", form * 1.25)

	# --- Tabellenplatz gegen die Erwartung des Vorstands.
	var lid: String = str(v["liga"])
	if d["ligen"].has(lid):
		var tabelle: Array = Spielplan.tabelle_sortiert(d, lid)
		var platz: int = tabelle.find(cid) + 1
		if platz > 0:
			var ziel_platz: int = int(v["vorstand"]["ziel_platz"])
			var abweichung: float = clampf(float(ziel_platz - platz) * 2.4, -16.0, 16.0)
			_eintrag(aus, "geschaeft", "Tabellenplatz %d (Ziel %d)" % [platz, ziel_platz], abweichung * 1.2)
			_eintrag(aus, "treue", "Tabellenplatz %d (Ziel %d)" % [platz, ziel_platz], abweichung)
			_eintrag(aus, "familien", "Tabellenplatz %d" % platz, abweichung * 0.6)

	# --- Eintrittspreise: das Thema der Kurve.
	var preisdruck: float = Ticketing.fanwirkung(d, cid) * 3.4
	_eintrag(aus, "ultras", "Preis der Stehplätze (%s)" % Ticketing.preistext(d, cid, "steh"), preisdruck)
	_eintrag(aus, "familien", "Preis der Sitzplätze (%s)" % Ticketing.preistext(d, cid, "sitz"), preisdruck * 0.85)
	_eintrag(aus, "treue", "Dauerkartenrabatt", clampf((0.85 - float(Ticketing.daten(d, cid)["dauerkarte_faktor"])) * 40.0, -8.0, 9.0))

	# --- Eigene Leute im Kader: der zweite Herzenspunkt der Kurve.
	var eigene := 0
	var jung := 0
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if str(sp.get("ausbildungsverein", "")) == str(cid):
			eigene += 1
		if int(sp["alter"]) <= 21:
			jung += 1
	_eintrag(aus, "ultras", "%d Spieler aus der eigenen Jugend" % eigene, clampf(float(eigene) * 3.2 - 4.0, -6.0, 13.0))
	_eintrag(aus, "treue", "%d Spieler unter 22 im Kader" % jung, clampf(float(jung) * 1.4 - 2.0, -3.0, 6.0))

	# --- Einsatz und Härte: die Kurve verzeiht eine Niederlage, keine Lauheit.
	var haerte: float = float(v["taktik"].get("haerte", 45))
	var tempo: float = float(v["taktik"].get("tempo", 50))
	_eintrag(aus, "ultras", "Zweikampfhärte der Abwehr", clampf((haerte - 45.0) * 0.16, -6.0, 7.0))
	_eintrag(aus, "familien", "Tempo im Angriff", clampf((tempo - 45.0) * 0.10, -4.0, 5.0))

	# --- Komfort der Halle: Familien und Loge merken ihn zuerst.
	var komfort: float = float(v["halle"]["komfort"])
	_eintrag(aus, "familien", "Komfort der Halle (Stufe %d)" % int(komfort), clampf((komfort - 4.5) * 2.1, -8.0, 11.0))
	_eintrag(aus, "geschaeft", "Komfort der Halle (Stufe %d)" % int(komfort), clampf((komfort - 5.0) * 2.6, -10.0, 12.0))

	# --- Ansehen des Vereins: Währung der Geschäftspartner.
	_eintrag(aus, "geschaeft", "Ansehen des Vereins", clampf((float(v["ruf"]) - 50.0) * 0.16, -8.0, 8.0))

	# --- Transferpolitik: verkaufte Leistungsträger merkt sich die Kurve.
	var verkauft: int = int(v.get("saison", {}).get("verkaufte_stammspieler", 0))
	if verkauft > 0:
		_eintrag(aus, "ultras", "%d verkaufte Leistungsträger" % verkauft, -float(verkauft) * 5.5)
		_eintrag(aus, "treue", "%d verkaufte Leistungsträger" % verkauft, -float(verkauft) * 3.5)

	# --- Wirtschaftliche Lage: die Loge liest Bilanzen.
	if float(v["kasse"]) < 0.0:
		_eintrag(aus, "geschaeft", "Negative Kasse", -9.0)
	var schuld: float = Darlehen.restschuld(d, cid)
	if schuld > float(v["jahresetat"]) * 0.5:
		_eintrag(aus, "geschaeft", "Hohe Verschuldung", -7.0)

	return aus

static func _eintrag(sammlung: Dictionary, gruppe: String, grund: String, wert: float) -> void:
	if absf(wert) < 0.4:
		return
	(sammlung[gruppe] as Array).append({"grund": grund, "wert": wert})

# ------------------------------------------------------------- Wirkungen ---

## Wie stark die Fanszene den Hallenpuls trägt (Multiplikator um 1.0).
static func pulsfaktor(d: Dictionary, cid: String) -> float:
	var s := szene(d, cid)
	var gewichtet := 0.0
	var summe := 0.0
	for g in GRUPPEN:
		var w: float = float((GRUPPE[g] as Dictionary)["puls"]) * float((GRUPPE[g] as Dictionary)["gewicht"])
		gewichtet += float((s.get(g, {}) as Dictionary).get("stimmung", 50.0)) * w
		summe += w
	var mittel: float = gewichtet / maxf(summe, 0.01)
	return clampf(0.78 + mittel / 230.0, 0.72, 1.24)

## Zusätzlicher Reiz aufs Publikum am Spieltag (Multiplikator um 1.0).
static func besuchsreiz(d: Dictionary, cid: String) -> float:
	return clampf(0.82 + gesamtstimmung(d, cid) / 280.0, 0.72, 1.2)

## Ein direkter Stoß auf eine Gruppe — Titel, Abstieg, Skandal, Choreo.
static func stossen(d: Dictionary, cid: String, gruppe: String, wert: float) -> void:
	var e: Dictionary = szene(d, cid).get(gruppe, {})
	if e.is_empty():
		return
	e["stimmung"] = clampf(float(e["stimmung"]) + wert, 3.0, 100.0)

static func alle_stossen(d: Dictionary, cid: String, wert: float) -> void:
	for g in GRUPPEN:
		stossen(d, cid, str(g), wert)

# ------------------------------------------------------------- Meldungen ---

## Gruppen, die von sich aus laut werden. Nur für den eigenen Verein und nur,
## wenn sich etwas geändert hat — sonst stünde jede Woche dasselbe im Postfach.
static func meldungen_pruefen(d: Dictionary, cid: String) -> void:
	if cid != Welt.mein_verein_id:
		return
	var s := szene(d, cid)
	for g in GRUPPEN:
		var e: Dictionary = s[g]
		var wert: float = float(e["stimmung"])
		var stufe: int = -1 if wert <= PROTEST else (1 if wert >= BEGEISTERT else 0)
		if stufe == int(e.get("gemeldet", 0)):
			continue
		e["gemeldet"] = stufe
		if stufe == 0:
			continue
		var info: Dictionary = GRUPPE[g]
		var gruende: Array = (begruendungen(d, cid)[g] as Array)
		gruende.sort_custom(func(a, b): return absf(float(a["wert"])) > absf(float(b["wert"])))
		var punkte: Array = []
		for p in gruende.slice(0, 3):
			punkte.append("%s (%s%d)" % [str(p["grund"]), "+" if float(p["wert"]) >= 0.0 else "", int(float(p["wert"]))])
		if stufe < 0:
			Welt.nachricht({
				"typ": "verein", "wichtig": true,
				"betreff": "Unmut: %s" % str(info["name"]),
				"text": "%s macht ihrem Ärger Luft. Am schwersten wiegt: %s." % [str(info["name"]), ", ".join(punkte)],
				"daten": {"verein": cid},
			})
		else:
			Welt.nachricht({
				"typ": "verein",
				"betreff": "Rückenwind: %s" % str(info["name"]),
				"text": "%s steht geschlossen hinter der Mannschaft. Ausschlaggebend: %s." % [str(info["name"]), ", ".join(punkte)],
				"daten": {"verein": cid},
			})
