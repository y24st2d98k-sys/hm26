class_name Medien
extends RefCounted
## Presse und "Hallenfunk" (das soziale Netz des Spiels).
##
## Beitraege entstehen nicht zufaellig, sondern aus dem, was tatsaechlich passiert ist:
## Hoehe des Ergebnisses, Derbycharakter, Serie, Einzelleistungen, Zuschauerzahl,
## Vorstandslage und Tabellensituation fliessen in Schlagzeile und Tonfall ein.

const TONFALL_FARBE := {"jubel": "gruen", "lob": "gruen", "neutral": "matt", "kritik": "gelb", "verriss": "rot"}

# ------------------------------------------------------------- Grundlagen ---

static func _outlet(d: Dictionary, nation: String) -> Dictionary:
	var passend: Array = []
	for o in d["medien"]["outlets"]:
		if str(o["nation"]) == nation:
			passend.append(o)
	if passend.is_empty():
		passend = d["medien"]["outlets"]
	if passend.is_empty():
		return {"name": "Hallenzeit", "haltung": "nüchtern", "reichweite": 50.0}
	return passend[Namen.wuerfel(0, passend.size() - 1)]

static func artikel(d: Dictionary, schlagzeile: String, text: String, tonfall: String, thema: String, bezug: Dictionary = {}) -> void:
	var nation: String = str(d["vereine"].get(Welt.mein_verein_id, {}).get("nation", "de"))
	var o := _outlet(d, nation)
	var eintrag := {
		"tag": int(d["tag"]),
		"outlet": str(o["name"]),
		"haltung": str(o["haltung"]),
		"schlagzeile": schlagzeile,
		"text": text,
		"tonfall": tonfall,
		"thema": thema,
		"bezug": bezug,
	}
	(d["presse"] as Array).push_front(eintrag)
	if (d["presse"] as Array).size() > 200:
		(d["presse"] as Array).resize(200)

static func beitrag(d: Dictionary, text: String, tonfall: String, typ_filter: Array = []) -> void:
	var accounts: Array = d["medien"]["fanaccounts"]
	if accounts.is_empty():
		return
	var kandidaten: Array = []
	for a in accounts:
		if typ_filter.is_empty() or typ_filter.has(str(a["typ"])):
			kandidaten.append(a)
	if kandidaten.is_empty():
		kandidaten = accounts
	var a2: Dictionary = kandidaten[Namen.wuerfel(0, kandidaten.size() - 1)]
	(d["social"] as Array).push_front({
		"tag": int(d["tag"]),
		"handle": str(a2["handle"]),
		"typ": str(a2["typ"]),
		"text": text,
		"tonfall": tonfall,
		"gefaellt": Namen.wuerfel(3, int(float(a2["folgen"]) / 12.0) + 20),
	})
	if (d["social"] as Array).size() > 250:
		(d["social"] as Array).resize(250)

# ---------------------------------------------------------- Spielberichte ---

static func spielbericht(d: Dictionary, m: Dictionary, cid: String) -> void:
	if str(m["art"]) == "turnier":
		return
	if str(m["art"]) == "test":
		_testspielnotiz(d, m, cid)
		return
	var ist_heim: bool = str(m["heim"]) == cid
	var eigene: int = int(m["tore_heim"]) if ist_heim else int(m["tore_gast"])
	var fremde: int = int(m["tore_gast"]) if ist_heim else int(m["tore_heim"])
	var gegner_id: String = str(m["gast"]) if ist_heim else str(m["heim"])
	var v: Dictionary = d["vereine"][cid]
	var g: Dictionary = d["vereine"][gegner_id]
	var abstand: int = eigene - fremde
	var derby: bool = float((v["rivalen"] as Dictionary).get(gegner_id, 0.0)) > 45.0
	var wettbewerb: String = Welt.wettbewerb_name(str(m["wettbewerb"]))
	var serie: String = _serientext(v)
	var held := _held(d, m, cid)

	var schlagzeile := _schlagzeile(v, g, abstand, eigene, fremde, derby, str(m["art"]), held, d)
	var text := _bericht_text(d, m, cid, abstand, derby, wettbewerb, held, serie)
	var tonfall := "jubel" if abstand >= 6 else ("lob" if abstand > 0 else ("neutral" if abstand == 0 else ("kritik" if abstand > -6 else "verriss")))
	artikel(d, schlagzeile, text, tonfall, "spiel", {"spiel": str(m["id"]), "verein": cid})
	_social_zum_spiel(d, m, cid, abstand, derby, held)

