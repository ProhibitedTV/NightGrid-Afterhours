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
const STAFF_EXIT=Vector3(-8.5,1.15,4.5)
var _staff_exit_open:=false
var _lobby_light: OmniLight3D
var _lobby_active := false
var _prologue_active := false
const CreatorCast = preload("res://scripts/synaxis_creator_cast.gd")
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
const LiftTransition=preload("res://scripts/synaxis_lift_transition.gd")
const LiftFrontage=preload("res://scripts/synaxis_lift_frontage.gd")
const GroundLayout=preload("res://scripts/synaxis_ground_layout.gd")
const BreakroomArt = preload("res://scripts/synaxis_breakroom.gd")
const Equipment = preload("res://scripts/synaxis_equipment.gd")
var _lift_transition:CanvasLayer
var _lift_target:=0
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
var _exit_phase:=0
var _returned_kit:Node3D
var _personal_bag:Node3D
var _assistant: Node3D
var _ceo: Node3D
var _hr: Node3D
const START = Vector3(0,1.15,4.9)
const BREAKROOM_POINT = Vector3(-4.2,1.15,6.85)
var _breakroom_seen := false
const POINTS = {-2:CUBICLE_POINT,-1:Vector3(-5,1.15-Workfloor.FLOOR_HEIGHT,4),0:Vector3(-5,1.15-Workfloor.FLOOR_HEIGHT,4),2:ExecutiveFloor.CEO_GOAL+Vector3.UP*ExecutiveFloor.BASE,4:ExecutiveFloor.HR_GOAL+Vector3.UP*ExecutiveFloor.BASE,5:Vector3(5,1.15,5),6:Vector3(5,1.15,5),7:CUBICLE_POINT,8:Vector3(0,1.15,-12.32)}
const TITLES = {-2:"CORPORATE IP SECURITY / COLLECT THE FOLDER",-1:"B1 IT DEPARTMENT / DROP OFF THE FOLDER",0:"B1 IT DESK / REVIEW THE ALERT",2:"EXECUTIVE OFFICE / ATTEND BRIEFING",4:"PEOPLE EXPERIENCE / EXIT INTERVIEW",5:"RECEPTION / COLLECT FINAL NOTICE",6:"RECEPTION / RETURN LAPTOP AND BADGE",7:"DESK 04 / COLLECT PERSONAL BELONGINGS",8:"EXIT / LEAVE SYNAXIS"}
var _hint: Label
var _mat: Dictionary = {}

