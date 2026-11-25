extends SceneTree
const Round = preload("res://scripts/arcade_round.gd")
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
	screen.queue_free()
	print("ARCADE_SMOKE: PASS")
	quit(0)
