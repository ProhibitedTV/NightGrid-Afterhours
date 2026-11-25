extends RefCounted
## Measured render-callback intervals for repeatable Windows traversal QA.
## This records observable frame spacing (including VSync), not pure GPU time.
const WINDOW_FRAMES = 240
const MAX_CAPTURE_FRAMES = 18000
const HITCH_MS = 1000.0 / 30.0
const MAX_TRANSITIONS = 256
const TRANSITION_WINDOW_FRAMES = 12
var _vehicle_transitions: Array[Dictionary] = []

var recording := false
var capture_full := false
var _recent: Array[float] = []
var _rows: Array[Dictionary] = []
var _elapsed := 0.0
var _previous_loads := 0
var _previous_stages := 0
var _previous_total_build_usec := 0

func begin_capture(loaded_count: int, build_stages: int = 0, total_build_usec: int = 0) -> void:
	_rows.clear()
	_vehicle_transitions.clear()
	_elapsed = 0.0
	_previous_loads = loaded_count
	_previous_stages = build_stages
	_previous_total_build_usec = total_build_usec
	capture_full = false
	recording = true

func end_capture() -> void:
	recording = false

func sample_frame(delta: float, stream: Dictionary, position: Vector3, driving: bool) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	var interval_ms := delta * 1000.0
	_recent.append(interval_ms)
	if _recent.size() > WINDOW_FRAMES:
		_recent.pop_front()

	var total_loads := int(stream.get("loads", 0))
	var new_loads := maxi(0, total_loads - _previous_loads)
	_previous_loads = total_loads
	var total_stages := int(stream.get("stage_steps", 0))
	var new_stages := maxi(0, total_stages - _previous_stages)
	_previous_stages = total_stages
	var cumulative_build := int(stream.get("total_build_usec", 0))
	var stage_build_ms := float(maxi(0, cumulative_build - _previous_total_build_usec)) / 1000.0
	_previous_total_build_usec = cumulative_build
	if not recording:
		return

	if _rows.size() >= MAX_CAPTURE_FRAMES:
		recording = false
		capture_full = true
		return

	_elapsed += delta
	# The world samples before its child CityDetails._process. A completed
	# build is visible on the NEXT world frame; never label idle frames as
	# spending the old last_build_usec measurement repeatedly.
	# Staged city construction may run for many frames without completing a
	# block. The monotonic microsecond counter correctly attributes ALL work
	# performed since the previous render sample, including emergency loads.
	# Keep a fallback for older stream dictionaries used by other tests.
	var build_ms := stage_build_ms if stream.has("total_build_usec") else (
		float(stream.get("last_build_usec", 0)) / 1000.0 if new_loads > 0 else 0.0)
	_rows.append({
		"elapsed_s": _elapsed,
		"frame_ms": interval_ms,
		"loaded": new_loads,
		"stages": new_stages,
		"build_ms": build_ms,
		"queued": int(stream.get("pending_blocks", 0)),
		"x": position.x,
		"z": position.z,
		"driving": 1 if driving else 0
	})

func get_frame_metrics() -> Dictionary:
	var count := _recent.size()
	if count == 0:
		return {"frames": 0, "avg_ms": 0.0, "p95_ms": 0.0,
			"p99_ms": 0.0, "low_1pct_fps": 0.0, "hitches": 0}
	var ordered: Array[float] = _recent.duplicate()
	ordered.sort()
	var sum_ms := 0.0
	var hitches := 0
	for value in ordered:
		sum_ms += value
		if value > HITCH_MS:
			hitches += 1
	var tail_count := maxi(1, ceili(float(count) * 0.01))
	var tail_ms := 0.0
	for index in range(count - tail_count, count):
		tail_ms += ordered[index]
	return {
		"frames": count,
		"avg_ms": sum_ms / float(count),
		"p95_ms": ordered[clampi(ceili(float(count) * 0.95) - 1, 0, count - 1)],
		"p99_ms": ordered[clampi(ceili(float(count) * 0.99) - 1, 0, count - 1)],
		"low_1pct_fps": 1000.0 * float(tail_count) / tail_ms,
		"hitches": hitches
	}

