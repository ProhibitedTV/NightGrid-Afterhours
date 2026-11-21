extends RefCounted
## Lightweight, opt-in-by-build Windows playtest diagnostics. One JSON object
## per line; no per-frame disk writes or automatic upload. Real-time sampling
## tracks frame spacing, not GPU duration.
const ROOT = "user://playtest-logs"
const MAX_EVENTS = 6000
const FLUSH_SECONDS = 2.0
const MAX_BUFFERED_EVENTS = 24
const HITCH_THRESHOLD_MS = 50.0
const HITCH_COOLDOWN_SECONDS = 1.5
const HEARTBEAT_SECONDS = 15.0

var _file: FileAccess
var _path := ""
var _elapsed := 0.0
var _last_flush_s := 0.0
var _last_hitch_s := -100.0
var _last_heartbeat_s := 0.0
var _events := 0
var _hitches := 0
var _peak_frame_ms := 0.0
var _last_fallback_stages := 0
var _last_total_build_usec := 0
var _buffer: Array[String] = []

func start_session(seed: int, details: Dictionary = {}, directory: String = ROOT) -> String:
	if _file != null or not directory.begins_with("user://"):
		return ""
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	for attempt in range(100):
		var candidate := directory.path_join("nightgrid-%s-%02d.jsonl" % [stamp, attempt])
		if FileAccess.file_exists(candidate):
			continue
		_file = FileAccess.open(candidate, FileAccess.WRITE)
		if _file != null:
			_path = ProjectSettings.globalize_path(candidate)
		break
	if _file == null:
		return ""
	_elapsed = 0.0
	_last_flush_s = 0.0
	_last_hitch_s = -100.0
	_last_heartbeat_s = 0.0
	_events = 0
	_hitches = 0
	_peak_frame_ms = 0.0
	_last_fallback_stages = 0
	_last_total_build_usec = 0
	_buffer.clear()
	record_event("session_start", {
		"world_seed": seed,
		"engine": str(Engine.get_version_info().get("string", "")),
		"os": OS.get_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"context": details
	})
	flush()
	return _path

func is_active() -> bool:
	return _file != null

func get_log_path() -> String:
	return _path

func record_event(event_name: String, details: Dictionary = {}) -> void:
	if _file == null or _events >= MAX_EVENTS:
		return
	var record := {
		"schema_version": 1,
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"elapsed_s": snappedf(_elapsed, 0.001),
		"event": event_name,
		"data": details
	}
	_buffer.append(JSON.stringify(record))
	_events += 1
	if _buffer.size() >= MAX_BUFFERED_EVENTS:
		flush()

func sample_frame(delta: float, stream: Dictionary, position: Vector3, mode: String) -> void:
	if _file == null or delta <= 0.0 or not is_finite(delta):
		return
	_elapsed += delta
	var frame_ms := delta * 1000.0
	_peak_frame_ms = maxf(_peak_frame_ms, frame_ms)
	var total_build_usec := int(stream.get("total_build_usec", 0))
	var new_build_usec := maxi(0, total_build_usec - _last_total_build_usec)
	_last_total_build_usec = total_build_usec
	var fallback_stages := int(stream.get("occupied_collision_fallback_stages", 0))
	var newly_primed := maxi(0, fallback_stages - _last_fallback_stages)
	_last_fallback_stages = fallback_stages
	# No heavyweight stream snapshot or file access on ordinary frames.
	if newly_primed > 0:
		record_event("occupied_collision_fallback", {
			"stages": newly_primed, "x": position.x, "z": position.z,
			"mode": mode, "queued": int(stream.get("pending_blocks", 0))
		})
	if frame_ms >= HITCH_THRESHOLD_MS:
		_hitches += 1
		if _elapsed - _last_hitch_s >= HITCH_COOLDOWN_SECONDS:
			_last_hitch_s = _elapsed
			record_event("frame_hitch", {
				"frame_ms": snappedf(frame_ms, 0.01),
				"x": position.x, "z": position.z, "mode": mode,
				"stream_build_ms": snappedf(float(new_build_usec) / 1000.0, 0.01),
				"queued": int(stream.get("pending_blocks", 0)),
				"staging": int(stream.get("staging_blocks", 0)),
				"loaded": int(stream.get("loaded_blocks", 0))
			})
	if _elapsed - _last_heartbeat_s >= HEARTBEAT_SECONDS:
		_last_heartbeat_s = _elapsed
		record_event("heartbeat", {
			"x": position.x, "z": position.z, "mode": mode,
			"queued": int(stream.get("pending_blocks", 0)),
			"staging": int(stream.get("staging_blocks", 0)),
			"loaded": int(stream.get("loaded_blocks", 0)),
			"total_stream_build_ms": snappedf(float(total_build_usec) / 1000.0, 0.01),
			"peak_stream_stage_ms": snappedf(float(stream.get("peak_build_usec", 0)) / 1000.0, 0.01),
			"hitches_over_50ms": _hitches,
			"peak_frame_ms": snappedf(_peak_frame_ms, 0.01)
		})
	if _elapsed - _last_flush_s >= FLUSH_SECONDS:
		flush()

func flush() -> void:
	if _file == null:
		return
	for line in _buffer:
		_file.store_line(line)
	_buffer.clear()
	_file.flush()
	_last_flush_s = _elapsed

func end_session() -> void:
	if _file == null:
		return
	record_event("session_end", {
		"events": _events, "hitches_over_50ms": _hitches,
		"peak_frame_ms": snappedf(_peak_frame_ms, 0.01)
	})
	flush()
	_file = null
