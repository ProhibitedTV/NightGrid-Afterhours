extends SceneTree
## Headless composition test for the generated city. Also exercises world startup.
func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("Unable to load main scene")
		quit(1)
		return
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails")
	if city == null:
		push_error("CityDetails was never instantiated")
		quit(1)
		return
	var stats: Dictionary = city.call("get_city_stats")
	if int(stats.get("buildings", 0)) != 72:
		push_error("Expected 72 building shells, got %s" % stats)
		quit(1)
		return
	if int(stats.get("storefronts", 0)) != 72:
		push_error("All building fronts must have signs and shop treatment")
		quit(1)
		return
	if int(stats.get("batched_details", 0)) < 3000:
		push_error("Procedural dressing unexpectedly sparse: %s" % stats)
		quit(1)
		return
	var expected := {
		Vector3(-29, 0, -29): "VESPER MARKET",
		Vector3(29, 0, -29): "GLASSLINE",
		Vector3(-29, 0, 29): "BRICKWATER",
		Vector3(29, 0, 29): "AFTERHOURS"
	}
	for point in expected:
		if city.call("get_district_at", point) != expected[point]:
			push_error("District lookup mismatch at %s" % point)
			quit(1)
			return
	print("CITY_SMOKE PASS: ", stats)
	quit(0)
