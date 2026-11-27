extends SceneTree

const HQ = preload("res://scripts/synaxis_office.gd")
const Rig = preload("res://scripts/pedestrian_rig_visual.gd")
const CANDIDATES := {
	"dev": ["dev.glb", "0c25c792f6b8dac6e7e65f91c5a2f0699940597eb8a90c6bc029a4cbf02ca0ee"],
	"rina": ["rina.glb", "7dd3de0e72d4fbd649a71bd369cda0536633d5916a6ef467ab3a0a6be5fd8947"],
}

func _initialize() -> void:
	call_deferred("_review")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _review() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("Expected a native Forward+ candidate directory and new evidence directory")
		return
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
	for frame in 24:
		await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(out.path_join("baseline.png")) != OK:
		_fail("Baseline frame could not be saved")
		return
	for id in CANDIDATES:
		var actor := staff[id] as Node3D
		var anchor := actor.global_position
		var nearby := anchor + Vector3(0.0, 1.15, -0.7)
		var before := str(office.call("update_staff_attention", 1, nearby))
		var input := directory.path_join(CANDIDATES[id][0])
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if FileAccess.get_sha256(input) != CANDIDATES[id][1] or document.append_from_file(input, state) != OK:
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
		reports[id] = {"remark": after, "actor_anchor": str(anchor), "file_sha256": CANDIDATES[id][1]}
	for frame in 36:
		await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(out.path_join("candidate.png")) != OK:
		_fail("Candidate frame could not be saved")
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
