extends Control
## Original studio ident. This is the launch scene, not part of world reloads.
## No full-screen flashes, external video codecs or per-frame audio generation.
signal finished
const EMBLEM = preload("res://assets/branding/bitriver_emblem.svg")
const GAME_SCENE = "res://scenes/main.tscn"
const STUDIO = "BitRiver Gaming"
const CREDIT = "by RhythmicCarnage"
const DURATION = 3.2
const IMPACT_AT = 0.52
const RATE = 22050
const INK = Color("080d13")
const STEEL = Color("e7edf0")
const CYAN = Color("81e0d4")
const PINK = Color("d35d86")
@export var auto_handoff := true
var elapsed := 0.0
var _finished := false
var _loading := false
var _requested := false
var _sting_started := false
var _sting: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	# Explicit diagnostic mode. No world creation, saves, or normal intro handoff.
	if auto_handoff and "--verify-creator-pck" in OS.get_cmdline_user_args():
		set_process(false)
		_verify_creator_pck.call_deferred()
		return
	if auto_handoff and (DisplayServer.get_name() == "headless" or "--skip-studio-intro" in OS.get_cmdline_user_args()):
		_finish.call_deferred()
		return
	if auto_handoff:
		_requested = ResourceLoader.load_threaded_request(GAME_SCENE, "PackedScene") == OK
	if DisplayServer.get_name() != "headless" and auto_handoff:
		_prepare_audio()

func _verify_creator_pck() -> void:
	var cast = load("res://scripts/synaxis_creator_cast.gd")
	if cast == null:
		push_error("CREATOR_PCK FAIL: verifier unavailable")
		get_tree().quit(1)
		return
	get_tree().quit(0 if cast.verify_packaged_candidates() else 1)

func _process(delta: float) -> void:
	if _loading:
		_poll_game()
		return
	_advance(delta)

func _advance(delta: float) -> void:
	if _finished:
		return
	elapsed = minf(DURATION, elapsed + maxf(0.0, delta))
	if not _sting_started and elapsed >= IMPACT_AT:
		_sting_started = true
		if is_instance_valid(_sting):
			_sting.play()
	if elapsed >= DURATION:
		_finish()
	else:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if _finished or not event.is_pressed() or event.is_echo():
		return
	var skip := false
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		skip = key in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]
	elif event is InputEventJoypadButton:
		skip = event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]
	elif event is InputEventMouseButton:
		skip = event.button_index == MOUSE_BUTTON_LEFT
	if skip:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	if is_instance_valid(_sting):
		_sting.stop()
	finished.emit()
	if not auto_handoff:
		set_process(false)
		return
	_loading = true
	queue_redraw()
	_poll_game.call_deferred()

func _poll_game() -> void:
	if not _loading:
		return
	var next: PackedScene
	if _requested:
		var status := ResourceLoader.load_threaded_get_status(GAME_SCENE)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			next = ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if next == null:
		next = load(GAME_SCENE) as PackedScene
	_loading = false
	set_process(false)
	if next == null:
		push_error("BitRiver startup could not load the game scene.")
		get_tree().quit(1)
		return
	var error := get_tree().change_scene_to_packed(next)
	if error != OK:
		push_error("BitRiver startup scene handoff failed: %d" % error)
		get_tree().quit(1)

func _prepare_audio() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	var master := clampf(float(config.get_value("player", "master_volume", 0.8)), 0.0, 1.0)
	var sfx := clampf(float(config.get_value("player", "sfx_volume", 0.75)), 0.0, 1.0)
	if master <= 0.0 or sfx <= 0.0:
		return
	_sting = AudioStreamPlayer.new()
	_sting.name = "OriginalStudioSting"
	_sting.stream = make_sting()
	_sting.volume_db = linear_to_db(master * sfx) - 8.0
	add_child(_sting)

