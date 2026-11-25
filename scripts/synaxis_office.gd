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
const Staff = preload("res://scripts/synaxis_staff.gd")
const Interviews = preload("res://scripts/synaxis_interviews.gd")
const Cast = preload("res://scripts/synaxis_cast.gd")
var _staff: Dictionary = {}
var _near_staff := ""
var _staff_remark := ""
var _staff_phase := -1
const Assistant = preload("res://scripts/synaxis_assistant.gd")
const Propaganda = preload("res://scripts/synaxis_propaganda.gd")
const Brand = preload("res://scripts/synaxis_brand.gd")
const Finish = preload("res://scripts/synaxis_office_finish.gd")
const FounderParking=preload("res://scripts/synaxis_founder_parking.gd")
const Radar = preload("res://scripts/hud_radar.gd")
const Arrival = preload("res://scripts/synaxis_arrival.gd")
const Restrooms = preload("res://scripts/synaxis_restrooms.gd")
const Workfloor = preload("res://scripts/synaxis_workfloor.gd")
const ExecutiveFloor = preload("res://scripts/synaxis_executive_floor.gd")
const Basement = preload("res://scripts/synaxis_basement.gd")
var _basement:Node3D
var _executive_floor: Node3D
var _workfloors: Array[Node3D]=[]
var _active_floor:=0
const GeneratedAudio=preload("res://scripts/synaxis_generated_audio.gd")
var _ground_ambience:AudioStreamPlayer3D
var _lift_audio:AudioStreamPlayer3D
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
const POINTS = {-2:CUBICLE_POINT,-1:Vector3(-5,1.15-Workfloor.FLOOR_HEIGHT,4),0:Vector3(-5,1.15-Workfloor.FLOOR_HEIGHT,4),2:ExecutiveFloor.CEO_GOAL+Vector3.UP*ExecutiveFloor.BASE,4:ExecutiveFloor.HR_GOAL+Vector3.UP*ExecutiveFloor.BASE,5:Vector3(5,1.15,5)}
const TITLES = {-2:"CORPORATE IP SECURITY / COLLECT THE FOLDER",-1:"B1 IT DEPARTMENT / DROP OFF THE FOLDER",0:"B1 IT DESK / REVIEW THE ALERT",2:"EXECUTIVE OFFICE / ATTEND BRIEFING",4:"PEOPLE EXPERIENCE / EXIT INTERVIEW",5:"RECEPTION / COLLECT FINAL NOTICE"}
var _target_sign: Label3D
var _hint: Label
var _mat: Dictionary = {}

func _ready() -> void:
	var floor_mat := _material("floor",Color("34414a"))
	var wall := _material("wall",Color("c6c9c5"))
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
	_solid("TowerCore",Vector3(0,32.85,0),Vector3(17,29.2,20),_material("glass",Color("354c60")))
	_build_workfloor_shell(wall,floor_mat)
	var parking:=FounderParking.new()
	parking.name="FounderParking"
	add_child(parking)
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
	_ground_ambience=GeneratedAudio.emitter(self,"office_air",Vector3(0,1,1),-22.0,16.0,true)
	_lift_audio=GeneratedAudio.emitter(self,"lift_chime",Vector3(0,1.2,5),-13.0,8.0)
	_build_arrival_canvas()
	set_stage(0)
	_target_sign.hide()
	_intro_canvas.hide()
	# Ground-floor furniture and collision remain; stage lighting is local.
	for light in find_children("*","OmniLight3D",true,false):
		light.hide()

