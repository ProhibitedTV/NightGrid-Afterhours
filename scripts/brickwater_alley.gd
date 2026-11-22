extends Node3D
## Fixed first service-alley vertical slice, at the existing two-building parcel.
const PILOT_BLOCK = Vector2i(-2,1)
const Maps = preload("res://scripts/material_library.gd")
const CABINET = preload("res://assets/models/polyhaven/utility_box_01/utility_box_01.gltf")
const TRASH = preload("res://assets/models/polyhaven/metal_trash_can/metal_trash_can.gltf")
const HVAC = preload("res://assets/models/polyhaven/exterior_aircon_unit/exterior_aircon_unit.gltf")
const GRIME = preload("res://assets/models/nightgrid/brickwater_alley/alley_weathering.svg")
const NOTICE = preload("res://assets/models/nightgrid/brickwater_alley/waste_notice.svg")
const WallArt = preload("res://scripts/brickwater_wall_art.gd")
const PBR = "res://assets/pbr/polyhaven/"
const FLOOR_Y = 0.14
const FOUNDATION_Y = -0.08
const START_Z = -12.0
const END_Z = 8.0
var left_wall := -2.65
var right_wall := 2.65
static var _metal: StandardMaterial3D
static var _lid: StandardMaterial3D
static var _grime_material: StandardMaterial3D
static var _notice_material: StandardMaterial3D
static var _dumpster_mesh: ArrayMesh
static var _lid_mesh: ArrayMesh
var _floor: StaticBody3D

func configure(left:float,right:float)->void:
	left_wall=left
	right_wall=right

func _ready()->void:
	assert(right_wall-left_wall>=4.0)
	_build_floor()
	_build_dumpster()
	_build_services()
	_install_reused_props()
	var wall_art := WallArt.new()
	wall_art.name = "BrickwaterWallArt"
	add_child(wall_art)
	wall_art.install(left_wall, right_wall)

func _view(parent:Node3D, label:String, mesh:Mesh, at:Vector3, material:Material)->MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	node.position=at
	node.material_override=material
	parent.add_child(node)
	return node

func _photo_metal(tint:Color)->StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_texture=load(PBR+"blue_metal_plate_diffuse_2k.jpg")
	m.normal_texture=load(PBR+"blue_metal_plate_nor_gl_2k.png")
	m.roughness_texture=load(PBR+"blue_metal_plate_rough_2k.png")
	m.normal_enabled=true
	m.normal_scale=0.65
	m.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic=0.58
	m.roughness=1.0
	m.albedo_color=tint
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _plate(parent:Node3D,label:String,at:Vector3,size:Vector3,material:Material)->MeshInstance3D:
	var mesh:=BoxMesh.new()
	mesh.size=size
	return _view(parent,label,mesh,at,material)

func _floor_segment(z0:float,z1:float,y0:float,y1:float,lo:float,hi:float)->void:
	var points:=PackedVector3Array()
	for x in [lo,hi]:
		points.append(Vector3(x,y0,z0))
		points.append(Vector3(x,y1,z1))
		points.append(Vector3(x,-0.18,z0))
		points.append(Vector3(x,-0.18,z1))
	var shape:=ConvexPolygonShape3D.new()
	shape.points=points
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	_floor.add_child(collider)

func _build_floor()->void:
	# Match the global sidewalk top instead of the old raised visual-only strip.
	# One-metre approach slopes meet the real foundation; no tall vertical ledge.
	var lo:=left_wall+0.04
	var hi:=right_wall-0.04
	_floor=StaticBody3D.new()
	_floor.name="AlleyWalkableFloor"
	add_child(_floor)
	_floor_segment(START_Z,END_Z,FLOOR_Y,FLOOR_Y,lo,hi)
	_floor_segment(START_Z-1.0,START_Z,FOUNDATION_Y,FLOOR_Y,lo,hi)
	_floor_segment(END_Z,END_Z+1.0,FLOOR_Y,FOUNDATION_Y,lo,hi)
	var mesh:=PlaneMesh.new()
	mesh.size=Vector2(hi-lo,END_Z-START_Z)
	var center:=Vector3((lo+hi)*0.5,FLOOR_Y+0.002,(START_Z+END_Z)*0.5)
	_view(self,"PhotographicAlleyPavement",mesh,center,Maps.surface("PHOTO_SIDEWALK",Color("797870")))
	if _grime_material==null:
		_grime_material=StandardMaterial3D.new()
		_grime_material.albedo_texture=GRIME
		_grime_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		_grime_material.roughness=0.76
		_grime_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var stain:=_view(self,"AuthoredWeatheringAtlas",mesh,center+Vector3.UP*0.003,_grime_material)
	stain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _ring(x:float,z:float,y:float,bevel:float)->PackedVector3Array:
	return PackedVector3Array([Vector3(-x+bevel,y,-z),Vector3(x-bevel,y,-z),
		Vector3(x,y,-z+bevel),Vector3(x,y,z-bevel),Vector3(x-bevel,y,z),
		Vector3(-x+bevel,y,z),Vector3(-x,y,z-bevel),Vector3(-x,y,-z+bevel)])

