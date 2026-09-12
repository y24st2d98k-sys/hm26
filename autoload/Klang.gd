extends Node
## Klang — alle Geräusche und die Musik von Hallenherz.
##
## Es liegt keine einzige Audiodatei im Projekt. Jeder Klang wird beim Start
## als PCM-Puffer berechnet und als AudioStreamWAV in den Speicher gelegt:
## die Schiedsrichterpfeife aus zwei verstimmten Sinustönen mit Vibrato, der
## Torjubel aus gefiltertem Rauschen mit einer Hüllkurve, die Hallenatmosphäre
## aus einer langsam wogenden Rauschschleife, die Musik aus Pad-Akkorden,
## Bass und einer sparsamen Melodie.
##
## Die Hallenatmosphäre folgt dem Hallenpuls: je lauter die Halle im
## Spielmodell, desto lauter wirklich zu hören.

const RATE := 22050
const KANAELE := 1

var _effekte: Dictionary = {}
var _musik: AudioStreamWAV
var _spieler_effekt: Array[AudioStreamPlayer] = []
var _naechster: int = 0
var _atmo: AudioStreamPlayer
var _musikspieler: AudioStreamPlayer
var _atmo_ziel: float = -80.0
var _atmo_ist: float = -80.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20260701
	_busse_anlegen()
	_baue_effekte()
	_eigene_dateien_laden()
	_musik = _laden_oder("musik", func(): return _baue_musik())
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "Halle"
		add_child(p)
		_spieler_effekt.append(p)
	_atmo = AudioStreamPlayer.new()
	_atmo.stream = _effekte.get("atmo")
	_atmo.bus = "Halle"
	_atmo.volume_db = -80.0
	add_child(_atmo)
	_musikspieler = AudioStreamPlayer.new()
	_musikspieler.stream = _musik
	_musikspieler.bus = "Musik"
	_musikspieler.volume_db = -80.0
	add_child(_musikspieler)
	set_process(true)

## Zwei eigene Busse: "Halle" traegt Nachhall und eine leichte Hoehenabsenkung,
## damit alles klingt, als stuende es in einer Sporthalle statt im Kopfhoerer.
## "Musik" bekommt nur wenig Raum und eine Kompression gegen Pegelspruenge.
func _busse_anlegen() -> void:
	if AudioServer.get_bus_index("Halle") >= 0:
		return
	var halle := AudioServer.bus_count
	AudioServer.add_bus(halle)
	AudioServer.set_bus_name(halle, "Halle")
	AudioServer.set_bus_send(halle, "Master")
	var hall := AudioEffectReverb.new()
	hall.room_size = 0.86
	hall.damping = 0.42
	hall.spread = 0.9
	hall.wet = 0.34
	hall.dry = 0.82
	hall.predelay_msec = 28.0
	AudioServer.add_bus_effect(halle, hall)
	var tief := AudioEffectLowPassFilter.new()
	tief.cutoff_hz = 9000.0
	AudioServer.add_bus_effect(halle, tief)

	var musik := AudioServer.bus_count
	AudioServer.add_bus(musik)
	AudioServer.set_bus_name(musik, "Musik")
	AudioServer.set_bus_send(musik, "Master")
	var mhall := AudioEffectReverb.new()
	mhall.room_size = 0.6
	mhall.wet = 0.18
	mhall.dry = 0.9
	AudioServer.add_bus_effect(musik, mhall)
	var druck := AudioEffectCompressor.new()
	druck.threshold = -16.0
	druck.ratio = 3.0
	AudioServer.add_bus_effect(musik, druck)

# ------------------------------------------------------- Eigene Dateien ---

## Ordner, in den eigene Klaenge gelegt werden koennen. Was hier liegt,
## ersetzt den synthetisierten Klang gleichen Namens.
const KLANGORDNER := "res://assets/klang"
const ENDUNGEN := ["ogg", "wav", "mp3"]

var eigene: Array = []

