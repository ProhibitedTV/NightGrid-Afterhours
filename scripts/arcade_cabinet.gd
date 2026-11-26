extends StaticBody3D
## Original static cabinet, face toward local +Z. No active viewport or per-frame scripts.
const Catalog = preload("res://scripts/arcade_round.gd")
const IDS = Catalog.IDS
const Scores = preload("res://scripts/arcade_scores.gd")
const KeyArt = preload("res://scripts/arcade_key_art.gd")
const ART = KeyArt.ART
const TINTS = {"grand_delay": "69d8c2", "claw_compliance": "efb169", "patch_day": "c4a2f3", "indie_dev": "f1cd82", "annual_warfare": "a5ca82", "day_one_dlc": "ed9db5", "open_world_checklist": "80bce9", "battle_pass_hero": "e6a1ef", "starline_patrol": "72d7cf", "neon_rebound": "f2a96b"}
const SERVICE_STICKERS = {"grand_delay":"RELEASE DATE: TBA", "claw_compliance":"APPROVED BY 12 COMMITTEES", "patch_day":"HOTFIX HOTLINE", "indie_dev":"MADE WITH WEEKENDS OFF", "annual_warfare":"RELOADS ARE FREE", "day_one_dlc":"ALL PARTS INCLUDED", "open_world_checklist":"SOCK NOT INCLUDED", "battle_pass_hero":"NO ATTENDANCE TRACKING", "starline_patrol":"RESTORED BY ROOK", "neon_rebound":"ORIGINAL BOARD / FREE PLAY"}
const CRT = preload("res://assets/arcade/attract_crt.gdshader")
const DeluxeCRT = preload("res://assets/arcade/grand_delay_crt.gdshader")
const DeluxeMarquee = preload("res://assets/arcade/grand_delay_marquee.svg")
var game_id := "grand_delay"
var _deluxe_wheel: Node3D
var _deluxe_button: MeshInstance3D
var _score_label: Label3D
static var materials: Dictionary = {}
static var screens: Dictionary = {}
static var printed_art: Dictionary = {}

func configure(id: String) -> bool:
	if is_inside_tree() or not ART.has(id):
		return false
	game_id = id
	return true