func _build_workfloor_shell(wall: Material,floor_mat: Material) -> void:
	for level in range(1,Workfloor.FLOOR_COUNT+1):
		var base:=level*Workfloor.FLOOR_HEIGHT
		# Ground ceiling already serves as level 1's floor slab.
		if level>1:
			_solid("UpperSlab",Vector3(0,base-.15,0),Vector3(17,.3,20),floor_mat)
		for side in [-1.0,1.0]:
			_solid("UpperSide",Vector3(side*8.5,base+1.675,0),Vector3(.25,3.35,20),wall)
			_solid("UpperEnd",Vector3(0,base+1.675,side*10),Vector3(17,3.35,.25),wall)
	# Crown suite sits at the top of the retained exterior tower core.
	var top:=ExecutiveFloor.BASE
	_solid("CrownSuiteSlab",Vector3(0,top-.15,0),Vector3(17,.3,20),floor_mat)
	_solid("CrownSuiteCeiling",Vector3(0,top+3.5,0),Vector3(17,.3,20),wall)
	_solid("CrownWest",Vector3(-8.5,top+1.675,0),Vector3(.25,3.35,20),wall)
	for side in [-1.0,1.0]:
		_solid("CrownEnd",Vector3(0,top+1.675,side*10),Vector3(17,3.35,.25),wall)
	_solid("CrownEastUtility",Vector3(8.5,top+1.675,4.65),Vector3(.25,3.35,10.7),wall)
	# Real transparent glazing on the skyline side, leaving a full-height terrace doorway.
	var clear:=StandardMaterial3D.new()
	clear.albedo_color=Color(.53,.69,.74,.17)
	clear.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness=.15
	for interval in [Vector2(-10,-5),Vector2(-3,-.7)]:
		var bounds:Vector2=interval
		_solid("CrownWindow",Vector3(8.5,top+1.675,(bounds.x+bounds.y)*.5),Vector3(.10,3.35,bounds.y-bounds.x),clear)
	_solid("CrownDoorHeader",Vector3(8.5,top+3.07,-4),Vector3(.25,.56,2),wall)
	_solid("CrownTerraceSlab",Vector3(9.85,top-.15,-5),Vector3(2.7,.3,7.4),floor_mat)
	# Outside the terrace extent, retain a barrier to prevent stepping into the void.
	_collision("CrownCornerGuard",Vector3(8.5,top+1.675,-9.35),Vector3(.10,3.35,1.3))
	for side in [-1.0,1.0]:
		_visual("GroundLiftPad",Vector3(side*.9,.018,5),Vector3(.78,.016,.82),_material("liftpad",Color("457d79")))
	_sign("LIFT UP / OFFICE FLOORS",Vector3(-.9,1.85,5.48),.003)
	_sign("LIFT DOWN / BASEMENT IT",Vector3(.9,1.85,5.48),.003)
	var utility:=_material("basement_concrete",Color("637078"))
	_solid("BasementSlab",Vector3(0,-Workfloor.FLOOR_HEIGHT-.15,0),Vector3(17,.3,20),utility)
	for side in [-1.0,1.0]:
		_solid("BasementSide",Vector3(side*8.5,-Workfloor.FLOOR_HEIGHT+1.675,0),Vector3(.25,3.35,20),utility)
		_solid("BasementEnd",Vector3(0,-Workfloor.FLOOR_HEIGHT+1.675,side*10),Vector3(17,3.35,.25),utility)

func _ensure_workfloors() -> void:
	if not _workfloors.is_empty():
		return
	for level in range(1,Workfloor.FLOOR_COUNT+1):
		var deck:=Workfloor.new()
		deck.level=level
		deck.name="Workfloor%d" % level
		deck.position.y=level*Workfloor.FLOOR_HEIGHT
		add_child(deck)
		_workfloors.append(deck)
	_basement=Basement.new()
	_basement.name="BasementIT"
	_basement.position.y=-Workfloor.FLOOR_HEIGHT
	add_child(_basement)
	_executive_floor=ExecutiveFloor.new()
	_executive_floor.name="ExecutiveFloor"
	_executive_floor.position.y=ExecutiveFloor.FLOOR*Workfloor.FLOOR_HEIGHT
	add_child(_executive_floor)

