extends Node
## Prueft die Ablöseklauseln: Wie viele Vertraege tragen eine, wie hoch liegen
## sie im Verhaeltnis zum Marktwert, und wie oft werden sie in einer Saison
## tatsaechlich gezogen?

func _ready() -> void:
	Welt.neues_spiel("c_001", {"vorname": "Test", "nachname": "Trainer", "hintergrund": "taktiker"}, 777)
	var d := Welt.daten
	var mit := 0
	var gesamt := 0
	var verhaeltnisse: Array = []
	for sp in d["spieler"].values():
		var v: Dictionary = sp.get("vertrag", {})
		if v.is_empty():
			continue
		gesamt += 1
		var k: float = float(v.get("ablöseklausel", 0.0))
		if k > 0.0:
			mit += 1
			verhaeltnisse.append(k / maxf(float(sp["wert"]), 1.0))
	verhaeltnisse.sort()
	printerr("Vertraege: %d, davon mit Klausel: %d (%.1f %%)" % [gesamt, mit, float(mit) / maxf(float(gesamt), 1.0) * 100.0])
	if not verhaeltnisse.is_empty():
		printerr("Klausel/Marktwert: min %.2f, median %.2f, max %.2f" % [
			verhaeltnisse[0], verhaeltnisse[verhaeltnisse.size() / 2], verhaeltnisse[-1]])
	var vorher := _klauselspieler(d)
	var tage := 0
	while tage < 330:
		var u := Welt.tag_weiter()
		if u.has("art") and str(u["art"]) == "eigenes_spiel":
			Welt.partie_simulieren(str(u["spiel"]))
			Welt.spieltag_abwickeln(Welt.tag())
			Welt.wochenrhythmus(Welt.tag())
			Welt.saison_pruefen(Welt.tag())
		tage += 1
	var gezogen := 0
	for sid in vorher.keys():
		if d["spieler"].has(sid) and str(d["spieler"][sid]["verein"]) != str(vorher[sid]):
			gezogen += 1
	printerr("Nach %d Tagen: %d von %d Klauselspielern haben den Verein gewechselt." % [tage, gezogen, vorher.size()])
	get_tree().quit()

func _klauselspieler(d: Dictionary) -> Dictionary:
	var aus := {}
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if float(sp.get("vertrag", {}).get("ablöseklausel", 0.0)) > 0.0:
			aus[sid] = str(sp["verein"])
	return aus
