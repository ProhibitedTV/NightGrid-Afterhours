extends Node3D
const AudioMix = preload("res://scripts/audio_mix.gd")
## Five reusable positional voices for the entire moving street fleet.
## Only audible nearby vehicles play; no AudioStreamPlayer is allocated per car.
## Waveform synthesis is original and cached, never done in _process.
const CarAudio = preload("res://scripts/kestrel_vehicle_audio.gd")
const VOICE_LIMIT = 5
const REFRESH_SECONDS = 0.18
const START_DISTANCE = 52.0
const KEEP_DISTANCE = 67.0
const MIN_SPEED = 1.0
const FADE_DB_PER_SECOND = 42.0
const BUS_SAMPLE_RATE = 11025
const BUS_SAMPLE_FRAMES = 22050

static var _bus_loop: AudioStreamWAV

var traffic: Node3D
var _listener := Vector3.ZERO
var _inside := false
var _riding := false
var _effects_volume := 0.75
var _refresh_clock := 0.0
var _voices: Array[AudioStreamPlayer3D] = []
var _owners: Array[Node3D] = []
var _reassignments := 0

static func bus_sound() -> AudioStreamWAV:
	if _bus_loop != null:
		return _bus_loop
	# Original electric-bus running motor + softly modulated road/tire bed.
	# Loop is 2s and tapered at both ends to avoid audible discontinuities.
	var data := PackedByteArray()
	data.resize(BUS_SAMPLE_FRAMES * 2)
	var generator := RandomNumberGenerator.new()
	generator.seed = 663214
	var road_smooth := 0.0
	for index in range(BUS_SAMPLE_FRAMES):
		var t := float(index) / float(BUS_SAMPLE_RATE)
		road_smooth = lerpf(road_smooth, generator.randf_range(-1.0, 1.0), 0.34)
		var motor := sin(TAU * 62.0 * t) * 0.039 + sin(TAU * 124.0 * t) * 0.014
		var harmonic := sin(TAU * 248.0 * t) * 0.008
		var tire := road_smooth * 0.024 + generator.randf_range(-1.0, 1.0) * 0.010
		var fade := clampf(minf(float(index), float(BUS_SAMPLE_FRAMES - 1 - index)) / 220.0, 0.0, 1.0)
		var signed := clampi(roundi((motor + harmonic + tire) * fade * 32767.0), -32768, 32767)
		var packed := signed if signed >= 0 else signed + 65536
		data[index * 2] = packed & 255
		data[index * 2 + 1] = (packed >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = BUS_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = BUS_SAMPLE_FRAMES
	stream.data = data
	_bus_loop = stream
	return stream

func _ready() -> void:
	# The original EV audio is shared with existing Kestrel hero vehicles.
	# The bus receives a separate lower-frequency bed but uses the same cache.
	var car_loop := CarAudio.sound()
	var bus_loop := bus_sound()
	for index in range(VOICE_LIMIT):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "PassingTrafficVoice_%d" % index
		AudioMix.ensure()
		voice.bus = AudioMix.EFFECTS
		voice.max_distance = 74.0
		voice.unit_size = 6.0
		voice.volume_db = -80.0
		voice.stream = car_loop if index < 3 else bus_loop
		add_child(voice)
		_voices.append(voice)
		_owners.append(null)

func set_traffic(root: Node3D) -> void:
	traffic = root

func update_listener(at: Vector3, indoors: bool, riding: bool, sfx_volume: float) -> void:
	_listener = at
	_inside = indoors
	_riding = riding
	_effects_volume = clampf(sfx_volume, 0.0, 1.0)

func _candidate_vehicles() -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	if not is_instance_valid(traffic):
		return matches
	var fleet: Array = traffic.get("fleet")
	for object in fleet:
		var actor := object as Node3D
		if not is_instance_valid(actor):
			continue
		var speed: float = absf(float(actor.get("speed")))
		if speed < MIN_SPEED:
			continue
		# Buses must be silent while dwelling, even if a snapshot briefly
		# restores a previous rolling speed before its physics tick.
		var bus: bool = bool(actor.get("buses"))
		if bus and float(actor.get("dwell_remaining")) > 0.05:
			continue
		var gap := Vector2(actor.global_position.x - _listener.x,
			actor.global_position.z - _listener.z).length()
		if gap > KEEP_DISTANCE:
			continue
		matches.append({
			"vehicle": actor, "distance": gap,
			"id": str(actor.get("vehicle_id")), "bus": bus
		})
	matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["distance"]) - float(b["distance"])) > 0.01:
			return float(a["distance"]) < float(b["distance"])
		return str(a["id"]) < str(b["id"]))
	return matches