static func _quad(t:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	for item in [[a,Vector2(0,0)],[b,Vector2(1,0)],[c,Vector2(1,1)],[a,Vector2(0,0)],[c,Vector2(1,1)],[d,Vector2(0,1)]]:
		t.set_uv(item[1])
		t.add_vertex(item[0])

static func _loft(rings:Array[PackedVector3Array])->ArrayMesh:
	var t:=SurfaceTool.new()
	t.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ri in range(rings.size()-1):
		for i in range(8):
			var j:=(i+1)%8
			_quad(t,rings[ri][i],rings[ri][j],rings[ri+1][j],rings[ri+1][i])
	# Clockwise outward cap at top, inverse at bottom.
	for i in range(1,7):
		for item in [[rings[-1][0],Vector2(0,0)],[rings[-1][i],Vector2(1,0)],[rings[-1][i+1],Vector2(1,1)],
			[rings[0][0],Vector2(0,0)],[rings[0][i+1],Vector2(1,1)],[rings[0][i],Vector2(1,0)]]:
			t.set_uv(item[1])
			t.add_vertex(item[0])
	t.generate_normals()
	t.generate_tangents()
	return t.commit()

func _build_dumpster()->void:
	if _metal==null:
		_metal=_photo_metal(Color("82938a"))
		_lid=_photo_metal(Color("414b50"))
		_notice_material=StandardMaterial3D.new()
		_notice_material.albedo_texture=NOTICE
		_notice_material.roughness=0.86
	var rings:Array[PackedVector3Array]=[_ring(0.56,0.97,0.07,0.08),_ring(0.67,1.10,0.28,0.10),_ring(0.70,1.14,1.18,0.10)]
	var cap:Array[PackedVector3Array]=[_ring(0.71,1.15,1.18,0.10),_ring(0.71,1.15,1.25,0.10),_ring(0.65,1.09,1.35,0.10)]
	if _dumpster_mesh==null:
		_dumpster_mesh=_loft(rings)
		_lid_mesh=_loft(cap)
	# Park against one wall rather than across the entire alley.
	var body:=StaticBody3D.new()
	body.name="ClosedSteelDumpster"
	body.position=Vector3(left_wall+0.79,FLOOR_Y,5.8)
	add_child(body)
	_view(body,"BeveledSteelBody",_dumpster_mesh,Vector3.ZERO,_metal)
	_view(body,"ClosedLid",_lid_mesh,Vector3.ZERO,_lid)
	for hull in [rings,cap]:
		var vertices:=PackedVector3Array()
		for ring in hull:
			vertices.append_array(ring)
		var shape:=ConvexPolygonShape3D.new()
		shape.points=vertices
		var collider:=CollisionShape3D.new()
		collider.shape=shape
		body.add_child(collider)
	for z in [-0.78,0.0,0.78]:
		_plate(body,"PressedSteelRib",Vector3(0.695,0.72,z),Vector3(0.055,0.77,0.075),_metal)
	for z in [-0.85,0.85]:
		for x in [-0.46,0.46]:
			var wheel:=CylinderMesh.new()
			wheel.top_radius=0.105
			wheel.bottom_radius=0.105
			wheel.height=0.105
			wheel.radial_segments=16
			wheel.rings=1
			var v:=_view(body,"Caster",wheel,Vector3(x,0.11,z),_lid)
			v.rotation.z=PI*0.5
	var sign_mesh:=QuadMesh.new()
	sign_mesh.size=Vector2(0.52,0.25)
	var sign:=_view(body,"MountedWasteNotice",sign_mesh,Vector3(0.708,0.80,-0.38),_notice_material)
	sign.rotation.y=PI*0.5

func _collect(node:Node,meshes:Array[MeshInstance3D])->void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect(child,meshes)

func _build_services()->void:
	# High wall-mounted equipment leaves a 2.9m pedestrian head clearance.
	var source:=HVAC.instantiate() as Node3D
	source.name="ScannedWallHVAC"
	add_child(source)
	var meshes:Array[MeshInstance3D]=[]
	_collect(source,meshes)
	for i in range(meshes.size()):
		meshes[i].visible=i==1
		meshes[i].position=Vector3.ZERO
	source.scale=Vector3.ONE*0.85
	source.rotation.y=PI*0.5
	source.position=Vector3(left_wall+0.30,3.9,-6.0)
	# Conduit runs along the actual wall. Round pipe cross-sections, flanged
	# brackets and a wall-mounted cabinet preserve an uncluttered ground path.
	for z in [-7.0,1.0]:
		var pipe:=CylinderMesh.new()
		pipe.top_radius=0.065
		pipe.bottom_radius=0.065
		pipe.height=3.1
		pipe.radial_segments=16
		pipe.rings=1
		_view(self,"WallConduit",pipe,Vector3(right_wall-0.09,2.1,z),_metal)
		for y in [0.85,2.2,3.35]:
			_plate(self,"ConduitBracket",Vector3(right_wall-0.08,y,z),Vector3(0.16,0.09,0.19),_lid)
	var run:=CylinderMesh.new()
	run.top_radius=0.055
	run.bottom_radius=0.055
	run.height=8.0
	run.radial_segments=16
	run.rings=1
	var horizontal:=_view(self,"OverheadServiceConduit",run,Vector3(right_wall-0.09,3.62,-3.0),_metal)
	horizontal.rotation.x=PI*0.5
	# Shared photo steel for a grounded drain cover, nearly flush to pavement.
	var drain:=_plate(self,"FlushDrainCover",Vector3(right_wall-0.28,FLOOR_Y+0.008,-3.0),Vector3(0.32,0.015,0.72),_lid)
	drain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(7):
		_plate(self,"DrainSlot",Vector3(right_wall-0.28,FLOOR_Y+0.017,-3.27+float(i)*0.09),Vector3(0.25,0.005,0.035),_lid)

func _install_reused_props()->void:
	# Reuse the exact imported resources from Central Exchange. No second
	# copy of their glTF, buffers or textures. Place at opposite-wall sites
	# clear of the dumpster and conduit risers.
	_place_scan("ReusedPowerCabinet",CABINET,Vector3(right_wall-0.24,FLOOR_Y,-9.8),-PI*0.5,false)
	_place_scan("ReusedRustedWasteCan",TRASH,Vector3(right_wall-0.46,FLOOR_Y,1.9),PI*0.5,true)

func _place_scan(label:String,source:PackedScene,at:Vector3,yaw:float,trash:bool)->void:
	var body:=StaticBody3D.new()
	body.name=label
	body.position=at
	body.rotation.y=yaw
	add_child(body)
	var imported:=source.instantiate() as Node3D
	body.add_child(imported)
	var meshes:Array[MeshInstance3D]=[]
	_collect(imported,meshes)
	assert(meshes.size()==(8 if trash else 1))
	for mesh in meshes:
		if trash:
			var rust:=str(mesh.name).to_lower().contains("rust")
			mesh.visible=rust
			mesh.position.x+=0.5 if rust else -0.5
	var collider:=CollisionShape3D.new()
	collider.name="MeasuredScanCollider"
	var shape:=BoxShape3D.new()
	# Measured upstream bounds, copied by resource rather than asset bytes;
	# trash body covers the reachable barrel, cabinet body covers the shell.
	shape.size=Vector3(0.61,0.90,0.55) if trash else Vector3(0.52,1.12,0.43)
	collider.shape=shape
	collider.position.y=shape.size.y*0.5
	if not trash:
		collider.position.z=0.006
	body.add_child(collider)
