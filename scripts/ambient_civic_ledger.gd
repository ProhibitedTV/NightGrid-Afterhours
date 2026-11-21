extends RefCounted
## Independent, deterministic simulated civic calls. No scene nodes, player
## incidents, heat, dispatch history, or response-fleet mutation.
const INTERVAL_MINUTES = 20
const QUEUED_MINUTES = 5
const ACTIVE_END_MINUTES = 18
const RETAIN_MINUTES = 40
const MAX_CASES = 2
const MAX_MINUTE = 100000000
const KINDS = ["MOTORIST ASSISTANCE", "TRAFFIC SERVICE", "PUBLIC SERVICE REQUEST"]
var _seed := 1
var _minute := 0
var _fraction := 0.0
var _sites: Array[Dictionary] = []
var _cases: Array[Dictionary] = []

func configure(seed_value: int, sites: Array[Dictionary]) -> void:
	_seed = seed_value
	_sites.clear()
	for site in sites:
		if str(site.get("site_id", "")).is_empty() or str(site.get("station_id", "")).is_empty() or str(site.get("district", "")).is_empty():
			continue
		var point: Variant = site.get("point")
		if not point is Vector3 or not point.is_finite():
			continue
		_sites.append(site.duplicate(true))
	_sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["site_id"]) < str(b["site_id"]))
	_minute = 0
	_fraction = 0.0
	_rebuild()

func advance(game_minutes: float) -> void:
	if not is_finite(game_minutes) or game_minutes <= 0.0:
		return
	var total := minf(float(MAX_MINUTE), float(_minute) + _fraction + game_minutes)
	var next := int(floor(total + 0.0000001))
	_fraction = maxf(0.0, total - float(next))
	if next != _minute:
		_minute = next
		_rebuild()

func _rebuild() -> void:
	_cases.clear()
	if _sites.is_empty():
		return
	@warning_ignore("integer_division")
	var latest := _minute / INTERVAL_MINUTES
	for slot in range(maxi(1, latest - MAX_CASES + 1), latest + 1):
		var age := _minute - slot * INTERVAL_MINUTES
		if age >= RETAIN_MINUTES:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 1000003 + slot
		var site: Dictionary = _sites[rng.randi_range(0, _sites.size() - 1)]
		var kind: String = KINDS[rng.randi_range(0, KINDS.size() - 1)]
		var state := "QUEUED" if age < QUEUED_MINUTES else ("ACTIVE" if age < ACTIVE_END_MINUTES else "RESOLVED")
		_cases.append({"id": "CIV-%06d" % slot, "kind": kind, "state": state,
			"site_id":site["site_id"], "station_id":site["station_id"], "district":site["district"],
			"point":site["point"], "created_minute":slot * INTERVAL_MINUTES})

func catalog() -> Array[Dictionary]:
	return _cases.duplicate(true)

func open_count() -> int:
	var count := 0
	for incident in _cases:
		if incident["state"] != "RESOLVED":
			count += 1
	return count

func snapshot() -> Dictionary:
	# Cases reconstruct from stable seed, sorted authored sites and this clock.
	return {"minute":_minute, "fraction":_fraction}

func restore(value: Variant) -> void:
	_minute = 0
	_fraction = 0.0
	if value is Dictionary:
		var minute: Variant = value.get("minute", 0)
		var fraction: Variant = value.get("fraction", 0.0)
		if (minute is int or minute is float) and (fraction is int or fraction is float):
			if is_finite(float(minute)) and is_finite(float(fraction)) and float(minute) >= 0.0 and float(minute) <= MAX_MINUTE and float(fraction) >= 0.0 and float(fraction) < 1.0:
				_minute = int(minute)
				_fraction = float(fraction)
	_rebuild()
