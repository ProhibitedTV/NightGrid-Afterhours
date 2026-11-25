extends Node3D
## Permanent authored headquarters ground floor, streamed by its city parcel.
## Only the introductory cast and mission UI are transient.
const BLOCK = Vector2i(1,-1)
const LOT = 0
const ORIGIN = Vector3(76.5,.15,-33.88)
const ENTRY = Vector3(76.5,1.30,-46.2)
const ID = "synaxis_hq"
const NAME = "SYNAXIS OMNISYSTEMS"
var _intro_canvas: CanvasLayer
var _cast: Node3D
const LOBBY_CHECKPOINT = Vector3(0,1.15,-9.0)
var _lobby_light: OmniLight3D
var _lobby_active := false
var _prologue_active := false
const Patron = preload("res://scripts/lantern_patron.gd")
const Assistant = preload("res://scripts/synaxis_assistant.gd")
const Propaganda = preload("res://scripts/synaxis_propaganda.gd")
const Brand = preload("res://scripts/synaxis_brand.gd")
const Finish = preload("res://scripts/synaxis_office_finish.gd")
const Radar = preload("res://scripts/hud_radar.gd")
const Arrival = preload("res://scripts/synaxis_arrival.gd")
const Restrooms = preload("res://scripts/synaxis_restrooms.gd")
var _restrooms: Node3D
const CUBICLE_POINT = Vector3(4.5,1.15,2.95)
var _arrival: RefCounted
var _arrival_canvas: CanvasLayer
var _arrival_caption: Label
var _radar: Control
var _folder: Node3D
var _folder_hand: BoneAttachment3D
var _folder_desk: Node3D
var _errand_phase := 0
var _arrival_fov := 68.0
var _gate_open := false
var _desk_beat_played := false
var _assistant: Node3D
var _ceo: Node3D
var _hr: Node3D
const START = Vector3(0,1.15,7)
const BREAKROOM_POINT = Vector3(-4.2,1.15,6.85)
var _breakroom_seen := false
const POINTS = {-2:CUBICLE_POINT,-1:Vector3(-5,1.15,4),0:Vector3(-5,1.15,4),2:Vector3(5,1.15,-4),4:Vector3(-5,1.15,-4),5:Vector3(5,1.15,5)}
const TITLES = {-2:"CORPORATE IP SECURITY / COLLECT THE FOLDER",-1:"IT DEPARTMENT / DROP OFF THE FOLDER",0:"IT DESK / REVIEW THE ALERT",2:"EXECUTIVE OFFICE / ATTEND BRIEFING",4:"PEOPLE EXPERIENCE / EXIT INTERVIEW",5:"RECEPTION / COLLECT FINAL NOTICE"}
var _target_sign: Label3D
var _hint: Label
var _mat: Dictionary = {}

