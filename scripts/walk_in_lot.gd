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
var clothing_store_id := ""
var _clothing_clerk:Node3D
var _clothing_greeted:=false
var _clothing_visit:=false
var _clothing_remark_index:=0
const ShopClerk=preload("res://scripts/synaxis_staff.gd")
const ClothingStore = preload("res://scripts/clothing_store.gd")
const Wardrobe = preload("res://scripts/wardrobe_catalog.gd")
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

## Original shop dressing, with the same collision-first streamed shell.
func dress_clothing_store() -> void:
	if _dressed:
		return
	_dressed=true
	clothing_store_id=ClothingStore.ID
	var black:=_mat(Color("252c33"))
	var oak:=_mat(Color("8e7660"))
	var brass:=_mat(Color("b9a277"))
	# Counter against west wall; center route and side passages remain open.
	_section("Furnishing",Vector3(-3.55,.52,2.8),Vector3(1.65,1.04,1.7),black)
	_visual("Worktop",Vector3(-3.55,1.07,2.8),Vector3(1.75,.10,1.8),oak)
	_visual("Worktop",Vector3(-3.35,1.22,2.65),Vector3(.32,.23,.22),black)
	# Two collision-backed garment display fixtures with folded colorways.
	for z in [2.6,6.3,11.8]:
		_section("Furnishing",Vector3(3.58,.45,z),Vector3(1.45,.90,1.55),black)
		_visual("Worktop",Vector3(3.58,.93,z),Vector3(1.52,.08,1.63),oak)
		_visual("Worktop",Vector3(4.19,1.53,z),Vector3(.055,1.15,1.43),brass)
		for i in range(3):
			var id:String=Wardrobe.IDS[(int(z)+i)%Wardrobe.IDS.size()]
			var item:Dictionary=Wardrobe.ITEMS[id]
			var tint:Color=item["jacket"]
			var at:=Vector3(3.48,1.15,z-.48+float(i)*.48)
			for layer in range(3):
				_visual("Worktop",Vector3(at.x,1.00+float(layer)*.065,at.z),Vector3(.60,.058,.36),_mat(tint.darkened(.24+float(layer)*.06)))
			# Shoulder/sleeve garment silhouettes on a display rail.
			_visual("Worktop",Vector3(4.04,1.58,at.z),Vector3(.15,.62,.35),_mat(tint.darkened(.25)))
			_visual("Worktop",Vector3(4.04,1.74,at.z),Vector3(.16,.23,.45),_mat(tint.darkened(.25)))
	for z in [2.3,6.1,10.7,14.5]:
		_visual("CeilingFixture",Vector3(0,ROOM_HEIGHT-.13,z),Vector3(2.6,.12,.42),_mat(Color("f4d9b0"),true))
	# Branded sign panels, counter point-of-sale and merchandise tags.
	_visual("Worktop",Vector3(4.68,2.0,8.2),Vector3(.07,1.1,1.2),black)
	_visual("Worktop",Vector3(-3.82,1.24,2.25),Vector3(.30,.28,.12),black)
	_visual("Worktop",Vector3(-3.65,1.23,2.25),Vector3(.018,.20,.09),_mat(Color("90c4b1"),true))
	_visual("Worktop",Vector3(-3.15,1.14,3.15),Vector3(.22,.028,.16),brass)
	for z in [2.6,6.3,11.8]:
		_visual("Worktop",Vector3(2.82,.99,z),Vector3(.045,.12,.65),brass)
	_shop_label("EVERYDAY. EVERYWHERE.",Vector3(0,2.66,4.1),.003,PI)
	_shop_label("THREADLINE",Vector3(4.62,2.12,8.2),.003,-PI/2)
	_shop_label("USD / BTC ACCEPTED",Vector3(-3.50,1.83,2.8),.003,PI)
	_shop_label("FITTING / LOOK GOOD. FEEL LIKE YOURSELF.",Vector3(3.45,2.25,6.3),.003,-PI/2)
	_shop_label("THREADLINE / VESPER MARKET",Vector3(0,2.95,4.1),.005,PI)
	_shop_label("FITTING / CHECKOUT",Vector3(-3.55,2.28,2.8),.004,PI)
	_shop_label("WORKWEAR / STREET / AFTER DARK",Vector3(3.45,2.25,2.6),.003,PI)
	_flush_interior_visuals()
	_clothing_clerk=ShopClerk.new()
	_clothing_clerk.call("configure_staff",{"id":"tess_threadline","name":"Tess Vale","role":"Threadline shopkeeper","activity":"TYPE","seated":false,"palette":3,"phase":1.4,"outfit":"retail","hair":"bun","glasses":true,"coat":Color("4d4641"),"height":.92,"width":.78})
	_clothing_clerk.name="ThreadlineClerk"
	_clothing_clerk.position=Vector3(-4.12,0,2.0)
	_clothing_clerk.rotation.y=PI/2
	add_child(_clothing_clerk)
	_clothing_clerk.process_mode=Node.PROCESS_MODE_DISABLED
	_clothing_clerk.hide()

func _shop_label(value:String,at:Vector3,pixel:float,yaw:float) -> void:
	var label:=Label3D.new()
	label.text=value
	label.position=at
	label.rotation.y=yaw
	label.font_size=40
	label.pixel_size=pixel
	label.modulate=Color("f4d9b0")
	label.outline_size=3
	add_child(label)

func clothing_greeting() -> String:
	if _clothing_greeted:
		return ""
	_clothing_greeted=true
	return "Tess: First time at Threadline? Try anything on. You only pay when you decide to keep it."

func clothing_remark(purchased:bool=false) -> String:
	if purchased:
		return "Tess: Nice choice. It is yours now. Come back whenever you want to change things up."
	var lines:Array=["Tess: Good clothes do not have to come with a corporate badge.","Tess: The night-shift colors look better under the streetlights.","Tess: Try the accessories with something you already own."]
	var line:String=lines[_clothing_remark_index%lines.size()]
	_clothing_remark_index+=1
	return line

func clothing_counter() -> Vector3:
	return to_global(ClothingStore.COUNTER)

func clothing_reachable(at:Vector3) -> bool:
	return clothing_store_id==ClothingStore.ID and contains(at) and at.distance_to(clothing_counter())<1.4

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
	# Compact enclosed sleeping berth within the reused shell. Leave the
	# entrance at z=12 open, and keep the shared walking aisle unobstructed.
	var shell := _mat(Color("555d63"))
	_section("PodPartition",Vector3(2.35,1.1,14.05),Vector3(.12,2.2,2.55),shell)
	_visual("PodCeiling",Vector3(3.35,2.14,14.05),Vector3(2.0,.15,2.55),shell)
	_visual("PodLight",Vector3(3.35,2.04,13.65),Vector3(.75,.045,.18),_mat(Color("e0b587"),true))
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
	if is_instance_valid(_clothing_clerk):
		var occupied:=enabled and at.is_finite() and contains(at) and to_local(at).y<ROOM_HEIGHT
		if occupied!=_clothing_visit:
			_clothing_visit=occupied
			_clothing_clerk.visible=occupied
			_clothing_clerk.process_mode=Node.PROCESS_MODE_INHERIT if occupied else Node.PROCESS_MODE_DISABLED
			if not occupied:
				_clothing_greeted=false
		_clothing_clerk.call("attend",at,occupied and clothing_reachable(at))
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