func _ready() -> void:
	var floor_mat := _material("floor",Color("b4ada1"))
	_configure_stone(floor_mat)
	var wall := _material("wall",Color("d8d4c9"))
	var desk := _material("desk",Color("242e36"))
	var accent := _material("accent",Color("b9cbd0"))
	var screen := _material("screen",Color("508f8d"),true)
	_solid("Floor",Vector3(0,-.15,0),Vector3(17,.3,20),floor_mat)
	_solid("Ceiling",Vector3(0,3.5,0),Vector3(17,.3,20),_material("ceiling",Color("d4d1c7")))
	for side in [-1.0,1.0]:
		_solid("FrontWall",Vector3(side*4.9,1.75,-10),Vector3(7.2,3.5,.25),wall)
	_solid("EntranceHeader",Vector3(0,3.15,-10),Vector3(2.6,.7,.25),wall)
	# Street vestibule is public; a full-width security barrier separates it from the offices.
	for side in [-1.0,1.0]:
		_solid("SecurityFlank",Vector3(side*4.9,1.75,-7.65),Vector3(7.2,3.5,.24),wall)
	_solid("SecurityGate",Vector3(0,1.4,-7.65),Vector3(2.6,2.8,.25),_material("security",Color("293842")))
	_solid("SecurityHeader",Vector3(0,3.15,-7.65),Vector3(2.6,.7,.25),wall)
	_plaque("BADGE ACCESS",Vector3(0,3.02,-7.793),PI,Vector2(1.40,.25))
	Brand.wall_logo(self,"EntranceBrand",Vector3(0,3.12,-10.17),PI,2.15)
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
	_solid("WestWallNorth",Vector3(-8.5,1.75,-3.25),Vector3(.25,3.5,13.5),wall)
	_solid("WestWallSouth",Vector3(-8.5,1.75,7.75),Vector3(.25,3.5,4.5),wall)
	_solid("StaffExitHeader",Vector3(-8.5,3.05,4.5),Vector3(.25,.90,2.0),wall)
	_solid("StaffExitDoor",Vector3(-8.5,1.30,4.5),Vector3(.16,2.60,2.0),desk)
	_visual("StaffExitFrameNorth",Vector3(-8.5,1.30,3.48),Vector3(.29,2.60,.10),accent)
	_visual("StaffExitFrameSouth",Vector3(-8.5,1.30,5.52),Vector3(.29,2.60,.10),accent)
	_plaque("STAFF EXIT / PARKING",Vector3(-8.357,2.85,4.5),PI/2,Vector2(1.72,.24))
	_plaque("STAFF ACCESS",Vector3(-8.643,2.85,4.5),-PI/2,Vector2(1.25,.24))
	_visual("StaffExitReader",Vector3(-8.66,1.18,3.25),Vector3(.065,.18,.12),screen)
	_solid("EastWall",Vector3(8.5,1.75,0),Vector3(.25,3.5,20),wall)
	# Leave a physical turning vestibule behind the security gate.
	var partition_length: float=Arrival.PARTITION_FAR_Z-Arrival.PARTITION_NEAR_Z
	_solid("ExecutivePartition",Vector3(0,1.5,Arrival.PARTITION_NEAR_Z+partition_length*.5),Vector3(.18,3.0,partition_length),wall)
	_build_lobby(accent)
	_build_office_details(desk,accent,screen)
	_build_breakroom()
	_build_ground_wayfinding(wall,accent)
	_build_corporate_relics(desk,accent,screen)
	_restrooms=Restrooms.new()
	_restrooms.name="Restrooms"
	_restrooms.position=Restrooms.OFFSET
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
	_plaque("IP SECURITY / 04",Vector3(5.60,1.39,1.7),-.5*PI,Vector2(.86,.20))
	_folder_desk = _make_folder()
	_folder_desk.position = Vector3(4.05,1.10,1.93)
	add_child(_folder_desk)
	_folder_desk.hide()
	_build_exit_props(desk,accent,screen)
	_visual("ExitBox",Vector3(5,1.25,6.5),Vector3(.42,.34,.4),_material("cardboard",Color("a88a63")))
	# Local pools of light instead of four overlapping omnidirectional washes.
	var diffuser:=_material("light",Color("e9e3d4"),true)
	diffuser.emission_energy_multiplier=.24
	for z in [-7.5,-2.5,2.5,7.5]:
		for x in [-3.7,3.7]:
			_visual("CeilingStrip",Vector3(x,3.28,z),Vector3(3.2,.035,.28),diffuser)
			var light:=SpotLight3D.new()
			light.name="OfficeDownlight"
			light.position=Vector3(x,3.14,z)
			light.rotation.x=-PI/2
			light.spot_range=7.0
			light.spot_angle=65.0
			light.spot_attenuation=1.1
			light.light_color=Color("fff0da")
			light.light_energy=.85
			# Bound shadow passes to four, irrespective of decorative fixtures.
			light.shadow_enabled=(x<0.0)==(z<0.0)
			add_child(light)
	Brand.wall_logo(self,"ReceptionBrand",Vector3(5.2,2.78,9.81),PI,3.65)
	Brand.wall_logo(self,"ExecutiveMark",Vector3(8.30,2.75,-5.9),-PI/2,.72,false,true)
	Brand.wall_logo(self,"ExitCartonMark",Vector3(5,1.25,6.285),PI,.22)
	_plaque("THINK OUTSIDE THE BOX\nBOX SOLD SEPARATELY",Vector3(-8.31,2.58,2.25),PI/2,Vector2(1.45,.38))
	_plaque("PEOPLE EXPERIENCE",Vector3(-8.31,2.94,-5.0),PI/2,Vector2(1.7,.24))
	_plaque("EXECUTIVE AFFAIRS",Vector3(8.31,2.94,-4.9),-PI/2,Vector2(1.7,.24))
	_plaque("RECEPTION / EXIT PROCESSING",Vector3(5.2,2.34,9.81),PI,Vector2(2.40,.26))
	_plaque("ELEVATORS / B1 IT + OFFICES",Vector3(8.31,2.64,4.25),-PI/2,Vector2(2.3,.30))
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
	_lift_transition=LiftTransition.new()
	_lift_transition.name="LiftTransition"
	add_child(_lift_transition)
	set_stage(0)
	_intro_canvas.hide()
	# Ground-floor furniture and collision remain; stage lighting is local.
	for light in find_children("*","Light3D",true,false):
		light.hide()

func _build_exit_props(desk:Material,accent:Material,screen:Material) -> void:
	_returned_kit=Node3D.new()
	_returned_kit.name="ReturnedCompanyEquipment"
	_returned_kit.position=Vector3(4.55,1.10,6.34)
	add_child(_returned_kit)
	# Meshes authored here, parented to the return tray for atomic visibility.
	_exit_prop(_returned_kit,"LaptopBase",Vector3.ZERO,Vector3(.32,.034,.23),desk)
	_exit_prop(_returned_kit,"LaptopLid",Vector3(0,.027,0),Vector3(.32,.018,.23),accent)
	_exit_prop(_returned_kit,"Badge",Vector3(.27,.016,0),Vector3(.10,.025,.072),accent)
	_exit_prop(_returned_kit,"BadgeStripe",Vector3(.27,.030,-.023),Vector3(.095,.005,.02),screen)
	_returned_kit.hide()
	_personal_bag=Node3D.new()
	_personal_bag.name="PersonalBelongings"
	_personal_bag.position=Vector3(4.84,1.12,1.84)
	add_child(_personal_bag)
	var cloth:=_material("personal_bag",Color("5b5d60"))
	_exit_prop(_personal_bag,"FoldedClothing",Vector3.ZERO,Vector3(.32,.14,.25),cloth)
	_exit_prop(_personal_bag,"FoldedShirt",Vector3(0,.075,0),Vector3(.29,.05,.22),accent)
	_exit_prop(_personal_bag,"PersonalNotebook",Vector3(-.20,-.035,0),Vector3(.13,.025,.19),desk)
	_personal_bag.hide()

func _exit_prop(parent:Node3D,id:String,at:Vector3,size:Vector3,mat:Material) -> void:
	var instance:=MeshInstance3D.new()
	instance.name=id
	var mesh:=BoxMesh.new()
	mesh.size=size
	instance.mesh=mesh
	instance.material_override=mat
	instance.position=at
	parent.add_child(instance)

