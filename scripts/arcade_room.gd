extends Node3D
## On-demand room dressing, fits the existing 16 x 18 interior envelope.
## The owner supplies the architectural shell and lighting.
const Cabinet = preload("res://scripts/arcade_cabinet.gd")
const ROOK_LINES := [
	"The devs aren't the problem. The boardroom is.",
	"Someone brought me a bug report with a save file and a thank-you note. Made my week.",
	"We kept the old cabinets offline. They still work.",
	"Play what you love. You don't owe a publisher your evenings.",
	"Those four friends on the warfare cabinet? They've been a squad for ten years.",
	"Every tile in the puzzle is included. Radical business model, I know."
]
var cabinets: Array[Cabinet] = []
var _line_index := 0

func _ready() -> void:
	for i in range(Cabinet.IDS.size()):
		var cabinet := Cabinet.new()
		cabinet.configure(Cabinet.IDS[i])
		cabinet.name = Cabinet.IDS[i]
		var left := i < 2 or i == 4
		var depth := 4.2 if i >= 4 else (-2.2 if i % 2 == 0 else 1.0)
		cabinet.position = Vector3(-5.6 if left else 5.6,0.0,depth)
		cabinet.rotation.y = PI / 2.0 if left else -PI / 2.0
		add_child(cabinet)
		cabinets.append(cabinet)
	_sign("INSERT COIN",Vector3(0,3.8,-7.9),Color("72d7cf"),56)
	_sign("INDEPENDENT CABINET UNION",Vector3(0,3.25,-7.9),Color("e9c283"),23)
	_sign("ROADMAP OF THE ROADMAP",Vector3(-4.9,2.7,-7.9),Color("d6a1bd"),24)
	_sign("NO SERVER REQUIRED",Vector3(4.9,2.7,-7.9),Color("b4c9d9"),24)
	_sign("AFTERHOURS: EARLY ACCESS TO BAD DECISIONS",Vector3(0,2.7,-7.9),Color("aab4ba"),18)
	_sign("ROOK / REPAIRS & HIGH SCORES",Vector3(0,2.3,-5.1),Color("e9c283"),22)
	var carpet := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.2,.025,12.0)
	carpet.mesh = mesh
	carpet.position = Vector3(0,.14,.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("493843")
	mat.roughness = 1.0
	carpet.material_override = mat
	add_child(carpet)

func cabinet_near(at: Vector3) -> String:
	for cabinet in cabinets:
		if is_instance_valid(cabinet) and cabinet.reachable(at):
			return cabinet.game_id
	return ""

func rook_line() -> String:
	var line: String = ROOK_LINES[_line_index]
	_line_index = (_line_index + 1) % ROOK_LINES.size()
	return line

func _sign(message: String, at: Vector3, tint: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.text = message
	label.position = at
	label.modulate = tint
	label.font_size = font_size
	label.pixel_size = .008
	label.outline_size = 2
	label.no_depth_test = false
	add_child(label)
