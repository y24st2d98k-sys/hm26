class_name Zweite
extends RefCounted
## Die zweite Mannschaft — und warum die Akademie ohne sie eine Sackgasse war.
##
## Bis hierher wurden Talente gesichtet, entwickelt und bewertet, und dann
## bekamen sie nie eine Pflichtspielminute. Man konnte einen Achtzehnjährigen
## hochziehen oder vergessen, aber nie herausfinden, ob er trägt. Damit war die
## gesamte Nachwuchssäule Aufwand ohne Rückkopplung.
##
## Die Zweite schließt das. Sie spielt in einer Reserverunde, die die Runde der
## Profis spiegelt: wann immer die Erste ein Ligaspiel hat, tritt am selben Tag
## die Zweite gegen die Zweite desselben Gegners an. Das braucht keinen
## eigenen Spielplan, hält die Tabelle synchron und kostet nichts.
##
## Wer aufläuft, schlägt die Automatik vor: alle Jugendspieler, dazu Profis,
## die kaum Einsatzzeit bekommen oder aus einer Verletzung zurückkommen. Der
## Trainer überstimmt sie mit einer Rolle je Spieler — und das ist der
## eigentliche Zweck einer Reservemannschaft. Wer einen Siebzehnjährigen
## aufbauen will, stellt ihn auf; wer ihn schonen will, lässt ihn draußen.
## Bis hierher konnte man nur sperren, und damit war die einzige Entscheidung
## "spielt gar nicht".
##
## Die Partien der Zweiten laufen nicht durch die volle Simulation. Das wäre
## bei 68 Paarungen je Spieltag eine zweite Sekunde Rechenzeit für etwas, das
## niemand anschaut. Stattdessen löst ein schlanker Rechner Ergebnis, Minuten,
## Tore und Noten auf — dieselben Größen, die auch aus einem Profispiel
## herausfallen, nur ohne Angriff-für-Angriff-Verlauf.

## Wie viele auflaufen. Handball spielt sieben, der Rest sitzt.
const AUFGEBOT := 12
## Ab wie vielen Profiminuten in der Saison ein Profi nicht mehr in der
## Zweiten gebraucht wird.
const MINUTENGRENZE := 240.0
## Bis zu welchem Alter ein Profi ohne Einsatzzeit selbstverständlich in der
## Zweiten spielt.
const JUNGPROFI_ALTER := 23

static func leere_bilanz() -> Dictionary:
	return {"spiele": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0,
		"tore": 0, "gegentore": 0, "punkte": 0}

