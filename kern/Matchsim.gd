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

## Die Abwehrformationen. Ein hoher Wert heisst durchweg: hier steht die
## Abwehr gut — ausser bei "zeitstrafe", wo er heisst, dass es haeufiger
## gepfiffen wird, und bei "kraft", wo er den Verbrauch meint.
##
## Zwei Dinge standen hier falsch, und beide fielen erst auf, als "kreis",
## "aussen" und "fern" ueberhaupt gelesen wurden (siehe deckungswirkung).
##
## Erstens die Richtung an den Aussenpositionen: die 6-0 war als schlechter
## eingetragen als die 4-2. Eine tiefe, kompakte Abwehr ist am Kreis und an
## den Fluegeln stark und laesst von neun Metern werfen; eine offene 4-2 macht
## genau das Gegenteil. Das ist der eigentliche Handel zwischen den beiden,
## und er stand verkehrt herum in der Tabelle.
##
## Zweitens die Spanne beim Ballgewinn. 0,84 gegen 1,40 sind zwei Drittel mehr
## eroberte Baelle — ueber eine Partie rund sechs zusaetzliche Ballverluste
## des Gegners, und die meisten davon werden zu Tempogegenstoessen. Gegen
## diesen Betrag kommt keine Formation an; gemessen lag die 4-2 gegen einen
## gleichstarken Gegner elfeinhalb Tore vor der 6-0. Im Handball presst eine
## offene Deckung mehr, aber nicht um zwei Drittel.
const DECKUNG := {
	"6-0": {"block": 1.12, "ballgewinn": 0.90, "zeitstrafe": 0.88, "kreis": 1.18, "aussen": 1.10, "fern": 0.84, "kraft": 0.95},
	"5-1": {"block": 1.02, "ballgewinn": 1.00, "zeitstrafe": 1.02, "kreis": 1.06, "aussen": 1.02, "fern": 1.00, "kraft": 1.0},
	"3-2-1": {"block": 0.94, "ballgewinn": 1.10, "zeitstrafe": 1.22, "kreis": 0.88, "aussen": 0.94, "fern": 1.12, "kraft": 1.12},
	"4-2": {"block": 0.88, "ballgewinn": 1.18, "zeitstrafe": 1.44, "kreis": 0.74, "aussen": 0.86, "fern": 1.20, "kraft": 1.22},
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
## Wie sich das Publikum auf Steh-, Sitz- und Logenplätze verteilt.
var zuschauer_aufschluesselung: Dictionary = {}
## Das eingelöste Spieltagsprogramm dieser Partie.
var programm: Dictionary = {}
var live: bool = false
## Das Gespann dieser Partie und seine Tagesform. Beides steht vor dem Anwurf
## fest und ändert sich bis zum Schlusspfiff nicht mehr.
var gespann: Dictionary = {}
var gespann_tagesform: float = 1.0

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
	# Der Hallenpuls hängt nicht an der Auslastung allein: ein voller Block
	# Stehplätze trägt mehr als eine ausverkaufte Loge, und die Stimmung der
	# Fanszene entscheidet, ob überhaupt jemand den Mund aufmacht.
	hallenpuls = clampf(float(daten["vereine"][spiel["heim"]]["hallenpuls_basis"])
		* (0.66 + 0.34 * _stimmungsanteil())
		* Fanszene.pulsfaktor(daten, str(spiel["heim"]))
		+ float(programm.get("puls", 0.0)), 15.0, 98.0)
	# Erst bereiten die Computertrainer sich auf diesen Gegner vor, dann gilt
	# der Plan. Gelesen wird dabei nur, was der Gegner bisher gespielt hat —
	# nicht, was er heute vorhat. Ein Trainer, der die Aufstellung des Gegners
	# vor dem Anwurf kennt, wäre kein Gegner, sondern ein Hellseher.
	if str(spiel.get("art", "")) != "turnier":
		KI.matchplan_stellen(daten, str(heim["cid"]), str(gast["cid"]), str(spiel.get("id", "")))
		KI.matchplan_stellen(daten, str(gast["cid"]), str(heim["cid"]), str(spiel.get("id", "")))
	# Der Matchplan gilt nur gegen den Verein, für den er gemacht wurde.
	heim["gegnerplan"] = Gegnerplan.fuer(daten, str(heim["cid"]), str(gast["cid"]))
	gast["gegnerplan"] = Gegnerplan.fuer(daten, str(gast["cid"]), str(heim["cid"]))
	# Und was heute gespielt wird, geht in die Akte — für das nächste Mal.
	if str(spiel.get("art", "")) != "turnier":
		KI.stil_verbuchen(daten, str(heim["cid"]), str(heim["taktik"].get("angriff", "positionsangriff")))
		KI.stil_verbuchen(daten, str(gast["cid"]), str(gast["taktik"].get("angriff", "positionsangriff")))
	gespann = Schiedsrichter.fuer_partie(daten, str(spiel["id"]))
	gespann_tagesform = Schiedsrichter.tagesform(gespann, rng)
	angriffsrecht = "heim" if rng.randf() < 0.5 else "gast"
	zeit = 0.0
	beendet = false
	_warteschlange.append(_ereignis("anwurf", angriffsrecht, "", "Anwurf in der %s. %s Zuschauer sind da." % [
		daten["vereine"][spiel["heim"]]["halle"]["name"], Stil.zahl(zuschauer)]))
	if not gespann.is_empty():
		_warteschlange.append(_ereignis("gespann", "", "", "Es pfeift das Gespann %s." % Schiedsrichter.namen_lang(gespann)))
	# Was sich eine Mannschaft für diese Partie vorgenommen hat, sieht man in
	# den ersten Minuten auf der Platte — also steht es im Ticker. Eine
	# Gegenmaßnahme, die unsichtbar bleibt, ist keine Entscheidung, auf die
	# man reagieren kann, sondern eine Zahl, die anders ausfällt.
	_matchplan_melden(heim, "heim")
	_matchplan_melden(gast, "gast")

func _matchplan_melden(t: Dictionary, seite: String) -> void:
	var p: Dictionary = t["gegnerplan"]
	if p.is_empty() or str(p.get("mittel", "keins")) == "keins":
		return
	_warteschlange.append(_ereignis("matchplan", seite, "", "%s hat sich etwas vorgenommen — %s" % [
		str(daten["vereine"][str(t["cid"])]["name"]), Gegnerplan.beschreibung(daten, p)]))

func _auslastung() -> float:
	var kap: float = maxf(float(daten["vereine"][spiel["heim"]]["halle"]["kapazitaet"]), 1.0)
	return clampf(float(zuschauer) / kap, 0.0, 1.0)

## Wie voll die lauten Blöcke sind. Fällt auf die reine Auslastung zurück,
## wenn keine Aufschlüsselung vorliegt (Turnierspiele, alte Spielstände).
func _stimmungsanteil() -> float:
	if zuschauer_aufschluesselung.is_empty():
		return _auslastung()
	return Ticketing.pulsanteil(zuschauer_aufschluesselung)

## Wer heute kommt. Die Rechnung liegt in kern/Ticketing.gd — hier steht nur,
## was diese eine Partie daran verschiebt: der Gegner, das Derby, der
## Wettbewerb und das Spieltagsprogramm.
func _zuschauer_berechnen() -> int:
	var cid: String = str(spiel["heim"])
	var g: Dictionary = daten["vereine"][spiel["gast"]]
	var reiz: float = 1.0
	reiz += clampf((float(g["ruf"]) - 45.0) / 220.0, -0.14, 0.4)
	if float((daten["vereine"][cid]["rivalen"] as Dictionary).get(g["id"], 0.0)) > 50.0:
		reiz += 0.22
	if str(spiel["art"]) == "international":
		reiz += 0.16
	elif str(spiel["art"]) == "test":
		reiz -= 0.3
	reiz *= Fanszene.besuchsreiz(daten, cid)
	# Das Spieltagsprogramm wird hier eingelöst: einmal je Heimspiel, mit
	# Kosten, Wirkung aufs Publikum und Nachhall in der Fanszene.
	programm = Spieltagsprogramm.einloesen(daten, cid)
	zuschauer_aufschluesselung = Ticketing.besucher(daten, cid, reiz,
		rng.randf_range(0.93, 1.06), programm.get("reiz", {}))
	return int(zuschauer_aufschluesselung["gesamt"])

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
			"gegenstoss_wuerfe": 0, "sieben_gegen_sechs": 0,
			"ballgewinne": 0, "wechsel": 0, "puls_hoch": 0.0, "verwarnungen": 0,
			"vorwarnungen_passiv": 0},
		# Wurfkarte: je Abschlussposition gezaehlt, was daraus geworden ist.
		# Nur Summen, keine Einzelwuerfe — der Spielstand soll schlank bleiben.
		"wurfkarte": {},
		"siebenmeter_schuetze": str(auf.get("siebenmeter", "")),
		"sieben_gegen_sechs": false,
		"ueberzahl": 0,
		"vorwarnung": false,
		"letzte_wechselpruefung": -999.0,
		"ansprache": 0.0,
		"ansprachen": [],
		# Individuelle Spieleranweisungen (siehe kern/Anweisungen.gd)
		"anweisungen": (auf.get("anweisungen", {}) as Dictionary).duplicate(true),
		# Zielminuten je Spieler (siehe kern/Einsatzzeit.gd). Leer heisst:
		# es rotiert allein die Kraft.
		"minutenziele": (auf.get("minuten", {}) as Dictionary).duplicate(true),
		# --- Werte, die eine Partie lang gleich bleiben ---------------------
		# Sie bei jedem Angriff neu zu holen kostete zwei Drittel der Rechen-
		# zeit eines Spieltags: bei 68 Partien am Tag ist das der Unterschied
		# zwischen einem Ruckler und einem Knopfdruck.
		"teamfaktor": Kabine.teamfaktor(daten, cid),
		"praevention": Medizin.praeventionsfaktor(daten, cid),
		"bonus_tempodiktat": Trainerkarriere.bonus_fuer(daten, cid, "tempodiktat"),
		"bonus_kontrolleur": Trainerkarriere.bonus_fuer(daten, cid, "kontrolleur"),
		"bonus_betonmischer": Trainerkarriere.bonus_fuer(daten, cid, "betonmischer"),
		"bonus_hexer": Trainerkarriere.bonus_fuer(daten, cid, "hexer"),
		# Wie gut die Mannschaft ihre beiden Formationen wirklich kann. Steht
		# vor dem Anwurf fest und ändert sich in der Partie nicht mehr.
		"vertraut_abwehr": Vertrautheit.faktor(daten, cid, "abwehr", str(taktik.get("abwehr", "6-0"))),
		"vertraut_angriff": Vertrautheit.faktor(daten, cid, "angriff", str(taktik.get("angriff", "positionsangriff"))),
		# Das Spielbuch und was daraus in dieser Partie tatsächlich gelaufen
		# ist — Letzteres geht nach dem Schlusspfiff zurück ins Training.
		"spielbuch": Spielzuege.buch(daten, cid),
		"zug_gelaufen": {},
		# Der Zug des laufenden Angriffs. Wird in _angriff_ausspielen gesetzt
		# und von _wurfposition und _angriffsdauer mitgelesen.
		"zug": "", "zug_wirkung": {},
		# Der Matchplan gegen genau diesen Gegner. Wird in vorbereiten()
		# gesetzt, weil er erst dort feststeht.
		"gegnerplan": {},
		# Reibung in der Sieben: wie viel Abstimmung zwei Zerstrittene auf dem
		# Feld kosten. Wird bei jedem Wechsel neu bestimmt (siehe cache).
		# Cache für alles, was sich erst mit einem Wechsel ändert.
		"cache": {},
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
	# Spieltagskader: sieben auf der Platte, der Rest auf der Bank — zusammen
	# hoechstens 14. Wer darueber hinaus im Kader steht, sitzt an diesem Tag
	# auf der Tribuene und taucht in der Partie gar nicht auf.
	var im_aufgebot := {}
	for pos_a in (t["angriff_auf"] as Dictionary).values():
		if str(pos_a) != "":
			im_aufgebot[str(pos_a)] = true
	for pos_b in (t["abwehr_auf"] as Dictionary).values():
		if str(pos_b) != "":
			im_aufgebot[str(pos_b)] = true
	var vorgabe: Array = auf.get("bank", [])
	for sid in vorgabe:
		if im_aufgebot.size() >= Weltgenerator.SPIELTAGSKADER:
			break
		if ersatz_pool.has(sid) and not im_aufgebot.has(sid):
			im_aufgebot[sid] = true
			t["bank"].append(sid)
	for sid in ersatz_pool:
		if im_aufgebot.size() >= Weltgenerator.SPIELTAGSKADER:
			break
		if not im_aufgebot.has(sid):
			im_aufgebot[sid] = true
			t["bank"].append(sid)
	ersatz_pool = im_aufgebot.keys()
	var reise := _reisefaktor(cid, ist_heim)
	for sid in ersatz_pool:
		var sp_cache: Dictionary = daten["spieler"][sid]
		t["zustand"][sid] = {
			"kraft": clampf((float(sp_cache["fitness"]) - float(sp_cache["last"]) * 0.18) * reise,
				40.0 * reise, 100.0),
			"tagesform": Spielerfabrik.tagesform(sp_cache),
			"basis_abwehr": Spielerfabrik.abwehrwert(sp_cache),
			"basis_angriff": {},
			# Ausdauer und Verletzungsanfälligkeit ändern sich in einer Partie
			# nicht — sie werden aber in jedem Angriff gebraucht.
			"ausdauer": float(sp_cache["attr"]["ausdauer"]) / 20.0,
			"risiko_basis": Medizin.risiko_roh(sp_cache),
			"sekunden": 0.0, "tore": 0, "wuerfe": 0, "assists": 0, "paraden": 0, "gegentore": 0,
			"blocks": 0, "fehler": 0, "zeitstrafen": 0, "verwarnungen": 0, "ballgewinne": 0,
			"gegenstoss_tore": 0, "rot": false,
			"bewertung": 3.4, "siebenmeter": 0, "siebenmeter_tore": 0,
		}
	if str(t["siebenmeter_schuetze"]) == "" or not t["zustand"].has(t["siebenmeter_schuetze"]):
		t["siebenmeter_schuetze"] = _bester_siebenmeter(t)
	return t

