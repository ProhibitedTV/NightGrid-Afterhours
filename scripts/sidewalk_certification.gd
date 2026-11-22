extends RefCounted
## Incremental clearance certificate for ONE straight sidewalk candidate.
## A certificate is short-lived, valid only for the loaded city revision.
## Local spawn clearance and live movement collision remain mandatory.
const Plan = preload("res://scripts/world_plan.gd")
const PENDING = 0
const CLEAR = 1
const BLOCKED = 2
const RADIUS = 0.45
const HEIGHT = 1.8
const MAX_PROBES_PER_TICK = 8
const SAMPLE_SPACING = 0.5
const MAX_LENGTH = 30.0
const VALID_TICKS = 30
const MAX_CACHE = 256
var _cache: Dictionary = {}
var _job: Dictionary = {}
var _epoch := ""
var _last_frame := -1
var _shape := CapsuleShape3D.new()

func _init() -> void:
	_shape.radius = RADIUS
	_shape.height = HEIGHT

func _reset_epoch(city: Node) -> bool:
	if not is_instance_valid(city) or not city.has_method("get_loaded_blocks") or not city.has_method("get_streaming_stats"):
		_cache.clear()
		_job.clear()
		_epoch = ""
		return false
	var stats: Dictionary = city.call("get_streaming_stats")
	if not stats.has("loads") or not stats.has("unloads"):
		return false
	var next := "%d:%s:%s" % [city.get_instance_id(),str(stats["loads"]),str(stats["unloads"])]
	if next!=_epoch:
		_epoch = next
		_cache.clear()
		_job.clear()
	return true

static func _valid_link(entry: Dictionary) -> bool:
	var a: Variant = entry.get("start")
	var b: Variant = entry.get("end")
	if str(entry.get("id","")).is_empty() or not a is Vector3 or not b is Vector3 or not a.is_finite() or not b.is_finite():
		return false
	if a.distance_to(b)<1.0 or a.distance_to(b)>MAX_LENGTH or absf(a.y-b.y)>0.01 or a.y<0.0 or a.y>0.6:
		return false
	var cell := Vector2i(floori(a.x/Plan.BLOCK_SIZE),floori(a.z/Plan.BLOCK_SIZE))
	if not Plan.is_valid_block(cell.x,cell.y) or Vector2i(floori(b.x/Plan.BLOCK_SIZE),floori(b.z/Plan.BLOCK_SIZE))!=cell:
		return false
	if entry.get("kind", "") == "retail_portal":
		# Only the two explicitly modeled open portals may leave the curb strip.
		# The sweeps and support samples below still apply to every meter.
		return cell.y == 0 and absf(a.x - b.x) < 0.01 and absf(absf(a.x) - 18.5) < 0.01 and (
			absf(a.z - 9.7) < 0.01 and absf(b.z - 15.45) < 0.01)
	var center := Vector3((cell.x+0.5)*Plan.BLOCK_SIZE,a.y,(cell.y+0.5)*Plan.BLOCK_SIZE)
	var x: Vector3 = a-center
	var y: Vector3 = b-center
	# Limit this pilot to the existing slab, away from the asphalt and
	# intersection corners. Explicit bent/crosswalk links are future work.
	for p in [x,y]:
		if absf(p.x)>20.0 or absf(p.z)>20.0:
			return false
	if absf(x.x-y.x)<0.01 and absf(x.x)>=18.0:
		return absf(x.z)<=15.0 and absf(y.z)<=15.0
	if absf(x.z-y.z)<0.01 and absf(x.z)>=18.0:
		return absf(x.x)<=15.0 and absf(y.x)<=15.0
	return false

func _loaded(city: Node, at: Vector3) -> bool:
	var cell := Vector2i(floori(at.x/Plan.BLOCK_SIZE),floori(at.z/Plan.BLOCK_SIZE))
	return cell in city.call("get_loaded_blocks")

static func _key(entry: Dictionary) -> String:
	return "%s:%s:%s" % [str(entry["id"]),str(entry["start"]),str(entry["end"])]

func cached_clear(city: Node, entry: Dictionary) -> bool:
	if not _reset_epoch(city) or not _valid_link(entry) or not _loaded(city,entry["start"]):
		return false
	var item: Dictionary = _cache.get(_key(entry),{})
	return not item.is_empty() and int(item["until"])>=Engine.get_physics_frames() and int(item["status"])==CLEAR

