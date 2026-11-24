extends SceneTree
## Offline analysis of the imported, weighted character rig; never run during
## gameplay. Samples actual evaluated bone transforms, not source clip labels.
const Model = preload("res://assets/models/nightgrid/courier/morrow_courier.glb")
const LOOPS = [&"walk",&"run",&"walk_back",&"strafe_left",&"strafe_right",&"aim_walk",&"aim_run",&"aim_left",&"aim_right"]
const SAMPLES = 64

func _initialize() -> void:
	call_deferred("_measure")

func _measure() -> void:
	var character := Model.instantiate()
	root.add_child(character)
	var skeleton := character.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var player := character.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var left := skeleton.find_bone("LeftFoot")
	var right := skeleton.find_bone("RightFoot")
	if left<0 or right<0:
		push_error("GAIT_ANALYSIS: imported foot bones missing")
		quit(1)
		return
	var profile := {}
	for clip in LOOPS:
		if not player.has_animation(clip):
			push_error("GAIT_ANALYSIS: missing "+str(clip))
			quit(1)
			return
		var duration := player.get_animation(clip).length
		player.play(clip,0.0)
		var l: Array[Vector3] = []
		var r: Array[Vector3] = []
		for i in SAMPLES:
			player.seek(float(i)*duration/float(SAMPLES),true)
			skeleton.force_update_all_bone_transforms()
			l.append(skeleton.get_bone_global_pose(left).origin)
			r.append(skeleton.get_bone_global_pose(right).origin)
		var lp := _contact(l,duration)
		var rp := _contact(r,duration)
		if not bool(lp.get("valid",false)) or not bool(rp.get("valid",false)):
			push_error("GAIT_ANALYSIS: invalid foot trace "+str(clip))
			quit(1)
			return
		profile[str(clip)] = {"duration":duration,"left":lp,"right":rp}
	player.stop()
	character.queue_free()
	await process_frame
	var json := JSON.stringify(profile,"\t")
	var output := FileAccess.open("user://courier_gait_profile.json",FileAccess.WRITE)
	if output == null:
		push_error("GAIT_ANALYSIS: cannot write evidence")
		quit(1)
		return
	output.store_string(json)
	output.close()
	print("GAIT_ANALYSIS_JSON ",JSON.stringify(profile))
	print("GAIT_ANALYSIS PASS: sampled ",profile.size()," weighted gait loops, ",SAMPLES," poses each")
	quit(0)

func _contact(trace: Array[Vector3],duration: float) -> Dictionary:
	var low := INF
	var high := -INF
	for p in trace:
		if not p.is_finite():
			return {"valid":false}
		low = minf(low,p.y)
		high = maxf(high,p.y)
	var threshold := low+maxf(.015,(high-low)*.16)
	var stance: Array[int] = []
	var velocities: Array[float] = []
	var step := duration/float(SAMPLES)
	var best := -1
	var best_score := INF
	for i in SAMPLES:
		var prev := trace[posmod(i-1,SAMPLES)]
		var next := trace[(i+1)%SAMPLES]
		var velocity := (next-prev)/(2.0*step)
		# Near minimum ankle height and low vertical velocity approximate
		# stance. Horizontal speed of these samples estimates slide-free gait.
		if trace[i].y<=threshold and absf(velocity.y)<=.30:
			stance.append(i)
			velocities.append(Vector2(velocity.x,velocity.z).length())
			var score := (trace[i].y-low)+absf(velocity.y)*.06
			if score<best_score:
				best_score = score
				best = i
	velocities.sort()
	var speed := velocities[velocities.size()/2] if not velocities.is_empty() else 0.0
	# A stationary clip or a badly retargeted foot must remain visible in
	# evidence, not silently become a guessed contact profile.
	return {"valid":duration>0.0 and high-low>.001 and not stance.is_empty(),"min_ankle_y":low,"max_ankle_y":high,"phase":float(best)/float(SAMPLES),"stance_fraction":float(stance.size())/float(SAMPLES),"estimated_stance_speed":speed,"samples":stance}
