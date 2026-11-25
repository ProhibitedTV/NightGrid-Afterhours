extends "res://scripts/synaxis_workfloor.gd"
## Executive-only fit-out and authored staff. All static furniture batched.
const Staff=preload("res://scripts/synaxis_staff.gd")
const FLOOR=5
const TITLE="EXECUTIVE LEADERSHIP / PEOPLE STRATEGY"
const WALL_EDGES=[
	[Vector2(-8.35,-.7),Vector2(-3.1,-.7)],
	[Vector2(3.1,-.7),Vector2(8.35,-.7)],
	[Vector2(-3.1,-9.85),Vector2(-3.1,-3.5)],
	[Vector2(3.1,-9.85),Vector2(3.1,-3.5)]
]
const FURNITURE_EDGES=[
	[Vector2(-7.25,-5.55),Vector2(-4.05,-5.55)],
	[Vector2(4.05,-5.55),Vector2(7.25,-5.55)],
	[Vector2(0,-8.4),Vector2(0,-3.7)],
	[Vector2(-7.1,2.5),Vector2(-4.1,2.5)],
	[Vector2(4.0,2.2),Vector2(7.2,2.2)]
]
const LUXURY={
	"walnut":Color("4e352b"),"brass":Color("b49a62"),"marble":Color("e2ddd1"),
	"vein":Color("b0a99e"),"cream":Color("d3c6b3"),"navy":Color("253745"),
	"velvet":Color("48655d"),"glass_tint":Color("819a9d"),"gold_light":Color("ffe1ae")
}
const EXECUTIVES=[
	{"id":"cfo","name":"Graham Voss","role":"Chief Financial Officer","activity":"READ","seated":true,"palette":4,"position":Vector3(-5.65,0,-6.8),"yaw":0.0,"outfit":"executive","hair":"silver","glasses":true,"coat":"303945","height":.95,"width":.87,"phase":1.6},
	{"id":"cto","name":"Dr. Sera Okafor","role":"Chief Technology Officer","activity":"CHAT","seated":true,"palette":1,"position":Vector3(5.65,0,-6.8),"yaw":0.0,"outfit":"executive","hair":"bun","glasses":false,"coat":"3f4d51","height":.91,"width":.77,"phase":2.3},
	{"id":"coo","name":"Victor Sloane","role":"Chief Operating Officer","activity":"CHAT","seated":true,"palette":0,"position":Vector3(-1.15,0,-6.3),"yaw":PI/2,"outfit":"executive","hair":"parted","glasses":false,"coat":"47454d","height":.96,"width":.88,"phase":.8},
	{"id":"legal","name":"Marianne Cross","role":"General Counsel","activity":"READ","seated":true,"palette":2,"position":Vector3(1.15,0,-5.5),"yaw":-PI/2,"outfit":"executive","hair":"bun","glasses":true,"coat":"34364d","height":.89,"width":.73,"phase":4.0},
	{"id":"chro","name":"Blaire Sterling","role":"Chief People Officer","activity":"CHAT","seated":false,"palette":3,"position":Vector3(-5.6,0,3.65),"yaw":0.0,"outfit":"hr","hair":"parted","glasses":false,"coat":"77616a","height":.92,"width":.75,"phase":3.1},
	{"id":"culture","name":"Tessa Bright","role":"VP of Culture & Belonging","activity":"CHAT","seated":false,"palette":4,"position":Vector3(-6.5,0,4.4),"yaw":PI/2,"outfit":"hr","hair":"bun","glasses":true,"coat":"8b7773","height":.87,"width":.70,"phase":1.2},
	{"id":"talent","name":"Parker Wynn","role":"Director of Talent Transformation","activity":"SCROLL","seated":false,"palette":2,"position":Vector3(5.6,0,3.55),"yaw":0.0,"outfit":"hr","hair":"cropped","glasses":false,"coat":"63746f","height":.92,"width":.76,"phase":5.0}
]
const REMARKS={
	"cfo":["We missed our savings target, so I approved another share buyback.","A headcount reduction is a recurring revenue opportunity.","If the investigation moves the share price, it becomes your performance issue."],
	"cto":["I actually miss writing code. Now I approve slides about code.","I didn't authorize that prototype transfer. Check Executive Affairs.","An audit log is not a suggestion. Unfortunately, my opinion apparently is."],
	"coo":["Our employees are our greatest asset. We are aggressively reducing assets.","We're eliminating friction by eliminating the people who report it.","The board wants a single owner for this issue. Congratulations."],
	"legal":["I can give you guidance, but I cannot give you advice about the guidance.","Please preserve the records. Please do not distribute the records.","We have concluded that our investigation of ourselves was sufficiently independent."],
	"chro":["Bring your whole self to work. Subject to the employee handbook.","We aren't cutting jobs. We're unlocking professional mobility.","We celebrate difficult conversations, especially when they end with a badge being returned."],
	"culture":["Your voice matters. Please use the approved feedback channel.","We're creating space for courageous conversations. The space is fully booked.","Belonging is a journey, not a contractual obligation."],
	"talent":["We put people first. Alphabetically, before productivity.","Human potential is infinite. Headcount is not.","Your transition is an opportunity to activate your personal brand."]
}
var _executives: Dictionary={}
var _occupied:=false
var _near:=""
var _phase:=-1
var _remark:=""
var _lux_materials: Dictionary={}

