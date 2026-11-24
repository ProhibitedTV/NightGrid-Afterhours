extends SceneTree
const Road = preload("res://scripts/photo_road_network.gd")
const Maps = preload("res://scripts/material_library.gd")
func _initialize() -> void:
	call_deferred("_verify")
func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("PHOTO_ROAD_NETWORK: "+message)
		quit(1)
	return ok
func _verify()->void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var world:Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var road := world.get_node_or_null("PhotoRoadNetwork")
	if not _check(road!=null and road.get_child_count()==2,"real scene has two material-sorted road drawables"):
		return
	var rects: Array[Rect2] = road.call("rectangles")
	var area := 0.0
	for i in range(rects.size()):
		var rect := rects[i]
		area += rect.get_area()
		for j in range(i):
			if rect.intersection(rects[j]).get_area()>0.01:
				_check(false,"overlapping road rectangles")
				return
	if not _check(rects.size()==837 and is_equal_approx(area,18.0*490.0*14.0-81.0*196.0),"exact original road union coverage"):
		return
	var dry := road.get_child(0) as MeshInstance3D
	var damp := road.get_child(1) as MeshInstance3D
	var a := dry.material_override as StandardMaterial3D
	var b := damp.material_override as StandardMaterial3D
	if not _check(a.albedo_texture==b.albedo_texture and a.normal_texture==b.normal_texture and a.roughness_texture==b.roughness_texture and a.normal_enabled and b.normal_enabled and a.metallic==0.0 and b.metallic==0.0 and b.roughness<a.roughness,"shared photographic dielectric materials"):
		return
	if not _check(a.albedo_texture.resource_path.ends_with("bitumen_diffuse_2k.jpg") and a.normal_texture.resource_path.ends_with("bitumen_nor_gl_2k.png") and a.roughness_texture.resource_path.ends_with("bitumen_rough_2k.png"),"actual source textures"):
		return
	for node in [dry,damp]:
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv:PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if not _check(vertices.size()==uv.size() and vertices.size()*4==(arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size(),"UVs and tangents"):
			return
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		if not _check((node.material_override as StandardMaterial3D).cull_mode==BaseMaterial3D.CULL_BACK,"retain front-face culling; do not mask incorrect topology"):
			return
		for i in range(0,vertices.size(),3):
			var cross:Vector3=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			if not _check(cross.dot(Vector3.UP)<-0.00001,"clockwise upward-facing nondegenerate asphalt triangle"):
				return
		for i in range(vertices.size()):
			# ArrayMesh stores packed normals/tangents; compare directional
			# alignment rather than exact reconstructed vector components.
			var tangent := Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
			var handedness:float = tangents[i*4+3]
			if not _check(normals[i].dot(Vector3.UP)>0.999 and tangent.dot(Vector3.RIGHT)>0.999 and handedness < -0.99,"correct photo normal and tangent basis: %s / %s / %f" % [normals[i],tangent,handedness]):
				return
			if not _check(is_equal_approx(vertices[i].y,Road.Y) and uv[i].is_equal_approx(Vector2(vertices[i].x,vertices[i].z)/Road.TILE_METRES),"world-aligned scale and road height"):
				return
	var clock: Node = world.get("day_night")
	clock.set_process(false)
	clock.set("paused", true)
	var sidewalk := Maps.surface("PHOTO_SIDEWALK", Color("b2b0ac"))
	var curb := Maps.surface("PHOTO_CURB", Color("bfc0bd"))
	var junction: Node = world.get("central_roadway")
	var junction_damp: StandardMaterial3D = junction.call("get_surface_material", true)
	var old_tint := a.albedo_color
	var old_rough := a.roughness
	var old_junction := junction_damp.roughness
	var old_sidewalk := sidewalk.roughness
	var old_curb := curb.roughness
	var old_mesh := dry.mesh
	clock.call("set_weather", "storm")
	clock.call("_process", 3.0)
	if not _check(a.albedo_color.r < old_tint.r and a.roughness < old_rough and b.roughness < a.roughness and junction_damp.roughness < old_junction and sidewalk.roughness < old_sidewalk and curb.roughness < old_curb, "shared city weather reaches all ground families"):
		return
	var new_sidewalk := Maps.surface("PHOTO_SIDEWALK", Color("b1b2b3"))
	if not _check(new_sidewalk.roughness < 1.0 and dry.mesh == old_mesh and dry.material_override == a, "newly cached ground inherits film without rebuilding meshes"):
		return
	clock.call("set_weather", "clear")
	clock.call("_process", 20.0)
	if not _check(a.albedo_color.is_equal_approx(old_tint) and is_equal_approx(a.roughness, old_rough) and is_equal_approx(junction_damp.roughness, old_junction) and is_equal_approx(sidewalk.roughness, old_sidewalk) and is_equal_approx(curb.roughness, old_curb) and is_equal_approx(new_sidewalk.roughness,1.0), "drying restores baseline across city"):
		return
	print("PHOTO_ROAD_NETWORK_SMOKE PASS: exact nonoverlapping street union, two drawables, photo PBR, UV scale, clockwise front faces and tangent basis")
	quit(0)
