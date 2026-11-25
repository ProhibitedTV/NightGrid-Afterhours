extends StaticBody3D
## Two accessible levels at their actual street coordinates. The surrounding
## solid volume stays intact; no teleports, sub-worlds or loading overlays.
## Collision and matching shell meshes arrive in the existing stage zero.
const Materials = preload("res://scripts/material_library.gd")
const PhotoMasonry = preload("res://scripts/photo_masonry.gd")
const Door = preload("res://scripts/storefront_door.gd")
const DOOR_WIDTH = 2.8
const DOOR_HEIGHT = 3.05
const ROOM_WIDTH = 9.6
const ROOM_DEPTH = 17.0
const RAMP_START = 9.4
const RAMP_END = 15.0
const RAMP_X = -3.275
const UPPER_HEIGHT = 8.2
const HALL_HALF = 1.75
const PARTITION_START = 4.6
const SIDE_PASSAGE_CENTER = 8.1
const SIDE_PASSAGE_WIDTH = 1.9
const ROOM_HEIGHT = 4.1
var _width: float
var _depth: float
var _height: float
var _dressed := false
var physical_venue_id := ""
var home_id := ""
var door: AnimatableBody3D
var _lamp: OmniLight3D
var _pending_visuals: Dictionary = {}
var _interior_batches := 0
var _interior_instances := 0
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
	_section("UpperMass", Vector3(0,(UPPER_HEIGHT+height)*.5,ROOM_DEPTH*.5), Vector3(ROOM_WIDTH,height-UPPER_HEIGHT,ROOM_DEPTH), exterior)
	_section("UpperFrontWall",Vector3(0,(ROOM_HEIGHT+UPPER_HEIGHT)*.5,.13),Vector3(ROOM_WIDTH,UPPER_HEIGHT-ROOM_HEIGHT,.26),exterior)
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
	_build_upper_level(inside)
	# Two actual side rooms open off a central corridor, each with a framed
	# 1.9 m passage. All partitions are registered in stage zero so later
	# decoration can never create a new wall inside an occupied player.
	var divider := _mat(Color("858581"))
	var first_end := SIDE_PASSAGE_CENTER - SIDE_PASSAGE_WIDTH*.5
	var second_start := SIDE_PASSAGE_CENTER + SIDE_PASSAGE_WIDTH*.5
	for side in [-1.0,1.0]:
		var x: float = side * HALL_HALF
		_section("RoomDivider",Vector3(x,ROOM_HEIGHT*.5,(PARTITION_START+first_end)*.5),Vector3(.18,ROOM_HEIGHT,first_end-PARTITION_START),divider)
		_section("RoomDivider",Vector3(x,ROOM_HEIGHT*.5,(second_start+ROOM_DEPTH)*.5),Vector3(.18,ROOM_HEIGHT,ROOM_DEPTH-second_start),divider)
		_section("RoomLintel",Vector3(x,(DOOR_HEIGHT+ROOM_HEIGHT)*.5,SIDE_PASSAGE_CENTER),Vector3(.18,ROOM_HEIGHT-DOOR_HEIGHT,SIDE_PASSAGE_WIDTH),divider)
		# Front walls make these real rooms rather than simple bays; the
		# central corridor stays clear from the street to the rear wall.
		var side_width := half-HALL_HALF-.09
		_section("RoomFront",Vector3(side*(HALL_HALF+.09+side_width*.5),ROOM_HEIGHT*.5,PARTITION_START),Vector3(side_width,ROOM_HEIGHT,.18),divider)
	_flush_interior_visuals()

