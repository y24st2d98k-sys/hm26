extends Node
## Kippt die Liga, wenn einer gut arbeitet?
##
## Seit die Trainingsarbeit wirklich etwas ändert, stellt sich die
## Gegenfrage: entwickelt ein Mensch, der sich kümmert, seinen Kader so viel
## schneller als die Konkurrenz, dass er die Liga nach ein paar Spielzeiten
## nicht mehr verlässt? Ein Managerspiel soll Können belohnen — aber es soll
## eine Liga bleiben und kein Selbstläufer.
##
## Gemessen wird über fünf Spielzeiten: Platz, Punkte und der Abstand der
## eigenen Kaderstärke zum Ligaschnitt.
##
## Wichtig beim Lesen: diese Sonde führt einen Verein *nur* über das Training.
## Verträge werden nicht verlängert, Abgänge nicht ersetzt, es wird nicht
## transferiert — für den Verein des Menschen tut die KI all das bewusst
## nicht. Ein Kader, den niemand pflegt, blutet über drei Spielzeiten aus, und
## der Trainer fliegt. Das ist kein Fehler der Messung, es ist ihre Grenze:
## Sie beantwortet die Frage "kippt die Liga durch gute Trainingsarbeit?" und
## nicht die Frage "reicht gute Trainingsarbeit?".

const SAAT := 4242
const SPIELZEITEN := 5

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var vorschau := Weltgenerator.erzeuge(2026, SAAT)
	# Bewusst kein Spitzenverein: bei Magdeburg wäre jeder Titel auch ohne
	# gute Arbeit zu erwarten. Der Test fragt, ob Arbeit die Rangordnung
	# umwirft, nicht ob sie sie bestätigt.
	var liste: Array = vorschau["ligen"]["l_de1"]["vereine"]
	var cid: String = str(liste[liste.size() - 4])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Lang", "nachname": "Zeit"}, SAAT)
	var d: Dictionary = Welt.daten
	_log("")
	_log("=== Fünf Spielzeiten mit guter Arbeit: %s ===" % str(d["vereine"][cid]["name"]))
	_log("")
	var p: Dictionary = Training.plan(d, cid)
	p["intensitaet"] = 62
	p["schwerpunkt"] = "ausgeglichen"

	_log("%-8s %6s %7s %8s %10s %12s" % ["Saison", "Platz", "Punkte", "Kader Ø", "Ligaschnitt", "Abstand"])
	var saison := 0
	var tage := 0
	while saison < SPIELZEITEN and tage < SPIELZEITEN * 380:
		_pflegen(d, cid)
		var u := Welt.tag_weiter()
		tage += 1
		if u.has("art"):
			match str(u["art"]):
				"eigenes_spiel":
					Welt.partie_simulieren(str(u["spiel"]))
					Welt.spieltag_abwickeln(Welt.tag())
					Welt.wochenrhythmus(Welt.tag())
					Welt.saison_pruefen(Welt.tag())
				"saisonende":
					_bericht(d, cid, saison)
					saison += 1
		if Welt.mein_verein_id == "":
			_log("   Verein verloren nach %d Tagen." % tage)
			break
	_log("")
	_log("Ein Abstand, der von Saison zu Saison wächst, heißt: die Liga kippt.")
	get_tree().quit()

## Die Arbeit, die ein guter Trainer jede Woche tut.
func _pflegen(d: Dictionary, cid: String) -> void:
	if not (d.get("vereine", {}) as Dictionary).has(cid):
		return
	var p: Dictionary = Training.plan(d, cid)
	var budget: int = Training.regenerationsbudget(d, cid)
	var kader: Array = (d["vereine"][cid]["kader"] as Array).duplicate()
	kader.sort_custom(func(a, b): return float(d["spieler"][str(a)]["last"]) > float(d["spieler"][str(b)]["last"]))
	var zuteilung := {}
	for i in range(mini(budget, kader.size())):
		if float(d["spieler"][str(kader[i])]["last"]) > 40.0:
			zuteilung[str(kader[i])] = 1
	p["regeneration_zuteilung"] = zuteilung
	for sid in kader:
		var sp: Dictionary = d["spieler"][str(sid)]
		if int(sp["alter"]) <= 23:
			sp["trainingsfokus"] = "athletik" if int(sp["alter"]) <= 20 else "wurf"

func _bericht(d: Dictionary, cid: String, saison: int) -> void:
	var lid: String = str(d["vereine"][cid]["liga"])
	var tabelle: Array = Spielplan.tabelle_sortiert(d, lid)
	var platz: int = tabelle.find(cid) + 1
	var zeile: Dictionary = (d["ligen"][lid]["tabelle"] as Dictionary).get(cid,
		Spielplan.leere_tabellenzeile())
	var eigen: float = _staerke(d, cid)
	var summe := 0.0
	var anzahl := 0
	for c in tabelle:
		summe += _staerke(d, str(c))
		anzahl += 1
	var schnitt: float = summe / maxf(float(anzahl), 1.0)
	_log("%-8d %6d %7d %8.1f %10.1f %12.1f" % [saison + 1, platz, int(zeile["punkte"]),
		eigen, schnitt, eigen - schnitt])

func _staerke(d: Dictionary, cid: String) -> float:
	var v: Dictionary = (d.get("vereine", {}) as Dictionary).get(cid, {})
	if v.is_empty():
		return 0.0
	var beste: Array = []
	for sid in (v.get("kader", []) as Array):
		beste.append(Spielerfabrik.gesamt(d["spieler"][str(sid)]))
	beste.sort()
	beste.reverse()
	var summe := 0.0
	var k: int = mini(8, beste.size())
	for i in k:
		summe += float(beste[i])
	return summe / maxf(float(k), 1.0)