func _ready() -> void:
	var floor_mat := _material("floor",Color("34414a"))
	var wall := _material("wall",Color("58636b"))
	var desk := _material("desk",Color("242e36"))
	var accent := _material("accent",Color("b9cbd0"))
	var screen := _material("screen",Color("508f8d"),true)
	_solid("Floor",Vector3(0,-.15,0),Vector3(17,.3,20),floor_mat)
	_solid("Ceiling",Vector3(0,3.5,0),Vector3(17,.3,20),wall)
	for side in [-1.0,1.0]:
		_solid("FrontWall",Vector3(side*4.9,1.75,-10),Vector3(7.2,3.5,.25),wall)
	_solid("EntranceHeader",Vector3(0,3.15,-10),Vector3(2.6,.7,.25),wall)
	# Street vestibule is public; a full-width security barrier separates it from the offices.
	for side in [-1.0,1.0]:
		_solid("SecurityFlank",Vector3(side*4.9,1.75,-7.65),Vector3(7.2,3.5,.24),wall)
	_solid("SecurityGate",Vector3(0,1.4,-7.65),Vector3(2.6,2.8,.25),_material("security",Color("293842")))
	_solid("SecurityHeader",Vector3(0,3.15,-7.65),Vector3(2.6,.7,.25),wall)
	_sign("RESTRICTED / BADGE ACCESS",Vector3(0,2.96,-7.80),.004).rotation.y=PI
	Brand.wall_logo(self,"EntranceBrand",Vector3(0,3.12,-10.17),PI,2.15)
	_sign("PUBLIC LOBBY",Vector3(0,2.65,-10.17),.0045).rotation.y = PI
	# Fixed upper-floor shell, not a second generic building intersecting the office.
	_solid("TowerCore",Vector3(0,27,0),Vector3(17,46.7,20),_material("glass",Color("354c60")))
	for floor in range(12):
		var y := 5.4+float(floor)*3.65
		_visual("FacadeSpandrel",Vector3(0,y,-10.13),Vector3(17,.36,.16),accent)
	_visual("Crown",Vector3(0,50.8,0),Vector3(17.5,.75,20.5),desk)
	Brand.wall_logo(self,"TowerBrandFront",Vector3(0,48.2,-10.24),PI,11.8)
	Brand.wall_logo(self,"TowerBrandRear",Vector3(0,48.2,10.24),0.0,11.8)
	_solid("SouthWall",Vector3(0,1.75,10),Vector3(17,3.5,.25),wall)
	_solid("WestWall",Vector3(-8.5,1.75,0),Vector3(.25,3.5,20),wall)
	_solid("EastWall",Vector3(8.5,1.75,0),Vector3(.25,3.5,20),wall)
	# Leave a physical turning vestibule behind the security gate.
	var partition_length: float=Arrival.PARTITION_FAR_Z-Arrival.PARTITION_NEAR_Z
	_solid("ExecutivePartition",Vector3(0,1.5,Arrival.PARTITION_NEAR_Z+partition_length*.5),Vector3(.18,3.0,partition_length),wall)
	_build_lobby(desk,accent,screen)
	_build_office_details(desk,accent,screen)
	_build_breakroom(desk,accent)
	_build_corporate_relics(desk,accent,screen)
	_restrooms=Restrooms.new()
	_restrooms.name="Restrooms"
	add_child(_restrooms)
	var propaganda := Propaganda.new()
	propaganda.name="CorporatePropaganda"
	add_child(propaganda)
	_collision("Workstation",Vector3(-5,.54,2.55),Vector3(2.6,1.08,.85))
	_collision("ExecutiveDesk",Vector3(5,.54,-5.4),Vector3(3.8,1.08,1.0))
	_collision("HRDesk",Vector3(-5,.54,-5.4),Vector3(2.7,1.08,1.0))
	_collision("ReceptionDesk",Vector3(5,.54,6.5),Vector3(3,1.08,.9))
	var finish := Finish.new()
	finish.name = "ArchitecturalFinish"
	add_child(finish)
	_collision("EmployeeCubicle",Vector3(4.5,.54,1.7),Vector3(2.25,1.08,.85))
	_solid("CubicleDivider",Vector3(5.65,.82,1.7),Vector3(.075,1.64,1.0),_material("cubicle_fabric",Color("606d71")))
	_sign("CORPORATE IP SECURITY / 04",Vector3(4.5,1.80,1.22),.003)
	_folder_desk = _make_folder()
	_folder_desk.position = Vector3(4.05,1.10,1.93)
	add_child(_folder_desk)
	_folder_desk.hide()
	_visual("ExitBox",Vector3(5,1.25,6.5),Vector3(.42,.34,.4),_material("cardboard",Color("a88a63")))
	for z in [-7.5,-2.5,2.5,7.5]:
		_visual("CeilingStrip",Vector3(0,3.28,z),Vector3(12,.055,.18),_material("light",Color("c9dfdf"),true))
		var light := OmniLight3D.new()
		light.position = Vector3(0,2.95,z)
		light.omni_range = 9.5
		light.light_energy = 1.25
		light.shadow_enabled = false
		add_child(light)
	Brand.wall_logo(self,"ReceptionBrand",Vector3(5.2,2.78,9.81),PI,3.65)
	Brand.wall_logo(self,"ExecutiveMark",Vector3(8.30,2.75,-5.9),-PI/2,.72,false,true)
	Brand.wall_logo(self,"ExitCartonMark",Vector3(5,1.25,6.285),PI,.22)
	_sign("THINK OUTSIDE THE BOX\nBOX SOLD SEPARATELY",Vector3(-5,2.25,2.15),.006)
	_sign("PEOPLE EXPERIENCE\nWE VALUE YOUR FEEDBACK",Vector3(-5,2.25,-5.0),.006)
	_sign("EXECUTIVE AFFAIRS\nTRANSPARENCY IS A CORE VALUE",Vector3(5,2.25,-4.9),.006)
	_sign("RECEPTION\nEXIT PROCESSING",Vector3(5,2.25,6.0),.006)
	_target_sign = _sign("",Vector3.ZERO,.006)
	_target_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_target_sign.modulate = Color("8de5cc")
	var canvas := CanvasLayer.new()
	_intro_canvas = canvas
	canvas.layer = 5
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(24,24)
	panel.custom_minimum_size = Vector2(420,0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size",20)
	panel.add_child(_hint)
	_radar = Radar.new()
	_radar.name = "OfficeRadar"
	_radar.anchor_top = 1.0
	_radar.anchor_bottom = 1.0
	_radar.offset_left = 24.0
	_radar.offset_right = 264.0
	_radar.offset_top = -264.0
	_radar.offset_bottom = -24.0
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_radar)
	_build_arrival_canvas()
	set_stage(0)
	_target_sign.hide()
	_intro_canvas.hide()
	# Ground-floor furniture and collision remain; stage lighting is local.
	for light in find_children("*","OmniLight3D",true,false):
		light.hide()

