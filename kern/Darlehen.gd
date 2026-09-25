class_name Darlehen
extends RefCounted
## Kredite: Geld, das man noch nicht hat.
##
## Bisher war die Kasse eine Wand — was nicht drin war, ging nicht. Ein Verein,
## der eine Halle ausbauen oder einen Transfer vorfinanzieren will, geht aber
## zur Bank. Damit wird aus "kann ich mir das leisten?" die interessantere
## Frage: "kann ich mir das leisten, wenn ich zwei Jahre lang dafür zahle?"
##
## Ein Darlehen bringt sofort Geld und kostet danach jede Woche — unabhängig
## davon, ob die Saison läuft oder nicht. Der Vorstand genehmigt nur, was zum
## Verein passt, und merkt sich, wer sich verhebt.
##
## Gespeichert je Verein in `verein["darlehen"]` als Liste.

## Laufzeiten, die die Bank anbietet — in Saisons.
const LAUFZEITEN := [1, 2, 3, 5]

## Wochen je Saison, über die abbezahlt wird.
const WOCHEN_JE_SAISON := 52

## Höchstverschuldung, gemessen am Jahresetat.
const SCHULDENDECKEL := 0.85
## Bis zu welcher Restschuld (Anteil des Jahresetats) die KI noch einmal
## nachfasst. Darueber hilft kein Darlehen mehr, sondern nur der Verkauf.
const ZWEITDARLEHEN_DECKEL := 0.55

static func liste(d: Dictionary, cid: String) -> Array:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("darlehen"):
		v["darlehen"] = []
	return v["darlehen"]

