class_name PokalBildschirm
extends Bildschirm
## Nationale Pokale und die beiden internationalen Wettbewerbe.

var inhalt: VBoxContainer
## Welcher Reiter offen steht.
var reiter := "europa"

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	# Kein Rollbereich um den ganzen Bildschirm: die Reiter bringen ihren
	# eigenen mit.
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(inhalt)

func aktualisieren() -> void:
	if inhalt == null or Welt.daten.is_empty():
		return
	leeren(inhalt)
	# Europa und die nationalen Pokale hintereinander waren mehr als eine
	# Bildschirmhoehe, obwohl man immer nur eines davon liest.
	var gruppe := Stil.reitergruppe([
		{"id": "europa", "name": "Europa"},
		{"id": "national", "name": "Nationale Pokale"},
	], reiter)
	gruppe.bei_wechsel = func(id): reiter = str(id)
	inhalt.add_child(gruppe)
	for wid in Welt.daten["international"].keys():
		_international(Welt.daten["international"][wid], gruppe.feld("europa"))
	var eigene_nation: String = str(Welt.verein(Welt.mein_verein_id).get("nation", "de")) if Welt.mein_verein_id != "" else "de"
	var ids: Array = Welt.daten["pokale"].keys()
	ids.sort_custom(func(a, b):
		return str(Welt.daten["pokale"][a]["nation"]) == eigene_nation and str(Welt.daten["pokale"][b]["nation"]) != eigene_nation)
	# Der eigene Pokal ganz, die anderen als Zeile.
	#
	# Ein Dutzend Laenderpokale mit allen Paarungen untereinander waren
	# anderthalb Bildschirmhoehen — und interessant ist daran genau einer.
	# Von den uebrigen zaehlt, wie weit sie sind und wer sie gewonnen hat.
	var fremde: Array = []
	for pid in ids:
		var pokal: Dictionary = Welt.daten["pokale"][pid]
		if str(pokal.get("nation", "")) == eigene_nation:
			_pokal(pokal, gruppe.feld("national"))
		else:
			fremde.append(pokal)
	if not fremde.is_empty():
		var karte := Bausteine.karte_in(gruppe.feld("national"), "Pokale anderer Länder")
		for f in fremde:
			var pokal2: Dictionary = f
			var zeile := Stil.hbox(10)
			karte.add_child(zeile)
			zeile.add_child(Flagge.fuer(str(pokal2.get("nation", "")), 18.0))
			var name := Stil.text(str(pokal2["name"]), Stil.S_KLEIN)
			zeile.add_child(Stil.beschnitten(name, 20.0))
			zeile.add_child(Stil.dehner())
			zeile.add_child(Stil.matt(_pokalstand(pokal2), Stil.S_MINI))

func _pokal(pokal: Dictionary, eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, str(pokal["name"]))
	var paarungen: Array = pokal.get("paarungen", [])
	if bool(pokal.get("beendet", false)):
		var sieger: String = str(pokal.get("sieger", ""))
		karte.add_child(Stil.text("Pokalsieger: %s" % Welt.verein(sieger).get("name", "—"), Stil.S_NORMAL, Stil.AKZENT))
	elif paarungen.is_empty():
		karte.add_child(Stil.matt("Der Wettbewerb beginnt in dieser Saison noch."))
	else:
		var uebrig: int = paarungen.size() * 2 + (pokal.get("freilose", []) as Array).size()
		karte.add_child(Stil.matt("%s · %d Mannschaften im Wettbewerb" % [Spielplan.pokalrunden_name(uebrig), uebrig], Stil.S_KLEIN))
		for mid in paarungen:
			var zeile := Stil.hbox(6)
			var m: Dictionary = Welt.partie(mid)
			var beteiligt: bool = str(m["heim"]) == Welt.mein_verein_id or str(m["gast"]) == Welt.mein_verein_id
			zeile.add_child(Bausteine.spielzeile(str(mid), Welt.mein_verein_id))
			if beteiligt:
				zeile.add_child(Stil.abzeichen("EIGENE PARTIE", Stil.AKZENT))
			karte.add_child(zeile)
	var historie: Array = pokal.get("sieger_historie", [])
	if not historie.is_empty():
		karte.add_child(Stil.trenner())
		for e in historie.slice(0, 5):
			karte.add_child(Stil.info_zeile(Kalender.saison_text(Welt.startjahr(), int(e["saison"])),
				str(Welt.verein(str(e["verein"])).get("name", ""))))