## Sucht zu jedem Klangnamen eine Datei im Assets-Ordner.
func _eigene_dateien_laden() -> void:
	for name in _effekte.keys():
		var geladen := _datei(name)
		if geladen != null:
			_effekte[name] = geladen
			eigene.append(name)

## Laedt eine Datei, wenn es sie gibt — sonst das Ergebnis der Synthese.
func _laden_oder(name: String, bauen: Callable) -> AudioStream:
	var geladen := _datei(name)
	if geladen != null:
		eigene.append(name)
		return geladen
	return bauen.call()

func _datei(name: String) -> AudioStream:
	for endung in ENDUNGEN:
		var pfad := "%s/%s.%s" % [KLANGORDNER, name, endung]
		if ResourceLoader.exists(pfad):
			var res := ResourceLoader.load(pfad)
			if res is AudioStream:
				return res
	return null

## Fuer die Anzeige in den Einstellungen: welche Klaenge aus Dateien stammen.
func eigene_klaenge() -> Array:
	return eigene

# ------------------------------------------------------------ Einstellungen ---

func _an(schluessel: String) -> bool:
	return bool(Welt.einstellung(schluessel, true))

func lautstaerke(schluessel: String) -> float:
	return clampf(float(Welt.einstellung(schluessel, 70.0)), 0.0, 100.0) / 100.0

func _db(anteil: float) -> float:
	if anteil <= 0.001:
		return -80.0
	return linear_to_db(anteil)

# ---------------------------------------------------------------- Abspielen ---

## Einen Effekt abspielen. staerke skaliert die Lautstärke (0..1).
func spiele(name: String, staerke: float = 1.0, tonhoehe: float = 1.0) -> void:
	if not _an("ton_an") or not _effekte.has(name):
		return
	var pegel: float = lautstaerke("lautstaerke_effekte") * clampf(staerke, 0.0, 1.4)
	if pegel <= 0.01:
		return
	var p: AudioStreamPlayer = _spieler_effekt[_naechster]
	_naechster = (_naechster + 1) % _spieler_effekt.size()
	p.stream = _effekte[name]
	p.pitch_scale = clampf(tonhoehe, 0.5, 2.0)
	p.volume_db = _db(pegel)
	p.play()

## Hallenatmosphäre starten und über den Hallenpuls steuern.
func atmo_start() -> void:
	if not _an("ton_an") or _atmo.stream == null:
		return
	if not _atmo.playing:
		_atmo.play()

func atmo_stop() -> void:
	_atmo_ziel = -80.0

## puls 0..100 aus der Spielsimulation.
func atmo_puls(puls: float) -> void:
	var anteil: float = lautstaerke("lautstaerke_atmo") * (0.18 + clampf(puls, 0.0, 100.0) / 100.0 * 0.82)
	_atmo_ziel = _db(anteil) if _an("ton_an") else -80.0

func musik_start() -> void:
	if not _an("ton_an") or _musikspieler.stream == null:
		return
	var pegel: float = lautstaerke("lautstaerke_musik")
	if pegel <= 0.01:
		_musikspieler.stop()
		return
	_musikspieler.volume_db = _db(pegel * 0.5)
	if not _musikspieler.playing:
		_musikspieler.play()

func musik_stop() -> void:
	_musikspieler.stop()

func _process(delta: float) -> void:
	# Die Atmosphäre wird weich nachgeführt, damit sie nicht springt.
	if absf(_atmo_ist - _atmo_ziel) > 0.2:
		_atmo_ist = lerpf(_atmo_ist, _atmo_ziel, clampf(delta * 2.5, 0.0, 1.0))
		_atmo.volume_db = _atmo_ist
		if _atmo_ist <= -60.0 and _atmo.playing and _atmo_ziel <= -70.0:
			_atmo.stop()

# ------------------------------------------------------------- Synthese ---

func _puffer(sekunden: float) -> PackedFloat32Array:
	var n: int = int(sekunden * float(RATE))
	var a := PackedFloat32Array()
	a.resize(n)
	return a

