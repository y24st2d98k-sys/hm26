class_name Schiedsrichter
extends RefCounted
## Die Gespanne — und warum der Regler „Härte in der Abwehr“ erst mit ihnen
## eine Entscheidung wird.
##
## Ohne Schiedsrichter rechnet die Härte nur mit sich selbst: 45 bedeutet immer
## 7,6 Prozent Zeitstrafen, in jedem Spiel, gegen jeden Gegner. Das ist eine
## Zahl, keine Wette. Mit einem Gespann, das vor dem Spiel im Vorbericht steht,
## kippt dieselbe Einstellung: gegen ein kleinliches Duo ist harte Abwehr teuer
## bezahlt, gegen eines, das laufen lässt, ist sie geschenkt.
##
## Im Handball pfeift ein Gespann aus zwei Personen, nie eine allein. Deshalb
## trägt jeder Eintrag zwei Namen und wird immer als Paar genannt.
##
## Vier Eigenschaften, jede mit genau einer Wirkung:
##  * strenge      — wie oft überhaupt gepfiffen wird (Zeitstrafen, Siebenmeter)
##  * zweikampf    — ob im Zweikampf früh unterbrochen oder laufen gelassen wird
##  * heimneigung  — wie sehr die Halle das Gespann beeinflusst
##  * konstanz     — wie stark die Tagesform des Gespanns schwankt

## So viele Gespanne hat die Welt. Genug, dass man Gesichter wiedererkennt,
## wenige genug, dass man sie sich merkt — ein Bundesligist trifft in einer
## Saison auf ein Dutzend davon.
const ANZAHL := 28

## Die Bandbreite, in der ein Gespann von der Norm abweichen darf. Weiter
## aufgezogen würden einzelne Partien zur Lotterie statt zur Einschätzung.
##
## Die Mitte liegt genau auf 1.0: die durchschnittliche Strenge liegt bei 50,
## und ein durchschnittliches Gespann darf die Kalibrierung der Liga nicht
## verschieben. Ein Gespann ändert, wie ein einzelnes Spiel läuft — nicht,
## wie viele Zeitstrafen eine Saison hat.
const STRENGE_SPANNE := Vector2(0.70, 1.30)

static func leer() -> Dictionary:
	return {"gespanne": {}, "reihenfolge": []}

# ------------------------------------------------------------- Erzeugung ---

## Legt den Gespann-Pool an. Wird einmal beim Weltaufbau gerufen.
static func erzeugen(d: Dictionary, nationen: Array) -> void:
	var pool := leer()
	# Zuerst die echten Gespanne aus daten/schiedsrichter.json. Ihre Namen
	# stehen fest, ihre Neigungen würfelt das Spiel — wie streng ein Duo
	# wirklich pfeift, weiß keine Tabelle.
	var echte: Array = Echtdaten.schiedsrichter() if bool(d.get("echte_welt", false)) else []
	var nummer := 0
	for e in echte:
		var eintrag: Dictionary = e
		if str(eintrag.get("a", "")) == "" or str(eintrag.get("b", "")) == "":
			continue
		nummer += 1
		var nat_e: String = str(eintrag.get("nation", "de"))
		var g_e := _gespann_bauen(d, "sr_%03d" % nummer, nat_e)
		g_e["a"] = str(eintrag["a"])
		g_e["b"] = str(eintrag["b"])
		g_e["echt"] = true
		if eintrag.has("erfahrung"):
			g_e["erfahrung"] = float(eintrag["erfahrung"])
		for feld in ["strenge", "zweikampf", "heimneigung", "konstanz"]:
			if eintrag.has(feld):
				g_e[feld] = clampf(float(eintrag[feld]), 5.0, 95.0)
		pool["gespanne"][g_e["id"]] = g_e
		(pool["reihenfolge"] as Array).append(g_e["id"])
	# Jede Liga braucht Gespanne aus dem eigenen Land — wo der Datensatz
	# weniger als drei kennt, ergänzt das Spiel erfundene.
	var je_nation := {}
	for gid in pool["reihenfolge"]:
		var n: String = str(pool["gespanne"][gid]["nation"])
		je_nation[n] = int(je_nation.get(n, 0)) + 1
	if not echte.is_empty():
		for nat_f in nationen:
			while int(je_nation.get(str(nat_f), 0)) < 3:
				nummer += 1
				var g_f := _gespann_bauen(d, "sr_%03d" % nummer, str(nat_f))
				g_f["nation"] = str(nat_f)
				pool["gespanne"][g_f["id"]] = g_f
				(pool["reihenfolge"] as Array).append(g_f["id"])
				je_nation[str(nat_f)] = int(je_nation.get(str(nat_f), 0)) + 1
	while nummer < ANZAHL:
		nummer += 1
		var nat: String = str(Namen.waehle(nationen)) if not nationen.is_empty() else "de"
		var g := _gespann_bauen(d, "sr_%03d" % nummer, nat)
		pool["gespanne"][g["id"]] = g
		(pool["reihenfolge"] as Array).append(g["id"])
	d["schiedsrichter"] = pool

