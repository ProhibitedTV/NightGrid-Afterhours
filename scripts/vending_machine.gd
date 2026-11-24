extends StaticBody3D
## Shared authored machine art. No per-machine frame callbacks or lights.
const Catalog = preload("res://scripts/consumables.gd")
const SignShader = preload("res://assets/vending/animated_display.gdshader")
const Faces = [preload("res://assets/vending/nightgrid_cyan.svg"),preload("res://assets/vending/nightgrid_magenta.svg")]
const SideArt = [preload("res://assets/vending/side_nightshift.svg"),preload("res://assets/vending/side_volt.svg")]
const SIZE = Vector3(1.6,2.4,1.0)
static var _shell := BoxMesh.new()
static var _sign := QuadMesh.new()
static var _shape := BoxShape3D.new()
static var _materials: Dictionary = {}
static var _displays: Dictionary = {}
static var _batches: Dictionary = {}
static var _side_materials: Dictionary = {}
static var _side_mesh: MultiMesh
var variant := 0

func configure(style: int, accent: Color) -> void:
	variant = posmod(style,Faces.size())
	set_meta("items",Catalog.assortment(variant))
	_shape.size = SIZE
	var collision := CollisionShape3D.new()
	collision.shape = _shape
	collision.position.y = SIZE.y*.5
	add_child(collision)
	var metal := _material(Color("293744"),.68,.48)
	var dark := _material(Color("111c24"),.4,.66)
	var neon := _material(accent,.2,.35,true)
	# A compact, fixed silhouette: one structural body, metal ribs,
	# dark recessed collection slot and protected emissive edge strips.
	_batch("Cabinet",metal,[
		[Vector3(0,1.2,0),SIZE],
		[Vector3(0,.11,-.04),Vector3(1.57,.18,.98)],
		[Vector3(0,2.33,-.04),Vector3(1.58,.14,1.0)],
		[Vector3(-.73,1.25,-.53),Vector3(.11,2.0,.10)],
		[Vector3(.73,1.25,-.53),Vector3(.11,2.0,.10)],
		[Vector3(0,.35,-.53),Vector3(1.32,.30,.10)]
	])
	_batch("Recesses",dark,[
		[Vector3(0,.35,-.59),Vector3(1.08,.18,.03)],
		[Vector3(.63,1.1,-.59),Vector3(.13,.33,.05)],
		[Vector3(0,2.32,-.56),Vector3(1.3,.09,.04)]
	])
	_batch("NeonTrim",neon,[
		[Vector3(-.66,1.35,-.60),Vector3(.035,1.85,.03)],
		[Vector3(.66,1.35,-.60),Vector3(.035,1.85,.03)],
		[Vector3(0,.23,-.60),Vector3(1.10,.035,.03)]
	])
	var display := MeshInstance3D.new()
	display.name = "AnimatedMarquee"
	_sign.size = Vector2(1.23,1.80)
	display.mesh = _sign
	display.position = Vector3(0,1.43,-.575)
	display.rotation.y = PI
	display.material_override = _display(variant)
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(display)
	_build_side_art()

func _build_side_art() -> void:
	if _side_mesh == null:
		var panel := QuadMesh.new()
		panel.size = Vector2(.81,1.91)
		_side_mesh = MultiMesh.new()
		_side_mesh.transform_format = MultiMesh.TRANSFORM_3D
		_side_mesh.mesh = panel
		_side_mesh.instance_count = 2
		_side_mesh.set_instance_transform(0,Transform3D(Basis(Vector3.UP,PI*.5),Vector3(.805,1.27,.01)))
		_side_mesh.set_instance_transform(1,Transform3D(Basis(Vector3.UP,-PI*.5),Vector3(-.805,1.27,.01)))
	if not _side_materials.has(variant):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = SideArt[variant]
		mat.roughness = .66
		mat.emission_enabled = true
		mat.emission_texture = SideArt[variant]
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = .16
		_side_materials[variant] = mat
	var sides := MultiMeshInstance3D.new()
	sides.name = "BrandSidePanels"
	sides.multimesh = _side_mesh
	sides.material_override = _side_materials[variant]
	sides.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sides)

func reachable(at: Vector3) -> bool:
	var p := to_local(at)
	return absf(p.x)<=1.3 and p.z>=-2.3 and p.z<=-.45 and p.y>=.2 and p.y<=2.5

func _material(tint: Color, metallic: float, rough: float, glow: bool = false) -> StandardMaterial3D:
	var key := "%s/%s/%s/%s" % [tint.to_html(),metallic,rough,glow]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.metallic = metallic
		mat.roughness = rough
		mat.emission_enabled = glow
		if glow:
			mat.emission = tint
			mat.emission_energy_multiplier = 1.4
		_materials[key] = mat
	return _materials[key]

func _display(style: int) -> ShaderMaterial:
	if not _displays.has(style):
		var mat := ShaderMaterial.new()
		mat.shader = SignShader
		mat.set_shader_parameter("artwork",Faces[style])
		mat.set_shader_parameter("neon_tint",Color("e87abd") if style==1 else Color("53e8e0"))
		_displays[style] = mat
	return _displays[style]

func _batch(label: String, material: Material, parts: Array) -> void:
	if not _batches.has(label):
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = _shell
		mesh.instance_count = parts.size()
		for i in parts.size():
			mesh.set_instance_transform(i,Transform3D(Basis.from_scale(parts[i][1]),parts[i][0]))
		_batches[label] = mesh
	var visual := MultiMeshInstance3D.new()
	visual.name = label
	visual.multimesh = _batches[label]
	visual.material_override = material
	add_child(visual)