func executive_floor_stats() -> Dictionary:
	return _executive_floor.call("executive_stats") if is_instance_valid(_executive_floor) else {}

func workfloor_stats() -> Array[Dictionary]:
	var results: Array[Dictionary]=[]
	for deck in _workfloors:
		results.append(deck.call("get_floor_stats"))
	return results

func _select_floor(level: int) -> void:
	_active_floor=clampi(level,Basement.FLOOR,ExecutiveFloor.FLOOR)
	GeneratedAudio.activate(_ground_ambience,_prologue_active and _active_floor==0)
	for child in get_children():
		if child is OmniLight3D:
			child.visible=_prologue_active and _active_floor==0
	for i in _workfloors.size():
		_workfloors[i].call("set_occupied",_prologue_active and _active_floor==i+1)
	if is_instance_valid(_executive_floor):
		_executive_floor.call("set_occupied",_prologue_active and _active_floor==ExecutiveFloor.FLOOR)
	if is_instance_valid(_basement):
		_basement.call("set_occupied",_prologue_active and _active_floor==Basement.FLOOR)
	for id in _staff:
		var actor:Node3D=_staff[id]
		var occupied:bool=_prologue_active and _active_floor==staff_floor(id)
		actor.visible=occupied
		actor.process_mode=Node.PROCESS_MODE_ALWAYS if occupied else Node.PROCESS_MODE_DISABLED
		if not occupied:
			actor.call("attend",Vector3.ZERO,false)
	if is_instance_valid(_assistant):
		_assistant.visible=_prologue_active and _active_floor==ExecutiveFloor.FLOOR
		_assistant.process_mode=Node.PROCESS_MODE_ALWAYS if _assistant.visible else Node.PROCESS_MODE_DISABLED
	_target_sign.visible=_prologue_active and absf(_target_sign.position.y-2.30-_active_floor*Workfloor.FLOOR_HEIGHT)<.1

func lift_direction(at: Vector3) -> int:
	if not _prologue_active or _arrival!=null:
		return 0
	var local:=to_local(at)
	if absf(local.y-(_active_floor*Workfloor.FLOOR_HEIGHT+1.15))>.8:
		return 0
	if _active_floor<ExecutiveFloor.FLOOR and Vector2(local.x,local.z).distance_to(Workfloor.LIFT+Vector2(-.9,0))<.73:
		return 1
	if _active_floor>Basement.FLOOR and Vector2(local.x,local.z).distance_to(Workfloor.LIFT+Vector2(.9,0))<.73:
		return -1
	return 0

func try_lift(player: CharacterBody3D) -> bool:
	var direction:=lift_direction(player.global_position)
	if direction==0:
		return false
	var destination:=_active_floor+direction
	if direction>0 and _active_floor==Workfloor.FLOOR_COUNT:
		destination=ExecutiveFloor.FLOOR
	elif direction<0 and _active_floor==ExecutiveFloor.FLOOR:
		destination=Workfloor.FLOOR_COUNT
	_select_floor(destination)
	player.global_position=to_global(Vector3(0,_active_floor*Workfloor.FLOOR_HEIGHT+1.15,Workfloor.LIFT.y))
	player.velocity=Vector3.ZERO
	if is_instance_valid(_lift_audio):
		_lift_audio.position.y=_active_floor*Workfloor.FLOOR_HEIGHT+1.2
		_lift_audio.play()
	return true

func recovery_floor() -> float:
	return global_position.y+_active_floor*Workfloor.FLOOR_HEIGHT-2.0

