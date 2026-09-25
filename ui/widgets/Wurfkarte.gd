class_name Wurfkarte
extends Control
## Zeichnet, von wo eine Mannschaft abgeschlossen hat und was dabei herauskam.
##
## Je Abschlussposition steht ein Kreis auf einer halben Spielfeldhälfte:
## Die Fläche wächst mit der Zahl der Würfe, die Farbe zeigt die Trefferquote,
## und im Kreis steht "Tore/Würfe". Der Siebenmeter bekommt einen eigenen Platz
## auf der Siebenmeterlinie.
##
## Die Daten kommen aus dem Spielbericht (`bericht[seite]["wurfkarte"]`) und sind
## reine Summen — die Engine hebt keine Einzelwürfe auf.

## Positionen in Anteilen der Zeichenfläche (Tor liegt rechts).
const PLATZ := {
	"LA": Vector2(0.22, 0.13), "RL": Vector2(0.38, 0.27), "RM": Vector2(0.25, 0.50),
	"RR": Vector2(0.38, 0.73), "RA": Vector2(0.22, 0.87), "KM": Vector2(0.75, 0.50),
	"7M": Vector2(0.50, 0.50), "TG": Vector2(0.60, 0.16), "LT": Vector2(0.08, 0.50),
}
const NAME := {
	"LA": "Linksaußen", "RL": "Rückraum links", "RM": "Rückraum Mitte",
	"RR": "Rückraum rechts", "RA": "Rechtsaußen", "KM": "Kreis", "7M": "Siebenmeter",
	"TG": "Tempogegenstoß", "LT": "Wurf ins leere Tor",
}

var karte: Dictionary = {}
var farbe: Color = Color("#ffb340")

func _init() -> void:
	custom_minimum_size = Vector2(300, 264)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Die Torraumbögen reichen über den Rand hinaus — ohne Beschneidung
	# zeichneten sie quer über die Karte.
	clip_contents = true

static func neu(wurfkarte: Dictionary, vereinsfarbe: Color, breite: float = 300.0) -> Wurfkarte:
	var w := Wurfkarte.new()
	w.karte = wurfkarte if wurfkarte != null else {}
	w.farbe = vereinsfarbe
	w.custom_minimum_size = Vector2(breite, breite * 0.88)
	return w

func _draw() -> void:
	var b: float = size.x
	var h: float = size.y
	if b < 60.0 or h < 50.0:
		return
	_feld(b, h)
	if karte.is_empty():
		return

	# Der groesste Posten bestimmt die Kreisgroesse aller anderen.
	var meiste := 1
	for pos in karte.keys():
		meiste = maxi(meiste, _summe(karte[pos]))

	var schrift := ThemeDB.fallback_font
	for pos in PLATZ.keys():
		if not karte.has(pos):
			continue
		var e: Dictionary = karte[pos]
		var gesamt: int = _summe(e)
		if gesamt <= 0:
			continue
		var tore: int = int(e.get("tor", 0))
		var quote: float = float(tore) / float(gesamt)
		var m: Vector2 = Vector2(PLATZ[pos].x * b, PLATZ[pos].y * h)
		var r: float = lerpf(minf(b, h) * 0.048, minf(b, h) * 0.115,
			sqrt(float(gesamt) / float(meiste)))
		var f: Color = Stil.prozent_farbe(quote * 100.0)
		draw_circle(m, r, Color(f.r, f.g, f.b, 0.28))
		draw_arc(m, r, 0.0, TAU, 28, f, maxf(r * 0.10, 1.5), true)
		# Der ausgefüllte Anteil zeigt die Quote als Tortenstück.
		if quote > 0.0:
			var punkte := PackedVector2Array([m])
			var schritte: int = maxi(int(28.0 * quote), 2)
			for i in range(schritte + 1):
				var w2: float = -PI / 2.0 + TAU * quote * float(i) / float(schritte)
				punkte.append(m + Vector2(cos(w2), sin(w2)) * r)
			if punkte.size() >= 3:
				draw_colored_polygon(punkte, Color(f.r, f.g, f.b, 0.55))
		var txt := "%d/%d" % [tore, gesamt]
		var groesse: int = maxi(int(r * 0.62), 9)
		var breite: float = schrift.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
		draw_string(schrift, m + Vector2(-breite * 0.5, groesse * 0.36), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Stil.TEXT)
		var kuerzel: String = str(pos)
		var kb: float = schrift.get_string_size(kuerzel, HORIZONTAL_ALIGNMENT_LEFT, -1, Stil.S_ETIKETT).x
		draw_string(schrift, m + Vector2(-kb * 0.5, -r - 4.0), kuerzel,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Stil.S_ETIKETT, Stil.TEXT_MATT)

static func _summe(e: Dictionary) -> int:
	return int(e.get("tor", 0)) + int(e.get("parade", 0)) + int(e.get("vorbei", 0)) + int(e.get("block", 0))

## Die angegriffene Hälfte: Torraum, Freiwurflinie, Tor rechts.
func _feld(b: float, h: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(b, h)), Color("#141b24"), true)
	var tor := Vector2(b * 0.985, h * 0.5)
	var linie := Color("#3f4c5b")
	# Torraum (6 m) und Freiwurflinie (9 m) als Halbkreise um das Tor
	for paar in [[0.34, linie, 0], [0.52, Color("#313d4a"), 2]]:
		var radius: float = float(paar[0]) * b
		var vorher := Vector2.ZERO
		for i in range(31):
			var w: float = PI * 0.5 + PI * float(i) / 30.0
			var p := tor + Vector2(cos(w), sin(w)) * radius
			if i > 0 and (int(paar[2]) == 0 or i % (int(paar[2]) + 1) != 0):
				draw_line(vorher, p, paar[1], 1.2)
			vorher = p
	draw_rect(Rect2(Vector2.ZERO, Vector2(b, h)), linie, false, 1.4)
	draw_line(Vector2(b * 0.985, h * 0.36), Vector2(b * 0.985, h * 0.64), Color("#eef3f9"), 3.0)
