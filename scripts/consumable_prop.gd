extends RefCounted
## Shared, original physical items; only the active courier owns a prop node.
const Catalog = preload("res://scripts/consumables.gd")
const TINTS = {"water":Color("7be0ee"),"soda":Color("fa5478"),"energy":Color("b89aff"),"protein":Color("ffb767"),"sandwich":Color("b7f19e")}
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static func is_drink(id: String) -> bool:
	return id in ["water","soda","energy"]
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "HeldConsumable"
	var drink := is_drink(id)
	var tint: Color = TINTS.get(id,Color.WHITE)
	var metal := _material("metal",Color("9ba8ac"),.7)
	var body_mat := _material(id,tint,.18)
	if drink:
		_part(root,"can",Vector3.ZERO,_cylinder("can",.033,.030,.112),body_mat)
		_part(root,"rim",Vector3(0,.057,0),_cylinder("rim",.033,.033,.005),metal)
		_part(root,"base",Vector3(0,-.057,0),_cylinder("rim",.033,.033,.005),metal)
		_part(root,"tab",Vector3(0,.062,-.004),_box("tab",Vector3(.014,.004,.024)),metal)
	else:
		var size := Vector3(.076,.035,.12) if id=="protein" else Vector3(.102,.052,.105)
		_part(root,id,Vector3.ZERO,_box(id,size),body_mat)
		_part(root,id+"seal",Vector3(0,0,size.z*.48),_box(id+"seal",Vector3(size.x,.012,.012)),metal)
	var label := MeshInstance3D.new()
	label.mesh = _quad("label_drink" if drink else "label_food",Vector2(.058,.085) if drink else Vector2(.085,.085))
	label.material_override = _label_material(id)
	label.position = Vector3(0,0,.034) if drink else Vector3(0,.028,0)
	if not drink:
		label.rotation.x = -PI*.5
	root.add_child(label)
	return root
static func _material(id: String,tint: Color,metallic: float) -> StandardMaterial3D:
	if not _materials.has(id):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.metallic = metallic
		mat.roughness = .42
		_materials[id] = mat
	return _materials[id]
static func _label_material(id: String) -> StandardMaterial3D:
	var key := "label_"+id
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = Catalog.PRODUCT_ICONS[id]
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = .4
		mat.roughness = .45
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = mat
	return _materials[key]
static func _cylinder(id: String,top: float,bottom: float,height: float) -> CylinderMesh:
	if not _meshes.has(id):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top
		mesh.bottom_radius = bottom
		mesh.height = height
		mesh.radial_segments = 16
		mesh.rings = 1
		_meshes[id] = mesh
	return _meshes[id]
static func _box(id: String,size: Vector3) -> BoxMesh:
	if not _meshes.has(id):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[id] = mesh
	return _meshes[id]
static func _quad(id: String,size: Vector2) -> QuadMesh:
	if not _meshes.has(id):
		var mesh := QuadMesh.new()
		mesh.size = size
		_meshes[id] = mesh
	return _meshes[id]
static func _part(parent: Node3D,id: String,at: Vector3,mesh: Mesh,material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = id
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	parent.add_child(visual)
