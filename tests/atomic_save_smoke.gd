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
	# A fresh game must retain the exact layout, even after an old seed is set.
	var baseline: Dictionary = session.call("get_world_manifest")
	session.set("world_seed", 12345)
	session.call("start_new_game")
	if not check(session.call("get_world_manifest") == baseline and session.get("world_seed") == 834726, "new game keeps canonical layout"):
		return
	var incompatible: Dictionary = session.call("make_snapshot", state)
	incompatible["seed"] = 12345
	if not check(not session.call("is_valid_snapshot", incompatible), "reject variable-layout legacy save"):
		return
	incompatible = session.call("make_snapshot", state)
	var block: String = incompatible["world_manifest"]["blocks"].keys()[0]
	incompatible["world_manifest"]["blocks"][block][0]["height"] = 99.0
	if not check(not session.call("is_valid_snapshot", incompatible), "reject changed saved architecture"):
		return
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
	# The indoor return anchor is a real world coordinate, not arbitrary JSON.
	for room in [
		{"group":"VENUE","id":"lantern_cup","outside":["0",1,0]},
		{"group":"VENUE","id":"lantern_cup","outside":[0,NAN,0]},
		{"group":"CIVIC","id":"dock_watch","outside":[0,1,INF]},
		{"group":"VENUE","id":"lantern_cup","outside":[10001,1,0]},
		{"group":"VENUE","id":123,"outside":[0,1,0]}]:
		var invalid_room:Dictionary=state.duplicate(true)
		invalid_room["interior"]=room
		if not check(not session.call("is_valid_snapshot",session.call("make_snapshot",invalid_room)) and not session.call("save_snapshot_to",invalid_room,Path) and FileAccess.get_file_as_string(Path)==original,"invalid indoor anchor preserves existing slot"):
			return
	var valid_room:Dictionary=state.duplicate(true)
	valid_room["interior"]={"group":"VENUE","id":"lantern_cup","outside":[-12.5,1.15,30.0]}
	if not check(session.call("is_valid_snapshot",session.call("make_snapshot",valid_room)),"valid indoor anchor remains supported"):
		return
	if not check(session.call("save_snapshot_to",state,Path) and session.call("read_snapshot_from",Path).get("cash")==300 and not FileAccess.file_exists(Path+".tmp"),"retry commits and cleans staging"):
		return
	DirAccess.remove_absolute(absolute)
	print("ATOMIC_SAVE PASS: replacement, rollback, staging failure, bounded validation")
	quit(0)
