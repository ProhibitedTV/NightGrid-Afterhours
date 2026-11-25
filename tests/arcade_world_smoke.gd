extends SceneTree
const Room = preload("res://scripts/interior_system.gd")
const Venue = preload("res://scripts/venue_system.gd")
const Plan = preload("res://scripts/world_plan.gd")
func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("ARCADE_WORLD_SMOKE: " + label)
		quit(1)
	return ok

func _verify() -> void:
	var venues := Venue.new()
	var rooms := Room.new()
	root.add_child(venues)
	root.add_child(rooms)
	await process_frame
	var site := venues.venue_by_id("insert_coin")
	var outside := venues.venue_position("insert_coin")
	if not check(not site.is_empty() and Plan.landmark_for_block(1,2).is_empty() and venues.nearest_venue(outside)["id"] == "insert_coin", "fixed non-landmark address"):
		return
	if not check(venues.is_open("insert_coin",14.0) and venues.is_open("insert_coin",2.9) and not venues.is_open("insert_coin",3.0), "midnight hours"):
		return
	var entry := rooms.enter(site,"VENUE",outside)
	if not check(rooms.arcade_cabinet_near(entry).is_empty() and rooms.arcade_cabinet_near(Room.ORIGIN + Vector3(-4.6,1.1,-2.2)) == "grand_delay", "entry and cabinet reachability"):
		return
	var snap := rooms.snapshot()
	if not check(rooms.leave() == outside and rooms.arcade_cabinet_near(entry).is_empty(), "leave clears activity"):
		return
	await process_frame
	if not check(rooms.restore(snap,site) and rooms.active_site_id() == "insert_coin", "legacy room save restore"):
		return
	var screen := preload("res://scenes/arcade_pilot.tscn").instantiate()
	if not check(screen.configure_cabinet("patch_day",{"patch_day":150}) and screen.selection == 2 and screen.best["patch_day"] == 150, "locked title and session highs"):
		return
	screen.free()
	rooms.queue_free()
	venues.queue_free()
	await process_frame
	print("ARCADE_WORLD_SMOKE: PASS")
	quit(0)
