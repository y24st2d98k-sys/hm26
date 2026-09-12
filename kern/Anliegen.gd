class_name Anliegen
extends RefCounted
## Spieler kommen von sich aus auf den Trainer zu.
##
## Bisher ging jede Ansprache vom Trainer aus. Hier ist es umgekehrt: Wer zu
## wenig spielt, wer nach einem gebrochenen Versprechen wartet, wer einen
## auslaufenden Vertrag hat oder wer sich über einen Mitspieler ärgert, klopft
## an die Tür. Jedes Anliegen hat eine Frist — wer es aussitzt, zahlt dafür.
##
## Die Anliegen liegen in `d["anliegen"]` und damit im Spielstand.

const FRIST_TAGE := 14
## Höchstens so viele offene Anliegen gleichzeitig, damit es nicht zur Flut wird.
const HOECHSTZAHL := 4
## So lange kommt derselbe Spieler nach einem Anliegen nicht wieder.
const ABKLINGZEIT := 45

const ARTEN := {
	"spielzeit": {
		"titel": "Zu wenig Einsatzzeit",
		"frage": "Trainer, ich sitze nur draußen. Ich brauche Spielpraxis — wie geht es weiter?",
	},
	"vertrag": {
		"titel": "Fragt nach seinem Vertrag",
		"frage": "Mein Vertrag läuft aus und ich höre nichts. Planen Sie noch mit mir?",
	},
	"wechsel": {
		"titel": "Will den Verein verlassen",
		"frage": "Ich glaube, es ist Zeit für etwas Neues. Lassen Sie mich gehen?",
	},
	"wortbruch": {
		"titel": "Erinnert an ein Versprechen",
		"frage": "Sie haben mir etwas zugesagt. Passiert ist nichts. Was gilt jetzt?",
	},
	"rolle": {
		"titel": "Will mehr Verantwortung",
		"frage": "Ich bin lange genug dabei. Ich will vorangehen — trauen Sie mir das zu?",
	},
	"form": {
		"titel": "Findet nicht in die Saison",
		"frage": "Bei mir läuft gerade gar nichts. Ich weiß selbst nicht, woran es liegt.",
	},
}

## Antworten je Art: Wirkung auf Moral, Unzufriedenheit und Verhältnis.
const ANTWORTEN := {
	"spielzeit": [
		{"id": "zusagen", "text": "Ich stelle dich auf. Versprochen.",
			"moral": 10.0, "unzufrieden": -24.0, "beziehung": 5.0, "versprechen": "einsatzzeit"},
		{"id": "leisten", "text": "Zeig es im Training, dann spielst du.",
			"moral": 1.0, "unzufrieden": -8.0, "beziehung": 3.0},
		{"id": "ehrlich", "text": "Du bist hinten dran. Daran ändert sich so schnell nichts.",
			"moral": -8.0, "unzufrieden": 6.0, "beziehung": 2.0},
	],
	"vertrag": [
		{"id": "verhandeln", "text": "Setzen wir uns zusammen.",
			"moral": 7.0, "unzufrieden": -14.0, "beziehung": 5.0, "aktion": "verhandlung"},
		{"id": "spaeter", "text": "Wir sprechen im Winter darüber.",
			"moral": -2.0, "unzufrieden": 5.0, "beziehung": 0.0},
		{"id": "nein", "text": "Ich plane nicht mehr mit dir.",
			"moral": -14.0, "unzufrieden": 18.0, "beziehung": -4.0},
	],
	"wechsel": [
		{"id": "freigeben", "text": "Wenn ein Angebot kommt, lasse ich dich ziehen.",
			"moral": 6.0, "unzufrieden": -28.0, "beziehung": 4.0, "versprechen": "freigabe"},
		{"id": "halten", "text": "Ich brauche dich hier.",
			"moral": 4.0, "unzufrieden": -12.0, "beziehung": 6.0},
		{"id": "vertrag", "text": "Du hast einen Vertrag. Punkt.",
			"moral": -12.0, "unzufrieden": 14.0, "beziehung": -8.0},
	],
	"wortbruch": [
		{"id": "einloesen", "text": "Du hast recht. Ab sofort ändert sich das.",
			"moral": 9.0, "unzufrieden": -20.0, "beziehung": 10.0, "versprechen": "einsatzzeit"},
		{"id": "entschuldigen", "text": "Das war mein Fehler. Ich kann es nur einräumen.",
			"moral": 3.0, "unzufrieden": -8.0, "beziehung": 7.0},
		{"id": "abtun", "text": "Die Lage hat sich geändert. So ist das Geschäft.",
			"moral": -12.0, "unzufrieden": 16.0, "beziehung": -12.0},
	],
	"rolle": [
		{"id": "geben", "text": "Übernimm. Die Mannschaft hört auf dich.",
			"moral": 10.0, "unzufrieden": -12.0, "beziehung": 8.0, "aktion": "leistungstraeger"},
		{"id": "pruefen", "text": "Mach es vor, dann reden wir weiter.",
			"moral": 2.0, "unzufrieden": -2.0, "beziehung": 3.0},
		{"id": "ablehnen", "text": "Dafür haben wir andere.",
			"moral": -9.0, "unzufrieden": 10.0, "beziehung": -5.0},
	],
	"form": [
		{"id": "rueckhalt", "text": "Ich halte an dir fest. Das kommt wieder.",
			"moral": 11.0, "unzufrieden": -10.0, "beziehung": 7.0},
		{"id": "pause", "text": "Nimm dir eine Woche und komm frei zurück.",
			"moral": 6.0, "unzufrieden": -6.0, "beziehung": 4.0, "aktion": "erholung"},
		{"id": "fordern", "text": "Reiß dich zusammen. Ich erwarte mehr.",
			"moral": -6.0, "unzufrieden": 4.0, "beziehung": -2.0},
	],
}

