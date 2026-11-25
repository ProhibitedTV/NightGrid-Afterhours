extends Node3D
## Permanent parcel-owned display; no added v1 fleet/save index.
const R9=preload("res://scripts/road_car_visual.gd")
const Kestrel=preload("res://scripts/kestrel_s6_visual.gd")
const Staff=preload("res://scripts/synaxis_staff.gd")
const GuardDialogue=preload("res://scripts/synaxis_parking_dialogue.gd")
var _guard:Node3D
var _guard_active:=false
const BAY=Vector3(0,0,14.1)
const EMPLOYEE_Z=23.1
const EMPLOYEE_X=[-5.4,-1.8,1.8,5.4]
var _parked:Array[Node3D]=[]
const PLATE="SYNX1"
const GOLD=Color("b7a06f")
var _car:Node3D
var _materials:Dictionary={}

func _material(color:Color) -> StandardMaterial3D:
	var key:=color.to_html()
	if not _materials.has(key):
		var m:=StandardMaterial3D.new()
		m.albedo_color=color
		m.roughness=.79
		_materials[key]=m
	return _materials[key]

func _box(id:String,at:Vector3,size:Vector3,color:Color,solid:bool=false) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.name=id
	var mesh:=BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.position=at
	node.material_override=_material(color)
	add_child(node)
	if solid:
		var body:=StaticBody3D.new()
		body.name=id+"Collision"
		body.position=at
		var hit:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=size
		hit.shape=shape
		body.add_child(hit)
		add_child(body)
	return node

func _label(id:String,value:String,at:Vector3,pixel:float,yaw:float=0.0) -> Label3D:
	var sign:=Label3D.new()
	sign.name=id
	sign.text=value
	sign.font_size=48
	sign.pixel_size=pixel
	sign.outline_size=2
	sign.position=at
	sign.rotation.y=yaw
	add_child(sign)
	return sign

func _ready() -> void:
	# Rear forecourt inside HQ's own western parcel, beyond the south wall.
	_box("ParkingSurface",Vector3(0,.012,18.15),Vector3(15.4,.024,15.3),Color("34383d"))
	for x in [-5.7,-2.1,2.1,5.7]:
		_box("BayStripe",BAY+Vector3(x,.030,0),Vector3(.09,.012,5.8),GOLD if absf(x)<3 else Color("b6b9b6"))
	_box("FounderBayHeader",BAY+Vector3(0,.031,-2.87),Vector3(4.2,.012,.11),GOLD)
	_box("FounderBayFooter",BAY+Vector3(0,.031,2.87),Vector3(4.2,.012,.11),GOLD)
	for x in [-3.9,3.9]:
		_box("WheelStop",BAY+Vector3(x,.09,-2.55),Vector3(1.65,.18,.17),Color("858980"),true)
		_box("WheelStopStripe",BAY+Vector3(x,.186,-2.55),Vector3(1.4,.015,.15),Color("d1ba80"))
	_box("FounderSignPost",BAY+Vector3(-1.8,.75,-3.38),Vector3(.10,1.5,.10),Color("686d70"),true)
	_box("FounderSign",BAY+Vector3(-1.8,1.55,-3.38),Vector3(1.18,.60,.065),Color("202a2d"))
	_label("ReservedFounder","SYNAXIS / FOUNDER\nRESERVED • 01",BAY+Vector3(-1.8,1.55,-3.337),.0018)
	_label("ReservedLeadership","EXECUTIVE RESERVE",BAY+Vector3(0,.044,3.35),.003).rotation.x=-PI/2
	for x in [-3.9,3.9]:
		_label("ExecutiveBay","LEADERSHIP",BAY+Vector3(x,.044,3.15),.0022).rotation.x=-PI/2
	# Same authored coupe mesh, with instance-private finish overrides.
	_car=R9.new()
	_car.name="JetsonFounderR9"
	_car.configure_founder_display()
	_car.position=BAY+Vector3(0,.825+.026,0)
	add_child(_car)
	# Collision is parcel-owned and matches the original coupe envelope.
	var body:=StaticBody3D.new()
	body.name="FounderR9Collision"
	body.position=BAY+Vector3(0,.655+.026,0)
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(2.03,1.31,4.66)
	collider.shape=shape
	body.add_child(collider)
	add_child(body)
	_box("FounderPlate",BAY+Vector3(0,.45,2.345),Vector3(.34,.16,.021),Color("11191b"))
	_label("FounderPlateText",PLATE,BAY+Vector3(0,.45,2.359),.0016)
	_box("FounderParkingPost",BAY+Vector3(2.55,.65,-3.35),Vector3(.22,1.30,.22),Color("313b3f"),true)
	_box("FounderParkingReader",BAY+Vector3(2.55,1.22,-3.22),Vector3(.18,.15,.06),GOLD)
	_build_leadership_cover()
	_park_kestrel("CapitalAllocationS6",Vector3(-3.9,0,BAY.z),Color("252c36"),0.0)
	_park_kestrel("TechnologyStrategyS6",Vector3(3.9,0,BAY.z),Color("c1c4c2"),0.0)
	_build_employee_row()
	_build_walkway()
	_build_security_station()
	_build_guard()

