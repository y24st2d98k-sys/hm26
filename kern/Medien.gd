class_name Medien
extends RefCounted
## Presse und "Hallenfunk" (das soziale Netz des Spiels).
##
## Beitraege entstehen nicht zufaellig, sondern aus dem, was tatsaechlich passiert ist:
## Hoehe des Ergebnisses, Derbycharakter, Serie, Einzelleistungen, Zuschauerzahl,
## Vorstandslage und Tabellensituation fliessen in Schlagzeile und Tonfall ein.

# ------------------------------------------------------------- Grundlagen ---

## Wer diesen Artikel schreibt.
##
## Die Wahl war vorher rein zufaellig unter allen Medien der Nation. Damit
## kamen ueber Jahre dieselben vier Namen im selben Wechsel — und das
## Lokalblatt des eigenen Vereins, das ueber ihn ja am meisten schreibt, hatte
## keinen Vorrang vor einer Zeitung am anderen Ende des Landes.
static func _outlet(d: Dictionary, nation: String, cid: String = "") -> Dictionary:
	var passend: Array = []
	var lokal: Array = []
	for o in d["medien"]["outlets"]:
		if str(o.get("verein", "")) != "":
			if cid != "" and str(o["verein"]) == cid:
				lokal.append(o)
			continue
		if str(o["nation"]) == nation:
			passend.append(o)
	# Das Lokalblatt ist bei jedem dritten Bericht dran. Oefter waere es
	# einseitig, seltener liefe es nebenher mit.
	if not lokal.is_empty() and Namen.zufall() < 0.34:
		return lokal[Namen.wuerfel(0, lokal.size() - 1)]
	if passend.is_empty():
		passend = d["medien"]["outlets"]
	if passend.is_empty():
		return {"name": "Hallenzeit", "haltung": "nüchtern", "gattung": "Tageszeitung", "reichweite": 50.0}
	return passend[Namen.wuerfel(0, passend.size() - 1)]

