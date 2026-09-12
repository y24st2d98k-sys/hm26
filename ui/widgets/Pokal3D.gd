class_name Pokal3D
extends SubViewportContainer
## Eine sich drehende Trophäe in echtem 3D.
##
## Das Spiel ist bewusst zweidimensional — eine Draufsicht liest sich in einem
## Manager besser als eine Kameraperspektive. An genau einer Stelle lohnt sich
## 3D trotzdem: bei einem gewonnenen Titel. Der Pokal wird aus Godot-Primitiven
## zusammengesetzt (Zylinder, Kugel, Torus, Kasten) und mit einem metallischen
## Material versehen; es wird kein Modell geladen.

var _viewport: SubViewport
var _wurzel: Node3D
var _tempo: float = 0.55

## groesse in Pixeln, farbe faerbt das Metall (Gold, Silber, Bronze …).
static func neu(groesse: float = 130.0, farbe: Color = Color("#e6b64c"),
		sockelfarbe: Color = Color("#2a2118")) -> Pokal3D:
	var p := Pokal3D.new()
	p.custom_minimum_size = Vector2(groesse, groesse)
	p.stretch = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("farbe", farbe)
	p.set_meta("sockel", sockelfarbe)
	return p

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	_viewport.size = Vector2i(int(maxf(custom_minimum_size.x, 64.0)),
		int(maxf(custom_minimum_size.y, 64.0)))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	_wurzel = Node3D.new()
	_wurzel.position = Vector3(0.0, 0.16, 0.0)
	_viewport.add_child(_wurzel)
	_baue_pokal()

	var kamera := Camera3D.new()
	kamera.position = Vector3(0.0, 0.30, 2.75)
	kamera.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	kamera.fov = 40.0
	_viewport.add_child(kamera)

	var licht := DirectionalLight3D.new()
	licht.rotation_degrees = Vector3(-38.0, 38.0, 0.0)
	licht.light_energy = 2.1
	_viewport.add_child(licht)
	var gegenlicht := DirectionalLight3D.new()
	gegenlicht.rotation_degrees = Vector3(-15.0, -140.0, 0.0)
	gegenlicht.light_energy = 0.7
	gegenlicht.light_color = Color("#8fb6ff")
	_viewport.add_child(gegenlicht)

	var umgebung := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#6f7d90")
	e.ambient_light_energy = 0.75
	umgebung.environment = e
	_viewport.add_child(umgebung)

func _process(delta: float) -> void:
	if _wurzel != null:
		_wurzel.rotate_y(delta * _tempo)

func _metall(farbe: Color, rauheit: float = 0.22) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = farbe
	m.metallic = 0.95
	m.metallic_specular = 0.8
	m.roughness = rauheit
	return m

func _teil(mesh: Mesh, material: Material, position: Vector3,
		drehung: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = position
	mi.rotation_degrees = drehung
	_wurzel.add_child(mi)

## Kelch, Fuss, Henkel und Sockel — ganz aus Grundkoerpern.
func _baue_pokal() -> void:
	var gold := _metall(get_meta("farbe", Color("#e6b64c")))
	var dunkel := StandardMaterial3D.new()
	dunkel.albedo_color = get_meta("sockel", Color("#2a2118"))
	dunkel.roughness = 0.88
	dunkel.albedo_color = dunkel.albedo_color.darkened(0.35)

	# Sockel in zwei Stufen
	var sockel := BoxMesh.new()
	sockel.size = Vector3(0.86, 0.20, 0.86)
	_teil(sockel, dunkel, Vector3(0, -0.72, 0))
	var sockel2 := BoxMesh.new()
	sockel2.size = Vector3(0.62, 0.10, 0.62)
	_teil(sockel2, gold, Vector3(0, -0.57, 0))

	# Schaft
	var schaft := CylinderMesh.new()
	schaft.top_radius = 0.09
	schaft.bottom_radius = 0.13
	schaft.height = 0.42
	schaft.radial_segments = 24
	_teil(schaft, gold, Vector3(0, -0.31, 0))

	# Knauf
	var knauf := SphereMesh.new()
	knauf.radius = 0.11
	knauf.height = 0.22
	knauf.radial_segments = 20
	knauf.rings = 10
	_teil(knauf, gold, Vector3(0, -0.06, 0))

	# Kelch: unten rund, oben weit
	var kelch_unten := SphereMesh.new()
	kelch_unten.radius = 0.30
	kelch_unten.height = 0.44
	kelch_unten.radial_segments = 28
	kelch_unten.rings = 12
	_teil(kelch_unten, gold, Vector3(0, 0.16, 0))
	var kelch := CylinderMesh.new()
	kelch.top_radius = 0.36
	kelch.bottom_radius = 0.25
	kelch.height = 0.40
	kelch.radial_segments = 28
	_teil(kelch, gold, Vector3(0, 0.36, 0))

	# Rand als Ring
	var rand := TorusMesh.new()
	rand.inner_radius = 0.34
	rand.outer_radius = 0.39
	rand.rings = 28
	rand.ring_segments = 12
	_teil(rand, gold, Vector3(0, 0.56, 0))

	# Zwei Henkel
	for seite in [-1.0, 1.0]:
		var henkel := TorusMesh.new()
		henkel.inner_radius = 0.09
		henkel.outer_radius = 0.14
		henkel.rings = 20
		henkel.ring_segments = 10
		_teil(henkel, gold, Vector3(seite * 0.38, 0.34, 0), Vector3(90, 0, 0))
