extends SceneTree
const Road = preload("res://scripts/photo_road_network.gd")
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
		for i in range(vertices.size()):
			if not _check(is_equal_approx(vertices[i].y,Road.Y) and uv[i].is_equal_approx(Vector2(vertices[i].x,vertices[i].z)/Road.TILE_METRES),"world-aligned scale and road height"):
				return
	print("PHOTO_ROAD_NETWORK_SMOKE PASS: exact nonoverlapping street union, two drawables, photo PBR and UV scale")
	quit(0)
