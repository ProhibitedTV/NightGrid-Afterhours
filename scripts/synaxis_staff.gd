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
static var _executive_leather: StandardMaterial3D

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
	var hair := HAIRS[palette]
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

func attend(target: Vector3,active: bool) -> void:
	_attentive=active and target.is_finite()
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