func begin_exit(at:Vector3) -> bool:
	if not _prologue_active or _exit_phase!=0 or not reachable(5,at):
		return false
	_exit_phase=1
	_set_staff_exit(false)
	set_stage(6)
	return true

func exit_active() -> bool:
	return _exit_phase>0

func exit_ready(at:Vector3) -> bool:
	return _exit_phase==3 and at.is_finite() and at.distance_to(point(8))<1.8

func try_exit_step(player:CharacterBody3D) -> bool:
	if _exit_phase==1 and reachable(6,player.global_position):
		_returned_kit.show()
		_personal_bag.show()
		_exit_phase=2
		player.call("play_visual_action",&"interact")
		set_stage(7)
		return true
	if _exit_phase==2 and reachable(7,player.global_position):
		_personal_bag.hide()
		player.get("visual").call("set_corporate_attire",false)
		player.call("play_visual_action",&"interact")
		_exit_phase=3
		_set_gate_open(true)
		set_stage(8)
		return true
	return false

func _build_workfloor_shell(wall: Material,floor_mat: Material) -> void:
	for level in range(1,Workfloor.FLOOR_COUNT+1):
		var base:=level*Workfloor.FLOOR_HEIGHT
		# Ground ceiling already serves as level 1's floor slab.
		if level>1:
			_solid("UpperSlab",Vector3(0,base-.15,0),Vector3(17,.3,20),floor_mat)
		for side in [-1.0,1.0]:
			_solid("UpperSide",Vector3(side*8.5,base+1.675,0),Vector3(.25,3.35,20),wall)
			_solid("UpperEnd",Vector3(0,base+1.675,side*10),Vector3(17,3.35,.25),wall)
	# Seal the gap between level four walls and the retained upper core.
	_solid("WorkfloorCap",Vector3(0,(Workfloor.FLOOR_COUNT+1)*Workfloor.FLOOR_HEIGHT-.15,0),Vector3(17,.3,20),floor_mat)
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
	var frame:=_material("crown_mullion",Color("59666a"))
	for z in [-9.95,-7.5,-5.05,-2.95,-.75]:
		_visual("CrownMullion",Vector3(8.5,top+1.675,z),Vector3(.19,3.35,.08),frame)
	for interval in [Vector2(-10,-5),Vector2(-3,-.7)]:
		var bounds:Vector2=interval
		for y in [.07,3.29]:
			_visual("CrownWindowFrame",Vector3(8.5,top+y,(bounds.x+bounds.y)*.5),Vector3(.18,.10,bounds.y-bounds.x),frame)
	_visual("CrownDoorThreshold",Vector3(8.5,top+.018,-4),Vector3(.30,.036,2.0),frame)
	_solid("CrownTerraceSlab",Vector3(9.85,top-.15,-5),Vector3(2.7,.3,7.4),floor_mat)
	# Outside the terrace extent, retain a barrier to prevent stepping into the void.
	_collision("CrownCornerGuard",Vector3(8.5,top+1.675,-9.35),Vector3(.10,3.35,1.3))
	var lift:=LiftFrontage.new()
	lift.name="LiftFrontage"
	lift.floor_label="G"
	lift.up_label="UP / OFFICES"
	lift.down_label="DOWN / B1 IT"
	add_child(lift)
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
		if child is Light3D:
			child.visible=_prologue_active and _active_floor==0
	# Opaque slabs and lift transitions separate these contents visually.
	# Visibility does not disable the existing collision or room anchors.
	for i in _workfloors.size():
		var occupied := _prologue_active and _active_floor == i + 1
		_workfloors[i].visible = occupied
		_workfloors[i].call("set_occupied", occupied)
	if is_instance_valid(_executive_floor):
		var occupied := _prologue_active and _active_floor == ExecutiveFloor.FLOOR
		_executive_floor.visible = occupied
		_executive_floor.call("set_occupied", occupied)
	if is_instance_valid(_basement):
		var occupied := _prologue_active and _active_floor == Basement.FLOOR
		_basement.visible = occupied
		_basement.call("set_occupied", occupied)
	var breakroom := get_node_or_null("BreakroomArt") as Node3D
	if breakroom != null:
		breakroom.visible = _active_floor == 0
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

func lift_direction(at: Vector3) -> int:
	if not _prologue_active or _arrival!=null or lift_active() or exit_active():
		return 0
	var local:=to_local(at)
	if absf(local.y-(_active_floor*Workfloor.FLOOR_HEIGHT+1.15))>.8:
		return 0
	# Entire marked call area, not a tiny invisible radius on the floor.
	if local.z<4.15 or local.z>5.85 or absf(local.x)>1.65:
		return 0
	if local.x<-.12 and _active_floor<ExecutiveFloor.FLOOR:
		return 1
	if local.x>.12 and _active_floor>Basement.FLOOR:
		return -1
	return 0

func lift_destination(direction:int) -> int:
	if direction>0 and _active_floor==Workfloor.FLOOR_COUNT:
		return ExecutiveFloor.FLOOR
	if direction<0 and _active_floor==ExecutiveFloor.FLOOR:
		return Workfloor.FLOOR_COUNT
	return clampi(_active_floor+direction,Basement.FLOOR,ExecutiveFloor.FLOOR)

