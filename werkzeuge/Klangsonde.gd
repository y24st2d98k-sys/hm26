extends Node
## Lässt sich der Ton überhaupt erzeugen, und was kostet er?
##
## Der Klang entsteht beim Start aus Rauschen und Sinus. Im Kopfbetrieb gibt
## es kein Tongerät, also wird er übersprungen — und damit auch nie geprüft.
## Diese Sonde erzwingt die Erzeugung, misst sie und sieht nach, ob die
## Puffer plausibel gefüllt sind. Hören kann sie nichts; was sie ausschließt,
## sind Abstürze, leere Puffer und eine Startverzögerung, die auffällt.

func _log(t: String) -> void:
	printerr(t)

func _ready() -> void:
	_log("")
	_log("=== Klangerzeugung ===")
	_log("")
	var t0 := Time.get_ticks_usec()
	Klang._erzeugen()
	var dauer: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_log("Erzeugung: %.1f ms" % dauer)
	if dauer > 250.0:
		_log("  ZU LANGSAM — das verzögert jeden Start spürbar.")
	_log("")
	_log("%-14s %10s %10s %9s %9s" % ["Klang", "Sekunden", "Bytes", "Spitze", "Effektiv"])
	var alles_gut := true
	for name in ["pfiff", "pfiff_lang", "jubel", "raunen"]:
		if not Klang._spieler.has(name):
			_log("%-14s FEHLT" % name)
			alles_gut = false
			continue
		alles_gut = _bericht(name, (Klang._spieler[name] as AudioStreamPlayer).stream) and alles_gut
	if Klang._halle != null:
		alles_gut = _bericht("halle", Klang._halle.stream) and alles_gut
	else:
		_log("halle FEHLT")
		alles_gut = false
	_log("")
	_log("— Klang %s —" % ("in Ordnung" if alles_gut else "FEHLERHAFT"))
	get_tree().quit()

## Spitze und Effektivwert sagen, ob überhaupt etwas im Puffer steht: ein
## stiller Klang ist kein Klang, ein übersteuerter ist Krach.
func _bericht(name: String, strom: AudioStreamWAV) -> bool:
	if strom == null or strom.data.is_empty():
		_log("%-14s LEER" % name)
		return false
	var n: int = strom.data.size() / 2
	var spitze := 0.0
	var summe := 0.0
	for i in n:
		var w: float = float(strom.data.decode_s16(i * 2)) / 32768.0
		spitze = maxf(spitze, absf(w))
		summe += w * w
	var effektiv: float = sqrt(summe / float(n))
	var sekunden: float = float(n) / float(strom.mix_rate)
	_log("%-14s %10.2f %10d %9.3f %9.3f" % [name, sekunden, strom.data.size(), spitze, effektiv])
	if spitze < 0.05:
		_log("  zu leise — da ist nichts drin.")
		return false
	if spitze > 0.999:
		_log("  übersteuert — der Puffer läuft an den Anschlag.")
		return false
	if effektiv < 0.005:
		_log("  effektiv still.")
		return false
	return true
