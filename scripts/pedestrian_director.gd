extends Node3D
## Opt-in orchestration; no default World installation or witness generation.
const Pop = preload("res://scripts/sidewalk_population.gd")
const Cert = preload("res://scripts/sidewalk_certification.gd")
const Safety = preload("res://scripts/streaming_safety.gd")
const Pool = preload("res://scripts/pedestrian_pool.gd")
const PLAN_PERIOD = 0.20
const MAX_LOCAL_LINKS = 24
var _population := Pop.new()
var _cert := Cert.new()
var _safety := Safety.new()
var _pool: Node3D
var _city: Node
var _leases := {}
var _clock := 0.0
var _last_tick := -1
var _running := false
var _activation_count := 0
var _release_count := 0
var _failed_activation := 0
var _pending_release := 0

func configure(city: Node, seed_value: int, links: Array[Dictionary], approved_visual: PackedScene, capacity: int = Pop.MAX_ACTIVE) -> bool:
	if _running or is_instance_valid(_pool) or not is_inside_tree() or not is_instance_valid(city) or links.is_empty():
		return false
	for method in ["reserve_pedestrian_parcel","release_pedestrian_parcel","get_loaded_blocks","get_streaming_stats","is_spawn_area_ready"]:
		if not city.has_method(method):
			return false
	var pool := Pool.new()
	add_child(pool)
	if not pool.build(approved_visual,capacity):
		remove_child(pool)
		pool.free()
		return false
	_pool = pool
	_city = city
	_population.configure(seed_value,links)
	_running = true
	return true

func _local_candidates(focus: Vector3, camera: Camera3D, active: Dictionary, hour: float) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id in _population.ids():
		if active.has(id) or (hour>=0.0 and not _population.available_at(id,hour)):
			continue
		var entry: Dictionary = _population.sample(id)
		var at: Vector3 = entry["position"]
		var distance := at.distance_to(focus)
		if distance<Pop.MIN_DISTANCE or distance>Pop.LOAD_DISTANCE or at.distance_to(camera.global_position)<Pop.MIN_DISTANCE:
			continue
		# Certify likely hidden spawn candidates first; the live predicate is
		# checked again at activation, never rely on an old camera sample.
		if not Safety.outside_expanded_view(camera,at,Safety.PEDESTRIAN_RADIUS):
			continue
		entry["distance"] = distance
		entries.append(entry)
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if is_equal_approx(float(a["distance"]),float(b["distance"])):
			return str(a["id"])<str(b["id"])
		return float(a["distance"])<float(b["distance"]))
	if entries.size()>MAX_LOCAL_LINKS:
		entries.resize(MAX_LOCAL_LINKS)
	return entries

func _ground(space: PhysicsDirectSpaceState3D, at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.65,at-Vector3.UP*0.65,1)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or not hit.get("collider") is StaticBody3D or (hit["normal"] as Vector3).y<0.8:
		return NAN
	return (hit["position"] as Vector3).y

## Call exactly once per physics tick after camera/focus update. Indoor mode
## prevents transitions, but exterior leases remain protected and keep walking.
func tick(delta: float, focus: Vector3, camera: Camera3D, indoors: bool, occupied: Array[Vector3], hour: float = -1.0) -> void:
	if not _running or not is_instance_valid(_city) or not is_instance_valid(_pool) or not is_finite(delta) or delta<=0.0 or delta>0.1:
		return
	var frame := Engine.get_physics_frames()
	if frame==_last_tick:
		return
	_last_tick = frame
	var space := get_world_3d().direct_space_state
	_pool.call("step",delta)
	var active: Dictionary = _pool.call("active_positions")
	_population.advance(delta,active.keys())
	_safety.observe(camera,delta)
	if indoors or not is_finite(hour) or not focus.is_finite() or not is_instance_valid(camera) or not camera.current:
		return
	_cert.advance_candidates(_city,space,_local_candidates(focus,camera,active,hour))
	_clock += delta
	if _clock<PLAN_PERIOD:
		return
	_clock = fposmod(_clock,PLAN_PERIOD)
	var certified := func(entry: Dictionary) -> bool: return _cert.cached_clear(_city,entry)
	var allow := func(entry: Dictionary) -> bool: return _safety.pedestrian_spawn_allowed(camera,_city,space,entry,certified)
	var hidden := func(at: Vector3) -> bool: return _safety.hidden(camera,at,Safety.PEDESTRIAN_RADIUS)
	var plan: Dictionary = _population.plan_changes(focus,camera.global_position,false,active,occupied,allow,hidden,hour)
	for id in plan["recycle"]:
		if bool(_pool.call("recycle",_population,id,hidden)):
			_city.call("release_pedestrian_parcel",id)
			_leases.erase(id)
			_release_count += 1
		else:
			_pending_release += 1
	for entry in plan["activate"]:
		if _leases.size()>=int(_pool.call("capacity")):
			break
		var id: String = entry["id"]
		var at: Vector3 = entry["position"]
		if not bool(_city.call("reserve_pedestrian_parcel",id,entry["start"],entry["end"])):
			_failed_activation += 1
			continue
		if bool(_pool.call("activate",_population,id,_ground(space,at),allow)):
			_leases[id] = true
			_activation_count += 1
		else:
			_city.call("release_pedestrian_parcel",id)
			_failed_activation += 1

## Save only logical phase data. Failed projection is explicit: caller must
## keep the prior save or recover the displaced actor rather than silently jump.
func snapshot() -> Dictionary:
	if not _running or not bool(_pool.call("capture_active",_population)):
		return {}
	return _population.snapshot()

func restore(value: Variant) -> bool:
	if not _running or not _leases.is_empty():
		return false
	_population.restore(value)
	return true

func active_routines() -> Dictionary:
	var result := {}
	for id in _leases:
		result[id] = _population.routine_for(id)
	return result

func stats() -> Dictionary:
	var movement: Dictionary = _pool.call("movement_states") if is_instance_valid(_pool) else {}
	return {"movement":movement,"logical":_population.ids().size(),"active":_leases.size(),"activations":_activation_count,
		"releases":_release_count,"failed_activations":_failed_activation,"failed_recycles":_pending_release}

## For level destruction or explicit transition only, not ordinary streaming.
func shutdown() -> void:
	_running = false
	if is_instance_valid(_pool):
		_pool.call("disable_all")
	if is_instance_valid(_city):
		for id in _leases:
			_city.call("release_pedestrian_parcel",id)
	_leases.clear()

func _exit_tree() -> void:
	shutdown()
