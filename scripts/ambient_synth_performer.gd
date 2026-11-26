extends Node3D
## One retained stage visual, no audio, physics or progression ownership.
const Visual=preload("res://scripts/pedestrian_rig_visual.gd")
const Model=preload("res://assets/models/nightgrid/pedestrians/hiker.glb")
const Art=preload("res://scripts/instrument_art.gd")
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
	var mesh:=BoxMesh.new()
	mesh.size=dimensions
	part.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("343846")
	material.metallic=.55
	material.roughness=.55
	part.material_override=material
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
