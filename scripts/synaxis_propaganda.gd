extends Node3D
## Original, static corporate print artwork. Each board has a fixed wall
## transform and real panel geometry. No billboard, timer, network or collider.
const INK = Color("12232f")
const PAPER = Color("e8e8df")
const GOLD = Color("f1c879")
const AQUA = Color("95e3d6")
const NAVY = Color("152e40")
const WHITE = Color("f3f5f0")
const RED = Color("ad4040")
const BLUE = Color("355969")

func _ready() -> void:
	# Local coordinates match the permanent Synaxis ground floor.
	_board("QuarterlyRecord",Vector3(8.31,1.95,2.0),-PI/2,Vector2(3.6,1.75),NAVY,GOLD,WHITE,
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
	_board("Wellness",Vector3(.0,1.98,9.81),PI,Vector2(3.15,1.6),PAPER,BLUE,INK,
		"WORKPLACE WELLNESS / 2036","TAKE CARE OF YOURSELF.",
		"Wellness sessions are available off the clock.\nUnpaid participation is strongly encouraged.")

func _board(id: String,at: Vector3,yaw: float,dimensions: Vector2,background: Color,accent: Color,ink: Color,eyebrow: String,headline: String,body: String) -> void:
	var root := Node3D.new()
	root.name=id
	root.position=at
	root.rotation.y=yaw
	add_child(root)
	_quad(root,"Backing",dimensions,Vector3.ZERO,background)
	_quad(root,"BrandStripe",Vector2(dimensions.x,.055),Vector3(0,dimensions.y*.5-.028,.004),accent)
	# Real font metrics fit each authored line inside its panel at world scale.
	_copy(root,"Department",eyebrow,Vector3(0,dimensions.y*.33,.012),dimensions.x-.20,dimensions.y*.09,accent)
	_copy(root,"Headline",headline,Vector3(0,dimensions.y*.11,.012),dimensions.x-.20,dimensions.y*.29,ink)
	_copy(root,"FinePrint",body,Vector3(0,-dimensions.y*.25,.012),dimensions.x-.20,dimensions.y*.33,ink)

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
