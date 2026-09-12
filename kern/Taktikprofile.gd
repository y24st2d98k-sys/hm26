class_name Taktikprofile
extends RefCounted
## Gespeicherte Taktiken und wann sie gelten.
##
## Bisher gab es eine Taktik, die man vor jedem Spiel von Hand umstellte. Gegen
## den Tabellenletzten dieselbe Deckung wie gegen den Meister zu spielen ist
## aber keine Entscheidung, sondern Vergesslichkeit. Ein Profil hält eine
## vollständige Spielidee fest — Deckung, Ausrichtung, Mentalität, Tempo,
## Risiko, Härte, Wechselintensität und den siebten Feldspieler — und kann
## automatisch gezogen werden, je nachdem, wer gegenübersteht.
##
## Gespeichert wird je Verein in `verein["taktikprofile"]` und
## `verein["taktikregeln"]`.

## Wann ein Profil automatisch gezogen wird.
const LAGEN := {
	"favorit": {"name": "Wenn wir Favorit sind", "text": "Der Gegner ist deutlich schwächer."},
	"ausgeglichen": {"name": "Auf Augenhöhe", "text": "Kein klarer Favorit."},
	"aussenseiter": {"name": "Wenn wir Außenseiter sind", "text": "Der Gegner ist deutlich stärker."},
	"derby": {"name": "Im Derby", "text": "Gegen einen Rivalen — geht allen anderen Lagen vor."},
}
const LAGEN_REIHE := ["derby", "favorit", "ausgeglichen", "aussenseiter"]

## Ab welchem Stärkeunterschied man Favorit bzw. Außenseiter ist.
const SCHWELLE := 9.0

static func profile(d: Dictionary, cid: String) -> Array:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("taktikprofile"):
		v["taktikprofile"] = []
	return v["taktikprofile"]

static func regeln(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("taktikregeln"):
		v["taktikregeln"] = {}
	return v["taktikregeln"]

static func namen(d: Dictionary, cid: String) -> Array:
	var liste: Array = []
	for p in profile(d, cid):
		liste.append(str(p["name"]))
	return liste

## Die aktuelle Spielidee unter einem Namen ablegen.
static func speichern(d: Dictionary, cid: String, name: String) -> Dictionary:
	var sauber: String = name.strip_edges()
	if sauber == "":
		return {"ok": false, "grund": "Das Profil braucht einen Namen."}
	var liste: Array = profile(d, cid)
	if liste.size() >= 6 and not namen(d, cid).has(sauber):
		return {"ok": false, "grund": "Mehr als sechs Profile werden unübersichtlich."}
	var taktik: Dictionary = (d["vereine"][cid]["taktik"] as Dictionary).duplicate(true)
	for i in range(liste.size()):
		if str((liste[i] as Dictionary)["name"]) == sauber:
			liste[i] = {"name": sauber, "taktik": taktik}
			return {"ok": true, "grund": "Profil „%s“ überschrieben." % sauber}
	liste.append({"name": sauber, "taktik": taktik})
	return {"ok": true, "grund": "Profil „%s“ gespeichert." % sauber}

static func loeschen(d: Dictionary, cid: String, name: String) -> void:
	var liste: Array = profile(d, cid)
	for i in range(liste.size() - 1, -1, -1):
		if str((liste[i] as Dictionary)["name"]) == name:
			liste.remove_at(i)
	var r := regeln(d, cid)
	for lage in r.keys():
		if str(r[lage]) == name:
			r[lage] = ""

## Ein Profil auf die laufende Taktik anwenden.
static func anwenden(d: Dictionary, cid: String, name: String) -> Dictionary:
	for p in profile(d, cid):
		if str(p["name"]) != name:
			continue
		var ziel: Dictionary = d["vereine"][cid]["taktik"]
		for k in (p["taktik"] as Dictionary).keys():
			ziel[k] = (p["taktik"] as Dictionary)[k]
		return {"ok": true, "grund": "Spielidee „%s“ übernommen." % name}
	return {"ok": false, "grund": "Dieses Profil gibt es nicht."}

static func regel_setzen(d: Dictionary, cid: String, lage: String, name: String) -> void:
	regeln(d, cid)[lage] = name

## Welche Lage gegen diesen Gegner gilt.
static func lage_gegen(d: Dictionary, cid: String, gegner: String) -> String:
	if gegner == "" or not d["vereine"].has(gegner):
		return "ausgeglichen"
	var rivale: float = float((d["vereine"][cid]["rivalen"] as Dictionary).get(gegner, 0.0))
	if rivale > 45.0:
		return "derby"
	var eigen: float = Vorstand.staerkeindex(d, cid)
	var fremd: float = Vorstand.staerkeindex(d, gegner)
	if eigen - fremd >= SCHWELLE:
		return "favorit"
	if fremd - eigen >= SCHWELLE:
		return "aussenseiter"
	return "ausgeglichen"

## Vor der Partie: das zur Lage hinterlegte Profil ziehen. Gibt den Namen des
## angewendeten Profils zurück, sonst einen leeren String.
static func automatisch_anwenden(d: Dictionary, cid: String, gegner: String) -> String:
	if not bool(d["einstellungen"].get("auto_taktik", true)):
		return ""
	var lage := lage_gegen(d, cid, gegner)
	var name: String = str(regeln(d, cid).get(lage, ""))
	if name == "":
		return ""
	if not bool(anwenden(d, cid, name)["ok"]):
		return ""
	return name

## Kurzbeschreibung einer gespeicherten Spielidee für die Oberfläche.
static func beschreibung(taktik: Dictionary) -> String:
	return "%s · %s · %s · Tempo %d, Risiko %d, Härte %d" % [
		str(taktik.get("abwehr", "6-0")),
		str(taktik.get("angriff", "positionsangriff")).capitalize(),
		str(taktik.get("mentalitaet", "ausgeglichen")).capitalize(),
		int(taktik.get("tempo", 50)), int(taktik.get("risiko", 45)), int(taktik.get("haerte", 45))]
