extends Node
## Prueft alle Bildschirme, Fenster und die Live-Ansicht auf Laufzeitfehler.

func _log(text: String) -> void:
	printerr(text)

func _ready() -> void:
	_log("— Neues Spiel anlegen —")
	var vorschau := Weltgenerator.erzeuge(2026, 777)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][3])
	Welt.neues_spiel(cid, {"vorname": "Mira", "nachname": "Halden", "hintergrund": "nachwuchs", "nation": "de", "alter": 41}, 777)
	_log("Verein: %s" % Welt.mein_verein()["name"])

	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)
	await get_tree().process_frame

	_log("— Alle Bildschirme aufrufen —")
	for id in app.bildschirme.keys():
		app.zeige(id)
		await get_tree().process_frame
		_log("   %s ok" % id)

	_log("— Fenster testen —")
	var sid: String = str(Welt.mein_verein()["kader"][0])
	var fenster: Node = get_tree().get_first_node_in_group("spielerfenster")
	for reiter in ["uebersicht", "attribute", "statistik", "vertrag", "entwicklung"]:
		fenster.zeige(sid)
		fenster.reiter = reiter
		fenster._zeichne()
		await get_tree().process_frame
	fenster.schliessen()
	get_tree().get_first_node_in_group("vereinsfenster").zeige(cid)
	await get_tree().process_frame
	_log("   Spieler- und Vereinsfenster ok")

	_log("— Tage bis zum ersten eigenen Spiel —")
	var schritte := 0
	while schritte < 90:
		var u := Welt.tag_weiter()
		schritte += 1
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			_log("   Spieltag erreicht nach %d Tagen: %s" % [schritte, Welt.datum_text()])
			break
	var naechstes := Welt.naechstes_spiel(Welt.mein_verein_id)
	if naechstes.is_empty():
		_log("   FEHLER: kein Spiel gefunden")
		get_tree().quit()
		return

	_log("— Live-Ansicht —")
	var live: Node = app.live
	live.visible = true
	live.starte(str(naechstes["id"]))
	await get_tree().process_frame
	for i in range(40):
		live._schritt()
	_log("— Kabinenansprachen —")
	for ton in Matchsim.ANSPRACHEN.keys():
		var erg: Dictionary = live.sim.ansprache_halten(live.sim.heim, str(ton))
		_log("   %s: %s" % [str(ton), str(erg.get("text", erg))])
	live._ansprache_aufbauen(false)
	await get_tree().process_frame
	live._ueberspringen()
	await get_tree().process_frame
	_log("   Endstand: %d:%d" % [int(live.sim.heim["tore"]), int(live.sim.gast["tore"])])
	live._abschliessen()
	await get_tree().process_frame

	_log("— Spielbericht —")
	get_tree().get_first_node_in_group("spielbericht").zeige(str(naechstes["id"]))
	await get_tree().process_frame

	_log("— Weitere 60 Tage —")
	for i in range(25):
		var u2 := Welt.tag_weiter()
		if u2.has("art") and str(u2["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u2["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
	for id2 in app.bildschirme.keys():
		app.zeige(id2)
		await get_tree().process_frame

	_log("— Kaderdaten pflegen —")
	var db: Node = app.bildschirme["daten"]
	app.zeige("daten")
	db.gewaehlt = "THW Kiel"
	db.entwurf = []
	db.aktualisieren()
	await get_tree().process_frame
	var eingelesen := Kaderpflege.csv_einlesen(
		"Vorname;Nachname;Position;Nation;Alter;Staerke\n" +
		"Test;Eins;RM;de;24;80\nTest;Zwei;XX;zz;99;500\nkaputt\n")
	_log("   CSV: %d übernommen, %d Hinweise" % [(eingelesen["eintraege"] as Array).size(),
		(eingelesen["meldungen"] as Array).size()])
	Kaderpflege.setzen("THW Kiel", eingelesen["eintraege"])
	_log("   THW Kiel jetzt %d Spieler, eigen: %s" % [Kaderpflege.kader("THW Kiel").size(),
		str(Kaderpflege.ist_eigen("THW Kiel"))])
	db.entwurf = []
	db.aktualisieren()
	await get_tree().process_frame
	Kaderpflege.alles_verwerfen()
	_log("   nach Verwerfen: %d Spieler" % Kaderpflege.kader("THW Kiel").size())

	_log("— Einzelgespräch —")
	var gsid: String = str(Welt.mein_verein()["kader"][1])
	_log("   angebotene Themen: %s" % str(Gespraech.themen(Welt.daten, gsid)))
	# Zum Pruefen alle Themen durchspielen, nicht nur die gerade angebotenen.
	for t in Gespraech.THEMEN.keys():
		for a in Gespraech.ANTWORTEN[t]:
			var erg := Gespraech.fuehren(Welt.daten, gsid, str(t), str((a as Dictionary)["id"]))
			_log("   %s/%s: %s" % [str(t), str((a as Dictionary)["id"]), str(erg["text"])])
			Welt.spieler(gsid)["letztes_gespraech_tag"] = -999
	fenster.zeige(gsid)
	fenster.reiter = "statistik"
	fenster._zeichne()
	await get_tree().process_frame
	fenster.schliessen()
	_log("   Versprechen offen: %d" % Gespraech.offene(Welt.daten, gsid).size())

	_log("— Spielvorbereitung —")
	var naechstes2 := Welt.naechstes_spiel(Welt.mein_verein_id)
	if not naechstes2.is_empty():
		var gegner2: String = str(naechstes2["gast"]) if str(naechstes2["heim"]) == Welt.mein_verein_id else str(naechstes2["heim"])
		var vf: Node = get_tree().get_first_node_in_group("vorberichtsfenster")
		vf.zeige(gegner2, str(naechstes2["id"]))
		await get_tree().process_frame
		_log("   Vorbericht Stufe %d ok" % int(Vorbericht.stufe(Welt.daten, Welt.mein_verein_id, gegner2)))
		vf.visible = false

	_log("— Statistikzentrum: alle Wertungen —")
	app.zeige("statistik")
	var stat: Node = app.bildschirme["statistik"]
	for kat in Statistik.KATEGORIEN.keys():
		stat.kategorie = str(kat)
		stat._zeichne()
		await get_tree().process_frame
	_log("   %d Wertungen gezeichnet" % Statistik.KATEGORIEN.size())

	_log("— Anliegen eines Spielers —")
	# Ein Anliegen erzwingen: einen Spieler unzufrieden machen und pruefen lassen
	var asid: String = str(Welt.mein_verein()["kader"][4])
	Welt.spieler(asid)["unzufriedenheit"] = 60.0
	Anliegen.wochenpruefung(Welt.daten)
	var offen := Anliegen.offene(Welt.daten)
	_log("   offene Anliegen: %d" % offen.size())
	if not offen.is_empty():
		var eintrag: Dictionary = offen[0]
		var af: Node = get_tree().get_first_node_in_group("anliegenfenster")
		af.zeige(str(eintrag["spieler"]))
		await get_tree().process_frame
		var moeglich: Array = Anliegen.ANTWORTEN[str(eintrag["art"])]
		var erg := Anliegen.antworten(Welt.daten, str(eintrag["spieler"]),
			str((moeglich[0] as Dictionary)["id"]))
		_log("   Antwort (%s): %s" % [str(eintrag["art"]), str(erg["text"])])
		af._ergebnis(erg, Welt.spieler(str(eintrag["spieler"])))
		await get_tree().process_frame
		af.visible = false
	_log("   nach Antwort offen: %d" % Anliegen.anzahl(Welt.daten))

	_log("— Vertragsverhandlung —")
	var vsid: String = str(Welt.mein_verein()["kader"][3])
	var start := Verhandlung.starten(Welt.daten, vsid, "verlaengerung")
	_log("   gestartet: %s" % str(start["ok"]))
	var vfenster: Node = get_tree().get_first_node_in_group("verhandlungsfenster")
	vfenster.zeige()
	await get_tree().process_frame
	# Erst ein zu niedriges Angebot, dann die Forderung übernehmen
	var forderung: Dictionary = (Verhandlung.aktuelle(Welt.daten)["forderung"] as Dictionary).duplicate()
	var mager := forderung.duplicate()
	mager["gehalt"] = float(forderung["gehalt"]) * 0.55
	var r1 := Verhandlung.anbieten(Welt.daten, mager)
	_log("   mageres Angebot: %s — %s" % [str(r1["status"]), str(r1["text"])])
	var r2 := Verhandlung.anbieten(Welt.daten, forderung)
	_log("   volle Forderung: %s" % str(r2["status"]))
	if str(r2["status"]) == "angenommen":
		var ab := Verhandlung.abschliessen(Welt.daten)
		_log("   Abschluss: %s" % str(ab["grund"]))
	vfenster._zeichne()
	await get_tree().process_frame
	vfenster.visible = false
	Verhandlung.abbrechen(Welt.daten)

	_log("— Spieleranweisungen —")
	var cid_a: String = Welt.mein_verein_id
	Anweisungen.automatisch(Welt.daten, cid_a)
	_log("   Rollen vergeben: %d" % Anweisungen.gesetzt(Welt.daten, cid_a))
	var erster: String = str(Welt.verein(cid_a)["kader"][0])
	Anweisungen.setzen(Welt.daten, cid_a, erster, "angriff", "abschluss")
	Anweisungen.setzen(Welt.daten, cid_a, erster, "abwehr", "offensiv")
	var gesetzt_a: Dictionary = Anweisungen.fuer(Welt.daten, cid_a, erster)
	_log("   %s: %s / %s" % [Spielerfabrik.kurz_name(Welt.spieler(erster)),
		str(Anweisungen.ANGRIFF[str(gesetzt_a["angriff"])]["name"]),
		str(Anweisungen.ABWEHR[str(gesetzt_a["abwehr"])]["name"])])
	app.zeige("taktik")
	await get_tree().process_frame

	_log("— Rückennummern —")
	Trikot.kader_nummerieren(Welt.daten, cid_a)
	var nummern := {}
	var ohne := 0
	for sid_t in Welt.verein(cid_a)["kader"]:
		var n_t: int = int(Welt.spieler(sid_t).get("nummer", 0))
		if n_t <= 0:
			ohne += 1
		elif nummern.has(n_t):
			_log("   FEHLER: Nummer %d doppelt vergeben" % n_t)
		nummern[n_t] = true
	_log("   %d Nummern, ohne Nummer: %d" % [nummern.size(), ohne])
	var tausch := Trikot.setzen(Welt.daten, cid_a, erster, int(Welt.spieler(str(Welt.verein(cid_a)["kader"][1])).get("nummer", 7)))
	_log("   Doppelvergabe abgelehnt: %s (%s)" % [str(not bool(tausch["ok"])), str(tausch["grund"])])

	_log("— Patenschaft —")
	var mentoren: Array = Mentoring.kandidaten_mentor(Welt.daten, cid_a)
	var schueler: Array = Mentoring.kandidaten_schueler(Welt.daten, cid_a)
	if mentoren.is_empty() or schueler.is_empty():
		_log("   keine passenden Kandidaten im Kader")
	else:
		var erg_m := Mentoring.anlegen(Welt.daten, cid_a, str(mentoren[0]), str(schueler[0]))
		_log("   %s" % str(erg_m["grund"]))
		# Die Patenschaft künstlich altern lassen, ohne die Weltuhr zu
		# verstellen: ein Sprung im Tageszähler würde 12 Spieltage überspringen.
		var paare_alt: Array = Mentoring.paare(Welt.daten, cid_a)
		if not paare_alt.is_empty():
			paare_alt[0]["seit"] = int(Welt.daten["tag"]) - 84
		for _w in range(12):
			Mentoring.wochenwechsel(Welt.daten)
		var paare_m: Array = Mentoring.paare(Welt.daten, cid_a)
		if not paare_m.is_empty():
			_log("   Fortschritt nach 12 Wochen: %.1f · %s" % [float(paare_m[0]["fortschritt"]),
				Mentoring.beschreibung(Welt.daten, paare_m[0])])
	app.zeige("kabine")
	await get_tree().process_frame

	_log("— Sponsorenmarkt —")
	var cid_s: String = Welt.mein_verein_id
	_log("   laufende Verträge: %d, Jahressumme %s" % [
		Sponsoren.laufende(Welt.daten, cid_s).size(), Stil.geld(Sponsoren.jahressumme(Welt.daten, cid_s))])
	# Einen Platz künstlich frei machen und das Angebot annehmen
	var vertraege: Array = Sponsoren.laufende(Welt.daten, cid_s)
	if not vertraege.is_empty():
		var weg: String = str(vertraege[0]["art"])
		vertraege.remove_at(0)
		Welt.verein(cid_s)["sponsorangebote"] = [Sponsoren.angebot(Welt.daten, cid_s, weg)]
		var erg_s := Sponsoren.annehmen(Welt.daten, cid_s, 0)
		_log("   %s" % str(erg_s["grund"]))
	Sponsoren.titelbonus(Welt.daten, cid_s, "Testpokal")
	app.zeige("finanzen")
	await get_tree().process_frame

	_log("— Laufbahn —")
	var mit_laufbahn := 0
	var beispiel := ""
	for sid_l in Welt.verein(cid_s)["kader"]:
		if not Laufbahn.liste(Welt.spieler(sid_l)).is_empty():
			mit_laufbahn += 1
			if beispiel == "":
				beispiel = "%s: %s" % [Spielerfabrik.kurz_name(Welt.spieler(sid_l)),
					str(Laufbahn.liste(Welt.spieler(sid_l))[0]["text"])]
	var welt_gesamt := 0
	var mit_spielen := 0
	for sid_w in Welt.daten["spieler"].keys():
		welt_gesamt += Laufbahn.liste(Welt.spieler(sid_w)).size()
		if int(Welt.spieler(sid_w)["stats"]["karriere"]["spiele"]) > 0:
			mit_spielen += 1
	_log("   Spieler mit mindestens einem Pflichtspiel: %d" % mit_spielen)
	_log("   eigene Vereinsspiele: %d" % int(Welt.mein_verein()["saison"]["spiele"]))
	var probe: Dictionary = Welt.spieler(str(Welt.verein(cid_s)["kader"][0]))
	_log("   %d im eigenen Kader, %d Einträge weltweit (Beispielspieler: %d Pflichtspiele)" % [
		mit_laufbahn, welt_gesamt, int(probe["stats"]["karriere"]["spiele"])])
	if beispiel != "":
		_log("   %s" % beispiel)
	var fenster_l: Node = get_tree().get_first_node_in_group("spielerfenster")
	fenster_l.zeige(str(Welt.verein(cid_s)["kader"][0]))
	fenster_l.reiter = "entwicklung"
	fenster_l._zeichne()
	await get_tree().process_frame
	fenster_l.visible = false

	_log("— Vorspulen —")
	var vf: Node = get_tree().get_first_node_in_group("vorspulfenster")
	vf.zeige()
	await get_tree().process_frame
	var vorher_tag := Welt.tag()
	Welt.setze_einstellung("vorspulen_simuliert", true)
	var sprung := Welt.vorspulen(Welt.tag() + 21, true)
	_log("   %d Tage vorgespult (%s), Tag %d -> %d" % [int(sprung["tage"]), str(sprung["grund"]),
		vorher_tag, Welt.tag()])
	vf._zeichne()
	await get_tree().process_frame
	vf.visible = false

	_log("— Alter Spielstand (fehlende Felder ergänzen) —")
	# Einen Spielstand aus einer früheren Fassung nachstellen: alles, was neu
	# dazugekommen ist, wieder entfernen und die Welt reparieren lassen.
	for cid_alt in Weltgenerator.clubs(Welt.daten):
		var v_alt: Dictionary = Welt.verein(cid_alt)
		v_alt.erase("mentoring")
		v_alt.erase("sponsorangebote")
		(v_alt["saison"] as Dictionary).erase("finanzen")
		(v_alt["aufstellung"] as Dictionary).erase("anweisungen")
		for sid_alt in v_alt["kader"]:
			Welt.spieler(sid_alt).erase("nummer")
			Welt.spieler(sid_alt).erase("laufbahn")
	Welt._daten_auffrischen()
	var fehlt := 0
	for cid_p in Weltgenerator.clubs(Welt.daten):
		var v_p: Dictionary = Welt.verein(cid_p)
		if not v_p.has("mentoring") or not v_p.has("sponsorangebote"):
			fehlt += 1
		for sid_p in v_p["kader"]:
			if int(Welt.spieler(sid_p).get("nummer", 0)) <= 0:
				fehlt += 1
	_log("   nach der Ergänzung fehlende Felder: %d" % fehlt)
	for id_alt in app.bildschirme.keys():
		app.zeige(id_alt)
		await get_tree().process_frame

	_log("— Speichern und Laden —")
	if Welt.speichern(1, "Testlauf"):
		_log("   gespeichert")
	var vorher := Welt.tag()
	var verein_vorher := str(Welt.mein_verein_id)
	if Welt.laden(1):
		_log("   geladen: Tag %d (vorher %d), Verein %s" % [Welt.tag(), vorher, Welt.mein_verein()["name"]])
		if Welt.tag() != vorher or Welt.mein_verein_id != verein_vorher:
			_log("   FEHLER: Spielstand stimmt nicht überein")
	for id3 in app.bildschirme.keys():
		app.zeige(id3)
		await get_tree().process_frame
	_log("— Alles durchlaufen —")
	get_tree().quit()
