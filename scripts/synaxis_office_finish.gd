extends Node3D
## Authored static ground-floor finish and tower curtain wall. Shared primitive
## meshes are batched by material, primitive and zone; no process or extra lights.
const PALETTE = {
	"stone": Color("637078"), "joint": Color("28343b"), "trim": Color("a4aeb1"),
	"steel": Color("465159"), "black": Color("1c242a"),
	"laminate": Color("d0b58e"), "walnut": Color("644b3c"), "leather": Color("30353b"),
	"paper": Color("e5e4d8"), "screen": Color("142a31"), "signal": Color("85c9bc"),
	"blue": Color("547d9a"), "amber": Color("d5ae63"), "red": Color("b55850"),
	"porcelain": Color("d8dedb"), "card": Color("ae9169"), "glass": Color("405d70"),
	"glass_dark": Color("304656"), "glass_lit": Color("6a797e"), "rubber": Color("343a3d"),
	"food": Color("d9a951")
}
const ChairAsset=preload("res://scripts/synaxis_chair_asset.gd")
const Desktop=preload("res://scripts/synaxis_desktop_material.gd")
var _chair_poses:Array[Transform3D]=[]
var _groups: Dictionary = {}
var _materials: Dictionary = {}
var _part_count := 0
var _gate_rest: Dictionary = {}

func _ready() -> void:
	_architecture()
	_facade()
	_workplaces()
	_lobby()
	_flush()

func get_detail_stats() -> Dictionary:
	return {"parts": _part_count, "batches": get_child_count()}

func _material(key: String) -> StandardMaterial3D:
	if key.begins_with("desktop"):
		return Desktop.material(key)
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PALETTE[key]
		mat.roughness = .84
		match key:
			"trim", "steel":
				mat.metallic = .65
				mat.roughness = .37
			"glass", "glass_dark", "glass_lit":
				mat.metallic = .26
				mat.roughness = .23
			"walnut", "laminate", "porcelain":
				mat.roughness = .48
			"signal", "amber", "red":
				mat.emission_enabled = true
				mat.emission = PALETTE[key]
				mat.emission_energy_multiplier = .38
		_materials[key] = mat
	return _materials[key]

func _part(zone: String,key: String,at: Vector3,size: Vector3,yaw: float=0.0,primitive: String="box") -> void:
	var id := zone+"_"+key+"_"+primitive
	if not _groups.has(id):
		_groups[id] = []
	var basis := Basis.from_euler(Vector3(0,yaw,0)).scaled_local(size)
	_groups[id].append(Transform3D(basis,at))
	_part_count += 1

