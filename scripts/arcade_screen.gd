extends Control
## Isolated cabinet screen: playable directly or embedded as a single modal later.
## No persistent score, world time, street cred or currency changes in this pilot.
const Round = preload("res://scripts/arcade_round.gd")
const AltRound = preload("res://scripts/arcade_alt_round.gd")
const ExtraRound = preload("res://scripts/arcade_extra_round.gd")
const SeasonRound = preload("res://scripts/arcade_season_round.gd")
const ClassicRound = preload("res://scripts/arcade_classic_round.gd")
const DeluxeView = preload("res://scripts/arcade_grand_delay_view.gd")
var deluxe_view := DeluxeView.new()
var deluxe_lane := 1.0
var deluxe_pulse := 0.0
var deluxe_cabinet: Node3D
const Scores = preload("res://scripts/arcade_scores.gd")
const AudioMix = preload("res://scripts/audio_mix.gd")
const CUES := {
	"start": preload("res://assets/arcade/audio/start.wav"),
	"score": preload("res://assets/arcade/audio/score.wav"),
	"damage": preload("res://assets/arcade/audio/damage.wav"),
	"record": preload("res://assets/arcade/audio/record.wav")
}
var _cue: AudioStreamPlayer
signal exit_requested
signal score_recorded(id: String, value: int)
var round = Round.new()
var selection := 0
var state := "select"
var elapsed := 0.0
var best: Dictionary = {}
var locked_cabinet := ""
var new_record := false

func configure_cabinet(id: String, previous_best: Dictionary) -> bool:
	if not Round.IDS.has(id):
		return false
	locked_cabinet = id
	selection = Round.IDS.find(id)
	best = Scores.normalized(previous_best)
	return true

func _ready() -> void:
	AudioMix.ensure()
	_cue = AudioStreamPlayer.new()
	_cue.name = "CabinetSpeaker"
	_cue.bus = AudioMix.EFFECTS
	_cue.volume_db = -12.0
	add_child(_cue)
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
		if state == "select" and locked_cabinet.is_empty():
			selection = posmod(selection + direction, Round.IDS.size())
		elif state == "play" and not round is ClassicRound:
			var before := Vector2i(round.score,round.lives)
			round.steer(direction)
			_feedback_cue(before)
			_finish_if_needed()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		if state == "play" and (round is AltRound or round is ExtraRound or round is SeasonRound):
			var before := Vector2i(round.score,round.lives)
			round.vertical(-1 if event.is_action_pressed("ui_up") else 1)
			_feedback_cue(before)
			_finish_if_needed()
	elif event.is_action_pressed("ui_accept"):
		deluxe_pulse = 1.0
		match state:
			"select":
				_start_round()
			"play":
				var before := Vector2i(round.score,round.lives)
				round.strike()
				_feedback_cue(before)
				_finish_if_needed()
			"result":
				_show_selection()
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()

func _show_selection() -> void:
	_reset_deluxe_controls()
	state = "select"
	elapsed = 0.0
	set_process(false)
	queue_redraw()

func _start_round() -> void:
	var id: String = Round.IDS[selection]
	if id == "starline_patrol" or id == "neon_rebound":
		round = ClassicRound.new()
	elif id == "open_world_checklist" or id == "battle_pass_hero":
		round = SeasonRound.new()
	elif id == "annual_warfare" or id == "day_one_dlc":
		round = ExtraRound.new()
	elif id == "patch_day" or id == "indie_dev":
		round = AltRound.new()
	else:
		round = Round.new()
	if not round.start(id):
		return
	state = "play"
	deluxe_lane = 1.0
	deluxe_pulse = 0.0
	new_record = false
	_play_cue("start")
	elapsed = 0.0
	set_process(id != "indie_dev" and id != "day_one_dlc")
	queue_redraw()

