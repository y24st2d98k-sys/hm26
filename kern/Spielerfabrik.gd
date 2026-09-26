class_name Spielerfabrik
extends RefCounted
## Erzeugt Spieler und rechnet alles aus, was sich direkt aus ihren Attributen ergibt:
## Angriffs- und Abwehrwert, Positionseignung, Marktwert, Gehaltsvorstellung, Alterskurve.
##
## Attributskala ist intern 1..20 (float, damit Entwicklung in kleinen Schritten laufen kann);
## angezeigt wird sie mal fünf als 5..100 — siehe `anzeige()`.
## Der "Gesamtwert" eines Spielers ist eine 0..100-Zahl, damit Vergleiche schnell lesbar sind.

const POSITIONEN := ["TW", "LA", "RL", "RM", "RR", "RA", "KM"]
const POSITION_NAME := {
	"TW": "Torwart", "LA": "Linksaußen", "RL": "Rückraum links", "RM": "Rückraum Mitte",
	"RR": "Rückraum rechts", "RA": "Rechtsaußen", "KM": "Kreisläufer",
}

const ATTR_TECHNIK := ["wurfkraft", "wurfpraezision", "taeuschung", "passspiel", "ballsicherheit", "siebenmeter"]
const ATTR_ATHLETIK := ["tempo", "sprungkraft", "physis", "ausdauer", "beweglichkeit"]
const ATTR_DEFENSIV := ["block", "deckungsarbeit", "zweikampf", "antizipation"]
const ATTR_MENTAL := ["uebersicht", "entscheidung", "nervenstaerke", "fuehrung", "arbeitseinsatz", "teamgeist"]
const ATTR_TORWART := ["reflexe", "tw_stellung", "rueckraumabwehr", "fluegelabwehr", "eins_gegen_eins",
	"siebenmeterabwehr", "anspiel", "ausstrahlung"]

const ATTR_LABEL := {
	"wurfkraft": "Wurfkraft", "wurfpraezision": "Wurfpräzision", "taeuschung": "Täuschung",
	"passspiel": "Passspiel", "ballsicherheit": "Ballsicherheit", "siebenmeter": "Siebenmeter",
	"tempo": "Tempo", "sprungkraft": "Sprungkraft", "physis": "Physis", "ausdauer": "Ausdauer",
	"beweglichkeit": "Beweglichkeit", "block": "Block", "deckungsarbeit": "Deckungsarbeit",
	"zweikampf": "Zweikampf", "antizipation": "Antizipation", "uebersicht": "Übersicht",
	"entscheidung": "Entscheidung", "nervenstaerke": "Nervenstärke", "fuehrung": "Führung",
	"arbeitseinsatz": "Arbeitseinsatz", "teamgeist": "Teamgeist", "reflexe": "Reflexe",
	"tw_stellung": "Stellungsspiel", "rueckraumabwehr": "Rückraumabwehr", "fluegelabwehr": "Flügelabwehr",
	"eins_gegen_eins": "Eins gegen Eins", "siebenmeterabwehr": "Siebenmeterabwehr",
	"anspiel": "Gegenstoß-Anspiel", "ausstrahlung": "Ausstrahlung",
}

## Gewichte fuer den Angriffswert je Position.
const ANGRIFF_GEWICHTE := {
	"LA": {"wurfpraezision": 3.0, "tempo": 2.6, "sprungkraft": 2.4, "beweglichkeit": 1.8, "taeuschung": 1.4,
		"entscheidung": 1.4, "nervenstaerke": 1.2, "ballsicherheit": 1.0, "wurfkraft": 0.6, "siebenmeter": 0.8},
	"RA": {"wurfpraezision": 3.0, "tempo": 2.6, "sprungkraft": 2.4, "beweglichkeit": 1.8, "taeuschung": 1.4,
		"entscheidung": 1.4, "nervenstaerke": 1.2, "ballsicherheit": 1.0, "wurfkraft": 0.6, "siebenmeter": 0.8},
	"RL": {"wurfkraft": 3.0, "wurfpraezision": 2.4, "sprungkraft": 2.0, "taeuschung": 2.0, "physis": 1.6,
		"entscheidung": 1.5, "passspiel": 1.2, "uebersicht": 1.0, "tempo": 0.9, "ballsicherheit": 0.8},
	"RR": {"wurfkraft": 3.0, "wurfpraezision": 2.4, "sprungkraft": 2.0, "taeuschung": 2.0, "physis": 1.6,
		"entscheidung": 1.5, "passspiel": 1.2, "uebersicht": 1.0, "tempo": 0.9, "ballsicherheit": 0.8},
	"RM": {"uebersicht": 3.0, "passspiel": 2.8, "entscheidung": 2.4, "taeuschung": 1.8, "ballsicherheit": 1.6,
		"wurfpraezision": 1.4, "wurfkraft": 1.2, "nervenstaerke": 1.2, "tempo": 0.8, "fuehrung": 0.8},
	"KM": {"physis": 3.0, "ballsicherheit": 2.4, "beweglichkeit": 2.0, "wurfpraezision": 1.8, "zweikampf": 1.6,
		"arbeitseinsatz": 1.4, "sprungkraft": 1.2, "taeuschung": 1.0, "entscheidung": 1.0, "passspiel": 0.6},
	"TW": {"reflexe": 3.0, "tw_stellung": 2.6, "rueckraumabwehr": 2.2, "eins_gegen_eins": 1.8,
		"fluegelabwehr": 1.6, "siebenmeterabwehr": 1.4, "antizipation": 1.2, "nervenstaerke": 1.2,
		"anspiel": 1.0, "ausstrahlung": 0.8},
}

