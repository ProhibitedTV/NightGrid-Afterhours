extends SceneTree
const Route = preload("res://scripts/street_route.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("STREET_ROUTE_SMOKE: " + message)
	quit(1)

func _check_network(route: Dictionary) -> bool:
	var points: Array[Vector2] = route["points"]
	if points.is_empty():
		return false
	for p in points:
		if absf(p.x) > Route.LIMIT + 0.01 or absf(p.y) > Route.LIMIT + 0.01:
			return false
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		if is_equal_approx(a.x, b.x):
			if absf(a.x - roundf(a.x / Route.STEP) * Route.STEP) > 0.01:
				return false
		elif is_equal_approx(a.y, b.y):
			if absf(a.y - roundf(a.y / Route.STEP) * Route.STEP) > 0.01:
				return false
		else:
			return false
	return is_equal_approx(Route.length_of(points), float(route["road_m"]))

func _verify() -> void:
	var straight := Route.plan(Vector2(10, 0), Vector2(43, 0))
	if not _check_network(straight) or not is_equal_approx(float(straight["road_m"]), 33.0):
		_fail("Same-road route must avoid detouring through an intersection")
		return
	var turn := Route.plan(Vector2(10, 0), Vector2(58, 42))
	if not _check_network(turn) or not is_equal_approx(float(turn["road_m"]), 90.0):
		_fail("Known two-edge route must follow the real street and intersection")
		return
	if not Route.guidance(turn, Vector2(10, 0), Vector2(58, 42)).contains("TURN RIGHT IN 48m"):
		_fail("East to south turn guidance is incorrect")
		return
	var left := Route.plan(Vector2(10, 0), Vector2(58, -42))
	if not Route.guidance(left, Vector2(10, 0), Vector2(58, -42)).contains("TURN LEFT IN 48m"):
		_fail("East to north turn guidance is incorrect")
		return
	var offroad := Route.plan(Vector2(20, 15), Vector2(72, 70))
	if not _check_network(offroad) or float(offroad["access_m"]) < 14.9 or float(offroad["last_m"]) < 11.9:
		_fail("Off-street links should be separated from the traversable route")
		return
	if not Route.guidance(offroad, Vector2(20, 15), Vector2(72, 70)).begins_with("Reach street"):
		_fail("Off-street actor needs street access guidance")
		return
	var crossing := Route.plan(Vector2(58.009, -0.008), Vector2(116, 58))
	if not _check_network(crossing) or crossing["entry"] != Vector2(58, 0):
		_fail("Near-grid coordinates must snap to the exact intersection")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 173
	for i in range(250):
		var a := Vector2(rng.randf_range(-260, 260), rng.randf_range(-260, 260))
		var b := Vector2(rng.randf_range(-232, 232), rng.randf_range(-232, 232))
		var path := Route.plan(a, b)
		if not _check_network(path) or path != Route.plan(a, b):
			_fail("Random route escapes real road geometry or is non-deterministic")
			return
		var reverse := Route.plan(b, a)
		if not is_equal_approx(float(path["road_m"]), float(reverse["road_m"])):
			_fail("Bidirectional street distances must be symmetric")
			return
	var trial := preload("res://scripts/driving_trial.gd").new()
	if trial.start(Vector2.ZERO,1,100.0,0.0) or trial.start(trial.START,1,100.0,3.0) or not trial.start(trial.START,1,100.0,0.0):
		_fail("Driving trial start gates")
		return
	if trial.tick(1.0/60.0,trial.GATES[2],1,100.0)!="ROUTE RESET" or trial.active:
		_fail("Teleport cannot skip driving checkpoints")
		return
	trial.start(trial.START,1,100.0,0.0)
	var pos:Vector2=trial.START
	for gate in trial.GATES:
		if Route.road_anchor(gate)!=gate:
			_fail("Circuit gate is not on the fixed road network")
			return
		while pos.distance_to(gate)>0.01:
			pos=pos.move_toward(gate,0.2)
			trial.tick(1.0/60.0,pos,1,100.0)
	if trial.result!="COMPLETE" or trial.active or trial.index!=trial.GATES.size():
		_fail("All authored checkpoints must settle in sequence")
		return
	var ledger:=preload("res://scripts/progression_ledger.gd").new()
	if not ledger.credit_once(trial.RECEIPT,trial.REWARD) or ledger.credit_once(trial.RECEIPT,trial.REWARD) or ledger.balance!=90:
		_fail("Circuit first finish reward must settle once")
		return
	trial.start(trial.START,1,100.0,0.0)
	if trial.tick(1.0/60.0,trial.START,2,100.0)!="ABANDONED":
		_fail("Changing cars must invalidate a circuit")
		return
	trial.start(trial.START,1,100.0,0.0)
	trial.elapsed=89.99
	if trial.tick(1.0/60.0,trial.START,1,100.0)!="TIME EXPIRED":
		_fail("Circuit timeout")
		return
	print("STREET_ROUTE_SMOKE PASS: 250 deterministic paired routes, bounds, turn directions, access links")
	quit(0)
