class_name Vorbereitung
extends RefCounted
## Eigene Vorbereitungsspiele ansetzen.
##
## Bis hierher war die Sommervorbereitung etwas, das einem widerfuhr: das Spiel
## setzte fünf Testspiele für jeden Verein an, und der Trainer sah zu. Wer nach
## dem Trainingslager noch einen harten Gegner wollte oder vor dem Auftakt
## lieber einen leichten, konnte nichts tun.
##
## Jetzt sucht man sich Gegner und Termin selbst. Der Preis steht dabei
## ausdrücklich da: ein großer Name kommt nicht umsonst, und ein Heimspiel
## bringt Eintritt, ein Auswärtsspiel kostet die Reise.
##
## Das Fenster liegt in der Sommervorbereitung — dort, wo auch das
## Trainingslager liegt, und beides schließt sich gegenseitig aus: an einem
## Tag im Lager wird nicht getestet.

## Erster und letzter Tag in der Saison, an dem ein Testspiel möglich ist.
## Davor läuft noch der Urlaub, danach beginnt die Runde.
const FENSTER_VON := 6
const FENSTER_BIS := 43

## Wie viele Vorbereitungsspiele ein Verein insgesamt haben darf — selbst
## angesetzte und vom Verband gesetzte zusammen. Mehr wäre keine Vorbereitung
## mehr, sondern eine zweite Saison.
const HOECHSTZAHL := 7

## Wie viele Tage zwischen zwei Partien mindestens liegen müssen.
const ABSTAND := 2

static func fenster_offen(d: Dictionary) -> bool:
	var tis: int = Kalender.tag_in_saison(int(d["tag"]))
	return tis >= 0 and tis <= FENSTER_BIS

## Alle Tage, an denen sich noch etwas ansetzen lässt.
static func freie_termine(d: Dictionary, cid: String) -> Array:
	var aus: Array = []
	var saisonbasis: int = int(d["tag"]) - Kalender.tag_in_saison(int(d["tag"]))
	for tis in range(FENSTER_VON, FENSTER_BIS + 1):
		var tag: int = saisonbasis + tis
		if tag <= int(d["tag"]):
			continue
		if _grund_dagegen(d, cid, tag) != "":
			continue
		aus.append(tag)
	return aus

## Warum an diesem Tag nichts geht. Leerer String heisst: er geht.
static func _grund_dagegen(d: Dictionary, cid: String, tag: int) -> String:
	var lager: Dictionary = Trainingslager.laufend(d, cid)
	if not lager.is_empty() and tag >= int(lager["beginn"]) and tag <= int(lager["bis"]):
		return "Trainingslager"
	for abstand in range(-ABSTAND, ABSTAND + 1):
		if _hat_spiel(d, cid, tag + abstand):
			return "zu dicht an einer anderen Partie" if abstand != 0 else "schon eine Partie"
	return ""

static func _hat_spiel(d: Dictionary, cid: String, tag: int) -> bool:
	for mid in (d.get("plan", {}) as Dictionary).get(tag, []):
		var m: Dictionary = d["spiele"].get(mid, {})
		if m.is_empty():
			continue
		if str(m["heim"]) == cid or str(m["gast"]) == cid:
			return true
	return false

## Alle Vorbereitungsspiele eines Vereins in dieser Saison, nach Termin.
static func partien(d: Dictionary, cid: String) -> Array:
	var aus: Array = []
	var saisonbasis: int = int(d["tag"]) - Kalender.tag_in_saison(int(d["tag"]))
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) != "test":
			continue
		if str(m["heim"]) != cid and str(m["gast"]) != cid:
			continue
		if int(m["tag"]) < saisonbasis or int(m["tag"]) > saisonbasis + FENSTER_BIS + 4:
			continue
		aus.append(mid)
	aus.sort_custom(func(a, b): return int(d["spiele"][a]["tag"]) < int(d["spiele"][b]["tag"]))
	return aus

## Wen man an diesem Tag fragen kann. Liefert je Gegner die Antragsgebühr und
## eine Einschätzung, damit nicht erst das Angebot zeigt, was es kostet.
static func moegliche_gegner(d: Dictionary, cid: String, tag: int) -> Array:
	var aus: Array = []
	if _grund_dagegen(d, cid, tag) != "":
		return aus
	var eigen: Dictionary = d["vereine"][cid]
	for kandidat in Weltgenerator.clubs(d):
		if str(kandidat) == cid:
			continue
		if _hat_spiel(d, str(kandidat), tag):
			continue
		var g: Dictionary = d["vereine"][kandidat]
		aus.append({
			"cid": str(kandidat),
			"name": str(g["name"]),
			"ruf": float(g["ruf"]),
			"liga": str(d["ligen"].get(str(g["liga"]), {}).get("name", "")),
			"gebuehr": antrittsgeld(d, cid, str(kandidat)),
		})
	aus.sort_custom(func(a, b): return float(a["ruf"]) > float(b["ruf"]))
	return aus