const ABWEHR_GEWICHTE := {
	"block": 2.8, "deckungsarbeit": 2.8, "zweikampf": 2.4, "antizipation": 2.0,
	"physis": 1.8, "beweglichkeit": 1.4, "arbeitseinsatz": 1.4, "tempo": 0.8, "uebersicht": 0.6,
}

## Positionsverwandtschaft — bestimmt, wie gut ein Spieler ausserhalb seiner Position ist.
const POSITION_NAEHE := {
	"TW": {"TW": 1.0},
	"LA": {"LA": 1.0, "RL": 0.62, "RA": 0.45, "RM": 0.4, "KM": 0.3, "RR": 0.3},
	"RA": {"RA": 1.0, "RR": 0.62, "LA": 0.45, "RM": 0.4, "KM": 0.3, "RL": 0.3},
	"RL": {"RL": 1.0, "RM": 0.72, "RR": 0.5, "LA": 0.55, "KM": 0.42, "RA": 0.3},
	"RR": {"RR": 1.0, "RM": 0.72, "RL": 0.5, "RA": 0.55, "KM": 0.42, "LA": 0.3},
	"RM": {"RM": 1.0, "RL": 0.74, "RR": 0.74, "LA": 0.4, "RA": 0.4, "KM": 0.4},
	"KM": {"KM": 1.0, "RL": 0.4, "RR": 0.4, "RM": 0.38, "LA": 0.3, "RA": 0.3},
}

## Wie gut eine Position in einen Abwehrplatz passt. A1 und A6 sind die
## Aussenpositionen, A3 und A4 die Innenblocker. Ein Aussenspieler verteidigt
## aussen, ein Kreislaeufer innen — wer am falschen Platz steht, verliert.
const ABWEHR_EIGNUNG := {
	"A1": {"LA": 1.0, "RA": 0.86, "RL": 0.72, "RR": 0.64, "RM": 0.58, "KM": 0.5},
	"A2": {"RL": 1.0, "LA": 0.84, "RM": 0.78, "KM": 0.74, "RR": 0.74, "RA": 0.62},
	"A3": {"KM": 1.0, "RL": 0.84, "RM": 0.82, "RR": 0.8, "LA": 0.54, "RA": 0.54},
	"A4": {"KM": 1.0, "RR": 0.84, "RM": 0.82, "RL": 0.8, "RA": 0.54, "LA": 0.54},
	"A5": {"RR": 1.0, "RA": 0.84, "RM": 0.78, "KM": 0.74, "RL": 0.74, "LA": 0.62},
	"A6": {"RA": 1.0, "LA": 0.86, "RR": 0.72, "RL": 0.64, "RM": 0.58, "KM": 0.5},
}

## Wie die Abwehrplaetze heissen, wenn man sie jemandem zeigt. "A1" bis "A6"
## sind Schluessel im Datensatz und sagen niemandem etwas; auf dem Feld und in
## der Aufstellung steht, was der Platz ist.
const ABWEHR_KURZ := {
	"A1": "AL", "A2": "HL", "A3": "IL", "A4": "IR", "A5": "HR", "A6": "AR",
}
const ABWEHR_NAME := {
	"A1": "Außen links", "A2": "Halblinks", "A3": "Innenblock links",
	"A4": "Innenblock rechts", "A5": "Halbrechts", "A6": "Außen rechts",
}

## Spannweite der Lernkurve: 1.0 ist der Normalfall, 0.55 ein echter
## Spaetzuender, 1.6 ein Spieler, der zwei Jahre ueberspringt.
const LERNKURVE_MIN := 0.55
const LERNKURVE_MAX := 1.6

## Klartext zur Lernkurve — die nackte Zahl saehe nach Tabellenkalkulation aus.
static func lernkurve_text(wert: float) -> String:
	if wert >= 1.34:
		return "reift im Zeitraffer"
	if wert >= 1.14:
		return "lernt schnell"
	if wert >= 0.9:
		return "entwickelt sich stetig"
	if wert >= 0.72:
		return "braucht Geduld"
	return "Spätzünder"

## Anzeigeskala für Attribute. Intern läuft ein Attribut von 1..20 in
## Fließkomma, damit Entwicklung in winzigen Schritten stattfinden kann.
## Angezeigt wird 5..100: eine Zwanzigerskala verschluckt Unterschiede, die
## im Spiel sehr wohl zählen — zwischen 14 und 15 liegt eine halbe Liga.
const ANZEIGE_FAKTOR := 5.0

## Ein internes Attribut als Zahl, wie sie in der Oberfläche steht.
static func anzeige(wert: float) -> int:
	return int(round(clampf(wert, 1.0, 20.0) * ANZEIGE_FAKTOR))

## Wie gut dieser Spieler auf diesen Abwehrplatz passt (0.5..1.0).
static func abwehr_eignung(spieler: Dictionary, platz: String) -> float:
	var tabelle: Dictionary = ABWEHR_EIGNUNG.get(platz, {})
	if tabelle.is_empty():
		return 1.0
	return float(tabelle.get(str(spieler["position"]), 0.6))

## Verteilung der Positionen in einem normalen Kader.
const KADER_SOLL := {"TW": 3, "LA": 2, "RL": 3, "RM": 3, "RR": 3, "RA": 2, "KM": 3}

