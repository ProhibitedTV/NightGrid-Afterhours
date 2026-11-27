extends SceneTree
## Clean CI exercises fallback; creator packaging must use --require-cast.
const Office = preload("res://scripts/synaxis_office.gd")
const Cast = preload("res://scripts/synaxis_creator_cast.gd")
const CLIPS = {
	"dev": "review/Cup hold",
	"rina": "Talk with gestures",
	"people_ops": "Sit idle (chair)",
	"jetson_wang": "Sit idle (chair)",
}

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var expected: Dictionary = Cast.SOCIAL_CANDIDATES.duplicate()
	expected.merge(Cast.SEATED_CANDIDATES)
	if not Cast.unexpected_candidate_files(Cast.ROOT,Cast.allowed_candidate_files()).is_empty():
		_fail("Unexpected private binary payload in staging folder")
		return
	var staged := 0
	for id in expected:
		var entry: Array = expected[id]
		var path := Cast.ROOT.path_join(str(entry[0]) + ".bin")
		if FileAccess.file_exists(path):
			staged += 1
			if FileAccess.get_sha256(path) != str(entry[1]):
				_fail("Candidate checksum mismatch: " + str(id))
				return
	if staged != expected.size() and (staged != 0 or "--require-cast" in OS.get_cmdline_user_args()):
		_fail("Creator cast must contain all four exact candidates; found %d" % staged)
		return
	var office := Office.new()
	office.position = Office.ORIGIN
	root.add_child(office)
	office.begin_prologue()
	await process_frame
	var staff: Dictionary = office.get("_staff")
	for id in expected:
		var actor := staff.get(id) as Node3D
		if actor == null:
			_fail("Missing authored actor: " + str(id))
			return
		office.call("_select_floor", office.call("staff_floor", id))
		await process_frame
		var rig := actor.get_node_or_null("CreatorCastVisual") as Node3D
		if staged == 0:
			if rig != null or not actor.visible or not actor.is_processing():
				_fail("Clean-checkout fallback not retained: " + str(id))
				return
			continue
		if rig == null or not rig.call("is_pedestrian_visual_ready") or not rig.is_visible_in_tree():
			_fail("Staged candidate failed to install: " + str(id))
			return
		var players := rig.find_children("*", "AnimationPlayer", true, false)
		var skeletons := rig.find_children("*", "Skeleton3D", true, false)
		if players.size() != 1 or skeletons.size() != 1:
			_fail("Unexpected candidate rig structure: " + str(id))
			return
		var player := players[0] as AnimationPlayer
		if actor.is_processing() or not player.is_playing():
			_fail("Imported animation must replace hidden legacy processing: " + str(id))
			return
		if str(player.current_animation) != str(CLIPS[id]):
			_fail("Unexpected candidate animation: " + str(id) + " " + str(player.current_animation))
			return
		if id == "dev" and rig.find_child("ReviewCoffeeCup", true, false) == null:
			_fail("Dev's hand-attached cup missing")
			return
	office.finish_prologue()
	office.queue_free()
	await process_frame
	print("SYNAXIS_CREATOR_CAST PASS: " + ("all four staged actors" if staged == 4 else "clean-checkout fallback"))
	quit(0)

func _fail(reason: String) -> void:
	push_error("SYNAXIS_CREATOR_CAST " + reason)
	quit(1)
