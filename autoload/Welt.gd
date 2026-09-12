extends Node
## Welt — der eine zentrale Spielzustand von Hallenherz.
##
## Saemtliche Bildschirme lesen und schreiben ausschliesslich ueber dieses Singleton.
## In "daten" liegt der komplette Spielstand als verschachteltes Dictionary; genau dieses
## Dictionary wird gespeichert und geladen, deshalb ist jede neue Zustandsvariable
## automatisch Teil der Persistenz, sobald sie dort abgelegt wird.

signal zustand_geaendert()
signal tag_gewechselt(tag: int)
signal nachricht_eingegangen(nachricht: Dictionary)
signal spiel_ausgetragen(spiel_id: String)
signal saison_gewechselt(saison: int)
signal live_spiel_faellig(spiel_id: String)

const DATENVERSION := 1
const SPEICHERORDNER := "user://spielstaende"
const SLOTS := 5
## Platz 0 gehört der Automatik — er wird ohne Zutun überschrieben.
const AUTOSLOT := 0

var daten: Dictionary = {}
var mein_verein_id: String = ""
var laeuft: bool = false
## Wird waehrend des Weiterschaltens gesetzt, damit die Oberflaeche anhalten kann.
var unterbrechung: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SPEICHERORDNER)

# ------------------------------------------------------------ Neues Spiel ---

func neues_spiel(verein_id: String, trainer_daten: Dictionary, saat: int = 0, echte_welt: bool = true) -> void:
	var s: int = saat if saat != 0 else int(Time.get_unix_time_from_system()) % 2147483647
	daten = Weltgenerator.erzeuge(2026, s, echte_welt)
	mein_verein_id = verein_id
	var v: Dictionary = daten["vereine"][verein_id]
	v["ist_mensch"] = true
	daten["trainer"] = Trainerkarriere.neu(trainer_daten, verein_id, daten)
	Saison.prognose_erstellen(daten, verein_id)
	v["trainer"] = "mensch"
	Vorstand.saisonziel_festlegen(daten, verein_id)
	for cid in Weltgenerator.clubs(daten):
		if cid != verein_id:
			Vorstand.saisonziel_festlegen(daten, cid)
	Spielplan.erzeuge_saison(daten)
	Finanzen.saison_budgets(daten)
	laeuft = true
	nachricht({
		"typ": "verein",
		"betreff": "Willkommen bei %s" % v["name"],
		"text": "Der Vorstand begrüßt Sie in %s. Ihr Vertrag läuft bis zum Ende der Saison %s. Saisonziel: %s." % [
			v["ort"], Kalender.saison_text(int(daten["startjahr"]), int(daten["trainer"]["vertrag"]["bis_saison"])),
			v["vorstand"]["saisonziel"]],
		"wichtig": true,
	})
	Medien.saisonauftakt(daten, verein_id)
	zustand_geaendert.emit()

# ------------------------------------------------------------- Zugriffe ---

# Alle Zugriffe vertragen einen leeren Zustand: die Anwendung startet ohne
# geladenen Spielstand, und jeder Bildschirm muss sich auch dann aufbauen lassen.

func verein(cid: String) -> Dictionary:
	return (daten.get("vereine", {}) as Dictionary).get(cid, {})

func spieler(sid: String) -> Dictionary:
	return (daten.get("spieler", {}) as Dictionary).get(sid, {})

func mitarbeiter(pid: String) -> Dictionary:
	return (daten.get("personal", {}) as Dictionary).get(pid, {})

func liga(lid: String) -> Dictionary:
	return (daten.get("ligen", {}) as Dictionary).get(lid, {})

func partie(mid: String) -> Dictionary:
	return (daten.get("spiele", {}) as Dictionary).get(mid, {})

func mein_verein() -> Dictionary:
	return (daten.get("vereine", {}) as Dictionary).get(mein_verein_id, {})

func trainer() -> Dictionary:
	return daten.get("trainer", {})

## Zugriff auf eine Spieleinstellung, auch wenn noch keine Welt geladen ist.
func einstellung(schluessel: String, standard: Variant) -> Variant:
	return (daten.get("einstellungen", {}) as Dictionary).get(schluessel, standard)

func setze_einstellung(schluessel: String, wert: Variant) -> void:
	if not daten.has("einstellungen"):
		daten["einstellungen"] = {}
	daten["einstellungen"][schluessel] = wert

## Gibt es einen bespielbaren Zustand?
func bereit() -> bool:
	return laeuft and not daten.is_empty()

