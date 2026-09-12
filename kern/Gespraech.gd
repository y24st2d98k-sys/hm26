class_name Gespraech
extends RefCounted
## Einzelgespräche zwischen Trainer und Spieler — mit Versprechen, die man hält
## oder bricht.
##
## Ein Gespräch hat ein Thema, das sich aus der Lage des Spielers ergibt (Form,
## Einsatzzeit, Wechselwunsch, auslaufender Vertrag), und mehrere Antworten mit
## unterschiedlichem Risiko. Wie ein Spieler reagiert, hängt an seinem Charakter,
## seiner Moral, dem Verhältnis zum Trainer und an der Strenge in dessen
## Handschrift.
##
## Zwei Antworten geben ein **Versprechen** ab: mehr Einsatzzeit oder eine
## Freigabe im nächsten Transferfenster. Versprechen werden gespeichert und
## später geprüft. Ein gehaltenes Versprechen bindet den Spieler dauerhaft, ein
## gebrochenes kostet Vertrauen, Moral und oft den Spieler selbst.

## Wie lange ein Spieler nach einem Gespräch nicht wieder angesprochen werden will.
const SPERRE_TAGE := 12
## Nach so vielen Tagen wird ein Einsatzzeitversprechen geprüft.
const PRUEFUNG_TAGE := 42

const THEMEN := {
	"lob": {"name": "Leistung loben", "frage": "Sie holen %s zu einem kurzen Gespräch nach dem Training."},
	"kritik": {"name": "Leistung ansprechen", "frage": "%s hat zuletzt deutlich unter seinen Möglichkeiten gespielt."},
	"einsatzzeit": {"name": "Einsatzzeit besprechen", "frage": "%s sitzt zu oft draußen und will wissen, woran er ist."},
	"wechselwunsch": {"name": "Wechselwunsch besprechen", "frage": "%s hat den Verein um die Freigabe für einen Wechsel gebeten."},
	"vertrag": {"name": "Zukunft besprechen", "frage": "Der Vertrag von %s läuft aus. Er will wissen, wie es weitergeht."},
	"fuehrung": {"name": "Verantwortung übertragen", "frage": "%s hat das Zeug dazu, in der Kabine voranzugehen."},
}

