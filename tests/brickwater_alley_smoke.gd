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
	var wet := pavement.material_override as ShaderMaterial
	if not _check(wet != null and wet.shader == Alley.WetSurface and (model.material_override as StandardMaterial3D).normal_enabled,"photo materials"):
		return
	for channel in ["concrete_albedo","concrete_normal","concrete_arm"]:
		if not _check(wet.get_shader_parameter(channel) is Texture2D,"bundled photographic channel "+channel):
			return
	if not _check((wet.get_shader_parameter("lane_size") as Vector2).is_equal_approx((pavement.mesh as PlaneMesh).size),"wet mask is anchored to real floor size"):
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
	var art := alley.get_node_or_null("BrickwaterWallArt") as Node3D
	if not _check(art != null and art.get_child_count() == 5, "five fixed wall art placements"):
		return
	var textures: Array[Texture2D] = []
	for child in art.get_children():
		var paint := child as MeshInstance3D
		if not _check(paint != null and paint.mesh is QuadMesh and paint.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "flat paint only"):
			return
		var mat := paint.material_override as StandardMaterial3D
		if not _check(mat != null and mat.albedo_texture != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and not mat.emission_enabled, "lit transparent artwork"):
			return
		if not _check(not textures.has(mat.albedo_texture), "unique artwork, not repeated identical tags"):
			return
		textures.append(mat.albedo_texture)
		var expected_wall: float = float(alley.get("left_wall")) if paint.position.x < x else float(alley.get("right_wall"))
		var inward := Vector3.RIGHT if paint.position.x < x else Vector3.LEFT
		if not _check(absf(paint.position.x - expected_wall) < 0.02 and paint.transform.basis.z.normalized().dot(inward) > 0.99, "flush placement and front faces lane"):
			return
		# Verify each artwork center and corners with actual shell ray contact.
		for local in [Vector3.ZERO, Vector3(-0.46,-0.46,0), Vector3(0.46,-0.46,0), Vector3(-0.46,0.46,0), Vector3(0.46,0.46,0)]:
			var at: Vector3 = paint.to_global(local)
			var wall_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + inward * 0.04, at - inward * 0.10, 1))
			if not _check(not wall_hit.is_empty() and absf(float(wall_hit["position"].x) - (alley.global_position.x + expected_wall)) < 0.025, "wall behind artwork, not floating or crossing a corner"):
				return
	for which in range(2):
		var envelope := chunk.get_node_or_null("BrickwaterFacade_%d"%which) as Node3D
		if not _check(envelope != null and int(envelope.get_meta("window_bays",0))>=12,"real modular envelope at each saved parcel"):
			return
		var backing := envelope.get_node_or_null("RecessBacking") as MeshInstance3D
		if not _check(backing != null and is_equal_approx(absf(backing.position.x),absf(float(envelope.get_meta("saved_width"))*0.5-0.36)),"window backing behind facade"):
			return
		var walls := 0
		var windows := 0
		for node in envelope.get_children():
			if node is MultiMeshInstance3D:
				if str(node.name).begins_with("wall_window"):
					walls += node.multimesh.instance_count
				elif str(node.name).begins_with("window_centered"):
					windows += node.multimesh.instance_count
				if not _check(node.multimesh.mesh is ArrayMesh,"source modular geometry, not a cube"):
					return
		if not _check(walls==windows and walls==int(envelope.get_meta("window_bays")),"one matched cutout and actual window per bay"):
			return
	var gold := alley.get_node_or_null("BrickwaterGoldArt") as Node3D
	if not _check(gold != null and gold.get_child_count()==18,"curated authored art layer (no asset display scenes)"):
		return
	var lit := 0
	for item in gold.get_children():
		var view := item.get_node_or_null("AuthoredMesh") as MeshInstance3D
		if not _check(view != null and view.mesh is ArrayMesh and view.mesh.get_surface_count()>0,"actual imported geometry "+str(item.name)):
			return
		if item.get_node_or_null("PracticalAmber") is OmniLight3D:
			lit += 1
		if item is StaticBody3D:
			var shape := item.get_child(1) as CollisionShape3D
			if not _check(shape != null and shape.shape is BoxShape3D,"reachable authored art collision"):
				return
			var bounds := view.mesh.get_aabb()
			if not _check((shape.shape as BoxShape3D).size.is_equal_approx(bounds.size*view.scale),"collider matches authored asset bounds"):
				return
	if not _check(lit==2,"two physically located practical light sources"):
		return
	var overhead := alley.get_node_or_null("BrickwaterOverhead") as Node3D
	if not _check(overhead != null and overhead.get_child_count()==3,"one authored escape and two connected spans"):
		return
	var escape := overhead.get_node_or_null("WestServiceFireEscape") as Node3D
	if not _check(escape != null and escape.get_child_count()==5,"paired steel landings, rails and stair"):
		return
	for part in escape.get_children():
		var mesh_part := part as MeshInstance3D
		if not _check(mesh_part != null and mesh_part.mesh is ArrayMesh and mesh_part.get_child(0) is StaticBody3D,"authored steel geometry and actual collision"):
			return
		var collider := mesh_part.get_node("SteelCollision").get_child(0) as CollisionShape3D
		if not _check(collider.shape is ConcavePolygonShape3D,"open steel collision instead of solid wall"):
			return
		var bounds := mesh_part.transform * mesh_part.mesh.get_aabb()
		if not _check(bounds.position.y+escape.position.y > 4.0,"escape remains clear of street actors"):
			return
	for span in overhead.get_children():
		if span == escape:
			continue
		var west := span.get_node("WestWallAnchor") as Node3D
		var east := span.get_node("EastWallAnchor") as Node3D
		var bundle := span.get_node("ContinuousCableBundle") as MeshInstance3D
		var bounds := bundle.mesh.get_aabb()
		if not _check(west.get_child_count()==3 and east.get_child_count()==3 and absf(bounds.position.x-west.position.x)<0.03 and absf(bounds.end.x-east.position.x)<0.03 and bounds.position.y>4.9,"each continuous cable span reaches both wall anchors above street"):
			return
	print("BRICKWATER_ALLEY_SMOKE PASS: physical floor, closed model, photo materials, clear path")
	quit(0)
