extends SceneTree
## Real city A/B screenshot regression: light pool stays at physical poles
## and actual storefront signs, never draws invisible fixture poles, and never
## exceeds the established eight unshadowed OmniLights.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("PRACTICAL_LIGHT_SMOKE: " + reason)
	quit(1)

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable NightGrid world not available")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var lamps: Node3D = world.get_node_or_null("NightLighting")
	var clock: Node = world.get_node_or_null("DayNight")
	if lamps == null or clock == null:
		_fail("Lighting or time controller missing")
		return
	var fixtures: Array = lamps.get("_fixtures")
	var pool: Array = lamps.get("_pool")
	if pool.size() != 8 or fixtures.size() < 100:
		_fail("Expected exactly eight reusable lights and independently placed civic fixtures")
		return
	var physical_lamp_matches := 0
	var actual_sign_matches := 0
	for fixture in fixtures:
		var pos: Vector3 = fixture["position"]
		if str(fixture["kind"]) == "street":
			var found := false
			for ix in range(-WorldPlan.GRID_RADIUS, WorldPlan.GRID_RADIUS + 1):
				for iz in range(-WorldPlan.GRID_RADIUS, WorldPlan.GRID_RADIUS + 1):
					if (ix + iz) % 2 != 0:
						continue
					var pole_head := Vector3(float(ix) * 58.0 - 9.98,
						6.76, float(iz) * 58.0 - 8.6)
					if pole_head.distance_to(pos) < 0.001:
						found = true
						break
				if found:
					break
			if not found:
				_fail("Street light is detached from the real emissive pole cap: " + str(pos))
				return
			physical_lamp_matches += 1
		elif str(fixture["kind"]) == "shop":
			var matched := false
			for ix in range(-WorldPlan.GRID_RADIUS, WorldPlan.GRID_RADIUS):
				for iz in range(-WorldPlan.GRID_RADIUS, WorldPlan.GRID_RADIUS):
					if not WorldPlan.landmark_for_block(ix, iz).is_empty():
						continue
					var center := Vector3((float(ix) + 0.5) * 58.0,
						0.0, (float(iz) + 0.5) * 58.0)
					for lot in range(2):
						var actual_sign := Vector3(center.x + (-10.5 if lot == 0 else 10.5),
							3.55, center.z - WorldPlan.PUBLIC_FACADE_SETBACK - 1.15)
						if actual_sign.distance_to(pos) < 0.001:
							matched = true
							break
					if matched:
						break
				if matched:
					break
			if not matched:
				_fail("Storefront light does not match existing saved lot geometry: " + str(pos))
				return
			actual_sign_matches += 1
		else:
			_fail("Untracked lighting kind: " + str(fixture["kind"]))
			return
	if physical_lamp_matches < 25 or actual_sign_matches < 80:
		_fail("Full real-fixture and storefront coverage is missing")
		return
	lamps.call("set_focus", Vector3(-29.0, 0.0, -29.0))
	clock.call("set_hour", 12.0)
	if int(lamps.call("active_light_count")) != 0:
		_fail("Pooled lights must be off during the day")
		return
	clock.call("set_hour", 0.0)
	var stats: Dictionary = lamps.call("get_practical_light_stats")
	if int(stats["active_poles"]) < 1 or int(stats["active_storefronts"]) < 1 or int(stats["active"]) > 8:
		_fail("Night scene needs both real lamp pools without exceeding budget: " + str(stats))
		return
	for light in pool:
		if light.visible:
			if light.shadow_enabled or light.light_energy <= 0.0 or light.omni_range > 18.1:
				_fail("Practical lights added excessive GPU shadow or range cost")
				return
			var anchored := false
			for fixture in fixtures:
				if (fixture["position"] as Vector3).distance_to(light.position) < 0.001:
					anchored = true
					break
			if not anchored:
				_fail("Enabled light floats away from all visible street/shop sources")
				return
	lamps.call("set_focus", Vector3(203.0, 0.0, 203.0))
	lamps.call("set_night_factor", 1.0)
	var relocated: Dictionary = lamps.call("get_practical_light_stats")
	if int(relocated["active"]) < 2 or int(relocated["active"]) > 8:
		_fail("Lighting did not follow the real streamed district")
		return
	clock.call("set_hour", 12.0)
	if int(lamps.call("active_light_count")) != 0:
		_fail("Moving light pool failed to release GPU cost at noon")
		return
	print("PRACTICAL_LIGHT_SMOKE PASS: exact pole heads, live shop signage, eight-light budget, day/night and streaming")
	quit(0)
