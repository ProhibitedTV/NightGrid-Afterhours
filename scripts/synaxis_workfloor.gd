extends Node3D
const InteriorFinish = preload("res://scripts/synaxis_architecture.gd")
## Four authored workfloor layouts, using static material/primitive batches.
## Real desk and partition collision; no per-desk process or lights.
const Rage=preload("res://scripts/synaxis_keyboard_rage.gd")
const Eggs=preload("res://scripts/synaxis_office_easter_eggs.gd")
const Robotics=preload("res://scripts/synaxis_robotics_lab.gd")
const FloorStaff=preload("res://scripts/synaxis_workfloor_staff.gd")
const Services=preload("res://scripts/synaxis_office_services.gd")
const DepartmentMeeting=preload("res://scripts/synaxis_department_meeting.gd")
var _services:Node3D
const GeneratedAudio=preload("res://scripts/synaxis_generated_audio.gd")
const LiftFrontage=preload("res://scripts/synaxis_lift_frontage.gd")
const FLOOR_COUNT=4
const FLOOR_HEIGHT=3.65
const LIFT=Vector2(0,5.0)
const DEPARTMENTS=["AI & ROBOTICS ENGINEERING","PRODUCT & DESIGN","QUALITY & VALIDATION","BUSINESS OPERATIONS"]
const COLORS={
	"oak":Color("d2b58e"),"oak_edge":Color("a98c68"),"white":Color("e7e4dc"),
	"steel":Color("535a5e"),"black":Color("252e36"),"carpet":Color("777b7c"),
	"fabric":Color("a5aaa7"),"blue":Color("527f9b"),"teal":Color("457d79"),
	"rust":Color("bd7754"),"sage":Color("82947b"),"screen":Color("263d4c"),
	"ui":Color("85abb8"),"paper":Color("eee8d8"),"green":Color("4c7352"),
	"leaf":Color("72916a"),"soil":Color("59473b"),"glass":Color("79959e"),
	"light":Color("e7e9df")
}
const ACCENTS=["teal","blue","sage","rust"]
const ROWS=[-5.6,-4.65,1.1,2.05]
const SLOGANS=["INNOVATE WITH INTENT","YOUR IDEAS. OUR INTELLECTUAL PROPERTY.","QUALITY IS EVERYONE'S RESPONSIBILITY*","TOGETHER WE DO MORE WITH LESS."]
const SUBLINES=["ALIGN. EXECUTE. REPEAT.","ALL SUBMISSIONS BECOME COMPANY PROPERTY.","*EXECUTIVE EXCEPTIONS MAY APPLY.","PLEASE DO NOT DISCUSS HEADCOUNT."]
var level:=1
const ChairAsset=preload("res://scripts/synaxis_chair_asset.gd")
const Desktop=preload("res://scripts/synaxis_desktop_material.gd")
var _chair_poses:Array[Transform3D]=[]
var _groups: Dictionary={}
var _materials: Dictionary={}
var _chairs:=0
var _desks:=0
var _raceways:=0
var _plants:=0
var _parts:=0
var _colliders:=0
var _lights: Array[OmniLight3D]=[]
var _rage:Node3D
var _eggs:Node3D
var _robotics:Node3D
var _people:Node3D
var _office_ambience:AudioStreamPlayer3D

static func desk_positions() -> Array[Vector2]:
	var result: Array[Vector2]=[]
	for z in ROWS:
		for col in range(7):
			result.append(Vector2(-6.0+col*2.0,float(z)))
	return result

