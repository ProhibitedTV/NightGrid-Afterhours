extends SceneTree
## Capture the actual Godot master mix from a repeatable Windows gameplay run.
## Scenario changes use permanent world addresses and the live gameplay methods.
const Game = preload("res://scenes/main.tscn")
const AudioMix = preload("res://scripts/audio_mix.gd")
var game: Node3D
var menu: CanvasLayer
var player: CharacterBody3D
var fm: Node
var sound: Node
var clock: Node
var record := AudioEffectRecord.new()
var master: int
var effect_index: int
var output: String
var captures: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	create_timer(180.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_run")

func _run() -> void:
	output = OS.get_environment("NIGHTGRID_AUDIO_EVIDENCE_DIR")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		push_error("Use Windows native audio and a new absolute evidence path")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	game = Game.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	menu = game.get_node("GameMenus")
	game.set_process_input(false)
	player = game.get("player")
	fm = game.get_node("NightGridFM")
	sound = game.get_node("WorldAudio")
	clock = game.get("day_night")
	clock.set("paused", true)
	var options: Dictionary = menu.call("get_settings")
	options.merge({"master_volume":0.80, "music_volume":0.65, "ambience_volume":0.65,
		"sfx_volume":0.75, "dialogue_volume":0.82, "radio_on":true, "vsync_enabled":false,
		"ssr_enabled":true, "ao_enabled":true, "glow_enabled":true, "fog_enabled":true}, true)
	menu.set("settings", options)
	game.call("_apply_game_settings", options)
	master = AudioServer.get_bus_index("Master")
	effect_index = AudioServer.get_bus_effect_count(master)
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(master, record)
	_expect(fm.call("available_tracks") == 20, "The twenty original tracks must be imported")
	await _title()
	if "--nearby-pedestrians" in OS.get_cmdline_user_args():
		await _nearby_pedestrians()
	else:
		await _brickwater()
		await _cafe_and_club()
		await _drive()
		await _transit()
		await _dispatch()
		await _harbor()
	AudioServer.remove_bus_effect(master, effect_index)
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({
		"revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"seed": root.get_node("GameSession").get("world_seed"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"output_device": AudioServer.get_output_device(),
		"mix_rate": AudioServer.get_mix_rate(),
		"captures": captures, "failures": failures
	}, "\t"))
	file.close()
	print("MORROW_BAY_AUDIO_CAPTURE ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout

func _clock(hour: float) -> void:
	clock.call("set_hour", hour)
	game.get_node("SocialVenues").call("set_hour", hour)
	game.get_node("CivicServices").call("set_hour", hour)

func _place(at: Vector3, yaw: float = 0.0) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	game.set("yaw", yaw)
	game.set("pitch", 0.38)
	game.get_node("CityDetails").call("set_focus", at)
	game.call("_snap_camera")

func _finish(label: String, details: Dictionary = {}) -> void:
	record.set_recording_active(false)
	var audio := record.get_recording()
	_expect(audio != null and audio.get_length() > 1.0 and audio.save_to_wav(output.path_join(label + ".wav")) == OK,
		"Missing native master audio for " + label)
	var row := {"scenario": label, "file": label + ".wav", "seconds": audio.get_length() if audio != null else 0.0,
		"music": fm.call("playback_stats"), "soundscape": sound.call("get_audio_stats"), "details":details}
	captures.append(row)
	print("MORROW_BAY_AUDIO_SCENE ", JSON.stringify(row))
	await process_frame

func _title() -> void:
	menu.call("open_title")
	record.set_recording_active(true)
	await _wait(2.8)
	var state: Dictionary = fm.call("playback_stats")
	_expect(state["track"] == "boot_sequence" and state["context"] == "title", "Title playback must use Boot Sequence")
	menu.call("hide_for_game")
	await _wait(1.25)
	await _finish("01-title-and-fade", {"title_track":state["track"]})

func _brickwater() -> void:
	_clock(22.10)
	_place(Vector3(-87.0, 1.29, 82.0), PI)
	await _wait(1.0)
	var before: Dictionary = sound.call("get_audio_stats")
	record.set_recording_active(true)
	Input.action_press("move_forward", 0.46)
	await _wait(1.4)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	Input.action_release("move_forward")
	await _wait(1.5)
	var after: Dictionary = sound.call("get_audio_stats")
	_expect(after["district"] == "BRICKWATER" and after["steps"] > before["steps"],
		"Actual Brickwater movement must produce footsteps and district context")
	await _finish("02-brickwater-sidewalk-and-vents")

func _nearby_pedestrians() -> void:
	var director: Node3D = game.get("pedestrians")
	if not is_instance_valid(director):
		_expect(false, "Use --living-streets to record passing residents")
		return
	_clock(12.0)
	_place(Vector3(-18.5, 1.18, -37), PI * 0.5)
	await _wait(4.1)
	var initial: Dictionary = director.call("active_positions")
	await _wait(0.4)
	var moving: Dictionary = director.call("active_positions")
	var resident := Vector3.INF
	var direction := Vector3.ZERO
	var distance := INF
	for id in moving:
		if not initial.has(id):
			continue
		var at: Vector3 = moving[id]
		var displacement: Vector3 = at - initial[id]
		var nearby := at.distance_squared_to(player.global_position)
		if nearby < distance and displacement.length_squared() > 0.04:
			resident = at
			direction = displacement.normalized()
			distance = nearby
	if not resident.is_finite():
		_expect(false, "Could not find a moving resident near the Brickwater start")
		return
	_place(resident - direction * 3.5 + Vector3.UP * 1.10, atan2(-direction.x, -direction.z))
	await _wait(0.4)
	var previous: Dictionary = sound.call("get_audio_stats")
	record.set_recording_active(true)
	await _wait(8.0)
	var current: Dictionary = sound.call("get_audio_stats")
	var initial_steps := int(previous["sites"]["pedestrian_steps"])
	var footsteps := int(current["sites"]["pedestrian_steps"]) - initial_steps
	_expect(footsteps > 0 and current["steps"] == previous["steps"],
		"A stationary courier must hear footsteps from active residents")
	await _finish("09-brickwater-daytime-pedestrians", {"resident_steps": footsteps, "courier_steps": 0,
		"courier_at": str(player.global_position), "resident_start": str(resident), "residents": director.call("stats")})

func _cafe_and_club() -> void:
	var venues := game.get_node("SocialVenues")
	var interiors := game.get_node("Interiors")
	for site in [["lantern_cup", 12.0, "cafe"], ["static_room", 22.5, "club"]]:
		_clock(site[1])
		var entry: Vector3 = venues.call("venue_position", site[0])
		_place(entry)
		record.set_recording_active(true)
		await _wait(1.9)
		var street: Dictionary = fm.call("playback_stats")
		var street_seconds: float = (fm.get("_venue") as AudioStreamPlayer3D).get_playback_position()
		game.call("_toggle_interior")
		await _wait(1.6)
		_expect(interiors.call("active_site_id") == site[0], "Could not enter the actual " + site[0])
		var inside: Dictionary = fm.call("playback_stats")
		var inside_seconds := (fm.get("_front") as AudioStreamPlayer).get_playback_position()
		_expect(str(inside["context"]).begins_with("interior:" + site[2]) and inside["track"] == street["venue_track"],
			"Street music must retain its track at " + site[0])
		_expect(inside_seconds > street_seconds + 0.6, "Venue handoff must preserve its audible playhead")
		_expect(float((sound.call("get_audio_stats") as Dictionary)["exterior_cutoff"]) < 1400.0,
			"Doorway must muffle the exterior bed")
		Input.action_press("move_forward", 0.40)
		await _wait(1.4)
		Input.action_release("move_forward")
		_expect((sound.call("get_audio_stats") as Dictionary)["surface"] == "TILE", "Interior movement must select recorded tile steps")
		await _finish("03-cafe-doorway" if site[2] == "cafe" else "04-club-doorway",
			{"street_track":street["venue_track"], "room_track":inside["track"],
			 "street_playhead":street_seconds, "room_playhead":inside_seconds})
		player.global_position = interiors.call("get_entry_point")
		game.call("_toggle_interior")
		await _wait(0.4)

func _drive() -> void:
	_clock(21.5)
	var car: CharacterBody3D = game.get("cars")[0]
	car.global_position = Vector3(2.8, 0.80, 223.0)
	car.rotation = Vector3.ZERO
	car.set("speed", 0.0)
	car.set_meta("claimed", true)
	_place(car.global_position + Vector3(-1.65, 0.4, 0.0))
	record.set_recording_active(true)
	game.call("_toggle_car")
	await _wait(2.0)
	var tuned: Dictionary = fm.call("playback_stats")
	_expect(tuned["context"] == "car" and not str(tuned["track"]).is_empty(), "The Kestrel must tune to the original station")
	var recorder: RefCounted = game.get("frame_time_recorder")
	var stream: Dictionary = game.get_node("CityDetails").call("get_streaming_stats")
	recorder.begin_capture(stream["loads"], stream["stage_steps"], stream["total_build_usec"])
	var start := car.global_position
	Input.action_press("drive_accelerate")
	await _wait(2.7)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_N
	keyboard.pressed = true
	game.call("_unhandled_input", keyboard)
	await _wait(1.25)
	var skipped: Dictionary = fm.call("playback_stats")
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_DPAD_UP
	controller.pressed = true
	game.call("_unhandled_input", controller)
	await _wait(1.25)
	var pad: Dictionary = fm.call("playback_stats")
	Input.action_release("drive_accelerate")
	Input.action_press("drive_brake")
	await _wait(1.0)
	Input.action_release("drive_brake")
	recorder.end_capture()
	var csv: String = recorder.export_csv(output.path_join("southworks-f8.csv"))
	_expect(not csv.is_empty() and start.distance_to(car.global_position) > 20.0, "The measured car needs a real traversal")
	_expect(skipped["track"] != tuned["track"] and pad["track"] != skipped["track"], "Keyboard and mapped pad skip must advance the station")
	var before_pause: Dictionary = fm.call("playback_stats")
	menu.call("open_pause")
	await _wait(0.85)
	var paused: Dictionary = fm.call("playback_stats")
	menu.call("hide_for_game")
	await _wait(0.65)
	_expect(paused["track"] == before_pause["track"] and float(paused["music_gain"]) < float(before_pause["music_gain"]) * 0.8,
		"Pause must duck the playing track without replacing it")
	var snapshot: Dictionary = game.call("_capture_snapshot")
	_expect(snapshot.get("nightgrid_radio", {}).get("track", "") == pad["track"], "Car tuning must be saved with the playhead")
	await _finish("05-southworks-engine-brake-and-fm", {"keyboard_track":skipped["track"], "controller_track":pad["track"],
		"distance_m":start.distance_to(car.global_position), "f8_frames":recorder.captured_frames(), "paused_gain":paused["music_gain"]})
	car.set("speed", 0.0)
	game.call("_toggle_car")
	await _wait(0.3)

func _transit() -> void:
	var rail := game.get_node("MorrowLine")
	var traffic := game.get_node("SurfaceTraffic")
	var buses: Array = traffic.get("buses")
	var bus: CharacterBody3D = buses[0]
	bus.set("speed", 0.0)
	bus.set("dwell_remaining", 5.0)
	_place(bus.global_position + Vector3(3.0, 0.0, 0.0))
	record.set_recording_active(true)
	game.call("_toggle_transit")
	_expect(game.get("transit_kind") == "BUS", "Must board an actual stopped city bus")
	await _wait(1.1)
	game.call("_toggle_transit")
	await _wait(0.65)
	rail.call("restore", {"x":232.0, "current_station":4, "next_station":3, "direction":-1, "dwell":6.0})
	_place(rail.call("alight_position", true))
	await physics_frame
	game.call("_toggle_transit")
	_expect(game.get("transit_kind") == "TRAIN", "Must board at the actual East Gardens platform door")
	await _wait(0.65)
	rail.call("restore", {"x":129.0, "current_station":4, "next_station":3, "direction":-1, "speed":6.0})
	await _wait(3.0)
	await _finish("06-city-loop-and-m-line")
	rail.call("restore", {"x":116.0, "current_station":3, "next_station":2, "direction":-1, "dwell":4.0})
	game.call("_toggle_transit")

func _dispatch() -> void:
	_clock(13.0)
	var service := game.get_node("CivicServices")
	_place(service.call("position_for", "police_hq"))
	game.call("_toggle_interior")
	var ledger: RefCounted = game.get("ambient_civic")
	ledger.call("advance", 21.0)
	clock.set("paused", false)
	record.set_recording_active(true)
	await _wait(0.8)
	var radio := game.get_node("PoliceRadio")
	var local: bool = radio.get("_local_voice").playing
	_expect(local, "Live civic requests must play through the precinct's positional receiver")
	await _wait(2.6)
	await _finish("07-mbpd-live-receiver", {"positional_receiver":local, "clips":radio.call("voice_count")})

func _harbor() -> void:
	var interiors := game.get_node("Interiors")
	player.global_position = interiors.call("get_entry_point")
	game.call("_toggle_interior")
	_clock(5.5)
	_place(Vector3(-221.0, 1.22, 38.0))
	await _wait(1.3)
	record.set_recording_active(true)
	await _wait(3.2)
	var scene: Dictionary = sound.call("get_audio_stats")
	_expect(scene["district"] == "WEST DOCKS" and int(scene["sites"]["active_sites"]) > 0,
		"The harbor recording must come from an active West Docks emitter")
	await _finish("08-west-docks-harbor")
