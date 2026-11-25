extends "res://scripts/synaxis_staff.gd"
## One original office-rage performance per visit. No combat or mission effects.
const GeneratedAudio=preload("res://scripts/synaxis_generated_audio.gd")
const DURATION=5.4
const DESK=Vector3(4,0,2.05)
const SEAT=DESK+Vector3(0,0,.85)
var _elapsed:float=-1.0
var _played:=false
var _enabled:=false
var _keyboard:Node3D
var _monitor:Node3D
var _screen:MeshInstance3D
var _seated_parts:Array[Node3D]=[]
var _standing_parts:Array[Node3D]=[]
var _hip:Node3D
var _impact:=false
var _impact_audio:AudioStreamPlayer3D
var _desk_keyboard:Node3D
var _arm:Node3D
var _left_arm:Node3D
var _desk_props:Node3D
var _original_sleeves:Array[Node3D]=[]

func _ready() -> void:
	super._ready()
	var jacket:Node3D=_torso.get_node("JacketSilhouette")
	jacket.scale=Vector3(.86,.85,.60)
	_ellipsoid(_torso,"ShirtAbdomen",Vector3(0,-.21,.035),Vector3(.75,.48,.56),_coat_color,"FABRIC")
	for child in get_children():
		if child is MeshInstance3D:
			if str(child.name)=="Hips":
				_hip=child
			else:
				_seated_parts.append(child)
	for child in _torso.get_children():
		if child is MeshInstance3D and (str(child.name).begins_with("TailoredSleeve") or str(child.name)=="Hand"):
			_original_sleeves.append(child)
	for side in [-1.0,1.0]:
		var x:float=side*.18
		_standing_parts.append(_ellipsoid(self,"StandingTrouser",Vector3(x,.47,0),Vector3(.27,.84,.30),_coat_color.darkened(.3),"FABRIC"))
		_standing_parts.append(_ellipsoid(self,"StandingShoe",Vector3(x,.10,.12),Vector3(.26,.18,.38),Color("292e34"),"FABRIC"))
	for part in _standing_parts:
		part.hide()
	_arm=_pivot(_torso,"RageRightShoulder",Vector3(.43,.15,0))
	_left_arm=_pivot(_torso,"RageLeftShoulder",Vector3(-.43,.15,0))
	for shoulder in [_arm,_left_arm]:
		_ellipsoid(shoulder,"UpperSleeve",Vector3(0,-.16,0),Vector3(.25,.36,.27),_coat_color,"FABRIC")
		_ellipsoid(shoulder,"Forearm",Vector3(0,-.31,.18),Vector3(.19,.19,.40),_coat_color,"FABRIC")
		_ellipsoid(shoulder,"Grip",Vector3(0,-.31,.40),Vector3(.14,.14,.17),_skin_color,"SKIN")
		shoulder.hide()
	_keyboard=_pivot(_arm,"HeldKeyboard",Vector3(-.26,-.31,.43))
	_box(_keyboard,"KeyboardCase",Vector3.ZERO,Vector3(.52,.055,.19),Color("292e34"),"FABRIC")
	for row in range(3):
		for col in range(10):
			_box(_keyboard,"Key",Vector3(-.23+col*.05,.032,-.055+row*.05),Vector3(.037,.012,.037),Color("7e8488"),"FABRIC")
	_keyboard.hide()
	_desk_props=Node3D.new()
	_desk_props.name="IncidentDeskProps"
	add_child(_desk_props)
	_desk_props.top_level=true
	_desk_props.global_position=get_parent().to_global(DESK)
	_impact_audio=GeneratedAudio.emitter(_desk_props,"keyboard_monitor_hit",Vector3(0,1.1,0),-10.0,10.0)
	_monitor=_pivot(_desk_props,"ImpactMonitor",Vector3(-.22,1.12,-.19))
	_box(_monitor,"MonitorCase",Vector3.ZERO,Vector3(.56,.34,.05),Color("252e36"),"FABRIC")
	_screen=_box(_monitor,"MonitorScreen",Vector3(0,0,.03),Vector3(.525,.305,.008),Color("6ea7b3"),"SCREEN")
	_box(_monitor,"MonitorStand",Vector3(0,-.205,0),Vector3(.055,.10,.055),Color("535a5e"),"METAL")
	_box(_monitor,"MonitorFoot",Vector3(0,-.26,0),Vector3(.23,.028,.16),Color("252e36"),"FABRIC")
	_desk_keyboard=_pivot(_desk_props,"DeskKeyboard",Vector3(-.22,.861,.19))
	_box(_desk_keyboard,"Keyboard",Vector3.ZERO,Vector3(.45,.025,.15),Color("252e36"),"FABRIC")
	_box(_desk_keyboard,"Keys",Vector3(0,.016,0),Vector3(.41,.008,.12),Color("777c80"),"METAL")