# --------------------------------------------------------------- Zugriff ---

static func offene(d: Dictionary) -> Array:
	return d.get("anliegen", [])

static func anzahl(d: Dictionary) -> int:
	return (d.get("anliegen", []) as Array).size()

static func fuer_spieler(d: Dictionary, sid: String) -> Dictionary:
	for e in offene(d):
		if str((e as Dictionary)["spieler"]) == sid:
			return e
	return {}

# ------------------------------------------------------------- Entstehen ---

## Einmal je Woche prüfen, wer etwas auf dem Herzen hat.
static func wochenpruefung(d: Dictionary) -> void:
	var cid: String = Welt.mein_verein_id
	if cid == "" or not d["vereine"].has(cid):
		return
	if not d.has("anliegen"):
		d["anliegen"] = []
	if anzahl(d) >= HOECHSTZAHL:
		return
	var kandidaten: Array = []
	for sid in d["vereine"][cid]["kader"]:
		if not fuer_spieler(d, sid).is_empty():
			continue
		# Wer gerade erst gefragt hat, wartet eine Weile — sonst klopft derselbe
		# Spieler alle zwei Wochen wieder an und die Kabine blutet langsam aus.
		if int(d["tag"]) - int(d["spieler"][sid].get("anliegen_tag", -999)) < ABKLINGZEIT:
			continue
		var art := _art_fuer(d, sid)
		if art == "":
			continue
		kandidaten.append({"spieler": sid, "art": art})
	if kandidaten.is_empty():
		return
	kandidaten.shuffle()
	var neu: Dictionary = kandidaten[0]
	var sp: Dictionary = d["spieler"][str(neu["spieler"])]
	sp["anliegen_tag"] = int(d["tag"])
	(d["anliegen"] as Array).append({
		"spieler": str(neu["spieler"]),
		"art": str(neu["art"]),
		"tag": int(d["tag"]),
		"frist": int(d["tag"]) + FRIST_TAGE,
	})
	Welt.nachricht({
		"typ": "kabine", "wichtig": true,
		"betreff": "%s möchte Sie sprechen" % Spielerfabrik.voller_name(sp),
		"text": "%s — antworten Sie binnen %d Tagen, sonst zieht er seine eigenen Schlüsse." % [
			str((ARTEN[str(neu["art"])] as Dictionary)["titel"]), FRIST_TAGE],
		"aktion": "anliegen",
		"daten": {"spieler": str(neu["spieler"])},
	})

## Welches Thema dieser Spieler gerade hätte — leer, wenn ihn nichts drückt.
static func _art_fuer(d: Dictionary, sid: String) -> String:
	var sp: Dictionary = d["spieler"][sid]
	# Ein gebrochenes Versprechen wiegt am schwersten
	if Gespraech.beziehung(sp) < 32.0 and float(sp["unzufriedenheit"]) > 45.0:
		return "wortbruch"
	if bool(sp.get("transferwunsch", false)):
		return "wechsel"
	var rest: int = int(sp["vertrag"].get("bis_saison", 9)) - Welt.saison_index()
	if rest <= 0 and Namen.zufall() < 0.6:
		return "vertrag"
	var st: Dictionary = sp["stats"]["saison"]
	var spiele: int = int(st["spiele"])
	if float(sp["unzufriedenheit"]) > 40.0:
		return "spielzeit"
	if spiele >= 5 and Spielerfabrik.note(sp) >= 3.6 and float(sp["moral"]) < 45.0:
		return "form"
	if spiele >= 6 and int(sp["alter"]) >= 27 and Kabine.einfluss(d, sid) >= 62.0 \
			and str(sp["vertrag"].get("rolle", "")) != "leistungstraeger" and Namen.zufall() < 0.5:
		return "rolle"
	return ""

