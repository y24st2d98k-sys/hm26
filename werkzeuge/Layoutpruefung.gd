extends Node
## Sucht Layoutfehler automatisch, statt sie auf Bildschirmfotos zu suchen.
##
## Ein abgeschnittener Text fällt auf einem Screenshot nur auf, wenn man
## genau hinsieht — und bei fünfundzwanzig Bildschirmen sieht irgendwann
## niemand mehr genau hin. Dieses Werkzeug geht jeden Bildschirm durch,
## vermisst jeden Knoten und meldet drei Dinge:
##
##   * Inhalt, der über den sichtbaren Bereich hinausragt
##   * Beschriftungen, die breiter sind als ihr Platz (also abgeschnitten)
##   * Knöpfe, die zu klein zum Treffen sind
##
## Aufruf: godot --headless res://werkzeuge/Layoutpruefung.tscn

## Mindestgröße einer anklickbaren Fläche. Alles darunter trifft man nicht
## zuverlässig — auch nicht mit der Maus.
const KLICKFLAECHE_MIN := 22.0  # etwas unter Stil.KLICKFLAECHE_MIN, damit Rundung nicht meldet

## Wie viel Überstand als Rundungsrest durchgeht.
const TOLERANZ := 1.5

var fehler: int = 0
var warnungen: int = 0

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var welt := Weltgenerator.erzeuge(2026, 90909)
	var cid: String = str(welt["ligen"]["l_de1"]["vereine"][0])
	# Der Spielplan mischt mit dem globalen Zufallsgenerator. Ohne feste Saat
	# misst jeder Lauf eine andere Welt, und ein Vergleich vorher/nachher
	# zeigt Unterschiede, die keine sind.
	seed(90909)
	Welt.neues_spiel(cid, {"vorname": "Lay", "nachname": "Out",
		"hintergrund": "spieler", "nation": "de", "alter": 45}, 90909)
	# Ein Stück Saison spielen, damit die Bildschirme echte Inhalte zeigen:
	# eine leere Tabelle hat noch nie ein Layout gesprengt.
	for i in range(90):
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
	_log("Geprüft am %s" % Welt.datum_text())
	_schlimmsten_fall_herstellen()

	# Zwei Zahlen als Argument setzen die Fenstergroesse. Das ist kein
	# Beiwerk: durch stretch/aspect="expand" haengt die nutzbare Breite am
	# Seitenverhaeltnis. Auf einem 4:3-Schirm bleiben von 1500 logischen Pixeln
	# nur rund 1253 uebrig, und was bei 16:9 gerade noch passt, ist dort
	# abgeschnitten. Geprueft gehoert beides.
	var wargs := OS.get_cmdline_user_args()
	var fenster := Vector2i(1680, 945)
	if wargs.size() >= 2 and str(wargs[0]).is_valid_int() and str(wargs[1]).is_valid_int():
		fenster = Vector2i(int(wargs[0]), int(wargs[1]))
	get_window().size = fenster
	var app: Node = load("res://ui/App.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app._zeige_start(false)
	await get_tree().process_frame

	# Nicht die Fenstergroesse in Pixeln, sondern die logische Zeichenflaeche.
	#
	# Das Spiel laeuft mit stretch/mode="canvas_items": der Inhalt wird auf das
	# Fenster skaliert, und was die Bildschirme an Platz haben, steht im
	# sichtbaren Rechteck des Viewports — nicht in der Pixelbreite des
	# Fensters. Wer gegen die Fensterbreite prueft, misst bei jeder anderen
	# Groesse als der Entwurfsgroesse Unsinn: bei 1280 Pixeln meldete diese
	# Pruefung fuenfhundert Fehler, die keine waren.
	var breite: float = get_viewport().get_visible_rect().size.x
	_log("Fenster %d x %d, Zeichenflaeche %d x %d" % [get_window().size.x, get_window().size.y,
		int(get_viewport().get_visible_rect().size.x), int(get_viewport().get_visible_rect().size.y)])
	for id in app.bildschirme.keys():
		app.zeige(str(id))
		app.bewegung_beenden()
		# Zwei Bilder abwarten: Container brauchen einen Durchlauf, um ihre
		# Kinder zu setzen, und einen zweiten für verschachtelte Container.
		await get_tree().process_frame
		await get_tree().process_frame
		var befunde: Array = []
		# Ein Bildschirm mit Reitern hat so viele Lagen, wie er Reiter hat.
		# Geprüft wird jede: ein Abschnitt, der zu breit ist, fällt sonst erst
		# auf, wenn ihn jemand aufschlägt.
		var gruppe := _reiter_finden(app.bildschirme[id])
		if gruppe != null:
			for o in gruppe.optionen:
				var rid: String = str((o as Dictionary)["id"])
				gruppe.zeige(rid)
				await get_tree().process_frame
				await get_tree().process_frame
				var teil: Array = []
				_pruefe(app.bildschirme[id], breite, teil)
				for t in teil:
					befunde.append("[%s] %s" % [rid, str(t)])
		else:
			_pruefe(app.bildschirme[id], breite, befunde)
		if befunde.is_empty():
			continue
		_log("")
		_log("— %s —" % str(id))
		# Fehler immer vollstaendig, Hinweise gekuerzt.
		#
		# Vorher stand hier eine Obergrenze von acht Zeilen fuer beides. Auf
		# einem Bildschirm mit achtzig harmlosen Hinweisen verschwand der
		# einzige echte Fehler hinter "und 74 weitere" — die Sonde zaehlte ihn,
		# nannte ihn aber nicht.
		var echte: Array = []
		var milde: Array = []
		for b in befunde:
			if str(b).contains("FEHLER"):
				echte.append(b)
			else:
				milde.append(b)
		for b in echte:
			_log("   %s" % str(b))
		for b in milde.slice(0, 8):
			_log("   %s" % str(b))
		if milde.size() > 8:
			_log("   … und %d weitere Hinweise" % (milde.size() - 8))

	_log("")
	_log("%d Layoutfehler, %d Hinweise." % [fehler, warnungen])
	get_tree().quit()

func _pruefe(knoten: Node, fensterbreite: float, befunde: Array) -> void:
	_spalten_pruefen(knoten, befunde)
	for kind in knoten.get_children():
		if kind is Control and kind.visible:
			_pruefe_control(kind, fensterbreite, befunde)
		_pruefe(kind, fensterbreite, befunde)

## Fluchten die Spalten einer Tabelle?
##
## Zeilen, die als HBox gebaut sind, geben ihren Zellen nur eine
## Mindestbreite. Das ist ein Minimum, kein Maximum: eine Zelle mit etwas mehr
## Inhalt — ein zweites Statusabzeichen genuegt — waechst darueber hinaus und
## schiebt den Rest der Zeile nach rechts. Im Kaderbildschirm standen dadurch
## einzelne Zeilen sichtbar versetzt zu allen anderen, und keine der bisherigen
## Pruefungen hat es bemerkt: nichts ragte ueber den Rand, kein Text war zu
## breit fuer sein Feld, jede Zeile fuer sich war in Ordnung.
##
## Diese Pruefung vergleicht deshalb Zeilen untereinander. Geschwister-HBoxen
## mit gleich vielen Zellen muessen ihre Zellen an denselben x-Positionen
## haben.
const SPALTEN_TOLERANZ := 2.0

## Erkennt eine gebaute Tabellenzeile daran, dass jede Zelle eine Spaltenbreite
## mitbringt. Wer Breiten angibt, will Spalten — eine gewoehnliche Zeile aus
## Etikett, Text und Knopf tut das nicht, und die darf ruhig unterschiedlich
## breit sein.
## Die Tabellenzeile in diesem Knoten — er selbst, oder die einzige HBox
## hoechstens zwei Ebenen darunter.
func _zeile_in(knoten: Node) -> Node:
	if knoten is HBoxContainer and (knoten as Control).visible \
			and knoten.get_child_count() >= 4:
		return knoten
	if not (knoten is Control) or not (knoten as Control).visible:
		return null
	for tiefe in range(2):
		if knoten.get_child_count() != 1:
			return null
		knoten = knoten.get_child(0)
		if knoten is HBoxContainer and (knoten as Control).visible \
				and knoten.get_child_count() >= 4:
			return knoten
		if not (knoten is Control):
			return null
	return null

func _hat_spaltenbreiten(zeile: Node) -> bool:
	for kind in zeile.get_children():
		var c := kind as Control
		if c == null or c.custom_minimum_size.x <= 0.0:
			return false
	return true

func _spalten_pruefen(eltern: Node, befunde: Array) -> void:
	var zeilen: Array = []
	for kind in eltern.get_children():
		# Eine Tabellenzeile steckt oft in einem Knopf oder einem Panel — der
		# erste Entwurf suchte nur nach Geschwister-HBoxen und fand deshalb
		# ausgerechnet den Kaderbildschirm nicht, in dem jede Zeile ein
		# anklickbarer Knopf ist.
		var z := _zeile_in(kind)
		if z != null:
			zeilen.append(z)
	if zeilen.size() < 3:
		return
	# Nur Zeilen mit gleicher Zellenzahl vergleichen — alles andere ist keine
	# Tabelle, sondern eine Liste verschiedener Dinge.
	var muster: int = (zeilen[0] as Node).get_child_count()
	var gleich: Array = []
	for z in zeilen:
		if (z as Node).get_child_count() == muster and _hat_spaltenbreiten(z):
			gleich.append(z)
	if gleich.size() < 3:
		return
	var erste: Node = gleich[0]
	for i in range(1, gleich.size()):
		var z: Node = gleich[i]
		for sp in range(muster):
			var a := erste.get_child(sp) as Control
			var b := z.get_child(sp) as Control
			if a == null or b == null or not a.visible or not b.visible:
				continue
			if absf(a.position.x - b.position.x) > SPALTEN_TOLERANZ:
				fehler += 1
				befunde.append("Spalte %d verrutscht: %s steht bei x=%.0f, in der ersten Zeile bei x=%.0f" % [
					sp + 1, _beschreibe(b), b.position.x, a.position.x])
				return

func _pruefe_control(c: Control, fensterbreite: float, befunde: Array) -> void:
	var rechts: float = c.global_position.x + c.size.x
	# Überstand nach rechts: der Inhalt ist außerhalb des Fensters.
	#
	# Ausser er liegt in einem Behaelter, der abschneidet: Stil.beschnitten()
	# setzt genau das absichtlich ein, damit eine lange Beschriftung ihre
	# Spalte nicht auseinanderdrueckt. Das Etikett ist dann breiter als sein
	# Rahmen, gezeichnet wird aber nur, was hineinpasst. Das ist ein Hinweis
	# wert, kein Fehler — Fehler ist ein Layout, das wirklich aus dem Bild
	# laeuft.
	if rechts > fensterbreite + TOLERANZ and c.size.x > 4.0:
		if _wird_abgeschnitten(c):
			warnungen += 1
			befunde.append("Hinweis beschnitten (bewusst): %s" % _beschreibe(c))
		else:
			fehler += 1
			befunde.append("FEHLER  ragt %d px über den rechten Rand: %s" % [
				int(rechts - fensterbreite), _beschreibe(c)])
	# Abgeschnittene Beschriftung.
	if c is Label:
		var l: Label = c
		if l.text.strip_edges() != "" and l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var noetig: float = l.get_theme_font("font").get_string_size(
				l.text, l.horizontal_alignment, -1, l.get_theme_font_size("font_size")).x
			if noetig > l.size.x + TOLERANZ:
				if l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
					warnungen += 1
					befunde.append("Hinweis abgeschnitten (bewusst): „%s“" % _kurz(l.text))
				else:
					fehler += 1
					befunde.append("FEHLER  Text passt nicht (%d von %d px): „%s“" % [
						int(l.size.x), int(noetig), _kurz(l.text)])
	# Zu kleine Klickfläche.
	if c is Button and c.visible and not c.disabled:
		if c.size.y > 0.5 and c.size.y < KLICKFLAECHE_MIN:
			warnungen += 1
			befunde.append("Hinweis Klickfläche nur %d px hoch: „%s“" % [int(c.size.y), _kurz(c.text)])

func _beschreibe(c: Control) -> String:
	if c is Label:
		return "Label „%s“" % _kurz((c as Label).text)
	if c is Button:
		return "Knopf „%s“" % _kurz((c as Button).text)
	return c.get_class()

func _kurz(t: String) -> String:
	var eine_zeile := t.replace("\n", " ")
	return eine_zeile if eine_zeile.length() <= 42 else eine_zeile.substr(0, 40) + "…"

## Stellt den Zustand her, in dem am meisten in eine Zeile muss.
##
## Eine Layoutpruefung findet nur, was der gerade vorliegende Spielstand
## hergibt. Der Fehler, der zu dieser Pruefung gefuehrt hat — verrutschte
## Spalten im Kaderbildschirm — tritt erst auf, wenn ein Spieler zwei oder drei
## Statusabzeichen traegt, und ob nach 90 simulierten Tagen zufaellig einer
## verletzt und ueberlastet ist, entscheidet der Zufall. Ein Test, der nur
## manchmal prueft, prueft nicht.
##
## Deshalb wird der ungünstigste Fall hergestellt: die ersten Spieler des
## eigenen Kaders bekommen alles gleichzeitig, was ein Abzeichen erzeugt, und
## dazu die laengsten Namen.
func _schlimmsten_fall_herstellen() -> void:
	if Welt.mein_verein_id == "":
		return
	var kader: Array = Welt.mein_verein()["kader"]
	for i in range(mini(3, kader.size())):
		var sp: Dictionary = Welt.spieler(str(kader[i]))
		# Genau die Form, die Medizin.verletzen() anlegt — ein von Hand
		# zusammengesteckter Eintrag ohne "rest" liess verletzungstext()
		# auflaufen, und der Test meldete einen Fehler, den es im Spiel nicht
		# gibt.
		sp["verletzung"] = {"art": "Muskelfaserriss", "tage": 12, "rest": 12.0,
			"schwere": 2, "im_spiel": false, "seit_tag": Welt.tag()}
		sp["last"] = 88.0
		sp["transferwunsch"] = true
		sp["auf_transferliste"] = true
		sp["bei_nationalmannschaft"] = true
		sp["vertrag"]["bis_saison"] = Welt.saison_index()
		# Ein langer, aber realistischer Name. Der erste Versuch nahm einen
		# 51 Zeichen langen Fantasienamen und meldete daraufhin 129 Fehler —
		# richtig gemessen, aber am wirklichen Kader vorbei: der laengste Name
		# im Datensatz ist "Gísli Þorgeir Kristjánsson" mit 26 Zeichen. Ein
		# Test, der Faelle erfindet, die es nicht gibt, erzeugt Arbeit statt
		# Erkenntnis. Dreissig Zeichen sind die ehrliche Obergrenze.
		sp["vorname"] = "Maximilian"
		sp["nachname"] = "Löwenstein-Wertheim"

## Die Reitergruppe eines Bildschirms, falls er eine hat.
func _reiter_finden(k: Node) -> Stil.Reitergruppe:
	if k is Stil.Reitergruppe:
		return k as Stil.Reitergruppe
	for kind in k.get_children():
		var t := _reiter_finden(kind)
		if t != null:
			return t
	return null

## Liegt dieser Knoten in einem Behaelter, der seinen Inhalt abschneidet?
func _wird_abgeschnitten(c: Control) -> bool:
	var eltern := c.get_parent()
	while eltern != null and eltern is Control:
		if (eltern as Control).clip_contents:
			return true
		eltern = eltern.get_parent()
	return false
