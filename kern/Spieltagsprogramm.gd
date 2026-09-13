class_name Spieltagsprogramm
extends RefCounted
## Was rund um das Heimspiel passiert — die Entscheidung vor der Entscheidung.
##
## Ein Heimspiel ist nicht nur sechzig Minuten Handball. Es ist ein Abend, den
## ein Verein gestaltet: Fanfest auf dem Vorplatz, Kindertag mit halben
## Preisen, eine Choreo, die man den Ultras bezahlt, oder ein Empfang für die
## Geschäftspartner. Jede dieser Entscheidungen kostet Geld und zieht ein
## anderes Publikum an — und jede verstimmt jemanden.
##
## Das ist der Punkt: Es gibt kein Programm, das alle glücklich macht. Der
## Sponsorenabend bringt Geld und ärgert die Kurve; das Fanfest macht Lärm und
## bringt nichts ein. Wer sich nie entscheidet, bekommt ein Publikum, das auch
## nie ganz da ist.
##
## Gilt jeweils für das nächste Heimspiel und fällt danach auf "Normalbetrieb"
## zurück. Gespeichert je Verein in `verein["spieltag"]`.

const STANDARD := "normal"

const PROGRAMME := {
	"normal": {
		"name": "Normalbetrieb",
		"text": "Türen auf, Anwurf. Kostet nichts und bewegt nichts.",
		"grundkosten": 0.0, "je_platz": 0.0,
		"reiz": {"steh": 1.0, "sitz": 1.0, "loge": 1.0},
		"puls": 0.0,
		"fans": {},
	},
	"fanfest": {
		"name": "Fanfest vor der Halle",
		"text": "Bühne, Bier, Musik ab zwei Stunden vor Anwurf. Die Kurve kommt früher und lauter.",
		"grundkosten": 9000.0, "je_platz": 0.9,
		"reiz": {"steh": 1.22, "sitz": 1.06, "loge": 0.98},
		"puls": 6.0,
		"fans": {"ultras": 3.4, "treue": 1.0, "familien": 0.8, "geschaeft": -0.6},
	},
	"familientag": {
		"name": "Familientag",
		"text": "Kinder zum halben Preis, Torwandschießen in der Pause. Füllt die Sitzplätze, kostet Eintrittsgeld.",
		"grundkosten": 6000.0, "je_platz": 1.4,
		"reiz": {"steh": 1.04, "sitz": 1.28, "loge": 1.0},
		"puls": 2.0,
		"fans": {"familien": 4.2, "treue": 0.8, "ultras": -0.4, "geschaeft": 0.0},
	},
	"choreo": {
		"name": "Choreografie unterstützen",
		"text": "Material und Halle für die Kurve. Sie bauen etwas auf, das man im ganzen Land sieht.",
		"grundkosten": 14000.0, "je_platz": 0.4,
		"reiz": {"steh": 1.15, "sitz": 1.08, "loge": 1.02},
		"puls": 11.0,
		"fans": {"ultras": 6.0, "treue": 1.6, "familien": 0.6, "geschaeft": -1.2},
	},
	"sponsorenabend": {
		"name": "Sponsorenabend",
		"text": "Empfang in der Loge, Häppchen, Handschlag. Bringt Geld herein — und ein Raunen in der Kurve.",
		"grundkosten": 11000.0, "je_platz": 0.2,
		"reiz": {"steh": 0.97, "sitz": 1.0, "loge": 1.34},
		"puls": -2.0,
		"fans": {"geschaeft": 5.5, "ultras": -3.2, "treue": -0.8, "familien": 0.0},
	},
	"nachwuchstag": {
		"name": "Tag des Nachwuchses",
		"text": "Die Akademie läuft mit ein, die Jahrgänge sitzen im Block. Billig, ehrlich, wirkt nach innen.",
		"grundkosten": 3500.0, "je_platz": 0.3,
		"reiz": {"steh": 1.08, "sitz": 1.10, "loge": 1.0},
		"puls": 3.0,
		"fans": {"ultras": 2.2, "familien": 2.6, "treue": 1.4, "geschaeft": 0.4},
	},
	"derbywoche": {
		"name": "Derbywoche ausrufen",
		"text": "Plakate, Videos, Ansage. Zieht das ganze Umfeld hoch — und macht eine Niederlage doppelt teuer.",
		"grundkosten": 12000.0, "je_platz": 0.7,
		"reiz": {"steh": 1.26, "sitz": 1.16, "loge": 1.08},
		"puls": 9.0,
		"fans": {"ultras": 3.0, "treue": 1.8, "familien": 1.0, "geschaeft": 0.8},
	},
}

