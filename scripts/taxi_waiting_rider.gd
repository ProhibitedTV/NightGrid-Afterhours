extends Node3D
## One reusable visual rider at the authored sidewalk waiting position.
## No crowd lease or collision. Seated pose is provisional; actual boarding
## and alighting transitions remain caption-only.
const Visual=preload("res://scripts/pedestrian_rig_visual.gd")
const MODELS=[
	preload("res://assets/models/nightgrid/pedestrians/casual-walker.glb"),
	preload("res://assets/models/nightgrid/pedestrians/hiker.glb"),
	preload("res://assets/models/nightgrid/pedestrians/road-worker.glb")
]
var _visual:Node3D
var _label:Label3D
var _style:=-1
var _departing:=false
var _departure_elapsed:=0.0
var _departure_goal:=Vector3.ZERO
var _seat_parent:Node
var _seated:=false
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
	leave_seat()
	var selected:=posmod(style,MODELS.size())
	if selected!=_style:
		if is_instance_valid(_visual):
			_visual.hide()
			remove_child(_visual)
			_visual.queue_free()
		_visual=Visual.new()
		_visual.call("set_pedestrian_model",MODELS[selected])
		add_child(_visual)
		_visual.call("set_activity","STOREFRONT")
		_style=selected
	_departing=false
	_visual.call("set_locomotion",0.0)
	_visual.call("set_activity","STOREFRONT")
	global_position=point
	rotation.y=PI
	_label.text=rider+" / WAITING FOR TAXI"
	_visual.process_mode=Node.PROCESS_MODE_INHERIT
	show()

## Presentation-only sidewalk departure after the temporary captioned
## alighting transition. The world supplies a collision-checked path.
func begin_departure(style:int,rider:String,point:Vector3,goal:Vector3)->void:
	show_rider(style,rider,point)
	if not visible or not goal.is_finite() or point.distance_to(goal)>5.0:
		hide_rider()
		return
	_departing=true
	_departure_elapsed=0.0
	_departure_goal=goal
	_label.text=rider+" / ARRIVED"
	_visual.call("set_activity","WALK")

func advance_departure(delta:float)->bool:
	if not _departing or not is_finite(delta) or delta<=0.0 or delta>.1:
		return false
	_departure_elapsed+=delta
	var offset:=_departure_goal-global_position
	if offset.length()>.05:
		var direction:=offset.normalized()
		rotation.y=atan2(direction.x,direction.z)
		_visual.call("set_locomotion",1.2)
		global_position=global_position.move_toward(_departure_goal,1.2*delta)
	else:
		_visual.call("set_locomotion",0.0)
		_visual.call("set_activity","STOREFRONT")
	if _departure_elapsed>=8.0:
		hide_rider()
		return false
	return true

func is_departing()->bool:
	return _departing

func seat_rider(style:int,rider:String,car:Node3D)->bool:
	if not is_instance_valid(car):
		return false
	show_rider(style,rider,car.global_position)
	var pose:Dictionary=_visual.call("pose_taxi_seated")
	if pose.is_empty():
		hide_rider()
		return false
	_seat_parent=get_parent()
	reparent(car,false)
	rotation=Vector3(0,PI,0)
	var factor:float=pose["scale"]
	scale=Vector3.ONE*factor
	var hip:Vector3=pose["hip"]
	# Real Kestrel front passenger cushion is centered at x=.49,z=-.43.
	position=Vector3(.49,.405,-.43)-Basis(Vector3.UP,PI)*hip*factor
	_label.hide()
	_seated=true
	return true

func is_seated()->bool:
	return _seated

func leave_seat()->void:
	if not _seated:
		return
	_seated=false
	if is_instance_valid(_seat_parent):
		reparent(_seat_parent,false)
	# Discard the complete scaled/rotated seat-local basis. The next
	# waiting/departure call sets its own world position and heading.
	transform=Transform3D.IDENTITY
	_visual.call("resume_taxi_standing")
	_label.show()
	_seat_parent=null

func hide_rider()->void:
	leave_seat()
	_departing=false
	hide()
	if is_instance_valid(_visual):
		_visual.process_mode=Node.PROCESS_MODE_DISABLED