## Was die Anreise kostet.
##
## Eine Auswaertsfahrt zum Nachbarn ist ein Bus und zwei Stunden; ein
## Europapokalspiel in einem anderen Land ist Flughafen, Umsteigen, fremdes
## Hotel und eine kurze Nacht. Bisher war beides gleich viel wert, naemlich
## nichts. Das nahm dem internationalen Wettbewerb den Teil, der ihn im
## Kalender wirklich teuer macht.
func _reisefaktor(cid: String, ist_heim: bool) -> float:
	if ist_heim:
		return 1.0
	var art: String = str(spiel.get("art", "liga"))
	if art == "international":
		var eigene: String = str(daten["vereine"][cid].get("nation", ""))
		var gastgeber: String = str(daten["vereine"][spiel["heim"]].get("nation", ""))
		# Im eigenen Land ist auch ein europaeisches Spiel nur eine Busfahrt.
		return 0.955 if eigene != gastgeber else 0.985
	# Im Inland bleibt es bei 1.0. Eine Busfahrt zum Nachbarn kostet nichts,
	# was nicht schon im Hallenpuls steckt — beides zu zaehlen hiesse, den
	# Heimvorteil doppelt zu berechnen, und genau das hat in der Messung die
	# Heimsiegquote von 55 auf 64 Prozent getrieben.
	return 1.0

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

## Wie sehr sich einer als Siebenmeterschuetze anbietet. Der im Datensatz
## hinterlegte Stammschuetze setzt sich immer durch — sonst muesste sein
## Attributwert kuenstlich hoch stehen, und genau der sagt im Spiel aus, wie
## oft er trifft. Ein Verein ohne hinterlegten Schuetzen waehlt wie bisher.
func _siebenmetereignung(sp: Dictionary) -> float:
	var w: float = float(sp["attr"]["siebenmeter"]) * 2.0 + float(sp["attr"]["nervenstaerke"])
	if bool(sp.get("stammschuetze", false)):
		w += 100.0
	return w

func _bester_siebenmeter(t: Dictionary) -> String:
	var best := ""
	var bw := -1.0
	for sid in t["zustand"].keys():
		var sp: Dictionary = daten["spieler"][sid]
		if bool(sp["ist_torwart"]):
			continue
		var w: float = _siebenmetereignung(sp)
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
	a["vorwarnung"] = dauer >= PASSIV_AB and not _gegenstoss
	v["vorwarnung"] = false
	if bool(a["vorwarnung"]):
		a["stats"]["vorwarnungen_passiv"] = int(a["stats"].get("vorwarnungen_passiv", 0)) + 1
		_warteschlange.append(_ereignis("passiv", _seite(a), "",
			Textbank.satz(Textbank.PASSIV, rng, str(a["name"]))))
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

## Ab wie vielen Sekunden vor Schluss der Spielstand das Verhalten aendert.
## Wie stark der Unterschied zwischen Angriff und Abwehr auf den einzelnen
## Wurf durchschlaegt.
const WURF_EMPFINDLICHKEIT := 0.0072

## Wieviel der reine Mannschaftsunterschied am Wurf wert ist.
##
## WURF_EMPFINDLICHKEIT allein reicht dafuer nicht: sie haengt am Koennen des
## einzelnen Werfers gegen den Torhueter, und das schwankt von Wurf zu Wurf —
## wer daran dreht, verstaerkt den Zufall genauso wie den Unterschied.
## Gemessen (werkzeuge/Tabellensonde.gd): die Empfindlichkeit von 0,0072 auf
## 0,0110 zu heben brachte dem Staerkepunkt 0,08 Tore mehr und der einzelnen
## Partie 0,6 Tore mehr Streuung — die Tabelle blieb, wo sie war.
##
## Dieser Zuschlag haengt dagegen am Unterschied zwischen Angriffs- und
## Abwehrkraft der beiden Mannschaften. Der steht fuer eine Partie praktisch
## fest: er traegt Staerke ins Ergebnis, ohne Rauschen mitzubringen. Ohne ihn
## kam der Meister auf dreiundfuenfzig Punkte und die Tabelle streute um
## elf — mit ihm sind es siebenundfuenfzig und zwoelfeinhalb. In der
## Bundesliga holt der Meister zwischen achtundfuenfzig und
## vierundsechzig Punkten von achtundsechzig.
const STAERKE_AM_WURF := 0.0036
const STAERKE_GRENZE := 40.0

## Trefferquote eines Wurfs von dieser Position, wenn sich gleich starke
## Mannschaften gegenueberstehen.
##
## Bis hierher traf jeder Wurf gleich wahrscheinlich, egal ob er vom Kreis kam
## oder aus zehn Metern ueber einen formierten Block ging. Genau das ist der
## Kern des Handballs: **die Position entscheidet ueber den Abschluss, nicht
## erst der Werfer.** Das Modell dahinter heisst im Handball SPAM (Shot
## Position Average Model) und wird als "Expected Goals" veroeffentlicht — der
## unbedraengte Kreiswurf liegt bei gut 0,8, der Aussenwurf bei rund 0,64, der
## Fernwurf ueber den Block bei 0,3 bis 0,45.
##
## Die Werte hier liegen bewusst etwas unter den reinen xG-Spitzenwerten: sie
## gelten fuer *alle* Wuerfe von dieser Position, also auch fuer den
## bedraengten Kreiswurf und den Aussenwurf aus spitzem Winkel, und sie sind an
## den veroeffentlichten Wurfquoten der Bundesliga ausgerichtet.
## Die Werte gelten fuer das gewoehnliche 6-gegen-6. Ueberzahl, Unterzahl und
## der siebte Feldspieler kommen obendrauf — deshalb liegt der gemessene
## Ligaschnitt ein paar Prozentpunkte darueber, genau wie in Wirklichkeit.
const TREFFER_POSITION := {
	"LA": 0.583, "RA": 0.583, "KM": 0.692, "RL": 0.456, "RM": 0.475, "RR": 0.456,
}
## Wie stark eine Abwehr darauf reagiert, dass ein Angriff immer dieselbe
## Position sucht.
##
## Hier lag die goldene Regel. Der Kreiswurf trifft zu 69 Prozent, der
## Rueckraumwurf zu 46 — und der Angriffsstil durfte achtunddreissig Prozent
## der Wuerfe an den Kreis schieben, ohne dass es etwas kostete. Damit war
## "Kreisfokus" in jeder Lage die beste Wahl: gegen den Staerksten, auf
## Augenhoehe und gegen den Schwaechsten. Gemessen mit
## werkzeuge/Hebelsonde.gd, Feld "goldregel".
##
## In Wirklichkeit gibt es diesen Freibetrag nicht. Wer immer den Kreis sucht,
## bekommt ihn zugestellt: die Abwehr sackt ein, der Anspielweg ist zu, und
## der Kreislaeufer wirft bedraengt statt frei. Umgekehrt steht der Fluegel
## plotzlich allein, wenn nie jemand zu ihm passt. Genau das macht dieser
## Faktor — er zieht von der Wurfquote ab, was der Stil einer Position an
## Aufmerksamkeit zuschanzt, und schlaegt drauf, was er ihr nimmt.
##
## Der Wert ist so gewaehlt, dass kein Stil mehr flaechendeckend der beste
## ist. Was danach entscheidet, ist die Deckung des Gegners und die Frage,
## wer im eigenen Kader ueberhaupt trifft.
const FOKUS_STRAFE := 0.22

## Was die Abwehrformation an dieser Wurfposition wirklich ausrichtet.
##
## Hier fehlte die halbe Deckungstabelle. Die Formationen oben tragen sieben
## Spalten, aber nur vier davon wurden je gelesen: Block, Ballgewinn,
## Zeitstrafe und Kraftverbrauch. Was eine Abwehr eigentlich ausmacht — wo sie
## dicht ist und wo sie Löcher hat — stand in "kreis", "aussen" und "fern" und
## wirkte nirgends.
##
## Damit war die 6-0 eine Falle: ihre einzige Stärke ist, dass am Kreis nichts
## durchgeht, und genau die war nicht eingebaut. Uebrig blieb eine Formation,
## die schlechter Baelle gewinnt als jede andere. Gemessen gegen eine
## gleichstarke Mannschaft lag sie achteinhalb Tore hinter der 4-2 — die
## meistgespielte Abwehr des deutschen Handballs war die schlechteste Wahl
## des Spiels.
##
## Jetzt entscheidet die Formation mit, von wo geworfen wird. Und zwar vor
## allem darueber, wohin der Angriff ueberhaupt kommt — nicht darueber, wie
## gut ein schon angesetzter Wurf sitzt.
##
## Der Unterschied ist nicht akademisch. Im ersten Versuch verschob die
## Formation nur die Trefferquote, und damit wurde die 6-0 noch schlechter:
## der Fernwurf ist mit 46 Prozent ohnehin der wertloseste Abschluss des
## Spiels, und ihn zusaetzlich um zwoelf Prozent aufzuwerten, zaehlt denselben
## Vorteil zweimal. Eine tiefe Abwehr ist deshalb gut, weil sie den Gegner
## *zwingt*, von neun Metern zu werfen — also gehoert ihre Wirkung in die
## Wurfverteilung. Wer innen zumacht, bekommt Fernwuerfe; wer vorne presst,
## laesst Kreis und Aussen frei.
##
## Am Abschluss bleibt ein kleiner Rest: ein Wurf gegen eine Abwehr, die genau
## dort steht, ist auch bedraengter. Mehr als ein Rest darf es nicht sein.
const DECKUNG_WIRKUNG := 0.28
## Wie stark die Formation die Wurfverteilung verschiebt.
const DECKUNG_VERTEILUNG := 1.0

static func deckungswirkung(td: Dictionary, pos: String) -> float:
	var schluessel := ""
	match pos:
		"KM":
			schluessel = "kreis"
		"LA", "RA":
			schluessel = "aussen"
		"RL", "RM", "RR":
			schluessel = "fern"
		_:
			return 1.0
	# In der Tabelle heisst ein hoher Wert "hier steht die Abwehr gut". Auf die
	# Wurfquote schlaegt er deshalb nach unten durch.
	var f: float = float(td.get(schluessel, 1.0))
	return clampf(1.0 - (f - 1.0) * DECKUNG_WIRKUNG, 0.86, 1.14)

