extends Node3D
## Owns the optional street population, its live leases and camera guards.
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
var _candidate_clock := 0.12
var _phase_clock := 0.0
var _candidates: Array[Dictionary] = []
var _last_tick := -1
var _running := false
var _activation_count := 0
var _release_count := 0
var _failed_activation := 0
var _pending_release := 0
var _street_clock := 12.0
var _street_lease := ""
var _street_check:=0.0
var _exchange:Dictionary={}
var _exchange_turn:=0
var _exchange_line:=""
var _exchange_result:=""
var _exchange_elapsed:=0.0
var _exchange_check:=0.0
var _exchange_gap:=0.0
var _street_dialogue:WeakRef
const Satire=preload("res://scripts/street_satire.gd")
var _named_ids:Dictionary={}
var _quest_resident:=""
var _contact:Dictionary={}
var _contact_clock:=0.0
var _player_request:Dictionary={}
var _player_lease:=""
var _player_line:=""
var _player_finished:=false
const PLAYER_SCOPE="street:player"
const EXCHANGE_SCOPE="street:exchange"

func configure(city: Node, seed_value: int, links: Array[Dictionary], approved_visual: PackedScene,
		capacity: int = Pop.MAX_ACTIVE, models: Array[PackedScene] = []) -> bool:
	if _running or is_instance_valid(_pool) or not is_inside_tree() or not is_instance_valid(city) or links.is_empty():
		return false
	for method in ["reserve_pedestrian_parcel","release_pedestrian_parcel","get_loaded_blocks","get_streaming_stats","is_spawn_area_ready"]:
		if not city.has_method(method):
			return false
	var pool := Pool.new()
	add_child(pool)
	if not pool.build(approved_visual, capacity, models):
		remove_child(pool)
		pool.free()
		return false
	_pool = pool
	_city = city
	_population.configure(seed_value,links)
	# Reserve each named identity for exactly one stable logical resident.
	var ids:=_population.ids()
	ids.sort()
	for id in ids:
		var character:=Satire.personality(id)
		if not _named_ids.has(character):
			_named_ids[character]=id
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
		if a["id"]==_quest_resident or b["id"]==_quest_resident:
			return a["id"]==_quest_resident and b["id"]!=_quest_resident
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
func tick(delta: float, focus: Vector3, camera: Camera3D, indoors: bool, occupied: Array[Vector3],
		hour: float = -1.0, signals: Node = null) -> void:
	if not _running or not is_instance_valid(_city) or not is_instance_valid(_pool) or not is_finite(delta) or delta<=0.0 or delta>0.1:
		return
	var frame := Engine.get_physics_frames()
	if frame==_last_tick:
		return
	_last_tick = frame
	var space := get_world_3d().direct_space_state
	_pool.call("step", delta, signals, hour)
	var active: Dictionary = _pool.call("active_positions")
	_phase_clock += delta
	if _phase_clock >= PLAN_PERIOD:
		_population.advance(_phase_clock, active.keys())
		_phase_clock = 0.0
	_safety.observe(camera,delta)
	if indoors or not is_finite(hour) or not focus.is_finite() or not is_instance_valid(camera) or not camera.current:
		return
	if _leases.size() < int(_pool.call("capacity")):
		_candidate_clock += delta
		if _candidate_clock >= 0.12:
			_candidates = _local_candidates(focus, camera, active, hour)
			_candidate_clock = 0.0
		_cert.advance_candidates(_city, space, _candidates)
	_clock += delta
	if _clock<PLAN_PERIOD:
		return
	_clock = fposmod(_clock,PLAN_PERIOD)
	var certified := func(entry: Dictionary) -> bool: return _cert.cached_clear(_city,entry)
	var allow := func(entry: Dictionary) -> bool:
		return _pool.call("has_free_style", entry["style"]) and _safety.pedestrian_spawn_allowed(camera,_city,space,entry,certified)
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
	if _phase_clock > 0.0:
		_population.advance(_phase_clock, _leases.keys())
		_phase_clock = 0.0
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

