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
	if not _check((pavement.material_override as ShaderMaterial).get_shader_parameter("concrete_color")!=null and (model.material_override as StandardMaterial3D).normal_enabled,"photo materials"):
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
	if not _check(pipe_parts == 24 and authored.get_node("CabinetFeedCollision").get_child_count() == 2, "selected pipe pieces and fitted cabinet feed contact"):
		return
	var stock := authored.get_node("StackedReturns0") as StaticBody3D
	for index in range(3):
		var crate := authored.get_node("StackedReturns%d" % index) as StaticBody3D
		var bounds := (crate.get_node("BoundsCollider") as CollisionShape3D).shape as BoxShape3D
		if not _check(is_equal_approx(crate.position.y, stock.position.y + index * bounds.size.y), "return crates stack on scan bounds"):
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
	for lot in range(2):
		var envelope := chunk.get_node("BrickwaterEnvelope_%d" % lot) as Node3D
		var backing := envelope.get_node("WindowBacking") as MeshInstance3D
		var hall_face := envelope.get_node("GroundMasonry") as MeshInstance3D
		if not _check(absf(backing.position.x) + 0.37 < absf(hall_face.position.x) and backing.mesh is QuadMesh, "dark backing is behind the imported apertures"):
			return
		var wall_x := envelope.to_global(hall_face.position).x
		var art_x := alley.to_global(architecture.get_node("WestApartmentFront" if lot == 0 else "EastApartmentFront").position).x
		if not _check(is_equal_approx(wall_x, art_x) and chunk.get_node_or_null("PhotorealFrontage_-2_1_%d" % lot) == null, "single wall plane with no competing frontage"):
			return
	var workroom := architecture.get_node("NightShiftWorkroom") as Node3D
	var workroom_glass := workroom.get_node("WorkroomGlass") as MeshInstance3D
	var room_at := workroom.to_global(Vector3(-1.5, 1.25, 0.0))
	var window_contact := space.intersect_ray(PhysicsRayQueryParameters3D.create(room_at + Vector3.RIGHT, room_at - Vector3.RIGHT, 1))
	var repair: Node3D = city.call("repair_storefront")
	if not _check(workroom_glass.mesh != null and repair.has_node("AuthoredWorkshop") and not window_contact.is_empty() and absf(window_contact["position"].x - room_at.x) < 0.10, "retained display window stays protected in front of the workshop"):
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
	if not _check(escape.get_child_count() == 10, "five authored escape parts with five fitted collision shapes"):
		return
	for child in escape.get_children():
		if child is StaticBody3D:
			if not _check(child.get_child(0).shape is ConcavePolygonShape3D, "escape collision follows mesh triangles"):
				return
			continue
		var view := child as MeshInstance3D
		if not _check(view != null and view.mesh != null, "authored fire escape mesh"):
			return
		var bounds: AABB = view.transform * view.mesh.get_aabb()
		if not _check(bounds.position.y > 4.1, "escape remains overhead"):
			return
	var surface_pass := alley.get_node_or_null("AlleySurfacePass") as Node3D
	if not _check(surface_pass != null, "local damp surface layer"):
		return
	var damp := pavement.material_override as ShaderMaterial
	if not _check(damp != null and damp.shader != null, "opaque wetness shader"):
		return
	for parameter in ["concrete_color", "concrete_normal", "concrete_arm", "wetness_atlas", "grime_atlas", "repair_emitter", "laundry_emitter"]:
		if not _check(damp.get_shader_parameter(parameter) is Texture2D, "bound photo/mask texture " + parameter):
			return
	var pavement_shader_source := damp.shader.code
	if not _check(pavement_shader_source.contains("global uniform float cinder_surface_film") and pavement_shader_source.contains("float wet_mask") and pavement_shader_source.contains("fwidth(local_metres)"), "weather film linked to pooled pavement and antialiased ripple"):
		return
	var wet_mask := damp.get_shader_parameter("wetness_atlas") as Texture2D
	var pixels := wet_mask.get_image()
	if pixels.is_compressed():
		pixels.decompress()
	var pool := pixels.get_pixel(int(pixels.get_width() * 0.48), int(pixels.get_height() * 0.65)).r
	var dry_zone := pixels.get_pixel(int(pixels.get_width() * 0.50), int(pixels.get_height() * 0.02)).r
	if not _check(pool > dry_zone + 0.35, "authored wetness has pooled cores and dry islands"):
		return
	var dry := preload("res://scripts/material_library.gd").surface("PHOTO_SIDEWALK", Color("797870"))
	if not _check(is_equal_approx(dry.roughness, 1.0), "shared dry material unchanged"):
		return
	for item in ["WestWallRunoff", "EastWallRunoff", "FadedChalkTag", "WallStorytelling/TideTag", "WallStorytelling/TornServiceNotices", "WallStorytelling/LastShiftStencil", "WallStorytelling/MothMark", "WallStorytelling/WaveTag"]:
		var overlay := surface_pass.get_node_or_null(item) as MeshInstance3D
		if not _check(overlay != null and overlay.has_meta("surface_art") and overlay.get_child_count() == 0, "nonphysical wall art " + item):
			return
		var paint := overlay.material_override as StandardMaterial3D
		if not _check(paint.albedo_texture != null and paint.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and not paint.emission_enabled, "matte painted surface"):
			return
		var west: bool = overlay.position.x < x
		var wall: float = float(alley.get("left_wall")) if west else float(alley.get("right_wall"))
		if not _check(absf(overlay.position.x - wall) <= 0.025, "paint is wall mounted"):
			return
	var atmosphere := alley.get_node_or_null("StreetAtmosphere") as Node3D
	if not _check(atmosphere != null, "local atmosphere layer"):
		return
	var steam := atmosphere.get_node_or_null("DrainSteam") as CPUParticles3D
	if not _check(steam != null and steam.amount <= 14 and steam.visibility_range_end <= 24.0 and steam.mesh != null, "bounded drain vapor"):
		return
	var drain := alley.get_node("FlushDrainCover") as MeshInstance3D
	if not _check(Vector2(steam.position.x, steam.position.z).distance_to(Vector2(drain.position.x, drain.position.z)) < 0.01, "steam is anchored to drain"):
		return
	var vent := atmosphere.get_node_or_null("WarmServiceVent") as Node3D
	if not _check(vent != null and vent.get_child_count() == 13, "mounted warm service vent with six physical louvers"):
		return
	var vent_lamp := vent.get_node("VentPractical") as OmniLight3D
	if not _check(absf(vent.position.x - float(alley.get("right_wall"))) < .05 and absf(vent.position.z - drain.position.z) < .01 and not vent_lamp.shadow_enabled and vent_lamp.omni_range <= 2.0, "local bounded vent practical anchored by drain"):
		return
	atmosphere.call("set_night_factor", 1.0)
	if not _check(vent_lamp.visible and is_equal_approx(vent_lamp.light_energy, .58) and steam.color_ramp.get_color(1).r > .8, "warm night steam and practical"):
		return
	atmosphere.call("set_night_factor", 0.0)
	if not _check(not vent_lamp.visible and is_zero_approx(vent_lamp.light_energy) and steam.color_ramp.get_color(1).r < .4, "daytime vent extinguishes and steam returns neutral"):
		return
	var papers := 0
	var lights := 0
	for child in atmosphere.get_children():
		if child.has_meta("street_litter"):
			var paper := child as MeshInstance3D
			if not _check(paper != null and paper.mesh is ArrayMesh and absf(paper.position.y - Alley.FLOOR_Y) < 0.02 and absf(paper.position.x - x) > 1.0, "folded wall-side litter"):
				return
			papers += 1
		if child is OmniLight3D:
			var light := child as OmniLight3D
			if not _check(not light.shadow_enabled and light.distance_fade_enabled and light.omni_range <= 6.0 and light.light_energy <= 1.55, "two bounded, fade-limited sign sources"):
				return
			lights += 1
	if not _check(papers == 4 and lights == 2, "limited atmosphere dressing budget"):
		return
	var spans := architecture.get_node_or_null("OverheadUtilitySpans") as Node3D
	if not _check(spans != null and spans.get_child_count() == 8 and architecture.get_node("SecondaryCableAnchors").get_child_count() == 4, "four cable pairs with mounted secondary feed boxes"):
		return
	for child in spans.get_children():
		var cable := child as MeshInstance3D
		if not _check(cable != null and cable.mesh is ArrayMesh, "continuous round cable"):
			return
		var bounds := cable.mesh.get_aabb()
		var west_anchor: Vector3 = cable.get_meta("west_anchor")
		var east_anchor: Vector3 = cable.get_meta("east_anchor")
		if not _check(bounds.position.y >= 3.7 and bounds.position.y < 4.45 and absf(west_anchor.x - float(alley.get("left_wall"))) < 0.05 and absf(east_anchor.x - float(alley.get("right_wall"))) < 0.05, "sag and wall attachment"):
			return
		if not _check(cable.mesh.surface_get_array_index_len(0) == 1152, "bounded cable topology"):
			return
	for label in ["EastServiceEntrance"]:
		var entrance := architecture.get_node_or_null(label) as StaticBody3D
		if not _check(entrance != null and entrance.get_child_count() == 4, "closed authored service front"):
			return
		var door := entrance.get_node("ClosedServiceDoor") as MeshInstance3D
		var collider := entrance.get_node("ServiceFrontCollider") as CollisionShape3D
		if not _check(door.mesh != null and collider.shape is BoxShape3D and (collider.shape as BoxShape3D).size.z <= 0.47, "door and shallow wall collision"):
			return
		var at := entrance.to_global(Vector3(-1.5, 1.1, 0.0))
		var outward := entrance.global_transform.basis.z
		var door_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + outward * 0.75, at + outward * 0.08, 1))
		if not _check(not door_hit.is_empty() and door_hit["collider"] == entrance, "closed service entrance has physical contact"):
			return
	var business := alley.get_node_or_null("BusinessFrontage") as Node3D
	if not _check(business != null and business.get_child_count() == 4, "two blade signs and rain shelters"):
		return
	for child in business.get_children():
		var body := child as StaticBody3D
		if not _check(body != null and absf(body.position.x - (float(alley.get("left_wall")) if body.position.x < x else float(alley.get("right_wall")))) < 0.01, "frontage physically mounted"):
			return
		var shape_node := body.get_node("MeasuredEnvelope") as CollisionShape3D
		var shape := shape_node.shape as BoxShape3D
		if not _check(shape != null and body.position.y + shape_node.position.y - shape.size.y * 0.5 >= 3.0 and shape.size.z <= 1.08, "clear passage below frontage"):
			return
		if str(body.name).ends_with("Blade"):
			var assembly := body.get_node("AuthoredNeon")
			var meshes := assembly.find_children("*", "MeshInstance3D", true, false)
			if not _check(meshes.size() == 1 and body.get_child_count() == 2, "one imported complete sign with measured solid clearance"):
				return
			var sign := meshes[0] as MeshInstance3D
			var emitters := 0
			var mapped := 0
			for i in range(sign.mesh.get_surface_count()):
				var source := sign.mesh.surface_get_material(i) as StandardMaterial3D
				mapped += int(source != null and source.normal_enabled and source.normal_texture != null)
				var material := sign.get_surface_override_material(i) as StandardMaterial3D
				emitters += int(material != null and material.emission_enabled)
			if not _check(sign.mesh is ArrayMesh and mapped == 2 and emitters == 2, "photographic metal and separately modeled glass tubes"):
				return
		else:
			var sheet := body.get_node("CorrugatedWeatheredSheet") as MeshInstance3D
			if not _check(sheet.mesh is ArrayMesh and (sheet.material_override as StandardMaterial3D).normal_enabled, "corrugated photo-metal canopy"):
				return
	var neighbor_block := Vector2i(-1, 1)
	var neighbor_center := Vector3((float(neighbor_block.x)+0.5)*58.0,0.0,(float(neighbor_block.y)+0.5)*58.0)
	city.call("set_focus", neighbor_center)
	await physics_frame
	await physics_frame
	var neighbor_chunk := (city.get("_loaded") as Dictionary).get(neighbor_block) as Node3D
	if not _check(neighbor_chunk != null, "adjacent fixed parcel loaded"):
		return
	var neighbor := neighbor_chunk.get_node_or_null("BrickwaterNeighborArchitecture") as Node3D
	if not _check(neighbor != null and neighbor.get_child_count() == 4, "residential-only kit"):
		return
	for label in ["WestApartmentFront", "EastApartmentFront"]:
		var face := neighbor.get_node(label) as Node3D
		if not _check(face.get_child_count() == 24, "four distinct authored bays on two floors"):
			return
		for child in face.get_children():
			var view := child as MeshInstance3D
			if not _check(view != null and view.mesh != null and view.position.y >= 4.8, "neighbor mesh and clearance"):
				return
	if not _check(neighbor.get_node_or_null("WestEmergencyEscape") != null and neighbor_chunk.get_node_or_null("BrickwaterServiceAlley") == null and neighbor.get_node_or_null("OverheadUtilitySpans") == null, "no duplicate pilot businesses or effects"):
		return
	var neighbor_middle := (float(neighbor.get("left_wall")) + float(neighbor.get("right_wall"))) * 0.5
	var neighbor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(neighbor_center + Vector3(neighbor_middle,2,-5),neighbor_center + Vector3(neighbor_middle,-0.3,-5),1))
	if not _check(not neighbor_hit.is_empty(), "existing neighboring ground collision preserved"):
		return
	# Both blocks share a bounded palette of independent glass overrides.
	# No source material or mesh is mutated; day/night changes only copies.
	city.call("set_night_factor", 1.0)
	var occupancy_counts := [0, 0, 0]
	var occupied_materials: Dictionary = {}
	for assembly in [architecture, neighbor]:
		for label in ["WestApartmentFront", "EastApartmentFront"]:
			var facade: Node3D = assembly.get_node(label)
			for child in facade.get_children():
				var window := child as MeshInstance3D
				if not window.has_meta("occupancy_state"):
					continue
				var state: int = window.get_meta("occupancy_state")
				var surface: int = window.get_meta("glazing_surface")
				occupancy_counts[state] += 1
				var source := window.mesh.surface_get_material(surface) as StandardMaterial3D
				var override := window.get_surface_override_material(surface) as StandardMaterial3D
				if not _check(source.resource_name.to_lower().contains("glass") and window.get_surface_override_material(0) == null, "only glazing may be overridden"):
					return
				if state == 0:
					if not _check(override == null, "unoccupied windows retain original glass"):
						return
				else:
					if not _check(override != null and override != source and override.emission_enabled and override.emission_energy_multiplier > 0.3 and override.albedo_texture == source.albedo_texture, "nighttime occupied glass copy"):
						return
					occupied_materials[override.get_instance_id()] = override
	if not _check(occupancy_counts[0] > 0 and occupancy_counts[1] > 0 and occupancy_counts[2] > 0 and occupancy_counts[0] + occupancy_counts[1] + occupancy_counts[2] == 36, "mixed deterministic apartment occupancy"):
		return
	if not _check(occupied_materials.size() <= 2, "shared glass palette"):
		return
	city.call("set_night_factor", 0.0)
	for material in occupied_materials.values():
		if not _check(is_zero_approx(material.emission_energy_multiplier), "occupied windows cease emitting in daylight"):
			return
	# The two permanent parcels each receive three selected PBR
	# condenser assemblies, no extra floor collision or lights.
	for assembly in [architecture, neighbor]:
		var vents: Node3D = assembly.get_node_or_null("ResidentialVentilation")
		if not _check(vents != null and vents.get_child_count() == 3, "bounded residential ventilation"):
			return
		for fixture in vents.get_children():
			var unit := fixture.get_node("ScannedCondenser") as MeshInstance3D
			var bounds := unit.mesh.get_aabb()
			if not _check(unit.has_meta("authored_ventilation") and fixture.get_child_count() == 4 and absf(unit.position.z + bounds.position.z) < 0.002, "scanned condenser meets masonry"):
				return
			if not _check(fixture.position.y + unit.position.y + bounds.position.y >= 4.8 and unit.position.x + bounds.end.x < -1.95, "unit clears narrow window and passage"):
				return
			if not _check(unit.mesh.surface_get_material(0) is StandardMaterial3D and (unit.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture != null, "original condenser photo material"):
				return
			var line := fixture.get_node("CondensateLine") as MeshInstance3D
			var wall_return := fixture.get_node("WallReturn") as MeshInstance3D
			if not _check((line.transform.basis * Vector3.RIGHT).y < -0.61 and wall_return.position.z == 0.0 and ((wall_return.transform.basis * Vector3.RIGHT).z > 0.05), "service pipe descends and returns into wall"):
				return
	print("BRICKWATER_ALLEY_SMOKE PASS: physical floor, authored ground props, upper facade, cable trunks, overhead escape")
	quit(0)