static func _gespann_bauen(d: Dictionary, id: String, nation: String) -> Dictionary:
	var kultur: String = Namen.kultur_zufall(nation, 0.9)
	var a: Dictionary = Namen.person(kultur)
	# Gespanne sind im Handball fast immer zwei Personen aus derselben Region,
	# oft Geschwister oder langjährige Paare. Ein gemeinsamer Nachname kommt
	# deshalb häufiger vor, als der Zufall es hergäbe.
	var b: Dictionary = Namen.person(kultur)
	if Namen.zufall() < 0.28:
		b["nachname"] = a["nachname"]
	return {
		"id": id,
		"nation": nation,
		"a": "%s %s" % [str(a["vorname"]), str(a["nachname"])],
		"b": "%s %s" % [str(b["vorname"]), str(b["nachname"])],
		"strenge": Namen.glocke(50.0, 17.0, 12.0, 92.0),
		"zweikampf": Namen.glocke(50.0, 16.0, 10.0, 92.0),
		"heimneigung": Namen.glocke(50.0, 15.0, 8.0, 92.0),
		"konstanz": Namen.glocke(58.0, 15.0, 15.0, 95.0),
		"erfahrung": float(Namen.wuerfel(1, 22)),
		# Was das Gespann tatsächlich gepfiffen hat. Erst diese Zahlen machen
		# aus einer Anlage einen Ruf: man liest nicht „strenge 78“, sondern
		# „4,1 Zeitstrafen je Spiel“.
		"spiele": 0, "zeitstrafen": 0, "siebenmeter": 0, "rote": 0,
	}

# -------------------------------------------------------------- Zuteilung ---

## Welches Gespann diese Partie pfeift.
##
## Die Zuteilung wird nicht gespeichert, sondern aus der Spiel-ID abgeleitet:
## dieselbe Partie bekommt immer dasselbe Gespann, ohne dass ein einziges Byte
## im Spielstand dafür draufgeht. Bei 60.000 Partien pro Karriere ist das der
## Unterschied zwischen einer Zeile Code und einem Megabyte.
static func fuer_partie(d: Dictionary, mid: String) -> Dictionary:
	var pool: Dictionary = d.get("schiedsrichter", {})
	var reihe: Array = pool.get("reihenfolge", [])
	if reihe.is_empty():
		return {}
	# Eine Ligapartie pfeift ein Gespann aus dem eigenen Land, sofern es eins
	# gibt — ein dänisches Duo in Lemgo gibt es nur im Europapokal.
	var spiel: Dictionary = (d.get("spiele", {}) as Dictionary).get(mid, {})
	var liga: Dictionary = (d.get("ligen", {}) as Dictionary).get(str(spiel.get("wettbewerb", "")), {})
	if liga.is_empty():
		liga = (d.get("pokale", {}) as Dictionary).get(str(spiel.get("wettbewerb", "")), {})
	var nation: String = str(liga.get("nation", ""))
	if nation != "":
		var heimisch: Array = []
		for gid in reihe:
			if str((pool["gespanne"][gid] as Dictionary).get("nation", "")) == nation:
				heimisch.append(gid)
		if heimisch.size() >= 3:
			return (pool["gespanne"] as Dictionary).get(str(heimisch[abs(hash(mid)) % heimisch.size()]), {})
	return (pool["gespanne"] as Dictionary).get(str(reihe[abs(hash(mid)) % reihe.size()]), {})

## Beide Namen als eine Zeile: „Berger / Weickert“.
static func namen(g: Dictionary) -> String:
	if g.is_empty():
		return "—"
	return "%s / %s" % [_nachname(str(g["a"])), _nachname(str(g["b"]))]

## Beide Namen ausgeschrieben, für den Vorbericht.
static func namen_lang(g: Dictionary) -> String:
	if g.is_empty():
		return "—"
	return "%s und %s" % [str(g["a"]), str(g["b"])]

static func _nachname(voll: String) -> String:
	var teile := voll.split(" ", false)
	return str(teile[-1]) if teile.size() > 0 else voll

# --------------------------------------------------------------- Wirkung ---

## Der Faktor auf die Zeitstrafenwahrscheinlichkeit.
##
## `tagesform` kommt aus der Partie und ist bei konstanten Gespannen fast 1.0,
## bei unberechenbaren schwankt sie spürbar. So bleibt ein als kleinlich
## bekanntes Duo auch dann kleinlich, wenn ein einzelner Abend aus der Reihe
## fällt.
static func strenge_faktor(g: Dictionary, tagesform: float = 1.0) -> float:
	if g.is_empty():
		return 1.0
	var s: float = float(g["strenge"])
	return clampf((STRENGE_SPANNE.x + (s / 100.0) * (STRENGE_SPANNE.y - STRENGE_SPANNE.x)) * tagesform,
		0.60, 1.55)

