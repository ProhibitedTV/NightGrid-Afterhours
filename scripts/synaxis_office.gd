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
var _security: StaticBody3D
const Patron = preload("res://scripts/lantern_patron.gd")
const Assistant = preload("res://scripts/synaxis_assistant.gd")
var _assistant: Node3D
var _ceo: Node3D
var _hr: Node3D
const START = Vector3(0,1.15,7)
const POINTS = {0:Vector3(-5,1.15,4),2:Vector3(5,1.15,-4),4:Vector3(-5,1.15,-4),5:Vector3(5,1.15,5)}
const TITLES = {0:"IT DESK / REVIEW THE ALERT",2:"EXECUTIVE OFFICE / ATTEND BRIEFING",4:"PEOPLE EXPERIENCE / EXIT INTERVIEW",5:"RECEPTION / COLLECT FINAL NOTICE"}
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
	_solid("SecurityGate",Vector3(0,1.4,-10),Vector3(2.6,2.8,.25),_material("security",Color("293842")))
	_sign("SYNAXIS / EMPLOYEE ACCESS",Vector3(0,2.95,-10.17),.006).rotation.y = PI
	_sign("BADGE REQUIRED",Vector3(0,1.65,-10.17),.005).rotation.y = PI
	# Fixed upper-floor shell, not a second generic building intersecting the office.
	_solid("TowerCore",Vector3(0,27,0),Vector3(17,46.7,20),_material("glass",Color("354c60")))
	for floor in range(12):
		var y := 5.4+float(floor)*3.65
		_visual("FacadeSpandrel",Vector3(0,y,-10.13),Vector3(17,.36,.16),accent)
	_visual("Crown",Vector3(0,50.8,0),Vector3(17.5,.75,20.5),desk)
	_sign("SYNAXIS",Vector3(0,49.2,-10.24),.028).rotation.y = PI
	_solid("SouthWall",Vector3(0,1.75,10),Vector3(17,3.5,.25),wall)
	_solid("WestWall",Vector3(-8.5,1.75,0),Vector3(.25,3.5,20),wall)
	_solid("EastWall",Vector3(8.5,1.75,0),Vector3(.25,3.5,20),wall)
	_solid("ExecutivePartition",Vector3(0,1.5,-5.8),Vector3(.18,3.0,7),wall)
	_solid("Workstation",Vector3(-5,.54,2.55),Vector3(2.6,1.08,.85),desk)
	_solid("ExecutiveDesk",Vector3(5,.54,-5.4),Vector3(3.8,1.08,1.0),desk)
	_solid("HRDesk",Vector3(-5,.54,-5.4),Vector3(2.7,1.08,1.0),desk)
	_solid("ReceptionDesk",Vector3(5,.54,6.5),Vector3(3,1.08,.9),desk)
	for point in [Vector3(-5,1.37,2.55),Vector3(5,1.37,-5.4),Vector3(-5,1.37,-5.4)]:
		_visual("Terminal",point,Vector3(.68,.46,.12),screen)
		_visual("TerminalBase",point-Vector3.UP*.26,Vector3(.44,.07,.3),accent)
	_visual("ExitBox",Vector3(5,1.25,6.5),Vector3(.42,.34,.4),_material("cardboard",Color("a88a63")))
	for z in [-7.5,-2.5,2.5,7.5]:
		_visual("CeilingStrip",Vector3(0,3.28,z),Vector3(12,.055,.18),_material("light",Color("c9dfdf"),true))
		var light := OmniLight3D.new()
		light.position = Vector3(0,2.95,z)
		light.omni_range = 9.5
		light.light_energy = 1.25
		light.shadow_enabled = false
		add_child(light)
	_sign("SYNAXIS OMNISYSTEMS",Vector3(0,2.55,-9.8),.012)
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
	set_stage(0)
	_target_sign.hide()
	_intro_canvas.hide()
	# Ground-floor furniture and collision remain; stage lighting is local.
	for light in find_children("*","OmniLight3D",true,false):
		light.hide()

func begin_prologue() -> void:
	if not is_instance_valid(_cast):
		_build_cast()
	_target_sign.show()
	_intro_canvas.show()
	for light in find_children("*","OmniLight3D",true,false):
		light.show()
	set_stage(0)

func finish_prologue() -> void:
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
	_hint.text = "SYNAXIS / EXECUTIVE PRIVILEGE\n%s\n%s" % [TITLES[stage],("X / INTERACT" if gamepad else "G / INTERACT") if reachable(stage,at) else "%dm to objective" % roundi(at.distance_to(point(stage)))]
