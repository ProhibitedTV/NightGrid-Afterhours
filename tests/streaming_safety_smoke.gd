extends SceneTree
const Safety = preload("res://scripts/streaming_safety.gd")

func _initialize() -> void:
	create_timer(35.0,true,false,true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")

func _check(ok: bool,message: String) -> bool:
	if not ok:
		push_error("STREAMING_SAFETY: "+message)
		quit(1)
	return ok

func _verify() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	var city: Node3D = world.get_node("CityDetails")
	var camera: Camera3D = world.get("camera")
	camera.global_position = Vector3(0,5,0)
	camera.rotation = Vector3.ZERO
	camera.current = true
	var front := Vector3(0,5,-90)
	var behind := Vector3(0,5,90)
	if not _check(not Safety.outside_expanded_view(camera,front,3.2) and Safety.outside_expanded_view(camera,behind,3.2),"actual camera frustum"):
		return
	var guard = Safety.new()
	guard.observe(camera,0.1)
	if not _check(not guard.hidden(camera,behind,3.2),"new camera delay"):
		return
	for i in range(5):
		guard.observe(camera,0.1)
	if not _check(guard.hidden(camera,behind,3.2),"settled camera"):
		return
	camera.rotation.y = PI
	guard.observe(camera,0.016)
	if not _check(not guard.hidden(camera,front,3.2) and not guard.hidden(camera,behind,3.2),"rapid camera rotation guard"):
		return
	var loaded := Vector3(29,0,29)
	var remote := Vector3(203,0,87)
	if not _check(bool(city.call("is_spawn_area_ready",loaded,1.0)) and not bool(city.call("is_spawn_area_ready",remote,1.0)) and not bool(city.call("is_spawn_area_ready",Vector3(999,0,999),1.0)),"actual loaded parcel and boundary"):
		return
	city.call("_run_build_stage",Vector2i(3,1))
	if not _check(not bool(city.call("is_spawn_area_ready",remote,1.0)),"partial chunk must not permit spawn"):
		return
	# Fixture on the known global road, far from source-owned buildings.
	var point := Vector3(29,1,0)
	var blocker := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,2,2)
	collider.shape = box
	blocker.add_child(collider)
	world.add_child(blocker)
	blocker.global_position = point
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	if not _check(not Safety.clear_grounded_volume(city,space,point,3.2,2.0,0.0),"actual occupied volume rejection"):
		return
	blocker.queue_free()
	await process_frame
	await physics_frame
	# A small isolated static floor fixture above the city road exercises
	# positive supporting-ground and volume checks without live car placement.
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(8,0.2,8)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(29,9.9,29)
	await physics_frame
	if not _check(Safety.clear_grounded_volume(city,world.get_world_3d().direct_space_state,Vector3(29,10,29),0.65,1.9,10.0),"positive actual physics fixture"):
		return
	print("STREAMING_SAFETY_SMOKE PASS: real frustum, turn guard, loaded vs staged parcels, body clearance and support")
	quit(0)