func _build_lobby(desk: Material,accent: Material,screen: Material) -> void:
	_solid("VisitorKiosk",Vector3(-2.8,.61,-8.65),Vector3(.62,1.22,.44),desk)
	_visual("VisitorDisplay",Vector3(-2.8,1.05,-8.9),Vector3(.48,.33,.04),screen)
	_sign("VISITOR SERVICES\nALL APPOINTMENTS REQUIRE APPROVAL",Vector3(-6.45,1.8,-7.80),.004).rotation.y=PI
	_sign("SECURITY NOTICE\nEMPLOYEE ACCESS MAY EXPIRE WITHOUT NOTICE",Vector3(6.45,1.8,-7.80),.004).rotation.y=PI
	for x in [-1.55,1.55]:
		_solid("CardReaderPedestal",Vector3(x,.55,-8.1),Vector3(.19,1.1,.19),accent)
		_visual("BadgeReader",Vector3(x,1.14,-8.1),Vector3(.23,.10,.25),_material("denied",Color("be5155"),true))
	_visual("LobbyRunner",Vector3(0,.012,-8.8),Vector3(2.4,.015,2.2),_material("runner",Color("20343e")))
	_lobby_light=OmniLight3D.new()
	_lobby_light.position=Vector3(0,2.95,-8.7)
	_lobby_light.omni_range=5.0
	_lobby_light.light_energy=.85
	_lobby_light.shadow_enabled=false
	add_child(_lobby_light)

