extends SceneTree
## Mathematical correctness and export contract; not a GPU benchmark.
const Recorder = preload("res://scripts/frame_time_recorder.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("FRAME_TRACE_SMOKE: " + reason)
	quit(1)

func _verify() -> void:
	var recorder = Recorder.new()
	var empty: Dictionary = recorder.get_frame_metrics()
	if int(empty["frames"]) != 0:
		_fail("An empty ring cannot report real frame times")
		return
	recorder.begin_capture(7)
	var stream := {"loads": 7, "last_build_usec": 0, "pending_blocks": 5}
	for index in range(100):
		var ms := 16.0
		if index == 98:
			ms = 45.0
			stream["loads"] = 8
			stream["last_build_usec"] = 12345
			stream["pending_blocks"] = 4
		elif index == 99:
			ms = 60.0
			stream["loads"] = 8
			# Old last-build duration must NOT be attributed twice.
			stream["last_build_usec"] = 12345
		recorder.sample_frame(ms / 1000.0, stream,
			Vector3(float(index), 0.0, 203.0), true)
	var stats: Dictionary = recorder.get_frame_metrics()
	if int(stats["frames"]) != 100 or int(stats["hitches"]) != 2:
		_fail("Incorrect window count or >33ms hitch count: " + str(stats))
		return
	if absf(float(stats["p95_ms"]) - 16.0) > 0.02:
		_fail("p95 should exclude two slowest of 100: " + str(stats))
		return
	if absf(float(stats["p99_ms"]) - 45.0) > 0.02:
		_fail("Nearest-rank p99 should equal 45ms: " + str(stats))
		return
	if absf(float(stats["low_1pct_fps"]) - 16.6667) > 0.05:
		_fail("1% low must average the slowest frame intervals: " + str(stats))
		return
	if recorder.captured_frames() != 100:
		_fail("Recording lost frame samples")
		return
	recorder.end_capture()
	var output := "user://nightgrid-frame-trace-smoke.csv"
	var saved: String = recorder.export_csv(output)
	if saved.is_empty() or not FileAccess.file_exists(output):
		_fail("Could not create actual trace CSV")
		return
	var lines := FileAccess.get_file_as_string(output).strip_edges().split("\n")
	if lines.size() != 101 or not lines[0].begins_with("elapsed_s,frame_ms,loaded_blocks"):
		_fail("Trace CSV lost its header or frame rows")
		return
	var accounted_builds := 0
	for index in range(1, lines.size()):
		var columns := lines[index].split(",")
		if columns.size() != 8:
			_fail("Trace CSV has a malformed row: " + lines[index])
			return
		if float(columns[3]) > 0.0:
			accounted_builds += 1
			if int(columns[2]) != 1 or absf(float(columns[3]) - 12.345) > 0.002:
				_fail("Build duration is not correlated to new streamed blocks")
				return
	if accounted_builds != 1:
		_fail("Stale last_build_usec was repeated across frames")
		return
	recorder.begin_capture(8)
	if recorder.captured_frames() != 0:
		_fail("A new capture must clear the previous driving session")
		return
	recorder.end_capture()
	if not recorder.export_csv("user://empty-trace.csv").is_empty():
		_fail("An empty capture cannot silently overwrite a CSV")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(output))
	print("FRAME_TRACE_SMOKE PASS: p95/p99/1% lows, two hitches, single chunk attribution and 100-row CSV")
	quit(0)