func _process(delta: float) -> void:
	if round is ClassicRound:
		_process_classic(delta)
		return
	var interval := AltRound.PATCH_SECONDS if round.game_id == "patch_day" else Round.STEP_SECONDS
	if round.game_id == "annual_warfare":
		interval = ExtraRound.GALLERY_SECONDS
	elif round.game_id == "open_world_checklist":
		interval = SeasonRound.CHECK_INTERVAL
	elif round.game_id == "battle_pass_hero":
		interval = SeasonRound.SEASON_INTERVAL
	if round.game_id == "grand_delay":
		deluxe_lane = move_toward(deluxe_lane,float(round.lane),delta*9.0)
		deluxe_pulse = move_toward(deluxe_pulse,0.0,delta*5.0)
		if is_instance_valid(deluxe_cabinet):
			deluxe_cabinet.call("set_deluxe_controls",deluxe_lane,deluxe_pulse)
		queue_redraw()
	# Limit catch-up after a stall; no unfair instant loss of multiple lives.
	elapsed += minf(delta, interval)
	if elapsed >= interval:
		elapsed -= interval
		var before := Vector2i(round.score,round.lives)
		round.advance()
		_feedback_cue(before)
		_finish_if_needed()
		queue_redraw()

func _process_classic(delta: float) -> void:
	# Bounded catch-up. Only the one active cabinet runs these fixed steps.
	elapsed += minf(delta,ClassicRound.DT*4)
	round.steer(int(Input.is_action_pressed("ui_right"))-int(Input.is_action_pressed("ui_left")))
	var before := Vector2i(round.score,round.lives)
	for i in range(4):
		if elapsed < ClassicRound.DT or round.finished:
			break
		elapsed -= ClassicRound.DT
		if round.game_id == "starline_patrol" and Input.is_action_pressed("ui_accept"):
			round.strike()
		round.advance()
	_feedback_cue(before)
	_finish_if_needed()
	queue_redraw()

func _finish_if_needed() -> void:
	if state == "play" and round.finished:
		new_record = Scores.record(best,round.game_id,round.score)
		if new_record:
			_play_cue("record")
			score_recorded.emit(round.game_id,round.score)
		state = "result"
		_reset_deluxe_controls()
		set_process(false)

func _play_cue(id: String) -> void:
	if not is_instance_valid(_cue) or not CUES.has(id):
		return
	_cue.stream = CUES[id]
	_cue.play()

func _feedback_cue(before: Vector2i) -> void:
	if round.lives < before.y:
		_play_cue("damage")
	elif round.score > before.x:
		_play_cue("score")

func _line(message: String, at: Vector2, tint: Color, font_size: int = 20) -> void:
	draw_string(ThemeDB.fallback_font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("10151d"))
	var scale_factor := minf(size.x / 800.0, size.y / 480.0)
	if scale_factor <= 0.0:
		return
	draw_set_transform((size - Vector2(800, 480) * scale_factor) * 0.5, 0.0, Vector2.ONE * scale_factor)
	var id: String = Round.IDS[selection]
	if id == "grand_delay":
		deluxe_view.render(self,clampf(elapsed/Round.STEP_SECONDS,0.0,1.0),deluxe_lane,deluxe_pulse)
		return
	var info: Dictionary = Round.GAMES[id]
	var accent := Color(str(info["color"]))
	draw_rect(Rect2(16, 16, 768, 448), Color("26343e"), false, 2.0)
	_line("INSERT COIN  /  INDEPENDENT CABINET UNION", Vector2(32, 48), Color("a0b0ba"), 16)
	_line(str(info["title"]), Vector2(32, 89), accent, 30)
	_line(str(info["studio"]) + "  /  " + str(info["tagline"]), Vector2(32, 117), Color("e0e6e9"), 17)
	if state == "select":
		_line(str(info["instructions"]), Vector2(32, 190), Color.WHITE, 18)
		_line("NEIGHBORHOOD LEADERBOARD", Vector2(32, 230), accent, 20)
		var board: Array = Scores.board(id,best)
		for i in range(board.size()):
			var record: Array = board[i]
			_line("%d.  %s   %06d" % [i+1,record[0],record[1]], Vector2(32+(i%2)*355,257+floori(float(i)/2.0)*27), accent if record[0] == "YOU" else Color.WHITE, 18)
		_line("<  SELECT CABINET  >  %d / %d" % [selection + 1, Round.IDS.size()] if locked_cabinet.is_empty() else "FREE PRACTICE / NO SERVER REQUIRED", Vector2(32, 325), accent, 22)
		_line("ENTER / A  PLAY     ESC / B  EXIT", Vector2(32, 428), Color.WHITE, 18)
	elif state == "result":
		_line("CREDITS ROLL" if round.result()["cleared"] else "GAME OVER", Vector2(32, 195), accent, 34)
		_line("SCORE  %06d  /  BEST  %06d" % [round.score, int(best.get(id, 0))], Vector2(32, 245), Color.WHITE, 24)
		if new_record:
			_line("NEW PERSONAL BEST!", Vector2(32, 275), accent, 19)
		for row in Scores.circuit_rows(best):
			if row["id"] == id and row["earned"]:
				_line("CIRCUIT STAMP: "+str(row["title"]),Vector2(32,345),Color("69d8c2"),17)
				break
		var joke := "Next-gen features sold separately." if id == "grand_delay" else "Your combat performance is pending stakeholder approval."
		if round is AltRound or round is ExtraRound or round is SeasonRound or round is ClassicRound:
			joke = round.feedback
		_line(joke, Vector2(32, 308), accent, 19)
		_line("ENTER / A  CABINETS     ESC / B  BACK", Vector2(32, 428), Color.WHITE, 18)
	elif id == "patch_day":
		_draw_patch(accent)
	elif id == "indie_dev":
		_draw_studio(accent)
	elif id == "annual_warfare" or id == "day_one_dlc":
		_draw_extra(accent, id == "annual_warfare")
	elif id == "open_world_checklist":
		_draw_checklist(accent)
	elif id == "battle_pass_hero":
		_draw_season(accent)
	elif round is ClassicRound:
		_draw_classic(accent)
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

