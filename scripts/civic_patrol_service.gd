extends RefCounted
## One physical service task, independent of player heat and scene nodes.
## Administrative requests may expire; a claimed physical task has its own
## bounded lifetime, and completion requires an observed vehicle arrival.
const MAX_TRAVEL_SECONDS = 100.0
const SERVICE_SECONDS = 6.0
var task: Dictionary = {}
var _handled: Dictionary = {}
var _history: Array[Dictionary] = []
const MAX_HISTORY = 8

func claim(incident: Dictionary, unit_id: String) -> bool:
	var id := str(incident.get("id", ""))
	var point: Variant = incident.get("point")
	if not task.is_empty() or id.is_empty() or unit_id.is_empty() or _handled.has(id) or incident.get("state") != "ACTIVE":
		return false
	if not point is Vector3 or not point.is_finite():
		return false
	task = incident.duplicate(true)
	task["unit_id"] = unit_id
	task["phase"] = "EN_ROUTE"
	task["elapsed"] = 0.0
	_handled[id] = true
	return true

func prune(cases: Array[Dictionary]) -> void:
	var retained := {}
	for incident in cases:
		var id := str(incident["id"])
		if _handled.has(id):
			retained[id] = true
	if not task.is_empty():
		retained[str(task["id"])] = true
	_handled = retained

func tick(delta: float, arrived: bool) -> void:
	if task.is_empty() or not is_finite(delta) or delta < 0.0:
		return
	task["elapsed"] = float(task["elapsed"]) + delta
	if task["phase"] == "EN_ROUTE":
		if arrived:
			task["phase"] = "SERVICING"
			task["elapsed"] = 0.0
		elif float(task["elapsed"]) >= MAX_TRAVEL_SECONDS:
			finish("EXPIRED")
	elif task["phase"] == "SERVICING":
		# A completed response requires continuous on-site service.
		if not arrived:
			finish("INTERRUPTED")
		elif float(task["elapsed"]) >= SERVICE_SECONDS:
			finish("COMPLETED")

func finish(outcome: String) -> void:
	if task.is_empty():
		return
	_history.append({"id":task["id"], "unit_id":task["unit_id"], "outcome":outcome})
	if _history.size() > MAX_HISTORY:
		_history.pop_front()
	task.clear()

func history() -> Array[Dictionary]:
	return _history.duplicate(true)

func snapshot() -> Dictionary:
	# Vehicle motion is not serialized for routine patrols. Safely cancel
	# in-flight tasks on reload; never restore a fictitious on-scene vehicle.
	return {"handled":_handled.keys()}

func restore(value: Variant) -> void:
	task.clear()
	_history.clear()
	_handled.clear()
	if value is Dictionary and value.get("handled") is Array:
		var ids: Array = value["handled"]
		for i in range(mini(ids.size(), 3)):
			if ids[i] is String and str(ids[i]).begins_with("CIV-") and str(ids[i]).length() <= 20:
				_handled[str(ids[i])] = true
