extends SceneTree
const Drive = preload("res://scripts/police_drive.gd")

func _initialize() -> void:
	create_timer(35.0, true, false, true).timeout.connect(func() -> void: _fail("timeout"))
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("POLICE_DRIVE_SMOKE: " + message)
	paused = false
	quit(1)

func _verify() -> void:
	var path := Drive.lane_path(Vector2(10, 0), Vector2(58, 42))
	if path.size() < 3 or not path[0].is_equal_approx(Vector2(10, 3.25)) or not path[-1].is_equal_approx(Vector2(54.75, 42)):
		_fail("Right-hand lane route must use actual street geometry")
		return
	for point in path:
		if minf(absf(point.x - roundf(point.x / 58.0) * 58.0), absf(point.y - roundf(point.y / 58.0) * 58.0)) > 3.26:
			_fail("Route waypoint strayed from street envelope")
			return
	if Drive.safe_speed(true, 40, 0, INF, 0, false) != 0.0:
		_fail("Even urgent response must stop at red")
		return
	if Drive.safe_speed(true, 40, 0, 2, 13, false) != 0.0:
		_fail("Urgent response must yield to obstruction")
		return
	if Drive.safe_speed(true, 40, 0, INF, 13, true) >= Drive.safe_speed(true, 40, 0, INF, 13, false):
		_fail("Dark conditions should lower the game speed cap")
		return
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var patrols: Array = world.get("routine_patrols")
	var patrol: CharacterBody3D = patrols[0]
	if not is_instance_valid(patrol.get("police_signals")) or bool(patrol.get("police_priority")):
		_fail("Real routine patrol must use signals without emergency priority")
		return
	patrol.set_physics_process(false)
	patrol.global_position = Vector3(0, 1.1, 0)
	patrol.rotation.y = 0
	var block := StaticBody3D.new()
	block.position = Vector3(0, 1.1, -7)
	var box := BoxShape3D.new()
	box.size = Vector3(5, 3, 1)
	var col := CollisionShape3D.new()
	col.shape = box
	block.add_child(col)
	world.add_child(block)
	await physics_frame
	await physics_frame
	var controller = patrol.get("drive_policy")
	controller.reset()
	var clearance: float = controller.clearance(patrol, 1.0)
	if not is_finite(clearance) or clearance > 5.0:
		_fail("Actual physics obstacle must appear in police clearance")
		return
	var speed := Drive.safe_speed(true, 40, 0, clearance, 13, false)
	if speed >= Drive.CORNER_SPEED:
		_fail("Obstacle should reduce urgent speed before collision")
		return
	print("POLICE_DRIVE_SMOKE PASS: lane route, red signal, night cap, obstruction cap, real patrol and collider")
	quit(0)
