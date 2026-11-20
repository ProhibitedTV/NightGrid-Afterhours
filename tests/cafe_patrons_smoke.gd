extends SceneTree
## Last pre-playtest gate: real world café guest cast + player interaction.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(why: String) -> void:
	push_error("CAFE_PATRONS_SMOKE: " + why)
	quit(1)

func _verify() -> void:
	var game: PackedScene = load("res://scenes/main.tscn")
	if game == null:
		_fail("No playable Godot scene")
		return
	var world: Node3D = game.instantiate()
	root.add_child(world)
	await process_frame
	var rooms := world.get_node_or_null("Interiors")
	var venues := world.get_node_or_null("SocialVenues")
	var session := root.get_node_or_null("GameSession")
	var player: CharacterBody3D = world.get("player")
	if rooms == null or venues == null or player == null or session == null:
		_fail("Live room, venues, session or player was not instantiated")
		return
	var original_seed: int = int(session.get("world_seed"))
	var outside: Vector3 = venues.call("venue_position", "lantern_cup")
	player.global_position = outside
	world.call("_toggle_interior")
	if str(rooms.call("active_site_id")) != "lantern_cup":
		_fail("Cannot enter Lantern Cup from canonical sidewalk")
		return
	var cast: Array = rooms.call("get_patron_manifest")
	var counts: Dictionary = rooms.call("get_hero_metrics")
	if cast.size() != 5 or int(counts.get("patrons", -1)) != 5:
		_fail("Expected five café regulars, not a citywide crowd")
		return
	if int(counts.get("patron_meshes", 0)) < 105 or int(counts.get("patron_meshes", 9999)) > 175:
		_fail("Patron geometry exceeds bounded quality/performance budget: %s" % counts)
		return
	if int(counts.get("patron_lights", -1)) != 0 or int(counts.get("patron_collision_objects", -1)) != 0:
		_fail("NPCs added unexpected runtime lighting or invisible obstacles")
		return
	var ids := {}
	var activities := {}
	for entry in cast:
		var ident := str(entry["id"])
		if ids.has(ident):
			_fail("Two NPCs were assigned the same stable identity")
			return
		ids[ident] = true
		activities[str(entry["activity"])] = true
		var anchor: Vector3 = entry["anchor"]
		if absf(anchor.x) < 5.45 or absf(anchor.x) > 6.5 or anchor.z < -4.0 or anchor.z > 4.2:
			_fail("Customer entered the central walk axis or exited the booth envelope")
			return
		if not bool(entry["seated"]):
			_fail("This small cast must occupy their existing banquettes")
			return
	if activities.size() < 4:
		_fail("All five customers animate the same recycled movement")
		return
	var room: Node3D = rooms.get("_room")
	var hero := room.get_node_or_null("LanternCupHero") as Node3D
	if hero == null or hero.get_node_or_null("Patron_tamsin") == null:
		_fail("Customer art is not owned by the actual café interior")
		return
	var guest := hero.get_node_or_null("Patron_rin") as Node3D
	if guest == null:
		_fail("Rail mechanic regular is not rendered")
		return
	var state_before: Dictionary = guest.call("get_animation_state")
	guest.call("_process", 1.0)
	var state_after: Dictionary = guest.call("get_animation_state")
	if str(state_after["activity"]) != "SIP" or float(state_after["cup_raised"]) == float(state_before["cup_raised"]):
		_fail("Seated coffee-drinking guest did not animate")
		return
	var left_eye := guest.get_node_or_null("BreathingTorso/LookHead/LeftEyeBlink") as Node3D
	var right_eye := guest.get_node_or_null("BreathingTorso/LookHead/RightEyeBlink") as Node3D
	if left_eye == null or right_eye == null:
		_fail("Guest character requires both eye pivots")
		return
	# Probe actual player-reachable spot *in front of*, not inside, the sofa.
	var conversation_pos := room.global_position + Vector3(-4.60, 1.18, 0.25)
	player.global_position = conversation_pos
	var nearby: Dictionary = rooms.call("patron_near", player.global_position)
	if str(nearby.get("id", "")) != "tamsin":
		_fail("Tamsin cannot be approached from a collision-free spot")
		return
	var cash_before := 71
	world.set("cash", cash_before)
	world.set("health", 68.0)
	world.set("venue_job_active", "")
	var contacts: Array = world.get("civic_intel")
	var count_before := contacts.size()
	world.call("_toggle_interaction")
	if not str(world.get("notification")).contains("Tamsin") or not str(world.get("notification")).contains("warehouse"):
		_fail("G did not surface actual customer dialog in the HUD")
		return
	if int(world.get("cash")) != cash_before or absf(float(world.get("health")) - 68.0) > 0.01:
		_fail("Talking to patrons incorrectly affected venue economy")
		return
	if (world.get("civic_intel") as Array).size() != count_before:
		_fail("Repeatable gossip must not create fake journal quests or rewards")
		return
	if (world.get("venue_panel") as PanelContainer).visible:
		_fail("Patron conversation must not steal Mara's counter UI")
		return
	# Original one-time booth clue still overrides normal customer chatter.
	player.global_position = rooms.call("get_hero_rumor_point")
	world.call("_toggle_interaction")
	if not (world.get("civic_intel") as Array).has("lantern_cup_shift_notes"):
		_fail("The existing Mara note has become unreachable")
		return
	# Save inside, re-instantiate only the room; seeded cast IDs and anchors
	# are identical, dialogue does not generate unpersisted quest state.
	var previous: Dictionary = world.call("_capture_snapshot")
	var packed: Dictionary = session.call("make_snapshot", previous)
	if not bool(session.call("is_valid_snapshot", packed)):
		_fail("Café with customers broke original save schema")
		return
	world.call("_apply_snapshot", packed)
	if int(session.get("world_seed")) != original_seed or int(world.get("cash")) != cash_before:
		_fail("Load mutated saved seed or player money")
		return
	if not (world.get("civic_intel") as Array).has("lantern_cup_shift_notes"):
		_fail("Mara's original persistent clue was lost")
		return
	if rooms.call("get_patron_manifest") != cast:
		_fail("Café crowd identity, anchor and activity changed on reload")
		return
	if rooms.call("get_hero_metrics") != counts:
		_fail("Art budgets changed after indoor save/restore")
		return
	player.global_position = rooms.call("get_entry_point")
	world.call("_toggle_interior")
	await process_frame
	if bool(rooms.call("is_inside")) or player.global_position.distance_to(outside) > 0.30:
		_fail("Patrons prevented leaving through the H door")
		return
	if not (rooms.call("get_patron_manifest") as Array).is_empty():
		_fail("Patrons were not freed with their room")
		return
	if int(rooms.call("get_metrics")["loaded_rooms"]) != 0:
		_fail("Room leaked after leaving café")
		return
	player.global_position = venues.call("venue_position", "helix_espresso")
	world.call("_toggle_interior")
	if str(rooms.call("active_site_id")) != "helix_espresso":
		_fail("Other café routes changed")
		return
	if not (rooms.call("get_patron_manifest") as Array).is_empty():
		_fail("Lantern Cup patrons leaked into other interiors")
		return
	print("CAFE_PATRONS_SMOKE PASS: ", counts,
		" / cast stable, G gossip, note, economy, save/load, cleanup")
	quit(0)
