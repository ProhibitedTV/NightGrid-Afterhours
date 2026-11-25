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
	if int(stats.get("buildings", 0)) != 112:
		push_error("Expected 112 authored building shells, got %s" % stats)
		quit(1)
		return
	if int(stats.get("storefronts", 0)) != 112:
		push_error("All procedural building fronts must have signs and shop treatment")
		quit(1)
		return
	if int(stats.get("authored_lots", 0)) != 112:
		push_error("All 112 parcel buildings should come from fixed design manifest: %s" % stats)
		quit(1)
		return
	if int(stats.get("landmarks", 0)) != 8:
		push_error("Authored landmarks missing: %s" % stats)
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
		Vector3(29, 0, 29): "AFTERHOURS",
		Vector3(-29, 0, -203): "NORTH QUAY",
		Vector3(-203, 0, 29): "WEST DOCKS",
		Vector3(203, 0, 29): "HORIZON GARDENS",
		Vector3(29, 0, 203): "SOUTHWORKS"
	}
	for point in expected:
		if city.call("get_district_at", point) != expected[point]:
			push_error("District lookup mismatch at %s" % point)
			quit(1)
			return
	var clock: Node = world.get("day_night")
	clock.set_process(false)
	clock.call("set_hour", 12.0)
	var late_color := Color("d4a1f3")
	var late_emitter: StandardMaterial3D = city.call("_material", late_color, true)
	var late_matte: StandardMaterial3D = city.call("_material", late_color, false)
	var registered: Array = city.get("_emissive_materials")
	if late_emitter.emission_energy_multiplier != 0.0 or not registered.has(late_emitter) or registered.has(late_matte):
		push_error("New streamed material must immediately inherit daytime glow state")
		quit(1)
		return
	clock.call("set_hour", 0.0)
	var updates := int(city.get("_emissive_updates"))
	if not is_equal_approx(late_emitter.emission_energy_multiplier, 2.35):
		push_error("Registered emissive palette failed midnight transition")
		quit(1)
		return
	for i in 12:
		city.call("set_night_factor", 1.0)
	if int(city.get("_emissive_updates")) != updates:
		push_error("Unchanged night plateau rewrites entire city emissive palette")
		quit(1)
		return
	if city.call("_material", late_color, true) != late_emitter:
		push_error("Palette identity must remain stable")
		quit(1)
		return
	var palette: Dictionary = city.get("_palette")
	if palette.has("1c2736_matte"):
		push_error("Legacy raised grime material still allocated")
		quit(1)
		return
	print("CITY_SMOKE PASS: ", stats)
	quit(0)
