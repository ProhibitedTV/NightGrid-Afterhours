extends SceneTree
const Rig = preload("res://scripts/pedestrian_rig_visual.gd")
const MusicPose = preload("res://scripts/music_performance_pose.gd")
func _initialize() -> void:
	call_deferred("_verify")
func _check(ok: bool,message: String) -> bool:
	if not ok:
		push_error("PEDESTRIAN_RIG: "+message)
		quit(1)
	return ok
func _fixture() -> Node3D:
	# Synthetic weighted triangle only to demonstrate the loader contract.
	# Not a character model or gameplay art.
	var rig := Rig.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	skeleton.add_bone("Root")
	skeleton.add_bone("Leg")
	skeleton.set_bone_parent(1,0)
	skeleton.add_bone("Head")
	skeleton.set_bone_parent(2,0)
	skeleton.set_bone_rest(2,Transform3D(Basis.IDENTITY,Vector3(0,1.5,0)))
	rig.add_child(skeleton)
	var mesh := MeshInstance3D.new()
	mesh.name = "Clothing"
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0,0,0,0,1,0,0,0,1,0,0,0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1,0,0,0,1,0,0,0,1,0,0,0])
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	surface.surface_set_material(0,StandardMaterial3D.new())
	mesh.mesh = surface
	mesh.skin = Skin.new()
	mesh.skin.add_bind(0,Transform3D.IDENTITY)
	mesh.skin.add_bind(1,Transform3D.IDENTITY)
	mesh.skeleton = NodePath("../Skeleton")
	rig.add_child(mesh)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	rig.add_child(player)
	var clips := AnimationLibrary.new()
	for id in [&"idle",&"walk"]:
		var anim := Animation.new()
		anim.length = 1.0
		anim.loop_mode = Animation.LOOP_LINEAR
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track,NodePath("Skeleton:Leg"))
		anim.rotation_track_insert_key(track,0.0,Quaternion.IDENTITY)
		anim.rotation_track_insert_key(track,0.5,Quaternion(Vector3.RIGHT,0.25 if id==&"walk" else 0.02))
		clips.add_animation(id,anim)
	player.add_animation_library(&"",clips)
	rig.skeleton_path = NodePath("Skeleton")
	rig.animation_player_path = NodePath("AnimationPlayer")
	rig.clothing_mesh_path = NodePath("Clothing")
	rig.clothing_surface = 0
	return rig