func tag() -> int:
	return int(daten.get("tag", 0))

func datum_vorhanden() -> bool:
	return daten.has("tag")

func startjahr() -> int:
	return int(daten.get("startjahr", 2026))

func saison_index() -> int:
	if daten.is_empty():
		return 0
	return Kalender.saison_index(int(daten["tag"]))

func saison_text() -> String:
	return Kalender.saison_text(startjahr(), saison_index())

func datum_text(lang: bool = false) -> String:
	return Kalender.text(tag(), startjahr(), lang)

func wettbewerb_name(wid: String) -> String:
	if (daten.get("ligen", {}) as Dictionary).has(wid):
		return str(daten["ligen"][wid]["name"])
	if (daten.get("pokale", {}) as Dictionary).has(wid):
		return str(daten["pokale"][wid]["name"])
	if (daten.get("international", {}) as Dictionary).has(wid):
		return str(daten["international"][wid]["name"])
	if wid == "turnier":
		return str(daten.get("turnier", {}).get("name", "Nationalmannschaft"))
	if wid.begins_with("test_"):
		return "Vorbereitungsspiel"
	if wid.begins_with("sc_"):
		var nid := wid.substr(3)
		return str((daten.get("nationen", {}) as Dictionary).get(nid, {}).get("supercup_name", "Supercup"))
	return "Testspiel"

func spiele_am_tag(t: int) -> Array:
	return (daten.get("plan", {}) as Dictionary).get(t, [])

## Naechste Partie eines Vereins ab dem aktuellen Tag.
## Sucht ueber den Terminplan statt ueber alle jemals angesetzten Partien —
## das wird pro Spieltag hundertfach aufgerufen.
func naechstes_spiel(cid: String, sichtweite: int = 120) -> Dictionary:
	if cid == "" or daten.is_empty():
		return {}
	var start: int = tag()
	for t in range(start, start + sichtweite):
		for mid in spiele_am_tag(t):
			var m: Dictionary = partie(mid)
			if m.is_empty() or bool(m["gespielt"]):
				continue
			if str(m["heim"]) == cid or str(m["gast"]) == cid:
				return m
	return {}

## Die zuletzt gespielten Partien eines Vereins, neueste zuerst.
func letzte_spiele(cid: String, anzahl: int = 5, sichtweite: int = 200) -> Array:
	var liste: Array = []
	if cid == "" or daten.is_empty():
		return liste
	var start: int = tag()
	for t in range(start, maxi(start - sichtweite, -1), -1):
		for mid in spiele_am_tag(t):
			var m: Dictionary = partie(mid)
			if m.is_empty() or not bool(m["gespielt"]):
				continue
			if str(m["heim"]) == cid or str(m["gast"]) == cid:
				liste.append(m)
				if liste.size() >= anzahl:
					return liste
	return liste

## Talente im Nachwuchszentrum eines Vereins.
func jugend(cid: String) -> Array:
	return Jugend.liste(daten, cid)

func kader(cid: String) -> Array:
	var liste: Array = (verein(cid).get("kader", []) as Array).duplicate()
	if liste.is_empty():
		return liste
	liste.sort_custom(func(a, b):
		var sa: Dictionary = spieler(a)
		var sb: Dictionary = spieler(b)
		var pa: int = Spielerfabrik.POSITIONEN.find(str(sa["position"]))
		var pb: int = Spielerfabrik.POSITIONEN.find(str(sb["position"]))
		if pa != pb:
			return pa < pb
		return Spielerfabrik.gesamt(sa) > Spielerfabrik.gesamt(sb))
	return liste

# ------------------------------------------------------------ Nachrichten ---

func nachricht(inhalt: Dictionary) -> void:
	if daten.is_empty():
		return
	daten["zaehler"]["nachricht"] = int(daten["zaehler"]["nachricht"]) + 1
	var n := {
		"id": "n_%05d" % int(daten["zaehler"]["nachricht"]),
		"tag": tag(),
		"gelesen": false,
		"typ": inhalt.get("typ", "info"),
		"betreff": inhalt.get("betreff", ""),
		"text": inhalt.get("text", ""),
		"wichtig": inhalt.get("wichtig", false),
		"aktion": inhalt.get("aktion", ""),
		"daten": inhalt.get("daten", {}),
	}
	(daten["nachrichten"] as Array).push_front(n)
	if (daten["nachrichten"] as Array).size() > 400:
		(daten["nachrichten"] as Array).resize(400)
	nachricht_eingegangen.emit(n)

