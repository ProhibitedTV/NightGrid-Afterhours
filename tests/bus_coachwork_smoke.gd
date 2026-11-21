extends SceneTree
const Coachwork = preload("res://scripts/bus_coachwork.gd")
func _initialize()->void:
	create_timer(35.0,true,false,true).timeout.connect(func()->void: quit(1))
	call_deferred("_verify")
func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("BUS_COACHWORK: "+message)
		quit(1)
	return ok
func _verify()->void:
	var packed:PackedScene = load("res://scenes/main.tscn")
	var world:Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var traffic:Node = world.get("traffic")
	var buses:Array = traffic.get("buses")
	if not _check(buses.size()==4 and (traffic.get("fleet") as Array).size()==29,"existing fleet"):
		return
	var meshes:Array[Mesh]=[]
	for bus in buses:
		var coach := bus.get_node_or_null("CityBusCoachwork") as MeshInstance3D
		if not _check(coach!=null and coach.mesh is ArrayMesh and coach.mesh.get_surface_count()==6,"one actual six-surface body mesh"):
			return
		var bounds := coach.mesh.get_aabb()
		if not _check(bounds.size.x<2.70 and bounds.size.y<2.85 and bounds.size.z<8.30,"body stays within existing collision envelope"):
			return
		if not _check(int(coach.get_meta("wheel_wells",0))==4 and Coachwork.ARCH_RADIUS>0.44 and Coachwork.AXLE_Y+Coachwork.ARCH_RADIUS<Coachwork.WAIST_Y,"four modeled wheel-well openings with tire clearance"):
			return
		# Inspect the actual charcoal skirt surface: its outer skin must
		# contain no vertices inside the tire profile at either axle.
		var vertices:PackedVector3Array = coach.mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
		var rim_vertices:=0
		for v in vertices:
			if absf(v.x)<1.10 or v.y<Coachwork.SKIRT_Y-0.001 or v.y>Coachwork.WAIST_Y+0.001:
				continue
			for axle in Coachwork.AXLES:
				if absf(v.z-axle)>Coachwork.ARCH_RADIUS+0.001:
					continue
				if not _check(Vector2(v.z-axle,v.y-Coachwork.AXLE_Y).length()>0.44,"skirt skin does not cross tire circle"):
					return
				rim_vertices+=1
		if not _check(rim_vertices>=48,"actual sampled arch vertices"):
			return
		var collider_count:=0
		var wheels:=0
		var rims:=0
		for child in bus.get_children():
			if child is CollisionShape3D:
				collider_count+=1
				if not _check((child.shape as BoxShape3D).size==Vector3(2.7,2.85,8.3),"unchanged collision"):
					return
			if child is MeshInstance3D and child.mesh is CylinderMesh:
				if not _check(is_equal_approx(child.position.y,-1.30),"wheel ride height aligned with route"):
					return
				wheels+=1
			if child is MeshInstance3D and str(child.name).begins_with("TrafficRim_"):
				if not _check(child.mesh is ArrayMesh and is_equal_approx(child.position.y,-1.30),"modeled rim at axle"):
					return
				rims+=1
		if not _check(collider_count==1 and wheels==4 and rims==4 and bus.is_boardable(),"original wheel count and bus boarding"):
			return
		meshes.append(coach.mesh)
	if not _check(meshes[0]==meshes[1] and meshes[2]==meshes[3] and meshes[0]!=meshes[2],"shared inner/outer livery resources"):
		return
	print("BUS_COACHWORK_SMOKE PASS: actual four buses, grouped shell, wheel height, shared liveries, collision and boarding")
	quit(0)
