class_name TransferBildschirm
extends Bildschirm
## Transfermarkt: Spielersuche mit Filtern, laufende Verhandlungen, Gerüchte.

var suchergebnis: VBoxContainer
var verhandlungen: VBoxContainer
var kopfinfo: Label
## Wie viele Trefferzeilen gebaut werden. Mehr auf Knopfdruck.
const ZEILEN_START := 25
const ZEILEN_SCHRITT := 25
var sichtbare_zeilen: int = ZEILEN_START

var filter := {"position": "", "max_alter": 40, "min_gesamt": 0.0, "max_ablöse": 0.0, "nur_transferliste": false,
	"nur_vereinslos": false, "nur_vertragsende": false, "text": ""}
var meldung: Label

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Transfermarkt", 0))
	kopf.add_child(Stil.dehner())
	kopfinfo = Stil.text("", Stil.S_KLEIN, Stil.AKZENT)
	kopf.add_child(kopfinfo)
	meldung = Stil.text("", Stil.S_KLEIN, Stil.GRUEN)
	v.add_child(meldung)

	var filterzeile := Stil.hbox(8)
	v.add_child(filterzeile)
	filterzeile.add_child(Stil.matt("Position"))
	var pos := OptionButton.new()
	pos.add_item("alle")
	pos.set_item_metadata(0, "")
	for p in Spielerfabrik.POSITIONEN:
		pos.add_item(p)
		pos.set_item_metadata(pos.item_count - 1, p)
	pos.item_selected.connect(func(i):
		filter["position"] = str(pos.get_item_metadata(i))
		_filter_geaendert())
	filterzeile.add_child(pos)

	filterzeile.add_child(Stil.matt("max. Alter"))
	var alter := SpinBox.new()
	alter.min_value = 16
	alter.max_value = 40
	alter.value = 40
	alter.value_changed.connect(func(w):
		filter["max_alter"] = int(w)
		_filter_geaendert())
	filterzeile.add_child(alter)

	filterzeile.add_child(Stil.matt("min. Stärke"))
	var staerke := SpinBox.new()
	staerke.min_value = 0
	staerke.max_value = 99
	staerke.value = 0
	staerke.value_changed.connect(func(w):
		filter["min_gesamt"] = float(w)
		_filter_geaendert())
	filterzeile.add_child(staerke)

	filterzeile.add_child(Stil.matt("Name"))
	var suchfeld := LineEdit.new()
	suchfeld.custom_minimum_size = Vector2(150, 0)
	suchfeld.text_changed.connect(func(t):
		filter["text"] = t
		_filter_geaendert())
	filterzeile.add_child(suchfeld)

	var zeile2 := Stil.hbox(10)
	v.add_child(zeile2)
	for f in [["nur_transferliste", "nur Transferliste / Wechselwunsch"], ["nur_vereinslos", "nur vereinslose Spieler"],
			["nur_vertragsende", "nur auslaufende Verträge"]]:
		var haken := Stil.schalter("")
		haken.text = str(f[1])
		var schluessel: String = str(f[0])
		haken.toggled.connect(func(an):
			filter[schluessel] = an
			_suche())
		zeile2.add_child(haken)
	zeile2.add_child(Stil.dehner())
	var budget := Stil.knopf("Nur im Budget")
	budget.pressed.connect(func():
		filter["max_ablöse"] = float(Welt.mein_verein().get("transferbudget", 0.0))
		_filter_geaendert())
	zeile2.add_child(budget)
	var zuruecksetzen := Stil.knopf("Filter zurücksetzen")
	zuruecksetzen.pressed.connect(func():
		filter = {"position": "", "max_alter": 40, "min_gesamt": 0.0, "nur_transferliste": false,
			"nur_vereinslos": false, "nur_vertragsende": false, "text": ""}
		pos.select(0)
		alter.value = 40
		staerke.value = 0
		suchfeld.text = ""
		_suche())
	zeile2.add_child(zuruecksetzen)

	var spalten := HSplitContainer.new()
	spalten.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spalten)
	var links := ScrollContainer.new()
	links.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	links.custom_minimum_size = Vector2(700, 0)
	spalten.add_child(links)
	suchergebnis = Stil.vbox(2)
	suchergebnis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_child(suchergebnis)
	var rechts := ScrollContainer.new()
	rechts.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	spalten.add_child(rechts)
	verhandlungen = Stil.vbox(10)
	verhandlungen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.add_child(verhandlungen)

func aktualisieren() -> void:
	if suchergebnis == null:
		return
	if not Welt.bereit():
		leeren(suchergebnis)
		leeren(verhandlungen)
		kopfinfo.text = ""
		suchergebnis.add_child(Stil.matt("Kein Spielstand geladen."))
		return
	_kopf()
	_suche()
	_verhandlungen()

