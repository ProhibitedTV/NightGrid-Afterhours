extends SceneTree
const Geometry=preload("res://scripts/wardrobe_geometry.gd")
const Visual=preload("res://scripts/courier_visual.gd")
func _initialize() -> void:
	call_deferred("_verify")
func _verify() -> void:
	var actor:=Visual.new()
	root.add_child(actor)
	await process_frame
	var rig:Skeleton3D=actor.skeleton
	var animation:AnimationPlayer=actor.animations
	var target:MeshInstance3D
	for child in actor.find_children("*","MeshInstance3D",true,false):
		if child.skin!=null:
			target=child
			break
	if target==null:
		push_error("WARDROBE: missing live skinned mesh")
		quit(1)
		return
	var original_mesh:=target.mesh
	var original_skin:=target.skin
	var paths:=OS.get_environment("NIGHTGRID_WARDROBE_CANDIDATES").split(",",false)
	if paths.is_empty():
		push_error("WARDROBE: no required candidates supplied")
		quit(1)
		return
	for path in paths:
		var donor:=Geometry.extract(rig,load(path) as PackedScene)
		if donor.is_empty():
			push_error("WARDROBE: incompatible imported candidate "+path)
			quit(1)
			return
		target.mesh=donor["mesh"]
		target.skin=donor["skin"]
		for pose in ["idle","walk","run","sit","drive_car","aim"]:
			animation.play(pose)
			animation.advance(.15)
			if actor.skeleton!=rig or actor.animations!=animation or not target.visible:
				push_error("WARDROBE: live rig changed")
				quit(1)
				return
		target.mesh=original_mesh
		target.skin=original_skin
	print("WARDROBE_GEOMETRY PASS: ",paths.size()," imported combinations on the live rig; visual inspection still required")
	quit(0)
