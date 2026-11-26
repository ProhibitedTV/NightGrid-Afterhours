extends SceneTree
const Room = preload("res://scripts/arcade_room.gd")
const KeyArt = preload("res://scripts/arcade_key_art.gd")
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
	if not check(room.cabinets.size() == 10, "ten cabinets"):
		return
	for cabinet in room.cabinets:
		var texture: Texture2D = KeyArt.texture(cabinet.game_id)
		var poster := room.get_node_or_null("GamePoster_"+cabinet.game_id+"/Print") as MeshInstance3D
		if not check(texture != null and poster != null and (poster.material_override as StandardMaterial3D).albedo_texture == texture, "poster shares catalog texture"):
			return
		var dims: Vector2 = (poster.mesh as QuadMesh).size
		if not check(dims.x <= 1.001 and dims.y <= 1.301 and absf(dims.aspect()-texture.get_size().aspect()) < .001, "aspect correct bounded poster"):
			return
		var crt := cabinet.get_node("CRTAttract") as MeshInstance3D
		if not check((crt.material_override as ShaderMaterial).get_shader_parameter("art") == texture, "shared CRT texture"):
			return
		var front: Vector3 = cabinet.to_global(Vector3(0,1.1,1.0))
		var back: Vector3 = cabinet.to_global(Vector3(0,1.1,-1.0))
		if not check(room.cabinet_near(front) == cabinet.game_id and room.cabinet_near(back).is_empty(), "front-only interaction " + str(cabinet.game_id)):
			return
		if not check(cabinet.get_node_or_null("MarqueeTitle") != null and cabinet.get_node_or_null("ServiceSticker") != null, "cabinet marquee and service sticker"):
			return
		if cabinet.game_id!="grand_delay":
			if not check(cabinet.get_node_or_null("CoinReturnRecess")!=null and cabinet.get_node_or_null("FreePlayIndicator")!=null and cabinet.get_node_or_null("ControlLegend")!=null,"restored cabinet physical details"):
				return
		var shapes := 0
		for child in cabinet.get_children():
			if child is CollisionShape3D:
				shapes += 1
			if not check(not child is SubViewport, "no idle live viewport"):
				return
		if not check(shapes == 2 and cabinet.get_node_or_null("CRTAttract") != null, "collidable shell and attract screen"):
			return
	var score_plate := room.cabinets[0].get_node("LocalScorePlate") as Label3D
	var progress := room.get_node("LocalProgressSign") as Label3D
	if not check(score_plate.text == "YOUR BEST -----  |  0/3" and progress.text.contains("0/30"),"fresh arcade shows no fabricated score"):
		return
	room.refresh_scores({"grand_delay":1800,"neon_rebound":4100})
	if not check(score_plate.text == "YOUR BEST 01800  |  2/3" and progress.text == "YOUR CIRCUIT 1/8  •  MEDALS 5/30","saved high scores reflected in physical room"):
		return
	if not check((room.cabinets[9].get_node("LocalScorePlate") as Label3D).text == "YOUR BEST 04100  |  3/3","restored cabinet gold plate"):
		return
	room.refresh_scores({})
	if not check(score_plate.text == "YOUR BEST -----  |  0/3" and progress.text.contains("0/30"),"new world clears physical score displays"):
		return
	var deluxe = room.cabinets[0]
	if not check(deluxe.get_node_or_null("DeluxeBacklitMarquee") != null and deluxe.get_node_or_null("MarqueeSpill") is OmniLight3D and deluxe.get_node_or_null("CoinReturnTray") != null, "deluxe cabinet has authored physical detail"):
		return
	var wheel: Node3D = deluxe.get_node("SteeringMount/SteeringWheel")
	var button: Node3D = deluxe.get_node("NitroButton")
	deluxe.set_deluxe_controls(2.0,1.0)
	if not check(is_equal_approx(wheel.rotation.y,.68) and button.position.y < 1.14, "physical wheel and button respond to controls"):
		return
	deluxe.set_deluxe_controls(1.0,0.0)
	if not check(is_zero_approx(wheel.rotation.y) and is_equal_approx(button.position.y,1.14), "physical controls return to neutral"):
		return
	if not check(room.cabinets[1].get_node_or_null("DeluxeBacklitMarquee") == null, "hero details isolated to one cabinet"):
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
	if not check(room.cabinet_near(Vector3(-2.0,1.1,4.5)) == "starline_patrol" and room.cabinet_near(Vector3(2.0,1.1,4.5)) == "neon_rebound", "restored cabinet approach"):
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
