extends SceneTree
const Lot = preload("res://scripts/walk_in_lot.gd")
const Home = preload("res://scripts/starter_home.gd")
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
	var early_colliders := lot.find_children("*","CollisionShape3D",true,false).size()
	if not check(early_colliders>=20,"all interior furniture collision is prepared in stage zero"):
		return
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
	if not check(lot.find_children("*","CollisionShape3D",true,false).size()==early_colliders,"later stages cannot add occupied room obstacles"):
		return
	var batch_stats: Dictionary = lot.call("get_interior_batch_stats")
	if not check(int(batch_stats["instances"])>=16 and int(batch_stats["batches"])<int(batch_stats["instances"]),"furnishing and fixture batches reduce decorative draw instances"):
		return
	var observed := 0
	for child in lot.get_children():
		if child is MultiMeshInstance3D:
			observed += child.multimesh.instance_count
			if not check(child.visibility_range_end == 45.0,"interior detail visibility budget"):
				return
	if not check(observed==int(batch_stats["instances"]),"real multimesh instance accounting"):
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
	# A named café has been migrated into its real lot. Walk in and buy
	# from its existing service catalog without activating remote interiors.
	var venues: Node = world.get("venue_system")
	var cafe_street: Vector3 = venues.call("venue_position","helix_espresso")
	city.call("set_focus",cafe_street)
	var cafe: Node3D = city.get("_loaded")[Vector2i(0,-3)].get_node("WalkInLot_1")
	if not check(str(cafe.get("physical_venue_id"))=="helix_espresso","named café bound to physical lot"):
		return
	player.global_position = cafe.to_global(Vector3(0,1.15,-1.5))
	player.velocity = Vector3.ZERO
	world.call("_toggle_interaction")
	if not check(not world.get("venue_panel").visible,"no sidewalk purchase"):
		return
	world.call("_toggle_interior")
	var cafe_door: AnimatableBody3D = cafe.get("door")
	for i in 48:
		await physics_frame
	if not check(float(cafe_door.call("openness"))>.95 and not world.get("interiors").call("is_inside"),"H opens actual named entrance, not remote room"):
		return
	for i in 52:
		player.velocity = Vector3(0,0,5)
		player.move_and_slide()
		await physics_frame
	for i in 25:
		player.velocity = Vector3(-5,0,0)
		player.move_and_slide()
		await physics_frame
	if not check(cafe.call("service_reachable",player.global_position),"walked from street to actual counter"):
		return
	world.set("cash",100)
	world.set("health",50.0)
	venues.call("set_hour",12.0)
	world.call("_toggle_interaction")
	if not check(str(world.get("venue_selected_id"))=="helix_espresso" and world.get("venue_panel").visible,"physical counter opens existing service UI"):
		return
	world.call("_venue_action",1)
	if not check(int(world.get("cash"))==80 and is_equal_approx(float(world.get("health")),70.0),"existing purchase economics preserved"):
		return
	world.call("_close_venue")
	var home_entry := Home.entry()
	city.call("set_focus",home_entry)
	var home: Node3D = city.get("_loaded")[Home.BLOCK].get_node("WalkInLot_0")
	player.global_position = home_entry
	world.call("_toggle_interior")
	var home_door: AnimatableBody3D = home.get("door")
	if not check(home.get("home_id") == Home.ID and not home_door.call("is_requested_open"),"locked home uses stable physical parcel"):
		return
	var ledger = world.get("progression")
	ledger.credit_once(Home.ACCESS_RECEIPT,100)
	world.get("story_mission").restore({"version":1,"id":Home.ACCESS_RECEIPT,"status":"complete","step":3})
	world.set("cash",Home.move_in_price()-1)
	world.call("_toggle_interior")
	world.call("_venue_action",3)
	if not check(not ledger.owns_home() and world.get("cash")==Home.move_in_price()-1,"unaffordable tenancy refused"):
		return
	world.set("cash",Home.move_in_price())
	world.call("_venue_action",3)
	if not check(ledger.owns_home() and world.get("cash")==0,"paid tenancy activated at door"):
		return
	world.call("_toggle_interior")
	for i in 48:
		await physics_frame
	if not check(float(home_door.call("openness"))>.95,"earned key opens physical home door"):
		return
	for i in 60:
		player.velocity = Vector3(0,0,5)
		player.move_and_slide()
		await physics_frame
	if not check(home.call("contains",player.global_position) and not world.get("interiors").call("is_inside"),"continuous entry without remote room"):
		return
	player.global_position = home.call("home_action_point","rest")
	world.set("health",40.0)
	world.set("heat",0.0)
	player.call("restore_stamina",20.0)
	world.call("_toggle_interaction")
	if not check(world.get("health")==100.0 and float(player.get("stamina"))==100.0,"home bed restores player"):
		return
	player.global_position = home.call("home_action_point","storage")
	world.set("ration_packs",3)
	world.call("_toggle_interaction")
	world.call("_venue_action",1)
	world.call("_venue_action",2)
	world.call("_venue_action",1)
	world.call("_close_venue")
	if not check(world.get("ration_packs")==2 and ledger.home_supplies==1,"storage conserves carried and stored provisions"):
		return
	world.set("cash",Home.STORAGE_UPGRADE_PRICE)
	world.call("_toggle_interaction")
	world.call("_venue_action",3)
	if not check(world.get("_storage_upgrade_quote") and world.get("cash")==Home.STORAGE_UPGRADE_PRICE,"upgrade review does not charge"):
		return
	world.call("_venue_action",1)
	if not check(not ledger.home_storage_expanded and world.get("cash")==Home.STORAGE_UPGRADE_PRICE,"cancel retains original storage and cash"):
		return
	world.call("_venue_action",3)
	world.set("cash",Home.STORAGE_UPGRADE_PRICE-1)
	world.call("_venue_action",3)
	if not check(not ledger.home_storage_expanded and world.get("cash")==Home.STORAGE_UPGRADE_PRICE-1,"recheck affordability at confirmation"):
		return
	world.set("cash",Home.STORAGE_UPGRADE_PRICE)
	world.call("_venue_action",3)
	world.call("_venue_action",3)
	world.call("_venue_action",3)
	if not check(ledger.home_capacity()==Home.EXPANDED_STORAGE and world.get("cash")==0 and ledger.home_supplies==1,"capacity upgrade paid once without losing stored supplies"):
		return
	world.call("_close_venue")
	player.global_position = home.call("home_action_point","wardrobe")
	world.call("_toggle_interaction")
	world.call("_venue_action",2)
	world.call("_venue_action",3)
	if not check(ledger.outfit_id=="dispatch" and not ledger.owns_outfit("tideline") and world.get("cash")==0,"common clothing is not free"):
		return
	world.set("cash",47)
	world.call("_venue_action",3)
	world.call("_venue_action",3)
	world.call("_venue_action",3)
	if not check(ledger.outfit_id=="tideline" and player.get_node("Visual").get("outfit_id")=="tideline" and world.get("cash")==0,"paid common colorway"):
		return
	world.set("cash",403)
	for i in range(3):
		world.call("_venue_action",2)
	world.call("_venue_action",3)
	if not check(world.get("_wardrobe_quote_id")=="vesper_tailored" and world.get("cash")==403,"rare wardrobe purchase review"):
		return
	world.call("_venue_action",1)
	if not check(not ledger.owns_outfit("vesper_tailored") and world.get("cash")==403,"cancel cosmetic purchase"):
		return
	world.call("_venue_action",3)
	world.call("_venue_action",3)
	world.call("_venue_action",3)
	if not check(ledger.owns_outfit("vesper_tailored") and ledger.outfit_id=="vesper_tailored" and world.get("cash")==0,"rare item paid once and equipped"):
		return
	world.call("_close_venue")
	player.global_position = home.call("home_action_point","exchange")
	world.set("cash",100)
	world.call("_toggle_interaction")
	world.call("_venue_action",1)
	if not check(ledger.bitcoin_sats==39200 and world.get("cash")==0,"real exchange action charges fee"):
		return
	world.call("_close_venue")
	player.global_position = home.call("home_action_point","wardrobe")
	world.call("_toggle_interaction")
	world.call("_venue_action",1)
	world.call("_venue_action",1)
	world.call("_venue_action",3)
	world.call("_venue_action",3)
	if not check(ledger.owns_outfit("rustline") and ledger.bitcoin_sats==15200 and world.get("cash")==0,"paid common clothing with BTC"):
		return
	world.call("_close_venue")
	player.global_position = home.call("home_action_point","storage")
	var home_save: Dictionary = world.call("_capture_snapshot")
	var session := root.get_node("GameSession")
	if not check(session.call("is_valid_snapshot",session.call("make_snapshot",home_save)),"home state valid on disk schema"):
		return
	ledger.home_supplies=0
	ledger.home_storage_expanded=false
	ledger.outfit_id="dispatch"
	player.get_node("Visual").call("set_outfit","dispatch")
	world.set("ration_packs",0)
	world.call("_apply_snapshot",home_save)
	if not check(ledger.home_supplies==1 and ledger.owns_home() and ledger.home_capacity()==Home.EXPANDED_STORAGE and ledger.outfit_id=="vesper_tailored" and ledger.owns_outfit("vesper_tailored") and ledger.owns_outfit("rustline") and ledger.bitcoin_sats==15200 and player.get_node("Visual").get("outfit_id")=="vesper_tailored" and world.get("ration_packs")==2 and player.global_position.distance_to(home.call("home_action_point","storage"))<.1,"home entitlement and stash round trip"):
		return
	print("WALK_IN_LOT PASS: physical doors, multiple rooms, upper floor ascent/descent, bounded walls, streamed finish, world-coordinate restore and exit")
	quit(0)