func _refresh_sources() -> void:
	var candidates := _candidate_vehicles()
	var target: Array[Node3D] = []
	# Keep an already audible source while it remains within the closest
	# seven moving vehicles. Hysteresis avoids panning/sample resets each
	# time two cars pass at the same intersection.
	for owner in _owners:
		if not is_instance_valid(owner):
			continue
		for rank in range(mini(candidates.size(), VOICE_LIMIT + 2)):
			if candidates[rank]["vehicle"] == owner and float(candidates[rank]["distance"]) <= KEEP_DISTANCE:
				if not target.has(owner):
					target.append(owner)
				break
	# Fill remaining voices with nearest approaching sources.
	for candidate in candidates:
		if target.size() >= VOICE_LIMIT:
			break
		if float(candidate["distance"]) > START_DISTANCE:
			continue
		var actor: Node3D = candidate["vehicle"]
		if not target.has(actor):
			target.append(actor)
	# Release owners no longer selected before assigning the new ones.
	for i in range(_owners.size()):
		if _owners[i] != null and not target.has(_owners[i]):
			_owners[i] = null
			_voices[i].stop()
			_voices[i].volume_db = -80.0
	for owner in target:
		if _owners.has(owner):
			continue
		for i in range(_owners.size()):
			if _owners[i] == null:
				_owners[i] = owner
				var bus: bool = bool(owner.get("buses"))
				var voice: AudioStreamPlayer3D = _voices[i]
				voice.stream = bus_sound() if bus else CarAudio.sound()
				voice.global_position = owner.global_position + Vector3(0.0, 0.55, 0.0)
				voice.volume_db = -80.0
				voice.play()
				_reassignments += 1
				break

func _process(delta: float) -> void:
	_refresh_clock += delta
	if _refresh_clock >= REFRESH_SECONDS:
		_refresh_clock = fposmod(_refresh_clock, REFRESH_SECONDS)
		_refresh_sources()
	for index in range(_owners.size()):
		var source: Node3D = _owners[index]
		if not is_instance_valid(source):
			continue
		var voice: AudioStreamPlayer3D = _voices[index]
		voice.global_position = source.global_position + Vector3(0.0, 0.55, 0.0)
		var speed := absf(float(source.get("speed")))
		var bus: bool = bool(source.get("buses"))
		var moving := speed >= MIN_SPEED and (not bus or float(source.get("dwell_remaining")) <= 0.05)
		var target_db := -80.0
		if moving and _effects_volume > 0.0:
			target_db = (-16.5 if bus else -19.0) + linear_to_db(_effects_volume)
			if _inside:
				target_db -= 18.0
			elif _riding:
				target_db -= 9.0
			target_db += clampf((speed - 7.0) * 0.45, -4.5, 4.0)
		voice.volume_db = move_toward(voice.volume_db, target_db, FADE_DB_PER_SECOND * delta)
		voice.pitch_scale = clampf((0.80 if bus else 0.89) + speed * 0.014, 0.75, 1.38)

func get_stats() -> Dictionary:
	var active := 0
	var bus_voices := 0
	for owner in _owners:
		if is_instance_valid(owner):
			active += 1
			if bool(owner.get("buses")):
				bus_voices += 1
	return {
		"voice_limit": VOICE_LIMIT, "allocated_voices": _voices.size(),
		"active_voices": active, "bus_voices": bus_voices,
		"reassignments": _reassignments,
		"distinct_cached_sounds": 2 if _bus_loop != null and CarAudio.sound() != null else 0
	}
