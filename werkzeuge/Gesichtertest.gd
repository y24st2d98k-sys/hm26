extends Node
## Kommen hinterlegte Portraetfotos an — und bleibt alles andere gezeichnet?
##
## Der zweite Teil ist der heiklere. Eine Sammlung deckt nie alle Spieler ab,
## und ein Kader, in dem die Haelfte ein Foto hat und die andere Haelfte einen
## gezeichneten Kopf, muss trotzdem zusammenpassen.

var fehler := 0
var durchgelaufen := false

func _log(t: String) -> void:
	printerr(t)

func _pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		_log("   ok    %s" % text)
	else:
		fehler += 1
		_log("   FEHLT  %s" % text)

func _ready() -> void:
	_log("— Aus dem Namen wird ein Dateiname —")
	var faelle := [
		["Kai", "Häfner", "kai_haefner"],
		["Gísli Þorgeir", "Kristjánsson", "gisli_thorgeir_kristjansson"],
		["Ómar Ingi", "Magnússon", "omar_ingi_magnusson"],
		["Petter", "Øverby", "petter_oeverby"],
		["Nikolaj", "Læsø", "nikolaj_laesoe"],
		["Elias", "Ellefsen á Skipagøtu", "elias_ellefsen_a_skipagoetu"],
		["Djibril", "M'Bengue", "djibril_m_bengue"],
		["Marko", "Grgić", "marko_grgic"],
		["Blaž", "Blagotinšek", "blaz_blagotinsek"],
		["Fynn-Luca", "Nicolaus", "fynn_luca_nicolaus"],
	]
	for f in faelle:
		var ist: String = Portraet.dateiname(str(f[0]), str(f[1]))
		_pruefe(ist == str(f[2]), "%s %s → %s%s" % [str(f[0]), str(f[1]), ist,
			"" if ist == str(f[2]) else "  (erwartet %s)" % str(f[2])])

	_log("")
	_log("— Hinterlegte Fotos werden gefunden —")
	# Die beiden Probebilder liegen im Auslieferungszustand mit im Ordner. Sie
	# tragen keinen Spielernamen: ein erfundenes Foto unter dem Namen eines
	# echten Spielers waere eine Behauptung ueber eine Person.
	_pruefe(Portraet.gesicht_fuer("_probe_hoch") != null, "Das Hochformat-Probebild liegt vor")
	_pruefe(Portraet.gesicht_fuer("_probe_quadrat") != null, "Das quadratische Probebild liegt vor")
	_pruefe(Portraet.gesicht_fuer("gibt_es_nicht") == null,
		"Für einen Spieler ohne Foto kommt nichts zurück")
	_pruefe(Portraet.gesicht_fuer("") == null, "Ein leerer Schlüssel liefert nichts")

	_log("")
	_log("— Im Spiel greift der abgeleitete Dateiname —")
	var d := Weltgenerator.erzeuge(2026, 4242, true)
	Welt.daten = d
	var haefner := ""
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["nachname"]) == "Häfner" and str(sp["vorname"]) == "Kai":
			haefner = str(sid)
			break
	_pruefe(haefner != "", "Kai Häfner steht im Kader")
	if haefner == "":
		return
	var spieler: Dictionary = d["spieler"][haefner]
	_pruefe(Portraet.dateiname(str(spieler["vorname"]), str(spieler["nachname"])) == "kai_haefner",
		"Sein Foto würde unter kai_haefner.png gesucht")

	var ohne := Portraet.new()
	ohne.setze(spieler)
	_pruefe(ohne.foto == null, "Ohne Datei bleibt es beim gezeichneten Kopf")
	ohne.free()

	_log("")
	_log("— Ein ausdrücklicher Dateiname geht vor —")
	var mit := Portraet.new()
	var kopie: Dictionary = spieler.duplicate()
	kopie["bild"] = "_probe_hoch"
	mit.setze(kopie)
	_pruefe(mit.foto != null, "Das Feld „bild\" schlägt die Namensableitung")
	mit.free()

	_log("")
	_log("— Der Datensatz reicht „bild\" durch —")
	var erzeugt := Spielerfabrik.erzeuge_mit_namen("s_test", {
		"vorname": "Probe", "nachname": "Spieler", "nation": "de", "alter": 27,
		"staerke": 70, "bild": "_probe_quadrat"}, "RM", 2026)
	_pruefe(str(erzeugt.get("bild", "")) == "_probe_quadrat",
		"Aus kader.json landet „bild\" beim Spieler")
	var ohne_feld := Spielerfabrik.erzeuge_mit_namen("s_test2", {
		"vorname": "Probe", "nachname": "Zwei", "nation": "de", "alter": 27,
		"staerke": 70}, "RM", 2026)
	_pruefe(not ohne_feld.has("bild"), "Ohne Angabe bleibt das Feld weg")
	_pruefe(str(Kaderpflege.normieren({"vorname": "A", "nachname": "B", "position": "RM",
		"nation": "de", "alter": 25, "staerke": 60, "bild": "_probe_hoch"}).get("bild", "")) == "_probe_hoch",
		"„bild\" überlebt das Normieren")

	durchgelaufen = true
	_log("")
	if not durchgelaufen:
		_log("— ABGEBROCHEN —")
		get_tree().quit(1)
		return
	if fehler == 0:
		_log("— Gesichter bestanden —")
	else:
		_log("— %d Prüfungen fehlgeschlagen —" % fehler)
	get_tree().quit(1 if fehler > 0 else 0)
