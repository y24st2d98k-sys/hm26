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
	_pruefe("Vorstand zieht Bilanz", bilanz != "",
		"%d neue Nachrichten, keine Saisonbilanz" % ((d["nachrichten"] as Array).size() - vorher_nachrichten))
	if bilanz != "":
		_log("        „%s“" % bilanz)

	var nachher_vertrauen: float = float(d["vereine"][cid]["vorstand"]["vertrauen"])
	_pruefe("Vertrauen sinkt nach dem Abstieg", nachher_vertrauen < vorher_vertrauen,
		"vorher %.1f, nachher %.1f" % [vorher_vertrauen, nachher_vertrauen])
	var nachher_ruf: float = float(d.get("trainer", {}).get("ruf", 0.0))
	_pruefe("Trainerruf sinkt nach dem Abstieg", nachher_ruf < vorher_ruf,
		"vorher %.1f, nachher %.1f" % [vorher_ruf, nachher_ruf])

	_log("")
	if fehler == 0:
		_log("— Abstiegstest bestanden (%d Prüfungen) —" % geprueft)
	else:
		_log("— Abstiegstest: %d FEHLER bei %d Prüfungen —" % [fehler, geprueft])
	get_tree().quit(1 if fehler > 0 else 0)
