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
	# Start at the middle of the route, away from endpoint reversal.
	pop.restore({"phases":{id:0.25}})
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
	# Local incident must be visible; a wall blocks the reaction ray.
	var eye := body.global_position + Vector3.UP*1.6
	var incident := eye + Vector3.RIGHT*4.0
	var wall := StaticBody3D.new()
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size=Vector3(0.3,3.0,3.0)
	wall_collision.shape=wall_shape
	wall.add_child(wall_collision)
	root.add_child(wall)
	wall.global_position=eye+Vector3.RIGHT*2.0
	await physics_frame
	var ignored: Array[RID]=[]
	pool.react_to_incident(pool.get_world_3d().direct_space_state,incident,10.0,ignored,true)
	if not _check(float(pool.get("_leases")[id]["alert"])==0.0,"opaque wall blocks incident reaction"):
		return
	wall.queue_free()
	await process_frame
	await physics_frame
	pool.react_to_incident(pool.get_world_3d().direct_space_state,incident,10.0,ignored,true)
	pool.step(1.0/60.0)
	if not _check(pool.movement_states()[id]=="ALERT","visible urgent incident interrupts routine"):
		return
	for i in range(46):
		await physics_frame
		pool.step(1.0/60.0)
	if not _check(pool.movement_states()[id]=="RETREAT","urgent incident leads to bounded same-link retreat"):
		return
	for i in range(200):
		await physics_frame
		pool.step(1.0/60.0)
	if not _check(float(pool.get("_leases")[id]["retreat"])<=0.0,"retreat expires without permanent panic"):
		return
	# A temporary obstruction in front of a live actor triggers a bounded
	# yield followed by a reversal on the same certified line.
	var heading := Vector3(sin(body.rotation.y),0,cos(body.rotation.y))
	var blocker := StaticBody3D.new()
	var blocker_collision := CollisionShape3D.new()
	var blocker_shape := BoxShape3D.new()
	blocker_shape.size = Vector3(0.8,1.8,0.8)
	blocker_collision.shape = blocker_shape
	blocker.add_child(blocker_collision)
	root.add_child(blocker)
	blocker.global_position = body.global_position+heading*1.1+Vector3.UP*0.9
	var yielded := false
	var reversed := false
	for i in range(170):
		await physics_frame
		pool.step(1.0/60.0)
		yielded = yielded or pool.movement_states().get(id)=="YIELD"
		var direction := Vector3(sin(body.rotation.y),0,cos(body.rotation.y))
		if direction.dot(heading)<-0.9:
			reversed = true
			break
	if not _check(yielded and reversed,"sustained obstruction yields then reverses"):
		return
	blocker.queue_free()
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
