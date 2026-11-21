extends RefCounted
## Fictional NPC driving policy, inspired by public safe-driving principles.
## All distances, speed caps and priority values are game balancing constants.
const Street = preload("res://scripts/street_route.gd")
const LANE = 3.25
const ROUTINE_SPEED = 9.0
const RESPONSE_SPEED = 13.0
const CORNER_SPEED = 5.5
const REFRESH = 0.12

var path: Array[Vector2] = []
var index := 0
var destination := Vector2.INF
var refresh_left := 0.0
var cached_clearance := INF

static func _right(d: Vector2) -> Vector2:
	return Vector2(-d.y, d.x) * LANE

static func lane_path(start: Vector2, goal: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var plan := Street.plan(start, goal)
	if plan.is_empty():
		return result
	var points: Array[Vector2] = plan["points"]
	if points.size() == 1:
		result.append(points[0])
		return result
	for i in range(points.size()):
		var incoming := (points[i] - points[i - 1]).normalized() if i > 0 else Vector2.ZERO
		var outgoing := (points[i + 1] - points[i]).normalized() if i + 1 < points.size() else Vector2.ZERO
		var offset := _right(outgoing if i == 0 else incoming)
		if i > 0 and i + 1 < points.size():
			if incoming.dot(outgoing) < -0.9:
				# Keep U-turn geometry within the game intersection.
				result.append(points[i] + _right(incoming))
				result.append(points[i] + _right(outgoing))
				continue
			if absf(incoming.dot(outgoing)) < 0.1:
				offset = _right(incoming) + _right(outgoing)
		result.append(points[i] + offset)
	return result

func next_point(at: Vector2, goal: Vector2) -> Vector2:
	if not goal.is_finite():
		return at
	# Only changed destination / initial plan causes replanning, never a
	# 60 Hz route search. A completed route remains stopped at its endpoint.
	if path.is_empty() or not destination.is_finite() or destination.distance_to(goal) > 9.0:
		path = lane_path(at, goal)
		destination = goal
		index = 0
	if path.is_empty():
		return at
	while index < path.size() - 1 and at.distance_to(path[index]) < 3.0:
		index += 1
	return path[index]

func reset() -> void:
	path.clear()
	index = 0
	destination = Vector2.INF
	cached_clearance = INF
	refresh_left = 0.0

static func safe_speed(priority: bool, distance_to_node: float, turn_error: float, clearance: float, signal_cap: float, night: bool) -> float:
	var cap := RESPONSE_SPEED if priority else ROUTINE_SPEED
	if night:
		cap *= 0.85
	# A conservative speed at all upcoming corners, not a racing line.
	if distance_to_node < 12.0 or absf(turn_error) > 0.30:
		cap = minf(cap, CORNER_SPEED)
	if absf(turn_error) > 0.9:
		cap = minf(cap, 1.4)
	if distance_to_node < 2.0:
		cap = minf(cap, maxf(0.0, distance_to_node - 0.75) * 2.0)
	if is_finite(clearance):
		cap = minf(cap, maxf(0.0, (clearance - 2.0) * 0.8))
	return maxf(0.0, minf(cap, signal_cap))

func clearance(car: CharacterBody3D, delta: float) -> float:
	refresh_left -= delta
	if refresh_left > 0.0:
		return cached_clearance
	refresh_left = REFRESH
	cached_clearance = INF
	var forward := -car.global_basis.z
	var side := car.global_basis.x
	var excluded: Array[RID] = [car.get_rid()]
	# Three short, collision-backed sensing rays include parked cars,
	# street traffic, other officers and city geometry in the actual scene.
	for offset in [-0.85, 0.0, 0.85]:
		var origin := car.global_position + side * float(offset) + forward * 2.25 + Vector3.UP * 0.1
		var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 18.0, 1, excluded)
		query.collide_with_areas = false
		var hit := car.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			cached_clearance = minf(cached_clearance, origin.distance_to(hit["position"]))
	return cached_clearance
