extends SceneTree

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var room := preload("res://tools/lighting/synaxis_reception_bake.tscn").instantiate()
	root.add_child(room)
	var gi := room.get_node("ReceptionGI") as LightmapGI
	var direct := room.get_node("ReceptionDirect") as Light3D
	if gi.environment_mode != LightmapGI.ENVIRONMENT_MODE_DISABLED or gi.get_child_count() != 3 or direct.light_bake_mode != Light3D.BAKE_DISABLED or not direct.shadow_enabled:
		_fail("Verify isolated bake lighting, probe positions and runtime direct shadow ownership")
		return
	var surfaces := 0
	var meshes := room.find_children("*", "MeshInstance3D", true, false)
	for item: MeshInstance3D in meshes:
		if item.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
			_fail(str(item.name) + " is missing static lightmap mode")
			return
		for index in item.mesh.get_surface_count():
			var arrays := item.mesh.surface_get_arrays(index)
			var secondary: Variant = arrays[Mesh.ARRAY_TEX_UV2]
			if not secondary is PackedVector2Array or secondary.size() != arrays[Mesh.ARRAY_VERTEX].size():
				_fail(str(item.name) + " is missing imported UV2 charts")
				return
			for uv: Vector2 in secondary:
				if not uv.is_finite() or not Rect2(0,0,1,1).has_point(uv):
					_fail(str(item.name) + " has a UV2 coordinate outside the atlas")
					return
			surfaces += 1
	if surfaces < 8:
		_fail("Expected the authored shell and luminaire")
		return
	var data := gi.light_data
	if data == null or data.get_user_count() != meshes.size() or data.lightmap_textures.is_empty() or not data.is_using_spherical_harmonics():
		_fail("Expected a directional atlas with one assignment per authored mesh")
		return
	for index in data.get_user_count():
		if not gi.get_node_or_null(data.get_user_path(index)) is MeshInstance3D:
			_fail("Invalid baked lightmap assignment")
			return
	print("SYNAXIS_RECEPTION_LIGHTMAP_INPUT PASS: ",surfaces," UV2 surfaces, ",data.get_user_count()," baked meshes and 3 authored probe positions")
	room.free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