## Wie sehr das Gespann Zweikämpfe laufen lässt. Ein Gespann, das früh
## unterbricht, nimmt dem Tempospiel die Wucht und dem Kreisläufer die Chance,
## nach dem Kontakt noch abzuschließen.
static func laufen_lassen(g: Dictionary) -> float:
	if g.is_empty():
		return 1.0
	return clampf(0.90 + float(g["zweikampf"]) / 100.0 * 0.20, 0.88, 1.12)

## Wie stark die Halle wirkt: 1.0 heißt neutral, darüber pfeift das Gespann
## häufiger gegen die Gäste.
static func heimfaktor(g: Dictionary, hallenpuls: float) -> float:
	if g.is_empty():
		return 1.0
	var neigung: float = (float(g["heimneigung"]) - 50.0) / 50.0
	var druck: float = clampf((hallenpuls - 50.0) / 50.0, -1.0, 1.0)
	return clampf(1.0 + neigung * druck * 0.13, 0.87, 1.13)

## Die Tagesform des Gespanns für genau diese Partie.
static func tagesform(g: Dictionary, rng: RandomNumberGenerator) -> float:
	if g.is_empty():
		return 1.0
	var schwankung: float = (100.0 - float(g["konstanz"])) / 100.0 * 0.26
	return clampf(1.0 + rng.randfn(0.0, schwankung), 0.72, 1.32)

# ------------------------------------------------------------------- Ruf ---

## Was man dem Gespann nachsagt — abgeleitet aus dem, was es gepfiffen hat,
## und erst ab genug Partien belastbar.
static func ruf(g: Dictionary) -> String:
	if g.is_empty():
		return "unbekannt"
	if int(g["spiele"]) < 6:
		return "noch kein Bild"
	var q: float = zeitstrafen_quote(g)
	if q >= 5.4:
		return "sehr kleinlich"
	elif q >= 4.4:
		return "kleinlich"
	elif q >= 3.4:
		return "ausgeglichen"
	elif q >= 2.6:
		return "großzügig"
	return "lässt viel laufen"

static func zeitstrafen_quote(g: Dictionary) -> float:
	if g.is_empty() or int(g["spiele"]) <= 0:
		return 0.0
	return float(g["zeitstrafen"]) / float(g["spiele"])

static func siebenmeter_quote(g: Dictionary) -> float:
	if g.is_empty() or int(g["spiele"]) <= 0:
		return 0.0
	return float(g["siebenmeter"]) / float(g["spiele"])

## Ein Satz für den Vorbericht — was die Einstellung der Härte heute kostet.
static func hinweis(g: Dictionary) -> String:
	if g.is_empty():
		return ""
	if int(g["spiele"]) < 6:
		return "Über das Gespann liegt noch nichts vor. Härte ist heute ein Blindflug."
	var q: float = zeitstrafen_quote(g)
	if q >= 5.4:
		return "Ein Gespann, das alles pfeift. Harte Abwehr wird heute teuer bezahlt."
	elif q >= 4.4:
		return "Das Duo greift früh ein. Mit hoher Härte sitzt regelmäßig jemand draußen."
	elif q >= 3.4:
		return "Ein Gespann ohne Ausschläge. Die Härte wirkt heute wie auf dem Papier."
	elif q >= 2.6:
		return "Das Duo lässt einiges laufen. Härte kostet heute weniger als sonst."
	return "Ein Gespann, das den Zweikampf zulässt. Wer hart deckt, kommt heute damit durch."

# ------------------------------------------------------------ Buchführung ---

## Trägt nach, was ein Gespann in dieser Partie gepfiffen hat.
static func partie_verbuchen(d: Dictionary, mid: String, zeitstrafen: int,
		siebenmeter: int, rote: int) -> void:
	var g := fuer_partie(d, mid)
	if g.is_empty():
		return
	g["spiele"] = int(g["spiele"]) + 1
	g["zeitstrafen"] = int(g["zeitstrafen"]) + zeitstrafen
	g["siebenmeter"] = int(g["siebenmeter"]) + siebenmeter
	g["rote"] = int(g["rote"]) + rote

## Alle Gespanne, nach Strenge sortiert — für die Übersicht.
static func alle(d: Dictionary) -> Array:
	var pool: Dictionary = d.get("schiedsrichter", {})
	var liste: Array = []
	for id in pool.get("reihenfolge", []):
		var g: Dictionary = (pool["gespanne"] as Dictionary).get(str(id), {})
		if not g.is_empty():
			liste.append(g)
	liste.sort_custom(func(x, y): return zeitstrafen_quote(x) > zeitstrafen_quote(y))
	return liste
