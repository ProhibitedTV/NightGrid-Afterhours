extends RefCounted
## Creator build only. The packager stages the exact reviewed candidate files.
const Rig = preload("res://scripts/pedestrian_rig_visual.gd")
const Bank = preload("res://scripts/character_bank.gd")
const ROOT = "res://assets/creator_playtest_cast/"
const SOCIAL_CANDIDATES = {
	"dev": ["dev.glb", "da44fc3cef88d7f55f2837b22b355140536ac19f0530a0779d1257a30d93bdd6"],
	"rina": ["rina.glb", "74321e1f1184090c50915ef8901d7c2b067f8643d21bb85055166558b4b1b08e"],
}

const SEATED_CANDIDATES = {
	"people_ops": ["dana.glb", "642073bc5d603e0dff9b99c5f6e0d2a5f8565bb995bea7636f1568cdafd70d84"],
	"jetson_wang": ["jetson.glb", "4f7878f077863584eb6ff9229cb8175d427db8298b45987184a1bcc85fdf8d36"],
}

## Return unexpected binary paths without opening or altering any payload.
static func unexpected_candidate_files(directory: String, allowed: Array[String]) -> Array[String]:
	var unexpected: Array[String] = []
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension().to_lower()=="bin" and not allowed.has(filename):
			unexpected.append(directory.path_join(filename))
	for subdir in DirAccess.get_directories_at(directory):
		unexpected.append_array(unexpected_candidate_files(directory.path_join(subdir), []))
	return unexpected

static func allowed_candidate_files() -> Array[String]:
	var allowed: Array[String] = []
	for entry in SOCIAL_CANDIDATES.values()+SEATED_CANDIDATES.values():
		allowed.append(str(entry[0])+".bin")
	return allowed

## Called only by explicit packaged-creator verification, before normal gameplay.
static func verify_packaged_candidates() -> bool:
	var expected: Dictionary = SOCIAL_CANDIDATES.duplicate()
	expected.merge(SEATED_CANDIDATES)
	if not unexpected_candidate_files(ROOT,allowed_candidate_files()).is_empty():
		push_error("CREATOR_PCK FAIL: unexpected private binary payload")
		return false
	for id in expected:
		var entry: Array = expected[id]
		var path := ROOT.path_join(str(entry[0]) + ".bin")
		if not FileAccess.file_exists(path):
			push_error("CREATOR_PCK FAIL: missing " + str(id))
			return false
		if FileAccess.get_sha256(path) != str(entry[1]):
			push_error("CREATOR_PCK FAIL: checksum mismatch " + str(id))
			return false
	print("CREATOR_PCK PASS: all four exact candidate hashes")
	return true

