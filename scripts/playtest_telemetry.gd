extends Node
## User-opt-in diagnostics for real Windows playtests. No network telemetry and
## no per-frame disk writes. F7 records frame intervals; F8 saves a real PNG.
## This measures wall-clock render callbacks, NOT precise GPU frame latency.
const Build = preload("res://scripts/playtest_build.gd")
const MAX_FRAMES = 18000
const EVIDENCE_FOLDER = "user://playtest_evidence"

var world: Node3D
var recording := false
var _samples: Array[Dictionary] = []
var _started_usec := 0
var _last_usec := 0
var _stamp := ""
var _dropped := 0
var _frame_number := 0
var _context: Dictionary = {}
var _last_report: Dictionary = {}
var _capture_pending := false

func configure(world_node: Node3D) -> void:
	world = world_node

static func summary_from_ms(frame_times: Array[float]) -> Dictionary:
	if frame_times.is_empty():
		return {"frames": 0, "p50_ms": 0.0, "p95_ms": 0.0, "p99_ms": 0.0,
			"max_ms": 0.0, "stalls_over_33ms": 0, "slowest_1pct_fps": 0.0}
	var ordered: Array[float] = frame_times.duplicate()
	ordered.sort()
	var count: int = ordered.size()
	var p50: int = clampi(ceili(float(count) * 0.50) - 1, 0, count - 1)
	var p95: int = clampi(ceili(float(count) * 0.95) - 1, 0, count - 1)
	var p99: int = clampi(ceili(float(count) * 0.99) - 1, 0, count - 1)
	var worst: int = maxi(1, ceili(float(count) * 0.01))
	var worst_total := 0.0
	var stall_count := 0
	for index in range(count):
		var value: float = ordered[index]
		if value >= 33.333:
			stall_count += 1
		if index >= count - worst:
			worst_total += value
	return {"frames": count, "p50_ms": ordered[p50], "p95_ms": ordered[p95],
		"p99_ms": ordered[p99], "max_ms": ordered[count - 1],
		"stalls_over_33ms": stall_count,
		"slowest_1pct_fps": 1000.0 * float(worst) / maxf(worst_total, 0.001)}

func _ready() -> void:
	set_process(false)

func _stamp_now() -> String:
	return Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")

func evidence_directory() -> String:
	return ProjectSettings.globalize_path(EVIDENCE_FOLDER)

func _ensure_folder() -> bool:
	return DirAccess.make_dir_recursive_absolute(evidence_directory()) == OK

func toggle_trace() -> Dictionary:
	if recording:
		return stop_trace()
	start_trace()
	return {"recording": true, "path": evidence_directory()}

func start_trace() -> void:
	_samples.clear()
	_context.clear()
	_dropped = 0
	_frame_number = 0
	_stamp = _stamp_now()
	_started_usec = Time.get_ticks_usec()
	_last_usec = 0
	recording = true
	set_process(true)

func _read_context() -> void:
	if not is_instance_valid(world):
		return
	var actor: Node3D = world.call("_actor")
	var outside: Vector3 = actor.global_position
	var rooms: Node3D = world.get("interiors") as Node3D
	if is_instance_valid(rooms) and bool(rooms.call("is_inside")):
		outside = rooms.get("exterior_position")
	var city: Node3D = world.get("city_details") as Node3D
	var stream := {}
	var district := ""
	if is_instance_valid(city):
		stream = city.call("get_streaming_stats")
		district = str(city.call("get_district_at", outside))
	var car: CharacterBody3D = world.get("current_car") as CharacterBody3D
	var transit: Node3D = world.get("current_transit") as Node3D
	_context = {"district": district, "actor": "car" if is_instance_valid(car) else
		("transit" if is_instance_valid(transit) else "foot"),
		"x": snappedf(outside.x, 0.01), "z": snappedf(outside.z, 0.01),
		"pending_blocks": int(stream.get("pending_blocks", 0)),
		"build_ms": float(stream.get("last_build_usec", 0)) / 1000.0}

func _process(delta: float) -> void:
	if not recording:
		return
	var now: int = Time.get_ticks_usec()
	if _last_usec == 0:
		_last_usec = now
		return
	var elapsed_ms: float = float(now - _last_usec) / 1000.0
	_last_usec = now
	if _frame_number % 10 == 0:
		_read_context()
	_frame_number += 1
	if _samples.size() >= MAX_FRAMES:
		_dropped += 1
		return
	_samples.append({
		"frame": _frame_number,
		"elapsed_s": float(now - _started_usec) / 1000000.0,
		"frame_ms": elapsed_ms,
		"godot_delta_ms": delta * 1000.0,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"district": str(_context.get("district", "")),
		"actor": str(_context.get("actor", "")),
		"x": float(_context.get("x", 0.0)),
		"z": float(_context.get("z", 0.0)),
		"pending_blocks": int(_context.get("pending_blocks", 0)),
		"build_ms": float(_context.get("build_ms", 0.0))
	})

