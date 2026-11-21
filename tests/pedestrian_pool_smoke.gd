extends SceneTree
const Pool = preload("res://scripts/pedestrian_pool.gd")
const Pop = preload("res://scripts/sidewalk_population.gd")
func _initialize() -> void:
	create_timer(20.0,true,false,true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")
func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("PEDESTRIAN_POOL: "+message)
		quit(1)
	return ok
func _verify() -> void:
	var pool := Pool.new()
	root.add_child(pool)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(58,0.2,58)
	collision.shape = shape
	floor_body.add_child(collision)
	root.add_child(floor_body)
	floor_body.position = Vector3(29,-0.1,29)
	# Headless-only empty visual fixture; never a gameplay visual asset.
	var fixture := Node3D.new()
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	if not _check(not pool.build(null) and pool.build(packed,1) and not pool.build(packed,1),"bounded one-time construction"):
		return
	var pop := Pop.new()
	pop.configure(123,Pop.block_candidates(0,0))
	var id: String = pop.ids()[0]
	var other: String = pop.ids()[1]
	var allow := func(_entry: Dictionary) -> bool: return true
	var deny := func(_entry: Dictionary) -> bool: return false
	var hide := func(_at: Vector3) -> bool: return true
	var show := func(_at: Vector3) -> bool: return false
	await physics_frame
	if not _check(not pool.activate(pop,id,0.0,deny) and not pool.activate(pop,id,4.0,allow),"activation guards"):
		return
	if not _check(pool.activate(pop,id,0.0,allow) and not pool.activate(pop,id,0.0,allow) and not pool.activate(pop,other,0.0,allow),"unique lease and capacity"):
		return
	var body := pool.get_child(0) as CharacterBody3D
	var instance := body.get_instance_id()
	var before: Vector3 = body.global_position
	for i in range(30):
		await physics_frame
		pool.step(1.0/60.0)
	if not _check(body.global_position.distance_to(before)>0.15 and body.is_on_floor(),"physics movement and ground contact"):
		return
	if not _check(not pool.recycle(pop,id,show),"visible actor cannot recycle"):
		return
	var last := body.global_position
	if not _check(pool.recycle(pop,id,hide) and pool.stats()["active"]==0 and body.collision_layer==0 and not body.visible,"inactive body has no collision or rendering"):
		return
	if not _check((pop.sample(id)["position"] as Vector3).distance_to(last)<0.5,"live phase preserved"):
		return
	if not _check(pool.activate(pop,other,0.0,allow) and body.get_instance_id()==instance,"same physical body reused"):
		return
	print("PEDESTRIAN_POOL_SMOKE PASS: guarded activation, bounded leases, grounded motion, hidden recycle and phase handoff")
	quit(0)
