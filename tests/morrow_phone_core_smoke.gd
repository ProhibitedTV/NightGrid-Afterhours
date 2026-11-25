extends SceneTree
const Phone = preload("res://scripts/morrow_phone.gd")
func _initialize() -> void:
	call_deferred("_verify")
func _verify() -> void:
	var seen := {}
	for entry in Phone.APPS:
		var id: String = entry["id"]
		if seen.has(id) or not Phone.ICONS.has(id) or Phone.app(id).is_empty() or not Phone.view(id,{}).has("rows"):
			push_error("MORROW_PHONE_CORE: invalid app " + id)
			quit(1)
			return
		seen[id] = true
	var wallet: Dictionary = Phone.view("wallet",{"cash":123,"bitcoin_sats":42})
	var work: Dictionary = Phone.view("work",{"gig":true,"carrying":true,"payout":18})
	if seen.size()!=9 or not str(wallet["rows"]).contains("123") or not str(work["rows"]).contains("Deliver to customer") or not Phone.view("work",{})["actions"].is_empty():
		push_error("MORROW_PHONE_CORE: projection mismatch")
		quit(1)
		return
	print("MORROW_PHONE_CORE PASS")
	quit(0)
