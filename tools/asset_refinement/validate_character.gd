extends SceneTree
## Verify a candidate’s actual Godot skeleton and optional Forward+ pose captures.

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not _require(args.size() >= 2, "Expected GLB path and output directory"):
		return
	if args[0] == "--batch":
		if not _require(args.size() == 3, "Use --batch <candidate root> <new evidence directory>"):
			return
		await _review_batch(args[1], args[2])
	else:
		var clips := args.slice(2) if args.size() > 2 else PackedStringArray(["Idle", "Walk"])
		await _review(args[0], args[1], clips)


func _review_batch(source: String, out: String) -> void:
	var folders := DirAccess.get_directories_at(source)
	if not _require(source.is_absolute_path() and not folders.is_empty(), "Expected a candidate batch"):
		return
	if not _require(out.is_absolute_path() and not DirAccess.dir_exists_absolute(out) and DirAccess.make_dir_recursive_absolute(out) == OK, "Expected a new evidence directory"):
		return
	var reviewed := 0
	for id in folders:
		if id.begins_with("."):
			continue
		var directory := source.path_join(id)
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("candidate.json")))
		if not _require(manifest is Dictionary and manifest.get("actor") == id and manifest.get("status") == "candidate-only", "Unexpected candidate manifest: " + id):
			return
		var model := str(manifest.get("model"))
		var file := directory.path_join(model)
		var structural: Variant = manifest.get("structural")
		if not _require(model.begins_with("export/") and model.get_file().get_extension() == "glb" and model.count("/") == 1 and not model.contains("\\"), "Unsafe candidate model path: " + id):
			return
		if not _require(structural is Dictionary and structural.get("clips") is Array
				and FileAccess.get_sha256(file) == structural.get("sha256"), "Invalid candidate hash or animation inventory: " + id):
			return
		if not await _review(file, out.path_join(id), PackedStringArray(structural["clips"]), false):
			return
		reviewed += 1
	if not _require(reviewed > 0, "No candidates reviewed"):
		return
	print("ANUBIS_RIG_BATCH PASS: ", reviewed, " hash-verified candidates")
	quit(0)


func _review(file: String, out: String, clips: PackedStringArray, standalone := true) -> bool:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if not _require(document.append_from_file(file, state) == OK, "Character import failed"):
		return false
	var model := document.generate_scene(state) as Node3D
	if not _require(model != null, "Missing character scene"):
		return false
	var review := Node3D.new()
	root.add_child(review)
	review.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not _require(skeletons.size() == 1 and players.size() == 1, "Expected one skeleton and animation player"):
		return false
	var skeleton := skeletons[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	var skinned := 0
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if view.skin != null and view.skin.get_bind_count() >= 55 and view.get_node_or_null(view.skeleton) == skeleton:
			skinned += 1
	if not _require(skeleton.get_bone_count() >= 55 and skinned > 0, "Insufficient live skin bindings"):
		return false
	var camera := Camera3D.new()
	review.add_child(camera)
	camera.position = Vector3(2.25, 1.3, 3.6)
	camera.look_at(Vector3(0, .9, 0))
	camera.fov = 32.0
	camera.make_current()
	for data in [[Vector3(0.4, -0.5, 0), 1.5], [Vector3(-0.5, 2.8, 0), 0.65]]:
		var light := DirectionalLight3D.new()
		light.rotation = data[0]
		light.light_energy = data[1]
		review.add_child(light)
	var report := {"file_sha256": FileAccess.get_sha256(file),
		"engine": Engine.get_version_info().get("string"), "bones": skeleton.get_bone_count(),
		"skinned_meshes": skinned, "clips": {},
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"renderer": RenderingServer.get_current_rendering_method()}
	if not _require(out.is_absolute_path() and not DirAccess.dir_exists_absolute(out) and DirAccess.make_dir_recursive_absolute(out) == OK, "Expected a new evidence directory"):
		return false
	if not _require(not clips.is_empty(), "Expected named animation clips"):
		return false
	for clip in clips:
		if not _require(clip.is_valid_filename() and player.has_animation(clip), "Missing or invalid animation: " + clip):
			return false
		var animation := player.get_animation(clip)
		if not _require(animation.length > 0.0 and animation.get_track_count() > 0, "Empty animation: " + clip):
			return false
		player.play(clip)
		player.seek(animation.length * 0.15, true)
		player.pause()
		var first: Array[Transform3D] = []
		for i in skeleton.get_bone_count():
			first.append(skeleton.get_bone_pose(i))
		player.seek(animation.length * 0.55, true)
		var changed := 0
		for i in skeleton.get_bone_count():
			var second := skeleton.get_bone_pose(i)
			if not _require(first[i].is_finite() and second.is_finite(), "Nonfinite bone pose: " + clip):
				return false
			if not first[i].is_equal_approx(second):
				changed += 1
		if not _require(changed > 0, "Animation does not change the skeleton: " + clip):
			return false
		report["clips"][clip] = {"length_seconds": animation.length, "tracks": animation.get_track_count(),
			"bones_changed": changed}
		if DisplayServer.get_name() != "headless":
			for frame in 4:
				await RenderingServer.frame_post_draw
			var error := root.get_texture().get_image().save_png(out.path_join(clip.to_lower() + ".png"))
			if not _require(error == OK, "Could not save a review frame"):
				return false
	var result := FileAccess.open(out.path_join("rig-review.json"), FileAccess.WRITE)
	if not _require(result != null, "Could not save the rig evidence"):
		return false
	result.store_string(JSON.stringify(report, "\t"))
	result.close()
	print("ANUBIS_RIG_REVIEW ", JSON.stringify(report))
	review.free()
	if standalone:
		quit(0)
	return true
