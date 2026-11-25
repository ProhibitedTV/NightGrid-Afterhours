extends StaticBody3D
## Original static cabinet, face toward local +Z. No active viewport or per-frame scripts.
const IDS := ["grand_delay", "claw_compliance", "patch_day", "indie_dev"]
const ART := {
	"grand_delay": preload("res://assets/arcade/grand_delay.svg"),
	"claw_compliance": preload("res://assets/arcade/claw_compliance.svg"),
	"patch_day": preload("res://assets/arcade/patch_day.svg"),
	"indie_dev": preload("res://assets/arcade/indie_dev.svg")
}
const TINTS := {"grand_delay": "69d8c2", "claw_compliance": "efb169", "patch_day": "c4a2f3", "indie_dev": "f1cd82"}
const CRT = preload("res://assets/arcade/attract_crt.gdshader")
var game_id := "grand_delay"
static var materials: Dictionary = {}
static var screens: Dictionary = {}

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
	screen.size = Vector2(.59,.65)
	if not screens.has(game_id):
		var mat := ShaderMaterial.new()
		mat.shader = CRT
		mat.set_shader_parameter("art",ART[game_id])
		screens[game_id] = mat
	_mesh("CRTAttract",screen,Vector3(0,1.52,.29),screens[game_id])
	var side := QuadMesh.new()
	side.size = Vector2(.60,.77)
	for sign in [-1,1]:
		var panel := _mesh("SideArt",side,Vector3(sign*.419,1.48,-.08),screens[game_id])
		panel.rotation.y = sign * PI / 2.0
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
