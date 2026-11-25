extends SceneTree
## Genuine graphical capture of the shipped ident; no replacement art.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("STUDIO_CAPTURE requires a graphical display")
		quit(1)
		return
	var output := OS.get_environment("STUDIO_CAPTURE_OUT")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("STUDIO_CAPTURE output directory unavailable")
		quit(1)
		return
	var intro = load("res://scenes/studio_intro.tscn").instantiate()
	intro.auto_handoff = false
	root.add_child(intro)
	intro.set_process(false)
	await process_frame
	var previous := 0.0
	for shot in [{"t": 0.36, "name": "01-signal.png"}, {"t": 0.95, "name": "02-impact.png"}, {"t": 1.8, "name": "03-studio.png"}]:
		var at := float(shot["t"])
		intro._advance(at - previous)
		previous = at
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		if frame == null or frame.is_empty() or frame.save_png(output.path_join(str(shot["name"]))) != OK:
			push_error("STUDIO_CAPTURE framebuffer read/write failed")
			quit(1)
			return
		print("STUDIO_CAPTURED ", shot["name"], " ", frame.get_size())
	print("STUDIO_CAPTURE PASS: three actual Godot frames")
	quit(0)
