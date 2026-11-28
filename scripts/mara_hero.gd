extends Node3D
## MARA — original stylized human hero character for Lantern Cup.
## Layered mesh anatomy, articulated idle/talk performance, no imported assets.
## Local origin sits on her raised work-platform behind the existing counter.
const HeroBank = preload("res://scripts/character_bank.gd")
var _bank_visual: Node3D
const BASE_SKIN = Color("b78169")
const SHADOW_SKIN = Color("8c6054")
const COAT = Color("304c53")
const COAT_EDGE = Color("719295")
const APRON = Color("554a46")
const APRON_SEAM = Color("ab8c72")
const HAIR = Color("25272f")
const HAIR_GLAZE = Color("43434d")
const COPPER = Color("c49a70")
const EYE_IRIS = Color("769d9a")
const GLOW = Color("68d9c8")

var _materials: Dictionary = {}
var _stats := {
	"body_meshes": 0, "face_details": 0, "hair_sections": 0,
	"uniform_details": 0, "joints": 0, "animations": 4,
	"live_lights": 0, "imported_assets": 0
}
var _torso: Node3D
var _head: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_eye: Node3D
var _right_eye: Node3D
var _mouth: MeshInstance3D
var _clock := 0.0
var _speaking := 0.0
var _service_gesture := 0.0
var _focused := false
var _target := Vector3(0.0, 1.55, 3.0)
var _topic := 0

func _ready() -> void:
	_build_rig()
	_build_uniform()
	_build_face_and_hair()
	_build_service_details()
	var model_id := "nina_bell" if has_method("set_phone_call") else "service_staff_01"
	_bank_visual = HeroBank.install(self, model_id)

func get_character_stats() -> Dictionary:
	return _stats.duplicate()

func get_performance_state() -> Dictionary:
	return {
		"focused": _focused,
		"speaking": _speaking > 0.0,
		"service_gesture": _service_gesture > 0.0,
		"topic": _topic,
		"head_yaw": _head.rotation.y if _head != null else 0.0,
		"blink_open": _left_eye.scale.y if _left_eye != null else 1.0
	}

func set_attention(active: bool) -> void:
	_focused = active
	if active:
		_speaking = maxf(_speaking, 0.42)

func set_look_target(world_position: Vector3) -> void:
	_target = to_local(world_position)

func react_to_purchase() -> void:
	_service_gesture = 1.9
	_speaking = 1.5
	_focused = true

func react_to_discovery() -> void:
	_speaking = 1.6
	_focused = true

func greeting(context: Dictionary) -> String:
	if float(context.get("health", 100.0)) < 42.0:
		return "Mara: You look like you've had a hard shift. Sit down. Let me get the kettle going."
	if float(context.get("hour", 12.0)) >= 19.0:
		return "Mara: Evening, courier. The Lantern Cup keeps a light on while the market winds down."
	return "Mara: Welcome to Lantern Cup. I'm Mara. We make coffee for people who keep this city running."

func next_dialogue(context: Dictionary) -> Dictionary:
	var current := _topic % 4
	_topic += 1
	var discovered := bool(context.get("shift_notes", false))
	var heat := float(context.get("heat", 0.0))
	var job := str(context.get("job", ""))
	var message := ""
	var topic_name := ""
	match current:
		0:
			topic_name = "THE NIGHT SHIFT"
			message = greeting(context)
			var tier := int(context.get("outfit_tier",0))
			if tier >= 2 and heat < .8 and float(context.get("health",100.0)) >= 42.0:
				topic_name = "DRESSED FOR THE CITY"
				message = "Mara: That's a sharp Vesper look. People notice when you take pride in yourself."
				if tier >= 3:
					message = "Mara: That atelier finish suits you. At Afterimage Lounge, presentation gets people talking. Try asking Iris about the glass invoice."
		1:
			topic_name = "VESPER MARKET"
			message = ("Mara: The patrols are watching the street tonight. Keep the storefronts between you and their cameras."
				if heat >= 0.8 else
				"Mara: Vesper remembers every worker the skyline tried to replace. Take a look around; we're still here.")
		2:
			topic_name = "THE SHIFT NOTES"
			message = ("Mara: So you found my notes. That alley door is real, but the people using it do not want to be seen."
				if discovered else
				"Mara: I leave notes at the booth by the east wall. Some things are safer written than said out loud.")
		3:
			topic_name = "NEIGHBORHOOD WORK"
			message = ("Mara: Finish the job you took. Around here, being dependable matters more than being quick."
				if not job.is_empty() else
				"Mara: Ask around Moon Noodles and Copper Cup. Nobody knows the neighborhood better than the night shift.")
	_speaking = 2.6
	_focused = true
	return {"topic": topic_name, "line": message, "index": current}