func _flush() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .5
	cylinder.bottom_radius = .5
	cylinder.height = 1.0
	cylinder.radial_segments = 16
	for id in _groups:
		var parts: Array = _groups[id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad if str(id).ends_with("_quad") else (cylinder if str(id).ends_with("_cyl") else box)
		mm.instance_count = parts.size()
		for i in range(parts.size()):
			mm.set_instance_transform(i,parts[i])
		var node := MultiMeshInstance3D.new()
		node.name = id
		node.multimesh = mm
		var key: String = str(id).get_slice("_",1)
		if str(id).begins_with("tower_glass_") and str(id).get_slice_count("_") == 4:
			key += "_"+str(id).get_slice("_",2)
		node.material_override = _material(key)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		if str(id).begins_with("gate_"):
			var rest: Array[Transform3D] = []
			for i in range(mm.instance_count):
				rest.append(mm.get_instance_transform(i))
			_gate_rest[id] = rest
	_groups.clear()
	ChairAsset.install(self,_chair_poses)
	_chair_poses.clear()

func _architecture() -> void:
	# Large-format stone joints, recessed skirting and ceiling service hardware.
	# All floor trim is at most 6 mm tall; circulation remains unchanged.
	for x in range(-8,9):
		_part("interior","joint",Vector3(x,.003,0),Vector3(.012,.006,19.7))
	for z in range(-9,10):
		_part("interior","joint",Vector3(0,.003,z),Vector3(16.7,.006,.012))
	for side in [-1.0,1.0]:
		if side<0:
			for span in [Vector2(-9.85,3.5),Vector2(5.5,9.85)]:
				var bounds:Vector2=span
				_part("interior","steel",Vector3(-8.32,.09,(bounds.x+bounds.y)*.5),Vector3(.055,.18,bounds.y-bounds.x))
				_part("interior","trim",Vector3(-8.30,.19,(bounds.x+bounds.y)*.5),Vector3(.06,.025,bounds.y-bounds.x))
		else:
			_part("interior","steel",Vector3(side*8.32,.09,0),Vector3(.055,.18,19.7))
			_part("interior","trim",Vector3(side*8.30,.19,0),Vector3(.06,.025,19.7))
	_part("interior","steel",Vector3(0,.09,9.82),Vector3(16.7,.18,.05))
	_part("interior","steel",Vector3(4.9,.09,-9.82),Vector3(7,.18,.05))
	_part("interior","steel",Vector3(-4.9,.09,-9.82),Vector3(7,.18,.05))
	for x in [-6.0,6.0]:
		for z in [-7.0,-1.0,5.0]:
			_part("interior","steel",Vector3(x,3.30,z),Vector3(.85,.07,.85))
			for i in range(7):
				_part("interior","black",Vector3(x-.33+i*.11,3.258,z),Vector3(.05,.012,.69))
	for z in [-7.5,-2.5,2.5,7.5]:
		for x in [-3.7,3.7]:
			if z < 6.05 or x > 0.0:
				_part("interior","steel",Vector3(x,3.317,z),Vector3(3.34,.04,.38))
	# Floor inlay defines the two circulation zones without collision.
	for x in [-1.55,1.55]:
		_part("interior","trim",Vector3(x,.007,1.1),Vector3(.035,.008,17.0))
	# Partition trim and a framed security door, outside the mission paths.
	for x in [-1.35,1.35]:
		_part("interior","trim",Vector3(x,1.45,-7.49),Vector3(.08,2.90,.09))
	_part("interior","trim",Vector3(0,2.85,-7.49),Vector3(2.78,.10,.09))

func _facade() -> void:
	# Exterior spandrels and individual glazed bays on all four elevations.
	# Opaque reflective finish: no alpha sorting and no fake interior lights.
	for level in range(12):
		var y := 7.18+level*3.65
		for side in [-1.0,1.0]:
			for bay in range(7):
				var x := -7.2+bay*2.4
				var key := "glass_lit" if (bay+level*3+int(side))%9==0 else ("glass_dark" if (bay+level)%4==0 else "glass")
				_part("tower",key,Vector3(x,y,side*10.04),Vector3(2.28,3.02,.12))
			for bay in range(8):
				if side>0 and level==11:
					continue # Clear actual crown glazing and balcony sightline.
				var z := -8.75+bay*2.5
				var key := "glass_dark" if (bay+level)%5==0 else "glass"
				_part("tower",key,Vector3(side*8.54,y,z),Vector3(.12,3.02,2.37))
			_part("tower","steel",Vector3(side*8.62,y-1.79,0),Vector3(.15,.35,20.2))
	for side in [-1.0,1.0]:
		for bay in range(8):
			_part("tower","trim",Vector3(-8.4+bay*2.4,27.5,side*10.13),Vector3(.065,43.8,.12))
		for bay in range(9):
			_part("tower","trim",Vector3(side*8.63,26.45,-10+bay*2.5),Vector3(.12,41.9,.065))

func _desk(at: Vector3,width: float,depth: float,finish: String,executive: bool=false) -> void:
	_part("furniture",finish,at+Vector3(0,1.025,0),Vector3(width,.11,depth))
	_part("furniture","trim",at+Vector3(0,1.05,depth*.5+.008),Vector3(width,.035,.025))
	for side in [-1.0,1.0]:
		_part("furniture","steel",at+Vector3(side*(width*.5-.10),.49,0),Vector3(.065,.98,depth-.12))
		_part("furniture","rubber",at+Vector3(side*(width*.5-.10),.035,0),Vector3(.11,.07,depth-.08))
	_part("furniture",finish,at+Vector3(0,.57,-depth*.28),Vector3(width-.26,.62,.075))
	# Locking drawer pedestal with seams and handles, under the existing footprint.
	var drawer := at+Vector3(width*.5-.36,.49,0)
	_part("furniture",finish,drawer,Vector3(.48,.92,depth-.15))
	for y in [.23,.47,.71]:
		_part("furniture","black",Vector3(drawer.x,y,at.z+depth*.5-.067),Vector3(.44,.013,.018))
		_part("furniture","trim",Vector3(drawer.x,y+.10,at.z+depth*.5-.045),Vector3(.16,.026,.04))
	if executive:
		_part("furniture","walnut",at+Vector3(0,.57,depth*.40),Vector3(width-.20,.80,.09))

func _monitor(at: Vector3,face: float,key: String) -> void:
	_part("furniture","black",at,Vector3(.71,.43,.065))
	_part("furniture","desktop"+key,at+Vector3(0,0,face*.038),Vector3(.66,.38,1.0),0.0 if face>0 else PI,"quad")
	_part("furniture","steel",at-Vector3.UP*.27,Vector3(.07,.19,.08))
	_part("furniture","steel",at-Vector3.UP*.315,Vector3(.37,.04,.23))
	_part("furniture","signal",at+Vector3(.30,-.195,face*.037),Vector3(.025,.013,.008))


func _keyboard(at: Vector3) -> void:
	_part("furniture","black",at,Vector3(.43,.035,.155))
	for row in range(4):
		for col in range(12):
			_part("furniture","steel",at+Vector3(-.194+col*.035,.021,-.058+row*.035),Vector3(.027,.009,.026))
	_part("furniture","rubber",at+Vector3(.33,.003,0),Vector3(.18,.012,.21))
	_part("furniture","black",at+Vector3(.33,.035,0),Vector3(.08,.055,.13))

func _chair(at: Vector3,face: float,executive: bool=false) -> void:
	_chair_poses.append(ChairAsset.pose(at,face,1.13 if executive else 1.08))
	_part_count+=1


func _paperwork(at: Vector3,yaw: float) -> void:
	_part("furniture","paper",at,Vector3(.29,.024,.22),yaw)
	for i in range(4):
		_part("furniture","paper",at+Vector3(.007*i,.014+i*.002,-.003*i),Vector3(.28,.003,.21),yaw)
	_part("furniture","blue",at+Vector3(.09,.029,0),Vector3(.13,.008,.012),yaw)

func _workplaces() -> void:
	_desk(Vector3(4.5,0,1.7),2.25,.85,"laminate")
	_monitor(Vector3(4.85,1.39,1.62),1.0,"blue")
	_keyboard(Vector3(4.85,1.10,1.96))
	_chair(Vector3(4.5,0,2.65),-1.0)
	_desk(Vector3(-5,0,2.55),2.6,.85,"laminate")
	_desk(Vector3(5,0,-5.4),3.8,1.0,"walnut",true)
	_desk(Vector3(-5,0,-5.4),2.7,1.0,"laminate")
	_desk(Vector3(5,0,6.5),3.0,.9,"laminate")
	_monitor(Vector3(-5.55,1.39,2.49),1.0,"signal")
	_monitor(Vector3(-4.77,1.39,2.49),1.0,"amber")
	_monitor(Vector3(5.85,1.39,-5.46),-1.0,"signal")
	_monitor(Vector3(-5.55,1.39,-5.46),-1.0,"blue")
	_monitor(Vector3(4.35,1.39,6.5),1.0,"signal")
	_keyboard(Vector3(-5.08,1.10,2.81))
	_keyboard(Vector3(5.8,1.10,-5.72))
	_keyboard(Vector3(-5.55,1.10,-5.72))
	_keyboard(Vector3(4.4,1.10,6.76))
	_chair(Vector3(5,0,-6.65),1.0,true)
	_chair(Vector3(-5,0,-6.65),1.0)
	_paperwork(Vector3(4.22,1.10,-5.26),.13)
	_paperwork(Vector3(-4.1,1.10,-5.51),-.09)
	_paperwork(Vector3(6.15,1.10,6.5),.05)
	# Cable raceway along west wall, not across walking lanes.
	_part("interior","steel",Vector3(-8.30,.32,1.0),Vector3(.09,.15,4.0))

func _lobby() -> void:
	# Physical gate is unchanged; stainless skin and recessed reader details.
	for side in [-1.0,1.0]:
		_part("gate","steel",Vector3(side*.65,1.36,-7.81),Vector3(1.24,2.62,.035))
		_part("gate","black",Vector3(side*.65,1.65,-7.835),Vector3(.90,.72,.025))
		_part("gate","glass",Vector3(side*.65,1.65,-7.854),Vector3(.84,.66,.015))
		_part("interior","trim",Vector3(side*1.55,1.10,-8.1),Vector3(.26,.045,.28))
		_part("reader","red",Vector3(side*1.55,1.197,-8.1),Vector3(.11,.012,.13))
	_part("reader","red",Vector3(0,2.92,-7.80),Vector3(.37,.04,.035))
	# Public entry threshold and tactile mat edge: flat and non-obstructive.
	_part("interior","trim",Vector3(0,.008,-9.96),Vector3(2.54,.012,.22))
	# Flush CCTV mounting plate and cylindrical lens, no surveillance simulation.
	for x in [-7.8,7.8]:
		_part("interior","steel",Vector3(x,3.24,-8.0),Vector3(.26,.09,.23))
		_part("interior","porcelain",Vector3(x,3.09,-8.0),Vector3(.20,.22,.20),0.0,"cyl")
		_part("interior","black",Vector3(x,2.965,-8.0),Vector3(.11,.045,.11),0.0,"cyl")

## Existing reader indicators are a separate batch so authorization changes only their material.
func set_reader_authorized(authorized: bool) -> void:
	var indicators := get_node_or_null("reader_red_box") as MultiMeshInstance3D
	if is_instance_valid(indicators):
		indicators.material_override = _material("signal" if authorized else "red")

## Provisional sliding motion for existing skins; authored leaves can replace this adapter.
func set_gate_fraction(fraction: float) -> void:
	var amount := clampf(fraction,0.0,1.0)
	for id in _gate_rest:
		var batch := get_node_or_null(NodePath(str(id))) as MultiMeshInstance3D
		if not is_instance_valid(batch):
			continue
		var rest: Array = _gate_rest[id]
		for i in range(rest.size()):
			var pose: Transform3D = rest[i]
			pose.origin.x += signf(pose.origin.x)*1.30*amount
			batch.multimesh.set_instance_transform(i,pose)
		batch.visible = amount < 0.999
