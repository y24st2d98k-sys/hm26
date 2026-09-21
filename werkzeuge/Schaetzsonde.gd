extends Node
## Bleibt eine Einschätzung stehen, wenn man zweimal hinsieht?
##
## Was der Scout über einen Spieler sagt, ist eine Meinung mit Fehler — das
## ist richtig so. Der Fehler darf aber nicht bei jedem Zeichnen neu gewürfelt
## werden: dann springt die Perspektive eines Nachwuchsspielers zwischen zwei
## Klicks von "Zweitliganiveau" auf "Nationalmannschaftsformat", und man kann
## keiner Zahl im Spiel mehr trauen.
##
## Diese Sonde ruft jede Anzeigefunktion zehnmal auf und zählt, wie oft sich
## die Antwort ändert. Und sie prüft, dass die Einschätzung mit wachsender
## Kenntnis näher an die Wahrheit rückt statt zu flackern.

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

func _stabil(f: Callable) -> Array:
	var gesehen := {}
	for _i in range(10):
		gesehen[str(f.call())] = true
	return gesehen.keys()

func _ready() -> void:
	seed(717171)
	var vorschau := Weltgenerator.erzeuge(2026, 717171)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(717171)
	Welt.neues_spiel(cid, {"vorname": "Schätz", "nachname": "Sonde"}, 717171)
	var d: Dictionary = Welt.daten

	# Ein junger Spieler eines fremden Vereins, halb bekannt — genau die Lage,
	# in der die Einschätzung eine Rolle spielt.
	var sid := ""
	for kandidat in (d["spieler"] as Dictionary).keys():
		var sp: Dictionary = d["spieler"][kandidat]
		if int(sp["alter"]) <= 21 and str(sp["verein"]) != cid and str(sp["verein"]) != "":
			sid = str(kandidat)
			break
	if sid == "":
		_log("Kein passender Spieler gefunden.")
		get_tree().quit(1)
		return
	var sp: Dictionary = d["spieler"][sid]
	sp["kenntnis"] = 55.0
	_log("")
	_log("Geprüft an %s, Kenntnis 55, echtes Potenzial %.1f" % [
		Spielerfabrik.voller_name(sp), float(sp["potenzial"])])
	_log("")

	var pot := _stabil(func(): return Scouting.potenzial_text(d, sid))
	_pruefe("Perspektive bleibt stehen", pot.size() == 1,
		"%d verschiedene Antworten: %s" % [pot.size(), ", ".join(pot)])
	var tempo := _stabil(func(): return Scouting.tempo_text(d, sid))
	_pruefe("Entwicklungstempo bleibt stehen", tempo.size() == 1,
		"%d verschiedene Antworten: %s" % [tempo.size(), ", ".join(tempo)])
	var attr := _stabil(func(): return Scouting.attributtext(d, sid, "wurfkraft"))
	_pruefe("Attributspanne bleibt stehen", attr.size() == 1,
		"%d verschiedene Antworten: %s" % [attr.size(), ", ".join(attr)])

	# Zwei Spieler dürfen nicht denselben Fehler haben — sonst wäre der
	# Irrtum kein Irrtum, sondern ein Versatz der ganzen Liga.
	var zweit := ""
	for kandidat2 in (d["spieler"] as Dictionary).keys():
		if str(kandidat2) != sid and int(d["spieler"][kandidat2]["alter"]) <= 21:
			zweit = str(kandidat2)
			break
	if zweit != "":
		d["spieler"][zweit]["kenntnis"] = 55.0
		d["spieler"][zweit]["potenzial"] = float(sp["potenzial"])
		var a: float = Scouting.potenzialschaetzung(d, sid)
		var b: float = Scouting.potenzialschaetzung(d, zweit)
		_pruefe("Zwei Spieler werden verschieden falsch eingeschätzt",
			absf(a - b) > 0.01, "beide %.2f" % a)

	# Nebenbei wachsende Kenntnis — das Mentoring hebt sie um Bruchteile je
	# Woche — darf die Einschätzung nicht verschieben. Nur ein Bericht darf
	# das, und der sagt es auch.
	var stand: String = Scouting.potenzial_text(d, sid)
	var spanne_vorher: String = Scouting.attributtext(d, sid, "wurfkraft")
	for _w in range(12):
		sp["kenntnis"] = clampf(float(sp["kenntnis"]) + 0.6, 0.0, 96.0)
	_pruefe("Einschätzung steht, während die Kenntnis nebenbei wächst",
		Scouting.potenzial_text(d, sid) == stand,
		"aus „%s“ wurde „%s“ bei Kenntnis %.1f" % [stand,
			Scouting.potenzial_text(d, sid), float(sp["kenntnis"])])
	_pruefe("Auch die Attributspanne steht",
		Scouting.attributtext(d, sid, "wurfkraft") == spanne_vorher,
		"aus %s wurde %s" % [spanne_vorher, Scouting.attributtext(d, sid, "wurfkraft")])

	# Ein Bericht ist der Grund, aus dem sie sich bewegen darf — und dann
	# muss sie näher an der Wahrheit liegen.
	var echt: float = float(sp["potenzial"])
	var vorher: float = absf(Scouting.potenzialschaetzung(d, sid) - echt)
	sp["kenntnis"] = 90.0
	Scouting.urteil_bilden(d, sid)
	var nachher: float = absf(Scouting.potenzialschaetzung(d, sid) - echt)
	_pruefe("Nach einem Bericht liegt sie näher an der Wahrheit",
		nachher <= vorher + 0.001,
		"vorher daneben um %.2f, nachher um %.2f" % [vorher, nachher])

	# Und wer vollständig bekannt ist, wird nicht mehr geschätzt.
	sp["kenntnis"] = 100.0
	_pruefe("Vollständig bekannt heißt: die Wahrheit",
		absf(Scouting.potenzialschaetzung(d, sid) - echt) < 0.001,
		"gezeigt %.2f, echt %.2f" % [Scouting.potenzialschaetzung(d, sid), echt])

	_log("")
	if fehler == 0:
		_log("— Schätzsonde bestanden (%d Prüfungen) —" % geprueft)
	else:
		_log("— Schätzsonde: %d FEHLER bei %d Prüfungen —" % [fehler, geprueft])
	get_tree().quit(1 if fehler > 0 else 0)
