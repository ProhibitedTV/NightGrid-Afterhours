extends SceneTree
const Path = "user://saves/atomic_regression_slot.json"
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool,reason: String) -> bool:
	if not ok:
		push_error("ATOMIC_SAVE: "+reason)
		quit(1)
	return ok
func _verify() -> void:
	var session := root.get_node("GameSession")
	var absolute := ProjectSettings.globalize_path(Path)
	DirAccess.remove_absolute(absolute)
	DirAccess.remove_absolute(absolute+".tmp")
	var state := {"player_position":[0,1,0],"cash":100,"health":100,"deliveries":0,"carrying":false,"hour":19.25,"cars":[],"traffic":{},"rail":{}}
	if not check(session.call("save_snapshot_to",state,Path),"first write"):
		return
	state["cash"]=250
	if not check(session.call("save_snapshot_to",state,Path) and session.call("read_snapshot_from",Path).get("cash")==250,"replace existing slot"):
		return
	var original := FileAccess.get_file_as_string(Path)
	state["cash"]=-1
	if not check(not session.call("save_snapshot_to",state,Path) and FileAccess.get_file_as_string(Path)==original,"invalid data retains original bytes"):
		return
	state["cash"]=300
	# A directory at the staging pathname simulates a failed opening without
	# permissions assumptions or touching the user's real slot.
	DirAccess.make_dir_absolute(absolute+".tmp")
	if not check(not session.call("save_snapshot_to",state,Path) and FileAccess.get_file_as_string(Path)==original,"staging failure retains prior save"):
		return
	DirAccess.remove_absolute(absolute+".tmp")
	var malformed: Dictionary = session.call("make_snapshot",state)
	malformed["version"]="1"
	if not check(not session.call("is_valid_snapshot",malformed),"reject coerced version"):
		return
	malformed["version"]=1
	malformed["player_position"]=["0",1,0]
	if not check(not session.call("is_valid_snapshot",malformed),"reject coerced coordinates"):
		return
	malformed["player_position"]=[0,1,0]
	malformed["progression"]={"version":1,"receipts":["story:night_shift_contact"],"home_supplies":1}
	if not check(not session.call("is_valid_snapshot",malformed),"reject orphan home entitlement"):
		return
	if not check(session.call("save_snapshot_to",state,Path) and session.call("read_snapshot_from",Path).get("cash")==300 and not FileAccess.file_exists(Path+".tmp"),"retry commits and cleans staging"):
		return
	DirAccess.remove_absolute(absolute)
	print("ATOMIC_SAVE PASS: replacement, rollback, staging failure, bounded validation")
	quit(0)