func captured_frames() -> int:
	return _rows.size()

func export_csv(path: String = "") -> String:
	if _rows.is_empty():
		return ""
	var destination := path
	if destination.is_empty():
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		destination = "user://nightgrid-drive-trace-" + stamp + ".csv"
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_line("elapsed_s,frame_ms,loaded_blocks,stream_build_ms,queued_blocks,world_x,world_z,in_car,stream_stage_steps")
	for row in _rows:
		file.store_line("%.4f,%.3f,%d,%.3f,%d,%.2f,%.2f,%d,%d" % [
			float(row["elapsed_s"]), float(row["frame_ms"]), int(row["loaded"]),
			float(row["build_ms"]), int(row["queued"]), float(row["x"]),
			float(row["z"]), int(row["driving"]), int(row["stages"])])
	file.close()
	return ProjectSettings.globalize_path(destination)

# All timing is opt-in with F8. Markers are CPU wall-clock durations, not GPU
# timings. Existing CSV format is unchanged; write a paired JSON evidence file.
func begin_vehicle_transition(kind: String,model: String) -> int:
	if not recording or _vehicle_transitions.size()>=MAX_TRANSITIONS:
		return -1
	var started := Time.get_ticks_usec()
	_vehicle_transitions.append({"kind":kind,"model":model,"first_frame_index":_rows.size(),"start_usec":started,"last_usec":started,"stages":{},"result":"unfinished"})
	return _vehicle_transitions.size()-1

func mark_vehicle_stage(index: int,stage: String) -> void:
	if index<0 or index>=_vehicle_transitions.size():
		return
	var event := _vehicle_transitions[index]
	if event["result"]!="unfinished":
		return
	var now := Time.get_ticks_usec()
	event["stages"][stage] = float(now-int(event["last_usec"]))/1000.0
	event["last_usec"] = now

func finish_vehicle_transition(index: int,result: String) -> void:
	if index<0 or index>=_vehicle_transitions.size():
		return
	var event := _vehicle_transitions[index]
	if event["result"]!="unfinished":
		return
	event["total_cpu_ms"] = float(Time.get_ticks_usec()-int(event["start_usec"]))/1000.0
	event["result"] = result

func vehicle_evidence() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for event in _vehicle_transitions:
		var entry: Dictionary = event.duplicate(true)
		entry.erase("start_usec")
		entry.erase("last_usec")
		var start := int(entry["first_frame_index"])
		var intervals: Array[float] = []
		var build_ms := 0.0
		var end := mini(start+TRANSITION_WINDOW_FRAMES,_rows.size())
		for i in range(start,end):
			intervals.append(float(_rows[i]["frame_ms"]))
			build_ms += float(_rows[i]["build_ms"])
		entry["following_frame_ms"] = intervals
		entry["following_stream_build_ms"] = build_ms
		entry["complete_window"] = intervals.size()==TRANSITION_WINDOW_FRAMES
		entry["peak_frame_ms"] = intervals.max() if not intervals.is_empty() else 0.0
		output.append(entry)
	return output

func export_vehicle_trace(csv_path: String) -> String:
	if csv_path.is_empty() or _vehicle_transitions.is_empty():
		return ""
	var destination := csv_path.get_basename()+"-vehicle-transitions.json"
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file==null:
		return ""
	file.store_string(JSON.stringify({"schema_version":1,"source_csv":csv_path.get_file(),"measurement_note":"CPU wall-clock stage durations plus following render intervals (including VSync); not GPU durations. Windows shader/render work can appear in later intervals. Overlapping windows are not exclusive attribution.","transitions":vehicle_evidence()},"\t"))
	file.close()
	return destination
