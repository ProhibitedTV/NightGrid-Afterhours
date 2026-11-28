extends SceneTree

const WITNESS_LAYER := 1 << 19

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [1, 2] or RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("Pass a new output directory and use Forward+.")
		return
	var out := args[0]
	if not out.is_absolute_path() or DirAccess.dir_exists_absolute(out) or DirAccess.make_dir_recursive_absolute(out) != OK:
		_fail("Cannot create the evidence directory.")
		return
	var production := "synaxis-ground" in args
	var scene_path := "res://scenes/synaxis/ground_envelope.tscn" if production else "res://tools/lighting/synaxis_reception_bake.tscn"
	var scene := load(scene_path) as PackedScene
	var bay := scene.instantiate() as Node3D
	root.add_child(bay)
	var gi := bay.get_node("Indirect" if production else "ReceptionGI") as LightmapGI
	var data := gi.light_data
	if data == null or data.get_user_count() == 0 or data.lightmap_textures.is_empty() or not data.is_using_spherical_harmonics():
		_fail("Directional baked atlas data and assignments are required.")
		return
	var users := []
	for index in data.get_user_count():
		var path := data.get_user_path(index)
		if not gi.has_node(path):
			_fail("Missing atlas assignment: " + str(path))
			return
		users.append(str(path))
	var atlases := []
	for atlas in data.lightmap_textures:
		atlases.append([atlas.get_width(), atlas.get_height(), atlas.get_layers()])
	var camera := _production_camera(bay) if production else bay.get_node("Camera3D") as Camera3D
	camera.make_current()
	var witness_mesh := SphereMesh.new()
	witness_mesh.radius = 0.16
	witness_mesh.height = 0.32
	var witness_material := StandardMaterial3D.new()
	witness_material.albedo_color = Color(0.5, 0.5, 0.5)
	witness_material.roughness = 1.0
	var witnesses := {}
	for probe: LightmapProbe in gi.get_children():
		if production and probe.name not in ["ReceptionApproach", "ReceptionStaff", "ReceptionReturn"]:
			continue
		var marker := MeshInstance3D.new()
		marker.mesh = witness_mesh
		marker.material_override = witness_material
		marker.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		if production:
			# Isolate indirect response on the witnesses. The room retains
			# the same realtime spotlight in both matched views.
			marker.layers = WITNESS_LAYER
		bay.add_child(marker)
		marker.global_position = probe.global_position
		witnesses[probe.name] = marker
	var records := {}
	var indirect_samples := {}
	for enabled in [true, false]:
		gi.light_data = data if enabled else null
		for frame in 60:
			await RenderingServer.frame_post_draw
		var name := "baked" if enabled else "realtime_only"
		var filename := out.path_join(name + ".png")
		var viewport_image := root.get_texture().get_image()
		if viewport_image.get_size() != Vector2i(1920, 1080) or viewport_image.save_png(filename) != OK:
			_fail("The fixed camera image did not save at 1920 × 1080.")
			return
		records[name] = FileAccess.get_sha256(filename)
		var levels := {}
		for id: StringName in witnesses:
			var marker: MeshInstance3D = witnesses[id]
			var sample := Vector2i(camera.unproject_position(marker.global_position - Vector3(0, .10, 0)))
			if not Rect2i(Vector2i(2, 2), viewport_image.get_size() - Vector2i(4, 4)).has_point(sample):
				_fail("A dynamic witness is outside the review frame.")
				return
			var luminance := 0.0
			for x in range(-2, 3):
				for y in range(-2, 3):
					luminance += viewport_image.get_pixelv(sample + Vector2i(x, y)).get_luminance()
			levels[id] = luminance / 25.0
		indirect_samples[name] = levels
	if records.baked == records.realtime_only:
		_fail("The matched bake and realtime images are identical.")
		return
	for id: StringName in witnesses:
		if indirect_samples.baked[id] <= indirect_samples.realtime_only[id] + 1.0 / 255.0:
			_fail("Probe %s did not lift: baked %.4f, realtime %.4f." % [
				id, indirect_samples.baked[id], indirect_samples.realtime_only[id]])
			return
	var report := FileAccess.open(out.path_join("pilot.json"), FileAccess.WRITE)
	if report == null:
		_fail("Cannot write pilot metadata.")
		return
	report.store_string(JSON.stringify({
		"godot": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"atlas_width_height_layers": atlases,
		"baked_users": users,
		"witnesses": witnesses.size(),
		"witness_luminance": indirect_samples,
		"images": records,
	}, "\t"))
	report.close()
	print("SYNAXIS BAKED RECEPTION COMPARISON PASS ", out)
	quit(0)


func _production_camera(bay: Node3D) -> Camera3D:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.031, 0.037)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	bay.add_child(world)
	var camera := Camera3D.new()
	bay.add_child(camera)
	camera.position = Vector3(5.65, 1.69, 3.85)
	camera.look_at(Vector3(6.0, 1.55, 8.0))
	camera.fov = 64.0
	var direct := SpotLight3D.new()
	bay.add_child(direct)
	direct.position = Vector3(4.74, 3.14, 7.5)
	direct.look_at(Vector3(6.15, 1.25, 8.30))
	direct.spot_range = 7.0
	direct.spot_angle = 58.0
	direct.spot_attenuation = 1.1
	direct.light_color = Color("fff0da")
	direct.light_energy = 1.35
	direct.light_cull_mask &= ~WITNESS_LAYER
	direct.shadow_enabled = true
	direct.light_bake_mode = Light3D.BAKE_DISABLED
	return camera


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
