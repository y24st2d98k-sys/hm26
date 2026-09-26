extends Node
## Integritätsprüfung: simuliert mehrere Saisons und prüft nach jeder Saison
## harte Invarianten der Welt. Was hier anschlägt, ist ein echter Fehler —
## kein Geschmacksurteil über Balance.
##
## Aufruf: godot --headless res://werkzeuge/Pruefung.gd  bzw. .tscn
##         optionales Argument: Anzahl Tage (Vorgabe 1100)

var fehler: int = 0
var geprueft: int = 0

func _log(text: String) -> void:
	print(text)

func _fehler(text: String) -> void:
	fehler += 1
	print("  FEHLER: %s" % text)

func _pruefe(bedingung: bool, text: String) -> void:
	geprueft += 1
	if not bedingung:
		_fehler(text)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var tage: int = int(args[0]) if args.size() > 0 else 1100
	var start := Time.get_ticks_msec()
	Welt.neues_spiel(_erster_verein(), {"vorname": "Prüf", "nachname": "Trainer", "hintergrund": "taktiker"}, 20260)
	var d: Dictionary = Welt.daten
	# Verbandsamt erzwingen: nur so läuft der Turnierstrang durch die Prüfung.
	d["trainer"]["verbandsangebote"] = [{"nation": "de", "name": "Deutschland",
		"staerke": 80.0, "ziel": "halbfinale", "gehalt": 4000.0}]
	Nationaltrainer.annehmen(d, "de")
	_log("— Ausgangswelt (Nationaltrainer: %s) —" % Nationaltrainer.nation(d))
	var soll_ligagroessen := _ligagroessen(d)
	_alles_pruefen(d, soll_ligagroessen)

	var saison := 0
	for i in range(tage):
		var u := Welt.tag_weiter()
		# Die eigene Partie wird sonst nie ausgetragen — dann fehlen dem
		# eigenen Verein alle Einnahmen und die Messung wäre wertlos.
		if str(u.get("art", "")) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		Welt.unterbrechung = {}
		if Welt.saison_index() != saison:
			saison = Welt.saison_index()
			_log("— Nach Saison %d (Tag %d) —" % [saison, int(d["tag"])])
			_alles_pruefen(d, soll_ligagroessen)
	_log("— Abschluss nach %d Tagen —" % tage)
	_alles_pruefen(d, soll_ligagroessen)
	_groessenbericht(d)
	_finanzbericht(d)
	_trainerbericht(d)
	_ehrungsbericht(d)
	_log("")
	_log("%d Prüfungen, %d Fehler. Dauer: %d ms" % [geprueft, fehler, Time.get_ticks_msec() - start])
	get_tree().quit(1 if fehler > 0 else 0)

func _erster_verein() -> String:
	var d := Weltgenerator.erzeuge(2026, 20260)
	return str(d["ligen"]["l_de1"]["vereine"][0])

func _ligagroessen(d: Dictionary) -> Dictionary:
	var g := {}
	for lid in d["ligen"].keys():
		g[lid] = (d["ligen"][lid]["vereine"] as Array).size()
	return g

func _alles_pruefen(d: Dictionary, soll: Dictionary) -> void:
	_ligen(d, soll)
	_kader(d)
	_spieler(d)
	_verweise(d)
	_finanzen(d)
	_spielplan(d)
	_trikotnummern(d)
	_halle_und_fans(d)
	_lizenzierung(d)
	_staerkecache(d)

