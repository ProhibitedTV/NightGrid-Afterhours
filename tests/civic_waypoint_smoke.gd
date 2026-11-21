extends SceneTree
const Route = preload("res://scripts/street_route.gd")
func _initialize() -> void:
	create_timer(30.0,true,false,true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")
func _check(ok: bool,message: String) -> bool:
	if not ok:
		push_error("CIVIC_WAYPOINT: "+message)
		quit(1)
	return ok
func _verify() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	var player: CharacterBody3D = world.get("player")
	player.global_position = Vector3(0,1.15,0)
	var start := Vector2.ZERO
	var goal := Vector2(58,0)
	world.set("navigation_waypoint",goal)
	var baseline: Dictionary = world.call("_navigation_route",start)
	if not _check(baseline==Route.plan(start,goal),"original route"):
		return
	var registry = world.get("road_restrictions")
	var old_mission: Vector3 = world.get("mission_position")
	if not _check(registry.add(Vector2i.ZERO,Vector2i.RIGHT,"TEST","service",10.0),"test registry"):
		return
	var state: Dictionary = world.call("get_map_state")
	if not _check(is_equal_approx(float(state["street_route"]["road_m"]),174.0) and str(world.call("navigation_text")).contains("174 m by street"),"map and HUD update without actor movement"):
		return
	world.set("navigation_waypoint",Vector2(20,0))
	if not _check((world.call("_navigation_route",start) as Dictionary).is_empty() and str(world.call("navigation_text")).contains("Street route unavailable"),"closed target shows no route"):
		return
	world.set("navigation_waypoint",goal)
	registry.advance(10.0)
	if not _check(world.call("_navigation_route",start)==baseline and world.get("mission_position")==old_mission and float(world.get("heat"))==0.0,"expiry invalidation independent of mission and heat"):
		return
	world.call("clear_navigation_waypoint")
	if not _check((world.call("_navigation_route",start) as Dictionary).is_empty(),"clear route"):
		return
	print("CIVIC_WAYPOINT_SMOKE PASS: real map/HUD, detour revision, closed target and expiry")
	quit(0)
