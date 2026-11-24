extends StaticBody3D
## A ground-floor room at its actual street coordinates. The surrounding
## solid volume stays intact; no teleports, sub-worlds or loading overlays.
## Collision and matching shell meshes arrive in the existing stage zero.
const Materials = preload("res://scripts/material_library.gd")
const PhotoMasonry = preload("res://scripts/photo_masonry.gd")
const Door = preload("res://scripts/storefront_door.gd")
const DOOR_WIDTH = 2.8
const DOOR_HEIGHT = 3.05
const ROOM_WIDTH = 9.6
const ROOM_DEPTH = 8.6
const ROOM_HEIGHT = 4.1
var _width: float
var _depth: float
var _height: float
var _dressed := false
var door: AnimatableBody3D
var _lamp: OmniLight3D
static var _unit := BoxMesh.new()
static var _shapes: Dictionary = {}
static var _materials: Dictionary = {}

func configure(width: float, height: float, depth: float, wall: Color, kind: String) -> void:
	_width = width
	_depth = depth
	_height = height
	var exterior: Material = PhotoMasonry.surface(wall) if kind == "BRICK" else Materials.surface(kind, wall)
	var half := ROOM_WIDTH * .5
	var flank := (width - ROOM_WIDTH) * .5
	# Preserve the original footprint and upper mass. Every box is disjoint.
	for side in [-1.0, 1.0]:
		_section("SideMass", Vector3(side * (half + flank * .5), height * .5, depth * .5), Vector3(flank, height, depth), exterior)
	_section("RearMass", Vector3(0,height * .5,(ROOM_DEPTH + depth)*.5), Vector3(ROOM_WIDTH,height,depth-ROOM_DEPTH), exterior)
	_section("UpperMass", Vector3(0,(ROOM_HEIGHT+height)*.5,ROOM_DEPTH*.5), Vector3(ROOM_WIDTH,height-ROOM_HEIGHT,ROOM_DEPTH), exterior)
	var jamb := (ROOM_WIDTH - DOOR_WIDTH)*.5
	for side in [-1.0,1.0]:
		_section("FrontWall", Vector3(side * (DOOR_WIDTH*.5+jamb*.5),ROOM_HEIGHT*.5,.13), Vector3(jamb,ROOM_HEIGHT,.26), exterior)
	_section("DoorHeader", Vector3(0,(DOOR_HEIGHT+ROOM_HEIGHT)*.5,.13), Vector3(DOOR_WIDTH,ROOM_HEIGHT-DOOR_HEIGHT,.26), exterior)
	_section("Floor", Vector3(0,-.075,ROOM_DEPTH*.5),Vector3(ROOM_WIDTH,.15,ROOM_DEPTH),Materials.surface("CONCRETE",Color("68666a")))
	# Inward swing from the right jamb. The existing obstruction-aware
	# storefront hinge checks characters and rigid bodies before each step.
	door = Door.new()
	door.name = "EntryDoor"
	door.position = Vector3(DOOR_WIDTH*.5-.04,0,.16)
	add_child(door)
	var size := Vector3(DOOR_WIDTH-.08,DOOR_HEIGHT-.10,.12)
	var center := Vector3(-size.x*.5,size.y*.5,0)
	door.call("configure",size,center)
	var leaf := MeshInstance3D.new()
	leaf.name = "DoorLeaf"
	leaf.mesh = _unit
	leaf.scale = size
	leaf.position = center
	leaf.material_override = _mat(Color("34434a"))
	door.add_child(leaf)
	var handle := MeshInstance3D.new()
	handle.mesh = _unit
	handle.scale = Vector3(.16,.42,.18)
	handle.position = Vector3(-size.x+.26,1.13,-.08)
	handle.material_override = _mat(Color("a5a7a3"))
	door.add_child(handle)
	door.set("art_ready",true)
	# Thin interior finishes on the solid surfaces, without added colliders.
	var inside := _mat(Color("777d80"))
	for side in [-1.0,1.0]:
		_visual("InteriorWall",Vector3(side*(half-.018),ROOM_HEIGHT*.5,ROOM_DEPTH*.5),Vector3(.025,ROOM_HEIGHT,ROOM_DEPTH),inside)
	_visual("InteriorBack",Vector3(0,ROOM_HEIGHT*.5,ROOM_DEPTH-.018),Vector3(ROOM_WIDTH,ROOM_HEIGHT,.025),inside)
	_visual("Ceiling",Vector3(0,ROOM_HEIGHT-.018,ROOM_DEPTH*.5),Vector3(ROOM_WIDTH,.025,ROOM_DEPTH),_mat(Color("b1a9a1")))

func dress(district: String, accent: Color, variant: int) -> void:
	if _dressed:
		return
	_dressed = true
	var industrial := district in ["WEST DOCKS","SOUTHWORKS","BRICKWATER"]
	var office := district in ["GLASSLINE","HORIZON GARDENS"]
	var counter := _mat(Color("48545b") if office else Color("625248") if industrial else Color("745e53"))
	# Protected central route from street to the back of the room. Layout
	# selection is stable and does not consume the city's exterior RNG.
	for side in [-1.0,1.0]:
		var x: float = side * 3.55
		for z in [2.8,6.0]:
			var tall := industrial and posmod(variant,2)==0
			_section("Furnishing",Vector3(x,1.0 if tall else .52,z),Vector3(1.65,2.0 if tall else 1.04,1.45 if office else 1.9),counter)
			_visual("Worktop",Vector3(x,2.04 if tall else 1.07,z),Vector3(1.72,.10,2.0),_mat(accent.darkened(.52)))
	# Two low-cost luminous fixtures; no extra shadow-casting lights per lot.
	for z in [2.3,6.1]:
		_visual("CeilingFixture",Vector3(0,ROOM_HEIGHT-.13,z),Vector3(3.0,.12,.42),_mat(Color("d8dad2"),true))

func doorway_reachable(at: Vector3) -> bool:
	var p := to_local(at)
	return absf(p.x)<2.0 and absf(p.z)<2.0 and p.y>=-.2 and p.y<2.8

func set_local_light(enabled: bool) -> void:
	if enabled and not is_instance_valid(_lamp):
		_lamp = OmniLight3D.new()
		_lamp.name = "NearInteriorLight"
		_lamp.position = Vector3(0,ROOM_HEIGHT-.45,4.3)
		_lamp.omni_range = 9.0
		_lamp.light_energy = .9
		_lamp.light_color = Color("f6dfbf")
		_lamp.shadow_enabled = false
		add_child(_lamp)
	if is_instance_valid(_lamp):
		_lamp.visible = enabled

func contains(at: Vector3) -> bool:
	var p := to_local(at)
	return absf(p.x)<ROOM_WIDTH*.5 and p.z>0.27 and p.z<ROOM_DEPTH and p.y>=-.1 and p.y<ROOM_HEIGHT

func _mat(tint: Color, glow: bool = false) -> StandardMaterial3D:
	var key := tint.to_html(false)+str(glow)
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = .82
		if glow:
			material.emission_enabled = true
			material.emission = tint
			material.emission_energy_multiplier = .65
		_materials[key] = material
	return _materials[key]

func _section(label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label+"Collision"
	if not _shapes.has(size):
		var box := BoxShape3D.new()
		box.size = size
		_shapes[size] = box
	collision.shape = _shapes[size]
	collision.position = at
	add_child(collision,true)
	_visual(label,at,size,material)

func _visual(label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = _unit
	view.scale = size
	view.position = at
	view.material_override = material
	add_child(view,true)
