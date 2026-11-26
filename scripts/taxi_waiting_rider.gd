extends Node3D
## One reusable visual rider at the authored sidewalk waiting position.
## No crowd lease, collision or fake seated animation. Boarding uses a
## temporary caption-only transition until the passenger rig is authored.
const Visual=preload("res://scripts/pedestrian_rig_visual.gd")
const MODELS=[
	preload("res://assets/models/nightgrid/pedestrians/casual-walker.glb"),
	preload("res://assets/models/nightgrid/pedestrians/hiker.glb"),
	preload("res://assets/models/nightgrid/pedestrians/road-worker.glb")
]
var _visual:Node3D
var _label:Label3D
var _style:=-1
func _ready()->void:
	_label=Label3D.new()
	_label.position.y=2.05
	_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size=28
	_label.pixel_size=.006
	_label.modulate=Color("b2fff0")
	_label.outline_size=6
	add_child(_label)
	hide()

func show_rider(style:int,rider:String,point:Vector3)->void:
	if not point.is_finite():
		hide_rider()
		return
	var selected:=posmod(style,MODELS.size())
	if selected!=_style:
		if is_instance_valid(_visual):
			_visual.hide()
			_visual.queue_free()
		_visual=Visual.new()
		_visual.call("set_pedestrian_model",MODELS[selected])
		add_child(_visual)
		_visual.call("set_activity","STOREFRONT")
		_style=selected
	global_position=point
	rotation.y=PI
	_label.text=rider+" / WAITING FOR TAXI"
	_visual.process_mode=Node.PROCESS_MODE_INHERIT
	show()

func hide_rider()->void:
	hide()
	if is_instance_valid(_visual):
		_visual.process_mode=Node.PROCESS_MODE_DISABLED