func _kopf() -> void:
	var offen := Transfermarkt.fenster_offen(Welt.daten)
	var rest := Transfermarkt.tage_bis_fensterschluss(Welt.daten)
	if offen:
		kopfinfo.text = "Transferfenster offen — noch %d Tage" % rest
		kopfinfo.add_theme_color_override("font_color", Stil.GRUEN if rest > 7 else Stil.ROT)
	else:
		kopfinfo.text = "Transferfenster geschlossen — öffnet in %d Tagen" % absi(rest)
		kopfinfo.add_theme_color_override("font_color", Stil.TEXT_MATT)
	if Welt.mein_verein_id != "":
		var v: Dictionary = Welt.mein_verein()
		kopfinfo.text += "   ·   Budget: %s   ·   Gehaltsauslastung: %.0f %%" % [
			Stil.geld(float(v["transferbudget"])), Finanzen.gehaltsauslastung(Welt.daten, Welt.mein_verein_id)]

## Nach einer Filteränderung fängt die Liste wieder oben an — sonst zeigte
## ein neuer Filter plötzlich hundert Zeilen, weil vorher nachgeladen wurde.
func _filter_geaendert() -> void:
	sichtbare_zeilen = ZEILEN_START
	_suche()

func _suche() -> void:
	if suchergebnis == null or not Welt.bereit():
		return
	leeren(suchergebnis)
	var f := filter.duplicate()
	# Nur so viele Zeilen bauen, wie jemand tatsächlich durchsieht. Sechzig
	# Zeilen auf einmal kosteten spürbar Zeit beim Öffnen und wurden trotzdem
	# nie zu Ende gelesen — wer mehr will, holt sie sich per Knopf.
	f["limit"] = sichtbare_zeilen + 1
	var treffer := Transfermarkt.suchen(Welt.daten, f, Welt.mein_verein_id)
	var mehr_da: bool = treffer.size() > sichtbare_zeilen
	treffer = treffer.slice(0, sichtbare_zeilen)
	var kopf := Stil.hbox(6)
	suchergebnis.add_child(kopf)
	for s in [["Pos", 44], ["Spieler", 180], ["Alter", 44], ["Stärke", 66], ["Perspektive", 150],
			["Verein", 120], ["Ablöse", 90], ["Gehalt", 86]]:
		var l := Stil.matt(str(s[0]), Stil.S_MINI)
		l.custom_minimum_size = Vector2(float(s[1]), 0)
		kopf.add_child(l)
	suchergebnis.add_child(Stil.trenner())
	if treffer.is_empty():
		suchergebnis.add_child(Stil.matt("Keine Spieler gefunden."))
		return
	var nummer := 0
	for sid in treffer:
		suchergebnis.add_child(_zeile(sid, nummer))
		nummer += 1
	if mehr_da:
		var fuss := Stil.hbox(8)
		suchergebnis.add_child(fuss)
		fuss.add_child(Stil.matt("%d Treffer angezeigt — die stärksten zuerst." % treffer.size(), Stil.S_MINI))
		fuss.add_child(Stil.dehner())
		var mehr := Stil.knopf("Weitere %d anzeigen" % ZEILEN_SCHRITT)
		mehr.pressed.connect(func():
			sichtbare_zeilen += ZEILEN_SCHRITT
			aktualisieren())
		fuss.add_child(mehr)