## Vorbereitungsspiele bekommen nur eine kurze Notiz statt eines Berichts.
static func _testspielnotiz(d: Dictionary, m: Dictionary, cid: String) -> void:
	if Namen.zufall() > 0.45:
		return
	var ist_heim: bool = str(m["heim"]) == cid
	var eigene: int = int(m["tore_heim"]) if ist_heim else int(m["tore_gast"])
	var fremde: int = int(m["tore_gast"]) if ist_heim else int(m["tore_heim"])
	var gegner: String = str(m["gast"]) if ist_heim else str(m["heim"])
	var texte := [
		"Erkenntnisse im Test gegen %s: Beim %d:%d wurde vor allem die Abwehr geprüft." % [d["vereine"][gegner]["name"], eigene, fremde],
		"Testspiel gegen %s endet %d:%d. Der Trainerstab verteilte die Spielzeit breit." % [d["vereine"][gegner]["name"], eigene, fremde],
		"%d:%d im Test gegen %s — Ergebnisse zählen in der Vorbereitung bekanntlich wenig." % [eigene, fremde, d["vereine"][gegner]["name"]],
	]
	artikel(d, "Vorbereitung: %d:%d gegen %s" % [eigene, fremde, d["vereine"][gegner]["name"]],
		str(texte[Namen.wuerfel(0, texte.size() - 1)]), "neutral", "vorbereitung", {"verein": cid})

static func _schlagzeile(v: Dictionary, g: Dictionary, abstand: int, eigene: int, fremde: int,
		derby: bool, art: String, held: Dictionary, d: Dictionary) -> String:
	var name: String = str(v["name"])
	var gname: String = str(g["name"])
	var ort: String = str(v["ort"])
	var beiname: String = str(v["beiname"]) if str(v["beiname"]) != "" else name
	var varianten: Array = []
	if abstand >= 9:
		varianten = [
			"Schützenfest in %s: %d:%d gegen %s" % [ort, eigene, fremde, gname],
			"%s demontiert %s" % [name, gname],
			"Kein Land in Sicht für %s — %d:%d" % [gname, eigene, fremde],
		]
	elif abstand >= 5:
		varianten = [
			"%s setzt sich klar durch" % name,
			"Deutlicher Sieg: %d:%d gegen %s" % [eigene, fremde, gname],
			"%s kontrolliert die Partie" % beiname,
		]
	elif abstand >= 3:
		varianten = ["%s gewinnt verdient mit %d:%d" % [name, eigene, fremde],
			"Sicherer Auftritt von %s" % name]
	elif abstand > 0:
		varianten = [
			"Zittersieg für %s" % name,
			"%d:%d — %s rettet den Vorsprung über die Zeit" % [eigene, fremde, name],
			"Hauchdünn: %s schlägt %s" % [name, gname],
		]
	elif abstand == 0:
		varianten = ["Punkteteilung zwischen %s und %s" % [name, gname],
			"%d:%d — beide Seiten bleiben unzufrieden" % [eigene, fremde]]
	elif abstand > -3:
		varianten = [
			"Knappe Niederlage für %s" % name,
			"%s verliert den Faden in der Schlussphase" % name,
			"%d:%d — %s fehlt der letzte Wurf" % [eigene, fremde, name],
		]
	elif abstand > -7:
		varianten = ["%s ohne Chance gegen %s" % [name, gname],
			"Klare Sache für %s" % gname]
	else:
		varianten = [
			"Debakel für %s" % name,
			"%d:%d — ein Abend zum Vergessen in %s" % [eigene, fremde, ort],
			"%s zerlegt %s" % [gname, name],
		]
	if derby:
		varianten.append("Derbytag in %s: %d:%d" % [ort, eigene, fremde])
		if abstand > 0:
			varianten.append("%s bleibt Herr im eigenen Haus" % name)
		elif abstand < 0:
			varianten.append("Derbypleite: %s jubelt in %s" % [gname, ort])
	if art == "pokal":
		varianten.append("Pokalabend: %s %s" % [name, "eine Runde weiter" if abstand > 0 else "raus"])
	if not held.is_empty() and abstand > 0:
		varianten.append("%s trägt %s zum Sieg" % [held["name"], name])
	return str(varianten[Namen.wuerfel(0, varianten.size() - 1)])

