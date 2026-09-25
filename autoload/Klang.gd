extends Node
## Klang — der Ton von Hallenherz, erzeugt statt geladen.
##
## Das Spiel hatte keinen einzigen Ton. Für ein Managerspiel ist das keine
## Kleinigkeit: die Live-Partie ist die einzige Stelle, an der man zusieht
## statt liest, und eine Halle ohne Geräusch ist keine Halle.
##
## Es kommt trotzdem keine Audiodatei ins Projekt. Dieselbe Regel, nach der
## jedes Wappen, jedes Gesicht und jedes Sinnbild gezeichnet und nicht
## abgelegt wird, gilt hier: die Klänge entstehen beim Start aus Rauschen,
## Sinus und Hüllkurven. Das kostet ein paar Millisekunden und spart jede
## Lizenzfrage, jeden Download und jede Frage nach dem Urheber.
##
## Was es gibt, ist bewusst wenig:
##
##   * die Halle — ein leises, langsam atmendes Rauschen, dessen Pegel am
##     Hallenpuls hängt. Eine volle Halle ist lauter als eine halbe.
##   * der Pfiff — Anwurf, Halbzeit, Schluss, Zeitstrafe.
##   * der Torjubel — ein kurzes Anschwellen, lauter im Heimspiel.
##   * ein Raunen — für die Parade und den Fehlwurf.
##
## Kein Klick auf Knöpfen, keine Musik. Ein Spiel, in dem man vierzig Stunden
## Tabellen liest, darf nicht bei jedem Druck etwas sagen.

## Abtastrate. 22050 genügt für Rauschen und einen Pfiff und halbiert die
## Rechenzeit beim Erzeugen gegenüber 44100.
const RATE := 22050

var _spieler: Dictionary = {}
var _halle: AudioStreamPlayer = null
var _bereit: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 4711
	# Ohne Tontreiber — im Kopfbetrieb, in dem alle Sonden laufen — wird nichts
	# erzeugt und nichts gespielt. Die Aufrufe bleiben gültig und tun nichts.
	if AudioServer.get_output_device_list().is_empty():
		return
	_erzeugen()
	_bereit = true
	pegel_setzen(float(Welt.einstellung("lautstaerke", 0.55)))

# ------------------------------------------------------------- Erzeugung ---

func _erzeugen() -> void:
	_anlegen("pfiff", _pfiff(0.34))
	_anlegen("pfiff_lang", _pfiff(0.85))
	_anlegen("jubel", _menge(1.7, 0.95, 0.55))
	_anlegen("raunen", _menge(0.9, 0.42, 0.30))
	var halle := _rauschbett(4.0)
	_halle = AudioStreamPlayer.new()
	_halle.stream = halle
	_halle.volume_db = -60.0
	add_child(_halle)

