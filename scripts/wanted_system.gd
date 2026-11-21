extends RefCounted
## Arcade wanted-level rules. Fixed-tick timers, bounded sight queries and
## game-world-only awareness. Heat remains the world's legacy saved scalar.
const SIGHT_INTERVAL = 0.20
const MAX_HEAT = 5.0
const MIN_HEAT = 0.15
const BRANDISH_TIME = 0.8
const BRANDISH_REPEAT = 3.0
const QUIET_DELAY = 8.0
const CIVILIAN_RANGE = 26.0
const POLICE_RANGE = 42.0
const MAX_RAYS = 12
var last_known := Vector3.INF
var seen := false
var police_seen := false
var quiet := 0.0
var exposure := 0.0
var report_cooldown := 0.0
var last_reason := ""
var last_ray_count := 0

static func stars(heat: float) -> int:
	return 0 if heat < MIN_HEAT else clampi(ceili(heat), 1, 5)

static func reinforcement_delay(heat: float) -> float:
	return [12.0, 9.0, 7.0, 5.0, 3.5][maxi(0, stars(heat) - 1)]

static func report_heat(heat: float, reason: String, officer: bool) -> float:
	match reason:
		"BRANDISH":
			return minf(MAX_HEAT, maxf(1.0, heat + (0.28 if officer else 0.18)))
		"THEFT":
			return minf(MAX_HEAT, maxf(1.0, heat + (1.0 if officer else 0.65)))
		"SHOT":
			return minf(MAX_HEAT, maxf(1.0, heat + (0.65 if officer else 0.45)))
	return heat

func report(heat: float, reason: String, where: Vector3, officer: bool) -> float:
	if not where.is_finite():
		return heat
	last_known = where
	last_reason = reason
	quiet = 0.0
	return report_heat(heat, reason, officer)

func observe(heat: float, where: Vector3, witness: Dictionary, drawn: bool, delta: float) -> float:
	seen = bool(witness.get("any", false))
	police_seen = bool(witness.get("police", false))
	report_cooldown = maxf(0.0, report_cooldown - delta)
	if drawn and seen:
		exposure += delta
		if exposure >= BRANDISH_TIME and report_cooldown <= 0.0:
			heat = report(heat, "BRANDISH", where, police_seen)
			report_cooldown = BRANDISH_REPEAT
	else:
		exposure = 0.0
	# An officer with actual sight can update the last observed position.
	# Ordinary civilian presence alone does not track a holstered player.
	if stars(heat) > 0 and police_seen:
		last_known = where
		quiet = 0.0
	return heat

func decay(heat: float, delta: float) -> float:
	if stars(heat) == 0:
		quiet = 0.0
		last_known = Vector3.INF
		last_reason = ""
		return 0.0
	if police_seen or (seen and exposure > 0.0):
		quiet = 0.0
	else:
		quiet += delta
		if quiet >= QUIET_DELAY:
			heat = maxf(0.0, heat - delta * 0.10)
	return heat

func status_text(heat: float) -> String:
	if stars(heat) == 0:
		return "WEAPON NOTICED" if seen and exposure > 0.0 else "CLEAR"
	if police_seen:
		return "IN SIGHT"
	if quiet >= QUIET_DELAY:
		return "COOLING DOWN"
	return "SEARCHING"

func reset() -> void:
	last_known = Vector3.INF
	seen = false
	police_seen = false
	quiet = 0.0
	exposure = 0.0
	report_cooldown = 0.0
	last_reason = ""

static func in_view(eye: Vector3, facing: Vector3, target: Vector3, reach: float) -> bool:
	var gap := target - eye
	if gap.length_squared() > reach * reach:
		return false
	var planar := Vector3(gap.x, 0, gap.z)
	var heading := Vector3(facing.x, 0, facing.z)
	# Broad arcade attention cone; very close activity is noticeable.
	return planar.length_squared() < 9.0 or (heading.length_squared() > 0.001 and heading.normalized().dot(planar.normalized()) >= 0.1)

func witnesses(space: PhysicsDirectSpaceState3D, target: Vector3, candidates: Array[Dictionary], ignored: Array[RID]) -> Dictionary:
	var nearby: Array[Dictionary] = []
	for entry in candidates:
		var eye: Vector3 = entry["eye"]
		var police: bool = entry["police"]
		if in_view(eye, entry["facing"], target, POLICE_RANGE if police else CIVILIAN_RANGE):
			var candidate := entry.duplicate()
			candidate["distance"] = eye.distance_squared_to(target)
			nearby.append(candidate)
	# Prioritize officers, then distance. Fixed upper bound regardless of
	# future city population size; no per-frame raycast for all world NPCs.
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["police"] != b["police"]:
			return bool(a["police"])
		return float(a["distance"]) < float(b["distance"]))
	var result := {"any": false, "police": false}
	last_ray_count = 0
	for entry in nearby:
		if last_ray_count >= MAX_RAYS:
			break
		var exclude: Array[RID] = ignored.duplicate()
		var body: Variant = entry.get("rid")
		if body is RID:
			exclude.append(body)
		var ray := PhysicsRayQueryParameters3D.create(entry["eye"], target, 1, exclude)
		ray.collide_with_areas = false
		last_ray_count += 1
		if space.intersect_ray(ray).is_empty():
			result["any"] = true
			if bool(entry["police"]):
				result["police"] = true
				break
			# Officers were checked first, so the first visible civilian ends
			# this bounded query as well.
			break
	return result