## Hüllkurve: Anstieg, Halten, Abfall — alles in Sekunden.
func _huelle(i: int, n: int, anstieg: float, abfall: float) -> float:
	var t: float = float(i) / float(RATE)
	var gesamt: float = float(n) / float(RATE)
	var auf: float = clampf(t / maxf(anstieg, 0.0001), 0.0, 1.0)
	var ab: float = clampf((gesamt - t) / maxf(abfall, 0.0001), 0.0, 1.0)
	return auf * ab

## Einfacher Einpol-Tiefpass — macht aus weissem Rauschen ein weiches Rauschen.
func _tiefpass(a: PackedFloat32Array, faktor: float) -> PackedFloat32Array:
	var letzter := 0.0
	for i in range(a.size()):
		letzter = letzter + (a[i] - letzter) * faktor
		a[i] = letzter
	return a

## Resonanter Bandpass (State-Variable-Filter). Damit bekommt Rauschen eine
## Tonhoehe — erst dadurch klingt eine Menschenmenge nach Stimmen und nicht
## nach Wind.
func _bandpass(a: PackedFloat32Array, mitte: float, guete: float) -> PackedFloat32Array:
	var f: float = 2.0 * sin(PI * clampf(mitte, 20.0, float(RATE) * 0.45) / float(RATE))
	var q: float = 1.0 / maxf(guete, 0.3)
	var tief := 0.0
	var band := 0.0
	var aus := PackedFloat32Array()
	aus.resize(a.size())
	for i in range(a.size()):
		var hoch: float = a[i] - tief - q * band
		band += f * hoch
		tief += f * band
		aus[i] = band
	return aus

func _mischen(ziel: PackedFloat32Array, quelle: PackedFloat32Array, pegel: float) -> void:
	for i in range(mini(ziel.size(), quelle.size())):
		ziel[i] += quelle[i] * pegel