func _anlegen(name: String, strom: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = strom
	add_child(p)
	_spieler[name] = p

## Ein Schiedsrichterpfiff: zwei dicht beieinanderliegende Töne, die
## gegeneinander schweben, dazu das Rauschen der Kugel im Pfeifenkörper.
func _pfiff(dauer: float) -> AudioStreamWAV:
	var n: int = int(dauer * RATE)
	var werte := PackedFloat32Array()
	werte.resize(n)
	var glaettung := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var anteil: float = float(i) / float(n)
		# Anschlag in zwanzig Millisekunden, danach gleichmäßig abfallen.
		var huelle: float = minf(t / 0.02, 1.0) * pow(1.0 - anteil, 0.7)
		var ton: float = sin(TAU * 3380.0 * t) * 0.6 + sin(TAU * 4270.0 * t) * 0.4
		# Die Kugel: schnelles Flattern auf dem Grundton.
		ton *= 0.82 + 0.18 * sin(TAU * 28.0 * t)
		glaettung += 0.35 * (_rng.randf_range(-1.0, 1.0) - glaettung)
		werte[i] = clampf((ton * 0.82 + glaettung * 0.18) * huelle * 0.5, -1.0, 1.0)
	return _wav(werte, false)

## Eine Menschenmenge: gefiltertes Rauschen mit einer Hüllkurve, die schnell
## ansteigt und langsam abfällt. Mehr braucht ein Jubel nicht.
func _menge(dauer: float, spitze: float, anstieg: float) -> AudioStreamWAV:
	var n: int = int(dauer * RATE)
	var werte := PackedFloat32Array()
	werte.resize(n)
	var tief := 0.0
	var mittel := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var roh: float = _rng.randf_range(-1.0, 1.0)
		# Zwei Filterstufen: der tiefe Anteil trägt, der mittlere gibt die
		# Stimmen. Ohne den mittleren klingt es wie Wind.
		tief += 0.06 * (roh - tief)
		mittel += 0.30 * (roh - mittel)
		var huelle: float
		if t < anstieg:
			huelle = pow(t / anstieg, 0.6)
		else:
			huelle = pow(1.0 - (t - anstieg) / maxf(dauer - anstieg, 0.001), 1.5)
		werte[i] = clampf((tief * 2.4 + mittel * 0.9) * huelle * spitze * 0.5, -1.0, 1.0)
	return _wav(werte, false)

## Das Bett: ein Rauschen, das langsam atmet und sich nahtlos wiederholt.
##
## Nahtlos wird es dadurch, dass die letzten zweihundert Millisekunden in den
## Anfang übergeblendet werden — sonst knackt es bei jeder Runde.
func _rauschbett(dauer: float) -> AudioStreamWAV:
	var n: int = int(dauer * RATE)
	var werte := PackedFloat32Array()
	werte.resize(n)
	var tief := 0.0
	var mittel := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var roh: float = _rng.randf_range(-1.0, 1.0)
		tief += 0.045 * (roh - tief)
		mittel += 0.22 * (roh - mittel)
		var atem: float = 0.80 + 0.20 * sin(TAU * 0.13 * t) + 0.08 * sin(TAU * 0.37 * t)
		werte[i] = clampf((tief * 2.6 + mittel * 0.55) * atem * 0.5, -1.0, 1.0)
	var blende: int = int(0.2 * RATE)
	for i in blende:
		var f: float = float(i) / float(blende)
		werte[i] = werte[i] * f + werte[n - blende + i] * (1.0 - f)
	var strom := _wav(werte, true)
	strom.loop_begin = 0
	strom.loop_end = n - blende
	return strom

## Aus Gleitkommawerten von -1 bis 1 wird ein 16-Bit-Strom.
func _wav(werte: PackedFloat32Array, schleife: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(werte.size() * 2)
	for i in werte.size():
		var s: int = int(clampf(werte[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, s)
	var strom := AudioStreamWAV.new()
	strom.format = AudioStreamWAV.FORMAT_16_BITS
	strom.mix_rate = RATE
	strom.stereo = false
	strom.data = bytes
	strom.loop_mode = AudioStreamWAV.LOOP_FORWARD if schleife else AudioStreamWAV.LOOP_DISABLED
	return strom

# ---------------------------------------------------------------- Spielen ---

func spiele(name: String, db: float = 0.0) -> void:
	if not _bereit or not _spieler.has(name):
		return
	var p: AudioStreamPlayer = _spieler[name]
	p.volume_db = db
	p.play()

## Die Halle an- und ausschalten. `puls` ist der Hallenpuls von 0 bis 100.
func halle_an(puls: float) -> void:
	if not _bereit or _halle == null:
		return
	halle_pegel(puls)
	if not _halle.playing:
		_halle.play()

func halle_aus() -> void:
	if not _bereit or _halle == null:
		return
	_halle.stop()

## Eine volle, laute Halle ist hörbar voller als eine halbleere — das ist der
## Sinn des Hallenpulses, und man soll ihn nicht nur als Zahl sehen.
func halle_pegel(puls: float) -> void:
	if not _bereit or _halle == null:
		return
	_halle.volume_db = lerpf(-30.0, -14.0, clampf(puls / 100.0, 0.0, 1.0))

## Gesamtlautstärke von 0 bis 1. 0 schaltet den Ton ganz ab.
func pegel_setzen(wert: float) -> void:
	var v: float = clampf(wert, 0.0, 1.0)
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_mute(0, v <= 0.001)
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))
