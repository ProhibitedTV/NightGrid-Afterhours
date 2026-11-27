extends "res://scripts/lantern_patron.gd"
## HQ-only actors; authored identities, reusable static detail and bounded pose updates.
## No navigation, physics or economy ownership. The scene owns mission progression.
var display_name := ""
var outfit := "office"
var hair_style := "parted"
var glasses := false
var _attentive := false
var _attention_yaw := 0.0
var _scene_beat := -1
var _left_wrist: Node3D
var _base_activity := ""
var _badge: Node3D
var _mouth_detail: Node3D
var _skin_color := Color.WHITE
var _coat_color := Color.WHITE
var _walk_rig:Array[Node3D]=[]
var _walk_knees:Array[Node3D]=[]
var _walk_speed:=0.0
var _walk_phase:=0.0
var _routine_pose:=""
var _clipboard:Node3D
var _routine_cup:Node3D
var _routine_page:Node3D
static var _executive_leather: StandardMaterial3D
const ROLE_BADGES = {
	"mika": preload("res://assets/synaxis/badge_mika.svg"),
	"eli": preload("res://assets/synaxis/badge_eli.svg"),
	"reception": preload("res://assets/synaxis/badge_reception.svg"),
	"security": preload("res://assets/synaxis/badge_security.svg"),
}
static var _role_badge_materials: Dictionary = {}

func configure_staff(data: Dictionary) -> void:
	configure(data)
	display_name=str(data["name"])
	outfit=str(data["outfit"])
	hair_style=str(data["hair"])
	glasses=bool(data.get("glasses",false))
	_base_activity=activity
	_skin_color=Color(data.get("skin",SKINS[palette]))
	_coat_color=Color(data.get("coat",JACKETS[palette]))
	scale=Vector3(float(data.get("width",.78)),float(data.get("height",.91)),.82)

func _mat(kind: String,color: Color) -> StandardMaterial3D:
	if outfit=="executive_leather" and (kind=="LEATHER" or (kind=="FABRIC" and color==JACKETS[palette])):
		return _leather_material()
	if kind=="SKIN" and color==SKINS[palette]:
		color=_skin_color
	if kind=="FABRIC" and color==JACKETS[palette]:
		color=_coat_color
	return super._mat(kind,color)

static func _leather_material() -> StandardMaterial3D:
	if _executive_leather==null:
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color("202125")
		mat.roughness=.47
		mat.metallic=0.0
		# Fine matte grain, shared by all jacket pieces, generated once.
		var grain:=FastNoiseLite.new()
		grain.seed=307
		grain.frequency=.38
		var texture:=NoiseTexture2D.new()
		texture.width=128
		texture.height=128
		texture.seamless=true
		texture.as_normal_map=true
		texture.bump_strength=1.1
		texture.noise=grain
		mat.normal_enabled=true
		mat.normal_texture=texture
		mat.normal_scale=.30
		_executive_leather=mat
	return _executive_leather

