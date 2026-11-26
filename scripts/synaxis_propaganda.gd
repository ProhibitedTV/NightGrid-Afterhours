extends Node3D
## Original, static corporate print artwork. Each board has a fixed wall
## transform and real panel geometry. No billboard, timer, network or collider.
const Brand = preload("res://scripts/synaxis_brand.gd")
const INK = Brand.INK
const PAPER = Brand.PAPER
const GOLD = Brand.GOLD
const AQUA = Brand.AQUA
const NAVY = Brand.NAVY
const WHITE = Brand.WHITE
const RED = Brand.RED
const BLUE = Brand.BLUE

func _ready() -> void:
	# Local coordinates match the permanent Synaxis ground floor.
	_board("QuarterlyRecord",Vector3(8.31,1.95,1.25),-PI/2,Vector2(3.6,1.75),NAVY,GOLD,WHITE,
		"INVESTOR RELATIONS / Q3 2036","$14.8 BILLION\nQUARTERLY PROFIT",
		"OUR BEST QUARTER YET.\nThank you for doing more with less.")
	_board("HealthRenewal",Vector3(-8.31,1.92,-5.5),PI/2,Vector2(2.55,1.8),PAPER,RED,INK,
		"PEOPLE EXPERIENCE / BENEFITS","YOUR PREMIUM IS UP 24%",
		"$186  >  $231 PER PAY PERIOD\nPlease confirm payroll deductions.\nYour health is our priority.*\n*Subject to plan terms and eligibility.")
	_board("PublicCelebration",Vector3(3.15,2.03,-7.80),PI,Vector2(2.5,1.34),NAVY,AQUA,WHITE,
		"SYNAXIS / SHAREHOLDER UPDATE","RECORD PROFITS.\nRECORD EFFICIENCY.",
		"Together, we eliminated 8,400 roles.\nThe future belongs to all of us.*\n*Shareholders of record.")
	_board("BenefitsReminder",Vector3(-3.15,2.03,-7.80),PI,Vector2(2.5,1.34),PAPER,RED,INK,
		"PAYROLL / ACTION REQUIRED","DON'T FORGET\nOPEN ENROLLMENT",
		"New deductible: $6,200.\nLate enrollment? Try next year.")
	_board("ExitCampaign",Vector3(-4.7,1.98,9.81),PI,Vector2(3.2,1.6),BLUE,GOLD,WHITE,
		"OUR PEOPLE. OUR PURPOSE.","WE INVEST IN PEOPLE.",
		"Voluntary separation is a growth opportunity.\nBenefits terminate at the end of employment.")
	_board("Wellness",Vector3(-3.38,1.98,-1.5),PI/2,Vector2(3.15,1.6),PAPER,BLUE,INK,
		"WORKPLACE WELLNESS / 2036","TAKE CARE OF YOURSELF.",
		"Wellness sessions are available off the clock.\nUnpaid participation is strongly encouraged.")

	# Each department gets its own contradictions, rather than repeating one gag.
	_board("OfficeAttendance",Vector3(-8.31,2.06,4.10),PI/2,Vector2(2.65,1.62),NAVY,AQUA,WHITE,
		"WORKPLACE EXPERIENCE / BADGE METRICS","TOGETHER, IN PERSON.",
		"5 days a week. No exceptions.\nYour manager will join remotely.\nParking subscriptions: $169/month.")
	_board("Calibration",Vector3(-.108,1.87,-3.8),-PI/2,Vector2(2.4,1.55),PAPER,RED,INK,
		"PEOPLE OPERATIONS / PERFORMANCE","EXCEED EXPECTATIONS.\nNOT THE BUDGET.",
		"95% of staff met all objectives.\nCalibration requires 15% below expectations.\nManagers: please reconcile.")
	_board("AIPledge",Vector3(8.31,1.85,-1.85),-PI/2,Vector2(2.9,1.65),NAVY,AQUA,WHITE,
		"SYNAXIS ASSISTANT ENTERPRISE","YOUR AI COLLEAGUE\nNEEDS YOU.",
		"Record your daily workflow.\nTrain the future of your role.\nA more human workplace, with fewer humans.")
	_board("PTOFreeze",Vector3(-5.8,1.96,.34),0.0,Vector2(2.2,1.55),PAPER,RED,INK,
		"Q4 DELIVERY READINESS / ACTION REQUIRED","UNLIMITED PTO*",
		"*Requests paused until further notice.\nUnused unlimited days have no cash value.\nThank you for your flexibility.")
	_board("Meetings",Vector3(.108,1.85,-1.6),PI/2,Vector2(1.9,1.5),BLUE,GOLD,WHITE,
		"COLLABORATION EXCELLENCE","LESS TALK.\nMORE ACTION.",
		"Mandatory 90-minute alignment meeting.\nAgenda: reducing meeting overhead.\nPre-read: 78 slides.")
	_board("SpeakUp",Vector3(-.108,1.85,-6.1),-PI/2,Vector2(1.85,1.55),NAVY,AQUA,WHITE,
		"ETHICS / CONFIDENTIAL CHANNEL","SEE SOMETHING?\nSAY SOMETHING.",
		"Anonymous reports require your employee ID.\nAll reports routed to your leadership chain.")
	_board("Equity",Vector3(.108,1.85,-6.1),PI/2,Vector2(1.85,1.55),NAVY,GOLD,WHITE,
		"TOTAL REWARDS / EQUITY","OWN THE FUTURE.",
		"Liquidity event: postponed.\nExecutive cash bonus: paid.\nYour patience is a competitive advantage.")
	_board("Water",Vector3(29.39,1.94,20.0),-PI/2,Vector2(2.45,1.48),PAPER,BLUE,INK,
		"BREAKROOM / SUSTAINABILITY","BYO MUG. BYO COFFEE.",
		"Company-provided coffee discontinued.\nWe saved 0.002% of operating expense.\nWater remains complimentary for now.")
	_board("Recruiting",Vector3(5.25,1.97,-9.84),0.0,Vector2(2.9,1.58),NAVY,AQUA,WHITE,
		"TALENT ACQUISITION / CAREERS","WE'RE HIRING!",
		"Entry level: 12 years of experience.\nCompensation: competitive exposure.\nInternal candidates need not apply.")
	_board("LobbySurveillance",Vector3(-5.25,1.97,-9.84),0.0,Vector2(2.9,1.58),PAPER,RED,INK,
		"FACILITIES / SMART WORKPLACE","PRIVACY MATTERS.",
		"Badge, camera and keystroke monitoring active.\nWe respect your right to be informed.\nContinued entry constitutes acknowledgment.")

