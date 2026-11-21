extends RefCounted
## Real Windows/Godot visual review evidence: one unmodified Viewport frame and
## machine-readable camera/world/graphics context, in a single local folder.
## This helper never synthesizes screenshots or claims GPU measurement.
const ROOT = "user://playtest-evidence"
const MAX_SAME_SECOND_CAPTURES = 100
const SCHEMA_VERSION = 1

static func vector3_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

static func camera_metadata(view: Camera3D) -> Dictionary:
	var orientation := view.global_transform.basis.get_rotation_quaternion()
	return {
		"world_position_m": vector3_array(view.global_position),
		"rotation_xyzw": [orientation.x, orientation.y, orientation.z, orientation.w],
		"field_of_view_deg": view.fov,
		"near_plane_m": view.near,
		"far_plane_m": view.far,
		"projection": view.projection
	}

static func build_metadata(view: Camera3D, actor: Node3D,
		info: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"capture_type": "actual_playable_viewport_frame",
		"date_utc": Time.get_datetime_string_from_system(true),
		"engine": str(Engine.get_version_info().get("string", "unknown")),
		"operating_system": OS.get_name(),
		"display_driver": DisplayServer.get_name(),
		"project_rendering_method": str(ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "unknown")),
		"camera": camera_metadata(view),
		"actor_position_m": vector3_array(actor.global_position),
		"world_seed": int(info.get("world_seed", 0)),
		"game_clock": str(info.get("game_clock", "")),
		"district": str(info.get("district", "")),
		"indoors": bool(info.get("indoors", false)),
		"motion_context": str(info.get("motion_context", "on_foot")),
		"graphic_settings": (info.get("graphic_settings", {}) as Dictionary).duplicate(true),
		"frame_interval_metrics": (info.get("frame_interval_metrics", {}) as Dictionary).duplicate(true),
		"streaming": (info.get("streaming", {}) as Dictionary).duplicate(true),
		"frame_trace_recording": bool(info.get("frame_trace_recording", false)),
		"measurement_note": "Rolling render callback spacing including VSync; not measured GPU frame time.",
		"capture_note": "This PNG comes directly from the active Godot viewport, not concept art. Project renderer setting is not a GPU feature or Forward+ benchmark certification."
	}

static func export_bundle(frame: Image, info: Dictionary,
		directory: String = ROOT) -> Dictionary:
	if frame == null or frame.is_empty() or frame.get_width() < 8 or frame.get_height() < 8:
		return {"ok": false, "error": "Empty or undersized framebuffer"}
	if not directory.begins_with("user://"):
		return {"ok": false, "error": "Evidence must remain in the local user data directory"}
	var target := ProjectSettings.globalize_path(directory)
	var mkdir_result := DirAccess.make_dir_recursive_absolute(target)
	if mkdir_result != OK:
		return {"ok": false, "error": "Could not create evidence directory (%d)" % mkdir_result}
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var name := ""
	for attempt in range(MAX_SAME_SECOND_CAPTURES):
		var candidate := "nightgrid-%s-%02d" % [stamp, attempt]
		if not FileAccess.file_exists(directory.path_join(candidate + ".png")) and not FileAccess.file_exists(directory.path_join(candidate + ".json")):
			name = candidate
			break
	if name.is_empty():
		return {"ok": false, "error": "Too many captures with identical timestamps"}
	var image_path := directory.path_join(name + ".png")
	var info_path := directory.path_join(name + ".json")
	if frame.save_png(image_path) != OK:
		return {"ok": false, "error": "Unable to save actual rendered PNG"}
	var contents: Dictionary = info.duplicate(true)
	contents["framebuffer_resolution_px"] = [frame.get_width(), frame.get_height()]
	contents["png_filename"] = name + ".png"
	contents["json_filename"] = name + ".json"
	var file := FileAccess.open(info_path, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(image_path))
		return {"ok": false, "error": "Could not open evidence metadata file"}
	file.store_string(JSON.stringify(contents, "\t") + "\n")
	file.close()
	if FileAccess.get_file_as_string(info_path).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(image_path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(info_path))
		return {"ok": false, "error": "Evidence metadata write was empty"}
	return {
		"ok": true,
		"png_path": ProjectSettings.globalize_path(image_path),
		"json_path": ProjectSettings.globalize_path(info_path),
		"directory": target
	}