func _draw_extra(accent: Color, gallery: bool) -> void:
	if gallery:
		_line("SCORE %06d  |  AMMO %d  |  LIFE %d  |  WAVE %02d/%02d" % [round.score,round.ammo,round.lives,round.step + 1,ExtraRound.GALLERY_STEPS],Vector2(32,150),Color.WHITE,18)
	else:
		_line("PACK %d/3  |  MOVES %d/%d  |  SCORE %06d" % [round.stage+1,round.moves,ExtraRound.MOVE_LIMIT,round.score],Vector2(32,150),Color.WHITE,18)
	for y in range(3):
		for x in range(3):
			var cell := Vector2i(x,y)
			var at := Vector2(245+x*105,165+y*68)
			var bounds := Rect2(at,Vector2(95,60))
			draw_rect(bounds,Color("26343e"))
			if gallery:
				if cell == round.target and not round.target_hit:
					draw_circle(at+Vector2(47,27),18.0,Color("ed777e"))
					_line("BOT",at+Vector2(30,33),Color("10151d"),15)
				elif cell == round.decoy:
					_line("FAN",at+Vector2(30,34),Color("69d8c2"),18)
				if cell == round.cursor:
					draw_rect(bounds,accent,false,3.0)
			else:
				var value: int = round.tiles[y*3+x]
				if value == 0:
					draw_rect(bounds,accent,false,2.0)
				else:
					_line("%d" % value,at+Vector2(37,40),accent if value == y*3+x+1 else Color.WHITE,30)
	_line(round.feedback,Vector2(32,391),accent,17)
	_line("ARROWS / D-PAD AIM   ENTER / A FIRE OR RELOAD" if gallery else "ARROWS / D-PAD SLIDE EMPTY SPACE",Vector2(32,428),Color.WHITE,16)
	_line("ESC / B ABANDON",Vector2(570,428),Color("a0b0ba"),16)

func _draw_checklist(accent: Color) -> void:
	_line("SCORE %06d  |  ICONS %d  |  TIME %02d" % [round.score,round.completed,SeasonRound.CHECK_TICKS-round.step],Vector2(32,150),Color.WHITE,18)
	for y in range(SeasonRound.HEIGHT):
		for x in range(SeasonRound.WIDTH):
			var cell := Vector2i(x,y)
			var at := Vector2(145+x*104,165+y*65)
			var bounds := Rect2(at,Vector2(98,59))
			draw_rect(bounds,Color("26343e"))
			draw_line(at+Vector2(0,30),at+Vector2(98,30),Color("3d5260"),2.0)
			draw_line(at+Vector2(49,0),at+Vector2(49,59),Color("3d5260"),2.0)
			if round.icons.has(cell):
				var kind: int = round.icons[cell]
				_line(SeasonRound.TASKS[kind],at+Vector2(9,24),[accent,Color("f1cd82"),Color("ed9db5")][kind],15)
			if cell == round.cursor:
				draw_rect(bounds,accent,false,3.0)
				draw_circle(at+Vector2(49,42),7.0,accent)
	_line(round.feedback,Vector2(32,391),accent,17)
	_line("ARROWS / D-PAD MOVE AND COLLECT",Vector2(32,428),Color.WHITE,16)
	_line("ESC / B ABANDON",Vector2(570,428),Color("a0b0ba"),16)