## Ligen behalten ihre Größe über Auf- und Abstieg hinweg.
func _ligen(d: Dictionary, soll: Dictionary) -> void:
	for lid in soll.keys():
		var ist: int = (d["ligen"][lid]["vereine"] as Array).size()
		_pruefe(ist == int(soll[lid]), "Liga %s hat %d statt %d Vereine" % [lid, ist, int(soll[lid])])
	# Kein Verein in zwei Ligen
	var gesehen := {}
	for lid2 in d["ligen"].keys():
		for cid in d["ligen"][lid2]["vereine"]:
			if gesehen.has(cid):
				_fehler("Verein %s steht in %s und in %s" % [cid, gesehen[cid], lid2])
			gesehen[cid] = lid2
		_pruefe(not (d["ligen"][lid2]["vereine"] as Array).is_empty(), "Liga %s ist leer" % lid2)
	# Jeder Verein kennt seine Liga
	for cid2 in Weltgenerator.clubs(d):
		var lid3: String = str(d["vereine"][cid2]["liga"])
		_pruefe(gesehen.get(cid2, "") == lid3,
			"Verein %s meldet Liga %s, steht aber in %s" % [cid2, lid3, str(gesehen.get(cid2, "—"))])

## Jeder Verein kann eine Mannschaft aufs Feld stellen.
func _kader(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var kader: Array = v["kader"]
		_pruefe(kader.size() >= 12, "%s hat nur %d Spieler im Kader" % [str(v["name"]), kader.size()])
		var torhueter := 0
		var einsatzfaehig := 0
		var doppelt := {}
		for sid in kader:
			if doppelt.has(sid):
				_fehler("%s führt %s doppelt im Kader" % [str(v["name"]), sid])
			doppelt[sid] = true
			var sp: Dictionary = d["spieler"].get(sid, {})
			if sp.is_empty():
				_fehler("%s führt unbekannten Spieler %s" % [str(v["name"]), sid])
				continue
			_pruefe(str(sp["verein"]) == cid,
				"%s steht im Kader von %s, gehört aber zu %s" % [sid, cid, str(sp["verein"])])
			if bool(sp["ist_torwart"]):
				torhueter += 1
			if (sp["verletzung"] as Dictionary).is_empty() and int(sp["sperre"]) <= 0:
				einsatzfaehig += 1
		_pruefe(torhueter >= 1, "%s hat keinen Torwart" % str(v["name"]))
		_pruefe(einsatzfaehig >= 7, "%s hat nur %d einsatzfähige Spieler" % [str(v["name"]), einsatzfaehig])

## Kein Spieler steht in zwei Kadern; Werte bleiben im gültigen Bereich.
func _spieler(d: Dictionary) -> void:
	var zuordnung := {}
	for cid in Weltgenerator.clubs(d):
		for sid in d["vereine"][cid]["kader"]:
			if zuordnung.has(sid):
				_fehler("Spieler %s steht in %s und in %s" % [sid, zuordnung[sid], cid])
			zuordnung[sid] = cid
		for jid in d["vereine"][cid].get("jugend", []):
			if zuordnung.has(jid):
				_fehler("Jugendspieler %s steht auch in %s" % [jid, zuordnung[jid]])
			zuordnung[jid] = cid
	var schlecht := 0
	for sid2 in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid2]
		var verein: String = str(sp["verein"])
		if verein != "" and not zuordnung.has(sid2) and not bool(sp.get("jugendspieler", false)):
			_fehler("Spieler %s nennt Verein %s, steht dort aber nicht im Kader" % [sid2, verein])
		for feld in ["form", "moral", "fitness", "last"]:
			var w: float = float(sp[feld])
			if is_nan(w) or w < 0.0 or w > 100.0:
				schlecht += 1
				if schlecht <= 3:
					_fehler("Spieler %s hat %s = %s" % [sid2, feld, str(w)])
		for a in (sp["attr"] as Dictionary).keys():
			var av: float = float(sp["attr"][a])
			if is_nan(av) or av < 1.0 or av > 20.0:
				schlecht += 1
				if schlecht <= 6:
					_fehler("Spieler %s hat Attribut %s = %s" % [sid2, a, str(av)])
		if float(sp["wert"]) < 0.0 or is_nan(float(sp["wert"])):
			_fehler("Spieler %s hat Marktwert %s" % [sid2, str(sp["wert"])])
		_pruefe(int(sp["alter"]) >= 15 and int(sp["alter"]) <= 45,
			"Spieler %s ist %d Jahre alt" % [sid2, int(sp["alter"])])
	if schlecht > 6:
		_log("  (%d Wertverletzungen insgesamt)" % schlecht)