func _material(key: String) -> StandardMaterial3D:
	if not LUXURY.has(key):
		return super._material(key)
	if not _lux_materials.has(key):
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=LUXURY[key]
		mat.roughness=.48
		if key=="brass":
			mat.metallic=.82
			mat.roughness=.29
		elif key=="marble":
			mat.roughness=.26
		elif key=="glass_tint":
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color=Color(.56,.68,.70,.32)
			mat.roughness=.18
		elif key=="gold_light":
			mat.emission_enabled=true
			mat.emission=LUXURY[key]
			mat.emission_energy_multiplier=.9
		_lux_materials[key]=mat
	return _lux_materials[key]

func _ready() -> void:
	# Pale stone, dark walnut, brass fittings and warm lighting; intentionally
	# unlike the employee floors. Preserve the same unobstructed lift landing.
	_part("marble",Vector3(0,.006,0),Vector3(16.6,.01,19.7))
	for x in range(-8,9,2):
		_part("vein",Vector3(x,.014,0),Vector3(.012,.004,19.7))
	for z in range(-9,10,2):
		_part("vein",Vector3(0,.014,z),Vector3(16.6,.004,.012))
	for side in [-1.0,1.0]:
		_part("walnut",Vector3(side*8.30,1.65,0),Vector3(.08,3.3,19.7))
		_part("brass",Vector3(side*8.24,.12,0),Vector3(.045,.18,19.7))
		for z in [-8.0,-4.0,0.0,4.0,8.0]:
			_part("brass",Vector3(side*8.245,1.66,z),Vector3(.035,3.25,.035))
		_part("walnut",Vector3(side*5.65,1.65,-9.79),Vector3(5.2,3.3,.07))
		_part("navy",Vector3(side*5.65,.019,-5.8),Vector3(4.85,.015,5.5))
		_private_office(side)
	for edge in WALL_EDGES:
		var a:Vector2=edge[0]
		var b:Vector2=edge[1]
		var center:Vector2=(a+b)*.5
		var size:=Vector3(absf(b.x-a.x)+.08,2.7,absf(b.y-a.y)+.08)
		_part("glass_tint",Vector3(center.x,1.35,center.y),size)
		_part("brass",Vector3(center.x,2.72,center.y),Vector3(size.x,.045,size.z))
		_solid(Vector3(center.x,1.35,center.y),size)
	_boardroom()
	_people_suite()
	_lounge()
	_part("navy",Vector3(0,2.2,9.80),Vector3(9.6,1.85,.10))
	_label("SYNAXIS  /  EXECUTIVE LEADERSHIP",Vector3(0,2.66,9.73),.006,PI)
	_label("OUR PEOPLE. OUR PURPOSE. OUR PERFORMANCE.",Vector3(0,2.12,9.73),.004,PI)
	_label("EXECUTIVE ACCESS / PLEASE RESPECT THE PRIVACY OF LEADERSHIP",Vector3(0,1.72,9.73),.0026,PI)
	_label("BOARDROOM / STRATEGY",Vector3(0,2.80,-9.78),.0048)
	_label("LIFT DOWN",Vector3(.9,1.85,5.48),.003)
	_part("brass",Vector3(.9,.018,5),Vector3(.78,.016,.82))
	for x in [-5.5,0.0,5.5]:
		for z in [-6.5,0.0,6.5]:
			_part("gold_light",Vector3(x,3.27,z),Vector3(2.65,.045,.16))
			_part("brass",Vector3(x,3.31,z),Vector3(2.82,.04,.24))
	for z in [-5.7,0.8,7.3]:
		var lamp:=OmniLight3D.new()
		lamp.position=Vector3(0,2.9,z)
		lamp.light_color=Color("ffe4bc")
		lamp.light_energy=1.7
		lamp.omni_range=11.5
		lamp.shadow_enabled=false
		add_child(lamp)
		_lights.append(lamp)
	_flush()
	_build_executives()
	set_occupied(false)