func ungelesene_nachrichten() -> int:
	var z := 0
	for n in (daten.get("nachrichten", []) as Array):
		if not bool(n["gelesen"]):
			z += 1
	return z

# --------------------------------------------------------- Zeitfortschritt ---

## Schaltet einen Tag weiter und verarbeitet alles, was an diesem Tag passiert.
## Gibt eine Unterbrechung zurueck, wenn die Oberflaeche eingreifen soll.
func tag_weiter() -> Dictionary:
	unterbrechung = {}
	daten["tag"] = tag() + 1
	var t: int = tag()

	Training.tageswechsel(daten)
	Trainingslager.tageswechsel(daten)
	Medizin.tageswechsel(daten)
	Transfermarkt.tageswechsel(daten)
	Scouting.tageswechsel(daten)
	Nationalteam.tageswechsel(daten)
	Presse.tageswechsel(daten)
	Gespraech.tageswechsel(daten)
	Transfermarkt.klauseln_pruefen(daten)
	Anliegen.tageswechsel(daten)

	# Anstehende Partien
	var heute: Array = (spiele_am_tag(t) as Array).duplicate()
	var eigenes := ""
	for mid in heute:
		var m: Dictionary = daten["spiele"].get(mid, {})
		if m.is_empty() or bool(m["gespielt"]):
			continue
		if str(m["heim"]) == mein_verein_id or str(m["gast"]) == mein_verein_id:
			eigenes = mid
		elif Nationaltrainer.ist_nationalteam_spiel(daten, m):
			eigenes = mid
	if eigenes != "":
		unterbrechung = {"art": "eigenes_spiel", "spiel": eigenes}
		live_spiel_faellig.emit(eigenes)
		tag_gewechselt.emit(t)
		return unterbrechung

	spieltag_abwickeln(t)
	wochenrhythmus(t)
	saison_pruefen(t)
	tag_gewechselt.emit(t)
	zustand_geaendert.emit()
	return unterbrechung

## Bis zu einem Tag durchschalten. Haelt an, sobald etwas passiert, das eine
## Entscheidung verlangt — eine eigene Partie (wenn nicht simuliert werden soll),
## das Saisonende, der Saisonwechsel oder der Verlust des Vereins.
## Liefert {"tage": …, "grund": …, "spiel": …} zurueck.
func vorspulen(ziel_tag: int, eigene_simulieren: bool = true) -> Dictionary:
	if not bereit():
		return {"tage": 0, "grund": "kein_spielstand"}
	var geschafft := 0
	var verein_vorher := mein_verein_id
	# Harte Obergrenze: ein Kalenderjahr. Sonst koennte ein falsches Zieldatum
	# das Spiel in eine sehr lange Schleife schicken.
	var grenze: int = mini(maxi(ziel_tag - tag(), 0), 400)
	while geschafft < grenze:
		var u := tag_weiter()
		geschafft += 1
		if u.has("art"):
			match str(u["art"]):
				"eigenes_spiel":
					if not eigene_simulieren:
						return {"tage": geschafft, "grund": "eigenes_spiel", "spiel": str(u["spiel"])}
					partie_simulieren(str(u["spiel"]))
					spieltag_abwickeln(tag())
					wochenrhythmus(tag())
					saison_pruefen(tag())
				"saisonende":
					return {"tage": geschafft, "grund": "saisonende"}
				"neue_saison":
					return {"tage": geschafft, "grund": "neue_saison"}
		if mein_verein_id != verein_vorher:
			return {"tage": geschafft, "grund": "verein_verloren"}
	zustand_geaendert.emit()
	return {"tage": geschafft, "grund": "ziel_erreicht"}

## Rechnet alle Partien eines Tages ab (ohne die des Spielers, falls schon gespielt).
func spieltag_abwickeln(t: int) -> void:
	var heute: Array = (spiele_am_tag(t) as Array).duplicate()
	for mid in heute:
		var m: Dictionary = daten["spiele"].get(mid, {})
		if m.is_empty() or bool(m["gespielt"]):
			continue
		partie_simulieren(mid)
	Auszeichnungen.woche_auswerten(daten, mein_verein_id)
	_wettbewerbe_fortschreiben()

func partie_simulieren(mid: String) -> void:
	var m: Dictionary = daten["spiele"][mid]
	KI.kader_auffuellen(daten, str(m["heim"]))
	KI.kader_auffuellen(daten, str(m["gast"]))
	KI.aufstellung_pruefen(daten, str(m["heim"]))
	KI.aufstellung_pruefen(daten, str(m["gast"]))
	var sim := Matchsim.new(daten, m)
	sim.vorbereiten()
	sim.schnell_simulieren()
	partie_abschliessen(mid, sim)