func floor_title(level:int) -> String:
	if level==Basement.FLOOR:
		return "B1 IT"
	if level==0:
		return "GROUND / LOBBY"
	if level==ExecutiveFloor.FLOOR:
		return "14 / EXECUTIVE LEADERSHIP"
	return "%d / %s" % [level+1,Workfloor.DEPARTMENTS[level-1]]

func try_office_service(at:Vector3) -> bool:
	if not _prologue_active or _active_floor<1 or _active_floor>Workfloor.FLOOR_COUNT:
		return false
	var service:=_workfloors[_active_floor-1].get_node_or_null("OfficeServices")
	return is_instance_valid(service) and bool(service.call("interact",at))

func try_lift(player: CharacterBody3D) -> bool:
	var direction:=lift_direction(player.global_position)
	if direction==0:
		return false
	_lift_target=lift_destination(direction)
	player.set("input_blocked",true)
	player.velocity=Vector3.ZERO
	_intro_canvas.hide()
	_lift_transition.call("begin",_active_floor,_lift_target,floor_title(_lift_target))
	return true

func lift_active() -> bool:
	return is_instance_valid(_lift_transition) and bool(_lift_transition.get("active"))

# Returns true only on the frame in which the hidden relocation occurs.
func tick_lift(delta:float,player:CharacterBody3D) -> bool:
	if not lift_active():
		return false
	_lift_transition.call("advance",delta)
	var moved:=false
	if _lift_transition.call("transfer_ready"):
		_select_floor(_lift_target)
		player.global_position=to_global(Vector3(0,_active_floor*Workfloor.FLOOR_HEIGHT+1.15,Workfloor.LIFT.y))
		player.velocity=Vector3.ZERO
		_lift_transition.set("transferred",true)
		moved=true
		if is_instance_valid(_lift_audio):
			_lift_audio.position.y=_active_floor*Workfloor.FLOOR_HEIGHT+1.2
			_lift_audio.play()
	if _lift_transition.call("complete"):
		_lift_transition.call("reset")
		player.set("input_blocked",false)
		_intro_canvas.show()
	return moved

# Acoustic zones share the physical campus coordinates. Parking and the
# executive terrace are outdoors; an elevator ride is enclosed even while
# its staged transfer changes floors.
static func acoustic_zone(local:Vector3,level:int,parking_open:bool,in_lift:bool) -> String:
	if not local.is_finite():
		return ""
	if in_lift:
		return "SYNAXIS_LIFT"
	var relative_y:=local.y-level*Workfloor.FLOOR_HEIGHT
	if relative_y<-.3 or relative_y>3.35:
		return ""
	if level==0:
		if absf(local.x)<=8.5 and local.z>=-10.0 and local.z< -7.65:
			return "SYNAXIS_LOBBY"
		var washroom:=local-Restrooms.OFFSET
		if absf(washroom.x)<2.35 and washroom.z>6.25 and washroom.z<9.76:
			return "SYNAXIS_FACILITIES"
		if GroundLayout.in_breakroom(local):
			return "SYNAXIS_FACILITIES"
		if absf(local.x)<=8.5 and local.z>=-7.65 and local.z<=10.0:
			return "SYNAXIS_OFFICE"
		if parking_open and within_chapter_bounds(local,0,true,false):
			return "SYNAXIS_PARKING"
		return ""
	if level==ExecutiveFloor.FLOOR and local.x>8.5 and within_chapter_bounds(local,level,false,false):
		return "SYNAXIS_PARKING"
	if not (absf(local.x)<=8.5 and absf(local.z)<=10.0):
		return ""
	if level==Basement.FLOOR:
		return "SYNAXIS_BASEMENT"
	if level==ExecutiveFloor.FLOOR:
		return "SYNAXIS_EXECUTIVE"
	if level>=1 and level<=Workfloor.FLOOR_COUNT:
		return "SYNAXIS_OFFICE"
	return ""

func acoustic_room(at:Vector3) -> String:
	return acoustic_zone(to_local(at),_active_floor,_staff_exit_open,lift_active())

func recovery_floor() -> float:
	return global_position.y+_active_floor*Workfloor.FLOOR_HEIGHT-2.0

# Keep optional parking and terrace exploration, but do not allow the
# active chapter to spill into the unrestricted city. This is a secondary
# safety net behind the physical shell, not a substitute for collision art.
static func within_chapter_bounds(local:Vector3,level:int,parking_open:bool,exit_unlocked:bool) -> bool:
	if not local.is_finite():
		return false
	var relative_y:=local.y-level*Workfloor.FLOOR_HEIGHT
	if relative_y < -2.0 or relative_y > 3.5:
		return false
	if level!=0 and level!=Basement.FLOOR and level!=ExecutiveFloor.FLOOR and (level<1 or level>Workfloor.FLOOR_COUNT):
		return false
	if level==0:
		if absf(local.x)<=8.6 and local.z>=-7.8 and local.z<=10.1:
			return true
		# The only ground-floor street exit is the completed offboarding route.
		if exit_unlocked and absf(local.x)<=1.6 and local.z>=-14.2 and local.z<=-7.6:
			return true
		# Bounded west walkway from the staff door and rear founder forecourt.
		# Preserve the guard and employee parking visit, not the entire city.
		if parking_open:
			if local.x>=-10.3 and local.x<=-8.3 and local.z>=3.3 and local.z<=25.9:
				return true
			if local.x>=-10.3 and local.x<=8.0 and local.z>=9.8 and local.z<=25.9:
				return true
		return false
	if absf(local.x)<=8.6 and absf(local.z)<=10.1:
		return true
	return level==ExecutiveFloor.FLOOR and local.x>=8.4 and local.x<=11.3 and local.z>=-8.8 and local.z<=-1.2

