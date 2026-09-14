class_name Spielplan
extends RefCounted
## Erzeugt und verwaltet den Terminkalender einer Saison: Ligen (Doppelrunde),
## nationale Pokale (K.-o. mit Freilosen), Supercups und die beiden internationalen
## Wettbewerbe. Pokalrunden werden erst ausgelost, wenn die Vorrunde gespielt ist.

const WINTERPAUSE_VON := 174   # ~22. Dezember
const WINTERPAUSE_BIS := 199   # ~16. Januar
const LIGA_START := 46
const LIGA_ENDE := 322
const SAISON_ABSCHLUSS := 338

# --------------------------------------------------------------- Aufbau ---

static func erzeuge_saison(d: Dictionary) -> void:
	d["plan"] = {}
	var basis: int = Kalender.saison_index(int(d["tag"])) * Kalender.TAGE_IM_JAHR
	for lid in d["ligen"].keys():
		_plane_liga(d, lid, basis)
	for pid in d["pokale"].keys():
		_plane_pokal_start(d, pid, basis)
	_plane_supercups(d, basis)
	_plane_testspiele(d, basis)
	_plane_international(d, basis)
	Nationalteam.turnier_planen(d, basis)

static func _neue_spiel_id(d: Dictionary) -> String:
	d["zaehler"]["spiel"] = int(d["zaehler"]["spiel"]) + 1
	return "m_%06d" % int(d["zaehler"]["spiel"])

static func eintragen(d: Dictionary, spiel: Dictionary) -> String:
	var sid: String = spiel["id"]
	d["spiele"][sid] = spiel
	var tag: int = int(spiel["tag"])
	if not d["plan"].has(tag):
		d["plan"][tag] = []
	(d["plan"][tag] as Array).append(sid)
	return sid

static func neues_spiel(d: Dictionary, wettbewerb: String, art: String, runde: int, tag: int, heim: String, gast: String, extra: Dictionary = {}) -> Dictionary:
	var spiel := {
		"id": _neue_spiel_id(d),
		"wettbewerb": wettbewerb,
		"art": art,
		"runde": runde,
		"tag": tag,
		"heim": heim,
		"gast": gast,
		"gespielt": false,
		"tore_heim": 0,
		"tore_gast": 0,
		"halbzeit": [0, 0],
		"zuschauer": 0,
		"ko": art in ["pokal", "supercup"] or bool(extra.get("ko", false)),
		"hinspiel": str(extra.get("hinspiel", "")),
		"rueckspiel_von": str(extra.get("rueckspiel_von", "")),
		"entscheidung": "",
		"bericht": {},
		"gruppe": str(extra.get("gruppe", "")),
	}
	eintragen(d, spiel)
	return spiel

# ------------------------------------------------------------------ Liga ---

static func _plane_liga(d: Dictionary, lid: String, basis: int) -> void:
	var liga: Dictionary = d["ligen"][lid]
	var teams: Array = (liga["vereine"] as Array).duplicate()
	teams.shuffle()
	# Hinterlegte Ansetzungen gehen vor. Was dort nicht steht, wird ergaenzt;
	# laesst sich der Rest nicht zu einer sauberen Doppelrunde schliessen,
	# faellt der ganze Plan weg und es wird ausgelost wie immer.
	var runden := echte_runden(d, lid, teams)
	if runden.is_empty():
		runden = doppelrunde(teams)
	liga["spieltage"] = runden.size()
	liga["aktueller_spieltag"] = 0
	liga["tabelle"] = {}
	for cid in teams:
		liga["tabelle"][cid] = leere_tabellenzeile()
	var termine := _spieltag_termine(runden.size(), basis, int(liga["stufe"]))
	for r in range(runden.size()):
		for paar in runden[r]:
			neues_spiel(d, lid, "liga", r + 1, termine[r], paar[0], paar[1])

static func leere_tabellenzeile() -> Dictionary:
	return {"sp": 0, "s": 0, "u": 0, "n": 0, "tore": 0, "gegentore": 0, "punkte": 0, "serie": []}