func _build_executive_leather() -> void:
	var edge:=Color("34343a")
	var hardware:=Color("909397")
	var shirt:=Color("252b34")
	_box(_torso,"ExecutiveOpenNeck",Vector3(0,.31,.236),Vector3(.145,.12,.035),shirt,"FABRIC")
	for side in [-1.0,1.0]:
		var fold:=_box(_torso,"LeatherCollar",Vector3(side*.12,.28,.238),Vector3(.095,.24,.038),edge,"LEATHER")
		fold.rotation.z=side*.42
		var seam:=_box(_torso,"FrontPanelSeam",Vector3(side*.19,-.095,.211),Vector3(.012,.43,.018),edge,"FABRIC")
		seam.rotation.z=side*.08
		var pocket:=_box(_torso,"ZippedWeltPocket",Vector3(side*.20,-.17,.225),Vector3(.14,.023,.018),hardware,"METAL")
		pocket.rotation.z=side*.19
		_box(_torso,"PocketZipperPull",Vector3(side*.245,-.183,.242),Vector3(.022,.042,.011),hardware,"METAL")
		var shoulder:=_ellipsoid(_torso,"LeatherShoulderPanel",Vector3(side*.33,.235,.015),Vector3(.25,.17,.31),edge,"LEATHER")
		shoulder.rotation.z=-side*.22
	_box(_torso,"MainZipperTrack",Vector3(0,-.175,.231),Vector3(.021,.31,.017),hardware,"METAL")
	_box(_torso,"MainZipperPull",Vector3(.015,-.02,.246),Vector3(.028,.058,.015),hardware,"METAL")
	_box(_torso,"JacketHem",Vector3(0,-.36,.115),Vector3(.48,.055,.20),edge,"LEATHER")
	# A distinctive small fictional executive pin, not a real company logo.
	_box(_torso,"FounderPin",Vector3(-.165,.20,.262),Vector3(.046,.027,.016),Color("76b6b0"),"METAL")

func _ready() -> void:
	super._ready()
	# Remove leisure headwear and generic union tags from office actors.
	for child in _head.get_children():
		if str(child.name) in ["WorkShiftBeanie","TaperedHairFringe","HairCap"]:
			child.hide()
	for child in _torso.get_children():
		if str(child.name) in ["UnionShiftTag","Collar"]:
			child.hide()
	var hair: Color = HAIRS[palette]
	if hair_style=="silver":
		hair=Color("777779")
	elif hair_style=="dark":
		hair=Color("27252b")
	_ellipsoid(_head,"HairCrown",Vector3(0,.16,-.045),Vector3(.442,.28,.406),hair,"HAIR")
	if hair_style=="bun":
		_ellipsoid(_head,"HairBun",Vector3(0,.08,-.235),Vector3(.20,.23,.22),hair,"HAIR")
	elif hair_style=="cropped":
		get_node("BreathingTorso/LookHead/HairCrown").scale.y=.15
	else:
		var fringe:=_ellipsoid(_head,"SidePart",Vector3(-.085,.16,.14),Vector3(.28,.115,.16),hair,"HAIR")
		fringe.rotation.z=-.16
	for side in [-1.0,1.0]:
		var x: float=side*.105
		var brow:=_ellipsoid(_head,"Brow",Vector3(x,.088,.209),Vector3(.09,.016,.022),hair,"HAIR")
		brow.rotation.z=side*.07
		if glasses:
			for offset in [-.048,.048]:
				_box(_head,"SpectacleRim",Vector3(x+offset,.038,.239),Vector3(.009,.064,.016),Color("303239"),"METAL")
			for offset in [-.031,.031]:
				_box(_head,"SpectacleRim",Vector3(x,.038+offset,.239),Vector3(.101,.009,.016),Color("303239"),"METAL")
	if glasses:
		_box(_head,"SpectacleBridge",Vector3(0,.045,.238),Vector3(.107,.012,.016),Color("303239"),"METAL")
	_mouth_detail=_head.get_node_or_null("Mouth")
	var shirt:=Color("252b34") if outfit=="executive_leather" else (Color("d9dbd6") if outfit!="security" else Color("8295a3"))
	_box(_torso,"ShirtFront",Vector3(0,.12,.205),Vector3(.20,.49,.036),shirt,"FABRIC")
	if outfit=="executive_leather":
		_build_executive_leather()
	elif outfit in ["executive","hr","security","supervisor"]:
		for side in [-1.0,1.0]:
			var lapel:=_box(_torso,"NotchLapel",Vector3(side*.13,.12,.231),Vector3(.09,.42,.026),_coat_color.lightened(.10),"FABRIC")
			lapel.rotation.z=side*.30
		var tie_color:=Color("713943") if outfit=="executive" else Color("364c63")
		_box(_torso,"TieKnot",Vector3(0,.32,.239),Vector3(.061,.068,.035),tie_color,"FABRIC")
		_box(_torso,"TieBlade",Vector3(0,.13,.239),Vector3(.055,.32,.029),tie_color,"FABRIC")
		for y in [-.15,-.25]:
			_cylinder(_torso,"JacketButton",Vector3(0,y,.22),.017,.019,_coat_color.darkened(.4),"FABRIC").rotation.x=PI/2
	else:
		_box(_torso,"OpenCollar",Vector3(0,.32,.231),Vector3(.17,.08,.028),shirt,"FABRIC")
	_badge=_pivot(_torso,"SynaxisEmployeeBadge",Vector3(-.23,.04,.24))
	_box(_badge,"BadgeCard",Vector3.ZERO,Vector3(.103,.139,.016),Color("cdd3d2"),"FABRIC")
	_box(_badge,"BadgeStripe",Vector3(0,.047,.012),Vector3(.095,.029,.008),Color("277e83"),"FABRIC")
	_box(_badge,"BadgePortrait",Vector3(-.025,-.008,.012),Vector3(.032,.048,.008),_skin_color,"FABRIC")
	_box(_badge,"BadgeText",Vector3(.019,-.014,.012),Vector3(.039,.013,.008),Color("37454d"),"FABRIC")
	if ROLE_BADGES.has(resident_id):
		_install_role_badge()
	if outfit=="retail":
		_badge.hide()
		_box(_torso,"RetailNameTag",Vector3(-.19,.16,.248),Vector3(.102,.041,.015),Color("c6ae86"),"METAL")
	if outfit=="executive" or outfit=="hr":
		_box(_torso,"ExecutivePocketSquare",Vector3(.19,.24,.25),Vector3(.10,.042,.018),Color("e2d9c8"),"FABRIC")
		_box(_right_hand,"ExecutiveWatch",Vector3(0,.08,.06),Vector3(.069,.047,.025),Color("b69a66"),"METAL")
	if outfit=="security":
		_box(_torso,"RadioBody",Vector3(.25,.21,.24),Vector3(.10,.19,.045),Color("202a32"),"FABRIC")
		_box(_torso,"RadioAntenna",Vector3(.28,.35,.24),Vector3(.018,.16,.018),Color("202a32"),"METAL")
	if outfit=="technician":
		_box(_torso,"DiagnosticTablet",Vector3(.26,-.26,.37),Vector3(.22,.28,.025),Color("313e48"),"METAL")
		_box(_torso,"DiagnosticScreen",Vector3(.26,-.26,.389),Vector3(.19,.25,.008),Color("62a8a8"),"SCREEN")
	for child in _torso.get_children():
		if str(child.name)=="Hand":
			_left_wrist=child
			break

