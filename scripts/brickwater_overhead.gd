extends Node3D
## One measured wall-mounted escape and two utility spans in the fixed alley.
## The escape is NOT yet a player-climbable traversal mechanic.
const Gold = preload("res://scripts/brickwater_gold_art.gd")
const FIRE = preload("res://assets/models/polyhaven/modular_fire_escape/modular_fire_escape.gltf")
const SEGMENTS = 24
const SIDES = 8
const DECK_Y = 6.65
const STOREY = 3.0
const END_Y = 5.82
const SAG = 0.72
var _left: float
var _right: float
var _cable_material: StandardMaterial3D

func install(left: float, right: float) -> void:
	_left=left
	_right=right
	_install_escape()
	_cable_material=StandardMaterial3D.new()
	_cable_material.albedo_color=Color("242727")
	_cable_material.roughness=0.82
	_cable_material.metallic=0.0
	for z in [-9.0,1.5]:
		_install_span(z)

func _piece(parent: Node3D, label: String, member: String, at: Vector3, scale_factor: Vector3 = Vector3.ONE) -> void:
	var source := Gold._source(FIRE,member)
	var view := MeshInstance3D.new()
	view.name=label
	view.mesh=source
	view.position=at
	view.scale=scale_factor
	parent.add_child(view)
	# Exact collision triangles for elevated fixed steel, not an opaque
	# AABB that would fill the alley or the open staircase with invisible wall.
	var body := StaticBody3D.new()
	body.name="SteelCollision"
	view.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape=source.create_trimesh_shape()
	body.add_child(shape)

func _install_escape() -> void:
	var escape := Node3D.new()
	escape.name="WestServiceFireEscape"
	# Source rear edge (-Z) features the downturned supports. Its +Z
	# outer edge faces into the alley after turning 90 degrees.
	escape.position=Vector3(_left+0.85,DECK_Y,-1.5)
	escape.rotation.y=PI*0.5
	add_child(escape)
	for level in range(2):
		var y := float(level)*STOREY
		_piece(escape,"Landing%d"%level,"modular_fire_escape_platform_middle",Vector3(0,y,0))
		# Rail foot at -.635 aligns with deck top +.072; outer rail
		# edge then aligns to the platform edge at +.514.
		_piece(escape,"Guardrail%d"%level,"modular_fire_escape_railing_middle",Vector3(0,y+0.707,0.240))
	# The actual stair mesh climbs along local X. The imported tread
	# levels differ by ~2.3m; fit those to the fixed three-metre floors.
	# At the ends, overlap the authored landing footprints rather than
	# leaving a detached staircase floating in the lane.
	_piece(escape,"ConnectingStair","modular_fire_escape_stairs",Vector3(0,1.47,0.68),Vector3(1,STOREY/2.3,1))
	escape.set_meta("landing_levels",Vector2(DECK_Y,DECK_Y+STOREY))

func _install_span(z: float) -> void:
	var span := Node3D.new()
	span.name="OverheadServiceSpan"
	add_child(span,true)
	var mount := Gold._source(Gold.CABLES,"cable_mount")
	for side in [-1,1]:
		var end := Node3D.new()
		end.name="WestWallAnchor" if side==-1 else "EastWallAnchor"
		end.position=Vector3(_left if side==-1 else _right,END_Y,z)
		end.rotation.y=0.0 if side==-1 else PI
		span.add_child(end)
		var fitting := MeshInstance3D.new()
		fitting.name="AuthoredCableMount"
		fitting.mesh=mount
		# The tiny published clip is reused threefold at real wire spacing.
		# Place the middle clip as the parent; offset one each side.
		for i in [-1,0,1]:
			var clip := fitting if i==0 else fitting.duplicate() as MeshInstance3D
			clip.position.z=float(i)*0.07
			span.get_node(str(end.name)).add_child(clip,true)
	# Three tightly grouped round service lines; endpoints meet the
	# actual mounting plane on each building. Sag is continuous.
	var mesh := MeshInstance3D.new()
	mesh.name="ContinuousCableBundle"
	mesh.mesh=_bundle(z)
	mesh.material_override=_cable_material
	span.add_child(mesh)
	span.set_meta("wall_endpoints",Vector2(_left,_right))
	span.set_meta("minimum_height",END_Y-SAG-0.02)

func _center(t: float, z: float, wire: int) -> Vector3:
	return Vector3(lerpf(_left+0.012,_right-0.012,t),
		END_Y-SAG*4.0*t*(1.0-t),z+float(wire)*0.07)

func _bundle(z: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for wire in [-1,0,1]:
		var base := vertices.size()
		var radius := 0.013 if wire==0 else 0.009
		for step in range(SEGMENTS+1):
			var t := float(step)/float(SEGMENTS)
			var axis := Vector3(_right-_left,-4.0*SAG*(1.0-2.0*t),0).normalized()
			var up := Vector3.FORWARD.cross(axis).normalized()
			for k in range(SIDES):
				var angle := TAU*float(k)/float(SIDES)
				var normal := up*cos(angle)+Vector3.FORWARD*sin(angle)
				vertices.append(_center(t,z,wire)+normal*radius)
				normals.append(normal)
				uv.append(Vector2(t*8.0,float(k)/float(SIDES)))
		for step in range(SEGMENTS):
			for k in range(SIDES):
				var a := base+step*SIDES+k
				var b := base+step*SIDES+(k+1)%SIDES
				var c := b+SIDES
				var d := a+SIDES
				indices.append_array(PackedInt32Array([a,b,c,a,c,d]))
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
