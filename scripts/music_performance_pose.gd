extends RefCounted
## Local, bounded arm override for stationary weighted musician rigs. The
## existing idle animation still drives the torso, head and lower body.
const ROLES = ["guitar","bass","synth"]

static func _bone(rig: Skeleton3D, wanted: String) -> int:
	var key := wanted.to_lower().replace("_","")
	for i in rig.get_bone_count():
		var name := String(rig.get_bone_name(i)).to_lower().replace("_","")
		if name.ends_with(key):
			return i
	return -1

static func arms(rig: Skeleton3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for side in ["Left","Right"]:
		var upper := _bone(rig,side+"Arm")
		var fore := _bone(rig,side+"ForeArm")
		var hand := _bone(rig,side+"Hand")
		if mini(upper,mini(fore,hand))<0:
			continue
		if rig.get_bone_parent(fore)!=upper or rig.get_bone_parent(hand)!=fore:
			continue
		result.append({"side":side,"upper":upper,"fore":fore,"hand":hand})
	return result

static func apply(rig: Skeleton3D, bindings: Array[Dictionary], role: String, phase: float) -> void:
	if role not in ROLES or bindings.size()!=2:
		return
	for binding in bindings:
		var upper: int = binding["upper"]
		var fore: int = binding["fore"]
		var hand: int = binding["hand"]
		var left: bool = binding["side"]=="Left"
		var shoulder := rig.get_bone_global_rest(upper)
		var elbow := rig.get_bone_global_rest(fore)
		var wrist := rig.get_bone_global_rest(hand)
		var parent := rig.get_bone_parent(upper)
		if parent<0:
			continue
		var parent_basis := rig.get_bone_global_rest(parent).basis
		var side := 1.0 if shoulder.origin.x>=0.0 else -1.0
		var a := shoulder.origin.distance_to(elbow.origin)
		var b := elbow.origin.distance_to(wrist.origin)
		if minf(a,b)<.001:
			continue
		var motion := sin(phase*TAU)
		var target := shoulder.origin+Vector3(-side*a*.80,-a*.55,a*.8)
		if role=="synth":
			target = shoulder.origin+Vector3(-side*a*.42,-a*.95,a*1.1)
			target.y += .035*motion*(1.0 if left else -1.0)
			target.x += .035*cos(phase*TAU)
		elif left:
			target = shoulder.origin+Vector3(side*a*.40,-a*.25,a*1.0)
			target.y += .025*motion
		else:
			target.y += (.045 if role=="guitar" else .020)*motion
		var reach := target-shoulder.origin
		var length := clampf(reach.length(),absf(a-b)+.001,a+b-.001)
		var axis := reach.normalized()
		var bend := Vector3(side,-.75,0)
		bend = (bend-axis*bend.dot(axis)).normalized()
		var along := (a*a-b*b+length*length)/(2.0*length)
		var joint := shoulder.origin+axis*along+bend*sqrt(maxf(0.0,a*a-along*along))
		var final := shoulder.origin+axis*length
		var upper_basis := Basis(Quaternion((elbow.origin-shoulder.origin).normalized(),(joint-shoulder.origin).normalized()))*shoulder.basis
		var fore_basis := Basis(Quaternion((wrist.origin-elbow.origin).normalized(),(final-joint).normalized()))*elbow.basis
		rig.set_bone_pose_rotation(upper,(parent_basis.inverse()*upper_basis).orthonormalized().get_rotation_quaternion())
		rig.set_bone_pose_rotation(fore,(upper_basis.inverse()*fore_basis).orthonormalized().get_rotation_quaternion())
