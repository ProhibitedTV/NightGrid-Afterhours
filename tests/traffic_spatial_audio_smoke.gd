extends SceneTree
## Godot integration test for the audio actually attached to the 29-car/bus
## city traffic fleet. Headless tests cannot establish perceived audio quality.
const TrafficAudio = preload("res://scripts/traffic_spatial_audio.gd")
const CarAudio = preload("res://scripts/kestrel_vehicle_audio.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("TRAFFIC_AUDIO_SMOKE: " + reason)
	quit(1)

func _verify() -> void:
	var bus_sound := TrafficAudio.bus_sound()
	if bus_sound == null or TrafficAudio.bus_sound() != bus_sound:
		_fail("Original bus sound must be synthesized only once and cached")
		return
	if bus_sound.format != AudioStreamWAV.FORMAT_16_BITS or bus_sound.data.size() != 44100:
		_fail("Missing valid original 2-second 16-bit bus loop")
		return
	if bus_sound.loop_mode != AudioStreamWAV.LOOP_FORWARD or CarAudio.sound() == null:
		_fail("Missing looping road/transit motor audio")
		return
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Playable scene missing")
		return
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var director := world.get_node_or_null("WorldAudio")
	var soundfield := world.get_node_or_null("WorldAudio/PassingTrafficSoundfield")
	var traffic := world.get_node_or_null("SurfaceTraffic")
	if director == null or soundfield == null or traffic == null:
		_fail("Positional street audio missing from the actual playable world")
		return
	var fleet: Array = traffic.get("fleet")
	if fleet.size() != 29:
		_fail("Spatial sound test requires 25 traffic cars and 4 actual buses")
		return
	var baseline: Dictionary = soundfield.call("get_stats")
	if int(baseline["allocated_voices"]) != 5 or int(baseline["voice_limit"]) != 5:
		_fail("Traffic system allocated one player per vehicle instead of a bounded five-voice pool")
		return
	var car: Node3D = fleet[0]
	var bus: Node3D = traffic.get("buses")[0]
	for vehicle in fleet:
		vehicle.set("speed", 0.0)
	car.set("speed", 10.0)
	bus.set("speed", 8.0)
	bus.set("dwell_remaining", 0.0)
	var point: Vector3 = car.global_position
	bus.global_position = point + Vector3(8.0, 0.0, 0.0)
	soundfield.call("update_listener", point, false, false, 0.7)
	soundfield.call("_refresh_sources")
	var selected: Dictionary = soundfield.call("get_stats")
	if int(selected["active_voices"]) != 2 or int(selected["bus_voices"]) != 1:
		_fail("Moving car and bus did not each obtain a localized voice: " + str(selected))
		return
	if int(selected["allocated_voices"]) != 5:
		_fail("Selecting traffic voices must not allocate new AudioStreamPlayers")
		return
	var voices: Array = soundfield.get("_voices")
	var owners: Array = soundfield.get("_owners")
	var car_found := false
	var bus_found := false
	for index in range(owners.size()):
		var assigned: Node3D = owners[index]
		if assigned == car:
			car_found = true
			if voices[index].stream != CarAudio.sound():
				_fail("Civilian vehicle is not playing its cached original motor")
				return
		if assigned == bus:
			bus_found = true
			if voices[index].stream != bus_sound:
				_fail("Actual city bus is not playing its distinct cached motor")
				return
	if not car_found or not bus_found:
		_fail("3D traffic emitters are detached from their moving sources")
		return
	soundfield.call("_process", 2.0)
	var moving_volume := -80.0
	for index in range(owners.size()):
		if owners[index] == car:
			moving_volume = float(voices[index].volume_db)
	if moving_volume <= -80.0:
		_fail("The passing car remained silent at positive SFX volume")
		return
	soundfield.call("update_listener", point, true, false, 0.7)
	soundfield.call("_process", 2.0)
	var indoor_volume := -80.0
	for index in range(owners.size()):
		if owners[index] == car:
			indoor_volume = float(voices[index].volume_db)
	if indoor_volume >= moving_volume:
		_fail("Interior context did not attenuate passing traffic")
		return
	soundfield.call("update_listener", point, false, true, 0.7)
	soundfield.call("_process", 2.0)
	var riding_volume := -80.0
	for index in range(owners.size()):
		if owners[index] == car:
			riding_volume = float(voices[index].volume_db)
	if riding_volume <= indoor_volume:
		_fail("Passenger traffic must be louder than sealed-indoor traffic")
		return
	bus.set("dwell_remaining", 7.0)
	car.set("speed", 0.0)
	soundfield.call("_refresh_sources")
	soundfield.call("_process", 0.8)
	if int(soundfield.call("get_stats")["active_voices"]) != 0:
		_fail("Stationary cars and buses at a stop must release their voices")
		return
	# A far-away owner is also culled when the soundfield moves to another
	# district. Near-overlap selections never exceed the fixed pool capacity.
	for index in range(7):
		var actor: Node3D = fleet[index]
		actor.global_position = point + Vector3(float(index) * 2.0, 0.0, 0.0)
		actor.set("speed", 9.0)
	soundfield.call("update_listener", point, false, false, 0.7)
	soundfield.call("_refresh_sources")
	if int(soundfield.call("get_stats")["active_voices"]) != 5:
		_fail("Seven nearby vehicles must be limited to five audio sources")
		return
	soundfield.call("update_listener", Vector3(9000.0, 0.0, 9000.0), false, false, 0.7)
	soundfield.call("_refresh_sources")
	soundfield.call("_process", 0.8)
	if int(soundfield.call("get_stats")["active_voices"]) != 0:
		_fail("Remote vehicles still consume audible voices")
		return
	# Changing saved SFX volume should be routed through WorldAudio and
	# applied to street emitters on the following listener update.
	director.call("set_preferences", 0.65, 0.0)
	director.call("update_context", point, point, true, true, false, "GLASSLINE", 20.0, 0.0)
	if absf(float(soundfield.get("_effects_volume"))) > 0.001:
		_fail("Mute control is not propagated to passing vehicle sound")
		return
	print("TRAFFIC_AUDIO_SMOKE PASS: original cached car/bus loops, 5-voice cap, motion, stop, indoor attenuation and SFX mute")
	quit(0)
