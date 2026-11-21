extends RefCounted
## The authored street network is a connected, bidirectional 9x9 orthogonal
## grid. Every road centreline uses the same WorldPlan spacing and bounds.
## No navmesh, scene search, physics query, lane autonomy or world mutation.
const Plan = preload("res://scripts/world_plan.gd")
const Nav = preload("res://scripts/navigation_waypoint.gd")
const STEP = Plan.BLOCK_SIZE
const LIMIT = STEP * Plan.GRID_RADIUS
const EPS = 0.02

static func road_anchor(point: Vector2) -> Vector2:
	var p := point.clamp(Vector2(-LIMIT, -LIMIT), Vector2(LIMIT, LIMIT))
	var x := roundf(p.x / STEP) * STEP
	var z := roundf(p.y / STEP) * STEP
	if absf(p.x - x) < EPS and absf(p.y - z) < EPS:
		return Vector2(x, z)
	return Vector2(p.x, z) if absf(p.y - z) <= absf(p.x - x) else Vector2(x, p.y)

static func _on_grid(value: float) -> bool:
	return absf(value - roundf(value / STEP) * STEP) < EPS

static func _endpoints(p: Vector2) -> Array[Vector2]:
	if _on_grid(p.x) and _on_grid(p.y):
		return [p]
	if _on_grid(p.y):
		return [Vector2(floorf(p.x / STEP) * STEP, p.y), Vector2(ceilf(p.x / STEP) * STEP, p.y)]
	return [Vector2(p.x, floorf(p.y / STEP) * STEP), Vector2(p.x, ceilf(p.y / STEP) * STEP)]

static func _push(path: Array[Vector2], point: Vector2) -> void:
	if path.is_empty():
		path.append(point)
		return
	if path[-1].distance_to(point) < EPS:
		return
	if path.size() >= 2:
		var previous := (path[-1] - path[-2]).normalized()
		var next := (point - path[-1]).normalized()
		if previous.dot(next) > 0.999:
			path[-1] = point
			return
	path.append(point)

static func length_of(path: Array[Vector2]) -> float:
	var meters := 0.0
	for i in range(1, path.size()):
		meters += path[i - 1].distance_to(path[i])
	return meters

static func plan(origin: Vector2, target: Vector2) -> Dictionary:
	if not origin.is_finite() or not target.is_finite():
		return {}
	var entry := road_anchor(origin)
	var exit := road_anchor(target)
	var best: Array[Vector2] = []
	var cost := INF
	# Same-road shortcuts are safe only when the shared coordinate is a
	# real road axis, not just two points that happen to share X or Z.
	if (is_equal_approx(entry.x, exit.x) and _on_grid(entry.x)) or (is_equal_approx(entry.y, exit.y) and _on_grid(entry.y)):
		_push(best, entry)
		_push(best, exit)
		cost = length_of(best)
	# Each projected point lies on a road edge. Enumerate both endpoint
	# choices and the two shortest Manhattan corner orders. Fewer turns
	# break exact length ties; iteration order makes the result stable.
	for a in _endpoints(entry):
		for b in _endpoints(exit):
			for corner in [Vector2(b.x, a.y), Vector2(a.x, b.y)]:
				var candidate: Array[Vector2] = []
				_push(candidate, entry)
				_push(candidate, a)
				_push(candidate, corner)
				_push(candidate, b)
				_push(candidate, exit)
				var score := length_of(candidate) + 0.01 * float(maxi(0, candidate.size() - 2))
				if score < cost - 0.0001:
					cost = score
					best = candidate
	return {"points": best, "entry": entry, "exit": exit, "road_m": length_of(best),
		"access_m": origin.distance_to(entry), "last_m": exit.distance_to(target)}

static func guidance(route: Dictionary, origin: Vector2, target: Vector2) -> String:
	if route.is_empty():
		return "Route unavailable"
	if origin.distance_to(target) <= 6.0:
		return "WAYPOINT NEARBY"
	var entry: Vector2 = route["entry"]
	if origin.distance_to(entry) > 8.0:
		return "Reach street • %dm %s" % [roundi(origin.distance_to(entry)), Nav.bearing(origin, entry)]
	var points: Array[Vector2] = route["points"]
	if points.size() < 2 or float(route["road_m"]) < 4.0:
		var exit: Vector2 = route["exit"]
		return "At nearest street • destination %dm %s" % [roundi(exit.distance_to(target)), Nav.bearing(exit, target)]
	var first := 1
	# Ignore a sub-three-metre initial leg near an intersection rather than
	# flashing an imminent turn while the actor is already crossing it.
	if points.size() > 2 and points[0].distance_to(points[1]) < 3.0:
		first = 2
	var start := points[first - 1]
	var end := points[first]
	var heading := Nav.bearing(start, end)
	if first + 1 < points.size():
		var approach := (end - start).normalized()
		var departure := (points[first + 1] - end).normalized()
		# Map positive Y is south; a positive 2D cross product turns right.
		var cross := approach.cross(departure)
		var turn := "TURN RIGHT" if cross > 0.0 else "TURN LEFT"
		if absf(cross) < 0.5:
			turn = "CONTINUE" if approach.dot(departure) > 0.0 else "TURN AROUND"
		return "%s • %s IN %dm" % [heading, turn, roundi(start.distance_to(end))]
	return "%s • %dm TO FINAL STREET" % [heading, roundi(start.distance_to(end))]