## Was ein Verein mit hinterlegtem echtem Kader noch braucht.
##
## KADER_SOLL beschreibt, was ein erfundener Verein braucht: drei Torhueter,
## drei Rueckraumspieler je Seite. Ein echter Bundesligakader sieht anders aus.
## Magdeburg hat zwei Torhueter, vier Spieler fuer die Rueckraummitte und je
## zwei fuer aussen — wer den auf KADER_SOLL auffuellt, stellt drei erfundene
## Spieler neben siebzehn echte, und im Kaderbildschirm stehen Namen, die es
## nicht gibt, zwischen denen, die es gibt. Genau das war zu sehen.
##
## Fuer einen belegten Kader gilt deshalb nur noch, was die Simulation
## zwingend braucht: zwei Torhueter und mindestens einer auf jeder
## Feldposition, dazu eine Mindestgroesse gegen Verletzungspech.
const ECHT_MINDEST := {"TW": 2, "LA": 1, "RL": 1, "RM": 1, "RR": 1, "RA": 1, "KM": 1}
## Ab so vielen echten Spielern gilt der Kader als belegt.
const ECHT_AB := 14
## So gross muss auch ein belegter Kader mindestens werden.
const ECHT_GESAMT := 16

# -------------------------------------------------------------- Erzeugung ---

## Erzeugt einen Spieler. ziel_gesamt ist der angestrebte Gesamtwert (0..100).
static func erzeuge(id: String, kultur: String, alter_jahre: int, ziel_gesamt: float, position: String, startjahr: int) -> Dictionary:
	var p := Namen.person(kultur)
	var ist_tw: bool = position == "TW"
	var attr := _attribute_fuer(position, ziel_gesamt)
	_jugendprofil(attr, alter_jahre, position)

	# Potenzial: junge Spieler haben deutlich mehr Luft nach oben.
	var rest_jahre: float = maxf(0.0, 27.0 - float(alter_jahre))
	var potenzial_bonus: float = Namen.glocke(rest_jahre * 1.55, 7.0, -3.0, 34.0)
	var potenzial: float = clampf(ziel_gesamt + potenzial_bonus, ziel_gesamt, 97.0)
	# Die Lernkurve sagt, wie schnell er diese Luft nutzt. Zwei Talente mit
	# demselben Potenzial sind nicht dasselbe: der eine steht mit 21 oben, der
	# andere braucht bis 26 — und einer von beiden ist ein Transfer wert.
	var lernkurve: float = Namen.glocke(1.0, 0.21, LERNKURVE_MIN, LERNKURVE_MAX)

	_auf_zielstaerke(attr, position, ziel_gesamt)

	var pers: String = Namen.persoenlichkeit()
	var charakter: Dictionary = (Namen.PERSOENLICHKEITEN[pers] as Dictionary).duplicate()
	for k in charakter.keys():
		charakter[k] = clampf(float(charakter[k]) + Namen.bereich(-2.0, 2.0), 1.0, 20.0)

	var zweit: Array[String] = []
	for kandidat in POSITIONEN:
		if kandidat == position or kandidat == "TW" or ist_tw:
			continue
		var naehe: float = float((POSITION_NAEHE[position] as Dictionary).get(kandidat, 0.0))
		if naehe >= 0.55 and Namen.zufall() < 0.3:
			zweit.append(kandidat)

	var spieler := {
		"id": id,
		"vorname": p["vorname"],
		"nachname": p["nachname"],
		"nation": kultur,
		"geburtsjahr": startjahr - alter_jahre,
		"geburtstag_doy": Namen.wuerfel(0, 364),
		"alter": alter_jahre,
		"position": position,
		"zweitpositionen": zweit,
		"nummer": 0,
		"ist_torwart": ist_tw,
		"attr": attr,
		"potenzial": potenzial,
		"lernkurve": lernkurve,
		# Gemerkter Gesamtwert; -1 heißt "muss neu gerechnet werden".
		"staerke": -1.0,
		"form": Namen.glocke(58.0, 14.0, 20.0, 95.0),
		"moral": Namen.glocke(66.0, 12.0, 25.0, 98.0),
		"fitness": Namen.glocke(93.0, 5.0, 70.0, 100.0),
		"last": Namen.glocke(22.0, 10.0, 0.0, 60.0),
		"verletzungsneigung": Namen.glocke(9.0, 4.0, 1.0, 20.0),
		"verletzung": {},
		# Welche Koerperregionen es schon einmal erwischt hat. Ein Sprunggelenk,
		# das einmal umgeknickt ist, knickt wieder um — siehe kern/Medizin.gd.
		"vorgeschichte": {},
		"sperre": 0,
		"verein": "",
		"vertrag": {},
		"persoenlichkeit": pers,
		"charakter": charakter,
		"kenntnis": 22.0,
		"wert": 0.0,
		"stats": leere_statistik(),
		"laufbahn": [],
		"unzufriedenheit": 0.0,
		"beziehung": 50.0,
		# Zusage fuer die kommende Saison (siehe kern/Vorvertrag.gd).
		"vorvertrag": {},
		"transferwunsch": false,
		"nationalspieler": 0,
		"trainingsfokus": "",
		"entwicklung_log": [],
	}
	koerper_wuerfeln(spieler)
	spieler["wert"] = marktwert(spieler)
	return spieler

# ------------------------------------------------------------ Körper ---
#
# Wurfhand, Größe und Gewicht. Die Hand ist die einzige der drei Angaben, die
# im Spiel etwas entscheidet: die rechte Seite gehört den Linkshändern. Ein
# Rechtshänder im rechten Rückraum wirft aus dem falschen Winkel, ein
# Linkshänder auf Linksaußen genauso — beides geht, kostet aber, und genau das
# fehlte, solange jeder Spieler auf jede Seite umgestellt werden konnte, als
# hätte er zwei gleich gute Hände.

## Anteil der Linkshänder je Stammposition. Auf der rechten Seite sind sie die
## Regel, sonst so selten wie in der Bevölkerung.
const LINKS_ANTEIL := {"TW": 0.14, "LA": 0.04, "RL": 0.05, "RM": 0.09, "RR": 0.88, "RA": 0.9, "KM": 0.1}
## Mittlere Größe (cm) und Streuung je Position.
const GROESSE_MITTEL := {"TW": 193.0, "LA": 182.0, "RL": 196.0, "RM": 189.0, "RR": 194.0, "RA": 183.0, "KM": 196.0}
## Body-Mass-Index-Mittel je Position — Kreisläufer sind schwer, Außen leicht.
const BMI_MITTEL := {"TW": 25.5, "LA": 23.8, "RL": 26.0, "RM": 25.2, "RR": 25.6, "RA": 23.8, "KM": 28.6}

