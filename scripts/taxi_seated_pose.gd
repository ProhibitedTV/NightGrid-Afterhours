extends RefCounted
## Original static seated pose pilot for the imported CC0 humanoid rig.
## Resolve common humanoid bone names; fail closed for unsupported rigs.
static func _bone(skeleton:Skeleton3D,terms:Array,side:String="")->int:
	for i in range(skeleton.get_bone_count()):
		var name:=str(skeleton.get_bone_name(i)).to_lower()
		var compact:=name.replace("_","").replace("-","").replace(".","").replace(":","").replace(" ","")
		if not side.is_empty():
			var short:=side.substr(0,1)
			if not compact.contains(side) and not name.begins_with(short+"_") and not name.ends_with("_"+short) and not name.ends_with("."+short) and not compact.ends_with(short):
				continue
		for term in terms:
			if compact.contains(term):
				return i
	return -1

static func _aim(skeleton:Skeleton3D,bone:int,child:int,direction:Vector3)->bool:
	if bone<0 or child<0:
		return false
	var at:=skeleton.get_bone_global_pose(bone)
	var next:=skeleton.get_bone_global_pose(child)
	var axis:=next.origin-at.origin
	if axis.length_squared()<.00001:
		return false
	var turn:=Quaternion(axis.normalized(),direction.normalized())
	at.basis=Basis(turn)*at.basis
	skeleton.set_bone_global_pose(bone,at)
	skeleton.force_update_all_bone_transforms()
	return true

static func apply(skeleton:Skeleton3D,visual:Node3D)->Dictionary:
	if not is_instance_valid(skeleton):
		return {}
	var hip:=_bone(skeleton,["hips","pelvis"])
	var head:=_bone(skeleton,["head"])
	if hip<0 or head<0:
		return {}
	var legs:Array[Dictionary]=[]
	for side in ["left","right"]:
		var thigh:=_bone(skeleton,["upleg","thigh","upperleg"],side)
		var shin:=_bone(skeleton,["lowerleg","calf","shin"],side)
		if shin<0 and thigh>=0:
			# Mixamo labels the direct child of UpLeg as Leg.
			for i in range(skeleton.get_bone_count()):
				if skeleton.get_bone_parent(i)==thigh:
					shin=i
					break
		var foot:=_bone(skeleton,["foot","ankle"],side)
		if mini(thigh,mini(shin,foot))<0:
			return {}
		legs.append({"thigh":thigh,"shin":shin,"foot":foot})
	skeleton.reset_bone_poses()
	skeleton.force_update_all_bone_transforms()
	# Visual forward is +Z; convert directions into the actual skeleton basis.
	var basis:=skeleton.global_basis.inverse()*visual.global_basis
	var forward:Vector3=(basis*Vector3(0,-.10,1)).normalized()
	var down:Vector3=(basis*Vector3(0,-1,.12)).normalized()
	for leg in legs:
		if not _aim(skeleton,leg["thigh"],leg["shin"],forward) or not _aim(skeleton,leg["shin"],leg["foot"],down):
			return {}
	for side in ["left","right"]:
		var upper:=_bone(skeleton,["upperarm","arm"],side)
		var fore:=_bone(skeleton,["forearm","lowerarm"],side)
		var hand:=_bone(skeleton,["hand","wrist"],side)
		var inward:float=.14 if side=="left" else -.14
		if upper>=0 and fore>=0 and hand>=0:
			_aim(skeleton,upper,fore,basis*Vector3(inward,-1,.14))
			_aim(skeleton,fore,hand,basis*Vector3(inward,-.20,1))
	var hip_point:=visual.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hip).origin))
	var head_point:=visual.to_local(skeleton.to_global(skeleton.get_bone_global_pose(head).origin))
	var height:=head_point.y-hip_point.y
	if not is_finite(height) or height<.2:
		return {}
	return {"hip":hip_point,"scale":clampf(.60/height,.78,1.0)}