# --------------------------------------------------- Echte Ansetzungen ---
#
# Eine ausgeloste Doppelrunde ist eine Doppelrunde, aber nicht die richtige.
# Wer wissen will, wann sein Verein nach Kiel muss, will den echten Termin —
# und der Saisonverlauf haengt daran, ob die drei schwersten Auswaertsspiele
# im September oder im April liegen.
#
# Hinterlegt wird in daten/spielplan.json, und zwar so viel, wie bekannt ist.
# Die HBL veroeffentlicht zeitgenaue Ansetzungen zunaechst nur fuer die ersten
# Spieltage; der Rest steht spaeter fest. Deshalb ergaenzt das Spiel, was
# fehlt, statt einen unvollstaendigen Plan abzulehnen.

## Baut die Spieltage einer Liga aus den hinterlegten Ansetzungen.
## Liefert eine leere Liste, wenn nichts hinterlegt ist oder der Plan nicht
## aufgeht — dann wird ausgelost.
static func echte_runden(d: Dictionary, lid: String, teams: Array) -> Array:
	var liganame: String = str(d["ligen"][lid].get("name", ""))
	# Selbst eingespielte Plaene schlagen den mitgelieferten Datensatz.
	var partien: Array = Spielplanpflege.partien(liganame)
	if partien.is_empty():
		return []
	# Vereinsname -> id. Ein Name, den die Liga nicht kennt, macht den ganzen
	# Plan unbrauchbar: lieber auslosen als die falschen Mannschaften paaren.
	var nach_name := {}
	for cid in teams:
		nach_name[str(d["vereine"][cid]["name"])] = str(cid)
	var soll: int = (teams.size() - 1) * 2
	var je_spieltag: int = int(teams.size() / 2)

	var belegt := {}
	var gesetzt := {}
	for e in partien:
		var heim: String = str(nach_name.get(str((e as Dictionary).get("heim", "")), ""))
		var gast: String = str(nach_name.get(str((e as Dictionary).get("gast", "")), ""))
		var tag: int = int((e as Dictionary).get("spieltag", 0))
		if heim == "" or gast == "" or heim == gast or tag < 1 or tag > soll:
			push_warning("Spielplan %s: unbrauchbare Zeile wird verworfen." % liganame)
			return []
		var schluessel: String = "%s>%s" % [heim, gast]
		if gesetzt.has(schluessel):
			push_warning("Spielplan %s: %s kommt doppelt vor." % [liganame, schluessel])
			return []
		gesetzt[schluessel] = tag
		if not belegt.has(tag):
			belegt[tag] = []
		# Keine Mannschaft zweimal an einem Spieltag.
		for paar in belegt[tag]:
			if paar[0] == heim or paar[1] == heim or paar[0] == gast or paar[1] == gast:
				push_warning("Spielplan %s: doppelter Einsatz am %d. Spieltag." % [liganame, tag])
				return []
		(belegt[tag] as Array).append([heim, gast])

	# Ist der Plan vollstaendig, gilt er unveraendert. Das ist der Fall, auf
	# den es ankommt: wer den offiziellen Spielplan einspielt, will ihn genau
	# so haben und nicht nachgebaut.
	if gesetzt.size() == teams.size() * (teams.size() - 1):
		var voll: Array = []
		for r in range(soll):
			voll.append((belegt.get(r + 1, []) as Array).duplicate())
		for r2 in range(soll):
			if (voll[r2] as Array).size() != je_spieltag:
				push_warning("Spielplan %s: %d. Spieltag hat %d statt %d Partien." % [
					liganame, r2 + 1, (voll[r2] as Array).size(), je_spieltag])
				return []
		return voll

	# Sonst wird ergaenzt — und zwar nicht durch Zusammenstueckeln.
	#
	# Eine Doppelrunde ist keine beliebige Verteilung von Paarungen auf
	# Spieltage, sondern eine Zerlegung in lauter vollstaendige Paarungsrunden.
	# Wer sie Partie fuer Partie fuellt, sitzt am Ende zuverlaessig mit zwei
	# Mannschaften da, die schon gegeneinander gespielt haben: sechzig Anlaeufe
	# eines gierigen Verfahrens sind in der Erprobung ausnahmslos gescheitert.
	#
	# Stattdessen wird vom Kreisverfahren ausgegangen, das eine gueltige
	# Doppelrunde von sich aus liefert, und die Mannschaften werden so
	# umbenannt, dass die erste hinterlegte Runde genau aufgeht. Danach werden
	# die Spieltage verschoben, bis sie an ihrem Platz liegt.
	return _um_hinterlegte_runde(teams, belegt, gesetzt, soll, je_spieltag, liganame)

