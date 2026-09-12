class_name Matchsim
extends RefCounted
## Die Spielsimulation von Hallenherz.
##
## Sie laeuft angriffsweise ab (ca. 110 Angriffe pro Partie) und liefert Ereignisse,
## die entweder still weggerechnet (KI-Partien) oder Stueck fuer Stueck in der
## Live-Ansicht abgespielt werden. Dieselbe Engine bedient beide Faelle.
##
## Handballspezifisch abgebildet:
##  * getrennte Angriffs- und Abwehrformation mit echtem Wechselaufwand
##  * Zeitstrafen mit echter Unterzahl (auch doppelte und dreifache)
##  * 7-gegen-6 (Torwart raus) samt Risiko des Wurfs ins leere Tor
##  * Siebenmeter, Blocks, technische Fehler, Tempogegenstoesse
##  * Kraefteverschleiss ueber 60 Minuten und Auszeiten
##  * "Hallenpuls" — die Atmosphaere in der Halle als eigener Leistungsfaktor

const SPIELZEIT := 3600.0
## Umrechnung der Anweisungs-Wurfguete in Punkte der internen Gueteskala.
const ANWEISUNG_GUETE := 2.0
const HALBZEIT := 1800.0

const DECKUNG := {
	"6-0": {"block": 1.12, "ballgewinn": 0.84, "zeitstrafe": 0.92, "kreis": 1.10, "aussen": 0.92, "fern": 0.90, "kraft": 0.95},
	"5-1": {"block": 1.02, "ballgewinn": 1.06, "zeitstrafe": 1.04, "kreis": 0.98, "aussen": 0.98, "fern": 1.06, "kraft": 1.0},
	"3-2-1": {"block": 0.94, "ballgewinn": 1.24, "zeitstrafe": 1.26, "kreis": 0.88, "aussen": 1.02, "fern": 1.16, "kraft": 1.12},
	"4-2": {"block": 0.88, "ballgewinn": 1.40, "zeitstrafe": 1.46, "kreis": 0.82, "aussen": 1.06, "fern": 1.20, "kraft": 1.2},
}

const ANGRIFF_GEGEN_DECKUNG := {
	"positionsangriff": {"6-0": 1.00, "5-1": 1.00, "3-2-1": 1.00, "4-2": 1.00},
	"tempospiel": {"6-0": 1.05, "5-1": 1.02, "3-2-1": 0.97, "4-2": 0.94},
	"kreisfokus": {"6-0": 0.93, "5-1": 1.02, "3-2-1": 1.09, "4-2": 1.14},
	"aussenfokus": {"6-0": 1.07, "5-1": 1.02, "3-2-1": 0.96, "4-2": 0.94},
	"rueckraumfokus": {"6-0": 1.08, "5-1": 0.99, "3-2-1": 0.91, "4-2": 0.88},
}

## Wie oft wirft welche Position, je nach Angriffsausrichtung.
const WURFVERTEILUNG := {
	"positionsangriff": {"LA": 0.13, "RL": 0.19, "RM": 0.15, "RR": 0.19, "RA": 0.13, "KM": 0.21},
	"tempospiel": {"LA": 0.19, "RL": 0.16, "RM": 0.16, "RR": 0.16, "RA": 0.19, "KM": 0.14},
	"kreisfokus": {"LA": 0.10, "RL": 0.15, "RM": 0.12, "RR": 0.15, "RA": 0.10, "KM": 0.38},
	"aussenfokus": {"LA": 0.26, "RL": 0.13, "RM": 0.11, "RR": 0.13, "RA": 0.26, "KM": 0.11},
	"rueckraumfokus": {"LA": 0.08, "RL": 0.27, "RM": 0.21, "RR": 0.27, "RA": 0.08, "KM": 0.09},
}

const MENTALITAET := {
	"defensiv": {"tempo": -18, "risiko": -18, "abwehr": 1.07, "angriff": 0.94},
	"ausgeglichen": {"tempo": 0, "risiko": 0, "abwehr": 1.0, "angriff": 1.0},
	"offensiv": {"tempo": 12, "risiko": 14, "abwehr": 0.95, "angriff": 1.06},
	"all-in": {"tempo": 26, "risiko": 32, "abwehr": 0.86, "angriff": 1.13},
}

## Wurfposition auf dem Feld (normiert 0..1 in Spielfeldkoordinaten der Angriffshaelfte).
const POSITION_KOORDINATE := {
	"LA": Vector2(0.10, 0.14), "RL": Vector2(0.27, 0.26), "RM": Vector2(0.50, 0.30),
	"RR": Vector2(0.73, 0.26), "RA": Vector2(0.90, 0.14), "KM": Vector2(0.50, 0.11),
	"TW": Vector2(0.50, 0.02),
}

var daten: Dictionary
var spiel: Dictionary
var rng := RandomNumberGenerator.new()

var heim: Dictionary = {}
var gast: Dictionary = {}
var zeit: float = 0.0
var beendet: bool = false
var halbzeit_gespielt: bool = false
var angriffsrecht: String = "heim"
var ereignisse: Array = []
var _warteschlange: Array = []
var _gegenstoss: bool = false
var lauf: Dictionary = {"team": "", "tore": 0}
var hallenpuls: float = 50.0
var zuschauer: int = 0
var live: bool = false

func _init(p_daten: Dictionary, p_spiel: Dictionary, saat: int = 0) -> void:
	daten = p_daten
	spiel = p_spiel
	if saat != 0:
		rng.seed = saat
	else:
		rng.randomize()

# ------------------------------------------------------------ Vorbereitung ---

func vorbereiten() -> void:
	heim = _team_zustand(str(spiel["heim"]), true)
	gast = _team_zustand(str(spiel["gast"]), false)
	zuschauer = _zuschauer_berechnen()
	hallenpuls = clampf(float(daten["vereine"][spiel["heim"]]["hallenpuls_basis"]) * (0.7 + 0.3 * _auslastung()), 20.0, 95.0)
	angriffsrecht = "heim" if rng.randf() < 0.5 else "gast"
	zeit = 0.0
	beendet = false
	_warteschlange.append(_ereignis("anwurf", angriffsrecht, "", "Anwurf in der %s. %s Zuschauer sind da." % [
		daten["vereine"][spiel["heim"]]["halle"]["name"], Stil.zahl(zuschauer)]))

func _auslastung() -> float:
	var kap: float = maxf(float(daten["vereine"][spiel["heim"]]["halle"]["kapazitaet"]), 1.0)
	return clampf(float(zuschauer) / kap, 0.0, 1.0)

func _zuschauer_berechnen() -> int:
	var v: Dictionary = daten["vereine"][spiel["heim"]]
	var g: Dictionary = daten["vereine"][spiel["gast"]]
	var kap: int = int(v["halle"]["kapazitaet"])
	var basis: float = 0.36 + float(v["fans"]["zufriedenheit"]) / 260.0 + float(v["fans"]["treue"]) / 320.0
	basis += clampf((float(g["ruf"]) - 45.0) / 300.0, -0.05, 0.18)
	if float((v["rivalen"] as Dictionary).get(g["id"], 0.0)) > 50.0:
		basis += 0.14
	if str(spiel["art"]) == "international":
		basis += 0.1
	basis *= rng.randf_range(0.9, 1.08)
	return int(clampf(basis, 0.15, 1.0) * float(kap))

