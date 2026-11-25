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
	var courier: RefCounted = world.get("courier_mission")
	courier.set("gig_economy",true)
	world.call("_refresh_courier_target")
	var original_route: String = courier.call("objective")["route_id"]
	menu.call("open_pause")
	menu.call("_choice","phone")
	menu.call("_choice","phone_app_wallet")
	world.call("_on_menu_action","phone_work_decline")
	if courier.call("objective")["route_id"] != original_route:
		_fail("decline rejected outside work app")
		return
	menu.call("_choice","phone_back")
	menu.call("_choice","phone_app_work")
	if not (menu.call("get_buttons") as Dictionary).has("phone_work_decline"):
		_fail("decline button visible for available offer")
		return
	menu.call("_choice","phone_work_decline")
	if menu.get("screen") != "phone" or not paused or courier.call("objective")["route_id"] == original_route or ledger.get("balance") != cash_before or int(courier.get("completed_runs")) != 0:
		_fail("decline refreshes live order without paying or closing phone")
		return
	menu.call("_choice","phone_work_off")
	if bool(courier.get("on_duty")) or world.get("marker").visible or (menu.call("get_buttons") as Dictionary).has("phone_route_order"):
		_fail("off duty hides world beacon and route action")
		return
	var off: Dictionary = world.call("_capture_snapshot")
	if bool(off.get("courier_on_duty",true)):
		_fail("off duty saved")
		return
	menu.call("_choice","phone_work_on")
	if not bool(courier.get("on_duty")) or not world.get("marker").visible or not (menu.call("get_buttons") as Dictionary).has("phone_route_order"):
		_fail("resume restores same order and world marker")
		return
	var snap: Dictionary = world.call("_capture_snapshot")
	if int(snap.get("courier_offer_offset",0)) != 1:
		_fail("offer offset captured")
		return
	menu.call("hide_for_game")
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