func needs_recovery(at:Vector3) -> bool:
	if not _prologue_active or arrival_active() or lift_active():
		return false
	if not at.is_finite():
		return true
	return not within_chapter_bounds(to_local(at),_active_floor,_staff_exit_open,_exit_phase==3)

func recovery_position() -> Vector3:
	return to_global(CUBICLE_POINT if _active_floor==0 else Vector3(0,_active_floor*Workfloor.FLOOR_HEIGHT+1.15,Workfloor.LIFT.y))

func _build_lobby(accent: Material) -> void:
	_collision("VisitorKiosk", Vector3(-2.8,.61,-8.65), Vector3(.62,1.22,.44))
	Equipment.place(self, Equipment.KIOSK, "VisitorKioskArt", Vector3(-2.8,0,-8.65))
	for x in [-1.55,1.55]:
		_solid("CardReaderPedestal",Vector3(x,.55,-8.1),Vector3(.19,1.1,.19),accent)
		_visual("BadgeReader",Vector3(x,1.14,-8.1),Vector3(.23,.10,.25),_material("denied",Color("be5155"),true))
	_visual("LobbyRunner",Vector3(0,.012,-8.8),Vector3(2.4,.015,2.2),_material("runner",Color("20343e")))
	_lobby_light=OmniLight3D.new()
	_lobby_light.position=Vector3(0,2.95,-8.7)
	_lobby_light.omni_range=5.0
	_lobby_light.light_energy=.55
	_lobby_light.light_color=Color("fff0dc")
	_lobby_light.shadow_enabled=false
	add_child(_lobby_light)

func _build_office_details(desk: Material,accent: Material,screen: Material) -> void:
	# Ground floor former IT alcove is now a records and compliance station.
	for x in [-7.55,-6.7]:
		_solid("RecordsCabinet",Vector3(x,1.07,.7),Vector3(.72,2.14,.85),desk)
		for row in range(4):
			_visual("FileDrawer",Vector3(x,.35+row*.50,1.14),Vector3(.63,.43,.035),accent)
			_visual("FileHandle",Vector3(x,.40+row*.50,1.17),Vector3(.21,.035,.025),desk)
	for x in [-6.4,6.4]:
		_visual("DeskNamePlate",Vector3(x,1.13,-5.05),Vector3(.47,.13,.08),accent)
	var carpet:=_material("carpet",Color.WHITE)
	carpet.albedo_texture=preload("res://assets/synaxis/office_carpet.svg")
	carpet.uv1_triplanar=true
	carpet.uv1_scale=Vector3(2,2,2)
	carpet.roughness=.96
	_visual("ExecutiveCarpet",Vector3(5,.012,-3.3),Vector3(5,.015,3.1),carpet)

func _build_ground_wayfinding(wall:Material,accent:Material) -> void:
	# Rear shaft side, exterior walls and these two spans form a separate
	# room. Its 1.9 m open doorway leaves the staff exit and main aisle clear.
	for i in GroundLayout.BREAKROOM_EDGES.size():
		var edge:Array=GroundLayout.BREAKROOM_EDGES[i]
		var center:Vector2=(edge[0]+edge[1])*.5
		_solid("BreakroomFront"+str(i),Vector3(center.x,1.675,center.y),Vector3(edge[0].distance_to(edge[1]),3.35,.16),wall)
	var door_center:float=(GroundLayout.DOOR_LEFT+GroundLayout.DOOR_RIGHT)*.5
	_solid("BreakroomDoorHeader",Vector3(door_center,2.925,GroundLayout.BREAKROOM_FRONT),Vector3(1.90,.85,.16),wall)
	for x in [GroundLayout.DOOR_LEFT,GroundLayout.DOOR_RIGHT]:
		_visual("BreakroomJamb",Vector3(x,1.25,GroundLayout.BREAKROOM_FRONT),Vector3(.065,2.5,.24),accent)
	_visual("BreakroomSill",Vector3(door_center,.012,GroundLayout.BREAKROOM_FRONT),Vector3(1.9,.015,.27),accent)
	_plaque("EMPLOYEE BREAKROOM",Vector3(door_center,2.83,GroundLayout.BREAKROOM_FRONT-.105),PI,Vector2(1.76,.29))
	_plaque("MAIN OFFICE",Vector3(door_center,2.83,GroundLayout.BREAKROOM_FRONT+.105),0,Vector2(1.76,.29))
	_plaque("ELEVATORS / B1 IT",Vector3(-6.62,2.20,GroundLayout.BREAKROOM_FRONT-.105),PI,Vector2(2.30,.32))
	# The approach from the arrival corridor and desk 04 uses flush,
	# contrasting arrows. No collision or hovering billboard.
	for at in [Vector3(2.15,.018,-.15),Vector3(2.15,.018,2.55)]:
		_floor_arrow(at,0.0)
	_floor_arrow(Vector3(3.10,.018,4.55),-PI/2)
	_floor_arrow(Vector3(1.70,.018,4.55),-PI/2)