func _team_zustand(cid: String, ist_heim: bool) -> Dictionary:
	var verein: Dictionary = daten["vereine"][cid]
	var auf: Dictionary = verein["aufstellung"]
	var taktik: Dictionary = (verein["taktik"] as Dictionary).duplicate(true)
	var t := {
		"cid": cid,
		"ist_heim": ist_heim,
		"name": verein["name"],
		"kurz": verein["kurz"],
		"taktik": taktik,
		"angriff_auf": {},
		"abwehr_auf": {},
		"bank": [],
		"zustand": {},
		"gesperrt": [],
		"tore": 0,
		"auszeiten": 3,
		"auszeit_wirkung": 0.0,
		"stats": {"wuerfe": 0, "tore": 0, "technische_fehler": 0, "zeitstrafen": 0, "rote": 0,
			"siebenmeter": 0, "siebenmeter_tore": 0, "paraden": 0, "blocks": 0, "gegenstoss_tore": 0,
			"ballgewinne": 0, "wechsel": 0, "puls_hoch": 0.0},
		# Wurfkarte: je Abschlussposition gezaehlt, was daraus geworden ist.
		# Nur Summen, keine Einzelwuerfe — der Spielstand soll schlank bleiben.
		"wurfkarte": {},
		"siebenmeter_schuetze": str(auf.get("siebenmeter", "")),
		"sieben_gegen_sechs": false,
		"letzte_wechselpruefung": -999.0,
		"ansprache": 0.0,
		"ansprachen": [],
		# Individuelle Spieleranweisungen (siehe kern/Anweisungen.gd)
		"anweisungen": (auf.get("anweisungen", {}) as Dictionary).duplicate(true),
	}
	var angriff: Dictionary = auf.get("angriff", {})
	var abwehr: Dictionary = auf.get("abwehr", {})
	if angriff.is_empty() or not angriff.has("TW"):
		angriff = Weltgenerator.beste_angriffsformation(daten, cid)
		abwehr = Weltgenerator.beste_abwehrformation(daten, cid, angriff)
	# Nur einsatzfaehige Spieler
	var ersatz_pool: Array = []
	for sid in verein["kader"]:
		var sp: Dictionary = daten["spieler"][sid]
		if not (sp["verletzung"] as Dictionary).is_empty() or int(sp["sperre"]) > 0:
			continue
		ersatz_pool.append(sid)
	for pos in angriff.keys():
		var sid: String = str(angriff[pos])
		if sid == "" or not ersatz_pool.has(sid):
			sid = _ersatz_fuer(ersatz_pool, angriff.values(), pos)
		if sid != "":
			t["angriff_auf"][pos] = sid
	for pos in abwehr.keys():
		var sid: String = str(abwehr[pos])
		if sid == "" or not ersatz_pool.has(sid):
			sid = _ersatz_fuer(ersatz_pool, abwehr.values(), pos)
		if sid != "":
			t["abwehr_auf"][pos] = sid
	if not t["abwehr_auf"].has("TW"):
		t["abwehr_auf"]["TW"] = t["angriff_auf"].get("TW", "")
	for sid in ersatz_pool:
		if not (t["angriff_auf"] as Dictionary).values().has(sid) and not (t["abwehr_auf"] as Dictionary).values().has(sid):
			t["bank"].append(sid)
	for sid in ersatz_pool:
		var sp_cache: Dictionary = daten["spieler"][sid]
		t["zustand"][sid] = {
			"kraft": clampf(float(sp_cache["fitness"]) - float(sp_cache["last"]) * 0.18, 40.0, 100.0),
			"tagesform": Spielerfabrik.tagesform(sp_cache),
			"basis_abwehr": Spielerfabrik.abwehrwert(sp_cache),
			"basis_angriff": {},
			"sekunden": 0.0, "tore": 0, "wuerfe": 0, "assists": 0, "paraden": 0, "gegentore": 0,
			"blocks": 0, "fehler": 0, "zeitstrafen": 0, "ballgewinne": 0, "rot": false,
			"bewertung": 3.4, "siebenmeter": 0, "siebenmeter_tore": 0,
		}
	if str(t["siebenmeter_schuetze"]) == "" or not t["zustand"].has(t["siebenmeter_schuetze"]):
		t["siebenmeter_schuetze"] = _bester_siebenmeter(t)
	return t

func _ersatz_fuer(pool: Array, belegt: Array, pos: String) -> String:
	var best := ""
	var bw := -1.0
	for sid in pool:
		if belegt.has(sid) or sid == "":
			continue
		var sp: Dictionary = daten["spieler"][sid]
		var ist_tw_platz: bool = pos == "TW"
		if bool(sp["ist_torwart"]) != ist_tw_platz:
			continue
		var w: float = Spielerfabrik.gesamt(sp) if pos.begins_with("A") or pos == "TW" else Spielerfabrik.angriff_auf(sp, pos)
		if w > bw:
			bw = w
			best = sid
	return best

func _bester_siebenmeter(t: Dictionary) -> String:
	var best := ""
	var bw := -1.0
	for sid in t["zustand"].keys():
		var sp: Dictionary = daten["spieler"][sid]
		if bool(sp["ist_torwart"]):
			continue
		var w: float = float(sp["attr"]["siebenmeter"]) * 2.0 + float(sp["attr"]["nervenstaerke"])
		if w > bw:
			bw = w
			best = sid
	return best

# --------------------------------------------------------------- Ablauf ---

## Liefert das naechste Ereignis oder ein leeres Dictionary, wenn das Spiel vorbei ist.
func naechstes_ereignis() -> Dictionary:
	while _warteschlange.is_empty() and not beendet:
		_angriff_simulieren()
	if _warteschlange.is_empty():
		return {}
	var e: Dictionary = _warteschlange.pop_front()
	ereignisse.append(e)
	return e

## Rechnet die komplette Partie ohne Ausgabe durch.
func schnell_simulieren() -> void:
	while not beendet:
		if _warteschlange.is_empty():
			_angriff_simulieren()
		while not _warteschlange.is_empty():
			ereignisse.append(_warteschlange.pop_front())

func _ereignis(typ: String, team: String, spieler_id: String, text: String, extra: Dictionary = {}) -> Dictionary:
	var e := {
		"zeit": zeit,
		"typ": typ,
		"team": team,
		"spieler": spieler_id,
		"text": text,
		"stand": [heim.get("tore", 0), gast.get("tore", 0)],
		"puls": hallenpuls,
	}
	for k in extra.keys():
		e[k] = extra[k]
	return e

func zeittext(sekunden: float) -> String:
	var m: int = int(sekunden / 60.0)
	var s: int = int(sekunden) % 60
	return "%02d:%02d" % [m, s]

func _angriff_simulieren() -> void:
	if beendet:
		return
	var a: Dictionary = heim if angriffsrecht == "heim" else gast
	var v: Dictionary = gast if angriffsrecht == "heim" else heim

	_strafzeiten_pruefen(a)
	_strafzeiten_pruefen(v)
	_wechsel_pruefen(a)
	_wechsel_pruefen(v)
	_auszeit_pruefen(a, v)

	var dauer: float = _angriffsdauer(a)
	if _gegenstoss:
		dauer = rng.randf_range(12.0, 20.0)
	zeit += dauer
	_kraft_verbrauchen(a, dauer, true)
	_kraft_verbrauchen(v, dauer, false)
	_puls_abklingen()
	heim["ansprache"] = float(heim["ansprache"]) * 0.965
	gast["ansprache"] = float(gast["ansprache"]) * 0.965
	if rng.randf() < 0.25:
		_verletzungspruefung(a)
		_verletzungspruefung(v)

	var ausgang := _angriff_ausspielen(a, v)
	_gegenstoss = bool(ausgang.get("gegenstoss", false))
	if bool(ausgang.get("ballwechsel", true)):
		angriffsrecht = "gast" if angriffsrecht == "heim" else "heim"

	if not halbzeit_gespielt and zeit >= HALBZEIT:
		halbzeit_gespielt = true
		zeit = HALBZEIT
		spiel["halbzeit"] = [heim["tore"], gast["tore"]]
		_warteschlange.append(_ereignis("halbzeit", "", "", "Halbzeit: %s %d:%d %s" % [
			heim["kurz"], heim["tore"], gast["tore"], gast["kurz"]]))
		_pause_erholung()
		angriffsrecht = "gast" if _erster_anwurf_heim() else "heim"
	if zeit >= SPIELZEIT:
		_spielende()

func _erster_anwurf_heim() -> bool:
	for e in ereignisse:
		if str(e["typ"]) == "anwurf":
			return str(e["team"]) == "heim"
	return true

func _angriffsdauer(a: Dictionary) -> float:
	var t: Dictionary = a["taktik"]
	var tempo: float = clampf(float(t["tempo"]) + float(MENTALITAET[str(t["mentalitaet"])]["tempo"]), 0.0, 100.0)
	var basis: float = 40.5 - 0.19 * tempo
	# Zeitspiel: wer fuehrt und langsam spielt, zieht die Angriffe in die Laenge
	var diff: int = int(a["tore"]) - (int(gast["tore"]) if a == heim else int(heim["tore"]))
	if diff >= 2 and zeit > SPIELZEIT - 420.0 and tempo < 45.0:
		basis += 10.0
	# Abschlussbereitschaft: eine Mannschaft, in der niemand den Wurf nimmt,
	# spielt sich fest. Das kostet Zeit — und damit Angriffe. Umgekehrt bringt
	# blindes Draufhalten kaum Tempo, sonst waere "Abschluss suchen" fuer alle
	# eine Gratisverbesserung.
	var bereitschaft: float = _anweisungsmittel(a, "angriff_auf", "angriff", "wurfanteil")
	basis += clampf((1.0 - bereitschaft) * 18.0, -3.0, 10.5)
	return clampf(basis + rng.randf_range(-6.0, 6.0), 9.0, 52.0)

# ---------------------------------------------------------- Angriffslogik ---

