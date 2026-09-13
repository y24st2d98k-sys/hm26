class_name Ticketing
extends RefCounted
## Eintrittspreise, Dauerkarten und wer am Spieltag tatsächlich kommt.
##
## Bisher war der Zuschauerschnitt eine Formel und der Eintrittspreis eine
## Konstante: Geld kam herein, ohne dass jemand eine Entscheidung getroffen
## hätte. Damit fehlte dem Verein genau der Hebel, den ein Handballklub in
## Wahrheit täglich zieht — was kostet ein Platz, und für wen?
##
## Drei Kategorien, drei Publikumsarten. Der Stehplatz trägt die Stimmung und
## reagiert am härtesten auf den Preis; der Sitzplatz ist das Rückgrat; die
## Loge bringt viel Geld von wenigen Leuten, die kaum auf den Preis schauen,
## dafür auf Komfort und Ansehen.
##
## Dauerkarten drehen die Frage um: Geld im Voraus und ein volles Haus auch am
## grauen Dienstag — aber am Spitzenspiel verdient man an einem Dauerkarten-
## besitzer keinen Cent mehr. Wer alles verkauft, hat Sicherheit ohne Oberkante.

const KATEGORIEN := ["steh", "sitz", "loge"]

const KATEGORIE := {
	"steh": {
		"name": "Stehplatz", "kurz": "STEH",
		"text": "Die Kurve. Trägt die Stimmung und schaut am genauesten auf den Preis.",
		"elastizitaet": 1.15, "puls": 1.0,
	},
	"sitz": {
		"name": "Sitzplatz", "kurz": "SITZ",
		"text": "Das Rückgrat des Hauses: kommt regelmäßig, erwartet Gegenwert.",
		"elastizitaet": 0.85, "puls": 0.55,
	},
	"loge": {
		"name": "Loge", "kurz": "LOGE",
		"text": "Wenige Plätze, viel Geld. Fragt nach Komfort und Ansehen, kaum nach dem Preis.",
		"elastizitaet": 0.42, "puls": 0.15,
	},
}

## Heimspiele einer Ligasaison — die Bezugsgröße einer Dauerkarte.
const HEIMSPIELE := 17

## Spanne, in der sich ein Dauerkartenrabatt bewegen darf.
const DAUERKARTE_MIN := 0.55
const DAUERKARTE_MAX := 1.05