func _ready() -> void:
	var accent: String=ACCENTS[level-1]
	_part("carpet",Vector3(0,.007,0),Vector3(16.55,.012,19.65))
	for row in range(4):
		var z: float=ROWS[row]
		var face: float= -1.0 if row%2==0 else 1.0
		for col in range(7):
			_station(Vector3(-6.0+col*2.0,0,z),face,row,col,accent)
		# Continuous desk-row collision; open aisle at both ends of each bench.
		_solid(Vector3(0,.43,z),Vector3(13.65,.86,.78))
	for pair in [0,2]:
		var mid: float=(float(ROWS[pair])+float(ROWS[pair+1]))*.5
		# Cubicles on floors 1/3, low shared bench dividers on 2/4.
		var h:=1.39 if level%2==1 else 1.10
		_part("fabric",Vector3(0,h*.5,mid),Vector3(13.65,h,.065))
		_part(accent,Vector3(0,h+.017,mid),Vector3(13.65,.034,.075))
		_solid(Vector3(0,h*.5,mid),Vector3(13.65,h,.065))
		if level%2==1:
			for x in [-5.0,-3.0,-1.0,1.0,3.0,5.0]:
				_part("fabric",Vector3(x,.95,mid),Vector3(.06,.86,1.72))
				_part("oak_edge",Vector3(x,1.39,mid),Vector3(.075,.025,1.72))
				_solid(Vector3(x,.95,mid),Vector3(.06,.86,1.72))
	_shared_area(accent)
	_architecture(accent)
	_noticeboard(accent)
	_flush()
	_office_ambience=GeneratedAudio.emitter(self,"office_air",Vector3(0,1,-1),-22.0,18.0,true)
	_services=Services.new()
	_services.name="OfficeServices"
	_services.level=level
	add_child(_services)
	_people=FloorStaff.new()
	_people.name="DepartmentStaff"
	_people.level=level
	add_child(_people)
	if level==1:
		_robotics=Robotics.new()
		_robotics.name="RoboticsLab"
		add_child(_robotics)
	if level==2:
		_rage=Rage.new()
		_rage.configure_staff({"id":"cal","name":"Cal Mercer","role":"Product systems analyst","activity":"TYPE","seated":true,"palette":0,"outfit":"office","hair":"parted","glasses":true,"coat":"61727c","width":1.02,"height":.90,"phase":.3})
		_rage.position=Rage.SEAT
		_rage.rotation.y=PI
		add_child(_rage)
	if level==4:
		_eggs=Eggs.new()
		_eggs.name="OfficeEasterEggs"
		add_child(_eggs)
	set_occupied(false)

func get_floor_stats() -> Dictionary:
	return {"level":level,"department":DEPARTMENTS[level-1],"desks":_desks,"raceways":_raceways,"chairs":_chairs,"plants":_plants,"parts":_parts,"colliders":_colliders,"batches":get_children().filter(func(n):return n is MultiMeshInstance3D).size()}

func set_story_stage(stage:int) -> void:
	if is_instance_valid(_people):
		_people.call("set_story_stage",stage)

func set_occupied(active: bool) -> void:
	GeneratedAudio.activate(_office_ambience,active)
	var chairs:=get_node_or_null("AuthoredTaskChairs") as MultiMeshInstance3D
	if chairs!=null:
		chairs.visible=active
	for key in ["desktopblue","desktopsignal","desktopamber"]:
		var screen:=get_node_or_null(key+"_quad") as MultiMeshInstance3D
		if screen!=null:
			screen.visible=active
	if is_instance_valid(_services):
		_services.call("set_active",active)
	for lamp in _lights:
		lamp.visible=active
	if is_instance_valid(_rage):
		_rage.call("enable_performance",active)
	if is_instance_valid(_eggs):
		_eggs.call("set_active",active)
	if is_instance_valid(_robotics):
		_robotics.call("set_active",active)
	if is_instance_valid(_people):
		_people.call("set_active",active)

func _material(key: String) -> StandardMaterial3D:
	if key.begins_with("desktop"):
		return Desktop.material(key)
	if not _materials.has(key):
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=COLORS[key]
		mat.roughness=.82
		if key=="carpet":
			mat.albedo_color=Color.WHITE
			mat.albedo_texture=preload("res://assets/synaxis/office_carpet.svg")
			mat.uv1_triplanar=true
			mat.uv1_scale=Vector3(2,2,2)
			mat.roughness=.96
		if key in ["oak","oak_edge","white","glass"]:
			mat.roughness=.48
		if key=="steel":
			mat.metallic=.5
			mat.roughness=.42
		if key in ["light","ui"]:
			mat.emission_enabled=true
			mat.emission=COLORS[key]
			mat.emission_energy_multiplier=.65
		_materials[key]=mat
	return _materials[key]

func _part(key: String,at: Vector3,size: Vector3,yaw: float=0.0,primitive: String="box",pitch: float=0.0) -> void:
	var group:=key+"|"+primitive
	if not _groups.has(group):
		_groups[group]=[]
	var basis:=Basis.from_euler(Vector3(pitch,yaw,0)).scaled_local(size)
	_groups[group].append(Transform3D(basis,at))
	_parts+=1

func _solid(at: Vector3,size: Vector3) -> void:
	var body:=StaticBody3D.new()
	body.position=at
	var shape:=BoxShape3D.new()
	shape.size=size
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	add_child(body)
	_colliders+=1

