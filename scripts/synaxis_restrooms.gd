extends Node3D
## Physical washrooms with privacy stalls, original fixtures and an optional
## one-shot corporate facilities encounter. No identity or hygiene simulation.
const MEN = "men"
const WOMEN = "women"
const CENTERS = {MEN:Vector3(-1.15,1.15,7.35),WOMEN:Vector3(1.15,1.15,7.35)}
const WALL_EDGES = [
	[Vector2(-2.35,6.25),Vector2(-2.35,9.76)],
	[Vector2(2.35,6.25),Vector2(2.35,9.76)],
	[Vector2(0,6.25),Vector2(0,9.76)],
	[Vector2(-2.35,6.25),Vector2(-1.82,6.25)],
	[Vector2(-.48,6.25),Vector2(0,6.25)],
	[Vector2(0,6.25),Vector2(.48,6.25)],
	[Vector2(1.82,6.25),Vector2(2.35,6.25)]
]
const MEN_DIALOGUE = "DEV (FROM A CLOSED STALL): Did they fix the extractor fan?\nARJUN: No. Facilities classified the smell as a non-blocking defect.\nDEV: I came from Bengaluru on an H-1B to work on distributed systems. This is the worst distributed system I've ever encountered.\nARJUN: I told HR the appreciation-day pizza was expired. They asked me to be more culturally sensitive to the catering budget.\nVOICE FROM NEXT STALL: PLEASE OPEN A WINDOW.\nFACILITIES DISPLAY: AIR QUALITY WITHIN ACCEPTABLE BUSINESS PARAMETERS."
const WOMEN_DIALOGUE = "FACILITIES TERMINAL: Are you entering the women's restroom? Do you identify as a woman now?\nPLAYER: I was looking for the sink.\nTERMINAL: Your answer has been forwarded to People Experience.\nPLAYER: Can I just wash my hands?\nTERMINAL: Please complete the inclusive facilities training module. Estimated time: 47 minutes.\nEMPLOYEE: Ignore it. They installed that thing instead of fixing the soap dispenser."
var _seen: Dictionary = {}
var _active := false
var _haze: GPUParticles3D
var _materials: Dictionary = {}

func _ready() -> void:
	for edge in WALL_EDGES:
		var a: Vector2=edge[0]
		var b: Vector2=edge[1]
		var center: Vector2=(a+b)*.5
		var length: Vector2=(b-a).abs()
		_box("Partition",Vector3(center.x,1.48,center.y),Vector3(maxf(length.x,.10),2.96,maxf(length.y,.10)),"tile",true)
	for id in [MEN,WOMEN]:
		var x: float=CENTERS[id].x
		_box("DoorHeader",Vector3(x,2.95,6.25),Vector3(1.34,.42,.12),"metal",true)
		_sign(id.to_upper()+" / RESTROOM",Vector3(x,2.95,6.16),PI,.0027)
		_box("FloorMat",Vector3(x,.009,7.8),Vector3(1.9,.012,2.6),"floor")
		# Shared bathroom partition with two individually shut stalls in each room.
		for dx in [-.52,.52]:
			_box("ClosedStall",Vector3(x+dx,1.19,8.52),Vector3(.96,1.9,.07),"stall",true)
			_box("StallLatch",Vector3(x+dx+.27,1.03,8.475),Vector3(.11,.045,.04),"metal")
			_box("OccupiedIndicator",Vector3(x+dx-.27,1.03,8.475),Vector3(.07,.05,.02),"red")
			_box("StallFoot",Vector3(x+dx,.14,8.52),Vector3(.07,.28,.07),"metal")
		_box("StallDivider",Vector3(x,1.17,9.14),Vector3(.065,1.94,1.2),"stall",true)
		# Compact basin against the side wall, taps and mirror, no collision in aisle.
		var basin_x: float=x+(-.77 if id==MEN else .77)
		_box("Basin",Vector3(basin_x,.93,7.46),Vector3(.38,.19,.49),"porcelain",true)
		_box("BasinInset",Vector3(basin_x,1.032,7.46),Vector3(.27,.012,.33),"floor")
		_box("Tap",Vector3(basin_x,1.15,7.28),Vector3(.06,.20,.06),"metal")
		_box("TapSpout",Vector3(basin_x,1.23,7.36),Vector3(.06,.05,.17),"metal")
		_box("Mirror",Vector3(basin_x+(-.20 if id==MEN else .20),1.65,7.46),Vector3(.025,.77,.65),"mirror")
		_box("SoapDispenser",Vector3(basin_x,1.23,7.72),Vector3(.12,.20,.10),"porcelain")
	_sign("EXTRACTOR / SERVICE DEFERRED",Vector3(-1.15,2.67,8.47),PI,.0020)
	_sign("FACILITIES / INCLUSION TERMINAL",Vector3(1.15,2.67,8.47),PI,.0020)
	_build_haze()

