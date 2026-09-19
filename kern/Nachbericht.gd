class_name Nachbericht
extends RefCounted
## Was nach dem Schlusspfiff zu sagen ist.
##
## Bis hierher endete eine Partie, und das Ergebnis war eine Zeile in einer
## Tabelle. Das ist der haeufigste Moment im ganzen Spiel — alle drei, vier
## Tage — und der emotional aufgeladenste, und er war der leerste.
##
## Dieser Bestand rechnet nichts neu. Alles steht im Bericht der Partie: die
## Schluesselszenen, die Einzelnoten, die Spielzeiten, die Zeitstrafen. Es
## wurde nur nie zu einer Geschichte zusammengesetzt.

## Ab wann eine Einzelnote etwas heisst. Wer vier Minuten spielt, hat keine
## Leistung gezeigt, sondern einen Kurzeinsatz.
const MINDESTZEIT := 600.0
## Ab wann jemand als durchgespielt gilt.
const DURCHGESPIELT := 3000.0

## Alles, was der Nachbericht zeigt. Leer, wenn die Partie nicht die eigene war
## oder kein Bericht vorliegt.
static func lesen(d: Dictionary, mid: String, cid: String) -> Dictionary:
	var m: Dictionary = (d.get("spiele", {}) as Dictionary).get(mid, {})
	if m.is_empty() or cid == "":
		return {}
	var bericht: Dictionary = m.get("bericht", {})
	if bericht.is_empty():
		return {}
	var heim: bool = str(m["heim"]) == cid
	if not heim and str(m["gast"]) != cid:
		return {}
	var eigene: Dictionary = bericht.get("heim" if heim else "gast", {})
	var fremde: Dictionary = bericht.get("gast" if heim else "heim", {})
	var tore: int = int(m["tore_heim"] if heim else m["tore_gast"])
	var gegentore: int = int(m["tore_gast"] if heim else m["tore_heim"])
	return {
		"spiel": m,
		"heimspiel": heim,
		"gegner": str(m["gast"]) if heim else str(m["heim"]),
		"tore": tore,
		"gegentore": gegentore,
		"ausgang": "sieg" if tore > gegentore else ("remis" if tore == gegentore else "niederlage"),
		"szenen": bericht.get("szenen", []),
		"spieler_des_spiels": str(bericht.get("spieler_des_spiels", "")),
		"zuschauer": int(bericht.get("zuschauer", 0)),
		"noten": _noten(d, eigene),
		"kosten": _kosten(d, cid, eigene),
		"saetze": _saetze(d, m, eigene, fremde, tore, gegentore, heim),
	}

## Die Einzelnoten der eigenen Mannschaft, beste zuerst. Kleiner ist besser.
static func _noten(d: Dictionary, seite: Dictionary) -> Array:
	var aus: Array = []
	for sid in (seite.get("spieler", {}) as Dictionary).keys():
		var e: Dictionary = seite["spieler"][sid]
		if float(e.get("sekunden", 0.0)) < MINDESTZEIT:
			continue
		if not (d["spieler"] as Dictionary).has(str(sid)):
			continue
		aus.append({
			"id": str(sid), "note": float(e.get("bewertung", 3.5)),
			"tore": int(e.get("tore", 0)), "paraden": int(e.get("paraden", 0)),
			"minuten": int(float(e.get("sekunden", 0.0)) / 60.0),
		})
	aus.sort_custom(func(a, b): return float(a["note"]) < float(b["note"]))
	return aus

## Was die Partie gekostet hat: frische Verletzungen, Strafen, Dauerlaeufer.
static func _kosten(d: Dictionary, cid: String, seite: Dictionary) -> Dictionary:
	var heute: int = int(d.get("tag", 0))
	var verletzt: Array = []
	for sid in Welt.kader(cid):
		var sp: Dictionary = (d["spieler"] as Dictionary).get(str(sid), {})
		if sp.is_empty():
			continue
		var verl: Dictionary = sp.get("verletzung", {})
		if verl.is_empty() or int(verl.get("seit_tag", -1)) != heute:
			continue
		verletzt.append({"id": str(sid), "art": str(verl.get("art", "Blessur")),
			"tage": int(verl.get("tage", 0))})
	var dauerlaeufer: Array = []
	for sid2 in (seite.get("spieler", {}) as Dictionary).keys():
		var e: Dictionary = seite["spieler"][sid2]
		if float(e.get("sekunden", 0.0)) >= DURCHGESPIELT:
			dauerlaeufer.append(str(sid2))
	var st: Dictionary = seite.get("stats", {})
	return {
		"verletzt": verletzt,
		"dauerlaeufer": dauerlaeufer,
		"zeitstrafen": int(st.get("zeitstrafen", 0)),
		"rote": int(st.get("rote", 0)),
	}