func _flush() -> void:
	var box:=BoxMesh.new()
	box.size=Vector3.ONE
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE
	var cyl:=CylinderMesh.new()
	cyl.top_radius=.5
	cyl.bottom_radius=.5
	cyl.height=1.0
	cyl.radial_segments=10
	var leaf:=SphereMesh.new()
	leaf.radius=.5
	leaf.height=1.0
	leaf.radial_segments=8
	leaf.rings=4
	for key in _groups:
		var transforms: Array=_groups[key]
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=quad if str(key).ends_with("|quad") else (cyl if str(key).ends_with("|cyl") else (leaf if str(key).ends_with("|leaf") else box))
		mm.instance_count=transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i,transforms[i])
		var node:=MultiMeshInstance3D.new()
		node.name=str(key).replace("|","_")
		node.multimesh=mm
		node.material_override=_material(str(key).get_slice("|",0))
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	_groups.clear()
	ChairAsset.install(self,_chair_poses)
	_chair_poses.clear()

func _station(at: Vector3,face: float,row: int,col: int,accent: String) -> void:
	_desks+=1
	_part("oak",at+Vector3(0,.82,0),Vector3(1.72,.055,.78))
	_part("oak_edge",at+Vector3(0,.81,face*.39),Vector3(1.72,.055,.018))
	# Under-desk power raceway inside the existing desk collision envelope.
	_raceways+=1
	_part("steel",at+Vector3(-.18,.73,-face*.26),Vector3(1.05,.07,.11))
	_part("black",at+Vector3(-.18,.695,-face*.26),Vector3(.88,.02,.07))
	if (row+col+level)%3==0:
		_part("black",at+Vector3(-.66,.53,-face*.24),Vector3(.022,.29,.025))
	for side in [-1.0,1.0]:
		_part("steel",at+Vector3(side*.78,.40,0),Vector3(.055,.80,.64))
	_part("white",at+Vector3(.61,.39,0),Vector3(.36,.72,.62))
	for y in [.24,.47,.66]:
		_part("steel",at+Vector3(.61,y,face*.32),Vector3(.16,.018,.027))
	var screen_at:=at+Vector3(-.22,1.12,-face*.19)
	if not (level==2 and row==3 and col==5):
		_monitor(screen_at,face)
		if (row+col+level)%3==0:
			_monitor(screen_at+Vector3(.61,0,0),face)
		_part("black",at+Vector3(-.22,.861,face*.19),Vector3(.45,.025,.15))
		_part("steel",at+Vector3(-.22,.876,face*.19),Vector3(.41,.008,.12))
	_part("black",at+Vector3(.12,.87,face*.19),Vector3(.07,.041,.11))
	if not (level==4 and row==3 and col==1):
		_part("paper",at+Vector3(-.66,.86,face*.15),Vector3(.22,.022,.29))
	if (row+col)%2==0:
		_part("white",at+Vector3(.55,.91,face*.14),Vector3(.085,.13,.085),0.0,"cyl")
	if (row*7+col+level)%5==0:
		_plant(at+Vector3(-.71,.85,-face*.23),.18)
	_chair(at+Vector3(0,0,face*.85),-face)
	# Varied desk clutter, kept within the existing desktop.
	var variant: int=(level*7+row*11+col*3)%6
	if variant==0:
		_part("black",at+Vector3(.42,.89,-face*.22),Vector3(.14,.09,.20))
		_part("steel",at+Vector3(.42,.94,-face*.22),Vector3(.12,.012,.17))
	elif variant==1:
		for book in range(3):
			_part(accent if book==1 else "paper",at+Vector3(-.64,.87+book*.026,-face*.18),Vector3(.21,.023,.22))
	elif variant==2:
		_part(accent,at+Vector3(.53,.96,-face*.22),Vector3(.10,.22,.10),0.0,"cyl")
		_part("black",at+Vector3(.53,1.075,-face*.22),Vector3(.105,.02,.105),0.0,"cyl")
	elif variant==3:
		_part("white",at+Vector3(.42,.875,face*.20),Vector3(.16,.045,.09))
		_part("black",at+Vector3(.42,.90,face*.20),Vector3(.13,.009,.065))
	elif variant==4:
		_part("black",at+Vector3(-.68,.94,-face*.18),Vector3(.09,.16,.09),0.0,"cyl")
		for pen in range(3):
			_part("steel",at+Vector3(-.70+pen*.022,1.045,-face*.18),Vector3(.009,.13,.009))
	# Small personal items make desk banks less uniform.
	if (row+col)%4==0:
		_part(accent,at+Vector3(.40,.91,-face*.21),Vector3(.15,.13,.045))
		_part("paper",at+Vector3(.40,.92,-face*.185),Vector3(.11,.08,.005))