static func _bericht_text(d: Dictionary, m: Dictionary, cid: String, abstand: int, derby: bool,
		wettbewerb: String, held: Dictionary, serie: String) -> String:
	var bericht: Dictionary = m.get("bericht", {})
	var ist_heim: bool = str(m["heim"]) == cid
	var seite: String = "heim" if ist_heim else "gast"
	var stats: Dictionary = bericht.get(seite, {}).get("stats", {})
	var zuschauer: int = int(m.get("zuschauer", 0))
	var saetze: Array = []
	saetze.append("%s: %d:%d gegen %s vor %s Zuschauern." % [
		wettbewerb, int(m["tore_heim"]), int(m["tore_gast"]), d["vereine"][str(m["gast"]) if ist_heim else str(m["heim"])]["name"], Stil.zahl(zuschauer)])
	if derby:
		saetze.append("Die Rivalität war in jeder Szene zu spüren — die Halle stand von der ersten Minute unter Strom.")
	if not held.is_empty():
		saetze.append(str(held["satz"]))
	if not stats.is_empty():
		var zeitstrafen: int = int(stats.get("zeitstrafen", 0))
		var fehler: int = int(stats.get("technische_fehler", 0))
		if zeitstrafen >= 5:
			saetze.append("%d Zeitstrafen zeigen, wie hart die Deckung zu Werke ging." % zeitstrafen)
		if fehler >= 14:
			saetze.append("%d technische Fehler waren allerdings deutlich zu viel." % fehler)
		if int(stats.get("gegenstoss_tore", 0)) >= 6:
			saetze.append("Über den Tempogegenstoß kamen allein %d Treffer zustande." % int(stats["gegenstoss_tore"]))
	if serie != "":
		saetze.append(serie)
	var v: Dictionary = d["vereine"][cid]
	if float(v["vorstand"]["vertrauen"]) < 30.0 and abstand < 0:
		saetze.append("Im Umfeld wird die Frage lauter, wie lange der Vorstand noch zusieht.")
	elif float(v["vorstand"]["vertrauen"]) > 75.0 and abstand > 0:
		saetze.append("Die Arbeit des Trainerstabs wird im Verein derzeit ausdrücklich gelobt.")
	return " ".join(saetze)

