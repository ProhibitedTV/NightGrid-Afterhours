extends SceneTree
const Round = preload("res://scripts/arcade_round.gd")
const Alt = preload("res://scripts/arcade_alt_round.gd")
const Extra = preload("res://scripts/arcade_extra_round.gd")
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
	var indie := Alt.new()
	indie.start("indie_dev")
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
	var screen := preload("res://scenes/arcade_pilot.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	if not check(screen.state == "select", "cabinet scene loads"):
		return
	screen._start_round()
	if not check(screen.state == "play" and not screen.round.finished, "screen launches title"):
		return
	screen._show_selection()
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
	screen.queue_free()
	print("ARCADE_SMOKE: PASS")
	quit(0)
