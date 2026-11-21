extends Node3D
## Night-time practical lights stay anchored to their ACTUAL visible geometry.
## Reuse eight shadow-free OmniLight3D nodes, not hundreds of per-building
## light nodes. The former placement grid had no relationship to the authored
## streetlamp meshes, leaving illuminated "bulbs" with dark pavement.
const WorldPlan = preload("res://scripts/world_plan.gd")
const FIXTURE_GRID = 58.0
const MAX_LOCAL_LIGHTS = 8
const STREET_SLOTS = 4
const MAX_DISTANCE = 75.0
# A Central Exchange walk-in light is borrowed from one of the EXISTING four
# shop slots, never added to the eight-light pool. Its short-radius,
# non-shadowed falloff originates immediately below one of the actual
# imported glTF's two warm recessed ceiling lenses.
const PORTAL_ACTIVATION_METRES = 23.0
const MAX_PORTAL_SLOTS = 2
const PORTAL_RANGE = 6.2
const PORTAL_ENERGY = 1.55
const PORTAL_LENS_LOCAL_Z = 1.08
const PORTAL_LENS_LOCAL_Y = 3.07
const PORTAL_LAMP_OFFSET_Y = -0.16
var _fixtures: Array[Dictionary] = []
var _pool: Array[OmniLight3D] = []
var _focus := Vector3.ZERO
var _night := 0.0
var _tick := 0.0
var _active_street := 0
var _active_shop := 0
var _active_portals := 0

func _ready() -> void:
	# CityDetails._build_intersections() only draws a physical light at
	# even-parity intersections. The light-emitting cap in _lamp() is at
	# pole_origin + (-1.58, 6.76, 0); match it exactly.
	for ix in range(-WorldPlan.GRID_RADIUS, WorldPlan.GRID_RADIUS + 1):
		for iz in range(-WorldPlan.GRID_RADIUS, WorldPlan.GRID_RADIUS + 1):
			if (ix + iz) % 2 != 0:
				continue
			var point := Vector3(float(ix) * FIXTURE_GRID - 9.98,
				6.76, float(iz) * FIXTURE_GRID - 8.6)
			_fixtures.append({
				"position": point, "color": Color("ffd4a0"),
				"kind": "street", "key": "pole_%d_%d" % [ix, iz]
			})
	# The existing city has an emissive retail sign on each normal lot.
	# Illuminate the sidewalk immediately below the actual canopy/sign;
	# do not generate "invisible lights" at landmark-only blocks.
	for ix in range(-WorldPlan.GRID_RADIUS, WorldPlan.GRID_RADIUS):
		for iz in range(-WorldPlan.GRID_RADIUS, WorldPlan.GRID_RADIUS):
			if not WorldPlan.landmark_for_block(ix, iz).is_empty():
				continue
			var center := Vector3((float(ix) + 0.5) * FIXTURE_GRID,
				0.0, (float(iz) + 0.5) * FIXTURE_GRID)
			var color := _shop_temperature(WorldPlan.district_at(center))
			for lot in range(2):
				var x := center.x + (-10.5 if lot == 0 else 10.5)
				_fixtures.append({
					"position": Vector3(x, 3.55,
						center.z - WorldPlan.PUBLIC_FACADE_SETBACK - 1.15),
					"color": color, "kind": "shop",
					"key": "shop_%d_%d_%d" % [ix, iz, lot]
				})
	# Exactly two source-verified, fixed Central Exchange walk-in shops.
	# Both existing photo-PBR glTFs contain a 1.08m-deep warm ceiling lens.
	# Keep all other storefront and civic lighting mapped to the original
	# public street/parcel anchors. No hidden lights in other districts.
	for portal in [
		{"ix": -1, "iz": 0, "lot": 1, "color": Color("ffe0b8")},
		{"ix": 0, "iz": 0, "lot": 0, "color": Color("ffe5c8")}
	]:
		var x := (float(portal["ix"]) + 0.5) * FIXTURE_GRID + (
			-10.5 if int(portal["lot"]) == 0 else 10.5)
		var z := (float(portal["iz"]) + 0.5) * FIXTURE_GRID - (
			WorldPlan.PUBLIC_FACADE_SETBACK) + PORTAL_LENS_LOCAL_Z
		_fixtures.append({
			"position": Vector3(x, 0.15 + PORTAL_LENS_LOCAL_Y + PORTAL_LAMP_OFFSET_Y, z),
			"color": portal["color"], "kind": "portal",
			"key": "portal_%d_%d_%d" % [portal["ix"], portal["iz"], portal["lot"]]
		})
	for i in range(MAX_LOCAL_LIGHTS):
		var lamp := OmniLight3D.new()
		lamp.name = "PooledStreetLight_%02d" % i
		lamp.omni_range = 14.5
		lamp.light_energy = 0.0
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		_pool.append(lamp)

