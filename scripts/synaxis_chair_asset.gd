extends RefCounted
## Imported original mesh shared across floors, no per-chair scene processing.
const MODEL=preload("res://assets/models/nightgrid/synaxis_task_chair/task_chair.gltf")
static var _mesh:Mesh

static func mesh_resource() -> Mesh:
	if _mesh==null:
		var root:=MODEL.instantiate()
		var instance:=root as MeshInstance3D
		if instance==null:
			for child in root.find_children("*","MeshInstance3D",true,false):
				instance=child as MeshInstance3D
				break
		if instance!=null:
			_mesh=instance.mesh
		root.free()
	return _mesh

static func pose(at:Vector3,face:float,scale_factor:float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,0.0 if face>0 else PI).scaled_local(Vector3.ONE*scale_factor),at)

static func install(parent:Node3D,transforms:Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mesh:=mesh_resource()
	assert(mesh!=null,"Synaxis original task chair import missing")
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=mesh
	mm.instance_count=transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i,transforms[i])
	var node:=MultiMeshInstance3D.new()
	node.name="AuthoredTaskChairs"
	node.multimesh=mm
	# Preserve the previous furniture shadow budget.
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
