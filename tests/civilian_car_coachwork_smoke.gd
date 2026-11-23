extends SceneTree
const Coach = preload("res://scripts/civilian_car_coachwork.gd")
func _initialize()->void:
	create_timer(40.0,true,false,true).timeout.connect(func()->void:quit(1))
	call_deferred("_verify")
func _check(ok:bool,msg:String)->bool:
	if not ok:
		push_error("CIVILIAN_CAR_COACHWORK: "+msg)
		quit(1)
	return ok
func _verify()->void:
	var packed:PackedScene=load("res://scenes/main.tscn")
	var world:Node3D=packed.instantiate()
	root.add_child(world)
	await process_frame
	var traffic:Node=world.get("traffic")
	var fleet:Array=traffic.get("fleet")
	var colors:Dictionary={}
	var cars:=0
	for car in fleet:
		if car.buses:
			continue
		cars+=1
		var body:=car.get_node_or_null("CivilianCarCoachwork") as MeshInstance3D
		if not _check(body!=null and body.mesh is ArrayMesh and body.mesh.get_surface_count()==5,"actual grouped car body"):
			return
		var bounds:=body.mesh.get_aabb()
		if not _check(bounds.size.x<2.25 and bounds.size.y<1.55 and bounds.size.z<4.55,"body dimensions within original envelope"):
			return
		var wheels:=0
		var colliders:=0
		for child in car.get_children():
			if child is CollisionShape3D:
				colliders+=1
				if not _check((child.shape as BoxShape3D).size==Vector3(2.25,1.55,4.55),"unchanged collision"):
					return
			elif child is MultiMeshInstance3D and child.multimesh.mesh is CylinderMesh:
				for i in range(child.multimesh.instance_count):
					var at: Vector3 = child.multimesh.get_instance_transform(i).origin
					wheels += 1
					if not _check(is_equal_approx(at.y, Coach.AXLE_Y) and absf(at.x) + 0.15 < 1.125 and is_equal_approx(absf(at.z), 1.36), "corrected axle stance"):
						return
		if not _check(colliders==1 and wheels==8 and not car.is_boardable(),"original car gameplay"):
			return
		var color:String=car.paint.to_html(false)
		if colors.has(color) and not _check(colors[color]==body.mesh,"shared paint mesh"):
			return
		colors[color]=body.mesh
		var verts:PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var arch_vertices:=0
		for v in verts:
			if absf(v.x)<1.05 or v.y<Coach.SILL-0.001 or v.y>Coach.BELT+0.001:
				continue
			for axle in Coach.AXLES:
				if absf(v.z-axle)>Coach.ARCH_RADIUS+0.001:
					continue
				if not _check(Vector2(v.z-axle,v.y-Coach.AXLE_Y).length()>Coach.TIRE_RADIUS,"outer body clear of tire circle"):
					return
				arch_vertices+=1
		if not _check(arch_vertices>=48,"actual wheel arch samples"):
			return
	if not _check(cars==25 and fleet.size()==29 and colors.size()<=6,"preserved fleet and bounded paint meshes"):
		return
	print("CIVILIAN_CAR_COACHWORK_SMOKE PASS: 25 actual cars, shared body, wheel openings, existing collisions")
	quit(0)
