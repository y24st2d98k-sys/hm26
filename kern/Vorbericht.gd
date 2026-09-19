class_name Vorbericht
extends RefCounted
## Spielvorbereitung: was die eigene Analyseabteilung über den nächsten Gegner weiß.
##
## Der Detailgrad hängt davon ab, wie gut der Gegner beobachtet wurde: ein
## frischer Scoutbericht, eine ausgebaute Analyseabteilung und Spieler, die man
## aus früheren Duellen kennt, machen aus Vermutungen belastbare Aussagen.

## 0 = kaum Erkenntnisse, 3 = lückenlose Analyse.
static func stufe(d: Dictionary, cid: String, gegner: String) -> int:
	if cid == "" or gegner == "" or not d["vereine"].has(gegner):
		return 0
	var punkte := 0.0
	var v: Dictionary = d["vereine"][cid]
	punkte += float(v["infrastruktur"]["analyse"]) * 0.34
	if Scouting.gegnervorteil(d, cid, gegner) > 0.0:
		punkte += 2.2
	# Wer den Gegner schon gespielt hat, kennt ihn besser.
	var kenntnis := 0.0
	var n := 0
	for sid in d["vereine"][gegner]["kader"]:
		kenntnis += float(d["spieler"][sid]["kenntnis"])
		n += 1
	punkte += (kenntnis / maxf(float(n), 1.0)) / 42.0
	return int(clampf(punkte / 1.6, 0.0, 3.0))

static func stufen_text(s: int) -> String:
	match s:
		0: return "Kaum Erkenntnisse — die Analyse tappt weitgehend im Dunkeln."
		1: return "Grobes Bild — Formation und Kern der Mannschaft sind bekannt."
		2: return "Solide Analyse — Aufstellung, Ausrichtung und Schwerpunkte liegen vor."
		_: return "Lückenlose Analyse — bis hin zu Wurfverteilung und Schwachstellen."

## Vollständiger Vorbericht für ein bevorstehendes Spiel.
##
## `mid` ist die Partie, um die es geht. Ohne sie fehlt das Gespann — der
## Bericht funktioniert trotzdem, sagt dann aber nichts darüber, was Härte
## heute kostet.
static func erzeuge(d: Dictionary, cid: String, gegner: String, mid: String = "") -> Dictionary:
	var s := stufe(d, cid, gegner)
	var g: Dictionary = d["vereine"][gegner]
	var bericht := {
		"stufe": s,
		"gegner": gegner,
		"text": stufen_text(s),
		"formation": [],
		"schluesselspieler": [],
		"taktik": {},
		"staerken": [],
		"schwaechen": [],
		"empfehlung": "",
		"wurfverteilung": {},
		# Das Gespann steht immer im Bericht, unabhängig von der Analysestufe:
		# wer heute pfeift, ist keine Frage der Scoutingabteilung, das steht
		# auf der Ansetzung.
		"gespann": {},
		"gespann_hinweis": "",
	}
	if mid != "":
		var gespann := Schiedsrichter.fuer_partie(d, mid)
		if not gespann.is_empty():
			bericht["gespann"] = gespann
			bericht["gespann_hinweis"] = Schiedsrichter.hinweis(gespann)
	if s >= 1:
		bericht["formation"] = _formation(d, gegner, s)
		bericht["schluesselspieler"] = _schluesselspieler(d, gegner, s)
	if s >= 2:
		bericht["taktik"] = {
			"abwehr": str(g["taktik"]["abwehr"]),
			"angriff": str(g["taktik"]["angriff"]),
			"tempo": int(g["taktik"]["tempo"]),
			"haerte": int(g["taktik"]["haerte"]),
			"mentalitaet": str(g["taktik"]["mentalitaet"]),
		}
		bericht["empfehlung"] = empfehlung(str(g["taktik"]["angriff"]))
	if s >= 3:
		bericht["wurfverteilung"] = Matchsim.WURFVERTEILUNG.get(str(g["taktik"]["angriff"]), {})
	bericht["staerken"] = _staerken(d, gegner, s)
	bericht["schwaechen"] = _schwaechen(d, gegner, s)
	return bericht

