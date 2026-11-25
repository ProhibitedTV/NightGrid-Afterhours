extends Node3D
## On-demand room dressing, fits the existing 16 x 18 interior envelope.
## The owner supplies the architectural shell and lighting.
const Cabinet = preload("res://scripts/arcade_cabinet.gd")
const KeyArt = preload("res://scripts/arcade_key_art.gd")
const Dressing = preload("res://scripts/arcade_dressing.gd")
const Heritage = preload("res://scripts/arcade_heritage.gd")
var heritage: Node3D
const CARPET = preload("res://assets/arcade/carpet_tile.svg")
const CIRCUIT_ART = preload("res://assets/arcade/circuit_poster.svg")
const CIRCUIT_POINT = Vector3(0,1.15,-3.35)
var dressing: Node3D
const ROOK_LINES = [
	"The devs aren't the problem. The boardroom is.",
	"Someone brought me a bug report with a save file and a thank-you note. Made my week.",
	"We kept the old cabinets offline. They still work.",
	"Play what you love. You don't owe a publisher your evenings.",
	"Those four friends on the warfare cabinet? They've been a squad for ten years.",
	"Every tile in the puzzle is included. Radical business model, I know.",
	"Somebody cleared the whole map, then spent an hour just watching the sunset. That's a good game.",
	"If the season ends before you finish, come back whenever. We don't track attendance.",
	"Go read the archive by the entrance. The people who made games worth loving deserve their flowers.",
	"The apology trophy is fake. The cartridge shelf is the real treasure.",
	"Games are a medium, not a monthly invoice.",
	"Try my circuit. Eight little challenges, no expiry date. You play when you feel like it.",
	"Those two classics by the entrance? No satire. Just games worth keeping alive.",
	"People learned physics from bouncing a ball off a paddle. Never needed a premium edition.",
	"Thirty mastery medals on the board now. The classics count too.",
	"Grand Delay has three cars. Somehow we managed to put them all on the same board."
]
var cabinets: Array[Cabinet] = []
var _line_index := 0

func _ready() -> void:
	for i in range(Cabinet.IDS.size()):
		var cabinet := Cabinet.new()
		cabinet.configure(Cabinet.IDS[i])
		cabinet.name = Cabinet.IDS[i]
		var left := i < 2 or i == 4 or i == 6
		var depth := -5.4 if i >= 6 else (4.2 if i >= 4 else (-2.2 if i % 2 == 0 else 1.0))
		cabinet.position = Vector3(-5.6 if left else 5.6,0.0,depth)
		cabinet.rotation.y = PI / 2.0 if left else -PI / 2.0
		if i >= 8:
			# Two restored machines flank the entry aisle, facing into the room.
			cabinet.position = Vector3(-2.0 if i == 8 else 2.0,0,5.5)
			cabinet.rotation.y = PI
		add_child(cabinet)
		cabinets.append(cabinet)
		_mount_game_poster(cabinet,i)
	_sign("INSERT COIN",Vector3(0,3.8,-7.9),Color("72d7cf"),56)
	_sign("INDEPENDENT CABINET UNION",Vector3(0,3.25,-7.9),Color("e9c283"),23)
	_sign("ROADMAP OF THE ROADMAP",Vector3(-4.9,2.7,-7.9),Color("d6a1bd"),24)
	_sign("NO SERVER REQUIRED",Vector3(4.9,2.7,-7.9),Color("b4c9d9"),24)
	_sign("AFTERHOURS: EARLY ACCESS TO BAD DECISIONS",Vector3(0,2.7,-7.9),Color("aab4ba"),18)
	_sign("ROOK / REPAIRS & HIGH SCORES",Vector3(0,2.3,-5.1),Color("e9c283"),22)
	_sign("10 GAMES / 30 MASTERY MEDALS",Vector3(0,2.05,-5.1),Color("72d7cf"),19)
	_sign("FREE PLAY • LOCAL SCORES • NO LOGIN",Vector3(0,3.12,-7.9),Color("b4c9d9"),17)
	var carpet := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.2,.025,12.0)
	carpet.mesh = mesh
	carpet.position = Vector3(0,.14,.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = CARPET
	mat.uv1_scale = Vector3(3.0,12.0,1.0)
	mat.roughness = 1.0
	carpet.material_override = mat
	add_child(carpet)
	dressing = Dressing.new()
	dressing.name = "ArcadeDressing"
	add_child(dressing)
	heritage = Heritage.new()
	heritage.name = "GameCultureArchive"
	add_child(heritage)
	var poster := MeshInstance3D.new()
	poster.name = "CircuitPoster"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.55,.97)
	poster.mesh = quad
	var poster_mat := StandardMaterial3D.new()
	poster_mat.albedo_texture = CIRCUIT_ART
	poster_mat.roughness = .9
	poster.material_override = poster_mat
	poster.position = Vector3(0,1.05,-4.96)
	add_child(poster)

func circuit_near(at: Vector3) -> bool:
	return to_local(at).distance_to(CIRCUIT_POINT) < .8

func exhibit_near(at: Vector3) -> Dictionary:
	return heritage.call("exhibit_near",at) if is_instance_valid(heritage) else {}

func regular_near(at: Vector3) -> Dictionary:
	return dressing.call("regular_near",at) if is_instance_valid(dressing) else {}

func talk_regular(at: Vector3) -> Dictionary:
	return dressing.call("talk",at) if is_instance_valid(dressing) else {}

func cabinet_node(id: String) -> Node3D:
	for cabinet in cabinets:
		if is_instance_valid(cabinet) and cabinet.game_id == id:
			return cabinet
	return null

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

# Static prints sit above the room's interaction zones. No new collisions or lights.
func _mount_game_poster(cabinet: Cabinet, index: int) -> void:
	var frame := Node3D.new()
	frame.name = "GamePoster_"+cabinet.game_id
	if index < 8:
		frame.position = Vector3(-7.65 if cabinet.position.x < 0 else 7.65,4.0,cabinet.position.z)
		frame.rotation.y = cabinet.rotation.y
	else:
		frame.position = Vector3(-2.6 if index == 8 else 2.6,4.0,8.69)
		frame.rotation.y = PI
	add_child(frame)
	var dims := KeyArt.fit(cabinet.game_id,Vector2(1.0,1.30))
	var border := MeshInstance3D.new()
	border.name = "Frame"
	var box := BoxMesh.new()
	box.size = Vector3(dims.x+.065,dims.y+.065,.045)
	border.mesh = box
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color("2b3038")
	border_mat.metallic = .35
	border_mat.roughness = .65
	border.material_override = border_mat
	frame.add_child(border)
	var art := MeshInstance3D.new()
	art.name = "Print"
	var print_mesh := QuadMesh.new()
	print_mesh.size = dims
	art.mesh = print_mesh
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = KeyArt.texture(cabinet.game_id)
	ink.roughness = .9
	art.material_override = ink
	art.position.z = .026
	frame.add_child(art)
