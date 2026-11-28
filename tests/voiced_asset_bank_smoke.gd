extends SceneTree
## Check actual imported dialogue resources, separated by their scene bank.
const Director = preload("res://scripts/dialogue_director.gd")
const OpeningVoice = preload("res://scripts/opening_voice.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_valid_int():
		push_error("Pass expected verified clip count after --")
		quit(1)
		return
	var expected := int(args[0])
	var director := Director.new()
	root.add_child(director)
	await process_frame
	var total := 0
	var failures: Array[String] = []
	var ids := DirAccess.get_directories_at("res://assets/audio/voiced")
	for prefix in ["synaxis.", "street."]:
		director.clear_bank()
		var count := 0
		for id in ids:
			if not id.begins_with(prefix):
				continue
			count += 1
			if not director.prewarm(id):
				failures.append("Failed to prewarm: " + id)
		total += count
		if director.stats()["cached"] != count:
			failures.append("Bank count mismatch: " + prefix)
		print("VOICE BANK ", prefix, ": ", count)
	if total != expected:
		failures.append("Expected %d verified clips, discovered %d" % [expected, total])
	if director.prewarm("nonexistent.line"):
		failures.append("Unexpected missing clip")
	director.clear_bank()
	var scene_voice := OpeningVoice.new()
	root.add_child(scene_voice)
	await process_frame
	var scene_ids: Array[String] = []
	for scene in OpeningVoice.SCENES:
		scene_ids.append_array(OpeningVoice.line_ids(scene))
	if scene_ids.size() != 28 or OpeningVoice.scene_for("opening", 2, 1, "") != "call_mandarin" or OpeningVoice.scene_for("breakroom", 0, 0, "breakroom_decline") != "breakroom_decline":
		failures.append("Opening scene voice dispatch does not match the canonical catalog")
	if OpeningVoice.scene_for("opening", 0, 0, "") != "it_handoff" or OpeningVoice.line_ids("it_handoff") != ["synaxis.it_handoff.01"]:
		failures.append("Opening scene mapping drift")
	for id in ids:
		if id.begins_with("synaxis.") and not scene_ids.has(id):
			failures.append("Unmapped corporate clip: " + id)
	paused = true
	scene_voice.select_scene("conference")
	var expected_first := ""
	for id in OpeningVoice.line_ids("conference"):
		if ids.has(id):
			expected_first = id
			break
	if scene_voice.active_id != expected_first:
		failures.append("Paused menu failed to select first available conference clip")
	scene_voice.select_scene("conference")
	if scene_voice.active_id != expected_first:
		failures.append("Same-scene rerender restarted dialogue")
	scene_voice.stop()
	if not scene_voice.active_id.is_empty() or not scene_voice.current_scene().is_empty():
		failures.append("Menu scene cancellation failed")
	paused = false
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("VOICED_ASSET_BANK PASS: ", total, " imported one-shot clips")
	quit(0)
