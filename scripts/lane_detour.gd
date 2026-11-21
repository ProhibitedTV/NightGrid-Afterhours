extends RefCounted
## Finite lane-aligned detour between junctions for future civilian routing.
## Does not replace current looping vehicle routes or issue movement orders.
const Street = preload("res://scripts/street_route.gd")
const Restrictions = preload("res://scripts/road_restrictions.gd")
const OFFSET = 3.25
const EPS = 0.02
const MAX_POINTS = 81

static func _junction(p: Vector2) -> bool:
	return p.is_finite() and absf(p.x)<=Street.LIMIT and absf(p.y)<=Street.LIMIT and Street._on_grid(p.x) and Street._on_grid(p.y)

static func _right(direction: Vector2) -> Vector2:
	return Vector2(-direction.y,direction.x)*OFFSET

static func from_centerline(points: Array[Vector2],level: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if points.size()<2 or points.size()>MAX_POINTS or not is_finite(level) or level<0.0 or level>3.0:
		return result
	var directions: Array[Vector2] = []
	for point in points:
		if not _junction(point):
			return []
	for i in range(1,points.size()):
		var delta := points[i]-points[i-1]
		if delta.length()<Street.STEP-EPS or (absf(delta.x)>EPS and absf(delta.y)>EPS):
			return []
		directions.append(delta.normalized())
	for i in range(points.size()):
		var offset: Vector2
		if i==0:
			offset = _right(directions[0])
		elif i==points.size()-1:
			offset = _right(directions[-1])
		else:
			var before := directions[i-1]
			var after := directions[i]
			if before.dot(after)<-0.5:
				return [] # no U-turn geometry in this pilot
			offset = _right(before) if before.dot(after)>0.5 else _right(before)+_right(after)
		var at := points[i]+offset
		# Do not place exterior-boundary lanes outside the known road envelope.
		if absf(at.x)>Street.LIMIT or absf(at.y)>Street.LIMIT:
			return []
		result.append(Vector3(at.x,level,at.y))
		if i>0:
			var leg := result[i]-result[i-1]
			var expected := Vector3(directions[i-1].x,0,directions[i-1].y)
			if leg.dot(expected)<Street.STEP-2.0*OFFSET-EPS or leg.normalized().dot(expected)<0.999:
				return []
	return result

static func plan(registry: RefCounted,start: Vector2i,goal: Vector2i,level: float=1.0) -> Array[Vector3]:
	if registry==null or not registry.has_method("plan") or not registry.has_method("is_closed") or start==goal or not Restrictions._valid_node(start) or not Restrictions._valid_node(goal):
		return []
	var route: Dictionary = registry.call("plan",Vector2(start)*Street.STEP,Vector2(goal)*Street.STEP)
	if route.is_empty():
		return []
	var points: Array[Vector2] = route["points"]
	if points.is_empty() or points[0]!=Vector2(start)*Street.STEP or points[-1]!=Vector2(goal)*Street.STEP:
		return []
	var lanes := from_centerline(points,level)
	if lanes.is_empty():
		return []
	# Validate every individual edge, even if the centerline compressed
	# multiple straight blocks into one leg.
	for i in range(1,points.size()):
		var at := Vector2i(roundi(points[i-1].x/Street.STEP),roundi(points[i-1].y/Street.STEP))
		var end := Vector2i(roundi(points[i].x/Street.STEP),roundi(points[i].y/Street.STEP))
		var span := end-at
		var step := Vector2i(signi(span.x),signi(span.y))
		while at!=end:
			var next := at+step
			if bool(registry.call("is_closed",at,next)):
				return []
			at = next
	return lanes
