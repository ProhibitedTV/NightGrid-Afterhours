extends RefCounted
## Conservative advisory gate for fictional civic road works.
## Does not add a restriction, modify traffic or create barriers.
const Restrictions = preload("res://scripts/road_restrictions.gd")
const Route = preload("res://scripts/street_route.gd")
const LANE_OFFSET = 3.25
const OCCUPIED_RADIUS = 14.0
const EPS = 0.05

static func route_edges(path: Array) -> Dictionary:
	# Current authored transit loops have lane-shifted corner nodes and
	# axis-aligned legs. Recover the intersection indices from each corner.
	# Reject unexpected path geometry rather than assuming transit access.
	var edges := {}
	if path.size()<3 or path.size()>128:
		return {}
	var corners: Array[Vector2i] = []
	for point in path:
		if not point is Vector3 or not point.is_finite():
			return {}
		var p: Vector3 = point
		var grid := Vector2i(roundi(p.x/Route.STEP),roundi(p.z/Route.STEP))
		if not Restrictions._valid_node(grid) or absf(p.x-grid.x*Route.STEP)>LANE_OFFSET+EPS or absf(p.z-grid.y*Route.STEP)>LANE_OFFSET+EPS:
			return {}
		corners.append(grid)
	for i in range(corners.size()):
		var at := corners[i]
		var goal := corners[(i+1)%corners.size()]
		var span := goal-at
		if (span.x!=0 and span.y!=0) or span==Vector2i.ZERO:
			return {}
		var step := Vector2i(signi(span.x),signi(span.y))
		while at!=goal:
			var next := at+step
			var key := Restrictions.edge_key(at,next)
			if key.is_empty():
				return {}
			edges[key] = true
			at = next
	return edges

static func evaluate(a: Vector2i,b: Vector2i,transit_routes: Array,occupied: Array[Vector3]) -> String:
	var key := Restrictions.edge_key(a,b)
	if key.is_empty():
		return "INVALID_EDGE"
	if transit_routes.is_empty():
		return "TRANSIT_UNKNOWN"
	for route in transit_routes:
		if not route is Array:
			return "TRANSIT_UNKNOWN"
		var edges := route_edges(route)
		if edges.is_empty():
			return "TRANSIT_UNKNOWN"
		if edges.has(key):
			return "TRANSIT_PROTECTED"
	var start := Vector2(a)*Route.STEP
	var end := Vector2(b)*Route.STEP
	var axis := end-start
	for p in occupied:
		if not p.is_finite():
			return "OCCUPANCY_UNKNOWN"
		var point := Vector2(p.x,p.z)
		var t := clampf((point-start).dot(axis)/axis.length_squared(),0.0,1.0)
		if point.distance_to(start+axis*t)<=OCCUPIED_RADIUS:
			return "OCCUPIED"
	# Advisory only. Actual publication must also verify scene clearance,
	# entry traffic, critical services, graph connectivity and detour plans.
	return "ELIGIBLE"