static func artikel(d: Dictionary, schlagzeile: String, text: String, tonfall: String, thema: String, bezug: Dictionary = {}) -> void:
	var nation: String = str(d["vereine"].get(Welt.mein_verein_id, {}).get("nation", "de"))
	var o := _outlet(d, nation, str(bezug.get("verein", "")))
	var eintrag := {
		"tag": int(d["tag"]),
		"outlet": str(o["name"]),
		"gattung": str(o.get("gattung", "Tageszeitung")),
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

## Was im Hallenfunk nach einer Partie steht.
##
## Frueher zog diese Funktion zwei bis fuenf Beitraege aus einem Topf von drei
## festen Saetzen — mit Zuruecklegen. Derselbe Satz stand deshalb regelmaessig
## zweimal untereinander, und ueber eine Saison las man dieselben fuenfzehn
## Saetze immer wieder. Genau das war die Beschwerde.
##
## Zwei Aenderungen: die Beitraege kennen jetzt die Partie — Ergebnis, Gegner,
## Halle, Zuschauer, Torschuetze, Serie, Tabellenplatz —, und sie kennen ihren
## Absender. Ein Statistiker schreibt Zahlen, ein Noergler noergelt auch nach
## einem Sieg, ein Ultra findet alles gross. Gezogen wird ohne Zuruecklegen.
static func _social_zum_spiel(d: Dictionary, m: Dictionary, cid: String, abstand: int, derby: bool, held: Dictionary) -> void:
	var accounts: Array = d["medien"]["fanaccounts"]
	if accounts.is_empty():
		return
	var v: Dictionary = d["vereine"][cid]
	var ist_heim: bool = str(m["heim"]) == cid
	var gegner: Dictionary = d["vereine"][str(m["gast"]) if ist_heim else str(m["heim"])]
	var eigene: int = int(m["tore_heim"]) if ist_heim else int(m["tore_gast"])
	var fremde: int = int(m["tore_gast"]) if ist_heim else int(m["tore_heim"])
	var anzahl: int = 2 + (2 if derby else 0) + (1 if absi(abstand) >= 7 else 0)
	var tonfall := "jubel" if abstand > 2 else ("neutral" if abstand >= 0 else "kritik")

	# Fuer jeden Beitrag ein eigener Absender, und fuer jeden Absender ein Satz
	# aus seiner Welt. Keine Wiederholung, weder beim Konto noch beim Text.
	var gezogen: Array = []
	var benutzte_texte := {}
	var benutzte_konten := {}
	for i in range(anzahl):
		var konto: Dictionary = {}
		for versuch in range(8):
			var kandidat: Dictionary = accounts[Namen.wuerfel(0, accounts.size() - 1)]
			if not benutzte_konten.has(str(kandidat["handle"])):
				konto = kandidat
				break
		if konto.is_empty():
			continue
		benutzte_konten[str(konto["handle"])] = true
		var topf := _stimmen(d, cid, v, gegner, m, str(konto["typ"]), abstand, eigene, fremde, derby, held, ist_heim)
		var text := ""
		for versuch2 in range(10):
			var kandidat2: String = str(topf[Namen.wuerfel(0, topf.size() - 1)])
			if not benutzte_texte.has(kandidat2):
				text = kandidat2
				break
		if text == "":
			continue
		benutzte_texte[text] = true
		gezogen.append({"konto": konto, "text": text})

	for eintrag in gezogen:
		_beitrag_von(d, eintrag["konto"], str(eintrag["text"]), tonfall)

## Ein Beitrag von einem bestimmten Konto. beitrag() sucht sich sein Konto
## selbst; hier steht der Absender schon fest, weil sein Charakter den Text
## bestimmt hat.
static func _beitrag_von(d: Dictionary, konto: Dictionary, text: String, tonfall: String) -> void:
	(d["social"] as Array).push_front({
		"tag": int(d["tag"]),
		"handle": str(konto["handle"]),
		"typ": str(konto["typ"]),
		"text": text,
		"tonfall": tonfall,
		"gefaellt": Namen.wuerfel(3, int(float(konto["folgen"]) / 12.0) + 20),
	})
	if (d["social"] as Array).size() > 250:
		(d["social"] as Array).resize(250)

## Was ein Konto dieses Schlags nach dieser Partie schreibt.
static func _stimmen(d: Dictionary, cid: String, v: Dictionary, gegner: Dictionary, m: Dictionary,
		typ: String, abstand: int, eigene: int, fremde: int, derby: bool,
		held: Dictionary, ist_heim: bool) -> Array:
	var kurz: String = str(v["kurz"])
	var gname: String = str(gegner["name"])
	var gkurz: String = str(gegner["kurz"])
	var ergebnis: String = "%d:%d" % [eigene, fremde]
	var zuschauer: int = int(m.get("zuschauer", 0))
	var platz: int = _tabellenplatz(d, cid, v)
	var texte: Array = []

	# Zuerst das, was jeder sagen koennte — mit den Zahlen dieser Partie.
	if abstand >= 7:
		texte.append_array([
			"%s gegen %s. Mehr muss man dazu nicht sagen." % [ergebnis, gkurz],
			"Sieben Tore und mehr Unterschied. So einen Abend nimmt man mit.",
			"%s war heute chancenlos. Selten so klar gesehen." % gname,
		])
	elif abstand > 0:
		texte.append_array([
			"%s. Nicht schön, aber zwei Punkte." % ergebnis,
			"Gewonnen ist gewonnen. Gegen %s zählt heute nur das." % gkurz,
			"Am Ende steht ein %s. Den Rest verdrängen wir." % ergebnis,
		])
	elif abstand == 0:
		texte.append_array([
			"%s. Ein Punkt, der sich wie eine Niederlage anfühlt." % ergebnis,
			"Schon wieder in der Schlussphase alles hergegeben.",
			"Unentschieden gegen %s. Damit kommen wir nicht weiter." % gkurz,
		])
	elif abstand > -6:
		texte.append_array([
			"%s. Knapp verloren ist auch verloren." % ergebnis,
			"Gegen %s war heute mehr drin. Deutlich mehr." % gkurz,
			"Ein Tor Unterschied. Genau das eine, das wir liegen gelassen haben." if abstand == -1
				else "%d Tore Unterschied, und keines davon war nötig." % absi(abstand),
		])
	else:
		texte.append_array([
			"%s. Das war indiskutabel." % ergebnis,
			"Keine Gegenwehr, kein Plan, %s gegen %s." % [ergebnis, gkurz],
			"Ich habe für dieses Spiel einen halben Tag Urlaub genommen.",
		])

	# Und dann das, was nur dieser Absender sagt.
	match typ:
		"statistiker":
			texte.append_array([
				"%s. %d Tore in sechzig Minuten, das sind %s pro Viertelstunde." % [
					ergebnis, eigene, Stil.komma(float(eigene) / 4.0)],
				"%d Gegentore. Der Saisonschnitt liegt woanders." % fremde,
				"Torverhältnis nach diesem Spiel: %+d. Tabellenplatz %d." % [eigene - fremde, platz] if platz > 0
					else "Torverhältnis nach diesem Spiel: %+d." % (eigene - fremde),
			])
			if zuschauer > 0:
				texte.append("%s Zuschauer. Auslastung berechne ich heute Abend." % Stil.zahl(zuschauer))
		"noergler", "nörgler":
			texte.append_array([
				"Sagt mir bitte jemand, warum wir nie früher wechseln.",
				"Auch beim %s bleibe ich dabei: das trägt nicht über eine Saison." % ergebnis,
				"Ich sehe hier seit Jahren dieselben Fehler. Heute gegen %s wieder." % gkurz,
			])
		"ultra":
			texte.append_array([
				"EGAL WIE. IMMER %s." % kurz.to_upper(),
				"Der Block hat neunzig Minuten gestanden. Die Mannschaft nicht immer.",
				"Auswärts dabei gewesen. Würde ich wieder machen." if not ist_heim
					else "Halle war laut heute. So muss das.",
			])
		"optimist":
			texte.append_array([
				"Ich sehe da eine Mannschaft, die zusammenwächst.",
				"%s gegen %s — daraus lernt man mehr als aus einem lockeren Sieg." % [ergebnis, gkurz],
				"Kopf hoch. Nächste Woche sieht das anders aus.",
			])
		"dauerkarte":
			texte.append_array([
				"Seit elf Jahren derselbe Platz, und ich habe schon Schlimmeres gesehen als das %s." % ergebnis,
				"Wer heute nicht da war, hat nichts verpasst." if abstand < 0
					else "Wer heute nicht da war, hat etwas verpasst.",
				"Die Halle war heute %s." % ("voll und laut" if zuschauer > 5000 else "gut gefüllt"),
			])
		"insider":
			texte.append_array([
				"Höre aus dem Umfeld, dass die Woche intern schon ausgewertet wurde.",
				"Man sagt mir, in der Kabine war es nach dem %s sehr ruhig." % ergebnis,
				"Da tut sich was auf der Position, auf der wir heute Probleme hatten.",
			])
		_:
			texte.append_array([
				"%s gegen %s. Sachlich betrachtet in Ordnung." % [ergebnis, gkurz],
				"Ein Spiel von vielen. Weiter geht es.",
			])

	if not held.is_empty():
		texte.append("%s hat heute die Bude alleine zusammengehalten." % str(held["name"]))
		texte.append("Wenn %s so spielt, ist vieles möglich." % str(held["name"]))
	if derby:
		texte.append("Derby bleibt Derby. Gänsehaut.")
		texte.append("Gegen %s zählt die Tabelle sowieso nicht." % gkurz)
	return texte

## Auf welchem Tabellenplatz der Verein gerade steht. 0, wenn es keine
## Tabelle gibt — im Pokal zum Beispiel.
static func _tabellenplatz(d: Dictionary, cid: String, v: Dictionary) -> int:
	var lid: String = str(v.get("liga", ""))
	if lid == "" or not d["ligen"].has(lid):
		return 0
	var tabelle: Array = Spielplan.tabelle_sortiert(d, lid)
	for i in range(tabelle.size()):
		if str(tabelle[i]) == cid:
			return i + 1
	return 0

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
		# Zehnmal dieselbe Schlagzeile in einer Saison hat niemand geschrieben.
		# Die Lage wiederholt sich, die Formulierung soll es nicht.
		var koepfe: Array = []
		if platz <= ziel:
			koepfe = [
				"%s auf Platz %d — im Plan" % [v["name"], platz],
				"Rang %d: %s liegt, wo der Vorstand es sehen will" % [platz, v["name"]],
				"%s hält Kurs auf Platz %d" % [v["name"], platz],
				"Platz %d nach %d Spieltagen — bei %s stimmt die Richtung" % [
					platz, int(liga["tabelle"][cid]["sp"]), v["name"]],
			]
		else:
			koepfe = [
				"%s auf Platz %d — unter den Erwartungen" % [v["name"], platz],
				"Rang %d: %s bleibt hinter dem Saisonziel zurück" % [platz, v["name"]],
				"Für %s wird die Luft dünner — nur Platz %d" % [v["name"], platz],
				"%d Spieltage, Platz %d: bei %s wächst die Unruhe" % [
					int(liga["tabelle"][cid]["sp"]), platz, v["name"]],
			]
		var kopf: String = str(koepfe[Namen.wuerfel(0, koepfe.size() - 1)])
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