## Baut eine vollstaendige Doppelrunde, in der ein hinterlegter Spieltag
## genau so vorkommt, wie er hinterlegt ist.
static func _um_hinterlegte_runde(teams: Array, belegt: Dictionary, gesetzt: Dictionary,
		soll: int, je_spieltag: int, liganame: String) -> Array:
	# Der Anker ist der erste vollstaendig hinterlegte Spieltag. Ein halb
	# gefuellter taugt nicht: dann steht nicht fest, wer gegen wen spielt.
	var anker := -1
	var tage: Array = belegt.keys()
	tage.sort()
	for tag in tage:
		if (belegt[tag] as Array).size() == je_spieltag:
			anker = int(tag)
			break
	if anker < 0:
		push_warning("Spielplan %s: kein vollstaendiger Spieltag hinterlegt — es wird ausgelost." % liganame)
		return []

	var vorbild: Array = belegt[anker]
	var basis := doppelrunde(teams)
	if basis.size() != soll or (basis[0] as Array).size() != je_spieltag:
		return []

	# Umbenennung: die k-te Paarung der ersten Kreisrunde wird die k-te
	# Paarung des hinterlegten Spieltags, Heimrecht eingeschlossen.
	var abbildung := {}
	for k in range(je_spieltag):
		abbildung[str((basis[0] as Array)[k][0])] = str(vorbild[k][0])
		abbildung[str((basis[0] as Array)[k][1])] = str(vorbild[k][1])
	if abbildung.size() != teams.size():
		return []

	var runden: Array = []
	for r in range(soll):
		# Die Spieltage rotieren, bis die Kreisrunde 0 auf dem Anker liegt.
		var quelle: int = (r - (anker - 1) + soll) % soll
		var neu_runde: Array = []
		for paar in basis[quelle]:
			neu_runde.append([str(abbildung[str(paar[0])]), str(abbildung[str(paar[1])])])
		runden.append(neu_runde)

	# Jetzt muss alles Hinterlegte darin stehen — auch die Spieltage jenseits
	# des Ankers. Tut es das nicht, ist der Plan mit diesem Verfahren nicht zu
	# treffen, und ein halb richtiger Spielplan waere schlechter als ein
	# ausgeloster: er saehe echt aus und waere es nicht.
	for schluessel in gesetzt.keys():
		var teile: PackedStringArray = str(schluessel).split(">")
		var tag2: int = int(gesetzt[schluessel])
		var gefunden := false
		for paar2 in runden[tag2 - 1]:
			if str(paar2[0]) == teile[0] and str(paar2[1]) == teile[1]:
				gefunden = true
				break
		if not gefunden:
			push_warning("Spielplan %s: %s am %d. Spieltag laesst sich nicht einpassen — es wird ausgelost." % [
				liganame, schluessel, tag2])
			return []
	return runden

## Doppelrunde nach dem Kreisverfahren; Rueckrunde mit getauschtem Heimrecht.
static func doppelrunde(teams: Array) -> Array:
	var hin := _paarungsrunden(teams)
	_heimrecht_verteilen(hin)
	var rueck: Array = []
	for paare in hin:
		var gedreht: Array = []
		for paar in paare:
			gedreht.append([paar[1], paar[0]])
		rueck.append(gedreht)
	var alles: Array = []
	alles.append_array(hin)
	alles.append_array(rueck)
	return alles

## Wer gegen wen — nach dem Kreisverfahren, ohne Heimrecht.
static func _paarungsrunden(teams: Array) -> Array:
	var liste: Array = teams.duplicate()
	if liste.size() % 2 == 1:
		liste.append("")
	var n: int = liste.size()
	var runden: Array = []
	for r in range(n - 1):
		var paare: Array = []
		for i in range(int(n / 2.0)):
			var a = liste[i]
			var b = liste[n - 1 - i]
			if a == "" or b == "":
				continue
			paare.append([a, b])
		runden.append(paare)
		# Rotation: erstes Element bleibt stehen
		var letzter = liste.pop_back()
		liste.insert(1, letzter)
	return runden