func recovery_position() -> Vector3:
	return to_global(CUBICLE_POINT if _active_floor==0 else Vector3(0,_active_floor*Workfloor.FLOOR_HEIGHT+1.15,Workfloor.LIFT.y))

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
	# Ground floor former IT alcove is now a records and compliance station.
	for x in [-7.55,-6.7]:
		_solid("RecordsCabinet",Vector3(x,1.07,.7),Vector3(.72,2.14,.85),desk)
		for row in range(4):
			_visual("FileDrawer",Vector3(x,.35+row*.50,1.14),Vector3(.63,.43,.035),accent)
			_visual("FileHandle",Vector3(x,.40+row*.50,1.17),Vector3(.21,.035,.025),desk)
	_sign("RECORDS / COMPLIANCE\nIT SUPPORT HAS MOVED TO B1",Vector3(-5.55,1.65,2.54),.0018)
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
	update_parking_guard(at)
	var active := at.is_finite() and at.distance_squared_to(ENTRY)<81.0
	if _lobby_active==active:
		return
	_lobby_active=active
	if is_instance_valid(_lobby_light):
		_lobby_light.visible=active or _prologue_active

func parking_guard_reachable(at:Vector3) -> bool:
	var parking:=get_node_or_null("FounderParking")
	return is_instance_valid(parking) and bool(parking.call("guard_reachable",at))

func update_parking_guard(at:Vector3) -> void:
	var parking:=get_node_or_null("FounderParking")
	if is_instance_valid(parking):
		parking.call("update_guard",at)

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
	_ensure_workfloors()
	_select_floor(0)
	set_stage(-2)

func finish_prologue() -> void:
	_prologue_active=false
	_select_floor(0)
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
	_staff.clear()
	_near_staff=""
	_staff_remark=""
	_staff_phase=-1
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
	_staff.clear()
	for spec in Cast.STAFF:
		var actor:=Staff.new()
		actor.configure_staff(spec)
		actor.position=spec["position"]
		if spec["id"]=="jetson_wang":
			actor.position=ExecutiveFloor.CEO_ANCHOR+Vector3.UP*ExecutiveFloor.BASE
		elif spec["id"]=="people_ops":
			actor.position=ExecutiveFloor.HR_ANCHOR+Vector3.UP*ExecutiveFloor.BASE
		actor.rotation.y=float(spec["yaw"])
		actor.process_mode=Node.PROCESS_MODE_ALWAYS
		_cast.add_child(actor)
		_staff[spec["id"]]=actor
	_ceo=_staff["jetson_wang"]
	_hr=_staff["people_ops"]
	_assistant=Assistant.new()
	_assistant.name="LinXue"
	_assistant.position=ExecutiveFloor.ASSISTANT_ANCHOR+Vector3.UP*ExecutiveFloor.BASE
	_assistant.scale=Vector3.ONE*.88
	_assistant.process_mode=Node.PROCESS_MODE_ALWAYS
	_cast.add_child(_assistant)
	for sign in [_sign("JETSON WANG / CEO",ExecutiveFloor.CEO_ANCHOR+Vector3.UP*(ExecutiveFloor.BASE+2.55),.0045),_sign("LIN XUE / EXECUTIVE ASSISTANT",ExecutiveFloor.ASSISTANT_ANCHOR+Vector3.UP*(ExecutiveFloor.BASE+2.35),.004),_sign("PEOPLE EXPERIENCE",ExecutiveFloor.HR_ANCHOR+Vector3.UP*(ExecutiveFloor.BASE+2.55),.0045)]:
		sign.reparent(_cast,false)

func dialogue_camera(camera: Camera3D,stage: int,beat: int) -> void:
	var from := Vector3(3.2,1.95,-3.85)
	var toward := ExecutiveFloor.CEO_ANCHOR+Vector3.UP*1.55
	if stage == 4:
		from = Vector3(-7.3,1.85,3.9)
		toward = ExecutiveFloor.HR_ANCHOR+Vector3.UP*1.55
	elif beat == 1:
		from = Vector3(5.9,1.85,-3.65)
		toward = ExecutiveFloor.ASSISTANT_ANCHOR+Vector3.UP*1.55
	camera.global_position = to_global(from+Vector3.UP*ExecutiveFloor.BASE)
	camera.look_at(to_global(toward+Vector3.UP*ExecutiveFloor.BASE),Vector3.UP)
	_assistant.call("set_phone_call",stage==2 and beat==1)
	if is_instance_valid(_ceo):
		_ceo.call("set_scene_beat",beat if stage==2 else -1)
	if is_instance_valid(_hr):
		_hr.call("set_scene_beat",2 if stage==4 else -1)