func active_positions() -> Dictionary:
	return _pool.call("active_positions") if _running else {}

func react_to_incident(at: Vector3, radius: float, ignored: Array[RID], urgent: bool = false) -> void:
	if _running:
		_pool.call("react_to_incident", get_world_3d().direct_space_state, at, radius, ignored, urgent)

func react_to_traffic(vehicles: Array[CharacterBody3D]) -> void:
	if _running:
		_pool.call("react_to_traffic", vehicles)
		_pool.call("socialize_nearby", get_world_3d().direct_space_state)

func camera_exclusions() -> Array[RID]:
	if _running:
		return _pool.call("live_body_rids")
	return []

func witness_candidates(target: Vector3, camera: Camera3D) -> Array[Dictionary]:
	if _running and is_instance_valid(camera) and camera.current:
		return _pool.call("witness_candidates", target, camera)
	return []

func stats() -> Dictionary:
	var movement: Dictionary = _pool.call("movement_states") if is_instance_valid(_pool) else {}
	return {"movement":movement,"logical":_population.ids().size(),"active":_leases.size(),"activations":_activation_count,
		"releases":_release_count,"failed_activations":_failed_activation,"failed_recycles":_pending_release}

## For level destruction or explicit transition only, not ordinary streaming.
func shutdown() -> void:
	if _street_dialogue!=null:
		var speech:=_street_dialogue.get_ref() as Node
		if is_instance_valid(speech):
			if not _exchange.is_empty():
				_end_exchange(speech)
			if not _street_lease.is_empty():
				speech.call("cancel_scope","street:"+_street_lease)
			_finish_player_reply(speech)
	_street_dialogue=null
	_street_lease=""
	_contact={}
	_player_request={}
	_running = false
	if is_instance_valid(_pool):
		_pool.call("disable_all")
	if is_instance_valid(_city):
		for id in _leases:
			_city.call("release_pedestrian_parcel",id)
	_leases.clear()

func _exit_tree() -> void:
	shutdown()

## Transient ambient dialogue only; no mission, wallet or wanted changes.

func update_street_dialogue(dialogue:Node, listener:Vector3, listener_rid:RID, allowed:bool, delta:float) -> void:
	if not _running or not is_instance_valid(dialogue):
		return
	_street_dialogue=weakref(dialogue)
	if not dialogue.is_connected("line_ended",_on_street_line_ended):
		dialogue.connect("line_ended",_on_street_line_ended)
	_update_contact(dialogue,listener,listener_rid,allowed,delta)
	if not _player_lease.is_empty():
		return
	if not _exchange.is_empty():
		_tick_exchange(dialogue,listener,listener_rid,allowed,delta)
		return
	if not _street_lease.is_empty():
		var scope:="street:"+_street_lease
		_street_check-=delta
		var invalid:=not allowed or not bool(_pool.call("street_bark_valid",_street_lease))
		if not invalid and _street_check<=0.0:
			_street_check=0.2
			invalid=not bool(_pool.call("bark_audible",_street_lease,get_world_3d().direct_space_state,listener,listener_rid))
		if invalid or not bool(dialogue.call("has_scope",scope)):
			dialogue.call("cancel_scope",scope)
			_street_lease=""
	if not allowed:
		return
	_street_clock=maxf(0.0,_street_clock-delta)
	if _street_clock>0.0:
		return
	_street_clock=1.0
	var speech:Dictionary=dialogue.call("stats")
	if not str(speech["active"]).is_empty() or int(speech["pending"])>0:
		return
	var space:=get_world_3d().direct_space_state
	# A remembered witnessed incident takes precedence over a new exchange.
	var bark:Dictionary=_pool.call("street_bark",space,listener,listener_rid,true)
	if bark.is_empty():
		_exchange=_pool.call("begin_street_exchange",space,listener,listener_rid)
		if not _exchange.is_empty():
			_exchange_turn=0
			_exchange_elapsed=0.0
			_exchange_check=0.0
			_exchange_gap=0.0
			_exchange_line=""
			_exchange_result=""
			_tick_exchange(dialogue,listener,listener_rid,allowed,delta)
			return
		bark=_pool.call("street_bark",space,listener,listener_rid)
	if bark.is_empty():
		return
	var lease_id:=str(bark["lease_id"])
	if dialogue.call("enqueue",str(bark["id"]),str(bark["text"]),0,bark["speaker"],"street:"+lease_id):
		_street_lease=lease_id
		_street_check=0.0
		_street_clock=24.0