## Original deterministic 1.2 second impact, brushed metal noise and low tone.
## Generated once at startup; no third-party music or recordings.
static func make_sting() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	var frames := roundi(RATE * 1.2)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 782134
	var filtered := 0.0
	for i in range(frames):
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.09)
		var hit := sin(TAU * (52.0 * t + 2.6 * (1.0 - exp(-18.0 * t)))) * exp(-5.6 * t) * 0.48
		var scrape := (noise * 0.11 + filtered * 0.25) * exp(-10.0 * t)
		var tail := sin(TAU * 196.0 * t) * exp(-4.0 * t) * 0.05
		var envelope := minf(1.0, t / 0.008) * clampf((1.2 - t) / 0.12, 0.0, 1.0)
		data.encode_s16(i * 2, roundi(clampf((hit + scrape + tail) * envelope, -0.85, 0.85) * 32767.0))
	stream.data = data
	return stream

func _center_text(value: String, at: Vector2, font_size: int, tint: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at + Vector2(-width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	var center := size * 0.5
	var unit := minf(size.x / 1920.0, size.y / 1080.0)
	if unit <= 0.0:
		return
	if _loading:
		_center_text("Loading Morrow Bay", center, maxi(12, roundi(22 * unit)), Color("8b9da6"))
		return
	var t := elapsed
	var reveal := smoothstep(0.10, 0.85, t)
	var settle := smoothstep(0.30, 0.98, t)
	var fade := 1.0 - smoothstep(2.64, DURATION, t)
	var mark_size := 330.0 * unit
	var mark_center := center + Vector2(0, -106 * unit)
	var mark_rect := Rect2(mark_center - Vector2.ONE * mark_size * 0.5, Vector2.ONE * mark_size)
	# Narrow moving signal line, then the original emblem assembles in strips.
	# No rapid screen-wide luminance changes.
	var line_y := mark_rect.position.y + mark_size * reveal
	draw_line(Vector2(center.x - 290 * unit, line_y), Vector2(center.x + 290 * unit, line_y), Color(CYAN, 0.25 * (1.0 - settle) * fade), maxf(1.0, unit), true)
	for i in range(8):
		var strip_alpha := smoothstep(0.08 + i * 0.052, 0.40 + i * 0.052, t) * fade
		var shift := sin(i * 2.3 + 0.7) * 110.0 * unit * (1.0 - settle)
		var dst := Rect2(mark_rect.position + Vector2(shift, i * mark_size / 8.0), Vector2(mark_size, mark_size / 8.0))
		var src := Rect2(0, i * 64.0, 512, 64)
		draw_texture_rect_region(EMBLEM, dst, src, Color(1, 1, 1, strip_alpha))
	var title_alpha := smoothstep(0.70, 1.13, t) * fade
	var credit_alpha := smoothstep(1.08, 1.48, t) * fade
	_center_text(STUDIO, center + Vector2(0, 145 * unit), maxi(12, roundi(64 * unit)), Color(STEEL, title_alpha))
	var rule_width := 228 * unit * smoothstep(0.92, 1.40, t)
	var rule_y := center.y + 174 * unit
	draw_line(Vector2(center.x - rule_width, rule_y), Vector2(center.x + rule_width, rule_y), Color(CYAN, credit_alpha * 0.7), maxf(1.0, 2 * unit), true)
	_center_text(CREDIT, center + Vector2(0, 222 * unit), maxi(10, roundi(26 * unit)), Color(CYAN, credit_alpha))
	# Two restrained moving corner accents give a mechanical lock-in feel.
	for side in [-1.0, 1.0]:
		var anchor := mark_center + Vector2(side * (210.0 + 50.0 * (1.0 - settle)) * unit, side * 140.0 * unit)
		draw_line(anchor, anchor + Vector2(-side * 26 * unit, 0), Color(PINK, reveal * fade * 0.65), maxf(1.0, 2 * unit), true)
		draw_line(anchor, anchor + Vector2(0, -side * 26 * unit), Color(PINK, reveal * fade * 0.65), maxf(1.0, 2 * unit), true)
	_center_text("Enter / A / Click to skip", Vector2(center.x, size.y - 42 * unit), maxi(10, roundi(17 * unit)), Color(STEEL, 0.35 * reveal * fade))