func _angriff_ausspielen(a: Dictionary, v: Dictionary) -> Dictionary:
	var a_feld: int = _feldspieler(a)
	var v_feld: int = _feldspieler(v)
	var ueberzahl: int = a_feld - v_feld

	var angriffskraft: float = _angriffskraft(a, v)
	var abwehrkraft: float = _abwehrkraft(v, a)
	var diff: float = angriffskraft - abwehrkraft
	var td: Dictionary = _deckungswerte(v)

	# Unter- bzw. Ueberzahl wirkt deutlich
	diff += float(ueberzahl) * 11.0
	if _gegenstoss:
		diff += 22.0
		if Trainerkarriere.bonus_fuer(daten, str(a["cid"]), "tempodiktat"):
			diff += 6.0

	# Technischer Fehler / Ballgewinn der Abwehr
	var risiko: float = clampf(float(a["taktik"]["risiko"]) + float(MENTALITAET[str(a["taktik"]["mentalitaet"])]["risiko"]), 0.0, 100.0)
	var p_fehler: float = clampf(0.185 - diff * 0.0008 + (risiko - 50.0) * 0.0009, 0.09, 0.26) * float(td["ballgewinn"])
	p_fehler *= _anweisungsmittel(a, "angriff_auf", "angriff", "fehler")
	if a["sieben_gegen_sechs"]:
		p_fehler *= 1.35
	if Trainerkarriere.bonus_fuer(daten, str(a["cid"]), "kontrolleur"):
		p_fehler *= 0.88
	if rng.randf() < p_fehler:
		return _ballverlust(a, v)

	# Freiwurf/Foul: Zeitstrafe oder Siebenmeter
	var haerte: float = clampf(float(v["taktik"]["haerte"]), 0.0, 100.0)
	var p_2min: float = clampf(0.050 + haerte * 0.00058, 0.02, 0.12) * float(td["zeitstrafe"])
	var p_7m: float = clampf(0.034 + haerte * 0.00026 + maxf(diff, 0.0) * 0.0005, 0.015, 0.09)
	p_7m *= _anweisungsmittel(a, "angriff_auf", "angriff", "siebenmeter")
	var wurf_zuf: float = rng.randf()
	if wurf_zuf < p_2min:
		_zeitstrafe(v, a)
		if rng.randf() < 0.25:
			return _siebenmeter(a, v)
		# Freiwurf: Angriff geht weiter, leicht verbessert
		diff += 6.0
	elif wurf_zuf < p_2min + p_7m:
		return _siebenmeter(a, v)

	return _wurf(a, v, diff, td)

func _wurf(a: Dictionary, v: Dictionary, diff: float, td: Dictionary) -> Dictionary:
	var pos := _wurfposition(a)
	var schuetze := _spieler_auf(a, pos)
	if schuetze == "":
		return _ballverlust(a, v)
	var sp: Dictionary = daten["spieler"][schuetze]
	var zst: Dictionary = a["zustand"][schuetze]
	a["stats"]["wuerfe"] += 1
	zst["wuerfe"] += 1

	var tw := _spieler_auf(v, "TW")
	var block_mod: float = float(td["block"])
	var p_block: float = clampf(0.140 - diff * 0.0008, 0.06, 0.19) * block_mod
	if pos == "KM" or pos == "LA" or pos == "RA":
		p_block *= 0.45
	if rng.randf() < p_block:
		_wurf_notieren(a, pos, "block")
		return _block(a, v, schuetze, pos)

	var wurfguete: float = _wurfguete(sp, pos, a, diff)
	var paradenwert: float = _paradenwert(v, tw, pos)
	# Der Hallenpuls wirkt direkt auf den Abschluss, nicht nur ueber den
	# Staerkevergleich — sonst verschwindet der Heimvorteil.
	var p_tor: float = clampf(0.735 + (wurfguete - paradenwert) * 0.0035 + _puls_abschluss(a), 0.42, 0.79)
	var p_vorbei: float = clampf(0.115 - (wurfguete - paradenwert) * 0.0009, 0.05, 0.17)
	var w: float = rng.randf()
	if w < p_vorbei:
		_wurf_notieren(a, pos, "vorbei")
		zst["bewertung"] += 0.16
		_bewertung_dampfen(zst)
		var t1 := "%s setzt den Ball an den Pfosten." % Spielerfabrik.kurz_name(sp) if rng.randf() < 0.4 else "%s wirft vorbei." % Spielerfabrik.kurz_name(sp)
		_warteschlange.append(_ereignis("fehlwurf", _seite(a), schuetze, t1, {"position": pos}))
		_puls_aendern(a, -2.0)
		return {"gegenstoss": rng.randf() < 0.24}
	elif w < p_vorbei + (1.0 - p_vorbei) * p_tor:
		_wurf_notieren(a, pos, "tor")
		return _tor(a, v, schuetze, pos, false)
	else:
		_wurf_notieren(a, pos, "parade")
		return _parade(a, v, schuetze, tw, pos)

# ------------------------------------------------------- Spieleranweisungen ---
#
# Die Mannschaftstaktik legt den Rahmen fest, die Anweisung eines einzelnen
# Spielers verschiebt darin sein Verhalten. Positionsbezogene Faktoren
# (Wurfanteil, Wurfguete) wirken direkt auf den betroffenen Spieler,
# mannschaftsbezogene (Fehler, Siebenmeter, Block, Ballgewinn, Zeitstrafe)
# als Mittelwert ueber die Feldspieler der jeweiligen Formation.

## Welchen Wert die Anweisung eines Spielers in einem Bereich hat.
func _faktor(t: Dictionary, sid: String, bereich: String, feld: String) -> float:
	var katalog: Dictionary = Anweisungen.ANGRIFF if bereich == "angriff" else Anweisungen.ABWEHR
	var gesetzt: Dictionary = (t["anweisungen"] as Dictionary).get(sid, {})
	var eintrag: Dictionary = katalog.get(str(gesetzt.get(bereich, "normal")), katalog["normal"])
	return float(eintrag[feld])

## Mittelwert eines Anweisungsfaktors ueber die Feldspieler einer Formation.
func _anweisungsmittel(t: Dictionary, formation: String, bereich: String, feld: String) -> float:
	var auf: Dictionary = t[formation]
	var summe := 0.0
	var n := 0
	for pos in auf.keys():
		if str(pos) == "TW":
			continue
		var sid: String = str(auf[pos])
		if sid == "":
			continue
		summe += _faktor(t, sid, bereich, feld)
		n += 1
	if n == 0:
		return 1.0
	return summe / float(n)

## Wie stark der Kreislaeufer von den Anspielern bedient wird.
func _kreisschub(a: Dictionary) -> float:
	var auf: Dictionary = a["angriff_auf"]
	var summe := 0.0
	var n := 0
	for pos in auf.keys():
		if str(pos) == "TW" or str(pos) == "KM":
			continue
		var sid: String = str(auf[pos])
		if sid == "":
			continue
		summe += _faktor(a, sid, "angriff", "kreis")
		n += 1
	if n == 0:
		return 1.0
	return summe / float(n)

## Deckungswerte der Taktik, verschoben durch die Abwehranweisungen.
func _deckungswerte(v: Dictionary) -> Dictionary:
	var td: Dictionary = (DECKUNG.get(str(v["taktik"]["abwehr"]), DECKUNG["6-0"]) as Dictionary).duplicate()
	td["block"] = float(td["block"]) * _anweisungsmittel(v, "abwehr_auf", "abwehr", "block")
	td["ballgewinn"] = float(td["ballgewinn"]) * _anweisungsmittel(v, "abwehr_auf", "abwehr", "ballgewinn")
	td["zeitstrafe"] = float(td["zeitstrafe"]) * _anweisungsmittel(v, "abwehr_auf", "abwehr", "zeitstrafe")
	return td

## Haelt fest, was aus einem Abschluss von dieser Position geworden ist.
func _wurf_notieren(a: Dictionary, pos: String, ergebnis: String) -> void:
	var karte: Dictionary = a["wurfkarte"]
	if not karte.has(pos):
		karte[pos] = {"tor": 0, "parade": 0, "vorbei": 0, "block": 0}
	var eintrag: Dictionary = karte[pos]
	eintrag[ergebnis] = int(eintrag.get(ergebnis, 0)) + 1

func _wurfposition(a: Dictionary) -> String:
	var stil: String = str(a["taktik"]["angriff"])
	var verteilung: Dictionary = WURFVERTEILUNG.get(stil, WURFVERTEILUNG["positionsangriff"])
	if a["sieben_gegen_sechs"]:
		verteilung = WURFVERTEILUNG["rueckraumfokus"]
	var gesamt := 0.0
	var gewichte := {}
	for pos in verteilung.keys():
		var sid := _spieler_auf(a, pos)
		if sid == "":
			continue
		var kraft: float = float(a["zustand"][sid]["kraft"]) / 100.0
		var g: float = float(verteilung[pos]) * (0.55 + 0.45 * kraft) * (0.7 + 0.6 * _angriff_basis(a, sid, pos) / 100.0)
		g *= _faktor(a, sid, "angriff", "wurfanteil")
		gewichte[pos] = g
		gesamt += g
	# Wer den Kreis anspielt, verschiebt Abschluesse zum Kreislaeufer.
	if gewichte.has("KM"):
		var schub: float = _kreisschub(a)
		if not is_equal_approx(schub, 1.0):
			gesamt -= float(gewichte["KM"])
			gewichte["KM"] = float(gewichte["KM"]) * schub
			gesamt += float(gewichte["KM"])
	if gesamt <= 0.0:
		return ""
	var wurf: float = rng.randf() * gesamt
	for pos in gewichte.keys():
		wurf -= float(gewichte[pos])
		if wurf <= 0.0:
			return pos
	return str(gewichte.keys()[0])