func _on_street_line_ended(line_id:String,reason:String) -> void:
	if not _player_line.is_empty() and line_id==_player_line:
		_player_finished=true
	if not _exchange.is_empty() and line_id==_exchange_line:
		_exchange_result=reason

func _end_exchange(dialogue:Node) -> void:
	var pair:=_exchange
	# Clear first so synchronous cancellation cannot advance a stale turn.
	_exchange={}
	_exchange_line=""
	_exchange_result=""
	if not pair.is_empty():
		_pool.call("release_exchange",pair)
	dialogue.call("cancel_scope",EXCHANGE_SCOPE)
	_street_clock=36.0

func _tick_exchange(dialogue:Node,listener:Vector3,listener_rid:RID,allowed:bool,delta:float) -> void:
	_exchange_elapsed+=delta
	if not allowed or _exchange_elapsed>=28.0 or not bool(_pool.call("exchange_valid",_exchange)):
		_end_exchange(dialogue)
		return
	_exchange_check-=delta
	if _exchange_check<=0.0:
		_exchange_check=0.2
		if not bool(_pool.call("exchange_visible",_exchange,get_world_3d().direct_space_state,listener,listener_rid)):
			_end_exchange(dialogue)
			return
	if not _exchange_result.is_empty():
		if _exchange_result!="complete":
			_end_exchange(dialogue)
			return
		_exchange_turn+=1
		_exchange_line=""
		_exchange_result=""
		_exchange_gap=0.35
	if _exchange_turn>=_exchange["beats"].size():
		_end_exchange(dialogue)
		return
	if not _exchange_line.is_empty():
		if not bool(dialogue.call("has_scope",EXCHANGE_SCOPE)):
			_end_exchange(dialogue)
		return
	_exchange_gap=maxf(0.0,_exchange_gap-delta)
	if _exchange_gap>0.0:
		return
	var speech:Dictionary=dialogue.call("stats")
	if not str(speech["active"]).is_empty() or int(speech["pending"])>0:
		# Story speech takes priority; do not resume an old conversation.
		_end_exchange(dialogue)
		return
	var beat:Dictionary=_exchange["beats"][_exchange_turn]
	var speaker:Node3D=_pool.call("exchange_speaker",_exchange,str(beat["character"]))
	if not is_instance_valid(speaker):
		_end_exchange(dialogue)
		return
	_exchange_line=str(beat["id"])
	if not bool(dialogue.call("enqueue",_exchange_line,str(beat["text"]),0,speaker,EXCHANGE_SCOPE)):
		_end_exchange(dialogue)

func nearby_contact()->Dictionary:
	return _contact.duplicate(true)

func request_player_reply(id:String,topic:int)->bool:
	if not _running or id.is_empty() or topic<0 or topic>1 or _contact.get("lease_id","")!=id:
		return false
	_player_request={"id":id,"topic":topic}
	return true

func _finish_player_reply(dialogue:Node)->void:
	var id:=_player_lease
	_player_lease=""
	_player_line=""
	_player_finished=false
	if not id.is_empty() and is_instance_valid(_pool):
		_pool.call("release_player_reply",id)
	dialogue.call("cancel_scope",PLAYER_SCOPE)
	_street_clock=maxf(_street_clock,24.0)

