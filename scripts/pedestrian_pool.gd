extends Node3D
## Opt-in pool of reusable CharacterBody3D sidewalk actors.
## The director supplies the visual rig, live spawn/recycle predicates,
## actual ground height and one physics-tick call.
const Population = preload("res://scripts/sidewalk_population.gd")
const Routines = preload("res://scripts/civilian_routines.gd")
const Satire = preload("res://scripts/street_satire.gd")
const RADIUS = 0.32
const HEIGHT = 1.8
const YIELD_SECONDS = 1.2
const TURN_COOLDOWN = 2.0
const MAX_LATERAL_OFFSET = 0.6
const SIDEWALK_RENDER_TOP = 0.14
var _slots: Array[CharacterBody3D] = []
var _leases: Dictionary = {}
var _visuals: Array[Node3D] = []
var _model_count := 1
const MAX_INCIDENT_RADIUS = 24.0
const ALERT_COOLDOWN = 5.0

func build(visual_scene: PackedScene, capacity: int = Population.MAX_ACTIVE,
		models: Array[PackedScene] = []) -> bool:
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
		if not models.is_empty():
			if not candidate.has_method("set_pedestrian_model"):
				for visual in pending:
					visual.free()
				return false
			candidate.call("set_pedestrian_model", models[i % models.size()])
	_model_count = maxi(1, models.size())
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	var valid := true
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
		if pending[i].has_method("is_pedestrian_visual_ready") and not pending[i].call("is_pedestrian_visual_ready"):
			valid = false
	return valid

func active_positions() -> Dictionary:
	var result := {}
	for id in _leases:
		var slot: int = _leases[id]["slot"]
		result[id] = _slots[slot].global_position
	return result

func capacity() -> int:
	return _slots.size()

func has_free_style(style: int) -> bool:
	var used := {}
	for lease in _leases.values():
		used[lease["slot"]] = true
	for i in range(style % _model_count, _slots.size(), _model_count):
		if not used.has(i):
			return true
	return false

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
	for i in range(int(sample["style"]) % _model_count, _slots.size(), _model_count):
		if used.has(i):
			continue
		var body := _slots[i]
		var heading: Vector3 = sample["heading"]
		body.global_position = Vector3(at.x,ground_y+0.02,at.z)
		body.rotation.y = atan2(heading.x,heading.z)
		body.velocity = Vector3.ZERO
		_leases[id] = {"slot":i,"start":sample["start"],"end":sample["end"],"heading":heading,"speed":sample["speed"],
			"blocked_time":0.0,"turn_cooldown":0.0,"state":"WALK","hold":0.0,"alert":0.0,
			"arrival":sample.get("arrival", ""), "signal":sample.get("signal", Vector3i.ZERO),
			"social":0.0,"social_cooldown":0.0,"social_facing":Vector3.ZERO,
			"routine":sample.get("routine",{}),"intent":"RESTING","dwell_state":"RESTING",
			"alert_facing":Vector3.ZERO,"alert_cooldown":0.0,"retreat":0.0,
			"bark_index":posmod(id.hash(),3),"bark_cooldown":0.0,
			"context":"","context_ttl":0.0,"context_cooldown":0.0}
		body.collision_layer = 1
		body.collision_mask = 1
		body.process_mode = Node.PROCESS_MODE_INHERIT
		if _visuals[i].has_method("reset_pedestrian_visual"):
			_visuals[i].call("reset_pedestrian_visual")
		_visuals[i].position.y = maxf(0.0, SIDEWALK_RENDER_TOP - ground_y - 0.02)
		body.show()
		if _visuals[i].has_method("set_pedestrian_style"):
			_visuals[i].call("set_pedestrian_style",sample["style"])
		return true
	return false

