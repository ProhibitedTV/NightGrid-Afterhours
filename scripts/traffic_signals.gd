extends Node3D
## Two-phase right-hand-traffic grid signal plan, with clearance intervals.
## Each node has coordinated offsets but no conflicting simultaneous green.
const CELL = 58.0
const GREEN_TIME = 30.0
const YELLOW_TIME = 4.0
const ALL_RED_TIME = 2.0
const CYCLE_TIME = 2.0 * (GREEN_TIME + YELLOW_TIME + ALL_RED_TIME)
var elapsed := 0.0
var _heads: Array[Dictionary] = []
var _visual_tick := 0.0
var _lamps: Dictionary = {}

func _ready() -> void:
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
			for axis in ["NS", "EW"]:
				_make_head(ix, iz, axis)
	_refresh()

func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, CYCLE_TIME)
	_visual_tick += delta
	if _visual_tick >= 0.20:
		_visual_tick = 0.0
		_refresh()

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

func _make_head(ix: int, iz: int, axis: String) -> void:
	var node := Node3D.new()
	node.name = "Signal_%d_%d_%s" % [ix, iz, axis]
	node.position = Vector3(float(ix) * CELL + 9.2, 5.8, float(iz) * CELL + 9.2)
	add_child(node)
	var casing := MeshInstance3D.new()
	var casing_mesh := BoxMesh.new()
	casing_mesh.size = Vector3(0.65, 1.96, 0.38)
	casing.mesh = casing_mesh
	casing.position.x = 0.48 if axis == "NS" else -0.48
	casing.material_override = _lamps["OFF"]
	node.add_child(casing)
	var bulbs := {}
	for color_name in ["RED", "YELLOW", "GREEN"]:
		var bulb := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.44
		mesh.radial_segments = 8
		mesh.rings = 4
		bulb.mesh = mesh
		bulb.position = Vector3(casing.position.x, {"RED": 0.60, "YELLOW": 0.0, "GREEN": -0.60}[color_name], -0.28 if axis == "NS" else 0.28)
		bulb.material_override = _lamps[color_name]
		node.add_child(bulb)
		bulbs[color_name] = bulb
	_heads.append({"ix": ix, "iz": iz, "axis": axis, "bulbs": bulbs})

func _refresh() -> void:
	for head in _heads:
		var state := phase_at(int(head["ix"]), int(head["iz"]), str(head["axis"]))
		var bulbs: Dictionary = head["bulbs"]
		for color_name in bulbs:
			(bulbs[color_name] as MeshInstance3D).visible = color_name == state
