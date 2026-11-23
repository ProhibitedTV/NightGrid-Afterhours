extends RefCounted
## Opt-in spans. Ordinary gameplay retains no trace buffers.
const MAX_EVENTS = 24000
static var enabled := false
static var events: Array[Dictionary] = []
static var _frame_totals: Dictionary = {}

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func end(start: int, category: String, detail: Variant = null) -> void:
	if start == 0 or events.size() >= MAX_EVENTS:
		return
	events.append({"frame": Engine.get_process_frames(), "start_us": start,
		"duration_us": Time.get_ticks_usec() - start, "category": category, "detail": detail})

static func accumulate(start: int, category: String) -> void:
	if start != 0:
		_frame_totals[category] = int(_frame_totals.get(category, 0)) + Time.get_ticks_usec() - start

static func take_frame_totals() -> Dictionary:
	var totals := _frame_totals
	_frame_totals = {}
	return totals