func _shop_temperature(district: String) -> Color:
	match district:
		"VESPER MARKET":
			return Color("ffcca0")
		"BRICKWATER", "WEST DOCKS":
			return Color("ffd7ab")
		"GLASSLINE":
			return Color("b6dbf3")
		"AFTERHOURS":
			return Color("efb8de")
		"NORTH QUAY":
			return Color("aedfd2")
		"HORIZON GARDENS":
			return Color("c8dfb2")
		"SOUTHWORKS":
			return Color("e6c19e")
	return Color("ffd1a4")

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

func get_practical_light_stats() -> Dictionary:
	var poles := 0
	var storefronts := 0
	var portals := 0
	for fixture in _fixtures:
		match str(fixture["kind"]):
			"street":
				poles += 1
			"shop":
				storefronts += 1
			"portal":
				portals += 1
	return {
		"pool_capacity": MAX_LOCAL_LIGHTS,
		"available_poles": poles,
		"available_storefronts": storefronts,
		"available_walk_in_portals": portals,
		"active_poles": _active_street,
		"active_storefronts": _active_shop,
		"active_walk_in_portals": _active_portals,
		"active": active_light_count(),
		"shadow_casting": 0
	}

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.45:
		_tick = 0.0
		_refresh()

func _nearby(kind: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for fixture in _fixtures:
		if str(fixture["kind"]) != kind:
			continue
		var point: Vector3 = fixture["position"]
		var distance := Vector2(point.x - _focus.x, point.z - _focus.z).length()
		if distance <= MAX_DISTANCE:
			candidates.append({
				"distance": distance, "position": point,
				"color": fixture["color"], "key": fixture["key"],
				"kind": fixture["kind"]
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["distance"]), float(b["distance"])):
			return float(a["distance"]) < float(b["distance"])
		return str(a["key"]) < str(b["key"]))
	return candidates

func _refresh() -> void:
	if _pool.is_empty():
		return
	_active_street = 0
	_active_shop = 0
	_active_portals = 0
	if _night < 0.01:
		for lamp in _pool:
			lamp.visible = false
			lamp.light_energy = 0.0
		return
	# Dedicated allocation gives streetlights and shops both a real pool:
	# neither can displace every instance of the other in a dense district.
	var poles := _nearby("street")
	var shops := _nearby("shop")
	var walk_in := _nearby("portal")
	# Each real source lens borrows a pre-existing sign-light slot only while
	# the player is within the protected two-storefront reference block. Two
	# remaining shop slots keep the wider district commercially readable.
	# When the player leaves, all four become ordinary storefront sources.
	var retail_targets: Array[Dictionary] = []
	for entry in walk_in:
		if float(entry["distance"]) > PORTAL_ACTIVATION_METRES:
			continue
		if retail_targets.size() >= MAX_PORTAL_SLOTS:
			break
		retail_targets.append(entry)
	for entry in shops:
		if retail_targets.size() >= MAX_LOCAL_LIGHTS - STREET_SLOTS:
			break
		retail_targets.append(entry)
	for i in range(MAX_LOCAL_LIGHTS):
		var use_pole := i < STREET_SLOTS
		var selection := poles if use_pole else retail_targets
		var index := i if use_pole else i - STREET_SLOTS
		var lamp := _pool[i]
		var enabled := index < selection.size()
		lamp.visible = enabled
		if enabled:
			var fixture: Dictionary = selection[index]
			var in_portal := str(fixture["kind"]) == "portal"
			lamp.position = fixture["position"]
			lamp.light_color = fixture["color"]
			lamp.omni_range = 18.0 if use_pole else (PORTAL_RANGE if in_portal else 11.5)
			lamp.light_energy = (1.8 if use_pole else (
				PORTAL_ENERGY if in_portal else 1.2)) * _night
			if use_pole:
				_active_street += 1
			elif in_portal:
				_active_portals += 1
			else:
				_active_shop += 1
		else:
			lamp.light_energy = 0.0
