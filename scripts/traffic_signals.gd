extends Node3D
## Two-phase right-hand-traffic grid signal plan, with clearance intervals.
## Each node has coordinated offsets but no conflicting simultaneous green.
const CELL = 58.0
const GREEN_TIME = 30.0
const YELLOW_TIME = 4.0
const ALL_RED_TIME = 2.0
const CYCLE_TIME = 2.0 * (GREEN_TIME + YELLOW_TIME + ALL_RED_TIME)
const MAST_OFFSET = 9.5
const LANE_OFFSET = 3.25
const ARM_Y = 6.9
const HEAD_Y = 6.28
const StreamProfile = preload("res://scripts/streaming_profile.gd")
var elapsed := 0.0
var _heads: Array[Dictionary] = []
var _visual_tick := 0.0
var _lamps: Dictionary = {}
var _steel := StandardMaterial3D.new()
var _casing := BoxMesh.new()
var _lens := CylinderMesh.new()
var _mounts := MultiMesh.new()
var _mount_transforms: Array[Transform3D] = []

func _ready() -> void:
	_steel.albedo_color = Color("566773")
	_steel.metallic = 0.68
	_steel.roughness = 0.46
	_casing.size = Vector3(0.46, 1.10, 0.29)
	_lens.top_radius = 0.12
	_lens.bottom_radius = 0.12
	_lens.height = 0.06
	_lens.radial_segments = 12
	for color_name in ["RED", "YELLOW", "GREEN", "OFF"]:
		var material := StandardMaterial3D.new()
		material.albedo_color = {
			"RED": Color("f45a64"), "YELLOW": Color("ffc668"),
			"GREEN": Color("65e6b4"), "OFF": Color("263140")
		}[color_name]
		material.emission_enabled = color_name != "OFF"
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 1.9
		_lamps[color_name] = material
	for ix in range(-4, 5):
		for iz in range(-4, 5):
			# Central Exchange already owns a separately authored signal assembly.
			if ix == 0 and iz == 0:
				continue
			for side in [-1.0, 1.0]:
				_make_mast(ix, iz, side)
	var tube := BoxMesh.new()
	_mounts.transform_format = MultiMesh.TRANSFORM_3D
	_mounts.mesh = tube
	_mounts.instance_count = _mount_transforms.size()
	for index in range(_mount_transforms.size()):
		_mounts.set_instance_transform(index, _mount_transforms[index])
	_mount_transforms.clear()
	var supports := MultiMeshInstance3D.new()
	supports.name = "SignalMastsAndArms"
	supports.multimesh = _mounts
	supports.material_override = _steel
	add_child(supports)
	_refresh()

func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, CYCLE_TIME)
	_visual_tick += delta
	if _visual_tick >= 0.20:
		_visual_tick = 0.0
		var started := StreamProfile.begin()
		_refresh()
		StreamProfile.accumulate(started, "signal_visual_refresh")

func phase_at(ix: int, iz: int, axis: String) -> String:
	# Approximate corridor offsets; both axes use the same local controller clock.
	var phase := fposmod(elapsed + float(ix + iz + 6) * 2.4, CYCLE_TIME)
	if axis == "NS":
		if phase < GREEN_TIME:
			return "GREEN"
		if phase < GREEN_TIME + YELLOW_TIME:
			return "YELLOW"
		return "RED"
	if phase < GREEN_TIME + YELLOW_TIME + ALL_RED_TIME:
		return "RED"
	if phase < GREEN_TIME * 2.0 + YELLOW_TIME + ALL_RED_TIME:
		return "GREEN"
	if phase < GREEN_TIME * 2.0 + YELLOW_TIME * 2.0 + ALL_RED_TIME:
		return "YELLOW"
	return "RED"