func _wurfguete(sp: Dictionary, pos: String, a: Dictionary, diff: float) -> float:
	var attr: Dictionary = sp["attr"]
	var basis: float = 0.0
	match pos:
		"LA", "RA":
			basis = float(attr["wurfpraezision"]) * 2.2 + float(attr["sprungkraft"]) * 1.5 + float(attr["taeuschung"]) * 0.8
			basis /= 4.5
		"KM":
			basis = float(attr["wurfpraezision"]) * 1.6 + float(attr["physis"]) * 1.6 + float(attr["beweglichkeit"]) * 1.0
			basis /= 4.2
		"RM":
			basis = float(attr["wurfkraft"]) * 1.6 + float(attr["wurfpraezision"]) * 1.9 + float(attr["entscheidung"]) * 0.9
			basis /= 4.4
		_:
			basis = float(attr["wurfkraft"]) * 2.0 + float(attr["wurfpraezision"]) * 1.7 + float(attr["sprungkraft"]) * 0.8
			basis /= 4.5
	var z_sch: Dictionary = a["zustand"][sp["id"]]
	var kraft: float = float(z_sch["kraft"]) / 100.0
	var nerven: float = float(attr["nervenstaerke"]) / 20.0
	var druck: float = 1.0
	if zeit > SPIELZEIT - 300.0:
		var abstand: int = absi(int(heim["tore"]) - int(gast["tore"]))
		if abstand <= 2:
			druck = 0.9 + 0.2 * nerven
	var puls_bonus: float = _puls_wirkung(a)
	var anweisung: float = _faktor(a, str(sp["id"]), "angriff", "wurfguete") * ANWEISUNG_GUETE
	return basis * 5.0 * (0.70 + 0.30 * kraft) * float(z_sch["tagesform"]) * druck * puls_bonus + clampf(diff, -30.0, 30.0) * 0.12 + anweisung

func _paradenwert(v: Dictionary, tw: String, pos: String) -> float:
	if tw == "":
		return 8.0  # leeres Tor
	var sp: Dictionary = daten["spieler"][tw]
	var attr: Dictionary = sp["attr"]
	var spezial: float = float(attr["rueckraumabwehr"])
	if pos == "LA" or pos == "RA":
		spezial = float(attr["fluegelabwehr"])
	elif pos == "KM":
		spezial = float(attr["eins_gegen_eins"])
	var basis: float = (float(attr["reflexe"]) * 2.0 + float(attr["tw_stellung"]) * 1.6 + spezial * 1.8) / 5.4
	var z_tw: Dictionary = v["zustand"][tw]
	var kraft: float = float(z_tw["kraft"]) / 100.0
	return basis * 5.0 * (0.82 + 0.18 * kraft) * float(z_tw["tagesform"]) * _puls_wirkung(v)

func _tor(a: Dictionary, v: Dictionary, schuetze: String, pos: String, ist_7m: bool) -> Dictionary:
	a["tore"] = int(a["tore"]) + 1
	# Gegentor dem Torwart zuschreiben, der gerade im Tor steht
	var kassiert := _spieler_auf(v, "TW")
	if kassiert != "" and v["zustand"].has(kassiert):
		v["zustand"][kassiert]["gegentore"] = int(v["zustand"][kassiert]["gegentore"]) + 1
	a["stats"]["tore"] += 1
	var zst: Dictionary = a["zustand"][schuetze]
	zst["tore"] += 1
	zst["bewertung"] -= 0.3
	_bewertung_dampfen(zst)
	if _gegenstoss:
		a["stats"]["gegenstoss_tore"] += 1
	if ist_7m:
		a["stats"]["siebenmeter_tore"] += 1
		zst["siebenmeter_tore"] += 1
	var sp: Dictionary = daten["spieler"][schuetze]
	var assist := ""
	if not ist_7m and not _gegenstoss and rng.randf() < 0.55:
		assist = _assistgeber(a, schuetze)
		if assist != "":
			a["zustand"][assist]["assists"] += 1
			a["zustand"][assist]["bewertung"] -= 0.1
	_lauf_aktualisieren(_seite(a))
	_puls_aendern(a, 3.0 if a["ist_heim"] else -2.0)
	var text := _tortext(sp, pos, ist_7m, assist, a)
	_warteschlange.append(_ereignis("tor", _seite(a), schuetze, text, {"position": pos, "assist": assist, "siebenmeter": ist_7m, "gegenstoss": _gegenstoss}))
	# Nach dem Tor pruefen, ob 7-gegen-6 aktiviert wird
	sieben_gegen_sechs_pruefen(v)
	sieben_gegen_sechs_pruefen(a)
	return {"gegenstoss": false}

func _tortext(sp: Dictionary, pos: String, ist_7m: bool, assist: String, a: Dictionary) -> String:
	var n := Spielerfabrik.kurz_name(sp)
	if ist_7m:
		return "%s verwandelt den Siebenmeter sicher." % n
	if _gegenstoss:
		return "Tempogegenstoß! %s schließt eiskalt ab." % n
	if a["sieben_gegen_sechs"]:
		return "Im 7-gegen-6 findet %s die Lücke." % n
	var varianten: Array = []
	match pos:
		"KM":
			varianten = ["%s dreht sich am Kreis durch." % n, "Anspiel an den Kreis — %s trifft." % n,
				"%s setzt sich im Zweikampf durch und trifft." % n]
		"LA", "RA":
			varianten = ["%s fliegt vom Flügel ein." % n, "%s hebelt den Torwart vom Flügel aus." % n,
				"Sauberer Winkel: %s trifft von außen." % n]
		"RM":
			varianten = ["%s zieht selbst ab und trifft." % n, "%s findet die Lücke im Zentrum." % n]
		_:
			varianten = ["%s hämmert den Ball aus dem Rückraum ins Netz." % n,
				"Schlagwurf von %s — drin." % n, "%s trifft nach Doppelpass aus dem Rückraum." % n]
	var t := str(varianten[rng.randi_range(0, varianten.size() - 1)])
	if assist != "":
		t += " Vorarbeit: %s." % Spielerfabrik.kurz_name(daten["spieler"][assist])
	return t

func _assistgeber(a: Dictionary, ausser: String) -> String:
	var kandidaten: Array = []
	var gewichte: Array = []
	var summe := 0.0
	for pos in a["angriff_auf"].keys():
		var sid: String = str(a["angriff_auf"][pos])
		if sid == "" or sid == ausser or pos == "TW":
			continue
		var sp: Dictionary = daten["spieler"][sid]
		var g: float = float(sp["attr"]["passspiel"]) + float(sp["attr"]["uebersicht"])
		kandidaten.append(sid)
		gewichte.append(g)
		summe += g
	if kandidaten.is_empty():
		return ""
	var w: float = rng.randf() * summe
	for i in range(kandidaten.size()):
		w -= float(gewichte[i])
		if w <= 0.0:
			return str(kandidaten[i])
	return str(kandidaten[0])

func _parade(a: Dictionary, v: Dictionary, schuetze: String, tw: String, pos: String) -> Dictionary:
	if tw != "":
		v["stats"]["paraden"] += 1
		var zt: Dictionary = v["zustand"][tw]
		zt["paraden"] += 1
		zt["bewertung"] -= 0.14
		_bewertung_dampfen(zt)
	var zs: Dictionary = a["zustand"][schuetze]
	zs["bewertung"] += 0.1
	_bewertung_dampfen(zs)
	var text := "Parade!"
	if tw != "":
		text = "%s pariert den Wurf von %s." % [Spielerfabrik.kurz_name(daten["spieler"][tw]), Spielerfabrik.kurz_name(daten["spieler"][schuetze])]
	_puls_aendern(v, 5.0 if v["ist_heim"] else -3.0)
	_warteschlange.append(_ereignis("parade", _seite(v), tw, text, {"position": pos, "schuetze": schuetze}))
	return {"gegenstoss": rng.randf() < 0.36}

func _block(a: Dictionary, v: Dictionary, schuetze: String, pos: String) -> Dictionary:
	var blocker := _zufaelliger_abwehrspieler(v)
	v["stats"]["blocks"] += 1
	if blocker != "":
		v["zustand"][blocker]["blocks"] += 1
		v["zustand"][blocker]["bewertung"] -= 0.12
	var text := "Block! Der Wurf von %s wird abgewehrt." % Spielerfabrik.kurz_name(daten["spieler"][schuetze])
	if blocker != "":
		text = "%s stellt sich in den Wurf von %s." % [Spielerfabrik.kurz_name(daten["spieler"][blocker]), Spielerfabrik.kurz_name(daten["spieler"][schuetze])]
	_warteschlange.append(_ereignis("block", _seite(v), blocker, text, {"position": pos}))
	_puls_aendern(v, 3.0 if v["ist_heim"] else -2.0)
	return {"gegenstoss": rng.randf() < 0.28}

