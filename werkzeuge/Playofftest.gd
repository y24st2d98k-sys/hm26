extends Node
## Prüft die Meisterschaft über Play-offs: eine ganze Saison in der Welt der
## fünf Kernnationen (Dänemark, Frankreich und Polen spielen Play-offs), dann
## je Liga, ob die Hauptrunde vor den Play-offs fertig war, ob alle Runden
## gespielt wurden und ob der Play-off-Sieger als Meister eingetragen ist.
##   godot4 --headless res://werkzeuge/Playofftest.tscn

func _ready() -> void:
	Echtdaten.nur_kernnationen = true
	Welt.neues_spiel("c_001", {"vorname": "Test", "nachname": "Trainer", "hintergrund": "taktiker"}, 5150)
	var d := Welt.daten
	var fehler := 0
	var tage := 0
	# Bis kurz nach dem Saisonabschluss, aber vor dem Saisonwechsel.
	while tage < Spielplan.SAISON_ABSCHLUSS + 3:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		tage += 1
	print("Datum: %s" % Welt.datum_text())
	for lid in d["ligen"].keys():
		var liga: Dictionary = d["ligen"][lid]
		if not Playoffs.hat_playoffs(liga):
			continue
		var po: Dictionary = liga.get("playoff", {})
		var letzter_liga := 0
		var erster_po := 99999
		var po_spiele := 0
		var offen := 0
		for mid in d["spiele"].keys():
			var m: Dictionary = d["spiele"][mid]
			if str(m["wettbewerb"]) != str(lid):
				continue
			if str(m["art"]) == "liga":
				letzter_liga = maxi(letzter_liga, int(m["tag"]))
			elif str(m["art"]) == "playoff":
				po_spiele += 1
				erster_po = mini(erster_po, int(m["tag"]))
				if not bool(m["gespielt"]):
					offen += 1
		var historie: Array = liga.get("meister_historie", [])
		var eingetragen: String = str(historie[0]["verein"]) if not historie.is_empty() else ""
		var sieger: String = str(po.get("sieger", ""))
		print("%-28s Phase %-9s Spiele %2d (offen %d)  Hauptrunde bis Tag %d, Play-offs ab Tag %d" % [
			str(liga["name"]), str(po.get("phase", "?")), po_spiele, offen, letzter_liga, erster_po])
		print("   Hauptrundenerster %s, Play-off-Sieger %s, eingetragener Meister %s" % [
			str(d["vereine"][Spielplan.tabelle_sortiert(d, str(lid))[0]]["name"]),
			str(d["vereine"].get(sieger, {}).get("name", "—")),
			str(d["vereine"].get(eingetragen, {}).get("name", "—"))])
		if str(po.get("phase", "")) != "beendet":
			printerr("FEHLER: Play-offs in %s nicht beendet" % liga["name"]); fehler += 1
		if offen > 0:
			printerr("FEHLER: %d Play-off-Partien in %s nicht gespielt" % [offen, liga["name"]]); fehler += 1
		if letzter_liga >= erster_po:
			printerr("FEHLER: Hauptrunde in %s überschneidet sich mit den Play-offs" % liga["name"]); fehler += 1
		if sieger == "" or sieger != eingetragen:
			printerr("FEHLER: Meister in %s ist nicht der Play-off-Sieger" % liga["name"]); fehler += 1
		var erwartet: int = int(liga["playoffs"]) - 1
		if po_spiele != erwartet * 2:
			printerr("FEHLER: %d Play-off-Partien in %s, erwartet %d" % [po_spiele, liga["name"], erwartet * 2]); fehler += 1
	# Die Champions League im Format ab 2026/27: sechs Vierergruppen, Final4.
	var krone: Dictionary = d["international"]["i_krone"]
	var gruppen: int = (krone.get("gruppen", []) as Array).size()
	var halbfinale_einzeln := 0
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["wettbewerb"]) == "i_krone" and bool(m["ko"]) and str(m["hinspiel"]) == "" and int(m["runde"]) >= 2:
			halbfinale_einzeln += 1
	print("%s: %d Teilnehmer, %d Gruppen, Phase %s, Sieger %s, Einzelspiele im K.-o. ab Runde 2: %d" % [
		str(krone["name"]), (krone["teilnehmer"] as Array).size(), gruppen, str(krone["phase"]),
		str(d["vereine"].get(str(krone.get("sieger", "")), {}).get("name", "—")), halbfinale_einzeln])
	if (krone["teilnehmer"] as Array).size() != 24 or gruppen != 6:
		printerr("FEHLER: Champions League nicht im Format 24/6"); fehler += 1
	if str(krone["phase"]) != "beendet" or str(krone.get("sieger", "")) == "":
		printerr("FEHLER: Champions League nicht zu Ende gespielt"); fehler += 1
	# Ab dem Halbfinale (Runde 2) gibt es nur Einzelspiele: zwei Halbfinals
	# und das Finale. Die Hinspiele des Viertelfinals zählen nicht mit, sie
	# gehören zu Runde 1.
	if halbfinale_einzeln != 3:
		printerr("FEHLER: Final4 erwartet drei Einzelspiele, gefunden %d" % halbfinale_einzeln); fehler += 1
	print("— Play-offs %s —" % ("bestanden" if fehler == 0 else "mit %d Fehlern" % fehler))
	get_tree().quit(1 if fehler > 0 else 0)
