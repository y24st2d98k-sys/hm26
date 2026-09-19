class_name Ehemalige
extends RefCounted
## Wer gegangen ist, verschwindet nicht.
##
## Die stärksten Momente eines Managerspiels sind Reue und Genugtuung: der
## Spieler, den man zu früh verkauft hat, trifft gegen einen; der, den man hat
## ziehen lassen, wird anderswo Torschützenkönig. Beides kostet fast nichts —
## die Simulation rechnet diese Spieler ohnehin weiter. Sie wurden nur nie
## wieder erwähnt.
##
## Gemerkt werden höchstens die letzten dreißig Abgänge. Wer weiter zurückliegt,
## interessiert niemanden mehr, und der Spielstand soll nicht mit Karteileichen
## wachsen.

const HOECHSTENS := 30
## So lange gilt einer als Ehemaliger. Danach ist er einfach ein Spieler.
const JAHRE := 4

## Einen Abgang vermerken. Wird beim Transfer, bei der Leihe und bei der
## Freistellung gerufen — überall dort, wo jemand den Kader verlässt.
static func vermerken(d: Dictionary, cid: String, sid: String, art: String, wohin: String,
		abloese: float) -> void:
	if cid == "" or cid != Welt.mein_verein_id:
		return
	var sp: Dictionary = (d.get("spieler", {}) as Dictionary).get(sid, {})
	if sp.is_empty():
		return
	var v: Dictionary = (d.get("vereine", {}) as Dictionary).get(cid, {})
	if v.is_empty():
		return
	if not v.has("ehemalige"):
		v["ehemalige"] = []
	var liste: Array = v["ehemalige"]
	for e in liste:
		if str((e as Dictionary)["spieler"]) == sid:
			liste.erase(e)
			break
	liste.append({
		"spieler": sid,
		"tag": int(d.get("tag", 0)),
		"art": art,
		"wohin": wohin,
		"abloese": abloese,
		"staerke": Spielerfabrik.gesamt(sp),
		"spiele": int(sp["stats"]["karriere"]["spiele"]),
		"tore": int(sp["stats"]["karriere"]["tore"]),
	})
	while liste.size() > HOECHSTENS:
		liste.pop_front()

## Wer noch als Ehemaliger zählt, jüngster Abgang zuerst.
## [{spieler, tage, art, wohin, staerke_damals, staerke_jetzt, verein_jetzt, …}]
static func stand(d: Dictionary, cid: String) -> Array:
	var aus: Array = []
	var v: Dictionary = (d.get("vereine", {}) as Dictionary).get(cid, {})
	if v.is_empty():
		return aus
	var heute: int = int(d.get("tag", 0))
	for e in (v.get("ehemalige", []) as Array):
		var eintrag: Dictionary = e
		var sid: String = str(eintrag["spieler"])
		var sp: Dictionary = (d["spieler"] as Dictionary).get(sid, {})
		if sp.is_empty():
			continue
		if heute - int(eintrag["tag"]) > JAHRE * Kalender.TAGE_IM_JAHR:
			continue
		# Wer zurückgekauft wurde, ist kein Ehemaliger mehr.
		if str(sp.get("verein", "")) == cid:
			continue
		aus.append({
			"spieler": sid,
			"tage": heute - int(eintrag["tag"]),
			"art": str(eintrag["art"]),
			"wohin": str(eintrag["wohin"]),
			"abloese": float(eintrag["abloese"]),
			"damals": float(eintrag["staerke"]),
			"jetzt": Spielerfabrik.gesamt(sp),
			"verein": str(sp.get("verein", "")),
			"tore_seither": int(sp["stats"]["karriere"]["tore"]) - int(eintrag.get("tore", 0)),
			"spiele_seither": int(sp["stats"]["karriere"]["spiele"]) - int(eintrag.get("spiele", 0)),
		})
	aus.reverse()
	return aus

static func ist_ehemaliger(d: Dictionary, cid: String, sid: String) -> bool:
	var v: Dictionary = (d.get("vereine", {}) as Dictionary).get(cid, {})
	for e in (v.get("ehemalige", []) as Array):
		if str((e as Dictionary)["spieler"]) == sid:
			return true
	return false

## Nach einer Partie: hat ein Ehemaliger gegen uns getroffen?
##
## Das ist der Moment, für den dieser ganze Bestand da ist. Eine Zeile in der
## Presse, und der Verkauf von vor anderthalb Jahren ist wieder eine Frage.
static func partie_pruefen(d: Dictionary, m: Dictionary, cid: String) -> void:
	if cid == "" or m.is_empty():
		return
	var heim: bool = str(m["heim"]) == cid
	if not heim and str(m["gast"]) != cid:
		return
	var bericht: Dictionary = m.get("bericht", {})
	var gegner: Dictionary = bericht.get("gast" if heim else "heim", {})
	if gegner.is_empty():
		return
	for sid in (gegner.get("spieler", {}) as Dictionary).keys():
		if not ist_ehemaliger(d, cid, str(sid)):
			continue
		var e: Dictionary = gegner["spieler"][sid]
		var tore: int = int(e.get("tore", 0))
		if tore < 3:
			continue
		var sp: Dictionary = d["spieler"][str(sid)]
		Welt.nachricht({
			"typ": "medien", "wichtig": tore >= 5,
			"betreff": "%s trifft gegen seinen alten Verein" % Spielerfabrik.voller_name(sp),
			"text": "%s hat %d Tore gegen Sie geworfen. Er stand bis vor Kurzem in Ihrem Kader.\n\nSolche Abende entscheiden im Nachhinein, ob ein Verkauf richtig war." % [
				Spielerfabrik.kurz_name(sp), tore],
			"daten": {"spieler": str(sid)},
		})
