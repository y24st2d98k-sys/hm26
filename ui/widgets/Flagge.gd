class_name Flagge
extends Control
## Gezeichnete Nationalflaggen. Jede Flagge ist ein kleines Rezept aus
## Streifen, Kreuzen und Feldern — keine Bilddateien, keine Emoji-Schrift.
##
## Die Rezepte sind bewusst schlicht gehalten: bei 16 bis 22 Pixel Kantenlaenge
## zaehlt nur, dass man die Herkunft auf einen Blick erkennt.

enum Art { WAAGERECHT, SENKRECHT, NORDKREUZ, KREUZ, MITTELBALKEN, VIERTEL, EINFARBIG }

const R := Color("#d7202f")
const W := Color("#f4f6f8")
const B := Color("#1b3d8f")
const S := Color("#141821")
const G := Color("#f2c619")
const GR := Color("#0f8a48")
const HB := Color("#3f9de0")
const OR := Color("#e8702a")

## Nation -> {art, farben, zusatz}
const FLAGGEN := {
	"de": {"art": Art.WAAGERECHT, "farben": [S, R, G]},
	"at": {"art": Art.WAAGERECHT, "farben": [R, W, R]},
	"ch": {"art": Art.KREUZ, "farben": [R, W]},
	"dk": {"art": Art.NORDKREUZ, "farben": [R, W]},
	"se": {"art": Art.NORDKREUZ, "farben": [B, G]},
	"no": {"art": Art.NORDKREUZ, "farben": [R, W, B]},
	"is": {"art": Art.NORDKREUZ, "farben": [B, W, R]},
	"fo": {"art": Art.NORDKREUZ, "farben": [W, R, B]},
	"fi": {"art": Art.NORDKREUZ, "farben": [W, B]},
	"fr": {"art": Art.SENKRECHT, "farben": [B, W, R]},
	"nl": {"art": Art.WAAGERECHT, "farben": [R, W, B]},
	"be": {"art": Art.SENKRECHT, "farben": [S, G, R]},
	"it": {"art": Art.SENKRECHT, "farben": [GR, W, R]},
	"ro": {"art": Art.SENKRECHT, "farben": [B, G, R]},
	"es": {"art": Art.MITTELBALKEN, "farben": [R, G]},
	"pt": {"art": Art.SENKRECHT, "farben": [GR, GR, R]},
	"pl": {"art": Art.WAAGERECHT, "farben": [W, R]},
	"cz": {"art": Art.VIERTEL, "farben": [W, R, B]},
	"sk": {"art": Art.WAAGERECHT, "farben": [W, B, R]},
	"si": {"art": Art.WAAGERECHT, "farben": [W, B, R]},
	"hr": {"art": Art.WAAGERECHT, "farben": [R, W, B]},
	"rs": {"art": Art.WAAGERECHT, "farben": [R, B, W]},
	"me": {"art": Art.WAAGERECHT, "farben": [R, R, R]},
	"ba": {"art": Art.VIERTEL, "farben": [B, G, B]},
	"mk": {"art": Art.EINFARBIG, "farben": [R, G]},
	"hu": {"art": Art.WAAGERECHT, "farben": [R, W, GR]},
	"gr": {"art": Art.WAAGERECHT, "farben": [HB, W, HB]},
	"ua": {"art": Art.WAAGERECHT, "farben": [B, G]},
	"by": {"art": Art.WAAGERECHT, "farben": [R, GR]},
	"lv": {"art": Art.WAAGERECHT, "farben": [Color("#9d2235"), W, Color("#9d2235")]},
	"eg": {"art": Art.WAAGERECHT, "farben": [R, W, S]},
	"tn": {"art": Art.EINFARBIG, "farben": [R, W]},
	"qa": {"art": Art.SENKRECHT, "farben": [W, Color("#8a1538"), Color("#8a1538")]},
	"br": {"art": Art.MITTELBALKEN, "farben": [GR, G]},
	"jp": {"art": Art.EINFARBIG, "farben": [W, R]},
	"kr": {"art": Art.EINFARBIG, "farben": [W, B]},
}

var nation: String = "de"

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

static func fuer(nation_id: String, breite: float = 20.0) -> Flagge:
	var f := Flagge.new()
	f.nation = nation_id
	f.custom_minimum_size = Vector2(breite, breite * 0.66)
	f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.tooltip_text = str(Namen.KULTUR_NAME.get(nation_id, nation_id.to_upper()))
	return f

func _draw() -> void:
	var b: float = size.x
	var h: float = size.y
	if b < 5.0 or h < 3.0:
		return
	var rezept: Dictionary = FLAGGEN.get(nation, {"art": Art.WAAGERECHT, "farben": [S, Color("#5d6b7c"), W]})
	var farben: Array = rezept["farben"]
	match int(rezept["art"]):
		Art.WAAGERECHT:
			for i in range(farben.size()):
				draw_rect(Rect2(0, h * float(i) / float(farben.size()), b, h / float(farben.size()) + 0.5),
					farben[i], true)
		Art.SENKRECHT:
			for i in range(farben.size()):
				draw_rect(Rect2(b * float(i) / float(farben.size()), 0, b / float(farben.size()) + 0.5, h),
					farben[i], true)
		Art.NORDKREUZ:
			draw_rect(Rect2(0, 0, b, h), farben[0], true)
			var kreuz: Color = farben[1]
			var d: float = maxf(h * 0.20, 2.0)
			if farben.size() >= 3:
				# Aussenkreuz etwas breiter, Innenkreuz in der dritten Farbe
				draw_rect(Rect2(b * 0.30 - d * 0.75, 0, d * 1.5, h), farben[1], true)
				draw_rect(Rect2(0, h * 0.5 - d * 0.75, b, d * 1.5), farben[1], true)
				kreuz = farben[2]
			draw_rect(Rect2(b * 0.30 - d * 0.5, 0, d, h), kreuz, true)
			draw_rect(Rect2(0, h * 0.5 - d * 0.5, b, d), kreuz, true)
		Art.KREUZ:
			draw_rect(Rect2(0, 0, b, h), farben[0], true)
			var dd: float = maxf(h * 0.20, 2.0)
			draw_rect(Rect2(b * 0.5 - dd * 0.5, h * 0.18, dd, h * 0.64), farben[1], true)
			draw_rect(Rect2(b * 0.5 - dd * 1.6, h * 0.5 - dd * 0.5, dd * 3.2, dd), farben[1], true)
		Art.MITTELBALKEN:
			draw_rect(Rect2(0, 0, b, h), farben[0], true)
			draw_rect(Rect2(0, h * 0.25, b, h * 0.5), farben[1], true)
		Art.VIERTEL:
			draw_rect(Rect2(0, 0, b, h * 0.5), farben[0], true)
			draw_rect(Rect2(0, h * 0.5, b, h * 0.5), farben[1], true)
			var keil := PackedVector2Array([Vector2(0, 0), Vector2(b * 0.45, h * 0.5), Vector2(0, h)])
			draw_colored_polygon(keil, farben[2] if farben.size() > 2 else B)
		_:
			draw_rect(Rect2(0, 0, b, h), farben[0], true)
			if farben.size() > 1:
				draw_circle(Vector2(b * 0.5, h * 0.5), h * 0.30, farben[1])
	draw_rect(Rect2(0, 0, b, h), Color(0, 0, 0, 0.45), false, 1.0)
