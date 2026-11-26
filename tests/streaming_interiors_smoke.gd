extends SceneTree
## Checks actual on-demand loading/unloading, deterministic re-generation,
## navigable physical interior rooms, counter gameplay and indoor save/load.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("STREAM_INTERIORS_SMOKE: " + message)
	quit(1)

func _block_shape_summary(block: Node3D) -> String:
	var positions: PackedStringArray = []
	var solids := 0
	var instanced := 0
	for node in block.get_children():
		if node is StaticBody3D:
			solids += 1
			var at: Vector3 = node.position
			positions.append("%.3f,%.3f,%.3f" % [at.x, at.y, at.z])
		elif node is MultiMeshInstance3D:
			instanced += node.multimesh.instance_count
	return "%d/%d/%s" % [solids, instanced, "|".join(positions)]

func _verify() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Main scene failed to load")
		return
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails")
	var rooms := world.get_node_or_null("Interiors")
	var services := world.get_node_or_null("CivicServices")
	var venues := world.get_node_or_null("SocialVenues")
	var player: CharacterBody3D = world.get("player")
	var session := root.get_node_or_null("GameSession")
	if city == null or rooms == null or services == null or venues == null or session == null:
		_fail("Streaming or interior world services not attached")
		return
	var initial: Dictionary = city.call("get_streaming_stats")
	if int(initial["loaded_blocks"]) > 25 or int(initial["loaded_blocks"]) < 16:
		_fail("Expected 5x5 downtown streaming window, not the full city: %s" % initial)
		return
	if int(initial["total_blocks"]) != 64 or int(initial["loaded_buildings"]) >= 111:
		_fail("The new streaming radius still constructs the entire city")
		return
	var stable_key := Vector2i(-2, -2)
	var old_chunk: Node3D = city.get("_loaded")[stable_key]
	var original_shape := _block_shape_summary(old_chunk)
	if original_shape.is_empty():
		_fail("Chunk had no distinct geometry")
		return
	# Move the real player as well: the live world updates the streaming focus
	# every frame and would otherwise correctly restore the downtown ring.
	player.global_position = Vector3(209.0, 1.15, 209.0)
	city.call("set_focus", player.global_position)
	await process_frame
	var distant: Dictionary = city.call("get_streaming_stats")
	if (city.get("_loaded") as Dictionary).has(stable_key):
		_fail("Remote downtown block was not unloaded")
		return
	if not (city.get("_loaded") as Dictionary).has(Vector2i(3, 3)):
		_fail("Far district block did not stream in")
		return
	if int(distant["unloads"]) == 0 or int(distant["loaded_blocks"]) >= 64:
		_fail("Walking away should actually free geometry: %s" % distant)
		return
	player.global_position = Vector3(0.0, 1.15, 6.0)
	city.call("set_focus", player.global_position)
	await process_frame
	var new_chunk: Node3D = city.get("_loaded")[stable_key]
	if original_shape != _block_shape_summary(new_chunk):
		_fail("Revisiting a district rerolled its building or decorative geometry")
		return
	if int(city.call("get_city_stats")["authored_lots"]) != 111:
		_fail("Streaming changed the consolidated 111-building layout contract")
		return
	# Populate enough cash for a local purchase, then enter the North Quay grocer.
	world.set("cash", 240)
	var grocery: Vector3 = services.call("position_for", "quay_fresh")
	player.global_position = grocery
	city.call("set_focus", grocery)
	world.call("_toggle_interior")
	if not bool(rooms.call("is_inside")):
		_fail("H did not enter the grocery")
		return
	if str(rooms.call("active_site_id")) != "quay_fresh" or str(rooms.call("active_site_group")) != "CIVIC":
		_fail("Interior lost its stable public-site identity")
		return
	if int(rooms.call("get_metrics")["loaded_rooms"]) != 1:
		_fail("Exactly one interior room should be active")
		return
	var floor_collisions := 0
	var active_room: Node3D = rooms.get("_room")
	for mesh in active_room.get_children():
		if mesh is StaticBody3D:
			floor_collisions += 1
	if floor_collisions < 12:
		_fail("Indoor scene lacks floors, walls and physical furniture")
		return
	# The normal outside-of-city bounds check must not respawn the indoor player.
	world.call("_process", 0.016)
	if not bool(rooms.call("is_inside")):
		_fail("Indoor world position triggered the outdoor respawn boundary")
		return
	# The contact is at a real interior counter, not instantly available at entry.
	world.call("_toggle_interaction")
	if (world.get("venue_panel") as PanelContainer).visible:
		_fail("Counter interaction incorrectly reaches across the entire room")
		return
	player.global_position = rooms.call("get_counter_point") + Vector3(0.0, 0.0, 2.5)
	world.call("_toggle_interaction")
	if str(world.get("civic_selected_id")) != "quay_fresh":
		_fail("G cannot interact at the indoor grocery counter")
		return
	world.call("_venue_action", 1)
	if int(world.get("cash")) != 212 or int(world.get("ration_packs")) != 2:
		_fail("Indoor grocery service does not use existing money/inventory")
		return
	world.call("_close_venue")
	# Save and reload *while indoors*. Location should restore inside the same
	# named store and world seed; exiting returns to the right street address.
	var snapshot: Dictionary = world.call("_capture_snapshot")
	var record: Dictionary = session.call("make_snapshot", snapshot)
	if not session.call("is_valid_snapshot", record):
		_fail("Indoor v1 snapshot failed schema validation")
		return
	if str(record["interior"]["id"]) != "quay_fresh":
		_fail("Indoor save omitted the correct venue ID")
		return
	var legacy: Dictionary = record.duplicate(true)
	legacy.erase("interior")
	if not session.call("is_valid_snapshot", legacy):
		_fail("Older game saves without indoor state stopped validating")
		return
	var invalid: Dictionary = record.duplicate(true)
	invalid["interior"] = {"id":"quay_fresh","group":"INVALID","outside":[]}
	if session.call("is_valid_snapshot", invalid):
		_fail("Malformed interior saves must be rejected")
		return
	var save_path := "user://tests/streaming_interiors.json"
	if not session.call("save_snapshot_to", snapshot, save_path):
		_fail("Cannot write indoor save slot to disk")
		return
	var restored: Dictionary = session.call("read_snapshot_from", save_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if restored.is_empty() or str(restored.get("interior", {}).get("id", "")) != "quay_fresh":
		_fail("Disk round-trip lost active interior location")
		return
	world.call("_apply_snapshot", restored)
	if not bool(rooms.call("is_inside")) or str(rooms.call("active_site_id")) != "quay_fresh":
		_fail("Loading a save from inside a business did not re-create its room")
		return
	if int(world.get("ration_packs")) != 2 or int(world.get("cash")) != 212:
		_fail("Inventory/currency lost in an indoor save restore")
		return
	player.global_position = rooms.call("get_entry_point")
	world.call("_toggle_interior")
	if bool(rooms.call("is_inside")) or player.global_position.distance_to(grocery) > 0.3:
		_fail("H exit did not return to the exact stored street address")
		return
	if int(rooms.call("get_metrics")["loaded_rooms"]) != 0:
		_fail("Interior objects were not released on leaving")
		return
	# Original social venues share the same door logic, but a different room.
	var club: Vector3 = venues.call("venue_position", "static_room")
	player.global_position = club
	world.call("_toggle_interior")
	if not bool(rooms.call("is_inside")) or str(rooms.call("active_site_group")) != "VENUE":
		_fail("Nightclubs are not enterable by their permanent ID")
		return
	var nightclub_name: String = rooms.get("_room").name
	if nightclub_name != "Interior_static_room":
		_fail("Wrong interior prototype loaded for the nightclub")
		return
	var map: Dictionary = world.call("get_map_state")
	if not bool(map.get("indoors", false)) or Vector2(club.x, club.z).distance_to(map["player"]) > 0.1:
		_fail("Minimap must keep the player at their actual public street address indoors")
		return
	player.global_position = rooms.call("get_entry_point")
	world.call("_toggle_interior")
	await process_frame
	print("STREAM_INTERIORS_SMOKE PASS: streamed=", initial,
		" / unloaded=", distant["unloads"], " / recreations=", rooms.call("get_metrics"),
		" / saved_seed=", session.get("world_seed"))
	quit(0)
