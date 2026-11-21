extends SceneTree
const Gate = preload("res://scripts/closure_eligibility.gd")
const Traffic = preload("res://scripts/traffic_system.gd")
func _initialize() -> void:
	create_timer(30.0,true,false,true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")
func _check(ok: bool,message: String) -> bool:
	if not ok:
		push_error("CLOSURE_ELIGIBILITY: "+message)
		quit(1)
	return ok
func _verify() -> void:
	var fixture = Traffic.new()
	var bus_path: Array[Vector3] = fixture.loop_route(-116,116,-116,116,1.75)
	var routes: Array = [bus_path]
	var empty: Array[Vector3] = []
	if not _check(Gate.route_edges(bus_path).size()==16,"whole bus loop is protected, including intermediate blocks"):
		return
	if not _check(Gate.evaluate(Vector2i(-1,-2),Vector2i(0,-2),routes,empty)=="TRANSIT_PROTECTED" and Gate.evaluate(Vector2i(0,-2),Vector2i(-1,-2),routes,empty)=="TRANSIT_PROTECTED","bidirectional bus protection"):
		return
	if not _check(Gate.evaluate(Vector2i.ZERO,Vector2i.RIGHT,routes,empty)=="ELIGIBLE","unoccupied non-transit edge"):
		return
	var blockers: Array[Vector3] = [Vector3(29,1,3.25)]
	if not _check(Gate.evaluate(Vector2i.ZERO,Vector2i.RIGHT,routes,blockers)=="OCCUPIED","actual lane offset occupancy"):
		return
	blockers = [Vector3(62,1,0)]
	if not _check(Gate.evaluate(Vector2i.ZERO,Vector2i.RIGHT,routes,blockers)=="OCCUPIED","junction safety margin"):
		return
	if not _check(Gate.evaluate(Vector2i.ZERO,Vector2i.RIGHT,[],empty)=="TRANSIT_UNKNOWN" and Gate.evaluate(Vector2i.ZERO,Vector2i.RIGHT,routes,[Vector3.INF])=="OCCUPANCY_UNKNOWN","fail closed on unavailable data"):
		return
	fixture.free()
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	var traffic: Node = world.get("traffic")
	var fleet: Array = traffic.get("fleet")
	if not _check(fleet.size()==29 and (traffic.get("buses") as Array).size()==4,"actual existing fleet"):
		return
	if not _check(traffic.call("closure_eligibility",Vector2i(-1,-3),Vector2i(0,-3),empty)=="TRANSIT_PROTECTED","actual outer bus route"):
		return
	var actor: Array[Vector3] = [Vector3(29,1,0)]
	if not _check(traffic.call("closure_eligibility",Vector2i.ZERO,Vector2i.RIGHT,actor)=="OCCUPIED","caller supplied real actor guard"):
		return
	print("CLOSURE_ELIGIBILITY_SMOKE PASS: full bus edges, bidirectional protection, lane and junction occupancy, actual fleet")
	quit(0)
