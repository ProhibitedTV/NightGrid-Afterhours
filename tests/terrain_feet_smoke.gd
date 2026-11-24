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
	await physics_frame
	mod.call("sample_ground",player,1.0/60.0,true)
	if not check(int(mod.get("probe_count"))==2,"strict two-probe budget"):
		return
	mod.call("sample_ground",player,1.0/60.0,false)
	if not check(not mod.active and int(mod.get("probe_count"))==0,"airborne/action/seat gate clears terrain correction"):
		return
	print("TERRAIN_FEET PASS: weighted leg solve, preserved lengths, two probes and state gate")
	quit(0)
