class_name Bildschirm
extends Control
## Grundlage aller Bildschirme. Wichtig: Bildschirme werden einmal gebaut und
## danach nur noch ein- bzw. ausgeblendet — so feuert nichts zu spaet.
## Bereiche, die sich staendig aendern, liegen in eigenen Unter-Containern,
## die geleert und neu befuellt werden. Dauerhafte Knoten liegen niemals darin.

var titelzeile: String = ""
var gebaut: bool = false

## Wechselt zu einem anderen Bildschirm. Die App haengt weiter oben im Baum;
## ein Bildschirm kennt sie nicht direkt, deshalb der Weg ueber die Gruppe.
func wechsel_zu(id: String) -> void:
	var app := get_tree().get_first_node_in_group("app")
	if app != null:
		app.zeige(id)

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_preset(Control.PRESET_FULL_RECT)

## Einmaliger Aufbau des Grundgeruests.
func aufbauen() -> void:
	pass

## Wird bei jedem Anzeigen und bei Zustandsaenderungen aufgerufen.
func aktualisieren() -> void:
	pass

func bereit() -> void:
	if gebaut:
		return
	gebaut = true
	aufbauen()

## Verteilt die Karten eines fertig gebauten Stapels auf zwei Spalten.
##
## Ein Bildschirm, der acht Karten untereinanderlegt, ist zwei bis drei
## Bildschirmhoehen lang — und daneben bleibt auf einem breiten Monitor Platz
## ungenutzt. Diese Umverteilung passiert einmal, nachdem der Inhalt steht:
## jede Karte kommt in die Spalte, die gerade kuerzer ist.
##
## Bewusst nicht als eigener Container geloest. Ein Behaelter, der seine Hoehe
## erst aus der Verteilung erfaehrt und die Verteilung aus der Hoehe, laesst
## Godot endlos neu sortieren — genau das ist beim ersten Versuch passiert.
## Einmal nach dem Aufbau umhaengen kann nicht schwingen.
static func zweispaltig(stapel: BoxContainer, ab_karten: int = 4) -> void:
	mehrspaltig(stapel, 2, ab_karten)

## Dasselbe mit frei gewaehlter Spaltenzahl. Drei Spalten lohnen sich, wo die
## Karten schmal sind — Tonregler, Spielstaende, kurze Beitraege.
static func mehrspaltig(stapel: BoxContainer, spaltenzahl: int, ab_karten: int = 4) -> void:
	var karten: Array = []
	for k in stapel.get_children():
		if k is Control:
			karten.append(k)
	if karten.size() < ab_karten:
		return
	var zahl: int = maxi(spaltenzahl, 2)
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", Stil.A_NORMAL)
	reihe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spalten: Array = []
	var hoehen: Array = []
	for i in zahl:
		var sp := VBoxContainer.new()
		sp.add_theme_constant_override("separation", Stil.A_NORMAL)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reihe.add_child(sp)
		spalten.append(sp)
		hoehen.append(0.0)
	for k2 in karten:
		var c := k2 as Control
		stapel.remove_child(c)
		# Immer in die bisher kuerzeste Spalte: so bleiben die Spalten gleich
		# hoch, ohne dass eine echte Mauerwerk-Anordnung noetig waere (die im
		# Layout-Durchlauf endlos schwingen wuerde).
		var ziel: int = 0
		for j in range(1, zahl):
			if float(hoehen[j]) < float(hoehen[ziel]):
				ziel = j
		(spalten[ziel] as Node).add_child(c)
		hoehen[ziel] = float(hoehen[ziel]) + c.get_combined_minimum_size().y + float(Stil.A_NORMAL)
	stapel.add_child(reihe)

## Leert einen Container vollstaendig und sicher.
static func leeren(c: Node) -> void:
	for kind in c.get_children():
		c.remove_child(kind)
		kind.queue_free()