func _ready() -> void:
	var accent := Color(str(TINTS[game_id]))
	var dark := _mat(Color("222831"), 0.35)
	var edge := _mat(Color("45454a"), 0.55)
	var trim := _mat(accent, 0.28)
	var black := _mat(Color("090e13"), 0.16)
	var steel := _mat(Color("8b9094"), 0.62)
	_box("Plinth", Vector3(0,.10,0), Vector3(.87,.20,.84), edge)
	_box("LowerShell", Vector3(0,.58,0), Vector3(.83,.83,.79), dark)
	_box("UpperShell", Vector3(0,1.49,-.08), Vector3(.83,1.10,.63), dark)
	_box("Crown", Vector3(0,2.05,-.08), Vector3(.87,.17,.69), trim)
	_box("ControlDeck", Vector3(0,1.04,.34), Vector3(.84,.15,.43), edge)
	_box("ScreenBezel", Vector3(0,1.52,.251), Vector3(.74,.77,.07), black)
	_box("CoinDoor", Vector3(0,.59,.405), Vector3(.33,.37,.025), edge)
	_box("CoinSlot", Vector3(-.08,.69,.427), Vector3(.045,.10,.015), steel)
	_box("ReturnButton", Vector3(.09,.69,.427), Vector3(.07,.07,.018), trim)
	for x in [-.413,.413]:
		_box("EdgeTrim", Vector3(x,1.35,.24), Vector3(.035,1.26,.05), trim)
	_box("SpeakerGrille", Vector3(0,1.98,.275), Vector3(.59,.09,.035), black)
	for n in range(5):
		_box("Vent", Vector3(-.23+n*.115,1.98,.299), Vector3(.07,.015,.01), steel)
	if game_id != "grand_delay":
		_cylinder("JoystickStem", Vector3(-.22,1.18,.36), .018,.16,steel)
		var ball := SphereMesh.new()
		ball.radius = .047
		ball.height = .094
		_mesh("JoystickBall", ball, Vector3(-.22,1.28,.36), trim)
		for n in range(3):
			_cylinder("Button", Vector3(.04+n*.105,1.13,.36), .035,.035,trim if n == 0 else black)
	var screen := QuadMesh.new()
	screen.size = KeyArt.fit(game_id,Vector2(.59,.65))
	if not screens.has(game_id):
		var mat := ShaderMaterial.new()
		mat.shader = DeluxeCRT if game_id == "grand_delay" else CRT
		mat.set_shader_parameter("art",KeyArt.texture(game_id))
		screens[game_id] = mat
	_mesh("CRTAttract",screen,Vector3(0,1.52,.29),screens[game_id])
	var side := QuadMesh.new()
	side.size = KeyArt.fit(game_id,Vector2(.60,.77))
	if not printed_art.has(game_id):
		printed_art[game_id] = _printed(KeyArt.texture(game_id))
	for sign in [-1,1]:
		var panel_mat: Material = printed_art[game_id]
		var panel := _mesh("SideArt",side,Vector3(sign*.419,1.48,-.08),panel_mat)
		panel.rotation.y = sign * PI / 2.0
	var marquee := Label3D.new()
	marquee.name = "MarqueeTitle"
	marquee.text = str(Catalog.GAMES[game_id]["title"])
	marquee.font_size = 28
	marquee.pixel_size = .0012
	marquee.position = Vector3(0,2.05,.275)
	marquee.modulate = Color("10151d")
	marquee.outline_size = 0
	add_child(marquee)
	var sticker := Label3D.new()
	sticker.name = "ServiceSticker"
	sticker.text = str(SERVICE_STICKERS[game_id])
	sticker.font_size = 20
	sticker.pixel_size = .0015
	sticker.modulate = Color("c8bba4")
	sticker.position = Vector3(0,.31,.401)
	sticker.outline_size = 0
	add_child(sticker)
	if game_id == "grand_delay":
		marquee.hide()
		_deluxe_details()
	else:
		_union_details(accent)
	_score_label = Label3D.new()
	_score_label.name = "LocalScorePlate"
	_score_label.position = Vector3(0,.935,.432)
	_score_label.font_size = 20
	_score_label.pixel_size = .0013
	_score_label.modulate = Color("e9c283")
	_score_label.outline_size = 1
	add_child(_score_label)
	set_local_score({})
	_collision(Vector3(0,1.10,.03),Vector3(.87,2.16,.85))
	_collision(Vector3(0,1.04,.43),Vector3(.84,.15,.24))

# Updated only on room entry, save restoration, and a settled high score.
# No polling, network leaderboard, or duplicate score persistence.
func set_local_score(scores: Dictionary) -> void:
	if not is_instance_valid(_score_label):
		return
	var best := int(scores.get(game_id,0))
	var record := "%05d" % best if scores.has(game_id) else "-----"
	_score_label.text = "YOUR BEST %s  |  %d/3" % [record,Scores.mastery_level(game_id,best)]

func reachable(at: Vector3) -> bool:
	var p := to_local(at)
	return absf(p.x) <= .75 and p.z >= .58 and p.z <= 1.65 and p.y >= .35 and p.y <= 2.1

func _mat(tint: Color, metallic: float) -> StandardMaterial3D:
	var key := tint.to_html() + str(metallic)
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.metallic = metallic
		mat.roughness = .57
		materials[key] = mat
	return materials[key]

func _mesh(label: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node, true)
	return node

