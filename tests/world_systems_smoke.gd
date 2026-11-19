extends SceneTree
## Verifies authored anchors, useful botanicals, and day/night continuity.
func _initialize() -> void:
	call_deferred("_check")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _check() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("World scene is missing")
		return
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails")
	var foliage := world.get_node_or_null("CityFlora")
	var clock := world.get_node_or_null("DayNight")
	if city == null or foliage == null or clock == null:
		_fail("One of the city/flora/clock world subsystems is missing")
		return
	var stats: Dictionary = foliage.call("get_stats")
	if int(stats.get("street_trees", 0)) != 128:
		_fail("Expected 128 district-assigned street trees: %s" % stats)
		return
	if int(stats.get("landmark_trees", 0)) < 20:
		_fail("Landmarks lack authored tree planting: %s" % stats)
		return
	if int(stats.get("flowers", 0)) < 30 or int(stats.get("shrubs", 0)) < 20:
		_fail("District flora is missing: %s" % stats)
		return
	var plan = load("res://scripts/world_plan.gd")
	var anchors := {
		Vector2i(-2, -2): "LANTERN COURT",
		Vector2i(0, -2): "HELIX TERMINAL",
		Vector2i(-2, 0): "FOUNDRY COMMONS",
		Vector2i(1, 1): "SABLE SQUARE",
		Vector2i(-1, -4): "NORTH QUAY EXCHANGE",
		Vector2i(-4, 0): "PIER NINE DEPOT",
		Vector2i(3, 0): "HORIZON COMMONS",
		Vector2i(0, 3): "SOUTHWORKS HALL"
	}
	for block in anchors:
		if plan.landmark_for_block(block.x, block.y) != anchors[block]:
			_fail("Landmark map was changed at %s" % block)
			return
	clock.call("set_hour", 0.0)
	var midnight: float = clock.call("daylight_amount")
	if midnight > 0.01 or clock.call("clock_string") != "00:00":
		_fail("Midnight lighting or clock format incorrect")
		return
	clock.call("set_hour", 12.0)
	var noon: float = clock.call("daylight_amount")
	if noon < 0.95:
		_fail("Daylight did not reach noon brightness")
		return
	clock.call("set_hour", 19.0)
	var twilight: float = clock.call("daylight_amount")
	if twilight <= midnight or twilight >= noon:
		_fail("Dusk should transition between night and noon")
		return
	print("WORLD_SYSTEMS PASS: ", stats, " / landmarks: ", anchors.size())
	quit(0)
