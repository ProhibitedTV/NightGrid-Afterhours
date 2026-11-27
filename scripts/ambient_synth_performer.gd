extends Node3D
## One retained stage visual, no audio, physics or progression ownership.
const Visual=preload("res://scripts/pedestrian_rig_visual.gd")
const Model=preload("res://assets/models/nightgrid/pedestrians/hiker.glb")
const Art=preload("res://scripts/instrument_art.gd")
static var _stand_meshes: Dictionary = {}
static var _stand_material: StandardMaterial3D
var _rig:Node3D
var _active:=false

func _ready()->void:
	_rig=Visual.new()
	_rig.name="PerformerRig"
	_rig.rotation.y=PI
	_rig.call("set_pedestrian_model",Model)
	add_child(_rig)
	Art.place(self,"portable_synth",Vector3(0,1.04,-.48),Vector3(-90,180,0),24.0)
	_stand(Vector3(0,.49,-.48),Vector3(.09,.98,.09))
	_stand(Vector3(0,1.0,-.48),Vector3(.72,.06,.36))
	_stand(Vector3(0,.035,-.48),Vector3(.54,.07,.32))
	_rig.set_process(false)
	hide()

func _stand(at:Vector3,dimensions:Vector3)->void:
	var part:=MeshInstance3D.new()
	if not _stand_meshes.has(dimensions):
		var mesh:=BoxMesh.new()
		mesh.size=dimensions
		_stand_meshes[dimensions]=mesh
	part.mesh=_stand_meshes[dimensions]
	if _stand_material==null:
		_stand_material=StandardMaterial3D.new()
		_stand_material.albedo_color=Color("343846")
		_stand_material.metallic=.55
		_stand_material.roughness=.55
	part.material_override=_stand_material
	part.position=at
	add_child(part)

func set_active(active:bool)->void:
	if active==_active:
		return
	_active=active
	if active:
		_rig.set_process(true)
		if not _rig.call("set_music_performance","synth"):
			_rig.set_process(false)
			_active=false
	else:
		_rig.call("clear_music_performance")
		_rig.set_process(false)
	visible=_active