## Wie die Abwehrformation den Weg des Angriffs verschiebt: wo sie steht,
## kommt seltener jemand zum Wurf.
static func deckungsverteilung(td: Dictionary, pos: String) -> float:
	var schluessel := ""
	match pos:
		"KM":
			schluessel = "kreis"
		"LA", "RA":
			schluessel = "aussen"
		"RL", "RM", "RR":
			schluessel = "fern"
		_:
			return 1.0
	var f: float = float(td.get(schluessel, 1.0))
	return clampf(1.0 - (f - 1.0) * DECKUNG_VERTEILUNG, 0.55, 1.45)

static func fokusfaktor(stil: String, pos: String) -> float:
	var neutral: Dictionary = WURFVERTEILUNG["positionsangriff"]
	var n: float = float(neutral.get(pos, 0.0))
	if n <= 0.0:
		return 1.0
	var gewaehlt: Dictionary = WURFVERTEILUNG.get(stil, neutral)
	var fokus: float = float(gewaehlt.get(pos, n)) / n
	return clampf(1.0 - (fokus - 1.0) * FOKUS_STRAFE, 0.70, 1.15)

## Der Tempogegenstoss ist der beste Abschluss, den der Handball kennt: ein
## Wurf aus dem Lauf auf einen Torwart, der allein im Tor steht.
const TREFFER_GEGENSTOSS := 0.824
## Und in ein wirklich leeres Tor trifft fast jeder.
const TREFFER_LEERES_TOR := 0.93
## Werfer und Torhueter werden aus verschiedenen Attributsaetzen gerechnet, und
## deren Mittelwerte liegen nicht uebereinander. Ohne Ausgleich zieht dieser
## Unterschied jede Positionsquote um gut vier Prozentpunkte nach unten — die
## Zahlen oben stuenden dann zwar im Code, aber nicht im Spiel. Der Wert ist
## gemessen (werkzeuge/Realismussonde.gd), nicht geschaetzt.
##
## Von 11,1 auf 13,6 gehoben, nachdem der Schongang und die selteneren
## Tempogegenstoesse die Ligaquote unter sechzig Prozent gedrueckt hatten. Ein
## weiterer Schritt auf 14,6 brachte die Quote zwar ueber die Schwelle, kostete
## aber zweieinhalb Punkte an der Tabellenspitze: mehr Tore heisst frueher
## sechs Tore Vorsprung, und dort greift der Schongang.
## Und von 13,6 auf 16,6, nachdem die Abwehrformation die Wurfverteilung
## verschiebt: eine 6-0 draengt den Angriff an die Neunmeterlinie, und dort
## trifft er schlechter. Das ist genau der Zweck der Aenderung — es senkt aber
## den Ligaschnitt, gemessen von 59,4 auf 56,3 Tore je Partie. Der Ausgleich
## hebt alle Positionen gleichmaessig an; Spielraum nach oben war an jeder.
const WURF_AUSGLEICH := 17.8
## Wie weit Koennen, Tagesform und Torwart die Positionsquote hoechstens
## verschieben. Ein ueberragender Kreislaeufer trifft oefter als ein
## durchschnittlicher — aber auch er wirft nicht vom Fluegel wie vom Kreis.
##
## Die Spanne ist ein Kompromiss, und zwar ein gemessener. Enger gefasst
## stimmen Unentschieden und Torabstand besser, weiter gefasst faechern die
## Ergebnisse auf.
##
## Lange stand hier, beides zugleich gehe nicht: eine einzelne Partie streue
## nun einmal um sechs Tore, und die kaemen allein aus den fuenfzig Wuerfen je
## Mannschaft. Das erste stimmte, das zweite nicht. Die Streusonde hat die
## sechs Tore zerlegt — knapp fuenf sind Wurfzufall, der Rest kam aus
## Hallenpuls, Heimvorteil und der Wurfdifferenz. Der Ausweg lag also nicht in
## dieser Spanne, sondern darin, den Staerkeunterschied am Wurf getrennt zu
## gewichten (STAERKE_AM_WURF) und das Rauschen daneben kleiner zu machen.
const WURF_UNTEN_ANTEIL := 0.52
const WURF_OBEN_ANTEIL := 1.46
## Trefferquote am Siebenmeterstrich bei gleich starker Paarung. Der Ligaschnitt
## liegt seit Jahren bei rund drei Vierteln.
const SIEBENMETER_GRUND := 0.805

const SCHLUSSPHASE := 1800.0
const DRUCK_LEER := {"tempo": 0.0, "risiko": 0.0, "angriff": 1.0, "abwehr": 1.0,
	"abschluss": 0.0, "dauer": 1.0}
## Wie stark ein Torabstand treibt.
##
## Der Verlauf ist bewusst steil: bei einem oder zwei Toren Unterschied
## entscheidet sich eine Handballpartie, und dort ziehen beide Mannschaften
## alles heraus, was sie haben — Auszeit, siebter Feldspieler, die beste
## Sieben, kein Wurf aus der Verlegenheit. Bei vier Toren Rueckstand wird
## dagegen nur noch gespielt, nicht mehr gerechnet. Genau diese Verteilung
## erzeugt die vielen knappen Ergebnisse, fuer die der Handball bekannt ist:
## in der Bundesliga endet jede achte Partie unentschieden.
const ABSTAND_GEWICHT := [0.0, 1.0, 0.78, 0.40, 0.18, 0.08, 0.03]
const R_TEMPO := 34.0
const R_RISIKO := 5.0
const R_ANGRIFF := 0.16
const F_ANGRIFF := -0.14
## Was ein Feldspieler mehr oder weniger auf der Platte wert ist.
##
## Eine Zeitstrafe ist im Handball die teuerste Strafe des Sports: zwei Minuten
## in Unterzahl kosten im Schnitt ein Tor. Gerechnet wurde das bisher als
## Zuschlag auf den Staerkevergleich — und davon kam am Wurf nicht einmal ein
## Prozentpunkt an. Eine Hinausstellung war praktisch folgenlos. Deshalb wirkt
## die Ueber- und Unterzahl hier direkt: auf die Trefferquote und auf die
## Fehlerquote, also genau dort, wo sie im Handball wehtut.
const UEBERZAHL_ABSCHLUSS := 0.075
const UEBERZAHL_FEHLER := 0.22
## Wieviel unsauberer ein Angriff mit sieben Feldspielern laeuft.
const SIEBTER_FEHLER := 1.18
## Wie oft ein Ballverlust im 7-gegen-6 dem Gegner einen freien Wurf auf das
## leere Tor gibt — und wie oft der dann sitzt. Vierzig Meter sind auch fuer
## einen Profi kein Selbstlaeufer.
const LEERES_TOR_WURF := 0.42
const LEERES_TOR_TREFFER := 0.72

## Was der Spielstand direkt am Abschluss aendert.
##
## Der Umweg ueber die Mannschaftsstaerke war wirkungslos: ein Angriffswert von
## sechzig, um sechzehn Prozent erhoeht, verschiebt die Trefferquote um einen
## halben Prozentpunkt — ueber fuenfzehn Angriffe sind das null Komma eins
## Tore. Gemessen hatte die Schlussphase damit gar keinen Einfluss. Der
## Zuschlag hier wirkt dort, wo er hingehoert: auf den Wurf.
const R_ABSCHLUSS := 0.225
const F_ABSCHLUSS := -0.195
## Uhrmanagement: wer knapp fuehrt, zieht die letzten Angriffe in die Laenge,
## bis das Vorwarnzeichen kommt. Das ist der wirksamste Hebel, den eine
## fuehrende Mannschaft in der Schlussphase hat — nicht der bessere Wurf,
## sondern der Angriff, der eine halbe Minute frisst.
const UHRPHASE := 480.0
const F_DAUER := 2.10
const R_DAUER := 0.52

## Passives Spiel (Regel 7:11-12).
##
## Im Handball gibt es keine Wurfuhr. Stattdessen heben die Schiedsrichter nach
## eigenem Ermessen den Arm, wenn eine Mannschaft das Spiel verzoegert, ohne
## etwas fuer das Tor zu tun (Handzeichen 17). Danach hat sie hoechstens sechs
## Paesse Zeit: wer dann nicht wirft, gibt den Ball ab.
##
## Die Simulation rechnet angriffsweise, nicht passweise — das Mass ist deshalb
## die Dauer des Angriffs. Wer den Ball ueber vierzig Sekunden haelt, sieht das
## Vorwarnzeichen, und danach faellt der Abschluss so aus, wie er in dieser
## Lage eben ausfaellt: ein unvorbereiteter Wurf aus dem Rueckraum mit
## schlechter Quote. Das verzahnt sich mit dem Uhrmanagement der Schlussphase —
## genau die Mannschaft, die die Uhr herunterspielt, holt sich das
## Vorwarnzeichen ab.
const PASSIV_AB := 40.0
const PASSIV_ABSCHLAG := 0.115
const PASSIV_ABPFIFF := 0.13

## Ab wann eine klare Fuehrung die Partie entscheidet — und was das aendert.
##
## In der Bundesliga spielt niemand eine Partie, die in der 45. Minute acht
## Tore vorn liegt, zu Ende wie beim 2:2. Die Stammkraefte setzen sich hin, der
## Zug geht aus dem Angriff, die Abwehr steht nur noch. Genau das fehlte: die
## Simulation warf weiter drauf, und die Ergebnisse fielen entsprechend hoch
## aus — sieben Tore Abstand im Mittel, in Wirklichkeit gut fuenf.
##
## Beide Zahlen sind gemessen und liegen gegenlaeufig: ein staerkerer Abzug am
## Abschluss drueckt die Partien mit zehn Toren Abstand, kostet aber die
## Wurfquote der Liga und vor allem Tabellenpunkte — er bestraft ja immer die
## fuehrende und damit meist die bessere Mannschaft. Bei -0,24 kam der Meister
## auf dreiundfuenfzig Punkte, bei -0,15 auf siebenundfuenfzig.
## Sechs Tore und nicht vier: bei vier traf der Abzug die Fuehrung in Spielen,
## die noch zu kippen waren, und kostete damit genau die Mannschaft Punkte, die
## am haeufigsten fuehrt — die beste. Ab sechs greift er nur noch dort, wo die
## Kantersiege entstehen.
const SCHONGANG_AB := 1800.0
const SCHONGANG_VORSPRUNG := 6
const SCHONGANG_ABSCHLUSS := -0.300
## Und wieviel laenger sie sich fuer einen Angriff Zeit laesst.
##
## Hier und nicht am Abschluss liegt der Hebel gegen die Kantersiege. Ein
## staerkerer Abzug an der Trefferquote druckt zwar die hohen Ergebnisse,
## bestraft aber immer die fuehrende und damit meist die bessere Mannschaft
## und kostet sie Tabellenpunkte — der Meister steht ohnehin schon knapp unter
## dem Zielband. Eine laengere Angriffszeit kostet dagegen kaum Siege: sie
## nimmt beiden Mannschaften Angriffe, und wer mit acht Toren vorn liegt,
## gewinnt auch mit sechs.
##
## Gemessen ueber zwoelf Spielzeiten, 3672 Partien, gleiche Saaten:
##
##             0,90    1,45    2,10   Ziel
##   >=10 Tore 19,0 %  17,9 %  17,4 %  15 %
##   Streuung   7,21    7,04    7,03   6,8
##   Abstand    5,50    5,39    5,38   5,4
##   <=2 Tore  35,5 %  35,7 %  35,9 %  36 %
##   Meister   55,50   55,50   56,25   56 bis 66
##   Spanne    45,08   43,83   46,33   44 bis 56
##
## Die engen Partien bleiben unberuehrt, und der Meister verliert keinen
## Punkt — bei 2,10 steht er erstmals im Zielband, weil der Letzte in
## entschiedenen Partien weniger Kosmetiktore bekommt.
## Weiter anzuheben bringt nichts mehr — gemessen.
##
## Nachdem Haerte und Risiko wirklich wirken, stiegen die Klatschen von 17,4
## auf 19,6 Prozent. Der Versuch, das mit einem langsameren Auslaufen
## aufzufangen, ist gescheitert: von 2,10 auf 3,00 blieben die Klatschen bei
## 19,7 Prozent, waehrend die engen Partien von 34,4 auf 33,2 Prozent fielen
## und die Wurfquote der Liga auf die untere Grenze von 0,60 rutschte. Der
## Hebel greift erst ab sechs Toren Vorsprung nach der dreissigsten Minute —
## die zusaetzlichen Klatschen entstehen frueher.
##
## Also bleibt es bei 2,10, und die Klatschen bleiben der Preis dafuer, dass
## Haerte und Risiko keine Fallen mehr sind.
##
## Nachtrag: die 19,6 Prozent von damals stimmen nicht mehr. Nachdem
## WURF_AUSGLEICH die Positionsquoten wieder angehoben hat, sind es 17,7
## Prozent bei einer Streuung des Torabstands von 6,85 — die Wirklichkeit
## nennt 15 Prozent bei 6,8. Die Streuung stimmt damit auf zwei Stellen, und
## der Rest ist kein Streuungsproblem mehr, sondern eine Frage der Randform:
## echter Handball hat weniger Ausreisser, als eine Normalverteilung mit
## dieser Streuung hergibt (erwartet 16,4 Prozent, gemessen 17,7).
## Was dagegen helfen wuerde, muesste vor der dreissigsten Minute greifen,
## denn dort greift der Schongang noch nicht — und genau das ist oben
## zweimal gemessen gescheitert.
const SCHONGANG_DAUER := 2.10
const SCHONGANG_VOLL := 12.0

