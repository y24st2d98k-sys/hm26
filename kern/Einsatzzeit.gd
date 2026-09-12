class_name Einsatzzeit
extends RefCounted
## Zielminuten je Spieler.
##
## Rotation nach Kraftstand allein reicht nicht. Wer ein Talent aufbauen will,
## bekommt es so nie aufs Feld: solange der Stammspieler bei 70 Prozent Kraft
## steht, wechselt niemand. Ein Minutenziel dreht die Frage um — nicht "wer ist
## müde?", sondern "wer hat sein Pensum noch nicht?". Damit wird Spielzeit zu
## dem, was sie in einer echten Saison ist: eine Planung, kein Zufall.
##
## Gespeichert wird je Verein in `aufstellung["minuten"][sid]` als Minuten pro
## Spiel. 0 heißt "kein Ziel" — dann entscheidet allein die Kraft, also genau
## das Verhalten von vorher. Ziele sind also immer eine bewusste Ansage.

## Ein Handballspiel dauert 60 Minuten.
const SPIELDAUER := 60.0

## Wie viel Spielzeit eine Vertragsrolle erwarten lässt. Das ist der
## Vorschlag, kein Zwang — aber wer einen Leistungsträger auf 15 Minuten
## setzt, wird das in der Kabine zu hören bekommen.
const VORGABEN := {
	"leistungstraeger": 52.0,
	"stammspieler": 42.0,
	"rotation": 26.0,
	"ergaenzung": 12.0,
	"talent": 16.0,
}

## Sieben Feldpositionen mal sechzig Minuten — mehr Spielzeit gibt es nicht
## zu verteilen.
const GESAMTMINUTEN := 7.0 * SPIELDAUER

static func _tabelle(d: Dictionary, cid: String) -> Dictionary:
	var auf: Dictionary = d["vereine"][cid]["aufstellung"]
	if not auf.has("minuten"):
		auf["minuten"] = {}
	return auf["minuten"]

## Zielminuten eines Spielers. 0 heißt: keine Vorgabe.
static func ziel(d: Dictionary, cid: String, sid: String) -> float:
	var auf: Dictionary = d["vereine"][cid].get("aufstellung", {})
	return float((auf.get("minuten", {}) as Dictionary).get(sid, 0.0))

static func setzen(d: Dictionary, cid: String, sid: String, minuten: float) -> void:
	var tab := _tabelle(d, cid)
	var wert: float = clampf(minuten, 0.0, SPIELDAUER)
	if wert < 1.0:
		tab.erase(sid)
	else:
		tab[sid] = wert

static func loeschen(d: Dictionary, cid: String) -> void:
	_tabelle(d, cid).clear()

## Was die Vertragsrolle erwarten lässt.
static func vorschlag(sp: Dictionary) -> float:
	var rolle: String = str((sp.get("vertrag", {}) as Dictionary).get("rolle", "rotation"))
	return float(VORGABEN.get(rolle, 22.0))

## Alle Ziele aus den Vertragsrollen ableiten. Torhüter bleiben aussen vor —
## dort entscheidet nicht das Pensum, sondern wer den Tag hat.
##
## Die Rollenwerte allein ergeben mehr Minuten, als ein Spiel hergibt: sechzehn
## Feldspieler mit ihrem jeweiligen Anspruch kommen auf weit über 360. Deshalb
## wird am Ende auf das Machbare heruntergerechnet — sonst wäre der Knopf eine
## Vorgabe, die von vornherein nicht zu halten ist.
static func aus_vertraegen(d: Dictionary, cid: String) -> void:
	var tab := _tabelle(d, cid)
	tab.clear()
	var summe := 0.0
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp["ist_torwart"]):
			continue
		var wunsch: float = vorschlag(sp)
		tab[sid] = wunsch
		summe += wunsch
	var machbar: float = 6.0 * SPIELDAUER
	if summe <= machbar or summe <= 0.0:
		return
	var faktor: float = machbar / summe
	for sid2 in tab.keys():
		tab[sid2] = roundf(float(tab[sid2]) * faktor / 2.0) * 2.0

## Summe aller vergebenen Zielminuten und wie sie zum Machbaren steht.
static func bilanz(d: Dictionary, cid: String) -> Dictionary:
	var tab: Dictionary = (d["vereine"][cid].get("aufstellung", {}) as Dictionary).get("minuten", {})
	var summe := 0.0
	var anzahl := 0
	for sid in tab.keys():
		if not d["spieler"].has(sid):
			continue
		summe += float(tab[sid])
		anzahl += 1
	# Ein Torwart steht die vollen sechzig Minuten und zählt nicht mit in die
	# sechs Feldpositionen, die zu verteilen sind.
	var machbar: float = 6.0 * SPIELDAUER
	return {
		"summe": summe,
		"anzahl": anzahl,
		"machbar": machbar,
		"auslastung": summe / machbar,
		"passt": absf(summe - machbar) <= machbar * 0.12,
	}

## Wie gut das Pensum in dieser Saison bisher eingehalten wurde.
static func erfuellung(d: Dictionary, cid: String, sid: String) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var soll: float = ziel(d, cid, sid)
	var spiele: int = int(sp["stats"]["saison"]["spiele"])
	if soll <= 0.0 or spiele <= 0:
		return {"soll": soll, "ist": 0.0, "spiele": spiele, "gilt": false, "abweichung": 0.0}
	var ist: float = float(sp["stats"]["saison"]["minuten"]) / float(spiele)
	return {
		"soll": soll, "ist": ist, "spiele": spiele, "gilt": true,
		"abweichung": ist - soll,
	}

## Klartext zur Erfüllung — was ein Spieler dazu sagen würde.
static func erfuellungstext(e: Dictionary) -> String:
	if not bool(e["gilt"]):
		return "kein Ziel gesetzt"
	var ab: float = float(e["abweichung"])
	if ab >= 6.0:
		return "deutlich über Plan"
	if ab >= 2.0:
		return "über Plan"
	if ab > -2.0:
		return "im Plan"
	if ab > -6.0:
		return "unter Plan"
	return "deutlich unter Plan"

## Spieler entfernen, wenn er den Verein verlässt.
static func spieler_entfernen(d: Dictionary, sid: String) -> void:
	for cid in d["vereine"].keys():
		var auf: Dictionary = (d["vereine"][cid] as Dictionary).get("aufstellung", {})
		var tab: Dictionary = auf.get("minuten", {})
		if not tab.is_empty():
			tab.erase(sid)
