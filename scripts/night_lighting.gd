extends Node3D
## Fixed street fixtures, pooled moving GPU lights (no per-fixture shadows).
## Daytime switches off the pool entirely; dusk ramps neon and light sources up.
const FIXTURE_GRID = 58.0
const MAX_LOCAL_LIGHTS = 8
const MAX_DISTANCE = 75.0
var _fixtures: Array[Dictionary] = []
var _pool: Array[OmniLight3D] = []
var _focus := Vector3.ZERO
var _night := 0.0
var _tick := 0.0

func _ready() -> void:
	for ix in range(-4, 5):
		for iz in range(-4, 5):
			var x := float(ix) * FIXTURE_GRID + 8.9
			var z := float(iz) * FIXTURE_GRID + 8.9
			var color := Color("ffd49a")
			if z < -174.0:
				color = Color("78d4ce")
			elif z >= 174.0:
				color = Color("e7bd8b")
			elif x < -174.0:
				color = Color("d9a679")
			elif x >= 174.0:
				color = Color("9cdda8")
			elif x >= 0.0 and z < 0.0:
				color = Color("84c9f0")
			elif x >= 0.0 and z >= 0.0:
				color = Color("f7a7db")
			elif x < 0.0 and z >= 0.0:
				color = Color("ffc397")
			_fixtures.append({"position": Vector3(x, 6.7, z), "color": color})
	for i in range(MAX_LOCAL_LIGHTS):
		var lamp := OmniLight3D.new()
		lamp.name = "PooledStreetLight_%02d" % i
		lamp.omni_range = 14.5
		lamp.light_energy = 0.0
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		_pool.append(lamp)

func set_focus(at: Vector3) -> void:
	_focus = at

func set_night_factor(value: float) -> void:
	_night = smoothstep(0.42, 0.77, clampf(value, 0.0, 1.0))
	_refresh()

func active_light_count() -> int:
	var count := 0
	for light in _pool:
		if light.visible:
			count += 1
	return count

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.45:
		_tick = 0.0
		_refresh()

func _refresh() -> void:
	if _pool.is_empty():
		return
	if _night < 0.01:
		for lamp in _pool:
			lamp.visible = false
			lamp.light_energy = 0.0
		return
	var closest: Array[Dictionary] = []
	for fixture in _fixtures:
		var point: Vector3 = fixture["position"]
		var distance := Vector2(point.x - _focus.x, point.z - _focus.z).length()
		if distance <= MAX_DISTANCE:
			closest.append({"distance": distance, "position": point, "color": fixture["color"]})
	closest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	for i in range(_pool.size()):
		var lamp := _pool[i]
		var enabled := i < mini(closest.size(), MAX_LOCAL_LIGHTS)
		lamp.visible = enabled
		if enabled:
			lamp.position = closest[i]["position"]
			lamp.light_color = closest[i]["color"]
			lamp.light_energy = 1.55 * _night
		else:
			lamp.light_energy = 0.0
