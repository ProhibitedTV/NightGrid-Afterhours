extends SceneTree
const Plan = preload("res://scripts/world_plan.gd")
func _initialize()->void:
	create_timer(40.0,true,false,true).timeout.connect(func()->void: quit(1))
	call_deferred("_verify")
func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("VESPER_WINDOWS: "+message)
		quit(1)
	return ok
func _verify()->void:
	var packed:PackedScene = load("res://scenes/main.tscn")
	var world:Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var city:Node3D = world.get("city_details")
	city.call("set_focus",Vector3(-145,0,-145))
	var chunks:Dictionary = city.get("_loaded")
	var chunk:Node3D = chunks[Vector2i(-3,-3)]
	var manifest:Dictionary = city.get("world_manifest")
	var lots:Array = manifest["blocks"]["-3,-3"]
	for i in range(2):
		var windows := chunk.get_node_or_null("VesperWindowAssembly_%d" % i) as MeshInstance3D
		var expected := (int(float(lots[i]["height"])/3.3)-2)*4
		if not _check(windows!=null and windows.mesh is ArrayMesh and int(windows.get_meta("window_count"))==expected,"actual pilot windows and saved profile"):
			return
		if not _check(windows.mesh.get_surface_count()>=2 and windows.mesh.get_surface_count()<=3 and windows.get_child_count()==0,"bounded material surfaces and no per-window nodes"):
			return
		var bounds := windows.mesh.get_aabb()
		if not _check(bounds.position.z< -0.20 and bounds.end.z<0.0 and is_equal_approx(windows.position.z,-145.0-Plan.PUBLIC_FACADE_SETBACK),"projecting frames stay outside unchanged facade"):
			return
	var bodies := 0
	for child in chunk.get_children():
		if child is StaticBody3D:
			bodies += 1
	if not _check(bodies==2,"existing two parcel shell bodies retained"):
		return
	print("VESPER_WINDOW_ASSEMBLY_SMOKE PASS: two real lots, framed glazing, bounded surfaces and original collision")
	quit(0)
