extends Node3D
## Fixed lift frontage, common across floors. Existing fade/transfer owns travel.
## The closed doors are real collision; call stations remain on the aisle side.
const CENTER=Vector2(0,5.0)
const WALL_EDGES=[
	[Vector2(-1.95,6.20),Vector2(1.95,6.20)],
	[Vector2(-1.95,6.20),Vector2(-1.95,9.85)],
	[Vector2(1.95,6.20),Vector2(1.95,9.85)]
]
var floor_label:="G"
var up_label:="UP"
var down_label:="DOWN"
var materials:Dictionary={}

func _ready() -> void:
	_box("LiftCoreFront",Vector3(0,1.67,6.32),Vector3(3.90,3.34,.24),"wall",true)
	for x in [-1.95,1.95]:
		_box("LiftCoreSide",Vector3(x,1.67,8.03),Vector3(.16,3.34,3.65),"wall",true)
	for side in [-1.0,1.0]:
		var x:float=side*.90
		_box("PortalFrame",Vector3(x,1.20,6.16),Vector3(1.48,2.40,.12),"frame")
		for half in [-1.0,1.0]:
			_box("DoorLeaf",Vector3(x+half*.322,1.13,6.08),Vector3(.635,2.23,.045),"door")
		_box("CallStation",Vector3(x+side*.78,1.20,6.07),Vector3(.13,.34,.10),"black")
		var destination:String=up_label if side<0 else down_label
		_box("Indicator",Vector3(x,2.52,6.12),Vector3(1.42,.27,.07),"black")
		_label("Destination",destination,Vector3(x,2.52,6.075),.0018)
		_box("LandingMat",Vector3(x,.016,5.0),Vector3(1.43,.012,1.55),"mat")
		_label("CallDirection","UP" if side<0 else "DOWN",Vector3(x+side*.78,1.20,6.012),.0008)
	_box("LiftHeader",Vector3(0,2.99,6.16),Vector3(3.78,.47,.09),"black")
	_label("LiftHeaderText","ELEVATORS  /  "+floor_label,Vector3(0,2.99,6.105),.0034)

func _box(id:String,at:Vector3,size:Vector3,key:String,solid:bool=false) -> void:
	var mesh:=BoxMesh.new()
	mesh.size=size
	var instance:=MeshInstance3D.new()
	instance.name=id
	instance.position=at
	instance.mesh=mesh
	if not materials.has(key):
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color({"wall":"d1cbbf","frame":"424c50","door":"8c9698","black":"18242c","mat":"3c5655"}[key])
		mat.roughness=.35 if key in ["frame","door"] else .82
		mat.metallic=.65 if key in ["frame","door"] else 0.0
		materials[key]=mat
	instance.material_override=materials[key]
	add_child(instance)
	if solid:
		var body:=StaticBody3D.new()
		body.position=at
		var collider:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=size
		collider.shape=shape
		body.add_child(collider)
		add_child(body)

func _label(id:String,value:String,at:Vector3,pixel:float) -> void:
	var label:=Label3D.new()
	label.name=id
	label.text=value
	label.position=at
	label.rotation.y=PI
	label.font_size=42
	label.pixel_size=pixel
	label.outline_size=0
	label.modulate=Color("e7e9e1")
	add_child(label)
