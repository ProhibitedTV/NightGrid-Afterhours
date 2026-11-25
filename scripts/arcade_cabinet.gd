extends StaticBody3D
## Original static cabinet, face toward local +Z. No active viewport or per-frame scripts.
const Catalog = preload("res://scripts/arcade_round.gd")
const IDS = Catalog.IDS
const KeyArt = preload("res://scripts/arcade_key_art.gd")
const ART = KeyArt.ART
const TINTS := {"grand_delay": "69d8c2", "claw_compliance": "efb169", "patch_day": "c4a2f3", "indie_dev": "f1cd82", "annual_warfare": "a5ca82", "day_one_dlc": "ed9db5", "open_world_checklist": "80bce9", "battle_pass_hero": "e6a1ef", "starline_patrol": "72d7cf", "neon_rebound": "f2a96b"}
const SERVICE_STICKERS := {"grand_delay":"RELEASE DATE: TBA", "claw_compliance":"APPROVED BY 12 COMMITTEES", "patch_day":"HOTFIX HOTLINE", "indie_dev":"MADE WITH WEEKENDS OFF", "annual_warfare":"RELOADS ARE FREE", "day_one_dlc":"ALL PARTS INCLUDED", "open_world_checklist":"SOCK NOT INCLUDED", "battle_pass_hero":"NO ATTENDANCE TRACKING", "starline_patrol":"RESTORED BY ROOK", "neon_rebound":"ORIGINAL BOARD / FREE PLAY"}
const CRT = preload("res://assets/arcade/attract_crt.gdshader")
var game_id := "grand_delay"
static var materials: Dictionary = {}
static var screens: Dictionary = {}
static var printed: Dictionary = {}

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
		mat.shader = CRT
		mat.set_shader_parameter("art",KeyArt.texture(game_id))
		screens[game_id] = mat
	_mesh("CRTAttract",screen,Vector3(0,1.52,.29),screens[game_id])
	var side := QuadMesh.new()
	side.size = KeyArt.fit(game_id,Vector2(.60,.77))
	if not printed.has(game_id):
		var ink := StandardMaterial3D.new()
		ink.albedo_texture = KeyArt.texture(game_id)
		ink.roughness = .85
		ink.metallic = 0.0
		printed[game_id] = ink
	for sign in [-1,1]:
		var panel := _mesh("SideArt",side,Vector3(sign*.419,1.48,-.08),printed[game_id])
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
	_collision(Vector3(0,1.10,.03),Vector3(.87,2.16,.85))
	_collision(Vector3(0,1.04,.43),Vector3(.84,.15,.24))

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