func _ballverlust(a: Dictionary, v: Dictionary) -> Dictionary:
	var verursacher := _zufaelliger_angreifer(a)
	a["stats"]["technische_fehler"] += 1
	if verursacher != "":
		a["zustand"][verursacher]["fehler"] += 1
		a["zustand"][verursacher]["bewertung"] += 0.22
		_bewertung_dampfen(a["zustand"][verursacher])
	var gewinner := _zufaelliger_abwehrspieler(v)
	if gewinner != "" and rng.randf() < 0.45:
		v["stats"]["ballgewinne"] += 1
		v["zustand"][gewinner]["ballgewinne"] += 1
		v["zustand"][gewinner]["bewertung"] -= 0.1
	var arten := ["Schrittfehler", "Stürmerfoul", "technischer Fehler", "Fehlpass", "Doppelfehler", "Zeitspiel-Abpfiff"]
	var art := str(arten[rng.randi_range(0, arten.size() - 1)])
	var text := "%s: %s." % [art, Spielerfabrik.kurz_name(daten["spieler"][verursacher])] if verursacher != "" else "Ballverlust."
	var leeres_tor_risiko: float = 0.42
	if Trainerkarriere.bonus_fuer(daten, str(a["cid"]), "hasardeur"):
		leeres_tor_risiko = 0.26
	if a["sieben_gegen_sechs"] and rng.randf() < leeres_tor_risiko:
		# Ins leere Tor
		v["tore"] = int(v["tore"]) + 1
		v["stats"]["tore"] += 1
		var werfer := _zufaelliger_abwehrspieler(v)
		if werfer != "":
			v["zustand"][werfer]["tore"] += 1
			v["zustand"][werfer]["bewertung"] -= 0.35
		text += " Und der Ball landet im verwaisten Tor!"
		_warteschlange.append(_ereignis("tor", _seite(v), werfer, text, {"position": "RM", "leeres_tor": true}))
		_lauf_aktualisieren(_seite(v))
		_puls_aendern(v, 8.0 if v["ist_heim"] else -6.0)
		return {"gegenstoss": false}
	_warteschlange.append(_ereignis("ballverlust", _seite(a), verursacher, text))
	_puls_aendern(a, -3.0)
	return {"gegenstoss": rng.randf() < 0.40}

func _siebenmeter(a: Dictionary, v: Dictionary) -> Dictionary:
	var schuetze: String = str(a["siebenmeter_schuetze"])
	if schuetze == "" or not _ist_auf_platz(a, schuetze):
		schuetze = _bester_auf_platz_siebenmeter(a)
	if schuetze == "":
		return _ballverlust(a, v)
	a["stats"]["siebenmeter"] += 1
	a["zustand"][schuetze]["siebenmeter"] += 1
	var sp: Dictionary = daten["spieler"][schuetze]
	var tw := _spieler_auf(v, "TW")
	var guete: float = (float(sp["attr"]["siebenmeter"]) * 2.4 + float(sp["attr"]["nervenstaerke"]) * 1.2) / 3.6 * 5.0
	var halten: float = 20.0
	if tw != "":
		var tsp: Dictionary = daten["spieler"][tw]
		halten = (float(tsp["attr"]["siebenmeterabwehr"]) * 2.2 + float(tsp["attr"]["reflexe"]) * 1.0) / 3.2 * 5.0
	var p: float = clampf(0.76 + (guete - halten) * 0.0055, 0.45, 0.95)
	_warteschlange.append(_ereignis("siebenmeter", _seite(a), schuetze, "Siebenmeter für %s — %s legt sich den Ball zurecht." % [a["kurz"], Spielerfabrik.kurz_name(sp)], {"position": "RM"}))
	if rng.randf() < p:
		_wurf_notieren(a, "7M", "tor")
		return _tor(a, v, schuetze, "RM", true)
	_wurf_notieren(a, "7M", "parade")
	if tw != "":
		v["stats"]["paraden"] += 1
		v["zustand"][tw]["paraden"] += 1
		v["zustand"][tw]["bewertung"] -= 0.32
		_bewertung_dampfen(v["zustand"][tw])
	a["zustand"][schuetze]["bewertung"] += 0.35
	_bewertung_dampfen(a["zustand"][schuetze])
	var tw_text := "Der Torwart hält!" if tw == "" else "%s hält den Siebenmeter!" % Spielerfabrik.kurz_name(daten["spieler"][tw])
	_warteschlange.append(_ereignis("parade", _seite(v), tw, tw_text, {"position": "RM", "schuetze": schuetze}))
	_puls_aendern(v, 9.0 if v["ist_heim"] else -6.0)
	return {"gegenstoss": false}

func _bester_auf_platz_siebenmeter(a: Dictionary) -> String:
	var best := ""
	var bw := -1.0
	for pos in a["angriff_auf"].keys():
		if pos == "TW":
			continue
		var sid: String = str(a["angriff_auf"][pos])
		if sid == "":
			continue
		var sp: Dictionary = daten["spieler"][sid]
		var w: float = float(sp["attr"]["siebenmeter"]) * 2.0 + float(sp["attr"]["nervenstaerke"])
		if w > bw:
			bw = w
			best = sid
	return best

# ------------------------------------------------------- Zeitstrafen etc. ---

func _zeitstrafe(v: Dictionary, a: Dictionary) -> void:
	var suender := _zufaelliger_abwehrspieler(v, true)
	if suender == "":
		return
	var zst: Dictionary = v["zustand"][suender]
	zst["zeitstrafen"] = int(zst["zeitstrafen"]) + 1
	zst["bewertung"] += 0.3
	_bewertung_dampfen(zst)
	v["stats"]["zeitstrafen"] += 1
	var sp: Dictionary = daten["spieler"][suender]
	if int(zst["zeitstrafen"]) >= 3:
		zst["rot"] = true
		v["stats"]["rote"] += 1
		_vom_platz_nehmen(v, suender)
		(v["gesperrt"] as Array).append({"sid": "", "bis": zeit + 120.0})
		_warteschlange.append(_ereignis("rot", _seite(v), suender, "Dritte Zeitstrafe: %s muss mit Rot vom Feld!" % Spielerfabrik.kurz_name(sp)))
	else:
		(v["gesperrt"] as Array).append({"sid": suender, "bis": zeit + 120.0})
		_vom_platz_nehmen(v, suender)
		_warteschlange.append(_ereignis("zeitstrafe", _seite(v), suender, "Zwei Minuten für %s." % Spielerfabrik.kurz_name(sp)))
	_puls_aendern(a, 4.0 if a["ist_heim"] else -2.0)

func _strafzeiten_pruefen(t: Dictionary) -> void:
	var offen: Array = []
	for e in t["gesperrt"]:
		if zeit >= float(e["bis"]):
			var sid: String = str(e["sid"])
			if sid != "" and not bool(t["zustand"][sid]["rot"]):
				_zurueck_aufs_feld(t, sid)
		else:
			offen.append(e)
	t["gesperrt"] = offen

## Feldspieler, die eine Mannschaft gerade wirklich auf dem Parkett hat.
## Bei einer Zeitstrafe rueckt zwar jemand von der Bank in die Aufstellung
## (damit alle Positionen besetzt bleiben), gezaehlt wird die Mannschaft aber
## in Unterzahl — genau das ist der Nachteil, den eine Hinausstellung bringt.
func _feldspieler(t: Dictionary) -> int:
	var besetzt: int = 0
	for pos in t["angriff_auf"].keys():
		if pos == "TW":
			continue
		if str(t["angriff_auf"][pos]) != "":
			besetzt += 1
	var grenze: int = 7 if bool(t["sieben_gegen_sechs"]) else 6
	var strafen: int = (t["gesperrt"] as Array).size()
	return clampi(mini(besetzt, grenze) - strafen, 3, 7)

func _vom_platz_nehmen(t: Dictionary, sid: String) -> void:
	for pos in (t["angriff_auf"] as Dictionary).keys():
		if str(t["angriff_auf"][pos]) == sid:
			var ersatz := _bester_von_bank(t, pos)
			t["angriff_auf"][pos] = ersatz
			if ersatz != "":
				(t["bank"] as Array).erase(ersatz)
	for pos in (t["abwehr_auf"] as Dictionary).keys():
		if str(t["abwehr_auf"][pos]) == sid:
			t["abwehr_auf"][pos] = ""

func _zurueck_aufs_feld(t: Dictionary, sid: String) -> void:
	if not (t["bank"] as Array).has(sid):
		(t["bank"] as Array).append(sid)
	# Leere Abwehrplaetze zuerst fuellen
	for pos in (t["abwehr_auf"] as Dictionary).keys():
		if str(t["abwehr_auf"][pos]) == "":
			t["abwehr_auf"][pos] = sid
			break

