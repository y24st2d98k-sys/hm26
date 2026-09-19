class_name AnalyseBildschirm
extends Bildschirm
## Saisonanalyse: was die eigene Mannschaft über eine ganze Spielzeit auszeichnet.
##
## Der Spielbericht zeigt eine Partie. Hier steht, wo über Wochen abgeschlossen
## wird, wann Tore fallen und wer in Form kommt oder abfällt.

var inhalt: VBoxContainer
var eigene_wuerfe: bool = true
## Welcher Reiter offen steht — ueberlebt den Wechsel zwischen eigenen und
## gegnerischen Wuerfen.
var reiter := "mannschaft"

func aufbauen() -> void:
	var v := Stil.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var kopf := Stil.hbox(10)
	v.add_child(kopf)
	kopf.add_child(Stil.titel("Saisonanalyse", 0))
	kopf.add_child(Stil.dehner())
	kopf.add_child(Stil.segmente([
		{"id": "eigene", "name": "Unsere Würfe"}, {"id": "gegner", "name": "Würfe der Gegner"}],
		"eigene" if eigene_wuerfe else "gegner", func(id):
			eigene_wuerfe = str(id) == "eigene"
			aktualisieren()))
	# Kein Rollbereich um den ganzen Bildschirm: die Reiter bringen ihren
	# eigenen mit, und zwei ineinander sind einer zu viel.
	inhalt = Stil.vbox(12)
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(inhalt)

func aktualisieren() -> void:
	if inhalt == null:
		return
	leeren(inhalt)
	if Welt.mein_verein_id == "":
		inhalt.add_child(Stil.matt("Sie haben derzeit keinen Verein."))
		return
	var cid := Welt.mein_verein_id
	var partien: Array = Saisonanalyse.partien(Welt.daten, cid)
	if partien.is_empty():
		inhalt.add_child(Stil.leerzustand("In dieser Saison ist noch kein Spiel ausgetragen."))
		return
	inhalt.add_child(Stil.matt("Ausgewertet werden %d Partien dieser Saison." % partien.size(), Stil.S_MINI))
	# Drei Reiter statt eines Stapels von drei Bildschirmhoehen. Mannschaft,
	# Spieler und Gespanne beantworten verschiedene Fragen — wer wissen will,
	# wer gerade in Form ist, will nicht an der Wurfkarte vorbeiscrollen.
	var gruppe := Stil.reitergruppe([
		{"id": "mannschaft", "name": "Mannschaft"},
		{"id": "spieler", "name": "Spieler"},
		{"id": "gespanne", "name": "Gespanne"},
	], reiter)
	gruppe.bei_wechsel = func(id): reiter = str(id)
	inhalt.add_child(gruppe)
	# Drei Spalten: Kennzahlen, Wurfkarte und Torverlauf sind drei Fragen und
	# stehen zusammen genau einmal ins Fenster. Zu zweit lief der Torverlauf
	# unter den Falz.
	var oben := Stil.hbox(12)
	gruppe.feld("mannschaft").add_child(oben)
	var links := Stil.vbox(12)
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(links)
	var mitte := Stil.vbox(12)
	mitte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(mitte)
	var rechts := Stil.vbox(12)
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oben.add_child(rechts)
	_kennzahlen(links, cid)
	_wurfkarte(mitte, cid)
	_torverlauf(rechts, cid)
	_formtabelle(gruppe.feld("spieler"), cid)
	_gespanne(gruppe.feld("gespanne"))

