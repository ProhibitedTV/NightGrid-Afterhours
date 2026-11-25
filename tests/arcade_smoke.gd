extends SceneTree
const Track = preload("res://scripts/grand_delay_track.gd")
const Garage = preload("res://scripts/grand_delay_garage.gd")
const Rivals = preload("res://scripts/grand_delay_rivals.gd")
const Race = preload("res://scripts/grand_delay_race.gd")
const Round = preload("res://scripts/arcade_round.gd")
const Alt = preload("res://scripts/arcade_alt_round.gd")
const Extra = preload("res://scripts/arcade_extra_round.gd")
const Season = preload("res://scripts/arcade_season_round.gd")
const Classic = preload("res://scripts/arcade_classic_round.gd")
func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("ARCADE_SMOKE: " + label)
		quit(1)
	return ok

func _verify() -> void:
	var a := Round.new()
	if not check(not a.start("missing") and a.finished, "unknown title rejected"):
		return
	if not check(a.start("grand_delay"), "driving title starts"):
		return
	a.steer(-99)
	a.steer(-1)
	if not check(a.lane == 0 and not a.strike(), "bounded steering and no driving attack"):
		return
	a.advance()
	if not check(a.objects.size() == 2, "feature and paywall spawn"):
		return
	a.steer(1)
	for i in range(5):
		a.advance()
	if not check(a.score == 100 and a.lives == 3, "feature collected without paywall"):
		return
	if not check(a.start("claw_compliance") and a.score == 0 and a.objects.is_empty(), "replay resets"):
		return
	a.advance()
	if not check(not a.strike(), "out of reach cannot strike"):
		return
	for i in range(3):
		a.advance()
	if not check(a.strike() and a.score == 100 and not a.strike(), "strike resolves once"):
		return
	while not a.finished:
		a.advance()
	var result := a.result()
	a.advance()
	a.steer(-1)
	a.strike()
	if not check(a.result() == result and a.step <= Round.ROUND_STEPS, "finished result immutable and bounded"):
		return
	var b := Round.new()
	b.start("grand_delay")
	b.steer(1)
	for i in range(6):
		b.advance()
	if not check(b.lives == 2, "paywall damage"):
		return
	var deluxe := Round.new()
	deluxe.start("grand_delay")
	for i in range(10):
		for item in deluxe.objects:
			if item["kind"] == "feature" and item["row"] == 4:
				deluxe.lane = item["lane"]
		deluxe.advance()
	if not check(deluxe.nitro_charge == 3 and deluxe.score == 300 and deluxe.strike() and not deluxe.strike(), "three shipped features charge one nitro"):
		return
	for item in deluxe.objects:
		if item["kind"] == "paywall" and item["row"] == 3:
			deluxe.lane = item["lane"]
	var before_nitro := deluxe.lives
	deluxe.advance()
	deluxe.advance()
	if not check(deluxe.lives == before_nitro and deluxe.nitro_ticks == 0, "nitro bypasses one paywall"):
		return
	deluxe.start("grand_delay")
	if not check(deluxe.nitro_charge == 0 and deluxe.nitro_ticks == 0 and deluxe.streak == 0, "nitro and streak reset on replay"):
		return
	if not check(is_zero_approx(Track.curvature(260.0)) and Track.curvature(440.0)>.7 and Track.curvature(925.0)<-.6 and is_zero_approx(Track.road_center(440.0,0.0)), "authored curve signs and contact projection"):
		return
	var race = Race.new()
	if not check(race.start("grand_delay") and race.course.size() == 30 and race.countdown > 0, "authored three-district course"):
		return
	for i in range(121):
		race.advance(true)
	if not check(race.distance < 1.0 and race.speed < 2.0, "countdown holds the car"):
		return
	for i in range(240):
		race.advance(true)
	if not check(race.speed > 70.0 and race.distance > 100.0, "throttle accelerates continuously"):
		return
	for i in range(90):
		race.steer(-1.0)
		race.advance(false,true)
	if not check(race.position_x >= -.10 and race.position_x < .1 and race.speed <= 29.0, "braking and steering bounded"):
		return
	race.start("grand_delay")
	race.countdown = 0.0
	for i in range(3):
		race._hit({"kind":"feature","label":"TEST"},0.0)
	if not check(race.strike() and race.nitro_left > 0.0 and not race.strike(), "charged boost once"):
		return
	race._hit({"kind":"wall","label":"TEST"},0.0)
	if not check(race.lives==3 and race.pickups==3 and race.score>300,"nitro bypasses paywall"):
		return
	race.speed=70.0
	race._hit({"kind":"traffic"},.45)
	if not check(race.near_misses==1 and race.overtakes==1,"near miss rewards skill"):
		return
	race._hit({"kind":"traffic"},0.0)
	race._hit({"kind":"traffic"},0.0)
	if not check(race.lives==2 and race.collisions==1,"contact invulnerability prevents double damage"):
		return
	race.start("grand_delay")
	race.countdown=0.0
	# Collision-free deterministic pace test isolates the checkpoint clock.
	race.course.clear()
	race.objects.clear()
	race.next_event=0
	for i in range(6000):
		race.advance(true)
		if race.finished:
			break
	if not check(race.cleared and race.distance==Race.LENGTH and race.splits.size()==3 and race.race_time<60.0,"three checkpoint sprint is winnable"):
		return
	# Full authored course: steer from visible objects only, without changing course,
	# score, speed, invulnerability or object positions.
	race.start("grand_delay")
	for i in range(6000):
		var closest: Dictionary = {}
		for item in race.objects:
			if closest.is_empty() or float(item["z"]) < float(closest["z"]):
				closest = item
		var target: float = 1.0
		if not closest.is_empty():
			target = float(closest["x"])
			if closest["kind"] != "feature":
				target += -.47 if target >= 2.0 else .47
		race.steer(clampf((target-race.position_x)*4.0,-1.0,1.0))
		race.advance(true)
		if race.finished:
			break
	if not check(race.cleared and race.lives==3 and race.pickups>=9 and race.near_misses>=5 and race.score>2000,"full authored course clear with steering and real traffic"):
		return
	var final_race = race.result()
	race.advance()
	if not check(race.result()==final_race,"race result immutable"):
		return
	race.start("grand_delay")
	race.countdown=0.0
	race.remaining=Race.DT
	race.advance()
	if not check(race.finished and not race.cleared and race.pickups==0,"timeout and replay reset"):
		return
	# Controlled slide is rewarded once per authored corner, not per button tap.
	race.start("grand_delay")
	race.countdown=0.0
	race.distance=440.0
	race.speed=65.0
	race.objects.clear()
	race.course.clear()
	race.next_event=0
	race.steer(.40)
	for i in range(24):
		race.advance(false,true)
	race.steer(0.0)
	race.advance(true)
	if not check(race.drift_count==1 and race.drift_points>40 and not race.drifting, "clean corner drift earns points"):
		return
	race.distance=440.0
	race.position_x=1.0
	race.speed=65.0
	race.steer(.40)
	for i in range(24):
		race.advance(false,true)
	race.steer(0.0)
	race.advance(true)
	if not check(race.drift_count==1, "one drift award per bend"):
		return
	race.start("grand_delay")
	if not check(race.drift_count==0 and race.drift_awards.is_empty() and not race.shoulder, "replay clears driving state"):
		return
	# All cars are selectable, all have authored speed/grip differences, no unlocks.
	var top_speeds: Array[float] = []
	for index in range(Garage.CARS.size()):
		race.start("grand_delay",index,false)
		race.countdown=0.0
		race.course.clear()
		race.objects.clear()
		for i in range(400):
			race.advance(true)
		top_speeds.append(race.speed)
	if not check(top_speeds[1]>top_speeds[0] and top_speeds[0]>top_speeds[2] and Garage.spec(2)["grip"]>Garage.spec(1)["grip"], "distinct vehicle performance"):
		return
	race.start("grand_delay",1,true)
	if not check(race.rivals.size()==3 and race.race_place()==4 and race.car_index==1, "competitive starting grid"):
		return
	race.countdown=0.0
	for i in range(120):
		race.advance(true)
	if not check(float(race.rivals[0]["z"])>12.0 and float(race.rivals[0]["speed"])>0.0, "rivals advance under own acceleration"):
		return
	# Exact finish ordering and contact cooldown isolated from the traffic model.
	var ai_grid = Rivals.new_grid()
	var ai_time = 0.0
	for i in range(4200):
		ai_time += Race.DT
		Rivals.advance(ai_grid,race.objects,race.course,Race.DT,ai_time)
	for driver in ai_grid:
		if not check(float(driver["finish"])>40.0 and float(driver["finish"])<65.0 and float(driver["z"])==Race.LENGTH, "each rival completes the full sprint"):
			return
	var grid = Rivals.new_grid()
	grid[0]["finish"]=48.0
	grid[1]["finish"]=51.0
	if not check(Rivals.place(grid,Race.LENGTH,50.0)==2, "finish-time ordering"):
		return
	race.rival_cooldown=0.0
	race.rivals[0]["z"]=race.distance
	race.rivals[0]["x"]=race.position_x
	var before_contact: float = race.speed
	var before_lives: int = race.lives
	race._rival_contact()
	race._rival_contact()
	if not check(race.rival_contacts==1 and race.speed<before_contact and race.lives==before_lives, "rival contact is a bounded speed penalty"):
		return
	race.start("grand_delay")
	if not check(race.rivals.is_empty() and race.car_index==0 and race.rival_contacts==0, "solo replay clears competition"):
		return
	# Complete competitive run through the same public controls. Do not require a
	# perfect finish here: it is a regression for mode settlement, not tuning.
	race.start("grand_delay",1,true)
	for i in range(6000):
		var next: Dictionary = {}
		for item in race.objects:
			if next.is_empty() or float(item["z"])<float(next["z"]):
				next=item
		var lane_target = 1.0
		if not next.is_empty():
			lane_target=float(next["x"])
			if next["kind"]!="feature":
				lane_target+=-.47 if lane_target>=2.0 else .47
		race.steer(clampf((lane_target-race.position_x)*4.0,-1.0,1.0))
		race.advance(true)
		if race.finished:
			break
	if not check(race.finished and race.cleared and race.finish_place>=1 and race.finish_place<=4 and race.score<=Race.MAX_SCORE, "competitive sprint settles bounded final position"):
		return
	var competitive_result = race.result()
	race.advance(true)
	if not check(race.result()==competitive_result, "competitive finish remains immutable"):
		return
	var parry := Round.new()
	parry.start("claw_compliance")
	parry.objects.append({"lane":1,"row":Round.END_ROW-1,"kind":"drone"})
	if not check(parry.strike() and parry.parries==1 and parry.score==125 and parry.claw_combo==1,"last-tick parry grants unique bonus"):
		return
	parry.start("claw_compliance")
	if not check(parry.parries==0 and parry.claw_combo==0,"parry reset"):
		return
	var patch := Alt.new()
	if not check(patch.start("patch_day") and patch.strike() and patch.score == 150 and not patch.strike(), "patch repairs exactly once"):
		return
	patch.steer(999)
	patch.vertical(-999)
	if not check(patch.cursor == Vector2i(2, 0), "grid movement bounded per action"):
		return
	while not patch.finished:
		patch.advance()
		if not patch.bugs.is_empty():
			patch.cursor = patch.bugs.keys()[0]
			patch.strike()
	if not check(patch.result()["cleared"] and patch.step == Alt.PATCH_STEPS and patch.lives == 3, "repair all bugs to clear"):
		return
	patch.start("patch_day")
	while not patch.finished:
		patch.advance()
	if not check(not patch.result()["cleared"] and patch.lives == 0, "unrepaired bugs crash servers"):
		return
	patch.start("patch_day")
	patch.bugs[patch.cursor]=2
	if not check(patch.strike() and patch.urgent_repairs==1 and patch.repair_combo==1,"urgent repair tracked"):
		return
	var indie := Alt.new()
	indie.start("indie_dev")
	var preview := indie.studio_preview(0)
	if not check(preview["quality"]==3 and preview["energy"]==4 and indie.quality==0,"studio preview is read-only"):
		return
	for action in [0, 0, 1, 2, 0, 1, 3, 2]:
		indie.choice = action
		if not check(indie.strike(), "studio action affordable"):
			return
	if not check(indie.result()["cleared"] and indie.step == Alt.WEEKS and indie.debt == 0, "balanced studio strategy wins"):
		return
	var ending := indie.result()
	if not check(not indie.strike() and indie.result() == ending, "studio ending cannot be replayed for points"):
		return
	indie.start("indie_dev")
	for i in range(3):
		indie.strike()
	if not check(not indie.strike() and indie.step == 3 and indie.energy == 0, "burnout action rejected without advancing week"):
		return
	var gallery := Extra.new()
	gallery.start("annual_warfare")
	gallery.cursor = gallery.target
	if not check(gallery.strike() and gallery.score == 100 and gallery.strike() and gallery.score == 100, "target only scores once"):
		return
	gallery.cursor = gallery.decoy
	if not check(gallery.strike() and gallery.lives == 2 and gallery.strike() and gallery.ammo == 0 and gallery.strike() and gallery.ammo == Extra.MAGAZINE, "fan penalty and free reload"):
		return
	gallery.start("annual_warfare")
	while not gallery.finished:
		if gallery.ammo == 0:
			gallery.strike()
		gallery.cursor = gallery.target
		gallery.strike()
		gallery.advance()
	if not check(gallery.result()["cleared"] and gallery.step == Extra.GALLERY_STEPS, "perfect gallery clears"):
		return
	var puzzle := Extra.new()
	puzzle.start("day_one_dlc")
	for scramble in Extra.SCRAMBLES:
		for i in range(scramble.size()-1,-1,-1):
			var delta: Vector2i = -scramble[i]
			if delta.x != 0:
				puzzle.steer(delta.x)
			else:
				puzzle.vertical(delta.y)
	if not check(puzzle.result()["cleared"] and puzzle.stage == 3 and puzzle.score > 0, "all puzzle packs solvable"):
		return
	var ending_puzzle := puzzle.result()
	puzzle.steer(1)
	if not check(puzzle.result() == ending_puzzle, "finished puzzle immutable"):
		return
	var checklist := Season.new()
	checklist.start("open_world_checklist")
	while not checklist.finished:
		for cell in checklist.icons.keys():
			checklist.cursor = cell
			if not check(checklist.strike() and not checklist.strike(), "map icon scores once"):
				return
		checklist.advance()
	if not check(checklist.result()["cleared"] and checklist.step == Season.CHECK_TICKS, "bounded checklist round"):
		return
	var pass_game := Season.new()
	pass_game.start("battle_pass_hero")
	if not check(not pass_game._command((pass_game.chain[0]+1)%5) and pass_game.progress == 0, "wrong command resets combo"):
		return
	while not pass_game.finished:
		var commands := pass_game.chain.duplicate()
		for command in commands:
			if not check(pass_game._command(command), "season sequence accepted"):
				return
	if not check(pass_game.result()["cleared"] and pass_game.completed == Season.SEASONS, "all seasons clear"):
		return
	pass_game.start("battle_pass_hero")
	while not pass_game.finished:
		pass_game.advance()
	if not check(pass_game.lives == 0 and not pass_game.result()["cleared"], "missed seasons terminate"):
		return
	var classic := Classic.new()
	classic.start("starline_patrol")
	if not check(classic.enemies.size() == 21 and classic.strike() and not classic.strike(), "shooter wave and fire cooldown"):
		return
	classic.shots.clear()
	classic.shots.append(classic.enemies[0]+Vector2(0,Classic.SHOT_SPEED*Classic.DT))
	classic.advance()
	if not check(classic.score == 100 and classic.enemies.size() == 20, "projectile removes exactly one enemy"):
		return
	classic.enemies.clear()
	classic.advance()
	if not check(classic.wave == 2 and classic.enemies.size() == 21, "next shooter wave"):
		return
	classic.start("neon_rebound")
	classic.steer(-1)
	for i in range(100):
		classic.advance()
	if not check(classic.player_x == Classic.PADDLE_HALF and not classic.launched and classic.strike(), "bounded paddle and explicit launch"):
		return
	classic.ball = Vector2(classic.player_x,Classic.SHIP_Y-9)
	classic.velocity = Vector2(0,180)
	classic.advance()
	if not check(classic.velocity.y < 0 and classic.lives == 3, "paddle returns ball"):
		return
	classic.ball = Vector2(35,39)
	classic.velocity = Vector2(0,-180)
	classic.advance()
	if not check(classic.score == 50 and classic.bricks.size() == 39, "brick collision awards once"):
		return
	classic.ball = Vector2(300,Classic.HEIGHT+10)
	classic.velocity = Vector2(0,180)
	classic.advance()
	if not check(classic.lives == 2 and not classic.launched, "lost ball resets to paddle"):
		return
	classic.step = Classic.MAX_TICKS-1
	classic.advance()
	if not check(classic.finished, "bounded classic session"):
		return
	var screen := preload("res://scenes/arcade_pilot.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	if not check(screen.state == "select" and screen.get_node_or_null("CabinetSpeaker") != null and screen.CUES.size() == 4, "cabinet scene loads with one speaker and four cues"):
		return
	screen._start_round()
	if not check(screen.state == "play" and screen.round is Race and not screen.round.finished, "screen launches dedicated race"):
		return
	if not check(screen.race_audio != null and screen.race_audio.engine.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and screen.race_audio.engine.stream.loop_end > 0, "race owns original looping engine sound"):
		return
	screen._show_selection()
	if not check(not screen.race_audio.engine.playing and not screen.race_audio.tires.playing, "abandon stops race audio"):
		return
	if not check(not screen.is_processing(), "abandoned round stops ticking"):
		return
	screen.selection = 3
	screen._start_round()
	if not check(screen.state == "play" and not screen.is_processing() and screen.round.game_id == "indie_dev", "turn-based cabinet has no background timer"):
		return
	for i in range(Alt.WEEKS):
		screen.round.choice = 2
		screen.round.strike()
	screen._finish_if_needed()
	if not check(screen.state == "result" and screen.best.has("indie_dev"), "turn-based result reaches scoreboard"):
		return
	for id in Round.IDS:
		screen._show_selection()
		screen.selection = Round.IDS.find(id)
		screen._start_round()
		if not check(screen.state == "play" and screen.round.game_id == id, "catalog launches " + id):
			return
	screen.queue_free()
	print("ARCADE_SMOKE: PASS")
	quit(0)