## Wer daheim spielt.
##
## Das war der schwerste Fehler im Spielplan, und er ist erst aufgefallen, als
## der Buerokalender den Monat am Stueck zeigte: siebzehn der achtzehn Vereine
## hatten die komplette Hinrunde Heimspiele und die komplette Rueckrunde
## Auswaertsspiele. Die Ursache lag in der alten Regel `(r + i) % 2`: ein
## Verein rueckt im Kreisverfahren je Runde um eine Position weiter, r waechst
## ebenfalls um eins, und damit blieb die Summe in ihrer Parität stehen. Jeder
## Verein hatte genau einen Wechsel — den, bei dem er die Kreismitte kreuzte.
##
## Jetzt wird das Heimrecht Runde fuer Runde vergeben, und zwar so, dass
## niemand lange dieselbe Sorte Spiel hat und der Stand zwischendurch ungefaehr
## ausgeglichen bleibt. Am Saisonende ist er es ohnehin: die Rueckrunde
## spiegelt die Hinrunde, also kommt jeder auf genau so viele Heim- wie
## Auswaertsspiele, unabhaengig davon, wie die Hinrunde ausfaellt.
static func _heimrecht_verteilen(runden: Array) -> void:
	var letzte := {}
	var serie := {}
	var heimzahl := {}
	for r in range(runden.size()):
		var paare: Array = runden[r]
		for k in range(paare.size()):
			var x: String = str(paare[k][0])
			var y: String = str(paare[k][1])
			if _heimkosten(x, y, r, letzte, serie, heimzahl) \
					<= _heimkosten(y, x, r, letzte, serie, heimzahl):
				paare[k] = [x, y]
			else:
				paare[k] = [y, x]
			var heim: String = str(paare[k][0])
			var gast: String = str(paare[k][1])
			for eintrag in [[heim, "H"], [gast, "A"]]:
				var t: String = str(eintrag[0])
				var art: String = str(eintrag[1])
				serie[t] = int(serie.get(t, 0)) + 1 if str(letzte.get(t, "")) == art else 1
				letzte[t] = art
			heimzahl[heim] = int(heimzahl.get(heim, 0)) + 1

## Was es kostet, wenn `heim` gegen `gast` das Heimrecht bekommt. Eine
## fortlaufende Serie wiegt schwer, ein ungleicher Zwischenstand leicht.
static func _heimkosten(heim: String, gast: String, runde: int,
		letzte: Dictionary, serie: Dictionary, heimzahl: Dictionary) -> float:
	var kosten := 0.0
	if str(letzte.get(heim, "")) == "H":
		kosten += 10.0 * float(serie.get(heim, 0))
	if str(letzte.get(gast, "")) == "A":
		kosten += 10.0 * float(serie.get(gast, 0))
	kosten += absf(float(int(heimzahl.get(heim, 0)) + 1) * 2.0 - float(runde + 1))
	kosten += absf(float(int(heimzahl.get(gast, 0))) * 2.0 - float(runde + 1))
	return kosten

## Verteilt Spieltage auf Wochenenden und laesst die Winterpause aus.
## Grosse Ligen (18 Vereine = 34 Spieltage) passen nicht allein auf Wochenenden —
## dann werden zusaetzlich Mittwochstermine belegt, also englische Wochen gespielt.
static func _spieltag_termine(anzahl: int, basis: int, stufe: int) -> Array:
	var wochenende: Array = []
	var mittwoch: Array = []
	var wunsch: int = 5 if stufe == 1 else 6  # Samstag / Sonntag
	for t in range(LIGA_START, LIGA_ENDE + 1):
		if t >= WINTERPAUSE_VON and t <= WINTERPAUSE_BIS:
			continue
		var wt: int = Kalender.wochentag(t)
		if wt == wunsch:
			wochenende.append(t)
		elif wt == 2:
			mittwoch.append(t)
	var slots: Array = wochenende.duplicate()
	if slots.size() < anzahl:
		slots.append_array(mittwoch)
		slots.sort()
	if slots.is_empty():
		var ersatz: Array = []
		for i in range(anzahl):
			ersatz.append(basis + LIGA_START + i * 7)
		return ersatz
	# Gleichmaessig ueber die Saison verteilen
	var termine: Array = []
	var schritt: float = float(slots.size()) / float(maxi(anzahl, 1))
	var zuletzt: int = -1
	for i in range(anzahl):
		var idx: int = clampi(int(round(float(i) * schritt)), 0, slots.size() - 1)
		if int(slots[idx]) <= zuletzt:
			idx = clampi(slots.bsearch(zuletzt + 1), 0, slots.size() - 1)
		zuletzt = int(slots[idx])
		termine.append(basis + zuletzt)
	# Falls die Liga laenger ist als die Slots reichen: hinten anhaengen
	for i in range(1, termine.size()):
		if termine[i] <= termine[i - 1]:
			termine[i] = termine[i - 1] + 3
	return termine