func _verify() -> void:
	var invalid := Rig.new()
	root.add_child(invalid)
	if not _check(not invalid.is_pedestrian_visual_ready(),"missing rig rejected"):
		return
	var rig = _fixture()
	root.add_child(rig)
	rig.set_process(false)
	if not _check(rig.is_pedestrian_visual_ready() and rig.animation_state()["variants"]==6,"weighted mesh and looping clips"):
		return
	var clothing := rig.get_node("Clothing") as MeshInstance3D
	rig.set_pedestrian_style(2)
	var original := clothing.get_surface_override_material(0)
	rig.set_pedestrian_style(3)
	if not _check(original!=clothing.get_surface_override_material(0),"palette variation"):
		return
	rig.set_pedestrian_style(2)
	if not _check(original==clothing.get_surface_override_material(0),"reuse prebuilt material"):
		return
	rig.set_locomotion(1.2)
	for i in range(20):
		rig._process(1.0/60.0)
	if not _check(rig.animation_state()["walking"] and rig.animation_state()["clip"]=="walk","measured walking state"):
		return
	rig.set_locomotion(0.0)
	for i in range(25):
		rig._process(1.0/60.0)
	if not _check(not rig.animation_state()["walking"] and rig.animation_state()["clip"]=="idle","smooth stop"):
		return
	rig.set_locomotion(1.2)
	rig._process(0.2)
	rig.reset_pedestrian_visual()
	if not _check(not rig.animation_state()["walking"] and rig.animation_state()["clip"]=="idle","pooled reset"):
		return
	# An additive head turn preserves the animated base pose and resets cleanly.
	var head:=rig.get_node("Skeleton") as Skeleton3D
	var base_rotation:=head.get_bone_pose_rotation(2)
	rig.set_attention_target(Vector3(2,1.5,3),true)
	for i in range(20):
		rig._process(1.0/60.0)
	if not _check(rig.get("_attention_applied") and head.get_bone_pose_rotation(2)!=base_rotation,"skinned attention turns the actual head bone"):
		return
	var turned:=head.get_bone_pose_rotation(2)
	for i in range(60):
		rig._process(1.0/60.0)
	if not _check(head.get_bone_pose_rotation(2).is_equal_approx(turned),"attention pose does not accumulate"):
		return
	rig.set_attention_target(Vector3.INF,true)
	for i in range(30):
		rig._process(1.0/60.0)
	if not _check(not rig.get("_attention_applied") and head.get_bone_pose_rotation(2).is_equal_approx(base_rotation),"invalid target releases gaze"):
		return
	rig.set_attention_target(Vector3(-2,1.5,3),true)
	rig._process(.2)
	rig.reset_pedestrian_visual()
	if not _check(not rig.get("_attention_applied") and head.get_bone_pose_rotation(2).is_equal_approx(base_rotation),"pool reset clears gaze"):
		return
	# An authored office clip must remain selected even when street speed changes.
	var office_player:=rig.get_node("AnimationPlayer") as AnimationPlayer
	var office_library:=AnimationLibrary.new()
	office_library.add_animation(&"seated",office_player.get_animation(&"idle").duplicate())
	office_player.add_animation_library(&"office",office_library)
	office_player.play(&"office/seated")
	office_player.seek(.25,true)
	rig.enable_authored_office_pose()
	rig.set_process(false)
	rig.set_locomotion(1.2)
	rig.set_attention_target(Vector3(2,1.5,3),true)
	for i in range(20):
		rig._process(1.0/60.0)
	if not _check(office_player.current_animation=="office/seated" and office_player.current_animation_position>.25 and rig.get("_attention_applied"),"authored office clip advances without street replacement and keeps gaze"):
		return
	rig.set_attention_target(Vector3.ZERO,false)
	for i in range(30):
		rig._process(1.0/60.0)
	if not _check(not rig.get("_attention_applied") and head.get_bone_pose_rotation(2).is_equal_approx(base_rotation),"office gaze releases to authored pose"):
		return
	rig.reset_pedestrian_visual()
	if not _check(not rig.get("_office_pose") and rig.animation_state()["clip"]=="idle","pool reset releases office mode"):
		return
	# Synthetic arms exercise the reversible layer independently of mesh art.
	var body := Node3D.new()
	root.add_child(body)
	var arms := Skeleton3D.new()
	body.add_child(arms)
	arms.add_bone("Spine")
	for side in ["Left","Right"]:
		var upper := arms.get_bone_count()
		var sign_x := 1.0 if side=="Left" else -1.0
		arms.add_bone(side+"Arm")
		arms.set_bone_parent(upper,0)
		arms.set_bone_rest(upper,Transform3D(Basis.IDENTITY,Vector3(sign_x*.2,1,0)))
		arms.add_bone(side+"ForeArm")
		arms.set_bone_parent(upper+1,upper)
		arms.set_bone_rest(upper+1,Transform3D(Basis.IDENTITY,Vector3(sign_x*.3,0,0)))
		arms.add_bone(side+"Hand")
		arms.set_bone_parent(upper+2,upper+1)
		arms.set_bone_rest(upper+2,Transform3D(Basis.IDENTITY,Vector3(sign_x*.25,0,0)))
	arms.reset_bone_poses()
	arms.force_update_all_bone_transforms()
	var bindings := MusicPose.bind(arms)
	if not _check(bindings.size()==2 and MusicPose.bind(rig.get_node("Skeleton")).is_empty(),"arm chain resolution and unsupported rig guard"):
		return
	for role in MusicPose.ROLES:
		var saved := MusicPose.apply(arms,body,bindings,role,.25)
		if not _check(saved.size()==4 and arms.get_bone_pose_rotation(1).is_finite() and arms.get_bone_pose_rotation(1)!=saved[1],"finite changed arm pose "+role):
			return
		MusicPose.restore(arms,saved)
		if not _check(arms.get_bone_pose_rotation(1)==saved[1],"restore exact prior arm rotation"):
			return
	if not _check(MusicPose.apply(arms,body,bindings,"sampler",NAN).is_empty(),"reject invalid phase"):
		return
	body.queue_free()
	# Exercise the exact three imported weighted rigs already used by taxi riders.
	for model in preload("res://scripts/taxi_waiting_rider.gd").MODELS:
		var musician := Rig.new()
		musician.set_pedestrian_model(model)
		root.add_child(musician)
		if not _check(musician.is_pedestrian_visual_ready() and musician.set_music_performance("sampler"),"imported musician arm chains"):
			return
		musician._process(.1)
		if not _check(musician.get("_music_restore").size()==4,"imported pose layer applied"):
			return
		musician.reset_pedestrian_visual()
		if not _check(musician.get("_music_restore").is_empty() and musician.get("_music_role")=="" and musician.animation_state()["clip"]=="idle","pool reset restores imported musician"):
			return
		musician.free()
	print("PEDESTRIAN_RIG_SMOKE PASS: weighted rig, looping walk/idle, palette reuse, measured speed and reset")
	quit(0)
