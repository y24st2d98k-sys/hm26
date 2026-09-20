extends Node
## Urteilt der Vorstand auch in der Saison, in der der Verein absteigt?
##
## Der Saisonabschluss verschiebt die Vereine zuerst zwischen den Ligen und
## zieht danach Bilanz. Wer die Bilanz aus verein["liga"] liest, liest nach
## dem Abstieg in der falschen Liga — und findet die eigene Mannschaft in
## deren Abschlusstabelle nicht. Diese Sonde stellt den Abstieg her und
## schaut, ob Vorstand und Trainerruf trotzdem reagieren.

var fehler := 0
var geprueft := 0

func _log(t: String) -> void:
	printerr(t)

func _pruefe(name: String, bedingung: bool, bemerkung: String = "") -> void:
	geprueft += 1
	if bedingung:
		_log("   ok   %s" % name)
	else:
		fehler += 1
		_log("   FEHLER %s   %s" % [name, bemerkung])

func _ready() -> void:
	seed(313131)
	var vorschau := Weltgenerator.erzeuge(2026, 313131)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][3])
	seed(313131)
	Welt.neues_spiel(cid, {"vorname": "Mira", "nachname": "Halden",
		"hintergrund": "nachwuchs", "nation": "de", "alter": 41}, 313131)
	var d: Dictionary = Welt.daten
	var lid: String = str(d["vereine"][cid]["liga"])
	var liga: Dictionary = d["ligen"][lid]

	# Eine Abschlusssaison von Hand: alle spielen 34 Spiele, wir werden Letzter.
	var vereine: Array = (liga["vereine"] as Array).duplicate()
	var punkte: int = 2 * vereine.size()
	for c in vereine:
		var eigen: bool = str(c) == cid
		liga["tabelle"][str(c)] = {
			"sp": 34, "s": 0, "u": 0, "n": 0,
			"punkte": 6 if eigen else punkte,
			"tore": 800 if eigen else 900,
			"gegentore": 900 if eigen else 850,
		}
		if not eigen:
			punkte -= 2
	var vorher_vertrauen: float = float(d["vereine"][cid]["vorstand"]["vertrauen"])
	var vorher_ruf: float = float(d.get("trainer", {}).get("ruf", 0.0))
	var vorher_nachrichten: int = (d["nachrichten"] as Array).size()

	_log("")
	_log("— Abstieg herstellen und Bilanz ziehen —")
	Saison.abschluss(d, cid)

	var neue_liga: String = str(d["vereine"][cid]["liga"])
	_pruefe("Verein ist abgestiegen", neue_liga != lid, "Liga blieb %s" % neue_liga)

	var bilanz := ""
	for n in (d["nachrichten"] as Array):
		if str((n as Dictionary).get("betreff", "")).begins_with("Saisonbilanz"):
			bilanz = str((n as Dictionary).get("text", ""))
			break
	_pruefe("Vorstand zieht Bilanz", bilanz != "",
		"%d neue Nachrichten, keine Saisonbilanz" % ((d["nachrichten"] as Array).size() - vorher_nachrichten))
	if bilanz != "":
		_log("        „%s“" % bilanz)

	var nachher_vertrauen: float = float(d["vereine"][cid]["vorstand"]["vertrauen"])
	_pruefe("Vertrauen sinkt nach dem Abstieg", nachher_vertrauen < vorher_vertrauen,
		"vorher %.1f, nachher %.1f" % [vorher_vertrauen, nachher_vertrauen])
	_pruefe("Abschlusstabelle trägt ihren Saisonstempel",
		int(d["ligen"][lid].get("abschluss_saison", -1)) == Welt.saison_index(),
		"Stempel %d, Saison %d" % [int(d["ligen"][lid].get("abschluss_saison", -1)), Welt.saison_index()])
	var nachher_ruf: float = float(d.get("trainer", {}).get("ruf", 0.0))
	_pruefe("Trainerruf sinkt nach dem Abstieg", nachher_ruf < vorher_ruf,
		"vorher %.1f, nachher %.1f" % [vorher_ruf, nachher_ruf])

	_aufstieg_pruefen(d, cid)

	_log("")
	if fehler == 0:
		_log("— Abstiegstest bestanden (%d Prüfungen) —" % geprueft)
	else:
		_log("— Abstiegstest: %d FEHLER bei %d Prüfungen —" % [fehler, geprueft])
	get_tree().quit(1 if fehler > 0 else 0)