func _mat(key: String) -> StandardMaterial3D:
	if not _materials.has(key):
		var colors := {"tile":"7f8b8e","floor":"4a5a60","metal":"a7b3b7","stall":"58676e","porcelain":"dce5e1","mirror":"6a8996","red":"c86b61"}
		var mat := StandardMaterial3D.new()
		mat.albedo_color=Color(colors[key])
		mat.roughness=.35 if key in ["metal","mirror","porcelain"] else .78
		mat.metallic=.55 if key in ["metal","mirror"] else 0.0
		_materials[key]=mat
	return _materials[key]

func _box(id: String,at: Vector3,size: Vector3,key: String,solid: bool=false) -> void:
	var node := MeshInstance3D.new()
	node.name=id
	node.position=at
	var mesh := BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.material_override=_mat(key)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	if solid:
		var body := StaticBody3D.new()
		body.position=at
		var shape := BoxShape3D.new()
		shape.size=size
		var collider := CollisionShape3D.new()
		collider.shape=shape
		body.add_child(collider)
		add_child(body)

func _sign(value: String,at: Vector3,yaw: float,pixel: float) -> void:
	var label := Label3D.new()
	label.text=value
	label.position=at
	label.rotation.y=yaw
	label.font_size=40
	label.pixel_size=pixel
	label.outline_size=2
	add_child(label)

func _build_haze() -> void:
	# Small bounded soft sprites; only active near the men's washroom in prologue.
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color(.51,.78,.18,.32),Color(.35,.62,.13,0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient=gradient
	texture.width=64
	texture.height=64
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5)
	texture.fill_to=Vector2(1,.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture=texture
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size=Vector2(.65,.65)
	quad.material=mat
	var motion := ParticleProcessMaterial.new()
	motion.direction=Vector3(0,.45,-1)
	motion.spread=34
	motion.gravity=Vector3(0,.16,0)
	motion.initial_velocity_min=.12
	motion.initial_velocity_max=.35
	motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents=Vector3(.82,.025,.03)
	motion.scale_min=.55
	motion.scale_max=1.25
	_haze=GPUParticles3D.new()
	_haze.name="ExtractorHaze"
	_haze.position=Vector3(-1.15,.30,8.43)
	_haze.amount=24
	_haze.lifetime=3.5
	_haze.process_material=motion
	_haze.draw_pass_1=quad
	_haze.visibility_aabb=AABB(Vector3(-1.4,-.3,-2),Vector3(2.8,2.4,2.5))
	_haze.emitting=false
	_haze.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_haze)

func begin_visit() -> void:
	_seen.clear()
	_active=true

func end_visit() -> void:
	_active=false
	_haze.emitting=false

func encounter(at: Vector3) -> String:
	if not _active or not at.is_finite():
		return ""
	# Require actual interior occupancy beyond the doorway, not wall proximity.
	for id in [MEN,WOMEN]:
		var center: Vector3=CENTERS[id]
		if absf(at.x-center.x)<.91 and at.z>6.85 and at.z<8.36 and absf(at.y-center.y)<.8 and not _seen.has(id):
			_seen[id]=true
			return id
	return ""

func update_effects(at: Vector3) -> void:
	var active := _active and at.is_finite() and at.distance_squared_to(CENTERS[MEN])<16.0
	if _haze.emitting!=active:
		_haze.emitting=active