## Die Bilanz der Zweiten eines Vereins. Legt sie an, wenn sie fehlt.
static func bilanz(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("zweite") or (v["zweite"] as Dictionary).is_empty():
		v["zweite"] = {"bilanz": leere_bilanz(), "letzte": []}
	if not (v["zweite"] as Dictionary).has("bilanz"):
		v["zweite"]["bilanz"] = leere_bilanz()
	return v["zweite"]["bilanz"]

static func zuruecksetzen(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		d["vereine"][cid]["zweite"] = {"bilanz": leere_bilanz(), "letzte": []}

# --------------------------------------------------------------- Aufgebot ---

## Wer für die Zweite in Frage kommt, in der Reihenfolge, in der aufgestellt
## wird: erst die Jugend, dann Profis ohne Einsatzzeit.
##
## Ein Talent, das oben schon spielt, gehört nicht mehr hierher — deshalb
## fällt jeder heraus, der in der Ersten genug Minuten sammelt.
static func kandidaten(d: Dictionary, cid: String) -> Array:
	var v: Dictionary = d["vereine"][cid]
	var liste: Array = []
	for sid in v.get("jugend", []):
		if _einsatzfaehig(d, str(sid)) and not _gesperrt(d, str(sid)):
			liste.append(str(sid))
	for sid2 in v["kader"]:
		if not _einsatzfaehig(d, str(sid2)) or _gesperrt(d, str(sid2)):
			continue
		var sp: Dictionary = d["spieler"][sid2]
		var minuten: float = float(((sp["stats"]["saison"]) as Dictionary).get("minuten", 0.0))
		# Wen der Trainer ausdrücklich aufstellt, der spielt — auch wenn er
		# nach der Automatik längst genug Profiminuten hätte. Eine Vorgabe,
		# die eine Faustregel nicht überstimmt, ist keine Vorgabe.
		if rolle(d, str(sid2)) == "gesetzt":
			liste.append(str(sid2))
		elif minuten <= MINUTENGRENZE and int(sp["alter"]) <= JUNGPROFI_ALTER:
			liste.append(str(sid2))
		elif minuten <= 40.0:
			# Auch ein erfahrener Spieler, der monatelang nicht gespielt hat,
			# braucht irgendwo Rhythmus.
			liste.append(str(sid2))
	return liste

static func _einsatzfaehig(d: Dictionary, sid: String) -> bool:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty():
		return false
	return (sp["verletzung"] as Dictionary).is_empty() and int(sp["sperre"]) <= 0

static func _gesperrt(d: Dictionary, sid: String) -> bool:
	return rolle(d, sid) == "nie"

## Die vier Rollen in der Reservemannschaft.
##
## Sie steuern nicht, *ob* jemand im Aufgebot steht, sondern *wo*. Das ist
## dasselbe: die ersten sieben spielen zweiundfünfzig Minuten, der Rest kommt
## in Abschnitten, und die letzten stehen bei acht. Wer oben steht, spielt.
const ROLLEN := [
	{"id": "gesetzt", "name": "Gesetzt", "satz": "Steht in den ersten Sieben."},
	{"id": "normal", "name": "Rotation", "satz": "Spielt, wenn Platz ist — nach Stärke."},
	{"id": "selten", "name": "Selten", "satz": "Nur wenn sonst niemand da ist."},
	{"id": "nie", "name": "Gar nicht", "satz": "Steht nicht im Aufgebot."},
]
const ROLLE_STANDARD := "normal"

static func rolle(d: Dictionary, sid: String) -> String:
	var sp: Dictionary = (d.get("spieler", {}) as Dictionary).get(sid, {})
	if sp.is_empty():
		return ROLLE_STANDARD
	# Ältere Spielstände kennen nur den Sperrschalter.
	if not sp.has("zweite_rolle"):
		return "nie" if bool(sp.get("nicht_zweite", false)) else ROLLE_STANDARD
	var r: String = str(sp["zweite_rolle"])
	for e in ROLLEN:
		if str((e as Dictionary)["id"]) == r:
			return r
	return ROLLE_STANDARD

static func rolle_setzen(d: Dictionary, sid: String, r: String) -> void:
	if not (d.get("spieler", {}) as Dictionary).has(sid):
		return
	d["spieler"][sid]["zweite_rolle"] = r
	# Den alten Schalter mitführen, damit nichts auseinanderläuft.
	d["spieler"][sid]["nicht_zweite"] = r == "nie"

## Wie weit vorn eine Rolle im Aufgebot steht. Klein ist vorn.
static func _rang(r: String) -> int:
	match r:
		"gesetzt": return 0
		"normal": return 1
		"selten": return 2
	return 3

## Sperrt einen Spieler für die Zweite oder gibt ihn wieder frei.
static func freistellen(d: Dictionary, sid: String, gesperrt: bool) -> void:
	rolle_setzen(d, sid, "nie" if gesperrt else ROLLE_STANDARD)

## Das tatsächliche Aufgebot einer Partie: die stärksten Kandidaten, aber immer
## mit einem Torwart, sonst steht das Tor leer.
static func aufgebot(d: Dictionary, cid: String) -> Array:
	var alle := kandidaten(d, cid)
	var feld: Array = []
	var tore: Array = []
	for sid in alle:
		if bool(d["spieler"][sid]["ist_torwart"]):
			tore.append(sid)
		else:
			feld.append(sid)
	# Erst die Rolle, dann die Stärke. Die Reihenfolge ist die Einsatzzeit:
	# _spieler_verbuchen gibt den ersten sieben zweiundfünfzig Minuten und
	# staffelt den Rest nach unten ab.
	feld = _ordnen(d, feld)
	tore = _ordnen(d, tore)
	var raus: Array = []
	if not tore.is_empty():
		raus.append(tore[0])
	for sid2 in feld:
		if raus.size() >= AUFGEBOT:
			break
		raus.append(sid2)
	return raus

## Beide Schlüssel in einem Vergleich: Godots Sortierung ist nicht stabil,
## zweimal hintereinander zu sortieren verwirft also die erste Ordnung.
static func _ordnen(d: Dictionary, liste: Array) -> Array:
	var sortiert: Array = liste.duplicate()
	sortiert.sort_custom(func(a, b):
		var ra: int = _rang(rolle(d, str(a)))
		var rb: int = _rang(rolle(d, str(b)))
		if ra != rb:
			return ra < rb
		return Spielerfabrik.gesamt(d["spieler"][str(a)]) > Spielerfabrik.gesamt(d["spieler"][str(b)]))
	return sortiert

## Die Spielstärke der Zweiten. Torhüter zählt doppelt, wie in jedem
## Handballspiel.
##
## `kader` kann übergeben werden, wenn das Aufgebot schon feststeht. Das ist
## kein Zierrat: an einem Spieltag laufen 68 Reservepartien, und das Aufgebot
## jedes Mal neu zu ermitteln heißt, denselben Kader viermal zu sortieren.
static func staerke(d: Dictionary, cid: String, vorgabe: Array = []) -> float:
	var kader: Array = vorgabe if not vorgabe.is_empty() else aufgebot(d, cid)
	if kader.is_empty():
		# Kein Aufgebot heißt: der Verein tritt mit angezogener Handbremse an.
		return 28.0
	var summe := 0.0
	var gewicht := 0.0
	for sid in kader:
		var sp: Dictionary = d["spieler"][sid]
		var g: float = 2.0 if bool(sp["ist_torwart"]) else 1.0
		# Nur die ersten Sieben tragen wirklich; die Bank zählt abgeschwächt.
		if gewicht > 7.0:
			g *= 0.35
		summe += Spielerfabrik.gesamt(sp) * g
		gewicht += g
	return summe / maxf(gewicht, 1.0)

# ---------------------------------------------------------------- Partie ---

## Löst die Reservepartie zu einem Ligaspiel auf.
##
## Aufgerufen wird das immer dann, wenn die Erste ein Ligaspiel ausgetragen
## hat. Pokal- und Europapartien haben keine Reserveentsprechung — dort tritt
## die Zweite nicht an.
static func partie(d: Dictionary, m: Dictionary) -> void:
	if str(m.get("art", "")) != "liga":
		return
	var h: String = str(m["heim"])
	var g: String = str(m["gast"])
	if not d["vereine"].has(h) or not d["vereine"].has(g):
		return
	var h_kader := aufgebot(d, h)
	var g_kader := aufgebot(d, g)
	var hs := staerke(d, h, h_kader)
	var gs := staerke(d, g, g_kader)
	# Reserveteams schwanken deutlich stärker als Profimannschaften: halbe
	# Kader aus Sechzehnjährigen, wechselnde Aufgebote, keine Routine.
	var diff: float = (hs - gs) + 2.6 + Namen.glocke(0.0, 6.5, -22.0, 22.0)
	var basis: float = 26.0 + clampf((hs + gs) / 2.0 - 40.0, -8.0, 10.0) * 0.22
	var tore_h: int = maxi(int(round(basis + diff * 0.30 + Namen.bereich(-3.0, 3.0))), 8)
	var tore_g: int = maxi(int(round(basis - diff * 0.30 + Namen.bereich(-3.0, 3.0))), 8)
	_verbuchen(d, h, tore_h, tore_g, g)
	_verbuchen(d, g, tore_g, tore_h, h)
	_spieler_verbuchen(d, h_kader, tore_h, tore_h > tore_g)
	_spieler_verbuchen(d, g_kader, tore_g, tore_g > tore_h)

static func _verbuchen(d: Dictionary, cid: String, eigene: int, fremde: int, gegner: String) -> void:
	var b := bilanz(d, cid)
	b["spiele"] = int(b["spiele"]) + 1
	b["tore"] = int(b["tore"]) + eigene
	b["gegentore"] = int(b["gegentore"]) + fremde
	if eigene > fremde:
		b["siege"] = int(b["siege"]) + 1
		b["punkte"] = int(b["punkte"]) + 2
	elif eigene == fremde:
		b["unentschieden"] = int(b["unentschieden"]) + 1
		b["punkte"] = int(b["punkte"]) + 1
	else:
		b["niederlagen"] = int(b["niederlagen"]) + 1
	var letzte: Array = d["vereine"][cid]["zweite"]["letzte"]
	letzte.push_front({"gegner": gegner, "eigene": eigene, "fremde": fremde, "tag": int(d["tag"])})
	while letzte.size() > 8:
		letzte.pop_back()

## Verteilt Minuten, Tore und Noten auf das Aufgebot.
##
## Das ist der eigentliche Zweck des ganzen Systems: erst wenn ein Talent eine
## Zahl hinter seinem Namen stehen hat, kann man beurteilen, ob er trägt.
static func _spieler_verbuchen(d: Dictionary, kader: Array, tore: int, gewonnen: bool) -> void:
	if kader.is_empty():
		return
	var werfer: Array = []
	for sid in kader:
		if not bool(d["spieler"][sid]["ist_torwart"]):
			werfer.append(sid)
	for i in range(kader.size()):
		var sid2: String = str(kader[i])
		var sp: Dictionary = d["spieler"][sid2]
		var konto: Dictionary = statistik(sp)
		# Die ersten Sieben spielen fast durch, die Bank kommt in Abschnitten.
		var minuten: float = 52.0 if i < 7 else clampf(38.0 - float(i - 7) * 7.0, 8.0, 38.0)
		konto["spiele"] = int(konto["spiele"]) + 1
		konto["minuten"] = float(konto["minuten"]) + minuten
		var note: float = clampf(3.2 + (0.6 if gewonnen else -0.2) + Namen.bereich(-1.1, 1.4), 1.0, 10.0)
		konto["notensumme"] = float(konto["notensumme"]) + note
		# Ein Pflichtspiel ist mehr wert als eine Trainingswoche: der Spieler
		# lernt das Tempo, und der Verein lernt den Spieler kennen.
		sp["kenntnis"] = clampf(float(sp["kenntnis"]) + 1.4, 0.0, 100.0)
		sp["last"] = clampf(float(sp["last"]) + minuten * 0.16, 0.0, 100.0)
		sp["fitness"] = clampf(float(sp["fitness"]) - minuten * 0.05, 30.0, 100.0)
	# Die Tore auf die Feldspieler, gewichtet nach Abschlussstärke.
	if werfer.is_empty():
		return
	var gewichte: Array = []
	var gesamt := 0.0
	for sid3 in werfer:
		# Flach gewichtet: in einer Reservemannschaft wirft jeder. Nähme man
		# die Abschlussstärke direkt, holte der beste Rückraumspieler die
		# Hälfte aller Tore, und die Statistik saegte am eigenen Zweck — man
		# will sehen, wer trifft, nicht wer am längsten auf dem Feld steht.
		var w: float = 4.0 + Spielerfabrik.angriff_auf(d["spieler"][sid3],
			str(d["spieler"][sid3]["position"])) / 12.0
		gewichte.append(w)
		gesamt += w
	for _t in range(tore):
		var wurf: float = Namen.zufall() * gesamt
		var summe := 0.0
		for i2 in range(werfer.size()):
			summe += float(gewichte[i2])
			if wurf <= summe:
				var k: Dictionary = statistik(d["spieler"][str(werfer[i2])])
				k["tore"] = int(k["tore"]) + 1
				break

## Das Reservekonto eines Spielers. Legt es an, wenn es fehlt.
static func statistik(sp: Dictionary) -> Dictionary:
	if not sp.has("zweite") or typeof(sp["zweite"]) != TYPE_DICTIONARY:
		sp["zweite"] = {"spiele": 0, "minuten": 0.0, "tore": 0, "notensumme": 0.0}
	return sp["zweite"]

static func note(sp: Dictionary) -> float:
	var k := statistik(sp)
	if int(k["spiele"]) <= 0:
		return 0.0
	return float(k["notensumme"]) / float(k["spiele"])

## Setzt die Spielerkonten zum Saisonwechsel zurück.
static func saison_zuruecksetzen(d: Dictionary) -> void:
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if sp.has("zweite"):
			sp["zweite"] = {"spiele": 0, "minuten": 0.0, "tore": 0, "notensumme": 0.0}

# ---------------------------------------------------------------- Tabelle ---

## Die Reservetabelle einer Liga. Sie steht neben der Profitabelle, weil die
## Reserverunde deren Paarungen spiegelt.
static func tabelle(d: Dictionary, lid: String) -> Array:
	var liga: Dictionary = d["ligen"].get(lid, {})
	if liga.is_empty():
		return []
	var zeilen: Array = []
	for cid in liga.get("vereine", []):
		var b := bilanz(d, str(cid))
		zeilen.append({
			"verein": str(cid),
			"spiele": int(b["spiele"]), "punkte": int(b["punkte"]),
			"siege": int(b["siege"]), "unentschieden": int(b["unentschieden"]),
			"niederlagen": int(b["niederlagen"]),
			"tore": int(b["tore"]), "gegentore": int(b["gegentore"]),
			"diff": int(b["tore"]) - int(b["gegentore"]),
		})
	zeilen.sort_custom(func(x, y):
		if int(x["punkte"]) != int(y["punkte"]):
			return int(x["punkte"]) > int(y["punkte"])
		if int(x["diff"]) != int(y["diff"]):
			return int(x["diff"]) > int(y["diff"])
		return int(x["tore"]) > int(y["tore"]))
	return zeilen

## Wie viel schneller sich ein Talent mit Spielpraxis entwickelt.
##
## Das ist die Rückkopplung, die vorher fehlte: Training allein bringt einen
## Spieler nur bis zu einem Punkt, ab dem er Spiele braucht. Der Faktor greift
## in Jugend.wochenwechsel.
static func entwicklungsschub(sp: Dictionary) -> float:
	var k := statistik(sp)
	var minuten: float = float(k["minuten"])
	if minuten <= 0.0:
		# Wer gar nicht spielt, entwickelt sich langsamer als jemand mit
		# Wettkampfpraxis. Das ist kein Malus auf den Trainingsertrag, das ist
		# der fehlende Teil davon.
		return 0.82
	return clampf(0.82 + minuten / 900.0, 0.82, 1.30)
