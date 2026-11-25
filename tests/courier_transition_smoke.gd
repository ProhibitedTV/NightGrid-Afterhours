extends SceneTree
const Motion = preload("res://scripts/locomotion_policy.gd")
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool,label: String) -> bool:
	if not ok:
		push_error("TRANSITION_SMOKE: "+label)
		quit(1)
	return ok
func _verify() -> void:
	if not check(Motion.landing_rate(3)>Motion.landing_rate(9) and Motion.landing_rate(9)>Motion.landing_rate(15),"impact modulates recovery rate"):
		return
	if not check(Motion.pivot_clip(.5,4)==&"turn_left" and Motion.pivot_clip(.5,-4)==&"turn_right" and Motion.pivot_clip(7,4)==&"","pivot selection is directional and slow-speed only"):
		return
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var player: CharacterBody3D = world.get("player")
	player.set_physics_process(false)
	var visual: Node3D = player.get_node("Visual")
	var anim: AnimationPlayer = visual.get("animations")
	visual.call("update_motion",Vector3.ZERO,true,false,false,false,.016,0.0,5.0)
	if not check(visual.get("current_pose")==&"turn_left","uses existing authored turn clip"):
		return
	visual.call("update_motion",Vector3(0,0,4),true,false,false,false,.016,0.0,5.0)
	if not check(visual.get("_action")==&"","movement interrupts pivot without changing velocity"):
		return
	visual.call("update_motion",Vector3.ZERO,false,true,false,false)
	visual.call("update_motion",Vector3.ZERO,true,false,true,false,.016,14.0,0.0)
	if not check(visual.get("current_pose")==&"jump_land" and is_equal_approx(anim.speed_scale,Motion.landing_rate(14)),"actual rig uses impact-sensitive landing"):
		return
	visual.call("_finish_action",&"jump_land")
	if not check(visual.get("_action")==&"","landing completes without locking locomotion"):
		return
	print("TRANSITION_SMOKE PASS: directional authored pivots, interruption and impact-sensitive landing")
	quit(0)
