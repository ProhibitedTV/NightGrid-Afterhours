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
	if kind=="SKIN" and color==SKINS[palette]:
		color=_skin_color
	if kind=="FABRIC" and color==JACKETS[palette]:
		color=_coat_color
	return super._mat(kind,color)

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
	var shirt:=Color("d9dbd6") if outfit!="security" else Color("8295a3")
	_box(_torso,"ShirtFront",Vector3(0,.12,.205),Vector3(.20,.49,.036),shirt,"FABRIC")
	if outfit in ["executive","hr","security","supervisor"]:
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
	if _mouth_detail!=null:
		_mouth_detail.scale.y=.018*(1.0+.25*absf(sin(t*13.0))) if _scene_beat>=0 else .018
