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

## Leert einen Container vollstaendig und sicher.
static func leeren(c: Node) -> void:
	for kind in c.get_children():
		c.remove_child(kind)
		kind.queue_free()