## Antworten je Thema: Kennung, Text, Grundchance, Wirkung, ggf. Versprechen.
const ANTWORTEN := {
	"lob": [
		{"id": "ehrlich", "text": "Ehrlich loben — „Genau so will ich dich sehen.“",
			"chance": 0.82, "moral": 7.0, "unzufrieden": -4.0, "beziehung": 5.0},
		{"id": "nuechtern", "text": "Nüchtern bleiben — „Solide. Da geht noch mehr.“",
			"chance": 0.62, "moral": 3.0, "unzufrieden": -1.0, "beziehung": 2.0},
		{"id": "vorbild", "text": "Zum Vorbild erklären — vor der Mannschaft hervorheben.",
			"chance": 0.55, "moral": 10.0, "unzufrieden": -6.0, "beziehung": 7.0, "kabine": -2.0},
	],
	"kritik": [
		{"id": "sachlich", "text": "Sachlich ansprechen — Zahlen auf den Tisch.",
			"chance": 0.70, "moral": -2.0, "unzufrieden": -10.0, "beziehung": 4.0},
		{"id": "hart", "text": "Hart rangehen — „So spielst du bei mir nicht.“",
			"chance": 0.42, "moral": -5.0, "unzufrieden": -18.0, "beziehung": 2.0},
		{"id": "aufbauen", "text": "Aufbauen — „Ich weiß, was du kannst.“",
			"chance": 0.74, "moral": 6.0, "unzufrieden": -6.0, "beziehung": 6.0},
	],
	"einsatzzeit": [
		{"id": "versprechen", "text": "Mehr Spielzeit zusagen.",
			"chance": 0.88, "moral": 9.0, "unzufrieden": -22.0, "beziehung": 6.0,
			"versprechen": "einsatzzeit"},
		{"id": "leistung", "text": "An die Leistung knüpfen — „Zeig es im Training.“",
			"chance": 0.60, "moral": 1.0, "unzufrieden": -8.0, "beziehung": 3.0},
		{"id": "klartext", "text": "Klartext — „Du bist hinten dran, das ändert sich so schnell nicht.“",
			"chance": 0.38, "moral": -7.0, "unzufrieden": 6.0, "beziehung": -2.0},
	],
	"wechselwunsch": [
		{"id": "freigabe", "text": "Freigabe im nächsten Fenster zusagen.",
			"chance": 0.90, "moral": 6.0, "unzufrieden": -30.0, "beziehung": 4.0,
			"versprechen": "freigabe"},
		{"id": "umstimmen", "text": "Umstimmen — „Ich plane fest mit dir.“",
			"chance": 0.48, "moral": 5.0, "unzufrieden": -20.0, "beziehung": 6.0},
		{"id": "ablehnen", "text": "Ablehnen — „Du erfüllst deinen Vertrag.“",
			"chance": 0.34, "moral": -10.0, "unzufrieden": 10.0, "beziehung": -6.0},
	],
	"vertrag": [
		{"id": "zusage", "text": "Verlängerung in Aussicht stellen.",
			"chance": 0.78, "moral": 8.0, "unzufrieden": -16.0, "beziehung": 6.0},
		{"id": "abwarten", "text": "Abwarten — „Wir sprechen im Winter.“",
			"chance": 0.55, "moral": -1.0, "unzufrieden": 3.0, "beziehung": 0.0},
		{"id": "ehrlich_nein", "text": "Ehrlich sein — „Ich kann dir nichts versprechen.“",
			"chance": 0.62, "moral": -4.0, "unzufrieden": 8.0, "beziehung": 4.0},
	],
	"fuehrung": [
		{"id": "verantwortung", "text": "Verantwortung übertragen — Führungsrolle anbieten.",
			"chance": 0.66, "moral": 8.0, "unzufrieden": -10.0, "beziehung": 7.0, "kabine": 3.0},
		{"id": "beobachten", "text": "Erst beobachten — „Mach es vor, dann reden wir.“",
			"chance": 0.70, "moral": 2.0, "unzufrieden": -2.0, "beziehung": 2.0},
	],
}

# --------------------------------------------------------------- Zustand ---

static func beziehung(sp: Dictionary) -> float:
	return clampf(float(sp.get("beziehung", 50.0)), 0.0, 100.0)

static func beziehung_text(wert: float) -> String:
	if wert >= 82.0:
		return "Er würde für Sie durchs Feuer gehen"
	if wert >= 66.0:
		return "Vertraut Ihnen"
	if wert >= 45.0:
		return "Sachliches Verhältnis"
	if wert >= 28.0:
		return "Distanziert"
	return "Zerrüttet"

## Wie viele Tage der Spieler noch keine Lust auf ein weiteres Gespräch hat.
static func sperre_rest(d: Dictionary, sp: Dictionary) -> int:
	var letzter: int = int(sp.get("letztes_gespraech_tag", -999))
	return maxi(SPERRE_TAGE - (int(d["tag"]) - letzter), 0)