# ----------------------------------------------------------------- Pokal ---

const POKAL_TERMINE := [62, 96, 130, 214, 248, 276, 304, 326]

static func _plane_pokal_start(d: Dictionary, pid: String, basis: int) -> void:
	var pokal: Dictionary = d["pokale"][pid]
	var nid: String = pokal["nation"]
	var teilnehmer: Array = []
	for lid in (d["nationen"][nid]["ligen"] as Array):
		teilnehmer.append_array(d["ligen"][lid]["vereine"])
	teilnehmer.sort_custom(func(a, b): return float(d["vereine"][a]["ruf"]) > float(d["vereine"][b]["ruf"]))
	pokal["teilnehmer"] = teilnehmer
	pokal["runde"] = 0
	pokal["beendet"] = false
	pokal["paarungen"] = []
	pokal["basis"] = basis
	_lose_pokalrunde(d, pid, teilnehmer)

## Lost die naechste Pokalrunde aus. Setzt Freilose fuer die stärksten Vereine.
static func _lose_pokalrunde(d: Dictionary, pid: String, teilnehmer: Array) -> void:
	var pokal: Dictionary = d["pokale"][pid]
	if teilnehmer.size() <= 1:
		pokal["beendet"] = true
		return
	var runde: int = int(pokal["runde"])
	var basis: int = int(pokal.get("basis", 0))
	var termin: int = maxi(basis + POKAL_TERMINE[mini(runde, POKAL_TERMINE.size() - 1)], int(d["tag"]) + 4)
	var liste: Array = teilnehmer.duplicate()
	# Auf die naechstkleinere Zweierpotenz reduzieren: die stärksten Vereine
	# bekommen ein Freilos, der Rest spielt die restlichen Plaetze aus.
	var ziel: int = 1
	while ziel * 2 <= liste.size():
		ziel *= 2
	var freilose: Array = []
	if ziel < liste.size():
		var ueberhang: int = liste.size() - ziel
		var stark: Array = liste.duplicate()
		stark.sort_custom(func(a, b): return float(d["vereine"][a]["ruf"]) > float(d["vereine"][b]["ruf"]))
		var freilos_anzahl: int = maxi(ziel - ueberhang, 0)
		for i in range(freilos_anzahl):
			freilose.append(stark[i])
		for f in freilose:
			liste.erase(f)
	liste.shuffle()
	var paarungen: Array = []
	for i in range(0, liste.size() - 1, 2):
		var heim: String = liste[i]
		var gast: String = liste[i + 1]
		# Unterklassiger Verein hat Heimrecht (Pokalfolklore)
		if int(d["ligen"][d["vereine"][gast]["liga"]]["stufe"]) > int(d["ligen"][d["vereine"][heim]["liga"]]["stufe"]):
			var tmp := heim
			heim = gast
			gast = tmp
		var spiel := neues_spiel(d, pid, "pokal", runde + 1, termin, heim, gast)
		paarungen.append(spiel["id"])
	pokal["paarungen"] = paarungen
	pokal["freilose"] = freilose
	pokal["runde"] = runde + 1
	pokal["termin"] = termin

## Nach gespielter Runde: Sieger ermitteln und naechste Runde auslosen.
static func pokal_weiter(d: Dictionary, pid: String) -> Array:
	var pokal: Dictionary = d["pokale"][pid]
	var sieger: Array = []
	for mid in pokal["paarungen"]:
		var sp: Dictionary = d["spiele"][mid]
		if not bool(sp["gespielt"]):
			return []
		sieger.append(sp["heim"] if int(sp["tore_heim"]) > int(sp["tore_gast"]) else sp["gast"])
	sieger.append_array(pokal.get("freilose", []))
	if sieger.size() == 1:
		pokal["beendet"] = true
		pokal["sieger"] = sieger[0]
		return sieger
	_lose_pokalrunde(d, pid, sieger)
	return sieger

