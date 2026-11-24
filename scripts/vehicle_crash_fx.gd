extends RefCounted
## Impact aftermath is cosmetic and bounded per SceneTree, not per vehicle.
## Debris interacts with static world collision but cannot block traffic or
## trigger a second crash. No particles or bodies for an undamaged car.
const SMOKE_GROUP = &"vehicle_crash_smoke"
const DEBRIS_GROUP = &"vehicle_crash_debris"
const MAX_SMOKE = 6
const MAX_DEBRIS = 18
const DEBRIS_LIFETIME = 7.0
static var _smoke_mesh: QuadMesh
static var _smoke_fade: Gradient
static var _shard_mesh: BoxMesh
static var _shard_shape: BoxShape3D

static func _make_smoke() -> void:
	if _smoke_mesh != null:
		return
	var radial := Gradient.new()
	radial.colors = PackedColorArray([Color(1, 1, 1, .70), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = radial
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5, .5)
	texture.fill_to = Vector2(1, .5)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	_smoke_mesh = QuadMesh.new()
	_smoke_mesh.size = Vector2(.65, .65)
	_smoke_mesh.material = material
	_smoke_fade = Gradient.new()
	_smoke_fade.offsets = PackedFloat32Array([0.0, .18, .65, 1.0])
	_smoke_fade.colors = PackedColorArray([Color(.30,.30,.31,0), Color(.30,.30,.31,.72), Color(.42,.42,.44,.38), Color(.50,.50,.52,0)])

static func sync_smoke(car: Node3D, condition: float, zones: Vector4, mount: Vector3 = Vector3.INF) -> void:
	if not car.is_inside_tree():
		return
	var emitter := car.get_node_or_null("CrashSmoke") as CPUParticles3D
	var needed := condition <= 45.0 or zones.x >= .82
	if not needed:
		if emitter != null:
			emitter.remove_from_group(SMOKE_GROUP)
			car.remove_child(emitter)
			emitter.queue_free()
		return
	if emitter == null:
		if car.get_tree().get_nodes_in_group(SMOKE_GROUP).size() >= MAX_SMOKE:
			return
		_make_smoke()
		emitter = CPUParticles3D.new()
		emitter.name = "CrashSmoke"
		emitter.emitting = false
		emitter.amount = 22
		emitter.lifetime = 2.0
		emitter.direction = Vector3.UP
		emitter.spread = 24.0
		emitter.gravity = Vector3(0, .32, 0)
		emitter.initial_velocity_min = .65
		emitter.initial_velocity_max = 1.45
		emitter.scale_amount_min = .6
		emitter.scale_amount_max = 1.3
		emitter.color_ramp = _smoke_fade
		emitter.mesh = _smoke_mesh
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.visibility_range_end = 44.0
		emitter.position = mount if mount.is_finite() else Vector3(0, .28 if str(car.get("model_id")).is_empty() else -.12, -1.55)
		car.add_child(emitter)
		emitter.add_to_group(SMOKE_GROUP)
		emitter.emitting = true

static func burst(car: CharacterBody3D, at: Vector3, incoming: Vector3, closing: float) -> void:
	if closing < 16.0 or not car.is_inside_tree() or not at.is_finite() or not incoming.is_finite():
		return
	var tree := car.get_tree()
	var room := MAX_DEBRIS - tree.get_nodes_in_group(DEBRIS_GROUP).size()
	if room <= 0:
		return
	if _shard_mesh == null:
		_shard_mesh = BoxMesh.new()
		_shard_mesh.size = Vector3(.12, .025, .20)
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(.17,.19,.21)
		metal.metallic = .72
		metal.roughness = .57
		_shard_mesh.material = metal
		_shard_shape = BoxShape3D.new()
		_shard_shape.size = _shard_mesh.size
	var outward := -incoming.normalized()
	if outward.length_squared() < .1:
		outward = car.global_basis.z
	for index in mini(room, 3 if closing >= 28.0 else 2):
		var body := RigidBody3D.new()
		body.name = "CrashMetalFragment"
		body.mass = .18
		body.collision_layer = 0
		body.collision_mask = 1
		body.continuous_cd = true
		body.contact_monitor = false
		var view := MeshInstance3D.new()
		view.mesh = _shard_mesh
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(view)
		var hitbox := CollisionShape3D.new()
		hitbox.shape = _shard_shape
		body.add_child(hitbox)
		car.get_parent().add_child(body)
		body.add_to_group(DEBRIS_GROUP)
		body.set_meta("crash_owner", car.get_instance_id())
		body.add_collision_exception_with(car)
		body.global_position = at + outward * .22 + Vector3.UP * (.16 + .06 * index)
		body.linear_velocity = outward * minf(closing * .15, 5.0) + Vector3.UP * (1.6 + index * .65) + car.global_basis.x * (float(index) - 1.0) * 2.0
		body.angular_velocity = Vector3(2.2 + index, -3.0 + index, 4.0)
		var timer := Timer.new()
		timer.name = "FragmentLifetime"
		timer.one_shot = true
		timer.wait_time = DEBRIS_LIFETIME
		body.add_child(timer)
		timer.timeout.connect(body.queue_free)
		timer.start()

static func clear_debris(car: Node3D) -> void:
	if not car.is_inside_tree():
		return
	for body in car.get_tree().get_nodes_in_group(DEBRIS_GROUP):
		if body.get_meta("crash_owner", -1) == car.get_instance_id():
			body.remove_from_group(DEBRIS_GROUP)
			body.queue_free()
