extends SceneTree
## Bounded JSONL diagnostic persistence and F7 marker contract. This does
## not measure Windows graphics performance or inspect actual playback audio.
const Logger = preload("res://scripts/playtest_logger.gd")
const InputSpec = preload("res://scripts/game_input.gd")
const OUT = "user://tests/nightgrid-playtest-log-smoke"

func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("PLAYTEST_LOG_SMOKE: " + message)
	quit(1)

func _verify() -> void:
	InputSpec.install()
	var f7_bound := false
	for binding in InputMap.action_get_events("playtest_mark"):
		if binding is InputEventKey and binding.physical_keycode == KEY_F7:
			f7_bound = true
	if not f7_bound:
		_fail("F7 manual incident marker is not mapped")
		return
	for action in ["game_save", "game_load", "record_frame_trace", "capture_playtest_frame"]:
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey and binding.physical_keycode == KEY_F7:
				_fail("F7 conflicts with " + action)
				return

	var log = Logger.new()
	if not log.start_session(123, {}, "res:" + "//wrong-location").is_empty():
		_fail("Playtest log allowed writes outside the user directory")
		return
	var file_path: String = log.start_session(123, {"test": true}, OUT)
	if file_path.is_empty() or not FileAccess.file_exists(file_path):
		_fail("Could not start a local JSONL diagnostic session")
		return
	if not log.start_session(123, {}, OUT).is_empty():
		_fail("Starting a second session while active should not truncate a log")
		return
	log.record_event("vehicle_enter", {"vehicle": "KESTREL"})
	var stream := {
		"loaded_blocks": 25, "pending_blocks": 5, "staging_blocks": 1,
		"total_build_usec": 1000, "occupied_collision_fallback_stages": 0
	}
	log.sample_frame(0.016, stream, Vector3(87.0, 1.0, 203.0), "car")
	stream["total_build_usec"] = 16000
	stream["occupied_collision_fallback_stages"] = 1
	log.sample_frame(0.070, stream, Vector3(89.0, 1.0, 203.0), "car")
	log.sample_frame(0.120, stream, Vector3(91.0, 1.0, 203.0), "car")
	# Even 60ms+ repeated hitches are counted but not all written. A 15s
	# heartbeat gives investigators a coarse summary during long sessions.
	for index in range(940):
		log.sample_frame(0.016, stream, Vector3(92.0, 1.0, 203.0), "car")
	log.record_event("manual_marker", {"note": "F7"})
	log.end_session()
	var raw := FileAccess.get_file_as_string(file_path)
	if raw.is_empty() or raw.length() > 60000:
		_fail("Playtest event file is missing or a short session wrote too much")
		return
	var counts := {}
	var lines := raw.strip_edges().split("\n")
	for line in lines:
		var item: Variant = JSON.parse_string(line)
		if not item is Dictionary or not item.has("timestamp_utc") or int(item.get("schema_version", 0)) != 1:
			_fail("Log line is not valid versioned JSONL")
			return
		var name := str(item.get("event", ""))
		counts[name] = int(counts.get(name, 0)) + 1
	for required in ["session_start", "vehicle_enter", "occupied_collision_fallback",
			"frame_hitch", "heartbeat", "manual_marker", "session_end"]:
		if int(counts.get(required, 0)) < 1:
			_fail("Expected diagnostic event was missing: " + required)
			return
	if int(counts.get("frame_hitch", 0)) != 1:
		_fail("Close-spaced hitches should be rate limited, not spam disk writes")
		return
	var last: Variant = JSON.parse_string(lines[lines.size() - 1])
	if int((last["data"] as Dictionary).get("hitches_over_50ms", 0)) != 2:
		_fail("Hitch summary must count every slow frame even if log events are throttled")
		return
	# Fast sequential launches cannot overwrite each other's diagnostic files.
	var another = Logger.new()
	var next_path: String = another.start_session(123, {}, OUT)
	if next_path.is_empty() or next_path == file_path or not FileAccess.file_exists(file_path):
		_fail("New session overwrote the previous JSONL log")
		return
	another.end_session()
	DirAccess.remove_absolute(file_path)
	DirAccess.remove_absolute(next_path)
	print("PLAYTEST_LOG_SMOKE PASS: local JSONL, F7, collision/hitch events, throttling, periodic summaries, separate sessions")
	quit(0)