## Wie eine Mannschaft auf den Spielstand reagiert.
##
## Bis hierher tat sie das gar nicht: wer in der 58. Minute acht Tore hinten
## lag, spielte genauso wie beim 2:2 in der fuenften, und wer zehn vorn lag,
## warf weiter drauf. Beides ist kein Handball, und beides war messbar — die
## Bundesligarunde der Simulation endete in 7,5 Prozent der Partien
## unentschieden, die echte Saison 2025/26 in 13,4 Prozent.
##
## Die Reaktion beginnt eine Viertelstunde vor Schluss und waechst bis zur
## Sirene. Ein Tor Rueckstand treibt am staerksten; wer zweistellig hinten
## liegt, spielt die Partie zu Ende, statt sie zu drehen.
func _spielstandsdruck(t: Dictionary) -> Dictionary:
	var rest: float = SPIELZEIT - zeit
	var diff: int = int(t["tore"]) - (int(gast["tore"]) if t == heim else int(heim["tore"]))
	if rest >= SCHLUSSPHASE:
		return _schongang(diff)
	# Nicht linear, und bewusst steil: in der 45. Minute aendert ein Tor
	# Rueckstand wenig, in der 59. alles. Mit einem flachen Verlauf zog sich
	# die Reaktion ueber die ganze zweite Halbzeit — und nahm der besseren
	# Mannschaft dort ihre Ueberlegenheit, statt nur die Schlussminuten zu
	# praegen. Messbar war das an der Tabelle: der Meister kam nur noch auf
	# fuenfzig Punkte statt auf die knapp fuenfundsechzig der Wirklichkeit.
	var naehe: float = pow(clampf(1.0 - rest / SCHLUSSPHASE, 0.0, 1.0), 2.6)
	if diff == 0:
		return _letzter_angriff(rest)
	var staerke: float = naehe * _abstandsgewicht(absi(diff))
	# Die Uhr zaehlt erst in den letzten sechs Minuten wirklich.
	var uhr: float = clampf(1.0 - rest / UHRPHASE, 0.0, 1.0) * _abstandsgewicht(absi(diff))
	if diff < 0:
		return {"tempo": R_TEMPO * staerke, "risiko": R_RISIKO * staerke,
			"angriff": 1.0 + R_ANGRIFF * staerke, "abwehr": 1.0,
			"abschluss": R_ABSCHLUSS * staerke, "dauer": 1.0 - (1.0 - R_DAUER) * uhr}
	var fuehrung := _schongang(diff)
	return {"tempo": 0.0, "risiko": 0.0, "angriff": 1.0 + F_ANGRIFF * staerke, "abwehr": 1.0,
		"abschluss": F_ABSCHLUSS * staerke + float(fuehrung["abschluss"]),
		"dauer": 1.0 + (F_DAUER - 1.0) * uhr}

## Was eine entschiedene Partie mit der fuehrenden Mannschaft macht.
func _schongang(diff: int) -> Dictionary:
	if zeit < SCHONGANG_AB or diff < SCHONGANG_VORSPRUNG:
		return DRUCK_LEER
	var staerke: float = clampf(float(diff - SCHONGANG_VORSPRUNG + 1)
		/ (SCHONGANG_VOLL - float(SCHONGANG_VORSPRUNG) + 1.0), 0.0, 1.0)
	staerke *= clampf((zeit - SCHONGANG_AB) / 600.0, 0.25, 1.0)
	# Eine Mannschaft, die zehn Minuten vor Schluss fuenf vorn liegt, wirft
	# nicht schlechter — sie wirft spaeter. Deshalb liegt das Gewicht auf der
	# Dauer des Angriffs und nicht auf der Trefferquote: der Vorsprung
	# schrumpft nicht, weil der Kreislaeufer ploetzlich daneben wirft, sondern
	# weil beide Mannschaften weniger Angriffe bekommen. Gemessen hat der
	# umgekehrte Weg die Wurfquote der Liga unter sechzig Prozent gedrueckt.
	return {"tempo": 0.0, "risiko": 0.0, "angriff": 1.0, "abwehr": 1.0,
		"abschluss": SCHONGANG_ABSCHLUSS * staerke, "dauer": 1.0 + SCHONGANG_DAUER * staerke}

## Beim Gleichstand in den Schlussminuten wird der letzte Angriff ausgespielt.
## Wer in der 59. Minute den Ball hat, wirft nicht sofort — er laesst die Uhr
## laufen, damit der Gegner keinen Angriff mehr bekommt.
func _letzter_angriff(rest: float) -> Dictionary:
	if rest > 150.0:
		return DRUCK_LEER
	var d := DRUCK_LEER.duplicate()
	d["dauer"] = 1.0 + 0.95 * clampf(1.0 - rest / 150.0, 0.0, 1.0)
	return d

func _abstandsgewicht(abstand: int) -> float:
	if abstand >= ABSTAND_GEWICHT.size():
		return float(ABSTAND_GEWICHT[ABSTAND_GEWICHT.size() - 1])
	return float(ABSTAND_GEWICHT[abstand])

func _angriffsdauer(a: Dictionary) -> float:
	var t: Dictionary = a["taktik"]
	var druck: Dictionary = _spielstandsdruck(a)
	var tempo: float = clampf(float(t["tempo"]) + float(MENTALITAET[str(t["mentalitaet"])]["tempo"])
		+ float(druck["tempo"]), 0.0, 100.0)
	var basis: float = 43.0 - 0.19 * tempo
	# Uhrmanagement: wer fuehrt, zieht die Angriffe in die Laenge, wer
	# zurueckliegt, kuerzt sie ab. Die Zahl der verbleibenden Angriffe ist in
	# der Schlussphase der eigentliche Einsatz.
	basis *= float(druck.get("dauer", 1.0))
	# Abschlussbereitschaft: eine Mannschaft, in der niemand den Wurf nimmt,
	# spielt sich fest. Das kostet Zeit — und damit Angriffe. Umgekehrt bringt
	# blindes Draufhalten kaum Tempo, sonst waere "Abschluss suchen" fuer alle
	# eine Gratisverbesserung.
	var bereitschaft: float = _anweisungsmittel(a, "angriff_auf", "angriff", "wurfanteil")
	basis += clampf((1.0 - bereitschaft) * 18.0, -3.0, 10.5)
	# Ein Zug hat seine eigene Länge: die zweite Welle ist nach zwanzig
	# Sekunden abgeschlossen, "Ball halten" zieht den Angriff bis zum
	# passiven Vorwarnzeichen.
	basis *= float((a.get("zug_wirkung", {}) as Dictionary).get("dauer", 1.0))
	return clampf(basis + rng.randf_range(-6.0, 6.0), 9.0, 58.0)

# --------------------------------------------- Wirkung der Regler (Anzeige) ---
#
# Die Oberflaeche soll nicht behaupten, was ein Regler tut, sondern es aus
# denselben Formeln ableiten, mit denen hier gerechnet wird. Wer im
# Taktikbildschirm am Tempo zieht, sieht sofort, wie viele Angriffe daraus
# werden — sonst bleibt jeder Regler eine Glaubensfrage.

## Ungefaehre Zahl der Angriffe je Mannschaft bei diesem Tempo.
static func angriffe_bei_tempo(tempo: float, mentalitaet: String = "ausgeglichen") -> int:
	var wirksam: float = clampf(tempo + float((MENTALITAET.get(mentalitaet, MENTALITAET["ausgeglichen"]) as Dictionary)["tempo"]), 0.0, 100.0)
	var dauer: float = 43.0 - 0.19 * wirksam
	# Beide Mannschaften teilen sich die Spielzeit, jeder Angriff gehoert einer.
	return int(round(SPIELZEIT / maxf(dauer, 9.0) / 2.0))

## Anteil der Angriffe, die im technischen Fehler enden.
static func fehlerquote_bei_risiko(risiko: float, mentalitaet: String = "ausgeglichen") -> float:
	var wirksam: float = clampf(risiko + float((MENTALITAET.get(mentalitaet, MENTALITAET["ausgeglichen"]) as Dictionary)["risiko"]), 0.0, 100.0)
	return clampf(0.205 + (wirksam - 50.0) * 0.0009, 0.10, 0.28)

## Wie oft eine Abwehraktion ueberhaupt geahndet wird — Verwarnung oder
## Zeitstrafe. Dass die ersten drei Vergehen einer Mannschaft meist mit Gelb
## abgehen, steckt in _ahnden().
## Was eine harte Abwehr einbringt — und was mehr Risiko im Angriff.
##
## Der Druck wirkt auf den Staerkevergleich am Wurf (Skala wie STAERKE_GRENZE,
## also Punkte), der Ballgewinn auf die Fehlerquote des Gegners.
## Die erste Fassung war zu zaghaft: gemessen sank die Spanne der Haerte nur
## von 4,93 auf 4,27 Tore, und die beste Wahl blieb der untere Anschlag.
##
## Nachgerechnet: ueber die Spanne von 20 bis 90 bringt HAERTE_DRUCK 0,075
## rund 5,3 Punkte im Staerkevergleich, mit STAERKE_AM_WURF also knapp zwei
## Prozent Trefferwahrscheinlichkeit auf rund fuenfzig Wuerfe — etwa ein Tor.
## Der Ballgewinn bringt bei achtzehn Prozent Unterschied auf zehn Fehler
## noch einmal knapp zwei. Zusammen zwei Tore gegen sechs Tore Kosten. Damit
## die Wette eine ist, muss der Nutzen die Kosten ungefaehr aufwiegen, und
## dafuer braucht es das Dreifache.
## Zwei Messungen, zwei Anschläge: bei 0,075 blieb 20 die beste Härte
## (Spanne 4,27 Tore nach unten), bei 0,22 war es 90 (Spanne 2,55 nach oben).
## Der Nulldurchgang liegt dazwischen, linear interpoliert bei rund 0,16 —
## und dort ist die Härte das, was sie sein soll: eine Wette, deren richtige
## Antwort von Gespann, Gegner und Spielstand abhängt statt vom Regler.
##
## Das Risiko sitzt mit 0,25 bereits richtig: gemessen liegt sein Optimum bei
## 45 und nicht am Rand, die Spanne beträgt 1,1 Tore.
const HAERTE_DRUCK := 0.155
const HAERTE_BALLGEWINN := 0.0053
const RISIKO_CHANCE := 0.25

static func ahndungsquote_bei_haerte(haerte: float) -> float:
	return clampf(0.093 + haerte * 0.00105, 0.04, 0.22)

## Wie oft eine Abwehraktion in zwei Minuten endet. Rund die Haelfte der
## geahndeten Vergehen einer Partie kommt nach den drei Verwarnungen.
static func zeitstrafenquote_bei_haerte(haerte: float) -> float:
	return ahndungsquote_bei_haerte(haerte) * 0.55

