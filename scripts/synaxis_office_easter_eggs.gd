extends Node3D
## Original environmental office-comedy homages. No quest markers, collectibles,
## borrowed dialogue, mission effects or additional persistent save state.
const Staff=preload("res://scripts/synaxis_staff.gd")
const STAPLER=Vector3(-4.65,.85,2.18)
const OWNER=Vector3(-4,0,2.90)
const LINES=[
	"Arthur: They issued me a shared stapler. I bought this one myself.",
	"Arthur: Procurement wants it back. It isn't on their inventory.",
	"Arthur: I have a receipt. I also have a drawer that locks."
]
var _owner:Node3D
var _stapler:Node3D
var _active:=false
var _near:=false
var _visits:=0
var _line:=""
var _materials:Dictionary={}

func _box(parent:Node3D,id:String,at:Vector3,size:Vector3,tint:Color,metal:bool=false) -> MeshInstance3D:
	var key:=tint.to_html()+str(metal)
	if not _materials.has(key):
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=tint
		mat.metallic=.65 if metal else 0.0
		mat.roughness=.32 if metal else .58
		_materials[key]=mat
	var part:=MeshInstance3D.new()
	part.name=id
	var mesh:=BoxMesh.new()
	mesh.size=size
	part.mesh=mesh
	part.material_override=_materials[key]
	part.position=at
	parent.add_child(part)
	return part

func _ready() -> void:
	_stapler=Node3D.new()
	_stapler.name="RedStapler"
	_stapler.position=STAPLER
	_stapler.rotation.y=.19
	add_child(_stapler)
	var red:=Color("b51b28")
	var dark:=Color("352e31")
	var steel:=Color("a9aeb2")
	_box(_stapler,"RubberFoot",Vector3(0,.006,0),Vector3(.047,.012,.165),dark)
	_box(_stapler,"RedBase",Vector3(0,.017,0),Vector3(.052,.014,.17),red)
	_box(_stapler,"Anvil",Vector3(0,.027,.049),Vector3(.031,.008,.034),steel,true)
	_box(_stapler,"StapleChannel",Vector3(0,.042,-.014),Vector3(.035,.022,.131),steel,true)
	var handle:=_box(_stapler,"RedHandle",Vector3(0,.068,-.012),Vector3(.053,.029,.151),red)
	handle.rotation.x=-.075
	_box(_stapler,"Hinge",Vector3(0,.036,-.07),Vector3(.052,.045,.032),dark)
	_box(_stapler,"PersonalNameTape",Vector3(0,.083,-.017),Vector3(.034,.004,.047),Color("e3d8b7"))
	_owner=Staff.new()
	_owner.configure_staff({"id":"arthur","name":"Arthur Bell","role":"Procurement records clerk","activity":"READ","seated":true,"palette":4,"outfit":"office","hair":"silver","glasses":true,"coat":"817260","height":.89,"width":.74,"phase":2.7})
	_owner.position=OWNER
	_owner.rotation.y=PI
	add_child(_owner)
	set_active(false)

func set_active(active:bool) -> void:
	_active=active
	_owner.process_mode=Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
	if not active:
		_near=false
		_line=""
		_owner.call("attend",Vector3.ZERO,false)

func observe(at:Vector3) -> String:
	if not _active or not at.is_finite():
		return ""
	var local:=to_local(at)
	var nearby:=absf(local.y-1.15)<.8 and local.z>2.6 and local.z<4.8 and absf(local.x-OWNER.x)<1.3
	if nearby and not _near:
		_line=LINES[mini(_visits,LINES.size()-1)]
		_visits+=1
	elif not nearby:
		_line=""
	_near=nearby
	_owner.call("attend",at,nearby)
	return _line

func get_egg_state() -> Dictionary:
	return {"visits":_visits,"near":_near,"active":_active,"prop_parts":_stapler.get_child_count()}