func _install_role_badge() -> void:
	# Keep the existing card body; replace raised placeholder marks with
	# a shared, depth-tested printed face. This is for fallback staff only.
	for child in _badge.get_children():
		if str(child.name) != "BadgeCard":
			child.hide()
	if not _role_badge_materials.has(resident_id):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ROLE_BADGES[resident_id]
		mat.roughness = .76
		_role_badge_materials[resident_id] = mat
	var face := MeshInstance3D.new()
	face.name = "RoleBadgePrint"
	var quad := QuadMesh.new()
	quad.size = Vector2(.099,.135)
	face.mesh = quad
	face.material_override = _role_badge_materials[resident_id]
	face.position.z = .009
	_badge.add_child(face)

func enable_walk_rig() -> void:
	if seated or not _walk_rig.is_empty():
		return
	# Replace only the opted-in actor's rigid standing legs. Keep identity,
	# upper-body detail, idle animation and material cache shared.
	for child in get_children():
		if child is MeshInstance3D and (absf(child.position.y-.47)<.01 or absf(child.position.y-.10)<.01):
			child.hide()
	for side in [-1.0,1.0]:
		var hip:=_pivot(self,"WalkingHip",Vector3(side*.18,.92,0))
		_ellipsoid(hip,"TrouserThigh",Vector3(0,-.22,0),Vector3(.22,.46,.25),_coat_color.darkened(.18),"FABRIC")
		var knee:=_pivot(hip,"WalkingKnee",Vector3(0,-.43,0))
		_ellipsoid(knee,"TrouserShin",Vector3(0,-.19,0),Vector3(.19,.43,.21),_coat_color.darkened(.21),"FABRIC")
		_ellipsoid(knee,"WalkingShoe",Vector3(0,-.39,.10),Vector3(.25,.18,.38),Color("292e34"),"FABRIC")
		_walk_rig.append(hip)
		_walk_knees.append(knee)

