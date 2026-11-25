extends RefCounted
## First authored contact chain. World adapters emit only validated gameplay
## events; no per-frame scans, live scene references, or saved coordinates.
const VERSION = 1
const ID = "story:night_shift_contact"
const REWARD = 100
const STEPS = [
	{"id":"meet_mara","kind":"interact","event":"mara_talk","title":"Meet Mara at Lantern Cup","site":"lantern_cup"},
	{"id":"first_delivery","kind":"deliver","event":"courier_delivered","title":"Complete a paid delivery or local/civic contract","site":""},
	{"id":"report_back","kind":"interact","event":"mara_talk","title":"Report back to Mara at Lantern Cup","site":"lantern_cup"}
]
var status: String = "available"
var step: int = 0

func objective() -> Dictionary:
	if status == "complete":
		return {}
	return STEPS[step].duplicate()

func journal() -> String:
	match status:
		"complete":
			return "NIGHT SHIFT CONTACT: Complete"
		"failed", "abandoned":
			return "NIGHT SHIFT CONTACT: Return to Mara to retry."
	return "NIGHT SHIFT CONTACT: %d/%d  %s" % [step + 1, STEPS.size(), STEPS[step]["title"]]

func event(event_id: String, wallet: RefCounted) -> String:
	# The original event ID remains valid for old saves and courier callers.
	if event_id == "contract_completed":
		event_id = "courier_delivered"
	if status == "complete" or event_id != STEPS[step]["event"]:
		return ""
	if step == 0:
		if wallet.call("has_receipt", ID):
			status = "complete"
			step = STEPS.size()
			return "already_paid"
		status = "active"
		step = 1
		return "started"
	if status != "active":
		return ""
	if step == 1:
		step = 2
		return "delivered"
	if not wallet.call("has_receipt", ID) and not wallet.call("credit_once", ID, REWARD):
		return "blocked"
	status = "complete"
	step = STEPS.size()
	return "complete"

func interrupt(reason: String) -> bool:
	if status != "active" or reason not in ["failed", "abandoned"]:
		return false
	status = reason
	step = 0
	return true

func snapshot() -> Dictionary:
	return {"version":VERSION,"id":ID,"status":status,"step":step}

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var v: Dictionary = value
	if v.get("version") != VERSION or v.get("id") != ID:
		return false
	var n: Variant = v.get("step")
	if not (n is int or n is float) or not is_finite(float(n)) or floor(float(n)) != float(n):
		return false
	match v.get("status"):
		"available", "failed", "abandoned":
			return n == 0
		"active":
			return n == 1 or n == 2
		"complete":
			return n == STEPS.size()
	return false

func restore(data: Variant) -> bool:
	if not valid_snapshot(data):
		return false
	status = data["status"]
	step = int(data["step"])
	return true
