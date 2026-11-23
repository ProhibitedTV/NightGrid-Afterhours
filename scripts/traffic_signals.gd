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
const COLORS = ["RED", "YELLOW", "GREEN"]
var elapsed := 0.0
var _active_lens_groups: Dictionary = {}
var _render_tiles: Dictionary = {}
var _phase_states: Dictionary = {}
var _visual_tick := 0.0
var _lamps: Dictionary = {}
var _steel := StandardMaterial3D.new()
var _casing := BoxMesh.new()
var _lens := CylinderMesh.new()

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
	_install_signal_visuals()
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
	# Keep each cluster within a single junction for frustum and shadow culling.
	var tile := Vector2i(ix, iz)
	if not _render_tiles.has(tile):
		_render_tiles[tile] = {"supports": [], "casings": [], "lenses": {}}
	var batch: Dictionary = _render_tiles[tile]
	var ns := junction + Vector3(-side * LANE_OFFSET, HEAD_Y, side * MAST_OFFSET)
	var ew := junction + Vector3(side * MAST_OFFSET, HEAD_Y, side * LANE_OFFSET)
	var top := at + Vector3.UP * ARM_Y
	for center in [ns, ew]:
		var arm_end := Vector3(center.x, ARM_Y, center.z)
		var span: Vector3 = (top - arm_end).abs()
		_install_mast_member(mast, batch["supports"], (top + arm_end) * 0.5, span + Vector3(0.16, 0.21, 0.16))
		_install_mast_member(mast, batch["supports"], arm_end - Vector3.UP * 0.09, Vector3(0.12, 0.28, 0.12))
	_install_mast_member(mast, batch["supports"], at + Vector3.UP * 0.25, Vector3(0.44, 0.22, 0.44))
	_install_mast_member(mast, batch["supports"], at + Vector3.UP * 3.51, Vector3(0.27, ARM_Y - 0.12, 0.27))
	_make_head(mast, batch, ix + iz, "NS", ns - at, Vector3(0.0, 0.0, -side))
	_make_head(mast, batch, ix + iz, "EW", ew - at, Vector3(-side, 0.0, 0.0))

func _install_mast_member(mast: StaticBody3D, transforms: Array, at: Vector3, dimensions: Vector3) -> void:
	transforms.append(Transform3D(Basis.from_scale(dimensions), at))
	_mast_collider(mast, at - mast.position, dimensions)

func _mast_collider(mast: StaticBody3D, local_at: Vector3, dimensions: Vector3, turn: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collider := CollisionShape3D.new()
	collider.position = local_at
	collider.rotation.y = turn
	collider.shape = shape
	mast.add_child(collider)

func _make_head(mast: StaticBody3D, batch: Dictionary, offset_key: int, axis: String,
		at: Vector3, facing: Vector3) -> void:
	var node := Node3D.new()
	node.name = axis
	node.position = at
	node.rotation.y = atan2(facing.x, facing.z)
	mast.add_child(node)
	var pose := mast.transform * node.transform
	batch["casings"].append(pose)
	_mast_collider(mast, at, _casing.size, node.rotation.y)
	var phase_key := Vector2i(offset_key, 0 if axis == "NS" else 1)
	if not batch["lenses"].has(phase_key):
		batch["lenses"][phase_key] = [[], [], []]
	var lens_rotation := Basis(Vector3.RIGHT, PI * 0.5)
	for index in range(COLORS.size()):
		batch["lenses"][phase_key][index].append(
			pose * Transform3D(lens_rotation, Vector3(0.0, 0.31 * (1 - index), 0.16)))

func _install_signal_visuals() -> void:
	var tube := BoxMesh.new()
	for tile in _render_tiles:
		var batch: Dictionary = _render_tiles[tile]
		var sector := Node3D.new()
		sector.name = "SignalVisualTile_%d_%d" % [tile.x, tile.y]
		add_child(sector)
		_instance_batch(sector, tube, batch["supports"], _steel)
		_instance_batch(sector, _casing, batch["casings"], _lamps["OFF"])
		for phase_key in batch["lenses"]:
			if not _active_lens_groups.has(phase_key):
				_active_lens_groups[phase_key] = [[], [], []]
			for index in range(COLORS.size()):
				var bulbs := _instance_batch(sector, _lens, batch["lenses"][phase_key][index], _lamps["OFF"])
				_active_lens_groups[phase_key][index].append(bulbs)
	_render_tiles.clear()

func _instance_batch(parent: Node3D, mesh: Mesh, transforms: Array, material: Material) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multimesh
	batch.material_override = material
	parent.add_child(batch)
	return batch

func _refresh() -> void:
	for key: Vector2i in _active_lens_groups:
		var state := phase_at(key.x, 0, "NS" if key.y == 0 else "EW")
		var previous: String = _phase_states.get(key, "")
		if state == previous:
			continue
		_phase_states[key] = state
		for index in range(COLORS.size()):
			var color: String = COLORS[index]
			if color != state and color != previous:
				continue
			var material: Material = _lamps[color if color == state else "OFF"]
			for batch: MultiMeshInstance3D in _active_lens_groups[key][index]:
				batch.material_override = material
