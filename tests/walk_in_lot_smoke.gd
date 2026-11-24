extends SceneTree
const Lot = preload("res://scripts/walk_in_lot.gd")
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("WALK_IN_LOT: "+label)
		quit(1)
	return ok
func _verify() -> void:
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var city := world.get_node("CityDetails")
	var player: CharacterBody3D = world.get("player")
	player.set_physics_process(false)
	var block := Vector2i(3,1)
	city.call("_run_build_stage",block)
	var chunk: Node3D = city.get("_staging")[block]["node"]
	var lot := chunk.get_node("WalkInLot_0") as StaticBody3D
	var entry := lot.to_global(Vector3(0,1.15,-1.5))
	player.global_position = entry
	player.velocity = Vector3.ZERO
	await physics_frame
	var door: AnimatableBody3D = lot.get("door")
	for i in 40:
		player.velocity = Vector3(0,0,5)
		player.move_and_slide()
		await physics_frame
	if not check(not lot.call("contains",player.global_position),"closed door physically blocks entry"):
		return
	player.global_position = entry
	player.velocity = Vector3.ZERO
	if not check(door.call("request_toggle"),"real door toggle"):
		return
	for i in 48:
		await physics_frame
	if not check(float(door.call("openness"))>.95,"door opens without teleport"):
		return
	for i in 90:
		player.velocity = Vector3(0,0,5)
		player.move_and_slide()
		await physics_frame
	if not check(lot.call("contains",player.global_position) and player.global_position.z>entry.z+4.0,"real player walks through stage-zero opening"):
		return
	# Walk the center corridor to a side room and return using the actual
	# doorway. The test never sets a new player position for this traversal.
	for i in 25:
		player.velocity = Vector3(0,0,5)
		player.move_and_slide()
		await physics_frame
	if not check(absf(lot.to_local(player.global_position).z-Lot.SIDE_PASSAGE_CENTER)<.55,"aligned with internal passage"):
		return
	for i in 40:
		player.velocity = Vector3(5,0,0)
		player.move_and_slide()
		await physics_frame
	if not check(lot.call("room_at",player.global_position)=="east_room","walked continuously into a second room"):
		return
	for i in 40:
		player.velocity = Vector3(-5,0,0)
		player.move_and_slide()
		await physics_frame
	if not check(lot.call("room_at",player.global_position)=="corridor","returned through internal passage"):
		return
	# At the west passage, cross to the physical ramp and climb it with
	# the same CharacterBody3D collision and floor snap as normal gameplay.
	for i in 39:
		player.velocity = Vector3(-5,0,0)
		player.move_and_slide()
		await physics_frame
	if not check(lot.call("room_at",player.global_position)=="west_room","west room connects to ramp"):
		return
	for i in 180:
		player.velocity = Vector3(0,-1,4)
		player.move_and_slide()
		await physics_frame
		if lot.to_local(player.global_position).z>Lot.RAMP_END+.65:
			break
	if not check(lot.to_local(player.global_position).y>Lot.ROOM_HEIGHT+.7 and lot.call("room_at",player.global_position)=="upper_floor","physical climb reaches upper landing"):
		return
	for i in 49:
		player.velocity = Vector3(4,-1,0)
		player.move_and_slide()
		await physics_frame
	if not check(lot.call("room_at",player.global_position)=="upper_floor" and absf(lot.to_local(player.global_position).x)<1.0,"upper landing opens onto second storey"):
		return
	var upper_at := player.global_position
	city.call("set_focus",upper_at)
	city.call("update_walk_in_light",upper_at)
	var light := lot.get_node("NearInteriorLight") as OmniLight3D
	if not check(light.position.y>Lot.ROOM_HEIGHT,"same light follows player to upper level"):
		return
	var upper_save: Dictionary = world.call("_capture_snapshot")
	world.call("_apply_snapshot",upper_save)
	if not check(player.global_position.distance_to(upper_at)<.1 and lot.call("room_at",player.global_position)=="upper_floor","upper level save restores exact physical elevation"):
		return
	for i in 49:
		player.velocity = Vector3(-4,-1,0)
		player.move_and_slide()
		await physics_frame
	for i in 180:
		player.velocity = Vector3(0,-2,-4)
		player.move_and_slide()
		await physics_frame
		if lot.to_local(player.global_position).z<Lot.SIDE_PASSAGE_CENTER+.12:
			break
	if not check(lot.to_local(player.global_position).y<1.5,"continuous descent returns to ground floor"):
		return
	city.call("update_walk_in_light",player.global_position)
	if not check(light.position.y<Lot.ROOM_HEIGHT,"light returns to ground level"):
		return
	for i in 39:
		player.velocity = Vector3(5,0,0)
		player.move_and_slide()
		await physics_frame
	if not check(lot.call("room_at",player.global_position)=="corridor","return through west passage"):
		return
	for i in 150:
		player.velocity = Vector3(0,0,5)
		player.move_and_slide()
		await physics_frame
	if not check(lot.to_local(player.global_position).z < Lot.ROOM_DEPTH,"rear mass blocks player"):
		return
	city.call("set_focus",entry)
	if not check(city.get("_loaded")[block] == chunk and lot.call("contains",player.global_position),"decorative completion preserves occupied shell"):
		return
	city.call("update_walk_in_light",player.global_position)
	if not check(lot.get_node_or_null("NearInteriorLight") != null and lot.get_node("NearInteriorLight").visible,"nearby room receives budgeted light"):
		return
	city.call("update_walk_in_light",Vector3.INF)
	if not check(not lot.get_node("NearInteriorLight").visible,"departed room light disabled"):
		return
	var record: Dictionary = world.call("_capture_snapshot")
	if not check(record.get("interior",{}).is_empty(),"physical room uses ordinary world save, not remote interior"):
		return
	var inside := player.global_position
	world.call("_apply_snapshot",record)
	if not check(player.global_position.distance_to(inside)<.1,"physical room save preserves world coordinates"):
		return
	lot = city.get("_loaded")[block].get_node("WalkInLot_0") as StaticBody3D
	door = lot.get("door")
	door.call("restore_open",true)
	for i in 245:
		player.velocity = Vector3(0,0,-5)
		player.move_and_slide()
		await physics_frame
	if not check(lot.to_local(player.global_position).z < -.4,"real player exits through the same physical opening"):
		return
	# Saved on the threshold with a closed transient door: restore the
	# exact position and ensure the regenerated leaf cannot trap the player.
	door.call("restore_open",false)
	player.global_position = lot.to_global(Vector3(0,1.15,.16))
	var threshold_save: Dictionary = world.call("_capture_snapshot")
	world.call("_apply_snapshot",threshold_save)
	if not check(float(door.call("openness"))>.95,"threshold restore leaves safe passage"):
		return
	print("WALK_IN_LOT PASS: physical doors, multiple rooms, upper floor ascent/descent, bounded walls, streamed finish, world-coordinate restore and exit")
	quit(0)
