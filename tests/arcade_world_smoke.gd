extends SceneTree
const Room = preload("res://scripts/interior_system.gd")
const Venue = preload("res://scripts/venue_system.gd")
const Plan = preload("res://scripts/world_plan.gd")
const Scores = preload("res://scripts/arcade_scores.gd")
const Session = preload("res://scripts/game_session.gd")
func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("ARCADE_WORLD_SMOKE: " + label)
		quit(1)
	return ok

func _verify() -> void:
	var venues := Venue.new()
	var rooms := Room.new()
	root.add_child(venues)
	root.add_child(rooms)
	await process_frame
	var site := venues.venue_by_id("insert_coin")
	var outside := venues.venue_position("insert_coin")
	if not check(not site.is_empty() and Plan.landmark_for_block(1,2).is_empty() and venues.nearest_venue(outside)["id"] == "insert_coin", "fixed non-landmark address"):
		return
	if not check(venues.is_open("insert_coin",14.0) and venues.is_open("insert_coin",2.9) and not venues.is_open("insert_coin",3.0), "midnight hours"):
		return
	var entry := rooms.enter(site,"VENUE",outside)
	if not check(rooms.arcade_cabinet_near(entry).is_empty() and rooms.arcade_cabinet_near(Room.ORIGIN + Vector3(-4.6,1.1,-2.2)) == "grand_delay", "entry and cabinet reachability"):
		return
	var snap := rooms.snapshot()
	if not check(rooms.leave() == outside and rooms.arcade_cabinet_near(entry).is_empty(), "leave clears activity"):
		return
	await process_frame
	if not check(rooms.restore(snap,site) and rooms.active_site_id() == "insert_coin", "legacy room save restore"):
		return
	if not check(rooms.arcade_circuit_near(Room.ORIGIN+Vector3(0,1.15,-3.35)) and not rooms.arcade_circuit_near(entry), "circuit board proximity"):
		return
	var highs := {}
	if not check(Scores.record(highs,"patch_day",150) and not Scores.record(highs,"patch_day",149) and not Scores.record(highs,"missing",500) and not Scores.record(highs,"patch_day",20001), "score settlement monotonic and bounded"):
		return
	var restored_highs := Scores.normalized(JSON.parse_string(JSON.stringify(highs)))
	if not check(restored_highs == highs and not Scores.valid({"patch_day":1.5}) and not Scores.valid({"patch_day":NAN}) and not Scores.valid({"bad":1}), "JSON and malformed score validation"):
		return
	if not check(Scores.board("patch_day",restored_highs).size() == 4 and Scores.board("patch_day",restored_highs)[3][0] == "YOU", "local board order"):
		return
	var stamps := {}
	if not check(Scores.circuit_count(stamps) == 0 and Scores.circuit_rows(stamps).size() == 8, "empty circuit"):
		return
	for challenge in Scores.CIRCUIT:
		Scores.record(stamps,challenge["id"],challenge["goal"]-1)
	if not check(Scores.circuit_count(stamps) == 0, "threshold minus one does not earn stamp"):
		return
	for challenge in Scores.CIRCUIT:
		Scores.record(stamps,challenge["id"],challenge["goal"])
	if not check(Scores.circuit_count(stamps) == 8 and Scores.circuit_count(Scores.normalized(JSON.parse_string(JSON.stringify(stamps)))) == 8, "eight stamps survive save roundtrip"):
		return
	if not check(Scores.mastery_rows({}).size()==10 and Scores.mastery_total({})==0 and Scores.mastery_level("neon_rebound",699)==0 and Scores.mastery_level("neon_rebound",4100)==3,"ten cabinet mastery thresholds"):
		return
	var gold := {}
	for id in Scores.MASTERY:
		Scores.record(gold,id,Scores.MASTERY[id][2])
	if not check(Scores.mastery_total(gold)==30 and Scores.mastery_total(Scores.normalized(JSON.parse_string(JSON.stringify(gold))))==30 and Scores.circuit_count(gold)==8,"mastery derives from existing saves"):
		return
	var board := preload("res://scripts/arcade_circuit_board.gd").new()
	board.configure(stamps)
	if not check(board.count == 8 and board.rows.size() == 8 and board.mastery.size()==10, "read-only circuit board"):
		return
	board.free()
	var session := Session.new()
	var snapshot := session.make_snapshot({"player_position":[0,1,0],"cash":0,"health":100,"deliveries":0,"carrying":false,"hour":19,"cars":[],"traffic":{},"rail":{}})
	if not check(session.is_valid_snapshot(snapshot), "old saves need no score field"):
		return
	snapshot["arcade_best"] = restored_highs
	if not check(session.is_valid_snapshot(snapshot), "valid scores accepted in save"):
		return
	snapshot["arcade_best"] = {"patch_day":-1}
	if not check(not session.is_valid_snapshot(snapshot), "malformed score save rejected"):
		return
	session.free()
	var screen := preload("res://scenes/arcade_pilot.tscn").instantiate()
	if not check(screen.configure_cabinet("patch_day",{"patch_day":150}) and screen.selection == 2 and screen.best["patch_day"] == 150, "locked title and session highs"):
		return
	# Exercise the actual modal screen lifecycle, not only score helpers.
	root.add_child(screen)
	var emissions: Array = []
	screen.score_recorded.connect(func(id: String, score: int) -> void:
		emissions.append([id,score,screen.state,screen.is_processing()]))
	screen.call("_start_round")
	if not check(screen.state == "play", "screen starts selected game"):
		return
	screen.round.score = 200
	var old_round = screen.round
	screen.call("_show_selection")
	var abandoned_step: int = old_round.step
	screen.call("_process", 10.0)
	screen.call("_finish_if_needed")
	if not check(screen.state == "select" and not screen.is_processing() and old_round.step == abandoned_step and emissions.is_empty() and screen.best["patch_day"] == 150, "abandon stops simulation without recording score"):
		return
	screen.call("_start_round")
	screen.round.score = 250
	screen.round.finished = true
	screen.call("_finish_if_needed")
	screen.call("_finish_if_needed")
	if not check(emissions == [["patch_day",250,"result",false]] and screen.best["patch_day"] == 250, "completion settles exactly once after stopping simulation"):
		return
	screen.call("_show_selection")
	screen.call("_start_round")
	screen.round.score = 200
	screen.round.finished = true
	screen.call("_finish_if_needed")
	if not check(emissions.size() == 1 and screen.best["patch_day"] == 250, "lower replay score does not replace record"):
		return
	# Closing a live modal must discard even a finished-but-unsettled round.
	screen.call("_show_selection")
	screen.call("_start_round")
	screen.round.score=400
	screen.round.finished=true
	var closing_round=screen.round
	var closing_step:int=closing_round.step
	screen.call("abort_session")
	screen.call("_process",10.0)
	screen.call("_finish_if_needed")
	if not check(screen.state=="select" and not screen.is_processing() and not screen.is_processing_input() and not screen.is_processing_unhandled_input() and closing_round.step==closing_step and emissions.size()==1 and screen.best["patch_day"]==250,"modal teardown discards unsettled round and disables input immediately"):
		return
	screen.free()
	rooms.queue_free()
	venues.queue_free()
	await process_frame
	print("ARCADE_WORLD_SMOKE: PASS")
	quit(0)
