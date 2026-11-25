extends RefCounted
## Import-time authored donors only. Reuse the live skeleton/animation player.
## Candidates are not automatically listed in stores or sold.
static func compatible(live:Skeleton3D,donor:Skeleton3D) -> bool:
	if live==null or donor==null or live.get_bone_count()!=donor.get_bone_count():
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
