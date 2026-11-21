extends Node3D
## Bounded, original human-scale placeholder replacement for the player and
## generic shopkeepers. A readable clothed figure with articulated limb rigs,
## not a rectangle mannequin. Art-final PBR/skinned mesh is still outstanding.
static var _shared_mats: Dictionary = {}
var palette_index := 0
var role := "PLAYER"
var _clock := 0.0
var _speed := 0.0
var _torso: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _weapon_display: Node3D
var _weapon_id := "holstered"
var _weapon_aiming := false
var _stats := {"body_parts": 0, "face_parts": 0, "articulated_limbs": 0, "lights": 0, "colliders": 0}

const SKINS = [
	Color("b78e76"), Color("86634e"), Color("d2af93"), Color("9d7164"),
	Color("b69e86"), Color("76544a")
]
const COATS = [
	Color("364d5c"), Color("5b515a"), Color("4a6068"), Color("665a4d"),
	Color("445267"), Color("676166")
]
const HAIRS = [
	Color("2c3139"), Color("423332"), Color("353b47"), Color("513d33"),
	Color("282b32"), Color("454046")
]

func configure(next_palette: int, next_role: String) -> void:
	palette_index = posmod(next_palette, SKINS.size())
	role = next_role

func get_visual_stats() -> Dictionary:
	return _stats.duplicate()

func set_locomotion(speed: float) -> void:
	_speed = clampf(speed / 8.0, 0.0, 1.6)

func _ready() -> void:
	_build_character()
	if role == "PLAYER":
		_build_weapon_display()

func set_weapon_pose(id: String, aiming: bool) -> void:
	_weapon_id = id
	_weapon_aiming = aiming
	if is_instance_valid(_weapon_display):
		_weapon_display.visible = id != "holstered"
		_weapon_display.get_node("Pulse").visible = id == "pulse"
		_weapon_display.get_node("Arc").visible = id == "arc"

func _build_weapon_display() -> void:
	# Original compact sci-fi prop meshes, no real-world firearm blueprint.
	_weapon_display = Node3D.new()
	_weapon_display.name = "EquippedWeapon"
	_arms[1].add_child(_weapon_display)
	_weapon_display.position = Vector3(0.04, -0.73, 0.0)
	for id in ["Pulse", "Arc"]:
		var item := Node3D.new()
		item.name = id
		_weapon_display.add_child(item)
		var tint := Color("567b83") if id == "Pulse" else Color("926f67")
		_box(item, "Shell", Vector3(0, -0.09, 0.04), Vector3(0.105, 0.26 if id == "Pulse" else 0.39, 0.15), tint, "STEEL")
		_box(item, "Housing", Vector3(0, 0.01, -0.045), Vector3(0.09, 0.12, 0.08), Color("26353e"), "LEATHER")
		_box(item, "Accent", Vector3(0, -0.13, 0.12), Vector3(0.075, 0.09, 0.014), Color("81d5cd") if id == "Pulse" else Color("e3bb83"), "STEEL")
	_weapon_display.hide()

func _process(delta: float) -> void:
	_clock = fposmod(_clock + delta, 1200.0)
	if _torso == null:
		return
	var t := _clock
	var walking := clampf(_speed, 0.0, 1.0)
	var stride := sin(t * (4.0 + walking * 5.8))
	_torso.position.y = 0.95 + sin(t * 1.25) * 0.010 + absf(stride) * walking * 0.027
	_torso.rotation.z = sin(t * 0.85) * 0.015 + sin(t * 6.0) * walking * 0.015
	_head.rotation.y = sin(t * 0.27) * 0.10 * (1.0 - walking * 0.6)
	_head.rotation.x = sin(t * 0.53) * 0.03
	for i in range(_arms.size()):
		_arms[i].rotation.x = stride * (0.45 if i == 0 else -0.45) * walking
		_arms[i].rotation.z = (-0.08 if i == 0 else 0.08)
	if role == "PLAYER" and _weapon_id != "holstered" and _arms.size() > 1:
		_arms[1].rotation.x = -PI * 0.5 if _weapon_aiming else -0.12
		_arms[1].rotation.z = 0.0
	for i in range(_legs.size()):
		_legs[i].rotation.x = stride * (-0.38 if i == 0 else 0.38) * walking
	var interval := fposmod(t, 4.25 + float(palette_index) * 0.19)
	var open_amount := clampf(absf(interval - 2.19) / 0.13, 0.07, 1.0)
	for eye in _eyes:
		eye.scale.y = open_amount
	# Ease quickly to stillness when player releases locomotion controls.
	_speed = move_toward(_speed, 0.0, delta * 6.0)

func _mat(kind: String, tint: Color) -> StandardMaterial3D:
	var key := kind + "|" + tint.to_html()
	if _shared_mats.has(key):
		return _shared_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	match kind:
		"SKIN": m.roughness = 0.74
		"HAIR":
			m.roughness = 0.47
			m.metallic = 0.02
		"FABRIC": m.roughness = 0.89
		"LEATHER":
			m.roughness = 0.64
			m.metallic = 0.03
		"EYE": m.roughness = 0.26
		"STEEL":
			m.roughness = 0.42
			m.metallic = 0.68
		_ : m.roughness = 0.74
	_shared_mats[key] = m
	return m

func _sphere(parent: Node3D, name_value: String, where: Vector3, dimensions: Vector3,
		tint: Color, kind: String, face: bool = false) -> void:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 14
	shape.rings = 8
	var instance := MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = shape
	instance.position = where
	instance.scale = dimensions
	instance.material_override = _mat(kind, tint)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	if face:
		_stats["face_parts"] += 1
	else:
		_stats["body_parts"] += 1

