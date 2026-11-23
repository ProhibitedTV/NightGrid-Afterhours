extends RefCounted
## Shared recordings, mixed only for the occupied car and its short exit tail.

const Mix = preload("res://scripts/audio_mix.gd")
const ENGINE = [
	preload("res://assets/audio/road_cars/cinder_idle.wav"),
	preload("res://assets/audio/road_cars/cinder_mid.wav"),
	preload("res://assets/audio/road_cars/cinder_load.wav"),
]
const ASPHALT = preload("res://assets/audio/road_cars/tire_asphalt.wav")
const SPRAY = preload("res://assets/audio/road_cars/tire_spray.wav")
const OPEN = preload("res://assets/audio/road_cars/door_unlatch.wav")
const LATCH = preload("res://assets/audio/road_cars/door_latch.wav")
const RATIOS = [460.0, 298.0, 219.0, 172.0, 139.0, 111.0] # RPM per m/s
const SILENT = -80.0

var _engine: Array[AudioStreamPlayer3D] = []
var _asphalt: AudioStreamPlayer3D
var _spray: AudioStreamPlayer3D
var _door: AudioStreamPlayer3D
var _load := 0.0
var _rpm := 850.0
var _gear := 0
var _shift := 0.0
var _mixing := false

func mount(parent: Node3D) -> void:
	for sample in ENGINE:
		var name := &"EnginePrimary" if _engine.is_empty() else &"EngineRPM"
		_engine.append(_voice(parent, name, sample, Vector3(0.0, -0.22, 1.32)))
	_asphalt = _voice(parent, &"TireContact", ASPHALT, Vector3(0.0, -0.68, 0.68))
	_spray = _voice(parent, &"TireSpray", SPRAY, Vector3(0.0, -0.68, 1.22))
	_door = _voice(parent, &"DoorLatch", null, Vector3.ZERO)
	_door.max_distance = 19.0

func _voice(parent: Node3D, name: StringName, sample: AudioStreamWAV, point: Vector3) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = name
	voice.bus = Mix.EFFECTS
	voice.position = point
	voice.unit_size = 4.9
	voice.max_distance = 39.0
	voice.volume_db = SILENT
	voice.stream = sample
	parent.add_child(voice, true)
	return voice

func door_moved(point: Vector3, opening: bool) -> void:
	_door.position = point
	_door.stream = OPEN if opening else LATCH
	_door.pitch_scale = 1.12
	_door.volume_db = -10.0 if opening else -6.0
	_door.play()

func update(speed: float, steer: float, braking: bool, occupied: bool,
		throttle: float, wetness: float, delta: float) -> void:
	if not occupied and not _mixing:
		return
	var moving := absf(speed)
	var smoothing := 1.0 - exp(-14.0 * delta)
	_load = lerpf(_load, absf(throttle) if occupied and not braking else 0.0, smoothing)
	_mix_engine(moving, speed < -0.2, occupied, delta, smoothing)
	var travel := smoothstep(0.5, 31.0, moving)
	var scrub := smoothstep(3.0, 18.0, moving) * maxf(absf(steer) * .69, 0.82 if braking else 0.0)
	var wet := smoothstep(.13, .84, wetness)
	var tire_db := lerpf(-40.0, -13.0, sqrt(travel)) + scrub * 6.0
	var rolling := smoothstep(.26, 2.6, moving) if occupied else 0.0
	_mix(_asphalt, tire_db + _db(rolling * lerpf(1.0, .57, wet)), 0.78 + travel * .42, delta, smoothing)
	_mix(_spray, tire_db + _db(rolling * wet) - 1.6, 0.79 + travel * .37, delta, smoothing)
	_mixing = occupied or _asphalt.playing or _spray.playing
	for voice in _engine:
		_mixing = _mixing or voice.playing

func _mix_engine(speed: float, reversing: bool, occupied: bool, delta: float, smoothing: float) -> void:
	var level := -17.0 + _load * 8.0
	var ratio: float = RATIOS[_gear]
	if reversing:
		_gear = 0
	elif _gear < RATIOS.size() - 1 and speed * ratio > lerpf(4370.0, 6850.0, _load):
		_gear += 1
		_shift = .15
	elif _gear > 0 and speed * ratio < lerpf(1550.0, 2450.0, _load):
		_gear -= 1
	var coupling := _load * 1550.0 * (1.0 - smoothstep(1.0, 9.0, speed))
	_rpm = lerpf(_rpm, clampf(speed * float(RATIOS[_gear]) + coupling, 850.0, 7250.0), smoothing)
	_shift = maxf(0.0, _shift - delta)
	level -= _shift * 31.0
	var mid := smoothstep(1120.0, 2790.0, _rpm)
	var high := smoothstep(3620.0, 5650.0, _rpm)
	_mix(_engine[0], level - 4.0 + _db(1.0 - mid) if occupied else SILENT, _rpm / 850.0, delta, smoothing)
	_mix(_engine[1], level + _db(mid * (1.0 - high)) if occupied else SILENT, _rpm / 3590.0, delta, smoothing)
	_mix(_engine[2], level + 2.0 + _db(high) if occupied else SILENT, _rpm / 4830.0, delta, smoothing)


func _db(amplitude: float) -> float:
	return linear_to_db(maxf(0.0001, amplitude))

func _mix(voice: AudioStreamPlayer3D, target_db: float, pitch: float, delta: float, smoothing: float) -> void:
	if not voice.playing and target_db > -50.0:
		# Fade in from audibility without waiting on a newly allocated stream.
		voice.volume_db = minf(-52.0, target_db - 15.0)
		voice.pitch_scale = clampf(pitch, .48, 1.85)
		voice.play()
	if voice.playing:
		voice.pitch_scale = lerpf(voice.pitch_scale, clampf(pitch, .48, 1.85), smoothing)
		voice.volume_db = move_toward(voice.volume_db, maxf(target_db, SILENT), delta * 210.0)
		if voice.volume_db <= -58.0 and target_db <= -58.0:
			voice.stop()