func _json_metadata() -> Dictionary:
	var result := {
		"git_revision": Build.SOURCE_REVISION,
		"build_flavor": Build.BUILD_FLAVOR,
		"captured_at_local": Time.get_datetime_string_from_system(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"window_px": [get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y],
		"platform": OS.get_name(),
		"sample_note": "Wall-clock intervals between game render callbacks; not GPU timestamps.",
		"user_data_path": evidence_directory()
	}
	if is_instance_valid(world):
		var actor: Node3D = world.call("_actor")
		result["actor_position"] = [actor.global_position.x, actor.global_position.y, actor.global_position.z]
		var outside: Vector3 = actor.global_position
		var interiors: Node3D = world.get("interiors") as Node3D
		if is_instance_valid(interiors) and bool(interiors.call("is_inside")):
			outside = interiors.get("exterior_position")
		var city: Node3D = world.get("city_details") as Node3D
		if is_instance_valid(city):
			result["district"] = city.call("get_district_at", outside)
			result["streaming"] = city.call("get_streaming_stats")
		var options: CanvasLayer = world.get("game_menu") as CanvasLayer
		if is_instance_valid(options):
			result["video_settings"] = options.call("get_settings")
	return result

func stop_trace() -> Dictionary:
	if not recording:
		return _last_report.duplicate(true)
	recording = false
	set_process(false)
	var values: Array[float] = []
	for item in _samples:
		values.append(float(item["frame_ms"]))
	var metrics := summary_from_ms(values)
	metrics["dropped_after_limit"] = _dropped
	metrics["recording_seconds"] = float(Time.get_ticks_usec() - _started_usec) / 1000000.0
	var name := "nightgrid-frame-trace-" + _stamp
	var result := {"recording": false, "summary": metrics, "path": evidence_directory()}
	if not _ensure_folder():
		push_warning("PLAYTEST: Could not create private evidence directory")
		return result
	var csv_path := evidence_directory().path_join(name + ".csv")
	var report_path := evidence_directory().path_join(name + ".json")
	var csv := FileAccess.open(csv_path, FileAccess.WRITE)
	if csv == null:
		push_warning("PLAYTEST: Could not write CSV frame trace")
		return result
	csv.store_line("frame,elapsed_s,frame_ms,godot_delta_ms,process_ms,physics_ms,district,actor,x,z,pending_blocks,build_ms")
	for item in _samples:
		csv.store_line("%d,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%s,%.2f,%.2f,%d,%.4f" % [
			int(item["frame"]), float(item["elapsed_s"]), float(item["frame_ms"]),
			float(item["godot_delta_ms"]), float(item["process_ms"]),
			float(item["physics_ms"]), str(item["district"]), str(item["actor"]),
			float(item["x"]), float(item["z"]), int(item["pending_blocks"]),
			float(item["build_ms"])])
	csv.close()
	var report: Dictionary = _json_metadata()
	report["statistics"] = metrics
	report["csv_file"] = name + ".csv"
	var written := FileAccess.open(report_path, FileAccess.WRITE)
	if written != null:
		written.store_string(JSON.stringify(report, "  ") + "\n")
		written.close()
	result["csv_path"] = csv_path
	result["report_path"] = report_path
	_last_report = result.duplicate(true)
	print("PLAYTEST FRAME TRACE: ", result)
	return result

func capture_screenshot() -> void:
	if _capture_pending or DisplayServer.get_name() == "headless":
		return
	_capture_pending = true
	var evidence := _json_metadata()
	if not _ensure_folder():
		_capture_pending = false
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_capture_pending = false
		return
	var prefix := "nightgrid-gameplay-" + _stamp_now()
	var png_path := evidence_directory().path_join(prefix + ".png")
	if image.save_png(png_path) == OK:
		evidence["image_file"] = prefix + ".png"
		evidence["size_px"] = [image.get_width(), image.get_height()]
		var meta := FileAccess.open(evidence_directory().path_join(prefix + ".json"), FileAccess.WRITE)
		if meta != null:
			meta.store_string(JSON.stringify(evidence, "  ") + "\n")
			meta.close()
		print("PLAYTEST SCREENSHOT: ", png_path)
	_capture_pending = false