static func daten(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("ticketing"):
		v["ticketing"] = standard(d, cid)
	return v["ticketing"]

static func standard(d: Dictionary, cid: String) -> Dictionary:
	var preise := {}
	for k in KATEGORIEN:
		preise[k] = roundf(referenzpreis(d, cid, str(k)))
	return {
		"preise": preise,
		"dauerkarten": {"steh": 0, "sitz": 0, "loge": 0},
		"dauerkarte_faktor": 0.82,
		"verkauft_saison": -1,
		"letzte_einnahme": 0.0,
	}

# ------------------------------------------------------------- Kapazität ---

## Wie sich die Halle auf die drei Kategorien verteilt. Eine einfache Halle ist
## fast nur Stehplatz; erst Komfortstufen bringen Sitzplätze und Logen.
static func aufteilung(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var komfort: float = clampf(float(v["halle"]["komfort"]), 1.0, 10.0)
	var loge: float = 0.008 + komfort * 0.0062
	var sitz: float = 0.30 + komfort * 0.035
	return {"loge": loge, "sitz": sitz, "steh": maxf(1.0 - loge - sitz, 0.15)}

static func plaetze(d: Dictionary, cid: String) -> Dictionary:
	var kap: int = int(d["vereine"][cid]["halle"]["kapazitaet"])
	var teil := aufteilung(d, cid)
	var aus := {}
	var vergeben := 0
	for k in ["loge", "sitz"]:
		aus[k] = int(round(float(kap) * float(teil[k])))
		vergeben += int(aus[k])
	aus["steh"] = maxi(kap - vergeben, 0)
	return aus

# --------------------------------------------------------------- Preise ---

## Was der Markt für diesen Verein hergibt. Ruf und Komfort bestimmen ihn —
## ein Zweitligist in einer Turnhalle kann keine Bundesligapreise nehmen.
static func referenzpreis(d: Dictionary, cid: String, kategorie: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var ruf: float = float(v["ruf"])
	var komfort: float = float(v["halle"]["komfort"])
	match kategorie:
		"steh":
			return 7.0 + ruf * 0.09 + komfort * 0.6
		"sitz":
			return 12.0 + ruf * 0.20 + komfort * 1.4
		"loge":
			return 50.0 + ruf * 1.4 + komfort * 7.0
	return 15.0

static func preis(d: Dictionary, cid: String, kategorie: String) -> float:
	var t := daten(d, cid)
	return float((t["preise"] as Dictionary).get(kategorie, referenzpreis(d, cid, kategorie)))

static func preis_setzen(d: Dictionary, cid: String, kategorie: String, wert: float) -> void:
	var t := daten(d, cid)
	var ref: float = referenzpreis(d, cid, kategorie)
	# Nach unten frei, nach oben begrenzt: für das Dreifache des Marktpreises
	# kommt niemand, und ein Regler, der ins Leere läuft, hilft niemandem.
	(t["preise"] as Dictionary)[kategorie] = clampf(wert, 1.0, ref * 2.5)

## Wie stark der gewählte Preis die Nachfrage verschiebt (1.0 = Marktpreis).
static func nachfragefaktor(d: Dictionary, cid: String, kategorie: String) -> float:
	var ref: float = maxf(referenzpreis(d, cid, kategorie), 1.0)
	var jetzt: float = maxf(preis(d, cid, kategorie), 1.0)
	var e: float = float((KATEGORIE[kategorie] as Dictionary)["elastizitaet"])
	return clampf(pow(ref / jetzt, e), 0.22, 1.32)

## Klartext zur Preislage — die Zahl allein sagt nichts über ihre Wirkung.
static func preistext(d: Dictionary, cid: String, kategorie: String) -> String:
	var anteil: float = preis(d, cid, kategorie) / maxf(referenzpreis(d, cid, kategorie), 1.0)
	if anteil >= 1.5:
		return "deutlich zu teuer"
	if anteil >= 1.18:
		return "teuer"
	if anteil >= 0.9:
		return "marktüblich"
	if anteil >= 0.72:
		return "günstig"
	return "verschenkt"

# ----------------------------------------------------------- Dauerkarten ---

## Preis einer Dauerkarte in dieser Kategorie.
static func dauerkartenpreis(d: Dictionary, cid: String, kategorie: String) -> float:
	var t := daten(d, cid)
	return preis(d, cid, kategorie) * float(HEIMSPIELE) * float(t["dauerkarte_faktor"])

static func dauerkarten(d: Dictionary, cid: String, kategorie: String) -> int:
	return int((daten(d, cid)["dauerkarten"] as Dictionary).get(kategorie, 0))

static func dauerkarten_gesamt(d: Dictionary, cid: String) -> int:
	var summe := 0
	for k in KATEGORIEN:
		summe += dauerkarten(d, cid, str(k))
	return summe

static func faktor_setzen(d: Dictionary, cid: String, wert: float) -> void:
	daten(d, cid)["dauerkarte_faktor"] = clampf(wert, DAUERKARTE_MIN, DAUERKARTE_MAX)

## Wie viele Dauerkarten zu den aktuellen Konditionen weggehen — ohne zu
## buchen. Getrennt vom Verkauf, damit alte Spielstände dieselbe Rechnung
## bekommen können, ohne dass Geld doppelt in die Kasse fließt.
static func _nachfrage_dauerkarten(d: Dictionary, cid: String) -> Dictionary:
	var t := daten(d, cid)
	var v: Dictionary = d["vereine"][cid]
	var fans: Dictionary = v["fans"]
	var sitze := plaetze(d, cid)
	# Grundneigung: wie viele überhaupt eine ganze Saison im Voraus kaufen.
	var neigung: float = 0.16 + float(fans["treue"]) / 420.0 + float(fans["zufriedenheit"]) / 620.0
	# Der letzte Tabellenplatz wirkt stärker als jede Werbung.
	var platzierung: Array = (v["chronik"]["saisons"] as Array)
	if not platzierung.is_empty():
		var letzte: Dictionary = platzierung[platzierung.size() - 1]
		var platz: int = int(letzte.get("platz", 9))
		neigung += clampf((9.0 - float(platz)) * 0.012, -0.09, 0.11)
	# Der Rabatt entscheidet mit: eine Dauerkarte zum vollen Preis kauft kaum
	# jemand, eine für zwei Drittel schon.
	var rabatt: float = clampf((1.0 - float(t["dauerkarte_faktor"])) * 1.5, -0.1, 0.7)
	neigung *= (0.72 + rabatt)
	var einnahme := 0.0
	var verkauft := {}
	for k in KATEGORIEN:
		var kat: String = str(k)
		# Obergrenze: ein Teil der Halle bleibt immer für Tageskarten frei,
		# sonst käme an keinem Spitzenspiel mehr jemand herein.
		var deckel: float = 0.78 if kat != "loge" else 0.9
		var anteil: float = clampf(neigung * nachfragefaktor(d, cid, kat), 0.0, deckel)
		var anzahl: int = int(round(float(sitze[kat]) * anteil))
		verkauft[kat] = anzahl
		einnahme += float(anzahl) * dauerkartenpreis(d, cid, kat)
	return {"verkauft": verkauft, "einnahme": einnahme}

## Der Dauerkartenverkauf vor der Saison. Läuft einmal je Spielzeit und bringt
## das Geld im Voraus — dafür ist der Platz für die ganze Saison vergeben.
static func verkauf(d: Dictionary, cid: String) -> Dictionary:
	var t := daten(d, cid)
	var saison: int = Welt.saison_index()
	if int(t.get("verkauft_saison", -1)) == saison:
		return {}
	t["verkauft_saison"] = saison
	var erg := _nachfrage_dauerkarten(d, cid)
	t["dauerkarten"] = erg["verkauft"]
	var einnahme: float = float(erg["einnahme"])
	if einnahme > 0.0:
		Finanzen.buchen(d, cid, einnahme, "Dauerkartenverkauf", "zuschauer")
	return {"anzahl": dauerkarten_gesamt(d, cid), "einnahme": einnahme, "verkauft": erg["verkauft"]}

## Für Spielstände aus der Zeit vor den Dauerkarten: mitten in der Saison die
## Karten nachtragen, ohne Geld zu buchen. Sie gelten als längst bezahlt —
## sonst stünde bis zum Sommer eine Halle voller Tageskarten da.
static func nachtragen(d: Dictionary, cid: String) -> void:
	var t := daten(d, cid)
	if int(t.get("verkauft_saison", -1)) == Welt.saison_index():
		return
	if Kalender.tag_in_saison(int(d["tag"])) < 30:
		return
	t["verkauft_saison"] = Welt.saison_index()
	t["dauerkarten"] = _nachfrage_dauerkarten(d, cid)["verkauft"]

# -------------------------------------------------------------- Spieltag ---

## Wer an diesem Spieltag kommt — je Kategorie und insgesamt.
## `reiz` bündelt alles, was für die ganze Halle gilt: Gegner, Derby,
## Wettbewerb, Fanstimmung. `je_kategorie_reiz` kommt vom Spieltagsprogramm und
## wirkt gezielt — ein Familientag füllt die Sitzplätze, nicht die Kurve.
static func besucher(d: Dictionary, cid: String, reiz: float, streuung: float = 1.0,
		je_kategorie_reiz: Dictionary = {}) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	var fans: Dictionary = v["fans"]
	var sitze := plaetze(d, cid)
	var grund: float = 0.30 + float(fans["zufriedenheit"]) / 300.0 + float(fans["treue"]) / 360.0
	var aus := {"gesamt": 0, "dauerkarten": 0, "tageskarten": 0, "je_kategorie": {}}
	for k in KATEGORIEN:
		var kat: String = str(k)
		var gesamt_plaetze: int = int(sitze[kat])
		var dk: int = mini(dauerkarten(d, cid, kat), gesamt_plaetze)
		# Auch ein Dauerkartenbesitzer bleibt mal zu Hause — bei mieser
		# Stimmung häufiger. Genau das sieht man an leeren Blöcken.
		var erscheinen: float = clampf(0.80 + float(fans["zufriedenheit"]) / 480.0, 0.6, 0.98)
		var da_dk: int = int(round(float(dk) * erscheinen))
		var frei: int = maxi(gesamt_plaetze - dk, 0)
		var besonders: float = float(je_kategorie_reiz.get(kat, 1.0))
		var nachfrage: float = clampf(grund * nachfragefaktor(d, cid, kat) * reiz * besonders * streuung, 0.02, 1.0)
		var tages: int = int(round(float(frei) * nachfrage))
		var summe: int = mini(da_dk + tages, gesamt_plaetze)
		(aus["je_kategorie"] as Dictionary)[kat] = {
			"plaetze": gesamt_plaetze, "dauerkarten": da_dk, "tageskarten": tages, "gesamt": summe,
		}
		aus["gesamt"] = int(aus["gesamt"]) + summe
		aus["dauerkarten"] = int(aus["dauerkarten"]) + da_dk
		aus["tageskarten"] = int(aus["tageskarten"]) + tages
	return aus

## Einnahmen aus Tageskarten. Dauerkarten sind längst bezahlt und tauchen hier
## bewusst nicht auf — sonst wäre das Geld zweimal gebucht.
static func tageseinnahme(d: Dictionary, cid: String, aufschluesselung: Dictionary) -> float:
	var summe := 0.0
	for k in KATEGORIEN:
		var e: Dictionary = (aufschluesselung.get("je_kategorie", {}) as Dictionary).get(str(k), {})
		summe += float(e.get("tageskarten", 0)) * preis(d, cid, str(k))
	return summe

## Wie laut es wird: Stehplätze tragen die Stimmung, Logen kaum.
static func pulsanteil(aufschluesselung: Dictionary) -> float:
	var gewichtet := 0.0
	var moeglich := 0.0
	for k in KATEGORIEN:
		var e: Dictionary = (aufschluesselung.get("je_kategorie", {}) as Dictionary).get(str(k), {})
		var g: float = float((KATEGORIE[str(k)] as Dictionary)["puls"])
		gewichtet += float(e.get("gesamt", 0)) * g
		moeglich += float(e.get("plaetze", 0)) * g
	return clampf(gewichtet / maxf(moeglich, 1.0), 0.0, 1.0)

## Mittlerer Eintrittspreis über alle Kategorien — für Anzeige und Vergleich.
static func schnittpreis(d: Dictionary, cid: String) -> float:
	var sitze := plaetze(d, cid)
	var kap: float = 0.0
	var summe := 0.0
	for k in KATEGORIEN:
		var n: float = float(sitze[str(k)])
		kap += n
		summe += n * preis(d, cid, str(k))
	return summe / maxf(kap, 1.0)

## Wie die Preispolitik auf die Fans wirkt — je Woche, in Punkten.
static func fanwirkung(d: Dictionary, cid: String) -> float:
	# Der Stehplatz wiegt am schwersten: dort sitzt das Stammpublikum.
	var wirkung := 0.0
	for k in KATEGORIEN:
		var kat: String = str(k)
		var anteil: float = preis(d, cid, kat) / maxf(referenzpreis(d, cid, kat), 1.0)
		var gewicht: float = 1.0 if kat == "steh" else (0.6 if kat == "sitz" else 0.15)
		wirkung += clampf((1.0 - anteil) * 3.2, -3.0, 2.0) * gewicht
	return clampf(wirkung, -4.0, 2.6)

## Die KI stellt ihre Preise am Marktpreis auf, mit etwas eigenem Charakter.
static func ki_preise(d: Dictionary, cid: String) -> void:
	var t := daten(d, cid)
	var v: Dictionary = d["vereine"][cid]
	# Ein Verein mit leerer Kasse dreht am Preis, ein zufriedener lässt ihn.
	var not_faktor: float = 1.10 if float(v["kasse"]) < 0.0 else 1.0
	for k in KATEGORIEN:
		(t["preise"] as Dictionary)[k] = roundf(referenzpreis(d, cid, str(k)) * not_faktor * Namen.bereich(0.94, 1.06))
	t["dauerkarte_faktor"] = clampf(Namen.bereich(0.72, 0.92), DAUERKARTE_MIN, DAUERKARTE_MAX)