## Die voraussichtliche Sieben des Gegners, ab Stufe 2 mit Namen der Bank.
static func _formation(d: Dictionary, gegner: String, s: int) -> Array:
	var auf: Dictionary = (d["vereine"][gegner]["aufstellung"] as Dictionary).get("angriff", {})
	var liste: Array = []
	for pos in ["TW", "LA", "RL", "RM", "RR", "RA", "KM"]:
		var sid: String = str(auf.get(pos, ""))
		if sid == "" or not d["spieler"].has(sid):
			continue
		var sp: Dictionary = d["spieler"][sid]
		if not sp["verletzung"].is_empty() or int(sp["sperre"]) > 0:
			continue
		liste.append({
			"position": pos,
			"spieler": sid,
			"staerke": Scouting.gesamt_text(d, sid) if s < 3 else str(int(Spielerfabrik.gesamt(sp))),
		})
	return liste

## Die gefährlichsten Spieler des Gegners nach Saisonleistung.
static func _schluesselspieler(d: Dictionary, gegner: String, s: int) -> Array:
	var liste: Array = []
	for sid in d["vereine"][gegner]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		var st: Dictionary = sp["stats"]["saison"]
		if int(st["spiele"]) < 2:
			continue
		var gewicht := 0.0
		if bool(sp["ist_torwart"]):
			gewicht = float(st["paraden"]) / float(st["spiele"]) * 1.8
		else:
			gewicht = float(st["tore"]) / float(st["spiele"]) * 2.0 + float(st["assists"]) / float(st["spiele"])
		gewicht += (7.0 - Spielerfabrik.note(sp)) * 0.8
		liste.append({"spieler": sid, "gewicht": gewicht, "hinweis": _hinweis(d, sp)})
	liste.sort_custom(func(a, b): return float(a["gewicht"]) > float(b["gewicht"]))
	return liste.slice(0, 3 if s < 3 else 5)

static func _hinweis(d: Dictionary, sp: Dictionary) -> String:
	var st: Dictionary = sp["stats"]["saison"]
	var spiele: int = maxi(int(st["spiele"]), 1)
	if bool(sp["ist_torwart"]):
		var gesamt: float = float(st["paraden"]) + float(st.get("gegentore", 0))
		var quote: float = float(st["paraden"]) / maxf(gesamt, 1.0) * 100.0
		return "%s Paraden je Spiel, Quote %s %%" % [
			Stil.komma(float(st["paraden"]) / float(spiele), 1), Stil.komma(quote, 1)]
	var teile: Array = ["%s Tore je Spiel" % Stil.komma(float(st["tore"]) / float(spiele), 1)]
	if Statistik.wuerfe_gesamt(st) >= 15:
		teile.append("Quote %s %%" % Stil.komma(Statistik.wurfquote(st), 0))
	if int(st["siebenmeter_wuerfe"]) >= 5:
		teile.append("Siebenmeterschütze")
	if float(st["assists"]) / float(spiele) >= 2.5:
		teile.append("starker Vorbereiter")
	return ", ".join(teile)

static func _staerken(d: Dictionary, gegner: String, s: int) -> Array:
	var liste: Array = []
	var v: Dictionary = d["vereine"][gegner]
	var sa: Dictionary = v["saison"]
	var spiele: int = maxi(int(sa["spiele"]), 1)
	if int(sa["spiele"]) < 3:
		return ["Zu wenige Saisonspiele für belastbare Aussagen."]
	if float(sa["tore"]) / float(spiele) >= 30.0:
		liste.append("Wuchtiger Angriff: %s Tore je Spiel." % Stil.komma(float(sa["tore"]) / float(spiele), 1))
	if float(sa["gegentore"]) / float(spiele) <= 27.0:
		liste.append("Stabile Abwehr: nur %s Gegentore je Spiel." % Stil.komma(float(sa["gegentore"]) / float(spiele), 1))
	var serie: Array = v.get("formkurve", [])
	var siege := 0
	for e in serie.slice(maxi(serie.size() - 5, 0)):
		if str(e) == "S":
			siege += 1
	if siege >= 4:
		liste.append("In Form: %d Siege aus den letzten fünf Spielen." % siege)
	if int(sa["heimspiele"]) > 0 and float(sa["zuschauer_summe"]) / float(sa["heimspiele"]) >= float(v["halle"]["kapazitaet"]) * 0.9:
		liste.append("Ausverkaufte Halle — der Rückhalt von den Rängen ist enorm.")
	if s >= 2 and str(v["taktik"]["abwehr"]) in ["3-2-1", "4-2"]:
		liste.append("Offensive %s-Deckung, die viele Bälle erobert." % str(v["taktik"]["abwehr"]))
	if liste.is_empty():
		liste.append("Keine herausstechenden Stärken erkennbar.")
	return liste

