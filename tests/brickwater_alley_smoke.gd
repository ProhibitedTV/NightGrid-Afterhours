extends SceneTree
const Alley=preload("res://scripts/brickwater_alley.gd")
func _initialize()->void:
	create_timer(40.0,true,false,true).timeout.connect(func()->void: quit(1))
	call_deferred("_verify")
func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("BRICKWATER_ALLEY: "+message)
		quit(1)
	return ok
func _verify()->void:
	var world:Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var city:Node3D=world.get("city_details")
	var block:=Alley.PILOT_BLOCK
	var center:=Vector3((float(block.x)+0.5)*58.0,0,(float(block.y)+0.5)*58.0)
	city.call("set_focus",center)
	await physics_frame
	await physics_frame
	var chunk:Node3D=city.get("_loaded")[block]
	var alley:Node3D=chunk.get_node_or_null("BrickwaterServiceAlley")
	if not _check(alley!=null,"fixed authored parcel"):
		return
	var floor_body:=alley.get_node("AlleyWalkableFloor") as StaticBody3D
	var dumpster:=alley.get_node("ClosedSteelDumpster") as StaticBody3D
	var pavement:=alley.get_node("PhotographicAlleyPavement") as MeshInstance3D
	var model:=dumpster.get_node("BeveledSteelBody") as MeshInstance3D
	if not _check(floor_body.get_child_count()==3 and model.mesh is ArrayMesh and dumpster.get_child_count()>=9,"real floor, shaped art and solid dumpster"):
		return
	if not _check((pavement.material_override as StandardMaterial3D).albedo_texture!=null and (model.material_override as StandardMaterial3D).normal_enabled,"photo materials"):
		return
	var space:=world.get_world_3d().direct_space_state
	var x:float=(float(alley.get("left_wall"))+float(alley.get("right_wall")))*0.5
	var ray:=PhysicsRayQueryParameters3D.create(center+Vector3(x,2,-5),center+Vector3(x,-0.3,-5),1)
	var hit:=space.intersect_ray(ray)
	if not _check(not hit.is_empty() and hit["collider"]==floor_body and absf(float(hit["position"].y)-Alley.FLOOR_Y)<0.005,"physical floor follows visible paving"):
		return
	var pos:=dumpster.global_position
	var contact:=space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3(1.0,0.7,0),pos+Vector3(0,0.7,0),1))
	if not _check(not contact.is_empty() and contact["collider"]==dumpster,"closed bin resists side contact"):
		return
	var passage:float=float(alley.get("right_wall"))-float(alley.get("left_wall"))-1.50
	if not _check(passage>=2.5,"wall-side bin leaves continuous passage"):
		return
	for item in ["ReusedPowerCabinet","ReusedRustedWasteCan"]:
		var prop:=alley.get_node_or_null(item) as StaticBody3D
		if not _check(prop!=null and prop.get_node_or_null("MeasuredScanCollider") is CollisionShape3D,"shared scanned prop with collision: "+item):
			return
		var meshes:Array[MeshInstance3D]=[]
		alley.call("_collect",prop,meshes)
		var visible_count:=0
		for mesh in meshes:
			if mesh.visible:
				visible_count+=1
				var material:=mesh.mesh.surface_get_material(0) as StandardMaterial3D
				if not _check(material!=null and material.albedo_texture!=null and material.normal_enabled,"existing photographic material"):
					return
		if not _check(visible_count==(4 if item=="ReusedRustedWasteCan" else 1),"one complete selected variant"):
			return
	print("BRICKWATER_ALLEY_SMOKE PASS: physical floor, closed model, photo materials, clear path")
	quit(0)