## Aufstellungen, Angebote und Aufträge zeigen nur auf Dinge, die es gibt.
func _verweise(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var auf: Dictionary = v.get("aufstellung", {})
		for block in ["angriff", "abwehr"]:
			for pos in (auf.get(block, {}) as Dictionary).keys():
				var sid: String = str(auf[block][pos])
				if sid == "":
					continue
				if not (v["kader"] as Array).has(sid):
					_fehler("%s stellt %s auf, der nicht im Kader ist" % [str(v["name"]), sid])
	for angebot in d.get("transfermarkt", {}).get("angebote", []):
		var asid: String = str(angebot.get("spieler", ""))
		_pruefe(d["spieler"].has(asid), "Transferangebot für unbekannten Spieler %s" % asid)
	for auftrag in d.get("scouting", {}).get("auftraege", []):
		var ziel: String = str(auftrag.get("ziel", ""))
		if str(auftrag.get("art", "")) == "spieler" and ziel != "":
			_pruefe(d["spieler"].has(ziel), "Scoutauftrag für unbekannten Spieler %s" % ziel)
	for eintrag in d.get("anliegen", []):
		_pruefe(d["spieler"].has(str(eintrag.get("spieler", ""))),
			"Anliegen eines unbekannten Spielers")
	# Zielminuten und Anweisungen haengen am Spieler: wer den Verein verlaesst,
	# darf keine Karteileiche hinterlassen.
	for cid_z in Weltgenerator.clubs(d):
		var v_z: Dictionary = d["vereine"][cid_z]
		var auf_z: Dictionary = v_z.get("aufstellung", {})
		for sid_z in (auf_z.get("minuten", {}) as Dictionary).keys():
			if not (v_z["kader"] as Array).has(str(sid_z)):
				_fehler("%s hat ein Minutenziel für %s, der nicht im Kader ist" % [str(v_z["name"]), sid_z])
		for sid_a in (auf_z.get("anweisungen", {}) as Dictionary).keys():
			if not d["spieler"].has(str(sid_a)):
				_fehler("%s hat eine Anweisung für den unbekannten Spieler %s" % [str(v_z["name"]), sid_a])
	# Gesichtete Talente: jeder Kandidat gehoert in die Liste, und jeder
	# Listeneintrag zeigt auf einen Spieler, den es noch gibt.
	var in_liste := {}
	for e_t in d.get("scouting", {}).get("talente", []):
		var tsid: String = str((e_t as Dictionary).get("spieler", ""))
		in_liste[tsid] = true
		if not d["spieler"].has(tsid):
			_fehler("Sichtungsliste nennt den unbekannten Spieler %s" % tsid)
		elif str(d["spieler"][tsid]["verein"]) != "":
			_fehler("Gesichtetes Talent %s steht schon bei einem Verein" % tsid)
	for sid_k in d["spieler"].keys():
		if bool(d["spieler"][sid_k].get("nachwuchskandidat", false)) and not in_liste.has(str(sid_k)):
			_fehler("Nachwuchskandidat %s steht in keiner Sichtungsliste" % sid_k)

## Der gemerkte Gesamtwert stimmt mit der frischen Rechnung überein.
##
## Ohne diese Prüfung wäre der Zwischenspeicher ein Risiko: eine vergessene
## Verwerfung fiele erst auf, wenn ein Spieler jahrelang mit veralteter Stärke
## aufliefe. So fällt sie beim nächsten Prüflauf auf.
func _staerkecache(d: Dictionary) -> void:
	var abweichungen := 0
	var schlimmste := 0.0
	var beispiel := ""
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		var gemerkt: float = float(sp.get("staerke", -1.0))
		if gemerkt < 0.0:
			continue
		var frisch: float = Spielerfabrik.gesamt_rechnen(sp)
		var delta: float = absf(frisch - gemerkt)
		if delta > 0.01:
			abweichungen += 1
			if delta > schlimmste:
				schlimmste = delta
				beispiel = str(sid)
	if abweichungen > 0:
		_fehler("%d Spieler tragen eine veraltete Stärke (schlimmster Fall %s: %.2f Punkte)" % [
			abweichungen, beispiel, schlimmste])

## Eintrittspreise, Dauerkarten, Fanszene und Kredite bleiben im Rahmen.
func _halle_und_fans(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var sitze := Ticketing.plaetze(d, cid)
		var summe := 0
		for k in Ticketing.KATEGORIEN:
			var kat: String = str(k)
			summe += int(sitze[kat])
			var preis: float = Ticketing.preis(d, cid, kat)
			if preis <= 0.0 or is_nan(preis) or preis > Ticketing.referenzpreis(d, cid, kat) * 2.6:
				_fehler("%s hat einen unmöglichen Preis für %s (%s)" % [str(v["name"]), kat, str(preis)])
			var dk: int = Ticketing.dauerkarten(d, cid, kat)
			if dk < 0 or dk > int(sitze[kat]):
				_fehler("%s hat %d Dauerkarten für %d Plätze in %s" % [str(v["name"]), dk, int(sitze[kat]), kat])
		if summe != int(v["halle"]["kapazitaet"]):
			_fehler("%s: Kategorien ergeben %d statt %d Plätze" % [str(v["name"]), summe, int(v["halle"]["kapazitaet"])])
		var s_szene := Fanszene.szene(d, cid)
		for g in Fanszene.GRUPPEN:
			var wert: float = float((s_szene.get(g, {}) as Dictionary).get("stimmung", -1.0))
			if wert < 0.0 or wert > 100.0 or is_nan(wert):
				_fehler("%s: Fangruppe %s steht bei %s" % [str(v["name"]), g, str(wert)])
		for k2 in Darlehen.liste(d, cid):
			var kredit: Dictionary = k2
			if float(kredit["rest"]) < 0.0 or is_nan(float(kredit["rest"])):
				_fehler("%s hat ein Darlehen mit Restschuld %s" % [str(v["name"]), str(kredit["rest"])])
			if float(kredit["rate"]) <= 0.0:
				_fehler("%s hat ein Darlehen ohne Rate" % str(v["name"]))
		if Darlehen.restschuld(d, cid) > float(v["jahresetat"]) * 1.6:
			_fehler("%s ist mit %s überschuldet" % [str(v["name"]), Stil.geld(Darlehen.restschuld(d, cid))])
		if not Spieltagsprogramm.PROGRAMME.has(Spieltagsprogramm.gewaehlt(d, cid)):
			_fehler("%s hat ein unbekanntes Spieltagsprogramm" % str(v["name"]))

## Halle, Beleuchtung und Jugendzertifikat.
func _lizenzierung(d: Dictionary) -> void:
	var mit_auflage := 0
	var zertifiziert := 0
	var erstliga := 0
	for cid in Weltgenerator.clubs(d):
		var c := str(cid)
		var h := Lizenzierung.halle(d, c)
		_pruefe(int(h["licht_feld"]) > 0, "%s: Spielfeldbeleuchtung fehlt" % str(d["vereine"][c]["name"]))
		_pruefe(int(h["licht_rang"]) > 0, "%s: Beleuchtung der Ränge fehlt" % str(d["vereine"][c]["name"]))
		_pruefe(float(h["gleichmaessigkeit"]) > 0.0 and float(h["gleichmaessigkeit"]) <= 1.0,
			"%s: unmögliche Gleichmäßigkeit %s" % [str(d["vereine"][c]["name"]), str(h["gleichmaessigkeit"])])
		var kont := Lizenzierung.gaestekontingent(d, c)
		_pruefe(kont >= Lizenzierung.GAESTE_MIN and kont <= Lizenzierung.GAESTE_MAX,
			"%s: Gästekontingent %d liegt außerhalb der Vorgabe" % [str(d["vereine"][c]["name"]), kont])
		if Lizenzierung.stufe(d, c) != 1:
			continue
		erstliga += 1
		if not Lizenzierung.auflagen(d, c).is_empty():
			mit_auflage += 1
		if Lizenzierung.hat_zertifikat(d, c):
			zertifiziert += 1
	if erstliga > 0:
		_log("  Lizenz: %d von %d Erstligavereinen mit Auflage, %d mit Jugendzertifikat" % [
			mit_auflage, erstliga, zertifiziert])

## Kein Verein rutscht dauerhaft ins Bodenlose.
func _finanzen(d: Dictionary) -> void:
	var pleite: Array = []
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		var kasse: float = float(v["kasse"])
		if is_nan(kasse):
			_fehler("%s hat eine ungültige Kasse" % str(v["name"]))
		elif kasse < -2000000.0:
			pleite.append("%s (%s)" % [str(v["name"]), Stil.geld(kasse)])
			_pleite_erklaeren(d, str(cid))
	if not pleite.is_empty():
		_fehler("%d Vereine tief im Minus: %s" % [pleite.size(), ", ".join(pleite.slice(0, 5))])

## Woher das Minus kommt: ohne diese Zeilen sagt der Fehler nur, dass etwas
## schiefging, nicht was — und ein Lauf dauert eine Viertelstunde.
func _pleite_erklaeren(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var gehaelter: float = (Finanzen.spielergehaelter(d, cid) + Finanzen.personalgehaelter(d, cid)) * 52.0
	_log("    %s: Ruf %.0f, Liga %s, Etat %s, Gehälter %s/Jahr (Budget %s/Jahr), Kader %d, Restschuld %s" % [
		str(v["name"]), float(v["ruf"]), str(d["ligen"].get(str(v["liga"]), {}).get("name", "?")),
		Stil.geld(float(v["jahresetat"])), Stil.geld(gehaelter), Stil.geld(float(v["gehaltsbudget"]) * 52.0),
		(v["kader"] as Array).size(), Stil.geld(Darlehen.restschuld(d, cid))])
	var posten: Array = []
	var fin: Dictionary = (v.get("saison", {}) as Dictionary).get("finanzen", {})
	for k in fin.keys():
		posten.append("%s %s" % [str(k), Stil.geld(float(fin[k]))])
	_log("      laufende Saison: %s" % ", ".join(posten))
	for e in (v.get("chronik", {}).get("saisons", []) as Array).slice(-2):
		_log("      Vorsaison: %s" % str(e).substr(0, 220))

## Jede Liga spielt eine vollständige Doppelrunde.
func _spielplan(d: Dictionary) -> void:
	var pro_verein := {}
	var saison_start: int = Kalender.saison_index(int(d["tag"])) * Kalender.TAGE_IM_JAHR
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) != "liga" or int(m["tag"]) < saison_start:
			continue
		for seite in ["heim", "gast"]:
			var cid: String = str(m[seite])
			pro_verein[cid] = int(pro_verein.get(cid, 0)) + 1
	for lid in d["ligen"].keys():
		var vereine: Array = d["ligen"][lid]["vereine"]
		var soll: int = (vereine.size() - 1) * 2
		for cid2 in vereine:
			var ist: int = int(pro_verein.get(cid2, 0))
			if ist != soll:
				_fehler("%s hat %d Ligaspiele statt %d" % [str(d["vereine"][cid2]["name"]), ist, soll])
				return

## Rückennummern sind je Kader eindeutig.
func _trikotnummern(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var gesehen := {}
		for sid in d["vereine"][cid]["kader"]:
			var n: int = int(d["spieler"][sid].get("nummer", 0))
			if n <= 0:
				_fehler("%s trägt keine Rückennummer" % sid)
			elif gesehen.has(n):
				_fehler("Nummer %d bei %s doppelt vergeben" % [n, str(d["vereine"][cid]["name"])])
			gesehen[n] = true

## Wurden Auszeichnungen tatsächlich vergeben — und an plausible Spieler?
func _ehrungsbericht(d: Dictionary) -> void:
	_log("")
	_log("Auszeichnungen:")
	var monate: Array = Auszeichnungen.monatsliste(d)
	var ohne := 0
	for e in monate:
		if str(e["spieler"]) == "":
			ohne += 1
	_log("  Monatsehrungen: %d, davon ohne Spieler: %d" % [monate.size(), ohne])
	for e2 in monate.slice(0, 3):
		var sid: String = str(e2["spieler"])
		_log("    %s %s: %s (Note %s) · Mannschaft: %s" % [str(e2["monat"]),
			str(d["ligen"][e2["liga"]]["name"]),
			Spielerfabrik.voller_name(d["spieler"][sid]) if d["spieler"].has(sid) else "—",
			Stil.komma(Spielerfabrik.note(d["spieler"][sid]), 2) if d["spieler"].has(sid) else "—",
			str(d["vereine"].get(str(e2["verein"]), {}).get("kurz", "—"))])
	var saisons: Array = Auszeichnungen.saisonliste(d)
	_log("  Saisonehrungen: %d" % saisons.size())
	for e3 in saisons.slice(0, 3):
		var teile: Array = []
		for schluessel in ["neuzugang", "talent"]:
			var s2: String = str(e3[schluessel])
			teile.append("%s: %s" % [schluessel,
				Spielerfabrik.voller_name(d["spieler"][s2]) if d["spieler"].has(s2) else "—"])
		teile.append("Trainer: %s" % str(d["vereine"].get(str(e3["trainerverein"]), {}).get("kurz", "—")))
		_log("    %s %s — %s" % [Kalender.saison_text(int(d["startjahr"]), int(e3["saison"])),
			str(d["ligen"][e3["liga"]]["name"]), ", ".join(teile)])
	var mit_ehrung := 0
	for sid2 in d["spieler"].keys():
		for eintrag in Laufbahn.liste(d["spieler"][sid2]):
			if str(eintrag.get("art", "")) == "allstar":
				mit_ehrung += 1
				break
	_log("  Spieler mit mindestens einer Ehrung in der Laufbahn: %d" % mit_ehrung)

## Wie es dem Trainer ergangen ist. Viele Stationen bei ordentlicher Siegquote
## heisst: der Vorstand feuert schneller, als jemand arbeiten kann.
func _trainerbericht(d: Dictionary) -> void:
	var t: Dictionary = d.get("trainer", {})
	if t.is_empty():
		return
	var s: Dictionary = t["statistik"]
	var spiele: int = int(s["spiele"])
	_log("")
	_log("Trainerkarriere:")
	_log("  %s, Ruf %.1f (%s)" % [Trainerkarriere.voller_name(t), float(t["ruf"]),
		Trainerkarriere.ruf_stufe(float(t["ruf"]))])
	_log("  %d Spiele, %d Siege (%.0f %%), %d Titel" % [spiele, int(s["siege"]),
		float(s["siege"]) / maxf(float(spiele), 1.0) * 100.0, (t["titel"] as Array).size()])
	_log("  Stationen: %d, derzeit: %s" % [(t["stationen"] as Array).size(),
		str(d["vereine"].get(str(t["verein"]), {}).get("name", "vereinslos"))])
	var b: Dictionary = t.get("national_bilanz", {})
	_log("  Verbandsamt: %s, Turnierspiele: %d, Siege: %d" % [
		Nationaltrainer.nation(d) if Nationaltrainer.ist_nationaltrainer(d) else "keins",
		int(b.get("spiele", 0)), int(b.get("siege", 0))])

## Einnahmen und Ausgaben je Saison, hochgerechnet aus der Wochenübersicht.
## Zeigt, ob das Wirtschaftsmodell überhaupt aufgehen kann.
func _finanzbericht(d: Dictionary) -> void:
	_log("")
	_log("Wirtschaft — tatsächlich gebuchte Saisonsummen:")
	var beispiele: Array = []
	for lid in ["l_de1", "l_de2", "l_pl1"]:
		if not d["ligen"].has(lid):
			continue
		var vereine: Array = (d["ligen"][lid]["vereine"] as Array).duplicate()
		vereine.sort_custom(func(a, b): return float(d["vereine"][a]["ruf"]) > float(d["vereine"][b]["ruf"]))
		beispiele.append(str(vereine[0]))
		beispiele.append(str(vereine[-1]))
	for cid in beispiele:
		var v: Dictionary = d["vereine"][cid]
		var jahr: Dictionary = (v["saison"] as Dictionary).get("finanzen", {})
		var ein := 0.0
		var aus := 0.0
		var teile: Array = []
		var schluessel: Array = jahr.keys()
		schluessel.sort()
		for k in schluessel:
			var betrag: float = float(jahr[k])
			if betrag >= 0.0:
				ein += betrag
			else:
				aus -= betrag
			teile.append("%s %s" % [str(k), Stil.geld(betrag)])
		_log("  %-30s Ruf %2d  Etat %s" % [str(v["name"]).substr(0, 30), int(float(v["ruf"])), Stil.geld(float(v["jahresetat"]))])
		_log("     %s" % ", ".join(teile))
		_log("     %d Spiele (%d daheim) · Ein %s  Aus %s  Saldo %s  Kasse %s" % [
			int(v["saison"]["spiele"]), int(v["saison"]["heimspiele"]),
			Stil.geld(ein), Stil.geld(aus), Stil.geld(ein - aus), Stil.geld(float(v["kasse"]))])
	var summe := 0.0
	var minus := 0
	for cid2 in Weltgenerator.clubs(d):
		summe += float(d["vereine"][cid2]["kasse"])
		if float(d["vereine"][cid2]["kasse"]) < 0.0:
			minus += 1
	_log("  Vereine mit negativer Kasse: %d von %d, Summe aller Kassen %s" % [
		minus, Weltgenerator.clubs(d).size(), Stil.geld(summe)])

## Was im Spielstand über die Zeit wächst — Frühwarnung für Speicherwucher.
func _groessenbericht(d: Dictionary) -> void:
	_log("")
	_log("Größen im Spielstand:")
	_log("  Spieler gesamt: %d" % (d["spieler"] as Dictionary).size())
	_log("  Spiele gesamt: %d" % (d["spiele"] as Dictionary).size())
	_log("  Nachrichten: %d, Presse: %d, Hallenfunk: %d" % [
		(d["nachrichten"] as Array).size(), (d["presse"] as Array).size(), (d["social"] as Array).size()])
	_log("  Transferverlauf: %d" % (d["transfermarkt"]["verlauf"] as Array).size())
	_log("  Chronikereignisse: %d" % (d["chronik"]["ereignisse"] as Array).size())
	var log_max := 0
	var laufbahn_max := 0
	var log_summe := 0
	for sid in d["spieler"].keys():
		var n: int = (d["spieler"][sid].get("entwicklung_log", []) as Array).size()
		log_summe += n
		log_max = maxi(log_max, n)
		laufbahn_max = maxi(laufbahn_max, (d["spieler"][sid].get("laufbahn", []) as Array).size())
	_log("  Entwicklungslog: %d Einträge gesamt, längster %d" % [log_summe, log_max])
	_log("  Längste Laufbahn: %d Stationen" % laufbahn_max)
	# Woraus besteht der Spielstand eigentlich?
	var teile := {"spieler": d["spieler"], "vereine": d["vereine"], "spiele": d["spiele"],
		"ligen": d["ligen"], "personal": d["personal"], "presse": d["presse"],
		"nachrichten": d["nachrichten"], "social": d["social"]}
	var namen: Array = teile.keys()
	namen.sort_custom(func(a, b): return var_to_bytes(teile[a]).size() > var_to_bytes(teile[b]).size())
	for k in namen:
		_log("  Anteil %-12s %.1f MB" % [str(k), float(var_to_bytes(teile[k]).size()) / 1048576.0])
	if Welt.speichern(9, "Prüfung"):
		var groesse: int = FileAccess.get_file_as_bytes(Welt.slot_pfad(9)).size()
		_log("  Spielstand auf der Platte: %.1f MB" % (float(groesse) / 1048576.0))
		Welt.slot_loeschen(9)