## Würfelt Wurfhand, Größe und Gewicht, soweit sie noch nicht gesetzt sind.
static func koerper_wuerfeln(sp: Dictionary) -> void:
	var pos: String = str(sp.get("position", "RM"))
	if not sp.has("hand"):
		sp["hand"] = "L" if Namen.zufall() < float(LINKS_ANTEIL.get(pos, 0.1)) else "R"
	if not sp.has("groesse"):
		sp["groesse"] = int(roundf(Namen.glocke(float(GROESSE_MITTEL.get(pos, 190.0)), 5.0, 168.0, 212.0)))
	if not sp.has("gewicht"):
		var m: float = float(sp["groesse"]) / 100.0
		sp["gewicht"] = int(roundf(Namen.glocke(float(BMI_MITTEL.get(pos, 25.0)), 1.4, 20.0, 33.0) * m * m))

## Linkshänder? Ältere Spielstände kennen die Hand nicht — dort gilt die
## Stammposition als Hinweis.
static func linkshaender(sp: Dictionary) -> bool:
	if sp.has("hand"):
		return str(sp["hand"]) == "L"
	return str(sp.get("position", "")) in ["RR", "RA"]

static func hand_text(sp: Dictionary) -> String:
	return "Linkshänder" if linkshaender(sp) else "Rechtshänder"

## Erzeugt einen Spieler mit vorgegebener Identität (echte Daten).
## Attribute entstehen wie bei jedem anderen Spieler aus Position und Zielstärke —
## Alter und Stärke im Datensatz sind Schätzwerte für die Simulation.
static func erzeuge_mit_namen(id: String, eintrag: Dictionary, position: String, startjahr: int) -> Dictionary:
	var nation: String = str(eintrag.get("nation", "de"))
	var alter_jahre: int = int(eintrag.get("alter", 26))
	var gd: Dictionary = geburtsdatum_lesen(str(eintrag.get("geburtsdatum", "")))
	if not gd.is_empty():
		alter_jahre = startjahr - int(gd["jahr"]) - (1 if int(gd["monat"]) > 7 else 0)
	var ziel: float = float(eintrag.get("staerke", 60.0))
	var sp := erzeuge(id, nation, alter_jahre, ziel, position, startjahr)
	sp["vorname"] = str(eintrag.get("vorname", sp["vorname"]))
	sp["nachname"] = str(eintrag.get("nachname", sp["nachname"]))
	sp["nation"] = nation
	sp["echt"] = true
	# Die Rueckennummer aus dem Datensatz. Trikot.vergeben() respektiert eine
	# schon gesetzte Nummer, solange sie im Verein frei ist — damit traegt
	# Gidsel die 19 und nicht irgendeine.
	if int(eintrag.get("nummer", 0)) > 0:
		sp["nummer"] = int(eintrag["nummer"])
	# Einzelne Attribute aus dem Datensatz. Gedacht fuer das eine Merkmal, das
	# einen Spieler ausmacht und das die Zielstaerke allein nicht hergibt: Kai
	# Haefner hat in einer Saison 133 Siebenmeter verwandelt, mehr als jeder
	# andere um Laengen. Wuerfelt man ihm den Wert wie jedem anderen aus, wirft
	# in Stuttgart irgendwer. Nach _auf_zielstaerke gesetzt, damit die
	# Angleichung den Wert nicht wieder wegskaliert.
	# Wer die Siebenmeter wirft, ist eine Rolle im Verein und keine Frage der
	# Wurftechnik allein. Frueher entschied das allein der Attributwert — dann
	# muss man ihn hochdrehen, damit der Richtige wirft, und verliert genau
	# damit die Angabe, wie gut er trifft. Beides steht jetzt getrennt da:
	# "stammschuetze" sagt wer, "attribute.siebenmeter" sagt wie gut.
	if bool(eintrag.get("stammschuetze", false)):
		sp["stammschuetze"] = true
	# Ausdruecklicher Dateiname fuer das Portraetfoto. Ohne Angabe leitet
	# Portraet ihn aus dem Namen ab; gebraucht wird das Feld bei
	# Namensgleichheit und bei Schreibweisen, die sich nicht sauber
	# umschreiben lassen.
	if str(eintrag.get("bild", "")) != "":
		sp["bild"] = str(eintrag["bild"])
	koerper_uebernehmen(sp, eintrag, startjahr)
	var werte: Dictionary = eintrag.get("attribute", {})
	for name in werte.keys():
		if not (sp["attr"] as Dictionary).has(name):
			push_warning("Unbekanntes Attribut '%s' bei %s" % [name, sp["nachname"]])
			continue
		sp["attr"][name] = clampf(float(werte[name]), 1.0, 20.0)
	if not werte.is_empty():
		staerke_verwerfen(sp)
	# Bei echten Spielern ist die Zielstärke gesetzt, nicht gewürfelt: Potenzial
	# darf sie nur bei jungen Spielern deutlich übersteigen.
	if alter_jahre >= 28:
		sp["potenzial"] = clampf(ziel + 1.0, ziel, 99.0)
	# Woher dieser Spieler kommt. Ohne diese Spur liesse sich ein spaeter
	# nachgelieferter Datensatz nicht mehr einspielen: das Spiel wuesste dann
	# nicht, welcher Teil der heutigen Werte aus den Daten stammt und welcher
	# aus drei Saisons Training. Siehe Echtdaten.abgleich().
	sp["datenspur"] = {"staerke": ziel, "attribute": werte.duplicate()}
	return sp