func _build_office_details(desk: Material,accent: Material,screen: Material) -> void:
	# Original authored IT rack silhouettes, ventilation grilles and monitor banks.
	for x in [-7.55,-6.7]:
		_solid("ITRack",Vector3(x,1.07,.7),Vector3(.72,2.14,.85),desk)
		for row in range(7):
			_visual("RackVent",Vector3(x,.35+row*.23,1.14),Vector3(.58,.06,.025),accent)
			_visual("RackStatus",Vector3(x+.21,.36+row*.23,1.16),Vector3(.035,.04,.02),screen)
	_sign("SYSTEM HEALTH: GREEN\nEXECUTIVE OVERRIDE ACTIVE",Vector3(-5.55,1.65,2.54),.0018)
	_sign("EMPLOYEE RETENTION\n100% OF DEPARTURES ARE SUCCESSFUL",Vector3(-8.32,2.36,-3),.005).rotation.y=PI/2
	_sign("EARNINGS / RECORD QUARTER\nWORKFORCE / OPTIMIZED",Vector3(8.32,2.4,-3.6),.005).rotation.y=-PI/2
	for x in [-6.4,6.4]:
		_visual("DeskNamePlate",Vector3(x,1.13,-5.05),Vector3(.47,.13,.08),accent)
	_visual("ExecutiveCarpet",Vector3(5,.012,-3.3),Vector3(5,.015,3.1),_material("carpet",Color("383d49")))

func _build_breakroom(desk: Material,accent: Material) -> void:
	# Furniture is permanent; the short party performance is intro-only.
	_collision("BreakroomTable",Vector3(-4.2,.47,8.12),Vector3(3.4,.94,1.02))
	var card:=_material("party_cardboard",Color("c3a880"))
	var cheese:=_material("party_food",Color("d5aa56"))
	var paper:=_material("party_paper",Color("eceae1"))
	_visual("CateringCarton",Vector3(-5.12,1.01,8.12),Vector3(.67,.12,.64),card)
	_visual("OpenPizzaCarton",Vector3(-4.28,.98,8.12),Vector3(.68,.07,.66),card)
	_visual("LastTwoSlices",Vector3(-4.28,1.04,8.12),Vector3(.36,.035,.31),cheese)
	_visual("NapkinStack",Vector3(-2.90,1.00,8.18),Vector3(.22,.09,.22),paper)
	_visual("PartyBannerBacking",Vector3(-4.2,2.98,9.80),Vector3(4.7,.66,.04),_material("party_navy",Brand.NAVY))
	Brand.wall_logo(self,"PartyBrand",Vector3(-6.03,2.98,9.765),PI,.72)
	_sign("GLOBAL TALENT APPRECIATION DAY",Vector3(-3.77,3.07,9.76),.004).rotation.y=PI
	_sign("SPONSORSHIP TEAM / PHOTO BEFORE FOOD",Vector3(-3.77,2.86,9.76),.003).rotation.y=PI
	_sign("CATERING BUDGET: $48\nATTENDANCE GOAL: 65",Vector3(-2.85,1.40,8.14),.0028).rotation.y=PI

