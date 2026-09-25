class_name Sponsoren
extends RefCounted
## Der Sponsorenmarkt.
##
## Sponsoring ist im Hallenhandball die wichtigste Einnahmequelle — vor
## Zuschauern, Medien und Merchandising. Verträge laufen aus und müssen neu
## verhandelt werden; was ein Verein dabei aufruft, hängt an Ansehen, Liga,
## Fanzufriedenheit und den Titeln der letzten Jahre. Wer aufsteigt und
## Erfolg hat, verdient anschließend deutlich mehr; wer abstürzt, verliert
## seine Partner an die Konkurrenz.
##
## Gespeichert wird je Verein in `verein["sponsoren"]` (laufende Verträge) und
## `verein["sponsorangebote"]` (offene Angebote, die der Trainer annehmen kann).

## Die fünf Plätze und ihr Anteil am gesamten Sponsorenvolumen.
const PLAETZE := {
	"Trikotbrust": 0.40,
	"Hallenname": 0.22,
	"Ausrüster": 0.15,
	"Ärmel": 0.13,
	"Rückenpartner": 0.10,
}
const REIHENFOLGE := ["Trikotbrust", "Hallenname", "Ausrüster", "Ärmel", "Rückenpartner"]

## Was ein Sitzplatz im Jahr an Sponsorengeld wert ist.
##
## Hier stand ein Anteil des Jahresetats (0,52), und das war im Kreis gerechnet:
## seit Finanzen.saison_budgets den Etat am Umsatz des Vorjahres bemisst, und
## der Umsatz zu einem Drittel aus Sponsoring besteht, senkte jeder Sparzwang
## auch die Einnahmen. Gemessen mit werkzeuge/Wirtschaftssonde.gd fiel das
## Sponsoring dadurch auf 32 Prozent des Ertrags, während die Zuschauer auf 44
## stiegen — in der Bundesliga ist es umgekehrt, dort ist Sponsoring die größte
## Säule.
##
## Ein Sponsor kauft keine Bilanz, er kauft eine Bühne: eine gefüllte Halle,
## den Namen des Vereins, das Ansehen der Liga, Titel. Genau daran bemisst es
## sich jetzt — und der Etat kommt darin nicht mehr vor.
## Der erste Wert (570) war geschaetzt und zu hoch: gemessen kamen 6,76 Mio.
## Sponsoring je Verein heraus, angepeilt waren 4,3.
##
## Vor allem war er allein: nur die Halle zu zaehlen hat die kleinen Vereine
## ausgetrocknet. Die Prüfung, die alle Ligen ansieht und nicht nur die
## Bundesliga, meldete danach neun Vereine unter zwei Millionen Minus — GOG,
## Mors-Thy, SønderjyskE, Lemvig, Eisenach, Balingen, alle mit kleinen Hallen.
## Ein Sponsor kauft eine Buehne, aber auch einen Markt: den Namen des Vereins
## in seiner Region, in seiner Liga, in seinem Land. Beides zaehlt jetzt.
const JE_PLATZ := 225.0
## Welcher Anteil der wirtschaftlichen Grundgroesse (Finanzen.grundetat, also
## Ruf mal Liga mal Landeswohlstand) als Marktseite dazukommt.
const MARKTANTEIL := 0.33

