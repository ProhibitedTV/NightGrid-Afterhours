extends SceneTree
## Expanded world: deterministic parcel manifests, visitable city systems and
## save snapshots that preserve inventory, civic errands and existing districts.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("EXPANSION_SMOKE: " + message)
	quit(1)

func _same_layout(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("version", -1)) != int(b.get("version", -2)):
		return false
	var first: Dictionary = a.get("blocks", {})
	var second: Dictionary = b.get("blocks", {})
	if first.size() != second.size():
		return false
	for key in first:
		if not second.has(key):
			return false
		var source: Array = first[key]
		var target: Array = second[key]
		if source.size() != target.size():
			return false
		for index in range(source.size()):
			var before: Dictionary = source[index]
			var after: Dictionary = target[index]
			for field in ["height", "width", "depth", "offset_z"]:
				if absf(float(before.get(field, -1.0)) - float(after.get(field, -2.0))) > 0.0001:
					return false
			for field in ["wall", "material"]:
				if str(before.get(field, "")) != str(after.get(field, "")):
					return false
	return true

func _verify() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Main scene missing")
		return
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var plan = load("res://scripts/world_plan.gd")
	var catalog = load("res://scripts/civic_services.gd")
	var session := root.get_node_or_null("GameSession")
	var services := world.get_node_or_null("CivicServices")
	var city := world.get_node_or_null("CityDetails")
	var rail := world.get_node_or_null("MorrowLine")
	var signals := world.get_node_or_null("TrafficSignals")
	var traffic := world.get_node_or_null("SurfaceTraffic")
	if session == null or services == null or city == null or rail == null or signals == null or traffic == null:
		_fail("City expansion not wired to game scene")
		return
	if plan.GRID_RADIUS != 4 or plan.WORLD_LAYOUT_VERSION != 2 or catalog.SITES.size() != 17:
		_fail("Expected an 8x8 city and 17 authored service addresses")
		return
	var manifest: Dictionary = session.call("get_world_manifest")
	if not plan.valid_manifest(manifest) or (manifest["blocks"] as Dictionary).size() != 56:
		_fail("Persisted layout should contain exactly 56 non-landmark blocks")
		return
	if manifest != city.get("world_manifest"):
		_fail("City build must use the persisted manifest, not reroll the lots")
		return
	var same: Dictionary = plan.build_manifest(1011)
	var same_again: Dictionary = plan.build_manifest(1011)
	var different: Dictionary = plan.build_manifest(1012)
	if same != same_again or same == different:
		_fail("Seeded outer lots must be stable within a game and vary on New Game")
		return
	var core_a: Dictionary = plan.lot_profile(-2, -1, 0, 0)
	var core_b: Dictionary = plan.lot_profile(-2, -1, 0, 0)
	if core_a != core_b:
		_fail("Original authored downtown should remain unchanged")
		return
	var known := {
		Vector3(-29, 0, -203): "NORTH QUAY",
		Vector3(-203, 0, 29): "WEST DOCKS",
		Vector3(203, 0, 29): "HORIZON GARDENS",
		Vector3(29, 0, 203): "SOUTHWORKS"
	}
	for point in known:
		if plan.district_at(point) != known[point]:
			_fail("Wrong outer district at %s" % point)
			return
	var sites_seen := {}
	var kinds := {}
	for site in catalog.SITES:
		var id: String = site["id"]
		if sites_seen.has(id):
			_fail("Duplicate civic site id")
			return
		sites_seen[id] = true
		var ix := int(site["ix"])
		var iz := int(site["iz"])
		if not plan.is_valid_block(ix, iz) or (plan.is_core_block(ix, iz) and id != "police_hq"):
			_fail("Expanded service outside new neighborhoods")
			return
		if not plan.landmark_for_block(ix, iz).is_empty():
			_fail("Services must not overlap protected landmark centers")
			return
		var position: Vector3 = services.call("position_for", id)
		if str(services.call("nearest_site", position).get("id", "")) != id:
			_fail("Player cannot find the fixed entrance to " + id)
			return
		var kind: String = site["kind"]
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	if kinds.size() != 8 or catalog.WORK_ORDERS.size() != 4:
		_fail("Missing essential land uses or logistics jobs")
		return
	if int(signals.call("safe_intersection_count")) != 81:
		_fail("Outer roads lack traffic signal coverage")
		return
	var fleet: Dictionary = traffic.call("get_counts")
	if int(fleet["ambient_cars"]) != 25 or int(fleet["buses"]) != 4 or int(fleet["stops"]) != 16:
		_fail("Expanded public bus/civilian vehicle routes unavailable")
		return
	if int(rail.call("get_counts")["stations"]) != 5:
		_fail("Rail did not reach the added outer neighborhoods")
		return
	services.call("set_hour", 12.0)
	if services.call("is_open", "seawall_pantry", 2.0) or not services.call("is_open", "seawall_pantry", 23.0):
		_fail("Cross-midnight grocery hours incorrect")
		return
	if not services.call("is_open", "freight_control", 2.0):
		_fail("24-hour dock freight dispatch incorrectly closed")
		return
	var player: CharacterBody3D = world.get("player")
	world.set("cash", 500)
	world.set("health", 40.0)
	player.global_position = services.call("position_for", "quay_fresh")
	world.call("_toggle_interaction")
	if str(world.get("civic_selected_id")) != "quay_fresh":
		_fail("G interaction did not open the grocery counter")
		return
	world.call("_venue_action", 1)
	if int(world.get("cash")) != 472 or int(world.get("ration_packs")) != 2:
		_fail("Provision purchase did not debit cash or add inventory")
		return
	world.call("_close_venue")
	world.call("_consume_ration")
	if int(world.get("ration_packs")) != 1 or absf(float(world.get("health")) - 65.0) > 0.01:
		_fail("Usable groceries did not recover player health")
		return
	player.global_position = services.call("position_for", "freight_control")
	world.call("_toggle_civic")
	world.call("_venue_action", 2)
	if str(world.get("civic_job_active")) != "cold_chain":
		_fail("Cargo dispatcher job was not accepted")
		return
	world.call("_close_venue")
	player.global_position = services.call("position_for", "quay_fresh")
	world.call("_toggle_civic")
	world.call("_venue_action", 2)
	if str(world.get("civic_job_active")) != "" or int(world.get("cash")) != 782:
		_fail("Freight contract did not complete and pay its $310 reward")
		return
	var completed: Array = world.get("civic_job_completed")
	if not completed.has("cold_chain"):
		_fail("Completed freight work was not recorded")
		return
	world.call("_close_venue")
	player.global_position = services.call("position_for", "crane_supply")
	var parked: Array = world.get("cars")
	var repairable: CharacterBody3D = parked[0]
	repairable.global_position = player.global_position + Vector3(0.0, 0.0, 7.0)
	repairable.set("condition", 42.0)
	world.call("_toggle_civic")
	world.call("_venue_action", 1)
	if absf(float(repairable.get("condition")) - 100.0) > 0.01 or int(world.get("cash")) != 727:
		_fail("Garage did not charge $55 and restore the parked vehicle")
		return
	world.call("_close_venue")
	player.global_position = services.call("position_for", "harbor_library")
	world.call("_toggle_civic")
	world.call("_venue_action", 1)
	if not (world.get("civic_intel") as Array).has("harbor_library"):
		_fail("Free library clues not recorded")
		return
	world.call("_close_venue")
	player.global_position = services.call("position_for", "union_supply")
	world.call("_toggle_civic")
	world.call("_venue_action", 2)
	if str(world.get("civic_job_active")) != "after_sparks":
		_fail("Next civic work order was not accepted")
		return
	var state: Dictionary = world.call("_capture_snapshot")
	var written: Dictionary = session.call("make_snapshot", state)
	if not session.call("is_valid_snapshot", written):
		_fail("World snapshot invalid after civic gameplay")
		return
	if written.get("world_manifest", {}) != manifest:
		_fail("Save did not include the exact generated city layout")
		return
	var old: Dictionary = written.duplicate(true)
	for field in ["world_manifest", "civic_job_active", "civic_job_completed", "civic_intel", "ration_packs"]:
		old.erase(field)
	if not session.call("is_valid_snapshot", old):
		_fail("Older version-one save slots are no longer accepted")
		return
	var test_path := "user://tests/expansion_smoke_slot.json"
	if not session.call("save_snapshot_to", state, test_path):
		_fail("Could not write isolated expansion test save")
		return
	var restored: Dictionary = session.call("read_snapshot_from", test_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if not _same_layout(restored.get("world_manifest", {}), manifest):
		_fail("Exact parcels changed during on-disk JSON serialization")
		return
	world.set("cash", 0)
	world.set("ration_packs", 0)
	world.set("civic_job_active", "")
	world.call("_apply_snapshot", restored)
	if int(world.get("cash")) != 727 or int(world.get("ration_packs")) != 1:
		_fail("Money or grocery inventory did not survive reload")
		return
	if str(world.get("civic_job_active")) != "after_sparks" or not (world.get("civic_job_completed") as Array).has("cold_chain"):
		_fail("Civic deliveries did not survive reload")
		return
	if not (world.get("civic_intel") as Array).has("harbor_library"):
		_fail("Archive clues did not survive reload")
		return
	if float((world.get("cars") as Array)[0].get("condition")) < 99.0:
		_fail("Garage repair condition did not survive reload")
		return
	var map: Dictionary = world.call("get_map_state")
	if (map.get("services", []) as Array).size() != 17 or not bool(map.get("civic_quest_active", false)):
		_fail("Full-sized minimap lacks service or civic quest markers")
		return
	print("EXPANSION_SMOKE PASS: districts=8 blocks=64 landmarks=8 profiles=112 civic=17 fleet=",fleet," seed=",session.get("world_seed"))
	quit(0)