func _monitor(at: Vector3,face: float) -> void:
	_part("black",at,Vector3(.56,.34,.042))
	var key:="desktopblue" if level<=0 or level==1 else ("desktopamber" if level==3 else "desktopsignal")
	_part(key,at+Vector3(0,0,face*.024),Vector3(.525,.305,1.0),0.0 if face>0 else PI,"quad")
	_part("steel",at+Vector3(0,-.205,0),Vector3(.055,.10,.055))
	_part("black",at+Vector3(0,-.26,0),Vector3(.23,.028,.16))


func _chair(at: Vector3,face: float,yaw_offset: float=0.0) -> void:
	_chairs+=1
	_parts+=1
	var pose:=ChairAsset.pose(at,face,.92)
	pose.basis=pose.basis.rotated(Vector3.UP,yaw_offset)
	_chair_poses.append(pose)


func _plant(at: Vector3,size: float) -> void:
	_plants+=1
	_part("white",at+Vector3.UP*size*.4,Vector3(size,size*.8,size),0.0,"cyl")
	_part("soil",at+Vector3.UP*size*.81,Vector3(size*.86,.015,size*.86),0.0,"cyl")
	for i in range(7):
		var angle:=i*TAU/7.0
		_part("leaf" if i%2==0 else "green",at+Vector3(sin(angle)*size*.29,size*(1.0+i%3*.13),cos(angle)*size*.29),Vector3(size*.28,size*.85,size*.15),angle,"leaf",.60)

func _shared_area(accent: String) -> void:
	# Leave the lift landing and central cross-aisle empty.
	for x in [-4.7,4.7]:
		if level==1 and x>0:
			continue
		_part("oak",Vector3(x,.76,7.55),Vector3(2.3,.075,1.28))
		_solid(Vector3(x,.40,7.55),Vector3(2.3,.80,1.28))
		for dx in [-.95,.95]:
			_part("steel",Vector3(x+dx,.36,7.55),Vector3(.08,.72,1.10))
		for dx in [-.55,.55]:
			_chair(Vector3(x+dx,0,6.5),1.0)
			_chair(Vector3(x+dx,0,8.60),-1.0)
		_part("paper",Vector3(x,.81,7.55),Vector3(.33,.02,.25))
		_plant(Vector3(x+.8,.80,7.55),.24)
	# Printer alcove and storage on perimeter.
	for x in [-7.85,7.85]:
		_part("oak",Vector3(x,.53,-.4),Vector3(.68,1.06,1.4))
		_solid(Vector3(x,.53,-.4),Vector3(.68,1.06,1.4))
		if x>0: # West appliance is owned by OfficeServices.
			_part("white",Vector3(x,1.23,-.4),Vector3(.55,.36,.62))
			_part("black",Vector3(x,1.38,-.4),Vector3(.36,.045,.42))
		if level!=1 or x<0:
			_plant(Vector3(x,0,8.8),.46)
	# Soft seating, facing the collaboration tables but away from main paths.
	for x in [-6.2,6.2]:
		if level==1 and x>0:
			continue
		_part(accent,Vector3(x,.43,9.45),Vector3(2.2,.56,.72))
		_part(accent,Vector3(x,.82,9.70),Vector3(2.2,.56,.20))
		_solid(Vector3(x,.50,9.45),Vector3(2.2,1.0,.72))

func _label(value: String,at: Vector3,pixel: float,yaw: float=0.0) -> void:
	var sign:=Label3D.new()
	sign.text=value
	sign.position=at
	sign.pixel_size=pixel
	sign.font_size=44
	sign.outline_size=0
	sign.fixed_size=false
	sign.no_depth_test=false
	sign.rotation.y=yaw
	add_child(sign)

func observe_worker(at:Vector3) -> String:
	if is_instance_valid(_rage):
		_rage.call("observe",at)
	var ambient:String=str(_people.call("observe",at)) if is_instance_valid(_people) else ""
	if is_instance_valid(_eggs):
		var egg_line:String=_eggs.call("observe",at)
		if not egg_line.is_empty():
			return egg_line
	if is_instance_valid(_robotics):
		var robot_line:String=_robotics.call("observe",at)
		if not robot_line.is_empty():
			return robot_line
	return ambient

