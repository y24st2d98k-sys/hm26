class_name Verhandlungsraum
extends SubViewportContainer
## Der Raum, in dem verhandelt wird — in echtem 3D.
##
## Ein Tisch, zwei Stühle, eine Lampe und dahinter der Spieler. Sein Gesicht ist
## dasselbe prozedurale Portrait wie überall sonst: es wird in einen eigenen
## Viewport gezeichnet und als Textur auf eine Fläche im Raum gelegt. Damit
## wandert die gezeichnete Grafik ohne Umweg in die 3D-Szene, und es liegt
## weiterhin keine Bilddatei im Projekt.
##
## Die Beleuchtung folgt der Stimmung: je gereizter das Gegenüber, desto kälter
## und härter das Licht.

var _viewport: SubViewport
var _wurzel: Node3D
var _kopflicht: OmniLight3D
var _gesichtsviewport: SubViewport
var _gesicht: Sprite3D
var _wappen: Sprite3D
var _wappenviewport: SubViewport
var _stimmung: float = 0.5
var _ziel_drehung: float = 0.0

static func neu(groesse: Vector2 = Vector2(520.0, 240.0)) -> Verhandlungsraum:
	var r := Verhandlungsraum.new()
	r.custom_minimum_size = groesse
	r.stretch = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	_viewport.size = Vector2i(int(maxf(custom_minimum_size.x, 128.0)),
		int(maxf(custom_minimum_size.y, 96.0)))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	_wurzel = Node3D.new()
	_viewport.add_child(_wurzel)
	_baue_raum()
	_baue_kamera()
	_baue_licht()

func _process(delta: float) -> void:
	if _gesicht != null:
		# Leichtes Wiegen, damit die Szene nicht wie ein Standbild wirkt
		var t: float = Time.get_ticks_msec() / 1000.0
		_gesicht.rotation.y = lerp_angle(_gesicht.rotation.y, _ziel_drehung + sin(t * 0.6) * 0.05, delta * 3.0)
		_gesicht.position.y = 0.86 + sin(t * 0.8) * 0.010

## Wen wir vor uns haben. Der Kopf wird in einen Viewport gezeichnet und als
## Textur benutzt.
func setze_spieler(sid: String) -> void:
	if _gesichtsviewport == null:
		return
	for k in _gesichtsviewport.get_children():
		k.queue_free()
	var p := Portraet.fuer_spieler(sid, 256.0)
	p.nur_kopf = true
	p.custom_minimum_size = Vector2(256, 256)
	p.size_flags_horizontal = Control.SIZE_FILL
	p.size_flags_vertical = Control.SIZE_FILL
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gesichtsviewport.add_child(p)
	var sp: Dictionary = Welt.spieler(sid)
	var cid: String = str(sp.get("verein", ""))
	if cid != "" and _wappenviewport != null:
		for k2 in _wappenviewport.get_children():
			k2.queue_free()
		var w := Wappen.fuer_verein(cid, 192.0)
		w.set_anchors_preset(Control.PRESET_FULL_RECT)
		_wappenviewport.add_child(w)

## 0 = aufgebracht, 1 = bester Laune. Steuert Licht und Kopfhaltung.
func setze_stimmung(wert: float) -> void:
	_stimmung = clampf(wert, 0.0, 1.0)
	if _kopflicht != null:
		_kopflicht.light_color = Color("#c9553f").lerp(Color("#ffd9a0"), _stimmung)
		_kopflicht.light_energy = lerpf(2.6, 1.7, _stimmung)
	_ziel_drehung = lerpf(-0.22, 0.0, _stimmung)

# ------------------------------------------------------------- Aufbau ---