func _process(delta: float) -> void:
	_clock = fposmod(_clock + delta, 3600.0)
	_speaking = maxf(0.0, _speaking - delta)
	_service_gesture = maxf(0.0, _service_gesture - delta)
	var engaged := _focused or _speaking > 0.0 or _service_gesture > 0.0
	if is_instance_valid(_bank_visual):
		_bank_visual.call("set_attention_target", to_global(_target), engaged)
		_bank_visual.call("set_activity", "SOCIALIZE" if engaged else "WALK")
		return
	if _torso != null:
		_torso.position.y = 1.05 + sin(_clock * 1.7) * 0.008
		_torso.rotation.z = sin(_clock * 0.79) * 0.014
	if _head != null:
		var desired := clampf(atan2(_target.x, maxf(0.8, _target.z + 0.35)), -0.32, 0.32) if engaged else sin(_clock * 0.29) * 0.13
		_head.rotation.y = lerpf(_head.rotation.y, desired, minf(1.0, delta * 4.0))
		_head.rotation.x = lerpf(_head.rotation.x, -0.035 if engaged else sin(_clock * 0.31) * 0.034,
			minf(1.0, delta * 4.5))
	# Deterministic paired blinks rather than randomized per-frame geometry.
	var blink := fposmod(_clock, 4.37)
	var openness := clampf(absf(blink - 2.24) / 0.115, 0.07, 1.0)
	if _left_eye != null:
		_left_eye.scale.y = openness
		_right_eye.scale.y = openness
	if _mouth != null:
		_mouth.scale.y = 1.0 + (0.46 * absf(sin(_clock * 16.0)) if _speaking > 0.0 else 0.0)
	if _left_arm != null:
		_left_arm.rotation.z = sin(_clock * 1.19) * 0.055
	if _right_arm != null:
		var impulse := sin(_clock * 9.2) * 0.27 if _service_gesture > 0.0 else 0.0
		_right_arm.rotation.x = -0.17 + impulse
		_right_arm.rotation.z = -0.11 if _service_gesture > 0.0 else sin(_clock * 0.92) * 0.045

func _mat(category: String, tint: Color) -> StandardMaterial3D:
	var key := category + "|" + tint.to_html(true)
	if _materials.has(key):
		return _materials[key]
	var surface := StandardMaterial3D.new()
	surface.albedo_color = tint
	match category:
		"SKIN":
			surface.metallic = 0.0
			surface.roughness = 0.71
		"HAIR":
			surface.metallic = 0.05
			surface.roughness = 0.47
		"FABRIC":
			surface.metallic = 0.0
			surface.roughness = 0.86
		"LEATHER":
			surface.metallic = 0.03
			surface.roughness = 0.67
		"BRASS":
			surface.metallic = 0.72
			surface.roughness = 0.36
		"EYE":
			surface.metallic = 0.0
			surface.roughness = 0.18
		"GLOW":
			surface.albedo_color = tint.darkened(0.65)
			surface.emission_enabled = true
			surface.emission = tint
			surface.emission_energy_multiplier = 1.10
			surface.roughness = 0.28
		_:
			surface.roughness = 0.70
	_materials[key] = surface
	return surface

func _mesh(parent: Node3D, name: String, shape: Mesh, place: Vector3,
		category: String, tint: Color, detail: String = "body") -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.mesh = shape
	part.position = place
	part.material_override = _mat(category, tint)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	if detail == "face":
		_stats["face_details"] += 1
	elif detail == "hair":
		_stats["hair_sections"] += 1
	elif detail == "uniform":
		_stats["uniform_details"] += 1
	else:
		_stats["body_meshes"] += 1
	return part

func _sphere(parent: Node3D, name: String, place: Vector3, shape: Vector3,
		category: String, tint: Color, detail: String = "body") -> MeshInstance3D:
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 16
	ball.rings = 8
	var part := _mesh(parent, name, ball, place, category, tint, detail)
	part.scale = shape
	return part

func _box(parent: Node3D, name: String, place: Vector3, size: Vector3,
		category: String, tint: Color, detail: String = "body") -> MeshInstance3D:
	var block := BoxMesh.new()
	block.size = size
	return _mesh(parent, name, block, place, category, tint, detail)

