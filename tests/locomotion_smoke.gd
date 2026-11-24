extends SceneTree
const Motion = preload("res://scripts/locomotion_policy.gd")
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool,label: String) -> bool:
	if not ok:
		push_error("LOCOMOTION_SMOKE: "+label)
		quit(1)
	return ok
func _verify() -> void:
	var dt := 1.0/60.0
	var step := Motion.step_velocity(Vector3(0,3,0),Vector3(7.5,0,7.5).normalized()*7.5,true,dt)
	if not check(is_equal_approx(Vector2(step.x,step.z).length(),Motion.ACCELERATION*dt) and step.y==3.0,"vector acceleration is independent of direction and preserves gravity"):
		return
	var current := Vector3.ZERO
	for i in 60:
		current = Motion.step_velocity(current,Vector3(0,0,12.5),true,dt)
	if not check(is_equal_approx(current.z,12.5),"existing sprint top speed retained"):
		return
	for i in 30:
		current = Motion.step_velocity(current,Vector3.ZERO,true,dt)
	if not check(current.is_zero_approx(),"bounded braking without overshoot"):
		return
	current = Motion.step_velocity(Vector3(0,0,7),Vector3(0,0,-7),true,dt)
	if not check(current.z>0.0 and current.z<7.0,"no instant reversal"):
		return
	var yaw := 0.0
	for i in 30:
		yaw = Motion.step_yaw(yaw,PI*.5,false,dt)
	if not check(absf(yaw-PI*.5)<.01,"responsive weighted facing"):
		return
	if not check(Motion.run_gait(3.3,true) and not Motion.run_gait(3.3,false),"gait hysteresis avoids threshold flicker"):
		return
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var player: CharacterBody3D = world.get("player")
	player.set_physics_process(false)
	var visual: Node3D = player.get_node("Visual")
	var anim: AnimationPlayer = visual.get("animations")
	visual.call("_reset_gait")
	for i in 30:
		visual.call("update_motion",Vector3(0,0,2),true,false,false,false,dt)
	if not check(visual.get("current_pose")==&"walk","actual skinned rig uses walk"):
		return
	anim.seek(anim.current_animation_length*.62,true)
	visual.call("_play",&"run",.2,1.0)
	var phase := Motion.loop_phase(anim.current_animation_position,anim.get_animation(&"run").length)
	if not check(absf(phase-.62)<.08,"walk/run transition preserves normalized stride phase"):
		return
	for i in 35:
		visual.call("update_motion",Vector3.ZERO,true,false,false,false,dt)
	if not check(visual.get("current_pose")==&"idle","filtered stop returns to idle"):
		return
	print("LOCOMOTION_SMOKE PASS: vector acceleration, braking, reversal, facing, hysteresis and stride phase")
	quit(0)