## Caller invokes once per physics tick. Stop on collision; do not teleport
## or push an actor back onto the nominal line. Grounded motion uses physics.
func step(delta: float, signals: Node = null, hour: float = -1.0) -> void:
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
		var arrival: String = lease["arrival"]
		lease["intent"] = Routines.activity(lease["routine"],hour)
		if remaining<=0.06:
			# Reaching the safe end terminates retreat before ordinary reversal.
			if float(lease["retreat"])>0.0:
				lease["retreat"]=0.0
			heading = -heading
			lease["heading"] = heading
			target = a if toward_end else b
			remaining = (target-body.global_position).dot(heading)
			if toward_end:
				lease["dwell_state"] = str(lease["intent"]) if arrival=="RESTING" else arrival
				lease["hold"] = Routines.dwell(lease["intent"]) if arrival=="RESTING" else _hold_duration(arrival, lease["signal"], signals)
		var offset := body.global_position-a
		offset.y = 0.0
		var lateral := (offset-axis*offset.dot(axis)).length()
		var desired := heading*minf(float(lease["speed"]),maxf(0.0,remaining)/delta)
		lease["turn_cooldown"] = maxf(0.0,float(lease["turn_cooldown"])-delta)
		# Do not keep walking sideways off a certified strip after a slide.
		# A displaced actor remains visible and leased for explicit recovery.
		lease["alert"] = maxf(0.0, float(lease["alert"]) - delta)
		lease["alert_cooldown"] = maxf(0.0, float(lease["alert_cooldown"]) - delta)
		lease["retreat"] = maxf(0.0, float(lease["retreat"]) - delta)
		lease["bark_cooldown"] = maxf(0.0,float(lease["bark_cooldown"])-delta)
		lease["context_ttl"] = maxf(0.0,float(lease["context_ttl"])-delta)
		lease["context_cooldown"] = maxf(0.0,float(lease["context_cooldown"])-delta)
		if float(lease["context_ttl"])<=0.0:
			lease["context"]=""
		lease["hold"] = maxf(0.0, float(lease["hold"]) - delta)
		lease["social"] = maxf(0.0, float(lease["social"]) - delta)
		lease["social_cooldown"] = maxf(0.0, float(lease["social_cooldown"]) - delta)
		if lateral>MAX_LATERAL_OFFSET:
			desired = Vector3.ZERO
			lease["state"] = "DISPLACED"
		elif float(lease["alert"]) > 0.0:
			desired = Vector3.ZERO
			lease["state"] = "ALERT"
		elif float(lease["retreat"]) > 0.0:
			# Retreat along the certified strip, not into traffic.
			desired = heading*minf(float(lease["speed"])*1.5,maxf(0.0,remaining)/delta)
			lease["state"] = "RETREAT"
		elif float(lease["social"]) > 0.0:
			desired = Vector3.ZERO
			lease["state"] = "SOCIALIZE"
		elif float(lease["hold"]) > 0.0:
			desired = Vector3.ZERO
			lease["state"] = lease["dwell_state"]
		else:
			lease["state"] = "WALK"
		body.velocity.x = desired.x
		body.velocity.z = desired.z
		body.velocity.y = -0.5 if body.is_on_floor() else maxf(-12.0,body.velocity.y-9.8*delta)
		var before := body.global_position
		body.move_and_slide()
		if body.is_on_floor():
			# The photo sidewalk overlays the established foundation collider.
			# Keep the visual feet at its surface without changing the capsule.
			var lift := maxf(0.0, SIDEWALK_RENDER_TOP - body.global_position.y)
			_visuals[i].position.y = move_toward(_visuals[i].position.y, lift, delta * 2.5)
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
		var facing: Vector3 = lease["social_facing"] if lease["state"] == "SOCIALIZE" else heading
		if lease["state"]=="ALERT" and (lease["alert_facing"] as Vector3).length_squared()>0.01:
			facing=lease["alert_facing"]
		body.rotation.y = lerp_angle(body.rotation.y, atan2(facing.x,facing.z), minf(1.0, 9.0 * delta))
		if _visuals[i].has_method("set_locomotion"):
			var v := body.get_real_velocity()
			_visuals[i].call("set_locomotion",Vector2(v.x,v.z).length())
		if _visuals[i].has_method("set_activity"):
			_visuals[i].call("set_activity", lease["state"])

