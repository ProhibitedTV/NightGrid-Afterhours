extends SceneTree
const Trial=preload("res://scripts/driving_trial.gd")
const Rival=preload("res://scripts/circuit_rival.gd")
const Route=preload("res://scripts/street_route.gd")

func _initialize()->void:
	for course in [Trial.SOUTH,Trial.BRICK]:
		var trial:=Trial.new()
		trial.course_id=course
		var start:Vector2=Trial.BRICK_START if course==Trial.BRICK else Trial.START
		# The player trial has its own authoritative clock and checkpoint
		# progression; the visual rival cannot grant a completion.
		if not _verify_trial(start):
			return
		var rival:=Rival.new()
		if not rival.configure(start,trial.gates()):
			_fail("Rival course configuration")
			return
		var prior:=rival.position
		for step in range(120):
			rival.tick(1.0/60.0,true)
		if rival.position!=prior or rival.speed!=0.0 or rival.travel!=0.0:
			_fail("Blocked rival must not advance")
			return
		for step in range(7200):
			prior=rival.position
			rival.tick(1.0/60.0,false)
			if rival.position.distance_to(prior)>Rival.MAX_SPEED/60.0+.001 or not is_equal_approx(rival.travel,rival.position.distance_to(prior)) or absf(rival.steer)>1.0 or Route.road_anchor(rival.position).distance_to(rival.position)>5.0:
				_fail("Bounded rival remains on the road")
				return
			if rival.finished:
				break
		if not rival.finished or rival.active or rival.elapsed>120.0:
			_fail("Both authored courses finish")
			return
		rival.configure(start,trial.gates())
		rival.stop()
		prior=rival.position
		rival.tick(1.0/60.0,false)
		if rival.active or rival.position!=prior:
			_fail("Cancelled rival must stop")
			return
	print("CIRCUIT_RIVAL_SMOKE PASS")
	quit(0)

func _verify_trial(start:Vector2)->bool:
	var trial:=Trial.new()
	for invalid_delta in [0.0,-0.01,0.101,NAN,INF]:
		if not trial.start(start,1,100.0,0.0):
			_fail("Invalid update fixture start")
			return false
		if trial.tick(invalid_delta,start,1,100.0)!="INVALID UPDATE" or trial.active or trial.vehicle_id!=0:
			_fail("Invalid physics update must abandon the run")
			return false
		if trial.tick(0.05,start,1,100.0)!="" or trial.result!="INVALID UPDATE":
			_fail("Inactive run must not advance")
			return false
	if not trial.start(start,1,100.0,0.0):
		_fail("Route reset fixture start")
		return false
	var gates:=trial.gates()
	var first:Vector2=gates[0]
	if trial.tick(0.05,first,1,100.0)!="ROUTE RESET" or trial.index!=0:
		_fail("Teleport must not credit a gate")
		return false
	if not trial.start(start,1,100.0,0.0):
		_fail("Full route fixture start")
		return false
	var at:=start
	for gate in gates:
		var target:Vector2=gate
		while at.distance_to(target)>0.001 and trial.active:
			at=at.move_toward(target,1.0)
			trial.tick(0.05,at,1,100.0)
	if trial.active or trial.result!="COMPLETE" or trial.index!=gates.size() or trial.vehicle_id!=0:
		_fail("Both circuits must remain completable in valid sequential updates")
		return false
	if not trial.start(start,1,100.0,0.0):
		_fail("Timeout fixture start")
		return false
	for step in range(ceili(trial.time_limit()/0.1)+2):
		if not trial.active:
			break
		trial.tick(0.1,start,1,100.0)
	if trial.active or trial.result!="TIME EXPIRED" or trial.index!=0:
		_fail("Stationary run must expire without a checkpoint")
		return false
	return true

func _fail(reason:String)->void:
	push_error("CIRCUIT_RIVAL_SMOKE: "+reason)
	quit(1)
