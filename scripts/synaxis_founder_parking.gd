extends Node3D
## Permanent parcel-owned display; no added v1 fleet/save index.
const R9=preload("res://scripts/road_car_visual.gd")
const BAY=Vector3(0,0,16.1)
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
	_box("ParkingSurface",BAY+Vector3(0,.012,0),Vector3(15.4,.024,8.3),Color("34383d"))
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

func stats() -> Dictionary:
	return {"plate":PLATE,"founder":is_instance_valid(_car),"static":_car.get("_founder_display"),"bay":BAY,"reserved_bays":3}