func _hold_duration(arrival: String, crossing: Vector3i, signals: Node) -> float:
	match arrival:
		"WAIT_CROSSING":
			if is_instance_valid(signals):
				var axis := "x" if crossing.z == 0 else "z"
				return 2.3 if signals.call("phase_at", crossing.x, crossing.y, axis) != "GREEN" else 0.0
		"STOREFRONT":
			return 3.0
		"RESTING":
			return 2.0
	return 0.0

func react_to_incident(space: PhysicsDirectSpaceState3D, at: Vector3, radius: float, ignored: Array[RID], urgent: bool = false) -> void:
	if not at.is_finite() or not is_finite(radius) or radius<=0.0:
		return
	radius=minf(radius,MAX_INCIDENT_RADIUS)
	for id in _leases:
		var lease: Dictionary = _leases[id]
		var body := _slots[int(lease["slot"])]
		var eye := body.global_position + Vector3.UP * 1.6
		if eye.distance_squared_to(at) > radius * radius or (float(lease["alert_cooldown"])>0.0 and (not urgent or float(lease["retreat"])>0.0)):
			continue
		var exclude := ignored.duplicate()
		exclude.append(body.get_rid())
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at, 1, exclude)).is_empty():
			lease["alert"] = 0.65 if urgent else 2.6
			_remember_context(lease,"urgent" if urgent else "incident")
			lease["alert_cooldown"] = ALERT_COOLDOWN
			lease["social"] = 0.0
			lease["hold"] = 0.0
			var toward := at-eye
			toward.y=0.0
			lease["alert_facing"] = toward.normalized()
			if urgent:
				var heading:Vector3=lease["heading"]
				if heading.dot(toward)>0.0:
					lease["heading"] = -heading
				lease["retreat"] = 3.8

func react_to_traffic(vehicles: Array[CharacterBody3D]) -> void:
	var space:=get_world_3d().direct_space_state
	for id in _leases:
		var lease: Dictionary = _leases[id]
		var body := _slots[int(lease["slot"])]
		for vehicle in vehicles:
			var offset := body.global_position - vehicle.global_position
			offset.y = 0.0
			if offset.length_squared() > 9.0 * 9.0:
				continue
			var velocity := Vector3(vehicle.velocity.x, 0, vehicle.velocity.z)
			var speed := velocity.length()
			if speed < 4.0:
				continue
			var leading := offset.dot(velocity / speed)
			if leading > -0.8 and leading < 1.1 * speed and (offset - velocity / speed * leading).length() < 2.25:
				# Reject vehicles on other floors or behind solid geometry.
				if absf(body.global_position.y-vehicle.global_position.y)>2.0:
					continue
				var exclude:Array[RID]=[body.get_rid(),vehicle.get_rid()]
				var eye:=body.global_position+Vector3.UP*1.4
				var target:=vehicle.global_position+Vector3.UP*0.8
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target,1,exclude)).is_empty():
					continue
				lease["alert"] = maxf(float(lease["alert"]), 0.65)
				_remember_context(lease,"traffic")
				break

func socialize_nearby(space: PhysicsDirectSpaceState3D) -> void:
	var resting: Array[Dictionary] = []
	for lease in _leases.values():
		if lease["state"] in ["RESTING", "BREAK", "NIGHT_OUT", "ERRAND", "STOREFRONT", "WAIT_CROSSING"] and float(lease["social_cooldown"]) <= 0.0:
			resting.append(lease)
	for i in range(resting.size()):
		var first := _slots[int(resting[i]["slot"])]
		for j in range(i + 1, resting.size()):
			var second := _slots[int(resting[j]["slot"])]
			var distance := first.global_position.distance_to(second.global_position)
			if distance < 1.35 or distance > 4.0:
				continue
			var ignore: Array[RID] = [first.get_rid(), second.get_rid()]
			var query := PhysicsRayQueryParameters3D.create(first.global_position + Vector3.UP * 1.6,
				second.global_position + Vector3.UP * 1.6, 1, ignore)
			if not space.intersect_ray(query).is_empty():
				continue
			var heading := first.global_position.direction_to(second.global_position)
			resting[i]["social_facing"] = heading
			resting[j]["social_facing"] = -heading
			for lease in [resting[i], resting[j]]:
				lease["social"] = 3.5
				lease["social_cooldown"] = 18.0
			return

