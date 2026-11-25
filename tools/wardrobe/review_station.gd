extends SceneTree
## Development-only native fitting room. Not called by gameplay or save code.
const Geometry=preload("res://scripts/wardrobe_geometry.gd")
const Visual=preload("res://scripts/courier_visual.gd")
const POSES=["idle","walk","run","sit","drive_car","aim"]
var actor:Node3D
var rig:Skeleton3D
var animation:AnimationPlayer
var target:MeshInstance3D
var original_mesh:Mesh
var original_skin:Skin
var candidate_paths:PackedStringArray=[]
var index:=0
var pose_index:=0
var orbit:=0.0
var distance:=3.5
var camera:Camera3D
var status:Label
var comparing:=false
var active_donor:Dictionary={}
var capture_dir:=""
var busy:=false

func _initialize()->void:
	call_deferred("_setup")

func _setup()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir=arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("res://assets/models/nightgrid/wardrobe_candidates/") and arg.ends_with("/Morrow_Courier.glb") and not arg.contains(".."):
			candidate_paths.append(arg)
	if candidate_paths.is_empty():
		push_error("Pass one or more imported wardrobe candidate res:// paths after --")
		quit(2)
		return
	var stage:=Node3D.new()
	root.add_child(stage)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("252932")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("bfc8dc")
	env.environment.ambient_light_energy=.65
	stage.add_child(env)
	var floor_mesh:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(8,8)
	floor_mesh.mesh=plane
	var floor_mat:=StandardMaterial3D.new()
	floor_mat.albedo_color=Color("383d45")
	floor_mat.roughness=.9
	floor_mesh.material_override=floor_mat
	floor_mesh.position.y=-.95
	stage.add_child(floor_mesh)
	for data in [[Vector3(2,3,3),Color("fff0d5"),1.9],[Vector3(-2,2,-2),Color("9fc6ff"),1.3]]:
		var light:=OmniLight3D.new()
		light.position=data[0]
		light.light_color=data[1]
		light.light_energy=data[2]
		light.omni_range=8
		stage.add_child(light)
	actor=Visual.new()
	stage.add_child(actor)
	await process_frame
	rig=actor.get("skeleton")
	animation=actor.get("animations")
	for node in actor.find_children("*","MeshInstance3D",true,false):
		if node.skin!=null:
			target=node
			break
	if target==null:
		push_error("No live skin found")
		quit(2)
		return
	original_mesh=target.mesh
	original_skin=target.skin
	camera=Camera3D.new()
	camera.fov=42
	stage.add_child(camera)
	camera.current=true
	var hud:=CanvasLayer.new()
	stage.add_child(hud)
	status=Label.new()
	status.position=Vector2(20,18)
	status.add_theme_font_size_override("font_size",20)
	hud.add_child(status)
	root.window_input.connect(_input)
	_select_candidate()
	_update_camera()

func _restore()->void:
	target.mesh=original_mesh
	target.skin=original_skin

func _select_candidate()->void:
	_restore()
	active_donor={}
	comparing=false
	var path:String=candidate_paths[index]
	if ResourceLoader.exists(path,"PackedScene"):
		active_donor=Geometry.review_donor(rig,target,load(path) as PackedScene)
	if active_donor.is_empty():
		comparing=true
		push_warning("Rejected or missing candidate: "+path)
	else:
		target.mesh=active_donor["mesh"]
		target.skin=active_donor["skin"]
	_apply_pose()

func _apply_pose()->void:
	var pose:String=POSES[pose_index]
	if animation.has_animation(pose):
		animation.play(pose)
	else:
		push_warning("Missing pose: "+pose)
	_update_status()

func _update_camera()->void:
	camera.position=Vector3(sin(orbit)*distance,.15,cos(orbit)*distance)
	camera.look_at(Vector3(0,-.05,0),Vector3.UP)

func _update_status()->void:
	status.text="%s | %s | %s\n←/→ orbit   ↑/↓ pose   N/P candidate   B compare   +/- zoom   F10 capture" % [candidate_paths[index].get_base_dir().get_file(),POSES[pose_index],"BASE / rejected" if active_donor.is_empty() else ("BASE" if comparing else "CANDIDATE")]

func _input(event:InputEvent)->void:
	if not is_instance_valid(status) or not event is InputEventKey or not event.pressed or event.echo or busy:
		return
	match event.keycode:
		KEY_LEFT: orbit-=PI/8.0
		KEY_RIGHT: orbit+=PI/8.0
		KEY_UP:
			pose_index=posmod(pose_index+1,POSES.size())
			_apply_pose()
		KEY_DOWN:
			pose_index=posmod(pose_index-1,POSES.size())
			_apply_pose()
		KEY_N:
			index=posmod(index+1,candidate_paths.size())
			_select_candidate()
		KEY_P:
			index=posmod(index-1,candidate_paths.size())
			_select_candidate()
		KEY_B:
			if not active_donor.is_empty():
				comparing=not comparing
				if comparing:
					_restore()
				else:
					target.mesh=active_donor["mesh"]
					target.skin=active_donor["skin"]
				_update_status()
		KEY_EQUAL,KEY_KP_ADD: distance=maxf(1.6,distance-.25)
		KEY_MINUS,KEY_KP_SUBTRACT: distance=minf(6.0,distance+.25)
		KEY_F10: _capture()
		KEY_ESCAPE: quit()
	_update_camera()

func _capture()->void:
	if capture_dir.is_empty() or active_donor.is_empty():
		return
	busy=true
	await RenderingServer.frame_post_draw
	var folder:=ProjectSettings.globalize_path(capture_dir)
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:
		push_warning("Cannot create review capture directory")
		busy=false
		return
	var id:String=candidate_paths[index].get_base_dir().get_file()
	var name:="%s_%s_%s_%d.png" % [id,POSES[pose_index],"base" if comparing else "candidate",Time.get_ticks_msec()]
	var error:=root.get_texture().get_image().save_png(folder.path_join(name))
	if error!=OK:
		push_warning("Capture failed: "+str(error))
	else:
		print("WARDROBE REVIEW CAPTURE: "+folder.path_join(name))
	busy=false