## Wie oft eine Abwehraktion einen Siebenmeter kostet.
static func siebenmeterquote_bei_haerte(haerte: float) -> float:
	return clampf(0.034 + haerte * 0.00026, 0.015, 0.09)

## Zusaetzlicher Kraftverbrauch durch die Wechselintensitaet, in Prozent.
static func kraftaufschlag_bei_wechselspiel(wechselspiel: float) -> float:
	return clampf(wechselspiel, 0.0, 100.0) / 100.0 * 28.0

# ---------------------------------------------------------- Angriffslogik ---

func _angriff_ausspielen(a: Dictionary, v: Dictionary) -> Dictionary:
	var a_feld: int = _feldspieler(a, true)
	var v_feld: int = _feldspieler(v, false)
	var ueberzahl: int = a_feld - v_feld
	_spielzug_waehlen(a, v, ueberzahl)
	var zug: Dictionary = a["zug_wirkung"]

	var angriffskraft: float = _angriffskraft(a, v)
	var abwehrkraft: float = _abwehrkraft(v, a)
	var diff: float = angriffskraft - abwehrkraft
	# Der Unterschied vor allen Zuschlaegen der Lage: Ueberzahl, Tempogegenstoss
	# und Freiwurf kommen gleich obendrauf, gehoeren aber nicht zur Staerke der
	# Mannschaft. Am Wurf wird beides getrennt gewichtet.
	var grunddiff: float = diff
	var td: Dictionary = _deckungswerte(v)

	# Unter- bzw. Ueberzahl wirkt direkt am Abschluss (siehe
	# UEBERZAHL_ABSCHLUSS); hier bleibt nur der kleine Anteil, der wirklich
	# ueber den Staerkevergleich laeuft — die freieren Wege im Aufbau.
	diff += float(ueberzahl) * 4.0
	a["ueberzahl"] = ueberzahl
	if _gegenstoss:
		diff += 22.0
		if bool(a["bonus_tempodiktat"]):
			diff += 6.0

	# Risiko und Haerte sind Wetten, keine Fallen.
	#
	# Gemessen mit werkzeuge/Hebelsonde.gd hatten beide nur Kosten: das Risiko
	# erhoehte allein die Fehlerquote, die Haerte allein die Zeitstrafen und
	# Siebenmeter. Damit war die beste Wahl immer der niedrigste Wert — bei
	# der Haerte kostete 90 gegenueber 20 ganze 4,9 Tore, beim Risiko 2,0.
	# Ein Regler, dessen Optimum am Anschlag liegt, ist keine Entscheidung,
	# sondern eine Falle fuer den, der ihn anfasst.
	#
	# Im Handball hat beides seine andere Seite. Wer mehr wagt, spielt
	# direkter und kommt zu besseren Abschluessen; wer zupackt, stoert den
	# Aufbau und gewinnt Baelle. Genau das fehlte.
	var haerte: float = clampf(float(v["taktik"]["haerte"]), 0.0, 100.0)
	diff -= (haerte - 45.0) * HAERTE_DRUCK

	# Technischer Fehler / Ballgewinn der Abwehr
	var risiko: float = clampf(float(a["taktik"]["risiko"]) + float(MENTALITAET[str(a["taktik"]["mentalitaet"])]["risiko"])
		+ float(_spielstandsdruck(a)["risiko"]), 0.0, 100.0)
	diff += (risiko - 50.0) * RISIKO_CHANCE
	var p_fehler: float = clampf(0.205 - diff * 0.0008 + (risiko - 50.0) * 0.0009, 0.10, 0.28) * float(td["ballgewinn"])
	p_fehler *= clampf(1.0 + (haerte - 45.0) * HAERTE_BALLGEWINN, 0.75, 1.45)
	p_fehler *= _anweisungsmittel(a, "angriff_auf", "angriff", "fehler")
	p_fehler *= clampf(1.0 - float(ueberzahl) * UEBERZAHL_FEHLER, 0.5, 1.6)
	if a["sieben_gegen_sechs"]:
		p_fehler *= SIEBTER_FEHLER
	if bool(a["bonus_kontrolleur"]):
		p_fehler *= 0.88
	# Unsaubere Abläufe enden nicht nur in schlechteren Würfen, sondern in
	# Schrittfehlern und Fehlpässen. Deshalb wirkt die Vertrautheit hier ein
	# zweites Mal, und zwar umgekehrt.
	p_fehler /= maxf(float(a["vertraut_angriff"]), 0.5)
	p_fehler *= float(zug.get("fehler", 1.0))
	p_fehler *= _reibung(a)
	if rng.randf() < p_fehler:
		return _ballverlust(a, v)

	# Freiwurf/Foul: Zeitstrafe oder Siebenmeter.
	#
	# Hier entscheidet sich, ob der Härteregler eine Zahl bleibt oder eine
	# Wette wird. Die eingestellte Härte sagt, wie oft die Abwehr zupackt; das
	# Gespann sagt, was das kostet. Dasselbe 70er-Deckungsverhalten bringt
	# gegen ein kleinliches Duo die halbe Abwehr auf die Strafbank und gegen
	# ein großzügiges kaum eine Verwarnung.
	var pfiff: float = Schiedsrichter.strenge_faktor(gespann, gespann_tagesform)
	# Die Halle wirkt nur gegen die Gäste — deshalb der Faktor allein, wenn die
	# verteidigende Mannschaft auswärts ist.
	if not bool(v["ist_heim"]):
		pfiff *= Schiedsrichter.heimfaktor(gespann, hallenpuls)
	var p_2min: float = ahndungsquote_bei_haerte(haerte) * float(td["zeitstrafe"]) * pfiff
	var p_7m: float = clampf(0.034 + haerte * 0.00026 + maxf(diff, 0.0) * 0.0005, 0.015, 0.09) * pfiff
	p_7m *= _anweisungsmittel(a, "angriff_auf", "angriff", "siebenmeter")
	p_7m *= float(zug.get("siebenmeter", 1.0))
	# Ein Gespann, das den Zweikampf zulässt, lässt den Angriff nach Kontakt
	# weiterlaufen: mehr Abschlüsse aus der Bewegung statt Unterbrechung.
	diff += (Schiedsrichter.laufen_lassen(gespann) - 1.0) * 22.0
	var wurf_zuf: float = rng.randf()
	if wurf_zuf < p_2min:
		_ahnden(v, a)
		if rng.randf() < 0.25:
			return _siebenmeter(a, v)
		# Freiwurf: Angriff geht weiter, leicht verbessert
		diff += 6.0
	elif wurf_zuf < p_2min + p_7m:
		return _siebenmeter(a, v)

	# Nach dem Vorwarnzeichen: wer die sechs Paesse verstreichen laesst, ohne
	# zu werfen, bekommt den Pfiff.
	if bool(a.get("vorwarnung", false)) and rng.randf() < PASSIV_ABPFIFF:
		return _ballverlust(a, v, "Zeitspiel-Abpfiff")

	# Der Zuschlag des Spielzugs: er wirkt auf die Abschlussqualität, nicht auf
	# die Wahrscheinlichkeit, überhaupt zum Wurf zu kommen. Ein gut gelaufener
	# Kreuz bringt die bessere Position, nicht mehr Angriffe.
	diff += float(zug.get("guete", 0.0)) * ANWEISUNG_GUETE
	return _wurf(a, v, diff, td, grunddiff)

## Welcher Zug in diesem Angriff läuft.
##
## Die Reihenfolge ist die aus Spielzuege.SITUATIONEN: die speziellste Lage
## gewinnt. Ein Zug, der nicht eingetragen oder nicht einstudiert ist, ergibt
## eine neutrale Wirkung — die Simulation rechnet dann genau wie ohne
## Spielbuch, und deshalb verschiebt das System nichts an der Kalibrierung.
func _spielzug_waehlen(a: Dictionary, v: Dictionary, ueberzahl: int) -> void:
	var b: Dictionary = a["spielbuch"]
	var situation := "standard"
	if ueberzahl < 0:
		situation = "unterzahl"
	elif ueberzahl > 0:
		situation = "ueberzahl"
	elif float(a["auszeit_wirkung"]) > 0.55:
		situation = "nach_auszeit"
	elif zeit > SPIELZEIT - 300.0 and absi(int(heim["tore"]) - int(gast["tore"])) <= 3:
		situation = "schluss"
	var zug: String = Spielzuege.zug_fuer(b, situation)
	if zug == "" and situation != "standard":
		# Für eine Lage ohne eigenen Eintrag gilt der normale Angriff. Sonst
		# stünde man in Überzahl plötzlich ohne jedes Konzept da.
		zug = Spielzuege.zug_fuer(b, "standard")
	a["zug"] = zug
	a["zug_wirkung"] = Spielzuege.wirkung(zug, Spielzuege.einstudiert(b, zug),
		str(v["taktik"]["abwehr"]))
	if zug != "":
		var gel: Dictionary = a["zug_gelaufen"]
		gel[zug] = int(gel.get(zug, 0)) + 1

func _wurf(a: Dictionary, v: Dictionary, diff: float, td: Dictionary, grunddiff: float = 0.0) -> Dictionary:
	var pos := _wurfposition(a)
	var schuetze := _spieler_auf(a, pos)
	if schuetze == "":
		return _ballverlust(a, v)
	var sp: Dictionary = daten["spieler"][schuetze]
	var zst: Dictionary = a["zustand"][schuetze]
	a["stats"]["wuerfe"] += 1
	zst["wuerfe"] += 1
	if _gegenstoss:
		a["stats"]["gegenstoss_wuerfe"] += 1

	var tw := _spieler_auf(v, "TW")
	# Geblockt wird im Handball fast ausschliesslich der Fernwurf. Ein Block am
	# Kreis oder am Fluegel ist die Ausnahme — dort steht der Verteidiger nicht
	# im Wurfarm, sondern im Weg.
	var block_mod: float = float(td["block"])
	var p_block: float = clampf(0.125 - diff * 0.0008, 0.05, 0.18) * block_mod
	if pos == "KM" or pos == "LA" or pos == "RA":
		p_block *= 0.22
	if _gegenstoss:
		p_block *= 0.25
	if rng.randf() < p_block:
		_wurf_notieren(a, pos, "block")
		return _block(a, v, schuetze, pos)

	var wurfguete: float = _wurfguete(sp, pos, a, diff)
	var paradenwert: float = _paradenwert(v, tw, pos)
	# Die Position gibt die Quote vor, Koennen und Torwart verschieben sie.
	# Der Hallenpuls wirkt direkt auf den Abschluss, nicht nur ueber den
	# Staerkevergleich — sonst verschwindet der Heimvorteil.
	var ziel: float = float(TREFFER_POSITION.get(pos, 0.60)) * fokusfaktor(
		str(a.get("wurfstil", a["taktik"]["angriff"])), pos) * deckungswirkung(td, pos)
	if _gegenstoss:
		ziel = TREFFER_GEGENSTOSS
	if bool(a.get("vorwarnung", false)):
		ziel = maxf(ziel - PASSIV_ABSCHLAG, 0.12)
	if tw == "":
		ziel = TREFFER_LEERES_TOR
	var treffer: float = clampf(ziel + (wurfguete - paradenwert + WURF_AUSGLEICH) * WURF_EMPFINDLICHKEIT
		+ _puls_abschluss(a) + float(_spielstandsdruck(a)["abschluss"])
		+ float(int(a.get("ueberzahl", 0))) * UEBERZAHL_ABSCHLUSS
		+ clampf(grunddiff, -STAERKE_GRENZE, STAERKE_GRENZE) * STAERKE_AM_WURF,
		ziel * WURF_UNTEN_ANTEIL, minf(ziel * WURF_OBEN_ANTEIL, 0.97))
	# Fehlwuerfe: gemessen lagen sie bei 8,7 Prozent aller Abschluesse, in der
	# Bundesliga sind es rund sechs. Die drei Prozentpunkte gehoeren dem
	# Torhueter — die Torquote bleibt davon unberuehrt, weil sie unten auf den
	# verbleibenden Wurf hochgerechnet wird. Was sich aendert, ist nur, ob ein
	# nicht verwandelter Ball daneben geht oder gehalten wird.
	var p_vorbei: float = clampf(0.066 - (wurfguete - paradenwert) * 0.0009, 0.03, 0.12)
	# Blockierte und vorbeigeworfene Baelle gehen von derselben Quote ab. Damit
	# am Ende wirklich `treffer` uebrig bleibt, wird die Torchance des
	# verbleibenden Wurfs entsprechend hochgerechnet.
	var p_tor: float = clampf(treffer / maxf((1.0 - p_block) * (1.0 - p_vorbei), 0.35), 0.02, 0.995)
	var w: float = rng.randf()
	if w < p_vorbei:
		_wurf_notieren(a, pos, "vorbei")
		zst["bewertung"] += 0.16
		_bewertung_dampfen(zst)
		var t1 := Textbank.satz(Textbank.FEHLWURF, rng, Spielerfabrik.kurz_name(sp))
		_warteschlange.append(_ereignis("fehlwurf", _seite(a), schuetze, t1, {"position": pos}))
		_puls_aendern(a, -2.0)
		return {"gegenstoss": rng.randf() < 0.19}
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
	var cache: Dictionary = t["cache"]
	var schluessel: String = "am:%s:%s:%s" % [formation, bereich, feld]
	if cache.has(schluessel):
		return float(cache[schluessel])
	var wert: float = _anweisungsmittel_rechnen(t, formation, bereich, feld)
	cache[schluessel] = wert
	return wert