func _bester_von_bank(t: Dictionary, pos: String) -> String:
	var best := ""
	var bw := -1.0
	for sid in t["bank"]:
		var sp: Dictionary = daten["spieler"][sid]
		if bool(sp["ist_torwart"]) != (pos == "TW"):
			continue
		if bool(t["zustand"][sid]["rot"]):
			continue
		var w: float = Spielerfabrik.angriff_auf(sp, pos) * (float(t["zustand"][sid]["kraft"]) / 100.0)
		if w > bw:
			bw = w
			best = sid
	return best

# -------------------------------------------------------- 7 gegen 6 / Zeit ---

func sieben_gegen_sechs_pruefen(t: Dictionary) -> void:
	var modus: String = str(t["taktik"].get("siebter_feldspieler", "nie"))
	var eigene: int = int(t["tore"])
	var fremde: int = int(gast["tore"]) if t == heim else int(heim["tore"])
	var rueckstand: int = fremde - eigene
	var aktiv := false
	match modus:
		"immer":
			aktiv = true
		"rueckstand":
			aktiv = rueckstand >= 2 and zeit > SPIELZEIT * 0.55
		"schluss":
			aktiv = zeit > SPIELZEIT - 480.0 and rueckstand >= 1
		"unterzahl":
			aktiv = (t["gesperrt"] as Array).size() > 0
		_:
			aktiv = false
	if aktiv == bool(t["sieben_gegen_sechs"]):
		return
	t["sieben_gegen_sechs"] = aktiv
	var text := "%s nimmt den Torwart heraus und spielt 7 gegen 6." % t["name"] if aktiv else "%s stellt wieder auf regulären Angriff um." % t["name"]
	_warteschlange.append(_ereignis("taktik", _seite(t), "", text))

# ------------------------------------------------------------- Kraft/Puls ---

func _kraft_verbrauchen(t: Dictionary, dauer: float, im_angriff: bool) -> void:
	var wechselintensitaet: float = float(t["taktik"].get("wechselspiel", 50)) / 100.0
	var tempo: float = float(t["taktik"]["tempo"]) / 100.0
	var auf_platz := alle_auf_platz(t)
	for sid in auf_platz:
		var sp: Dictionary = daten["spieler"][sid]
		var ausdauer: float = float(sp["attr"]["ausdauer"]) / 20.0
		var verbrauch: float = dauer / 60.0 * (1.25 + 0.55 * tempo) * (1.5 - 0.75 * ausdauer)
		if bool(sp["ist_torwart"]):
			verbrauch *= 0.32
		else:
			verbrauch *= (1.0 + 0.28 * wechselintensitaet)
		if not im_angriff:
			verbrauch *= float(DECKUNG.get(str(t["taktik"]["abwehr"]), DECKUNG["6-0"])["kraft"])
		var z: Dictionary = t["zustand"][sid]
		z["kraft"] = clampf(float(z["kraft"]) - verbrauch, 5.0, 100.0)
		z["sekunden"] = float(z["sekunden"]) + dauer
	for sid in t["bank"]:
		var z2: Dictionary = t["zustand"][sid]
		z2["kraft"] = clampf(float(z2["kraft"]) + dauer / 60.0 * 1.5, 0.0, 100.0)

## Prueft, ob sich ein Spieler auf dem Feld verletzt — mit sofortigem Ausfall.
func _verletzungspruefung(t: Dictionary) -> void:
	for sid in alle_auf_platz(t):
		if rng.randf() >= Medizin.risiko(daten, sid) * 2.2:
			continue
		var sp: Dictionary = daten["spieler"][sid]
		if not (sp["verletzung"] as Dictionary).is_empty():
			continue
		var vl := Medizin.verletzung_im_spiel(daten, sid)
		t["zustand"][sid]["verletzt"] = true
		_vom_platz_nehmen(t, sid)
		(t["bank"] as Array).erase(sid)
		_warteschlange.append(_ereignis("verletzung", _seite(t), sid,
			"%s muss verletzt vom Feld (%s)." % [Spielerfabrik.kurz_name(sp), vl["art"]]))
		return

func alle_auf_platz(t: Dictionary) -> Array:
	var liste := {}
	for pos in t["angriff_auf"].keys():
		var sid: String = str(t["angriff_auf"][pos])
		if sid != "":
			liste[sid] = true
	for pos in t["abwehr_auf"].keys():
		var sid2: String = str(t["abwehr_auf"][pos])
		if sid2 != "":
			liste[sid2] = true
	return liste.keys()

func _pause_erholung() -> void:
	for t in [heim, gast]:
		for sid in t["zustand"].keys():
			var z: Dictionary = t["zustand"][sid]
			z["kraft"] = clampf(float(z["kraft"]) + 22.0, 0.0, 100.0)
		t["auszeit_wirkung"] = 0.0

func _puls_aendern(t: Dictionary, wert: float) -> void:
	var treue: float = float(daten["vereine"][spiel["heim"]]["fans"]["treue"]) / 100.0
	hallenpuls = clampf(hallenpuls + wert * (0.7 + 0.6 * treue) * (0.6 + 0.8 * _auslastung()), 5.0, 100.0)

func _puls_abklingen() -> void:
	var ruhe: float = float(daten["vereine"][spiel["heim"]]["hallenpuls_basis"])
	hallenpuls = lerpf(hallenpuls, ruhe, 0.10)

## Direkter Zuschlag auf die Trefferwahrscheinlichkeit durch die Hallenatmosphaere.
func _puls_abschluss(t: Dictionary) -> float:
	var abweichung: float = (hallenpuls - 50.0) / 50.0
	if bool(t["ist_heim"]):
		return clampf(abweichung * 0.045, -0.05, 0.05)
	var nerven := 0.0
	var anzahl := 0
	for sid in alle_auf_platz(t):
		nerven += float(daten["spieler"][sid]["attr"]["nervenstaerke"])
		anzahl += 1
	var schnitt: float = (nerven / maxf(float(anzahl), 1.0)) / 20.0
	return clampf(-abweichung * 0.030 * (1.3 - schnitt), -0.05, 0.04)

## Wirkung des Hallenpulses auf ein Team (Heim profitiert, Gast leidet je nach Nerven).
func _puls_wirkung(t: Dictionary) -> float:
	var abweichung: float = (hallenpuls - 50.0) / 50.0
	if bool(t["ist_heim"]):
		return clampf(1.0 + abweichung * 0.075, 0.92, 1.09)
	var nerven := 0.0
	var anzahl := 0
	for sid in alle_auf_platz(t):
		nerven += float(daten["spieler"][sid]["attr"]["nervenstaerke"])
		anzahl += 1
	var schnitt: float = (nerven / maxf(float(anzahl), 1.0)) / 20.0
	return clampf(1.0 - abweichung * 0.048 * (1.3 - schnitt), 0.92, 1.05)

func _lauf_aktualisieren(seite: String) -> void:
	if str(lauf["team"]) == seite:
		lauf["tore"] = int(lauf["tore"]) + 1
	else:
		lauf["team"] = seite
		lauf["tore"] = 1
	if int(lauf["tore"]) >= 3:
		var t: Dictionary = heim if seite == "heim" else gast
		_puls_aendern(t, 3.0 if t["ist_heim"] else -2.5)
		if int(lauf["tore"]) == 3 or int(lauf["tore"]) == 5:
			_warteschlange.append(_ereignis("lauf", seite, "", "%d Tore in Folge für %s!" % [int(lauf["tore"]), t["name"]]))

# ---------------------------------------------------------- Wechsel / KI ---

func _wechsel_pruefen(t: Dictionary) -> void:
	if zeit - float(t["letzte_wechselpruefung"]) < 120.0:
		return
	t["letzte_wechselpruefung"] = zeit
	var ist_mensch: bool = bool(daten["vereine"][t["cid"]].get("ist_mensch", false))
	if ist_mensch and not bool(daten["einstellungen"].get("autorotation", true)):
		return
	for pos in (t["angriff_auf"] as Dictionary).keys():
		var sid: String = str(t["angriff_auf"][pos])
		if sid == "":
			continue
		var z: Dictionary = t["zustand"][sid]
		if float(z["kraft"]) > 62.0:
			continue
		var ersatz := _bester_von_bank(t, pos)
		if ersatz == "":
			continue
		if float(t["zustand"][ersatz]["kraft"]) < float(z["kraft"]) + 18.0:
			continue
		wechsel(t, sid, ersatz, pos)

