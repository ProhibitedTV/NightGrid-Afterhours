extends SceneTree
## Visual AND gameplay acceptance test for Lantern Cup's only authored host.
## No player save slots are modified; the full scene is instantiated privately.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(why: String) -> void:
	push_error("MARA_CHARACTER_SMOKE: " + why)
	quit(1)

func _verify() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("Playable game scene did not load")
		return
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	var venues := world.get_node_or_null("SocialVenues")
	var rooms := world.get_node_or_null("Interiors")
	var session := root.get_node_or_null("GameSession")
	var player: CharacterBody3D = world.get("player")
	if venues == null or rooms == null or player == null or session == null:
		_fail("Main venue, interior, save, or player system is missing")
		return
	var initial_seed: int = int(session.get("world_seed"))
	var exterior: Vector3 = venues.call("venue_position", "lantern_cup")
	player.global_position = exterior
	world.call("_toggle_interior")
	var room: Node3D = rooms.get("_room")
	var mara: Node3D = rooms.call("get_mara_character")
	if mara == null or room.get_node_or_null("LanternCupHero/MaraHero") != mara:
		_fail("Mara must replace the generic mannequin INSIDE her real café")
		return
	if mara.global_position.distance_to(room.to_global(Vector3(0.0, 0.33, -7.12))) > 0.02:
		_fail("Mara is not at the real staffed service counter")
		return
	var counts: Dictionary = rooms.call("get_mara_stats")
	if int(counts.get("face_details", 0)) < 20 or int(counts.get("hair_sections", 0)) < 10:
		_fail("Mara lacks original sculpted facial/hair geometry: %s" % counts)
		return
	if int(counts.get("uniform_details", 0)) < 10 or int(counts.get("joints", 0)) < 5:
		_fail("Barista costume and expressive transform hierarchy incomplete: %s" % counts)
		return
	if int(counts.get("live_lights", -1)) != 0 or int(counts.get("imported_assets", -1)) != 0:
		_fail("Character exceeded its material/light/asset provenance budget")
		return
	var head := mara.get_node_or_null("UpperBodyBreathingRig/HeadExpressionRig") as Node3D
	var left_arm := mara.get_node_or_null("UpperBodyBreathingRig/LeftArmCoffeeRig") as Node3D
	var right_arm := mara.get_node_or_null("UpperBodyBreathingRig/RightArmServiceRig") as Node3D
	if head == null or left_arm == null or right_arm == null:
		_fail("Character skeleton pivots must exist for idle/talk/service")
		return
	var eye_rig := head.get_node_or_null("LeftEyeBlinkRig") as Node3D
	var pupil := head.get_node_or_null("LeftEyeBlinkRig/Pupil")
	if eye_rig == null or pupil == null:
		_fail("Blink rig must include the iris/pupil, not just sclera")
		return
	var until_blink := fposmod(2.24 - fposmod(float(mara.get("_clock")), 4.37), 4.37)
	mara.call("_process", until_blink)
	if eye_rig.scale.y > 0.21:
		_fail("Eye rig must close during a blink")
		return
	mara.call("_process", 0.26)
	if eye_rig.scale.y < 0.9:
		_fail("Mara's eyes must reopen naturally after the blink")
		return
	var plinth := room.get_node_or_null("LanternCupHero/StaffRaisedServicePlinth")
	if plinth == null:
		_fail("Mara must stand on a believable raised service work surface")
		return
	# Concrete fixed context lines: injured player, a police alert, unlocked
	# shift notes and an active contract all change the authored conversation.
	var context := {"hour": 20.0, "health": 34.0, "heat": 1.25,
		"shift_notes": false, "job": "dead_frequency"}
	var intro: String = rooms.call("mara_greeting", context)
	if not intro.contains("hard shift"):
		_fail("Mara's greeting must react to player injury")
		return
	var first: Dictionary = rooms.call("mara_talk", context)
	var second: Dictionary = rooms.call("mara_talk", context)
	var third: Dictionary = rooms.call("mara_talk", context)
	var fourth: Dictionary = rooms.call("mara_talk", context)
	if not str(first["line"]).contains("hard shift") or not str(second["line"]).contains("patrols"):
		_fail("Health/police attention does not change face-to-face conversation")
		return
	if not str(third["line"]).contains("booth") or not str(fourth["line"]).contains("Finish the job"):
		_fail("Narrative branch did not use clue and existing active job")
		return
	var discovered := context.duplicate()
	discovered["shift_notes"] = true
	discovered["job"] = ""
	if not str(mara.call("next_dialogue", discovered)["line"]).contains("hard shift"):
		_fail("Conversation topic did not loop back to first exchange")
		return
	mara.call("next_dialogue", discovered)
	var known_line: Dictionary = mara.call("next_dialogue", discovered)
	if not str(known_line["line"]).contains("found my notes"):
		_fail("Discovery state does not unlock Mara's acknowledgment")
		return
	# The actual venue action UI exposes the third choice with gamepad focus.
	player.global_position = rooms.call("get_counter_point") + Vector3(0.0, 0.0, 2.0)
	world.set("health", 40.0)
	world.set("heat", 1.0)
	world.set("cash", 60)
	world.call("_toggle_interaction")
	var dialogue: PanelContainer = world.get("venue_panel")
	var talk_button: Button = world.get("venue_talk_button")
	if not dialogue.visible or talk_button == null or not talk_button.visible:
		_fail("The old G counter interaction must expose the accessible Talk button")
		return
	if not InputMap.has_action("service_three") or InputMap.action_get_events("service_three").size() < 2:
		_fail("Talk must support number 3 and a controller binding")
		return
	var money_before := int(world.get("cash"))
	var health_before := float(world.get("health"))
	world.call("_venue_action", 3)
	var dialogue_line := str(world.get("mara_dialogue_line"))
	if dialogue_line.is_empty() or int(world.get("cash")) != money_before or absf(float(world.get("health")) - health_before) > 0.001:
		_fail("Talking via the real menu must not change player money or health")
		return
	if not (world.get("venue_label") as Label).text.contains(dialogue_line):
		_fail("Dialogue panel must actually show Mara's current response")
		return
	rooms.call("set_mara_focus", player.global_position + Vector3(1.25, 0.0, 0.0))
	mara.call("_process", 0.19)
	var performance: Dictionary = mara.call("get_performance_state")
	if not bool(performance["focused"]) or not bool(performance["speaking"]):
		_fail("Character must react visibly when dialogue opens")
		return
	mara.call("_process", 0.27)
	if absf(float(mara.call("get_performance_state")["head_yaw"])) < 0.02:
		_fail("Mara's head is not tracking a patron at the counter")
		return
	# Purchase retains original fixed-price gameplay and triggers a sleeve/
	# hand rig gesture. A denied transaction must not animate a new sale.
	world.call("_venue_action", 1)
	if int(world.get("cash")) != 42 or absf(float(world.get("health")) - 60.0) > 0.01:
		_fail("Mara's upgraded model broke original $18 coffee service")
		return
	if not bool(mara.call("get_performance_state")["service_gesture"]):
		_fail("Successful coffee purchase did not animate the serving arm")
		return
	world.call("_close_venue")
	if bool(mara.call("get_performance_state")["focused"]):
		_fail("Mara must return to idle after the menu closes")
		return
	# The original existing collectible clue remains physical, one-time and
	# persistent; Mara's conversation changes after picking it up.
	player.global_position = rooms.call("get_hero_rumor_point")
	world.call("_toggle_interaction")
	if not (world.get("civic_intel") as Array).has("lantern_cup_shift_notes"):
		_fail("Existing booth note ceased to work with Mara in the room")
		return
	# Save while inside. Character can be reconstructed from fixed venue ID,
	# while journal discovery, cash and seed remain part of the normal schema.
	var snap: Dictionary = world.call("_capture_snapshot")
	var record: Dictionary = session.call("make_snapshot", snap)
	if not bool(session.call("is_valid_snapshot", record)):
		_fail("Mara's dialogue or animation broke version-one save validation")
		return
	world.call("_apply_snapshot", record)
	if int(session.get("world_seed")) != initial_seed or int(world.get("cash")) != 42:
		_fail("World state changed after reconstructing Lantern Cup")
		return
	if not (world.get("civic_intel") as Array).has("lantern_cup_shift_notes"):
		_fail("Discovered shift note missing on reload")
		return
	var restored_mara: Node3D = rooms.call("get_mara_character")
	if restored_mara == null or restored_mara == mara or int(rooms.call("get_mara_stats")["face_details"]) < 20:
		_fail("Save restore must recreate Mara instead of serializing live nodes")
		return
	var after_context := {"hour": 9.0, "health": 90.0, "heat": 0.0,
		"shift_notes": true, "job": ""}
	if not str(restored_mara.call("next_dialogue", after_context)["line"]).contains("Welcome"):
		_fail("Fresh encounter dialogue should reset after reconstruction")
		return
	# Leaving releases all character resources. The other cafés retain their
	# generic hosts, original names and service menus.
	player.global_position = rooms.call("get_entry_point")
	world.call("_toggle_interior")
	await process_frame
	if bool(rooms.call("is_inside")) or player.global_position.distance_to(exterior) > 0.30:
		_fail("Mara's geometry prevented return to the same outside door")
		return
	if rooms.call("get_mara_character") != null:
		_fail("Character should not stay resident after streaming out")
		return
	player.global_position = venues.call("venue_position", "helix_espresso")
	world.call("_toggle_interior")
	if rooms.call("get_mara_character") != null or str(rooms.call("active_site_id")) != "helix_espresso":
		_fail("Unique character should not leak into other businesses")
		return
	print("MARA_CHARACTER_SMOKE PASS: ", counts, " / dialogue, gestures, venue economy, save/load")
	quit(0)