func _park_kestrel(id:String,at:Vector3,paint:Color,yaw:float) -> void:
	var car:=Kestrel.new()
	car.name=id
	car.configure_parking_display(paint)
	car.position=at+Vector3.UP*.866
	car.rotation.y=yaw
	add_child(car)
	_parked.append(car)
	# Match the actual Kestrel parked tire datum and body envelope.
	var body:=StaticBody3D.new()
	body.name=id+"Collision"
	body.position=at+Vector3.UP*1.05
	body.rotation.y=yaw
	var hit:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(2.35,1.95,4.65)
	hit.shape=shape
	body.add_child(hit)
	add_child(body)

func _build_leadership_cover() -> void:
	var slate:=Color("343d42")
	_box("ExecutiveCanopy",Vector3(0,3.17,BAY.z),Vector3(14.4,.24,6.45),slate,true)
	for x in [-7.0,7.0]:
		for z in [BAY.z-2.9,BAY.z+2.9]:
			_box("CanopyPost",Vector3(x,1.55,z),Vector3(.22,3.10,.22),slate,true)
			_box("PostFoot",Vector3(x,.095,z),Vector3(.40,.19,.40),Color("727776"),true)
	for x in [-4.3,0.0,4.3]:
		_box("CanopyBeam",Vector3(x,2.99,BAY.z),Vector3(.18,.14,6.10),slate)
		var fixture:=_box("CanopyLight",Vector3(x,2.89,BAY.z),Vector3(.70,.07,2.0),Color("ded1ad"))
		var lamp:=StandardMaterial3D.new()
		lamp.albedo_color=Color("e6d9bb")
		lamp.emission_enabled=true
		lamp.emission=Color("e6d9bb")
		lamp.emission_energy_multiplier=.7
		fixture.material_override=lamp
	_box("CanopyFascia",Vector3(0,3.12,BAY.z+3.25),Vector3(14.4,.40,.09),slate)
	_label("CoveredReserve","SYNAXIS  /  LEADERSHIP RESERVE",Vector3(0,3.12,BAY.z+3.31),.0043)
	_label("FounderPrivilege","EMPLOYEE PARKING BENEFITS VARY BY LEVEL",Vector3(0,2.73,BAY.z+3.31),.0025)

func _build_employee_row() -> void:
	var faded:=Color("8f9592")
	for x in [-7.2,-3.6,0.0,3.6,7.2]:
		_box("EmployeeLine",Vector3(x,.031,EMPLOYEE_Z),Vector3(.075,.012,5.0),faded)
	for x in EMPLOYEE_X:
		_box("EmployeeStop",Vector3(x,.09,EMPLOYEE_Z+2.20),Vector3(1.75,.18,.16),Color("737977"),true)
		_label("EmployeeSlot","STAFF",Vector3(x,.044,EMPLOYEE_Z-2.25),.0021).rotation.x=-PI/2
	_park_kestrel("EmployeeSilver",Vector3(-5.4,0,EMPLOYEE_Z),Color("8d9297"),PI)
	_park_kestrel("EmployeeBlue",Vector3(-1.8,0,EMPLOYEE_Z),Color("4d6879"),PI)
	_park_kestrel("EmployeeWhite",Vector3(5.4,0,EMPLOYEE_Z),Color("d2d0c7"),PI)
	# One empty stall, with a painted arrow toward the remainder of campus parking.
	_label("Overflow","STAFF OVERFLOW / NO RESERVED SPACES",Vector3(7.48,1.5,19.25),.0022,-PI/2)
	_box("OverflowPost",Vector3(7.52,.75,19.25),Vector3(.10,1.5,.10),Color("676e70"),true)

func _build_walkway() -> void:
	# Thin markings above the existing sidewalk, no additional trip hazards.
	for z in range(-8,18):
		_box("PedestrianStripe",Vector3(-9.14,.027,float(z)),Vector3(.085,.012,.65),Color("d2bf86"))
	for i in range(6):
		_box("RearCrosswalk",Vector3(-7.52,.039,17.9+i*.39),Vector3(1.14,.012,.22),Color("c2c3bc"))
	_label("PedestrianRoute","PEDESTRIAN ROUTE / LOBBY",Vector3(-8.9,.043,10.6),.0026).rotation.x=-PI/2

