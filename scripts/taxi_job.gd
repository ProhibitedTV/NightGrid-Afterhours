extends RefCounted
## Independent taxi fares on fixed street approaches to known venues.
## Caption-only passenger interaction until boarding and seated rigs are authored.
const MAX_RUNS=100000
const RADIUS=5.5
const ROUTES=[
	{"from":"lantern_cup","to":"helix_espresso","pickup":Vector2(-76.5,-170.75),"drop":Vector2(39.5,-170.75),"reward":35,"name":"Morning connection","rider":"Nina","request":"Helix Espresso, please. I have a shift to catch.","arrival":"Thanks. That beats missing another train."},
	{"from":"helix_espresso","to":"copper_cup","pickup":Vector2(39.5,-170.75),"drop":Vector2(-39.5,119.25),"reward":55,"name":"Independent commute","rider":"Eli","request":"Copper Cup. My band is rehearsing there.","arrival":"Perfect. See you at the next set."},
	{"from":"copper_cup","to":"lantern_cup","pickup":Vector2(-39.5,119.25),"drop":Vector2(-76.5,-170.75),"reward":55,"name":"Homeward fare","rider":"Sam","request":"Lantern Cup, please. I could use a quiet evening.","arrival":"Cheers. Keep the change."}
]
var active:=false
var sequence:=0
var vehicle_id:=0
var route:Dictionary={}
var previous:=Vector2.ZERO
var meters:=0.0
var elapsed:=0.0
const LIMIT=240.0
static func offer(completed:int)->Dictionary:
	if completed<0 or completed>=MAX_RUNS:
		return {}
	return ROUTES[completed%ROUTES.size()].duplicate()

## Venue frontages sit on the south sidewalk of the north road.
## Place the rider on the sidewalk, not the road loading point.
static func waiting_point(offer:Dictionary)->Vector3:
	var pickup:Vector2=offer["pickup"]
	return Vector3(pickup.x,.16,pickup.y+6.45)

static func near(at:Vector2,target:Vector2)->bool:
	return at.is_finite() and at.distance_to(target)<=RADIUS

static func roadworthy(condition:float,speed:float)->bool:
	return is_finite(condition) and condition>=50.0 and is_finite(speed) and absf(speed)<=1.0

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
	elapsed=0.0
	return true

func cancel()->void:
	active=false
	vehicle_id=0
	route={}

func tick(at:Vector2,id:int,condition:float,delta:float)->bool:
	if not active:
		return false
	if not at.is_finite() or id!=vehicle_id or not is_finite(condition) or condition<50.0 or not is_finite(delta) or delta<=0.0 or delta>.1 or at.distance_to(previous)>maxf(2.0,delta*100.0):
		cancel()
		return false
	elapsed+=delta
	if elapsed>=LIMIT:
		cancel()
		return false
	meters+=at.distance_to(previous)
	previous=at
	return true

func ready_to_arrive(at:Vector2,id:int,condition:float,speed:float)->bool:
	return active and id==vehicle_id and roadworthy(condition,speed) and near(at,route["drop"]) and at.distance_to(previous)<=2.0 and meters>=Vector2(route["pickup"]).distance_to(route["drop"])-2.0*RADIUS