## Fuehrt einen Wechsel durch. Gibt false zurueck, wenn er nicht moeglich ist.
func wechsel(t: Dictionary, raus: String, rein: String, pos: String = "") -> bool:
	if not t["zustand"].has(rein) or bool(t["zustand"][rein]["rot"]):
		return false
	var gefunden := false
	for p in (t["angriff_auf"] as Dictionary).keys():
		if str(t["angriff_auf"][p]) == raus:
			t["angriff_auf"][p] = rein
			gefunden = true
	for p in (t["abwehr_auf"] as Dictionary).keys():
		if str(t["abwehr_auf"][p]) == raus:
			t["abwehr_auf"][p] = rein
	if not gefunden and pos != "":
		t["angriff_auf"][pos] = rein
		gefunden = true
	if not gefunden:
		return false
	(t["bank"] as Array).erase(rein)
	if not (t["bank"] as Array).has(raus):
		(t["bank"] as Array).append(raus)
	t["stats"]["wechsel"] += 1
	# Wechselfehler: bei sehr hoher Wechselintensitaet droht eine Zeitstrafe
	var intensitaet: float = float(t["taktik"].get("wechselspiel", 50)) / 100.0
	if rng.randf() < 0.006 * intensitaet:
		var gegner: Dictionary = gast if t == heim else heim
		_warteschlange.append(_ereignis("wechselfehler", _seite(t), rein, "Wechselfehler bei %s — zwei Minuten!" % t["name"]))
		_zeitstrafe(t, gegner)
	else:
		_warteschlange.append(_ereignis("wechsel", _seite(t), rein, "Wechsel bei %s: %s kommt für %s." % [
			t["kurz"], Spielerfabrik.kurz_name(daten["spieler"][rein]), Spielerfabrik.kurz_name(daten["spieler"][raus])]))
	return true

func _auszeit_pruefen(a: Dictionary, v: Dictionary) -> void:
	for t in [a, v]:
		if int(t["auszeiten"]) <= 0:
			continue
		if not bool(t["taktik"].get("auszeit_automatik", true)):
			continue
		var gegen: String = "gast" if _seite(t) == "heim" else "heim"
		if str(lauf["team"]) == gegen and int(lauf["tore"]) >= 3 and rng.randf() < 0.55:
			auszeit(t)

## Auszeit: beruhigt das Spiel, gibt Kraft und einen kurzen Leistungsschub.
func auszeit(t: Dictionary) -> bool:
	if int(t["auszeiten"]) <= 0:
		return false
	t["auszeiten"] = int(t["auszeiten"]) - 1
	t["auszeit_wirkung"] = 1.0
	for sid in alle_auf_platz(t):
		var z: Dictionary = t["zustand"][sid]
		z["kraft"] = clampf(float(z["kraft"]) + 6.0, 0.0, 100.0)
	lauf["tore"] = 0
	if not bool(t["ist_heim"]):
		hallenpuls = clampf(hallenpuls - 6.0, 5.0, 100.0)
	_warteschlange.append(_ereignis("auszeit", _seite(t), "", "Auszeit %s. Der Trainer stellt die Mannschaft neu ein." % t["name"]))
	return true

# ------------------------------------------------------------- Ansprache ---

const ANSPRACHEN := {
	"ruhig": {"name": "Ruhe bewahren", "beschreibung": "Nichts überstürzen, beim Plan bleiben."},
	"anfeuern": {"name": "Anfeuern", "beschreibung": "Emotion, Lautstärke, alles nach vorn."},
	"kritisieren": {"name": "Kritisieren", "beschreibung": "Klare Ansage, keine Rücksicht."},
	"vertrauen": {"name": "Vertrauen zusichern", "beschreibung": "Rückendeckung geben, Druck nehmen."},
}

## Ansprache in der Halbzeit oder Auszeit. Wie sie ankommt, haengt von der
## Spielsituation, dem Kabinenklima und den Charakteren auf dem Feld ab.
## Rueckgabe: {"wirkung": float, "positiv": int, "negativ": int, "text": String}
func ansprache_halten(t: Dictionary, tonlage: String) -> Dictionary:
	var eigene: int = int(t["tore"])
	var fremde: int = int(gast["tore"]) if t == heim else int(heim["tore"])
	var abstand: int = eigene - fremde
	var klima: float = float(daten["vereine"][t["cid"]].get("stimmung_kabine", 60.0)) / 100.0
	var positiv := 0
	var negativ := 0
	for sid in alle_auf_platz(t):
		var sp: Dictionary = daten["spieler"][sid]
		var charakter: Dictionary = sp["charakter"]
		var temperament: float = float(charakter.get("temperament", 10.0)) / 20.0
		var profitum: float = float(charakter.get("profitum", 12.0)) / 20.0
		var loyalitaet: float = float(charakter.get("loyalitaet", 12.0)) / 20.0
		var nerven: float = float(sp["attr"]["nervenstaerke"]) / 20.0
		var chance := 0.5
		match tonlage:
			"ruhig":
				chance = 0.46 + profitum * 0.35 + nerven * 0.15 - absf(float(abstand)) * 0.01
			"anfeuern":
				chance = 0.44 + temperament * 0.34 + (0.18 if absi(abstand) <= 3 else -0.08)
			"kritisieren":
				chance = 0.30 + profitum * 0.45 - temperament * 0.25 + (0.14 if abstand < -2 else -0.06)
			"vertrauen":
				chance = 0.48 + loyalitaet * 0.28 + (1.0 - nerven) * 0.16
		chance += (klima - 0.6) * 0.3
		if Trainerkarriere.bonus_fuer(daten, str(t["cid"]), "kumpeltyp"):
			chance += 0.06
		if Trainerkarriere.bonus_fuer(daten, str(t["cid"]), "eiserne_hand") and tonlage == "kritisieren":
			chance += 0.10
		if rng.randf() < clampf(chance, 0.05, 0.95):
			positiv += 1
			sp["moral"] = clampf(float(sp["moral"]) + 1.2, 5.0, 100.0)
		else:
			negativ += 1
			sp["moral"] = clampf(float(sp["moral"]) - 1.0, 5.0, 100.0)
	var gesamt: int = maxi(positiv + negativ, 1)
	var wirkung: float = clampf((float(positiv) / float(gesamt) - 0.5) * 2.0, -1.0, 1.0)
	t["ansprache"] = clampf(float(t["ansprache"]) * 0.4 + wirkung, -1.0, 1.0)
	(t["ansprachen"] as Array).append({"zeit": zeit, "tonlage": tonlage, "wirkung": wirkung})
	var text := ""
	if wirkung > 0.45:
		text = "Die Mannschaft zieht mit — %d von %d Spielern reagieren deutlich." % [positiv, gesamt]
	elif wirkung > 0.1:
		text = "Die Ansprache kommt überwiegend an (%d von %d)." % [positiv, gesamt]
	elif wirkung > -0.15:
		text = "Gemischte Reaktionen: %d von %d nehmen es an." % [positiv, gesamt]
	elif wirkung > -0.5:
		text = "Das kam nicht gut an — nur %d von %d gehen mit." % [positiv, gesamt]
	else:
		text = "Die Kabine macht dicht. Nur %d von %d reagieren." % [positiv, gesamt]
	_warteschlange.append(_ereignis("ansprache", _seite(t), "",
		"%s: %s" % [str(ANSPRACHEN[tonlage]["name"]), text]))
	return {"wirkung": wirkung, "positiv": positiv, "negativ": negativ, "text": text}

# ------------------------------------------------------------- Hilfsmittel ---

func _seite(t: Dictionary) -> String:
	return "heim" if t == heim else "gast"

func _spieler_auf(t: Dictionary, pos: String) -> String:
	if pos == "TW" and bool(t["sieben_gegen_sechs"]):
		return ""
	return str((t["angriff_auf"] as Dictionary).get(pos, ""))

func _ist_auf_platz(t: Dictionary, sid: String) -> bool:
	return alle_auf_platz(t).has(sid)

func _zufaelliger_angreifer(t: Dictionary) -> String:
	var liste: Array = []
	for pos in t["angriff_auf"].keys():
		if pos == "TW":
			continue
		var sid: String = str(t["angriff_auf"][pos])
		if sid != "":
			liste.append(sid)
	if liste.is_empty():
		return ""
	return str(liste[rng.randi_range(0, liste.size() - 1)])

func _zufaelliger_abwehrspieler(t: Dictionary, ohne_tw: bool = true) -> String:
	var liste: Array = []
	for pos in t["abwehr_auf"].keys():
		if ohne_tw and pos == "TW":
			continue
		var sid: String = str(t["abwehr_auf"][pos])
		if sid != "" and not bool(t["zustand"][sid]["rot"]):
			liste.append(sid)
	if liste.is_empty():
		return _zufaelliger_angreifer(t)
	return str(liste[rng.randi_range(0, liste.size() - 1)])

## Gecachter Angriffswert eines Spielers auf einer Position.
func _angriff_basis(t: Dictionary, sid: String, pos: String) -> float:
	var z: Dictionary = t["zustand"][sid]
	var cache: Dictionary = z["basis_angriff"]
	if not cache.has(pos):
		cache[pos] = Spielerfabrik.angriff_auf(daten["spieler"][sid], pos)
	return float(cache[pos])

func _bewertung_dampfen(z: Dictionary) -> void:
	z["bewertung"] = clampf(float(z["bewertung"]), 1.0, 6.0)

