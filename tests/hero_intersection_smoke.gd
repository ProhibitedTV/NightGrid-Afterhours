extends SceneTree
## Integration contract for the authored CENTRAL EXCHANGE junction.
## Reuses the real world and original traffic-light controller.
func _initialize() -> void:
	call_deferred("_check")

func _fail(why: String) -> void:
	push_error("HERO_INTERSECTION_SMOKE: " + why)
	quit(1)

func _check() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("Playable game scene missing")
		return
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	var hero := world.get_node_or_null("CentralExchangeHero") as Node3D
	var city := world.get_node_or_null("CityDetails") as Node3D
	var signals := world.get_node_or_null("TrafficSignals") as Node3D
	var clock := world.get_node_or_null("DayNight") as Node
	if hero == null or city == null or signals == null or clock == null:
		_fail("Central Exchange or existing city/signal/clock systems not installed")
		return
	if hero.position != Vector3.ZERO:
		_fail("Central Exchange must retain permanent city-grid origin")
		return
	var stats: Dictionary = hero.call("get_visual_stats")
	if int(stats.get("crossings", -1)) != 4 or int(stats.get("paint_wear_marks", -1)) != 216:
		_fail("Hero crossing weathering is incomplete: %s" % stats)
		return
	if int(stats.get("curb_ramps", -1)) != 8 or int(stats.get("storm_drains", -1)) != 8:
		_fail("Accessible slope geometry and real drainage design missing: %s" % stats)
		return
	if int(stats.get("repair_patches", -1)) != 3 or int(stats.get("reflective_puddles", -1)) != 2:
		_fail("Local rain and repair surfaces not authored: %s" % stats)
		return
	if int(stats.get("mounted_signal_heads", -1)) != 2 or int(stats.get("crossing_signs", 0)) < 4:
		_fail("Real existing traffic heads must be mounted beside readable crossing signage")
		return
	if int(stats.get("batched_instances", 0)) < 260 or int(stats.get("night_lights", -1)) != 1:
		_fail("Missing instanced detail or bounded practical night fixture")
		return
	for n in range(8):
		var found := false
		for child in hero.get_children():
			if child.name.ends_with("_%02d" % n) and child.name.begins_with("AccessibleRamp"):
				found = child is MeshInstance3D and child.mesh is ArrayMesh
				break
		if not found:
			_fail("Missing a tessellated, non-colliding sidewalk approach: %d" % n)
			return
	for child in hero.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			_fail("Decorative hero treatment must not obstruct traffic or player collision")
			return
	# Confirm no independent fake traffic heads: the real controller remains
	# responsible for every change of yellow/all-red and the 81 intersections.
	if int(signals.call("safe_intersection_count")) != 81:
		_fail("Traffic controller signal map changed")
		return
	for second in range(72):
		signals.set("elapsed", float(second))
		if signals.call("phase_at", 0, 0, "NS") == "GREEN" and signals.call("phase_at", 0, 0, "EW") == "GREEN":
			_fail("Conflicting central exchange signal phases")
			return
	clock.call("set_hour", 12.0)
	if float(hero.call("get_night_light_energy")) > 0.001:
		_fail("Central Exchange practical lamps must be off in daylight")
		return
	clock.call("set_hour", 0.0)
	var night_energy: float = hero.call("get_night_light_energy")
	if night_energy < 0.7 or night_energy > 1.0:
		_fail("Central Exchange nighttime glow must follow actual clock")
		return
	# Validate structural stability, including when world seed/clock changes.
	var saved: Dictionary = world.call("_capture_snapshot")
	world.call("_apply_snapshot", saved)
	if hero.call("get_visual_stats") != stats:
		_fail("Hero landmark geometry count changed across snapshot restoration")
		return
	print("HERO_INTERSECTION_SMOKE PASS: ", stats, " / light=", night_energy)
	quit(0)