func _anweisungsmittel_rechnen(t: Dictionary, formation: String, bereich: String, feld: String) -> float:
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

## Wie sehr sich die aktuelle Sieben im Weg steht.
##
## Ein Zerwuerfnis in der Kabine ist nur dann eines, wenn es auf der Platte
## etwas kostet. Zwei Spieler, die einander aus dem Weg gehen, spielen sich
## den Ball nicht in den Lauf: das kostet Abstimmung, nicht Koennen — deshalb
## trifft es die Fehlerquote und die Vorlagen, nicht die Wurfstaerke.
##
## Nur fuer den eigenen Verein: fremde Kabinen fuehren kein Netz.
func _reibung(t: Dictionary) -> float:
	var cache: Dictionary = t["cache"]
	if cache.has("reibung"):
		return cache["reibung"]
	var r := 1.0
	if str(t["cid"]) == Welt.mein_verein_id:
		var auf: Array = aktuell_auf_platz(t)
		var streit := 0
		for i in range(auf.size()):
			for j in range(i + 1, auf.size()):
				if Beziehungen.wert(daten, str(t["cid"]), str(auf[i]), str(auf[j])) <= Beziehungen.KONFLIKT:
					streit += 1
		r = 1.0 + float(streit) * 0.035
	cache["reibung"] = r
	return r

## Deckungswerte der Taktik, verschoben durch die Abwehranweisungen.
func _deckungswerte(v: Dictionary) -> Dictionary:
	var cache: Dictionary = v["cache"]
	if cache.has("deckung"):
		return cache["deckung"]
	var td: Dictionary = (DECKUNG.get(str(v["taktik"]["abwehr"]), DECKUNG["6-0"]) as Dictionary).duplicate()
	td["block"] = float(td["block"]) * _anweisungsmittel(v, "abwehr_auf", "abwehr", "block")
	td["ballgewinn"] = float(td["ballgewinn"]) * _anweisungsmittel(v, "abwehr_auf", "abwehr", "ballgewinn")
	td["zeitstrafe"] = float(td["zeitstrafe"]) * _anweisungsmittel(v, "abwehr_auf", "abwehr", "zeitstrafe")
	# Der Matchplan verschiebt dieselben Werte noch einmal — Manndeckung
	# bringt Ballgewinne und Zeitstrafen, Kreis zustellen macht innen zu und
	# außen auf.
	for feld in Gegnerplan.deckungswerte(v["gegnerplan"]).keys():
		td[feld] = float(td.get(feld, 1.0)) * float(Gegnerplan.deckungswerte(v["gegnerplan"])[feld])
	cache["deckung"] = td
	return td

## Haelt fest, was aus einem Abschluss von dieser Position geworden ist.
##
## Der Tempogegenstoss bekommt einen eigenen Eintrag ("TG"). Er ist im Handball
## eine eigene Wurfkategorie und keine Position: derselbe Linksaussen wirft aus
## dem Lauf gegen einen allein stehenden Torwart voellig anders als aus dem
## Stand gegen eine formierte Abwehr. Zaehlte man beides zusammen, sagte die
## Wurfkarte ueber keine der beiden Lagen mehr etwas.
func _wurf_notieren(a: Dictionary, pos: String, ergebnis: String) -> void:
	var schluessel: String = "TG" if _gegenstoss and pos != "7M" else pos
	var karte: Dictionary = a["wurfkarte"]
	if not karte.has(schluessel):
		karte[schluessel] = {"tor": 0, "parade": 0, "vorbei": 0, "block": 0}
	var eintrag: Dictionary = karte[schluessel]
	eintrag[ergebnis] = int(eintrag.get(ergebnis, 0)) + 1

func _wurfposition(a: Dictionary) -> String:
	var stil: String = str(a["taktik"]["angriff"])
	if not WURFVERTEILUNG.has(stil):
		stil = "positionsangriff"
	if a["sieben_gegen_sechs"]:
		stil = "rueckraumfokus"
	# Unter dem Vorwarnzeichen wird geworfen, wer den Ball hat — und das ist
	# der Rueckraum. Am Kreis oder aussen laesst sich ein erzwungener Wurf
	# nicht ansetzen.
	if bool(a.get("vorwarnung", false)):
		stil = "rueckraumfokus"
	# Der Stil, aus dem die Verteilung wirklich kommt — der Abschluss rechnet
	# mit demselben, sonst straft der Fokusfaktor eine Verteilung ab, die gar
	# nicht gespielt wurde.
	a["wurfstil"] = stil
	var verteilung: Dictionary = WURFVERTEILUNG[stil]
	var gesamt := 0.0
	var gewichte := {}
	for pos in verteilung.keys():
		var sid := _spieler_auf(a, pos)
		if sid == "":
			continue
		var kraft: float = float(a["zustand"][sid]["kraft"]) / 100.0
		var g: float = float(verteilung[pos]) * (0.55 + 0.45 * kraft) * (0.7 + 0.6 * _angriff_basis(a, sid, pos) / 100.0)
		g *= _faktor(a, sid, "angriff", "wurfanteil")
		# Der laufende Spielzug verschiebt, wer zum Abschluss kommt. Genau das
		# ist der sichtbarste Teil eines einstudierten Ablaufs: nach einem
		# Einläufer wirft der Kreis, nach einem Kreuz der Rückraum.
		g *= float((a["zug_wirkung"].get("wurf", {}) as Dictionary).get(pos, 1.0))
		# Wer in Manndeckung steht, kommt kaum noch zum Wurf. Das ist der
		# eigentliche Zweck der Massnahme — nicht, dass er schlechter trifft,
		# sondern dass er den Ball nicht bekommt.
		g *= Gegnerplan.wurfanteil(_gegner_zu(a)["gegnerplan"], sid)
		# Und die Formation, gegen die gespielt wird: wo die Abwehr steht,
		# kommt seltener jemand zum Abschluss.
		g *= deckungsverteilung(_deckungswerte(_gegner_zu(a)), pos)
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
	var gedeckt: float = Gegnerplan.gueteabzug(_gegner_zu(a)["gegnerplan"], str(sp["id"]))
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
	return basis * 5.0 * (0.70 + 0.30 * kraft) * float(z_sch["tagesform"]) * druck * puls_bonus \
		+ clampf(diff, -30.0, 30.0) * 0.12 + anweisung - gedeckt * ANWEISUNG_GUETE

## Die jeweils andere Mannschaft. Wird gebraucht, wo eine Angriffsrechnung
## wissen muss, was die Abwehr vorhat.
func _gegner_zu(t: Dictionary) -> Dictionary:
	return gast if t == heim else heim

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
		zst["gegenstoss_tore"] += 1
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
		return Textbank.satz(Textbank.TOR["SIEBENMETER"], rng, n)
	if _gegenstoss:
		return Textbank.satz(Textbank.TOR["GEGENSTOSS"], rng, n)
	if a["sieben_gegen_sechs"]:
		return Textbank.satz(Textbank.TOR["SIEBEN_GEGEN_SECHS"], rng, n)
	# Die Sätze stehen in kern/Textbank.gd, gezogen wird mit dem Generator
	# dieser Partie: derselbe Anwurf ergibt denselben Ticker.
	var t := Textbank.satz(Textbank.tortexte(pos), rng, n)
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
	var text := Textbank.satz(Textbank.PARADE, rng,
		Spielerfabrik.kurz_name(daten["spieler"][tw]) if tw != "" else "Der Torwart")
	_puls_aendern(v, 5.0 if v["ist_heim"] else -3.0)
	_warteschlange.append(_ereignis("parade", _seite(v), tw, text, {"position": pos, "schuetze": schuetze}))
	return {"gegenstoss": rng.randf() < 0.29}

func _block(a: Dictionary, v: Dictionary, schuetze: String, pos: String) -> Dictionary:
	var blocker := _zufaelliger_abwehrspieler(v)
	v["stats"]["blocks"] += 1
	if blocker != "":
		v["zustand"][blocker]["blocks"] += 1
		v["zustand"][blocker]["bewertung"] -= 0.12
	var text := ""
	if blocker != "":
		text = Textbank.satz(Textbank.BLOCK_NAMEN, rng,
			[Spielerfabrik.kurz_name(daten["spieler"][blocker]),
			Spielerfabrik.kurz_name(daten["spieler"][schuetze])])
	else:
		text = Textbank.satz(Textbank.BLOCK, rng, Spielerfabrik.kurz_name(daten["spieler"][schuetze]))
	_warteschlange.append(_ereignis("block", _seite(v), blocker, text, {"position": pos}))
	_puls_aendern(v, 3.0 if v["ist_heim"] else -2.0)
	return {"gegenstoss": rng.randf() < 0.22}

func _ballverlust(a: Dictionary, v: Dictionary, ursache: String = "") -> Dictionary:
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
	var arten := ["Schrittfehler", "Stürmerfoul", "technischer Fehler", "Fehlpass", "Doppelfehler"]
	var art := ursache if ursache != "" else str(arten[rng.randi_range(0, arten.size() - 1)])
	# Die knappe Form nennt den Grund, die Bank erzaehlt ihn. Beides
	# abwechselnd, damit der Ticker weder eintoenig noch grundlos wird.
	var text := ""
	if verursacher == "":
		text = Textbank.satz(Textbank.BALLVERLUST, rng)
	elif rng.randf() < 0.40:
		text = "%s: %s." % [art, Spielerfabrik.kurz_name(daten["spieler"][verursacher])]
	else:
		text = Textbank.satz(Textbank.BALLVERLUST_NAMEN, rng,
			Spielerfabrik.kurz_name(daten["spieler"][verursacher]))
	var leeres_tor_risiko: float = LEERES_TOR_WURF
	if Trainerkarriere.bonus_fuer(daten, str(a["cid"]), "hasardeur"):
		leeres_tor_risiko = 0.26
	if a["sieben_gegen_sechs"] and rng.randf() < leeres_tor_risiko:
		# Freie Bahn auf das verwaiste Tor — aus der eigenen Haelfte.
		var werfer := _zufaelliger_abwehrspieler(v)
		v["stats"]["wuerfe"] += 1
		if werfer != "":
			v["zustand"][werfer]["wuerfe"] += 1
		if rng.randf() >= LEERES_TOR_TREFFER:
			_wurf_notieren(v, "LT", "vorbei")
			text += " Der Gegenwurf auf das leere Tor geht daneben."
			_warteschlange.append(_ereignis("fehlwurf", _seite(v), werfer, text, {"position": "RM"}))
			_puls_aendern(a, -2.0)
			return {"gegenstoss": false}
		_wurf_notieren(v, "LT", "tor")
		v["tore"] = int(v["tore"]) + 1
		v["stats"]["tore"] += 1
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
	return {"gegenstoss": rng.randf() < 0.32}

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
	var p: float = clampf(SIEBENMETER_GRUND + (guete - halten) * 0.0055, 0.45, 0.95)
	_warteschlange.append(_ereignis("siebenmeter", _seite(a), schuetze,
		Textbank.satz(Textbank.SIEBENMETER, rng,
			[str(a["kurz"]), Spielerfabrik.kurz_name(sp)]), {"position": "RM"}))
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
	var tw_text := "Der Torwart hält!" if tw == "" else Textbank.satz(
		Textbank.SIEBENMETER_GEHALTEN, rng, Spielerfabrik.kurz_name(daten["spieler"][tw]))
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
		var w: float = _siebenmetereignung(sp)
		if w > bw:
			bw = w
			best = sid
	return best

