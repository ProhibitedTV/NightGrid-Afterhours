extends SceneTree
const Wheel = preload("res://scripts/traffic_wheel_mesh.gd")
func _initialize()->void:
	create_timer(35.0,true,false,true).timeout.connect(func()->void:quit(1))
	call_deferred("_verify")
func _check(ok:bool,msg:String)->bool:
	if not ok:
		push_error("TRAFFIC_WHEEL_MOTION: "+msg)
		quit(1)
	return ok
func _verify()->void:
	var scene:PackedScene=load("res://scenes/main.tscn")
	var world:Node3D=scene.instantiate()
	root.add_child(world)
	await process_frame
	var traffic:Node=world.get("traffic")
	var fleet:Array=traffic.get("fleet")
	var count:=0
	for actor in fleet:
		actor.set_physics_process(false)
		var radius:=0.44 if actor.buses else 0.35
		var hubs:Array=actor.get("_wheel_hubs")
		if not _check(hubs.size()==4,"actual four rims"):
			return
		for i in range(4):
			var hub:MeshInstance3D=hubs[i]
			var tire:MeshInstance3D=actor.get_node("TrafficTire_%d"%i)
			if not _check(hub.mesh==Wheel.rim(radius) and tire.mesh==Wheel.tire(radius) and hub.mesh.get_surface_count()==1,"shared size resources and one rim surface"):
				return
			if not _check(hub.mesh.get_aabb().size.y<0.30 and hub.mesh.get_aabb().size.x<radius*2.0,"rim within tire"):
				return
		var old:Dictionary=actor.snapshot()
		actor.apply_snapshot(old)
		var before:Basis=hubs[0].basis
		actor.call("_roll_wheels",Vector3.ZERO)
		if not _check(hubs[0].basis.is_equal_approx(before),"stopped wheel"):
			return
		var forward:Vector3=-actor.global_transform.basis.z
		actor.call("_roll_wheels",actor.global_transform.basis.x*radius)
		if not _check(hubs[0].basis==before,"lateral slide keeps identical rim transform"):
			return
		actor.call("_roll_wheels",forward*radius)
		if not _check(is_equal_approx(float(actor.get("_wheel_phase")),1.0) and not hubs[0].basis.is_equal_approx(before),"one radian for radius distance"):
			return
		var running:Basis=hubs[0].basis
		# A contact point initially at the bottom of the wheel must rotate
		# toward the back of the car as the vehicle drives forward.
		var contact_local:=before.inverse()*Vector3.DOWN
		if not _check((running*contact_local).z>0.0,"correct forward rolling direction"):
			return
		actor.call("_roll_wheels",-forward*radius)
		if not _check(hubs[0].basis.is_equal_approx(before),"reverse travel unwinds phase"):
			return
		actor.call("_roll_wheels",forward*radius)
		actor.call("_roll_wheels",forward*100.0)
		if not _check(hubs[0].basis.is_equal_approx(running),"teleport ignored"):
			return
		actor.apply_snapshot(old)
		if not _check(hubs[0].basis.is_equal_approx(before) and actor.snapshot()==old,"motion phase visual only"):
			return
		count+=1
	if not _check(count==29,"entire live fleet"):
		return
	print("TRAFFIC_WHEEL_MOTION_SMOKE PASS: 116 shared modeled rims, displacement rotation, no save mutation")
	quit(0)