func _noticeboard(accent:String) -> void:
	_part("oak_edge",Vector3(-8.24,1.94,6.8),Vector3(.085,1.38,2.75))
	_part("white",Vector3(-8.18,1.94,6.8),Vector3(.025,1.30,2.65))
	_part(accent,Vector3(-8.158,2.44,6.8),Vector3(.012,.19,2.53))
	_label("TEAM DELIVERY BOARD",Vector3(-8.145,2.44,6.8),.0027,PI/2)
	for col in range(3):
		var z:float=5.98+col*.81
		_part("steel",Vector3(-8.154,1.9,z+.39),Vector3(.012,.77,.012))
		for note in range(2+col%2):
			_part("paper" if note%2==0 else accent,Vector3(-8.14,2.15-note*.22,z),Vector3(.014,.15,.22))
			_part("steel",Vector3(-8.129,2.15-note*.22,z),Vector3(.006,.009,.15))
	_label("BACKLOG",Vector3(-8.12,2.25,6.0),.0016,PI/2)
	_label("IN PROGRESS",Vector3(-8.12,2.25,6.8),.0016,PI/2)
	_label("BLOCKED",Vector3(-8.12,2.25,7.62),.0016,PI/2)
	_part("black",Vector3(-8.24,1.87,8.08),Vector3(.05,.72,.98))
	_label("DAILY STAND-UP",Vector3(-8.20,2.10,8.08),.0021,PI/2)
	_label(DepartmentMeeting.TITLES[level-1],Vector3(-8.20,1.87,8.08),.0017,PI/2)
	_label("AFTER EQUIPMENT ROUND",Vector3(-8.20,1.65,8.08),.0014,PI/2)
	_part("white",Vector3(-4.7,2.00,9.76),Vector3(2.65,1.0,.05))
	_part("steel",Vector3(-4.7,1.48,9.69),Vector3(2.65,.045,.16))
	_label("THIS WEEK: ALIGN ON THE ALIGNMENT",Vector3(-4.7,2.29,9.729),.0019,PI)
	_label("OWNER?      DUE DATE?      FOLLOW UP?",Vector3(-4.7,1.98,9.729),.0016,PI)
	for marker in range(3):
		_part(accent if marker==1 else "black",Vector3(-5.6+marker*.22,1.52,9.66),Vector3(.15,.018,.018))

func _architecture(accent: String) -> void:
	# Light oak wall panels, accent bands, acoustic ceiling and corporate banners.
	for x in [-8.32,8.32]:
		_part("oak",Vector3(x,.52,0),Vector3(.06,1.04,19.7))
		_part(accent,Vector3(x,1.75,0),Vector3(.065,.18,19.7))
		for z in [-7.5,-4.5,-1.5,1.5,4.5,7.5]:
			_part("glass",Vector3(x,2.34,z),Vector3(.045,1.02,2.62))
	_part(accent,Vector3(0,1.7,-9.81),Vector3(16.6,3.35,.08))
	_part("oak",Vector3(0,.48,-9.73),Vector3(16.4,.95,.06))
	InteriorFinish.nameplate(self,"DepartmentEntry",DEPARTMENTS[level-1]+" / LEVEL "+str(level+1),Vector3(0,2.73,-9.755),0.0,Vector2(3.5,.36))
	InteriorFinish.strip(self,"DepartmentAcousticWall",Vector3(4.90,0,9.875),PI,5.8,InteriorFinish.FABRIC)
	InteriorFinish.nameplate(self,"DepartmentIdentity","SYNAXIS / "+DEPARTMENTS[level-1],Vector3(4.90,2.12,9.81),PI,Vector2(3.5,.36))
	for x in [-6,-3,0,3,6]:
		for z in [-7.5,-2.5,2.5,7.5]:
			_part("white",Vector3(x,3.31,z),Vector3(2.85,.045,4.85))
			_part("light",Vector3(x,3.27,z),Vector3(1.25,.04,.18))
	for z in [-5.0,1.0,7.0]:
		var lamp:=OmniLight3D.new()
		lamp.position=Vector3(0,2.95,z)
		lamp.omni_range=11.0
		lamp.light_energy=1.45
		lamp.shadow_enabled=false
		add_child(lamp)
		_lights.append(lamp)
	_install_lift(str(level+1),"UP / 14 EXPRESS" if level==FLOOR_COUNT else "UP","DOWN")

func _install_lift(floor_name:String,up:String,down:String) -> void:
	var lift:=LiftFrontage.new()
	lift.name="LiftFrontage"
	lift.floor_label=floor_name
	lift.up_label=up
	lift.down_label=down
	add_child(lift)

func interview_id(at:Vector3) -> String:
	return str(_people.call("interview_id",at)) if is_instance_valid(_people) else ""