func breakroom_camera(camera: Camera3D) -> void:
	camera.global_position=to_global(Vector3(-6.1,1.9,5.0))
	camera.look_at(to_global(Vector3(-3.7,1.5,8.7)),Vector3.UP)

func end_dialogue() -> void:
	if is_instance_valid(_assistant):
		_assistant.call("set_phone_call",false)
	for actor in _staff.values():
		actor.call("set_scene_beat",-1)

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
		_folder_desk.position=Vector3(-5.15,1.10-Workfloor.FLOOR_HEIGHT,2.88)
		_folder_desk.show()
		_errand_phase=2
	player.call("play_visual_action",&"interact")
	set_stage(objective_stage(0))
	return true

func point(stage: int) -> Vector3:
	return to_global(POINTS.get(stage,Vector3.INF))

func reachable(stage: int,at: Vector3) -> bool:
	return POINTS.has(stage) and _active_floor==objective_floor(stage) and at.distance_to(point(stage)) <= 1.8

func objective_floor(stage:int) -> int:
	if stage in [2,4]:
		return ExecutiveFloor.FLOOR
	return Basement.FLOOR if stage in [-1,0] else 0

func staff_floor(id:String) -> int:
	if id in ["jetson_wang","people_ops"]:
		return ExecutiveFloor.FLOOR
	return Basement.FLOOR if id=="eli" else 0

func set_stage(stage: int) -> void:
	if not POINTS.has(stage):
		return
	_target_sign.position = POINTS[stage]+Vector3.UP*1.15
	_target_sign.text = TITLES[stage]
	_target_sign.visible=_prologue_active and _active_floor==objective_floor(stage)

func update_staff_attention(stage: int,at: Vector3) -> String:
	if not _prologue_active or _arrival!=null or not at.is_finite():
		return ""
	var closest := ""
	var best := 2.25*2.25
	for id in _staff:
		var actor: Node3D=_staff[id]
		if _active_floor!=staff_floor(id):
			continue
		var distance:=actor.global_position.distance_squared_to(at-Vector3.UP*1.15)
		# Avoid talking through executive partitions or across the locked gate.
		var local:=to_local(at)
		var anchor:=actor.position
		if _active_floor==0 and (local.z< -7.65)!=(anchor.z< -7.65):
			continue
		if _active_floor==0 and local.z>Arrival.PARTITION_NEAR_Z and local.z<Arrival.PARTITION_FAR_Z and anchor.z>Arrival.PARTITION_NEAR_Z and anchor.z<Arrival.PARTITION_FAR_Z and local.x*anchor.x<0.0:
			continue
		if distance<best:
			closest=id
			best=distance
	var phase:=0 if stage< -1 else (1 if stage<4 else 2)
	if closest!=_near_staff or phase!=_staff_phase:
		_near_staff=closest
		_staff_phase=phase
		_staff_remark="" if closest.is_empty() else "%s: %s" % [_staff[closest].get("display_name"),Cast.remark(closest,phase)]
	for id in _staff:
		_staff[id].call("attend",at,id==closest)
	return _staff_remark

