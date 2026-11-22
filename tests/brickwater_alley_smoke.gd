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
	var authored := alley.get_node_or_null("AuthoredStreetProps") as Node3D
	if not _check(authored != null, "authored asset layer installed"):
		return
	for item in ["DeliveryCart", "DeliveryCrate", "DeliveryCarton", "RefuseBagA", "RefuseBagB", "ReturnCrate", "ReturnCarton"]:
		var body := authored.get_node_or_null(item) as StaticBody3D
		if not _check(body != null, "ground prop " + item):
			return
		var view := body.get_node("AuthoredMesh") as MeshInstance3D
		var bounds := view.mesh.get_aabb()
		var shape := (body.get_node("BoundsCollider") as CollisionShape3D).shape as BoxShape3D
		var m := view.mesh.surface_get_material(0) as StandardMaterial3D
		if not _check(m != null and m.albedo_texture != null and m.normal_enabled, "authored PBR " + item):
			return
		if not _check(absf(bounds.position.y + view.position.y) < 0.001 and shape.size.is_equal_approx(bounds.size), "ground contact and collider " + item):
			return
		var p := body.global_position
		var prop_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * (bounds.size.y + 0.2), p + Vector3.UP * 0.03, 1))
		if not _check(not prop_hit.is_empty() and prop_hit["collider"] == body, "physical contact " + item):
			return
	for item in ["WestServiceLamp", "EastServiceLamp"]:
		var fixture := authored.get_node(item) as Node3D
		var view := fixture.get_node("CagedFixture") as MeshInstance3D
		var light := fixture.get_node("PracticalLight") as OmniLight3D
		if not _check(view.mesh != null and fixture.position.y + view.mesh.get_aabb().position.y > 2.9 and light.omni_range <= 5.0, "practical caged lamp " + item):
			return
	var pipe_parts := 0
	for child in authored.get_children():
		if child is MeshInstance3D and child.has_meta("source_component"):
			pipe_parts += 1
			if not _check(child.mesh != null, "selected pipe mesh"):
				return
	if not _check(pipe_parts == 14, "only selected modular pipe pieces"):
		return
	for z in [-10.0, -5.0, 0.0, 5.0, 7.5]:
		var ray_start := center + Vector3(x, 0.9, z)
		var clear := space.intersect_ray(PhysicsRayQueryParameters3D.create(ray_start, ray_start + Vector3(0, 0, 0.4), 1))
		if not _check(clear.is_empty(), "centerline remains clear"):
			return
	var architecture := alley.get_node_or_null("AuthoredUpperArchitecture") as Node3D
	if not _check(architecture != null, "upper architecture installed"):
		return
	for label in ["WestApartmentFront", "EastApartmentFront"]:
		var face := architecture.get_node(label) as Node3D
		if not _check(face.get_child_count() == 30, "two floors with five complete bays"):
			return
		for child in face.get_children():
			var view := child as MeshInstance3D
			if not _check(view != null and view.mesh != null and view.position.y >= 4.8, "selected facade mesh and overhead clearance"):
				return
	for label in ["WestElectricalTrunk", "EastElectricalTrunk"]:
		var trunk := architecture.get_node(label) as Node3D
		if not _check(trunk.get_child_count() == 14, "bounded cable trunk with two terminal boxes"):
			return
		for child in trunk.get_children():
			var view := child as MeshInstance3D
			if not _check(view != null and view.mesh != null and absf(view.transform.basis.determinant() - 1.0) < 0.001, "cable source and proper orientation"):
				return
	var escape := architecture.get_node("WestEmergencyEscape") as Node3D
	if not _check(escape.get_child_count() == 5, "selected escape assembly"):
		return
	for child in escape.get_children():
		var view := child as MeshInstance3D
		if not _check(view != null and view.mesh != null, "authored fire escape mesh"):
			return
		var bounds: AABB = view.transform * view.mesh.get_aabb()
		if not _check(bounds.position.y > 4.1, "escape remains overhead"):
			return
	var surface_pass := alley.get_node_or_null("AlleySurfacePass") as Node3D
	if not _check(surface_pass != null, "local damp surface layer"):
		return
	var damp := pavement.material_override as StandardMaterial3D
	if not _check(damp.clearcoat_enabled and damp.roughness < 0.8 and damp.normal_texture != null, "damp photographic concrete"):
		return
	var dry := preload("res://scripts/material_library.gd").surface("PHOTO_SIDEWALK", Color("797870"))
	if not _check(dry != damp and is_equal_approx(dry.roughness, 1.0), "shared dry material unchanged"):
		return
	for item in ["DrainRunoff", "LowPointPuddle", "EntryRunoff"]:
		var patch := surface_pass.get_node_or_null(item) as MeshInstance3D
		if not _check(patch != null and patch.mesh is ArrayMesh and absf(patch.position.y - Alley.FLOOR_Y) < 0.02 and patch.get_child_count() == 0, "flush collision-free water " + item):
			return
		var wet := patch.material_override as StandardMaterial3D
		if not _check(wet.roughness < damp.roughness and wet.metallic == 0.0, "dielectric puddle response"):
			return
	for item in ["NightShiftRepairs", "JadeLaundry"]:
		var sign := surface_pass.get_node_or_null(item) as MeshInstance3D
		if not _check(sign != null and (sign.material_override as StandardMaterial3D).emission_enabled, "original mounted sign " + item):
			return
	print("BRICKWATER_ALLEY_SMOKE PASS: physical floor, authored ground props, upper facade, cable trunks, overhead escape")
	quit(0)
