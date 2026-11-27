extends SceneTree
## Native review only. Uses the real HQ, existing actors and external candidate
## records. Does not stage, publish or replace runtime asset pins.
const HQ=preload("res://scripts/synaxis_office.gd")
const Rig=preload("res://scripts/pedestrian_rig_visual.gd")
const ACTORS={"mika":"mika_torres","eli":"eli_brooks","security":"owen_pike","reception":"nina_bell"}

func _initialize() -> void:
	call_deferred("_review")

func _fail(reason:String) -> void:
	push_error("REMAINING_STAFF_REVIEW "+reason)
	quit(1)

static func candidate_record(folder:String,identity:String) -> Dictionary:
	var record:Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("candidate.json")))
	if not record is Dictionary or record.get("schema")!=1 or record.get("status")!="candidate-only" or record.get("actor")!=identity or record.get("package")!="ara3d@0.13.0":
		return {}
	var model:=str(record.get("model",""))
	# The exporter writes exactly one GLB under export/, not arbitrary paths.
	if model.get_base_dir()!="export" or model.get_file().get_extension().to_lower()!="glb":
		return {}
	var source:=folder.path_join(model)
	var structural:Variant=record.get("structural")
	if not structural is Dictionary or not FileAccess.file_exists(source) or FileAccess.get_sha256(source)!=str(structural.get("sha256","")):
		return {}
	return {"path":source,"sha256":structural["sha256"]}

func _review() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2 or DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus":
		_fail("Use native Forward+ with an existing candidate batch and new evidence directory")
		return
	var inputs:Dictionary={}
	for id in ACTORS:
		var identity:String=ACTORS[id]
		var record:=candidate_record(args[0].path_join(identity),identity)
		if record.is_empty():
			_fail("Missing or invalid candidate record for "+identity)
			return
		inputs[id]=record
	var out:String=args[1]
	if DirAccess.dir_exists_absolute(out) or DirAccess.make_dir_recursive_absolute(out)!=OK:
		_fail("Expected a new evidence directory")
		return
	var world:Node3D=(load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player:CharacterBody3D=world.get("player")
	var city:Node3D=world.get("city_details")
	player.global_position=HQ.ENTRY
	city.call("set_focus",HQ.ENTRY)
	var office:Node3D
	for attempt in 120:
		office=city.call("synaxis_headquarters")
		if is_instance_valid(office):
			break
		await physics_frame
	if not is_instance_valid(office):
		_fail("Headquarters did not stream")
		return
	world.get_node("GameMenus").call("hide_for_game")
	(world.get_node("HUD") as CanvasLayer).hide()
	world.set_process(false)
	world.set_physics_process(false)
	player.set_physics_process(false)
	player.hide()
	var clock:Node=world.get("day_night")
	clock.set("paused",true)
	clock.call("set_hour",12.0)
	office.call("begin_prologue")
	var intro:CanvasLayer=office.get("_intro_canvas")
	intro.hide()
	var staff:Dictionary=office.get("_staff")
	var camera:Camera3D=world.get("camera")
	camera.make_current()
	camera.fov=47.0
	var reports:Dictionary={}
	for id in ACTORS:
		var actor:Node3D=staff.get(id)
		if not is_instance_valid(actor):
			_fail("Missing authored actor "+id)
			return
		office.call("_select_floor",office.call("staff_floor",id))
		await physics_frame
		var anchor:=actor.global_position
		var forward:=actor.global_basis.orthonormalized().z
		var right:=actor.global_basis.orthonormalized().x
		# Candidate views use the same camera transform as their matched baseline.
		camera.global_position=anchor+forward*1.95+right*.65+Vector3.UP*1.35
		camera.look_at(anchor+Vector3.UP*.90)
		var camera_pose:=camera.global_transform
		var display_name:String=actor.get("display_name")
		if not await _snapshot(out.path_join(id+"-baseline.png")):
			return
		var document:=GLTFDocument.new()
		var state:=GLTFState.new()
		if document.append_from_file(inputs[id]["path"],state)!=OK:
			_fail("Import failed "+id)
			return
		var imported:=document.generate_scene(state)
		var packed:=PackedScene.new()
		if imported==null or packed.pack(imported)!=OK:
			_fail("Scene packing failed "+id)
			return
		imported.free()
		var originals:=actor.get_children()
		var visual:=Rig.new()
		visual.name="RemainingStaffReview"
		visual.idle_clip=&"Idle"
		visual.walk_clip=&"Walk"
		visual.scale=Vector3.ONE/actor.scale
		visual.set_pedestrian_model(packed)
		actor.add_child(visual)
		if not visual.is_pedestrian_visual_ready():
			_fail("Rig adapter rejected "+id)
			return
		var players:=visual.find_children("*","AnimationPlayer",true,false)
		if players.size()!=1:
			_fail("Expected one animation player "+id)
			return
		var animation:=players[0] as AnimationPlayer
		var talk:=animation.get_animation(&"Talk with gestures")
		if talk==null:
			_fail("Missing conversation clip "+id)
			return
		talk.loop_mode=Animation.LOOP_LINEAR
		animation.play(&"Talk with gestures")
		animation.seek(talk.length*.33,true)
		visual.enable_authored_office_pose()
		visual.set_attention_target(camera.global_position,true)
		for child in originals:
			if child is Node3D:
				child.hide()
		actor.set_process(false)
		if actor.global_position!=anchor or str(actor.get("display_name"))!=display_name:
			_fail("Authored identity or anchor changed "+id)
			return
		if not await _snapshot(out.path_join(id+"-candidate.png")):
			return
		reports[id]={"identity":ACTORS[id],"display_name":display_name,"candidate_sha256":inputs[id]["sha256"],
			"floor":office.call("staff_floor",id),"anchor":str(anchor),"camera":str(camera_pose),
			"animation":str(animation.current_animation),"review":"pending human visual, outfit, rights and performance review"}
	var file:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	if file==null:
		_fail("Could not write review report")
		return
	file.store_string(JSON.stringify({"actors":reports,"adapter":RenderingServer.get_video_adapter_name(),
		"driver":RenderingServer.get_current_rendering_driver_name(),"resolution":[root.size.x,root.size.y]}, "\t"))
	file.close()
	print("REMAINING_STAFF_REVIEW PASS: captured four matched actor pairs; acceptance pending")
	quit(0)

func _snapshot(path:String) -> bool:
	for frame in 30:
		await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	if image==null or image.is_empty() or image.save_png(path)!=OK:
		_fail("Could not capture "+path)
		return false
	return true
