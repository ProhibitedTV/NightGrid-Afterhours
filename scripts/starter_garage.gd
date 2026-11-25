extends StaticBody3D
## Fixed two-bay pilot garage. Physical shell is installed in collision stage
## zero; vehicle nodes remain owned by World, never by the streamed parcel.
const BLOCK = Vector2i(-1,-3)
const LOT = 0
const NAME = "LANTERN GARAGE"
const IDS = ["street:kestrel_01","street:cinder_01"]
const RECOVERY_FEE = 75
const Materials = preload("res://scripts/material_library.gd")
const Plan = preload("res://scripts/world_plan.gd")
const WIDTH = 9.6
const DEPTH = 17.0
static func entry() -> Vector3:
	return Vector3((BLOCK.x+.5)*58.0-10.5,1.15,(BLOCK.y+.5)*58.0-Plan.PUBLIC_FACADE_SETBACK-1.5)

func configure(width: float,height: float,depth: float,wall: Color,kind: String) -> void:
	var exterior: Material = Materials.surface(kind,wall)
	var slab: Material = Materials.surface("CONCRETE",Color("686b70"))
	var metal: Material = Materials.surface("METAL",Color("343e48"))
	var stripe: Material = Materials.surface("METAL",Color("e2b569"))
	var flank := (width-WIDTH)*.5
	for side in [-1.0,1.0]:
		_section(Vector3(side*(WIDTH*.5+flank*.5),height*.5,depth*.5),Vector3(flank,height,depth),exterior)
	_section(Vector3(0,height*.5,(DEPTH+depth)*.5),Vector3(WIDTH,height,depth-DEPTH),exterior)
	_section(Vector3(0,(height+4.2)*.5,DEPTH*.5),Vector3(WIDTH,height-4.2,DEPTH),exterior)
	_section(Vector3(0,3.95,.15),Vector3(WIDTH,.5,.3),metal)
	_section(Vector3(0,-.075,DEPTH*.5),Vector3(WIDTH,.15,DEPTH),slab)
	# Side-mounted service desk leaves both drive lanes unobstructed.
	_section(Vector3(4.0,.55,3.0),Vector3(1.1,1.1,1.0),metal)
	for x in [-4.65,0.0,4.65]:
		_mesh(Vector3(x,.012,10.5),Vector3(.10,.018,7.0),stripe)
	for z in [4.0,9.0,14.0]:
		_mesh(Vector3(0,4.12,z),Vector3(6.0,.10,.28),stripe)
	var label := Label3D.new()
	label.text = "LANTERN GARAGE / RECOVERY DESK"
	label.font_size = 44
	label.pixel_size = .007
	label.position = Vector3(0,3.35,-.18)
	label.rotation.y = PI
	add_child(label)

func _section(at: Vector3,size: Vector3,material: Material) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = at
	add_child(collider)
	_mesh(at,size,material)

func _mesh(at: Vector3,size: Vector3,material: Material) -> void:
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.position = at
	view.material_override = material
	add_child(view)

func desk_point() -> Vector3:
	return to_global(Vector3(3.0,1.15,3.0))

func desk_reachable(at: Vector3) -> bool:
	return at.distance_to(desk_point()) < 1.35

func bay_point(index: int) -> Vector3:
	return to_global(Vector3(-2.35 if index == 0 else 2.35,0.0,10.5))

func parked_at(at: Vector3,index: int) -> bool:
	var p := to_local(at)
	return absf(p.x-(-2.35 if index == 0 else 2.35))<1.4 and absf(p.z-10.5)<2.1 and p.y>=-.1 and p.y<2.4