func _build_upper_level(inside: Material) -> void:
	# Clear the entire ramp shaft at stage zero. All walking surfaces and
	# guardrails belong to the same immutable parcel collision body.
	var slab := _mat(Color("747b80"))
	var rail := _mat(Color("47555d"))
	var west_width := ROOM_WIDTH*.5-HALL_HALF
	var east_width := ROOM_WIDTH*.5+HALL_HALF
	var shaft_start := RAMP_START-.45
	_section("UpperMainFloor",Vector3((ROOM_WIDTH*.5-HALL_HALF)*.5,ROOM_HEIGHT-.09,ROOM_DEPTH*.5),Vector3(east_width,.18,ROOM_DEPTH),slab)
	_section("UpperWestFront",Vector3(RAMP_X,ROOM_HEIGHT-.09,shaft_start*.5),Vector3(west_width,.18,shaft_start),slab)
	_section("UpperLanding",Vector3(RAMP_X,ROOM_HEIGHT-.09,(RAMP_END+ROOM_DEPTH)*.5),Vector3(west_width,.18,ROOM_DEPTH-RAMP_END),slab)
	# Sloped solid, with its upper plane exactly matching both floor heights.
	var run := RAMP_END-RAMP_START
	var angle := -atan2(ROOM_HEIGHT,run)
	var length := Vector2(run,ROOM_HEIGHT).length()
	var normal := Basis(Vector3.RIGHT,angle)*Vector3.UP
	var midpoint := Vector3(RAMP_X,ROOM_HEIGHT*.5,(RAMP_START+RAMP_END)*.5)-normal*.10
	_section("AccessRamp",midpoint,Vector3(west_width-.16,.20,length),slab,angle)
	# Upper-level edges facing the shaft cannot be walked through.
	_section("UpperGuard",Vector3(-HALL_HALF+.06,ROOM_HEIGHT+.55,(shaft_start+RAMP_END)*.5),Vector3(.12,1.1,RAMP_END-shaft_start),rail)
	_section("UpperGuardFront",Vector3(RAMP_X,ROOM_HEIGHT+.55,shaft_start-.06),Vector3(west_width,1.1,.12),rail)
	# Close the narrow drop between the ramp and east-side shaft wall.
	_section("RampRail",midpoint+normal*.72+Vector3(west_width*.5-.12,0,0),Vector3(.12,1.1,length),rail,angle)
	_visual("UpperRearFinish",Vector3(0,(UPPER_HEIGHT+ROOM_HEIGHT)*.5,ROOM_DEPTH-.018),Vector3(ROOM_WIDTH,ROOM_HEIGHT,.025),inside)
	_visual("UpperCeiling",Vector3(0,UPPER_HEIGHT-.018,ROOM_DEPTH*.5),Vector3(ROOM_WIDTH,.025,ROOM_DEPTH),_mat(Color("b1a9a1")))
	for side in [-1.0,1.0]:
		_visual("UpperSideFinish",Vector3(side*(ROOM_WIDTH*.5-.018),(UPPER_HEIGHT+ROOM_HEIGHT)*.5,ROOM_DEPTH*.5),Vector3(.025,ROOM_HEIGHT,ROOM_DEPTH),inside)

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
		for z in [2.8,6.2,11.0,14.8]:
			if side < 0.0 and z >= 9.0:
				continue
			var tall := industrial and posmod(variant,2)==0
			_section("Furnishing",Vector3(x,1.0 if tall else .52,z),Vector3(1.65,2.0 if tall else 1.04,1.45 if office else 1.9),counter)
			_visual("Worktop",Vector3(x,2.04 if tall else 1.07,z),Vector3(1.72,.10,2.0),_mat(accent.darkened(.52)))
	# Low-cost luminous fixtures; a single local light follows the player.
	for z in [2.3,6.1,10.7,14.5]:
		_visual("CeilingFixture",Vector3(0,ROOM_HEIGHT-.13,z),Vector3(3.0,.12,.42),_mat(Color("d8dad2"),true))

	for z in [2.8,6.2,10.0,13.0]:
		_visual("UpperFixture",Vector3(0,UPPER_HEIGHT-.13,z),Vector3(3.0,.12,.42),_mat(Color("d8dad2"),true))
		_section("UpperWorkstation",Vector3(3.55,ROOM_HEIGHT+.52,z),Vector3(1.65,1.04,1.45),counter)
	_flush_interior_visuals()