## Wie viel Sponsorengeld ein Verein im Jahr insgesamt anziehen kann.
static func marktwert(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var liga: Dictionary = d["ligen"].get(str(v["liga"]), {})
	var plaetze: float = maxf(float((v.get("halle", {}) as Dictionary).get("kapazitaet", 2000.0)), 500.0)
	# Die Bühne: Plätze in der Halle, und wer darauf steht.
	var buehne: float = plaetze * JE_PLATZ * (0.55 + float(v["ruf"]) / 120.0)
	# Und der Markt, in dem der Verein steht.
	var markt: float = Finanzen.grundetat(d, cid) * MARKTANTEIL
	var wert: float = buehne + markt
	# Eine erste Liga bringt Partner, die eine zweite nicht sieht.
	wert *= 0.72 + float(liga.get("ruf", 50.0)) / 190.0
	# Volle Halle und treue Anhänger sind ein Verkaufsargument.
	var fans: Dictionary = v["fans"]
	wert *= 0.86 + float(fans["zufriedenheit"]) / 480.0 + float(fans["treue"]) / 620.0
	# Titel der letzten Jahre wirken nach.
	var titel: Array = (v.get("chronik", {}) as Dictionary).get("titel", [])
	var frisch := 0
	var saison_jetzt: int = Kalender.saison_index(int(d["tag"]))
	for t in titel:
		if saison_jetzt - int(t["saison"]) <= 3:
			frisch += 1
	wert *= 1.0 + clampf(float(frisch) * 0.05, 0.0, 0.25)
	return maxf(wert, 20000.0)

## Ein Angebot für einen freien Platz.
static func angebot(d: Dictionary, cid: String, platz: String) -> Dictionary:
	var volumen: float = marktwert(d, cid) * float(PLAETZE.get(platz, 0.1))
	return {
		"name": Namen.sponsor(),
		"art": platz,
		"wert": volumen * Namen.bereich(0.86, 1.16),
		"jahre": Namen.wuerfel(2, 4),
		"bonus_titel": Namen.bereich(0.06, 0.22),
	}

static func laufende(d: Dictionary, cid: String) -> Array:
	return d["vereine"][cid].get("sponsoren", [])

static func offene_angebote(d: Dictionary, cid: String) -> Array:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("sponsorangebote"):
		v["sponsorangebote"] = []
	return v["sponsorangebote"]

static func jahressumme(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	for s in laufende(d, cid):
		summe += float(s["wert"])
	return summe

## Welche Plätze gerade unbesetzt sind.
static func freie_plaetze(d: Dictionary, cid: String) -> Array:
	var belegt := {}
	for s in laufende(d, cid):
		belegt[str(s["art"])] = true
	var frei: Array = []
	for platz in REIHENFOLGE:
		if not belegt.has(platz):
			frei.append(platz)
	return frei

## Beim Anlegen der Welt: jeder Verein hat schon Partner, mit gestaffelten
## Laufzeiten — sonst liefen in derselben Saison alle Verträge zugleich aus.
static func erstbelegung(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		v["sponsoren"] = []
		v["sponsorangebote"] = []
		for platz in REIHENFOLGE:
			var a := angebot(d, cid, platz)
			a["jahre"] = Namen.wuerfel(1, 4)
			_unterschreiben(d, cid, a)

# ------------------------------------------------------------ Saisonlauf ---

## Zum Saisonwechsel: ausgelaufene Verträge fallen weg, für jeden freien Platz
## kommt ein neues Angebot. Computervereine unterschreiben sofort, der Trainer
## entscheidet selbst.
static func jahreswechsel(d: Dictionary, mein: String) -> void:
	var saison: int = Kalender.saison_index(int(d["tag"]))
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var weiter: Array = []
		var ausgelaufen: Array = []
		for s in laufende(d, cid):
			if int(s.get("bis_saison", 0)) >= saison:
				weiter.append(s)
			else:
				ausgelaufen.append(s)
		v["sponsoren"] = weiter
		var neue: Array = []
		for platz in freie_plaetze(d, cid):
			neue.append(angebot(d, cid, platz))
		if cid != mein:
			for a in neue:
				_unterschreiben(d, cid, a)
			v["sponsorangebote"] = []
			continue
		v["sponsorangebote"] = neue
		if neue.is_empty():
			continue
		var summe := 0.0
		for a2 in neue:
			summe += float(a2["wert"])
		Welt.nachricht({
			"typ": "finanzen", "wichtig": true,
			"betreff": "%d Sponsorenplätze sind frei" % neue.size(),
			"text": "%s. Auf dem Tisch liegen Angebote über zusammen %s im Jahr. Solange Sie nicht unterschreiben, bleiben die Plätze leer — und das Geld aus." % [
				("Die Verträge von %s sind ausgelaufen" % ", ".join(_namen(ausgelaufen))) if not ausgelaufen.is_empty()
					else "Ihr Verein kann weitere Partner binden",
				Stil.geld(summe)],
		})

# ---------------------------------------------------------------- Akquise ---
#
# Bisher war Sponsoring etwas, das einem zustiess: einmal im Jahr lagen
# Angebote auf dem Tisch, man nahm sie an oder liess es. Ein Trainer, der einen
# freien Platz besetzen wollte, konnte nichts tun ausser warten — und was ein
# Partner zahlt, stand fest, bevor man das erste Wort gewechselt hatte.
#
# Jetzt gibt es beides: selbst auf die Suche gehen und ueber das Ergebnis
# reden. Die Akquise braucht Zeit und liefert nicht immer etwas; die
# Nachverhandlung kann mehr bringen und den Partner kosten.

## Wie lange nach einem Versuch derselbe Platz gesperrt ist.
const AKQUISE_SPERRE := 21
## Wie wahrscheinlich ein Versuch ueberhaupt jemanden findet — bei einem
## Verein mit mittlerem Ruf und zufriedenen Fans.
const AKQUISE_GRUNDCHANCE := 0.55

static func _versuche(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("sponsorakquise"):
		v["sponsorakquise"] = {}
	return v["sponsorakquise"]

## Wie viele Tage der Platz noch gesperrt ist. 0 heisst: jetzt.
static func akquise_sperre(d: Dictionary, cid: String, platz: String) -> int:
	var wann: int = int(_versuche(d, cid).get(platz, -9999))
	return maxi(AKQUISE_SPERRE - (int(d["tag"]) - wann), 0)

## Wie gut die Aussichten stehen, fuer diesen Platz jemanden zu finden.
static func akquise_chance(d: Dictionary, cid: String, platz: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var fans: Dictionary = v["fans"]
	var chance: float = AKQUISE_GRUNDCHANCE
	chance += (float(v["ruf"]) - 55.0) / 260.0
	chance += (float(fans["zufriedenheit"]) - 55.0) / 340.0
	# Der grosse Platz ist schwerer zu besetzen als der kleine.
	chance -= float(PLAETZE.get(platz, 0.1)) * 0.55
	return clampf(chance, 0.10, 0.92)

## Der Trainer geht selbst auf die Suche.
static func akquise(d: Dictionary, cid: String, platz: String) -> Dictionary:
	if not PLAETZE.has(platz):
		return {"ok": false, "grund": "Diesen Werbeplatz gibt es nicht."}
	if not freie_plaetze(d, cid).has(platz):
		return {"ok": false, "grund": "%s ist bereits vergeben." % platz}
	for a in offene_angebote(d, cid):
		if str(a["art"]) == platz:
			return {"ok": false, "grund": "Für %s liegt schon ein Angebot auf dem Tisch." % platz}
	var rest: int = akquise_sperre(d, cid, platz)
	if rest > 0:
		return {"ok": false, "grund": "Sie haben gerade erst angefragt. In %d Tagen wieder." % rest}
	_versuche(d, cid)[platz] = int(d["tag"])
	if Namen.zufall() > akquise_chance(d, cid, platz):
		return {"ok": false, "grund": "Keine Zusage. Für %s hat sich derzeit niemand gefunden." % platz}
	var neu := angebot(d, cid, platz)
	# Selbst gesucht heisst nicht besser verhandelt: wer von sich aus anklopft,
	# sitzt am kuerzeren Hebel.
	neu["wert"] = float(neu["wert"]) * Namen.bereich(0.88, 1.04)
	neu["selbst_gesucht"] = true
	(d["vereine"][cid]["sponsorangebote"] as Array).append(neu)
	return {"ok": true, "grund": "%s würde einsteigen: %s für %s im Jahr, %d Jahre." % [
		str(neu["name"]), platz, Stil.geld(float(neu["wert"])), int(neu["jahre"])],
		"angebot": neu}

# ----------------------------------------------------------- Verhandlung ---

## Wie viel mehr sich hoechstens herausholen laesst.
const NACHFORDERUNG_MAX := 1.35

## Ueber ein Angebot nachverhandeln. Wer mehr will, riskiert den Partner.
static func nachverhandeln(d: Dictionary, cid: String, index: int, wunsch: float, jahre: int) -> Dictionary:
	var angebote: Array = offene_angebote(d, cid)
	if index < 0 or index >= angebote.size():
		return {"ok": false, "grund": "Dieses Angebot gibt es nicht mehr."}
	var a: Dictionary = angebote[index]
	if int(a.get("runden", 0)) >= 2:
		return {"ok": false, "grund": "%s hat deutlich gemacht, dass jetzt Schluss ist." % str(a["name"])}
	var jetzt: float = float(a["wert"])
	var faktor: float = clampf(wunsch / maxf(jetzt, 1.0), 0.5, 3.0)
	var jahre_neu: int = clampi(jahre, 1, 5)
	# Eine laengere Laufzeit ist fuer den Partner ein Zugestaendnis und macht
	# ihn beim Geld weicher; eine kuerzere kostet.
	var laufzeit_bonus: float = float(jahre_neu - int(a.get("jahre", 2))) * 0.045
	a["runden"] = int(a.get("runden", 0)) + 1
	var schmerzgrenze: float = NACHFORDERUNG_MAX + laufzeit_bonus
	if faktor <= 1.0:
		a["wert"] = wunsch
		a["jahre"] = jahre_neu
		return {"ok": true, "grund": "%s nimmt an — kein Wunder bei dem Preis." % str(a["name"])}
	if faktor <= schmerzgrenze * Namen.bereich(0.72, 0.92):
		a["wert"] = wunsch
		a["jahre"] = jahre_neu
		return {"ok": true, "grund": "%s geht mit: %s im Jahr über %d Jahre." % [
			str(a["name"]), Stil.geld(wunsch), jahre_neu]}
	if faktor <= schmerzgrenze:
		var mitte: float = jetzt * (1.0 + (faktor - 1.0) * Namen.bereich(0.35, 0.6))
		a["wert"] = mitte
		a["jahre"] = jahre_neu
		return {"ok": true, "grund": "%s bietet %s im Jahr über %d Jahre — mehr nicht." % [
			str(a["name"]), Stil.geld(mitte), jahre_neu]}
	# Zu viel verlangt. Beim ersten Mal bleibt der Partner, beim zweiten geht er.
	if int(a["runden"]) >= 2 or Namen.zufall() < 0.35:
		for i in range(angebote.size()):
			if angebote[i] == a:
				angebote.remove_at(i)
				break
		return {"ok": false, "grund": "%s zieht das Angebot zurück. Das war zu viel verlangt." % str(a["name"])}
	return {"ok": false, "grund": "%s lehnt ab, bleibt aber im Gespräch. Ein Versuch bleibt Ihnen." % str(a["name"])}

static func _namen(liste: Array) -> Array:
	var namen: Array = []
	for s in liste:
		namen.append(str(s["name"]))
	return namen

static func _unterschreiben(d: Dictionary, cid: String, a: Dictionary) -> void:
	var vertrag := a.duplicate()
	vertrag["bis_saison"] = Kalender.saison_index(int(d["tag"])) + maxi(int(a.get("jahre", 2)), 1) - 1
	vertrag.erase("jahre")
	(d["vereine"][cid]["sponsoren"] as Array).append(vertrag)

## Der Trainer nimmt ein Angebot an.
static func annehmen(d: Dictionary, cid: String, index: int) -> Dictionary:
	var angebote: Array = offene_angebote(d, cid)
	if index < 0 or index >= angebote.size():
		return {"ok": false, "grund": "Dieses Angebot gibt es nicht mehr."}
	var a: Dictionary = angebote[index]
	if not freie_plaetze(d, cid).has(str(a["art"])):
		angebote.remove_at(index)
		return {"ok": false, "grund": "Der Platz %s ist bereits vergeben." % str(a["art"])}
	_unterschreiben(d, cid, a)
	angebote.remove_at(index)
	return {"ok": true, "grund": "%s ist neuer Partner (%s, %s im Jahr)." % [
		str(a["name"]), str(a["art"]), Stil.geld(float(a["wert"]))]}

static func alle_annehmen(d: Dictionary, cid: String) -> int:
	var n := 0
	for i in range(offene_angebote(d, cid).size() - 1, -1, -1):
		if bool(annehmen(d, cid, i)["ok"]):
			n += 1
	return n

## Titelprämien der Partner — dafür stehen sie schliesslich auf dem Trikot.
static func titelbonus(d: Dictionary, cid: String, titel: String) -> void:
	var summe := 0.0
	for s in laufende(d, cid):
		summe += float(s["wert"]) * float(s.get("bonus_titel", 0.0))
	if summe <= 0.0:
		return
	Finanzen.buchen(d, cid, summe, "Titelprämien der Sponsoren (%s)" % titel, "sponsor")
	if cid == Welt.mein_verein_id:
		Welt.nachricht({
			"typ": "finanzen",
			"betreff": "Titelprämien der Sponsoren",
			"text": "Für den Gewinn (%s) zahlen Ihre Partner zusammen %s aus." % [titel, Stil.geld(summe)],
		})
