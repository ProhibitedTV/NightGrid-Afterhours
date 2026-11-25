extends Node3D
## Bounded static shop props, original print assets and four animated regulars.
const Human = preload("res://scripts/humanoid_visual.gd")
const REPAIR = preload("res://assets/arcade/repair_poster.svg")
const TOURNAMENT = preload("res://assets/arcade/tournament_poster.svg")
const REGULARS := [
	{"id":"ev","name":"Ev","role":"Modder","position":Vector3(-2.8,0.0,-.6),"palette":2,"lines":["I fixed a shader bug in a game once. The dev sent me a thank-you email.","The best patch notes are the ones that say what actually changed.","Back up your saves. Trust me.","There is a difference between a patch and a permission slip.","The engine-room tribute is my favorite. Modders kept a whole generation of games alive."]},
	{"id":"nyx","name":"Nyx","role":"Speedrunner","position":Vector3(2.8,0.0,-.6),"palette":3,"lines":["I lost a world record by one frame. The person who beat me gave me their route.","A good game makes you want another run, not another purchase.","Nobody gets fast without looking silly first.","We race old games because their rules don't change every Tuesday.","A leaderboard should be a challenge, not an advertisement."]},
	{"id":"ash","name":"Ash","role":"Squad regular","position":Vector3(-2.8,0.0,3.2),"palette":4,"lines":["Same friends, different sequel. I come for the friends.","We used to pass the controller around. This place gets it.","I let my kid beat my score. Don't tell Rook.","The new edition is mostly the same game. The laughter on voice chat is always new.","We still call it the Friday tournament even when we show up on Saturday."]},
	{"id":"hal","name":"Hal","role":"Former studio QA","position":Vector3(2.8,0.0,3.2),"palette":1,"lines":["A team of fifty people cared about that game. One executive cared about the date.","Report the bug, don't yell at the tester.","I still play games every weekend. Can't help it.","The Golden Apology is a joke, but please thank your testers.","Some of the best design decisions are the features the team decided not to add."]}
]
var _dialogue: Dictionary = {}
var _mats: Dictionary = {}

func _ready() -> void:
	_poster("RepairPoster",REPAIR,Vector3(-4.3,3.45,-8.64))
	_poster("TournamentPoster",TOURNAMENT,Vector3(4.3,3.45,-8.64))
	# Side bench behind the counter, outside the cabinet approach rectangles.
	_prop("RepairBench",Vector3(-3.4,.88,-7.2),Vector3(1.45,.16,.68),Color("756352"),true)
	for x in [-3.96,-2.84]:
		_prop("BenchLeg",Vector3(x,.41,-7.2),Vector3(.10,.82,.54),Color("3d454a"),true)
	_prop("SpareCRT",Vector3(-3.68,1.25,-7.2),Vector3(.49,.50,.44),Color("41474d"))
	_prop("SpareCRTGlass",Vector3(-3.68,1.25,-6.965),Vector3(.39,.38,.025),Color("212a2e"))
	_prop("Toolbox",Vector3(-3.0,1.08,-7.2),Vector3(.44,.24,.36),Color("8d494a"))
	_prop("Handle",Vector3(-3.0,1.23,-7.2),Vector3(.17,.035,.08),Color("a1a6a3"))
	for n in range(3):
		_prop("PartsBin",Vector3(3.2+n*.43,.25,-7.3),Vector3(.38,.42,.54),Color("4c5759"),true)
		_prop("BinLabel",Vector3(3.2+n*.43,.35,-7.02),Vector3(.23,.08,.018),Color("c7b89a"))
	for data in REGULARS:
		var human := Human.new()
		human.name = str(data["id"])
		human.configure(int(data["palette"]),"ARCADE")
		human.position = data["position"] + Vector3(0,1.02,0)
		human.rotation.y = PI if human.position.x < 0.0 else 0.0
		add_child(human)
		var body := StaticBody3D.new()
		body.position = data["position"] + Vector3(0,.9,0)
		var shape := CylinderShape3D.new()
		shape.radius = .35
		shape.height = 1.7
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)

func regular_near(at: Vector3) -> Dictionary:
	var local := to_local(at)
	var closest := 1.55
	var found := {}
	for data in REGULARS:
		var distance := local.distance_to(data["position"] + Vector3(0,1.05,0))
		if distance < closest:
			closest = distance
			found = data
	return found.duplicate(true)

func talk(at: Vector3) -> Dictionary:
	var data := regular_near(at)
	if data.is_empty():
		return {}
	var id := str(data["id"])
	var lines: Array = data["lines"]
	var index := int(_dialogue.get(id,0))
	_dialogue[id] = (index+1) % lines.size()
	return {"name":data["name"],"role":data["role"],"line":lines[index]}

func _poster(label: String, art: Texture2D, at: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.45,1.53)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = art
	mat.roughness = .95
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = quad
	node.material_override = mat
	node.position = at
	add_child(node)

func _prop(label: String, at: Vector3, dimensions: Vector3, tint: Color, collidable: bool = false) -> void:
	var key := tint.to_html()
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = .78
		_mats[key] = mat
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = _mats[key]
	node.position = at
	add_child(node,true)
	if collidable:
		var body := StaticBody3D.new()
		body.position = at
		var shape := BoxShape3D.new()
		shape.size = dimensions
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