## Und dieselbe Frage von der anderen Seite.
##
## Der Aufstieg verschiebt den Verein genauso zwischen den Ligen wie der
## Abstieg — nur nach oben. Wer die Bilanz aus verein["liga"] liest, findet
## ihn auch hier nicht, und der Vorstand schwiege zur schönsten Saison.
func _aufstieg_pruefen(d: Dictionary, cid: String) -> void:
	_log("")
	_log("— Und nun der Aufstieg —")
	Saison.neue_saison(d, cid)
	var lid: String = str(d["vereine"][cid]["liga"])
	var liga: Dictionary = d["ligen"][lid]
	var vereine: Array = (liga["vereine"] as Array).duplicate()
	if vereine.size() < 3:
		_pruefe("Zweite Liga hat Vereine", false, "nur %d" % vereine.size())
		return
	_tabelle_fuellen(d, lid, cid)
	# Auch die erste Liga braucht eine Tabelle. Ohne sie verwirft der
	# Spielplan ihre Zeilen, die Abschlusstabelle bleibt zu kurz, und der
	# Auf- und Abstieg bricht ab, bevor er etwas tut — das war ein Fehler
	# dieser Sonde und keiner des Spiels.
	_tabelle_fuellen(d, str((d["nationen"][str(liga["nation"])]["ligen"] as Array)[0]), "")
	var vorher_vertrauen: float = float(d["vereine"][cid]["vorstand"]["vertrauen"])
	var vorher_nachrichten: int = (d["nachrichten"] as Array).size()
	Saison.abschluss(d, cid)

	_pruefe("Verein ist aufgestiegen", str(d["vereine"][cid]["liga"]) != lid,
		"Liga blieb %s" % str(d["vereine"][cid]["liga"]))
	# Neue Nachrichten stehen vorn, nicht hinten: Welt.nachricht setzt sie
	# mit push_front ein. Wer von hinten liest, findet die Bilanz der
	# vorigen Saison und haelt sie fuer die neue.
	var neue: int = (d["nachrichten"] as Array).size() - vorher_nachrichten
	var bilanz := ""
	for i in range(maxi(neue, 0)):
		var n: Dictionary = (d["nachrichten"] as Array)[i]
		if str(n.get("betreff", "")).begins_with("Saisonbilanz"):
			bilanz = str(n.get("text", ""))
			break
	_pruefe("Vorstand zieht auch nach dem Aufstieg Bilanz", bilanz != "",
		"%d neue Nachrichten, keine Saisonbilanz" % ((d["nachrichten"] as Array).size() - vorher_nachrichten))
	if bilanz != "":
		_log("        \u201e%s\u201c" % bilanz)
	_pruefe("Vertrauen steigt nach dem Aufstieg",
		float(d["vereine"][cid]["vorstand"]["vertrauen"]) > vorher_vertrauen,
		"vorher %.1f, nachher %.1f" % [vorher_vertrauen,
			float(d["vereine"][cid]["vorstand"]["vertrauen"])])


## Eine vollstaendige Abschlusstabelle von Hand. Wer in "bester" steht,
## gewinnt die Liga deutlich; "" heisst: niemand ist hervorgehoben.
func _tabelle_fuellen(d: Dictionary, lid: String, bester: String) -> void:
	var liga: Dictionary = d["ligen"][lid]
	# Der Hervorgehobene bekommt mehr Punkte, als die absteigende Reihe
	# ueberhaupt vergibt. Ein Aufschlag auf den Listenplatz reichte nicht:
	# stand er weit hinten in der Liste, blieb er trotzdem hinter dem
	# Ersten — und die Sonde mass ihren eigenen Fehler.
	var hoechste: int = 2 * (liga["vereine"] as Array).size()
	var punkte: int = hoechste
	for c in (liga["vereine"] as Array):
		var eigen: bool = str(c) == bester and bester != ""
		liga["tabelle"][str(c)] = {
			"sp": 34, "s": 0, "u": 0, "n": 0,
			"punkte": hoechste + 10 if eigen else punkte,
			"tore": 1000 if eigen else 880,
			"gegentore": 820 if eigen else 880,
		}
		if not eigen:
			punkte -= 2
