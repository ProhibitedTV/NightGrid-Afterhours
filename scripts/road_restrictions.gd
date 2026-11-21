extends RefCounted
## Optional fictional civic street restrictions. Grid indices identify whole
## bidirectional street edges; no scene nodes or player wanted interactions.
const Route = preload("res://scripts/street_route.gd")
const Plan = preload("res://scripts/world_plan.gd")
const RADIUS = Plan.GRID_RADIUS
const MAX_RESTRICTIONS = 4
const MAX_DURATION = 180.0
const DIRECTIONS = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var _closed: Dictionary = {}
var revision := 0

static func _valid_node(p: Vector2i) -> bool:
	return absi(p.x) <= RADIUS and absi(p.y) <= RADIUS

static func edge_key(a: Vector2i, b: Vector2i) -> String:
	if not _valid_node(a) or not _valid_node(b) or absi(a.x-b.x) + absi(a.y-b.y) != 1:
		return ""
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var tmp := a
		a = b
		b = tmp
	return "%d,%d:%d,%d" % [a.x, a.y, b.x, b.y]

func add(a: Vector2i, b: Vector2i, owner: String, reason: String, duration: float) -> bool:
	var key := edge_key(a,b)
	if key.is_empty() or _closed.has(key) or _closed.size() >= MAX_RESTRICTIONS or owner.strip_edges().is_empty() or reason.strip_edges().is_empty():
		return false
	if not is_finite(duration) or duration <= 0.0 or duration > MAX_DURATION:
		return false
	_closed[key] = {"a":a, "b":b, "owner":owner, "reason":reason, "remaining":duration}
	# Conservatively keep every intersection connected, including boundary
	# junctions. Reject a transaction that would isolate a neighborhood.
	if _traverse(Vector2i.ZERO).size() != (2 * RADIUS + 1) * (2 * RADIUS + 1):
		_closed.erase(key)
		return false
	revision += 1
	return true

func advance(minutes: float) -> void:
	if not is_finite(minutes) or minutes <= 0.0:
		return
	for key in _closed.keys():
		var item: Dictionary = _closed[key]
		item["remaining"] = float(item["remaining"]) - minutes
		if float(item["remaining"]) <= 0.0:
			_closed.erase(key)
			revision += 1

func catalog() -> Dictionary:
	return _closed.duplicate(true)

func is_closed(a: Vector2i, b: Vector2i) -> bool:
	return _closed.has(edge_key(a,b))

func _traverse(start: Vector2i) -> Dictionary:
	var parent: Dictionary = {start:start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var at := queue[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next: Vector2i = at + direction
			if not _valid_node(next) or parent.has(next) or is_closed(at,next):
				continue
			parent[next] = at
			queue.append(next)
	return parent

static func _index(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / Route.STEP), roundi(p.y / Route.STEP))

static func _world(p: Vector2i) -> Vector2:
	return Vector2(p) * Route.STEP

func _accessible(p: Vector2) -> Array[Vector2]:
	var ends: Array[Vector2] = Route._endpoints(p)
	if ends.size() == 2 and is_closed(_index(ends[0]), _index(ends[1])):
		# A destination inside a closed segment is unavailable. The live
		# traffic integration must handle occupied edges before closing them.
		return []
	return ends

func plan(origin: Vector2, target: Vector2) -> Dictionary:
	if _closed.is_empty():
		return Route.plan(origin,target)
	if not origin.is_finite() or not target.is_finite():
		return {}
	var entry: Vector2 = Route.road_anchor(origin)
	var exit: Vector2 = Route.road_anchor(target)
	var starts := _accessible(entry)
	var ends := _accessible(exit)
	if starts.is_empty() or ends.is_empty():
		return {}
	var best: Array[Vector2] = []
	var cost := INF
	# Preserve a direct path within one open edge.
	if starts.size() == 2 and starts == ends:
		best = [entry]
		Route._push(best,exit)
		cost = Route.length_of(best)
	for a in starts:
		var start := _index(a)
		var parents := _traverse(start)
		for b in ends:
			var goal := _index(b)
			if not parents.has(goal):
				continue
			var reverse: Array[Vector2i] = [goal]
			var cursor := goal
			while cursor != start:
				cursor = parents[cursor]
				reverse.append(cursor)
			reverse.reverse()
			var path: Array[Vector2] = []
			Route._push(path,entry)
			for node in reverse:
				Route._push(path,_world(node))
			Route._push(path,exit)
			var distance := Route.length_of(path)
			if distance < cost - 0.0001:
				best = path
				cost = distance
	if best.is_empty():
		return {}
	return {"points":best,"entry":entry,"exit":exit,"road_m":cost,
		"access_m":origin.distance_to(entry),"last_m":exit.distance_to(target)}
