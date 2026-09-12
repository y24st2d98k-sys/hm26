class_name Talentsuche
extends RefCounted
## Nachwuchssichtung: Talente für die eigene Akademie holen.
##
## Bisher entstand Nachwuchs nur im eigenen Verein — einmal im Jahr kam ein
## Jahrgang, und damit war die Frage beantwortet. Ein Verein mit gutem Scouting
## arbeitet aber anders: er schickt Leute in eine Region, lässt Jahrgänge
## sichten und holt die zwei, drei Jungen, die herausstechen, in die eigene
## Akademie — gegen eine Ausbildungsentschädigung an den Heimatverein.
##
## Ein Talent, das ein Scout gefunden hat, steht nicht ewig bereit. Andere
## Vereine sichten dieselben Hallen; wer zögert, verliert. Genau deshalb ist
## das eine Entscheidung und keine Liste zum Abarbeiten.

## Regionen, in die ein Scout reisen kann. Jede Region hat eine eigene
## Handballkultur: Skandinavien bringt ausgebildete Rückraumspieler, der
## Balkan Physis und Härte, Nordafrika Athletik und rohes Talent.
const REGIONEN := {
	"heimat": {
		"name": "Eigene Region", "dauer": 12, "kosten": 8000.0,
		"nationen": [], "streuung": 0.9, "guete": 0.95,
		"text": "Nahe Vereine und Verbandsauswahlen. Günstig, verlässlich, selten spektakulär.",
	},
	"skandinavien": {
		"name": "Skandinavien", "dauer": 20, "kosten": 26000.0,
		"nationen": ["dk", "se", "no", "is", "fo", "fi"], "streuung": 1.0, "guete": 1.18,
		"text": "Hervorragend ausgebildete Rückraumspieler. Teuer, aber selten ein Fehlgriff.",
	},
	"balkan": {
		"name": "Balkan", "dauer": 22, "kosten": 17000.0,
		"nationen": ["hr", "rs", "si", "ba", "me", "mk", "hu", "ro"], "streuung": 1.35, "guete": 1.08,
		"text": "Große Streuung. Wer trifft, findet einen Weltklassespieler für nichts.",
	},
	"westeuropa": {
		"name": "Westeuropa", "dauer": 18, "kosten": 24000.0,
		"nationen": ["fr", "es", "pt", "nl", "be", "it", "ch", "at"], "streuung": 1.05, "guete": 1.12,
		"text": "Dichte Nachwuchsstrukturen — und starke Konkurrenz um jedes Talent.",
	},
	"osteuropa": {
		"name": "Osteuropa", "dauer": 24, "kosten": 13000.0,
		"nationen": ["pl", "cz", "sk", "ua", "by", "lv"], "streuung": 1.2, "guete": 1.0,
		"text": "Wenig beobachtet. Lange Reisen, niedrige Entschädigungen.",
	},
	"uebersee": {
		"name": "Übersee", "dauer": 30, "kosten": 34000.0,
		"nationen": ["eg", "tn", "br", "qa", "jp", "kr"], "streuung": 1.5, "guete": 1.02,
		"text": "Athleten mit wenig Handballschule. Ein Risiko mit hoher Decke.",
	},
}

## Wie lange ein gefundenes Talent verfügbar bleibt.
const FRIST_TAGE := 30

## Wie viele Talente in der Akademie höchstens Platz haben.
const AKADEMIE_GRENZE := 16

static func _pool(d: Dictionary) -> Array:
	var sc: Dictionary = d["scouting"]
	if not sc.has("talente"):
		sc["talente"] = []
	return sc["talente"]

## Alle derzeit für diesen Verein verfügbaren Talente.
static func verfuegbar(d: Dictionary, cid: String) -> Array:
	var aus: Array = []
	for e in _pool(d):
		if str(e["verein"]) != cid:
			continue
		if not d["spieler"].has(str(e["spieler"])):
			continue
		aus.append(e)
	aus.sort_custom(func(a, b):
		return float(d["spieler"][a["spieler"]]["potenzial"]) > float(d["spieler"][b["spieler"]]["potenzial"]))
	return aus

## Was eine Sichtungsreise kostet. Ein großer Verein zahlt mehr, weil er
## anders auftritt — und weil er sich anders behandeln lässt.
static func reisekosten(d: Dictionary, cid: String, region: String) -> float:
	var r: Dictionary = REGIONEN.get(region, REGIONEN["heimat"])
	var v: Dictionary = d["vereine"][cid]
	return float(r["kosten"]) * (0.6 + 0.5 * clampf(float(v["ruf"]) / 70.0, 0.2, 1.6))

