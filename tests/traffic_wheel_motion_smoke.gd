extends SceneTree
const Wheel = preload("res://scripts/traffic_wheel_mesh.gd")
const Coach = preload("res://scripts/civilian_car_coachwork.gd")
func _initialize() -> void:
	create_timer(45.0,true,false,true).timeout.connect(func()->void:quit(1))
	call_deferred("_verify")
func _check(ok:bool,msg:String)->bool:
	if not ok:
		push_error("TRAFFIC_WHEEL_MOTION_SMOKE: "+msg)
		quit(1)
	return ok
func _verify()->void:
	var scene:PackedScene=load("res://scenes/main.tscn")
	var world:Node3D=scene.instantiate()
	root.add_child(world)
	await process_frame
	paused=true
	var fleet:Array=world.get("traffic").get("fleet")
	var batches:Dictionary={}
	var tires_by_type:Dictionary={}
	for actor in fleet:
		var tire:MultiMeshInstance3D=actor.get_node("Tires")
		var rim:MultiMeshInstance3D=actor.get_node("Hubs")
		var radius:float=0.44 if actor.buses else Coach.TIRE_RADIUS
		if not _check(rim.multimesh.mesh==Wheel.rim(radius) and tire.multimesh.mesh==Wheel.tire(radius) and rim.multimesh.instance_count==4 and tire.multimesh.instance_count==4,"two four-instance batches, shared art"):
			return
		if not _check(not batches.has(rim.multimesh) and rim.multimesh.mesh.get_aabb().size.y<0.30,"independent phase and bounded rim geometry"):
			return
		batches[rim.multimesh]=true
		if tires_by_type.has(actor.buses) and not _check(tires_by_type[actor.buses]==tire.multimesh,"stationary tire batches remain shared"):
			return
		tires_by_type[actor.buses]=tire.multimesh
		actor.call("_reset_wheel_phase")
		var forward:Vector3=-actor.global_basis.z
		var before:Dictionary=actor.snapshot()
		actor.call("_roll_wheels",Vector3.ZERO)
		actor.call("_roll_wheels",actor.global_basis.x*radius)
		if not _check(is_zero_approx(float(actor.get("_wheel_phase"))),"stationary and lateral motion"):
			return
		actor.call("_roll_wheels",forward*radius)
		if not _check(is_equal_approx(float(actor.get("_wheel_phase")),1.0),"one radian per radius travelled"):
			return
		actor.call("_roll_wheels",forward*100.0)
		if not _check(is_equal_approx(float(actor.get("_wheel_phase")),1.0),"reject teleport"):
			return
		actor.call("_roll_wheels",-forward*radius)
		if not _check(is_zero_approx(float(actor.get("_wheel_phase"))) or is_equal_approx(float(actor.get("_wheel_phase")),TAU),"reverse unwinds"):
			return
		actor.call("_roll_wheels",forward*radius)
		actor.call("apply_snapshot",before)
		if not _check(is_zero_approx(float(actor.get("_wheel_phase"))) and actor.snapshot()==before,"restoration resets cosmetic phase"):
			return
	if not _check(fleet.size()==29 and batches.size()==29,"existing fleet and independent transform storage"):
		return
	paused=false
	world.queue_free()
	await process_frame
	print("TRAFFIC_WHEEL_MOTION_SMOKE PASS: shared rim meshes and tires, isolated rolling batches")
	quit(0)