# ------------------------------------------------------- Zeitstrafen etc. ---

## Wie viele Verwarnungen eine Mannschaft hoechstens bekommt, bevor das
## Schiedsrichtergespann bei jedem weiteren Vergehen zur Zeitstrafe greift.
## Die Regel steht so im Regelwerk: drei Gelbe je Mannschaft, danach entfaellt
## diese Stufe.
const VERWARNUNGEN_MAX := 3

## Die progressive Bestrafung des Handballs.
##
## Sie fehlte ganz: jedes geahndete Vergehen fuehrte sofort zu zwei Minuten.
## In Wirklichkeit steht davor die Verwarnung — und sie ist nicht unbegrenzt.
## Hat eine Mannschaft ihre drei Gelben gesehen, geht jedes weitere Foul
## denselben Weg wie vorher: direkt auf die Strafbank.
func _ahnden(v: Dictionary, a: Dictionary) -> void:
	var gelb: int = int(v["stats"].get("verwarnungen", 0))
	if gelb < VERWARNUNGEN_MAX and rng.randf() < 0.62:
		_verwarnung(v)
		return
	_zeitstrafe(v, a)

func _verwarnung(v: Dictionary) -> void:
	var suender := _foulender_spieler(v)
	if suender == "":
		return
	var zst: Dictionary = v["zustand"][suender]
	# Wer schon Gelb hat, bekommt sie nicht zweimal — dann greift die naechste
	# Stufe. Dass er trotzdem weiterspielt, entscheidet erst die Zeitstrafe.
	if int(zst.get("verwarnungen", 0)) > 0:
		return
	zst["verwarnungen"] = 1
	v["stats"]["verwarnungen"] = int(v["stats"].get("verwarnungen", 0)) + 1
	var sp: Dictionary = daten["spieler"][suender]
	_warteschlange.append(_ereignis("verwarnung", _seite(v), suender,
		Textbank.satz(Textbank.VERWARNUNG, rng, Spielerfabrik.kurz_name(sp))))

## Wen es trifft.
##
## Nicht gleichverteilt: ein Trainer nimmt einen Spieler mit zwei Zeitstrafen
## aus der Abwehr, und die Spieler selbst gehen nach der zweiten kein Risiko
## mehr ein. Ohne diese Gewichtung sah die Simulation in jeder dritten Partie
## eine Disqualifikation — in der Bundesliga ist es etwa jede zehnte.
func _foulender_spieler(t: Dictionary) -> String:
	var liste: Array = []
	var gewichte: Array = []
	var summe := 0.0
	for pos in t["abwehr_auf"].keys():
		if pos == "TW":
			continue
		var sid: String = str(t["abwehr_auf"][pos])
		if sid == "" or bool(t["zustand"][sid]["rot"]):
			continue
		var bisher: int = int(t["zustand"][sid]["zeitstrafen"])
		var g: float = 1.0 / (1.0 + 2.6 * float(bisher))
		liste.append(sid)
		gewichte.append(g)
		summe += g
	if liste.is_empty():
		return _zufaelliger_abwehrspieler(t, true)
	var wurf: float = rng.randf() * summe
	for i in liste.size():
		wurf -= float(gewichte[i])
		if wurf <= 0.0:
			return str(liste[i])
	return str(liste[liste.size() - 1])

func _zeitstrafe(v: Dictionary, a: Dictionary) -> void:
	var suender := _foulender_spieler(v)
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
		_warteschlange.append(_ereignis("zeitstrafe", _seite(v), suender,
			Textbank.satz(Textbank.ZEITSTRAFE, rng, Spielerfabrik.kurz_name(sp))))
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
func _feldspieler(t: Dictionary, im_angriff: bool = true) -> int:
	var besetzt: int = 0
	for pos in t["angriff_auf"].keys():
		if pos == "TW":
			continue
		if str(t["angriff_auf"][pos]) != "":
			besetzt += 1
	# Im 7-gegen-6 kommt ein Feldspieler fuer den Torwart — er steht auf keiner
	# der sechs Angriffspositionen, spielt aber mit. Ohne diesen Zuschlag war
	# der zusaetzliche Spieler im Modell schlicht nicht vorhanden, und die
	# ganze Massnahme brachte nur Nachteile.
	# Nur im Angriff: wer in Unterzahl den Torwart herausnimmt, greift wieder
	# zu sechst an — verteidigt aber weiter zu fuenft. Genau das ist der
	# Handel, und ohne diese Unterscheidung hob die Massnahme die eigene
	# Unterzahl auch in der Abwehr auf.
	var zusatz: int = 1 if (im_angriff and bool(t["sieben_gegen_sechs"])) else 0
	var strafen: int = (t["gesperrt"] as Array).size()
	return clampi(mini(besetzt, 6) + zusatz - strafen, 3, 7)

func _vom_platz_nehmen(t: Dictionary, sid: String) -> void:
	cache_verwerfen(t)
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
	cache_verwerfen(t)
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
	if aktiv:
		t["stats"]["sieben_gegen_sechs"] += 1
	cache_verwerfen(t)
	var text := Textbank.satz(Textbank.SIEBEN_GEGEN_SECHS_AN if aktiv
		else Textbank.SIEBEN_GEGEN_SECHS_AUS, rng, str(t["name"]))
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
		# Vorgerechnet: die Grundneigung des Spielers mal die Prävention des
		# Vereins. Beides ändert sich während einer Partie nicht.
		if rng.randf() >= float(t["zustand"][sid]["risiko_basis"]) * float(t["praevention"]) * 2.2:
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

## Die Sieben, die in dieser Phase tatsächlich auf der Platte steht.
## `alle_auf_platz` liefert dagegen alle, die in der Rotation stehen — das sind
## je nach Aufstellung deutlich mehr, aber eben nicht gleichzeitig im Spiel.
func aktuell_auf_platz(t: Dictionary) -> Array:
	var greift_an: bool = angriffsrecht == _seite(t)
	var block: Dictionary = t["angriff_auf"] if greift_an else t["abwehr_auf"]
	var liste: Array = []
	for pos in block.keys():
		if pos == "TW" and bool(t["sieben_gegen_sechs"]) and greift_an:
			continue
		var sid: String = str(block[pos])
		if sid != "":
			liste.append(sid)
	return liste

func alle_auf_platz(t: Dictionary) -> Array:
	var cache: Dictionary = t["cache"]
	if cache.has("auf_platz"):
		return cache["auf_platz"]
	var liste := {}
	for pos in t["angriff_auf"].keys():
		var sid: String = str(t["angriff_auf"][pos])
		if sid != "":
			liste[sid] = true
	for pos in t["abwehr_auf"].keys():
		var sid2: String = str(t["abwehr_auf"][pos])
		if sid2 != "":
			liste[sid2] = true
	cache["auf_platz"] = liste.keys()
	return cache["auf_platz"]

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

## Direkter Zuschlag auf die Trefferquote durch die Hallenatmosphaere.
##
## Der Wert war zu gross. Fuenf Prozentpunkte fuer die eine und fuenf gegen die
## andere Seite sind ueber fuenfzig Wuerfe fast fuenf Tore — und weil der Puls
## waehrend der Partie schwankt, war das zum grossen Teil Rauschen. Gemessen
## an derselben Paarung streuten die Ergebnisse um gut sechs Tore, wo der reine
## Wurfzufall knapp fuenf hergibt. Der Heimvorteil selbst bleibt: er steckt
## ausserdem in _puls_wirkung und im Gespann.
##
## Was der schwankende Puls verloren hat, holt HEIMVORTEIL als fester Anteil
## zurueck: die eigene Halle, die kurze Anreise, der bekannte Hallenboden. Fest
## heisst hier ohne Streuung — der Heimvorteil soll den Schnitt verschieben,
## nicht die Ergebnisse auffaechern.
##
## Genau deshalb sind die Pulsanteile darunter zweimal kleiner geworden: der
## Heimvorteil lag gemessen bei 2,4 Toren statt bei den 1,4 der Bundesliga, und
## der groessere Teil davon kam aus einem Hallenpuls, der im Schnitt bei
## sechsundsiebzig steht und damit fast immer fuer die Heimmannschaft spricht.
## Jetzt sind es 1,5 Tore und zweiundfuenfzig Prozent Heimsiege.
const HEIMVORTEIL := 0.018

func _puls_abschluss(t: Dictionary) -> float:
	var abweichung: float = (hallenpuls - 50.0) / 50.0
	if bool(t["ist_heim"]):
		return clampf(abweichung * 0.009, -0.012, 0.012) + HEIMVORTEIL
	var nerven := 0.0
	var anzahl := 0
	for sid in alle_auf_platz(t):
		nerven += float(daten["spieler"][sid]["attr"]["nervenstaerke"])
		anzahl += 1
	var schnitt: float = (nerven / maxf(float(anzahl), 1.0)) / 20.0
	return clampf(-abweichung * 0.007 * (1.3 - schnitt), -0.012, 0.010) - HEIMVORTEIL * 0.5

## Wirkung des Hallenpulses auf ein Team (Heim profitiert, Gast leidet je nach Nerven).
func _puls_wirkung(t: Dictionary) -> float:
	var abweichung: float = (hallenpuls - 50.0) / 50.0
	if bool(t["ist_heim"]):
		return clampf(1.0 + abweichung * 0.030, 0.965, 1.04)
	var nerven := 0.0
	var anzahl := 0
	for sid in alle_auf_platz(t):
		nerven += float(daten["spieler"][sid]["attr"]["nervenstaerke"])
		anzahl += 1
	var schnitt: float = (nerven / maxf(float(anzahl), 1.0)) / 20.0
	return clampf(1.0 - abweichung * 0.020 * (1.3 - schnitt), 0.965, 1.02)

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
			_warteschlange.append(_ereignis("lauf", seite, "", Textbank.satz(Textbank.LAUF, rng, [int(lauf["tore"]), t["name"]])))

# ---------------------------------------------------------- Wechsel / KI ---

func _wechsel_pruefen(t: Dictionary) -> void:
	if zeit - float(t["letzte_wechselpruefung"]) < 120.0:
		return
	t["letzte_wechselpruefung"] = zeit
	# Der Minutenplan gilt immer: er ist eine ausdrueckliche Ansage des
	# Trainers und keine Automatik, die man abschalten wollen wuerde. Wer
	# keine Ziele setzt, merkt davon nichts.
	_minutenplan_pruefen(t)
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
		# Ein Minutenziel gilt in beide Richtungen.
		#
		# Die Kraftrotation holte den besten Mann von der Bank, ohne sein
		# Pensum anzusehen — und der beste Mann auf der Bank ist oft genau
		# der, dem man zwanzig Minuten zugesagt hat. Der Minutenplan nahm ihn
		# pflichtgemaess wieder herunter, die Kraftrotation holte ihn sofort
		# zurueck, und am Ende standen achtundvierzig Minuten auf dem Zettel
		# statt zwanzig. Gemessen mit werkzeuge/Minutensonde.gd.
		if _ueber_pensum(t, ersatz):
			continue
		wechsel(t, sid, ersatz, pos)

## Hat dieser Spieler sein anteiliges Pensum schon voll?
func _ueber_pensum(t: Dictionary, sid: String) -> bool:
	var ziele: Dictionary = t["minutenziele"]
	if not ziele.has(sid):
		return false
	var anteil: float = clampf(zeit / (Einsatzzeit.SPIELDAUER * 60.0), 0.0, 1.0)
	if anteil < 0.12:
		return false
	return float(t["zustand"][sid]["sekunden"]) / 60.0 >= float(ziele[sid]) * anteil