func enable_performance(active:bool) -> void:
	_enabled=active
	# Furniture remains visible; only the actor is paused off-floor.
	process_mode=Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
	if not active:
		_elapsed=-1.0
		_reset_pose()

func observe(at:Vector3) -> void:
	if not _enabled or _played or not at.is_finite():
		return
	var local:Vector3=get_parent().to_local(at)
	if local.z<2.6 or local.z>5.5 or absf(local.x-DESK.x)>2.1 or absf(local.y-1.15)>.8:
		return
	_played=true
	_elapsed=0.0

func get_gag_state() -> Dictionary:
	return {"played":_played,"performing":_elapsed>=0.0,"standing":not seated,"keyboard":_keyboard.visible,"impact":_impact,"monitor_tilt":_monitor.rotation.x}

func _reset_pose() -> void:
	seated=true
	position=SEAT
	_torso.rotation.x=0.0
	_torso.position.y=1.18
	_right_hand.show()
	for part in _seated_parts:
		part.show()
	for part in _standing_parts:
		part.hide()
	for sleeve in _original_sleeves:
		sleeve.show()
	if _hip!=null:
		_hip.position.y=.83
	for arm in [_arm,_left_arm]:
		arm.hide()
		arm.rotation=Vector3.ZERO
	_keyboard.hide()
	_desk_keyboard.show()

func _process(delta:float) -> void:
	super._process(delta)
	if _elapsed<0.0:
		return
	_elapsed+=maxf(0.0,delta)
	if _elapsed>=DURATION:
		_elapsed=-1.0
		_reset_pose()
		return
	var rise:=smoothstep(.65,1.55,_elapsed)
	var sit:=smoothstep(4.15,5.25,_elapsed)
	var upright:float=rise*(1.0-sit)
	seated=upright<.5
	position=SEAT+Vector3(0,0,.12*upright)
	_torso.position.y=1.18+.25*upright
	if _hip!=null:
		_hip.position.y=.83+.16*upright
	for part in _seated_parts:
		part.visible=seated
	for part in _standing_parts:
		part.visible=not seated
	var grip:=_elapsed>=1.4 and _elapsed<4.15
	_keyboard.visible=grip
	_desk_keyboard.visible=not grip
	_right_hand.visible=not grip
	_arm.visible=grip
	_left_arm.visible=grip
	for sleeve in _original_sleeves:
		sleeve.visible=not grip
	var windup:=smoothstep(1.4,2.25,_elapsed)
	var strike:=smoothstep(2.25,2.65,_elapsed)
	var release:=smoothstep(3.15,4.1,_elapsed)
	var lift:float=windup*(1.0-strike)
	_arm.rotation.x=(-1.9*lift-.75*strike)*(1.0-release)
	_left_arm.rotation.x=_arm.rotation.x
	_arm.rotation.z=-.20
	_left_arm.rotation.z=.20
	_torso.rotation.x=.20*strike*(1.0-release)
	_head.rotation.x=-.10+.17*strike
	if _elapsed>=2.65 and not _impact:
		_impact=true
		if is_instance_valid(_impact_audio):
			_impact_audio.play()
		_monitor.rotation.x=-.32
		_monitor.rotation.z=.18
		_monitor.position.z-=.08
		_screen.material_override=_mat("FABRIC",Color("17232a"))
