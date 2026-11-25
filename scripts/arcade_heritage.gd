extends Node3D
## Eight original illustrated museum pieces. Names are historical tributes, not endorsements.
## Read from the clear front-wall gallery; static textures, no animated displays.
const EXHIBITS := [
	{"id":"pixel_pioneers", "title":"PIXEL PIONEERS", "line":"A tribute to Toru Iwatani and Shigeru Miyamoto: expressive characters, readable rules, and the joy of one more try.", "art":preload("res://assets/arcade/heritage/pixel_pioneers.svg"), "position":Vector3(-6.4,2.14,8.57), "approach":Vector3(-6.4,1.15,7.18), "rotation":PI},
	{"id":"puzzle_legacy", "title":"THE PERFECT PUZZLE", "line":"For Alexey Pajitnov and the puzzle makers who taught us that a few simple rules can last a lifetime.", "art":preload("res://assets/arcade/heritage/puzzle_legacy.svg"), "position":Vector3(-4.5,2.14,8.57), "approach":Vector3(-4.5,1.15,7.18), "rotation":PI},
	{"id":"adventure_legacy", "title":"THE NEXT ROOM", "line":"For Roberta Williams and adventure-game storytellers: the joy of opening a door, asking a question, and finding a new world.", "art":preload("res://assets/arcade/heritage/adventure_legacy.svg"), "position":Vector3(-2.6,2.14,8.57), "approach":Vector3(-2.6,1.15,7.18), "rotation":PI},
	{"id":"engine_legacy", "title":"ENGINE ROOM", "line":"For John Carmack, John Romero and the modding scene: make a world, then let curious players build their own.", "art":preload("res://assets/arcade/heritage/engine_legacy.svg"), "position":Vector3(2.6,2.14,8.57), "approach":Vector3(2.6,1.15,7.18), "rotation":PI},
	{"id":"strategy_legacy", "title":"ONE MORE TURN", "line":"For Sid Meier and strategy designers: a meaningful decision is worth more than a thousand compulsory daily tasks.", "art":preload("res://assets/arcade/heritage/strategy_legacy.svg"), "position":Vector3(4.5,2.14,8.57), "approach":Vector3(4.5,1.15,7.18), "rotation":PI},
	{"id":"physical_media", "title":"YOU OWNED IT", "line":"Rook kept the cartridge, manual, disc and save files. Nobody can revoke the memories attached to them.", "art":preload("res://assets/arcade/heritage/physical_media.svg"), "position":Vector3(6.4,2.14,8.57), "approach":Vector3(6.4,1.15,7.18), "rotation":PI},
	{"id":"roadmap_museum", "title":"THE ROADMAP OF THE ROADMAP", "line":"A fictional collector's roadmap: announce the teaser, delay the trailer, sell the calendar. The game is listed as optional.", "art":preload("res://assets/arcade/heritage/roadmap_museum.svg"), "position":Vector3(-7.65,2.14,6), "approach":Vector3(-6.45,1.15,6), "rotation":PI / 2.0},
	{"id":"apology_award", "title":"THE GOLDEN APOLOGY", "line":"Fictional industry trophy for the most sincere promise to listen to feedback. The feedback is still in a queue.", "art":preload("res://assets/arcade/heritage/apology_award.svg"), "position":Vector3(7.65,2.14,6), "approach":Vector3(6.45,1.15,6), "rotation":-PI / 2.0}
]
const INSPECT_RADIUS := 1.05
var _materials: Dictionary = {}

func _ready() -> void:
	for data in EXHIBITS:
		var frame := Node3D.new()
		frame.name = str(data["id"])
		frame.position = data["position"]
		frame.rotation.y = float(data["rotation"])
		add_child(frame)
		_box(frame,"Frame",Vector3.ZERO,Vector3(1.72,1.22,.09),Color("51433d"))
		var quad := QuadMesh.new()
		quad.size = Vector2(1.62,1.08)
		var material := StandardMaterial3D.new()
		material.albedo_texture = data["art"]
		material.roughness = .92
		var art := MeshInstance3D.new()
		art.name = "Illustration"
		art.mesh = quad
		art.material_override = material
		art.position.z = .051
		frame.add_child(art)
		var label := Label3D.new()
		label.text = "ARCHIVE / INSPECT"
		label.font_size = 20
		label.pixel_size = .003
		label.modulate = Color("e9c283")
		label.position = Vector3(0,-.72,.06)
		frame.add_child(label)
	# Shallow wall shelves: entirely behind the marked inspection spots.
	# Geometry is original, not a recreation of a branded console.
	for x in [-4.5,4.5]:
		_box(self,"ArchiveShelf",Vector3(x,.82,8.42),Vector3(1.40,.09,.42),Color("7c6954"),true)
		_box(self,"Bracket",Vector3(x-.48,.68,8.48),Vector3(.08,.28,.25),Color("434b4e"))
		_box(self,"Bracket",Vector3(x+.48,.68,8.48),Vector3(.08,.28,.25),Color("434b4e"))
	for n in range(3):
		var x := -4.94+n*.39
		_box(self,"Cartridge",Vector3(x,.99,8.40),Vector3(.24,.27,.09),Color("555d64"))
		_box(self,"CartridgeLabel",Vector3(x,1.02,8.347),Vector3(.18,.11,.008),Color("bba77e"))
	_box(self,"Manual",Vector3(4.10,.94,8.40),Vector3(.30,.16,.10),Color("8b6055"))
	_box(self,"DiscCase",Vector3(4.48,1.01,8.40),Vector3(.26,.29,.06),Color("3d777a"))
	_box(self,"SaveDisk",Vector3(4.84,.98,8.40),Vector3(.24,.23,.05),Color("6c647d"))

func exhibit_near(at: Vector3) -> Dictionary:
	var local := to_local(at)
	var closest := INSPECT_RADIUS
	var found := {}
	for data in EXHIBITS:
		var distance := local.distance_to(data["approach"])
		if distance < closest:
			closest = distance
			found = {"id":data["id"],"title":data["title"],"line":data["line"]}
	return found

func _box(parent: Node3D, label: String, at: Vector3, dimensions: Vector3, tint: Color, collidable: bool = false) -> void:
	var key := tint.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = .82
		_materials[key] = mat
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = _materials[key]
	visual.position = at
	parent.add_child(visual,true)
	if collidable:
		var body := StaticBody3D.new()
		body.position = at
		var shape := BoxShape3D.new()
		shape.size = dimensions
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		parent.add_child(body)