## Traegt das Ergebnis einer (live oder schnell) gespielten Partie in die Welt ein.
func partie_abschliessen(mid: String, sim: Matchsim) -> void:
	var m: Dictionary = daten["spiele"][mid]
	m["bericht"] = sim.bericht()
	if str(m["art"]) == "turnier":
		Nationalteam.spiel_verbuchen(daten, m)
		Medizin.spiel_nachwirkung(daten, m)
		if Nationaltrainer.ist_nationalteam_spiel(daten, m):
			Nationaltrainer.spiel_verbuchen(daten, m)
		else:
			m["bericht"] = Matchsim.bericht_schlank(m["bericht"])
		spiel_ausgetragen.emit(mid)
		return
	Statistik.spiel_verbuchen(daten, m)
	Finanzen.spieltag_abrechnen(daten, m)
	Praemien.abrechnen(daten, m)
	Medizin.spiel_nachwirkung(daten, m)
	Chronik.spiel_eintragen(daten, m)
	if str(m["heim"]) == mein_verein_id or str(m["gast"]) == mein_verein_id:
		Medien.spielbericht(daten, m, mein_verein_id)
		Vorstand.nach_spiel(daten, mein_verein_id, m)
	else:
		# Alles verbucht — fremde Partien brauchen die Einzelheiten nicht mehr.
		m["bericht"] = Matchsim.bericht_schlank(m["bericht"])
	spiel_ausgetragen.emit(mid)

## Prueft nach jedem Spieltag, ob Pokal- oder Europarunden weitergehen.
func _wettbewerbe_fortschreiben() -> void:
	Nationalteam.fortschreiben(daten)
	for pid in daten["pokale"].keys():
		var pokal: Dictionary = daten["pokale"][pid]
		if bool(pokal.get("beendet", false)):
			continue
		var alle_gespielt := true
		for mid in pokal.get("paarungen", []):
			if not bool(daten["spiele"][mid]["gespielt"]):
				alle_gespielt = false
				break
		if alle_gespielt and not (pokal.get("paarungen", []) as Array).is_empty():
			var uebrig := Spielplan.pokal_weiter(daten, pid)
			if bool(pokal.get("beendet", false)):
				Saison.pokalsieger_feiern(daten, pid)
			elif uebrig.size() > 0:
				var rundenname := Spielplan.pokalrunden_name(uebrig.size())
				if _eigener_in(uebrig):
					nachricht({"typ": "wettbewerb", "betreff": "%s: %s erreicht" % [pokal["name"], rundenname],
						"text": "Die Auslosung ist erfolgt. Der nächste Gegner steht fest."})
	for wid in daten["international"].keys():
		var wb: Dictionary = daten["international"][wid]
		if str(wb["phase"]) == "beendet":
			continue
		if str(wb["phase"]) == "gruppe":
			var fertig := true
			for mid in daten["spiele"].keys():
				var sp: Dictionary = daten["spiele"][mid]
				if str(sp["wettbewerb"]) == wid and not bool(sp["gespielt"]):
					fertig = false
					break
			if fertig:
				Spielplan.gruppen_auswertung(daten, wid)
				nachricht({"typ": "wettbewerb", "betreff": "%s: Gruppenphase beendet" % wb["name"],
					"text": "Die Viertelfinalpaarungen stehen fest."})
		elif str(wb["phase"]) == "ko":
			var alles_gespielt := true
			for p in wb.get("paarungen", []):
				if not bool(daten["spiele"][p["rueck"]]["gespielt"]):
					alles_gespielt = false
					break
			if alles_gespielt and not (wb.get("paarungen", []) as Array).is_empty():
				var weiter := Spielplan.ko_weiter(daten, wid)
				if str(wb["phase"]) == "beendet":
					Saison.europapokal_feiern(daten, wid)
				elif weiter.size() > 0 and _eigener_in(weiter):
					nachricht({"typ": "wettbewerb", "betreff": "%s: eine Runde weiter" % wb["name"],
						"text": "Wir stehen in der nächsten Runde."})

func _eigener_in(liste: Array) -> bool:
	return liste.has(mein_verein_id)

