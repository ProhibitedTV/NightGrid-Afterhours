extends SceneTree
## Verify imported resources against Python's hash-validated partial bank.
const Generated = preload("res://scripts/synaxis_generated_audio.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected verified SFX bank JSON after --")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(args[0])
	if not parsed is Array:
		push_error("Invalid SFX bank JSON")
		quit(1)
		return
	var failures: Array[String] = []
	var count := 0
	var expected_ids: Array[String] = []
	for entry in parsed:
		var id := str(entry["id"])
		var loop := bool(entry["loop"])
		expected_ids.append(id)
		var audio := Generated.stream(id, loop)
		if audio == null:
			failures.append("Missing imported effect: " + id)
			continue
		if audio.get_length() <= 0.0 or audio.get_length() > 120.0:
			failures.append("Invalid duration: " + id)
		var desired := AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if audio.loop_mode != desired:
			failures.append("Loop mismatch: " + id)
		if loop and (audio.loop_begin != 0 or audio.loop_end <= 0):
			failures.append("Invalid loop bounds: " + id)
		count += 1
	var directory := DirAccess.open("res://assets/audio/generated/synaxis")
	if directory != null:
		for filename in directory.get_files():
			if filename.ends_with(".wav") and not expected_ids.has(filename.get_basename()):
				failures.append("Unexpected imported effect: " + filename)
	if Generated.stream("nonexistent_playtest_cue") != null:
		failures.append("Missing effect should return null for fallback")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("GENERATED_SFX_BANK PASS: ", count, " verified imported effects; missing cues retain fallback")
	quit(0)
