extends RefCounted
## Pure data sidewalk population. Candidate paths use parcel geometry but
## are not certified walkable until the live scene validates each segment.
## No physical bodies, witnesses, player tracking or scene changes here.
const Plan = preload("res://scripts/world_plan.gd")
const MAX_LOGICAL = 128
const MAX_ACTIVE = 12
const MAX_CHANGES = 2
const SIDE_OFFSET = 19.3
const HALF_SPAN = 13.0
const MIN_DISTANCE = 35.0
const LOAD_DISTANCE = 95.0
const UNLOAD_DISTANCE = 120.0
const MIN_SEPARATION = 2.0
var _agents: Dictionary = {}
var _routes: Dictionary = {}

static func block_candidates(ix: int, iz: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not Plan.is_valid_block(ix, iz):
		return result
	var center := Vector3((float(ix)+0.5)*Plan.BLOCK_SIZE,0.3,(float(iz)+0.5)*Plan.BLOCK_SIZE)
	for side in range(4):
		var normal: Vector3 = [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT][side]
		var across := Vector3(-normal.z,0,normal.x)
		var mid := center+normal*SIDE_OFFSET
		result.append({"id":"%d,%d:%d" % [ix,iz,side],"district":Plan.district_at(center),
			"start":mid-across*HALF_SPAN,"end":mid+across*HALF_SPAN})
	return result

static func balanced_links(links: Array[Dictionary]) -> Array[Dictionary]:
	# Round-robin by district prevents the global population cap
	# from exhausting the west side of the map before reaching the east.
	var groups := {}
	var sorted := links.duplicate()
	sorted.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a.get("id","")) < str(b.get("id","")))
	for link in sorted:
		var district := str(link.get("district",""))
		if not groups.has(district):
			groups[district] = []
		groups[district].append(link)
	var districts := groups.keys()
	districts.sort()
	var result: Array[Dictionary] = []
	var row := 0
	while result.size()<links.size():
		var added := false
		for district in districts:
			var group: Array = groups[district]
			# One candidate per district on each pass.
			if row<group.size():
				result.append(group[row])
				added = true
		if not added:
			break
		row += 1
	return result

func configure(seed_value: int, links: Array[Dictionary]) -> void:
	_agents.clear()
	_routes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 615213
	for link in balanced_links(links):
		if _agents.size() >= MAX_LOGICAL:
			break
		var id := str(link.get("id",""))
		var a: Variant = link.get("start")
		var b: Variant = link.get("end")
		if id.is_empty() or _routes.has(id) or not a is Vector3 or not b is Vector3 or not a.is_finite() or not b.is_finite() or a.distance_to(b)<1.0:
			continue
		_routes[id] = link.duplicate(true)
		_agents[id] = {"phase":rng.randf(),"speed":rng.randf_range(0.9,1.45),"style":rng.randi_range(0,5)}

func ids() -> Array:
	return _agents.keys()

func sample(id: String) -> Dictionary:
	if not _agents.has(id):
		return {}
	var agent: Dictionary = _agents[id]
	var route: Dictionary = _routes[id]
	var a: Vector3 = route["start"]
	var b: Vector3 = route["end"]
	var phase: float = agent["phase"]
	# Out-and-back on one link; never crosses the road or jumps between lots.
	var t := 1.0-absf(phase*2.0-1.0)
	return {"id":id,"position":a.lerp(b,t),"heading":(b-a).normalized()*(1.0 if phase<0.5 else -1.0),
		"style":agent["style"],"speed":agent["speed"],"district":route.get("district",""),
		"start":a,"end":b}

func advance(seconds: float, active_ids: Array) -> void:
	if not is_finite(seconds) or seconds<=0.0:
		return
	var active := {}
	for id in active_ids:
		active[id] = true
	for id in _agents:
		if active.has(id):
			continue
		var agent: Dictionary = _agents[id]
		var route: Dictionary = _routes[id]
		var length: float = route["start"].distance_to(route["end"])*2.0
		var period := length/float(agent["speed"])
		agent["phase"] = fposmod(float(agent["phase"])+fposmod(seconds,period)/period,1.0)

func capture_live(id: String, position: Vector3, heading: Vector3) -> bool:
	if not _agents.has(id) or not position.is_finite() or not heading.is_finite():
		return false
	var route: Dictionary = _routes[id]
	var a: Vector3 = route["start"]
	var b: Vector3 = route["end"]
	var axis := b-a
	var t := clampf((position-a).dot(axis)/axis.length_squared(),0.0,1.0)
	if position.distance_to(a+axis*t)>1.0 or heading.length_squared()<0.01:
		return false
	_agents[id]["phase"] = fposmod(t*0.5 if heading.dot(axis)>=0.0 else 1.0-t*0.5,1.0)
	return true

func snapshot() -> Dictionary:
	var phases := {}
	for id in _agents:
		phases[id] = _agents[id]["phase"]
	return {"phases":phases}

func restore(value: Variant) -> void:
	if not value is Dictionary or not value.get("phases") is Dictionary:
		return
	var phases: Dictionary = value["phases"]
	for id in _agents:
		var phase: Variant = phases.get(id)
		if (phase is float or phase is int) and is_finite(float(phase)) and float(phase)>=0.0 and float(phase)<1.0:
			_agents[id]["phase"] = float(phase)

func plan_changes(focus: Vector3, camera: Vector3, indoors: bool, active: Dictionary,
		occupied: Array[Vector3], can_walk_and_spawn: Callable, can_hide: Callable) -> Dictionary:
	var result := {"activate":[],"recycle":[]}
	if indoors or not focus.is_finite() or not camera.is_finite() or not can_walk_and_spawn.is_valid() or not can_hide.is_valid():
		return result
	for id in active:
		var at: Variant = active[id]
		if _agents.has(id) and at is Vector3 and at.is_finite() and at.distance_to(focus)>=UNLOAD_DISTANCE and at.distance_to(camera)>=UNLOAD_DISTANCE and bool(can_hide.call(at)):
			result["recycle"].append(id)
			if result["recycle"].size()>=MAX_CHANGES:
				return result
	var remaining := maxi(0,MAX_ACTIVE-active.size()+result["recycle"].size())
	var candidates: Array[Dictionary] = []
	for id in _agents:
		if active.has(id):
			continue
		var entry := sample(id)
		var at: Vector3 = entry["position"]
		var distance := at.distance_to(focus)
		if distance<MIN_DISTANCE or distance>LOAD_DISTANCE or at.distance_to(camera)<MIN_DISTANCE:
			continue
		entry["distance"] = distance
		candidates.append(entry)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if is_equal_approx(float(a["distance"]),float(b["distance"])):
			return str(a["id"])<str(b["id"])
		return float(a["distance"])<float(b["distance"]))
	var reserved := occupied.duplicate()
	for at in active.values():
		if at is Vector3 and at.is_finite():
			reserved.append(at)
	for entry in candidates:
		if remaining<=0 or result["activate"].size()+result["recycle"].size()>=MAX_CHANGES:
			break
		var at: Vector3 = entry["position"]
		var clear := true
		for other in reserved:
			if at.distance_to(other)<MIN_SEPARATION:
				clear = false
				break
		# Required callback certifies the WHOLE link, loaded ground, clearance,
		# and camera visibility. A sample alone is never a walkable route.
		if not clear or not bool(can_walk_and_spawn.call(entry)):
			continue
		result["activate"].append(entry)
		reserved.append(at)
		remaining -= 1
	return result