## Wochenrhythmus: Sammelereignisse statt taeglichem Kleinkram.
func wochenrhythmus(t: int) -> void:
	var wt: int = Kalender.wochentag(t)
	if wt == 0:  # Montag: Wochenbericht
		Training.wochenwechsel(daten)
		Finanzen.wochenabrechnung(daten)
		Medien.wochenrueckblick(daten, mein_verein_id)
		Vorstand.wochenpruefung(daten, mein_verein_id)
		KI.wochenlogik(daten)
		Scouting.wochenbericht(daten, mein_verein_id)
		if mein_verein_id == "" and (trainer().get("jobangebote", []) as Array).is_empty():
			Saison.jobangebote_erzeugen(daten, "")
	if Kalender.datum(t, startjahr())["tag"] == 1:
		Auszeichnungen.monatswahl(daten, mein_verein_id)
		Auszeichnungen.monat_zuruecksetzen(daten)
	if wt == 3:  # Donnerstag: Kabine und Gerüchte
		Kabine.wochenpuls(daten)
		Transfermarkt.geruechtekueche(daten)
		Anliegen.wochenpruefung(daten)
	if wt == 0:
		automatisch_speichern()

func saison_pruefen(t: int) -> void:
	var tis: int = Kalender.tag_in_saison(t)
	if tis == Spielplan.SAISON_ABSCHLUSS and not bool(daten.get("saison_abgeschlossen", false)):
		daten["saison_abgeschlossen"] = true
		Saison.abschluss(daten, mein_verein_id)
		unterbrechung = {"art": "saisonende"}
	if tis == 0 and bool(daten.get("saison_abgeschlossen", false)):
		Saison.neue_saison(daten, mein_verein_id)
		daten["saison_abgeschlossen"] = false
		saison_gewechselt.emit(saison_index())
		unterbrechung = {"art": "neue_saison"}
		automatisch_speichern()

## Wöchentlicher Sicherungspunkt auf Platz 0. Läuft still im Hintergrund und
## lässt sich in den Einstellungen abschalten.
func automatisch_speichern() -> bool:
	if daten.is_empty() or mein_verein_id == "":
		return false
	if not bool(einstellung("autospeichern", true)):
		return false
	return speichern(AUTOSLOT, "Automatisch")

# ------------------------------------------------------------- Persistenz ---

func slot_pfad(slot: int) -> String:
	return "%s/spielstand_%d.hh" % [SPEICHERORDNER, slot]

func slot_meta_pfad(slot: int) -> String:
	return "%s/spielstand_%d.json" % [SPEICHERORDNER, slot]

