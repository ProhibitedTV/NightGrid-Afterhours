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
	var taxi:=preload("res://scripts/taxi_job.gd").new()
	var rider:=preload("res://scripts/taxi_waiting_rider.gd").new()
	root.add_child(rider)
	var waiting:=taxi.waiting_point(taxi.offer(0))
	rider.show_rider(0,"Nina",waiting)
	if not rider.visible or rider.global_position!=waiting or rider.find_children("*","Skeleton3D",true,false).size()!=1 or not rider.find_children("*","CollisionShape3D",true,false).is_empty():
		_fail("Taxi waiting rider uses an actual weighted rig without crowd collision")
		return
	rider.hide_rider()
	if rider.visible:
		_fail("Taxi boarding removes curbside visual")
		return
	var seat_car:=Node3D.new()
	root.add_child(seat_car)
	# These are the exact shipped three civilian imports, not mock bones.
	for style in range(3):
		if not rider.seat_rider(style,"Passenger",seat_car) or not rider.is_seated() or rider.get_parent()!=seat_car:
			_fail("Imported taxi rider must support the seated pose: %d"%style)
			return
		rider.hide_rider()
		if rider.is_seated() or rider.get_parent()!=root or not rider.scale.is_equal_approx(Vector3.ONE) or not rider.transform.basis.is_equal_approx(Basis.IDENTITY):
			_fail("Seated rider lifecycle restores standing parent and scale: style %d seated %s parent %s scale %s"%[style,str(rider.is_seated()),str(rider.get_parent()),str(rider.scale)])
			return
	seat_car.queue_free()
	var arrival:=taxi.arrival_point(taxi.offer(0))
	var goal:=arrival+Vector3(-3,0,0)
	rider.begin_departure(0,"Nina",arrival,goal)
	for step in range(180):
		rider.advance_departure(1.0/60.0)
	if not rider.is_departing() or rider.global_position.distance_to(goal)>.06:
		_fail("Taxi arrival actor walks a bounded sidewalk segment")
		return
	for step in range(310):
		rider.advance_departure(1.0/60.0)
	if rider.visible or rider.is_departing():
		_fail("Taxi departure terminates and releases visual")
		return
	rider.queue_free()
	var taxi_ledger:=preload("res://scripts/progression_ledger.gd").new()
	for run in range(3):
		var offer:=taxi.offer(run)
		var pickup:Vector2=offer["pickup"]
		var drop:Vector2=offer["drop"]
		if taxi.begin(run,pickup,9,49.0,0.0) or taxi.begin(run,pickup,9,100.0,2.0) or not taxi.begin(run,pickup,9,100.0,0.0):
			_fail("Taxi comfort and stopped pickup guards")
			return
		if taxi.tick(pickup,10,100.0,1.0/60.0) or taxi.active or taxi.failure_reason!="Original vehicle required.":
			_fail("Taxi vehicle switch cancels fare")
			return
		taxi.begin(run,pickup,9,100.0,0.0)
		if not taxi.failure_reason.is_empty():
			_fail("Taxi retry clears previous failure")
			return
		var taxi_pos:=pickup
		var path:=Route.plan(pickup,drop)
		var points:Array[Vector2]=path["points"]
		points.append(drop)
		for waypoint in points:
			while taxi_pos.distance_to(waypoint)>.01:
				taxi_pos=taxi_pos.move_toward(waypoint,.2)
				taxi.tick(taxi_pos,9,100.0,1.0/60.0)
		if not taxi.ready_to_arrive(drop,9,100.0,0.0) or not taxi_ledger.settle_taxi(taxi.sequence) or taxi_ledger.settle_taxi(taxi.sequence):
			_fail("Taxi physical-route and exactly-once settlement")
			return
		taxi.cancel()
	var taxi_save:Dictionary=JSON.parse_string(JSON.stringify(taxi_ledger.snapshot()))
	var taxi_restored:=preload("res://scripts/progression_ledger.gd").new()
	if not taxi_restored.restore(145,taxi_save) or taxi_restored.taxi_runs!=3 or taxi_ledger.balance!=145 or taxi_ledger.freight_runs!=0:
		_fail("Independent taxi progression roundtrip")
		return
	taxi_save["taxi_runs"]=100001
	if taxi_restored.restore(0,taxi_save) or taxi_restored.taxi_runs!=3:
		_fail("Invalid taxi count rejected atomically")
		return
	taxi.begin(0,taxi.ROUTES[0]["pickup"],9,100.0,0.0)
	taxi.elapsed=239.99
	if taxi.tick(taxi.ROUTES[0]["pickup"],9,100.0,1.0/60.0) or taxi.active or taxi.failure_reason!="Passenger time limit expired.":
		_fail("Taxi timeout")
		return
	var freight:=preload("res://scripts/freight_job.gd").new()
	if not freight.supports_vehicle("",false) or freight.supports_vehicle("cinder_r9",false) or freight.supports_vehicle("",true):
		_fail("Cargo capacity must reject sports cars and service cruisers")
		return
	var case_view:=preload("res://scripts/freight_cargo_case.gd").new()
	case_view.configure("Cold Chain transfer")
	root.add_child(case_view)
	if case_view.find_children("*","MeshInstance3D",true,false).size()!=8 or not case_view.find_children("*","CollisionShape3D",true,false).is_empty():
		_fail("Sealed cargo case has bounded geometry and no collision")
		return
	case_view.queue_free()
	var freight_ledger:=preload("res://scripts/progression_ledger.gd").new()
	for run in range(3):
		var offer:=freight.offer(run)
		var pickup:Vector2=offer["pickup"]
		var drop:Vector2=offer["drop"]
		if not freight.begin(run,pickup,55,100.0,0.0) or freight.ready_to_deliver(drop,55,100.0,0.0):
			_fail("Freight load and premature unload guards")
			return
		if freight.tick(drop,55,100.0,1.0/60.0) or freight.active or freight.failure_reason!="Route interrupted by displacement.":
			_fail("Freight teleport cancels load")
			return
		freight.begin(run,pickup,55,100.0,0.0)
		if freight.tick(pickup,55,18.0,1.0/60.0) or freight.failure_reason!="Cargo vehicle is no longer roadworthy.":
			_fail("Freight condition failure is explicit")
			return
		freight.begin(run,pickup,55,100.0,0.0)
		if not freight.failure_reason.is_empty():
			_fail("Freight retry clears previous failure")
			return
		var freight_pos:=pickup
		var road:=Route.plan(pickup,drop)
		var road_points:Array[Vector2]=road["points"]
		road_points.append(drop)
		for waypoint in road_points:
			while freight_pos.distance_to(waypoint)>.01:
				freight_pos=freight_pos.move_toward(waypoint,.2)
				freight.tick(freight_pos,55,100.0,1.0/60.0)
		if not freight.ready_to_deliver(drop,55,100.0,0.0) or not freight_ledger.settle_freight(freight.sequence) or freight_ledger.settle_freight(freight.sequence):
			_fail("Freight exactly-once settlement and original vehicle")
			return
		freight.cancel()
	var freight_save:Dictionary=JSON.parse_string(JSON.stringify(freight_ledger.snapshot()))
	var freight_restored:=preload("res://scripts/progression_ledger.gd").new()
	if not freight_restored.restore(230,freight_save) or freight_restored.freight_runs!=3 or freight_ledger.balance!=230 or freight.offer(3)!=freight.offer(0):
		_fail("Repeatable freight cycle and save")
		return
	freight_save["freight_runs"]=-1
	if freight_restored.restore(0,freight_save) or freight_restored.freight_runs!=3:
		_fail("Invalid freight save rejected")
		return
	var trial := preload("res://scripts/driving_trial.gd").new()
	if trial.start(Vector2.ZERO,1,100.0,0.0) or trial.start(trial.START,1,100.0,3.0) or not trial.start(trial.START,1,100.0,0.0):
		_fail("Driving trial start gates")
		return
	if trial.tick(1.0/60.0,trial.GATES[2],1,100.0)!="ROUTE RESET" or trial.active:
		_fail("Teleport cannot skip driving checkpoints")
		return
	trial.start(trial.START,1,100.0,0.0)
	# Gradual off-road movement is not a teleport; it must still fail.
	for step in range(1,45):
		var outside:Vector2=trial.START+Vector2(0,.2*step)
		trial.tick(1.0/60.0,outside,1,100.0)
	if trial.active or trial.result!="OFF COURSE" or trial.index!=0:
		_fail("Slow off-road shortcuts cannot preserve a race")
		return
	trial.start(trial.START,1,100.0,0.0)
	# Legal parallel lane and early radius entry must permit a turn.
	var corner:Vector2=trial.GATES[0]
	var lane:Vector2=trial.START+Vector2(0,-3)
	while trial.previous.distance_to(lane)>.01 and trial.active:
		trial.tick(1.0/60.0,trial.previous.move_toward(lane,.2),1,100.0)
	var approach:=corner+Vector2(-5,-3)
	while trial.previous.distance_to(approach)>.01 and trial.active:
		trial.tick(1.0/60.0,trial.previous.move_toward(approach,.2),1,100.0)
	if not trial.active or trial.index!=1 or not trial.on_course(approach) or not trial.on_course(corner+Vector2(-3,-5)):
		_fail("Normal lane approach and early checkpoint turn remain valid")
		return
	var checkpoint_split:float=trial.pace_split()
	var checkpoint_elapsed:float=trial.last_gate_elapsed
	for frame in range(60):
		trial.tick(1.0/60.0,approach,1,100.0)
	if not trial.active or trial.elapsed<checkpoint_elapsed+0.9 or trial.pace_split()!=checkpoint_split or not trial.status(approach).contains("SPLIT"):
		_fail("Completed checkpoint split remains fixed while race clock advances")
		return
	trial.stop("ABANDONED")
	trial.start(trial.START,1,100.0,0.0)
	if trial.last_gate_elapsed!=0.0 or trial.pace_split()!=0.0 or trial.status(trial.START).contains("SPLIT"):
		_fail("Restart resets split timing")
		return
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
	if not is_equal_approx(trial.pace_split(),trial.elapsed-trial.pace_time()):
		_fail("Final checkpoint split matches finish time")
		return
	var ledger:=preload("res://scripts/progression_ledger.gd").new()
	if not ledger.credit_once(trial.RECEIPT,trial.REWARD) or ledger.credit_once(trial.RECEIPT,trial.REWARD) or ledger.balance!=90:
		_fail("Circuit first finish reward must settle once")
		return
	if ledger.circuit_best_ms!=0 or not ledger.record_circuit_time(42.567) or ledger.circuit_best_ms!=42567 or ledger.record_circuit_time(43.0) or ledger.record_circuit_time(42.567) or ledger.record_circuit_time(NAN) or ledger.record_circuit_time(-1.0) or ledger.record_circuit_time(90.0):
		_fail("Personal record must be valid and strictly improved")
		return
	if not ledger.record_circuit_time(40.125) or ledger.balance!=90:
		_fail("Improved record cannot grant duplicate money")
		return
	var saved:Dictionary=JSON.parse_string(JSON.stringify(ledger.snapshot()))
	var restored:=preload("res://scripts/progression_ledger.gd").new()
	if not restored.restore(ledger.balance,saved) or restored.circuit_best_ms!=40125 or not restored.has_receipt(trial.RECEIPT):
		_fail("Circuit record must survive JSON save roundtrip")
		return
	var phone:=preload("res://scripts/morrow_phone.gd")
	if not str(phone.view("opportunities",{"circuit_best_ms":40125,"circuit_completed":true})["rows"]).contains("40.125s"):
		_fail("Workboard must show the persistent personal best")
		return
	saved["circuit_best_ms"]=90001
	if restored.restore(0,saved) or restored.balance!=90 or restored.circuit_best_ms!=40125:
		_fail("Malformed record must not mutate live progression")
		return
	saved.erase("circuit_best_ms")
	if not restored.restore(90,saved) or restored.circuit_best_ms!=0 or not restored.has_receipt(trial.RECEIPT):
		_fail("Legacy circuit receipt remains compatible without a recorded time")
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
	var brick:=preload("res://scripts/driving_trial.gd").new()
	if not brick.start(brick.BRICK_START,7,100.0,0.0) or brick.course_id!=brick.BRICK or brick.time_limit()!=120.0 or brick.receipt()==trial.RECEIPT:
		_fail("Second course must select its own rules from the physical start")
		return
	var brick_pos:Vector2=brick.BRICK_START
	for gate in brick.gates():
		if Route.road_anchor(gate)!=gate:
			_fail("Brickwater gate must lie on the fixed road network")
			return
		while brick_pos.distance_to(gate)>0.01:
			brick_pos=brick_pos.move_toward(gate,0.2)
			brick.tick(1.0/60.0,brick_pos,7,100.0)
	if brick.result!="COMPLETE" or not ledger.record_circuit_time(brick.elapsed,brick.BRICK) or not ledger.credit_once(brick.receipt(),brick.reward()) or ledger.credit_once(brick.receipt(),brick.reward()) or ledger.balance!=230 or ledger.circuit_best_ms!=40125:
		_fail("Second course has independent settlement and personal record")
		return
	var combined:Dictionary=JSON.parse_string(JSON.stringify(ledger.snapshot()))
	if not restored.restore(230,combined) or restored.brickwater_best_ms!=ledger.brickwater_best_ms or restored.circuit_best_ms!=40125:
		_fail("Both records persist independently")
		return
	if not str(phone.view("opportunities",{"brickwater_best_ms":12345,"brickwater_completed":true})["rows"]).contains("12.345s"):
		_fail("Second course personal best visible in phone")
		return
	combined["brickwater_best_ms"]=120001
	if restored.restore(0,combined) or restored.balance!=230:
		_fail("Invalid second course record cannot mutate progression")
		return
	# Reference rivals follow only fixed authored road segments and never
	# affect a checkpoint, payout or saved record.
	for reference in [trial,brick]:
		var start_point:Vector2=reference.BRICK_START if reference.course_id==reference.BRICK else reference.START
		var start_pose:Dictionary=reference.pace_pose(0.0)
		var end_pose:Dictionary=reference.pace_pose(reference.pace_time())
		if start_pose["position"]!=start_point or end_pose["position"]!=start_point or not reference.pace_pose(NAN).is_empty():
			_fail("Reference rival start, finish and input guards")
			return
		var prior:Vector2=start_pose["position"]
		for sample in range(1,121):
			var pose:Dictionary=reference.pace_pose(reference.pace_time()*float(sample)/120.0)
			var point:Vector2=pose["position"]
			var heading:Vector2=pose["heading"]
			if Route.road_anchor(point).distance_to(point)>.02 or not is_equal_approx(heading.length(),1.0) or point.distance_to(prior)>5.0:
				_fail("Reference rival remains on authored streets with bounded continuous movement")
				return
			prior=point
	if not is_finite(brick.pace_split()) or ledger.balance!=230:
		_fail("Reference split does not affect progression")
		return
	print("STREET_ROUTE_SMOKE PASS: 250 deterministic paired routes, bounds, turn directions, access links")
	quit(0)
