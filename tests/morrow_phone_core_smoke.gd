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
	var scores := {"music":50,"community":20,"underground":0}
	var cred: Dictionary = Phone.view("cred",{"scene_scores":scores})
	var cred_rows: Array = cred["rows"]
	if cred_rows[1]["label"]!="Music scene" or cred_rows[1]["value"]!="50 / 100 · Respected" or cred_rows[2]["value"]!="20 / 100 · Recognized" or cred_rows[3]["value"]!="0 / 100 · Unknown" or not cred["actions"].is_empty() or scores["music"]!=50:
		_fail("scene reputation ranks must be read-only and accurately projected")
		return
	var music: Dictionary = Phone.view("music",{"music_recruit_milo":true,"music_showcase":true,"music_merch":"12 tapes in stock"})
	var music_actions := str(music["actions"])
	var empty_music_actions := str(Phone.view("music",{})["actions"])
	if not music_actions.contains("phone_route_music_milo") or not music_actions.contains("phone_route_music_showcase") or not str(music["rows"]).contains("12 tapes in stock") or empty_music_actions.contains("phone_route_music_milo") or empty_music_actions.contains("phone_route_music_showcase"):
		_fail("music navigation reflects current career availability")
		return
	var packed: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var menu: Node = world.get_node("GameMenus")
	var ledger: RefCounted = world.get("progression")
	var context: Dictionary = world.call("_phone_context")
	if context.get("scene_scores",{}) != preload("res://scripts/scene_reputation.gd").scores(ledger):
		_fail("phone uses authoritative scene reputation")
		return
	if bool(context.get("music_recruit_milo")) or bool(context.get("music_showcase")):
		_fail("new career cannot expose unavailable bookings")
		return
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
	menu.call("_choice","phone_app_music")
	world.call("_on_menu_action","phone_route_music_milo")
	world.call("_on_menu_action","phone_route_music_showcase")
	if menu.get("screen")!="phone" or ledger.get("balance")!=cash_before:
		_fail("unavailable music routes cannot close phone or change wallet")
		return
	menu.call("_choice","phone_back")
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
	menu.call("_choice","phone_app_opportunities")
	if not (menu.call("get_buttons") as Dictionary).has("phone_route_circuit"):
		_fail("Circuit discoverable on workboard")
		return
	menu.call("_choice","phone_route_circuit")
	var trial=world.get("_driving_trial")
	if paused or world.get("navigation_waypoint")!=trial.START or trial.active or ledger.get("balance")!=cash_before:
		_fail("Circuit discovery routes without starting or paying")
		return
	var beacon:=world.get_node_or_null("DrivingTrialBeacon") as Node3D
	if beacon==null or beacon.find_children("*","CollisionShape3D",true,false).size()!=0 or beacon.position!=Vector3(trial.START.x,0,trial.START.y):
		_fail("Circuit marker is missing, misplaced or colliding")
		return
	world.call("clear_navigation_waypoint")
	var taxi = preload("res://scripts/taxi_job.gd")
	var freight = preload("res://scripts/freight_job.gd")
	for listing_id in ["taxi:current","freight:current"]:
		menu.call("open_pause")
		menu.call("_choice","phone")
		menu.call("_choice","phone_app_opportunities")
		var route_action: String = "phone_route_contract:"+listing_id
		var expected: Vector2 = taxi.offer(0)["pickup"] if listing_id=="taxi:current" else freight.offer(0)["pickup"]
		if not (menu.call("get_buttons") as Dictionary).has(route_action):
			_fail("vehicle job is discoverable in workboard: "+listing_id)
			return
		menu.call("_choice",route_action)
		if paused or world.get("navigation_waypoint")!=expected or ledger.get("balance")!=cash_before:
			_fail("vehicle job routes to exact road stop, not a nearby pin: "+listing_id)
			return
		world.call("clear_navigation_waypoint")
	var venue: Node = world.get("venue_system")
	var entrance: Vector3 = venue.call("venue_position","lantern_cup")
	var near_pin := Vector2(entrance.x,entrance.z)+Vector2(1,0)
	if world.call("set_navigation_waypoint",near_pin,false)!=near_pin or world.call("set_navigation_waypoint",near_pin)==near_pin:
		_fail("exact route opt-out must preserve ordinary manual map snapping")
		return
	world.call("clear_navigation_waypoint")
	for owner in ["taxi","freight"]:
		var job_drop := Vector2(58,116)
		world.call("set_navigation_waypoint",job_drop,false)
		world.set("_vehicle_job_waypoint_owner",owner)
		var active_save: Dictionary = world.call("_capture_snapshot")
		if not active_save["navigation_waypoint"].is_empty():
			_fail("transient vehicle job route cannot survive save")
			return
		world.call("_cancel_"+owner)
		if world.get("navigation_waypoint")!=null or world.get("_vehicle_job_waypoint_owner")!="":
			_fail("job cancellation clears its own route")
			return
		world.call("set_navigation_waypoint",job_drop,false)
		world.set("_vehicle_job_waypoint_owner",owner)
		var manual := Vector2(0,58)
		world.call("set_navigation_waypoint",manual,false)
		world.call("_cancel_"+owner)
		if world.get("navigation_waypoint")!=manual:
			_fail("job cancellation must preserve replacement waypoint")
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
	# Use the same ledger operations as the physical music venues.
	var instruments = preload("res://scripts/instrument_catalog.gd")
	ledger.call("set_balance",1000)
	if not ledger.call("buy_instrument",instruments.STARTER) or not ledger.call("credit_once","venue:soundcheck_pass",0):
		_fail("music career fixture")
		return
	for practice in range(1,instruments.OWNED_SET_PRACTICE+1):
		if not ledger.call("complete_sampler_practice",practice):
			_fail("music practice fixture")
			return
	if not ledger.call("settle_blue_hour_set",1):
		_fail("music opening set fixture")
		return
	if not _verify_music_route(world,menu,ledger,"phone_route_music_milo","dock_nine"):
		return
	if not ledger.call("recruit_band_member","milo") or not ledger.call("recruit_band_member","rhea") or not ledger.call("choose_band_name",0):
		_fail("music roster fixture")
		return
	for rehearsal in range(1,3):
		if not ledger.call("complete_band_rehearsal",rehearsal):
			_fail("band rehearsal fixture")
			return
	if not ledger.call("settle_band_debut") or not ledger.call("press_tapes") or not ledger.call("settle_band_encore",1) or not ledger.call("settle_band_encore",2):
		_fail("headline career fixture")
		return
	var live_music: Dictionary = Phone.view("music",world.call("_phone_context"))
	if str(live_music["actions"]).contains("phone_route_music_milo") or not str(live_music["rows"]).contains("4 tapes in stock"):
		_fail("recruited collaborator removed and actual merchandise displayed")
		return
	if not _verify_music_route(world,menu,ledger,"phone_route_music_showcase","static_room"):
		return
	world.queue_free()
	await process_frame
	print("MORROW_PHONE_CORE PASS")
	quit(0)

func _verify_music_route(world: Node3D,menu: Node,ledger: RefCounted,action: String,site: String) -> bool:
	var before: Dictionary = ledger.call("snapshot")
	var before_cash: int = ledger.get("balance")
	menu.call("open_pause")
	menu.call("_choice","phone")
	menu.call("_choice","phone_app_music")
	if not (menu.call("get_buttons") as Dictionary).has(action):
		_fail("unlocked career destination missing: "+site)
		return false
	var point: Vector3 = world.get("venue_system").call("venue_position",site)
	menu.call("_choice",action)
	if paused or menu.call("is_open") or world.get("navigation_waypoint")!=Vector2(point.x,point.z) or ledger.call("snapshot")!=before or ledger.get("balance")!=before_cash:
		_fail("music navigation must route without changing career or cash: "+site)
		return false
	world.call("clear_navigation_waypoint")
	return true

func _fail(message: String) -> void:
	push_error("MORROW_PHONE_CORE: " + message)
	paused = false
	quit(1)