func live_body_rids() -> Array[RID]:
	var result: Array[RID] = []
	for lease in _leases.values():
		result.append(_slots[int(lease["slot"])].get_rid())
	return result

func witness_candidates(target: Vector3, camera: Camera3D) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for id in _leases:
		var slot: int = _leases[id]["slot"]
		var body := _slots[slot]
		var visual := _visuals[slot]
		var eye := visual.global_position + Vector3.UP * 1.62
		if not body.is_visible_in_tree() or not visual.has_method("is_pedestrian_visual_ready") or not visual.call("is_pedestrian_visual_ready"):
			continue
		if eye.distance_squared_to(target) <= 30.0 * 30.0 and camera.is_position_in_frustum(eye):
			candidates.append({"eye":eye, "facing":body.global_basis.z, "police":false, "rid":body.get_rid()})
	return candidates

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

## At most one local calm speaker selected per global cooldown, with real LOS.
func street_bark(space:PhysicsDirectSpaceState3D, listener:Vector3, listener_rid:RID) -> Dictionary:
	var nearest: String = ""
	var best := 8.0*8.0
	var best_context:=false
	for id in _leases:
		var lease:Dictionary=_leases[id]
		var contextual:=float(lease["context_ttl"])>0.0 and float(lease["context_cooldown"])<=0.0
		if not _bark_calm(lease) or (not contextual and (best_context or float(lease["bark_cooldown"])>0.0)):
			continue
		var body:=_slots[int(lease["slot"])]
		var eye:=body.global_position+Vector3.UP*1.6
		var distance:=eye.distance_squared_to(listener)
		if distance>8.0*8.0 or distance<1.0 or (contextual==best_context and distance>best):
			continue
		var ignored:Array[RID]=[body.get_rid()]
		if listener_rid.is_valid():
			ignored.append(listener_rid)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,listener,1,ignored)).is_empty():
			continue
		best=distance
		best_context=contextual
		nearest=id
	if nearest.is_empty():
		return {}
	var chosen:Dictionary=_leases[nearest]
	var line:Dictionary=Satire.contextual_line(nearest,str(chosen["context"])) if best_context else {}
	if not line.is_empty():
		chosen["context"]=""
		chosen["context_ttl"]=0.0
		chosen["context_cooldown"]=60.0
	else:
		line=Satire.line_for(nearest,int(chosen["bark_index"]))
		chosen["bark_index"]=posmod(int(chosen["bark_index"])+1,3)
	chosen["bark_cooldown"]=75.0
	line["speaker"]=_slots[int(chosen["slot"])]
	line["lease_id"]=nearest
	return line

static func _bark_calm(lease:Dictionary) -> bool:
	return float(lease["alert"])<=0.0 and float(lease["retreat"])<=0.0 and lease["state"] in ["WALK","RESTING","BREAK","NIGHT_OUT","ERRAND","STOREFRONT","SOCIALIZE","WAIT_CROSSING"]

func street_bark_valid(id:String) -> bool:
	return _leases.has(id) and _bark_calm(_leases[id])

## One bounded recent event per lease. Keep more urgent context over traffic.
static func _remember_context(lease:Dictionary,context:String) -> void:
	if float(lease["context_cooldown"])>0.0:
		return
	var previous:=str(lease["context"])
	var priority:Dictionary={"":0,"traffic":1,"incident":2,"urgent":3}
	if int(priority.get(context,0))<int(priority.get(previous,0)):
		return
	lease["context"]=context
	lease["context_ttl"]=28.0