## Übernimmt, was der Datensatz über Person und Körper weiß: Geburtsdatum,
## Wurfhand, Größe, Gewicht und weitere Positionen. Was fehlt, bleibt so, wie
## erzeuge() es gewürfelt hat.
static func koerper_uebernehmen(sp: Dictionary, eintrag: Dictionary, startjahr: int) -> void:
	var gd: Dictionary = geburtsdatum_lesen(str(eintrag.get("geburtsdatum", "")))
	if not gd.is_empty():
		var jahr: int = int(gd["jahr"])
		var monat: int = int(gd["monat"])
		var tag: int = int(gd["tag"])
		# Das Alter gilt am 1. Juli des Startjahres, dem ersten Spieltag des
		# Kalenders; der Geburtstag im Kalender ist der Tag der Saison.
		var alter_jahre: int = startjahr - jahr
		if monat > 7 or (monat == 7 and tag > 1):
			alter_jahre -= 1
		sp["alter"] = clampi(alter_jahre, 14, 48)
		sp["geburtsjahr"] = jahr
		sp["geburtsdatum"] = "%04d-%02d-%02d" % [jahr, monat, tag]
		var tag_im_jahr: int = tag - 1
		for m in range(monat - 1):
			tag_im_jahr += int(Kalender.MONATSTAGE[m])
		sp["geburtstag_doy"] = posmod(tag_im_jahr - Kalender.JULI_ERSTER, Kalender.TAGE_IM_JAHR)
		# Wer am 1. Juli Geburtstag hat, ist oben schon mitgezählt.
		sp["hatte_geburtstag"] = int(sp["geburtstag_doy"]) <= 3
	var hand: String = str(eintrag.get("hand", "")).to_upper()
	if hand in ["L", "R"]:
		sp["hand"] = hand
	if int(eintrag.get("groesse", 0)) >= 150:
		sp["groesse"] = int(eintrag["groesse"])
	if int(eintrag.get("gewicht", 0)) >= 50:
		sp["gewicht"] = int(eintrag["gewicht"])
	var zp: Array = eintrag.get("zweitpositionen", [])
	if not zp.is_empty() and not bool(sp["ist_torwart"]):
		var liste: Array[String] = []
		for p in zp:
			var pos: String = str(p)
			if POSITIONEN.has(pos) and pos != "TW" and pos != str(sp["position"]) and not liste.has(pos):
				liste.append(pos)
		sp["zweitpositionen"] = liste

## "1994-02-28" oder "28.02.1994" — alles andere wird ignoriert.
static func geburtsdatum_lesen(text: String) -> Dictionary:
	text = text.strip_edges()
	if text == "":
		return {}
	var teile: PackedStringArray
	var jahr := 0
	var monat := 0
	var tag := 0
	if text.contains("-"):
		teile = text.split("-")
		if teile.size() != 3:
			return {}
		jahr = int(teile[0]); monat = int(teile[1]); tag = int(teile[2])
	elif text.contains("."):
		teile = text.split(".")
		if teile.size() != 3:
			return {}
		tag = int(teile[0]); monat = int(teile[1]); jahr = int(teile[2])
	else:
		return {}
	if jahr < 1950 or jahr > 2020 or monat < 1 or monat > 12 or tag < 1 or tag > 31:
		return {}
	tag = mini(tag, int(Kalender.MONATSTAGE[monat - 1]))
	return {"jahr": jahr, "monat": monat, "tag": tag}

static func leere_statistik() -> Dictionary:
	return {
		"saison": leere_saisonstats(),
		# Eigenes Becken für die Monatswahl: Saisonwerte taugen dafür nicht,
		# weil ein starker September einen schwachen März überdeckt.
		"monat": leere_saisonstats(),
		"karriere": leere_saisonstats(),
		"verlauf": [],
	}

static func leere_saisonstats() -> Dictionary:
	return {
		"spiele": 0, "minuten": 0.0, "tore": 0, "wuerfe": 0, "assists": 0,
		"technische_fehler": 0, "zeitstrafen": 0, "verwarnungen": 0, "rote": 0,
		"siebenmeter_tore": 0, "siebenmeter_wuerfe": 0, "gegenstoss_tore": 0,
		"paraden": 0, "gegentore": 0, "blocks": 0, "ballgewinne": 0,
		"note_summe": 0.0, "noten": 0, "spieler_des_spiels": 0, "titel": 0,
		"praemien": 0.0, "allstar": 0,
	}

## Zieht einen fertigen Spieler auf eine neue Zielstaerke. Gebraucht, wenn ein
## nachgelieferter Datensatz die Staerke eines Spielers verschiebt, ohne dass
## er neu erzeugt werden darf — seine Laufbahn, sein Vertrag und seine
## Beziehungen sollen ja bleiben. Siehe Echtdaten.abgleich().
static func auf_staerke_ziehen(spieler: Dictionary, ziel: float) -> void:
	_auf_zielstaerke(spieler["attr"], str(spieler["position"]), ziel)
	staerke_verwerfen(spieler)
	spieler["potenzial"] = maxf(float(spieler.get("potenzial", ziel)), ziel)