## Prototype furnishings, installed with collision in stage zero.
func dress_home(id: String) -> void:
	if _dressed:
		return
	_dressed = true
	home_id = id
	var timber := _mat(Color("604d40"))
	var linen := _mat(Color("536d77"))
	_section("Furnishing",Vector3(3.35,.28,13.9),Vector3(1.75,.56,2.25),timber)
	_visual("Worktop",Vector3(3.35,.70,13.9),Vector3(1.68,.28,2.14),linen)
	_visual("Worktop",Vector3(3.35,.89,14.64),Vector3(1.15,.12,.45),_mat(Color("d5ceba")))
	_section("Furnishing",Vector3(3.55,.72,6.0),Vector3(1.55,1.44,.85),timber)
	_section("Furnishing",Vector3(-3.55,.52,2.8),Vector3(1.65,1.04,1.45),timber)
	_visual("Worktop",Vector3(-3.55,1.08,2.8),Vector3(1.72,.10,1.55),_mat(Color("a69c85")))
	for z in [2.3,6.1,10.7,14.5]:
		_visual("CeilingFixture",Vector3(0,ROOM_HEIGHT-.13,z),Vector3(2.0,.12,.42),_mat(Color("f1d5ad"),true))
	_flush_interior_visuals()
	var wardrobe_label := Label3D.new()
	wardrobe_label.name = "WardrobeLabel"
	wardrobe_label.text = "WARDROBE"
	wardrobe_label.font_size = 28
	wardrobe_label.pixel_size = .005
	wardrobe_label.position = Vector3(3.55,1.7,5.52)
	wardrobe_label.rotation.y = PI
	wardrobe_label.modulate = Color("b4d7d4")
	add_child(wardrobe_label)

func home_action_point(action: String) -> Vector3:
	match action:
		"rest":
			return to_global(Vector3(3.35,1.15,12.0))
		"storage":
			return to_global(Vector3(3.55,1.15,7.45))
		"wardrobe":
			return to_global(Vector3(3.55,1.15,4.55))
		"exchange":
			return to_global(Vector3(-2.1,1.15,5.0))
		"save":
			return to_global(Vector3(-2.1,1.15,2.8))
	return Vector3.INF

func home_action(at: Vector3) -> String:
	if home_id.is_empty() or not contains(at):
		return ""
	for action in ["rest","storage","wardrobe","exchange","save"]:
		if at.distance_to(home_action_point(action)) < 1.1:
			return action
	return ""

func bind_physical_venue(id: String) -> void:
	physical_venue_id = id
	# Existing lobby furniture supplies the actual service counter on the
	# left. A permanent label identifies the interaction from the entrance.
	var label := Label3D.new()
	label.name = "PhysicalServiceCounter"
	label.text = "HELIX ESPRESSO / ORDER HERE"
	label.font_size = 34
	label.pixel_size = .006
	label.position = Vector3(-3.55,2.3,2.8)
	label.rotation.y = PI
	label.modulate = Color("85cad0")
	add_child(label)

func service_counter() -> Vector3:
	return to_global(Vector3(-2.35,1.15,2.8))

func service_reachable(at: Vector3) -> bool:
	return not physical_venue_id.is_empty() and contains(at) and at.distance_to(service_counter()) <= 1.65

func doorway_reachable(at: Vector3) -> bool:
	var p := to_local(at)
	return absf(p.x)<2.0 and absf(p.z)<2.0 and p.y>=-.2 and p.y<2.8

func set_local_light(enabled: bool, at: Vector3 = Vector3.INF) -> void:
	if enabled and not is_instance_valid(_lamp):
		_lamp = OmniLight3D.new()
		_lamp.name = "NearInteriorLight"
		_lamp.position = Vector3(0,ROOM_HEIGHT-.45,6.3)
		_lamp.omni_range = 12.0
		_lamp.light_energy = .9
		_lamp.light_color = Color("f6dfbf")
		_lamp.shadow_enabled = false
		add_child(_lamp)
	if is_instance_valid(_lamp):
		_lamp.visible = enabled
		if enabled and at.is_finite():
			# Reuse the same light on the occupied level. No additional
			# active lights are allocated when the player climbs the ramp.
			var p := to_local(at)
			var level := ROOM_HEIGHT if p.y >= ROOM_HEIGHT+.5 else 0.0
			_lamp.position = Vector3(0,level+ROOM_HEIGHT-.45,8.0 if level > 0.0 else 6.3)

