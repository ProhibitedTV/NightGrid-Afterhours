extends Node3D
## Daytime acoustic residency; physical visual only, no economy or audio lease.
const Visual=preload("res://scripts/pedestrian_rig_visual.gd")
const Model=preload("res://assets/models/nightgrid/pedestrians/casual-walker.glb")
const Art=preload("res://scripts/instrument_art.gd")
var _rig:Node3D
var _active:=false

func _ready()->void:
	_rig=Visual.new()
	_rig.name="PerformerRig"
	_rig.rotation.y=PI
	_rig.call("set_pedestrian_model",Model)
	add_child(_rig)
	# Mesh origin is the soundboard; tilt the neck toward the fretting hand.
	Art.place(_rig,"acoustic_guitar",Vector3(-.09,1.08,.28),Vector3(0,0,-65),24.0)
	_rig.set_process(false)
	hide()

func set_active(active:bool)->void:
	if active==_active:
		return
	_active=active
	if active:
		_rig.set_process(true)
		if not _rig.call("set_music_performance","guitar"):
			_rig.set_process(false)
			_active=false
	else:
		_rig.call("clear_music_performance")
		_rig.set_process(false)
	visible=_active
