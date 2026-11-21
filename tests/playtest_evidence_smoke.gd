extends SceneTree
## This test uses a deliberately synthetic 64x48 image ONLY to exercise
## file output/metadata. Real gameplay screenshots are captured from the
## actual Viewport by World._capture_playtest_frame on Windows (F10).
const Evidence = preload("res://scripts/playtest_evidence.gd")
const OUT = "user://tests/evidence_bundles"

func _initialize() -> void:
	call_deferred("_verify")

func _fail(why: String) -> void:
	push_error("PLAYTEST_EVIDENCE_SMOKE: " + why)
	quit(1)

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable scene unavailable")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var input_spec = load("res://scripts/game_input.gd")
	if not (input_spec.ACTIONS as Array).has("capture_playtest_frame"):
		_fail("F10 playtest evidence must be a registered shared input action")
		return
	var f10 := false
	for binding in InputMap.action_get_events("capture_playtest_frame"):
		if binding is InputEventKey and binding.physical_keycode == KEY_F10:
			f10 = true
	if not f10:
		_fail("Evidence capture action is not bound to F10")
		return
	for action in ["game_load", "record_frame_trace", "game_save"]:
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey and binding.physical_keycode == KEY_F10:
				_fail("F10 conflicts with an existing save/load/frame trace action")
				return
	var camera := world.get("camera") as Camera3D
	var actor := world.get("player") as Node3D
	var seed := int(root.get_node("GameSession").get("world_seed"))
	var pose: Dictionary = Evidence.camera_metadata(camera)
	if (pose.get("world_position_m", []) as Array).size() != 3 or (pose.get("rotation_xyzw", []) as Array).size() != 4:
		_fail("Camera position and orientation needed for comparable frames are absent")
		return
	var info: Dictionary = Evidence.build_metadata(camera, actor, {
		"world_seed": seed,
		"game_clock": "20:11",
		"district": "CENTRAL EXCHANGE",
		"motion_context": "on_foot",
		"indoors": false,
		"graphic_settings": {"ssr_enabled": true},
		"frame_interval_metrics": {"frames": 240, "p95_ms": 19.6, "p99_ms": 32.4},
		"streaming": {"loaded_blocks": 16},
		"frame_trace_recording": true
	})
	if int(info.get("world_seed", -1)) != seed or str(info.get("capture_type", "")) != "actual_playable_viewport_frame":
		_fail("World provenance fields missing from capture record")
		return
	if float((info["frame_interval_metrics"] as Dictionary)["p99_ms"]) != 32.4:
		_fail("Measured frame percentiles not retained in capture")
		return
	if (info.get("camera", {}) as Dictionary).get("field_of_view_deg", 0.0) != camera.fov:
		_fail("Camera FOV needed to reproduce a shot was lost")
		return
	var empty := Image.new()
	if bool(Evidence.export_bundle(empty, info, OUT).get("ok", false)):
		_fail("Evidence exporter accepted an empty screenshot")
		return
	if bool(Evidence.export_bundle(Image.create(8, 8, false, Image.FORMAT_RGBA8), info, "res:" + "//exports").get("ok", false)):
		_fail("Evidence exporter should only write to user data directory")
		return
	# Synthetic image intentionally not presented as a real game render.
	var dummy := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	dummy.fill(Color(0.25, 0.18, 0.40))
	var first: Dictionary = Evidence.export_bundle(dummy, info, OUT)
	var second: Dictionary = Evidence.export_bundle(dummy, info, OUT)
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		_fail("Photo PNG and metadata cannot both be exported: " + str(first) + " / " + str(second))
		return
	if str(first["png_path"]) == str(second["png_path"]) or str(first["json_path"]) == str(second["json_path"]):
		_fail("Rapid captures overwrote an earlier PNG or JSON")
		return
	for result in [first, second]:
		var png_path := str(result["png_path"])
		var json_path := str(result["json_path"])
		if not FileAccess.file_exists(png_path) or not FileAccess.file_exists(json_path):
			_fail("Paired screenshot/metadata bundle has missing file")
			return
		var decoded := Image.new()
		if decoded.load(png_path) != OK or decoded.get_width() != 64 or decoded.get_height() != 48:
			_fail("Evidence file is not a valid PNG")
			return
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if not parsed is Dictionary:
			_fail("Evidence metadata is not valid JSON")
			return
		if int(parsed.get("schema_version", 0)) != 1 or (parsed.get("framebuffer_resolution_px", []) as Array) != [64, 48]:
			_fail("Paired metadata is missing exact image dimensions and schema")
			return
		if str(parsed.get("png_filename", "")) != png_path.get_file() or str(parsed.get("json_filename", "")) != json_path.get_file():
			_fail("Evidence pair lost matching basename")
			return
		if int(parsed.get("world_seed", -1)) != seed or not (parsed.get("frame_trace_recording", false) as bool):
			_fail("World state or trace state lost from metadata")
			return
		DirAccess.remove_absolute(png_path)
		DirAccess.remove_absolute(json_path)
	print("PLAYTEST_EVIDENCE_SMOKE PASS: F10 input, real-camera pose, metrics, atomic paired PNG/JSON filenames, no save mutation")
	quit(0)
