extends RefCounted
## Single authored city driving challenge. Only sequential on-road gates,
## fixed-physics time and the same occupied car may complete a run.
const START = Vector2(29,174)
const GATES = [Vector2(58,174),Vector2(58,145),Vector2(58,116),Vector2(29,116),Vector2(0,116),Vector2(0,145),Vector2(0,174),START]
const LIMIT = 90.0
const RADIUS = 7.0
const RECEIPT = "driving:southworks_circuit"
const REWARD = 90
const BRICK_START = Vector2(-145,116)
const BRICK_GATES = [Vector2(-116,116),Vector2(-58,116),Vector2(-58,87),Vector2(-58,58),Vector2(-116,58),Vector2(-174,58),Vector2(-174,87),Vector2(-174,116),BRICK_START]
const BRICK_LIMIT = 120.0
const BRICK_RECEIPT = "driving:brickwater_loop"
const BRICK_REWARD = 140
const SOUTH = "southworks"
const BRICK = "brickwater"
var course_id := SOUTH
var active := false
var index := 0
var elapsed := 0.0
var vehicle_id := 0
var previous := Vector2.ZERO
var result := ""

static func course_at(at:Vector2)->String:
	if not at.is_finite():
		return ""
	if at.distance_to(START)<=RADIUS:
		return SOUTH
	if at.distance_to(BRICK_START)<=RADIUS:
		return BRICK
	return ""

static func near_start(at:Vector2)->bool:
	return not course_at(at).is_empty()

static func name_for(id:String)->String:
	return "Brickwater Loop" if id==BRICK else "Southworks Circuit"

func gates()->Array:
	return BRICK_GATES if course_id==BRICK else GATES

func time_limit()->float:
	return BRICK_LIMIT if course_id==BRICK else LIMIT

func reward()->int:
	return BRICK_REWARD if course_id==BRICK else REWARD

func receipt()->String:
	return BRICK_RECEIPT if course_id==BRICK else RECEIPT

func start(at:Vector2,id:int,condition:float,speed:float)->bool:
	if active or id<=0 or not near_start(at) or not is_finite(condition) or condition<=18.0 or not is_finite(speed) or absf(speed)>2.0:
		return false
	course_id=course_at(at)
	active=true
	index=0
	elapsed=0.0
	vehicle_id=id
	previous=at
	result=""
	return true

func stop(reason:String)->void:
	active=false
	result=reason
	vehicle_id=0

func tick(delta:float,at:Vector2,id:int,condition:float)->String:
	if not active:
		return ""
	if not at.is_finite() or id!=vehicle_id or not is_finite(condition) or condition<=18.0:
		stop("ABANDONED")
		return result
	if not is_finite(delta) or delta<=0.0 or delta>0.1:
		return ""
	# Allow ample margin above the car's physical top speed, but never
	# credit a checkpoint after a teleport or save displacement.
	if at.distance_to(previous)>maxf(2.0,delta*100.0):
		stop("ROUTE RESET")
		return result
	previous=at
	elapsed+=delta
	if elapsed>=time_limit():
		stop("TIME EXPIRED")
		return result
	var checkpoints:=gates()
	if at.distance_to(checkpoints[index])<=RADIUS:
		index+=1
		if index==checkpoints.size():
			stop("COMPLETE")
			return result
		return "GATE"
	return ""

func status(at:Vector2)->String:
	if not active:
		return ""
	var next:Vector2=gates()[index]
	return "%s / %d/%d • %ds • %dm %s"%[name_for(course_id).to_upper(),index,gates().size(),ceili(time_limit()-elapsed),roundi(at.distance_to(next)),preload("res://scripts/navigation_waypoint.gd").bearing(at,next)]