static func pokalrunden_name(teilnehmer: int) -> String:
	match teilnehmer:
		2: return "Finale"
		4: return "Halbfinale"
		8: return "Viertelfinale"
		16: return "Achtelfinale"
		32: return "Sechzehntelfinale"
		_: return "%d. Runde" % teilnehmer

# ------------------------------------------------------------- Supercup ---

static func _plane_supercups(d: Dictionary, basis: int) -> void:
	for nid in d["nationen"].keys():
		var nation: Dictionary = d["nationen"][nid]
		var meister: String = str(nation.get("letzter_meister", ""))
		var pokalsieger: String = str(nation.get("letzter_pokalsieger", ""))
		if meister == "" or pokalsieger == "" or meister == pokalsieger:
			continue
		neues_spiel(d, "sc_" + nid, "supercup", 1, basis + 38, meister, pokalsieger)

# ------------------------------------------------------ Vorbereitung ---

const TEST_TERMINE := [12, 19, 26, 33, 40]

## Vorbereitungsspiele im Juli und August. Sie zaehlen fuer keine Tabelle und
## keine Statistik, geben der Mannschaft aber Spielpraxis — und dem Trainer den
## ersten Blick auf den neuen Kader.
static func _plane_testspiele(d: Dictionary, basis: int) -> void:
	for nid in d["nationen"].keys():
		var vereine: Array = []
		for lid in (d["nationen"][nid]["ligen"] as Array):
			vereine.append_array(d["ligen"][lid]["vereine"])
		if vereine.size() < 2:
			continue
		# Nach Ruf sortieren und nur innerhalb kleiner Fenster mischen, damit
		# Testspiele halbwegs ausgeglichen sind statt 40:12 zu enden.
		vereine.sort_custom(func(a, b): return float(d["vereine"][a]["ruf"]) > float(d["vereine"][b]["ruf"]))
		for runde in range(TEST_TERMINE.size()):
			var liste: Array = []
			for start in range(0, vereine.size(), 4):
				var fenster: Array = vereine.slice(start, mini(start + 4, vereine.size()))
				fenster.shuffle()
				liste.append_array(fenster)
			var termin: int = basis + TEST_TERMINE[runde]
			for i in range(0, liste.size() - 1, 2):
				var heim: String = str(liste[i])
				var gast: String = str(liste[i + 1])
				if runde % 2 == 1:
					var tausch := heim
					heim = gast
					gast = tausch
				neues_spiel(d, "test_" + nid, "test", runde + 1, termin, heim, gast)

# -------------------------------------------------------- International ---

const GRUPPEN_TERMINE := [104, 118, 138, 152, 166, 208]
const KO_TERMINE := [222, 234, 248, 260, 274, 288, 302, 318]

static func _plane_international(d: Dictionary, basis: int) -> void:
	var krone: Dictionary = d["international"]["i_krone"]
	var challenge: Dictionary = d["international"]["i_challenge"]
	var qual := _qualifikanten(d)
	krone["teilnehmer"] = qual["krone"]
	challenge["teilnehmer"] = qual["challenge"]
	krone["basis"] = basis
	challenge["basis"] = basis
	_plane_gruppenphase(d, krone, basis)
	_plane_ko_start(d, challenge, basis, challenge["teilnehmer"])

## Teilnehmer: in der ersten Saison nach Ruf, danach nach Abschlussplatzierung.
static func _qualifikanten(d: Dictionary) -> Dictionary:
	var krone: Array = []
	var challenge: Array = []
	for nid in d["nationen"].keys():
		var nation: Dictionary = d["nationen"][nid]
		var lid: String = str((nation["ligen"] as Array)[0])
		var liga: Dictionary = d["ligen"][lid]
		var rang: Array = liga.get("abschlusstabelle", [])
		if rang.is_empty():
			rang = (liga["vereine"] as Array).duplicate()
			rang.sort_custom(func(a, b): return float(d["vereine"][a]["ruf"]) > float(d["vereine"][b]["ruf"]))
		var plaetze_krone: int = 3 if float(nation["ruf"]) >= 85.0 else 2
		for i in range(mini(plaetze_krone, rang.size())):
			krone.append(rang[i])
		for i in range(plaetze_krone, mini(plaetze_krone + 3, rang.size())):
			challenge.append(rang[i])
		var pokal: Dictionary = d["pokale"][nation["pokal"]]
		var ps: String = str(pokal.get("sieger", ""))
		if ps != "" and not krone.has(ps) and not challenge.has(ps):
			challenge.append(ps)
	# Auf 16 auffuellen bzw. kuerzen
	krone = _auf_groesse(d, krone, 16, challenge)
	challenge = _auf_groesse(d, challenge, 16, krone)
	return {"krone": krone, "challenge": challenge}

