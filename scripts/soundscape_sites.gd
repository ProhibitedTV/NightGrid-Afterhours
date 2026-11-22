extends Node3D
## Fixed, authored emitters share two loop voices across streamed places.
const Mix = preload("res://scripts/audio_mix.gd")
const Foley = preload("res://scripts/city_foley.gd")
const SITES = [
	{"at":Vector3(-88, 2.3, 88.5), "sound":"VENT", "db":-8.0},
	{"at":Vector3(-79, 1.6, 79.5), "sound":"SERVICE", "db":-13.0, "night":true},
	{"at":Vector3(-33, 1.7, -68), "sound":"SERVICE", "db":-15.0, "day":true},
	{"at":Vector3(94, 2.6, -63), "sound":"VENT", "db":-17.0},
	{"at":Vector3(29, 1.9, 12.4), "sound":"SERVICE", "db":-19.0, "night":true},
	{"at":Vector3(-224, 1.1, 38), "sound":"HARBOR", "db":-8.0},
	{"at":Vector3(-198, 2.6, -32), "sound":"VENT", "db":-17.0},
	{"at":Vector3(126, 1.2, -221), "sound":"HARBOR", "db":-8.0},
	{"at":Vector3(204, 2.8, 40), "sound":"GARDEN", "db":-17.0},
	{"at":Vector3(-23, 2.1, 196), "sound":"VENT", "db":-13.0},
	{"at":Vector3(84, 2.3, 194), "sound":"SERVICE", "db":-15.0}
]
const LOOP_LIMIT = 2
const FOOT_LIMIT = 2
const PERIOD = 0.20
const QUIET = -64.0

var pedestrians: Node3D
var listener := Vector3.ZERO
var hour := 12.0
var indoor := false
var muted := false
var _clock := 0.0
var _owners: Array[int] = [-1, -1]
var _selected: Array[int] = [-1, -1]
var _targets: Array[float] = [QUIET, QUIET]
var _voices: Array[AudioStreamPlayer3D] = []
var _feet: Array[AudioStreamPlayer3D] = []
var _streams := {}
var _foot_samples: Array[AudioStream] = []
var _previous := {}
var _walked := {}
var _foot_index := 0
var _occluded := 0
var _paused_mix := false

func _ready() -> void:
	for key in ["VENT", "SERVICE", "GARDEN"]:
		_streams[key] = Foley.sound(key)
	var harbor := load("res://assets/audio/morrow_bay/harbor.ogg") as AudioStreamOggVorbis
	if harbor != null:
		harbor.loop = true
	_streams["HARBOR"] = harbor if harbor != null else Foley.sound("WATER")
	for index in range(LOOP_LIMIT):
		_voices.append(_voice(Mix.OUTSIDE_BEDS, 42.0, 6.0))
	for index in range(FOOT_LIMIT):
		_feet.append(_voice(Mix.OUTSIDE_EFFECTS, 15.0, 2.0))

func _voice(bus: String, radius: float, unit: float) -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	source.bus = bus
	source.max_distance = radius
	source.unit_size = unit
	source.volume_db = QUIET
	add_child(source)
	return source

func configure_steps(bank: Array[AudioStream]) -> void:
	_foot_samples = bank

func set_context(at: Vector3, local_hour: float, inside: bool, effects_muted: bool, paused_mix: bool) -> void:
	listener = at
	hour = local_hour
	indoor = inside
	muted = effects_muted
	_paused_mix = paused_mix

func _update_sites() -> void:
	var available: Array[int] = []
	var nighttime := hour >= 18.5 or hour < 6.5
	if not indoor:
		for index in range(SITES.size()):
			var site: Dictionary = SITES[index]
			var at: Vector3 = site["at"]
			if (site.get("night", false) and not nighttime) or (site.get("day", false) and nighttime):
				continue
			if at.distance_squared_to(listener) <= 41.0 * 41.0:
				available.append(index)
		available.sort_custom(func(a: int, b: int) -> bool:
			return (SITES[a]["at"] as Vector3).distance_squared_to(listener) < (SITES[b]["at"] as Vector3).distance_squared_to(listener))
	available.resize(mini(LOOP_LIMIT, available.size()))
	for slot in range(LOOP_LIMIT):
		var owner := _owners[slot]
		_selected[slot] = owner if owner in available else -1
	for index in available:
		if not index in _selected:
			_selected[_selected.find(-1)] = index
	var space := get_world_3d().direct_space_state
	_occluded = 0
	for slot in range(LOOP_LIMIT):
		var next := _selected[slot]
		_targets[slot] = QUIET
		if next < 0:
			continue
		var site: Dictionary = SITES[next]
		var ray := PhysicsRayQueryParameters3D.create(listener + Vector3.UP * 0.35, site["at"], 1)
		var result := space.intersect_ray(ray)
		var blocked := result.get("collider") is StaticBody3D and (result["position"] as Vector3).distance_to(site["at"]) > 0.40
		_occluded += int(blocked)
		_targets[slot] = float(site["db"]) - (15.0 if blocked else 0.0) - (13.0 if _paused_mix else 0.0)

func _update_feet() -> void:
	if muted or indoor or _paused_mix or not is_instance_valid(pedestrians) or _foot_samples.is_empty():
		_previous.clear()
		_walked.clear()
		return
	var positions: Dictionary = pedestrians.call("active_positions")
	for id in _walked.keys():
		if not positions.has(id):
			_walked.erase(id)
	for id in positions:
		var at: Vector3 = positions[id]
		if at.distance_squared_to(listener) > 13.0 * 13.0 or not _previous.has(id):
			continue
		var gap := Vector2(at.x - _previous[id].x, at.z - _previous[id].z).length()
		if gap > 0.04 and gap < 1.7:
			_walked[id] = float(_walked.get(id, 0.0)) + gap
		if float(_walked.get(id, 0.0)) < 1.36:
			continue
		_walked[id] = 0.0
		var voice := _feet[_foot_index % FOOT_LIMIT]
		if not voice.playing:
			voice.stream = _foot_samples[_foot_index % _foot_samples.size()]
			voice.global_position = at
			voice.pitch_scale = 0.88 + float(_foot_index % 5) * 0.035
			voice.volume_db = -17.0
			voice.play()
			_foot_index += 1
	_previous = positions

func _process(delta: float) -> void:
	_clock += delta
	if _clock >= PERIOD:
		_clock = fposmod(_clock, PERIOD)
		_update_sites()
		_update_feet()
	for slot in range(LOOP_LIMIT):
		var voice := _voices[slot]
		var next := _selected[slot]
		var target := _targets[slot] if _owners[slot] == next else QUIET
		voice.volume_db = move_toward(voice.volume_db, target, delta * 105.0)
		if voice.volume_db > QUIET + 0.5 or _owners[slot] == next:
			continue
		voice.stop()
		_owners[slot] = next
		if next >= 0:
			var site: Dictionary = SITES[next]
			voice.global_position = site["at"]
			voice.stream = _streams[site["sound"]]
			voice.play()

func stats() -> Dictionary:
	var playing := 0
	for voice in _voices:
		playing += int(voice.playing)
	return {"site_voice_limit": LOOP_LIMIT, "active_sites": playing, "occluded_sites": _occluded,
		"pedestrian_voice_limit": FOOT_LIMIT, "pedestrian_steps": _foot_index}
