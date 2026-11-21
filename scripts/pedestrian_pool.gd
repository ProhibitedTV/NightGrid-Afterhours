extends Node3D
## Opt-in pool of reusable CharacterBody3D sidewalk actors.
## Not installed in World. A director must supply an approved visual scene,
## live spawn/recycle predicates, actual ground height and physics-tick calls.
const Population = preload("res://scripts/sidewalk_population.gd")
const RADIUS = 0.32
const HEIGHT = 1.8
const YIELD_SECONDS = 1.2
const TURN_COOLDOWN = 2.0
const MAX_LATERAL_OFFSET = 0.6
var _slots: Array[CharacterBody3D] = []
var _leases: Dictionary = {}
var _visuals: Array[Node3D] = []

func build(visual_scene: PackedScene, capacity: int = Population.MAX_ACTIVE) -> bool:
	if not is_inside_tree() or not _slots.is_empty() or visual_scene == null or capacity<1 or capacity>Population.MAX_ACTIVE:
		return false
	# Instantiate all assets once. Fail without leaving partial pool bodies.
	var pending: Array[Node3D] = []
	for i in range(capacity):
		var candidate := visual_scene.instantiate()
		if not candidate is Node3D:
			if candidate != null:
				candidate.free()
			for visual in pending:
				visual.free()
			return false
		pending.append(candidate)
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	for i in range(capacity):
		var body := CharacterBody3D.new()
		body.name = "PedestrianSlot%d" % i
		body.collision_layer = 0
		body.collision_mask = 0
		body.floor_snap_length = 0.25
		body.process_mode = Node.PROCESS_MODE_DISABLED
		body.hide()
		var shape := CollisionShape3D.new()
		shape.shape = capsule
		shape.position.y = HEIGHT*0.5
		body.add_child(shape)
		body.add_child(pending[i])
		add_child(body)
		_slots.append(body)
		_visuals.append(pending[i])
	return true

func active_positions() -> Dictionary:
	var result := {}
	for id in _leases:
		var slot: int = _leases[id]["slot"]
		result[id] = _slots[slot].global_position
	return result

func capacity() -> int:
	return _slots.size()

func activate(population, id: String, ground_y: float, allowed: Callable) -> bool:
	if population == null or _leases.has(id) or not allowed.is_valid() or not is_finite(ground_y):
		return false
	var sample: Dictionary = population.sample(id)
	if sample.is_empty():
		return false
	var at: Vector3 = sample["position"]
	if absf(ground_y-at.y)>0.4:
		return false
	if not bool(allowed.call(sample)):
		return false
	var used := {}
	for lease in _leases.values():
		used[lease["slot"]] = true
		var existing: CharacterBody3D = _slots[lease["slot"]]
		if existing.global_position.distance_to(at)<Population.MIN_SEPARATION:
			return false
	for i in range(_slots.size()):
		if used.has(i):
			continue
		var body := _slots[i]
		var heading: Vector3 = sample["heading"]
		body.global_position = Vector3(at.x,ground_y+0.02,at.z)
		body.rotation.y = atan2(heading.x,heading.z)
		body.velocity = Vector3.ZERO
		_leases[id] = {"slot":i,"start":sample["start"],"end":sample["end"],"heading":heading,"speed":sample["speed"],"blocked_time":0.0,"turn_cooldown":0.0,"state":"WALK"}
		body.collision_layer = 1
		body.collision_mask = 1
		body.process_mode = Node.PROCESS_MODE_INHERIT
		body.show()
		if _visuals[i].has_method("set_pedestrian_style"):
			_visuals[i].call("set_pedestrian_style",sample["style"])
		return true
	return false

