extends SceneTree
const Intro = preload("res://scripts/studio_intro.gd")
const Scene = preload("res://scenes/studio_intro.tscn")

func _initialize() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void: _fail("startup watchdog"))
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("STUDIO_INTRO_SMOKE: " + message)
	quit(1)

func _verify() -> void:
	if ProjectSettings.get_setting("application/run/main_scene") != "res://scenes/studio_intro.tscn":
		_fail("Shipped entry point must use the studio ident")
		return
	var intro = Scene.instantiate()
	intro.auto_handoff = false
	root.add_child(intro)
	intro.set_process(false)
	var hits := [0]
	intro.finished.connect(func() -> void: hits[0] += 1)
	intro._advance(0.51)
	if intro._sting_started or hits[0] != 0:
		_fail("Audio impact or finish occurred early")
		return
	intro._advance(0.02)
	if not intro._sting_started:
		_fail("Impact cue missing")
		return
	intro._advance(2.5)
	if hits[0] != 0:
		_fail("Intro ended before intended duration")
		return
	intro._advance(0.2)
	intro._advance(10.0)
	intro._finish()
	if hits[0] != 1 or not is_equal_approx(intro.elapsed, Intro.DURATION):
		_fail("Timed completion must happen exactly once")
		return
	intro.free()
	for mode in ["key", "pad", "mouse"]:
		var skip_intro = Scene.instantiate()
		skip_intro.auto_handoff = false
		root.add_child(skip_intro)
		skip_intro.set_process(false)
		var skip_hits := [0]
		skip_intro.finished.connect(func() -> void: skip_hits[0] += 1)
		var event: InputEvent
		match mode:
			"key":
				var key := InputEventKey.new()
				key.physical_keycode = KEY_ENTER
				key.pressed = true
				event = key
			"pad":
				var pad := InputEventJoypadButton.new()
				pad.button_index = JOY_BUTTON_A
				pad.pressed = true
				event = pad
			"mouse":
				var mouse := InputEventMouseButton.new()
				mouse.button_index = MOUSE_BUTTON_LEFT
				mouse.pressed = true
				event = mouse
		skip_intro._input(event)
		skip_intro._input(event)
		if skip_hits[0] != 1 or not skip_intro._finished:
			_fail("Skip did not complete exactly once for " + mode)
			return
		skip_intro.free()
	var sound := Intro.make_sting()
	if sound.mix_rate != Intro.RATE or sound.data.size() != roundi(Intro.RATE * 1.2) * 2 or sound.data != Intro.make_sting().data or sound.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		_fail("Original audio must be finite, deterministic and non-looping")
		return
	if sound.data.decode_s16(0) != 0:
		_fail("Audio should start without a discontinuity")
		return
	# Launch the actual shipping scene. In headless CI it must bypass the
	# splash and enter the existing world, with no extra title or save flag.
	if change_scene_to_file("res://scenes/studio_intro.tscn") != OK:
		_fail("Unable to launch shipping scene")
		return
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.name == "NightgridWorld":
			if current_scene.get_node_or_null("GameMenus") == null:
				_fail("World did not build its existing menu")
				return
			print("STUDIO_INTRO_SMOKE PASS: duration, one-shot skip, deterministic sting, headless world handoff")
			quit(0)
			return
	_fail("Headless startup did not hand off to actual world")
