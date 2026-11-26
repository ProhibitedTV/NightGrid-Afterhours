extends RefCounted
## Single authored city driving challenge. Only sequential on-road gates,
## fixed-physics time and the same occupied car may complete a run.
const START = Vector2(29,174)
const GATES = [Vector2(58,174),Vector2(58,145),Vector2(58,116),Vector2(29,116),Vector2(0,116),Vector2(0,145),Vector2(0,174),START]
const LIMIT = 90.0
const RADIUS = 7.0
# Includes lane width and a small allowance for turning at intersections.
const ROAD_CORRIDOR = 7.5
const APPROACH_TAIL = 10.0
const RECEIPT = "driving:southworks_circuit"
const REWARD = 90
const BRICK_START = Vector2(-145,116)
const BRICK_GATES = [Vector2(-116,116),Vector2(-58,116),Vector2(-58,87),Vector2(-58,58),Vector2(-116,58),Vector2(-174,58),Vector2(-174,87),Vector2(-174,116),BRICK_START]
const BRICK_LIMIT = 120.0
const BRICK_RECEIPT = "driving:brickwater_loop"
const BRICK_REWARD = 140
const SOUTH = "southworks"
const BRICK = "brickwater"
const SOUTH_PACE = 34.0
const BRICK_PACE = 48.0
var course_id := SOUTH
var active := false
var index := 0
var elapsed := 0.0
var last_gate_elapsed := 0.0
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

## Authored reference pace, not a simulated traffic participant or recorded replay.
func pace_time()->float:
	return BRICK_PACE if course_id==BRICK else SOUTH_PACE

func pace_pose(seconds:float)->Dictionary:
	if not is_finite(seconds):
		return {}
	var checkpoints:=gates()
	var origin:=BRICK_START if course_id==BRICK else START
	var distance:=0.0
	var prior:=origin
	for gate in checkpoints:
		distance+=prior.distance_to(gate)
		prior=gate
	var travel:=clampf(seconds/pace_time(),0.0,1.0)*distance
	prior=origin
	for i in range(checkpoints.size()):
		var gate:Vector2=checkpoints[i]
		var length:=prior.distance_to(gate)
		if travel<=length or i==checkpoints.size()-1:
			var heading:Vector2=(gate-prior).normalized()
			return {"position":prior.lerp(gate,clampf(travel/length,0.0,1.0)),"heading":heading}
		travel-=length
		prior=gate
	return {}

func pace_split()->float:
	# Compare the time at the last completed gate against the reference
	# schedule for that gate. It is an advisory split, never a payout gate.
	if index<=0:
		return 0.0
	var checkpoints:=gates()
	var prior:=BRICK_START if course_id==BRICK else START
	var total:=0.0
	var passed:=0.0
	for i in range(checkpoints.size()):
		var gate:Vector2=checkpoints[i]
		total+=prior.distance_to(gate)
		if i<index:
			passed=total
		prior=gate
	return last_gate_elapsed-pace_time()*passed/total

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
	last_gate_elapsed=0.0
	vehicle_id=id
	previous=at
	result=""
	return true

func stop(reason:String)->void:
	active=false
	result=reason
	vehicle_id=0

static func _segment_distance(at:Vector2,a:Vector2,b:Vector2)->float:
	var axis:=b-a
	var fraction:=clampf((at-a).dot(axis)/maxf(axis.length_squared(),.0001),0.0,1.0)
	return at.distance_to(a+axis*fraction)

func on_course(at:Vector2)->bool:
	if not at.is_finite() or index<0 or index>=gates().size():
		return false
	var checkpoints:=gates()
	var origin:=BRICK_START if course_id==BRICK else START
	var from:Vector2=origin if index==0 else checkpoints[index-1]
	var to:Vector2=checkpoints[index]
	if _segment_distance(at,from,to)<=ROAD_CORRIDOR:
		return true
	# A gate can be credited on entry to its radius, before reaching the
	# exact intersection center. Preserve the short incoming approach,
	# not the entire previous leg or a neighboring parallel road.
	if index>0:
		var previous_gate:Vector2=origin if index==1 else checkpoints[index-2]
		var tail:=from.move_toward(previous_gate,APPROACH_TAIL)
		if _segment_distance(at,tail,from)<=ROAD_CORRIDOR:
			return true
	return false

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
	if not on_course(at):
		stop("OFF COURSE")
		return result
	previous=at
	elapsed+=delta
	if elapsed>=time_limit():
		stop("TIME EXPIRED")
		return result
	var checkpoints:=gates()
	if at.distance_to(checkpoints[index])<=RADIUS:
		index+=1
		last_gate_elapsed=elapsed
		if index==checkpoints.size():
			stop("COMPLETE")
			return result
		return "GATE"
	return ""

func status(at:Vector2)->String:
	if not active:
		return ""
	var next:Vector2=gates()[index]
	var split := " • SPLIT %+.1fs"%pace_split() if index>0 else ""
	return "%s / %d/%d • %.1fs elapsed • %ds left • %dm %s%s"%[name_for(course_id).to_upper(),index,gates().size(),elapsed,ceili(time_limit()-elapsed),roundi(at.distance_to(next)),preload("res://scripts/navigation_waypoint.gd").bearing(at,next),split]
