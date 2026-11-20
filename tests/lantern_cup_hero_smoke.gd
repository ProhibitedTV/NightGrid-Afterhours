extends SceneTree
## Isolated gameplay test for the actual Lantern Cup shop, not a static gallery.
func _initialize() -> void:
	call_deferred("_check")

func _fail(why: String) -> void:
	push_error("LANTERN_CUP_HERO_SMOKE: " + why)
	quit(1)

func _check() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("Missing runnable game scene")
		return
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	var venues := world.get_node_or_null("SocialVenues")
	var rooms := world.get_node_or_null("Interiors")
	var session := root.get_node_or_null("GameSession")
	var player: CharacterBody3D = world.get("player")
	if venues == null or rooms == null or session == null or player == null:
		_fail("Existing real venues, interior system, session, player missing")
		return
	var site: Dictionary = venues.call("venue_by_id", "lantern_cup")
	if str(site.get("name", "")) != "LANTERN CUP" or str(site.get("host", "")) != "Mara":
		_fail("Hero café replaced canonical location or contact")
		return
	if not bool(venues.call("is_open", "lantern_cup", 19.25)):
		_fail("Existing business hours unexpectedly changed")
		return
	var streetfront := venues.get_node_or_null("lantern_cup/LanternCupStreetfront")
	if streetfront == null or streetfront.get_node_or_null("TranslucentStreetWindow") == null:
		_fail("Real Vesper Market café facade lacks its own glazed architecture")
		return
	if bool(venues.call("is_open", "lantern_cup", 23.0)):
		_fail("Venue hours unexpectedly extended past closing")
		return
	var exterior: Vector3 = venues.call("venue_position", "lantern_cup")
	var initial_seed: int = session.get("world_seed")
	var generic_club: Dictionary = venues.call("venue_by_id", "static_room")
	if generic_club.is_empty():
		_fail("Other venue catalog entries changed")
		return
	player.global_position = exterior
	world.call("_toggle_interior")
	if not bool(rooms.call("is_inside")) or str(rooms.call("active_site_id")) != "lantern_cup":
		_fail("Player cannot enter Lantern Cup through original H door")
		return
	var room: Node3D = rooms.get("_room")
	var hero := room.get_node_or_null("LanternCupHero")
	if hero == null:
		_fail("Flagship café interior is not present inside the entered room")
		return
	var counts: Dictionary = rooms.call("get_hero_metrics")
	if int(counts.get("booths", 0)) != 6 or int(counts.get("seats", 0)) != 12:
		_fail("Café requires six constructed upholstered booths: %s" % counts)
		return
	if int(counts.get("espresso_groups", 0)) != 2 or int(counts.get("menu_panels", 0)) != 3:
		_fail("Service bar must have two full brewing heads and three menus")
		return
	if int(counts.get("pendants", 0)) != 12 or int(counts.get("glass_panels", 0)) < 7:
		_fail("Architectural lighting and glazed café enclosure missing")
		return
	if int(counts.get("collidable_furniture", 0)) < 8 or int(counts.get("tables", 0)) < 8:
		_fail("Café booths and tables must have physical room-scale geometry")
		return
	if int(counts.get("original_audio_sources", 0)) != 1 or int(counts.get("steam_wisps", 0)) != 3:
		_fail("Espresso machine ambience and animated steam missing")
		return
	if int(counts.get("lights", 0)) != 2:
		_fail("Bounded additional café practical light budget exceeded")
		return
	if hero.get_node_or_null("OriginalBaristaSteamPump") == null or room.get_node_or_null("OriginalAtmosphere") == null:
		_fail("Two independent original café sound beds are not active-room owned")
		return
	hero.call("_process", 1.0)
	var first_wisp := hero.get_node_or_null("AnimatedBrewSteam_00") as MeshInstance3D
	if first_wisp == null or first_wisp.position.y <= 2.39:
		_fail("Coffee machine steam should be animated during a visit")
		return
	var recorded: Array = world.get("civic_intel")
	var before_count := recorded.size()
	player.global_position = rooms.call("get_hero_rumor_point")
	world.call("_toggle_interaction")
	var after_clue: Array = world.get("civic_intel")
	if after_clue.size() != before_count + 1 or not after_clue.has("lantern_cup_shift_notes"):
		_fail("Mara's booth shift note must enter the existing saved journal")
		return
	world.call("_toggle_interaction")
	if (world.get("civic_intel") as Array).size() != before_count + 1:
		_fail("Hero clue must not be farmable on repeated inspection")
		return
	# The café still sells services at the existing counter and uses real cash.
	player.global_position = rooms.call("get_counter_point") + Vector3(0.0, 0.0, 2.2)
	world.set("cash", 40)
	world.set("health", 63.0)
	world.call("_toggle_interaction")
	if str(world.get("venue_selected_id")) != "lantern_cup":
		_fail("Original G counter interaction is broken by new geometry")
		return
	world.call("_venue_action", 1)
	if int(world.get("cash")) != 22 or absf(float(world.get("health")) - 83.0) > 0.01:
		_fail("Coffee purchase failed to use canonical price/healing")
		return
	world.call("_close_venue")
	var snapshot: Dictionary = world.call("_capture_snapshot")
	var packed: Dictionary = session.call("make_snapshot", snapshot)
	if not bool(session.call("is_valid_snapshot", packed)):
		_fail("Saved hero café interior is not supported by version-one snapshot")
		return
	if str(packed.get("interior", {}).get("id", "")) != "lantern_cup":
		_fail("Café identity missing from saved room metadata")
		return
	world.call("_apply_snapshot", packed)
	if not bool(rooms.call("is_inside")) or str(rooms.call("active_site_id")) != "lantern_cup":
		_fail("Saving inside the new café failed to restore the venue")
		return
	if not (world.get("civic_intel") as Array).has("lantern_cup_shift_notes"):
		_fail("Mara's discovered shift note did not survive save/load")
		return
	if int(world.get("cash")) != 22 or int(session.get("world_seed")) != initial_seed:
		_fail("Visual upgrade changed cash or immutable city seed")
		return
	if (rooms.get("_room") as Node3D).get_node_or_null("LanternCupHero") == null:
		_fail("Save re-entry did not reconstruct exact flagship café geometry")
		return
	# H exit must return to the exact original sidewalk, freeing the whole room.
	player.global_position = rooms.call("get_entry_point")
	world.call("_toggle_interior")
	await process_frame
	if bool(rooms.call("is_inside")) or player.global_position.distance_to(exterior) > 0.3:
		_fail("Original street return path is broken")
		return
	if int(rooms.call("get_metrics")["loaded_rooms"]) != 0:
		_fail("Café geometry/audio was not freed when leaving")
		return
	# The same scene routing must keep other cafés on the generic archetype.
	player.global_position = venues.call("venue_position", "helix_espresso")
	world.call("_toggle_interior")
	if str(rooms.call("active_site_id")) != "helix_espresso":
		_fail("Other cafés' fixed entrances changed")
		return
	if (rooms.get("_room") as Node3D).get_node_or_null("LanternCupHero") != null:
		_fail("Hero café incorrectly leaked into a different venue")
		return
	print("LANTERN_CUP_HERO_SMOKE PASS: ", counts, " / saved intel & purchase valid")
	quit(0)