func _draw_season(accent: Color) -> void:
	_line("SCORE %06d  |  SEASON %d/%d  |  LIVES %d" % [round.score,round.season+1,SeasonRound.SEASONS,round.lives],Vector2(32,150),Color.WHITE,18)
	_line(SeasonRound.OBJECTIVES[round.season],Vector2(32,185),accent,22)
	draw_rect(Rect2(32,200,736,8),Color("26343e"))
	draw_rect(Rect2(32,200,736.0*round.time_left/SeasonRound.SEASON_TICKS,8),accent)
	for i in range(round.chain.size()):
		var at := Vector2(34+i*144,240)
		var bounds := Rect2(at,Vector2(130,76))
		var done: bool = i < round.progress
		var next: bool = i == round.progress
		draw_rect(bounds,Color("35463e") if done else Color("26343e"))
		draw_rect(bounds,accent if next else Color("53606b"),false,3.0 if next else 1.0)
		_line(SeasonRound.COMMANDS[round.chain[i]],at+Vector2(14,44),Color("69d8c2") if done else Color.WHITE,22)
	_line(round.feedback,Vector2(32,391),accent,17)
	_line("ARROWS / D-PAD + ENTER / A MATCH COMMANDS",Vector2(32,428),Color.WHITE,16)
	_line("ESC / B ABANDON",Vector2(570,428),Color("a0b0ba"),16)

func _draw_classic(accent: Color) -> void:
	var origin := Vector2(100,156)
	var area := Rect2(origin,Vector2(ClassicRound.WIDTH,ClassicRound.HEIGHT))
	draw_rect(area,Color("090f18"))
	draw_rect(area,Color("344655"),false,1.0)
	_line("SCORE %06d   /   LIVES %d   /   WAVE %d" % [round.score,round.lives,round.wave],Vector2(100,146),accent,16)
	if round.game_id == "starline_patrol":
		for n in range(32):
			draw_circle(origin+Vector2(posmod(n*137+29,590)+5,posmod(n*71+19,240)+5),1.0,Color("46566b"))
		for enemy in round.enemies:
			var at: Vector2 = origin+enemy
			draw_colored_polygon(PackedVector2Array([at+Vector2(-13,6),at+Vector2(-8,-7),at+Vector2(8,-7),at+Vector2(13,6),at]),Color("e7a0b3"))
		for shot in round.shots:
			draw_rect(Rect2(origin+shot-Vector2(2,5),Vector2(4,10)),accent)
		for shot in round.enemy_shots:
			draw_circle(origin+shot,3.0,Color("f1cd82"))
		var ship := origin+Vector2(round.player_x,ClassicRound.SHIP_Y)
		draw_colored_polygon(PackedVector2Array([ship+Vector2(-13,8),ship+Vector2(0,-11),ship+Vector2(13,8),ship+Vector2(0,3)]),accent)
	else:
		for brick in round.bricks:
			var bounds: Rect2 = brick
			var tint := Color("e79e6a") if bounds.position.y < 50 else Color("72d7cf")
			draw_rect(Rect2(origin+bounds.position,bounds.size),tint)
		draw_rect(Rect2(origin+Vector2(round.player_x-ClassicRound.PADDLE_HALF,ClassicRound.SHIP_Y),Vector2(ClassicRound.PADDLE_HALF*2,7)),accent)
		draw_circle(origin+round.ball,ClassicRound.BALL_RADIUS,Color.WHITE)
		if not round.launched:
			_line("ENTER / A LAUNCH",Vector2(310,310),accent,18)
	_line("HOLD LEFT / RIGHT   ENTER / A FIRE OR LAUNCH",Vector2(32,428),Color.WHITE,16)
	_line("ESC / B ABANDON",Vector2(570,428),Color("a0b0ba"),16)

func bind_deluxe_cabinet(cabinet: Node3D) -> void:
	deluxe_cabinet = cabinet

func _reset_deluxe_controls() -> void:
	deluxe_lane = 1.0
	deluxe_pulse = 0.0
	if is_instance_valid(deluxe_cabinet):
		deluxe_cabinet.call("set_deluxe_controls",1.0,0.0)

func _exit_tree() -> void:
	_reset_deluxe_controls()
