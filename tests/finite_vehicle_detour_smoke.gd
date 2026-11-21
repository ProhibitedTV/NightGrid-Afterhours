extends SceneTree
const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")
class SignalFixture extends Node:
	func approach_speed_cap(_at:Vector3,_direction:Vector3,cap:float)->float:
		return cap
class FleetFixture extends Node:
	func headway_speed_cap(_car:CharacterBody3D,_direction:Vector3,cap:float)->float:
		return cap
func _initialize() -> void:
	create_timer(30.0,true,false,true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")
func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("FINITE_DETOUR: "+message)
		quit(1)
	return ok
func _verify()->void:
	var signals := SignalFixture.new()
	var fleet := FleetFixture.new()
	root.add_child(signals)
	root.add_child(fleet)
	var car = TrafficVehicle.new()
	root.add_child(car)
	var ordinary: Array[Vector3] = [Vector3(0,1,0),Vector3(30,1,0),Vector3(30,1,30),Vector3(0,1,30)]
	car.setup(ordinary,1,Vector3(5,1,0),false,"fixture",Color.WHITE,signals,fleet)
	car.set_physics_process(false)
	var path: Array[Vector3] = [Vector3(5,1,0),Vector3(10,1,0),Vector3(10,1,30),Vector3(5,1,30)]
	var allow := func(_points:Array[Vector3],_rejoin:int)->bool: return true
	var deny := func(_points:Array[Vector3],_rejoin:int)->bool: return false
	if not _check(not car.begin_finite_detour(path,3,deny),"mandatory certification"):
		return
	car.buses = true
	if not _check(not car.begin_finite_detour(path,3,allow),"bus cannot divert"):
		return
	car.buses = false
	car.speed = 3.0
	if not _check(not car.begin_finite_detour(path,3,allow),"moving handoff rejected"):
		return
	car.speed = 0.0
	var at:Vector3 = car.global_position
	if not _check(car.begin_finite_detour(path,3,allow) and car.global_position==at and car.route==ordinary,"accepted opt-in path without teleport or loop mutation"):
		return
	var interrupted:Dictionary = car.snapshot()
	if not _check(bool(interrupted["detour_interrupted"]),"interrupted snapshot flagged"):
		return
	# Controlled advancement through actual car controller targets. Fixture
	# places at each reached waypoint; this is not autonomous road evidence.
	for i in range(1,path.size()):
		car.global_position = path[i]
		car.call("_physics_process",0.0)
		if not _check(car.global_position==path[i],"handoff callback does not teleport"):
			return
	if not _check(not car.finite_detour_active() and car.next_index==3 and car.laps==0,"finite completion rejoins original loop exactly once"):
		return
	car.apply_snapshot(interrupted)
	car.call("_physics_process",0.016)
	if not _check(not car.finite_detour_active() and car.velocity==Vector3.ZERO and car.speed==0.0,"interrupted save fails closed"):
		return
	interrupted.erase("detour_interrupted")
	car.apply_snapshot(interrupted)
	if not _check(not bool(car.get("_detour_hold")),"legacy saves remain normal"):
		return
	print("FINITE_VEHICLE_DETOUR_SMOKE PASS: certified handoff, transit protection, finite completion and restore guard")
	quit(0)
