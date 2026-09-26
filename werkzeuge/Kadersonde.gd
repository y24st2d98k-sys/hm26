extends Node
## Wie sieht ein Kader nach ein paar Jahren aus — und wie sollte er aussehen?
##
## Die Alterssonde hat gezeigt: die Spitze der Simulation ist stärker als die
## der erzeugten Welt, der Mittelwert ist schwächer. Die besten
## Zweiundzwanzigjährigen stehen bei 87,2 gegen 81,0 — wer oben ankommt,
## kommt schnell genug an. Der Fehlbetrag steckt im Mittelwert, und der
## Verdacht lautet: die Vereine schleppen zu viele zu schwache Spieler mit.
##
## Diese Sonde prüft den Verdacht. Sie vergleicht Kadergröße, Altersaufbau
## und vor allem den Abstand jedes Spielers zur Stammsieben seines Vereins:
## wer weit darunter liegt, steht in einem echten Profikader nicht.
##
##     godot --headless res://werkzeuge/Kadersonde.tscn -- <jahre>

const SAAT := 6161
## Wie weit unter der eigenen Stammsieben jemand liegen darf, bevor er als
## Mitläufer zählt. Fünfzehn Punkte sind der Abstand vom Leistungsträger zum
## Ergänzungsspieler; wer mehr als das zurückliegt, spielt nicht mehr mit.
const MITLAEUFER_ABSTAND := 15.0

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var jahre: int = int(args[0]) if args.size() > 0 else 4
	seed(SAAT)
	var vorschau := Weltgenerator.erzeuge(2026, SAAT)
	var cid: String = str(vorschau["ligen"]["l_de1"]["vereine"][0])
	seed(SAAT)
	Welt.neues_spiel(cid, {"vorname": "Kader", "nachname": "Sonde"}, SAAT)
	var d: Dictionary = Welt.daten
	_log("")
	_log("=== Kaderaufbau der Bundesliga ===")
	_log("")
	_log("%-22s %8s %9s %10s %11s %10s" % ["Stand", "Größe", "Alter Ø",
		"Stammsieben", "Mitläufer", "Anteil"])
	_bericht(d, "Erzeugte Welt")

	var tage := 0
	while tage < jahre * 365:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		tage += 1
		if tage % 365 == 0:
			_bericht(d, "Nach %d Jahr%s" % [tage / 365, "" if tage == 365 else "en"])
	_log("")
	_log("Mitläufer sind Spieler, die mehr als %d Punkte unter der Stammsieben" % int(MITLAEUFER_ABSTAND))
	_log("ihres eigenen Vereins liegen. In einem echten Profikader stehen sie nicht.")
	get_tree().quit()

func _bericht(d: Dictionary, titel: String) -> void:
	var lid := ""
	for l in (d["ligen"] as Dictionary).keys():
		if str(d["ligen"][l].get("kurz", "")) == "HBL":
			lid = str(l)
			break
	if lid == "":
		return
	var groesse := 0.0
	var alter := 0.0
	var spieler := 0
	var stamm_summe := 0.0
	var mitlaeufer := 0
	var herkunft := {}
	var vereine: Array = d["ligen"][lid]["vereine"]
	for c in vereine:
		var kader: Array = d["vereine"][str(c)].get("kader", [])
		groesse += float(kader.size())
		var werte: Array = []
		for sid in kader:
			var sp: Dictionary = d["spieler"][str(sid)]
			werte.append(Spielerfabrik.gesamt(sp))
			alter += float(int(sp["alter"]))
			spieler += 1
		werte.sort()
		werte.reverse()
		var stamm := 0.0
		var k: int = mini(7, werte.size())
		for i in k:
			stamm += float(werte[i])
		stamm = stamm / maxf(float(k), 1.0)
		stamm_summe += stamm
		# Und woher sie kommen. Die Zahl allein sagt nur, dass zu viele zu
		# schwache Spieler in den Kadern stehen; erst die Herkunft sagt, an
		# welcher Tuer sie hereinkommen.
		for sid2 in kader:
			var sp2: Dictionary = d["spieler"][str(sid2)]
			if Spielerfabrik.gesamt(sp2) >= stamm - MITLAEUFER_ABSTAND:
				continue
			mitlaeufer += 1
			var her := "gekauft oder geerbt"
			if str(sp2.get("ausbildungsverein", "")) == str(c):
				her = "eigene Akademie"
			elif str(sp2.get("ausbildungsverein", "")) != "":
				her = "fremde Akademie"
			elif int(sp2["alter"]) >= 32:
				her = "gealtert"
			herkunft[her] = int(herkunft.get(her, 0)) + 1
	var n: float = float(vereine.size())
	_log("%-22s %8.1f %9.1f %10.1f %11.1f %9.1f %%   %s" % [titel, groesse / n,
		alter / maxf(float(spieler), 1.0), stamm_summe / n,
		float(mitlaeufer) / n, float(mitlaeufer) / maxf(float(spieler), 1.0) * 100.0,
		_herkunftstext(herkunft, mitlaeufer)])

## Die Herkunft der Mitläufer in einer Zeile.
func _herkunftstext(herkunft: Dictionary, gesamt: int) -> String:
	if gesamt <= 0:
		return ""
	var liste: Array = herkunft.keys()
	liste.sort_custom(func(a, b): return int(herkunft[a]) > int(herkunft[b]))
	var teile: PackedStringArray = PackedStringArray()
	for k in liste:
		teile.append("%s %d %%" % [str(k), int(round(float(herkunft[k]) / float(gesamt) * 100.0))])
	return "  ".join(teile)
