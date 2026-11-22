extends Node3D
## Actual cut-out authored facade modules, matching recessed window assemblies,
## and a sealed architectural envelope. No rendered whole-volume box.
const Gold = preload("res://scripts/brickwater_gold_art.gd")
const Masonry = preload("res://scripts/photo_masonry.gd")
const Maps = preload("res://scripts/material_library.gd")
const MODULE = 3.0
const MAX_DETAILED_STOREYS = 4
const RECESS_BACK = 0.36
static var _lit_meshes: Dictionary = {}
static var _lit_materials: Array[StandardMaterial3D] = []
static var _night := 0.0
var _groups: Dictionary = {}
var _wall_material: Material

func _quad(label: String, at: Vector3, size_m: Vector2, yaw: float, material: Material, pitch: float = 0.0) -> void:
	if size_m.x < 0.001 or size_m.y < 0.001:
		return
	var mesh := QuadMesh.new()
	mesh.size = size_m
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = mesh
	view.material_override = material
	view.position = at
	view.rotation = Vector3(pitch,yaw,0)
	add_child(view)

func _module(member: String, at: Vector3, yaw: float) -> void:
	if not _groups.has(member):
		_groups[member] = []
	var transforms: Array = _groups[member]
	transforms.append(Transform3D(Basis(Vector3.UP,yaw),at))

static func set_night_factor(value: float) -> void:
	_night=smoothstep(0.35,0.85,clampf(value,0.0,1.0))
	for material in _lit_materials:
		material.emission_energy_multiplier=0.85*_night

static func _window_mesh(member: String) -> Mesh:
	if not member.ends_with("_lit"):
		return Gold._source(Gold.FACADE,member)
	if _lit_meshes.has(member):
		return _lit_meshes[member]
	var original := Gold._source(Gold.FACADE,member.trim_suffix("_lit"))
	var copy := original.duplicate() as Mesh
	for index in range(copy.get_surface_count()):
		var original_mat := copy.surface_get_material(index) as StandardMaterial3D
		if original_mat == null or not original_mat.resource_name.to_lower().contains("glass"):
			continue
		var warm := original_mat.duplicate() as StandardMaterial3D
		warm.emission_enabled=true
		warm.emission=Color("f9c389")
		warm.emission_energy_multiplier=0.85*_night
		copy.surface_set_material(index,warm)
		_lit_materials.append(warm)
	_lit_meshes[member]=copy
	return copy

func _flush() -> void:
	for member in _groups:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _window_mesh(member)
		var transforms: Array = _groups[member]
		batch.instance_count = transforms.size()
		for i in range(transforms.size()):
			batch.set_instance_transform(i,transforms[i])
		var renderer := MultiMeshInstance3D.new()
		renderer.name = member
		renderer.multimesh = batch
		add_child(renderer)
	_groups.clear()

func install(width: float, height: float, depth: float, which: int, tint: Color) -> void:
	# Local origin at ground centre of saved parcel, y already +0.15.
	_wall_material = Masonry.surface(tint)
	var half_w := width*0.5
	var half_d := depth*0.5
	var inward := 1.0 if which==0 else -1.0
	var yaw := inward*PI*0.5
	var face_x := inward*half_w
	# Five exposed outer faces, with no old opaque sixth face behind windows.
	_quad("FrontMasonry",Vector3(0,height*0.5,-half_d),Vector2(width,height),PI,_wall_material)
	_quad("RearMasonry",Vector3(0,height*0.5,half_d),Vector2(width,height),0,_wall_material)
	_quad("OuterMasonry",Vector3(-face_x,height*0.5,0),Vector2(depth,height),-yaw,_wall_material)
	_quad("Roof",Vector3(0,height,0),Vector2(width,depth),0,Maps.surface("PHOTO_SIDEWALK",Color("777774")),-PI*0.5)
	_quad("GroundMasonry",Vector3(face_x,1.5,0),Vector2(depth,3.0),yaw,_wall_material)
	var bays := floori(depth/MODULE)
	var rows := mini(MAX_DETAILED_STOREYS, floori((height-MODULE)/MODULE))
	var covered := float(bays)*MODULE
	var remaining := (depth-covered)*0.5
	var decorated_height := float(rows)*MODULE
	# The paired glTF modules share the exact source origin: x -3..0,
	# y 0..3, wall at z=0, reveals at z=-.18, glazing behind its frame.
	# Retain both source meshes in their original alignment, not an overlay.
	for row in range(rows):
		for bay in range(bays):
			var z := -covered*0.5+(float(bay)+0.5)*MODULE
			var origin := Vector3(face_x,float(row+1)*MODULE,z) + Basis(Vector3.UP,yaw)*Vector3(1.5,0,0)
			var variant := "large" if which==0 else "double"
			if (bay+row*2+which)%4==0:
				variant = "small"
			_module("wall_window_centered_%s_03"%variant,origin,yaw)
			# Stable occupancy pattern: only some apartments glow, no random flicker.
			var occupied := (bay*7+row*3+which*2)%9 in [1,4,7]
			_module("window_centered_%s_03"%variant+("_lit" if occupied else ""),origin,yaw)
	# End strips and upper band close the envelope; a dark continuous backing
	# sits behind the imported reveals, never at the front plane.
	for edge in [-1.0,1.0]:
		_quad("EndMasonry",Vector3(face_x,MODULE+decorated_height*0.5,edge*(covered*0.5+remaining*0.5)),Vector2(remaining,decorated_height),yaw,_wall_material)
	var upper := height-MODULE-decorated_height
	_quad("UpperMasonry",Vector3(face_x,MODULE+decorated_height+upper*0.5,0),Vector2(depth,upper),yaw,_wall_material)
	_quad("RecessBacking",Vector3(face_x-inward*RECESS_BACK,MODULE+decorated_height*0.5,0),Vector2(depth,decorated_height),yaw,Maps.surface("CONCRETE",Color("252a2c")))
	_flush()
	set_meta("window_bays",bays*rows)
	set_meta("recess_depth",RECESS_BACK)
	set_meta("saved_width",width)
	set_meta("saved_depth",depth)
	set_meta("saved_height",height)