static func _held(d: Dictionary, m: Dictionary, cid: String) -> Dictionary:
	var bericht: Dictionary = m.get("bericht", {})
	var seite: String = "heim" if str(m["heim"]) == cid else "gast"
	var spieler: Dictionary = bericht.get(seite, {}).get("spieler", {})
	var best := ""
	var bw := 0
	var tw := ""
	var paraden := 0
	for sid in spieler.keys():
		var z: Dictionary = spieler[sid]
		if int(z["tore"]) > bw:
			bw = int(z["tore"])
			best = sid
		if int(z["paraden"]) > paraden:
			paraden = int(z["paraden"])
			tw = sid
	if paraden >= 13 and tw != "" and d["spieler"].has(tw):
		var sp: Dictionary = d["spieler"][tw]
		return {"sid": tw, "name": Spielerfabrik.voller_name(sp),
			"satz": "%s hielt %d Bälle und war der Rückhalt des Abends." % [Spielerfabrik.voller_name(sp), paraden]}
	if bw >= 7 and best != "" and d["spieler"].has(best):
		var sp2: Dictionary = d["spieler"][best]
		return {"sid": best, "name": Spielerfabrik.voller_name(sp2),
			"satz": "%s war mit %d Treffern der auffälligste Spieler auf dem Parkett." % [Spielerfabrik.voller_name(sp2), bw]}
	return {}

static func _serientext(v: Dictionary) -> String:
	var kurve: Array = v["formkurve"]
	if kurve.size() < 3:
		return ""
	var letzte: String = str(kurve[-1])
	var anzahl := 0
	for i in range(kurve.size() - 1, -1, -1):
		if str(kurve[i]) == letzte:
			anzahl += 1
		else:
			break
	if anzahl < 3:
		return ""
	if letzte == "S":
		return "Damit steht %s bei %d Siegen in Folge." % [v["name"], anzahl]
	elif letzte == "N":
		return "Es ist bereits die %d. Niederlage nacheinander." % anzahl
	return "Das dritte Remis in Serie sorgt für Stirnrunzeln."

static func _social_zum_spiel(d: Dictionary, m: Dictionary, cid: String, abstand: int, derby: bool, held: Dictionary) -> void:
	var v: Dictionary = d["vereine"][cid]
	var anzahl: int = 2 + (2 if derby else 0) + (1 if absi(abstand) >= 7 else 0)
	for i in range(anzahl):
		var tonfall := "jubel" if abstand > 2 else ("neutral" if abstand >= 0 else "kritik")
		var texte: Array = []
		if abstand >= 7:
			texte = [
				"Was für ein Abend. So kann es weitergehen. #%s" % str(v["kurz"]),
				"Die Deckung stand heute wie eine Wand. Endlich mal wieder.",
				"Wenn wir so spielen, muss uns niemand Angst machen.",
			]
		elif abstand > 0:
			texte = [
				"Gewonnen ist gewonnen. Schön war es trotzdem nicht.",
				"Zwei Punkte mitgenommen, mehr zählt heute nicht.",
				"Der Kampfgeist stimmt. Am Abschluss müssen wir arbeiten.",
			]
		elif abstand == 0:
			texte = [
				"Ein Punkt, der sich wie eine Niederlage anfühlt.",
				"Wieder in der Schlussphase alles hergegeben. Das nervt.",
			]
		elif abstand > -6:
			texte = [
				"Knapp verloren ist auch verloren.",
				"Die Fehlwurfquote war heute nicht zu ertragen.",
				"Warum wechseln wir eigentlich nie früher?",
			]
		else:
			texte = [
				"Das war indiskutabel. Keine Gegenwehr, kein Plan.",
				"So eine Vorstellung darf man den Leuten nicht bieten.",
				"Ich habe für dieses Spiel einen halben Tag Urlaub genommen.",
			]
		if not held.is_empty() and Namen.zufall() < 0.4:
			texte.append("%s hat heute die Bude alleine zusammengehalten." % str(held["name"]))
		if derby and Namen.zufall() < 0.5:
			texte.append("Derby bleibt Derby. Die Stimmung war Gänsehaut pur.")
		beitrag(d, str(texte[Namen.wuerfel(0, texte.size() - 1)]), tonfall)

# --------------------------------------------------------------- Rhythmus ---

