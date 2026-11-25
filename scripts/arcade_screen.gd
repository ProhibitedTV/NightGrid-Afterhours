extends Control
## Isolated cabinet screen: playable directly or embedded as a single modal later.
## No persistent score, world time, street cred or currency changes in this pilot.
const Round = preload("res://scripts/arcade_round.gd")
const AltRound = preload("res://scripts/arcade_alt_round.gd")
signal exit_requested
var round = Round.new()
var selection := 0
var state := "select"
var elapsed := 0.0
var best: Dictionary = {}

func _ready() -> void:
	set_process(false)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		if state == "select":
			exit_requested.emit()
		else:
			_show_selection()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var direction := -1 if event.is_action_pressed("ui_left") else 1
		if state == "select":
			selection = posmod(selection + direction, Round.IDS.size())
		elif state == "play":
			round.steer(direction)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		if state == "play" and round is AltRound:
			round.vertical(-1 if event.is_action_pressed("ui_up") else 1)
	elif event.is_action_pressed("ui_accept"):
		match state:
			"select":
				_start_round()
			"play":
				round.strike()
				_finish_if_needed()
			"result":
				_show_selection()
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()

func _show_selection() -> void:
	state = "select"
	elapsed = 0.0
	set_process(false)
	queue_redraw()

func _start_round() -> void:
	var id: String = Round.IDS[selection]
	round = AltRound.new() if id == "patch_day" or id == "indie_dev" else Round.new()
	if not round.start(id):
		return
	state = "play"
	elapsed = 0.0
	set_process(id != "indie_dev")
	queue_redraw()

func _process(delta: float) -> void:
	var interval := AltRound.PATCH_SECONDS if round.game_id == "patch_day" else Round.STEP_SECONDS
	# Limit catch-up after a stall; no unfair instant loss of multiple lives.
	elapsed += minf(delta, interval)
	if elapsed >= interval:
		elapsed -= interval
		round.advance()
		_finish_if_needed()
		queue_redraw()

func _finish_if_needed() -> void:
	if state == "play" and round.finished:
		best[round.game_id] = maxi(int(best.get(round.game_id, 0)), round.score)
		state = "result"
		set_process(false)

func _line(message: String, at: Vector2, tint: Color, font_size: int = 20) -> void:
	draw_string(ThemeDB.fallback_font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("10151d"))
	var scale_factor := minf(size.x / 800.0, size.y / 480.0)
	if scale_factor <= 0.0:
		return
	draw_set_transform((size - Vector2(800, 480) * scale_factor) * 0.5, 0.0, Vector2.ONE * scale_factor)
	var id: String = Round.IDS[selection]
	var info: Dictionary = Round.GAMES[id]
	var accent := Color(str(info["color"]))
	draw_rect(Rect2(16, 16, 768, 448), Color("26343e"), false, 2.0)
	_line("INSERT COIN  /  INDEPENDENT CABINET UNION", Vector2(32, 48), Color("a0b0ba"), 16)
	_line(str(info["title"]), Vector2(32, 89), accent, 30)
	_line(str(info["studio"]) + "  /  " + str(info["tagline"]), Vector2(32, 117), Color("e0e6e9"), 17)
	if state == "select":
		_line(str(info["instructions"]), Vector2(32, 190), Color.WHITE, 18)
		_line("LOCAL BEST  %06d" % int(best.get(id, 0)), Vector2(32, 235), accent, 24)
		_line("<  SELECT CABINET  >  %d / %d" % [selection + 1, Round.IDS.size()], Vector2(32, 325), accent, 22)
		_line("ENTER / A  PLAY     ESC / B  EXIT", Vector2(32, 428), Color.WHITE, 18)
	elif state == "result":
		_line("CREDITS ROLL" if round.result()["cleared"] else "GAME OVER", Vector2(32, 195), accent, 34)
		_line("SCORE  %06d  /  BEST  %06d" % [round.score, int(best.get(id, 0))], Vector2(32, 245), Color.WHITE, 24)
		var joke := "Next-gen features sold separately." if id == "grand_delay" else "Your combat performance is pending stakeholder approval."
		if round is AltRound:
			joke = round.feedback
		_line(joke, Vector2(32, 308), accent, 19)
		_line("ENTER / A  CABINETS     ESC / B  BACK", Vector2(32, 428), Color.WHITE, 18)
	elif id == "patch_day":
		_draw_patch(accent)
	elif id == "indie_dev":
		_draw_studio(accent)
	else:
		_line("SCORE %06d  |  LIFE %d  |  WAVE %02d/%02d" % [round.score, round.lives, round.step, Round.ROUND_STEPS], Vector2(32, 150), Color.WHITE, 18)
		for n in range(Round.LANES):
			draw_rect(Rect2(220 + n * 120, 167, 116, 235), Color("192832"))
			draw_line(Vector2(278 + n * 120, 167), Vector2(278 + n * 120, 402), Color("344b55"), 2.0)
		for item in round.objects:
			var center := Vector2(278 + int(item["lane"]) * 120, 184 + int(item["row"]) * 40)
			var good: bool = item["kind"] == "feature"
			var tint := Color("63e3ad") if good else Color("ee727e")
			draw_rect(Rect2(center - Vector2(24, 13), Vector2(48, 26)), tint, false, 3.0)
			_line("DLC" if item["kind"] == "paywall" else ("+" if good else "BOT"), center + Vector2(-18, 6), tint, 14)
		var player_center := Vector2(278 + round.lane * 120, 384)
		draw_rect(Rect2(player_center - Vector2(22, 13), Vector2(44, 26)), accent)
		if id == "claw_compliance":
			draw_rect(Rect2(player_center - Vector2(28, 100), Vector2(56, 100)), accent, false, 1.0)
		_line("ARROWS / D-PAD  MOVE    ENTER / A  STRIKE" if id == "claw_compliance" else "ARROWS / D-PAD  STEER", Vector2(32, 428), Color.WHITE, 16)
		_line("ESC / B  ABANDON", Vector2(570, 428), Color("a0b0ba"), 16)

