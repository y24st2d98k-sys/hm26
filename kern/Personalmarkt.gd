class_name Personalmarkt
extends RefCounted
## Wer sich gerade bei diesem Verein bewirbt.
##
## Bis hierher erzeugte der Personalbildschirm die Bewerber bei jedem Druck
## auf "Bewerber sichten" neu — mit Weltgenerator.erzeuge_mitarbeiter(), und
## die schreibt jeden Erzeugten dauerhaft nach d["personal"]. Zweimal
## gedrückt hiess: acht Leute im Spielstand, von denen sechs niemand mehr
## sieht. Gemessen mit werkzeuge/Personalsonde.gd.
##
## Der zweite Schaden wiegt schwerer als der erste. Wer oft genug drückte,
## bekam irgendwann den perfekten Torwarttrainer — ohne Zeit, ohne Kosten,
## ohne Risiko. Das ist kein Arbeitsmarkt, sondern ein Würfelbecher, und es
## entwertet jede Personalentscheidung: warum den Zweitbesten nehmen, wenn
## der Beste nur ein paar Klicks entfernt ist?
##
## Also steht die Bewerberliste jetzt in der Welt, gilt zwei Wochen und wird
## beim Wechsel aufgeräumt. Wer heute niemanden findet, findet heute
## niemanden.

## Wie lange dieselben Leute sich bewerben.
const GUELTIG_TAGE := 14
## Wie viele es sind.
const BEWERBER := 4

static func _markt(d: Dictionary) -> Dictionary:
	if not d.has("personalmarkt"):
		d["personalmarkt"] = {}
	return d["personalmarkt"]

## Die aktuelle Bewerberliste für eine Rolle. Erzeugt sie, wenn sie fehlt
## oder abgelaufen ist — und räumt die vorige dabei ab.
static func bewerber(d: Dictionary, cid: String, rolle: String) -> Array:
	var markt := _markt(d)
	var eintrag: Dictionary = markt.get(rolle, {})
	var heute: int = int(d.get("tag", 0))
	if not eintrag.is_empty() and heute - int(eintrag.get("tag", -999)) < GUELTIG_TAGE:
		# Ein Bewerber, der inzwischen woanders unterschrieben hat, steht
		# nicht mehr zur Verfügung.
		var gueltig: Array = []
		for pid in (eintrag.get("liste", []) as Array):
			var p: Dictionary = (d["personal"] as Dictionary).get(str(pid), {})
			if not p.is_empty() and str(p.get("verein", "")) == "":
				gueltig.append(str(pid))
		eintrag["liste"] = gueltig
		return gueltig.duplicate()

	_aufraeumen(d, eintrag)
	var v: Dictionary = (d["vereine"] as Dictionary).get(cid, {})
	var ruf: float = float(v.get("ruf", 50.0))
	var liste: Array = []
	for _i in range(BEWERBER):
		var pid := Weltgenerator.erzeuge_mitarbeiter(d, rolle,
			clampf(ruf + Namen.bereich(-18.0, 14.0), 10.0, 99.0), str(v.get("nation", "de")))
		liste.append(pid)
	markt[rolle] = {"tag": heute, "liste": liste}
	return liste.duplicate()

## Wie viele Tage die Liste noch steht.
static func rest_tage(d: Dictionary, rolle: String) -> int:
	var eintrag: Dictionary = _markt(d).get(rolle, {})
	if eintrag.is_empty():
		return 0
	return maxi(GUELTIG_TAGE - (int(d.get("tag", 0)) - int(eintrag.get("tag", 0))), 0)

## Wer sich beworben hatte und nicht genommen wurde, verschwindet wieder.
## Nur wer nirgends unterschrieben hat — ein verpflichteter Bewerber gehört
## längst einem Verein und bleibt.
static func _aufraeumen(d: Dictionary, eintrag: Dictionary) -> void:
	for pid in (eintrag.get("liste", []) as Array):
		var p: Dictionary = (d["personal"] as Dictionary).get(str(pid), {})
		if not p.is_empty() and str(p.get("verein", "")) == "":
			(d["personal"] as Dictionary).erase(str(pid))