static func saisonauftakt(d: Dictionary, cid: String) -> void:
	if cid == "":
		return
	var v: Dictionary = d["vereine"][cid]
	var t: Dictionary = d["trainer"]
	artikel(d,
		"%s stellt %s vor" % [v["name"], Trainerkarriere.voller_name(t)],
		"%s übernimmt zur neuen Saison das Traineramt bei %s. Der Vorstand nennt als Ziel: %s. In der Halle an der %s erwartet man einen Neuanfang." % [
			Trainerkarriere.voller_name(t), v["name"], v["vorstand"]["saisonziel"], v["halle"]["name"]],
		"neutral", "verein", {"verein": cid})
	beitrag(d, "Neuer Trainer, neues Glück. Mal sehen, wie lange die Euphorie hält.", "neutral")
	beitrag(d, "Endlich geht es wieder los. Dauerkarte liegt bereit.", "jubel", ["dauerkarte", "ultra"])

static func wochenrueckblick(d: Dictionary, cid: String) -> void:
	if cid == "" or not d["vereine"].has(cid):
		return
	var v: Dictionary = d["vereine"][cid]
	var liga: Dictionary = d["ligen"][v["liga"]]
	var tabelle := Spielplan.tabelle_sortiert(d, str(liga["id"]))
	var platz: int = tabelle.find(cid) + 1
	if int(liga["tabelle"].get(cid, {}).get("sp", 0)) < 2:
		return
	if Namen.zufall() < 0.55:
		var ziel: int = int(v["vorstand"]["ziel_platz"])
		var tonfall := "lob" if platz <= ziel else "kritik"
		var kopf := "%s auf Platz %d — %s" % [v["name"], platz, "im Plan" if platz <= ziel else "unter den Erwartungen"]
		var text := "Nach %d Spieltagen steht %s auf Rang %d der %s. Das Saisonziel lautet %s." % [
			int(liga["tabelle"][cid]["sp"]), v["name"], platz, liga["name"], v["vorstand"]["saisonziel"]]
		var lazarett := Medizin.lazarett(d, cid)
		if lazarett.size() >= 3:
			text += " Die Verletztenliste ist mit %d Ausfällen ungewöhnlich lang." % lazarett.size()
		var klima: float = float(v["stimmung_kabine"])
		if klima < 42.0:
			text += " Aus der Kabine dringen unterdessen kritische Töne."
		elif klima > 74.0:
			text += " Die Mannschaft macht einen geschlossenen Eindruck."
		artikel(d, kopf, text, tonfall, "tabelle", {"verein": cid})

static func transfer_meldung(d: Dictionary, sid: String, von: String, nach: String, ablöse: float) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var vname: String = str(d["vereine"].get(von, {}).get("name", "vereinslos"))
	var nname: String = str(d["vereine"].get(nach, {}).get("name", "vereinslos"))
	artikel(d,
		"%s wechselt zu %s" % [Spielerfabrik.voller_name(sp), nname],
		"%s (%d, %s) verlässt %s und schließt sich %s an. Die Ablöse liegt bei %s." % [
			Spielerfabrik.voller_name(sp), int(sp["alter"]), Spielerfabrik.POSITION_NAME[str(sp["position"])],
			vname, nname, Stil.geld(ablöse)],
		"neutral", "transfer", {"spieler": sid})
	if nach == Welt.mein_verein_id:
		beitrag(d, "Endlich mal eine Verpflichtung, die Sinn ergibt. Willkommen, %s!" % str(sp["nachname"]), "jubel")
	elif von == Welt.mein_verein_id:
		beitrag(d, "%s weg. Und wer wirft jetzt die Tore?" % str(sp["nachname"]), "kritik")

static func geruecht(d: Dictionary, text: String) -> void:
	artikel(d, "Gerüchteküche", text, "neutral", "geruecht")

## Presse zu einem Titelgewinn oder Abstieg.
static func saisonfazit(d: Dictionary, cid: String, kopf: String, text: String, tonfall: String) -> void:
	artikel(d, kopf, text, tonfall, "saison", {"verein": cid})
	beitrag(d, text.substr(0, 140), tonfall)
