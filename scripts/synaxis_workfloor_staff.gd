extends Node3D
## Named background actors using existing seats. No additional physics or mission state.
const Staff=preload("res://scripts/synaxis_staff.gd")
const Meeting=preload("res://scripts/synaxis_department_meeting.gd")
var _meeting:=Meeting.new()
var _rounds:=0
var _offboarding:=false
const LATE_CHAT=[
	["Nora: They just restricted access to the prototype folder.","Faye: We received a reminder about discussing internal matters.","Sam: I think everyone is keeping their heads down today."],
	["Ruth: The review meeting disappeared from my calendar.","Dana: Legal has asked us to preserve all project notes.","Jules: I was told not to speculate. So here we are."],
	["Evan: They froze the release sign-off.","Avery: Our manager says it is a routine administrative change.","Milo: We should keep the test records exactly as they are."],
	["Morgan: They have stopped approving new access requests.","Ellis: HR sent an updated confidentiality reminder.","Lee: I hope whoever is affected is okay."]
]
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
# One short circulation route per department. Clear of desk rows, table
# collision and the lift landing (x=0,z=5). Faye/other coworker stays put.
const WALKER=7
const ROUTE=[Vector3(-3.35,0,6.12),Vector3(-2.0,0,6.12),Vector3(-2.0,0,4.05),Vector3(-5.3,0,4.05),Vector3(-7.10,0,4.05),Vector3(-7.10,0,6.8),Vector3(-7.24,0,4.05),Vector3(-7.24,0,-.4),Vector3(-6.65,0,-.4),Vector3(-6.65,0,-2.45),Vector3(-6.65,0,-.4),Vector3(-7.24,0,-.4),Vector3(-7.24,0,4.05),Vector3(-2.0,0,4.05),Vector3(-2.0,0,6.12),Vector3(-3.35,0,6.12)]
const EXCHANGES=[
	["Sam: Did you update the risk matrix?","Faye: Yes. The risk matrix now requires a risk matrix."],
	["Jules: Did the client approve the new design?","Dana: They approved the presentation about the design."],
	["Milo: Are we still testing the old build?","Avery: The new build is waiting for approval to be tested."],
	["Lee: Did we get the purchase order?","Ellis: We got approval to ask about the purchase order."]
]
var _task:="idle"
var _board_visits:=0
var _chat_visits:=0
var _chat_elapsed:=0.0
var _task_yaw:=0.0
var _services:Node3D
var _service_site:=""
var _service_started:=false
var _held:=""
var _print_visits:=0
var _coffee_visits:=0
const OWNER="department_walker"
var _route_index:=1
var _wait:=0.0
var _walking:=false
var _visitor:=Vector3.INF
var _walk_distance:=0.0

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
	_people[WALKER].call("enable_walk_rig")
	_people[WALKER].call("enable_routine_props")
	_services=get_parent().get_node_or_null("OfficeServices")
	set_active(false)

func set_story_stage(stage:int) -> void:
	var late:=stage>=4
	if late==_offboarding:
		return
	_offboarding=late
	_last_near=-1
	_line=""
	# Never reveal the private briefing or a specific employee accusation.
	# Cancel an obsolete stand-up and let the current route finish normally.
	if _meeting.active:
		_meeting.reset()
		for i in [6,WALKER]:
			_people[i].call("set_scene_beat",-1)
			_people[i].call("set_routine_pose","")
		_task="idle"
		_wait=6.0

func set_active(active:bool) -> void:
	_active=active
	set_process(active)
	_visitor=Vector3.INF
	_walking=false
	if not _people.is_empty():
		_people[WALKER].call("set_walk_speed",0.0)
	if active:
		_wait=maxf(_wait,3.0+float(level)*1.1)
	else:
		_meeting.reset()
		_people[6].call("set_routine_pose","")
		_people[6].rotation.y=YAW[6]
		_service_site=""
		_service_started=false
		_held=""
		_task="idle"
		_people[WALKER].position=SEATS[WALKER]
		_people[WALKER].rotation.y=YAW[WALKER]
		_people[WALKER].call("set_routine_pose","")
		_route_index=1
		_wait=0.0
	_last_near=-1
	_line=""
	for actor in _people:
		actor.visible=active
		actor.process_mode=Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
		if not active:
			actor.call("attend",Vector3.ZERO,false)
			actor.call("set_scene_beat",-1)

