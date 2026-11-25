extends Node3D
## Isolated, bounded introductory office set. Built once, removed before city play.
## Existing player rig and collision controller; no additional player or city streamer.
const ORIGIN = Vector3(0,48,0)
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
	_solid("NorthWall",Vector3(0,1.75,-10),Vector3(17,3.5,.25),wall)
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
