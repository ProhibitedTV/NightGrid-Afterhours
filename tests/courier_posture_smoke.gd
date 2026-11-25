extends SceneTree
const Posture = preload("res://scripts/courier_posture.gd")
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool,label: String) -> bool:
	if not ok:
		push_error("POSTURE_SMOKE: "+label)
		quit(1)
	return ok
func _verify() -> void:
	var forward := Posture.target_lean(Vector3(0,0,24),7.5,0)
	var brake := Posture.target_lean(Vector3(0,0,-24),7.5,0)
	var turn := Posture.target_lean(Vector3.ZERO,7.5,4.0)
	if not check(forward.x>0 and brake.x<0 and absf(forward.x)<=Posture.MAX_PITCH and absf(turn.y)<=Posture.MAX_ROLL and turn.y<0,"acceleration, braking and turn lean are opposed and bounded"):
		return
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var player: CharacterBody3D = world.get("player")
	player.set_physics_process(false)
	var visual: Node3D = player.get_node("Visual")
	var rig: Skeleton3D = visual.get("skeleton")
	var mod: SkeletonModifier3D = rig.get_node("ReactivePosture")
	var spine: int = mod.get("_spine")
	if not check(spine>=0,"imported spine resolved"):
		return
	mod.call("update_posture",Vector3(0,0,4),0.0,.016,true)
	for i in 12:
		mod.call("update_posture",Vector3(0,0,4),2.0,.016,true)
	var before := rig.get_bone_global_pose(spine)
	var foot := rig.find_bone("LeftFoot")
	var foot_before := rig.get_bone_global_pose(foot)
	mod.call("_process_modification_with_delta",.016)
	var after := rig.get_bone_global_pose(spine)
	if not check(before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion())>.01 and before.origin.distance_to(after.origin)<.001 and foot_before.origin.distance_to(rig.get_bone_global_pose(foot).origin)<.001,"torso tilts independently of foot and translation"):
		return
	mod.call("update_posture",Vector3.ZERO,0.0,.016,false)
	if not check(not mod.active and (mod.get("lean") as Vector2).is_zero_approx(),"action gate resets inertia"):
		return
	print("POSTURE_SMOKE PASS: bounded acceleration/braking/turn lean, actual rig isolation and reset")
	quit(0)
