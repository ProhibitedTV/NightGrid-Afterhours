extends Node3D
## Permanent parcel-owned display; no added v1 fleet/save index.
const R9=preload("res://scripts/road_car_visual.gd")
const Kestrel=preload("res://scripts/kestrel_s6_visual.gd")
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

func stats() -> Dictionary:
	return {"plate":PLATE,"founder":is_instance_valid(_car),"static":_car.get("_founder_display"),"bay":BAY,"reserved_bays":3,"staff_bays":EMPLOYEE_X.size(),"other_parked":_parked.size(),"covered":get_node_or_null("ExecutiveCanopy")!=null}