func _finish(key: String, status: int) -> int:
	if _cache.size()>=MAX_CACHE:
		_cache.erase(_cache.keys()[0])
	_cache[key] = {"status":status,"until":Engine.get_physics_frames()+VALID_TICKS}
	_job.clear()
	return status

func evaluate(city: Node, space: PhysicsDirectSpaceState3D, entry: Dictionary) -> int:
	if not _reset_epoch(city) or space==null or not _valid_link(entry) or not _loaded(city,entry["start"]):
		return BLOCKED
	var key := _key(entry)
	var frame := Engine.get_physics_frames()
	var cached: Dictionary = _cache.get(key,{})
	if not cached.is_empty() and int(cached["until"])>=frame:
		return int(cached["status"])
	if _last_frame==frame:
		return PENDING
	_last_frame = frame
	var a: Vector3 = entry["start"]
	var b: Vector3 = entry["end"]
	if _job.get("key","")!=key:
		_job = {"key":key,"index":0,"samples":ceili(a.distance_to(b)/SAMPLE_SPACING)+1,"floor":0.0,"lowest":INF}
	var count: int = _job["samples"]
	var start: int = _job["index"]
	# Incrementally probe support along the complete link, not just endpoints.
	for i in range(start,mini(count,start+MAX_PROBES_PER_TICK)):
		var at := a.lerp(b,float(i)/float(count-1))
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.4,at-Vector3.UP*0.75,1)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not hit.get("collider") is StaticBody3D or (hit["normal"] as Vector3).y<0.8:
			return _finish(key,BLOCKED)
		var floor_y: float = (hit["position"] as Vector3).y
		if absf(floor_y-at.y)>0.45 or (i>0 and absf(floor_y-float(_job["floor"]))>0.12):
			return _finish(key,BLOCKED)
		_job["lowest"] = minf(float(_job["lowest"]),floor_y)
		_job["floor"] = floor_y
		_job["index"] = i+1
	if int(_job["index"])<count:
		return PENDING
	# A conservative continuous capsule sweep along the nominal sidewalk,
	# with explicit endpoint overlap checks (cast_motion ignores initial overlaps).
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var offset := Vector3.UP*(HEIGHT*0.5+0.04+float(_job["lowest"])-a.y)
	query.transform = Transform3D(Basis.IDENTITY,a+offset)
	if not space.intersect_shape(query,1).is_empty():
		return _finish(key,BLOCKED)
	query.motion = b-a
	var fractions := space.cast_motion(query)
	if fractions.size()!=2 or fractions[0]<0.999:
		return _finish(key,BLOCKED)
	query.motion = Vector3.ZERO
	query.transform = Transform3D(Basis.IDENTITY,b+offset)
	if not space.intersect_shape(query,1).is_empty():
		return _finish(key,BLOCKED)
	return _finish(key,CLEAR)

## Advance at most one uncached candidate per physics tick. The caller supplies
## currently relevant links in priority order (e.g. nearest first). A pending
## job stays pinned while still relevant, even as the player changes ordering.
## Cached decisions are skipped; callers use cached_clear for spawn permission.
func advance_candidates(city: Node, space: PhysicsDirectSpaceState3D, entries: Array[Dictionary]) -> Dictionary:
	if not _reset_epoch(city) or space==null or _last_frame==Engine.get_physics_frames():
		return {}
	var chosen: Dictionary = {}
	var pending_key: String = _job.get("key","")
	var frame := Engine.get_physics_frames()
	# The caller supplies a bounded local candidate list, never the entire city.
	for i in range(mini(entries.size(),MAX_CACHE)):
		var entry: Dictionary = entries[i]
		if not _valid_link(entry) or not _loaded(city,entry["start"]):
			continue
		var key := _key(entry)
		if key==pending_key:
			chosen = entry
			break
		var item: Dictionary = _cache.get(key,{})
		if chosen.is_empty() and (item.is_empty() or int(item["until"])<frame):
			chosen = entry
	# If the player moved away or the route vanished, abandon that partial
	# certificate rather than spending ticks validating an irrelevant parcel.
	if chosen.is_empty():
		_job.clear()
		return {}
	var state := evaluate(city,space,chosen)
	return {"id":chosen["id"],"status":state}