func _zeile(sid: String, index: int = 0) -> Control:
	var sp: Dictionary = Welt.spieler(sid)
	var knopf := Stil.zeilen_knopf(index, false, 27)
	knopf.tooltip_text = "%s öffnen" % Spielerfabrik.voller_name(sp)
	knopf.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
	var h := Stil.hbox(6)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knopf.add_child(h)
	var namenszelle := Stil.hbox(5)
	namenszelle.add_child(Flagge.fuer(str(sp["nation"]), 16.0))
	namenszelle.add_child(Stil.text(Spielerfabrik.voller_name(sp), Stil.S_KLEIN))
	var zellen := [
		Bausteine.positions_abzeichen(str(sp["position"])),
		namenszelle,
		Stil.text(str(int(sp["alter"])), Stil.S_KLEIN),
		Stil.text(Scouting.gesamt_text(Welt.daten, sid), Stil.S_KLEIN, Stil.wert_farbe(Spielerfabrik.gesamt(sp), 100.0)),
		Stil.text(Scouting.potenzial_text(Welt.daten, sid), Stil.S_MINI, Stil.LILA),
		Stil.matt(str(Welt.verein(str(sp["verein"])).get("kurz", "frei")), Stil.S_KLEIN),
		Stil.text(Stil.geld(Transfermarkt.ablösevorstellung(Welt.daten, sid)), Stil.S_KLEIN),
		Stil.text(Stil.geld(Spielerfabrik.gehaltsvorstellung(sp, float(Welt.mein_verein().get("ruf", 50.0)))), Stil.S_KLEIN),
	]
	var breiten := [44, 180, 44, 66, 150, 120, 90, 86]
	for i in range(zellen.size()):
		zellen[i].custom_minimum_size = Vector2(float(breiten[i]), 0)
		zellen[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(zellen[i])
	if bool(sp.get("transferwunsch", false)) or bool(sp.get("auf_transferliste", false)):
		var a := Stil.abzeichen("VERFÜGBAR", Stil.GRUEN)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(a)
	return knopf

func _verhandlungen() -> void:
	leeren(verhandlungen)
	if not Welt.bereit():
		return
	var laufend := Bausteine.karte_in(verhandlungen, "Laufende Verhandlungen")
	var eigene: Array = []
	for a in (Welt.daten.get("transfermarkt", {}).get("angebote", []) as Array):
		if str(a["nach"]) == Welt.mein_verein_id or str(a["von"]) == Welt.mein_verein_id:
			eigene.append(a)
	if eigene.is_empty():
		laufend.add_child(Stil.matt("Keine offenen Vorgänge."))
	for a in eigene:
		laufend.add_child(_verhandlung(a))

	var geruechte := Bausteine.karte_in(verhandlungen, "Gerüchteküche")
	var liste: Array = Welt.daten.get("transfermarkt", {}).get("gerüchte", [])
	if liste.is_empty():
		geruechte.add_child(Stil.matt("Derzeit ist es ruhig."))
	for g in liste.slice(0, 8):
		var t := Stil.text("• " + str(g["text"]), Stil.S_KLEIN, Stil.TEXT_MATT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		geruechte.add_child(t)

	var verlauf := Bausteine.karte_in(verhandlungen, "Letzte Wechsel")
	var v: Array = Welt.daten.get("transfermarkt", {}).get("verlauf", [])
	if v.is_empty():
		verlauf.add_child(Stil.matt("Noch keine Transfers."))
	for e in v.slice(0, 10):
		if Welt.spieler(str(e["spieler"])).is_empty():
			continue
		var sp: Dictionary = Welt.spieler(str(e["spieler"]))
		verlauf.add_child(Stil.info_zeile("%s → %s" % [Spielerfabrik.kurz_name(sp),
			str(Welt.verein(str(e["nach"])).get("kurz", "—"))], Stil.geld(float(e["ablöse"]))))

func _verhandlung(a: Dictionary) -> Control:
	var karte := Stil.karte("", true)
	var sid: String = str(a["spieler"])
	if Welt.spieler(sid).is_empty():
		karte.add_child(Stil.matt("Spieler nicht mehr verfügbar."))
		return Stil.karte_wurzel(karte)
	var sp: Dictionary = Welt.spieler(sid)
	var eingehend: bool = str(a["richtung"]) == "eingehend"
	karte.add_child(Stil.text("%s %s" % ["Angebot für" if eingehend else "Angebot an", Spielerfabrik.voller_name(sp)], Stil.S_KLEIN, Stil.AKZENT))
	karte.add_child(Stil.info_zeile("Verein", str(Welt.verein(str(a["nach"]) if eingehend else str(a["von"])).get("name", "vereinslos"))))
	karte.add_child(Stil.info_zeile("Ablöse", Stil.geld(float(a["ablöse"]))))
	karte.add_child(Stil.info_zeile("Gehalt", Stil.geld(float(a["gehalt"]))))
	karte.add_child(Stil.info_zeile("Status", str(a["status"]).capitalize()))
	if str(a.get("antwort", "")) != "":
		var t := Stil.text(str(a["antwort"]), Stil.S_MINI, Stil.TEXT_MATT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		karte.add_child(t)
	var zeile := Stil.hbox(6)
	karte.add_child(zeile)
	if eingehend and str(a["status"]) == "eingegangen":
		var ja := Stil.knopf_primaer("Annehmen")
		ja.pressed.connect(func():
			var erg := Transfermarkt.eingehendes_angebot_entscheiden(Welt.daten, str(a["id"]), true)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			aktualisieren())
		zeile.add_child(ja)
		var nein := Stil.knopf("Ablehnen")
		nein.pressed.connect(func():
			Transfermarkt.eingehendes_angebot_entscheiden(Welt.daten, str(a["id"]), false)
			_melde("Angebot abgelehnt.")
			aktualisieren())
		zeile.add_child(nein)
	elif str(a["status"]) in ["gegenangebot", "spieler_gegenangebot"]:
		var nach := Stil.knopf_primaer("Forderung erfüllen")
		nach.pressed.connect(func():
			var neue_abloese: float = float(a.get("gegenforderung", a["ablöse"]))
			var neues_gehalt: float = float(a.get("gehaltsforderung", a["gehalt"]))
			var erg := Transfermarkt.nachbessern(Welt.daten, str(a["id"]), neue_abloese, neues_gehalt)
			_melde(str(erg["grund"]), bool(erg["ok"]))
			aktualisieren())
		zeile.add_child(nach)
		var raus := Stil.knopf("Abbrechen")
		raus.pressed.connect(func():
			Transfermarkt.zurueckziehen(Welt.daten, str(a["id"]))
			aktualisieren())
		zeile.add_child(raus)
	elif str(a["status"]) == "offen" or str(a["status"]) == "verein_einig":
		var raus2 := Stil.knopf("Zurückziehen")
		raus2.pressed.connect(func():
			Transfermarkt.zurueckziehen(Welt.daten, str(a["id"]))
			aktualisieren())
		zeile.add_child(raus2)
	return Stil.karte_wurzel(karte)

func _melde(text: String, gut: bool = true) -> void:
	meldung.text = text
	meldung.add_theme_color_override("font_color", Stil.GRUEN if gut else Stil.ROT)
