extends RefCounted
## Fixed road-side loading stops at existing civic warehouses.
const MAX_RUNS=100000
const RADIUS=5.5
const ROUTES=[
	{"from":"freight_control","to":"cold_storage","pickup":Vector2(-213.5,-170.75),"drop":Vector2(-192.5,119.25),"reward":65,"name":"Cold Chain transfer"},
	{"from":"cold_storage","to":"union_supply","pickup":Vector2(-192.5,119.25),"drop":Vector2(76.5,177.25),"reward":75,"name":"Cooperative supplies"},
	{"from":"union_supply","to":"freight_control","pickup":Vector2(76.5,177.25),"drop":Vector2(-213.5,-170.75),"reward":90,"name":"Return freight"}
]
var active:=false
var sequence:=0
var vehicle_id:=0
var route:Dictionary={}
var previous:=Vector2.ZERO
var meters:=0.0

static func offer(completed:int)->Dictionary:
	if completed<0 or completed>=MAX_RUNS:
		return {}
	return ROUTES[completed%ROUTES.size()].duplicate()

static func near(at:Vector2,target:Vector2)->bool:
	return at.is_finite() and at.distance_to(target)<=RADIUS

func begin(completed:int,at:Vector2,id:int,condition:float,speed:float)->bool:
	var next:=offer(completed)
	if active or next.is_empty() or id<=0 or not near(at,next["pickup"]) or not roadworthy(condition,speed):
		return false
	active=true
	sequence=completed+1
	vehicle_id=id
	route=next
	previous=at
	meters=0.0
	return true

static func roadworthy(condition:float,speed:float)->bool:
	return is_finite(condition) and condition>18.0 and is_finite(speed) and absf(speed)<=2.0

func cancel()->void:
	active=false
	vehicle_id=0
	route={}

func tick(at:Vector2,id:int,condition:float,delta:float)->bool:
	if not active:
		return false
	if not at.is_finite() or id!=vehicle_id or not is_finite(condition) or condition<=18.0 or not is_finite(delta) or delta<=0.0 or delta>.1 or at.distance_to(previous)>maxf(2.0,delta*100.0):
		cancel()
		return false
	meters+=at.distance_to(previous)
	previous=at
	return true

func ready_to_deliver(at:Vector2,id:int,condition:float,speed:float)->bool:
	return active and id==vehicle_id and roadworthy(condition,speed) and near(at,route["drop"]) and at.distance_to(previous)<=2.0 and meters>=Vector2(route["pickup"]).distance_to(route["drop"])-2.0*RADIUS
