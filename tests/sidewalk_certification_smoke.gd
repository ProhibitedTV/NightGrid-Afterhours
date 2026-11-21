extends SceneTree
const Cert = preload("res://scripts/sidewalk_certification.gd")
const Pop = preload("res://scripts/sidewalk_population.gd")
class CityFixture extends Node3D:
	var revision := 1
	var ready_cell := true
	func get_streaming_stats() -> Dictionary:
		return {"loads":revision,"unloads":0}
	func get_loaded_blocks() -> Array[Vector2i]:
		return [Vector2i.ZERO] if ready_cell else []

func _initialize() -> void:
	create_timer(25.0,true,false,true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")

func _check(ok: bool,message: String) -> bool:
	if not ok:
		push_error("SIDEWALK_CERTIFICATION: "+message)
		quit(1)
	return ok

func _box(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = at
	return body

func _evaluate(cert, city: Node3D, entry: Dictionary) -> int:
	for i in range(12):
		await physics_frame
		var state: int = cert.evaluate(city,city.get_world_3d().direct_space_state,entry)
		if state!=Cert.PENDING:
			return state
	return Cert.PENDING

func _verify() -> void:
	var city := CityFixture.new()
	root.add_child(city)
	_box(city,Vector3(29,-0.1,29),Vector3(42,0.2,42))
	var entry: Dictionary = Pop.block_candidates(0,0)[0]
	var cert = Cert.new()
	await physics_frame
	if not _check(cert.evaluate(city,city.get_world_3d().direct_space_state,entry)==Cert.PENDING,"incremental probe budget"):
		return
	if not _check(await _evaluate(cert,city,entry)==Cert.CLEAR and cert.cached_clear(city,entry),"supported unobstructed link"):
		return
	var middle: Vector3 = (entry["start"]+entry["end"])*0.5
	_box(city,middle+Vector3.UP,Vector3(0.3,2.0,1.0))
	city.revision += 1
	if not _check(not cert.cached_clear(city,entry) and await _evaluate(cert,city,entry)==Cert.BLOCKED,"mid-link blocker and revision invalidation"):
		return
	city.ready_cell = false
	if not _check(not cert.cached_clear(city,entry) and cert.evaluate(city,city.get_world_3d().direct_space_state,entry)==Cert.BLOCKED,"unloaded parcel"):
		return
	var links: Array[Dictionary] = []
	for ix in range(-4,4):
		for iz in range(-4,4):
			links.append_array(Pop.block_candidates(ix,iz))
	var population = Pop.new()
	population.configure(123,links)
	var districts := {}
	for id in population.ids():
		districts[population.sample(id)["district"]] = true
	if not _check(districts.size()==8,"population cap covers all districts"):
		return
	print("SIDEWALK_CERTIFICATION_SMOKE PASS: incremental support, swept capsule, revision, unloaded parcel and eight districts")
	quit(0)
