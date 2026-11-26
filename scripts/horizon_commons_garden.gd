extends Node3D
## Fixed public garden furniture, independent of seed. Keep the central
## cross paths, pavilion columns and existing flora sites unobstructed.
const Materials = preload("res://scripts/material_library.gd")
const BED_TINT = Color("7d8982")
const TIMBER = Color("a08468")
const STEEL = Color("414f52")
const PATH = Color("aaa398")
const RECEIPT = "civic:horizon_garden_trail"
const REWARD = 25
const STOPS = [
	{"point":Vector3(-9.0,0.15,-9.0),"name":"Rain garden","text":"Rainwater feeds the beds instead of flooding the street."},
	{"point":Vector3(-9.0,0.15,5.0),"name":"Pollinator patch","text":"The cooperative grows flowers for the rooftop beekeepers."},
	{"point":Vector3(9.0,0.15,-9.0),"name":"Medicinal herbs","text":"Horizon Health teaches residents how to tend these plants."},
	{"point":Vector3(9.0,0.15,5.0),"name":"Community seed bank","text":"Take seeds, leave seeds. No subscription required."}
]

func trail_stop(at:Vector3)->int:
	if not at.is_finite():
		return -1
	var local:=to_local(at)
	if local.y<-.2 or local.y>1.8:
		return -1
	for i in range(STOPS.size()):
		var point:Vector3=STOPS[i]["point"]
		if Vector2(local.x-point.x,local.z-point.z).length()<=1.35:
			return i
	return -1


func _ready() -> void:
	# Four planted beds beside the north/south approach. Existing large
	# trees are at z +/-14; the side fern and flowers are at x +/-15.5.
	for side in [-1,1]:
		for row in [-9.0,5.0]:
			var bed := Node3D.new()
			bed.name = "RaisedBed_%s_%d" % ["W" if side<0 else "E",int(row)]
			bed.position = Vector3(side*12.0,0.15,row)
			add_child(bed)
			_box(bed,"RetainingWall",Vector3(0,.29,0),Vector3(4.6,.58,2.1),BED_TINT,"CONCRETE",true)
			_box(bed,"Soil",Vector3(0,.60,0),Vector3(4.27,.08,1.77),Color("51463c"),"CONCRETE")
			for edge in [-1.0,1.0]:
				_box(bed,"StoneCap",Vector3(0,.62,edge*.96),Vector3(4.65,.12,.20),PATH,"PAVERS")
			for n in range(5):
				# Small authored planting clusters; existing scanned fern
				# and landmark trees are retained, not duplicated.
				_plant(bed,Vector3(-1.65+n*.82,.64,0.0),n)
		for row in [-7.0,3.8]:
			var bench := Node3D.new()
			bench.name = "GardenBench_%s_%d" % ["W" if side<0 else "E",int(row*10)]
			bench.position = Vector3(side*7.3,.15,row)
			bench.rotation.y = side*PI/2.0
			add_child(bench)
			_bench(bench)
		# Small flat drain assemblies beside the paved axis, not hazards.
		for row in [-12.0,-4.0,4.0]:
			var drain := Node3D.new()
			drain.name = "GardenDrain_%s_%d" % ["W" if side<0 else "E",int(row)]
			drain.position = Vector3(side*2.85,.205,row)
			add_child(drain)
			_box(drain,"Frame",Vector3.ZERO,Vector3(.55,.035,.80),STEEL,"METAL")
			for n in range(7):
				_box(drain,"GrateBar",Vector3(0,.025,-.33+n*.11),Vector3(.46,.025,.035),BED_TINT,"METAL")
	# Four physical interpretive panels on the inner faces of the beds.
	for i in range(STOPS.size()):
		var stop:Dictionary=STOPS[i]
		var point:Vector3=stop["point"]
		var panel:=Node3D.new()
		panel.name="GardenTrailPanel_%d"%i
		panel.position=point+Vector3(signf(point.x)*.68,.90,0)
		panel.rotation.y=-signf(point.x)*PI/2.0
		add_child(panel)
		_box(panel,"Panel",Vector3.ZERO,Vector3(1.12,.48,.08),STEEL,"METAL")
		var label:=Label3D.new()
		label.text="%02d / %s\nGARDEN TRAIL"%[i+1,str(stop["name"]).to_upper()]
		label.font_size=21
		label.pixel_size=.0045
		label.position.z=.05
		label.modulate=Color("d9efe3")
		label.double_sided=false
		panel.add_child(label)
	# Wayfinding is mounted to actual panels on the approach shoulders.
	for side in [-1,1]:
		var sign := Node3D.new()
		sign.name = "GardenWayfinding_%s" % ["W" if side<0 else "E"]
		sign.position = Vector3(side*4.6,.15,-15.7)
		add_child(sign)
		_box(sign,"Post",Vector3(0,.80,0),Vector3(.14,1.6,.14),STEEL,"METAL",true)
		_box(sign,"Panel",Vector3(0,1.65,0),Vector3(2.1,.75,.13),STEEL,"METAL",true)
		var label := Label3D.new()
		label.text = "HORIZON COMMONS\nGARDEN / HEALTH PAVILION"
		label.position = Vector3(0,1.65,-.075)
		label.rotation.y = PI
		label.font_size = 22
		label.pixel_size = .005
		label.modulate = Color("d9efe3")
		label.double_sided = false
		sign.add_child(label)

func _bench(root:Node3D)->void:
	_box(root,"Seat",Vector3(0,.47,0),Vector3(2.35,.12,.55),TIMBER,"WOOD",true)
	_box(root,"Backrest",Vector3(0,.82,.26),Vector3(2.35,.52,.09),TIMBER,"WOOD",true)
	for x in [-.93,.93]:
		_box(root,"Leg",Vector3(x,.23,0),Vector3(.13,.46,.47),STEEL,"METAL",true)
	for n in range(4):
		_box(root,"SeatSlat",Vector3(0,.535,-.205+n*.137),Vector3(2.31,.025,.118),TIMBER,"WOOD")
	for n in range(3):
		_box(root,"BackSlat",Vector3(0,.64+n*.17,.205),Vector3(2.31,.13,.025),TIMBER,"WOOD")

func _plant(parent:Node3D,at:Vector3,index:int)->void:
	var plant := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius=.34
	mesh.height=.53
	mesh.radial_segments=12
	mesh.rings=5
	plant.mesh=mesh
	plant.position=at+Vector3.UP*.27
	plant.material_override=Materials.surface("WOOD",Color("62856b") if index%2==0 else Color("78976a"))
	parent.add_child(plant)

func _box(parent:Node3D,label:String,at:Vector3,size:Vector3,tint:Color,kind:String,solid:bool=false)->void:
	var view := MeshInstance3D.new()
	view.name=label
	var mesh := BoxMesh.new()
	mesh.size=size
	view.mesh=mesh
	view.material_override=Materials.surface(kind,tint)
	if solid:
		var body:=StaticBody3D.new()
		body.name=label
		body.position=at
		var collision:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=size
		collision.shape=shape
		body.add_child(collision)
		body.add_child(view)
		parent.add_child(body,true)
	else:
		view.position=at
		parent.add_child(view,true)