func speichern(slot: int, bezeichnung: String = "") -> bool:
	if daten.is_empty():
		return false
	daten["version"] = DATENVERSION
	daten["mein_verein"] = mein_verein_id
	var f := FileAccess.open(slot_pfad(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(daten, false)
	f.close()
	var v: Dictionary = mein_verein()
	var meta := {
		"bezeichnung": bezeichnung if bezeichnung != "" else str(v.get("name", "Spielstand")),
		"verein": str(v.get("name", "")),
		"trainer": "%s %s" % [trainer().get("vorname", ""), trainer().get("nachname", "")],
		"saison": saison_text(),
		"datum": datum_text(),
		"gespeichert": Time.get_datetime_string_from_system(false, true),
		"version": DATENVERSION,
	}
	var mf := FileAccess.open(slot_meta_pfad(slot), FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify(meta, "\t"))
		mf.close()
	return true

func laden(slot: int) -> bool:
	var pfad := slot_pfad(slot)
	if not FileAccess.file_exists(pfad):
		return false
	var f := FileAccess.open(pfad, FileAccess.READ)
	if f == null:
		return false
	var geladen = f.get_var(false)
	f.close()
	if typeof(geladen) != TYPE_DICTIONARY:
		return false
	daten = geladen
	_daten_auffrischen()
	mein_verein_id = str(daten.get("mein_verein", ""))
	laeuft = true
	zustand_geaendert.emit()
	return true

func slot_info(slot: int) -> Dictionary:
	if not FileAccess.file_exists(slot_meta_pfad(slot)):
		return {}
	var f := FileAccess.open(slot_meta_pfad(slot), FileAccess.READ)
	if f == null:
		return {}
	var roh := f.get_as_text()
	f.close()
	var erg = JSON.parse_string(roh)
	return erg if typeof(erg) == TYPE_DICTIONARY else {}

func slot_loeschen(slot: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_pfad(slot)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_meta_pfad(slot)))

## Ergaenzt fehlende Felder in aelteren Spielstaenden, damit Weiterentwicklung
## des Spiels keine alten Staende zerstoert.
func _daten_auffrischen() -> void:
	var vorlage := {
		"nachrichten": [], "presse": [], "social": [], "chronik": {"saisons": [], "ereignisse": []},
		"rekorde": {}, "scouting": {"auftraege": [], "berichte": [], "beobachtung": []},
		"transfermarkt": {"angebote": [], "gerüchte": [], "verlauf": [], "fenster_offen": true},
		"medien": {"outlets": [], "fanaccounts": []},
		"einstellungen": {"autorotation": true, "auto_aufstellung": true, "auto_taktik": true,
			"presse_filter": "alle", "sim_tempo": 2,
			"autospeichern": true,
			"ton_an": true, "lautstaerke_musik": 55.0,
			"lautstaerke_effekte": 75.0, "lautstaerke_atmo": 65.0},
		"plan": {}, "international": {}, "pokale": {}, "saison_abgeschlossen": false,
		"nationalteams": [], "turnier": Nationalteam.leeres_turnier(),
		"pressekonferenz": {}, "versprechen": [], "anliegen": [],
		"auszeichnungen": Auszeichnungen.leer(),
	}
	for k in vorlage.keys():
		if not daten.has(k):
			daten[k] = vorlage[k]
	var trainer_dict: Dictionary = daten.get("trainer", {})
	if not trainer_dict.is_empty():
		if not trainer_dict.has("nationalteam"):
			trainer_dict["nationalteam"] = ""
		if not trainer_dict.has("verbandsangebote"):
			trainer_dict["verbandsangebote"] = []
	if not daten.has("echte_welt"):
		daten["echte_welt"] = false
	if not daten.has("datenstand"):
		daten["datenstand"] = ""
	if not daten.has("zaehler"):
		daten["zaehler"] = {"spieler": 0, "verein": 0, "spiel": 0, "personal": 0, "nachricht": 0, "auftrag": 0}
	for verein_cid in daten.get("vereine", {}).keys():
		var verein_dict: Dictionary = daten["vereine"][verein_cid]
		if not verein_dict.has("chronik"):
			verein_dict["chronik"] = {"titel": [], "beste_liga_platzierung": {}, "saisons": [],
				"ewige_bilanz": {"spiele": 0, "siege": 0, "unentschieden": 0, "niederlagen": 0, "tore": 0, "gegentore": 0},
				"legenden": []}
		if not verein_dict.has("formkurve"):
			verein_dict["formkurve"] = []
		if not verein_dict.has("jugend"):
			verein_dict["jugend"] = []
		if not verein_dict.has("mentoring"):
			verein_dict["mentoring"] = []
		if not verein_dict.has("sponsorangebote"):
			verein_dict["sponsorangebote"] = []
		if not verein_dict.has("trainingslager"):
			verein_dict["trainingslager"] = {}
		if not verein_dict.has("taktikprofile"):
			verein_dict["taktikprofile"] = []
		if not verein_dict.has("taktikregeln"):
			verein_dict["taktikregeln"] = {}
		if not (verein_dict.get("saison", {}) as Dictionary).has("finanzen"):
			(verein_dict.get("saison", {}) as Dictionary)["finanzen"] = {}
		var auf_dict: Dictionary = verein_dict.get("aufstellung", {})
		if not auf_dict.is_empty() and not auf_dict.has("anweisungen"):
			auf_dict["anweisungen"] = {}
		Trikot.kader_nummerieren(daten, str(verein_cid))
	for sp in daten.get("spieler", {}).values():
		if not sp.has("entwicklung_log"):
			sp["entwicklung_log"] = []
		if not sp.has("laufbahn"):
			sp["laufbahn"] = []
		if not sp.has("beziehung"):
			sp["beziehung"] = 50.0
		var vertrag: Dictionary = sp.get("vertrag", {})
		if not vertrag.is_empty():
			if not vertrag.has("praemie_tor"):
				vertrag["praemie_tor"] = 0.0
			if not vertrag.has("praemie_sieg"):
				vertrag["praemie_sieg"] = 0.0
		if not (sp.get("stats", {}) as Dictionary).has("monat"):
			(sp.get("stats", {}) as Dictionary)["monat"] = Spielerfabrik.leere_saisonstats()
		for zeitraum in ["saison", "karriere"]:
			var st: Dictionary = (sp.get("stats", {}) as Dictionary).get(zeitraum, {})
			if not st.is_empty() and not st.has("praemien"):
				st["praemien"] = 0.0
			if not st.is_empty() and not st.has("allstar"):
				st["allstar"] = 0
	daten["version"] = DATENVERSION
