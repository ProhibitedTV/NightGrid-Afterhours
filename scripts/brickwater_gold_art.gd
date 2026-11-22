extends Node3D
## Hand-placed, source-mesh-only art layer. Each kit is a library, not a scene.
const FACADE = preload("res://assets/models/polyhaven/modular_urban_apartments_facade/modular_urban_apartments_facade.gltf")
const SCONCE = preload("res://assets/models/polyhaven/industrial_caged_sconce/industrial_caged_sconce.gltf")
const PIPES = preload("res://assets/models/polyhaven/modular_pipes/modular_pipes.gltf")
const CABLES = preload("res://assets/models/polyhaven/modular_electric_cables/modular_electric_cables.gltf")
const BAG = preload("res://assets/models/polyhaven/trashbag/trashbag.gltf")
const BOX = preload("res://assets/models/polyhaven/cardboard_box_01/cardboard_box_01.gltf")
const CRATE = preload("res://assets/models/polyhaven/plastic_crate_01/plastic_crate_01.gltf")
const TRUCK = preload("res://assets/models/polyhaven/hand_truck/hand_truck.gltf")
static var _meshes: Dictionary = {}
var left: float
var right: float
var floor_y: float

static func _source(scene: PackedScene, member: String) -> Mesh:
	var key := scene.resource_path + ":" + member
	if _meshes.has(key):
		return _meshes[key]
	var root := scene.instantiate()
	var node: MeshInstance3D
	if root is MeshInstance3D and str(root.name) == member:
		node = root
	else:
		node = root.find_child(member,true,false) as MeshInstance3D
	# The four single-object glTF imports may be wrapped by an importer-
	# generated root. Only permit this fallback for known one-mesh assets.
	if node == null and scene in [BAG,BOX,CRATE,TRUCK]:
		var candidates := root.find_children("*","MeshInstance3D",true,false)
		if root is MeshInstance3D:
			candidates.append(root)
		if candidates.size() == 1:
			node = candidates[0] as MeshInstance3D
	assert(node != null and node.mesh != null, "Missing exact authored kit member: " + key)
	if node == null:
		root.free()
		return null
	var mesh := node.mesh
	_meshes[key] = mesh
	root.free()
	return mesh

func _view(label: String, mesh: Mesh, at: Vector3, rotation_basis: Basis, scale_factor: Vector3, anchor: Vector3, solid: bool) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = label
	body.position = at
	body.basis = rotation_basis
	add_child(body)
	var visual := MeshInstance3D.new()
	visual.name = "AuthoredMesh"
	visual.mesh = mesh
	visual.scale = scale_factor
	visual.position = -anchor * scale_factor
	body.add_child(visual)
	body.set_meta("source_mesh",mesh.resource_name)
	if solid:
		var bounds := mesh.get_aabb()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bounds.size * scale_factor
		collider.shape = shape
		collider.position = (bounds.get_center()-anchor)*scale_factor
		body.add_child(collider)
	return body

func _wall(label: String, scene: PackedScene, member: String, side: int, y: float, z: float, factor: float = 1.0, solid: bool = false) -> Node3D:
	# Local +Z faces passage; rear-most source surface sits against wall.
	# Preserve UVs, imported materials and exact source mesh. Never include the
	# other scattered variants from the publisher display scene.
	var mesh := _source(scene,member)
	var bounds := mesh.get_aabb()
	var anchor := Vector3(bounds.get_center().x,bounds.position.y,bounds.position.z)
	var yaw := PI*0.5 if side == -1 else -PI*0.5
	var wall_x := left if side == -1 else right
	return _view(label,mesh,Vector3(wall_x-side*0.006,y,z),Basis(Vector3.UP,yaw),Vector3.ONE*factor,anchor,solid)

func _ground(label: String, scene: PackedScene, member: String, side: int, z: float, yaw: float, factor: float = 1.0) -> Node3D:
	var mesh := _source(scene,member)
	var b := mesh.get_aabb()
	var anchor := Vector3(b.get_center().x,b.position.y,b.get_center().z)
	# Conservative wall setback using rotated horizontal bounding radius;
	# bottom sits exactly on the physical pavement regardless of source pivot.
	var setback := Vector2(b.size.x,b.size.z).length()*factor*0.5 + 0.06
	var x := left+setback if side == -1 else right-setback
	return _view(label,mesh,Vector3(x,floor_y,z),Basis(Vector3.UP,yaw),Vector3.ONE*factor,anchor,true)

func install(left_wall: float, right_wall: float, y: float) -> void:
	left = left_wall
	right = right_wall
	floor_y = y
	# Real wall-mounted caged fixtures, warm pools rather than unmotivated neon.
	for spec in [[-1,-8.6],[1,3.25]]:
		var side: int = spec[0]
		var z: float = spec[1]
		var fixture := _wall("CagedFixture_%s"%str(side),SCONCE,"industrial_caged_sconce_a",side,2.65,z,1.15)
		var light := OmniLight3D.new()
		light.name = "PracticalAmber"
		light.position = Vector3(0.0,0.22,0.29)
		light.light_color = Color("ffd3a1")
		light.light_energy = 1.6
		light.omni_range = 5.0
		light.omni_attenuation = 1.6
		light.shadow_enabled = true
		fixture.add_child(light)
	# Actual wet-service riser: original metal kit segments and flanged support.
	var pipe_x := right-0.13
	for i in range(2):
		var mesh := _source(PIPES,"pipe_200cm_metal")
		_view("DrainRiser%d"%i,mesh,Vector3(pipe_x,0.25+2.0*i,-5.0),Basis.IDENTITY,Vector3.ONE,Vector3.ZERO,true)
	for i in range(3):
		_wall("PipeClamp%d"%i,PIPES,"pipe_support_crossover_metal",1,0.55+1.4*i,-5.0)
	# Short cable runs in the utility zone; source cable axes are +Y and
	# wall-normal +X. Rotate into the east wall; no layout-sheet transform.
	var cable := _source(CABLES,"cable_straight_long")
	for i in range(5):
		_view("ElectricalRun%d"%i,cable,Vector3(left+0.007,1.65+0.60*i,-4.5),Basis.IDENTITY,Vector3.ONE,Vector3.ZERO,false)
	# Group street waste and deliveries by use, not evenly spaced decoration.
	_ground("WasteBagA",BAG,"trashbag",-1,7.35,0.4,1.0)
	_ground("WasteBagB",BAG,"trashbag",-1,7.70,-0.8,0.85)
	_ground("DeliveryCart",TRUCK,"hand_truck",1,-11.25,-PI*0.5)
	_ground("FoldedCarton",BOX,"cardboard_box_01",1,-10.55,0.3,1.15)
	_ground("ProduceCrate",CRATE,"plastic_crate_01",1,-7.9,0.18,1.25)
	_ground("SpareCrate",CRATE,"plastic_crate_01",1,-7.35,-0.12,1.0)

func set_night_factor(value: float) -> void:
	var night := smoothstep(0.35,0.85,clampf(value,0.0,1.0))
	for child in get_children():
		var lamp := child.get_node_or_null("PracticalAmber") as OmniLight3D
		if lamp != null:
			lamp.light_energy=1.6*night
			lamp.visible=night>0.001
