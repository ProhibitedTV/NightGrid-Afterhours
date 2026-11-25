extends "res://scripts/mara_hero.gd"
## Provisional executive costume and speakerphone performance on existing rig.
var _phone: Node3D
var _on_call := false

func _build_uniform() -> void:
	_box(_torso,"SilkBlouse",Vector3(0,.43,.185),Vector3(.22,.20,.05),"FABRIC",Color("dcd6c8"),"uniform")
	for side in [-1.0,1.0]:
		_segment(_torso,"BlazerLapel",Vector3(side*.16,.46,.19),Vector3(side*.05,.18,.235),.035,.028,"FABRIC",Color("28212f"),"uniform")
	_box(_torso,"ExecutiveBadge",Vector3(-.18,.32,.245),Vector3(.13,.044,.018),"BRASS",Color("c4ae84"),"uniform")
	_phone = Node3D.new()
	_phone.name = "ExecutivePhone"
	_right_arm.add_child(_phone)
	_phone.position = Vector3(.018,-.67,.255)
	_box(_phone,"PhoneBody",Vector3.ZERO,Vector3(.075,.142,.012),"LEATHER",Color("171d27"))
	_box(_phone,"PhoneScreen",Vector3(0,0,.007),Vector3(.065,.128,.003),"GLOW",Color("69aab1"))
	_phone.hide()

func _mat(category: String,tint: Color) -> StandardMaterial3D:
	if tint == COAT:
		tint = Color("392d40")
	elif tint == COAT_EDGE:
		tint = Color("514158")
	elif tint == EYE_IRIS:
		tint = Color("48332e")
	return super._mat(category,tint)

func set_phone_call(active: bool) -> void:
	_on_call = active
	if is_instance_valid(_phone):
		_phone.visible = active
	_focused = true
	_speaking = 12.0 if active else 2.0

func _process(delta: float) -> void:
	super._process(delta)
	if _on_call and is_instance_valid(_right_arm):
		_right_arm.rotation.x = -1.28
		_right_arm.rotation.z = -.16