## Zieht die leistungsrelevanten Attribute so zurecht, dass der Gesamtwert die
## vorgegebene Zielstärke trifft. Ohne diesen Schritt liegt das Ergebnis der
## Streuung systematisch unter dem Ziel — ein hinterlegter Weltklassetorwart
## käme dann als solider Zweitligist im Spiel an.
static func _auf_zielstaerke(attr: Dictionary, position: String, ziel: float) -> void:
	var relevant: Array = (ANGRIFF_GEWICHTE.get(position, ANGRIFF_GEWICHTE["RM"]) as Dictionary).keys()
	if position != "TW":
		for a in ABWEHR_GEWICHTE.keys():
			if not relevant.has(a):
				relevant.append(a)
	for _durchlauf in range(8):
		var ist: float = _gesamt_aus(attr, position)
		if absf(ist - ziel) < 0.6:
			return
		var faktor: float = clampf(ziel / maxf(ist, 1.0), 0.75, 1.35)
		var veraendert := false
		for a in relevant:
			var alt_wert: float = float(attr[a])
			var neu_wert: float = clampf(alt_wert * faktor, 1.0, 20.0)
			if not is_equal_approx(alt_wert, neu_wert):
				veraendert = true
			attr[a] = neu_wert
		if not veraendert:
			return

## Gesamtwert direkt aus einer Attributtabelle (ohne fertigen Spieler).
static func _gesamt_aus(attr: Dictionary, position: String) -> float:
	var gew: Dictionary = ANGRIFF_GEWICHTE.get(position, ANGRIFF_GEWICHTE["RM"])
	var summe := 0.0
	var gewicht := 0.0
	for a in gew.keys():
		summe += float(attr.get(a, 1.0)) * float(gew[a])
		gewicht += float(gew[a])
	var angriff: float = summe / maxf(gewicht, 0.01) * 5.0
	if position == "TW":
		return angriff
	var d_summe := 0.0
	var d_gewicht := 0.0
	for a in ABWEHR_GEWICHTE.keys():
		d_summe += float(attr.get(a, 1.0)) * float(ABWEHR_GEWICHTE[a])
		d_gewicht += float(ABWEHR_GEWICHTE[a])
	var abwehr: float = d_summe / maxf(d_gewicht, 0.01) * 5.0
	var abwehr_anteil: float = 0.34
	if position == "KM":
		abwehr_anteil = 0.44
	elif position == "LA" or position == "RA":
		abwehr_anteil = 0.24
	return angriff * (1.0 - abwehr_anteil) + abwehr * abwehr_anteil

## Wie ein Nachwuchsspieler aussieht, bevor er Profihandball gelernt hat.
##
## Die DHB-Rahmentrainingskonzeption beschreibt den Werdegang in fuenf Stufen.
## Bis etwa zwoelf wird ausschliesslich mannorientiert gedeckt — ausdruecklich,
## um die Wahrnehmungsanforderungen klein zu halten: das Kind sieht seinen
## Gegenspieler und den Ball, sonst nichts. Die verdichteten Raumdeckungen 6:0
## und 5:1 kommen erst im Aufbautraining 2 und im Anschlusstraining dazu, also
## ab sechzehn bis neunzehn.
##
## Daraus folgt ein Spielertyp, den das Spiel bisher nicht kannte: ein
## Achtzehnjaehriger mit hervorragendem Eins-gegen-Eins, der in einer
## Profiabwehr trotzdem falsch steht, weil Uebergeben, Uebernehmen und Sichern
## des Nebenmannes noch nicht sitzen. Bisher war ein junger Spieler einfach in
## allem etwas schwaecher — also nur eine kleinere Ausgabe des fertigen
## Profis, und damit uninteressant.
##
## Der Gesamtwert bleibt unberuehrt: das Profil wird vor _auf_zielstaerke
## angelegt, die Staerke danach wieder genau getroffen. Was sich aendert, ist
## die Form, nicht die Hoehe.
const JUGENDPROFIL_BIS := 23
##
## Torhueterattribute bleiben aussen vor. Ihre Gewichte gehen ueber
## _auf_zielstaerke anders ein als bei einem Feldspieler, und ein
## verschobenes Stellungsspiel verrueckt sofort die Paradenquote der ganzen
## Liga — gemessen mit werkzeuge/Testlauf.gd, wo ein erster, kraeftigerer
## Zuschnitt die Tore je Partie um zwei nach oben zog.
const JUGEND_STARK := {"zweikampf": 1.09, "taeuschung": 1.08, "tempo": 1.05, "sprungkraft": 1.05}
const JUGEND_SCHWACH := {"deckungsarbeit": 0.86, "antizipation": 0.88, "uebersicht": 0.90,
	"entscheidung": 0.89, "fuehrung": 0.85}

static func _jugendprofil(attr: Dictionary, alter_jahre: int, position: String) -> void:
	if alter_jahre >= JUGENDPROFIL_BIS or position == "TW":
		return
	var anteil: float = clampf(float(JUGENDPROFIL_BIS - alter_jahre) / 6.0, 0.0, 1.0)
	for a in JUGEND_STARK.keys():
		if attr.has(a):
			attr[a] = clampf(float(attr[a]) * lerpf(1.0, float(JUGEND_STARK[a]), anteil), 1.0, 20.0)
	for b in JUGEND_SCHWACH.keys():
		if attr.has(b):
			attr[b] = clampf(float(attr[b]) * lerpf(1.0, float(JUGEND_SCHWACH[b]), anteil), 1.0, 20.0)

static func _attribute_fuer(position: String, ziel: float) -> Dictionary:
	var attr := {}
	var alle: Array = []
	alle.append_array(ATTR_TECHNIK)
	alle.append_array(ATTR_ATHLETIK)
	alle.append_array(ATTR_DEFENSIV)
	alle.append_array(ATTR_MENTAL)
	alle.append_array(ATTR_TORWART)

	var basis: float = clampf(ziel / 5.0, 1.5, 19.0)  # 0..100 -> 1..20
	var gew: Dictionary = ANGRIFF_GEWICHTE[position]
	for a in alle:
		var wichtig: float = float(gew.get(a, 0.0))
		var abwehr_wichtig: float = float(ABWEHR_GEWICHTE.get(a, 0.0))
		var relevanz: float = maxf(wichtig / 3.0, abwehr_wichtig / 3.0 * (0.35 if position == "TW" else 0.85))
		var mitte: float = basis * (0.55 + 0.55 * relevanz)
		if position == "TW":
			if a in ATTR_TORWART:
				mitte = basis * (0.75 + 0.35 * relevanz)
			elif a in ATTR_TECHNIK or a in ATTR_DEFENSIV:
				mitte = basis * 0.35
		elif a in ATTR_TORWART:
			mitte = Namen.bereich(1.0, 4.0)
		attr[a] = clampf(Namen.glocke(mitte, 1.9, 1.0, 20.0), 1.0, 20.0)
	return attr

