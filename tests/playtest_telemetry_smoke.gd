extends SceneTree
## Repeatable Godot 4.3 checks for local, opt-in playtest diagnostics.
## Validates real CSV/JSON output without claiming GPU profiler timings.
const Recorder = preload("res://scripts/playtest_telemetry.gd")
const Build = preload("res://scripts/playtest_build.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("PLAYTEST_TELEMETRY_SMOKE: " + reason)
	quit(1)

func _has_key(action_name: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event as InputEventKey).keycode == keycode:
			return true
	return false

func _verify() -> void:
	var samples: Array[float] = [16.0, 16.2, 33.5, 40.0]
	var metrics: Dictionary = Recorder.summary_from_ms(samples)
	if int(metrics["frames"]) != 4 or absf(float(metrics["p50_ms"]) - 16.2) > 0.01:
		_fail("Incorrect median interval or frame count")
		return
	if absf(float(metrics["p95_ms"]) - 40.0) > 0.01 or int(metrics["stalls_over_33ms"]) != 2:
		_fail("Frame-percentile and hitch statistics are incorrect: " + str(metrics))
		return
	if absf(float(metrics["slowest_1pct_fps"]) - 25.0) > 0.01:
		_fail("Slowest-1pct average FPS formula is incorrect")
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable scene missing")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var recorder := world.get_node_or_null("PlaytestTelemetry")
	if recorder == null or not _has_key("playtest_trace", KEY_F7) or not _has_key("playtest_screenshot", KEY_F8):
		_fail("Trace hotkeys or recorder are not connected to gameplay")
		return
	if str(Build.SOURCE_REVISION).is_empty():
		_fail("Every executable needs a known source-build revision marker")
		return
	recorder.call("start_trace")
	await process_frame
	await process_frame
	await process_frame
	if int(recorder.get("_samples").size()) < 2:
		_fail("Opt-in sampler missed actual render callbacks")
		return
	var result: Dictionary = recorder.call("stop_trace")
	if bool(result.get("recording", true)):
		_fail("F7 stop left the recorder active")
		return
	var json_path := str(result.get("report_path", ""))
	var csv_path := str(result.get("csv_path", ""))
	if not FileAccess.file_exists(json_path) or not FileAccess.file_exists(csv_path):
		_fail("Trace CSV/JSON artifacts were not written to user://")
		return
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (report is Dictionary):
		_fail("Trace metadata is not valid JSON")
		return
	if str(report.get("git_revision", "")) != str(Build.SOURCE_REVISION) or not report.has("statistics"):
		_fail("Trace lacks reproducible build ID or frame statistics")
		return
	var csv: String = FileAccess.get_file_as_string(csv_path)
	if not csv.begins_with("frame,elapsed_s,frame_ms") or csv.split("\n").size() < 4:
		_fail("CSV did not contain actual measured render frame records")
		return
	if recorder.call("toggle_trace").get("recording", false) != true:
		_fail("F7 must begin a new recording after an earlier trace ended")
		return
	recorder.call("stop_trace")
	print("PLAYTEST_TELEMETRY_SMOKE PASS: F7/F8 map, wall intervals, trace files, p95/p99, build SHA")
	quit(0)