## Die eigenen Werte gegen den Ligaschnitt.
func _kennzahlen(eltern: Node, cid: String) -> void:
	var werte: Array = Saisonanalyse.kennzahlen(Welt.daten, cid)
	if werte.is_empty():
		return
	var karte := Bausteine.karte_in(eltern, "Kennzahlen gegen den Ligaschnitt")
	var g := Stil.tabelle(["Kennzahl", "Wir", "Liga", "Abstand"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for w in werte:
		g.add_child(Stil.text(str(w["name"]), Stil.S_KLEIN))
		g.add_child(Stil.text(Stil.komma(float(w["eigen"]), 1), Stil.S_KLEIN))
		g.add_child(Stil.matt(Stil.komma(float(w["liga"]), 1), Stil.S_KLEIN))
		var delta: float = float(w["eigen"]) - float(w["liga"])
		var gut: bool = delta < 0.0 if bool(w["niedriger_besser"]) else delta > 0.0
		g.add_child(Stil.text("%s%s" % ["+" if delta >= 0.0 else "", Stil.komma(delta, 1)],
			Stil.S_KLEIN, Stil.GRUEN if gut else (Stil.ROT if absf(delta) > 0.05 else Stil.TEXT_MATT)))

## Wo über die Saison abgeschlossen wurde.
func _wurfkarte(eltern: Node, cid: String) -> void:
	var karte := Saisonanalyse.wurfkarte(Welt.daten, cid, eigene_wuerfe)
	var k := Bausteine.karte_in(eltern, "Abschlüsse der Saison")
	Stil.karte_wurzel(k).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if karte.is_empty():
		k.add_child(Stil.leerzustand("Für diese Partien liegen keine Wurfkarten im Archiv."))
		return
	var farbe: Color = Welt.verein(cid).get("wappen", {}).get("a", Stil.AKZENT)
	var bild := Wurfkarte.neu(karte, farbe if eigene_wuerfe else Stil.ROT, 296.0)
	bild.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_child(bild)
	k.add_child(Stil.matt("Kreisgröße: Würfe · Füllung: Trefferquote", Stil.S_MINI))
	var g := Stil.tabelle(["Position", "Würfe", "Tore", "Quote"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_child(g)
	for e in Saisonanalyse.positionsquoten(karte):
		g.add_child(Stil.text(str(Spielerfabrik.POSITION_NAME.get(str(e["position"]), str(e["position"]))), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(e["wuerfe"])), Stil.S_KLEIN))
		g.add_child(Stil.text(str(int(e["tore"])), Stil.S_KLEIN))
		g.add_child(Stil.text("%d %%" % int(float(e["quote"])), Stil.S_KLEIN,
			Stil.prozent_farbe(float(e["quote"]) * 1.4)))

## Wann Tore fallen — und wann sie kassiert werden.
func _torverlauf(eltern: Node, cid: String) -> void:
	var werte: Array = Saisonanalyse.torverlauf(Welt.daten, cid)
	var k := Bausteine.karte_in(eltern, "Tore nach Spielabschnitt")
	Stil.karte_wurzel(k).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var groesste := 1
	for w in werte:
		groesste = maxi(groesste, maxi(int(w["tore"]), int(w["gegentore"])))
	if groesste <= 1:
		k.add_child(Stil.leerzustand("Der Spielverlauf steht nur für eigene Partien im Archiv."))
		return
	for w2 in werte:
		var zeile := Stil.hbox(8)
		k.add_child(zeile)
		var l := Stil.matt("%s min" % str(w2["name"]), Stil.S_KLEIN)
		l.custom_minimum_size = Vector2(64, 0)
		zeile.add_child(l)
		zeile.add_child(Stil.balken(float(w2["tore"]), float(groesste), 110, Stil.GRUEN))
		zeile.add_child(Stil.text(str(int(w2["tore"])), Stil.S_KLEIN, Stil.GRUEN))
		zeile.add_child(Stil.balken(float(w2["gegentore"]), float(groesste), 110, Stil.ROT))
		zeile.add_child(Stil.text(str(int(w2["gegentore"])), Stil.S_KLEIN, Stil.ROT))
		var diff: int = int(w2["tore"]) - int(w2["gegentore"])
		zeile.add_child(Stil.text("%s%d" % ["+" if diff >= 0 else "", diff], Stil.S_KLEIN,
			Stil.GRUEN if diff > 0 else (Stil.ROT if diff < 0 else Stil.TEXT_MATT)))
	k.add_child(Stil.matt("Grün: eigene Tore. Rot: Gegentore. Wo Rot überwiegt, geht das Spiel verloren.", Stil.S_MINI))

## Wer in Form kommt und wer abfällt.
func _formtabelle(eltern: Node, cid: String) -> void:
	var liste: Array = Saisonanalyse.formtabelle(Welt.daten, cid)
	var karte := Bausteine.karte_in(eltern, "Form über die Saison")
	if liste.is_empty():
		karte.add_child(Stil.leerzustand("Noch zu wenige Einsätze für eine Formkurve."))
		return
	karte.add_child(Stil.matt("Verglichen wird der Saisonschnitt mit den letzten drei Partien. Kleinere Note ist besser.", Stil.S_MINI))
	var g := Stil.tabelle(["Spieler", "Pos", "Spiele", "Schnitt", "letzte 3", "Tendenz"])
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(g)
	for e in liste:
		var sid: String = str(e["spieler"])
		var sp: Dictionary = Welt.spieler(sid)
		var knopf := Stil.knopf_flach(Spielerfabrik.voller_name(sp))
		knopf.pressed.connect(func(): Spielerfenster.oeffnen(self, sid))
		g.add_child(knopf)
		g.add_child(Bausteine.positions_abzeichen(str(sp["position"])))
		g.add_child(Stil.matt(str(int(e["spiele"])), Stil.S_KLEIN))
		g.add_child(Stil.text(Stil.komma(float(e["schnitt"]), 2), Stil.S_KLEIN,
			Stil.wert_farbe(6.0 - float(e["schnitt"]), 5.0)))
		g.add_child(Stil.text(Stil.komma(float(e["zuletzt"]), 2), Stil.S_KLEIN,
			Stil.wert_farbe(6.0 - float(e["zuletzt"]), 5.0)))
		var t: float = float(e["tendenz"])
		var pfeil: String = "steigend" if t > 0.12 else ("fallend" if t < -0.12 else "gleichbleibend")
		g.add_child(Stil.text(pfeil, Stil.S_KLEIN,
			Stil.GRUEN if t > 0.12 else (Stil.ROT if t < -0.12 else Stil.TEXT_MATT)))


## Die Gespanne, nach Strenge sortiert.
##
## Diese Tabelle ist kein Zierrat: wer weiß, dass ein Duo im Schnitt fünf
## Zeitstrafen verteilt, stellt vor dem Spiel die Härte anders ein. Aufgeführt
## werden nur Gespanne, die schon gepfiffen haben — über die anderen wäre jede
## Aussage erfunden.
func _gespanne(eltern: Node) -> void:
	var liste: Array = []
	for g in Schiedsrichter.alle(Welt.daten):
		if int((g as Dictionary)["spiele"]) > 0:
			liste.append(g)
	if liste.is_empty():
		return
	var karte := Bausteine.karte_in(eltern, "Die Gespanne")
	karte.add_child(Stil.matt(
		"Wer viel pfeift, macht harte Abwehr teuer. Der Vorbericht nennt vor jedem Spiel das angesetzte Duo.",
		Stil.S_MINI))
	# Zwei Tabellen nebeneinander statt einer langen: zwei Dutzend Gespanne
	# untereinander reichen ueber den Bildschirmrand, und wer sein angesetztes
	# Duo sucht, will nicht rollen.
	var reihe := Stil.hbox(Stil.A_GROSS)
	reihe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte.add_child(reihe)
	var haelfte: int = int(ceil(float(liste.size()) / 2.0))
	var tabellen: Array = []
	for i in 2:
		var t := Stil.tabelle(["Gespann", "Sp", "Zeitstr.", "7m", "Rot", "Ruf"])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reihe.add_child(t)
		tabellen.append(t)
	var nummer := 0
	for g in liste:
		var gr: GridContainer = tabellen[0] if nummer < haelfte else tabellen[1]
		nummer += 1
		var q: float = Schiedsrichter.zeitstrafen_quote(g)
		var farbe: Color = Stil.prozent_farbe(clampf(100.0 - (q - 2.0) * 24.0, 0.0, 100.0))
		gr.add_child(Stil.text(Schiedsrichter.namen(g), Stil.S_KLEIN))
		gr.add_child(Stil.matt(str(int(g["spiele"])), Stil.S_KLEIN))
		gr.add_child(Stil.text("%.1f" % q, Stil.S_KLEIN, farbe))
		gr.add_child(Stil.matt("%.1f" % Schiedsrichter.siebenmeter_quote(g), Stil.S_KLEIN))
		gr.add_child(Stil.matt(str(int(g["rote"])), Stil.S_KLEIN))
		gr.add_child(Stil.text(Schiedsrichter.ruf(g), Stil.S_KLEIN, farbe))