func _box(label: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_mesh(label,mesh,at,material)

func _cylinder(label: String, at: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	_mesh(label,mesh,at,material)

func _collision(at: Vector3, dimensions: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = at
	add_child(node)

# Deluxe cabinet: separate printed vinyl from the CRT, all static except GPU screen sweep.
func _printed(texture: Texture2D, illuminated: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.roughness = .42 if illuminated else .78
	if illuminated:
		mat.emission_enabled = true
		mat.emission_texture = texture
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = .65
	return mat

func _deluxe_details() -> void:
	var chrome := _mat(Color("899ca3"),.82)
	var rubber := _mat(Color("111a24"),.0)
	var warm := _mat(Color("f1b683"),.25)
	var led := StandardMaterial3D.new()
	led.albedo_color = Color("58e5ca")
	led.emission_enabled = true
	led.emission = Color("58e5ca")
	led.emission_energy_multiplier = 1.3
	var marquee_mesh := QuadMesh.new()
	marquee_mesh.size = Vector2(.79,.145)
	_mesh("DeluxeBacklitMarquee",marquee_mesh,Vector3(0,2.05,.278),_printed(DeluxeMarquee,true))
	for side_x in [-.405,.405]:
		_box("ChromeRail",Vector3(side_x,1.52,.293),Vector3(.018,.79,.025),chrome)
		_box("MarqueeLightPipe",Vector3(side_x,2.05,.282),Vector3(.015,.155,.02),led)
		_box("KickplateLightPipe",Vector3(side_x,.24,.403),Vector3(.018,.12,.025),led)
		for y in [.29,.91,1.12,1.91]:
			_cylinder("Fastener",Vector3(side_x,y,.411 if y < 1.0 else .31),.009,.012,chrome)
	for y in [1.14,1.90]:
		_box("CRTFrame",Vector3(0,y,.295),Vector3(.74,.025,.034),chrome)
	_box("Kickplate",Vector3(0,.19,.407),Vector3(.76,.12,.026),rubber)
	_box("CoinReturnTray",Vector3(0,.48,.431),Vector3(.16,.08,.04),rubber)
	_box("CoinReturnLip",Vector3(0,.45,.456),Vector3(.16,.014,.04),chrome)
	for i in range(7):
		_box("CoolingLouver",Vector3(0,.78+i*.025,-.4),Vector3(.36,.009,.025),rubber)
	_cylinder("SteeringColumn",Vector3(-.17,1.16,.36),.055,.10,chrome)
	var mount := Node3D.new()
	mount.name = "SteeringMount"
	mount.position = Vector3(-.17,1.24,.36)
	mount.rotation.x = deg_to_rad(35.0)
	add_child(mount)
	_deluxe_wheel = Node3D.new()
	_deluxe_wheel.name = "SteeringWheel"
	mount.add_child(_deluxe_wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = .105
	rim.outer_radius = .135
	rim.rings = 24
	rim.ring_segments = 12
	var ring := _mesh("SteeringRim",rim,Vector3.ZERO,rubber)
	ring.reparent(_deluxe_wheel,false)
	for i in range(3):
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(.025,.022,.11)
		var angle := i*TAU/3.0
		var spoke := _mesh("SteeringSpoke",spoke_mesh,Vector3.ZERO,chrome)
		spoke.reparent(_deluxe_wheel,false)
		spoke.position = Vector3(0,0,.055).rotated(Vector3.UP,angle)
		spoke.rotation.y = angle
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = .047
	hub_mesh.bottom_radius = .047
	hub_mesh.height = .026
	var hub := _mesh("SteeringHub",hub_mesh,Vector3.ZERO,led)
	hub.reparent(_deluxe_wheel,false)
	_cylinder("NitroCollar",Vector3(.18,1.12,.36),.065,.018,chrome)
	var cap := CylinderMesh.new()
	cap.top_radius = .052
	cap.bottom_radius = .052
	cap.height = .032
	_deluxe_button = _mesh("NitroButton",cap,Vector3(.18,1.14,.36),warm)
	_box("FreePlayLamp",Vector3(.27,.69,.42),Vector3(.075,.025,.014),led)
	_box("SerialPlate",Vector3(.26,.36,.419),Vector3(.22,.08,.01),chrome)
	_deluxe_label("Serial","MM-006 / ROOK 014",Vector3(.26,.36,.427),Color("162833"),12,.0008)
	_deluxe_label("FreePlay","FREE PLAY",Vector3(.27,.65,.429),Color("86e9d2"),12,.001)
	_deluxe_label("ControlLegend","STEER   /   NITRO",Vector3(0,1.043,.566),Color("e9cfaa"),16,.0015)
	_deluxe_label("Warranty","NO ONLINE ACCOUNT REQUIRED",Vector3(0,.88,.417),Color("e9cfaa"),15,.001)
	_box("ServiceSeal",Vector3(-.28,.36,.416),Vector3(.14,.075,.01),warm)
	_deluxe_label("Seal","OFFLINE",Vector3(-.28,.36,.425),Color("26333d"),13,.0011)
	var spill := OmniLight3D.new()
	spill.name = "MarqueeSpill"
	spill.position = Vector3(0,1.94,.48)
	spill.light_color = Color("69d8c2")
	spill.light_energy = .32
	spill.omni_range = 1.25
	spill.shadow_enabled = false
	add_child(spill)

func _deluxe_label(label: String, message: String, at: Vector3, tint: Color, font_size: int, pixel: float) -> void:
	var node := Label3D.new()
	node.name = label
	node.text = message
	node.position = at
	node.font_size = font_size
	node.pixel_size = pixel
	node.modulate = tint
	node.outline_size = 0
	add_child(node)

# Called by the active modal only; no idle processing or input polling.
func set_deluxe_controls(lane: float, pulse: float) -> void:
	if is_instance_valid(_deluxe_wheel):
		_deluxe_wheel.rotation.y = (clampf(lane,0.0,2.0)-1.0)*.68
	if is_instance_valid(_deluxe_button):
		_deluxe_button.position.y = 1.14-clampf(pulse,0.0,1.0)*.014

# Common restoration pass for the nine remaining machines: no active lights,
# input polling or per-cabinet viewport. Printed trim stays physically lit.
func _union_details(accent: Color) -> void:
	var metal := _mat(Color("899ca3"),.62)
	var rubber := _mat(Color("111923"),.0)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = accent
	lit.emission_enabled = true
	lit.emission = accent
	lit.emission_energy_multiplier = .40
	for x in [-.385,.385]:
		_box("MarqueeEdge",Vector3(x,2.05,.273),Vector3(.018,.145,.025),lit)
		_box("BezelRail",Vector3(x,1.52,.29),Vector3(.018,.76,.025),metal)
	_box("KickGuard",Vector3(0,.18,.415),Vector3(.73,.10,.025),rubber)
	_box("CoinReturnRecess",Vector3(0,.48,.427),Vector3(.15,.06,.03),rubber)
	_box("CoinReturnLip",Vector3(0,.45,.448),Vector3(.15,.012,.03),metal)
	_cylinder("JoystickCollar",Vector3(-.22,1.127,.36),.057,.018,rubber)
	for n in range(3):
		_cylinder("ButtonRing",Vector3(.04+n*.105,1.116,.36),.043,.009,metal)
	_box("FreePlayIndicator",Vector3(.27,.66,.421),Vector3(.065,.021,.014),lit)
	_deluxe_label("FreePlayLegend","FREE PLAY",Vector3(.27,.62,.429),accent,12,.001)
	_deluxe_label("UnionSerial","ICU-%03d / OFFLINE" % (IDS.find(game_id)+1),Vector3(0,.91,.404),Color("c8bba4"),14,.001)
	var legend := "MOVE / ACTION"
	if game_id=="starline_patrol":
		legend = "PILOT / FIRE"
	elif game_id=="neon_rebound":
		legend = "PADDLE / LAUNCH"
	elif game_id=="day_one_dlc":
		legend = "SLIDE / NO DLC"
	_deluxe_label("ControlLegend",legend,Vector3(0,1.043,.566),accent,15,.0014)
