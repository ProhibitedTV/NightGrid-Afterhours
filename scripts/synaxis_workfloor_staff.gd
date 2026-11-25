extends Node3D
## Named background actors using existing seats. No additional physics or mission state.
const Staff=preload("res://scripts/synaxis_staff.gd")
const SEATS=[Vector3(-6,0,-6.45),Vector3(0,0,-6.45),Vector3(4,0,-3.80),Vector3(-2,0,.25),Vector3(2,0,.25),Vector3(6,0,2.90),Vector3(-5.3,0,5.65),Vector3(-3.35,0,6.12)]
const YAW=[0.0,0.0,PI,0.0,0.0,PI,PI/2,-PI/2]
const NAMES=[
	["Nora Finch","Omar Valdez","June Park","Hugo Bell","Mara Chen","Theo Ward","Faye Ellis","Sam Porter"],
	["Ruth Lane","Andre Moss","Kim Foster","Ben Hale","Cleo James","Noah Gray","Dana Wells","Jules Hart"],
	["Evan Cole","Lena Ross","Sofia Quinn","Max Boone","Tariq Stone","Ivy Reed","Avery Shaw","Milo West"],
	["Morgan Pierce","Jade Fox","Wes Flynn","Rosa Wood","Casey North","Robin Lake","Ellis Grant","Lee Price"]
]
const ROLES=["Engineer","Product specialist","Validation analyst","Operations analyst"]
const COATS=["7c8280","536779","665e69","728076","927e69","59616b","535f61","796d76"]
const HAIRSTYLES=["parted","cropped","bun","dark","silver","parted","bun","cropped"]
const ACTIVITIES=["TYPE","READ","TYPE","SCROLL","TYPE","SIP","CHAT","CHAT"]
const CHAT=[
	["Nora: The demo passed. They haven't defined what passing means.","Faye: We have a model for the model's risk assessment.","Sam: Does the model have to attend the all-hands?"],
	["Ruth: I designed the new dashboard. It shows the old dashboard's metrics.","Dana: We have a meeting to prepare for the meeting.","Jules: My calendar says focus time. That's where the meetings go."],
	["Evan: I reopened the bug. Someone changed the severity to cosmetic.","Avery: The acceptance criteria moved again.","Milo: We can reproduce it. Apparently that's the problem."],
	["Morgan: I need an approval to request the approval.","Ellis: We saved fourteen dollars on office supplies this quarter.","Lee: The optimization consultancy charged us forty thousand."]
]
var level:=1
var _people:Array[Node3D]=[]
var _active:=false
var _last_near:=-1
var _line:=""

func _ready() -> void:
	for i in SEATS.size():
		var actor:=Staff.new()
		actor.configure_staff({
			"id":"worker_%d_%d" % [level,i],"name":NAMES[level-1][i],"role":ROLES[level-1],
			"activity":ACTIVITIES[i],"seated":i<6,"palette":(i+level)%5,
			"outfit":"office","hair":HAIRSTYLES[(i+level)%8],"glasses":(i+level)%3==0,
			"coat":COATS[(i+level)%8],"width":.73+float(i%4)*.045,
			"height":.83+float((i+level)%5)*.025,"phase":float(i)*.71+float(level)*1.3
		})
		actor.position=SEATS[i]
		actor.rotation.y=YAW[i]
		add_child(actor)
		_people.append(actor)
	set_active(false)

func set_active(active:bool) -> void:
	_active=active
	_last_near=-1
	_line=""
	for actor in _people:
		actor.visible=active
		actor.process_mode=Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
		if not active:
			actor.call("attend",Vector3.ZERO,false)

func observe(at:Vector3) -> String:
	if not _active or not at.is_finite():
		return ""
	var local:=to_local(at)
	if absf(local.y-1.15)>.8:
		return ""
	var closest:=-1
	var best:=1.45*1.45
	for i in [0,6,7]:
		var actor:Node3D=_people[i]
		if i==0 and local.z>actor.position.z+.15:
			continue
		var distance:=actor.global_position.distance_squared_to(at-Vector3.UP*1.15)
		if distance<best:
			closest=i
			best=distance
	if closest!=_last_near:
		_last_near=closest
		_line="" if closest<0 else str(CHAT[level-1][0 if closest==0 else closest-5])
		for i in _people.size():
			_people[i].call("attend",at,i==closest)
	return _line

func stats() -> Dictionary:
	var animated:=0
	for actor in _people:
		if actor.process_mode!=Node.PROCESS_MODE_DISABLED:
			animated+=1
	return {"people":_people.size(),"animated":animated,"seated":6,"standing":2}

func interview_id(at:Vector3) -> String:
	if not _active or not at.is_finite():
		return ""
	var local:=to_local(at)
	if absf(local.y-1.15)>.8 or local.z>SEATS[0].z+.15:
		return ""
	return "worker_%d_0" % level if _people[0].global_position.distance_squared_to(at-Vector3.UP*1.15)<1.45*1.45 else ""