static func _auf_groesse(d: Dictionary, liste: Array, groesse: int, tabu: Array) -> Array:
	var ergebnis: Array = liste.duplicate()
	if ergebnis.size() > groesse:
		return ergebnis.slice(0, groesse)
	var kandidaten: Array = []
	for cid in Weltgenerator.clubs(d):
		if ergebnis.has(cid) or tabu.has(cid):
			continue
		var lid: String = str(d["vereine"][cid]["liga"])
		if not d["ligen"].has(lid) or int(d["ligen"][lid]["stufe"]) != 1:
			continue
		kandidaten.append(cid)
	kandidaten.sort_custom(func(a, b): return float(d["vereine"][a]["ruf"]) > float(d["vereine"][b]["ruf"]))
	var i := 0
	while ergebnis.size() < groesse and i < kandidaten.size():
		ergebnis.append(kandidaten[i])
		i += 1
	return ergebnis

static func _plane_gruppenphase(d: Dictionary, wb: Dictionary, basis: int) -> void:
	var teams: Array = (wb["teilnehmer"] as Array).duplicate()
	teams.sort_custom(func(a, b): return float(d["vereine"][a]["ruf"]) > float(d["vereine"][b]["ruf"]))
	var gruppen: Array = [[], [], [], []]
	# Schlangensetzung fuer ausgewogene Gruppen
	for i in range(teams.size()):
		var topf: int = int(i / 4.0)
		var g: int = (i % 4) if topf % 2 == 0 else (3 - (i % 4))
		gruppen[g].append(teams[i])
	wb["gruppen"] = gruppen
	wb["tabelle"] = {}
	wb["phase"] = "gruppe"
	wb["runde"] = 0
	wb["paarungen"] = []
	var gnamen := ["A", "B", "C", "D"]
	for gi in range(gruppen.size()):
		for cid in gruppen[gi]:
			wb["tabelle"][cid] = leere_tabellenzeile()
		var runden := doppelrunde(gruppen[gi])
		for r in range(runden.size()):
			var termin: int = basis + GRUPPEN_TERMINE[mini(r, GRUPPEN_TERMINE.size() - 1)]
			for paar in runden[r]:
				neues_spiel(d, wb["id"], "international", r + 1, termin, paar[0], paar[1], {"gruppe": gnamen[gi]})

static func _plane_ko_start(d: Dictionary, wb: Dictionary, basis: int, teams: Array) -> void:
	wb["phase"] = "ko"
	wb["runde"] = 0
	var liste: Array = teams.duplicate()
	liste.shuffle()
	_ko_runde(d, wb, basis, liste)

## Erzeugt eine K.-o.-Runde mit Hin- und Rueckspiel (Finale einfach).
static func _ko_runde(d: Dictionary, wb: Dictionary, basis: int, teams: Array) -> void:
	if teams.size() <= 1:
		wb["phase"] = "beendet"
		if teams.size() == 1:
			wb["sieger"] = teams[0]
		return
	var runde: int = int(wb["runde"])
	var idx: int = mini(runde * 2, KO_TERMINE.size() - 2)
	# Termine duerfen nie in der Vergangenheit liegen, sonst wird die Runde nie gespielt.
	var frueheste: int = int(d["tag"]) + 4
	var t1: int = maxi(basis + KO_TERMINE[idx], frueheste)
	var t2: int = maxi(basis + KO_TERMINE[idx + 1], t1 + 7)
	var paarungen: Array = []
	var finale: bool = teams.size() == 2
	for i in range(0, teams.size() - 1, 2):
		var a: String = teams[i]
		var b: String = teams[i + 1]
		if finale:
			var f := neues_spiel(d, wb["id"], "international", runde + 1, t2, a, b, {"ko": true})
			paarungen.append({"hin": "", "rueck": f["id"], "a": a, "b": b})
		else:
			var hin := neues_spiel(d, wb["id"], "international", runde + 1, t1, a, b, {"ko": true})
			var rueck := neues_spiel(d, wb["id"], "international", runde + 1, t2, b, a, {"ko": true, "hinspiel": hin["id"]})
			paarungen.append({"hin": hin["id"], "rueck": rueck["id"], "a": a, "b": b})
	wb["paarungen"] = paarungen
	wb["runde"] = runde + 1