func _box(parent: Node3D, name_value: String, where: Vector3, dimensions: Vector3,
		tint: Color, kind: String) -> void:
	var shape := BoxMesh.new()
	shape.size = dimensions
	var instance := MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = shape
	instance.position = where
	instance.material_override = _mat(kind, tint)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	_stats["body_parts"] += 1

func _pivot(parent: Node3D, name_value: String, where: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_value
	pivot.position = where
	parent.add_child(pivot)
	return pivot

func _build_character() -> void:
	var skin: Color = SKINS[palette_index]
	var coat: Color = COATS[palette_index]
	var hair: Color = HAIRS[palette_index]
	_sphere(self, "Pelvis", Vector3(0.0, 0.88, 0.0), Vector3(0.45, 0.33, 0.31),
		coat.darkened(0.22), "FABRIC")
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.19
		var leg := _pivot(self,
			"LeftWalkingLeg" if side < 0.0 else "RightWalkingLeg",
			Vector3(x, 0.85, 0.01))
		_legs.append(leg)
		_sphere(leg, "TaperedTrouser", Vector3(0.0, -0.36, 0.0),
			Vector3(0.235, 0.77, 0.255), coat.darkened(0.17), "FABRIC")
		_sphere(leg, "WorkBoot", Vector3(0.0, -0.75, 0.095),
			Vector3(0.26, 0.18, 0.42), Color("282e36"), "LEATHER")
	_torso = _pivot(self, "BreathingTorso", Vector3(0.0, 0.95, 0.0))
	_sphere(_torso, "FittedJacket", Vector3(0.0, 0.24, 0.0),
		Vector3(0.77, 0.79, 0.44), coat, "FABRIC")
	_sphere(_torso, "ShirtNeckline", Vector3(0.0, 0.54, 0.21),
		Vector3(0.27, 0.14, 0.13), Color("bcc3bf"), "FABRIC")
	_sphere(_torso, "Neck", Vector3(0.0, 0.63, 0.0),
		Vector3(0.20, 0.22, 0.20), skin, "SKIN")
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.43
		var shoulder := _pivot(_torso,
			"LeftArmSwing" if side < 0.0 else "RightArmSwing",
			Vector3(x, 0.50, 0.0))
		_arms.append(shoulder)
		_sphere(shoulder, "JacketSleeve", Vector3(side * 0.036, -0.28, 0.0),
			Vector3(0.27, 0.63, 0.29), coat.lightened(0.045), "FABRIC")
		_sphere(shoulder, "SleeveHem", Vector3(side * 0.036, -0.57, 0.0),
			Vector3(0.23, 0.13, 0.23), coat.darkened(0.26), "FABRIC")
		_sphere(shoulder, "Hand", Vector3(side * 0.036, -0.71, 0.0),
			Vector3(0.16, 0.20, 0.15), skin, "SKIN")
		# Utility wristband provides believable material scale.
		_sphere(shoulder, "Wristband", Vector3(side * 0.036, -0.63, 0.0),
			Vector3(0.165, 0.07, 0.158), Color("647e89"), "STEEL")
	_head = _pivot(_torso, "HeadLookRig", Vector3(0.0, 0.92, 0.0))
	_sphere(_head, "HumanHead", Vector3(0.0, 0.0, 0.01),
		Vector3(0.43, 0.53, 0.41), skin, "SKIN", true)
	_sphere(_head, "Jaw", Vector3(0.0, -0.15, 0.06),
		Vector3(0.30, 0.24, 0.32), skin.darkened(0.035), "SKIN", true)
	_sphere(_head, "HairCap", Vector3(0.0, 0.215, -0.06),
		Vector3(0.48, 0.26, 0.42), hair, "HAIR", true)
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.113
		_sphere(_head, "Ear", Vector3(float(side) * 0.22, -0.015, 0.0),
			Vector3(0.07, 0.14, 0.08), skin, "SKIN", true)
		var eye := _pivot(_head, "LeftBlinkEye" if side < 0.0 else "RightBlinkEye",
			Vector3(x, 0.035, 0.197))
		_eyes.append(eye)
		_sphere(eye, "Sclera", Vector3.ZERO, Vector3(0.08, 0.048, 0.04),
			Color("d8dbd4"), "EYE", true)
		_sphere(eye, "Iris", Vector3(0.0, 0.0, 0.028),
			Vector3(0.038, 0.038, 0.021), Color("607f80"), "EYE", true)
		_sphere(_head, "Brow", Vector3(x, 0.114, 0.185),
			Vector3(0.12, 0.021, 0.03), hair, "HAIR", true)
	_sphere(_head, "NoseBridge", Vector3(0.0, -0.049, 0.221),
		Vector3(0.086, 0.17, 0.104), skin, "SKIN", true)
	_sphere(_head, "Mouth", Vector3(0.0, -0.157, 0.191),
		Vector3(0.135, 0.024, 0.021), skin.darkened(0.23), "SKIN", true)
	# All heads/actors are original and low-cost, but intentionally do NOT
	# claim high-resolution skin/hair/rig or imported photoreal source art.
	if role == "PLAYER":
		_box(_torso, "CourierHarness", Vector3(0.0, 0.20, -0.25),
			Vector3(0.68, 0.21, 0.10), Color("28333c"), "LEATHER")
		_sphere(_torso, "HarnessClasp", Vector3(0.0, 0.20, -0.319),
			Vector3(0.12, 0.11, 0.04), Color("6fb7b4"), "STEEL")
	else:
		_box(_torso, "ServiceNameplate", Vector3(0.19, 0.35, 0.24),
			Vector3(0.18, 0.055, 0.04), Color("a5ad9e"), "STEEL")
	_stats["articulated_limbs"] = _arms.size() + _legs.size()