func _rauschen(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	for i in range(n):
		a[i] = _rng.randf_range(-1.0, 1.0)
	return a

func _normieren(a: PackedFloat32Array, spitze: float = 0.85) -> PackedFloat32Array:
	var maximum := 0.0
	for v in a:
		maximum = maxf(maximum, absf(v))
	if maximum < 0.0001:
		return a
	var f: float = spitze / maximum
	for i in range(a.size()):
		a[i] = a[i] * f
	return a

func _zu_stream(a: PackedFloat32Array, schleife: bool = false) -> AudioStreamWAV:
	var daten := PackedByteArray()
	daten.resize(a.size() * 2)
	for i in range(a.size()):
		var wert: int = int(clampf(a[i], -1.0, 1.0) * 32767.0)
		daten.encode_s16(i * 2, wert)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = daten
	if schleife:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = a.size()
	return s

# ------------------------------------------------------------- Die Klänge ---

func _baue_effekte() -> void:
	_effekte["pfiff"] = _zu_stream(_pfiff(0.42))
	_effekte["anpfiff"] = _zu_stream(_pfiff(0.75))
	_effekte["tor"] = _zu_stream(_jubel(1.5, 1.0))
	_effekte["tor_gegen"] = _zu_stream(_jubel(1.1, 0.45))
	_effekte["parade"] = _zu_stream(_jubel(0.8, 0.6))
	_effekte["raunen"] = _zu_stream(_jubel(0.7, 0.25))
	_effekte["ball"] = _zu_stream(_ballaufprall())
	_effekte["sirene"] = _zu_stream(_sirene())
	_effekte["klick"] = _zu_stream(_klick())
	_effekte["blaettern"] = _zu_stream(_blaettern())
	_effekte["atmo"] = _zu_stream(_atmosphaere(6.0), true)

## Schiedsrichterpfeife. Drei Bestandteile machen den Unterschied: ein kurzer
## Anblas-Chirp, der Grundton mit seinem leicht verstimmten Zwilling, und das
## Rasseln der Erbse als schnelles Vibrato plus Luftrauschen.
func _pfiff(dauer: float) -> PackedFloat32Array:
	var n: int = int(dauer * float(RATE))
	var a := _puffer(dauer)
	var luft := _bandpass(_rauschen(n), 3200.0, 1.4)
	for i in range(n):
		var t: float = float(i) / float(RATE)
		# Anblasen: die Tonhöhe zieht in 35 ms nach oben
		var anblas: float = clampf(t / 0.035, 0.0, 1.0)
		var grund: float = lerpf(1900.0, 2880.0, anblas)
		# Erbse: schnelles, unregelmäßiges Vibrato
		grund += sin(TAU * 31.0 * t) * 22.0 + sin(TAU * 47.0 * t) * 9.0
		var wert: float = sin(TAU * grund * t) * 0.62
		wert += sin(TAU * grund * 1.011 * t) * 0.46
		wert += sin(TAU * grund * 2.02 * t) * 0.13
		wert += sin(TAU * grund * 3.01 * t) * 0.05
		# Rauschanteil vorne stark, dann zurücknehmen
		wert += luft[i] * (0.30 * exp(-t * 26.0) + 0.05)
		a[i] = wert * _huelle(i, n, 0.010, 0.075)
	return _normieren(a, 0.58)

## Jubel einer Menschenmenge. Aufgebaut aus drei Schichten:
## ein tiefes Grollen, mehrere Resonanzbänder im Stimmbereich (das ist der
## Unterschied zwischen "Wind" und "Menschen") und einzelne Klatschtransienten.
func _jubel(dauer: float, kraft: float) -> PackedFloat32Array:
	var n: int = int(dauer * float(RATE))
	var a := _puffer(dauer)
	var roh := _rauschen(n)

	# Grundteppich: tiefes, weiches Rauschen
	var tief := _tiefpass(roh.duplicate(), 0.09)
	tief = _tiefpass(tief, 0.14)
	_mischen(a, tief, 2.6)

	# Stimmbänder — drei Formanten, wie sie ein "Ooooh" hat
	for paar in [[330.0, 4.0, 0.9], [720.0, 3.2, 0.7], [1450.0, 2.6, 0.4]]:
		var band := _bandpass(roh, float(paar[0]), float(paar[1]))
		_mischen(a, band, float(paar[2]))

	# Hüllkurve: schneller Anstieg, langes Ausklingen
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var form: float = pow(clampf(t / (dauer * 0.16), 0.0, 1.0), 0.65)
		form *= pow(clampf((dauer - t) / (dauer * 0.82), 0.0, 1.0), 1.3)
		# Leichtes Wogen, damit die Menge lebt
		form *= 0.86 + 0.14 * sin(TAU * 3.1 * t + sin(TAU * 0.7 * t))
		a[i] = a[i] * form * kraft

	# Klatschen: kurze, gefilterte Knackser über die erste Hälfte verteilt
	var klatscher: int = int(60.0 * kraft * dauer)
	for k in range(klatscher):
		var start: int = int(_rng.randf_range(0.02, 0.75) * float(n))
		var laenge: int = int(_rng.randf_range(0.004, 0.012) * float(RATE))
		var pegel: float = _rng.randf_range(0.10, 0.30) * kraft
		for j in range(laenge):
			var i2: int = start + j
			if i2 >= n:
				break
			a[i2] += _rng.randf_range(-1.0, 1.0) * pegel * exp(-float(j) / float(laenge) * 4.0)
	return _normieren(a, 0.80 * clampf(kraft + 0.22, 0.3, 1.0))

## Grundgeräusch einer gefüllten Halle: das Gemurmel vieler Stimmen als
## nahtlose Schleife. Auch hier tragen Resonanzbänder die Stimmhaftigkeit;
## reines Tiefpassrauschen klang nach Lüftungsanlage.
func _atmosphaere(dauer: float) -> PackedFloat32Array:
	var n: int = int(dauer * float(RATE))
	var a := _puffer(dauer)
	var roh := _rauschen(n)
	var tief := _tiefpass(roh.duplicate(), 0.07)
	tief = _tiefpass(tief, 0.11)
	_mischen(a, tief, 3.0)
	for paar in [[290.0, 3.4, 0.55], [640.0, 2.8, 0.40], [1180.0, 2.2, 0.20]]:
		_mischen(a, _bandpass(roh, float(paar[0]), float(paar[1])), float(paar[2]))
	# Zwei ineinanderlaufende langsame Wellen — nichts wiederholt sich hörbar
	for i in range(n):
		var t: float = float(i) / float(RATE)
		a[i] = a[i] * (0.70 + 0.30 * sin(TAU * 0.13 * t) * sin(TAU * 0.071 * t + 1.3))
	# Vereinzelte Rufe aus der Menge
	for k in range(int(dauer * 1.6)):
		var start: int = int(_rng.randf_range(0.0, 0.92) * float(n))
		var laenge: int = int(_rng.randf_range(0.12, 0.34) * float(RATE))
		var hoehe: float = _rng.randf_range(420.0, 900.0)
		for j in range(laenge):
			var i2: int = start + j
			if i2 >= n:
				break
			var tt: float = float(j) / float(RATE)
			var h: float = sin(PI * float(j) / float(laenge))
			a[i2] += sin(TAU * hoehe * tt) * 0.05 * h * h
	# Nahtlose Schleife: die letzten 0,4 s in den Anfang blenden
	var blende: int = int(0.4 * float(RATE))
	for i3 in range(blende):
		var f: float = float(i3) / float(blende)
		a[i3] = a[i3] * f + a[n - blende + i3] * (1.0 - f)
	return _normieren(a, 0.5)

## Ball auf Hallenboden: kurzer, tiefer Schlag mit Anschlagsgeräusch.
func _ballaufprall() -> PackedFloat32Array:
	var a := _puffer(0.18)
	var n := a.size()
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var ton: float = sin(TAU * (165.0 - 90.0 * t / 0.18) * t)
		var knall: float = _rng.randf_range(-1.0, 1.0) * exp(-t * 90.0)
		a[i] = (ton * 0.7 + knall * 0.5) * _huelle(i, n, 0.002, 0.10)
	return _normieren(a, 0.6)

## Schlusssirene: zwei rauhe Rechtecktöne.
func _sirene() -> PackedFloat32Array:
	var a := _puffer(1.4)
	var n := a.size()
	for i in range(n):
		var t: float = float(i) / float(RATE)
		var w1: float = 1.0 if fmod(t * 233.0, 1.0) < 0.5 else -1.0
		var w2: float = 1.0 if fmod(t * 349.0, 1.0) < 0.5 else -1.0
		a[i] = (w1 * 0.5 + w2 * 0.34) * _huelle(i, n, 0.015, 0.25)
	a = _tiefpass(a, 0.5)
	return _normieren(a, 0.5)

## Kurzer Klick für Knöpfe.
func _klick() -> PackedFloat32Array:
	var a := _puffer(0.045)
	var n := a.size()
	for i in range(n):
		var t: float = float(i) / float(RATE)
		a[i] = (sin(TAU * 1400.0 * t) * 0.5 + _rng.randf_range(-1.0, 1.0) * 0.35) * exp(-t * 130.0)
	return _normieren(a, 0.30)

## Weiches Wischen für Seitenwechsel.
func _blaettern() -> PackedFloat32Array:
	var a := _puffer(0.22)
	var n := a.size()
	for i in range(n):
		a[i] = _rng.randf_range(-1.0, 1.0)
	a = _tiefpass(a, 0.30)
	for i in range(n):
		var t: float = float(i) / float(RATE)
		a[i] = a[i] * exp(-t * 16.0) * (0.4 + 0.6 * sin(PI * t / 0.22))
	return _normieren(a, 0.26)

# ---------------------------------------------------------------- Musik ---

## Halbtonabstand zur Frequenz.
func _ton(halbton: float) -> float:
	return 220.0 * pow(2.0, halbton / 12.0)

## Ein warmer Pad-Ton aus mehreren leicht verstimmten Sinusanteilen.
func _pad(a: PackedFloat32Array, start: float, dauer: float, halbton: float, pegel: float) -> void:
	var i0: int = int(start * float(RATE))
	var n: int = int(dauer * float(RATE))
	var f: float = _ton(halbton)
	for k in range(n):
		var i: int = i0 + k
		if i < 0 or i >= a.size():
			continue
		var t: float = float(k) / float(RATE)
		var h: float = clampf(t / 0.45, 0.0, 1.0) * clampf((dauer - t) / 0.7, 0.0, 1.0)
		var wert: float = sin(TAU * f * t) * 0.5
		wert += sin(TAU * f * 1.003 * t) * 0.34
		wert += sin(TAU * f * 2.0 * t) * 0.16
		wert += sin(TAU * f * 3.0 * t) * 0.07
		a[i] += wert * h * pegel

## Weicher Basston.
func _bass(a: PackedFloat32Array, start: float, dauer: float, halbton: float, pegel: float) -> void:
	var i0: int = int(start * float(RATE))
	var n: int = int(dauer * float(RATE))
	var f: float = _ton(halbton - 24.0)
	for k in range(n):
		var i: int = i0 + k
		if i < 0 or i >= a.size():
			continue
		var t: float = float(k) / float(RATE)
		var h: float = clampf(t / 0.02, 0.0, 1.0) * exp(-t * 1.6)
		a[i] += (sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.22) * h * pegel

## Melodieton mit Anschlag.
func _glocke(a: PackedFloat32Array, start: float, dauer: float, halbton: float, pegel: float) -> void:
	var i0: int = int(start * float(RATE))
	var n: int = int(dauer * float(RATE))
	var f: float = _ton(halbton)
	for k in range(n):
		var i: int = i0 + k
		if i < 0 or i >= a.size():
			continue
		var t: float = float(k) / float(RATE)
		var h: float = clampf(t / 0.01, 0.0, 1.0) * exp(-t * 3.2)
		a[i] += (sin(TAU * f * t) * 0.7 + sin(TAU * f * 2.01 * t) * 0.22
			+ sin(TAU * f * 3.02 * t) * 0.08) * h * pegel

## Die Menümusik: vier Akkorde in a-Moll, ruhig, als nahtlose Schleife.
func _baue_musik() -> AudioStreamWAV:
	var takt := 3.2
	var a := _puffer(takt * 4.0 + 0.001)
	# a-Moll · F-Dur · C-Dur · G-Dur, jeweils als Dreiklang im Pad
	var akkorde := [[0.0, 3.0, 7.0], [-4.0, 0.0, 5.0], [-9.0, -5.0, 0.0], [-2.0, 2.0, 7.0]]
	var grundtoene := [0.0, -4.0, -9.0, -2.0]
	var melodie := [
		[0.0, 12.0], [1.6, 15.0], [3.2, 12.0], [4.8, 10.0],
		[6.4, 7.0], [8.0, 12.0], [9.6, 14.0], [11.2, 15.0],
	]
	for i in range(4):
		var start: float = float(i) * takt
		for halbton in akkorde[i]:
			_pad(a, start, takt + 0.5, float(halbton) + 12.0, 0.30)
		_bass(a, start, takt * 0.6, float(grundtoene[i]), 0.42)
		_bass(a, start + takt * 0.5, takt * 0.4, float(grundtoene[i]) + 7.0, 0.22)
	for e in melodie:
		_glocke(a, float(e[0]), 1.4, float(e[1]), 0.20)
	# Schleifenkante weichzeichnen
	var blende: int = int(0.25 * float(RATE))
	var n := a.size()
	for i in range(blende):
		var f: float = float(i) / float(blende)
		a[i] = a[i] * f + a[n - blende + i] * (1.0 - f)
	return _zu_stream(_normieren(a, 0.55), true)