## Was der Gegner fürs Kommen verlangt.
##
## Wer deutlich größer ist als man selbst, lässt sich das bezahlen; wer
## kleiner ist, freut sich über den Besuch und verlangt nichts. Die Zahl hängt
## am Ruf-Unterschied, nicht am eigenen Etat — sonst würde derselbe Gegner für
## einen reichen Verein plötzlich teurer, und das wäre keine Gebühr, sondern
## eine Steuer.
static func antrittsgeld(d: Dictionary, cid: String, gegner: String) -> float:
	var eigen: float = float(d["vereine"][cid]["ruf"])
	var fremd: float = float(d["vereine"][gegner]["ruf"])
	var unterschied: float = fremd - eigen
	if unterschied <= 0.0:
		return 0.0
	return pow(unterschied, 1.65) * 620.0

## Setzt ein Vorbereitungsspiel an.
static func ansetzen(d: Dictionary, cid: String, gegner: String, tag: int, daheim: bool) -> Dictionary:
	if not fenster_offen(d):
		return {"ok": false, "grund": "Die Vorbereitung ist vorbei — jetzt zählt jede Partie."}
	if not d["vereine"].has(gegner) or gegner == cid:
		return {"ok": false, "grund": "Diesen Gegner gibt es nicht."}
	var tis: int = tag - (int(d["tag"]) - Kalender.tag_in_saison(int(d["tag"])))
	if tis < FENSTER_VON or tis > FENSTER_BIS:
		return {"ok": false, "grund": "Dieser Termin liegt außerhalb der Vorbereitung."}
	if tag <= int(d["tag"]):
		return {"ok": false, "grund": "Dieser Termin liegt nicht mehr in der Zukunft."}
	var grund: String = _grund_dagegen(d, cid, tag)
	if grund != "":
		return {"ok": false, "grund": "An diesem Tag geht nichts: %s." % grund}
	if _hat_spiel(d, gegner, tag):
		return {"ok": false, "grund": "%s spielt an diesem Tag bereits." % str(d["vereine"][gegner]["name"])}
	if partien(d, cid).size() >= HOECHSTZAHL:
		return {"ok": false, "grund": "Mehr als %d Vorbereitungsspiele macht keine Mannschaft mit." % HOECHSTZAHL}
	var gebuehr := antrittsgeld(d, cid, gegner)
	if gebuehr > 0.0 and float(d["vereine"][cid]["kasse"]) < gebuehr:
		return {"ok": false, "grund": "%s verlangt %s Antrittsgeld — so viel ist nicht in der Kasse." % [
			str(d["vereine"][gegner]["name"]), Stil.geld(gebuehr)]}
	if gebuehr > 0.0:
		Finanzen.buchen(d, cid, -gebuehr, "Antrittsgeld %s" % str(d["vereine"][gegner]["name"]), "betrieb")
		Finanzen.buchen(d, gegner, gebuehr, "Antrittsgeld %s" % str(d["vereine"][cid]["name"]), "betrieb")
	var heim: String = cid if daheim else gegner
	var gast: String = gegner if daheim else cid
	Spielplan.neues_spiel(d, "test_" + str(d["vereine"][cid]["nation"]), "test",
		partien(d, cid).size() + 1, tag, heim, gast, {"selbst_angesetzt": true})
	return {"ok": true, "grund": "%s am %s%s." % [
		("Heimspiel gegen %s" % str(d["vereine"][gegner]["name"])) if daheim
			else ("Auswärtsspiel bei %s" % str(d["vereine"][gegner]["name"])),
		Kalender.text(tag, Welt.startjahr()),
		"" if gebuehr <= 0.0 else " Antrittsgeld %s gezahlt." % Stil.geld(gebuehr)]}

## Sagt ein noch nicht gespieltes Vorbereitungsspiel ab.
static func absagen(d: Dictionary, cid: String, mid: String) -> Dictionary:
	var m: Dictionary = d["spiele"].get(mid, {})
	if m.is_empty() or str(m["art"]) != "test":
		return {"ok": false, "grund": "Diese Partie gibt es nicht."}
	if bool(m["gespielt"]):
		return {"ok": false, "grund": "Die Partie ist bereits gespielt."}
	if str(m["heim"]) != cid and str(m["gast"]) != cid:
		return {"ok": false, "grund": "Das ist nicht Ihre Partie."}
	if int(m["tag"]) <= int(d["tag"]):
		return {"ok": false, "grund": "So kurzfristig sagt man nicht ab."}
	var gegner: String = str(m["gast"]) if str(m["heim"]) == cid else str(m["heim"])
	# Ein Antrittsgeld ist weg. Wer zusagt und wieder absagt, zahlt dafuer —
	# sonst waere das Ansetzen kostenlos und man koennte sich durchprobieren.
	(d["plan"][int(m["tag"])] as Array).erase(mid)
	d["spiele"].erase(mid)
	return {"ok": true, "grund": "Die Partie gegen %s ist abgesagt. Ein gezahltes Antrittsgeld gibt es nicht zurück." % [
		str(d["vereine"][gegner]["name"])]}