func _update_contact(dialogue:Node,listener:Vector3,listener_rid:RID,allowed:bool,delta:float)->void:
	var space:=get_world_3d().direct_space_state
	if not _player_lease.is_empty() and (not allowed or _player_finished or not bool(dialogue.call("has_scope",PLAYER_SCOPE)) or not bool(_pool.call("player_reply_valid",_player_lease))):
		_finish_player_reply(dialogue)
	_contact_clock-=delta
	if not allowed:
		_contact={}
		_player_request={}
		return
	if _contact_clock<=0.0:
		_contact_clock=0.18
		_contact=_pool.call("contact_near",space,listener,listener_rid)
		if not _contact.is_empty() and _named_ids.get(_contact["character"],"")!=_contact["lease_id"]:
			# Other residents of the same archetype are not duplicate named people.
			_contact["name"]=_contact["role"]
		if not _player_lease.is_empty() and (_pool.call("contact_near",space,listener,listener_rid,_player_lease) as Dictionary).is_empty():
			_finish_player_reply(dialogue)
	if _player_request.is_empty():
		return
	var request:=_player_request
	_player_request={}
	if not _player_lease.is_empty():
		_finish_player_reply(dialogue)
	if not _exchange.is_empty():
		_end_exchange(dialogue)
	if not _street_lease.is_empty():
		dialogue.call("cancel_scope","street:"+_street_lease)
		_street_lease=""
	var stats:Dictionary=dialogue.call("stats")
	if not str(stats["active"]).is_empty() or int(stats["pending"])>0:
		return
	var reply:Dictionary=_pool.call("begin_player_reply",space,listener,listener_rid,str(request["id"]),int(request["topic"]))
	if reply.is_empty():
		return
	_player_lease=str(request["id"])
	_player_line=str(reply["id"])
	_player_finished=false
	if not bool(dialogue.call("enqueue",_player_line,str(reply["text"]),0,reply["speaker"],PLAYER_SCOPE)):
		_finish_player_reply(dialogue)

## Clear transient interactions on respawn, story transitions or save restore.
func cancel_street_dialogue(dialogue:Node)->void:
	if not is_instance_valid(dialogue):
		return
	if not _exchange.is_empty():
		_end_exchange(dialogue)
	if not _street_lease.is_empty():
		dialogue.call("cancel_scope","street:"+_street_lease)
		_street_lease=""
	_finish_player_reply(dialogue)
	_player_request={}
	_contact={}
	_contact_clock=0.0

## Quest availability changes only scheduling preference, never the spawn
## distance, visibility, collision certification, or physical actor budget.
func track_cal_quest(active:bool)->void:
	var id:=str(_named_ids.get("robot_romantic","")) if active else ""
	if id!=_quest_resident:
		_quest_resident=id
		_population.prioritize_resident(id)
		_candidate_clock=0.12

func cal_position()->Vector3:
	var id:=str(_named_ids.get("robot_romantic",""))
	var active:=active_positions()
	if active.has(id):
		return active[id]
	var sample:Dictionary=_population.sample(id)
	return sample.get("position",Vector3.INF)

func is_named_cal(id:String)->bool:
	return not id.is_empty() and _named_ids.get("robot_romantic","")==id

func confirm_cal_contact(id:String,listener:Vector3,listener_rid:RID)->bool:
	if not _running or not is_named_cal(id):
		return false
	var current:Dictionary=_pool.call("contact_near",get_world_3d().direct_space_state,listener,listener_rid,id)
	return not current.is_empty()

func play_cal_quest_line(dialogue:Node,id:String,action:String,listener:Vector3,listener_rid:RID)->bool:
	if not confirm_cal_contact(id,listener,listener_rid) or not is_instance_valid(dialogue):
		return false
	cancel_street_dialogue(dialogue)
	var speech:Dictionary=dialogue.call("stats")
	if not str(speech["active"]).is_empty() or int(speech["pending"])>0:
		return false
	var reply:Dictionary=_pool.call("begin_cal_reply",get_world_3d().direct_space_state,listener,listener_rid,id,action)
	if reply.is_empty():
		return false
	_player_lease=id
	_player_line=str(reply["id"])
	_player_finished=false
	if not bool(dialogue.call("enqueue",_player_line,str(reply["text"]),0,reply["speaker"],PLAYER_SCOPE)):
		_finish_player_reply(dialogue)
		return false
	return true