func approach_speed_cap(at: Vector3, direction: Vector3, speed_cap: float) -> float:
	# Stop bar ~11m from intersection center. Once committed past that line,
	# the vehicle clears the intersection even when the signal changes.
	var along_x := absf(direction.x) > absf(direction.z)
	var coord: float = at.x if along_x else at.z
	var travel: float = direction.x if along_x else direction.z
	if absf(travel) < 0.75:
		return speed_cap
	var next_line := ceilf((coord + 8.0) / CELL) * CELL if travel > 0.0 else floorf((coord - 8.0) / CELL) * CELL
	if next_line < -232.0 or next_line > 232.0:
		return speed_cap
	var distance := absf(next_line - coord)
	if distance <= 8.0 or distance > 33.0:
		return speed_cap
	var ix: int = roundi(next_line / CELL) if along_x else roundi(at.x / CELL)
	var iz: int = roundi(at.z / CELL) if along_x else roundi(next_line / CELL)
	var axis := "EW" if along_x else "NS"
	if phase_at(ix, iz, axis) != "GREEN":
		return minf(speed_cap, maxf(0.0, (distance - 11.0) * 0.86))
	return speed_cap

func safe_intersection_count() -> int:
	return 81

func _make_mast(ix: int, iz: int, side: float) -> void:
	var junction := Vector3(ix * CELL, 0.0, iz * CELL)
	var at := junction + Vector3(side * MAST_OFFSET, 0.0, side * MAST_OFFSET)
	var mast := StaticBody3D.new()
	mast.name = "SignalMast_%d_%d_%d" % [ix, iz, int(side)]
	mast.position = at
	add_child(mast)
	var ns := junction + Vector3(-side * LANE_OFFSET, HEAD_Y, side * MAST_OFFSET)
	var ew := junction + Vector3(side * MAST_OFFSET, HEAD_Y, side * LANE_OFFSET)
	var top := at + Vector3.UP * ARM_Y
	for center in [ns, ew]:
		var arm_end := Vector3(center.x, ARM_Y, center.z)
		var span: Vector3 = (top - arm_end).abs()
		_install_mast_member(mast, (top + arm_end) * 0.5, span + Vector3(0.16, 0.21, 0.16))
		_install_mast_member(mast, arm_end - Vector3.UP * 0.09, Vector3(0.12, 0.28, 0.12))
	_install_mast_member(mast, at + Vector3.UP * 0.25, Vector3(0.44, 0.22, 0.44))
	_install_mast_member(mast, at + Vector3.UP * 3.51, Vector3(0.27, ARM_Y - 0.12, 0.27))
	_make_head(mast, ix, iz, "NS", ns - at, Vector3(0.0, 0.0, -side))
	_make_head(mast, ix, iz, "EW", ew - at, Vector3(-side, 0.0, 0.0))

func _install_mast_member(mast: StaticBody3D, at: Vector3, dimensions: Vector3) -> void:
	_mount_transforms.append(Transform3D(Basis.from_scale(dimensions), at))
	_mast_collider(mast, at - mast.position, dimensions)

func _mast_collider(mast: StaticBody3D, local_at: Vector3, dimensions: Vector3, turn: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collider := CollisionShape3D.new()
	collider.position = local_at
	collider.rotation.y = turn
	collider.shape = shape
	mast.add_child(collider)

func _make_head(mast: StaticBody3D, ix: int, iz: int, axis: String,
		at: Vector3, facing: Vector3) -> void:
	var node := Node3D.new()
	node.name = axis
	node.position = at
	node.rotation.y = atan2(facing.x, facing.z)
	mast.add_child(node)
	var casing := MeshInstance3D.new()
	casing.mesh = _casing
	casing.material_override = _lamps["OFF"]
	node.add_child(casing)
	_mast_collider(mast, at, _casing.size, node.rotation.y)
	var bulbs := {}
	for color_name in ["RED", "YELLOW", "GREEN"]:
		var bulb := MeshInstance3D.new()
		bulb.mesh = _lens
		bulb.rotation.x = PI * 0.5
		bulb.position = Vector3(0.0, {"RED": 0.31, "YELLOW": 0.0, "GREEN": -0.31}[color_name], 0.16)
		bulb.material_override = _lamps["OFF"]
		node.add_child(bulb)
		bulbs[color_name] = bulb
	_heads.append({"ix": ix, "iz": iz, "axis": axis, "bulbs": bulbs, "state": ""})

func _refresh() -> void:
	for head in _heads:
		var state := phase_at(int(head["ix"]), int(head["iz"]), str(head["axis"]))
		if state == head["state"]:
			continue
		head["state"] = state
		var bulbs: Dictionary = head["bulbs"]
		for color_name in bulbs:
			(bulbs[color_name] as MeshInstance3D).material_override = _lamps[color_name if color_name == state else "OFF"]