## Caller invokes once per physics tick. Stop on collision; do not teleport
## or push an actor back onto the nominal line. Grounded motion uses physics.
func step(delta: float) -> void:
	if not is_finite(delta) or delta<=0.0 or delta>0.1:
		return
	for id in _leases:
		var lease: Dictionary = _leases[id]
		var i: int = lease["slot"]
		var body := _slots[i]
		var heading: Vector3 = lease["heading"]
		var a: Vector3 = lease["start"]
		var b: Vector3 = lease["end"]
		var axis := (b-a).normalized()
		var toward_end := heading.dot(axis)>0.0
		var target := b if toward_end else a
		var remaining := (target-body.global_position).dot(heading)
		if remaining<=0.06:
			heading = -heading
			lease["heading"] = heading
			target = a if toward_end else b
			remaining = (target-body.global_position).dot(heading)
		var offset := body.global_position-a
		offset.y = 0.0
		var lateral := (offset-axis*offset.dot(axis)).length()
		var desired := heading*minf(float(lease["speed"]),maxf(0.0,remaining)/delta)
		lease["turn_cooldown"] = maxf(0.0,float(lease["turn_cooldown"])-delta)
		# Do not keep walking sideways off a certified strip after a slide.
		# A displaced actor remains visible and leased for explicit recovery.
		if lateral>MAX_LATERAL_OFFSET:
			desired = Vector3.ZERO
			lease["state"] = "DISPLACED"
		else:
			lease["state"] = "WALK"
		body.velocity.x = desired.x
		body.velocity.z = desired.z
		body.velocity.y = -0.5 if body.is_on_floor() else maxf(-12.0,body.velocity.y-9.8*delta)
		var before := body.global_position
		body.move_and_slide()
		var progress := maxf(0.0,(body.global_position-before).dot(heading)/delta)
		if desired.length()>0.2 and progress<0.15 and body.is_on_floor():
			lease["state"] = "YIELD"
			lease["blocked_time"] = float(lease["blocked_time"])+delta
			# A sustained obstruction warrants walking back along the same
			# link, not stepping into the street or teleporting through it.
			if float(lease["blocked_time"])>=YIELD_SECONDS and float(lease["turn_cooldown"])<=0.0:
				heading = -heading
				lease["heading"] = heading
				lease["blocked_time"] = 0.0
				lease["turn_cooldown"] = TURN_COOLDOWN
		else:
			lease["blocked_time"] = 0.0
		body.rotation.y = atan2(heading.x,heading.z)
		if _visuals[i].has_method("set_locomotion"):
			var v := body.get_real_velocity()
			_visuals[i].call("set_locomotion",Vector2(v.x,v.z).length())

func movement_states() -> Dictionary:
	var result := {}
	for id in _leases:
		result[id] = _leases[id]["state"]
	return result

## Phase capture must succeed before release; a body displaced far from its
## link stays leased for a director to recover safely. No forced relocation.
func recycle(population, id: String, hidden: Callable) -> bool:
	if population == null or not _leases.has(id) or not hidden.is_valid():
		return false
	var lease: Dictionary = _leases[id]
	var i: int = lease["slot"]
	var body := _slots[i]
	if not bool(hidden.call(body.global_position)) or not population.capture_live(id,body.global_position,lease["heading"]):
		return false
	_leases.erase(id)
	body.velocity = Vector3.ZERO
	body.collision_layer = 0
	body.collision_mask = 0
	body.hide()
	body.process_mode = Node.PROCESS_MODE_DISABLED
	return true

## For a future director's occupied-chunk protection and native diagnostics.
## No witness candidates are produced until the director integrates LOS and
## actual approved rendered assets with the world's existing witness system.
func stats() -> Dictionary:
	return {"capacity":_slots.size(),"active":_leases.size(),"inactive":_slots.size()-_leases.size()}

## Explicit teardown only; caller must release parcel leases AFTER this call.
func disable_all() -> void:
	for id in _leases:
		var slot: int = _leases[id]["slot"]
		var body := _slots[slot]
		body.velocity = Vector3.ZERO
		body.collision_layer = 0
		body.collision_mask = 0
		body.hide()
		body.process_mode = Node.PROCESS_MODE_DISABLED
	_leases.clear()

func capture_active(population) -> bool:
	var ok := true
	for id in _leases:
		var lease: Dictionary = _leases[id]
		var body := _slots[int(lease["slot"])]
		if not population.capture_live(id,body.global_position,lease["heading"]):
			ok = false
	return ok
