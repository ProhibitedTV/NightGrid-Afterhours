extends Node3D
## Fictional demonstration hardware only. Articulated display props, not combat AI.
const Staff=preload("res://scripts/synaxis_staff.gd")
const GeneratedAudio=preload("res://scripts/synaxis_generated_audio.gd")
const BAY=Vector3(4.9,0,7.65)
const LINES=[
	"Imani: It is a workforce augmentation platform. That's what the slide says.",
	"Imani: The demonstration had a 100 percent human retention rate. We counted the observers.",
	"Imani: They asked me to remove the word autonomous from the risk assessment. Not the robot."
]
var _materials:Dictionary={}
var _units:Array[Node3D]=[]
var _heads:Array[Node3D]=[]
var _arms:Array[Node3D]=[]
var _status:Array[MeshInstance3D]=[]
var _engineer:Node3D
var _active:=false
var _near:=false
var _visits:=0
var _line:=""
var _clock:=0.0
var _barriers:=0
var _servo_audio:AudioStreamPlayer3D

func _mat(key:String) -> StandardMaterial3D:
	if not _materials.has(key):
		var m:=StandardMaterial3D.new()
		match key:
			"shell": m.albedo_color=Color("c9cecb")
			"dark": m.albedo_color=Color("242c34")
			"steel": m.albedo_color=Color("697981")
			"amber": m.albedo_color=Color("d8a64d")
			"red": m.albedo_color=Color("e04f48")
			"cyan": m.albedo_color=Color("69c7cf")
			"glass":
				m.albedo_color=Color(.48,.70,.75,.19)
				m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			_: m.albedo_color=Color("4d575d")
		m.roughness=.56
		if key=="steel":
			m.metallic=.72
			m.roughness=.34
		if key in ["red","cyan","amber"]:
			m.emission_enabled=true
			m.emission=m.albedo_color
			m.emission_energy_multiplier=.8
		_materials[key]=m
	return _materials[key]

func _box(parent:Node3D,id:String,at:Vector3,size:Vector3,key:String) -> MeshInstance3D:
	var mesh:=BoxMesh.new()
	mesh.size=size
	var part:=MeshInstance3D.new()
	part.name=id
	part.mesh=mesh
	part.position=at
	part.material_override=_mat(key)
	part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

func _joint(parent:Node3D,id:String,at:Vector3) -> Node3D:
	var pivot:=Node3D.new()
	pivot.name=id
	pivot.position=at
	parent.add_child(pivot)
	return pivot

func _barrier(at:Vector3,size:Vector3) -> void:
	_box(self,"ContainmentGlass",at,size,"glass")
	var body:=StaticBody3D.new()
	body.position=at
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collider.shape=shape
	body.add_child(collider)
	add_child(body)
	_barriers+=1

func _sign(id:String,value:String,at:Vector3,pixel:float,yaw:float=PI) -> void:
	var label:=Label3D.new()
	label.name=id
	label.text=value
	label.position=at
	label.font_size=48
	label.pixel_size=pixel
	label.outline_size=3
	label.rotation.y=yaw
	add_child(label)

func _ready() -> void:
	_box(self,"LabDeck",BAY+Vector3(0,.025,0),Vector3(5.6,.05,4.0),"dark")
	# Closed transparent demonstration bay, no access to the prototypes.
	for x in [-2.8,2.8]:
		_barrier(BAY+Vector3(x,1.23,0),Vector3(.09,2.45,4.0))
		for z in [-2.0,2.0]:
			_box(self,"SafetyPost",BAY+Vector3(x,1.25,z),Vector3(.13,2.5,.13),"steel")
	for z in [-2.0,2.0]:
		_barrier(BAY+Vector3(0,1.23,z),Vector3(5.6,2.45,.09))
		_box(self,"Header",BAY+Vector3(0,2.45,z),Vector3(5.6,.12,.13),"steel")
	for i in range(14):
		_box(self,"WarningStripe",BAY+Vector3(-2.6+i*.40,.105,-2.04),Vector3(.21,.10,.12),"amber")
	_build_unit("CARETAKER_03",BAY+Vector3(-1.25,.05,.12),false)
	_build_unit("HARMONY_08",BAY+Vector3(1.25,.05,.12),true)
	_box(self,"Dock",BAY+Vector3(0,.18,1.55),Vector3(4.6,.36,.65),"steel")
	_box(self,"TelemetryDisplay",BAY+Vector3(0,1.55,1.89),Vector3(3.9,1.18,.08),"dark")
	_sign("Telemetry","HUMAN COMPLEMENTARITY TEST\nPROJECTED HUMAN STAFF: 0\nPUBLIC RELATIONS STATUS: GREEN",BAY+Vector3(0,1.55,1.82),.0036)
	_sign("SafetyNotice","PROTOTYPE DEMONSTRATION / DO NOT ENTER",BAY+Vector3(0,2.66,-2.07),.0038)
	_sign("MissionStatement","A SAFER TOMORROW.\nHUMANITY IS OUR TOP PRIORITY*",BAY+Vector3(0,2.03,-2.07),.0034)
	_sign("Disclaimer","*SUBJECT TO QUARTERLY REVIEW",BAY+Vector3(0,1.67,-2.08),.0023)
	_engineer=Staff.new()
	_engineer.configure_staff({"id":"imani","name":"Imani Reed","role":"Robotics validation engineer","activity":"SCROLL","seated":false,"palette":1,"outfit":"technician","hair":"bun","glasses":true,"coat":"576b74","height":.91,"width":.78,"phase":1.4})
	_engineer.position=Vector3(3.8,0,4.45)
	_engineer.rotation.y=PI
	add_child(_engineer)
	_servo_audio=GeneratedAudio.emitter(self,"robotics_servos",BAY+Vector3.UP,-19.0,9.0,true)
	set_active(false)

