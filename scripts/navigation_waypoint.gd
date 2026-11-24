extends RefCounted
## Optional player waypoint; no pathfinding, teleport, gameplay or save-version changes.
const WorldPlan = preload("res://scripts/world_plan.gd")
const LIMIT = WorldPlan.GRID_RADIUS * WorldPlan.BLOCK_SIZE
const COLOR = Color("c9a8ff")
const CLOSURE_COLOR = Color("ff997b")

static func closure_segment(record: Dictionary) -> PackedVector2Array:
	# Registry endpoints are intersection indices, not world metres.
	if not record.get("a") is Vector2i or not record.get("b") is Vector2i:
		return PackedVector2Array()
	var a: Vector2i = record["a"]
	var b: Vector2i = record["b"]
	if absi(a.x-b.x)+absi(a.y-b.y) != 1:
		return PackedVector2Array()
	var start := Vector2(a) * WorldPlan.BLOCK_SIZE
	var end := Vector2(b) * WorldPlan.BLOCK_SIZE
	if not valid(start) or not valid(end):
		return PackedVector2Array()
	return PackedVector2Array([start,end])
const SNAP_RADIUS = 10.0

static func valid(point: Vector2) -> bool:
	return point.is_finite() and absf(point.x) <= LIMIT and absf(point.y) <= LIMIT

static func clamp_point(point: Vector2) -> Vector2:
	return point.clamp(Vector2(-LIMIT, -LIMIT), Vector2(LIMIT, LIMIT))

static func decode(value: Variant) -> Variant:
	# Optional v1 save field; bad/missing values simply mean no waypoint.
	if not value is Array or value.size() != 2:
		return null
	for component in value:
		if not (component is int or component is float):
			return null
	var point := Vector2(float(value[0]), float(value[1]))
	return point if valid(point) else null

static func bearing(from: Vector2, to: Vector2) -> String:
	var d := to - from
	if d.length() < 3.0:
		return "ARRIVED"
	# +X east and -Z north. Map coordinates are X/Z, not X/Y world height.
	var index := posmod(roundi(atan2(d.x, -d.y) / (PI / 4.0)), 8)
	return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][index]
