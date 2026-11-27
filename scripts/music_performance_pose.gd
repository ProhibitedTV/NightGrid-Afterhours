extends RefCounted
## Optional, bounded arm-only performance layer. Adapted from draft #315.
## The owner restores the previous animation pose before advancing its clip.
const ROLES = ["guitar","bass","synth","sampler","rap"]

static func _compact(name: String) -> String:
	return name.to_lower().replace("_","").replace("-","").replace(".","").replace(":","").replace(" ","")

static func _find(rig: Skeleton3D, side: String, terms: Array) -> int:
	for i in range(rig.get_bone_count()):
		var name := _compact(str(rig.get_bone_name(i)))
		for term in terms:
			if name.ends_with(side+term) or name.ends_with(term+side) or name.ends_with(term+side.substr(0,1)):
				return i
	return -1

static func bind(rig: Skeleton3D) -> Array[Dictionary]:
	var bindings: Array[Dictionary] = []
	if not is_instance_valid(rig):
		return bindings
	for side in ["left","right"]:
		var upper := _find(rig,side,["upperarm","arm"])
		var fore := _find(rig,side,["forearm","lowerarm"])
		var hand := _find(rig,side,["hand","wrist"])
		if mini(upper,mini(fore,hand))<0 or rig.get_bone_parent(fore)!=upper or rig.get_bone_parent(hand)!=fore:
			bindings.clear()
			return bindings
		bindings.append({"side":side,"upper":upper,"fore":fore,"hand":hand})
	return bindings

static func _aim(rig: Skeleton3D, bone: int, child: int, direction: Vector3) -> void:
	var at := rig.get_bone_global_pose(bone)
	var axis := rig.get_bone_global_pose(child).origin-at.origin
	if not at.is_finite() or not axis.is_finite() or axis.length_squared()<0.00001 or not direction.is_finite() or direction.length_squared()<0.00001:
		return
	at.basis=Basis(Quaternion(axis.normalized(),direction.normalized()))*at.basis
	rig.set_bone_global_pose(bone,at)
	rig.force_update_all_bone_transforms()

static func apply(rig: Skeleton3D, visual: Node3D, bindings: Array[Dictionary], role: String, phase: float) -> Dictionary:
	if not is_instance_valid(rig) or not is_instance_valid(visual) or role not in ROLES or bindings.size()!=2 or not is_finite(phase):
		return {}
	var basis := rig.global_basis.inverse()*visual.global_basis
	if not basis.is_finite():
		return {}
	var saved := {}
	for binding in bindings:
		for key in ["upper","fore"]:
			var bone: int = binding[key]
			saved[bone]=rig.get_bone_pose_rotation(bone)
	var motion := sin(fposmod(phase,1.0)*TAU)
	for binding in bindings:
		var side := 1.0 if binding["side"]=="left" else -1.0
		var upper := Vector3(-side*.22,-1,.50)
		var fore := Vector3(-side*.55,-.08,1)
		if role=="rap":
			if binding["side"]=="right":
				upper=Vector3(.15,-.65,.65)
				fore=Vector3(.05,.85,.45)
			else:
				upper=Vector3(.30,-.55,.75)
				fore=Vector3(.20,.20+motion*.35,1)
		elif role in ["synth","sampler"]:
			upper = Vector3(-side*.10,-1,.65)
			fore = Vector3(-side*.18,-.16+side*motion*.12,1)
		elif binding["side"]=="left":
			upper = Vector3(side*.45,-.65,.75)
			fore = Vector3(side*.62,.15,1)
		else:
			fore.y += motion*(.24 if role=="guitar" else .12)
		_aim(rig,binding["upper"],binding["fore"],basis*upper)
		_aim(rig,binding["fore"],binding["hand"],basis*fore)
	return saved

static func restore(rig: Skeleton3D, saved: Dictionary) -> void:
	if not is_instance_valid(rig):
		return
	for bone in saved:
		if bone>=0 and bone<rig.get_bone_count():
			rig.set_bone_pose_rotation(bone,saved[bone])