func _build_unit(id:String,at:Vector3,heavy:bool) -> void:
	var root:=_joint(self,id,at)
	_units.append(root)
	var width:=.68 if heavy else .48
	var torso:=_joint(root,"Torso",Vector3(0,1.22,0))
	_box(torso,"ArmoredChest",Vector3.ZERO,Vector3(width,.54,.31),"shell")
	_box(torso,"ChestInset",Vector3(0,.05,-.165),Vector3(width*.72,.19,.035),"dark")
	_status.append(_box(torso,"StatusStrip",Vector3(0,.05,-.19),Vector3(width*.56,.035,.015),"red" if heavy else "cyan"))
	_box(root,"Pelvis",Vector3(0,.87,0),Vector3(.38,.23,.28),"dark")
	for side in [-1.0,1.0]:
		var x:float=side*.18
		_box(root,"UpperLeg",Vector3(x,.66,0),Vector3(.18,.32,.24),"shell")
		_box(root,"KneeHousing",Vector3(x,.46,0),Vector3(.20,.13,.23),"steel")
		_box(root,"LowerLeg",Vector3(x,.28,0),Vector3(.16,.34,.21),"shell")
		_box(root,"Foot",Vector3(x,.07,-.05),Vector3(.22,.14,.36),"dark")
		var shoulder:=_joint(torso,"Shoulder",Vector3(side*(width*.5+.10),.16,0))
		_arms.append(shoulder)
		_box(shoulder,"ShoulderGuard",Vector3.ZERO,Vector3(.22,.21,.26),"steel")
		_box(shoulder,"UpperArm",Vector3(0,-.20,0),Vector3(.16,.32,.20),"shell")
		_box(shoulder,"Elbow",Vector3(0,-.38,0),Vector3(.14,.13,.17),"dark")
		_box(shoulder,"Forearm",Vector3(0,-.55,0),Vector3(.18,.25,.20),"shell")
		_box(shoulder,"Hand",Vector3(0,-.73,0),Vector3(.13,.14,.13),"steel")
	var head:=_joint(torso,"HeadGimbal",Vector3(0,.40,0))
	_heads.append(head)
	_box(head,"SensorHousing",Vector3.ZERO,Vector3(.32,.27,.29),"shell")
	_box(head,"Visor",Vector3(0,.025,-.15),Vector3(.27,.11,.025),"dark")
	_box(head,"OpticalStrip",Vector3(0,.025,-.17),Vector3(.20,.035,.014),"red" if heavy else "cyan")

func set_active(active:bool) -> void:
	GeneratedAudio.activate(_servo_audio,active)
	_active=active
	set_process(active)
	_engineer.process_mode=Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
	if not active:
		_near=false
		_line=""
		_engineer.call("attend",Vector3.ZERO,false)

func observe(at:Vector3) -> String:
	if not _active or not at.is_finite():
		return ""
	var local:=to_local(at)
	var nearby:=absf(local.y-1.15)<.8 and local.z>3.5 and local.z<5.5 and local.x>2.5 and local.x<6.0
	if nearby and not _near:
		_line=LINES[mini(_visits,LINES.size()-1)]
		_visits+=1
	elif not nearby:
		_line=""
	_near=nearby
	_engineer.call("attend",at,nearby)
	return _line

func _process(delta:float) -> void:
	_clock=fposmod(_clock+maxf(0.0,delta),600.0)
	for i in _heads.size():
		_heads[i].rotation.y=sin(_clock*.8+i*1.4)*.32
	for i in _arms.size():
		_arms[i].rotation.x=sin(_clock*.9+i*.75)*.12
	# Slow status pulses, only on the occupied floor.
	for i in _status.size():
		_status[i].visible=sin(_clock*1.5+i)>-.7

func lab_stats() -> Dictionary:
	return {"prototypes":_units.size(),"barriers":_barriers,"engineers":1,"active":_active,"clock":_clock}
