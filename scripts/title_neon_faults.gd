extends RefCounted
## Title-only low-frequency faults in the actual neon tubes and practical spill.
## No shared material mutation, flashing overlays, extra light sources or RNG.
const PERIOD = 53.0
const EVENTS = [[9.0, 1.65, 0.56], [31.0, 2.1, 0.70], [44.0, 1.35, 0.48]]
var _surfaces: Array[Dictionary] = []
var _lights: Array[OmniLight3D] = []
var _pavement: MeshInstance3D

static func power_at(seconds: float, index: int) -> float:
	# Smooth single dips separated by seconds of stable light. The second
	# sign has independent timing, avoiding a synchronized whole-frame flash.
	var phase := fposmod(seconds + (19.0 if index == 1 else 0.0), PERIOD)
	var power := 1.0
	for event in EVENTS:
		var t := (phase - float(event[0])) / float(event[1])
		if t >= 0.0 and t <= 1.0:
			power = minf(power, 1.0 - float(event[2]) * pow(sin(PI * t), 2.0))
	return power

func attach(alley: Node3D) -> void:
	_pavement = alley.get_node_or_null("PhotographicAlleyPavement") as MeshInstance3D
	for index in range(2):
		var blade := alley.get_node_or_null("BusinessFrontage/" + ["RepairBlade", "LaundryBlade"][index])
		var spill := alley.get_node_or_null("StreetAtmosphere/" + ["RepairSignSpill", "LaundrySignSpill"][index]) as OmniLight3D
		_lights.append(spill)
		if blade == null:
			continue
		for mesh: MeshInstance3D in blade.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var base := mesh.get_surface_override_material(surface) as StandardMaterial3D
				if base == null or not base.emission_enabled:
					continue
				var local := base.duplicate() as StandardMaterial3D
				_surfaces.append({"mesh": mesh, "surface": surface, "base": base, "local": local, "index": index})
				mesh.set_surface_override_material(surface, local)

func apply(seconds: float, night: float, animate: bool) -> void:
	var power := Vector2.ONE
	if animate:
		power = Vector2(power_at(seconds, 0), power_at(seconds, 1))
	for entry in _surfaces:
		if is_instance_valid(entry["mesh"]):
			var base: StandardMaterial3D = entry["base"]
			var local: StandardMaterial3D = entry["local"]
			local.emission_energy_multiplier = base.emission_energy_multiplier * power[int(entry["index"])]
	for index in range(_lights.size()):
		if is_instance_valid(_lights[index]):
			_lights[index].light_energy = 1.55 * smoothstep(0.30, 0.80, night) * power[index]
	if is_instance_valid(_pavement):
		_pavement.set_instance_shader_parameter("title_neon_power", power)

func detach(night: float) -> void:
	apply(0.0, night, false)
	for entry in _surfaces:
		if is_instance_valid(entry["mesh"]):
			entry["mesh"].set_surface_override_material(entry["surface"], entry["base"])
	_surfaces.clear()
	_lights.clear()
	_pavement = null