func _private_office(side: float) -> void:
	var x:=side*5.65
	_part("walnut",Vector3(x,.84,-5.55),Vector3(3.2,.13,1.0))
	_part("brass",Vector3(x,.79,-5.05),Vector3(3.2,.025,.025))
	for dx in [-1.34,1.34]:
		_part("walnut",Vector3(x+dx,.40,-5.55),Vector3(.44,.8,.86))
	_solid(Vector3(x,.46,-5.55),Vector3(3.2,.91,1.0))
	_monitor(Vector3(x+.75,1.18,-5.65),-1.0)
	_part("cream",Vector3(x-.65,.93,-5.46),Vector3(.37,.045,.28))
	_chair(Vector3(x,0,-6.80),1.0)
	_chair(Vector3(x-.70,0,-4.45),-1.0)
	_chair(Vector3(x+.70,0,-4.45),-1.0)
	_plant(Vector3(side*7.65,0,-8.7),.65)
	_part("walnut",Vector3(x,.55,-9.25),Vector3(3.2,1.1,.60))
	_solid(Vector3(x,.55,-9.25),Vector3(3.2,1.1,.60))
	_label("FINANCE / CAPITAL ALLOCATION" if side<0 else "TECHNOLOGY / PRODUCT STRATEGY",Vector3(x,2.6,-9.68),.004)

func _boardroom() -> void:
	_part("walnut",Vector3(0,.84,-6.05),Vector3(1.52,.13,4.7))
	_part("brass",Vector3(0,.79,-6.05),Vector3(.10,.025,4.66))
	_part("marble",Vector3(0,.40,-6.05),Vector3(.66,.80,3.35))
	_solid(Vector3(0,.46,-6.05),Vector3(1.52,.91,4.7))
	for side in [-1.0,1.0]:
		for z in [-7.7,-6.3,-5.5,-4.35]:
			_chair(Vector3(side*1.15,0,z),1.0)
			_part("paper",Vector3(side*.46,.924,z),Vector3(.27,.028,.24))
			_part("glass",Vector3(side*.48,1.0,z+.22),Vector3(.075,.14,.075),0.0,"cyl")
	_part("black",Vector3(0,2.0,-9.73),Vector3(3.8,1.53,.09))
	_part("screen",Vector3(0,2.0,-9.67),Vector3(3.65,1.38,.02))
	_label("Q4  /  SHAREHOLDER VALUE",Vector3(0,2.35,-9.64),.004)
	_label("REVENUE ↑   HEADCOUNT ↓",Vector3(0,1.85,-9.64),.004)