static func restschuld(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	for k in liste(d, cid):
		summe += float((k as Dictionary)["rest"])
	return summe

static func wochenlast(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	for k in liste(d, cid):
		summe += float((k as Dictionary)["rate"])
	return summe

## Zinssatz je Jahr. Wer Ansehen hat und wenig schuldet, zahlt weniger —
## und wer schon tief drin steckt, zahlt für jeden weiteren Euro drauf.
static func zinssatz(d: Dictionary, cid: String, betrag: float, laufzeit: int) -> float:
	var v: Dictionary = d["vereine"][cid]
	var basis: float = 0.085 - clampf(float(v["ruf"]) / 100.0, 0.0, 1.0) * 0.035
	var etat: float = maxf(float(v["jahresetat"]), 50000.0)
	var last: float = clampf((restschuld(d, cid) + betrag) / etat, 0.0, 1.5)
	basis += last * 0.055
	basis += float(laufzeit) * 0.004
	if float(v["kasse"]) < 0.0:
		basis += 0.02
	return clampf(basis, 0.028, 0.185)

## Was die Bank höchstens gibt.
static func hoechstbetrag(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var deckel: float = float(v["jahresetat"]) * SCHULDENDECKEL
	return maxf(deckel - restschuld(d, cid), 0.0)

## Wochenrate eines gedachten Darlehens — für die Vorschau im Bildschirm.
static func rate(betrag: float, zins: float, laufzeit: int) -> float:
	var wochen: float = float(maxi(laufzeit, 1) * WOCHEN_JE_SAISON)
	# Einfache Verzinsung über die Laufzeit, gleichmäßig auf die Wochen
	# verteilt. Ein Tilgungsplan mit Restschuldverzinsung wäre genauer und für
	# die Entscheidung, um die es hier geht, kein Stück nützlicher.
	return betrag * (1.0 + zins * float(maxi(laufzeit, 1))) / wochen

static func gesamtkosten(betrag: float, zins: float, laufzeit: int) -> float:
	return betrag * zins * float(maxi(laufzeit, 1))

## Prüft, ob dieses Darlehen zustande käme, ohne es aufzunehmen.
static func pruefen(d: Dictionary, cid: String, betrag: float, laufzeit: int) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if betrag < 25000.0:
		return {"ok": false, "grund": "Unter 25.000 € macht die Bank keinen Vertrag."}
	var moeglich: float = hoechstbetrag(d, cid)
	if betrag > moeglich:
		return {"ok": false, "grund": "Die Bank gibt Ihnen höchstens %s. Bestehende Kredite zählen dagegen." % Stil.geld(moeglich)}
	if liste(d, cid).size() >= 3:
		return {"ok": false, "grund": "Drei laufende Darlehen sind das Äußerste."}
	var zins: float = zinssatz(d, cid, betrag, laufzeit)
	var neue_rate: float = rate(betrag, zins, laufzeit) + wochenlast(d, cid)
	# Der Vorstand rechnet nach: eine Rate, die den Wochenetat auffrisst,
	# unterschreibt er nicht.
	var wochenetat: float = float(v["jahresetat"]) / 52.0
	if neue_rate > wochenetat * 0.22:
		return {"ok": false, "grund": "Der Vorstand lehnt ab: %s je Woche sind mehr als ein Fünftel des Wochenetats." % Stil.geld(neue_rate)}
	if float(v["vorstand"]["vertrauen"]) < 30.0:
		return {"ok": false, "grund": "Der Vorstand vertraut Ihnen derzeit keine Schulden an."}
	return {"ok": true, "grund": "Die Bank würde zu %.1f %% Zinsen abschließen." % (zins * 100.0), "zins": zins}

## Darlehen aufnehmen. Das Geld ist sofort da, die Rate ab der nächsten Woche.
static func aufnehmen(d: Dictionary, cid: String, betrag: float, laufzeit: int, zweck: String = "") -> Dictionary:
	var geprueft := pruefen(d, cid, betrag, laufzeit)
	if not bool(geprueft["ok"]):
		return geprueft
	var zins: float = float(geprueft["zins"])
	var r: float = rate(betrag, zins, laufzeit)
	var wochen: int = maxi(laufzeit, 1) * WOCHEN_JE_SAISON
	liste(d, cid).append({
		"betrag": betrag,
		"rest": r * float(wochen),
		"rate": r,
		"zins": zins,
		"laufzeit": laufzeit,
		"wochen_offen": wochen,
		"aufgenommen_tag": int(d["tag"]),
		"zweck": zweck if zweck != "" else "Allgemeine Finanzierung",
	})
	Finanzen.buchen(d, cid, betrag, "Darlehen aufgenommen", "darlehen")
	# Ein Kredit ist ein Vertrauensvorschuss, kein Erfolg.
	var vorstand: Dictionary = d["vereine"][cid]["vorstand"]
	vorstand["vertrauen"] = clampf(float(vorstand["vertrauen"]) - 1.5, 0.0, 100.0)
	return {"ok": true, "grund": "%s ausgezahlt. Wochenrate %s über %d Saison(s)." % [
		Stil.geld(betrag), Stil.geld(r), laufzeit]}

## Vorzeitig ablösen — spart die restlichen Zinsen nicht ganz, aber die Sorge.
static func abloesen(d: Dictionary, cid: String, index: int) -> Dictionary:
	var l := liste(d, cid)
	if index < 0 or index >= l.size():
		return {"ok": false, "grund": "Dieses Darlehen gibt es nicht."}
	var k: Dictionary = l[index]
	# Vorfälligkeit: die Bank verzichtet auf die Hälfte der offenen Zinsen.
	var offen: float = float(k["rest"])
	var zinsanteil: float = offen - offen / (1.0 + float(k["zins"]) * float(k["laufzeit"]))
	var summe: float = offen - zinsanteil * 0.5
	var v: Dictionary = d["vereine"][cid]
	if float(v["kasse"]) < summe:
		return {"ok": false, "grund": "Für die Ablösung fehlen %s." % Stil.geld(summe - float(v["kasse"]))}
	Finanzen.buchen(d, cid, -summe, "Darlehen abgelöst", "darlehen")
	l.remove_at(index)
	return {"ok": true, "grund": "Darlehen für %s abgelöst." % Stil.geld(summe)}

## Wöchentliche Rate. Wer nicht zahlen kann, zahlt trotzdem — und der Vorstand
## sieht es.
static func wochenwechsel(d: Dictionary, cid: String) -> void:
	var l := liste(d, cid)
	if l.is_empty():
		return
	var v: Dictionary = d["vereine"][cid]
	var summe := 0.0
	for i in range(l.size() - 1, -1, -1):
		var k: Dictionary = l[i]
		var r: float = minf(float(k["rate"]), float(k["rest"]))
		summe += r
		k["rest"] = float(k["rest"]) - r
		k["wochen_offen"] = maxi(int(k["wochen_offen"]) - 1, 0)
		if float(k["rest"]) <= 0.5:
			l.remove_at(i)
			if cid == Welt.mein_verein_id:
				Welt.nachricht({
					"typ": "finanzen", "betreff": "Darlehen abbezahlt",
					"text": "Das Darlehen über %s (%s) ist getilgt. Die Wochenrate entfällt." % [
						Stil.geld(float(k["betrag"])), str(k["zweck"])],
				})
	if summe > 0.0:
		Finanzen.buchen(d, cid, -summe, "Kreditrate", "darlehen")
	# Wer die Rate nur noch aus dem Minus bedient, verliert Rückhalt.
	if float(v["kasse"]) < -summe * 4.0:
		v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) - 0.35, 0.0, 100.0)

## Die KI nimmt nur auf, was sie für einen Hallenausbau wirklich braucht.
static func ki_pruefen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if not (v["halle"]["bauprojekt"] as Dictionary).is_empty():
		return
	if float(v["kasse"]) > 0.0:
		return
	# Ein zweites Darlehen ist erlaubt, solange die Bank Luft laesst.
	#
	# Hier stand ein hartes "wer schon eines hat, bekommt keines mehr". Wer
	# einmal ueberbrueckt hatte und danach weiter blutete, konnte gar nichts
	# mehr tun: keine zweite Rate, kein Verkauf, nichts. Gemessen mit
	# werkzeuge/Wirtschaftssonde.gd standen Vereine dadurch jahrelang bei zwei
	# bis drei Millionen im Minus, und die Prüfung meldete sie als pleite.
	# Der Schuldendeckel in hoechstbetrag zieht die Grenze, nicht die Anzahl.
	if restschuld(d, cid) > float(v["jahresetat"]) * ZWEITDARLEHEN_DECKEL:
		return
	var bedarf: float = minf(absf(float(v["kasse"])) * 1.6 + 60000.0, hoechstbetrag(d, cid))
	if bedarf < 25000.0:
		return
	aufnehmen(d, cid, roundf(bedarf / 5000.0) * 5000.0, 3, "Liquiditätsüberbrückung")
