extends SceneTree
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool,label: String) -> bool:
	if not ok:
		push_error("REACH_SMOKE: "+label)
		quit(1)
	return ok
func _verify() -> void:
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var player: CharacterBody3D = world.get("player")
	player.set_physics_process(false)
	var visual: Node3D = player.get_node("Visual")
	var rig: Skeleton3D = visual.get("skeleton")
	var mod: SkeletonModifier3D = rig.get_node("ContextualReach")
	if not check(bool(mod.get("_ready_rig")),"real imported arm chains resolved"):
		return
	var chain: Vector3i = (mod.get("_chains") as Array)[1]
	var shoulder := rig.get_bone_global_pose(chain.x).origin
	var elbow := rig.get_bone_global_pose(chain.y).origin
	var wrist := rig.get_bone_global_pose(chain.z).origin
	var goal := wrist.lerp(shoulder,.18)+Vector3(0,0,.04)
	var lengths := Vector2(shoulder.distance_to(elbow),elbow.distance_to(wrist))
	if not check(bool(mod.call("_solve",rig,chain,rig.to_global(goal),1.0)),"reachable target solves"):
		return
	var after := rig.get_bone_global_pose(chain.z).origin
	var joint := rig.get_bone_global_pose(chain.y).origin
	if not check(after.distance_to(goal)<wrist.distance_to(goal) and absf(joint.distance_to(shoulder)-lengths.x)<.005 and absf(joint.distance_to(after)-lengths.y)<.005,"contact moves wrist without stretching"):
		return
	if not check(not bool(mod.call("_solve",rig,chain,rig.to_global(goal+Vector3(0,0,10)),1.0)),"unreachable target retains authored gesture"):
		return
	var target := Node3D.new()
	world.add_child(target)
	visual.call("update_motion",Vector3.ZERO,true,false,false,false)
	visual.call("play_action",&"interact")
	visual.call("reach_target",target,Vector3.ZERO,1)
	if not check(mod.active,"contextual action activates the temporary target"):
		return
	target.free()
	mod.call("_process_modification_with_delta",.016)
	if not check(not mod.active,"streamed target teardown releases reach"):
		return
	print("REACH_SMOKE PASS: imported arm solve, bounded range, preserved lengths and target cleanup")
	quit(0)
