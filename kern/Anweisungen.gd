class_name Anweisungen
extends RefCounted
## Individuelle Spieleranweisungen für Angriff und Abwehr.
##
## Die Mannschaftstaktik sagt, *wie* gespielt wird — die Anweisung sagt, was ein
## einzelner Spieler darin tun soll. Wer den Abschluss sucht, wirft öfter, aber
## aus schlechteren Lagen; wer eröffnet, wirft seltener und verliert weniger
## Bälle; wer das Eins-gegen-Eins sucht, zieht Siebenmeter und Fehler zugleich.
##
## Gespeichert wird je Verein in `aufstellung["anweisungen"][sid]`. Damit hängt
## die Anweisung am Spieler und nicht an der Position — ein Wechsel bringt sie
## automatisch mit aufs Feld.

const ANGRIFF := {
	"normal": {
		"name": "Ausgeglichen",
		"text": "Spielt, was sich anbietet.",
		"wurfanteil": 1.0, "wurfguete": 0.0, "fehler": 1.0, "siebenmeter": 1.0, "kreis": 1.0,
	},
	"abschluss": {
		"name": "Abschluss suchen",
		"text": "Zieht deutlich öfter ab — auch aus Lagen, die nicht ideal sind.",
		"wurfanteil": 1.45, "wurfguete": -3.4, "fehler": 1.0, "siebenmeter": 1.0, "kreis": 1.0,
	},
	"vorbereiten": {
		"name": "Spiel eröffnen",
		"text": "Sucht den Pass statt den Wurf. Weniger Abschlüsse, weniger Ballverluste.",
		"wurfanteil": 0.55, "wurfguete": 1.5, "fehler": 0.92, "siebenmeter": 1.0, "kreis": 1.0,
	},
	"durchbruch": {
		"name": "Eins gegen Eins",
		"text": "Geht in den Zweikampf. Zieht Siebenmeter — und macht mehr Fehler.",
		"wurfanteil": 1.15, "wurfguete": -1.4, "fehler": 1.12, "siebenmeter": 1.26, "kreis": 1.0,
	},
	"kreis_anspielen": {
		"name": "Kreis anspielen",
		"text": "Sucht konsequent den Kreisläufer. Der eigene Abschluss tritt zurück.",
		"wurfanteil": 0.62, "wurfguete": 0.0, "fehler": 1.0, "siebenmeter": 1.0, "kreis": 1.30,
	},
}

const ABWEHR := {
	"normal": {
		"name": "Position halten",
		"text": "Steht im System.",
		"block": 1.0, "ballgewinn": 1.0, "zeitstrafe": 1.0,
	},
	"offensiv": {
		"name": "Vorschieben",
		"text": "Attackiert früh. Mehr Ballgewinne, mehr Zeitstrafen, weniger Block.",
		"block": 0.86, "ballgewinn": 1.20, "zeitstrafe": 1.60,
	},
	"block": {
		"name": "Block stellen",
		"text": "Bleibt in der Wurfbahn. Mehr Blocks, weniger Ballgewinne.",
		"block": 1.20, "ballgewinn": 0.92, "zeitstrafe": 0.96,
	},
	"absichern": {
		"name": "Absichern",
		"text": "Vermeidet Risiko. Kaum Zeitstrafen, aber auch kaum Ballgewinne.",
		"block": 1.04, "ballgewinn": 0.94, "zeitstrafe": 0.76,
	},
}

## Vorschlag anhand von Position und Stärken — was der Trainerstab empfehlen würde.
static func vorschlag(sp: Dictionary) -> Dictionary:
	if bool(sp.get("ist_torwart", false)):
		return {"angriff": "normal", "abwehr": "normal"}
	var attr: Dictionary = sp["attr"]
	var pos: String = str(sp["position"])
	var uebersicht: float = float(attr.get("uebersicht", 10.0))
	var taeuschung: float = float(attr.get("taeuschung", 10.0))
	var angriff := "normal"
	if pos == "RM" and uebersicht >= 14.0:
		angriff = "vorbereiten"
	elif (pos == "LA" or pos == "RA") and taeuschung >= 14.0:
		angriff = "durchbruch"
	elif float(attr.get("wurfkraft", 10.0)) + float(attr.get("wurfpraezision", 10.0)) >= 30.0:
		angriff = "abschluss"
	elif pos != "KM" and uebersicht >= 14.0:
		angriff = "kreis_anspielen"
	elif taeuschung >= 15.0:
		angriff = "durchbruch"
	# In der Abwehr zuerst pruefen, wer vorschieben kann: ein antizipations-
	# starker, schneller Spieler stoert vorne mehr, als er im Block bringt.
	var block_wert: float = float(attr.get("block", 10.0))
	var antizipation: float = float(attr.get("antizipation", 10.0))
	var abwehr := "normal"
	if antizipation >= 13.0 and float(attr.get("tempo", 10.0)) >= 12.0 and antizipation > block_wert:
		abwehr = "offensiv"
	elif block_wert >= 15.0:
		abwehr = "block"
	elif float(attr.get("deckungsarbeit", 10.0)) >= 15.0:
		abwehr = "absichern"
	return {"angriff": angriff, "abwehr": abwehr}

# ------------------------------------------------------------- Zugriff ---

static func fuer(d: Dictionary, cid: String, sid: String) -> Dictionary:
	var auf: Dictionary = d["vereine"][cid].get("aufstellung", {})
	var alle: Dictionary = auf.get("anweisungen", {})
	var e: Dictionary = alle.get(sid, {})
	return {
		"angriff": str(e.get("angriff", "normal")),
		"abwehr": str(e.get("abwehr", "normal")),
	}

static func setzen(d: Dictionary, cid: String, sid: String, bereich: String, wert: String) -> void:
	var auf: Dictionary = d["vereine"][cid]["aufstellung"]
	if not auf.has("anweisungen"):
		auf["anweisungen"] = {}
	if not (auf["anweisungen"] as Dictionary).has(sid):
		auf["anweisungen"][sid] = {"angriff": "normal", "abwehr": "normal"}
	(auf["anweisungen"][sid] as Dictionary)[bereich] = wert

## Alle Anweisungen eines Vereins auf den Vorschlag des Trainerstabs setzen.
static func automatisch(d: Dictionary, cid: String) -> void:
	for sid in d["vereine"][cid]["kader"]:
		var v := vorschlag(d["spieler"][sid])
		setzen(d, cid, sid, "angriff", str(v["angriff"]))
		setzen(d, cid, sid, "abwehr", str(v["abwehr"]))

## Wie viele Spieler eines Kaders von der Voreinstellung abweichen.
static func gesetzt(d: Dictionary, cid: String) -> int:
	var alle: Dictionary = d["vereine"][cid].get("aufstellung", {}).get("anweisungen", {})
	var n := 0
	for sid in alle.keys():
		var e: Dictionary = alle[sid]
		if str(e.get("angriff", "normal")) != "normal" or str(e.get("abwehr", "normal")) != "normal":
			n += 1
	return n
