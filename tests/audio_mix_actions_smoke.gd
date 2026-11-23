extends SceneTree
## Issue #33: verify real routing, bounded one-shot cue lifecycle, and
## interactions in the playable game, not merely synthetic audio helpers.
## This cannot establish headphone sound quality or platform loudness.
const AudioMix = preload("res://scripts/audio_mix.gd")
const Foley = preload("res://scripts/city_foley.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("AUDIO_MIX_ACTIONS_SMOKE: " + reason)
	quit(1)

func _count(director: Node) -> int:
	return int((director.call("get_audio_stats") as Dictionary)["action_cues"])

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable main scene is unavailable")
		return
	var game := packed.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	if not AudioMix.is_routed():
		_fail("Independent audio stems do not send to Master")
		return
	var total_buses := AudioServer.get_bus_count()
	AudioMix.ensure()
	if AudioServer.get_bus_count() != total_buses:
		_fail("Scene reload or repeated ensure created duplicate buses")
		return
	var fm := game.get_node_or_null("NightGridFM")
	var menu := game.get_node_or_null("GameMenus")
	var director := game.get_node_or_null("WorldAudio")
	var car: Node3D = (game.get("cars") as Array)[0]
	if fm == null or menu == null or director == null or car == null:
		_fail("An active game audio subsystem is missing")
		return
	var decks: Array = fm.get("_decks")
	if decks.size() != 2:
		_fail("NightGrid FM does not retain its two music decks")
		return
	for deck in decks:
		if (deck as AudioStreamPlayer).bus != AudioMix.MUSIC:
			_fail("Radio music is bypassing the music stem")
			return
	if (fm.get("_venue") as AudioStreamPlayer3D).bus != AudioMix.STREET_MUSIC:
		_fail("Outdoor venue soundtrack is bypassing the music stem")
		return
	if (menu.get("_ui_click") as AudioStreamPlayer).bus != AudioMix.UI:
		_fail("Menu selection does not use its own UI stem")
		return
	for kind in ["WIND", "TRAFFIC", "INDUSTRIAL", "WATER"]:
		var bed := director.get_node_or_null("MorrowBay_" + kind) as AudioStreamPlayer
		if bed == null or bed.bus != AudioMix.OUTSIDE_BEDS:
			_fail("City background is not routed independently: " + kind)
			return
	var venues := game.get_node_or_null("SocialVenues")
	if venues == null:
		_fail("Venue system missing")
		return
	for emitter in (venues.get("_ambience") as Dictionary).values():
		if (emitter as AudioStreamPlayer3D).bus != AudioMix.OUTSIDE_BEDS:
			_fail("Outdoor venue ambience bypasses the ambient stem")
			return
	var step := director.get_node_or_null("CourierFootsteps") as AudioStreamPlayer3D
	if step == null or step.bus != AudioMix.EFFECTS:
		_fail("Player footsteps are not on WorldSFX")
		return
	var traffic := director.get_node_or_null("PassingTrafficSoundfield")
	if traffic == null:
		_fail("Spatial traffic soundfield is missing")
		return
	for voice in traffic.get("_voices"):
		if (voice as AudioStreamPlayer3D).bus != AudioMix.OUTSIDE_EFFECTS:
			_fail("A moving traffic source bypassed the effects stem")
			return
	var motor := car.get_node_or_null("KestrelS6HeroVisual/OriginalElectricDrivetrain") as AudioStreamPlayer3D
	if motor == null or motor.bus != AudioMix.EFFECTS:
		_fail("Player car drivetrain does not use the effects stem")
		return
	var rail := game.get_node_or_null("MorrowLine/MorrowLineTrain/CicadaM8HeroVisual")
	if rail == null:
		_fail("M-Line train visual is missing")
		return
	var rail_sound := rail.get_node_or_null("OriginalRailRollingLoop") as AudioStreamPlayer3D
	if rail_sound == null or rail_sound.bus != AudioMix.EFFECTS:
		_fail("M-Line train audio does not use the effects stem")
		return
	var voices: Array = director.get("_events")
	var radio := game.get_node("PoliceRadio")
	for property in ["_voice", "_local_voice"]:
		if radio.get(property).bus != AudioMix.DIALOGUE:
			_fail("The local and player dispatch receivers need an independent dialogue stem")
			return
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	if not InputMap.action_has_event("radio_toggle", key) or not InputMap.action_has_event("radio_toggle", pad):
		_fail("Keyboard and gamepad radio power bindings must both be installed")
		return
	if voices.size() != 4:
		_fail("Action sounds must use four bounded pooled voices")
		return
	for voice in voices:
		if (voice as AudioStreamPlayer3D).bus != AudioMix.EFFECTS:
			_fail("An action voice bypasses WorldSFX")
			return
	for kind in ["DOOR", "TRANSIT", "PICKUP", "DELIVERY", "JUMP", "LAND"]:
		var audio := Foley.sound(kind)
		if audio == null or audio.data.size() < 1000 or Foley.sound(kind) != audio:
			_fail("A one-shot is missing or not cached: " + kind)
			return
	director.call("set_preferences", 0.65, 0.8)
	var ambience_bus := AudioServer.get_bus_index(AudioMix.AMBIENCE)
	var effects_bus := AudioServer.get_bus_index(AudioMix.EFFECTS)
	if AudioServer.is_bus_mute(ambience_bus) or AudioServer.is_bus_mute(effects_bus):
		_fail("Audible settings left gameplay stems muted")
		return
	if absf(AudioServer.get_bus_volume_db(ambience_bus) - linear_to_db(0.65)) > 0.02 or (
			absf(AudioServer.get_bus_volume_db(effects_bus) - linear_to_db(0.8)) > 0.02):
		_fail("Global audio bus gains do not match the saved sliders")
		return
	var origin := _count(director)
	var next_voice := int(director.get("_event_cursor"))
	director.call("play_event", "DOOR", Vector3(1.0, 1.0, 2.0))
	if _count(director) != origin + 1:
		_fail("Vehicle-door cue did not play")
		return
	var first := voices[next_voice] as AudioStreamPlayer3D
	if first.stream != Foley.sound("DOOR") or first.global_position.distance_to(Vector3(1.0, 1.0, 2.0)) > 0.01:
		_fail("Door sound does not follow its physical source")
		return
	# Real courier delivery and vehicle entry/exit must call the shared director.
	game.call("_advance_mission")
	game.call("_advance_mission")
	if _count(director) != origin + 3:
		_fail("Delivery objective transitions did not trigger pickup and completion cues")
		return
	var player := game.get("player") as CharacterBody3D
	player.global_position = car.global_position
	game.call("_toggle_car")
	if game.get("current_car") == null or _count(director) != origin + 4:
		_fail("Entering a vehicle did not trigger its door sound")
		return
	game.call("_toggle_car")
	if game.get("current_car") != null or _count(director) != origin + 5:
		_fail("Exiting a parked vehicle did not trigger its door sound")
		return
	# Explicit context changes are independent of FPS, and a standing
	# character does not produce a stream of extra jump/land cues.
	var at := Vector3(12.0, 1.0, 12.0)
	# A headless spawn can begin without floor contact until the first physics
	# tick; establish a known grounded baseline before asserting transitions.
	director.set("_has_foot", false)
	director.set("_grounded", true)
	director.call("update_context", at, at, true, true, false, "SOUTHWORKS", 22.0, 0.0, 0.0)
	director.call("update_context", at, at, true, false, false, "SOUTHWORKS", 22.0, 0.0, 8.0)
	director.call("update_context", at, at, true, true, false, "SOUTHWORKS", 22.0, 0.0, -5.0)
	if _count(director) != origin + 7:
		_fail("Takeoff and landing did not produce one event each")
		return
	for iteration in range(10):
		director.call("update_context", at, at, true, true, false, "SOUTHWORKS", 22.0, 0.0, 0.0)
	if _count(director) != origin + 7:
		_fail("Stationary audio incorrectly depends on render-frame count")
		return
	director.call("set_preferences", 0.0, 0.0)
	if not AudioServer.is_bus_mute(ambience_bus) or not AudioServer.is_bus_mute(effects_bus):
		_fail("Masterless audio stems still play when ambience or effects are muted")
		return
	director.call("play_event", "TRANSIT", at)
	if _count(director) != origin + 7:
		_fail("Saved SFX mute is not respected for action sounds")
		return
	director.call("set_preferences", 0.65, 0.75)
	print("AUDIO_MIX_ACTIONS_SMOKE PASS: routed stems, acoustic buses, dispatch, 4 pooled cues, mission/car/jump/land and idempotence")
	quit(0)
