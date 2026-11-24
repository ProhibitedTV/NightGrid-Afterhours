extends SceneTree
func _initialize() -> void:
	call_deferred("_verify")
func check(ok: bool,label: String) -> bool:
	if not ok:
		push_error("TERRAIN_FEET: "+label)
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
	var mod: SkeletonModifier3D = rig.get_node("TerrainFeet")
	if not check(bool(mod.get("_ready_rig")),"real imported leg chains resolved"):
		return
	var chains: Array = mod.get("_chains")
	var chain: Vector3i = chains[0]
	var before := rig.get_bone_global_pose(chain.z).origin
	var hip := rig.get_bone_global_pose(chain.x).origin
	var knee := rig.get_bone_global_pose(chain.y).origin
	var lengths := Vector2(hip.distance_to(knee),knee.distance_to(before))
	if not check(bool(mod.call("_solve_leg",rig,chain,.09)),"two-bone correction solves"):
		return
	var after := rig.get_bone_global_pose(chain.z).origin
	var after_hip := rig.get_bone_global_pose(chain.x).origin
	var after_knee := rig.get_bone_global_pose(chain.y).origin
	if not check(after.y>before.y+.025 and absf(after_hip.distance_to(after_knee)-lengths.x)<.005 and absf(after_knee.distance_to(after)-lengths.y)<.005,"ankle rises without changing limb lengths"):
		return
	var tilt: Quaternion = mod.call("_bounded_tilt",Vector3(.55,.83,0).normalized(),1.0)
	if not check(tilt.get_angle()>0.1 and tilt.get_angle()<=deg_to_rad(20.0)+.001,"slope tilt is bounded"):
		return
	var swing_tilt: Quaternion = mod.call("_bounded_tilt",Vector3(.55,.83,0).normalized(),0.0)
	if not check(swing_tilt.get_angle()<.001,"swing foot preserves authored orientation"):
		return
	var hips: int = mod.get("_pelvis")
	var hip_before := rig.get_bone_global_pose(hips).origin.y
	mod.set("_pelvis_drop",-.08)
	mod.set("_offsets",PackedFloat32Array([-.08,0.0]))
	mod.call("_process_modification_with_delta",1.0/60.0)
	if not check(absf(rig.get_bone_global_pose(hips).origin.y-hip_before+.08)<.005,"pelvis follows lower planted surface"):
		return
	await physics_frame
	mod.call("sample_ground",player,1.0/60.0,true)
	if not check(int(mod.get("probe_count"))==2,"strict two-probe budget"):
		return
	# Real physics RID, isolated synthetic contact trace. No extra query.
	var support := player.get_rid()
	mod.call("reset")
	mod.call("_tick_lock",0,Vector3.ZERO,1.0,support,.016)
	for i in 4:
		mod.call("_tick_lock",0,Vector3(.03,0,0),1.0,support,.016)
	var lock_delta: Vector3 = mod.call("_horizontal_lock",0,Vector3(.03,0,0))
	if not check(lock_delta.x<-.01 and absf(lock_delta.y)<.001,"planted contact resists world-space drift"):
		return
	mod.call("_tick_lock",0,Vector3(.20,0,0),1.0,support,.016)
	if not check((mod.call("_horizontal_lock",0,Vector3(.20,0,0)) as Vector3).is_zero_approx(),"overreach releases lock"):
		return
	mod.call("_tick_lock",0,Vector3.ZERO,0.0,support,.016)
	mod.call("_tick_lock",0,Vector3.ZERO,1.0,support,.016)
	mod.call("_tick_lock",0,Vector3.ZERO,1.0,RID(),.016)
	if not check((mod.get("_locks") as Array)[0].is_empty(),"lost support releases lock"):
		return
	mod.call("sample_ground",player,1.0/60.0,false)
	if not check(not mod.active and int(mod.get("probe_count"))==0 and is_zero_approx(float(mod.get("_pelvis_drop"))),"airborne/action/seat gate clears terrain correction"):
		return
	print("TERRAIN_FEET PASS: weighted leg solve, preserved lengths, slope tilt, pelvis drop, bounded foot locking, two probes and state gate")
	quit(0)