## Welche Themen bei diesem Spieler gerade anstehen.
static func themen(d: Dictionary, sid: String) -> Array:
	var sp: Dictionary = d["spieler"][sid]
	var liste: Array = []
	var st: Dictionary = sp["stats"]["saison"]
	var spiele: int = int(st["spiele"])
	var note: float = Spielerfabrik.note(sp)
	if bool(sp.get("transferwunsch", false)):
		liste.append("wechselwunsch")
	if spiele >= 3 and note > 0.0 and note <= 2.7:
		liste.append("lob")
	if spiele >= 3 and note >= 3.4:
		liste.append("kritik")
	if float(sp["unzufriedenheit"]) >= 28.0:
		liste.append("einsatzzeit")
	if int(sp["vertrag"].get("bis_saison", 9)) - Welt.saison_index() <= 0:
		liste.append("vertrag")
	if float(sp["charakter"].get("fuehrung", 0.0)) > 0.0 or Spielerfabrik.gesamt(sp) >= 74.0:
		if int(sp["alter"]) >= 26 and float(Kabine.einfluss(d, sid)) >= 55.0:
			liste.append("fuehrung")
	if liste.is_empty():
		liste.append("lob")
	return liste

# --------------------------------------------------------------- Führen ---

## Ein Gespräch führen. Liefert {ok, gelungen, text, versprechen}.
static func fuehren(d: Dictionary, sid: String, thema: String, antwort: String) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	if sperre_rest(d, sp) > 0:
		return {"ok": false, "gelungen": false,
			"text": "%s möchte gerade nicht schon wieder reden (noch %d Tage)." % [
				Spielerfabrik.kurz_name(sp), sperre_rest(d, sp)]}
	var moeglich: Array = ANTWORTEN.get(thema, [])
	var gewaehlt: Dictionary = {}
	for a in moeglich:
		if str((a as Dictionary)["id"]) == antwort:
			gewaehlt = a
			break
	if gewaehlt.is_empty():
		return {"ok": false, "gelungen": false, "text": "Diese Antwort passt nicht zum Thema."}

	var chance: float = float(gewaehlt["chance"]) * 0.55 + _neigung(d, sp, thema, antwort) * 0.45
	var gelungen: bool = Namen.zufall() < clampf(chance, 0.05, 0.96)
	var faktor: float = 1.0 if gelungen else -0.75
	# Ein misslungenes Gespräch dreht die Wirkung um und kostet zusätzlich Vertrauen.
	sp["moral"] = clampf(float(sp["moral"]) + float(gewaehlt.get("moral", 0.0)) * faktor, 5.0, 100.0)
	sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"])
		+ float(gewaehlt.get("unzufrieden", 0.0)) * faktor, 0.0, 100.0)
	sp["beziehung"] = clampf(beziehung(sp) + float(gewaehlt.get("beziehung", 0.0)) * faktor
		- (0.0 if gelungen else 3.0), 0.0, 100.0)
	sp["letztes_gespraech_tag"] = int(d["tag"])
	var cid: String = str(sp["verein"])
	if gewaehlt.has("kabine") and cid != "" and d["vereine"].has(cid):
		var v: Dictionary = d["vereine"][cid]
		v["stimmung_kabine"] = clampf(float(v["stimmung_kabine"])
			+ float(gewaehlt["kabine"]) * faktor, 0.0, 100.0)

	var versprochen := ""
	if gelungen and gewaehlt.has("versprechen"):
		versprochen = str(gewaehlt["versprechen"])
		_versprechen_anlegen(d, sid, versprochen)
	if thema == "fuehrung" and gelungen and antwort == "verantwortung":
		sp["vertrag"]["rolle"] = "leistungstraeger"

	return {
		"ok": true, "gelungen": gelungen, "versprechen": versprochen,
		"text": _antworttext(sp, thema, antwort, gelungen),
	}

