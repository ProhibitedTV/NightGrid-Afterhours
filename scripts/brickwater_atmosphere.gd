extends Node3D
## Small, deterministic street dressing layer. No global fog or weather edits.
const PAPER = preload("res://assets/models/nightgrid/brickwater_alley/discarded_print.svg")
const VAPOR = preload("res://assets/models/nightgrid/brickwater_alley/steam_sprite.svg")
const Frontage = preload("res://scripts/brickwater_business_frontage.gd")
var left_wall: float
var right_wall: float
var floor_y: float
var _spills: Array[OmniLight3D] = []

func set_night_factor(value: float) -> void:
	for spill in _spills:
		spill.light_energy = 1.55 * smoothstep(0.30, 0.80, value)

func configure(left: float, right: float, y: float) -> void:
	left_wall = left
	right_wall = right
	floor_y = y

func _ready() -> void:
	var paper := _paper_material(PAPER)
	# Fixed wall-side refuse, not a collision obstacle or random scatter.
	_litter("CrushedDispatch", Vector3(left_wall + 0.63, floor_y + 0.006, -4.1), 0.7, paper)
	_litter("DiscardedReceipt", Vector3(right_wall - 0.68, floor_y + 0.006, -1.1), -0.42, paper)
	_litter("OldFlyer", Vector3(left_wall + 0.61, floor_y + 0.006, 3.1), 1.8, paper)
	_litter("WetBroadsheet", Vector3(right_wall - 0.80, floor_y + 0.006, 6.8), -1.2, paper)
	# Keep the same two shadowless lights. Each source is inside its
	# visible blade, with enough range to reach the catchment below.
	_sign_spill("RepairSignSpill", Vector3(left_wall + 0.64, Frontage.BLADE_HEIGHT - 0.18, Frontage.REPAIR_Z), Color("ff456e"))
	_sign_spill("LaundrySignSpill", Vector3(right_wall - 0.64, Frontage.BLADE_HEIGHT - 0.18, Frontage.LAUNDRY_Z), Color("2faaf7"))
	_drain_vapor()

func _paper_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.25
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _litter(label: String, at: Vector3, yaw: float, material: StandardMaterial3D) -> void:
	# A folded, irregular paper surface, not a rectangular floating card.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-0.16, 0.0, -0.11), Vector3(0.17, 0.002, -0.10),
		Vector3(0.14, 0.018, 0.12), Vector3(-0.14, 0.0, 0.09), Vector3(0.0, 0.012, 0.0)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0.5, 0.5)]
	for i in range(4):
		for idx in [4, i, (i + 1) % 4]:
			tool.set_uv(uvs[idx])
			tool.add_vertex(points[idx])
	tool.generate_normals()
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = tool.commit()
	view.material_override = material
	view.position = at
	view.rotation.y = yaw
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.set_meta("street_litter", true)
	add_child(view)

func _sign_spill(label: String, at: Vector3, tint: Color) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.position = at
	light.light_color = tint
	light.light_energy = 0.0
	light.light_size = 0.54
	light.omni_range = 5.9
	light.omni_attenuation = 2.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.shadow_enabled = false
	add_child(light)
	_spills.append(light)

func _drain_vapor() -> void:
	# Spawn only at the existing drain grille. Single low-count local
	# plume, no volumetric fog, no additional lights or physics.
	var emitter := CPUParticles3D.new()
	emitter.name = "DrainSteam"
	emitter.position = Vector3(right_wall - 0.28, floor_y + 0.026, -3.0)
	emitter.amount = 12
	emitter.lifetime = 3.8
	emitter.preprocess = 2.0
	emitter.use_fixed_seed = true
	emitter.seed = 522
	emitter.direction = Vector3(-0.48, 0.76, 0.22).normalized()
	emitter.spread = 24.0
	emitter.gravity = Vector3(0, 0.025, 0)
	emitter.initial_velocity_min = 0.22
	emitter.initial_velocity_max = 0.52
	emitter.scale_amount_min = 0.54
	emitter.scale_amount_max = 1.28
	emitter.local_coords = true
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.18, 0.70, 1.0])
	fade.colors = PackedColorArray([Color(0.38,0.43,0.49,0.0), Color(0.38,0.43,0.49,0.13), Color(0.42,0.48,0.56,0.055), Color(0.42,0.48,0.56,0.0)])
	emitter.color_ramp = fade
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = VAPOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var sprite := QuadMesh.new()
	sprite.size = Vector2(0.72, 0.72)
	sprite.material = mat
	emitter.mesh = sprite
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.visibility_range_end = 24.0
	add_child(emitter)
