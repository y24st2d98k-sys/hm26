class_name Wechselbereitschaft
extends RefCounted
## Wer wechselt wohin — und wer eben nicht.
##
## Vorher fehlte diesem Spiel der Begriff der Bindung. Ein Spieler war eine
## Stärke mit einem Marktwert, und jeder Verein, dem diese Stärke fehlte, gab
## ein Angebot ab. Nachgemessen über zwei Saisons: 210 Angebote für den
## eigenen Kader, von denen 201 der Spieler ablehnte — eine Annahmequote von
## vier Prozent. Beide Zahlen sind falsch, und zwar aus derselben Ursache.
##
## Die Ablehnungen waren nämlich sachlich richtig: wer bei einem Spitzenverein
## spielt, geht nicht zu einem schwächeren. Falsch war, dass diese Angebote
## überhaupt zustande kamen. Ein Sportdirektor weiß vorher, dass der
## Führungsspieler des Meisters nicht zum Tabellenzwölften wechselt; er ruft
## dort gar nicht erst an.
##
## Deshalb steht hier eine Frage vor jedem Angebot: würde dieser Spieler
## überhaupt zusagen? Nur wenn ja, wird geboten. Das senkt die Zahl der
## Angebote drastisch und hebt die Annahmequote auf ein Maß, bei dem eine
## Verhandlung wieder etwas bedeutet.

## Ab diesem Zielwert lohnt sich ein Angebot. Darunter ruft niemand an.
const ANSPRECHBAR := 0.31
## Ab hier gilt ein Spieler als Identifikationsfigur.
const IKONE := 78.0

# ------------------------------------------------------------- Bindung ---