static func _schwaechen(d: Dictionary, gegner: String, s: int) -> Array:
	var liste: Array = []
	var v: Dictionary = d["vereine"][gegner]
	var sa: Dictionary = v["saison"]
	var spiele: int = maxi(int(sa["spiele"]), 1)
	if int(sa["spiele"]) < 3:
		return ["Zu wenige Saisonspiele für belastbare Aussagen."]
	if float(sa["gegentore"]) / float(spiele) >= 31.0:
		liste.append("Löchrige Abwehr: %s Gegentore je Spiel." % Stil.komma(float(sa["gegentore"]) / float(spiele), 1))
	if float(sa["tore"]) / float(spiele) <= 26.0:
		liste.append("Zäher Angriff: nur %s Tore je Spiel." % Stil.komma(float(sa["tore"]) / float(spiele), 1))
	if float(sa["zeitstrafen"]) / float(spiele) >= 4.0:
		liste.append("Undiszipliniert: %s Zeitstrafen je Spiel." % Stil.komma(float(sa["zeitstrafen"]) / float(spiele), 1))
	var verletzt := 0
	for sid in v["kader"]:
		if not (d["spieler"][sid]["verletzung"] as Dictionary).is_empty():
			verletzt += 1
	if verletzt >= 3:
		liste.append("Personalsorgen: %d Spieler fallen aus." % verletzt)
	if s >= 2 and int(v["taktik"]["tempo"]) >= 65:
		liste.append("Hohes Tempo geht auf die Kräfte — in der Schlussphase lässt der Gegner nach.")
	if s >= 3:
		var wv: Dictionary = Matchsim.WURFVERTEILUNG.get(str(v["taktik"]["angriff"]), {})
		var beste := ""
		var bester_wert := 0.0
		for pos in wv.keys():
			if float(wv[pos]) > bester_wert:
				bester_wert = float(wv[pos])
				beste = str(pos)
		if beste != "":
			liste.append("Berechenbar: %s %% aller Würfe kommen von %s." % [
				Stil.komma(bester_wert * 100.0, 0), Spielerfabrik.POSITION_NAME.get(beste, beste)])
	if liste.is_empty():
		liste.append("Keine offensichtlichen Schwächen — hier hilft nur die eigene Bestleistung.")
	return liste

## Welche eigene Abwehr gegen die Angriffsausrichtung des Gegners am besten wirkt.
static func empfehlung(gegner_angriff: String) -> String:
	var reihe: Dictionary = Matchsim.ANGRIFF_GEGEN_DECKUNG.get(gegner_angriff, {})
	if reihe.is_empty():
		return ""
	var beste := ""
	var bester_wert := 99.0
	for deckung in reihe.keys():
		if float(reihe[deckung]) < bester_wert:
			bester_wert = float(reihe[deckung])
			beste = str(deckung)
	if beste == "":
		return ""
	return "Gegen %s wirkt eine %s-Deckung am besten." % [ANGRIFF_NAME.get(gegner_angriff, gegner_angriff), beste]

const ANGRIFF_NAME := {
	"positionsangriff": "Positionsangriff", "tempospiel": "Tempospiel",
	"kreisfokus": "Kreisfokus", "aussenfokus": "Außenfokus", "rueckraumfokus": "Rückraumfokus",
}
