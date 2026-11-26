extends RefCounted
## Bounded non-contact racing rival, separate from the authored pace schedule.
## The world supplies live obstruction observations. No traffic leases,
## player input, collision body, save state, or financial settlement.
const MAX_SPEED=15.5
const CORNER_SPEED=6.0
const LANE=2.6
var points:Array[Vector2]=[]
var index:=0
var position:=Vector2.ZERO
var heading:=Vector2.RIGHT
var speed:=0.0
var elapsed:=0.0
var travel:=0.0
var steer:=0.0
var finished:=false
var active:=false

func configure(start:Vector2,gates:Array)->bool:
	points.clear()
	active=false
	finished=false
	index=0
	speed=0.0
	elapsed=0.0
	travel=0.0
	steer=0.0
	if not start.is_finite() or gates.is_empty() or gates.size()>24:
		return false
	var center:Array[Vector2]=[start]
	for gate in gates:
		if not gate is Vector2 or not gate.is_finite() or gate.distance_to(center[-1])<10.0:
			return false
		center.append(gate)
	for i in range(center.size()):
		var incoming:Vector2=(center[i]-center[i-1]).normalized() if i>0 else (center[1]-center[0]).normalized()
		var outgoing:Vector2=(center[i+1]-center[i]).normalized() if i<center.size()-1 else incoming
		var right:=Vector2(-incoming.y,incoming.x)
		var next_right:=Vector2(-outgoing.y,outgoing.x)
		var offset:=right if incoming.dot(outgoing)>.99 else (right+next_right)
		points.append(center[i]+offset*LANE)
	position=points[0]
	heading=(points[1]-points[0]).normalized()
	index=1
	active=true
	return true

func desired_heading()->Vector2:
	if active and index<points.size():
		var offset:=points[index]-position
		if offset.length_squared()>.000001:
			return offset.normalized()
	return heading

func tick(delta:float,blocked:bool)->void:
	if not active or not is_finite(delta) or delta<=0.0 or delta>.1:
		return
	elapsed+=delta
	travel=0.0
	steer=0.0
	var distance:=position.distance_to(points[index])
	var target:=CORNER_SPEED if distance<12.0 and index<points.size()-1 else MAX_SPEED
	# An obstruction is a hard visual stop: never advance a non-contact
	# model through a detected solid just to maintain a target time.
	speed=0.0 if blocked else move_toward(speed,target,delta*(4.0 if target>speed else 9.0))
	if speed<=0.0:
		return
	var direction:=desired_heading()
	if direction.length_squared()>.5:
		steer=clampf(heading.angle_to(direction)*2.0,-1.0,1.0)
		heading=direction
	var prior:=position
	position=position.move_toward(points[index],speed*delta)
	travel=position.distance_to(prior)
	if position.distance_to(points[index])<.001:
		index+=1
		if index>=points.size():
			active=false
			finished=true

func stop()->void:
	active=false
	speed=0.0