## Wie zugänglich der Spieler für genau diese Antwort ist (0..1).
static func _neigung(d: Dictionary, sp: Dictionary, thema: String, antwort: String) -> float:
	var ch: Dictionary = sp["charakter"]
	var temperament: float = float(ch.get("temperament", 10.0)) / 20.0
	var profitum: float = float(ch.get("profitum", 12.0)) / 20.0
	var loyalitaet: float = float(ch.get("loyalitaet", 12.0)) / 20.0
	var ehrgeiz: float = float(ch.get("ehrgeiz", 12.0)) / 20.0
	var basis: float = 0.30 + beziehung(sp) / 220.0 + float(sp["moral"]) / 320.0
	var strenge: float = float((d.get("trainer", {}).get("handschrift", {}) as Dictionary).get("strenge", 50.0)) / 100.0
	match antwort:
		"hart", "klartext", "ablehnen":
			# Harte Ansagen tragen nur bei Profis und einem strengen Trainer
			basis += profitum * 0.35 - temperament * 0.30 + (strenge - 0.5) * 0.30
		"aufbauen", "ehrlich", "vertrauen", "umstimmen":
			basis += loyalitaet * 0.28 + (0.5 - absf(strenge - 0.4)) * 0.15
		"vorbild":
			basis += ehrgeiz * 0.30 - temperament * 0.12
		"versprechen", "freigabe", "zusage":
			basis += 0.18 + ehrgeiz * 0.10
		"ehrlich_nein":
			basis += profitum * 0.30 + loyalitaet * 0.15
		_:
			basis += profitum * 0.15
	if thema == "kritik" and float(sp["moral"]) < 35.0:
		basis -= 0.12
	return clampf(basis, 0.0, 1.0)

static func _antworttext(sp: Dictionary, thema: String, antwort: String, gelungen: bool) -> String:
	var n: String = Spielerfabrik.kurz_name(sp)
	if gelungen:
		match antwort:
			"ehrlich": return "%s nimmt das Lob an und wirkt gelöst." % n
			"nuechtern": return "%s nickt knapp. Botschaft angekommen." % n
			"vorbild": return "%s trägt die Brust breiter — der Rest der Kabine registriert es genau." % n
			"sachlich": return "%s widerspricht nicht. Er kennt die Zahlen selbst." % n
			"hart": return "%s schluckt die Ansage und will es beweisen." % n
			"aufbauen": return "%s richtet sich sichtbar auf." % n
			"versprechen": return "%s ist zufrieden — jetzt zählt, dass die Minuten auch kommen." % n
			"leistung": return "%s akzeptiert die Bedingung." % n
			"klartext": return "%s ist enttäuscht, nimmt die Ehrlichkeit aber an." % n
			"freigabe": return "%s bedankt sich für die klare Ansage." % n
			"umstimmen": return "%s zieht seine Wechselbitte vorerst zurück." % n
			"ablehnen": return "%s fügt sich — überzeugt ist er nicht." % n
			"zusage": return "%s freut sich auf die Verlängerung." % n
			"abwarten": return "%s wartet ab, wie angekündigt." % n
			"ehrlich_nein": return "%s schätzt die Offenheit, auch wenn sie wehtut." % n
			"verantwortung": return "%s nimmt die Rolle an und wirkt gewachsen." % n
			"beobachten": return "%s versteht die Ansage als Auftrag." % n
	else:
		match antwort:
			"hart", "klartext", "ablehnen": return "%s nimmt die Ansage persönlich. Das hat gesessen." % n
			"vorbild": return "%s ist es sichtlich unangenehm, so herausgestellt zu werden." % n
			"versprechen", "freigabe", "zusage": return "%s glaubt Ihnen nicht so recht." % n
			"ehrlich_nein": return "%s wertet die Offenheit als Absage." % n
			_: return "%s bleibt verschlossen. Das Gespräch verpufft." % n
	return "%s hört zu." % n

# ----------------------------------------------------------- Versprechen ---

static func _versprechen_anlegen(d: Dictionary, sid: String, art: String) -> void:
	if not d.has("versprechen"):
		d["versprechen"] = []
	var liste: Array = d["versprechen"]
	for e in liste:
		if str((e as Dictionary)["spieler"]) == sid and str((e as Dictionary)["art"]) == art:
			e["tag"] = int(d["tag"])
			return
	var basis := 0.0
	if art == "einsatzzeit":
		basis = _minuten_schnitt(d["spieler"][sid])
	liste.append({
		"spieler": sid, "art": art, "tag": int(d["tag"]),
		"faellig": int(d["tag"]) + PRUEFUNG_TAGE, "basis": basis,
	})

