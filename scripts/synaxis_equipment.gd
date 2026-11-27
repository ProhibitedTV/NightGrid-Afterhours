extends RefCounted
## Shared imported physical equipment for the playable Synaxis rooms.
const Photo = preload("res://scripts/synaxis_breakroom.gd")
const COPIER = preload("res://assets/models/nightgrid/synaxis_equipment/copier.glb")
const COPIER_FAR = preload("res://assets/models/nightgrid/synaxis_equipment/copier_far.glb")
const RACK = preload("res://assets/models/nightgrid/synaxis_equipment/server_rack.glb")
const KIOSK = preload("res://assets/models/nightgrid/synaxis_equipment/visitor_kiosk.glb")
static var _meshes: Dictionary = {}

static func mesh_for(source: PackedScene) -> Mesh:
	var key := source.resource_path
	if _meshes.has(key):
		return _meshes[key]
	var scene := source.instantiate()
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	if scene is MeshInstance3D:
		meshes.append(scene)
	assert(meshes.size() == 1)
	var mesh := (meshes[0].mesh as ArrayMesh).duplicate() as ArrayMesh
	scene.free()
	for index in mesh.get_surface_count():
		var material := mesh.surface_get_material(index)
		if material == null:
			continue
		var matched := Photo.material_for(material.resource_name)
		if matched != null:
			mesh.surface_set_material(index, matched)
	_meshes[key] = mesh
	return mesh

static func place(parent: Node3D, source: PackedScene, label: String, at: Vector3) -> MeshInstance3D:
	var prop := MeshInstance3D.new()
	prop.name = label
	prop.mesh = mesh_for(source)
	prop.position = at
	parent.add_child(prop)
	return prop

static func batch(parent: Node3D, source: PackedScene, label: String, poses: Array[Transform3D]) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh_for(source)
	instances.instance_count = poses.size()
	for i in poses.size():
		instances.set_instance_transform(i, poses[i])
	var view := MultiMeshInstance3D.new()
	view.name = label
	view.multimesh = instances
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
