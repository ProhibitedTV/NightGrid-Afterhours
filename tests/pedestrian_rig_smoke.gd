extends SceneTree
const Rig = preload("res://scripts/pedestrian_rig_visual.gd")
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
	print("PEDESTRIAN_RIG_SMOKE PASS: weighted rig, looping walk/idle, palette reuse, measured speed and reset")
	quit(0)
