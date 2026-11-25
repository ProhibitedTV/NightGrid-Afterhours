extends SceneTree
const Room = preload("res://scripts/arcade_room.gd")
func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("ARCADE_ROOM_SMOKE: " + label)
		quit(1)
	return ok

func _verify() -> void:
	var room := Room.new()
	root.add_child(room)
	await process_frame
	if not check(room.cabinets.size() == 8, "eight cabinets"):
		return
	for cabinet in room.cabinets:
		var front: Vector3 = cabinet.to_global(Vector3(0,1.1,1.0))
		var back: Vector3 = cabinet.to_global(Vector3(0,1.1,-1.0))
		if not check(room.cabinet_near(front) == cabinet.game_id and room.cabinet_near(back).is_empty(), "front-only interaction " + str(cabinet.game_id)):
			return
		if not check(cabinet.get_node_or_null("MarqueeTitle") != null and cabinet.get_node_or_null("ServiceSticker") != null, "cabinet marquee and service sticker"):
			return
		var shapes := 0
		for child in cabinet.get_children():
			if child is CollisionShape3D:
				shapes += 1
			if not check(not child is SubViewport, "no idle live viewport"):
				return
		if not check(shapes == 2 and cabinet.get_node_or_null("CRTAttract") != null, "collidable shell and attract screen"):
			return
	if not check(room.cabinet_near(Vector3(0,1.1,5.8)).is_empty(), "entry aisle clear"):
		return
	var local := Vector3(-2.8,1.05,-.6)
	if not check(room.regular_near(local)["name"] == "Ev" and room.regular_near(Vector3(0,1.1,5.8)).is_empty(), "regular proximity and clear entry"):
		return
	var first_line := room.talk_regular(local)
	var second_line := room.talk_regular(local)
	if not check(first_line["line"] != second_line["line"], "regular has rotating dialogue"):
		return
	for i in range(3):
		room.talk_regular(local)
	if not check(room.talk_regular(local) == first_line, "regular dialogue wraps"):
		return
	var archive := room.get_node_or_null("GameCultureArchive")
	if not check(archive != null and archive.EXHIBITS.size() == 10, "ten archive exhibits"):
		return
	if not check(archive.get_node_or_null("PublisherAwards") != null and archive.get_node_or_null("CommunityAward") != null, "physical satire and community awards"):
		return
	var seen := {}
	for exhibit in archive.EXHIBITS:
		var point: Vector3 = archive.to_global(exhibit["approach"])
		var found: Dictionary = room.exhibit_near(point)
		if not check(found.get("id","") == exhibit["id"] and not seen.has(exhibit["id"]) and room.cabinet_near(point).is_empty() and room.regular_near(point).is_empty(), "distinct reachable archive display " + str(exhibit["id"])):
			return
		seen[exhibit["id"]] = true
		if not check(archive.get_node_or_null(str(exhibit["id"])+"/Illustration") != null, "exhibit has artwork"):
			return
	if not check(room.exhibit_near(Vector3(0,1.1,5.8)).is_empty(), "entry not consumed by archive"):
		return
	var first := room.rook_line()
	for i in range(Room.ROOK_LINES.size()-1):
		room.rook_line()
	if not check(room.rook_line() == first, "bounded dialogue rotation"):
		return
	room.queue_free()
	await process_frame
	print("ARCADE_ROOM_SMOKE: PASS")
	quit(0)