func _build_corporate_relics(desk: Material,accent: Material,screen: Material) -> void:
	# Actual desk objects, not floating tutorial text. Keep the circulation aisle clear.
	var trophy_gold := _material("recognition_gold",Brand.GOLD)
	_visual("RecognitionPlinth",Vector3(-6.0,1.125,2.59),Vector3(.30,.09,.22),desk)
	_visual("RecognitionStem",Vector3(-6.0,1.30,2.59),Vector3(.075,.27,.075),trophy_gold)
	_visual("RecognitionAward",Vector3(-6.0,1.46,2.59),Vector3(.24,.13,.065),trophy_gold)
	_sign("ABOVE & BEYOND\n$0 CASH VALUE",Vector3(-6.0,1.50,2.635),.0014)
	_visual("DeskTimeTracker",Vector3(-4.0,1.15,2.81),Vector3(.24,.12,.12),desk)
	_visual("TimeTrackerDisplay",Vector3(-4.0,1.15,2.878),Vector3(.20,.07,.007),screen)
	_sign("IDLE: 00:01",Vector3(-4.0,1.15,2.886),.0009)
	# A real executive-only amenity contrasts with the employee catering table.
	_solid("ExecutiveRefreshmentCabinet",Vector3(7.62,.49,-.25),Vector3(.85,.98,1.5),desk)
	_visual("ExecutiveCoffeeMachine",Vector3(7.62,1.18,-.52),Vector3(.42,.40,.41),accent)
	_visual("ExecutiveCoffeeDisplay",Vector3(7.385,1.24,-.52),Vector3(.012,.12,.26),screen)
	_sign("EXECUTIVE RESERVE\nNO EMPLOYEE ACCESS",Vector3(7.13,1.49,-.25),.003).rotation.y=-PI/2
	_visual("ExecutivePorcelainCup",Vector3(7.57,1.07,.12),Vector3(.13,.16,.13),_material("porcelain",Brand.WHITE))
	# Exit packaging price: consistent with the existing HR line. No charge until a future shop transaction.
	_visual("CartonPriceCard",Vector3(5.47,1.13,6.19),Vector3(.20,.11,.018),_material("exit_card",Brand.PAPER))
	var price_label:=_sign("BOX $4.99",Vector3(5.47,1.13,6.176),.0018)
	price_label.rotation.y=PI
	price_label.modulate=Brand.INK

func restroom_encounter(at: Vector3) -> String:
	if not _prologue_active or _arrival!=null:
		return ""
	var local := to_local(at)
	_restrooms.call("update_effects",local)
	return str(_restrooms.call("encounter",local))

func breakroom_reachable(at: Vector3) -> bool:
	return _prologue_active and at.is_finite() and at.distance_to(to_global(BREAKROOM_POINT))<1.35

func mark_breakroom_seen() -> void:
	_breakroom_seen=true

func update_public_light(at: Vector3) -> void:
	var active := at.is_finite() and at.distance_squared_to(ENTRY)<81.0
	if _lobby_active==active:
		return
	_lobby_active=active
	if is_instance_valid(_lobby_light):
		_lobby_light.visible=active or _prologue_active

func public_checkpoint_reachable(at: Vector3) -> bool:
	return at.is_finite() and at.distance_to(to_global(LOBBY_CHECKPOINT))<1.5

func begin_prologue() -> void:
	_prologue_active=true
	_restrooms.call("begin_visit")
	_errand_phase=0
	_folder_desk.position=Vector3(4.05,1.10,1.93)
	_folder_desk.show()
	_breakroom_seen=false
	if not is_instance_valid(_cast):
		_build_cast()
	_target_sign.show()
	_intro_canvas.show()
	for light in find_children("*","OmniLight3D",true,false):
		light.show()
	set_stage(-2)

func finish_prologue() -> void:
	_prologue_active=false
	_restrooms.call("end_visit")
	_arrival=null
	_arrival_canvas.hide()
	_set_gate_open(false)
	_clear_folder()
	_folder_desk.hide()
	end_dialogue()
	_target_sign.hide()
	_intro_canvas.hide()
	if is_instance_valid(_cast):
		_cast.queue_free()
		_cast = null
	_assistant = null
	_ceo = null
	_hr = null
	for light in find_children("*","OmniLight3D",true,false):
		light.hide()
	_lobby_light.visible=_lobby_active

static func entrance_reachable(at: Vector3) -> bool:
	return at.is_finite() and at.distance_to(ENTRY) < 3.0

