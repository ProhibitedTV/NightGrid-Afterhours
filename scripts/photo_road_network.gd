extends Node3D
## Permanent replacement of visual street strips with two UV-authored
## meshes sharing the existing licensed Poly Haven bitumen photo maps.
## No collisions, runtime fetches, lights, animated effects or per-frame work.
const Plan = preload("res://scripts/world_plan.gd")
const ROOT = "res:" + "//assets/pbr/polyhaven/bitumen_"
const HALF = 7.0
const EDGE = 245.0
const Y = 0.008
const TILE_METRES = 3.5
const SHOULDER = 5.70
const CROSSING_CLEARANCE = 14.15
var _dry: Array[Rect2] = []
var _damp: Array[Rect2] = []

func _ready() -> void:
	var albedo := load(ROOT+"diffuse_2k.jpg") as Texture2D
	var normal := load(ROOT+"nor_gl_2k.png") as Texture2D
	var rough := load(ROOT+"rough_2k.png") as Texture2D
	if albedo==null or normal==null or rough==null:
		push_error("Photo road network requires the bundled CC0 bitumen scan")
		return
	var radius: int = Plan.GRID_RADIUS
	var step: float = Plan.BLOCK_SIZE
	# Tile the road union without overlapping perpendicular asphalt strips.
	for x in range(-radius,radius+1):
		for z in range(-radius,radius+1):
			_rect(_dry,x*step-HALF,x*step+HALF,z*step-HALF,z*step+HALF)
	for index in range(-radius,radius+1):
		var axis := index*step
		for along in range(-radius,radius):
			var low := along*step
			var high := low+step
			_segment(axis,low,high,false)
			_segment(axis,low,high,true)
		for horizontal in [false,true]:
			_strip(_dry,axis,-EDGE,-radius*step-HALF,-HALF,HALF,horizontal)
			_strip(_dry,axis,radius*step+HALF,EDGE,-HALF,HALF,horizontal)
	_build("DryPhotographicAsphalt",_dry,_material(albedo,normal,rough,false))
	_build("DampPhotographicGutters",_damp,_material(albedo,normal,rough,true))

func _rect(target: Array[Rect2],x0:float,x1:float,z0:float,z1:float) -> void:
	target.append(Rect2(x0,z0,x1-x0,z1-z0))

func _strip(target:Array[Rect2],axis:float,lo:float,hi:float,side0:float,side1:float,horizontal:bool) -> void:
	if horizontal:
		_rect(target,lo,hi,axis+side0,axis+side1)
	else:
		_rect(target,axis+side0,axis+side1,lo,hi)

func _segment(axis:float,lo:float,hi:float,horizontal:bool) -> void:
	var first := lo+CROSSING_CLEARANCE
	var last := hi-CROSSING_CLEARANCE
	_strip(_dry,axis,lo+HALF,first,-HALF,HALF,horizontal)
	_strip(_dry,axis,last,hi-HALF,-HALF,HALF,horizontal)
	_strip(_dry,axis,first,last,-SHOULDER,SHOULDER,horizontal)
	_strip(_damp,axis,first,last,-HALF,-SHOULDER,horizontal)
	_strip(_damp,axis,first,last,SHOULDER,HALF,horizontal)

func _material(albedo:Texture2D,normal:Texture2D,rough:Texture2D,damp:bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo
	m.albedo_color = Color("777f87") if damp else Color("91959a")
	m.normal_enabled = true
	m.normal_texture = normal
	m.normal_scale = 0.55 if damp else 0.75
	m.roughness_texture = rough
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 0.63 if damp else 1.0
	m.metallic = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _build(label:String,rects:Array[Rect2],material:StandardMaterial3D) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var tangents := PackedFloat32Array()
	for rect in rects:
		var a := Vector3(rect.position.x,Y,rect.position.y)
		var b := Vector3(rect.end.x,Y,rect.position.y)
		var c := Vector3(rect.end.x,Y,rect.end.y)
		var d := Vector3(rect.position.x,Y,rect.end.y)
		for p in [a,c,b,a,d,c]:
			vertices.append(p)
			normals.append(Vector3.UP)
			uv.append(Vector2(p.x,p.z)/TILE_METRES)
			tangents.append_array(PackedFloat32Array([1.0,0.0,0.0,-1.0]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func rectangles() -> Array[Rect2]:
	var all := _dry.duplicate()
	all.append_array(_damp)
	return all