# ------------------------------------------------------------- Bewertungen ---

static func angriffswert(spieler: Dictionary, position: String = "") -> float:
	var pos: String = position if position != "" else str(spieler["position"])
	var gew: Dictionary = ANGRIFF_GEWICHTE.get(pos, ANGRIFF_GEWICHTE["RM"])
	var summe := 0.0
	var gewicht := 0.0
	var attr: Dictionary = spieler["attr"]
	for a in gew.keys():
		summe += float(attr.get(a, 1.0)) * float(gew[a])
		gewicht += float(gew[a])
	var roh: float = summe / maxf(gewicht, 0.01)
	return roh * 5.0

static func abwehrwert(spieler: Dictionary) -> float:
	if bool(spieler["ist_torwart"]):
		return angriffswert(spieler)
	var summe := 0.0
	var gewicht := 0.0
	var attr: Dictionary = spieler["attr"]
	for a in ABWEHR_GEWICHTE.keys():
		summe += float(attr.get(a, 1.0)) * float(ABWEHR_GEWICHTE[a])
		gewicht += float(ABWEHR_GEWICHTE[a])
	return summe / maxf(gewicht, 0.01) * 5.0

## Gesamtwert 0..100 — Mischung aus Angriff und Abwehr, je nach Position gewichtet.
## Der Gesamtwert eines Spielers, gemerkt statt jedes Mal neu summiert.
##
## `gesamt()` läuft über zwanzig Attribute und wird überall aufgerufen: im
## Transfermarkt für dreitausend Spieler, in jeder Kaderliste, in der
## Spielsimulation. Attribute ändern sich aber nur im Training, im Lager, in
## der Jugend und bei einer Patenschaft — sechs Stellen, die den Wert
## anschließend verwerfen. Damit das verlässlich bleibt, rechnet
## `werkzeuge/Pruefung.gd` den Wert für jeden Spieler frisch nach und
## vergleicht: ein vergessenes Verwerfen fällt sofort auf.
static func gesamt(spieler: Dictionary) -> float:
	var gemerkt: float = float(spieler.get("staerke", -1.0))
	if gemerkt >= 0.0:
		return gemerkt
	var frisch: float = gesamt_rechnen(spieler)
	spieler["staerke"] = frisch
	return frisch

## Die Rechnung selbst, ohne Gedächtnis — für die Prüfung und das Verwerfen.
static func gesamt_rechnen(spieler: Dictionary) -> float:
	if bool(spieler["ist_torwart"]):
		return angriffswert(spieler)
	var pos: String = str(spieler["position"])
	var abwehr_anteil: float = 0.34
	if pos == "KM":
		abwehr_anteil = 0.44
	elif pos == "LA" or pos == "RA":
		abwehr_anteil = 0.24
	return angriffswert(spieler) * (1.0 - abwehr_anteil) + abwehrwert(spieler) * abwehr_anteil

## Nach jeder Attributänderung aufzurufen: der gemerkte Gesamtwert gilt nicht
## mehr. Wer das vergisst, spielt mit veralteten Stärken weiter.
static func staerke_verwerfen(spieler: Dictionary) -> void:
	spieler["staerke"] = -1.0

## Spieler-IDs nach Gesamtstärke, der Stärkste zuerst.
##
## Das Entscheidende ist das "einmal": `sort_custom` ruft seinen Vergleich
## n·log n mal auf, und `gesamt()` summiert dabei jedes Mal zwanzig Attribute.
## Bei dreitausend Spielern sind das über hunderttausend Attributschleifen für
## eine einzige Liste. Einmal rechnen, dann nach dem fertigen Wert sortieren.
static func nach_staerke(d: Dictionary, ids: Array) -> Array:
	var paare: Array = []
	for sid in ids:
		var sp: Dictionary = d["spieler"].get(str(sid), {})
		if sp.is_empty():
			continue
		paare.append({"id": str(sid), "wert": gesamt(sp)})
	paare.sort_custom(func(a, b): return float(a["wert"]) > float(b["wert"]))
	var aus: Array = []
	for e in paare:
		aus.append(str((e as Dictionary)["id"]))
	return aus

## Dieselbe Sortierung für eine beliebige, teuer zu berechnende Kennzahl.
## `schluessel` bekommt eine ID und liefert die Zahl, nach der absteigend
## sortiert wird — berechnet genau einmal je Eintrag.
static func nach_kennzahl(ids: Array, schluessel: Callable) -> Array:
	var paare: Array = []
	for id in ids:
		paare.append({"id": id, "wert": float(schluessel.call(id))})
	paare.sort_custom(func(a, b): return float(a["wert"]) > float(b["wert"]))
	var aus: Array = []
	for e in paare:
		aus.append((e as Dictionary)["id"])
	return aus