func _angriffskraft(a: Dictionary, v: Dictionary) -> float:
	var summe := 0.0
	var gewicht := 0.0
	for pos in a["angriff_auf"].keys():
		if pos == "TW":
			continue
		var sid: String = str(a["angriff_auf"][pos])
		if sid == "":
			continue
		var z: Dictionary = a["zustand"][sid]
		var kraft: float = float(z["kraft"]) / 100.0
		summe += _angriff_basis(a, sid, pos) * (0.68 + 0.32 * kraft) * float(z["tagesform"])
		gewicht += 1.0
	var basis: float = summe / maxf(gewicht, 1.0)
	var stil: String = str(a["taktik"]["angriff"])
	var gegen: String = str(v["taktik"]["abwehr"])
	basis *= float((ANGRIFF_GEGEN_DECKUNG.get(stil, {}) as Dictionary).get(gegen, 1.0))
	basis *= float(MENTALITAET[str(a["taktik"]["mentalitaet"])]["angriff"])
	basis *= _puls_wirkung(a)
	basis *= Kabine.teamfaktor(daten, str(a["cid"]))
	basis *= 1.0 + Scouting.gegnervorteil(daten, str(a["cid"]), str(v["cid"]))
	basis *= 1.0 + 0.035 * float(a["auszeit_wirkung"])
	basis *= 1.0 + 0.055 * float(a["ansprache"])
	basis *= 1.0 + Presse.motivation(daten, str(a["cid"]))
	a["auszeit_wirkung"] = maxf(float(a["auszeit_wirkung"]) - 0.12, 0.0)
	return basis

func _abwehrkraft(v: Dictionary, a: Dictionary) -> float:
	var summe := 0.0
	var gewicht := 0.0
	for pos in v["abwehr_auf"].keys():
		if pos == "TW":
			continue
		var sid: String = str(v["abwehr_auf"][pos])
		if sid == "":
			continue
		var z: Dictionary = v["zustand"][sid]
		var kraft: float = float(z["kraft"]) / 100.0
		summe += float(z["basis_abwehr"]) * (0.68 + 0.32 * kraft) * float(z["tagesform"])
		gewicht += 1.0
	var basis: float = summe / maxf(gewicht, 1.0)
	basis *= float(MENTALITAET[str(v["taktik"]["mentalitaet"])]["abwehr"])
	basis *= _puls_wirkung(v)
	basis *= Kabine.teamfaktor(daten, str(v["cid"]))
	basis *= 1.0 + 0.045 * float(v["ansprache"])
	if Trainerkarriere.bonus_fuer(daten, str(v["cid"]), "betonmischer"):
		basis *= 1.035
	# Gezielte Manndeckung gegen den Hauptwerfer des Gegners
	if str(v["taktik"].get("deckungsfokus", "keiner")) == "rueckraum":
		basis *= 1.03
	return basis

# ------------------------------------------------------------- Spielende ---

func _spielende() -> void:
	if beendet:
		return
	beendet = true
	zeit = SPIELZEIT
	spiel["tore_heim"] = int(heim["tore"])
	spiel["tore_gast"] = int(gast["tore"])
	spiel["gespielt"] = true
	spiel["zuschauer"] = zuschauer
	_warteschlange.append(_ereignis("ende", "", "", "Schlusssirene: %s %d:%d %s" % [
		heim["kurz"], heim["tore"], gast["tore"], gast["kurz"]]))
	if bool(spiel.get("ko", false)) and int(heim["tore"]) == int(gast["tore"]) and str(spiel["hinspiel"]) == "":
		_entscheidung_erzwingen()

## Bei K.-o.-Spielen: Verlaengerung und ggf. Siebenmeterwerfen.
func _entscheidung_erzwingen() -> void:
	var h_bonus: float = _team_gesamtstaerke(heim)
	var g_bonus: float = _team_gesamtstaerke(gast)
	var h_tore := 0
	var g_tore := 0
	for i in range(10):
		if rng.randf() < clampf(0.5 + (h_bonus - g_bonus) * 0.004, 0.3, 0.7):
			h_tore += 1
		if rng.randf() < clampf(0.5 + (g_bonus - h_bonus) * 0.004, 0.3, 0.7):
			g_tore += 1
	_warteschlange.append(_ereignis("verlaengerung", "", "", "Verlängerung: %d:%d" % [h_tore, g_tore]))
	spiel["tore_heim"] = int(spiel["tore_heim"]) + h_tore
	spiel["tore_gast"] = int(spiel["tore_gast"]) + g_tore
	spiel["entscheidung"] = "verlaengerung"
	if h_tore == g_tore:
		var sieger := "heim" if rng.randf() < clampf(0.5 + (h_bonus - g_bonus) * 0.006, 0.25, 0.75) else "gast"
		if sieger == "heim":
			spiel["tore_heim"] = int(spiel["tore_heim"]) + 1
		else:
			spiel["tore_gast"] = int(spiel["tore_gast"]) + 1
		spiel["entscheidung"] = "siebenmeterwerfen"
		_warteschlange.append(_ereignis("siebenmeterwerfen", sieger, "", "Siebenmeterwerfen! %s setzt sich durch." % (heim["name"] if sieger == "heim" else gast["name"])))

func _team_gesamtstaerke(t: Dictionary) -> float:
	var summe := 0.0
	var n := 0
	for sid in alle_auf_platz(t):
		summe += Spielerfabrik.gesamt(daten["spieler"][sid])
		n += 1
	return summe / maxf(float(n), 1.0)

## Ein Bericht ohne Einzelheiten: Ergebnis, Mannschaftswerte, bester Spieler.
## Fremde Partien werden nach der Verbuchung darauf eingedampft — sonst waere
## der Spielstand nach einer Saison mehrere Dutzend Megabyte gross, obwohl
## niemand die Einzelbewertungen eines Spiels in Polen je aufschlaegt.
static func bericht_schlank(voll: Dictionary) -> Dictionary:
	if voll.is_empty():
		return {}
	var schlank := {
		"zuschauer": voll.get("zuschauer", 0),
		"hallenpuls": voll.get("hallenpuls", 50.0),
		"spieler_des_spiels": voll.get("spieler_des_spiels", ""),
		"knapp": true,
	}
	for seite in ["heim", "gast"]:
		var t: Dictionary = voll.get(seite, {})
		if t.is_empty():
			continue
		schlank[seite] = {
			"cid": t.get("cid", ""),
			"tore": t.get("tore", 0),
			"stats": t.get("stats", {}),
			"spieler": {},
			"wurfkarte": {},
			"taktik": t.get("taktik", {}),
		}
	return schlank

## Fasst die Partie zusammen (fuer Bericht, Statistik und Presse).
func bericht() -> Dictionary:
	var bester := _spieler_des_spiels()
	return {
		"heim": _team_bericht(heim),
		"gast": _team_bericht(gast),
		"zuschauer": zuschauer,
		"hallenpuls": hallenpuls,
		"spieler_des_spiels": bester,
		"ticker": _ticker_kurz(),
	}

const BERICHT_FELDER := ["sekunden", "tore", "wuerfe", "assists", "paraden", "gegentore",
	"blocks", "fehler", "zeitstrafen", "ballgewinne", "rot", "bewertung", "siebenmeter",
	"siebenmeter_tore", "kraft"]

func _team_bericht(t: Dictionary) -> Dictionary:
	var spieler := {}
	for sid in t["zustand"].keys():
		var z: Dictionary = t["zustand"][sid]
		if float(z["sekunden"]) <= 0.0:
			continue
		# Nur die Ergebnisfelder aufheben — Zwischenspeicher gehoert nicht in den Spielstand.
		var schlank := {}
		for feld in BERICHT_FELDER:
			schlank[feld] = z.get(feld, 0)
		spieler[sid] = schlank
	return {
		"cid": t["cid"],
		"tore": t["tore"],
		"stats": (t["stats"] as Dictionary).duplicate(),
		"wurfkarte": (t["wurfkarte"] as Dictionary).duplicate(true),
		"spieler": spieler,
		"taktik": (t["taktik"] as Dictionary).duplicate(),
	}

func _spieler_des_spiels() -> String:
	var best := ""
	var bw := 99.0
	for t in [heim, gast]:
		for sid in t["zustand"].keys():
			var z: Dictionary = t["zustand"][sid]
			if float(z["sekunden"]) < 600.0:
				continue
			var b: float = float(z["bewertung"])
			if b < bw:
				bw = b
				best = sid
	return best

func _ticker_kurz() -> Array:
	var wichtig: Array = []
	for e in ereignisse:
		if str(e["typ"]) in ["tor", "zeitstrafe", "rot", "auszeit", "halbzeit", "ende", "lauf", "siebenmeterwerfen"]:
			# Die Seite gehoert dazu: ohne sie laesst sich spaeter nicht sagen,
			# wer das Tor geworfen hat.
			wichtig.append({"zeit": e["zeit"], "typ": e["typ"], "text": e["text"],
				"stand": e["stand"], "team": e.get("team", "")})
	return wichtig
