extends SceneTree
## Uses the actual permanent Brickwater parcel and the normal player controller.
const GAME = preload("res://scenes/main.tscn")
const Shop = preload("res://scripts/brickwater_storefront.gd")
const BLOCK = Vector2i(-2, 1)
var world: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	create_timer(55.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_run")

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		push_error("BRICKWATER_STOREFRONT: " + message)
		quit(1)
	return ok

func _run() -> void:
	world = GAME.instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	var city: Node3D = world.get("city_details")
	player = world.get("player")
	city.call("set_focus", Vector3(-87, 0, 87))
	var shop := city.call("repair_storefront") as Shop
	if not _expect(shop != null and shop.door.art_ready, "authored shop art and collision in the permanent chunk"):
		return
	var loaded := (city.get("_loaded") as Dictionary).get(BLOCK) as Node3D
	if not _expect(loaded.is_ancestor_of(shop) and absf(shop.global_position.z - 87.9) < 0.01, "original west doorway datum"):
		return
	var phase_start := shop.to_global(Vector3(0.72, 0.95, 0))
	player.global_position = phase_start
	player.velocity = Vector3.ZERO
	world.set("yaw", PI * 0.5)
	await _ticks(3)
	var floor := _ray(shop, Vector3(-2.4, 1, -0.4), Vector3(-2.4, -0.2, -0.4))
	if not _expect(not floor.is_empty() and absf(floor["position"].y - Shop.FLOOR_Y) < 0.015, "flush walkable slab"):
		return
	for probe in [
		[Vector3(0.70,1.3,-6.55), Vector3(-0.81,1.3,-6.55)],
		[Vector3(-5.1,1.5,-0.6), Vector3(-6.1,1.5,-0.6)],
		[Vector3(-2.0,2.5,-0.6), Vector3(-2.0,3.85,-0.6)],
		[Vector3(-2.0,0.6,-0.6), Vector3(-4.2,0.6,-0.6)],
		[Vector3(-2.0,1.1,-3.60), Vector3(-0.3,1.1,-3.60)],
	]:
		if not _expect(not _ray(shop, probe[0], probe[1]).is_empty(), "window, rear, ceiling, counter and rack stay solid"):
			return
	await _walk("move_forward", 35)
	if not _expect(not shop.contains(player.global_position), "a closed door stops the actual character capsule"):
		return
	world.call("_toggle_interior")
	await _ticks(48)
	if not _expect(shop.door.openness() > 0.98 and shop.door.rotation.y > 0.0, "door opens inward"):
		return
	var before := player.global_position
	await _walk("move_forward", 57)
	if not _expect(shop.contains(player.global_position) and before.distance_to(player.global_position) < 5.2, "the actual controller crosses the physical threshold"):
		return
	player.global_position = shop.to_global(Vector3(-0.49, 0.95, 0.38))
	player.velocity = Vector3.ZERO
	await _ticks(3)
	world.call("_toggle_interior")
	await _ticks(45)
	if not _expect(shop.door.openness() > 0.05, "door stops for a player in the sweep"):
		return
	player.global_position = shop.counter_position()
	player.velocity = Vector3.ZERO
	await _ticks(55)
	if not _expect(shop.door.openness() < 0.02 and shop.counter_reachable(player.global_position), "clear sweep resumes closing and counter stays accessible"):
		return
	var saved_at := player.global_position
	var session := root.get_node("GameSession")
	var save: Dictionary = session.call("make_snapshot", world.call("_capture_snapshot"))
	if not _expect(session.call("is_valid_snapshot", save) and save["version"] == 1 and save["interior"].is_empty(), "walk-in saves retain the v1 position contract"):
		return
	session.set("pending_restore", save)
	world.queue_free()
	await process_frame
	world = GAME.instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	player = world.get("player")
	city = world.get("city_details")
	shop = city.call("repair_storefront") as Shop
	if not _expect(shop != null and player.global_position.distance_to(saved_at) < 0.05 and shop.door.openness() < 0.02, "same physical room and safe closed leaf on v1 reload"):
		return
	var car: CharacterBody3D = world.get("cars")[0]
	car.global_position = Vector3(-86.8, 1.05, 72.4)
	car.set("condition", 50.0)
	world.set("cash", 60)
	var cash: int = world.get("cash")
	world.call("_toggle_interaction")
	world.call("_venue_action", 1)
	if not _expect(float(car.get("condition")) >= 99.9 and world.get("cash") == cash - Shop.PRICE, "the counter charges once and calls the current repair mechanic"):
		return
	var ledger = world.get("progression")
	var vehicle_id := str(car.get_meta("vehicle_id", ""))
	var before_title: int = world.get("cash")
	world.call("_venue_action", 2)
	if not _expect(not ledger.owns_vehicle(vehicle_id) and world.get("cash") == before_title, "unaffordable title rejected without debit"):
		return
	world.set("cash", 600)
	world.call("_update_venue_panel")
	world.call("_venue_action", 2)
	if not _expect(world.get("_title_quote_id") == vehicle_id and world.get("cash") == 600 and not ledger.owns_vehicle(vehicle_id), "review binds exact ID without debit"):
		return
	world.call("_venue_action", 1)
	if not _expect(str(world.get("_title_quote_id")).is_empty() and world.get("cash") == 600, "cancel does not repair or charge"):
		return
	world.call("_venue_action", 2)
	var parked_at := car.global_position
	car.global_position = Vector3(0,1,0)
	world.call("_venue_action", 2)
	if not _expect(not ledger.owns_vehicle(vehicle_id) and world.get("cash") == 600, "stale selected vehicle refuses confirmation"):
		return
	car.global_position = parked_at
	world.call("_update_venue_panel")
	world.call("_venue_action", 2)
	world.set("cash", 499)
	world.call("_venue_action", 2)
	if not _expect(not ledger.owns_vehicle(vehicle_id) and world.get("cash") == 499, "affordability rechecked at confirmation"):
		return
	world.set("cash", 500)
	world.call("_update_venue_panel")
	world.call("_venue_action", 2)
	world.call("_venue_action", 2)
	world.call("_venue_action", 2)
	if not _expect(ledger.owns_vehicle(vehicle_id) and world.get("cash") == 0 and world.get("cars").size() == 12, "actual counter registers one existing car once at exact balance"):
		return
	var owned_save: Dictionary = session.call("make_snapshot", world.call("_capture_snapshot"))
	if not _expect(session.call("is_valid_snapshot", owned_save), "registered title is valid save data"):
		return
	ledger.restore(0, {"version":1,"receipts":[]})
	world.call("_apply_snapshot", owned_save)
	if not _expect(ledger.owns_vehicle(vehicle_id) and world.get("cash") == 0 and world.get("cars").size() == 12, "title and balance restore without spawning a second car"):
		return
	world.call("_close_venue")
	player.global_position = shop.to_global(Vector3(-1.42, 0.95, 0))
	player.velocity = Vector3.ZERO
	world.call("_toggle_interior")
	await _ticks(48)
	if not _expect(shop.door.openness() > 0.98, "inside controls can open the door from beyond its sweep"):
		return
	await _walk("move_backward", 78)
	if not _expect(not shop.contains(player.global_position), "reopened shop can be exited on foot after reload"):
		return
	print("BRICKWATER_STOREFRONT PASS: original door and window, continuous collision, blocked sweep, v1 reload, counter and exit")
	quit(0)

func _ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _walk(action: StringName, ticks: int) -> void:
	Input.action_press(action, 0.63)
	await _ticks(ticks)
	Input.action_release(action)
	await _ticks(6)

func _ray(shop: Shop, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(shop.to_global(from), shop.to_global(to), 1, [player.get_rid()])
	return shop.get_world_3d().direct_space_state.intersect_ray(query)