## Wie fest ein Spieler an seinem Verein hängt, 0..100.
##
## Das ist die Größe, die vorher komplett fehlte. Sie entsteht aus Dingen, die
## man einem Kader ansieht: wie lange er da ist, ob er aus der eigenen Jugend
## kommt, was für ein Typ er ist, welche Rolle er hat und ob er spielt.
static func bindung(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty() or str(sp.get("verein", "")) == "":
		return 0.0
	var w := 28.0
	# Dienstjahre. Wer seit sechs Jahren da ist, geht nicht wegen eines
	# besseren Angebots.
	var jahre: float = maxf(float(Welt.saison_index()) - float(sp["vertrag"].get("unterschrieben_saison", 0)), 0.0)
	w += minf(jahre * 6.5, 30.0)
	if bool(sp.get("aus_eigener_jugend", false)):
		w += 17.0
	w += float(sp["charakter"].get("loyalitaet", 12.0)) / 20.0 * 24.0
	match str(sp["vertrag"].get("rolle", "rotation")):
		"leistungstraeger": w += 12.0
		"stammspieler": w += 6.0
		"ergaenzung": w -= 9.0
		"talent": w -= 4.0
	# Wer spielt, bleibt. Wer zuschaut, hört zu.
	var spiele: int = int(sp["stats"]["saison"]["spiele"])
	if spiele >= 5:
		var schnitt: float = float(sp["stats"]["saison"]["minuten"]) / float(spiele)
		w += clampf((schnitt - 22.0) * 0.35, -12.0, 9.0)
	w -= float(sp.get("unzufriedenheit", 0.0)) * 0.62
	if bool(sp.get("transferwunsch", false)):
		w -= 42.0
	# Im letzten Vertragsjahr denkt jeder über sich nach.
	if int(sp["vertrag"].get("bis_saison", 9)) <= Welt.saison_index():
		w -= 16.0
	return clampf(w, 0.0, 100.0)

static func bindung_text(w: float) -> String:
	if w >= IKONE:
		return "Identifikationsfigur"
	elif w >= 60.0:
		return "fest verwurzelt"
	elif w >= 42.0:
		return "zufrieden"
	elif w >= 26.0:
		return "offen für Neues"
	elif w >= 12.0:
		return "wechselwillig"
	return "steht auf dem Sprung"

# ------------------------------------------------------------ Zielwert ---

## Wie attraktiv ein bestimmter Verein für diesen Spieler ist, 0..1.
static func zielwert(d: Dictionary, sid: String, ziel: String, rolle: String,
		gehalt: float = -1.0) -> float:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty() or not d["vereine"].has(ziel):
		return 0.0
	var neu: Dictionary = d["vereine"][ziel]
	var alt: String = str(sp["verein"])
	var alt_ruf: float = 30.0
	if alt != "" and d["vereine"].has(alt):
		alt_ruf = float(d["vereine"][alt]["ruf"])
	var b := bindung(d, sid)
	var wert := 0.44
	wert += clampf((float(neu["ruf"]) - alt_ruf) / 60.0, -0.40, 0.45)
	var rollen_wert: float = {"leistungstraeger": 0.22, "stammspieler": 0.14,
		"rotation": 0.0, "ergaenzung": -0.16, "talent": 0.04}.get(rolle, 0.0)
	var eigen: float = Spielerfabrik.gesamt(sp)
	wert += rollen_wert * (1.4 if eigen < _kaderstaerke(d, ziel) else 0.7)
	# Bindung zieht generell zurück — bei einer Identifikationsfigur mehr als
	# ein Drittel des ganzen Spielraums.
	wert -= b / 100.0 * 0.33
	# Der Rivale. Das ist der Fall, den man beim Namen nennt: ein
	# Führungsspieler wechselt nicht zum direkten Konkurrenten, auch nicht für
	# mehr Geld. Je fester er sitzt, desto undenkbarer.
	wert -= rivalitaetsabschlag(d, sid, ziel)
	# Geld. Ein deutlich besserer Vertrag bewegt auch jemanden, der bleiben
	# würde — aber er wiegt weniger als die sportliche Perspektive.
	if gehalt > 0.0:
		var jetzt: float = maxf(float(sp["vertrag"].get("gehalt", 1.0)), 1.0)
		wert += clampf((gehalt / jetzt - 1.0) * 0.30, -0.20, 0.26)
	var loyalitaet: float = float(sp["charakter"].get("loyalitaet", 12.0)) / 20.0
	wert -= loyalitaet * 0.08
	if str(sp["nation"]) == str(neu["nation"]):
		wert += 0.06
	if str(d.get("trainer", {}).get("verein", "")) == ziel:
		wert += clampf(float(d["trainer"]["ruf"]) / 300.0, 0.0, 0.3)
	return clampf(wert, 0.0, 1.0)

## Wie sehr die Rivalität zwischen altem und neuem Verein den Wechsel bremst.
static func rivalitaetsabschlag(d: Dictionary, sid: String, ziel: String) -> float:
	var sp: Dictionary = d["spieler"].get(sid, {})
	var alt: String = str(sp.get("verein", ""))
	if alt == "" or alt == ziel or not d["vereine"].has(alt):
		return 0.0
	var r: float = float((d["vereine"][alt]["rivalen"] as Dictionary).get(ziel, 0.0))
	if r <= 30.0:
		return 0.0
	# Bis zu 0.75 Abzug — mehr als jeder andere Einzelposten. Bei einer
	# Identifikationsfigur und einem echten Derbygegner ist der Wechsel damit
	# rechnerisch ausgeschlossen, und genau so soll es sein.
	return clampf((r - 30.0) / 70.0, 0.0, 1.0) * (0.32 + bindung(d, sid) / 100.0 * 0.43)

## Lohnt sich ein Angebot überhaupt? Die Frage, die vorher niemand stellte.
static func ansprechbar(d: Dictionary, sid: String, ziel: String, rolle: String,
		gehalt: float = -1.0) -> bool:
	return zielwert(d, sid, ziel, rolle, gehalt) >= ANSPRECHBAR

## Warum ein Wechsel nicht in Frage kommt — für Oberfläche und Meldungen.
static func absage_grund(d: Dictionary, sid: String, ziel: String) -> String:
	var sp: Dictionary = d["spieler"][sid]
	if rivalitaetsabschlag(d, sid, ziel) > 0.20:
		return "%s wechselt nicht zum direkten Konkurrenten." % Spielerfabrik.kurz_name(sp)
	var b := bindung(d, sid)
	if b >= IKONE:
		return "%s ist hier verwurzelt und denkt nicht an einen Wechsel." % Spielerfabrik.kurz_name(sp)
	var alt: String = str(sp["verein"])
	if alt != "" and d["vereine"].has(alt) and d["vereine"].has(ziel):
		if float(d["vereine"][ziel]["ruf"]) < float(d["vereine"][alt]["ruf"]) - 8.0:
			return "%s sieht dort keinen sportlichen Schritt nach vorn." % Spielerfabrik.kurz_name(sp)
	return "%s sieht keine Perspektive bei diesem Angebot." % Spielerfabrik.kurz_name(sp)

static func _kaderstaerke(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	var n := 0
	for sid in d["vereine"][cid]["kader"]:
		summe += Spielerfabrik.gesamt(d["spieler"][sid])
		n += 1
	return summe / maxf(float(n), 1.0)

# ------------------------------------------------------------- Abfuhren ---
#
# Ein Verein, dem gerade abgesagt wurde, ruft nicht naechste Woche wieder an.
# Ohne dieses Gedaechtnis kaeme derselbe Interessent im Wochentakt zurueck,
# und der Posteingang waere wieder voll.

const SPERRE_TAGE := 45

static func abfuhr_merken(d: Dictionary, sid: String, ziel: String) -> void:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty():
		return
	if not sp.has("abfuhren") or typeof(sp["abfuhren"]) != TYPE_DICTIONARY:
		sp["abfuhren"] = {}
	(sp["abfuhren"] as Dictionary)[ziel] = int(d["tag"]) + SPERRE_TAGE
	# Alte Einträge mitnehmen, damit die Liste nicht wächst.
	for k in (sp["abfuhren"] as Dictionary).keys():
		if int((sp["abfuhren"] as Dictionary)[k]) < int(d["tag"]):
			(sp["abfuhren"] as Dictionary).erase(k)

static func hat_abfuhr(d: Dictionary, sid: String, ziel: String) -> bool:
	var sp: Dictionary = d["spieler"].get(sid, {})
	var liste: Dictionary = sp.get("abfuhren", {})
	return int(liste.get(ziel, 0)) > int(d["tag"])
