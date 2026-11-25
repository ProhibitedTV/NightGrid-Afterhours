extends RefCounted
## A single original takeaway bag. Lightweight shared resources, no physics.
static var _mesh_cache: Dictionary = {}
static var _materials: Dictionary = {}
static func _material(key: String, color: Color, roughness: float) -> StandardMaterial3D:
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		_materials[key] = mat
	return _materials[key]

static func _part(root: Node3D, id: String, size: Vector3, at: Vector3, mat: Material) -> void:
	if not _mesh_cache.has(id):
		var mesh := BoxMesh.new()
		mesh.size = size
		_mesh_cache[id] = mesh
	var part := MeshInstance3D.new()
	part.name = id
	part.mesh = _mesh_cache[id]
	part.material_override = mat
	part.position = at
	root.add_child(part)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "QuotaDropBag"
	var paper := _material("paper",Color("b9a17c"),.94)
	var fold := _material("fold",Color("8e7659"),.94)
	var strap := _material("strap",Color("77634c"),.85)
	var sticker := _material("sticker",Color("e5d9b5"),.78)
	# Bag hangs below the handle. Folded top, reinforced seams and a tamper seal.
	_part(root,"BagBody",Vector3(.17,.23,.12),Vector3(0,-.18,0),paper)
	_part(root,"FoldedTop",Vector3(.17,.025,.12),Vector3(0,-.057,0),fold)
	_part(root,"BaseFold",Vector3(.17,.025,.12),Vector3(0,-.287,0),fold)
	_part(root,"HandleLeft",Vector3(.012,.065,.012),Vector3(-.041,-.013,0),strap)
	_part(root,"HandleRight",Vector3(.012,.065,.012),Vector3(.041,-.013,0),strap)
	_part(root,"HandleGrip",Vector3(.094,.014,.014),Vector3(0,.02,0),strap)
	_part(root,"Seal",Vector3(.053,.041,.003),Vector3(0,-.077,.0615),sticker)
	var label := Label3D.new()
	label.name = "OriginalQuotaDropMark"
	label.text = "QUOTA\nDROP"
	label.font_size = 32
	label.pixel_size = .0018
	label.outline_size = 0
	label.modulate = Color("29433e")
	label.position = Vector3(0,-.17,.0618)
	root.add_child(label)
	return root