func _process(delta:float) -> void:
	if not _active:
		return
	var actor:Node3D=_people[WALKER]
	var step:=clampf(delta,0.0,.10)
	# Stop for nearby visitors and do not walk through their space.
	var visitor_near:=_visitor.is_finite() and actor.position.distance_to(_visitor)<1.45
	if visitor_near:
		_walking=false
		actor.call("set_walk_speed",0.0)
		_wait=maxf(_wait,1.0)
		if _meeting.active:
			for i in [6,WALKER]:
				_people[i].call("set_scene_beat",-1)
				_people[i].call("set_routine_pose","")
		return
	if _meeting.active:
		_tick_meeting(step)
		return
	if not _service_site.is_empty():
		_tick_service(actor,step)
		return
	if _wait>0.0:
		_wait=maxf(0.0,_wait-step)
		_walking=false
		actor.call("set_walk_speed",0.0)
		if _task in ["board","chat","sip"]:
			actor.rotation.y=lerp_angle(actor.rotation.y,_task_yaw,clampf(step*6.0,0.0,1.0))
		if _task=="chat":
			_chat_elapsed+=step
			_people[6].call("set_routine_pose","chat")
			_people[6].call("attend",actor.global_position,true)
		if _wait<=0.0:
			_task="carry"
			actor.call("set_routine_pose",_held if not _held.is_empty() else "carry")
			_people[6].call("set_routine_pose","")
			_people[6].call("attend",Vector3.ZERO,false)
		return
	var target:Vector3=ROUTE[_route_index]
	var offset:=target-actor.position
	var distance:=offset.length()
	if distance<.04:
		actor.position=target
		_route_index+=1
		if _route_index>=ROUTE.size():
			_route_index=1
			_rounds+=1
			_wait=7.0+float(level)
			_task="idle"
			_held=""
			actor.call("set_routine_pose","")
			actor.rotation.y=YAW[WALKER]
			_meeting.begin(_offboarding)
			_task="meeting"
		elif _route_index==4:
			_wait=5.0
			_task="chat"
			_task_yaw=0.0
			_chat_elapsed=0.0
			_chat_visits+=1
			actor.call("set_routine_pose","chat")
		elif _route_index==6:
			_wait=4.0
			_task="board"
			_task_yaw=-PI/2
			_board_visits+=1
			actor.call("set_routine_pose","board")
		elif _route_index in [9,10]:
			_service_site="printer" if _route_index==9 else "coffee"
			_service_started=false
			_task=_service_site
			actor.call("set_routine_pose","appliance")
		_walking=false
		actor.call("set_walk_speed",0.0)
		return
	var heading:=atan2(offset.x,offset.z)
	actor.rotation.y=lerp_angle(actor.rotation.y,heading,clampf(step*7.0,0.0,1.0))
	# Turn first at corners instead of sliding sideways.
	if absf(angle_difference(actor.rotation.y,heading))>.28:
		_walking=false
		actor.call("set_walk_speed",0.0)
		return
	var advance:=minf(distance,step*.85)
	var next:=actor.position+offset.normalized()*advance
	if _visitor.is_finite() and next.distance_to(_visitor)<1.25:
		_walking=false
		actor.call("set_walk_speed",0.0)
		return
	actor.position=next
	_task="carry"
	actor.call("set_routine_pose",_held if not _held.is_empty() else "carry")
	_walk_distance+=advance
	_walking=true
	actor.call("set_walk_speed",.85)

