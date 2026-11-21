extends SceneTree
const Service = preload("res://scripts/civic_patrol_service.gd")

func _initialize() -> void:
	create_timer(35.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("CIVIC_PATROL: " + message)
		quit(1)
	return ok

func _verify() -> void:
	var s = Service.new()
	var request := {"id":"CIV-000001", "state":"ACTIVE", "point":Vector3.ONE}
	if not _check(s.claim(request,"PATROL-01") and not s.claim(request,"PATROL-02"), "single claim"):
		return
	s.tick(5.0,false)
	if not _check(s.task["phase"] == "EN_ROUTE", "no fabricated arrival"):
		return
	s.tick(1.0,true)
	s.tick(6.0,true)
	if not _check(s.task.is_empty() and s.history()[0]["outcome"] == "COMPLETED" and not s.claim(request,"PATROL-01"), "service dwell and deduplication"):
		return
	request["id"] = "CIV-000002"
	s.claim(request,"PATROL-02")
	s.tick(Service.MAX_TRAVEL_SECONDS,false)
	if not _check(s.history()[-1]["outcome"] == "EXPIRED", "travel timeout"):
		return
	s.restore(JSON.parse_string(JSON.stringify(s.snapshot())))
	if not _check(not s.claim(request,"PATROL-02") and s.task.is_empty(), "safe reload"):
		return
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var ledger = world.get("ambient_civic")
	var dispatch = world.get("dispatch")
	var service = world.get("civic_patrol_service")
	ledger.restore({})
	ledger.advance(25.0)
	world.call("_update_civic_patrols",1.0)
	var patrol: CharacterBody3D = world.get("_civic_patrol")
	if not _check(is_instance_valid(patrol) and service.task["phase"] == "EN_ROUTE" and patrol.get("police_destination") == service.task["point"] and not bool(patrol.get("police_priority")), "real existing cruiser assignment"):
		return
	var goal: Vector3 = service.task["point"]
	# Controlled fixture, not proof of native driving to the location.
	patrol.set_physics_process(false)
	patrol.global_position = goal
	patrol.set("speed",0.0)
	var policy = patrol.get("drive_policy")
	var fixture_path: Array[Vector2] = [Vector2(goal.x,goal.z)]
	policy.path = fixture_path
	policy.destination = Vector2(goal.x,goal.z)
	policy.index = 0
	world.call("_update_civic_patrols",0.1)
	if not _check(service.task["phase"] == "SERVICING" and bool(patrol.get("civic_service_hold")), "observed arrival and dwell"):
		return
	world.call("_update_civic_patrols",6.0)
	if not _check(service.task.is_empty() and not bool(patrol.get("civic_service_hold")) and not (patrol.get("police_destination") as Vector3).is_finite(), "return to routine path"):
		return
	if not _check(float(world.get("heat")) == 0.0 and dispatch.active.is_empty() and (world.get("officers") as Array).is_empty() and (world.get("routine_patrols") as Array).size() == 2, "independent heat and stable fleet"):
		return
	print("CIVIC_PATROL_SMOKE PASS: assignment, observed arrival fixture, dwell, timeout, reload and unchanged player dispatch")
	quit(0)
