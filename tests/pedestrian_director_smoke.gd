extends SceneTree
const Director = preload("res://scripts/pedestrian_director.gd")
const Pop = preload("res://scripts/sidewalk_population.gd")
class CityFixture extends Node3D:
	var leases := {}
	func get_loaded_blocks() -> Array[Vector2i]:
		return [Vector2i.ZERO]
	func get_streaming_stats() -> Dictionary:
		return {"loads":1,"unloads":0}
	func is_spawn_area_ready(_at: Vector3,_radius: float) -> bool:
		return true
	func reserve_pedestrian_parcel(id: String,_a: Vector3,_b: Vector3) -> bool:
		if leases.has(id):
			return false
		leases[id] = true
		return true
	func release_pedestrian_parcel(id: String) -> bool:
		return leases.erase(id)
func _initialize() -> void:
	create_timer(25.0,true,false,true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")
func _check(ok: bool,message: String) -> bool:
	if not ok:
		push_error("PEDESTRIAN_DIRECTOR: "+message)
		quit(1)
	return ok
func _verify() -> void:
	var city := CityFixture.new()
	root.add_child(city)
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(58,0.2,58)
	collision.shape = shape
	ground.add_child(collision)
	city.add_child(ground)
	ground.position = Vector3(29,-0.1,29)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(29,2,-40)
	camera.make_current()
	var director := Director.new()
	root.add_child(director)
	var fixture := Node3D.new()
	var visual := PackedScene.new()
	visual.pack(fixture)
	fixture.free()
	if not _check(director.configure(city,123,Pop.block_candidates(0,0),visual,1),"separate opt-in director"):
		return
	var focus := Vector3(29,0,-40)
	var occupied: Array[Vector3] = []
	for i in range(45):
		await physics_frame
		director.tick(1.0/60.0,focus,camera,true,occupied)
	if not _check(director.stats()["active"]==0 and city.leases.is_empty(),"indoors prevents activation"):
		return
	for i in range(150):
		await physics_frame
		director.tick(1.0/60.0,focus,camera,false,occupied)
		if director.stats()["active"]==1:
			break
	if not _check(director.stats()["active"]==1 and city.leases.size()==1,"certified hidden actor and parcel lease"):
		return
	if not _check(not director.snapshot().is_empty() and not director.restore({}),"active save and restore guard"):
		return
	director.shutdown()
	if not _check(director.stats()["active"]==0 and city.leases.is_empty(),"shutdown releases protected parcel after disabling actors"):
		return
	print("PEDESTRIAN_DIRECTOR_SMOKE PASS: indoor gating, live physics certification, camera guard, leased activation and teardown")
	quit(0)