## Reihenfolge für die Oberfläche.
const REIHE := ["normal", "fanfest", "familientag", "choreo", "sponsorenabend", "nachwuchstag", "derbywoche"]

static func zustand(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("spieltag"):
		v["spieltag"] = {"programm": STANDARD, "letztes": STANDARD, "kosten": 0.0}
	return v["spieltag"]

static func gewaehlt(d: Dictionary, cid: String) -> String:
	var s := zustand(d, cid)
	var p: String = str(s.get("programm", STANDARD))
	return p if PROGRAMME.has(p) else STANDARD

static func kosten(d: Dictionary, cid: String, programm: String) -> float:
	var p: Dictionary = PROGRAMME.get(programm, PROGRAMME[STANDARD])
	var kap: float = float(d["vereine"][cid]["halle"]["kapazitaet"])
	return float(p["grundkosten"]) + kap * float(p["je_platz"])

static func waehlen(d: Dictionary, cid: String, programm: String) -> Dictionary:
	if not PROGRAMME.has(programm):
		return {"ok": false, "grund": "Dieses Programm gibt es nicht."}
	var preis: float = kosten(d, cid, programm)
	if preis > 0.0 and float(d["vereine"][cid]["kasse"]) < preis:
		return {"ok": false, "grund": "Dafür fehlen %s in der Kasse." % Stil.geld(preis - float(d["vereine"][cid]["kasse"]))}
	zustand(d, cid)["programm"] = programm
	if programm == STANDARD:
		return {"ok": true, "grund": "Nächstes Heimspiel im Normalbetrieb."}
	return {"ok": true, "grund": "%s angesetzt — %s werden am Spieltag fällig." % [
		str((PROGRAMME[programm] as Dictionary)["name"]), Stil.geld(preis)]}

## Beim Heimspiel: Kosten buchen, Wirkung zurückgeben, Auswahl zurücksetzen.
## Gibt {"programm", "reiz", "puls"} zurück — der Rest wirkt sofort.
static func einloesen(d: Dictionary, cid: String) -> Dictionary:
	var s := zustand(d, cid)
	var programm: String = gewaehlt(d, cid)
	var p: Dictionary = PROGRAMME[programm]
	s["programm"] = STANDARD
	s["letztes"] = programm
	if programm == STANDARD:
		s["kosten"] = 0.0
		return {"programm": programm, "reiz": (p["reiz"] as Dictionary).duplicate(), "puls": 0.0}
	var preis: float = kosten(d, cid, programm)
	s["kosten"] = preis
	Finanzen.buchen(d, cid, -preis, "Spieltagsprogramm: %s" % str(p["name"]), "spieltag")
	for gruppe in (p["fans"] as Dictionary).keys():
		Fanszene.stossen(d, cid, str(gruppe), float((p["fans"] as Dictionary)[gruppe]))
	return {
		"programm": programm,
		"reiz": (p["reiz"] as Dictionary).duplicate(),
		"puls": float(p["puls"]),
	}

## Was der Trainerstab empfehlen würde — abhängig davon, wer gerade grollt.
static func vorschlag(d: Dictionary, cid: String, gegner: String) -> String:
	if gegner != "" and d["vereine"].has(gegner):
		if float((d["vereine"][cid]["rivalen"] as Dictionary).get(gegner, 0.0)) > 45.0:
			return "derbywoche"
	var schlechteste := ""
	var tiefstand := 101.0
	for g in Fanszene.GRUPPEN:
		var wert: float = Fanszene.stimmung(d, cid, str(g))
		if wert < tiefstand:
			tiefstand = wert
			schlechteste = str(g)
	if tiefstand > 62.0:
		return STANDARD
	match schlechteste:
		"ultras":
			return "choreo"
		"familien":
			return "familientag"
		"geschaeft":
			return "sponsorenabend"
		"treue":
			return "nachwuchstag"
	return STANDARD