## Der Scout reist los. Läuft über die normale Auftragsverwaltung, damit
## Scouting an einer Stelle bleibt.
static func sichtung_beauftragen(d: Dictionary, pid: String, region: String) -> Dictionary:
	var cid: String = Welt.mein_verein_id
	if cid == "":
		return {"ok": false, "grund": "Kein Verein."}
	if not REGIONEN.has(region):
		return {"ok": false, "grund": "Diese Region kennt niemand."}
	var kosten: float = reisekosten(d, cid, region)
	if float(d["vereine"][cid]["kasse"]) < kosten:
		return {"ok": false, "grund": "Die Reise nach %s kostet %s — das gibt die Kasse nicht her." % [
			str(REGIONEN[region]["name"]), Stil.geld(kosten)]}
	var erg := Scouting.auftrag_erteilen(d, pid, "nachwuchs", region)
	if not bool(erg["ok"]):
		return erg
	Finanzen.buchen(d, cid, -kosten, "Sichtungsreise %s" % str(REGIONEN[region]["name"]), "scouting")
	return {"ok": true, "grund": "%s Reisekosten gebucht. %s" % [Stil.geld(kosten), str(erg["grund"])]}

## Der Bericht: wen der Scout gefunden hat. Die Güte des Scouts entscheidet
## über Anzahl und Qualität — ein schwacher Scout bringt vier Mitläufer,
## ein guter zwei echte Talente.
static func bericht(d: Dictionary, a: Dictionary, qualitaet: float) -> Array:
	var cid: String = str(a["verein"])
	if not d["vereine"].has(cid):
		return []
	var region: String = str(a["ziel"])
	var r: Dictionary = REGIONEN.get(region, REGIONEN["heimat"])
	var v: Dictionary = d["vereine"][cid]
	var anzahl: int = 2 + (1 if qualitaet > 45.0 else 0) + (1 if qualitaet > 72.0 else 0)
	var nationen: Array = r["nationen"]
	if nationen.is_empty():
		nationen = [str(v["nation"])]
	var gefunden: Array = []
	for _i in range(anzahl):
		var kultur: String = str(Namen.waehle(nationen))
		var basis: float = 20.0 + qualitaet * 0.11 + float(v["ruf"]) * 0.06
		var ziel: float = clampf(Namen.glocke(basis, 4.5 * float(r["streuung"]), 12.0, 52.0), 12.0, 52.0)
		var pos: String = str(Namen.waehle(Spielerfabrik.POSITIONEN))
		var sid: String = Weltgenerator.neue_spieler_id(d)
		var sp: Dictionary = Spielerfabrik.erzeuge(sid, kultur, Namen.wuerfel(15, 18), ziel, pos, int(d["startjahr"]))
		# Das Potenzial ist der eigentliche Fund. Die Region verschiebt die
		# Decke, das Gespür des Scouts verengt die Streuung nach oben.
		var deckel: float = float(r["guete"]) * (0.9 + 0.004 * qualitaet)
		sp["potenzial"] = clampf((float(sp["potenzial"]) + Namen.bereich(-4.0, 14.0 * float(r["streuung"]))) * deckel, ziel + 5.0, 96.0)
		# Ein gesichtetes Talent ist nur so gut bekannt, wie der Scout taugt.
		sp["kenntnis"] = clampf(24.0 + qualitaet * 0.42, 18.0, 88.0)
		sp["verein"] = ""
		sp["jugendspieler"] = true
		sp["nachwuchskandidat"] = true
		sp["vertrag"] = {}
		sp["wert"] = Spielerfabrik.marktwert(sp)
		d["spieler"][sid] = sp
		# Ausbildungsentschädigung: der Heimatverein gibt niemanden umsonst ab.
		var entschaedigung: float = (8000.0 + float(sp["potenzial"]) * 1450.0) * Namen.bereich(0.75, 1.3)
		_pool(d).append({
			"spieler": sid,
			"verein": cid,
			"region": region,
			"scout": str(a["scout"]),
			"gefunden_tag": int(d["tag"]),
			"frist": int(d["tag"]) + FRIST_TAGE,
			"entschaedigung": roundf(entschaedigung / 500.0) * 500.0,
			"gehalt": 150.0 + ziel * 3.4,
		})
		gefunden.append(sid)
	return gefunden

