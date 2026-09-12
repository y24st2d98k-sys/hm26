extends Node
## Prueft die synthetisierten Klaenge: Laenge, Spitzenpegel, Effektivwert und
## Nulldurchgangsrate (grobe Tonhoehenkontrolle). Ohne Lautsprecher ist das die
## einzige Moeglichkeit, Stille oder Uebersteuerung zu bemerken.

func _ready() -> void:
	var namen := ["pfiff", "anpfiff", "tor", "tor_gegen", "parade", "raunen",
		"ball", "sirene", "klick", "blaettern", "atmo"]
	printerr("%-12s %8s %8s %8s %10s" % ["Klang", "Sek", "Spitze", "RMS", "Nulldg/s"])
	for n in namen:
		_bericht(n, Klang._effekte.get(n))
	_bericht("musik", Klang._musik)
	get_tree().quit()

func _bericht(name: String, stream) -> void:
	if stream == null:
		printerr("%-12s FEHLT" % name)
		return
	var s := stream as AudioStreamWAV
	var daten: PackedByteArray = s.data
	var n: int = daten.size() / 2
	if n == 0:
		printerr("%-12s LEER" % name)
		return
	var spitze := 0.0
	var summe := 0.0
	var wechsel := 0
	var vorher := 0.0
	for i in range(n):
		var v: float = float(daten.decode_s16(i * 2)) / 32768.0
		spitze = maxf(spitze, absf(v))
		summe += v * v
		if (v >= 0.0) != (vorher >= 0.0):
			wechsel += 1
		vorher = v
	var sek: float = float(n) / float(s.mix_rate)
	printerr("%-12s %8.2f %8.3f %8.3f %10.0f" % [name, sek, spitze, sqrt(summe / float(n)),
		float(wechsel) / maxf(sek, 0.001) * 0.5])
