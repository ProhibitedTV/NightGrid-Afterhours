extends SceneTree
const Phone = preload("res://scripts/morrow_phone.gd")
const Cred = preload("res://scripts/street_cred.gd")
const InstrumentArt = preload("res://scripts/instrument_art.gd")
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
	for id in InstrumentArt.MODELS:
		var prop := InstrumentArt.build(id)
		if prop.mesh==null or prop.mesh.get_surface_count()==0 or prop.material_override!=InstrumentArt.material():
			prop.free()
			_fail("Imported instrument mesh or shared wear material missing: "+id)
			return
		prop.free()
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
	# The optional hobby uses real wallet debits and fixed gameplay time.
	var career = world.get("music_career")
	var music_cash: int = world.get("cash")
	var venues = world.get("venue_system")
	var musicians: Dictionary = venues.get("_ambient_musicians")
	if musicians.size()!=3:
		_fail("Expected three persistent ambient musicians")
		return
	var ash: Node3D = musicians["ash"]
	venues.call("set_focus",ash.global_position)
	venues.call("set_hour",13.0)
	if not ash.visible or venues.get("_ambient_source")!="ash":
		_fail("Scheduled nearby street musician must appear and source audio")
		return
	venues.call("set_player_performing",true)
	venues.call("_refresh")
	if not str(venues.get("_ambient_source")).is_empty():
		_fail("Ambient music must yield to player performance")
		return
	venues.call("set_player_performing",false)
	venues.call("set_hour",23.0)
	if ash.visible:
		_fail("Off-hours musician must be hidden")
		return
	venues.call("set_focus",Vector3.ZERO)
	venues.call("set_hour",16.0)
	actor.global_position = venues.call("venue_position","copper_cup")
	world.call("_toggle_venue")
	world.call("_venue_action",3)
	if not career.owned or world.get("cash") != music_cash-85:
		_fail("Physical instrument purchase must debit once")
		return
	world.call("_venue_action",3)
	if world.get("cash") != music_cash-85:
		_fail("Duplicate instrument purchase")
		return
	world.call("_close_venue")
	if not world.call("_start_music","busk","copper_cup") or not actor.get("input_blocked"):
		_fail("Busking must start at a safe physical spot")
		return
	venues.call("_refresh")
	if int(venues.call("music_audience_count"))<=0:
		_fail("Nearby open venue patrons should acknowledge the performance")
		return
	var rig: Node3D = actor.get_node("Visual")
	if rig.get("current_pose") != &"music_strum" or not rig.get_node("AcousticGuitar").visible:
		_fail("Performance should show guitar and authored strum clip")
		return
	world.call("_tick_music",.25)
	world.call("_stop_music")
	if int(venues.call("music_audience_count"))!=0:
		_fail("Performance cancellation must restore audience")
		return
	if actor.get("input_blocked") or rig.get_node("AcousticGuitar").visible or rig.get("current_pose")==&"music_strum" or world.get("cash") != music_cash-85:
		_fail("Interrupted set must restore input and not pay")
		return
	for set_index in range(3):
		if not world.call("_start_music","busk","copper_cup"):
			_fail("Expected busking set")
			return
		for tick in range(96):
			world.call("_tick_music",.25)
		if not career.mode.is_empty() or actor.get("input_blocked"):
			_fail("Completed set must release player input")
			return
		for tick in range(60):
			world.call("_tick_music",.25)
	if career.completed_sets != 3 or not career.can_gig(wallet) or world.get("cash") != music_cash-85+27:
		_fail("Three completed sets must unlock debut and award bounded tips")
		return
	var music_saved: Dictionary = career.snapshot()
	career.restore(music_saved)
	if not career.owned or career.completed_sets != 3:
		_fail("Instrument ownership and completed sets must restore")
		return
	actor.global_position = venues.call("venue_position","dock_nine")
	world.call("_toggle_venue")
	world.call("_venue_action",3)
	if career.mode != "gig":
		_fail("Debut booking must be available at physical venue")
		return
	for tick in range(160):
		world.call("_tick_music",.25)
	if not wallet.has_receipt("music:dock_nine_debut") or career.can_gig(wallet) or world.get("cash") != music_cash-85+27+95:
		_fail("Debut must pay once")
		return
	# The band roster is proximity-gated and persists; rehearsals never mint cash.
	var band_cash: int = world.get("cash")
	for tick in range(60):
		world.call("_tick_music",.25)
	for id in ["rhea","milo"]:
		actor.global_position = Vector3.ZERO
		world.call("_open_phone",false)
		menu.call("_choice","phone_app_music")
		menu.call("_choice","phone_music_recruit:"+id)
		if career.members.has(id):
			_fail("Remote recruitment must fail")
			return
		menu.call("hide_for_game")
		var contact: Vector3 = venues.call("music_contact_position",id)
		actor.global_position = contact+Vector3.UP
		world.call("_open_phone",false)
		menu.call("_choice","phone_app_music")
		menu.call("_choice","phone_music_recruit:"+id)
		if not career.members.has(id):
			_fail("In-person recruitment should succeed")
			return
		menu.call("hide_for_game")
	actor.global_position = venues.call("venue_position","copper_cup")
	for rehearsal in range(2):
		if not world.call("_start_music","rehearse","copper_cup"):
			_fail("Band rehearsal must start")
			return
		for tick in range(96):
			world.call("_tick_music",.25)
		for tick in range(60):
			world.call("_tick_music",.25)
	if career.rehearsals!=2 or world.get("cash")!=band_cash or not career.can_band_gig(wallet):
		_fail("Rehearsals must unlock band booking without payouts")
		return
	career.restore(career.snapshot())
	if not career.band_ready() or career.rehearsals!=2:
		_fail("Band roster and rehearsal history must restore")
		return
	venues.call("set_hour",21.0)
	actor.global_position = venues.call("venue_position","blue_hour")
	world.call("_toggle_venue")
	world.call("_venue_action",3)
	if not is_instance_valid(venues.get("_active_ensemble")):
		_fail("Band should populate both musician visuals")
		return
	if career.mode!="band":
		_fail("Blue Hour booking must start at the venue")
		return
	for tick in range(240):
		world.call("_tick_music",.25)
	if is_instance_valid(venues.get("_active_ensemble")):
		_fail("Band visuals must clear after performance")
		return
	if world.get("cash")!=band_cash+240 or career.can_band_gig(wallet) or not wallet.has_receipt("music:blue_hour_debut"):
		_fail("Band debut must settle once")
		return
	if Cred.community_price(18,{"community":19})!=18 or Cred.community_price(18,{"community":20})!=17 or Cred.rank(85)!="Scene icon":
		_fail("Street cred tier and price boundaries must agree")
		return
	var cred: Dictionary = world.call("_street_cred")
	if cred["music"]!=55 or cred["community"]!=12 or cred["underground"]!=40 or not career.can_encore(wallet):
		_fail("Cred must derive from successful performances, technical work and investigation")
		return
	for tick in range(60):
		world.call("_tick_music",.25)
	world.call("_toggle_venue")
	world.call("_venue_action",3)
	if career.mode!="encore":
		_fail("Respected musicians must unlock repeatable resident set")
		return
	for tick in range(240):
		world.call("_tick_music",.25)
	if career.encores!=1 or world.call("_street_cred")["music"]!=59 or world.get("cash")!=band_cash+360:
		_fail("Completed encore must pay and build music cred")
		return
	career.restore(career.snapshot())
	if world.call("_street_cred")["music"]!=59:
		_fail("Reputation must survive restore")
		return
	var before_cap: int = career.completed_sets
	career.completed_sets = 100000
	if world.call("_street_cred")["music"]!=100 or world.call("_street_cred")["community"]!=12:
		_fail("Music cred cap must not bleed into other scenes")
		return
	career.completed_sets = before_cap
	# The indoor stage uses the existing enter/exit lifecycle.
	for tick in range(60):
		world.call("_tick_music",.25)
	var interior = world.get("interiors")
	var outside: Vector3 = venues.call("venue_position","blue_hour")
	actor.global_position = interior.call("enter",venues.call("venue_by_id","blue_hour"),"VENUE",outside)
	var stage: Vector3 = interior.call("music_stage_point")
	if not stage.is_finite() or not is_instance_valid(interior.get("_room").get_node_or_null("LiveMusicStage")):
		_fail("Blue Hour needs a physical stage room")
		return
	actor.global_position = stage
	var before_indoor: int = world.get("cash")
	world.call("_toggle_interaction")
	if career.mode!="encore" or not is_instance_valid(venues.get("_active_ensemble")):
		_fail("Indoor stage interaction must start resident booking")
		return
	world.call("_tick_music",.25)
	world.call("_stop_music")
	if world.get("cash")!=before_indoor or is_instance_valid(venues.get("_active_ensemble")):
		_fail("Cancelled indoor set must clean up without pay")
		return
	actor.global_position = interior.call("leave")
	actor.global_position = interior.call("enter",venues.call("venue_by_id","copper_cup"),"VENUE",venues.call("venue_position","copper_cup"))
	if not is_instance_valid(interior.get("_room").get_node_or_null("CopperStrings")):
		_fail("Copper Strings indoor inventory display missing")
		return
	actor.global_position = interior.call("leave")
	world.set("current_car",world.get("cars")[0])
	if world.call("phone_available"):
		_fail("Phone must not open while driving")
		return
	world.set("current_car",null)
	print("MORROW_PHONE PASS: nine apps, live state, offer rotation, duty gate, workboard, alternate contact progression, physical diagnostics, staged investigation, music career, band progression, instrument pose, scene cred and resident booking and driving gate")
	quit(0)
