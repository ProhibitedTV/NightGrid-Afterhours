extends SceneTree
const Phone = preload("res://scripts/morrow_phone.gd")
func _initialize() -> void:
	create_timer(60.0,true,false,true).timeout.connect(func() -> void: _fail("watchdog"))
	call_deferred("_verify")
func _fail(reason: String) -> void:
	push_error("MORROW_PHONE: "+reason)
	quit(1)
func _verify() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var menu = world.get("game_menu")
	var original: Dictionary = world.call("_capture_snapshot")
	var state: Dictionary = world.call("_phone_context")
	if state["cash"] != original["cash"] or not state["rail_available"] or not state["bus_available"]:
		_fail("Phone must expose actual world wallet and transit")
		return
	var inactive := Phone.view("work",{"gig":false})
	if not inactive["actions"].is_empty():
		_fail("Inactive account cannot route work")
		return
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.pressed = true
	world.call("_unhandled_input",key)
	if not paused or menu.get("screen") != "phone":
		_fail("P must open phone on foot")
		return
	var buttons: Dictionary = menu.call("get_buttons")
	for entry in Phone.APPS:
		var id: String = entry["id"]
		if not buttons.has("phone_app_"+id) or buttons["phone_app_"+id].focus_mode != Control.FOCUS_ALL:
			_fail("Missing focusable phone app "+id)
			return
	menu.call("_choice","phone_app_wallet")
	if menu.get("_phone_app") != "wallet":
		_fail("Wallet navigation")
		return
	menu.call("_choice","phone_back")
	menu.call("_choice","phone_app_housing")
	menu.call("_choice","phone_route_home")
	if paused or world.get("navigation_waypoint") == null:
		_fail("Housing route must return to gameplay and create waypoint")
		return
	var after: Dictionary = world.call("_capture_snapshot")
	if original["cash"] != after["cash"] or original["progression"] != after["progression"] or original["deliveries"] != after["deliveries"]:
		_fail("Phone browsing or routing mutated economy")
		return
	menu.call("open_pause")
	menu.call("_choice","phone")
	if menu.get("screen") != "phone":
		_fail("Controller-accessible pause entry missing")
		return
	menu.call("_choice","phone_back")
	if menu.get("screen") != "pause" or not paused:
		_fail("Back must restore pause ownership")
		return
	menu.call("hide_for_game")
	world.set("current_car",world.get("cars")[0])
	if world.call("phone_available"):
		_fail("Phone must not open while driving")
		return
	world.set("current_car",null)
	print("MORROW_PHONE PASS: six apps, live state, physical routes, pause ownership and driving gate")
	quit(0)