static func _minuten_schnitt(sp: Dictionary) -> float:
	var st: Dictionary = sp["stats"]["saison"]
	return float(st["minuten"]) / maxf(float(st["spiele"]), 1.0)

## Offene Versprechen für einen Spieler.
static func offene(d: Dictionary, sid: String) -> Array:
	var erg: Array = []
	for e in d.get("versprechen", []):
		if str((e as Dictionary)["spieler"]) == sid:
			erg.append(e)
	return erg

static func versprechen_text(e: Dictionary) -> String:
	match str(e["art"]):
		"einsatzzeit": return "Mehr Einsatzzeit zugesagt"
		"freigabe": return "Freigabe im nächsten Transferfenster zugesagt"
	return "Zusage"

## Täglich: fällige Versprechen abrechnen.
static func tageswechsel(d: Dictionary) -> void:
	var liste: Array = d.get("versprechen", [])
	if liste.is_empty():
		return
	var behalten: Array = []
	for e in liste:
		var eintrag: Dictionary = e
		var sid: String = str(eintrag["spieler"])
		if not d["spieler"].has(sid):
			continue
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["verein"]) != Welt.mein_verein_id:
			# Der Spieler ist weg — bei einer Freigabe ist das Versprechen erfüllt.
			if str(eintrag["art"]) == "freigabe":
				_einloesen(d, sp, eintrag, true)
			continue
		if int(d["tag"]) < int(eintrag["faellig"]):
			behalten.append(eintrag)
			continue
		match str(eintrag["art"]):
			"einsatzzeit":
				var jetzt: float = _minuten_schnitt(sp)
				_einloesen(d, sp, eintrag, jetzt >= float(eintrag["basis"]) + 6.0)
			"freigabe":
				# Fenster war offen, der Spieler ist trotzdem noch da
				_einloesen(d, sp, eintrag, false)
	d["versprechen"] = behalten

static func _einloesen(d: Dictionary, sp: Dictionary, eintrag: Dictionary, gehalten: bool) -> void:
	var n: String = Spielerfabrik.voller_name(sp)
	if gehalten:
		sp["beziehung"] = clampf(beziehung(sp) + 14.0, 0.0, 100.0)
		sp["moral"] = clampf(float(sp["moral"]) + 8.0, 5.0, 100.0)
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) - 12.0, 0.0, 100.0)
		Welt.nachricht({
			"typ": "kabine",
			"betreff": "Wort gehalten: %s" % n,
			"text": "%s hat gemerkt, dass Ihre Zusage etwas wert war. Das Verhältnis ist spürbar besser." % n,
			"daten": {"spieler": str(sp["id"])},
		})
		return
	sp["beziehung"] = clampf(beziehung(sp) - 26.0, 0.0, 100.0)
	sp["moral"] = clampf(float(sp["moral"]) - 14.0, 5.0, 100.0)
	sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) + 24.0, 0.0, 100.0)
	if float(sp["unzufriedenheit"]) > 60.0:
		sp["transferwunsch"] = true
	var cid: String = str(sp["verein"])
	if cid != "" and d["vereine"].has(cid):
		# Ein gebrochenes Wort spricht sich in der Kabine herum.
		d["vereine"][cid]["stimmung_kabine"] = clampf(
			float(d["vereine"][cid]["stimmung_kabine"]) - 4.0, 0.0, 100.0)
	Welt.nachricht({
		"typ": "kabine", "wichtig": true,
		"betreff": "Wortbruch: %s" % n,
		"text": "%s wartet bis heute auf das, was Sie ihm zugesagt haben (%s). In der Kabine hat sich das herumgesprochen." % [
			n, versprechen_text(eintrag).to_lower()],
		"daten": {"spieler": str(sp["id"])},
	})