## Täglich: abgelaufene Fristen abrechnen.
static func tageswechsel(d: Dictionary) -> void:
	var liste: Array = d.get("anliegen", [])
	if liste.is_empty():
		return
	var behalten: Array = []
	for e in liste:
		var eintrag: Dictionary = e
		var sid: String = str(eintrag["spieler"])
		if not d["spieler"].has(sid) or str(d["spieler"][sid]["verein"]) != Welt.mein_verein_id:
			continue
		if int(d["tag"]) < int(eintrag["frist"]):
			behalten.append(eintrag)
			continue
		_ignoriert(d, d["spieler"][sid], eintrag)
	d["anliegen"] = behalten

static func _ignoriert(d: Dictionary, sp: Dictionary, eintrag: Dictionary) -> void:
	sp["moral"] = clampf(float(sp["moral"]) - 9.0, 5.0, 100.0)
	sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) + 14.0, 0.0, 100.0)
	sp["beziehung"] = clampf(Gespraech.beziehung(sp) - 13.0, 0.0, 100.0)
	var cid: String = str(sp["verein"])
	if cid != "" and d["vereine"].has(cid):
		# Das Klima leidet, aber es ist die Sache zwischen Trainer und Spieler —
		# ein einzelnes uebergangenes Anliegen kippt keine Mannschaft.
		d["vereine"][cid]["stimmung_kabine"] = clampf(
			float(d["vereine"][cid]["stimmung_kabine"]) - 0.9, 0.0, 100.0)
	Welt.nachricht({
		"typ": "kabine",
		"betreff": "Keine Antwort für %s" % Spielerfabrik.voller_name(sp),
		"text": "%s hat auf ein Gespräch gewartet und keines bekommen. In der Kabine ist das nicht unbemerkt geblieben." % Spielerfabrik.kurz_name(sp),
		"daten": {"spieler": str(sp["id"])},
	})

# -------------------------------------------------------------- Antworten ---

## Auf ein Anliegen antworten. Liefert {"ok", "text", "aktion"}.
static func antworten(d: Dictionary, sid: String, antwort: String) -> Dictionary:
	var eintrag := fuer_spieler(d, sid)
	if eintrag.is_empty():
		return {"ok": false, "text": "Dieses Anliegen gibt es nicht mehr."}
	var art: String = str(eintrag["art"])
	var gewaehlt: Dictionary = {}
	for a in ANTWORTEN.get(art, []):
		if str((a as Dictionary)["id"]) == antwort:
			gewaehlt = a
			break
	if gewaehlt.is_empty():
		return {"ok": false, "text": "Diese Antwort passt nicht."}

	var sp: Dictionary = d["spieler"][sid]
	# Wie gut die Antwort ankommt, hängt am Charakter — dieselbe Logik wie beim
	# Einzelgespräch, damit sich das Spiel überall gleich anfühlt.
	var neigung: float = 0.45 + Gespraech.beziehung(sp) / 260.0 + float(sp["moral"]) / 400.0
	var temperament: float = float(sp["charakter"].get("temperament", 12.0)) / 20.0
	if antwort in ["ehrlich", "nein", "vertrag", "abtun", "ablehnen", "fordern"]:
		neigung += float(sp["charakter"].get("profitum", 12.0)) / 20.0 * 0.30 - temperament * 0.32
	var gelungen: bool = Namen.zufall() < clampf(neigung, 0.08, 0.95)
	var faktor: float = 1.0 if gelungen else -0.6

	sp["moral"] = clampf(float(sp["moral"]) + float(gewaehlt.get("moral", 0.0)) * faktor, 5.0, 100.0)
	sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"])
		+ float(gewaehlt.get("unzufrieden", 0.0)) * faktor, 0.0, 100.0)
	sp["beziehung"] = clampf(Gespraech.beziehung(sp)
		+ float(gewaehlt.get("beziehung", 0.0)) * faktor, 0.0, 100.0)

	if gelungen and gewaehlt.has("versprechen"):
		Gespraech.versprechen_anlegen(d, sid, str(gewaehlt["versprechen"]))
	var aktion := str(gewaehlt.get("aktion", ""))
	if gelungen:
		match aktion:
			"leistungstraeger":
				sp["vertrag"]["rolle"] = "leistungstraeger"
			"erholung":
				sp["last"] = clampf(float(sp["last"]) - 25.0, 0.0, 100.0)
				sp["form"] = clampf(float(sp["form"]) + 6.0, 5.0, 100.0)
	(d["anliegen"] as Array).erase(eintrag)

	var name: String = Spielerfabrik.kurz_name(sp)
	var text := "%s nimmt die Antwort an." % name if gelungen else "%s ist damit nicht zufrieden." % name
	if gelungen and gewaehlt.has("versprechen"):
		text += " Jetzt muss es auch so kommen."
	return {"ok": true, "text": text, "gelungen": gelungen,
		"aktion": aktion if gelungen else ""}
