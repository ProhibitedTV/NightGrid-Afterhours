extends RefCounted
## Import-time authored donors only. Reuse the live skeleton/animation player.
## Candidates are not automatically listed in stores or sold.
static func compatible(live:Skeleton3D,donor:Skeleton3D) -> bool:
	if live==null or donor==null or live.get_bone_count()==0 or live.get_bone_count()!=donor.get_bone_count():
		return false
	for i in live.get_bone_count():
		if live.get_bone_name(i)!=donor.get_bone_name(i) or live.get_bone_parent(i)!=donor.get_bone_parent(i) or not live.get_bone_rest(i).is_equal_approx(donor.get_bone_rest(i)):
			return false
	return true

static func extract(live:Skeleton3D,scene:PackedScene) -> Dictionary:
	if scene==null:
		return {}
	var candidate:=scene.instantiate()
	var rigs:=candidate.find_children("*","Skeleton3D",true,false)
	var meshes:Array[MeshInstance3D]=[]
	for node in candidate.find_children("*","MeshInstance3D",true,false):
		if node.skin!=null:
			meshes.append(node)
	var result:Dictionary={}
	if rigs.size()==1 and meshes.size()==1 and compatible(live,rigs[0]) and meshes[0].mesh!=null:
		result={"mesh":meshes[0].mesh,"skin":meshes[0].skin}
	candidate.free()
	return result

# The donor is review-only. Validate the imported skin against the actual target
# rather than accepting a matching bone list with mismatched inverse binds.
static func skin_compatible(original:Skin,donor:Skin) -> bool:
	if original==null or donor==null or original.get_bind_count()==0 or original.get_bind_count()!=donor.get_bind_count():
		return false
	for i in original.get_bind_count():
		if original.get_bind_name(i)!=donor.get_bind_name(i) or original.get_bind_bone(i)!=donor.get_bind_bone(i) or not original.get_bind_pose(i).is_equal_approx(donor.get_bind_pose(i)):
			return false
	return true

static func review_donor(live:Skeleton3D,target:MeshInstance3D,scene:PackedScene) -> Dictionary:
	if target==null or target.mesh==null or target.skin==null:
		return {}
	var donor:=extract(live,scene)
	if donor.is_empty() or not skin_compatible(target.skin,donor["skin"]):
		return {}
	return donor