func _material(farbe: Color, rauheit: float = 0.7, metall: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = farbe
	m.roughness = rauheit
	m.metallic = metall
	return m

func _teil(mesh: Mesh, material: Material, position: Vector3, drehung: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = position
	mi.rotation_degrees = drehung
	_wurzel.add_child(mi)
	return mi

func _baue_raum() -> void:
	var holz := _material(Color("#3b2b20"), 0.55)
	var dunkel := _material(Color("#10151d"), 0.9)
	var metall := _material(Color("#8d97a4"), 0.35, 0.8)

	# Rückwand und Boden
	var wand := BoxMesh.new()
	wand.size = Vector3(9.0, 4.0, 0.2)
	_teil(wand, dunkel, Vector3(0, 1.2, -2.4))
	var boden := BoxMesh.new()
	boden.size = Vector3(9.0, 0.2, 6.0)
	_teil(boden, _material(Color("#181f28"), 0.85), Vector3(0, -0.9, 0))

	# Tisch
	var platte := BoxMesh.new()
	platte.size = Vector3(3.4, 0.10, 1.3)
	_teil(platte, holz, Vector3(0, 0.0, 0.55))
	for x in [-1.5, 1.5]:
		var bein := BoxMesh.new()
		bein.size = Vector3(0.10, 0.80, 0.10)
		_teil(bein, metall, Vector3(x, -0.45, 0.55))

	# Stuhllehne hinter dem Spieler
	var lehne := BoxMesh.new()
	lehne.size = Vector3(1.15, 0.7, 0.09)
	_teil(lehne, _material(Color("#1a242e"), 0.85), Vector3(0, 0.18, -0.92))

	# Der Spieler: Schultern als Körper, Kopf als Bildfläche
	var koerper := CylinderMesh.new()
	koerper.top_radius = 0.24
	koerper.bottom_radius = 0.40
	koerper.height = 0.62
	koerper.radial_segments = 20
	_teil(koerper, _material(Color("#1d2733"), 0.85), Vector3(0, 0.36, -0.55))

	_gesichtsviewport = SubViewport.new()
	_gesichtsviewport.size = Vector2i(256, 256)
	_gesichtsviewport.transparent_bg = true
	_gesichtsviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Wichtig: nicht an den SubViewportContainer haengen. Der streckt mit
	# stretch=true jeden Kind-Viewport auf seine eigene Groesse — das Gesicht
	# waere dann 640x240 statt 256x256 und laege ueber der Szene.
	_wurzel.add_child(_gesichtsviewport)
	_gesicht = Sprite3D.new()
	_gesicht.texture = _gesichtsviewport.get_texture()
	_gesicht.pixel_size = 0.0046
	_gesicht.position = Vector3(0, 0.86, -0.52)
	_gesicht.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_gesicht.shaded = true
	_gesicht.double_sided = false
	_gesicht.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_wurzel.add_child(_gesicht)

	# Vereinswappen an der Wand
	_wappenviewport = SubViewport.new()
	_wappenviewport.size = Vector2i(192, 192)
	_wappenviewport.transparent_bg = true
	_wappenviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_wurzel.add_child(_wappenviewport)
	_wappen = Sprite3D.new()
	_wappen.texture = _wappenviewport.get_texture()
	_wappen.pixel_size = 0.0042
	_wappen.position = Vector3(-1.85, 1.25, -2.25)
	_wappen.shaded = true
	_wappen.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_wurzel.add_child(_wappen)

	# Unterlagen und Stift auf dem Tisch
	var papier := BoxMesh.new()
	papier.size = Vector3(0.42, 0.012, 0.30)
	_teil(papier, _material(Color("#e6e2d6"), 0.95), Vector3(0.75, 0.06, 0.72), Vector3(0, 12, 0))
	var stift := CylinderMesh.new()
	stift.top_radius = 0.012
	stift.bottom_radius = 0.012
	stift.height = 0.22
	_teil(stift, _material(Color("#1a1a1a"), 0.4), Vector3(0.95, 0.08, 0.62), Vector3(0, 0, 78))

	# Schreibtischlampe rechts
	var fuss := CylinderMesh.new()
	fuss.top_radius = 0.10
	fuss.bottom_radius = 0.13
	fuss.height = 0.05
	_teil(fuss, metall, Vector3(-1.15, 0.08, 0.62))
	var arm := CylinderMesh.new()
	arm.top_radius = 0.02
	arm.bottom_radius = 0.02
	arm.height = 0.5
	_teil(arm, metall, Vector3(-1.15, 0.32, 0.62), Vector3(14, 0, 0))
	var schirm := CylinderMesh.new()
	schirm.top_radius = 0.05
	schirm.bottom_radius = 0.16
	schirm.height = 0.18
	_teil(schirm, _material(Color("#2b3440"), 0.6), Vector3(-1.15, 0.60, 0.50), Vector3(28, 0, 0))

func _baue_kamera() -> void:
	var kamera := Camera3D.new()
	kamera.position = Vector3(0.55, 1.05, 2.35)
	kamera.rotation_degrees = Vector3(-9.0, 12.0, 0.0)
	kamera.fov = 46.0
	_viewport.add_child(kamera)

func _baue_licht() -> void:
	_kopflicht = OmniLight3D.new()
	_kopflicht.position = Vector3(-1.05, 0.85, 0.45)
	_kopflicht.light_color = Color("#ffd9a0")
	_kopflicht.light_energy = 2.0
	_kopflicht.omni_range = 6.0
	_viewport.add_child(_kopflicht)
	var fuell := DirectionalLight3D.new()
	fuell.rotation_degrees = Vector3(-32.0, 26.0, 0.0)
	fuell.light_energy = 0.75
	fuell.light_color = Color("#8fa9d0")
	_viewport.add_child(fuell)
	var umgebung := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0a0e14")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#2b3644")
	e.ambient_light_energy = 1.35
	e.fog_enabled = true
	e.fog_light_color = Color("#0d131b")
	e.fog_density = 0.06
	umgebung.environment = e
	_viewport.add_child(umgebung)