func _build_security_station() -> void:
	# Compact booth along the west side, outside vehicle and pedestrian lanes.
	var at:=Vector3(-7.92,0,15.6)
	var slate:=Color("303d44")
	var steel:=Color("78878a")
	_box("SecurityBoothBase",at+Vector3(0,.48,0),Vector3(1.12,.96,1.56),slate,true)
	_box("SecurityBoothCounter",at+Vector3(0,1.00,0),Vector3(1.18,.09,1.65),steel)
	_box("SecurityBoothRoof",at+Vector3(0,2.34,0),Vector3(1.38,.15,1.87),slate)
	for dx in [-.51,.51]:
		for dz in [-.71,.71]:
			_box("BoothFrame",at+Vector3(dx,1.65,dz),Vector3(.075,1.24,.075),steel)
	# Side and back panels are physically closed; the aisle-facing service window is open.
	var glass:=StandardMaterial3D.new()
	glass.albedo_color=Color(.46,.65,.69,.24)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness=.17
	var west:=_box("BoothWestWindow",at+Vector3(-.53,1.65,0),Vector3(.05,1.24,1.43),steel,true)
	west.material_override=glass
	var back:=_box("BoothRearWindow",at+Vector3(0,1.65,-.73),Vector3(1.04,1.24,.05),steel,true)
	back.material_override=glass
	_box("BoothMonitor",at+Vector3(.05,1.34,-.38),Vector3(.50,.37,.08),Color("171d21"))
	var screen:=_box("BoothMonitorScreen",at+Vector3(.05,1.34,-.331),Vector3(.44,.30,.012),Color("557b75"))
	var lit:=StandardMaterial3D.new()
	lit.albedo_color=Color("243d39")
	lit.emission_enabled=true
	lit.emission=Color("629d91")
	lit.emission_energy_multiplier=.45
	screen.material_override=lit
	_box("BoothMonitorStand",at+Vector3(.05,1.12,-.38),Vector3(.10,.16,.18),slate)
	_box("BoothLogbook",at+Vector3(.05,1.065,.24),Vector3(.31,.035,.26),Color("c6ba9b"))
	for i in range(3):
		_box("LogbookLine",at+Vector3(.05,1.087,.18+i*.047),Vector3(.23,.006,.009),Color("77766b"))
	_box("BoothRadio",at+Vector3(-.36,1.16,.30),Vector3(.11,.24,.09),Color("20282c"))
	_box("RadioAntenna",at+Vector3(-.39,1.36,.30),Vector3(.015,.20,.015),Color("20282c"))
	_box("BoothFascia",at+Vector3(0,2.28,.96),Vector3(1.30,.26,.07),slate)
	_label("SecurityBoothTitle","SECURITY / 02",at+Vector3(0,2.28,1.0),.0018)
	_label("BoothNotice","ALL INCIDENTS MUST BE LOGGED",at+Vector3(0,.68,.785),.0013)
	# CCTV housing is a visual prop, not an extra camera feed or render pass.
	_box("BoothCameraMount",at+Vector3(.57,2.22,.77),Vector3(.12,.14,.16),steel)
	var camera:=_box("BoothCamera",at+Vector3(.64,2.15,.91),Vector3(.18,.16,.30),Color("c4cbca"))
	camera.rotation.x=-.20
	_box("BoothCameraLens",at+Vector3(.64,2.12,1.07),Vector3(.11,.09,.025),Color("171d21"))

func _build_guard() -> void:
	_guard=Staff.new()
	_guard.name="ParkingSecurityGuard"
	_guard.configure_staff({"id":"marcus_vale","name":GuardDialogue.NAME,"role":"Executive parking security","activity":"WATCH","seated":false,"palette":3,"outfit":"security","hair":"cropped","glasses":false,"coat":"263b50","height":.94,"width":.86,"phase":2.5})
	_guard.position=GuardDialogue.ANCHOR
	_guard.rotation.y=-PI/2
	add_child(_guard)
	_box("SecurityStationPost",Vector3(-7.12,.85,17.65),Vector3(.09,1.7,.09),Color("59646a"),true)
	_box("SecurityStationSign",Vector3(-7.12,1.70,17.65),Vector3(.10,.48,.78),Color("25323e"))
	_label("GuardStation","SECURITY\nLEADERSHIP RESERVE",Vector3(-7.06,1.70,17.65),.0017,PI/2)
	update_guard(Vector3.INF)

func guard_reachable(at:Vector3) -> bool:
	if not at.is_finite():
		return false
	var local:=to_local(at)
	return absf(local.y-1.15)<.8 and local.z>17.0 and local.z<20.2 and local.x< -4.9 and local.distance_to(GuardDialogue.ANCHOR+Vector3.UP*1.15)<1.85

func update_guard(at:Vector3) -> void:
	if not is_instance_valid(_guard):
		return
	var active:=at.is_finite() and _guard.global_position.distance_squared_to(at)<400.0
	if active!=_guard_active or (not active and _guard.process_mode!=Node.PROCESS_MODE_DISABLED):
		_guard_active=active
		_guard.process_mode=Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
	_guard.call("attend",at if active else Vector3.ZERO,guard_reachable(at))

func stats() -> Dictionary:
	return {"plate":PLATE,"founder":is_instance_valid(_car),"static":_car.get("_founder_display"),"bay":BAY,"reserved_bays":3,"staff_bays":EMPLOYEE_X.size(),"other_parked":_parked.size(),"covered":get_node_or_null("ExecutiveCanopy")!=null,"guard":is_instance_valid(_guard),"booth":get_node_or_null("SecurityBoothBaseCollision")!=null}
