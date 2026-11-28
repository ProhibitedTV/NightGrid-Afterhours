extends Node3D
## One resident of Lantern Cup; authored identity, deterministic motion, no AI,
## pathfinding, additional lights, runtime mesh creation or save-schema changes.
## Local origin stays on the café floor. Customization is applied before _ready.
static var _shared_materials: Dictionary = {}
const PatronBank = preload("res://scripts/character_bank.gd")
var _bank_visual: Node3D

var resident_id := ""
var role := ""
var activity := "READ"
var seated := true
var palette := 0
var phase := 0.0
var _clock := 0.0
var _torso: Node3D
var _head: Node3D
var _right_hand: Node3D
var _blink: Node3D
var _second_blink: Node3D
var _cup: Node3D
var _stats := {"mesh_parts": 0, "joints": 0, "lights": 0, "colliders": 0}
var _last_activity := ""

const SKINS = [
	Color("b78c76"), Color("8e634d"), Color("c8aa8e"), Color("9f7569"),
	Color("b9a28a")
]
const JACKETS = [
	Color("465c63"), Color("746055"), Color("4d5365"), Color("70667d"),
	Color("42675c")
]
const HAIRS = [
	Color("242630"), Color("3c3235"), Color("363d44"), Color("5a443e"),
	Color("2e343c")
]

func configure(data: Dictionary) -> void:
	resident_id = str(data.get("id", ""))
	role = str(data.get("role", ""))
	activity = str(data.get("activity", "READ"))
	seated = bool(data.get("seated", true))
	palette = clampi(int(data.get("palette", 0)), 0, 4)
	phase = float(data.get("phase", 0.0))
	name = "Patron_" + resident_id

func get_identity() -> Dictionary:
	return {
		"id": resident_id, "role": role, "activity": activity,
		"seated": seated, "palette": palette,
		"anchor": position, "phase": phase
	}

func get_visual_stats() -> Dictionary:
	return _stats.duplicate()

func get_animation_state() -> Dictionary:
	return {
		"activity": _last_activity,
		"blink_open": _blink.scale.y if _blink != null else 1.0,
		"cup_raised": _cup.position.y if _cup != null else 0.0,
		"head_yaw": _head.rotation.y if _head != null else 0.0
	}

func _ready() -> void:
	_build_character()
	# Staff subclasses finish their own badge/role geometry before swapping.
	if not has_method("configure_staff"):
		_bank_visual = PatronBank.install(self, PatronBank.choose(resident_id), seated)
	set_process(not is_instance_valid(_bank_visual))

func _process(delta: float) -> void:
	_clock = fposmod(_clock + maxf(0.0, delta), 1800.0)
	var t := _clock + phase
	if _torso == null:
		return
	# An inexpensive breathing pivot and slightly different action timings
	# establish life without ever rebuilding vertex buffers each frame.
	_torso.position.y = (1.18 if seated else 1.31) + sin(t * 1.38) * 0.008
	_torso.rotation.z = sin(t * 0.71) * 0.017
	_head.rotation.y = sin(t * 0.31) * (0.19 if activity == "CHAT" else 0.075)
	_head.rotation.x = sin(t * (0.63 if activity == "READ" else 0.27)) * 0.045
	var blink_time := fposmod(t, 4.05 + float(palette) * 0.22)
	var blink_open := clampf(absf(blink_time - 1.87) / 0.11, 0.07, 1.0)
	_blink.scale.y = blink_open
	_second_blink.scale.y = blink_open
	_last_activity = activity
	if _right_hand != null:
		var lift := 0.0
		match activity:
			"SIP":
				lift = pow(maxf(0.0, sin(t * 1.20)), 2.0) * 0.29
			"CHAT":
				lift = sin(t * 1.85) * 0.10
			"READ":
				lift = sin(t * 0.62) * 0.018
			"SCROLL":
				lift = sin(t * 1.14) * 0.025
		_right_hand.position.y = -0.40 + lift
		_right_hand.rotation.x = lift * 0.68
		if _cup != null:
			_cup.position.y = -0.27 + lift