## Zielminuten umsetzen. Der Vergleich laeuft anteilig — nach zwanzig Minuten
## zaehlt ein Drittel des Ziels, sonst sperrte man einen Leistungstraeger nach
## der ersten Viertelstunde aus.
##
## Die Ansage hat zwei Haelften, und umgesetzt war nur eine davon:
##
##   1. Wer sein Pensum erfuellt hat, macht Platz.
##   2. Wer weit hinter seinem Pensum liegt, muss aufs Feld — und dafuer muss
##      jemand weichen, der gar kein Pensum hat.
##
## Ohne die zweite lief die Minutenzuweisung genau dann ins Leere, wenn man
## sie so benutzt, wie sie gedacht ist: ein Ziel fuer den Jungen, keines fuer
## die Stammkraefte. Ausgewechselt wurde ja nur, wer selbst ein Ziel hatte und
## es uebererfuellte — also niemand. Gemessen mit werkzeuge/Minutensonde.gd:
## null Minuten in sechs Partien fuer einen Spieler mit zwanzig Zielminuten.
##
## Das traf auch die Talentfoerderung der Computervereine, die seit kurzem
## ueber dieselben Zielminuten laeuft.

## Wie weit ueber dem anteiligen Soll jemand liegen muss, um Platz zu machen.
const PENSUM_UEBER := 2.0
## Wie weit darunter, um beruecksichtigt zu werden.
const PENSUM_RUECKSTAND := 1.5
## Und wie weit darunter, um jemanden ohne Pensum zu verdraengen. Hoeher als
## die Schwelle davor: einen Stammspieler holt man nicht wegen einer halben
## Minute vom Feld.
const PENSUM_VERDRAENGT := 2.5

func _minutenplan_pruefen(t: Dictionary) -> void:
	var ziele: Dictionary = t["minutenziele"]
	if ziele.is_empty():
		return
	var anteil: float = clampf(zeit / (Einsatzzeit.SPIELDAUER * 60.0), 0.0, 1.0)
	# In den ersten Minuten sagt der Vergleich nichts aus.
	if anteil < 0.12:
		return
	for pos in (t["angriff_auf"] as Dictionary).keys():
		if pos == "TW":
			continue
		var sid: String = str(t["angriff_auf"][pos])
		if sid == "":
			continue
		var hat_ziel: bool = ziele.has(sid)
		var ueber: bool = hat_ziel and float(t["zustand"][sid]["sekunden"]) / 60.0 \
			>= float(ziele[sid]) * anteil + PENSUM_UEBER
		# Wer auf der Bank am weitesten hinter seinem Pensum liegt.
		var kandidat := ""
		var groesster: float = PENSUM_RUECKSTAND
		for ersatz in t["bank"]:
			var z_e: Dictionary = t["zustand"][ersatz]
			if bool(z_e["rot"]):
				continue
			var sp_e: Dictionary = daten["spieler"][ersatz]
			if bool(sp_e["ist_torwart"]):
				continue
			# Auf eine Position, die er gar nicht spielen kann, hilft auch das
			# schoenste Minutenziel nicht.
			if Spielerfabrik.eignung(sp_e, pos) < 0.42:
				continue
			var rueckstand: float = float(ziele.get(ersatz, 0.0)) * anteil - float(z_e["sekunden"]) / 60.0
			if rueckstand > groesster:
				groesster = rueckstand
				kandidat = ersatz
		if ueber:
			# Wartet niemand mit Pensum, kommt der Beste zurueck — sonst
			# bliebe der Junge bis zur Sirene drauf, obwohl er sein Pensum
			# laengst hat.
			if kandidat == "":
				kandidat = _bester_von_bank(t, pos)
			if kandidat != "" and kandidat != sid:
				wechsel(t, sid, kandidat, pos)
			continue
		if not hat_ziel and kandidat != "" and groesster >= PENSUM_VERDRAENGT:
			wechsel(t, sid, kandidat, pos)

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
	cache_verwerfen(t)
	t["stats"]["wechsel"] += 1
	# Wechselfehler: bei sehr hoher Wechselintensitaet droht eine Zeitstrafe
	var intensitaet: float = float(t["taktik"].get("wechselspiel", 50)) / 100.0
	if rng.randf() < 0.006 * intensitaet:
		var gegner: Dictionary = gast if t == heim else heim
		_warteschlange.append(_ereignis("wechselfehler", _seite(t), rein, "Wechselfehler bei %s — zwei Minuten!" % t["name"]))
		_zeitstrafe(t, gegner)
	else:
		_warteschlange.append(_ereignis("wechsel", _seite(t), rein,
			Textbank.satz(Textbank.WECHSEL, rng, [str(t["kurz"]),
				Spielerfabrik.kurz_name(daten["spieler"][rein]),
				Spielerfabrik.kurz_name(daten["spieler"][raus])])))
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
	_warteschlange.append(_ereignis("auszeit", _seite(t), "",
		Textbank.satz(Textbank.AUSZEIT, rng, str(t["name"]))))
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

## Der Cache gilt nur, solange dieselben sieben auf der Platte stehen und
## dieselben Anweisungen gelten. Jeder Wechsel, jede Zeitstrafe und jede
## Umstellung wirft ihn weg — lieber einmal zu oft neu gerechnet als mit einer
## veralteten Mannschaft weitergespielt. Öffentlich, weil auch die Live-Ansicht
## Taktik und Anweisungen mitten in der Partie ändern kann.
## Setzt einen Spieler mitten in der Partie auf eine andere Position.
##
## Angriff und Abwehr sind getrennte Aufstellungen, und genau das war im Spiel
## nicht zu aendern: wer merkte, dass sein Kreislaeufer in der Abwehr auf dem
## Aussenplatz untergeht, konnte ihn bis zum Schlusspfiff nicht umstellen.
##
## Steht der Spieler schon woanders im selben Block, tauschen die beiden ihre
## Plaetze — alles andere liesse eine Position unbesetzt.
func position_besetzen(t: Dictionary, block: String, pos: String, sid: String) -> Dictionary:
	var feldname: String = "angriff_auf" if block == "angriff" else "abwehr_auf"
	var auf: Dictionary = t[feldname]
	if not auf.has(pos):
		return {"ok": false, "grund": "Diese Position gibt es nicht."}
	if sid == "" or not (t["zustand"] as Dictionary).has(sid):
		return {"ok": false, "grund": "Dieser Spieler ist nicht im Aufgebot."}
	for e in (t["gesperrt"] as Array):
		if str((e as Dictionary).get("sid", "")) == sid:
			return {"ok": false, "grund": "Er sitzt auf der Strafbank."}
	var vorher: String = str(auf[pos])
	if vorher == sid:
		return {"ok": false, "grund": "Er steht bereits dort."}
	var alte_position := ""
	for p2 in auf.keys():
		if str(auf[p2]) == sid:
			alte_position = str(p2)
			break
	auf[pos] = sid
	if alte_position != "":
		auf[alte_position] = vorher
	cache_verwerfen(t)
	var name: String = Spielerfabrik.kurz_name(daten["spieler"][sid])
	if alte_position != "":
		return {"ok": true, "grund": "%s und %s tauschen die Plätze." % [
			name, Spielerfabrik.kurz_name(daten["spieler"][vorher])]}
	return {"ok": true, "grund": "%s übernimmt %s." % [name, pos]}

func cache_verwerfen(t: Dictionary) -> void:
	(t["cache"] as Dictionary).clear()

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
	basis *= float(_spielstandsdruck(a)["angriff"])
	basis *= _puls_wirkung(a)
	basis *= float(a["teamfaktor"])
	basis *= 1.0 + Scouting.gegnervorteil(daten, str(a["cid"]), str(v["cid"]))
	# Videostudium wirkt ueber den Unterschied zum Gegenueber, nicht ueber den
	# eigenen Aufwand: zwei gleich gut vorbereitete Mannschaften heben sich auf.
	basis *= 1.0 + Videostudium.vorteil(daten, str(a["cid"]), str(v["cid"]))
	basis *= 1.0 + 0.035 * float(a["auszeit_wirkung"])
	basis *= 1.0 + 0.055 * float(a["ansprache"])
	basis *= 1.0 + Presse.motivation(daten, str(a["cid"]))
	a["auszeit_wirkung"] = maxf(float(a["auszeit_wirkung"]) - 0.12, 0.0)
	# Dasselbe im Angriff: ein frisch umgestelltes System läuft, aber es läuft
	# nicht rund.
	basis *= float(a["vertraut_angriff"])
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
		# Wer auf einem fremden Abwehrplatz steht, bringt dort weniger.
		var passt: float = 0.82 + 0.18 * Spielerfabrik.abwehr_eignung(daten["spieler"][sid], str(pos))
		summe += float(z["basis_abwehr"]) * (0.68 + 0.32 * kraft) * float(z["tagesform"]) * passt
		gewicht += 1.0
	var basis: float = summe / maxf(gewicht, 1.0)
	basis *= float(MENTALITAET[str(v["taktik"]["mentalitaet"])]["abwehr"])
	basis *= float(_spielstandsdruck(v)["abwehr"])
	basis *= 1.0 + Videostudium.vorteil(daten, str(v["cid"]), str(a["cid"]))
	basis *= _puls_wirkung(v)
	basis *= float(v["teamfaktor"])
	basis *= 1.0 + 0.045 * float(v["ansprache"])
	if bool(v["bonus_betonmischer"]):
		basis *= 1.035
	# Eine Formation, die nicht eingeschliffen ist, steht schlechter: die
	# Übergaben stimmen nicht, das Herausrücken kommt zu spät.
	basis *= float(v["vertraut_abwehr"])
	# Der Preis des Matchplans: wer einen Mann herausschickt, deckt hinten mit
	# einem weniger. Ohne diesen Faktor waere Manndeckung eine Gratisverbesserung.
	basis *= Gegnerplan.abwehrfaktor(v["gegnerplan"])
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
	# Die Aufschlüsselung braucht die Abrechnung: nur Tageskarten bringen am
	# Spieltag noch Geld, Dauerkarten sind längst bezahlt.
	spiel["tickets"] = zuschauer_aufschluesselung.duplicate(true)
	# Was das Gespann gepfiffen hat, geht auf sein Konto. Erst diese Zahlen
	# machen aus einer verborgenen Anlage einen Ruf, den man vor dem nächsten
	# Spiel nachlesen kann.
	# Was gespielt wurde, schleift sich ein — ein Pflichtspiel bringt mehr als
	# eine ganze Trainingswoche.
	for t in [heim, gast]:
		Vertrautheit.partie_verbuchen(daten, str(t["cid"]),
			str(t["taktik"]["abwehr"]), str(t["taktik"]["angriff"]))
		Spielzuege.partie_verbuchen(daten, str(t["cid"]), t["zug_gelaufen"])
	Schiedsrichter.partie_verbuchen(daten, str(spiel["id"]),
		int(heim["stats"]["zeitstrafen"]) + int(gast["stats"]["zeitstrafen"]),
		int(heim["stats"]["siebenmeter"]) + int(gast["stats"]["siebenmeter"]),
		int(heim["stats"]["rote"]) + int(gast["stats"]["rote"]))
	if not programm.is_empty() and str(programm.get("programm", "")) != Spieltagsprogramm.STANDARD:
		spiel["programm"] = str(programm["programm"])
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
		"gespann": voll.get("gespann", ""),
		"szenen": voll.get("szenen", []),
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
		"gespann": Schiedsrichter.namen(gespann),
		"ticker": _ticker_kurz(),
		# Die sieben Momente, an denen die Partie gekippt ist. Sie entstehen
		# aus derselben Ereignisliste wie der Ticker — sie wegzuwerfen war die
		# Verschwendung, nicht sie zu berechnen.
		"szenen": Schluesselszenen.auswaehlen(ereignisse, SPIELZEIT),
	}

const BERICHT_FELDER := ["sekunden", "tore", "wuerfe", "assists", "paraden", "gegentore",
	"blocks", "fehler", "zeitstrafen", "verwarnungen", "ballgewinne", "rot", "bewertung",
	"siebenmeter", "siebenmeter_tore", "gegenstoss_tore", "kraft"]

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
		# Die Note gehoert in den Bereich 1 bis 6, und nur hier ist sicher, dass
		# sie es auch tut: waehrend der Partie zieht ein Dutzend Stellen an ihr,
		# und nur ein Teil davon daempft danach. Im Bericht stand deshalb schon
		# eine Note von 0,9 — die gibt es nicht.
		schlank["bewertung"] = clampf(float(z.get("bewertung", 3.5)), 1.0, 6.0)
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
