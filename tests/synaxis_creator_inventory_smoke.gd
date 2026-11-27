extends SceneTree
const Cast=preload("res://scripts/synaxis_creator_cast.gd")

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var folder: String="user://creator-inventory-fixture-"+str(Time.get_ticks_usec())
	var absolute:=ProjectSettings.globalize_path(folder)
	if DirAccess.make_dir_recursive_absolute(absolute.path_join("nested"))!=OK:
		quit(1)
		return
	var expected:=Cast.allowed_candidate_files()
	for name in expected+["README.md","unreviewed.BIN","nested/dev.glb.bin"]:
		var file:=FileAccess.open(folder.path_join(name),FileAccess.WRITE)
		if file==null:
			quit(1)
			return
		file.store_string("synthetic inventory fixture, not a candidate")
		file.close()
	var unexpected:=Cast.unexpected_candidate_files(folder,expected)
	for name in expected+["README.md","unreviewed.BIN","nested/dev.glb.bin"]:
		DirAccess.remove_absolute(absolute.path_join(name))
	DirAccess.remove_absolute(absolute.path_join("nested"))
	DirAccess.remove_absolute(absolute)
	if expected.size()!=4 or unexpected.size()!=2 or not unexpected.has(folder.path_join("unreviewed.BIN")) or not unexpected.has(folder.path_join("nested/dev.glb.bin")):
		push_error("CREATOR_INVENTORY: unexpected payload detection")
		quit(1)
		return
	print("CREATOR_INVENTORY PASS: only four pinned binary filenames allowed")
	quit(0)
