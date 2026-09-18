extends Node
## Greift das Lizenzierungsverfahren?
##
## Geprueft wird, was der Konzeptbericht beschreibt: Hallenauflagen nach
## Mindestkapazitaet und Beleuchtung, das Jugendzertifikat mit seinen drei
## Kriterien und der Solidarfonds, aus dem die zertifizierten Vereine bedient
## werden. Der Stand wird dabei so hergestellt, wie er am Saisonende wirklich
## aussieht — mit Nachwuchskader und gespielter Reserverunde.

var fehler := 0
var geprueft := 0

func _log(t: String) -> void:
	printerr(t)

func _pruefe(bedingung: bool, text: String) -> void:
	geprueft += 1
	if bedingung:
		_log("   ok    %s" % text)
	else:
		fehler += 1
		_log("   FEHLER %s" % text)

func _ready() -> void:
	var d := Weltgenerator.erzeuge(2026, 5150)
	Welt.daten = d
	Welt.mein_verein_id = ""

	_log("— Hallenauflagen —")
	var hbl: Array = d["ligen"]["l_de1"]["vereine"]
	var mit_auflage := 0
	for cid in hbl:
		if not Lizenzierung.auflagen(d, str(cid)).is_empty():
			mit_auflage += 1
	_log("   %d von %d Bundesligavereinen haben eine Auflage" % [mit_auflage, hbl.size()])
	_pruefe(mit_auflage <= hbl.size() / 3,
		"Die Bundesligahallen erfuellen die Vorgaben ueberwiegend")
	var zweite_liga: Array = d["ligen"]["l_de2"]["vereine"]
	var auflage2 := 0
	for cid2 in zweite_liga:
		if not Lizenzierung.auflagen(d, str(cid2)).is_empty():
			auflage2 += 1
	_log("   %d von %d Zweitligavereinen haben eine Auflage" % [auflage2, zweite_liga.size()])

	_log("— Kapazitaet und Gaestekontingent —")
	for cid3 in hbl:
		var kont := Lizenzierung.gaestekontingent(d, str(cid3))
		_pruefe(kont >= Lizenzierung.GAESTE_MIN and kont <= Lizenzierung.GAESTE_MAX,
			"%s: Gaestekontingent %d" % [str(d["vereine"][cid3]["kurz"]), kont])
		break

	_log("— Beleuchtung nachruesten —")
	var opfer := ""
	for cid4 in Weltgenerator.clubs(d):
		for a in Lizenzierung.auflagen(d, str(cid4)):
			if str((a as Dictionary)["feld"]) == "licht":
				opfer = str(cid4)
				break
		if opfer != "":
			break
	if opfer == "":
		_log("   (kein Verein mit Lichtauflage im Datensatz)")
	else:
		var v: Dictionary = d["vereine"][opfer]
		v["kasse"] = Lizenzierung.lichtkosten(d, opfer) * 2.0
		var erg := Lizenzierung.licht_nachruesten(d, opfer)
		_pruefe(bool(erg["ok"]), "%s ruestet nach: %s" % [str(v["kurz"]), str(erg["grund"])])
		var rest := 0
		for a2 in Lizenzierung.auflagen(d, opfer):
			if str((a2 as Dictionary)["feld"]) == "licht":
				rest += 1
		_pruefe(rest == 0, "Nach der Nachruestung ist die Lichtauflage erledigt")
		var nochmal := Lizenzierung.licht_nachruesten(d, opfer)
		_pruefe(not bool(nochmal["ok"]), "Eine zweite Nachruestung wird abgelehnt")

	_log("— Jugendzertifikat am Saisonende —")
	# Stand herstellen, wie er nach einer gespielten Saison aussieht.
	for cid5 in Weltgenerator.clubs(d):
		# So viele, wie ein Jahrgang wirklich bringt — nicht mehr.
		Jugend.erzeuge_jahrgang(d, str(cid5), 3)
		var b := Zweite.bilanz(d, str(cid5))
		b["spiele"] = 34
	var erfuellt := 0
	for cid6 in hbl:
		if Lizenzierung.zertifikat_erfuellt(d, str(cid6)):
			erfuellt += 1
	_log("   %d von %d Bundesligavereinen erfuellen alle Kriterien" % [erfuellt, hbl.size()])
	_pruefe(erfuellt > 0, "Das Zertifikat ist ueberhaupt erreichbar")
	# Die drei Kriterien muessen greifen, und zwar einzeln. Dass sie im
	# Datensatz eines Jahrgangs ohnehin alle erfuellt sind, sagt darueber
	# nichts — deshalb wird hier jedes einzeln verletzt.
	var proband := str(hbl[hbl.size() - 1])
	var jugendstufe: int = int(d["vereine"][proband]["infrastruktur"]["jugendarbeit"])
	d["vereine"][proband]["infrastruktur"]["jugendarbeit"] = 2
	_pruefe(not Lizenzierung.zertifikat_erfuellt(d, proband),
		"Zu schwache Jugendarbeit verhindert das Zertifikat")
	d["vereine"][proband]["infrastruktur"]["jugendarbeit"] = jugendstufe
	var jugendkader: Array = (d["vereine"][proband]["jugend"] as Array).duplicate()
	d["vereine"][proband]["jugend"] = []
	_pruefe(not Lizenzierung.zertifikat_erfuellt(d, proband),
		"Ein leeres Nachwuchszentrum verhindert das Zertifikat")
	d["vereine"][proband]["jugend"] = jugendkader
	Zweite.bilanz(d, proband)["spiele"] = 0
	_pruefe(not Lizenzierung.zertifikat_erfuellt(d, proband),
		"Eine Zweite ohne Pflichtspiele verhindert das Zertifikat")
	Zweite.bilanz(d, proband)["spiele"] = 34
	_pruefe(Lizenzierung.zertifikat_erfuellt(d, str(hbl[0])),
		"Ein Verein mit erfuellten Auflagen bekommt es")

	_log("— Solidarfonds —")
	# Der Fonds umfasst alle Lizenzligen, nicht nur die Bundesliga — sonst
	# geht die Rechnung nicht auf.
	var kasse_vorher := {}
	for cid7 in Weltgenerator.clubs(d):
		if Lizenzierung.stufe(d, str(cid7)) <= 2:
			kasse_vorher[str(cid7)] = float(d["vereine"][cid7]["kasse"])
	Lizenzierung.jahreslauf(d, "")
	var gezahlt := 0.0
	var erhalten := 0.0
	for cid8 in Weltgenerator.clubs(d):
		if Lizenzierung.stufe(d, str(cid8)) > 2:
			continue
		var diff: float = float(d["vereine"][cid8]["kasse"]) - float(kasse_vorher.get(str(cid8), float(d["vereine"][cid8]["kasse"])))
		if Lizenzierung.hat_zertifikat(d, str(cid8)):
			erhalten += maxf(diff, 0.0)
		else:
			gezahlt += maxf(-diff, 0.0)
	_log("   Strafzahlungen gesamt: %s, Ausschuettung gesamt: %s" % [Stil.geld(gezahlt), Stil.geld(erhalten)])
	_pruefe(gezahlt > 0.0, "Wer das Zertifikat nicht hat, zahlt")
	_pruefe(absf(gezahlt - erhalten) < maxf(gezahlt, 1.0) * 0.02,
		"Was gezahlt wird, kommt auch an (Solidarfonds geht auf)")
	var gespeichert := 0
	for cid9 in hbl:
		if Lizenzierung.hat_zertifikat(d, str(cid9)):
			gespeichert += 1
	_pruefe(gespeichert == erfuellt, "Der gespeicherte Stand entspricht der Pruefung (%d von %d)" % [gespeichert, erfuellt])
	var lizenzligen := 0
	var mit_zert := 0
	for cid12 in Weltgenerator.clubs(d):
		if Lizenzierung.stufe(d, str(cid12)) > 2:
			continue
		lizenzligen += 1
		if Lizenzierung.hat_zertifikat(d, str(cid12)):
			mit_zert += 1
	_log("   %d von %d Vereinen der Lizenzligen haben das Zertifikat" % [mit_zert, lizenzligen])

	_log("— Harz —")
	var mit_verbot := 0
	for cid10 in hbl:
		if Lizenzierung.harzverbot(d, str(cid10)):
			mit_verbot += 1
	var verbot2 := 0
	for cid13 in zweite_liga:
		if Lizenzierung.harzverbot(d, str(cid13)):
			verbot2 += 1
	_log("   Harzverbot: %d von %d in der Bundesliga, %d von %d in der 2. Liga" % [
		mit_verbot, hbl.size(), verbot2, zweite_liga.size()])
	_pruefe(mit_verbot < hbl.size(), "Nicht jede Halle hat ein Harzverbot")
	for cid11 in hbl:
		var f := Lizenzierung.nachwuchsfaktor(d, str(cid11))
		_pruefe(f > 0.5 and f <= 1.0, "Nachwuchsfaktor liegt im Rahmen (%s)" % Stil.komma(f, 2))
		break

	_log("")
	if fehler == 0:
		_log("— Lizenzierung bestanden (%d Pruefungen) —" % geprueft)
	else:
		_log("— Lizenzierung: %d von %d Pruefungen fehlgeschlagen —" % [fehler, geprueft])
	get_tree().quit()