func _build_cast() -> void:
	_cast = Node3D.new()
	_cast.name = "OpeningCast"
	add_child(_cast)
	_ceo = Patron.new()
	_ceo.call("configure",{"id":"jetson_wang","role":"Chief Executive Officer","activity":"CHAT","seated":true,"palette":2,"phase":1.2})
	_ceo.position = Vector3(5,0,-6.65)
	_cast.add_child(_ceo)
	_assistant = Assistant.new()
	_assistant.name = "LinXue"
	_assistant.position = Vector3(7.1,0,-5.8)
	_assistant.scale = Vector3.ONE*.88
	_cast.add_child(_assistant)
	_hr = Patron.new()
	_hr.call("configure",{"id":"people_ops","role":"People Experience","activity":"SCROLL","seated":true,"palette":4,"phase":2.1})
	_hr.position = Vector3(-5,0,-6.65)
	_cast.add_child(_hr)
	for spec in [{"id":"dev","role":"Platform engineer","palette":1,"position":Vector3(-5.35,0,9.18)},{"id":"rina","role":"QA analyst","palette":3,"position":Vector3(-3.1,0,9.18)}]:
		var coworker:=Patron.new()
		coworker.call("configure",{"id":spec["id"],"role":spec["role"],"activity":"CHAT","seated":false,"palette":spec["palette"]})
		coworker.position=spec["position"]
		coworker.rotation.y=PI
		coworker.process_mode=Node.PROCESS_MODE_ALWAYS
		_cast.add_child(coworker)
	# Department staff remain at authored standing anchors, not in circulation lanes.
	for spec in [{"id":"mika","role":"IP Security supervisor","palette":0,"position":Vector3(6.35,0,2.65),"yaw":-PI/2},{"id":"eli","role":"IT support technician","palette":2,"position":Vector3(-6.75,0,3.55),"yaw":PI/2},{"id":"security","role":"Lobby security","palette":4,"position":Vector3(3.5,0,-8.75),"yaw":-PI/2}]:
		var staff:=Patron.new()
		staff.call("configure",{"id":spec["id"],"role":spec["role"],"activity":"CHAT","seated":false,"palette":spec["palette"]})
		staff.position=spec["position"]
		staff.rotation.y=spec["yaw"]
		_cast.add_child(staff)
	for actor in [_ceo,_assistant,_hr]:
		actor.process_mode = Node.PROCESS_MODE_ALWAYS
	for sign in [_sign("JETSON WANG / CEO",Vector3(5,2.55,-6.65),.0045),_sign("LIN XUE / EXECUTIVE ASSISTANT",Vector3(7.1,2.35,-5.8),.004),_sign("PEOPLE EXPERIENCE",Vector3(-5,2.55,-6.65),.0045)]:
		sign.reparent(_cast,false)

func dialogue_camera(camera: Camera3D,stage: int,beat: int) -> void:
	var from := Vector3(4.0,1.85,-2.7)
	var toward := Vector3(6.4,1.6,-6.25)
	if stage == 4:
		from = Vector3(-6.9,1.8,-2.7)
		toward = Vector3(-4.4,1.55,-6.25)
	elif beat == 1:
		from = Vector3(5.6,1.85,-3.7)
		toward = Vector3(7.1,1.6,-5.8)
	camera.global_position = to_global(from)
	camera.look_at(to_global(toward),Vector3.UP)
	_assistant.call("set_phone_call",stage==2 and beat==1)

func breakroom_camera(camera: Camera3D) -> void:
	camera.global_position=to_global(Vector3(-6.1,1.9,5.0))
	camera.look_at(to_global(Vector3(-3.7,1.5,8.7)),Vector3.UP)

func end_dialogue() -> void:
	if is_instance_valid(_assistant):
		_assistant.call("set_phone_call",false)

func _material(key: String,tint: Color,emissive: bool=false) -> StandardMaterial3D:
	if not _mat.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = .82
		if emissive:
			material.emission_enabled = true
			material.emission = tint
			material.emission_energy_multiplier = .55
		_mat[key] = material
	return _mat[key]

