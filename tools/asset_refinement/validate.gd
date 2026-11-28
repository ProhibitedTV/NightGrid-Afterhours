extends SceneTree
# Offline import gate with an optional native architecture review camera.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [1, 2]:
		quit(2)
		return
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(args[0], state)
	if err != OK:
		push_error("GLB import failed: %s" % err)
		quit(1)
		return
	var asset := doc.generate_scene(state) as Node3D
	if asset == null:
		quit(1)
		return
	var nodes := asset.find_children("*", "MeshInstance3D", true, false)
	if asset is MeshInstance3D:
		nodes.append(asset)
	var meshes := 0
	var surfaces := 0
	var vertices := 0
	for node in nodes:
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		meshes += 1
		surfaces += instance.mesh.get_surface_count()
		for i in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(i)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for point in points:
				if not point.is_finite():
					asset.free()
					quit(1)
					return
			vertices += points.size()
	if meshes == 0 or surfaces == 0 or vertices == 0:
		asset.free()
		quit(1)
		return
	if args.size() == 2 and not await _capture_architecture(asset, nodes, args[1]):
		asset.free()
		quit(1)
		return
	asset.free()
	print("ANUBIS_IMPORT_PASS ", JSON.stringify({"meshes": meshes, "surfaces": surfaces, "vertices": vertices}))
	quit(0)


func _capture_architecture(asset: Node3D, nodes: Array[Node], image_path: String) -> bool:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("Architecture capture requires native Forward+.")
		return false
	if not image_path.is_absolute_path() or FileAccess.file_exists(image_path) or not DirAccess.dir_exists_absolute(image_path.get_base_dir()):
		push_error("Use a new PNG path in an existing evidence directory.")
		return false
	root.add_child(asset)
	var bounds: AABB = (nodes[0] as MeshInstance3D).global_transform * (nodes[0] as MeshInstance3D).get_aabb()
	for node: MeshInstance3D in nodes:
		bounds = bounds.merge(node.global_transform * node.get_aabb())
	var grade := MeshInstance3D.new()
	var pavement := PlaneMesh.new()
	pavement.size = Vector2(160, 160)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.25, 0.28, 0.28)
	concrete.roughness = 0.91
	grade.mesh = pavement
	grade.material_override = concrete
	root.add_child(grade)
	grade.position = Vector3(bounds.get_center().x, bounds.position.y - .025, bounds.get_center().z)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.41, 0.50, 0.59)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.86, 1.0)
	environment.ambient_light_energy = .38
	world.environment = environment
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-37, 33, 0)
	sun.light_color = Color(1.0, .91, .80)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	root.add_child(sun)
	var camera := Camera3D.new()
	root.add_child(camera)
	var span := maxf(bounds.size.x, bounds.size.y)
	camera.position = bounds.get_center() + Vector3(.62 * span, .23 * span, -bounds.size.z * .5 - .99 * span)
	camera.look_at(bounds.get_center())
	camera.fov = 52
	camera.make_current()
	for frame in 10:
		await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	return shot.get_size() == Vector2i(1920,1080) and shot.save_png(image_path) == OK
