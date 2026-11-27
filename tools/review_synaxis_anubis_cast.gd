extends SceneTree

const HQ = preload("res://scripts/synaxis_office.gd")
const Rig = preload("res://scripts/pedestrian_rig_visual.gd")
const CANDIDATES := {
	"dev": ["dev.glb", "0c25c792f6b8dac6e7e65f91c5a2f0699940597eb8a90c6bc029a4cbf02ca0ee"],
	"rina": ["rina.glb", "7dd3de0e72d4fbd649a71bd369cda0536633d5916a6ef467ab3a0a6be5fd8947"],
}


const SOCIAL_CANDIDATES := {
	"dev": ["dev.glb", "da44fc3cef88d7f55f2837b22b355140536ac19f0530a0779d1257a30d93bdd6"],
	"rina": ["rina.glb", "74321e1f1184090c50915ef8901d7c2b067f8643d21bb85055166558b4b1b08e"],
}

const SEATED_CANDIDATES := {
	"people_ops": ["dana.glb", "642073bc5d603e0dff9b99c5f6e0d2a5f8565bb995bea7636f1568cdafd70d84"],
	"jetson_wang": ["jetson.glb", "4f7878f077863584eb6ff9229cb8175d427db8298b45987184a1bcc85fdf8d36"],
}

static func _pose_avatar(visual: Node3D, actor: Node3D, id: String) -> String:
	var player := visual.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skeleton := visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
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


func _initialize() -> void:
	call_deferred("_review")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _review() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() > 3 or RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("Expected a native Forward+ candidate directory and new evidence directory")
		return
	var social := "--social" in args
	var seated := "--seated" in args
	var candidates := CANDIDATES
	if seated:
		candidates = SEATED_CANDIDATES
	elif social:
		candidates = SOCIAL_CANDIDATES
	var directory := args[0]
	var out := args[1]
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player := world.get("player") as CharacterBody3D
	var city := world.get("city_details") as Node3D
	player.global_position = HQ.ENTRY
	city.call("set_focus", HQ.ENTRY)
	var office: Node3D
	for attempt in 120:
		office = city.call("synaxis_headquarters")
		if office != null:
			break
		await physics_frame
	if office == null:
		_fail("Permanent Synaxis office did not stream")
		return
	world.get_node("GameMenus").call("hide_for_game")
	(world.get_node("HUD") as CanvasLayer).hide()
	world.set_process(false)
	world.set_physics_process(false)
	player.set_physics_process(false)
	player.hide()
	var clock := world.get("day_night") as Node
	clock.set("paused", true)
	clock.call("set_hour", 12.0)
	office.call("begin_prologue")
	if seated:
		office.call("_select_floor", office.call("staff_floor", "jetson_wang"))
	var staff: Dictionary = office.get("_staff")
	var reports := {}
	var camera := world.get("camera") as Camera3D
	camera.make_current()
	camera.fov = 47.0
	camera.global_position = office.to_global(Vector3(-4.1, 1.45, 5.9))
	camera.look_at(office.to_global(Vector3(-4.2, 1.23, 9.18)))
	if DirAccess.dir_exists_absolute(out) or DirAccess.make_dir_recursive_absolute(out) != OK:
		_fail("Expected new review directory")
		return
	if not seated:
		if not await _snapshot(out.path_join("baseline.png")):
			return
	for id in candidates:
		var actor := staff[id] as Node3D
		var anchor := actor.global_position
		if seated:
			camera.global_position = anchor + Vector3(-1.62, 1.72, 1.12)
			camera.look_at(anchor + Vector3.UP * .92)
			if not await _snapshot(out.path_join(id+"-baseline.png")):
				return
		var nearby := anchor + Vector3(0.0, 1.15, -0.7)
		var before := str(office.call("update_staff_attention", 1, nearby))
		var input := directory.path_join(candidates[id][0])
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if FileAccess.get_sha256(input) != candidates[id][1] or document.append_from_file(input, state) != OK:
			_fail("Candidate import failed: " + id)
			return
		var imported := document.generate_scene(state)
		var packed := PackedScene.new()
		if imported == null or packed.pack(imported) != OK:
			_fail("Candidate could not be instanced: " + id)
			return
		imported.free()
		var originals := actor.get_children()
		var visual := Rig.new()
		visual.name = "StandingCandidateReview"
		visual.idle_clip = &"Idle"
		visual.walk_clip = &"Walk"
		visual.scale = Vector3.ONE / actor.scale
		visual.set_pedestrian_model(packed)
		actor.add_child(visual)
		if not visual.is_pedestrian_visual_ready():
			_fail("Candidate failed the game's rig adapter: " + id)
			return
		for original in originals:
			if original is Node3D:
				original.hide()
		var after := str(office.call("update_staff_attention", 1, nearby))
		if before != after or not after.begins_with(str(actor.get("display_name"))) or actor.global_position != anchor:
			_fail("Dialogue or world anchor changed: " + id)
			return
		visual.set_attention_target(nearby, true)
		var pose := _pose_avatar(visual, actor, id) if social or seated else "Idle"
		if pose.is_empty():
			_fail("The candidate gesture could not be applied: " + id)
			return
		reports[id] = {"remark": after, "actor_anchor": str(anchor), "file_sha256": candidates[id][1], "pose": pose}
		if seated:
			if not await _snapshot(out.path_join(id+"-candidate.png")):
				return
	if not seated:
		if not await _snapshot(out.path_join("candidate.png")):
			return
	var f := FileAccess.open(out.path_join("report.json"), FileAccess.WRITE)
	if f == null:
		_fail("Candidate report could not be saved")
		return
	f.store_string(JSON.stringify({"actors": reports, "adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "resolution": [root.size.x, root.size.y]}, "\t"))
	f.close()
	print("SYNAXIS_CAST_REVIEW PASS ", JSON.stringify(reports))
	quit(0)


func _snapshot(path: String) -> bool:
	for frame in 30:
		await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(path) != OK:
		_fail("Candidate frame could not be saved")
		return false
	return true