func enable_routine_props() -> void:
	if is_instance_valid(_clipboard):
		return
	_clipboard=_pivot(_right_hand,"TaskClipboard",Vector3(0,-.09,.11))
	_box(_clipboard,"Backing",Vector3.ZERO,Vector3(.24,.31,.022),Color("6b5b49"),"FABRIC")
	_box(_clipboard,"TaskSheet",Vector3(0,0,.016),Vector3(.215,.275,.010),Color("e6e2d6"),"FABRIC")
	_box(_clipboard,"Clip",Vector3(0,.135,.027),Vector3(.105,.035,.018),Color("77868a"),"METAL")
	for i in range(5):
		_box(_clipboard,"TaskLine",Vector3(.025,.085-i*.041,.023),Vector3(.13,.008,.006),Color("647573"),"FABRIC")
		_box(_clipboard,"TaskCheck",Vector3(-.079,.085-i*.041,.023),Vector3(.017,.017,.006),Color("52867e"),"FABRIC")
	_clipboard.hide()
	_routine_cup=_pivot(_right_hand,"RoutineCoffee",Vector3(0,.03,.12))
	_cylinder(_routine_cup,"Cup",Vector3.ZERO,.065,.15,Color("d1c1a7"),"FABRIC")
	_cylinder(_routine_cup,"Lid",Vector3(0,.079,0),.069,.018,Color("454b4a"),"FABRIC")
	_routine_cup.hide()
	_routine_page=_pivot(_right_hand,"RoutinePrintout",Vector3(0,-.08,.12))
	_box(_routine_page,"Page",Vector3.ZERO,Vector3(.20,.28,.009),Color("eeeade"),"FABRIC")
	for i in range(5):
		_box(_routine_page,"PrintLine",Vector3(0,.09-i*.035,.008),Vector3(.15,.006,.003),Color("667472"),"FABRIC")
	_routine_page.hide()
	_sync_routine_props()

func set_routine_pose(pose:String) -> void:
	if _routine_pose==pose:
		return
	_routine_pose=pose
	_sync_routine_props()

func _sync_routine_props() -> void:
	var pose:=_routine_pose
	if is_instance_valid(_clipboard):
		_clipboard.visible=pose in ["carry","board"]
	if is_instance_valid(_routine_cup):
		_routine_cup.visible=pose in ["cup","sip"]
	if is_instance_valid(_routine_page):
		_routine_page.visible=pose=="page"

func _animate_routine(delta:float,t:float) -> void:
	if _routine_pose=="board":
		_right_hand.position.y=lerpf(_right_hand.position.y,-.19,clampf(delta*8.0,0.0,1.0))
		_right_hand.position.z=.34
		_right_hand.rotation.x=-.38
		_head.rotation.x=.09
		if is_instance_valid(_clipboard):
			_clipboard.rotation.x=.32
	elif _routine_pose=="carry":
		_right_hand.position.y=-.42
		_right_hand.position.z=.24
		_right_hand.rotation.x=.15
		if is_instance_valid(_clipboard):
			_clipboard.rotation.x=.10
	elif _routine_pose=="appliance":
		_right_hand.position.y=-.27
		_right_hand.position.z=.43
		_right_hand.rotation.x=-.15
	elif _routine_pose in ["cup","sip","page"]:
		var lift:=.23*pow(maxf(0.0,sin(t*1.6)),2.0) if _routine_pose=="sip" else 0.0
		_right_hand.position.y=-.36+lift
		_right_hand.position.z=.25+lift*.2
		_right_hand.rotation.x=-lift*.9
	elif _routine_pose=="chat":
		_right_hand.position.y=-.40+.085*maxf(0.0,sin(t*2.0))
		_right_hand.position.z=.23
		_right_hand.rotation.x=.08