## Wie gut spielt jemand auf einer fremden Position? 0..1
static func eignung(spieler: Dictionary, position: String) -> float:
	var eigen: String = str(spieler["position"])
	if eigen == position:
		return 1.0
	if bool(spieler["ist_torwart"]) != (position == "TW"):
		return 0.05
	var basis: float = float((POSITION_NAEHE.get(eigen, {}) as Dictionary).get(position, 0.2))
	if position in spieler["zweitpositionen"]:
		basis = maxf(basis, 0.86)
	# Die Wurfhand: rechts spielen Linkshänder, links Rechtshänder. Wer auf die
	# falsche Seite gestellt wird, verliert den Wurfwinkel; wer auf die richtige
	# kommt, hat ihn — ein linker Rückraum, der Linkshänder ist, taugt
	# rechts mehr als die Positionsnähe allein sagt. Die Rückraummitte ist
	# beidseitig und bleibt unberührt.
	var links: bool = linkshaender(spieler)
	if position in ["RR", "RA"]:
		basis = basis * 0.84 if not links else maxf(basis, minf(basis + 0.15, 0.8))
	elif position in ["LA", "RL"]:
		basis = basis * 0.88 if links else basis
	return clampf(basis, 0.05, 1.0)

## Effektiver Angriffswert auf einer konkreten Position (inkl. Eignungsabschlag).
static func angriff_auf(spieler: Dictionary, position: String) -> float:
	var e: float = eignung(spieler, position)
	return angriffswert(spieler, position) * (0.55 + 0.45 * e)

static func alters_faktor(alter_jahre: int) -> float:
	if alter_jahre <= 19:
		return 0.86
	elif alter_jahre <= 22:
		return 0.94
	elif alter_jahre <= 25:
		return 1.0
	elif alter_jahre <= 29:
		return 1.04
	elif alter_jahre <= 31:
		return 1.0
	elif alter_jahre <= 33:
		return 0.93
	elif alter_jahre <= 35:
		return 0.84
	return 0.74

## Marktwert in Euro.
static func marktwert(spieler: Dictionary) -> float:
	var g: float = gesamt(spieler)
	var alter_jahre: int = int(spieler["alter"])
	var basis: float = pow(maxf(g - 28.0, 1.0), 2.45) * 28.0
	var alters_mod := 1.0
	if alter_jahre <= 20:
		alters_mod = 1.5
	elif alter_jahre <= 23:
		alters_mod = 1.35
	elif alter_jahre <= 27:
		alters_mod = 1.15
	elif alter_jahre <= 30:
		alters_mod = 0.92
	elif alter_jahre <= 32:
		alters_mod = 0.65
	elif alter_jahre <= 34:
		alters_mod = 0.38
	else:
		alters_mod = 0.18
	# Potenzial hebt junge Spieler zusaetzlich
	var pot_mod: float = 1.0 + clampf((float(spieler["potenzial"]) - g) / 100.0, 0.0, 0.35) * (1.6 if alter_jahre < 24 else 0.5)
	var vertrag: Dictionary = spieler.get("vertrag", {})
	var rest_mod := 1.0
	if not vertrag.is_empty():
		var rest: int = int(vertrag.get("bis_saison", 0)) - int(Welt.saison_index())
		rest_mod = clampf(0.55 + 0.22 * float(rest), 0.35, 1.15)
	var form_mod: float = 0.92 + 0.16 * (float(spieler["form"]) / 100.0)
	return maxf(basis * alters_mod * pot_mod * rest_mod * form_mod, 4000.0)

## Wochengehalt, das ein Spieler erwartet.
##
## `niveau` ist das Lohnniveau des Vereins (siehe Finanzen.lohnniveau): in der
## polnischen zweiten Liga verdient dieselbe Stärke ein Bruchteil dessen, was
## sie in Kiel bekäme. Ohne diesen Faktor zahlten kleine und auswärtige Vereine
## Gehälter, die ihre Einnahmen um ein Mehrfaches übersteigen.
static func gehaltsvorstellung(spieler: Dictionary, vereinsruf: float, niveau: float = 1.0) -> float:
	var g: float = gesamt(spieler)
	var basis: float = pow(maxf(g - 30.0, 1.0), 2.15) * 1.6 + 300.0
	var ehrgeiz: float = float((spieler["charakter"] as Dictionary).get("ehrgeiz", 12.0))
	var gier: float = 0.86 + ehrgeiz / 42.0
	var ruf_mod: float = clampf(1.25 - vereinsruf / 260.0, 0.82, 1.25)
	return maxf(basis * gier * ruf_mod * niveau, 180.0)

static func voller_name(spieler: Dictionary) -> String:
	return "%s %s" % [spieler["vorname"], spieler["nachname"]]

static func kurz_name(spieler: Dictionary) -> String:
	var v: String = str(spieler["vorname"])
	return "%s. %s" % [v.substr(0, 1), spieler["nachname"]]

## Durchschnittsnote der laufenden Saison (1,0 = sehr gut ... 6,0 = ungenuegend).
static func note(spieler: Dictionary) -> float:
	var s: Dictionary = spieler["stats"]["saison"]
	if int(s["noten"]) <= 0:
		return 0.0
	return float(s["note_summe"]) / float(s["noten"])

## Zustandswert 0..100: wie einsatzbereit ist der Spieler gerade wirklich?
static func einsatzform(spieler: Dictionary) -> float:
	var fit: float = float(spieler["fitness"])
	var form: float = float(spieler["form"])
	var last: float = float(spieler["last"])
	return clampf(fit * 0.45 + form * 0.35 + (100.0 - last) * 0.2, 0.0, 100.0)

## Leistungsmodifikator, der in die Simulation eingeht (0.7 .. 1.18).
static func tagesform(spieler: Dictionary) -> float:
	var form: float = float(spieler["form"]) / 100.0
	var moral: float = float(spieler["moral"]) / 100.0
	var fit: float = float(spieler["fitness"]) / 100.0
	var last: float = float(spieler["last"]) / 100.0
	return clampf(0.70 + 0.22 * form + 0.12 * moral + 0.16 * fit - 0.14 * last, 0.62, 1.20)