func _floor_arrow(at:Vector3,yaw:float) -> void:
	var node:=MeshInstance3D.new()
	node.name="ElevatorFloorDirection"
	var mesh:=QuadMesh.new()
	mesh.size=Vector2(.70,.70)
	node.mesh=mesh
	var mat:=_material("lift_route_art",Color.WHITE)
	mat.albedo_texture=preload("res://assets/synaxis/elevator_floor_arrow.svg")
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness=.85
	node.material_override=mat
	node.position=at
	node.basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-PI/2)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node,true)

func _build_breakroom() -> void:
	var art := BreakroomArt.new()
	art.name = "BreakroomArt"
	add_child(art)
	# Same table footprint and room routes. Colliders match the new furniture.
	_collision("BreakroomTable", Vector3(-4.2,.38,8.12), Vector3(3.4,.76,1.02))
	_collision("BreakroomCasework", Vector3(-7.992,.468,8.0), Vector3(.749,.936,3.20))
	for x in [-5.36, -3.04]:
		_collision("BreakroomDiningChair",Vector3(x,.39,7.25),Vector3(.48,.78,.49))
	_visual("PartyBannerBacking",Vector3(-4.2,2.98,9.80),Vector3(4.7,.66,.04),_material("party_navy",Brand.NAVY))
	Brand.wall_logo(self,"PartyBrand",Vector3(-6.03,2.98,9.765),PI,.72)
	_sign("TALENT APPRECIATION DAY",Vector3(-3.77,2.98,9.775),.0027).rotation.y=PI


func _build_corporate_relics(desk: Material,accent: Material,screen: Material) -> void:
	# Actual desk objects, not floating tutorial text. Keep the circulation aisle clear.
	var trophy_gold := _material("recognition_gold",Brand.GOLD)
	_visual("RecognitionPlinth",Vector3(-6.0,1.125,2.59),Vector3(.30,.09,.22),desk)
	_visual("RecognitionStem",Vector3(-6.0,1.30,2.59),Vector3(.075,.27,.075),trophy_gold)
	_visual("RecognitionAward",Vector3(-6.0,1.46,2.59),Vector3(.24,.13,.065),trophy_gold)
	_sign("ABOVE & BEYOND\n$0 CASH VALUE",Vector3(-6.0,1.46,2.627),.00034)
	_visual("DeskTimeTracker",Vector3(-4.0,1.15,2.81),Vector3(.24,.12,.12),desk)
	_visual("TimeTrackerDisplay",Vector3(-4.0,1.15,2.878),Vector3(.20,.07,.007),screen)
	_sign("IDLE: 00:01",Vector3(-4.0,1.15,2.886),.00065)
	# A real executive-only amenity contrasts with the employee catering table.
	_solid("ExecutiveRefreshmentCabinet",Vector3(7.62,.49,-.25),Vector3(.85,.98,1.5),desk)
	_visual("ExecutiveCoffeeMachine",Vector3(7.62,1.18,-.52),Vector3(.42,.40,.41),accent)
	_visual("ExecutiveCoffeeDisplay",Vector3(7.385,1.24,-.52),Vector3(.012,.12,.26),screen)
	_visual("ExecutivePorcelainCup",Vector3(7.57,1.07,.12),Vector3(.13,.16,.13),_material("porcelain",Brand.WHITE))
	# Exit packaging price: consistent with the existing HR line. No charge until a future shop transaction.
	_visual("CartonPriceCard",Vector3(5.47,1.13,6.19),Vector3(.20,.11,.018),_material("exit_card",Brand.PAPER))
	var price_label:=_sign("BOX $4.99",Vector3(5.47,1.13,6.176),.00085)
	price_label.rotation.y=PI
	price_label.modulate=Brand.INK

func restroom_encounter(at: Vector3) -> String:
	if not _prologue_active or _arrival!=null:
		return ""
	var local:Vector3=_restrooms.to_local(at)
	_restrooms.call("update_effects",local)
	return str(_restrooms.call("encounter",local))

func breakroom_reachable(at: Vector3) -> bool:
	return _prologue_active and _active_floor==0 and at.is_finite() and GroundLayout.in_breakroom(to_local(at)) and at.distance_to(to_global(BREAKROOM_POINT))<1.35

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

func _set_staff_exit(open:bool) -> void:
	_staff_exit_open=open
	get_node("StaffExitDoor").visible=not open
	get_node("StaffExitDoorCollision").get_child(0).set_deferred("disabled",open)

func begin_prologue() -> void:
	_prologue_active=true
	_exit_phase=0
	_returned_kit.hide()
	_personal_bag.hide()
	_set_staff_exit(true)
	_restrooms.call("begin_visit")
	_errand_phase=0
	_folder_desk.position=Vector3(4.05,1.10,1.93)
	_folder_desk.show()
	_breakroom_seen=false
	if not is_instance_valid(_cast):
		_build_cast()
	_intro_canvas.show()
	_ensure_workfloors()
	_select_floor(0)
	set_stage(-2)