func update_prompt(stage: int,at: Vector3,gamepad: bool) -> void:
	if not POINTS.has(stage):
		return
	update_parking_guard(at)
	var local := to_local(at)
	var goal: Vector3=POINTS[stage]
	_radar.call("set_office_state",Vector2(local.x,local.z),Vector2(goal.x,goal.z) if _active_floor==objective_floor(stage) else Workfloor.LIFT,_active_floor)
	if _active_floor==Basement.FLOOR:
		_hint.text="SYNAXIS / "+Basement.TITLE+"\n"+TITLES[stage]
		if objective_floor(stage)!=Basement.FLOOR:
			_hint.text+="\nReturn to ground floor via the lift."
		elif reachable(stage,at):
			_hint.text+="\n"+("X / INTERACT" if gamepad else "G / INTERACT")
		if lift_direction(at)!=0:
			_hint.text+="\n"+("X" if gamepad else "G")+" / LIFT UP"
		var eli_line:=update_staff_attention(stage,at)
		if not eli_line.is_empty():
			_hint.text+="\n"+eli_line
		return
	if _active_floor>0:
		var department: String=ExecutiveFloor.TITLE if _active_floor==ExecutiveFloor.FLOOR else Workfloor.DEPARTMENTS[_active_floor-1]
		_hint.text="SYNAXIS / LEVEL %d / %s\n%s" % [_active_floor+1,department,TITLES[stage]]
		if reachable(stage,at):
			_hint.text+="\n"+("X / INTERACT" if gamepad else "G / INTERACT")
		elif objective_floor(stage)!=_active_floor:
			_hint.text+="\nUse the lift."
		if _active_floor==ExecutiveFloor.FLOOR and is_instance_valid(_executive_floor):
			var executive_line: String=_executive_floor.call("staff_remark",at,stage)
			if executive_line.is_empty():
				executive_line=update_staff_attention(stage,at)
			if not executive_line.is_empty():
				_hint.text+="\n"+executive_line
		if _active_floor<=Workfloor.FLOOR_COUNT:
			var worker_line:String=_workfloors[_active_floor-1].call("observe_worker",at)
			if not worker_line.is_empty():
				_hint.text+="\n"+worker_line
		var interview:=interview_at(at,stage)
		if not interview.is_empty() and not reachable(stage,at):
			_hint.text+="\n"+("X" if gamepad else "G")+" / TALK TO "+str(interview["name"])
		var direction:=lift_direction(at)
		if direction!=0:
			_hint.text+="\n"+("X" if gamepad else "G")+" / LIFT "+("UP" if direction>0 else "DOWN")
		return
	_hint.text = "SYNAXIS / EXECUTIVE PRIVILEGE\n%s" % TITLES[stage]
	if stage==-2:
		_hint.text += "\nMika: Take the sealed access-control request to Eli in IT."
	elif stage==-1:
		_hint.text += "\nTake the lift down to B1. Eli can verify the authorization records."
	if reachable(stage,at):
		_hint.text += "\n"+("X / INTERACT" if gamepad else "G / INTERACT")
	if breakroom_reachable(at) and not _breakroom_seen:
		_hint.text += "\n" + ("X" if gamepad else "G") + " / OPTIONAL: BREAKROOM PARTY"
	var lift:=lift_direction(at)
	if lift!=0:
		_hint.text+="\n"+("X" if gamepad else "G")+(" / LIFT UP / WORKFLOORS" if lift>0 else " / LIFT DOWN / BASEMENT IT")
	if parking_guard_reachable(at):
		_hint.text+="\n"+("X" if gamepad else "G")+" / TALK TO PARKING SECURITY"
	var remark:=update_staff_attention(stage,at)
	if not remark.is_empty():
		_hint.text += "\n"+remark

func interview_at(at:Vector3,stage:int) -> Dictionary:
	if not _prologue_active or _arrival!=null or not at.is_finite():
		return {}
	var id: String=""
	if _active_floor==ExecutiveFloor.FLOOR and is_instance_valid(_executive_floor):
		id=str(_executive_floor.call("executive_interview_id",at,stage))
	elif _active_floor>=1 and _active_floor<=_workfloors.size():
		id=str(_workfloors[_active_floor-1].call("interview_id",at))
	return Interviews.conversation(id,stage)