func restore_safe_threshold(at: Vector3) -> void:
	var p := to_local(at)
	# An ordinary save stores the real player coordinates. If a save is
	# restored in the door plane, never reconstruct a closed leaf over it.
	if is_instance_valid(door) and absf(p.x) < DOOR_WIDTH*.5+.45 and absf(p.z-.16) < .65 and p.y < DOOR_HEIGHT+.3:
		door.call("restore_open",true)

func contains(at: Vector3) -> bool:
	var p := to_local(at)
	return absf(p.x)<ROOM_WIDTH*.5 and p.z>0.27 and p.z<ROOM_DEPTH and p.y>=-.1 and p.y<UPPER_HEIGHT

func room_at(at: Vector3) -> String:
	if not contains(at):
		return ""
	var p := to_local(at)
	if p.x < -HALL_HALF and p.z >= RAMP_START and p.z < RAMP_END:
		return "access_ramp"
	if p.y >= ROOM_HEIGHT+.5:
		return "upper_floor"
	if p.z < PARTITION_START:
		return "lobby"
	if absf(p.x) <= HALL_HALF:
		return "corridor"
	return "west_room" if p.x < 0.0 else "east_room"

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

func _section(label: String, at: Vector3, size: Vector3, material: Material, angle: float = 0.0) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label+"Collision"
	if not _shapes.has(size):
		var box := BoxShape3D.new()
		box.size = size
		_shapes[size] = box
	collision.shape = _shapes[size]
	collision.position = at
	collision.rotation.x = angle
	add_child(collision,true)
	_visual(label,at,size,material,angle)

func get_interior_batch_stats() -> Dictionary:
	return {"batches":_interior_batches,"instances":_interior_instances}

func _flush_interior_visuals() -> void:
	# Local-space per-material batches are owned by this streamed lot.
	# Keep the real collision shapes, moving door, and exterior meshes
	# independent. Splitting floors keeps culling reasonably granular.
	for key in _pending_visuals:
		var bucket: Dictionary = _pending_visuals[key]
		var transforms: Array = bucket["transforms"]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _unit
		batch.instance_count = transforms.size()
		for i in transforms.size():
			batch.set_instance_transform(i,transforms[i])
		var view := MultiMeshInstance3D.new()
		view.name = "InteriorBatch"
		view.multimesh = batch
		view.material_override = bucket["material"]
		view.visibility_range_end = 45.0
		view.visibility_range_end_margin = 5.0
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view,true)
		_interior_batches += 1
		_interior_instances += transforms.size()
	_pending_visuals.clear()

func _visual(label: String, at: Vector3, size: Vector3, material: Material, angle: float = 0.0) -> void:
	# The exterior shell is always rendered, including roof and masonry.
	# Keep structural interior surfaces visible nearby; only decorative
	# fixtures/furnishings are range culled. Floors/walls remain individual
	# meshes to preserve correct shadows and doorway visibility.
	if label in ["Furnishing","Worktop","CeilingFixture","UpperFixture","UpperWorkstation"]:
		var key := "%d:%d" % [material.get_instance_id(),int(at.y >= ROOM_HEIGHT)]
		if not _pending_visuals.has(key):
			_pending_visuals[key] = {"material":material,"transforms":[]}
		var transform := Transform3D(Basis(Vector3.RIGHT,angle).scaled_local(size),at)
		_pending_visuals[key]["transforms"].append(transform)
		return
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = _unit
	view.scale = size
	view.position = at
	view.rotation.x = angle
	view.material_override = material
	add_child(view,true)