func _segment(parent: Node3D, name: String, first: Vector3, second: Vector3,
		thick_start: float, thick_end: float, category: String, tint: Color,
		detail: String = "body") -> MeshInstance3D:
	var tube := CylinderMesh.new()
	tube.bottom_radius = thick_start
	tube.top_radius = thick_end
	tube.height = first.distance_to(second)
	tube.radial_segments = 12
	var mid := (first + second) * 0.5
	var part := _mesh(parent, name, tube, mid, category, tint, detail)
	part.quaternion = Quaternion(Vector3.UP, (second - first).normalized())
	return part

func _loft(name: String, profiles: Array, category: String, tint: Color,
		parent: Node3D, detail: String = "body") -> MeshInstance3D:
	# Curved anatomical volume with an asymmetric but coherent silhouette.
	# Profiles are [height, width, depth, centerZ] in local component space.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	for section in range(profiles.size() - 1):
		for i in range(n):
			var a := TAU * float(i) / float(n)
			var b := TAU * float(i + 1) / float(n)
			var lower: Array = profiles[section]
			var upper: Array = profiles[section + 1]
			var p := Vector3(sin(a) * float(lower[1]), float(lower[0]), cos(a) * float(lower[2]) + float(lower[3]))
			var q := Vector3(sin(b) * float(lower[1]), float(lower[0]), cos(b) * float(lower[2]) + float(lower[3]))
			var r := Vector3(sin(b) * float(upper[1]), float(upper[0]), cos(b) * float(upper[2]) + float(upper[3]))
			var t := Vector3(sin(a) * float(upper[1]), float(upper[0]), cos(a) * float(upper[2]) + float(upper[3]))
			for vertex in [p, q, r, p, r, t]:
				st.set_uv(Vector2(vertex.x * 1.7 + vertex.z, vertex.y * 1.7))
				st.add_vertex(vertex)
	st.generate_normals()
	return _mesh(parent, name, st.commit(), Vector3.ZERO, category, tint, detail)

func _joint(parent: Node3D, name: String, at: Vector3) -> Node3D:
	var item := Node3D.new()
	item.name = name
	item.position = at
	parent.add_child(item)
	_stats["joints"] += 1
	return item

func _build_rig() -> void:
	# Her feet are behind the bar. The venue's built-in counter, not Mara,
	# remains the collidable gameplay service target.
	var legs := _joint(self, "HipsAndLegs", Vector3(0, 0.0, 0.0))
	_sphere(legs, "Waist", Vector3(0.0, 0.89, -0.025),
		Vector3(0.49, 0.31, 0.34), "FABRIC", COAT)
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.20
		_segment(legs, "TrouserThigh", Vector3(x, 0.84, 0.0),
			Vector3(x * 1.05, 0.45, 0.005), 0.13, 0.115,
			"FABRIC", Color("313d44"))
		_segment(legs, "TrouserShin", Vector3(x * 1.05, 0.45, 0.005),
			Vector3(x, 0.095, -0.006), 0.115, 0.083,
			"FABRIC", Color("37434a"))
		_sphere(legs, "RubberSoleWorkBoot", Vector3(x, 0.076, 0.095),
			Vector3(0.25, 0.15, 0.38), "LEATHER", Color("262b31"))
	_torso = _joint(self, "UpperBodyBreathingRig", Vector3(0.0, 1.05, 0.0))
	_loft("TailoredUtilityJacket", [
		[-0.16, 0.24, 0.18, 0.0],
		[0.03, 0.28, 0.20, 0.01],
		[0.36, 0.38, 0.23, 0.0],
		[0.50, 0.33, 0.21, 0.0],
		[0.60, 0.17, 0.14, 0.0]
	], "FABRIC", COAT, _torso)
	_segment(_torso, "CollarNeck", Vector3(0.0, 0.52, 0.0),
		Vector3(0.0, 0.69, 0.0), 0.105, 0.086, "SKIN", BASE_SKIN)
	_head = _joint(_torso, "HeadExpressionRig", Vector3(0.0, 0.76, 0.0))
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.35
		var limb := _joint(_torso,
			"LeftArmCoffeeRig" if side < 0.0 else "RightArmServiceRig",
			Vector3(x, 0.48, -0.012))
		if side < 0.0:
			_left_arm = limb
		else:
			_right_arm = limb
		_sphere(limb, "ShoulderPad", Vector3(0.0, -0.065, 0.0),
			Vector3(0.26, 0.27, 0.27), "FABRIC", COAT)
		_segment(limb, "SewnUpperSleeve", Vector3(0.0, -0.07, 0.0),
			Vector3(side * 0.060, -0.36, 0.10), 0.145, 0.12, "FABRIC", COAT)
		_segment(limb, "RolledSleeveCuff",
			Vector3(side * 0.058, -0.36, 0.10), Vector3(side * 0.056, -0.43, 0.13),
			0.127, 0.124, "FABRIC", COAT_EDGE, "uniform")
		_segment(limb, "ExposedForearm", Vector3(side * 0.056, -0.43, 0.13),
			Vector3(side * 0.018, -0.64, 0.22), 0.103, 0.064, "SKIN", BASE_SKIN)
		_sphere(limb, "ArticulatedHand", Vector3(side * 0.018, -0.67, 0.23),
			Vector3(0.13, 0.16, 0.14), "SKIN", BASE_SKIN)
		_segment(limb, "Thumb", Vector3(side * 0.016, -0.68, 0.27),
			Vector3(side * 0.083, -0.75, 0.305), 0.029, 0.018, "SKIN", BASE_SKIN)
		for digit in range(3):
			var spacing := (float(digit) - 1.0) * 0.036
			_segment(limb, "Finger_%d" % digit,
				Vector3(side * 0.018 + spacing, -0.72, 0.25),
				Vector3(side * 0.015 + spacing, -0.79, 0.29),
				0.022, 0.013, "SKIN", BASE_SKIN)