func set_walk_speed(speed:float) -> void:
	_walk_speed=clampf(speed,0.0,1.1)

func _animate_walk(delta:float) -> void:
	if _walk_rig.is_empty():
		return
	var amount:=clampf(_walk_speed/.85,0.0,1.0)
	_walk_phase=fposmod(_walk_phase+delta*_walk_speed*TAU/.66,TAU)
	var blend:=clampf(delta*10.0,0.0,1.0)
	for i in range(2):
		var swing:=sin(_walk_phase+float(i)*PI)
		_walk_rig[i].rotation.x=lerpf(_walk_rig[i].rotation.x,-swing*.34*amount,blend)
		_walk_knees[i].rotation.x=lerpf(_walk_knees[i].rotation.x,maxf(0.0,-swing)*.36*amount,blend)
	_torso.position.y+=absf(sin(_walk_phase))*.018*amount
	_torso.rotation.z+=sin(_walk_phase)*.027*amount
	if amount>.02:
		_right_hand.position.z=.19+sin(_walk_phase)*.12*amount
		if is_instance_valid(_left_wrist):
			_left_wrist.position.z=.17-sin(_walk_phase)*.12*amount

func attend(target: Vector3,active: bool) -> void:
	_attentive=active and target.is_finite()
	var imported:=get_node_or_null("CreatorCastVisual")
	if is_instance_valid(imported):
		imported.call("set_attention_target",target,_attentive)
	if _attentive:
		var local:=to_local(target)
		_attention_yaw=clampf(atan2(local.x,maxf(.2,local.z)),-.63,.63)

func set_scene_beat(beat: int) -> void:
	_scene_beat=beat

func get_staff_state() -> Dictionary:
	return {"id":resident_id,"name":display_name,"outfit":outfit,"hair":hair_style,"attention":_attentive,"beat":_scene_beat,"activity":activity}

func _process(delta: float) -> void:
	super._process(delta)
	if _head==null:
		return
	var t:=_clock+phase
	if _attentive:
		_head.rotation.y=lerpf(_head.rotation.y,_attention_yaw,clampf(delta*8.0,0.0,1.0))
		_head.rotation.x=-.045
	if _right_hand!=null:
		if _base_activity=="TYPE" and not _attentive:
			_right_hand.position.z=.29+sin(t*7.5)*.018
			_right_hand.position.y=-.36+sin(t*11.0)*.015
			if _left_wrist!=null:
				_left_wrist.position.y=-.40+sin(t*9.0)*.018
		elif _base_activity=="WATCH":
			_right_hand.position.y=-.40+pow(maxf(0.0,sin(t*.6)),5.0)*.13
		if _scene_beat>=0:
			_right_hand.position.y=-.40+(.14 if _scene_beat==2 else .06)*absf(sin(t*2.1))
			_head.rotation.x=.045 if _scene_beat==2 else -.025
			if outfit=="executive_leather" and _scene_beat==1:
				# Briefly look toward the assistant, then hold an uneasy silence.
				_head.rotation.y=lerpf(_head.rotation.y,.38,clampf(delta*3.0,0.0,1.0))
				_right_hand.position.y=-.40
	if _mouth_detail!=null:
		_mouth_detail.scale.y=.018*(1.0+.25*absf(sin(t*13.0))) if _scene_beat>=0 else .018
	_animate_walk(delta)
	_animate_routine(delta,t)