func finish_prologue() -> void:
	_prologue_active=false
	_exit_phase=0
	_returned_kit.hide()
	_personal_bag.hide()
	if is_instance_valid(_lift_transition):
		_lift_transition.call("reset")
	_set_staff_exit(false)
	_select_floor(0)
	_restrooms.call("end_visit")
	_arrival=null
	_arrival_canvas.hide()
	_set_gate_open(false)
	_clear_folder()
	_folder_desk.hide()
	end_dialogue()
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
	for light in find_children("*","Light3D",true,false):
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
		CreatorCast.install(actor, str(spec["id"]))
		_staff[spec["id"]]=actor
	_ceo=_staff["jetson_wang"]
	_hr=_staff["people_ops"]
	_assistant=Assistant.new()
	_assistant.name="LinXue"
	_assistant.position=ExecutiveFloor.ASSISTANT_ANCHOR+Vector3.UP*ExecutiveFloor.BASE
	_assistant.scale=Vector3.ONE*.88
	_assistant.process_mode=Node.PROCESS_MODE_ALWAYS
	_cast.add_child(_assistant)

# Fixed room-local coverage, not a free camera moving through furniture.
# Each cut changes emphasis while preserving the established actor anchors.
var _dialogue_lens: Tween
var _dialogue_camera: Camera3D
var _dialogue_original_fov := 68.0

func dialogue_camera(camera: Camera3D,stage: int,beat: int) -> void:
	if not is_instance_valid(camera) or stage not in [2,3,4]:
		return
	if _dialogue_camera != camera:
		_dialogue_camera = camera
		_dialogue_original_fov = camera.fov
	if is_instance_valid(_dialogue_lens):
		_dialogue_lens.kill()
	var from := Vector3(3.2,1.95,-3.85)
	var toward := ExecutiveFloor.CEO_ANCHOR+Vector3.UP*1.30
	var lens := 58.0
	var framing := .48
	if stage == 4:
		from = Vector3(-7.3,1.85,3.9)
		toward = ExecutiveFloor.HR_ANCHOR+Vector3.UP*1.26
		lens = 51.0
		framing = .40
	elif stage == 2 and beat == 1:
		from = Vector3(5.9,1.85,-3.65)
		toward = ExecutiveFloor.ASSISTANT_ANCHOR+Vector3.UP*1.48
		lens = 52.0
		framing = .28
	elif stage == 3 or beat == 2:
		# Return to the founder for the decision and its immediate fallout.
		from = Vector3(3.65,1.75,-4.08)
		lens = 48.0 if stage == 3 else 53.0
		framing = .42
	var position_world := to_global(from+Vector3.UP*ExecutiveFloor.BASE)
	var subject := to_global(toward+Vector3.UP*ExecutiveFloor.BASE)
	var right := (subject-position_world).normalized().cross(Vector3.UP).normalized()
	camera.global_position = position_world
	# Frame the speaker left of center; the existing conversation panel sits right.
	camera.look_at(subject+right*framing,Vector3.UP)
	camera.fov = lens+2.0
	_dialogue_lens = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_dialogue_lens.tween_property(camera,"fov",lens,.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_canvas.hide()
	if is_instance_valid(_assistant):
		_assistant.call("set_phone_call",stage==2 and beat==1)
	if is_instance_valid(_ceo):
		_ceo.call("set_scene_beat",beat if stage==2 else (2 if stage==3 else -1))
		_ceo.call("attend",to_global(ExecutiveFloor.CEO_GOAL+Vector3.UP*ExecutiveFloor.BASE),stage in [2,3] and beat!=1)
	if is_instance_valid(_hr):
		_hr.call("set_scene_beat",2 if stage==4 else -1)
		_hr.call("attend",to_global(ExecutiveFloor.HR_GOAL+Vector3.UP*ExecutiveFloor.BASE),stage==4)

func breakroom_camera(camera: Camera3D) -> void:
	camera.global_position=to_global(Vector3(-7.25,2.15,6.65))
	camera.look_at(to_global(Vector3(-3.7,1.5,8.7)),Vector3.UP)

func end_dialogue() -> void:
	if is_instance_valid(_dialogue_lens):
		_dialogue_lens.kill()
	_dialogue_lens = null
	if is_instance_valid(_dialogue_camera):
		_dialogue_camera.fov = _dialogue_original_fov
	_dialogue_camera = null
	if _prologue_active and is_instance_valid(_intro_canvas):
		_intro_canvas.show()
	if is_instance_valid(_assistant):
		_assistant.call("set_phone_call",false)
	for actor in _staff.values():
		actor.call("set_scene_beat",-1)
		actor.call("attend",Vector3.ZERO,false)

# Reuse the existing CC0 photo-derived concrete maps, documented in
# central_exchange_curb/SOURCE.json, as a honed aggregate finish.
func _configure_stone(material:StandardMaterial3D) -> void:
	material.albedo_texture=preload("res://assets/models/nightgrid/central_exchange_curb/textures/concrete_base_1k.jpg")
	material.normal_enabled=true
	material.normal_texture=preload("res://assets/models/nightgrid/central_exchange_curb/textures/concrete_normal_1k.jpg")
	material.normal_scale=.22
	material.roughness=.55
	material.uv1_triplanar=true
	material.uv1_scale=Vector3(.75,.75,.75)

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

func _plaque(value:String,at:Vector3,yaw:float,size:Vector2) -> void:
	var backing:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(size.x,size.y,.035)
	backing.mesh=mesh
	backing.name="MountedWayfinding"
	backing.material_override=_material("wayfinding",Color("26343a"))
	backing.position=at
	backing.rotation.y=yaw
	add_child(backing,true)
	var label:=Label3D.new()
	label.text=value
	label.font_size=40
	var width:=1.0
	var lines:=value.split("\n")
	for line in lines:
		width=maxf(width,ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,40).x)
	label.pixel_size=minf((size.x-.08)/width,(size.y-.04)/(ThemeDB.fallback_font.get_height(40)*lines.size()))
	label.outline_size=0
	label.fixed_size=false
	label.no_depth_test=false
	label.position=Vector3(0,0,.021)
	backing.add_child(label)