func _build_uniform() -> void:
	# Layered work apron, draped waistband, metallic fasteners and name card.
	_box(_torso, "InnerCollarTee", Vector3(0.0, 0.46, 0.17),
		Vector3(0.20, 0.15, 0.065), "FABRIC", Color("b2a89e"), "uniform")
	_loft("CrossbackBaristaApron", [
		[-0.22, 0.27, 0.025, 0.23],
		[0.04, 0.27, 0.030, 0.24],
		[0.34, 0.28, 0.038, 0.245],
		[0.47, 0.19, 0.025, 0.22]
	], "LEATHER", APRON, _torso, "uniform")
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.22
		_segment(_torso, "ApronSuspender", Vector3(x, 0.48, 0.16),
			Vector3(x * 1.12, 0.02, 0.244), 0.019, 0.016,
			"BRASS", APRON_SEAM, "uniform")
		_box(_torso, "LinenPocketEdge",
			Vector3(x * 0.54, 0.01, 0.281),
			Vector3(0.18, 0.032, 0.027), "FABRIC", APRON_SEAM, "uniform")
		_sphere(_torso, "ApronRivet", Vector3(x, 0.44, 0.23),
			Vector3(0.034, 0.034, 0.022), "BRASS", COPPER, "uniform")
	_box(_torso, "SatinNameCard", Vector3(-0.17, 0.38, 0.274),
		Vector3(0.28, 0.085, 0.027), "BRASS", COPPER, "uniform")
	_box(_torso, "NameCardInlay", Vector3(-0.17, 0.38, 0.292),
		Vector3(0.23, 0.041, 0.013), "GLOW", GLOW.darkened(0.13), "uniform")
	# Practical coffee thermos worn on her belt.
	_segment(_torso, "BaristaUtilityPen", Vector3(0.32, 0.22, 0.20),
		Vector3(0.32, 0.04, 0.22), 0.018, 0.018,
		"BRASS", Color("8cc1ba"), "uniform")

