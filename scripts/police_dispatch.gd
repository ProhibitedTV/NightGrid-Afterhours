extends RefCounted
## Fictional city dispatch registry: station IDs are content data, not tied
## to a particular map radius or fixed list of districts. Every station has
## a public address and a marked curb staging point supplied by its site.
const Street = preload("res://scripts/street_route.gd")
const MAX_UNITS = 5
const MAX_HISTORY = 24
var stations: Dictionary = {}
var active: Dictionary = {}
var history: Array[Dictionary] = []
var serial := 0
var sequence := 0

func register_station(id: String, label: String, district: String, address: Vector3, launch: Vector3, capacity: int, headquarters: bool = false) -> bool:
	if id.is_empty() or stations.has(id) or not address.is_finite() or not launch.is_finite() or capacity < 1 or capacity > MAX_UNITS:
		return false
	stations[id] = {"id":id, "name":label, "district":district, "address":address, "launch":launch, "capacity":capacity, "hq":headquarters}
	return true

func catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for station in stations.values():
		result.append(station.duplicate())
	return result

func report(reason: String, point: Vector3, tier: int) -> void:
	if not point.is_finite() or tier < 1:
		return
	if active.is_empty():
		serial += 1
		active = {"id":serial, "reports":0, "point":point, "tier":tier, "reason":reason}
	active["point"] = point
	active["tier"] = clampi(tier, 1, MAX_UNITS)
	active["reason"] = reason
	active["reports"] = int(active["reports"]) + 1
	_event("REPORT", reason)

func update_case(point: Vector3, tier: int) -> void:
	if tier <= 0:
		if not active.is_empty():
			_event("CLOSED", str(active["reason"]))
			active.clear()
	elif point.is_finite():
		if active.is_empty():
			report("EXISTING INCIDENT", point, tier)
		else:
			active["point"] = point
			active["tier"] = clampi(tier, 1, MAX_UNITS)

func _event(kind: String, detail: String) -> void:
	history.append({"event":kind, "detail":detail, "incident":int(active.get("id", 0))})
	if history.size() > MAX_HISTORY:
		history.pop_front()

func ranked(point: Vector3, deployed: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not point.is_finite():
		return result
	for entry in stations.values():
		var id: String = entry["id"]
		if int(deployed.get(id, 0)) >= int(entry["capacity"]):
			continue
		var launch: Vector3 = entry["launch"]
		var route := Street.plan(Vector2(launch.x, launch.z), Vector2(point.x, point.z))
		var copy: Dictionary = entry.duplicate()
		copy["distance"] = float(route.get("road_m", INF))
		result.append(copy)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["distance"]), float(b["distance"])):
			return str(a["id"]) < str(b["id"])
		return float(a["distance"]) < float(b["distance"]))
	return result

func assign(station_id: String) -> String:
	if not stations.has(station_id) or active.is_empty():
		return ""
	sequence += 1
	var id := "%s-%03d" % [station_id.to_upper(), sequence]
	_event("ASSIGNED", id)
	return id

func released(unit_id: String) -> void:
	_event("RELEASED", unit_id)

func status() -> String:
	if active.is_empty():
		return "DISPATCH • AVAILABLE"
	return "DISPATCH • CASE %03d • %s" % [int(active["id"]), str(active["reason"])]