func _sign(value: String,at: Vector3,pixel: float) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.font_size = 40
	label.pixel_size = pixel
	label.outline_size = 0
	label.fixed_size = false
	label.no_depth_test = false
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
	set_stage(-2)

func objective_stage(story_stage: int) -> int:
	if _exit_phase>0:
		return 5+_exit_phase
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
	for deck in _workfloors:
		deck.call("set_story_stage",stage)
	if not POINTS.has(stage):
		return

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

static func lift_goal_pad(current:int,desired:int) -> Vector2:
	if current==desired:
		return Workfloor.LIFT
	return Workfloor.LIFT+Vector2(.90 if desired<current else -.90,0)

func _lift_hint(stage:int,local:Vector3) -> String:
	var desired:=objective_floor(stage)
	if desired==_active_floor:
		return ""
	var pad:=lift_goal_pad(_active_floor,desired)
	var distance:=Vector2(local.x,local.z).distance_to(pad)
	var button:="RIGHT / DOWN" if desired<_active_floor else "LEFT / UP"
	if local.z>=4.15 and local.z<=5.85 and absf(local.x)<=.12:
		return "\nStep onto the %s call mat toward %s" % [button,floor_title(desired)]
	return "\nFollow the marked aisle to ELEVATORS · %.0f m · %s toward %s" % [distance,button,floor_title(desired)]

func update_prompt(stage: int,at: Vector3,gamepad: bool) -> void:
	if not POINTS.has(stage):
		return
	update_parking_guard(at)
	var local := to_local(at)
	var goal: Vector3=POINTS[stage]
	_radar.call("set_office_state",Vector2(local.x,local.z),Vector2(goal.x,goal.z) if _active_floor==objective_floor(stage) else lift_goal_pad(_active_floor,objective_floor(stage)),_active_floor)
	if _active_floor==Basement.FLOOR:
		_hint.text="SYNAXIS / "+Basement.TITLE+"\n"+TITLES[stage]
		if objective_floor(stage)!=Basement.FLOOR:
			_hint.text+=_lift_hint(stage,local)
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
			_hint.text+=_lift_hint(stage,local)
		if _active_floor==ExecutiveFloor.FLOOR and is_instance_valid(_executive_floor):
			var executive_line: String=_executive_floor.call("staff_remark",at,stage)
			if executive_line.is_empty():
				executive_line=update_staff_attention(stage,at)
			if not executive_line.is_empty():
				_hint.text+="\n"+executive_line
		if _active_floor<=Workfloor.FLOOR_COUNT:
			var service:=_workfloors[_active_floor-1].get_node_or_null("OfficeServices")
			if is_instance_valid(service):
				var service_prompt:=str(service.call("prompt",at))
				if not service_prompt.is_empty():
					_hint.text+="\n"+("X" if gamepad else "G")+" / "+service_prompt
			var worker_line:String=_workfloors[_active_floor-1].call("observe_worker",at)
			if not worker_line.is_empty():
				_hint.text+="\n"+worker_line
		var interview:=interview_at(at,stage)
		if not interview.is_empty() and not reachable(stage,at):
			_hint.text+="\n"+("X" if gamepad else "G")+" / TALK TO "+str(interview["name"])
		var direction:=lift_direction(at)
		if direction!=0:
			_hint.text+="\n"+("X" if gamepad else "G")+" / LIFT TO "+floor_title(lift_destination(direction))
		return
	_hint.text = "SYNAXIS / EXECUTIVE PRIVILEGE\n%s" % TITLES[stage]
	if _exit_phase>0:
		match _exit_phase:
			1: _hint.text+="\nNina: Laptop and badge on the desk, please."
			2: _hint.text+="\nNina: Your personal clothes are back at desk 04."
			3: _hint.text+="\nSecurity: The front gate is open. Please proceed to the street."
		if _exit_phase<3 and reachable(stage,at):
			_hint.text+="\n"+("X / INTERACT" if gamepad else "G / INTERACT")
		return
	if stage==-2:
		_hint.text += "\nMika: Take the sealed access-control request to Eli in IT."
	elif stage==-1:
		_hint.text += "\nEli can verify the authorization records."
	_hint.text+=_lift_hint(stage,local)
	if reachable(stage,at):
		_hint.text += "\n"+("X / INTERACT" if gamepad else "G / INTERACT")
	if terminal_reachable(at) and stage==-1:
		_hint.text+="\n"+("X" if gamepad else "G")+" / OPEN WORKSTATION"
	if breakroom_reachable(at) and not _breakroom_seen:
		_hint.text += "\n" + ("X" if gamepad else "G") + " / OPTIONAL: BREAKROOM PARTY"
	var lift:=lift_direction(at)
	if lift!=0:
		_hint.text+="\n"+("X" if gamepad else "G")+" / LIFT TO "+floor_title(lift_destination(lift))
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

## Collecting the folder retains priority; the adjacent workstation is available
## while carrying the request, before the verified IT report.
func terminal_reachable(at:Vector3) -> bool:
	return _prologue_active and _arrival==null and _active_floor==0 and _errand_phase==1 and at.is_finite() and at.distance_to(to_global(CUBICLE_POINT))<=1.8
