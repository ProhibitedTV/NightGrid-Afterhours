extends SceneTree
const Bank = preload("res://scripts/character_bank.gd")
const Rig = preload("res://scripts/pedestrian_rig_visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var require := "--require-bank" in OS.get_cmdline_user_args()
	if Bank.ids().size() != 24:
		push_error("Character bank inventory drift")
		quit(1)
		return
	if not Bank.available():
		if require or FileAccess.file_exists(Bank.ROOT + "bank.json"):
			push_error("Complete creator character bank required")
			quit(1)
			return
		print("CHARACTER_BANK PASS: optional bank absent in clean checkout")
		quit()
		return
	var seen := {}
	for id in Bank.ids():
		if seen.has(id):
			push_error("Duplicate character identity: " + str(id))
			quit(1)
			return
		seen[id] = true
		var rig := Rig.new()
		rig.set_pedestrian_model(Bank.model(id))
		root.add_child(rig)
		if not rig.is_pedestrian_visual_ready():
			push_error("Imported rig failed: " + str(id))
			quit(1)
			return
		root.remove_child(rig)
		rig.free()
	if Bank.street_models().size() != 12:
		push_error("Street pool must contain twelve candidate models")
		quit(1)
		return
	print("CHARACTER_BANK PASS: all 24 imported rigs")
	quit()