func _international(wb: Dictionary, eltern: Node) -> void:
	var karte := Bausteine.karte_in(eltern, str(wb["name"]))
	var phase: String = str(wb["phase"])
	karte.add_child(Stil.matt("Phase: %s" % phase.capitalize(), Stil.S_KLEIN))
	if phase == "gruppe":
		var gnamen := ["A", "B", "C", "D"]
		var reihe := Stil.hbox(12)
		karte.add_child(reihe)
		for gi in range((wb["gruppen"] as Array).size()):
			var gruppe: Array = wb["gruppen"][gi]
			var gk := Bausteine.karte_in(reihe, "Gruppe %s" % gnamen[gi], true)
			Stil.karte_wurzel(gk).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sortiert := Spielplan.gruppen_tabelle_sortiert(wb, gruppe)
			var g := Stil.tabelle(["#", "Verein", "Sp", "P", "Diff"])
			gk.add_child(g)
			for i in range(sortiert.size()):
				var cid: String = str(sortiert[i])
				var z: Dictionary = wb["tabelle"].get(cid, Spielplan.leere_tabellenzeile())
				var farbe: Color = Stil.AKZENT if cid == Welt.mein_verein_id else (Stil.GRUEN if i < 2 else Stil.TEXT)
				g.add_child(Stil.text(str(i + 1), Stil.S_MINI, farbe))
				g.add_child(Stil.text(str(Welt.verein(cid).get("kurz", "")), Stil.S_MINI, farbe))
				g.add_child(Stil.text(str(int(z["sp"])), Stil.S_MINI, farbe))
				g.add_child(Stil.text(str(int(z["punkte"])), Stil.S_MINI, farbe))
				g.add_child(Stil.text("%+d" % (int(z["tore"]) - int(z["gegentore"])), Stil.S_MINI, farbe))
	elif phase == "ko":
		for p in wb.get("paarungen", []):
			var zeile := Stil.hbox(8)
			karte.add_child(zeile)
			zeile.add_child(Bausteine.vereinszeile(str(p["a"]), 20))
			zeile.add_child(Stil.matt("gegen"))
			zeile.add_child(Bausteine.vereinszeile(str(p["b"]), 20))
			zeile.add_child(Stil.dehner())
			var ergebnis := ""
			if str(p["hin"]) != "" and bool(Welt.partie(str(p["hin"]))["gespielt"]):
				var h: Dictionary = Welt.partie(str(p["hin"]))
				ergebnis += "Hin %d:%d  " % [int(h["tore_heim"]), int(h["tore_gast"])]
			if bool(Welt.partie(str(p["rueck"]))["gespielt"]):
				var r: Dictionary = Welt.partie(str(p["rueck"]))
				ergebnis += "Rück %d:%d" % [int(r["tore_heim"]), int(r["tore_gast"])]
			zeile.add_child(Stil.text(ergebnis if ergebnis != "" else "noch offen", Stil.S_KLEIN, Stil.TEXT_MATT))
	elif phase == "beendet":
		karte.add_child(Stil.text("Sieger: %s" % Welt.verein(str(wb.get("sieger", ""))).get("name", "—"), Stil.S_NORMAL, Stil.AKZENT))
	var teilnehmer: Array = wb.get("teilnehmer", [])
	if not teilnehmer.is_empty() and teilnehmer.has(Welt.mein_verein_id):
		karte.add_child(Stil.abzeichen("SIE SIND DABEI", Stil.GRUEN, true))


## Wie weit ein Pokal ist — in einer Zeile.
func _pokalstand(pokal: Dictionary) -> String:
	if bool(pokal.get("beendet", false)):
		return "Sieger: %s" % str(Welt.verein(str(pokal.get("sieger", ""))).get("name", "—"))
	var paarungen: Array = pokal.get("paarungen", [])
	if paarungen.is_empty():
		return "beginnt in dieser Saison"
	var uebrig: int = paarungen.size() * 2 + (pokal.get("freilose", []) as Array).size()
	return "%s · %d Mannschaften" % [Spielplan.pokalrunden_name(uebrig), uebrig]
