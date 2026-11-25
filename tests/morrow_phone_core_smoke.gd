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
	var packed: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var menu: Node = world.get_node("GameMenus")
	var ledger: RefCounted = world.get("progression")
	var cash_before: int = ledger.get("balance")
	var mission_before: Vector3 = world.get("mission_position")
	menu.call("open_pause")
	if not world.call("phone_available") or (menu.call("get_buttons") as Dictionary)["phone"].disabled:
		_fail("pause phone availability")
		return
	menu.call("_choice","phone")
	if menu.get("screen") != "phone" or not paused or (menu.call("get_buttons") as Dictionary).size()!=10:
		_fail("real phone launcher and nine apps")
		return
	for app in Phone.APPS:
		menu.call("_choice","phone_app_"+str(app["id"]))
		if menu.get("_phone_app") != app["id"]:
			_fail("app selection "+str(app["id"]))
			return
		menu.call("_choice","phone_back")
		if not str(menu.get("_phone_app")).is_empty():
			_fail("back to launcher")
			return
	menu.call("_choice","phone_app_wallet")
	world.call("_on_menu_action","phone_route_mara")
	if menu.get("screen")!="phone":
		_fail("wrong-app route rejected")
		return
	menu.call("_choice","phone_back")
	menu.call("_choice","phone_app_contacts")
	menu.call("_choice","phone_route_mara")
	if paused or menu.call("is_open") or world.get("navigation_waypoint")==null or ledger.get("balance")!=cash_before or world.get("mission_position")!=mission_before:
		_fail("real route must resume gameplay without changing wallet or mission")
		return
	world.call("clear_navigation_waypoint")
	menu.call("open_pause")
	menu.call("_choice","phone")
	menu.call("_choice","phone_back")
	if menu.get("screen")!="pause" or not paused:
		_fail("phone back restores pause")
		return
	menu.call("hide_for_game")
	world.get("venue_panel").show()
	if world.call("phone_available"):
		_fail("phone blocked during service interaction")
		return
	world.get("venue_panel").hide()
	world.queue_free()
	await process_frame
	print("MORROW_PHONE_CORE PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("MORROW_PHONE_CORE: " + message)
	paused = false
	quit(1)
