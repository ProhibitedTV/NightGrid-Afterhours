extends SceneTree
## Check actual imported dialogue resources, separated by their scene bank.
const Director = preload("res://scripts/dialogue_director.gd")

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
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("VOICED_ASSET_BANK PASS: ", total, " imported one-shot clips")
	quit(0)
