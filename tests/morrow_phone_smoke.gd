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
		if not buttons.has("phone_app_"+id) or buttons["phone_app_"+id].focus_mode != Control.FOCUS_ALL or buttons["phone_app_"+id].icon == null:
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
	# Route cycling is a real mission operation, not a second phone ledger.
	var mission = world.get("courier_mission")
	mission.gig_economy = true
	var before_offer: String = mission.objective()["route_id"]
	var before_runs: int = mission.completed_runs
	var before_cash: int = world.get("cash")
	world.call("_open_phone",false)
	menu.call("_choice","phone_app_work")
	menu.call("_choice","phone_decline_offer")
	if mission.objective()["route_id"] == before_offer or mission.completed_runs != before_runs or world.get("cash") != before_cash:
		_fail("Declining must rotate offer without payout or run credit")
		return
	var chosen: String = mission.objective()["route_id"]
	var snapshot: Dictionary = world.call("_capture_snapshot")
	mission.restore_offer_offset(0)
	mission.restore_offer_offset(snapshot["courier_offer_offset"])
	if mission.objective()["route_id"] != chosen:
		_fail("Offer cursor must survive restoration")
		return
	mission.step = 1
	menu.call("refresh_phone",world.call("_phone_context"))
	if menu.call("get_buttons").has("phone_decline_offer") or mission.decline_offer():
		_fail("A carried package cannot be switched")
		return
	if mission.set_on_duty(false):
		_fail("Cannot go offline with a carried order")
		return
	mission.step = 0
	menu.call("refresh_phone",world.call("_phone_context"))
	menu.call("_choice","phone_toggle_duty")
	if mission.on_duty or world.get("marker").visible or world.call("get_map_state")["mission_active"] or not str(world.call("_journal_context")["main_objective"]).contains("offline"):
		_fail("Offline must clear active courier presentation")
		return
	if not mission.advance("collect",mission.target(),world.get("progression")).is_empty():
		_fail("Offline courier must not collect")
		return
	if world.call("_capture_snapshot")["courier_on_duty"] != false:
		_fail("Offline state missing from save")
		return
	menu.call("_choice","phone_back")
	menu.call("_choice","phone_app_opportunities")
	var listings: Array = world.call("_phone_workboard")
	if listings.size() != 10:
		_fail("Workboard must list eight existing and two technical contracts")
		return
	var first: Dictionary = listings[0]
	var route_action: String = "phone_route_contract:"+str(first["id"])
	if not menu.call("get_buttons").has(route_action):
		_fail("Missing real contract route")
		return
	var ledger_before: Dictionary = world.get("progression").snapshot()
	menu.call("_choice",route_action)
	if paused or world.get("navigation_waypoint") == null or world.get("progression").snapshot() != ledger_before or not str(world.get("venue_job_active")).is_empty():
		_fail("Browsing must route, never remotely accept or pay")
		return
	var story = world.get("story_mission")
	var wallet = world.get("progression")
	story.event("mara_talk",wallet)
	if story.event("contract_completed",wallet) != "delivered" or story.step != 2:
		_fail("Legitimate local work should qualify for Mara's referral")
		return
	# Real civic counter, evidence, retry, one-time payout and discovery removal.
	var civic = world.get("civic_services")
	var actor: Node3D = world.get("player")
	civic.call("set_hour",12.0)
	actor.global_position = civic.call("position_for","crane_supply")
	world.call("_toggle_civic")
	world.call("_venue_action",3)
	if not world.get("_technical_case_open") or not world.get("venue_label").text.contains("DIAGNOSTIC REPORT"):
		_fail("Technical contract must open at the actual counter")
		return
	var technical_cash: int = world.get("cash")
	world.call("_venue_action",1)
	if world.get("cash") != technical_cash or not world.get("_technical_case_open"):
		_fail("Incorrect diagnosis must not pay or complete")
		return
	actor.global_position += Vector3(20,0,0)
	world.call("_venue_action",2)
	if world.get("cash") != technical_cash:
		_fail("Remote repair must be rejected")
		return
	actor.global_position = civic.call("position_for","crane_supply")
	world.call("_toggle_civic")
	world.call("_venue_action",3)
	world.call("_venue_action",2)
	if world.get("cash") != technical_cash+480 or not wallet.has_receipt("technical:crane_interlock"):
		_fail("Correct physical diagnosis must settle once")
		return
	world.call("_venue_action",3)
	if world.get("cash") != technical_cash+480 or world.get("_technical_case_open"):
		_fail("Completed repair must not reopen")
		return
	for listing in world.call("_phone_workboard"):
		if listing["id"] == "technical:crane_interlock":
			_fail("Completed repair still advertised")
			return
	world.call("_close_venue")
	var case_state = world.get("investigation")
	var case_cash: int = world.get("cash")
	var unlocked := false
	for listing in world.call("_phone_workboard"):
		if listing["id"] == "investigation:paper_city":
			unlocked = true
	if not unlocked:
		_fail("Paid technical work must unlock investigation")
		return
	if case_state.advance("dock_watch",0,wallet)["status"] != "unavailable":
		_fail("Cannot skip investigation stages")
		return
	for site in ["harbor_library","records_office","dock_watch","harbor_library"]:
		actor.global_position = civic.call("position_for",site)
		world.call("_toggle_civic")
		world.call("_venue_action",3)
		if not world.get("_investigation_open"):
			_fail("Investigation must open only at the current physical lead")
			return
		if case_state.stage == 3:
			world.call("_venue_action",2)
			if case_state.stage != 3 or world.get("cash") != case_cash:
				_fail("Unsupported accusation must not settle")
				return
		world.call("_venue_action",1)
		if case_state.stage < 4:
			var stored: Dictionary = world.call("_capture_snapshot")
			var stage_before: int = case_state.stage
			case_state.restore(0,wallet)
			case_state.restore(int(stored["investigation_stage"]),wallet)
			if case_state.stage != stage_before or world.get("cash") != case_cash:
				_fail("Intermediate lead must persist without payment")
				return
	if case_state.stage != 4 or world.get("cash") != case_cash+1450 or not wallet.has_receipt("investigation:paper_city"):
		_fail("Investigation must settle exactly once")
		return
	if case_state.advance("harbor_library",0,wallet)["status"] != "unavailable":
		_fail("Completed investigation must not pay again")
		return
	world.set("current_car",world.get("cars")[0])
	if world.call("phone_available"):
		_fail("Phone must not open while driving")
		return
	world.set("current_car",null)
	print("MORROW_PHONE PASS: seven apps, live state, offer rotation, duty gate, workboard, alternate contact progression, physical diagnostics, staged investigation and driving gate")
	quit(0)