func _people_suite() -> void:
	for side in [-1.0,1.0]:
		var x:=side*5.6
		_part("walnut",Vector3(x,.84,2.35),Vector3(3.0,.13,1.1))
		_solid(Vector3(x,.46,2.35),Vector3(3.0,.91,1.1))
		_part("brass",Vector3(x,.42,2.35),Vector3(.45,.84,.82))
		_monitor(Vector3(x+.55,1.18,2.25),1.0)
		_chair(Vector3(x,0,1.18),1.0)
		_plant(Vector3(x-.95,.91,2.35),.23)
	_label("PEOPLE EXPERIENCE / CULTURE",Vector3(-5.6,2.5,2.35),.0038)
	_label("TALENT TRANSFORMATION",Vector3(5.6,2.5,2.35),.0038)
	_label("WE LISTEN. WE CARE. WE OPTIMIZE.",Vector3(-8.17,2.6,3.1),.004,PI/2)
	_label("EMPOWERING YOUR NEXT CHAPTER",Vector3(8.17,2.6,3.1),.004,-PI/2)

func _lounge() -> void:
	for side in [-1.0,1.0]:
		var x:=side*5.4
		_part("velvet",Vector3(x,.42,8.85),Vector3(3.0,.52,.88))
		_part("velvet",Vector3(x,.86,9.21),Vector3(3.0,.65,.20))
		_solid(Vector3(x,.55,8.85),Vector3(3.0,1.10,.88))
		_part("marble",Vector3(x,.45,7.45),Vector3(1.58,.085,.82))
		_part("brass",Vector3(x,.22,7.45),Vector3(.25,.44,.40))
		_solid(Vector3(x,.25,7.45),Vector3(1.58,.50,.82))
		_plant(Vector3(side*7.55,0,9.0),.68)
	_part("walnut",Vector3(7.78,.58,5.7),Vector3(.75,1.16,1.85))
	_solid(Vector3(7.78,.58,5.7),Vector3(.75,1.16,1.85))
	_part("black",Vector3(7.76,1.43,5.7),Vector3(.56,.53,.65))
	_part("brass",Vector3(7.46,1.43,5.7),Vector3(.025,.31,.48))
	_label("EXECUTIVE ESPRESSO / COMPLIMENTARY",Vector3(7.31,1.97,5.7),.0024,-PI/2)

func _build_executives() -> void:
	for spec in EXECUTIVES:
		var actor:=Staff.new()
		actor.configure_staff(spec)
		actor.position=spec["position"]
		actor.rotation.y=float(spec["yaw"])
		add_child(actor)
		_executives[spec["id"]]=actor

func set_occupied(active: bool) -> void:
	super.set_occupied(active)
	_occupied=active
	for actor in _executives.values():
		actor.visible=active
		actor.process_mode=Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
		if not active:
			actor.call("attend",Vector3.ZERO,false)
	_near=""
	_phase=-1
	_remark=""

func executive_stats() -> Dictionary:
	return {"executives":_executives.size(),"chairs":_chairs,"plants":_plants,"colliders":_colliders,"parts":_parts,"occupied":_occupied}

func staff_remark(at: Vector3,stage: int) -> String:
	if not _occupied or not at.is_finite():
		return ""
	var closest:=""
	var best:=2.15*2.15
	var local:=to_local(at)
	for id in _executives:
		var actor:Node3D=_executives[id]
		var anchor:=actor.position
		# Do not converse through the glass office partitions.
		if (local.z<-.7)!=(anchor.z<-.7):
			continue
		if local.z< -3.5 and anchor.z< -3.5 and int(signf(local.x)*float(absf(local.x)>3.1))!=int(signf(anchor.x)*float(absf(anchor.x)>3.1)):
			continue
		var distance:=actor.global_position.distance_squared_to(at-Vector3.UP*1.15)
		if distance<best:
			closest=id
			best=distance
	var phase:=0 if stage< -1 else (1 if stage<4 else 2)
	if closest!=_near or phase!=_phase:
		_near=closest
		_phase=phase
		_remark="" if closest.is_empty() else "%s: %s" % [_executives[closest].get("display_name"),REMARKS[closest][phase]]
	for id in _executives:
		_executives[id].call("attend",at,id==closest)
	return _remark
