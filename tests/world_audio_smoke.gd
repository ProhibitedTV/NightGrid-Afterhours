extends SceneTree
## Runtime test for deterministic generated WAVs, footfall distance scheduling,
## ambience identity and persisted SFX/ambience settings. Listening requires QA.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("WORLD_AUDIO_SMOKE: " + message)
	quit(1)

func _verify() -> void:
	var Foley = load("res://scripts/city_foley.gd")
	for kind in ["WIND", "TRAFFIC", "INDUSTRIAL", "WATER", "STEP_CONCRETE", "STEP_TILE", "UI"]:
		var stream: AudioStreamWAV = Foley.sound(kind)
		if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.data.size() <= 1000:
			_fail("Missing or invalid original audio layer: " + kind)
			return
		if Foley.sound(kind) != stream:
			_fail("Waveform generation must be cached, not repeated on the render frame")
			return
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Missing game scene")
		return
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var director := world.get_node_or_null("WorldAudio")
	var menu := world.get_node_or_null("GameMenus")
	var player: CharacterBody3D = world.get("player")
	if director == null or menu == null or player == null:
		_fail("Audio director, menus or character are missing")
		return
	var stats: Dictionary = director.call("get_audio_stats")
	if int(stats["environment_layers"]) != 4:
		_fail("Expected four city atmosphere buses")
		return
	var bank: Dictionary = director.get("_step_bank")
	if bank.size() != 4 or not bank.values().all(func(samples: Array) -> bool:
		return samples.size() == 4 and samples.all(func(clip: AudioStream) -> bool: return clip.get_length() > 0.2)):
		_fail("Expected four distinct prewarmed recordings for each pavement class")
		return
	director.call("set_preferences", 0.65, 0.75)
	director.call("update_context", Vector3.ZERO, Vector3.ZERO,
		true, true, false, "SOUTHWORKS", 22.0, 8.0)
	var industry_db := float(director.call("_target_db", "INDUSTRIAL"))
	var sea_db := float(director.call("_target_db", "WATER"))
	if industry_db <= sea_db + 10.0:
		_fail("Southworks needs a distinct audible industrial bed")
		return
	director.call("update_context", Vector3.ZERO, Vector3.ZERO,
		true, true, true, "SOUTHWORKS", 22.0, 0.0)
	if float(director.call("_target_db", "INDUSTRIAL")) >= industry_db - 10.0:
		_fail("Interior entry should substantially attenuate the outside bed")
		return
	director.call("_process", 1.0)
	if float((director.call("get_audio_stats") as Dictionary)["exterior_cutoff"]) > 1400.0:
		_fail("The interior bus must lose outdoor high frequencies")
		return
	director.call("update_context", Vector3.ZERO, Vector3.ZERO,
		true, true, false, "GLASSLINE", 13.0, 7.5)
	director.call("update_context", Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		true, true, false, "GLASSLINE", 13.0, 7.5)
	director.call("update_context", Vector3(2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0),
		true, true, false, "GLASSLINE", 13.0, 7.5)
	if int((director.call("get_audio_stats") as Dictionary)["steps"]) != 1:
		_fail("Two meters of walking should trigger one non-frame-count-driven footstep")
		return
	director.call("update_context", Vector3(250.0, 0.0, 0.0), Vector3(250.0, 0.0, 0.0),
		true, true, false, "GLASSLINE", 13.0, 7.5)
	if int((director.call("get_audio_stats") as Dictionary)["steps"]) != 1:
		_fail("Teleport must not emit a burst of phantom footsteps")
		return
	var saved: Dictionary = menu.call("get_settings")
	menu.call("update_setting", "ambience_volume", 0.4)
	menu.call("update_setting", "sfx_volume", 0.2)
	menu.call("update_setting", "dialogue_volume", 0.34)
	if absf(float(director.get("ambience_volume")) - 0.4) > 0.001 or absf(float(director.get("sfx_volume")) - 0.2) > 0.001:
		_fail("Audio settings are not applied to the live soundscape")
		return
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK or absf(float(config.get_value("player", "sfx_volume", -1.0)) - 0.2) > 0.001 or (
			absf(float(config.get_value("player", "dialogue_volume", -1.0)) - 0.34) > 0.001):
		_fail("SFX preferences did not persist")
		return
	for key in saved:
		menu.call("update_setting", key, saved[key])
	print("WORLD_AUDIO_SMOKE PASS: original cached effects, four district layers, footsteps, teleport and settings")
	quit(0)
