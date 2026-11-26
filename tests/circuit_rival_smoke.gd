extends SceneTree
const Trial=preload("res://scripts/driving_trial.gd")
const Rival=preload("res://scripts/circuit_rival.gd")
const Route=preload("res://scripts/street_route.gd")

func _initialize()->void:
	for course in [Trial.SOUTH,Trial.BRICK]:
		var trial:=Trial.new()
		trial.course_id=course
		var start:Vector2=Trial.BRICK_START if course==Trial.BRICK else Trial.START
		var rival:=Rival.new()
		if not rival.configure(start,trial.gates()):
			_fail("Rival course configuration")
			return
		var prior:=rival.position
		for step in range(120):
			rival.tick(1.0/60.0,true)
		if rival.position!=prior or rival.speed!=0.0:
			_fail("Blocked rival must not advance")
			return
		for step in range(7200):
			prior=rival.position
			rival.tick(1.0/60.0,false)
			if rival.position.distance_to(prior)>Rival.MAX_SPEED/60.0+.001 or Route.road_anchor(rival.position).distance_to(rival.position)>5.0:
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

func _fail(reason:String)->void:
	push_error("CIRCUIT_RIVAL_SMOKE: "+reason)
	quit(1)