func _board(id: String,at: Vector3,yaw: float,dimensions: Vector2,background: Color,accent: Color,ink: Color,eyebrow: String,headline: String,body: String) -> void:
	var root := Node3D.new()
	root.name=id
	root.position=at
	root.rotation.y=yaw
	add_child(root)
	_quad(root,"Backing",dimensions,Vector3.ZERO,background)
	_quad(root,"BrandStripe",Vector2(dimensions.x,.055),Vector3(0,dimensions.y*.5-.028,.004),accent)
	# Real font metrics fit each authored line inside its panel at world scale.
	var logo_width:=minf(dimensions.x*.38,dimensions.y*.82)
	Brand.wall_logo(root,"BrandLockup",Vector3(-dimensions.x*.5+.12+logo_width*.5,dimensions.y*.34,.014),0.0,logo_width,background==PAPER)
	var department_width:=dimensions.x-logo_width-.38
	_copy(root,"Department",eyebrow,Vector3(dimensions.x*.5-.12-department_width*.5,dimensions.y*.34,.012),department_width,dimensions.y*.10,accent)
	_copy(root,"Headline",headline,Vector3(0,dimensions.y*.08,.012),dimensions.x-.20,dimensions.y*.28,ink)
	_copy(root,"FinePrint",body,Vector3(0,-dimensions.y*.25,.012),dimensions.x-.20,dimensions.y*.32,ink)

func _quad(parent: Node3D,id: String,size: Vector2,at: Vector3,tint: Color) -> void:
	var mesh := QuadMesh.new()
	mesh.size=size
	var instance := MeshInstance3D.new()
	instance.name=id
	instance.mesh=mesh
	instance.position=at
	var mat := StandardMaterial3D.new()
	mat.albedo_color=tint
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override=mat
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _copy(parent: Node3D,id: String,value: String,at: Vector3,width: float,height: float,tint: Color) -> void:
	var font := ThemeDB.fallback_font
	var longest := 1.0
	var lines := value.split("\n")
	for line in lines:
		longest=maxf(longest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x)
	var label := Label3D.new()
	label.name=id
	label.text=value
	label.font=font
	label.font_size=64
	label.pixel_size=minf(width/longest,height/(font.get_height(64)*lines.size()))
	label.outline_size=0
	label.modulate=tint
	label.position=at
	parent.add_child(label)