## Wertet eine abgeschlossene K.-o.-Runde aus und lost die naechste.
static func ko_weiter(d: Dictionary, wid: String) -> Array:
	var wb: Dictionary = d["international"][wid]
	var sieger: Array = []
	for p in wb["paarungen"]:
		var rueck: Dictionary = d["spiele"][p["rueck"]]
		if not bool(rueck["gespielt"]):
			return []
		if str(p["hin"]) == "":
			sieger.append(rueck["heim"] if int(rueck["tore_heim"]) > int(rueck["tore_gast"]) else rueck["gast"])
			continue
		var hin: Dictionary = d["spiele"][p["hin"]]
		var a_tore: int = int(hin["tore_heim"]) + int(rueck["tore_gast"])
		var b_tore: int = int(hin["tore_gast"]) + int(rueck["tore_heim"])
		if a_tore > b_tore:
			sieger.append(p["a"])
		elif b_tore > a_tore:
			sieger.append(p["b"])
		else:
			# Auswaertstore, sonst Los
			sieger.append(p["b"] if int(rueck["tore_heim"]) > 0 else p["a"])
	if sieger.size() == 1:
		wb["phase"] = "beendet"
		wb["sieger"] = sieger[0]
		return sieger
	_ko_runde(d, wb, int(wb.get("basis", 0)), sieger)
	return sieger

## Nach der Gruppenphase: die zwei Besten jeder Gruppe ziehen ins Viertelfinale.
static func gruppen_auswertung(d: Dictionary, wid: String) -> Array:
	var wb: Dictionary = d["international"][wid]
	var weiter: Array = []
	var gnamen := ["A", "B", "C", "D"]
	for gi in range(wb["gruppen"].size()):
		var gruppe: Array = wb["gruppen"][gi]
		var sortiert: Array = gruppe.duplicate()
		sortiert.sort_custom(func(a, b): return _tabellen_vergleich(wb["tabelle"], a, b))
		for i in range(mini(2, sortiert.size())):
			weiter.append(sortiert[i])
		wb["gruppe_%s" % gnamen[gi]] = sortiert
	# Kreuzweise Zuordnung: Gruppensieger trifft auf den Zweiten einer anderen Gruppe.
	var sieger_liste: Array = []
	var zweite: Array = []
	for i in range(weiter.size()):
		if i % 2 == 0:
			sieger_liste.append(weiter[i])
		else:
			zweite.append(weiter[i])
	var paarung: Array = []
	var kreuz := [1, 0, 3, 2]
	for i in range(sieger_liste.size()):
		paarung.append(sieger_liste[i])
		paarung.append(zweite[kreuz[i] if i < kreuz.size() and kreuz[i] < zweite.size() else i])
	wb["phase"] = "ko"
	wb["runde"] = 0
	_ko_runde(d, wb, int(wb.get("basis", 0)), paarung)
	return paarung

static func _tabellen_vergleich(tabelle: Dictionary, a, b) -> bool:
	var ta: Dictionary = tabelle.get(a, leere_tabellenzeile())
	var tb: Dictionary = tabelle.get(b, leere_tabellenzeile())
	if int(ta["punkte"]) != int(tb["punkte"]):
		return int(ta["punkte"]) > int(tb["punkte"])
	var da: int = int(ta["tore"]) - int(ta["gegentore"])
	var db: int = int(tb["tore"]) - int(tb["gegentore"])
	if da != db:
		return da > db
	return int(ta["tore"]) > int(tb["tore"])

## Sortierte Ligatabelle als Array von Vereins-IDs.
static func tabelle_sortiert(d: Dictionary, lid: String) -> Array:
	var liga: Dictionary = d["ligen"][lid]
	var liste: Array = (liga["vereine"] as Array).duplicate()
	liste.sort_custom(func(a, b): return _tabellen_vergleich(liga["tabelle"], a, b))
	return liste

static func gruppen_tabelle_sortiert(wb: Dictionary, gruppe: Array) -> Array:
	var liste: Array = gruppe.duplicate()
	liste.sort_custom(func(a, b): return _tabellen_vergleich(wb["tabelle"], a, b))
	return liste