func _mat(kind: String, color: Color) -> StandardMaterial3D:
	var key := kind + "|" + color.to_html(true)
	if _shared_materials.has(key):
		return _shared_materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	match kind:
		"SKIN":
			material.roughness = 0.68
		"HAIR":
			material.roughness = 0.57
			material.metallic = 0.02
		"FABRIC":
			material.roughness = 0.87
		"METAL":
			material.roughness = 0.41
			material.metallic = 0.68
		"EYE":
			material.roughness = 0.26
		"SCREEN":
			material.albedo_color = color.darkened(0.68)
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 0.48
			material.roughness = 0.34
		_:
			material.roughness = 0.75
	_shared_materials[key] = material
	return material

func _part(parent: Node3D, label: String, mesh: Mesh, at: Vector3,
		tint: Color, kind: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = at
	part.material_override = _mat(kind, tint)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	_stats["mesh_parts"] += 1
	return part

func _ellipsoid(parent: Node3D, label: String, at: Vector3,
		shape: Vector3, tint: Color, kind: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var part := _part(parent, label, mesh, at, tint, kind)
	part.scale = shape
	return part

func _cylinder(parent: Node3D, label: String, at: Vector3, radius: float,
		height: float, tint: Color, kind: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	return _part(parent, label, mesh, at, tint, kind)

func _box(parent: Node3D, label: String, at: Vector3,
		dimensions: Vector3, tint: Color, kind: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _part(parent, label, mesh, at, tint, kind)

func _pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = at
	parent.add_child(pivot)
	_stats["joints"] += 1
	return pivot

func _build_character() -> void:
	var skin: Color = SKINS[palette]
	var coat: Color = JACKETS[palette]
	var hair: Color = HAIRS[palette]
	# Colliders intentionally omitted. Patrons occupy existing seats and
	# wall-side corners without introducing invisible player obstacles.
	_ellipsoid(self, "Hips", Vector3(0.0, 0.83, -0.10) if seated else Vector3(0.0, 0.97, 0.0),
		Vector3(0.42, 0.30, 0.28), coat.darkened(0.22), "FABRIC")
	if seated:
		for side in [-1.0, 1.0]:
			var x: float = float(side) * 0.16
			_ellipsoid(self, "SeatedThigh", Vector3(x, 0.68, 0.28),
				Vector3(0.21, 0.22, 0.72), coat.darkened(0.12), "FABRIC")
			_ellipsoid(self, "SeatedShin", Vector3(x, 0.38, 0.55),
				Vector3(0.19, 0.60, 0.19), coat.darkened(0.18), "FABRIC")
			_ellipsoid(self, "Boot", Vector3(x, 0.12, 0.67),
				Vector3(0.23, 0.18, 0.37), Color("292e34"), "FABRIC")
	else:
		for side in [-1.0, 1.0]:
			var x: float = float(side) * 0.18
			_ellipsoid(self, "StandingLeg", Vector3(x, 0.47, 0.0),
				Vector3(0.22, 0.84, 0.25), coat.darkened(0.18), "FABRIC")
			_ellipsoid(self, "Boot", Vector3(x, 0.10, 0.12),
				Vector3(0.25, 0.18, 0.38), Color("292e34"), "FABRIC")
	_torso = _pivot(self, "BreathingTorso", Vector3(0.0, 1.18 if seated else 1.31, 0.0))
	_ellipsoid(_torso, "JacketSilhouette", Vector3.ZERO,
		Vector3(0.73, 0.85, 0.40), coat, "FABRIC")
	_box(_torso, "Collar", Vector3(0.0, 0.32, 0.16),
		Vector3(0.23, 0.11, 0.15), Color("aab4af"), "FABRIC")
	_cylinder(_torso, "Neck", Vector3(0.0, 0.47, 0.0), 0.102, 0.23, skin, "SKIN")
	_head = _pivot(_torso, "LookHead", Vector3(0.0, 0.66, 0.0))
	_ellipsoid(_head, "FaceAndCheeks", Vector3(0.0, 0.0, 0.015),
		Vector3(0.43, 0.51, 0.40), skin, "SKIN")
	_ellipsoid(_head, "HairCap", Vector3(0.0, 0.21, -0.06),
		Vector3(0.48, 0.26, 0.42), hair, "HAIR")
	if palette % 2 == 0:
		_box(_head, "TaperedHairFringe", Vector3(-0.08, 0.15, 0.20),
			Vector3(0.27, 0.14, 0.085), hair, "HAIR")
	else:
		_cylinder(_head, "WorkShiftBeanie", Vector3(0.0, 0.25, -0.035),
			0.24, 0.18, coat.darkened(0.32), "FABRIC")
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.105
		var eye_rig := _pivot(_head,
			"LeftEyeBlink" if side < 0.0 else "RightEyeBlink",
			Vector3(x, 0.038, 0.204))
		if side < 0.0:
			_blink = eye_rig
		else:
			_second_blink = eye_rig
		_ellipsoid(eye_rig, "White", Vector3.ZERO,
			Vector3(0.082, 0.052, 0.034), Color("e5ddd0"), "EYE")
		_ellipsoid(eye_rig, "Pupil", Vector3(0.0, 0.0, 0.023),
			Vector3(0.028, 0.034, 0.014), Color("293942"), "EYE")
		_ellipsoid(_head, "Ear", Vector3(float(side) * 0.216, -0.02, 0.0),
			Vector3(0.07, 0.12, 0.075), skin, "SKIN")
	_ellipsoid(_head, "Nose", Vector3(0.0, -0.052, 0.221),
		Vector3(0.075, 0.080, 0.081), skin, "SKIN")
	_ellipsoid(_head, "Mouth", Vector3(0.0, -0.132, 0.187),
		Vector3(0.11, 0.018, 0.018), skin.darkened(0.21), "SKIN")
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.42
		_ellipsoid(_torso, "TailoredSleeve", Vector3(x, -0.12, 0.01),
			Vector3(0.27, 0.65, 0.29), coat, "FABRIC")
		if side < 0.0:
			_ellipsoid(_torso, "Hand", Vector3(x, -0.44, 0.17),
				Vector3(0.13, 0.21, 0.15), skin, "SKIN")
	_right_hand = _pivot(_torso, "ActivityHand", Vector3(0.43, -0.40, 0.19))
	_ellipsoid(_right_hand, "RightHandGlove", Vector3.ZERO,
		Vector3(0.15, 0.18, 0.15), skin, "SKIN")
	match activity:
		"SIP":
			_cup = _pivot(_right_hand, "CoffeeCup", Vector3(0.0, -0.27, 0.30))
			_cylinder(_cup, "Cup", Vector3.ZERO, 0.091, 0.17, Color("cac9bd"), "FABRIC")
			_cylinder(_cup, "Lid", Vector3(0.0, 0.095, 0.0), 0.098, 0.025,
				Color("5d646b"), "METAL")
		"READ":
			_box(_torso, "PocketPaperback", Vector3(0.0, -0.31, 0.39),
				Vector3(0.36, 0.035, 0.23), Color("a99a87"), "FABRIC")
		"SCROLL":
			_box(_torso, "PocketDisplay", Vector3(0.0, -0.27, 0.40),
				Vector3(0.23, 0.28, 0.031), Color("68aaa7"), "SCREEN")
		"CHAT":
			_box(_torso, "UnionShiftTag", Vector3(-0.19, 0.18, 0.22),
				Vector3(0.21, 0.05, 0.025), Color("d3aa72"), "METAL")