## Ein Talent verpflichten. Es landet im Jugendbereich, nicht im Profikader.
static func verpflichten(d: Dictionary, sid: String) -> Dictionary:
	var cid: String = Welt.mein_verein_id
	var eintrag := _eintrag(d, sid)
	if eintrag.is_empty() or str(eintrag["verein"]) != cid:
		return {"ok": false, "grund": "Dieses Talent steht Ihnen nicht zur Verfügung."}
	var v: Dictionary = d["vereine"][cid]
	if (v.get("jugend", []) as Array).size() >= AKADEMIE_GRENZE:
		return {"ok": false, "grund": "Die Akademie ist voll (%d Plätze). Befördern oder verabschieden Sie zuerst jemanden." % AKADEMIE_GRENZE}
	var kosten: float = float(eintrag["entschaedigung"])
	if float(v["kasse"]) < kosten:
		return {"ok": false, "grund": "Die Ausbildungsentschädigung von %s ist nicht gedeckt." % Stil.geld(kosten)}
	var sp: Dictionary = d["spieler"][sid]
	sp["verein"] = cid
	sp["nachwuchskandidat"] = false
	sp["jugendspieler"] = true
	sp["aus_eigener_jugend"] = false
	sp["kenntnis"] = clampf(float(sp["kenntnis"]) + 20.0, 0.0, 100.0)
	sp["vertrag"] = {
		"bis_saison": Welt.saison_index() + Namen.wuerfel(3, 5),
		"gehalt": float(eintrag["gehalt"]),
		"rolle": "talent",
		"ablöseklausel": 0.0,
		"unterschrieben_saison": Welt.saison_index(),
		"praemie_tor": 0.0, "praemie_sieg": 0.0,
	}
	(v["jugend"] as Array).append(sid)
	Finanzen.buchen(d, cid, -kosten, "Ausbildungsentschädigung %s" % Spielerfabrik.voller_name(sp), "transfer")
	v["transferbudget"] = maxf(float(v["transferbudget"]) - kosten, 0.0)
	Laufbahn.eintragen(d, sid, "jugend", "Kam über die Nachwuchssichtung in die Akademie von %s." % str(v["name"]))
	_streichen(d, sid)
	return {"ok": true, "grund": "%s kommt für %s in die Akademie." % [Spielerfabrik.voller_name(sp), Stil.geld(kosten)]}

## Ein Talent ablehnen — dann ist es sofort weg, wie im echten Leben.
static func ablehnen(d: Dictionary, sid: String) -> void:
	_entfernen(d, sid)

static func _eintrag(d: Dictionary, sid: String) -> Dictionary:
	for e in _pool(d):
		if str(e["spieler"]) == sid:
			return e
	return {}

## Nur aus der Liste nehmen — der Spieler bleibt bestehen.
static func _streichen(d: Dictionary, sid: String) -> void:
	var pool := _pool(d)
	for i in range(pool.size() - 1, -1, -1):
		if str((pool[i] as Dictionary)["spieler"]) == sid:
			pool.remove_at(i)

## Aus der Liste nehmen und den Spieler auflösen: ein nicht verpflichteter
## Kandidat darf nicht als vereinsloser Sechzehnjähriger in der Welt stehen
## bleiben, sonst füllt sich der Spielstand mit Namen, die niemand kennt.
static func _entfernen(d: Dictionary, sid: String) -> void:
	_streichen(d, sid)
	if d["spieler"].has(sid) and bool(d["spieler"][sid].get("nachwuchskandidat", false)):
		d["spieler"].erase(sid)

static func tageswechsel(d: Dictionary) -> void:
	var pool := _pool(d)
	for i in range(pool.size() - 1, -1, -1):
		var e: Dictionary = pool[i]
		var sid: String = str(e["spieler"])
		if not d["spieler"].has(sid):
			pool.remove_at(i)
			continue
		var sp: Dictionary = d["spieler"][sid]
		if int(d["tag"]) >= int(e["frist"]):
			if str(e["verein"]) == Welt.mein_verein_id:
				Welt.nachricht({
					"typ": "scouting",
					"betreff": "Talent vergeben: %s" % Spielerfabrik.voller_name(sp),
					"text": "%s hat sich einem anderen Verein angeschlossen. Die Sichtung war umsonst." % Spielerfabrik.kurz_name(sp),
				})
			_entfernen(d, sid)
			continue
		# Konkurrenz: je größer das Talent, desto eher greift ein anderer zu.
		var druck: float = clampf((float(sp["potenzial"]) - 55.0) / 260.0, 0.002, 0.16)
		if Namen.zufall() < druck:
			if str(e["verein"]) == Welt.mein_verein_id:
				Welt.nachricht({
					"typ": "scouting",
					"betreff": "Zu spät: %s" % Spielerfabrik.voller_name(sp),
					"text": "Ein anderer Verein war schneller. %s wird nicht bei uns ausgebildet." % Spielerfabrik.kurz_name(sp),
				})
			_entfernen(d, sid)

## Beim Vereinswechsel oder bei einer Freistellung: die alten Funde gehören dem
## alten Verein. Ein neuer Trainer erbt keine Sichtungsliste, und ein
## freigestellter erst recht nicht.
static func aufraeumen(d: Dictionary) -> void:
	if not d.has("scouting"):
		return
	var mein: String = Welt.mein_verein_id
	for e in _pool(d).duplicate():
		var cid: String = str((e as Dictionary)["verein"])
		if cid != mein or not d["vereine"].has(cid):
			_entfernen(d, str((e as Dictionary)["spieler"]))