func _visual(id: String,at: Vector3,size: Vector3,mat: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	add_child(instance)

func _solid(id: String,at: Vector3,size: Vector3,mat: Material) -> void:
	_visual(id,at,size,mat)
	_collision(id,at,size)

func _collision(id: String,at: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = id+"Collision"
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _sign(value: String,at: Vector3,pixel: float) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.font_size = 40
	label.pixel_size = pixel
	label.outline_size = 3
	add_child(label)
	return label

func _build_arrival_canvas() -> void:
	_arrival_canvas = CanvasLayer.new()
	_arrival_canvas.layer = 6
	add_child(_arrival_canvas)
	for top in [true,false]:
		var bar := ColorRect.new()
		bar.color=Color("080b10")
		bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		bar.anchor_right=1.0
		bar.anchor_top=0.0 if top else 1.0
		bar.anchor_bottom=bar.anchor_top
		bar.offset_top=0.0 if top else -74.0
		bar.offset_bottom=74.0 if top else 0.0
		_arrival_canvas.add_child(bar)
	_arrival_caption=Label.new()
	_arrival_caption.anchor_left=.0
	_arrival_caption.anchor_right=1.0
	_arrival_caption.anchor_top=1.0
	_arrival_caption.anchor_bottom=1.0
	_arrival_caption.offset_top=-69.0
	_arrival_caption.offset_bottom=-30.0
	_arrival_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_arrival_caption.add_theme_font_size_override("font_size",22)
	_arrival_canvas.add_child(_arrival_caption)
	var skip := Label.new()
	skip.text="INTERACT / SKIP"
	skip.anchor_left=1.0
	skip.anchor_right=1.0
	skip.offset_left=-220
	skip.offset_top=22
	skip.add_theme_font_size_override("font_size",16)
	_arrival_canvas.add_child(skip)
	_arrival_canvas.hide()

func _set_gate_open(value: bool) -> void:
	if _gate_open==value:
		return
	_gate_open=value
	get_node("SecurityGate").visible=not value
	get_node("SecurityGateCollision").get_child(0).set_deferred("disabled",value)
	for child in get_node("ArchitecturalFinish").get_children():
		if str(child.name).begins_with("gate_"):
			child.visible=not value

func start_arrival(player: Node3D,camera: Camera3D) -> void:
	_arrival=Arrival.new()
	_desk_beat_played=false
	_arrival_fov=camera.fov
	player.set("input_blocked",true)
	_intro_canvas.hide()
	_target_sign.hide()
	_arrival_canvas.show()
	tick_arrival(0.0,player,camera)

func arrival_active() -> bool:
	return _arrival!=null

func tick_arrival(delta: float,player: Node3D,camera: Camera3D) -> bool:
	if _arrival==null:
		return false
	if not _arrival.call("advance",delta):
		finish_arrival(player,camera)
		return false
	var shot: Dictionary=_arrival.call("sample")
	player.global_position=to_global(shot["position"])
	player.set("velocity",Vector3.ZERO)
	var motion: Vector3=shot["motion"]
	var visual: Node3D=player.get("visual")
	if is_instance_valid(visual):
		if motion.length_squared()>.01:
			visual.rotation.y=atan2(motion.x,motion.z)
		elif bool(shot["desk"]):
			visual.rotation.y=PI
		visual.call("update_motion",visual.global_basis.inverse()*motion,true,false,false,false)
		if bool(shot["desk"]) and motion.length_squared()<.01 and not _desk_beat_played:
			_desk_beat_played=true
			player.call("play_visual_action",&"interact")
	_set_gate_open(bool(shot["gate_open"]))
	camera.global_position=to_global(shot["camera"])
	camera.look_at(to_global(shot["look"]),Vector3.UP)
	camera.fov=60.0
	_arrival_caption.text=shot["caption"]
	return true

func finish_arrival(player: Node3D,camera: Camera3D) -> void:
	if _arrival==null:
		return
	_arrival=null
	_set_gate_open(false)
	camera.fov=_arrival_fov
	player.global_position=to_global(CUBICLE_POINT)
	player.set("velocity",Vector3.ZERO)
	player.set("input_blocked",false)
	var visual: Node3D=player.get("visual")
	if is_instance_valid(visual):
		visual.rotation.y=PI
		visual.call("update_motion",Vector3.ZERO,true,false,false,false)
	_arrival_canvas.hide()
	_intro_canvas.show()
	_target_sign.show()
	set_stage(-2)

func objective_stage(story_stage: int) -> int:
	return -2 if _errand_phase==0 else (-1 if _errand_phase==1 else story_stage)

func errand_complete() -> bool:
	return _errand_phase==2

func _make_folder() -> Node3D:
	var folder := Node3D.new()
	folder.name="AuditFolder"
	for spec in [
		{"size":Vector3(.245,.012,.315),"at":Vector3.ZERO,"color":"b69b6c"},
		{"size":Vector3(.224,.016,.288),"at":Vector3(0,.014,0),"color":"e2e0d7"},
		{"size":Vector3(.245,.009,.315),"at":Vector3(0,.029,0),"color":"b69b6c"},
		{"size":Vector3(.092,.006,.042),"at":Vector3(.065,.035,-.095),"color":"b54c4b"}
	]:
		var part := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size=spec["size"]
		part.mesh=mesh
		part.position=spec["at"]
		part.material_override=_material("folder_"+str(spec["color"]),Color(spec["color"]))
		part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		folder.add_child(part)
	return folder

func _clear_folder() -> void:
	if is_instance_valid(_folder_hand):
		_folder_hand.hide()
		_folder_hand.queue_free()
	_folder_hand=null
	_folder=null

func try_errand(player: Node3D) -> bool:
	if _arrival!=null or _errand_phase>=2 or not reachable(objective_stage(0),player.global_position):
		return false
	if _errand_phase==0:
		_folder_desk.hide()
		var visual: Node3D=player.get("visual")
		var skel: Skeleton3D=visual.get("skeleton") if is_instance_valid(visual) else null
		if skel!=null and skel.find_bone("LeftHand")>=0:
			_folder_hand=BoneAttachment3D.new()
			_folder_hand.name="SynaxisFolderHand"
			_folder_hand.bone_name="LeftHand"
			skel.add_child(_folder_hand)
			_folder=_make_folder()
			_folder.position=Vector3(0,.03,.10)
			_folder.rotation.z=PI/2
			_folder_hand.add_child(_folder)
		_errand_phase=1
	else:
		_clear_folder()
		_folder_desk.position=Vector3(-5.15,1.10,2.88)
		_folder_desk.show()
		_errand_phase=2
	player.call("play_visual_action",&"interact")
	set_stage(objective_stage(0))
	return true

func point(stage: int) -> Vector3:
	return to_global(POINTS.get(stage,Vector3.INF))

func reachable(stage: int,at: Vector3) -> bool:
	return POINTS.has(stage) and at.distance_to(point(stage)) <= 1.8

func set_stage(stage: int) -> void:
	if not POINTS.has(stage):
		return
	_target_sign.position = POINTS[stage]+Vector3.UP*1.15
	_target_sign.text = TITLES[stage]

func update_prompt(stage: int,at: Vector3,gamepad: bool) -> void:
	if not POINTS.has(stage):
		return
	var local := to_local(at)
	var goal: Vector3=POINTS[stage]
	_radar.call("set_office_state",Vector2(local.x,local.z),Vector2(goal.x,goal.z))
	_hint.text = "SYNAXIS / EXECUTIVE PRIVILEGE\n%s" % TITLES[stage]
	if stage==-2:
		_hint.text += "\nMika: Take the sealed access-control request to Eli in IT."
	elif stage==-1:
		_hint.text += "\nEli can verify the authorization records across the aisle."
	if reachable(stage,at):
		_hint.text += "\n"+("X / INTERACT" if gamepad else "G / INTERACT")
	if breakroom_reachable(at) and not _breakroom_seen:
		_hint.text += "\n" + ("X" if gamepad else "G") + " / OPTIONAL: BREAKROOM PARTY"
