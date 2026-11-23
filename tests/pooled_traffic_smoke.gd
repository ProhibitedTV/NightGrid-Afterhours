extends SceneTree
## Run the lease director against actual streets, real camera and colliders.
const Game = preload("res://scenes/main.tscn")
const Pool = preload("res://scripts/ambient_traffic_pool.gd")
const Rules = preload("res://scripts/road_restrictions.gd")

func _initialize() -> void:
	create_timer(48.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("POOLED_TRAFFIC: " + message)
		quit(1)
	return ok

func _verify() -> void:
	var world := Game.instantiate() as Node3D
	world.set("_pooled_traffic_enabled", true)
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	var traffic := world.get_node("SurfaceTraffic")
	var pool := traffic.get_node("AmbientTrafficPool") as Pool
	var site := Vector3(3.25, 1.09, 146.0)
	var player: CharacterBody3D = world.get("player")
	player.global_position = site
	player.velocity = Vector3.ZERO
	var city := world.get_node("CityDetails")
	city.call("set_focus", site)
	world.call("_snap_camera")
	var rules := Rules.new()
	var candidate := Vector3(3.25, 1.0, 146.0)
	if not _check(Pool.legal_lane(candidate, rules) and not Pool.legal_lane(Vector3(3.25, 1.0, 116.0), rules), "authored lane versus intersection clearance"):
		return
	if not _check(rules.add(Vector2i(0,2), Vector2i(0,3), "fixture", "closure", 1.0) and not Pool.legal_lane(candidate, rules), "a closed lane rejects a real route position"):
		return
	var warmup := pool.stats()
	if not _check(warmup["logical_cars"] == 25 and warmup["lease_capacity"] == 16 and pool.get_child_count() == 16, "seeded population and reused slot count"):
		return
	for direction in [0.0, PI, PI * 0.5, -PI * 0.5]:
		world.set("yaw", direction)
		world.call("_snap_camera")
		for tick in range(85):
			await physics_frame
		if pool.stats()["activated"] > 0:
			break
	var stats := pool.stats()
	if not _check(stats["activated"] > 0 and stats["leased_cars"] <= 16, "leases occur behind the real camera on streamed roads"):
		return
	var fleet: Array = traffic.get("fleet")
	if not _check(fleet.size() == stats["leased_cars"] + 4, "registries include active leases and four persistent buses"):
		return
	var state: Dictionary = traffic.call("snapshot")
	var ids := {}
	for actor in state["vehicles"]:
		ids[str(actor["id"])] = true
	if not _check(ids.size() == 29 and state["vehicles"].size() == 29 and state["logical"]["phases"].size() == 25, "v1 includes all unique logical and physical identities"):
		return
	# Exercise migration from the original v1 vehicle list without a phase map.
	state.erase("logical")
	traffic.call("restore", state)
	if not _check(traffic.get("fleet").size() == 4 and pool.get_child_count() == 16, "restore releases ambient registries but keeps nodes and transit"):
		return
	var after: Dictionary = traffic.call("snapshot")
	if not _check(after["vehicles"].size() == 29 and traffic.call("bus_by_id", "bus-0") != null, "legacy migration keeps identities and bus service"):
		return
	print("POOLED_TRAFFIC PASS: loaded lane admission, real camera, closed edge, capped slots and v1 migration")
	quit(0)