func _tick_meeting(step:float) -> void:
	var a:Node3D=_people[6]
	var b:Node3D=_people[WALKER]
	var offset:=b.position-a.position
	a.rotation.y=lerp_angle(a.rotation.y,atan2(offset.x,offset.z),clampf(step*6.0,0.0,1.0))
	b.rotation.y=lerp_angle(b.rotation.y,atan2(-offset.x,-offset.z),clampf(step*6.0,0.0,1.0))
	b.call("set_walk_speed",0.0)
	_walking=false
	var speaker:=_meeting.speaker()
	for i in [6,WALKER]:
		_people[i].call("set_routine_pose","chat" if i==speaker else "")
		_people[i].call("set_scene_beat",0 if i==speaker else -1)
	_meeting.tick(step)
	if not _meeting.active:
		for i in [6,WALKER]:
			_people[i].call("set_scene_beat",-1)
			_people[i].call("set_routine_pose","")
		_task="idle"
		_wait=10.0+float(level)*2.0

func _tick_service(actor:Node3D,step:float) -> void:
	actor.call("set_walk_speed",0.0)
	_walking=false
	actor.rotation.y=lerp_angle(actor.rotation.y,-PI/2,clampf(step*7.0,0.0,1.0))
	if absf(angle_difference(actor.rotation.y,-PI/2))>.2:
		return
	if not is_instance_valid(_services):
		_service_site=""
		return
	if not _service_started:
		# Player takes precedence if equipment already busy. Skip this stop.
		if not _services.call("request",_service_site,OWNER):
			_service_site=""
			return
		_service_started=true
		return
	var state:Dictionary=_services.call("stats")
	if state["owner"]!=OWNER:
		_service_site=""
		_service_started=false
		return
	if not _services.call("collect",OWNER,_service_site):
		return
	if _service_site=="printer":
		_print_visits+=1
		_held="page"
		actor.call("set_routine_pose","page")
	else:
		_coffee_visits+=1
		_held="cup"
		_task="sip"
		_task_yaw=-PI/2
		_wait=2.5
		actor.call("set_routine_pose","sip")
	_service_site=""
	_service_started=false

func observe(at:Vector3) -> String:
	if not _active or not at.is_finite():
		_visitor=Vector3.INF
		return ""
	var local:=to_local(at)
	if absf(local.y-1.15)>.8:
		_visitor=Vector3.INF
		return ""
	_visitor=Vector3(local.x,0,local.z)
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
		var lines:Array=LATE_CHAT[level-1] if _offboarding else CHAT[level-1]
		_line="" if closest<0 else str(lines[0 if closest==0 else closest-5])
	for i in _people.size():
		if i==6 and _task=="chat" and closest<0:
			_people[i].call("attend",_people[WALKER].global_position,true)
		else:
			_people[i].call("attend",at,i==closest)
	if closest<0 and _meeting.active and local.distance_to(_people[WALKER].position+Vector3.UP*1.15)<5.0:
		return _meeting.line(level)
	if closest<0 and _task=="chat" and local.distance_to(_people[WALKER].position+Vector3.UP*1.15)<5.0:
		var exchange:Array=Meeting.LATE_AGENDA[level-1] if _offboarding else EXCHANGES[level-1]
		return str(exchange[0 if _chat_elapsed<2.5 else 1])
	return _line

func stats() -> Dictionary:
	var animated:=0
	for actor in _people:
		if actor.process_mode!=Node.PROCESS_MODE_DISABLED:
			animated+=1
	return {"people":_people.size(),"animated":animated,"seated":6,"standing":2,"walking":_walking,"walk_distance":_walk_distance,"route_index":_route_index,"task":_task,"board_visits":_board_visits,"chat_visits":_chat_visits,"print_visits":_print_visits,"coffee_visits":_coffee_visits,"rounds":_rounds,"meeting":_meeting.active,"meetings_completed":_meeting.completed,"offboarding":_offboarding}