static func _pose_avatar(visual: Node3D, actor: Node3D, id: String) -> String:
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	var skeletons := visual.find_children("*", "Skeleton3D", true, false)
	if players.size() != 1 or skeletons.size() != 1:
		return ""
	var player := players[0] as AnimationPlayer
	var skeleton := skeletons[0] as Skeleton3D
	visual.set_process(false)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	if SEATED_CANDIDATES.has(id):
		var seat := player.get_animation(&"Sit idle (chair)")
		if seat == null:
			return ""
		seat.loop_mode = Animation.LOOP_LINEAR
		player.play(&"Sit idle (chair)")
		player.seek(seat.length * .40, true)
		skeleton.force_update_all_bone_transforms()
		var hips := skeleton.find_bone("Hips")
		if hips < 0:
			return ""
		# The executive chair's .555 m seat top uses the existing .92 visual scale.
		# Position only the imported visual so the hips settle above the cushion.
		var seat_anchor := actor.global_position + actor.global_basis.orthonormalized() * Vector3(0, .563, -.045)
		var rig_hips := skeleton.to_global(skeleton.get_bone_global_pose(hips).origin)
		visual.global_position += seat_anchor - rig_hips
		return "Sit idle (chair) / cushion aligned"
	if id == "rina":
		var talk := player.get_animation(&"Talk with gestures")
		if talk == null:
			return ""
		talk.loop_mode = Animation.LOOP_LINEAR
		player.play(&"Talk with gestures", .16)
		player.seek(talk.length * .33, true)
		return "Talk with gestures"
	var carry := player.get_animation(&"Carry idle")
	var idle := player.get_animation(&"Idle")
	if carry == null or idle == null:
		return ""
	var hold := idle.duplicate(true) as Animation
	var arm_tracks := 0
	for index in carry.get_track_count():
		if carry.track_get_type(index) != Animation.TYPE_ROTATION_3D:
			continue
		var path := carry.track_get_path(index)
		var bone := str(path.get_concatenated_subnames())
		if bone not in ["RightShoulder", "RightArm", "RightForeArm"] and not bone.begins_with("RightHand"):
			continue
		var old := hold.find_track(path, Animation.TYPE_ROTATION_3D)
		if old >= 0:
			hold.remove_track(old)
		var track := hold.add_track(Animation.TYPE_ROTATION_3D)
		hold.track_set_path(track, path)
		for key in carry.track_get_key_count(index):
			var phase := carry.track_get_key_time(index, key) / carry.length
			var rotation: Quaternion = carry.track_get_key_value(index, key)
			hold.rotation_track_insert_key(track, phase * hold.length, rotation)
		arm_tracks += 1
	var bone_index := skeleton.find_bone("RightHand")
	var palm_index := skeleton.find_bone("RightHandMiddle1")
	var legacy_cup := actor.find_child("CoffeeCup", true, false) as Node3D
	if arm_tracks < 3 or bone_index < 0 or palm_index < 0 or legacy_cup == null:
		return ""
	var library := AnimationLibrary.new()
	hold.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(&"Cup hold", hold)
	player.add_animation_library(&"review", library)
	player.play(&"review/Cup hold", .18)
	player.seek(hold.length * .28, true)
	skeleton.force_update_all_bone_transforms()
	var attachment := BoneAttachment3D.new()
	attachment.name = "ReviewCoffeeRightHand"
	attachment.bone_name = "RightHand"
	skeleton.add_child(attachment)
	var grip := skeleton.get_bone_global_pose(bone_index)
	attachment.transform = grip
	var cup := legacy_cup.duplicate() as Node3D
	cup.name = "ReviewCoffeeCup"
	attachment.add_child(cup)
	var palm := skeleton.get_bone_global_pose(palm_index).origin.lerp(grip.origin, .30)
	var toward_body := (actor.global_position - skeleton.to_global(palm))
	toward_body.y = 0.0
	var center := skeleton.to_global(palm) + toward_body.normalized() * .045 + Vector3.UP * .018
	cup.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * .55), center)
	return "Cup hold / RightHand"


static func install(actor: Node3D, id: String) -> bool:
	var candidate: Array = SOCIAL_CANDIDATES.get(id, SEATED_CANDIDATES.get(id, []))
	if candidate.is_empty():
		return false
	var packed := Bank.model(str(Bank.NAMED.get(id, "")))
	if packed == null:
		var path := ROOT.path_join(candidate[0] + ".bin")
		if not FileAccess.file_exists(path):
			return false
		if FileAccess.get_sha256(path) != candidate[1]:
			push_warning("Creator cast candidate checksum mismatch: " + id)
			return false
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		if gltf.append_from_buffer(FileAccess.get_file_as_bytes(path), "", state) != OK:
			return false
		var model := gltf.generate_scene(state)
		if model == null:
			return false
		packed = PackedScene.new()
		var packed_ok := packed.pack(model)
		model.free()
		if packed_ok != OK:
			return false
	var original_nodes := actor.get_children()
	var rig := Rig.new()
	rig.name = "CreatorCastVisual"
	rig.set_pedestrian_model(packed)
	rig.idle_clip = &"Idle"
	rig.walk_clip = &"Walk"
	rig.scale = Vector3.ONE / actor.scale
	actor.add_child(rig)
	if not rig.is_pedestrian_visual_ready() or _pose_avatar(rig, actor, id).is_empty():
		rig.queue_free()
		return false
	rig.enable_authored_office_pose()
	for child in original_nodes:
		if child is Node3D:
			child.hide()
	# The imported animation player owns the visible pose. Do not keep
	# updating the hidden legacy head, blink, torso and prop transforms.
	# set_process affects only the actor, not its imported animation child.
	actor.set_process(false)
	return true