## Drei bis fünf Sätze, die die Partie erzählen.
##
## Sie stehen bewusst als Text und nicht als Kennzahlenreihe: eine Tabelle mit
## zwölf Werten liest man einmal, einen Satz über den eigenen Torwart liest man
## zu Ende.
static func _saetze(d: Dictionary, m: Dictionary, eigene: Dictionary, fremde: Dictionary,
		tore: int, gegentore: int, heim: bool) -> Array:
	var aus: Array = []
	var gegner: String = str(Welt.verein(str(m["gast"]) if heim else str(m["heim"])).get("name", "?"))
	var abstand: int = tore - gegentore
	if abstand >= 8:
		aus.append("Das war nie ein Spiel. %s hatte nach der Pause nichts mehr entgegenzusetzen." % gegner)
	elif abstand > 0 and abstand <= 2:
		aus.append("Ein Sieg, der bis zur Sirene auf der Kippe stand.")
	elif abstand > 2:
		aus.append("Ein Sieg mit %d Toren Abstand — die Partie war vor dem Ende entschieden." % abstand)
	elif abstand == 0:
		aus.append("Ein Punkt, der sich wie ein halber anfühlt.")
	elif abstand >= -2:
		aus.append("Eine Niederlage um %d Tore. Nah dran ist nicht vorbei." % absi(abstand))
	else:
		aus.append("Eine deutliche Niederlage. %s war über sechzig Minuten die bessere Mannschaft." % gegner)

	var e_st: Dictionary = eigene.get("stats", {})
	var f_st: Dictionary = fremde.get("stats", {})
	# Statistik.wurfquote liefert Prozent, keinen Anteil. Ohne diese Zeile
	# stand im Bericht "7963 Prozent der Würfe saßen".
	var quote: float = Statistik.wurfquote(e_st)
	var gegenquote: float = Statistik.wurfquote(f_st)
	if quote >= 66.0:
		aus.append("Im Angriff lief es: %.0f Prozent der Würfe saßen." % quote)
	elif quote <= 52.0 and quote > 0.0:
		aus.append("Der Angriff traf nur %.0f Prozent — zu wenig, um ein Spiel zu gewinnen." % quote)
	var paraden: int = int(e_st.get("paraden", 0))
	if paraden >= 14:
		aus.append("Der Torhüter hielt %d Bälle. Ohne ihn wäre das anders ausgegangen." % paraden)
	elif gegenquote >= 68.0:
		aus.append("Die Abwehr ließ %.0f Prozent Trefferquote zu — da hilft auch der beste Torwart nicht." % gegenquote)
	var fehler: int = int(e_st.get("technische_fehler", 0))
	if fehler >= 14:
		aus.append("%d technische Fehler sind %d verschenkte Angriffe." % [fehler, fehler])
	var strafen: int = int(e_st.get("zeitstrafen", 0))
	if strafen >= 6:
		aus.append("%d Zeitstrafen bedeuten zwölf Minuten Unterzahl. Das ist kein Zufall, das ist die eingestellte Härte." % strafen)
	return aus

## Der Vorschlag des Co-Trainers: wen man ansprechen sollte und warum.
static func ansprache_vorschlag(noten: Array) -> Dictionary:
	if noten.is_empty():
		return {}
	var beste: Dictionary = noten[0]
	var schwaechste: Dictionary = noten[noten.size() - 1]
	var aus := {}
	if float(beste["note"]) <= 2.6:
		aus["lob"] = beste
	if float(schwaechste["note"]) >= 4.4 and noten.size() > 2:
		aus["kritik"] = schwaechste
	return aus