func _draw_patch(accent: Color) -> void:
	_line("SCORE %06d  |  SERVERS %d  |  TICK %02d/%02d" % [round.score, round.lives, round.step, AltRound.PATCH_STEPS], Vector2(32, 150), Color.WHITE, 18)
	for y in range(AltRound.ROWS):
		for x in range(AltRound.COLS):
			var cell := Vector2i(x, y)
			var at := Vector2(180 + x * 110, 170 + y * 65)
			var bounds := Rect2(at, Vector2(100, 55))
			draw_rect(bounds, Color("202633"))
			if round.bugs.has(cell):
				var ttl: int = round.bugs[cell]
				var tint := Color("ed777e") if ttl <= 2 else Color("f4bd70")
				_line("BUG %d" % ttl, at + Vector2(12, 30), tint, 19)
				draw_rect(Rect2(at + Vector2(8, 43), Vector2(ttl * 16, 4)), tint)
			else:
				_line("OK", at + Vector2(35, 31), Color("69d8c2"), 16)
			if cell == round.cursor:
				draw_rect(bounds, accent, false, 3.0)
	_line(round.feedback, Vector2(32, 391), accent, 17)
	_line("ARROWS / D-PAD  MOVE    ENTER / A  REPAIR", Vector2(32, 428), Color.WHITE, 16)
	_line("ESC / B  ABANDON", Vector2(570, 428), Color("a0b0ba"), 16)

func _draw_studio(accent: Color) -> void:
	_line("WEEK %d/%d   QUALITY %d   BUGS %d   ENERGY %d   FANS %d" % [round.step + 1, AltRound.WEEKS, round.quality, round.debt, round.energy, round.fans], Vector2(32, 150), Color.WHITE, 18)
	_line("Goal: quality 9+, bugs 2 or fewer, fans 3+", Vector2(32, 182), accent, 17)
	for n in range(AltRound.ACTIONS.size()):
		var at := Vector2(32, 196 + n * 40)
		var tint := accent if n == round.choice else Color("a0b0ba")
		draw_rect(Rect2(at, Vector2(736, 36)), Color("26343e"))
		if n == round.choice:
			draw_rect(Rect2(at, Vector2(736, 36)), tint, false, 2.0)
		_line(AltRound.ACTIONS[n], at + Vector2(12, 24), tint, 19)
		_line(AltRound.DETAILS[n], at + Vector2(180, 24), Color.WHITE, 17)
	_line(round.feedback, Vector2(32, 391), accent, 17)
	_line("LEFT / RIGHT  CHOOSE    ENTER / A  COMMIT WEEK", Vector2(32, 428), Color.WHITE, 16)
	_line("ESC / B  ABANDON", Vector2(570, 428), Color("a0b0ba"), 16)
