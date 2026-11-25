extends SceneTree
## Integration test: fixed social addresses, hours, paid services, a linked
## delivery, minimap pins, and real save/load compatibility.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("VENUE_SMOKE: " + message)
	quit(1)

func _verify() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("Main scene failed to load")
		return
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	var venues := world.get_node_or_null("SocialVenues")
	var session := root.get_node_or_null("GameSession")
	var plan = load("res://scripts/world_plan.gd")
	var catalog = load("res://scripts/venue_system.gd")
	if venues == null or session == null:
		_fail("SocialVenues or GameSession is missing")
		return
	if int(venues.call("get_venue_count")) != 12 or catalog.SIDE_JOBS.size() != 5:
		_fail("Expected 12 social hubs and five story contracts")
		return
	var seen := {}
	var kind_counts := {}
	for venue in catalog.VENUES:
		var venue_id: String = venue["id"]
		if seen.has(venue_id):
			_fail("Duplicate permanent venue ID " + venue_id)
			return
		seen[venue_id] = true
		var ix := int(venue["ix"])
		var iz := int(venue["iz"])
		if ix < -3 or ix > 2 or iz < -3 or iz > 2:
			_fail("Venue was placed outside the authored downtown grid")
			return
		if not plan.landmark_for_block(ix, iz).is_empty():
			_fail("Venue overlaps an immutable landmark block")
			return
		var pos: Vector3 = venues.call("venue_position", venue_id)
		var center := Vector3((float(ix) + 0.5) * 58.0, 0.0, (float(iz) + 0.5) * 58.0)
		if absf(pos.x - center.x) > 12.0 or absf(pos.z - (center.z - 19.3)) > 0.01:
			_fail("Social hub marker is not on its fixed sidewalk frontage")
			return
		var near: Dictionary = venues.call("nearest_venue", pos)
		if str(near.get("id", "")) != venue_id:
			_fail("Player cannot discover venue " + venue_id)
			return
		var kind: String = venue["kind"]
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
	for kind in ["STALL", "CAFE", "BAR", "CLUB"]:
		if int(kind_counts.get(kind, 0)) != 3:
			_fail("Missing distinctive venue category " + kind)
			return
	for job in catalog.SIDE_JOBS:
		if not seen.has(str(job["from"])) or not seen.has(str(job["to"])) or job["from"] == job["to"]:
			_fail("Broken authored quest source/destination")
			return
	venues.call("set_hour", 12.0)
	var day: Dictionary = venues.call("get_lighting_state", "static_room")
	if day["open"] or float(day["energy"]) > 0.10:
		_fail("Nightclubs should be shut and nearly dark at noon")
		return
	venues.call("set_focus", venues.call("venue_position", "static_room"))
	venues.call("set_hour", 23.0)
	var night: Dictionary = venues.call("get_lighting_state", "static_room")
	if not night["open"] or float(night["energy"]) < 1.5:
		_fail("Nightclub signage should switch on after dark")
		return
	if int(venues.call("get_active_light_count")) > 2:
		_fail("More than the two budgeted local venue lights were enabled")
		return
	if int(venues.call("get_soundscape_count")) != 4 or int(venues.call("get_audio_player_count")) != 12:
		_fail("Four original soundscapes must be assigned to twelve social venues")
		return
	var ambience = load("res://scripts/venue_ambience.gd")
	for kind in ["STALL", "CAFE", "BAR", "CLUB"]:
		var stream: AudioStreamWAV = ambience.soundscape(kind)
		if stream == null or stream.data.size() != 44100:
			_fail("Original spatial audio loop missing or malformed for " + kind)
			return
	if not venues.call("is_open", "moon_noodles", 1.0) or venues.call("is_open", "moon_noodles", 5.0):
		_fail("Stall hours wrapping midnight are broken")
		return
	if venues.call("is_open", "copper_cup", 23.0) or not venues.call("is_open", "copper_cup", 9.0):
		_fail("Daytime cafe operating hours are broken")
		return
	var player: CharacterBody3D = world.get("player")
	var ui: PanelContainer = world.get("venue_panel")
	world.set("cash", 100)
	world.set("health", 40.0)
	player.global_position = venues.call("venue_position", "moon_noodles")
	world.call("_toggle_venue")
	if not ui.visible or str(world.get("venue_selected_id")) != "moon_noodles":
		_fail("The venue interaction menu did not open at the food stall")
		return
	world.call("_venue_action", 1)
	if int(world.get("cash")) != 84 or absf(float(world.get("health")) - 68.0) > 0.01:
		_fail("Food purchase did not deduct cash and restore health")
		return
	world.call("_venue_action", 2)
	if str(world.get("venue_job_active")) != "midnight_thermos":
		_fail("Auntie Sol's local side job was not accepted")
		return
	var map_state: Dictionary = world.call("get_map_state")
	if not bool(map_state.get("side_quest_active", false)) or (map_state.get("venues", []) as Array).size() != 12:
		_fail("Minimap does not expose side job and discovered venue pins")
		return
	world.call("_toggle_venue")
	player.global_position = venues.call("venue_position", "copper_cup")
	world.call("_toggle_venue")
	world.call("_venue_action", 2)
	if str(world.get("venue_job_active")) != "midnight_thermos":
		_fail("A closed destination incorrectly completed a side job")
		return
	venues.call("set_hour", 9.0)
	world.call("_venue_action", 2)
	if not str(world.get("venue_job_active")).is_empty() or int(world.get("cash")) != 264:
		_fail("Authored job did not complete or pay its $180 reward")
		return
	var completed: Array = world.get("venue_job_completed")
	if not completed.has("midnight_thermos"):
		_fail("Completed side job not recorded")
		return
	world.call("_toggle_venue")
	venues.call("set_hour", 23.0)
	player.global_position = venues.call("venue_position", "ink_tonic")
	world.call("_toggle_venue")
	world.call("_venue_action", 2)
	if str(world.get("venue_job_active")) != "dead_frequency":
		_fail("Second story job did not become active")
		return
	var old_seed: int = session.get("world_seed")
	var before: Dictionary = world.call("_capture_snapshot")
	var record: Dictionary = session.call("make_snapshot", before)
	if int(record.get("seed", -1)) != old_seed or not session.call("is_valid_snapshot", record):
		_fail("Venue state caused an invalid world save")
		return
	var older: Dictionary = record.duplicate(true)
	older.erase("venue_job_active")
	older.erase("venue_job_completed")
	older.erase("progression")
	if not session.call("is_valid_snapshot", older):
		_fail("Backward compatibility with existing version-one saves broke")
		return
	var malformed: Dictionary = record.duplicate(true)
	malformed["progression"] = {"version":1,"receipts":["venue:midnight_thermos","venue:midnight_thermos"]}
	if session.call("is_valid_snapshot", malformed):
		_fail("Duplicate reward receipt accepted by save validator")
		return
	var isolated_path := "user://tests/venues_smoke_slot.json"
	if not session.call("save_snapshot_to", before, isolated_path):
		_fail("Cannot write the isolated venue save slot")
		return
	var after: Dictionary = session.call("read_snapshot_from", isolated_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated_path))
	if after.is_empty():
		_fail("Could not load the on-disk venue save")
		return
	world.set("venue_job_active", "")
	world.set("cash", 0)
	world.call("_apply_snapshot", after)
	var restored_completed: Array = world.get("venue_job_completed")
	if str(world.get("venue_job_active")) != "dead_frequency" or not restored_completed.has("midnight_thermos"):
		_fail("Side job completion and in-progress state were not restored")
		return
	if int(world.get("cash")) != 264 or int(session.get("world_seed")) != old_seed:
		_fail("Loading a venue save changed currency or the city seed")
		return
	# Replaying a stale active contract after an actual disk restore must not pay.
	var ledger = world.get("progression")
	if not ledger.has_receipt("venue:midnight_thermos"):
		_fail("Paid venue receipt was lost on disk round trip")
		return
	world.set("venue_job_active", "midnight_thermos")
	world.set("venue_selected_id", "copper_cup")
	player.global_position = venues.call("venue_position", "copper_cup")
	venues.call("set_hour", 9.0)
	ui.visible = true
	world.call("_venue_action", 2)
	if int(world.get("cash")) != 264 or not str(world.get("venue_job_active")).is_empty():
		_fail("Stale paid job replay changed wallet or remained active")
		return
	# Old saves had only completed IDs; those still guard against duplicate pay.
	var pre_ledger: Dictionary = after.duplicate(true)
	pre_ledger.erase("progression")
	pre_ledger["venue_job_active"] = "midnight_thermos"
	world.call("_apply_snapshot", pre_ledger)
	world.set("venue_selected_id", "copper_cup")
	venues.call("set_hour", 9.0)
	ui.visible = true
	world.call("_venue_action", 2)
	if int(world.get("cash")) != 264 or not str(world.get("venue_job_active")).is_empty():
		_fail("Pre-ledger completed job replay changed wallet or remained active")
		return
	var music_job:Dictionary=venues.call("job_by_id","soundcheck_pass")
	if venues.call("job_unlocked",music_job,99) or not venues.call("job_unlocked",music_job,100):
		_fail("Exact music reputation threshold")
		return
	# A direct button/action call cannot bypass the reputation gate.
	world.call("_close_venue")
	world.set("venue_job_active","")
	venues.call("set_hour",23.0)
	player.global_position=venues.call("venue_position","static_room")
	world.call("_toggle_venue")
	world.call("_venue_action",2)
	if not str(world.get("venue_job_active")).is_empty():
		_fail("Low-reputation music contract bypass")
		return
	var music_ledger=world.get("progression")
	for id in ["midnight_thermos","dead_frequency","glass_invoice","last_shift_recipe"]:
		music_ledger.credit_once("venue:"+id,1)
	music_ledger.accept_cal_quest()
	music_ledger.collect_cal_gift()
	music_ledger.complete_cal_quest()
	if music_ledger.street_cred()!=105:
		_fail("Music contact threshold fixture failed")
		return
	world.call("_venue_action",2)
	if str(world.get("venue_job_active"))!="soundcheck_pass":
		_fail("Recognized player could not accept music introduction")
		return
	world.call("_close_venue")
	player.global_position=venues.call("venue_position","blue_hour")
	world.call("_toggle_venue")
	var before_cash:int=world.get("cash")
	world.call("_venue_action",2)
	if music_ledger.street_cred()!=135 or int(world.get("cash"))!=before_cash+125 or not music_ledger.has_receipt("venue:soundcheck_pass"):
		_fail("Music introduction reward or contact receipt missing")
		return
	world.call("_venue_action",2)
	if int(world.get("cash"))!=before_cash+125:
		_fail("Music introduction paid twice")
		return
	# Exercise real venue-to-menu-to-ledger bridge with the fixture clock.
	world.call("_venue_action",3)
	var menu:Node=world.get("game_menu")
	if menu.get("screen")!="blue_hour_set" or not paused:
		_fail("Opening set did not use the pause-safe music menu")
		return
	var run=menu.get("_rhythm")
	for lane in run.pattern:
		run.advance(run.target_time()-run.elapsed)
		run.strike(lane)
	var cash_before_set:int=world.get("cash")
	menu.call("_choice","rhythm_claim")
	if paused or menu.get("screen")!="hidden" or music_ledger.street_activity_runs("live_gig")!=1 or music_ledger.street_cred()!=147 or int(world.get("cash"))!=cash_before_set+45:
		_fail("Opening set did not settle and unpause exactly once")
		return
	world.call("_on_menu_action","rhythm_claim")
	if music_ledger.street_activity_runs("live_gig")!=1 or int(world.get("cash"))!=cash_before_set+45:
		_fail("Direct settlement replay awarded a second set")
		return
	# Street music is accessible before the underground introduction.
	var busk_ledger=world.get("progression")
	venues.call("set_hour",12.0)
	player.global_position=venues.call("venue_position","moon_noodles")
	world.call("_toggle_venue")
	world.call("_venue_action",3)
	if menu.get("screen")!="blue_hour_set" or menu.get("_rhythm").mode!="busking":
		_fail("Street sampler menu did not open")
		return
	var street_run=menu.get("_rhythm")
	for lane in street_run.pattern:
		street_run.advance(street_run.target_time()-street_run.elapsed)
		street_run.strike(lane)
	var cash_before_busk:int=world.get("cash")
	menu.call("_choice","rhythm_claim")
	if paused or busk_ledger.street_activity_runs("busking")!=1 or busk_ledger.street_activity_runs("live_gig")!=1 or int(world.get("cash"))!=cash_before_busk+8:
		_fail("Busking settlement crossed activity streams")
		return
	print("VENUE_SMOKE PASS: ", kind_counts, " / quests=", catalog.SIDE_JOBS.size(),
		" / saved_seed=", old_seed, " / venue_lights=", venues.call("get_active_light_count"))
	quit(0)