func _build_face_and_hair() -> void:
	# Sculpted facial hull: jaw narrows below the cheekbones and the forehead
	# flattens. Eyes, eyelids, nostrils, brows and lips are independent geometry.
	_loft("CharacterFaceSculpt", [
		[-0.22, 0.10, 0.095, 0.0],
		[-0.16, 0.145, 0.125, 0.0],
		[-0.055, 0.193, 0.173, 0.007],
		[0.075, 0.202, 0.175, 0.010],
		[0.18, 0.194, 0.155, 0.0],
		[0.245, 0.11, 0.12, -0.004],
		[0.265, 0.02, 0.028, -0.002]
	], "SKIN", BASE_SKIN, _head, "face")
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.108
		_sphere(_head, "Ear", Vector3(float(side) * 0.195, 0.002, -0.005),
			Vector3(0.07, 0.135, 0.064), "SKIN", SHADOW_SKIN, "face")
		_sphere(_head, "LowerEarlobe", Vector3(float(side) * 0.20, -0.055, 0.016),
			Vector3(0.04, 0.043, 0.046), "SKIN", BASE_SKIN, "face")
		# Blink the WHOLE eye (sclera, iris, pupil and reflection) around
		# one anatomical pivot, rather than leaving pupils visible when shut.
		var eye_rig := _joint(_head,
			"LeftEyeBlinkRig" if side < 0.0 else "RightEyeBlinkRig",
			Vector3(x, 0.073, 0.175))
		if side < 0.0:
			_left_eye = eye_rig
		else:
			_right_eye = eye_rig
		_sphere(eye_rig, "Sclera", Vector3(0.0, 0.0, -0.016),
			Vector3(0.093, 0.056, 0.036), "EYE", Color("cbd2c9"), "face")
		_sphere(eye_rig, "Iris", Vector3(-0.008, -0.003, 0.013),
			Vector3(0.038, 0.046, 0.019), "EYE", EYE_IRIS, "face")
		_sphere(eye_rig, "Pupil", Vector3(-0.006, -0.003, 0.024),
			Vector3(0.016, 0.027, 0.011), "EYE", Color("192c34"), "face")
		_sphere(eye_rig, "CornealCatchlight", Vector3(-0.017, 0.015, 0.034),
			Vector3(0.011, 0.012, 0.006), "EYE", Color("fff4dd"), "face")
		_segment(_head, "UpperLid", Vector3(x - 0.048, 0.104, 0.180),
			Vector3(x + 0.046, 0.101, 0.181), 0.012, 0.010,
			"SKIN", SHADOW_SKIN, "face")
		_segment(_head, "Brow", Vector3(x - 0.049, 0.139, 0.163),
			Vector3(x + 0.047, 0.135, 0.162), 0.018, 0.014,
			"HAIR", HAIR, "face")
		for dot in range(2):
			_sphere(_head, "Freckle", Vector3(float(side) * (0.124 + 0.022 * float(dot)),
				-0.015, 0.142 - 0.009 * float(dot)),
				Vector3(0.011, 0.009, 0.008), "SKIN", Color("8e6256"), "face")
	_segment(_head, "NoseBridge", Vector3(0.0, 0.067, 0.174),
		Vector3(0.0, -0.059, 0.206), 0.035, 0.026,
		"SKIN", BASE_SKIN, "face")
	_sphere(_head, "NoseTip", Vector3(0.0, -0.061, 0.218),
		Vector3(0.064, 0.041, 0.079), "SKIN", BASE_SKIN, "face")
	_mouth = _sphere(_head, "Lips", Vector3(0.0, -0.141, 0.145),
		Vector3(0.119, 0.028, 0.027), "SKIN", Color("935e5f"), "face")
	_box(_head, "MouthCornerShadow", Vector3(0.0, -0.151, 0.159),
		Vector3(0.085, 0.008, 0.010), "SKIN", SHADOW_SKIN, "face")
	# Asymmetric undercut with shaped dark hair shell and long swept fringe.
	_loft("StyledHairCrown", [
		[0.109, 0.185, 0.151, -0.028],
		[0.20, 0.21, 0.16, -0.013],
		[0.275, 0.16, 0.135, -0.023],
		[0.317, 0.012, 0.018, -0.015]
	], "HAIR", HAIR, _head, "hair")
	for i in range(7):
		var side_x := -0.16 + float(i) * 0.046
		var length := 0.115 + float(i % 3) * 0.040
		_segment(_head, "SideSweptFringe",
			Vector3(side_x - 0.065, 0.269 - float(i) * 0.008, 0.125),
			Vector3(side_x + 0.025, 0.26 - length, 0.166), 0.035, 0.005,
			"HAIR", HAIR if i % 3 else HAIR_GLAZE, "hair")
	# Long asymmetrical swept side lock and anchored copper hair clip.
	_segment(_head, "LongFaceFramingLock", Vector3(-0.176, 0.203, -0.006),
		Vector3(-0.184, -0.198, 0.006), 0.092, 0.043,
		"HAIR", HAIR, "hair")
	_segment(_head, "CopperHairClip", Vector3(-0.176, 0.181, 0.09),
		Vector3(-0.188, 0.117, 0.135), 0.020, 0.020,
		"BRASS", COPPER, "hair")
	# Functioning-looking earpiece, not an extra decorative local light.
	_sphere(_head, "ServiceCommsEarbud", Vector3(0.226, -0.011, 0.012),
		Vector3(0.038, 0.073, 0.068), "BRASS", COPPER, "hair")
	_sphere(_head, "ServiceStatusLED", Vector3(0.248, -0.001, 0.054),
		Vector3(0.022, 0.027, 0.013), "GLOW", GLOW, "hair")

func _build_service_details() -> void:
	# Contact label remains readable at 2-3 m in the original 3rd-person view.
	var label := Label3D.new()
	label.name = "MaraDialogueMarker"
	label.text = "MARA  /  LANTERN CUP"
	label.font_size = 28
	label.pixel_size = 0.0031
	label.position = Vector3(0.0, 2.40, 0.02)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("d3d8c7")
	label.outline_size = 5
	label.outline_modulate = Color("213340")
	add_child(label)
