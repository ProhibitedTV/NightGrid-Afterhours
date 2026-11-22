extends Node
## Runtime audio for city travel and player action. Musical programming is
## handled separately by NightGridFM. This layer uses original cached WAVs.
const Foley = preload("res://scripts/city_foley.gd")
const TrafficSpatialAudio = preload("res://scripts/traffic_spatial_audio.gd")
const SoundscapeSites = preload("res://scripts/soundscape_sites.gd")
const AudioMix = preload("res://scripts/audio_mix.gd")
const Plan = preload("res://scripts/world_plan.gd")
const BEDS = ["WIND", "TRAFFIC", "INDUSTRIAL", "WATER"]
const PROFILE_DB = {
	"VESPER MARKET": [-28.0, -17.0, -52.0, -54.0],
	"GLASSLINE": [-23.0, -21.0, -41.0, -62.0],
	"BRICKWATER": [-23.0, -23.0, -39.0, -62.0],
	"AFTERHOURS": [-29.0, -20.0, -42.0, -56.0],
	"NORTH QUAY": [-20.0, -29.0, -36.0, -18.0],
	"WEST DOCKS": [-19.0, -30.0, -24.0, -20.0],
	"HORIZON GARDENS": [-17.0, -34.0, -58.0, -43.0],
	"SOUTHWORKS": [-23.0, -27.0, -16.0, -57.0],
}
const EVENTS = ["DOOR", "TRANSIT", "PICKUP", "DELIVERY", "JUMP", "LAND", "BRAKE", "BUS_DOOR", "RAIL_DOOR"]
const EVENT_VOICES = 4
const FADE_DB_PER_SECOND = 44.0
const STEPS = {
	"CONCRETE": "stone",
	"TILE": "tile",
	"ASPHALT": "asphalt",
	"GRAVEL": "gravel",
}
const STEP_ROOT = "res://assets/audio/morrow_bay/steps/"

var menu: CanvasLayer
var ambience_volume := 0.65
var sfx_volume := 0.75
var _district := ""
var _hour := 19.0
var _indoors := false
var _in_car := false
var _moving_on_foot := false
var _grounded := true
var _was_grounded := true
var _travel := 0.0
var _last_foot := Vector3.ZERO
var _has_foot := false
var _floor_observed := false
var _step_index := 0
var _step_speed := 0.0
var _step_surface := "CONCRETE"
var _step_bank := {}
var _beds: Dictionary = {}
var _footsteps: AudioStreamPlayer3D
var _events: Array[AudioStreamPlayer3D] = []
var _event_cursor := 0
var _event_count := 0
var _traffic_audio: Node3D
var _sites: Node3D
var _listener := Vector3.ZERO
var _enclosure := 18000.0
var _acoustic_clock := 0.0
var _transport := ""
var _transport_speed := 0.0
var _previous_speed := 0.0
var _brake_cooldown := 0.0
var _brake_pressed := false
var _cabin: AudioStreamPlayer
var _last_event := ""
var _room_kind := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioMix.ensure()
	for kind in EVENTS:
		Foley.sound(kind) # Prewarm transient PCM before first interaction.
	for kind in BEDS:
		var player := AudioStreamPlayer.new()
		player.name = "MorrowBay_" + kind
		player.bus = AudioMix.OUTSIDE_BEDS
		player.stream = _bed_stream(kind)
		player.volume_db = -80.0
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		player.play()
		_beds[kind] = player
	_footsteps = AudioStreamPlayer3D.new()
	_footsteps.name = "CourierFootsteps"
	_footsteps.bus = AudioMix.EFFECTS
	_footsteps.max_distance = 20.0
	_footsteps.unit_size = 3.0
	_footsteps.volume_db = -16.0
	_footsteps.max_polyphony = 2
	add_child(_footsteps)
	for surface in STEPS:
		var samples: Array[AudioStream] = []
		for variant in range(4):
			var path := STEP_ROOT + ("%s_%d.wav" % [STEPS[surface], variant + 1])
			var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
			samples.append(stream if stream != null else Foley.sound("STEP_TILE" if surface == "TILE" else "STEP_CONCRETE", variant))
		_step_bank[surface] = samples
	for index in range(EVENT_VOICES):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "PlayerActionVoice_%d" % index
		voice.bus = AudioMix.EFFECTS
		voice.max_distance = 27.0
		voice.unit_size = 2.0
		voice.volume_db = -80.0
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		_events.append(voice)
	_traffic_audio = TrafficSpatialAudio.new()
	_traffic_audio.name = "PassingTrafficSoundfield"
	add_child(_traffic_audio)
	_sites = SoundscapeSites.new()
	_sites.name = "StreetDetailVoices"
	add_child(_sites)
	_sites.call("configure_steps", _step_bank["CONCRETE"])
	_cabin = AudioStreamPlayer.new()
	_cabin.name = "PassengerRoadAndRail"
	_cabin.bus = AudioMix.EFFECTS
	_cabin.stream = Foley.sound("ROAD_ROLL")
	_cabin.volume_db = -80.0
	add_child(_cabin)

func _bed_stream(kind: String) -> AudioStream:
	if kind == "TRAFFIC":
		var traffic := load("res://assets/audio/morrow_bay/traffic.ogg") as AudioStreamOggVorbis
		if traffic != null:
			traffic.loop = true
			return traffic
	return Foley.sound(kind)

func set_traffic(traffic_root: Node3D) -> void:
	_traffic_audio.call("set_traffic", traffic_root)

func set_pedestrians(director: Node3D) -> void:
	_sites.set("pedestrians", director)

func set_room_kind(kind: String) -> void:
	if kind != _room_kind:
		_room_kind = kind
		AudioMix.set_room_character(kind)

func set_transport(mode: String, speed: float, brakes: bool) -> void:
	_transport = mode
	_transport_speed = absf(speed)
	_brake_pressed = brakes

func set_preferences(ambience: float, effects: float) -> void:
	ambience_volume = clampf(ambience, 0.0, 1.0)
	sfx_volume = clampf(effects, 0.0, 1.0)
	AudioMix.apply_game_levels(ambience_volume, sfx_volume)

func update_context(actor_position: Vector3, foot_position: Vector3,
		on_foot: bool, on_ground: bool, indoors: bool,
		district: String, hour: float, speed: float, vertical_speed: float = 0.0) -> void:
	_district = district
	_listener = actor_position
	_hour = fposmod(hour, 24.0)
	_indoors = indoors
	_in_car = not on_foot
	_moving_on_foot = on_foot and speed > 0.7
	_step_speed = speed
	_was_grounded = _grounded
	_grounded = on_ground
	_footsteps.global_position = foot_position - Vector3.UP * 0.70
	var nearby := _has_foot and _last_foot.distance_squared_to(foot_position) < 9.0
	if nearby and on_foot and _floor_observed:
		if _was_grounded and not on_ground and vertical_speed > 1.0:
			play_event("JUMP", foot_position)
		elif not _was_grounded and on_ground:
			play_event("LAND", foot_position)
	_floor_observed = on_foot and (on_ground or (nearby and _floor_observed))
	_traffic_audio.call("update_listener", actor_position, indoors, not on_foot, sfx_volume)
	if not _has_foot or not on_foot:
		_last_foot = foot_position
		_has_foot = on_foot
		_travel = 0.0
		return
	var displacement := Vector2(foot_position.x - _last_foot.x,
		foot_position.z - _last_foot.z).length()
	_last_foot = foot_position
	if not _grounded or not _moving_on_foot or displacement >= 3.0:
		# Teleports, respawns and blocked walks produce no false footsteps.
		_travel = 0.0
		return
	_travel += displacement
	var cadence := lerpf(1.9, 4.15, clampf((speed - 1.25) / 7.5, 0.0, 1.0))
	var stride := maxf(0.70, speed / cadence)
	if _travel >= stride:
		_travel = fposmod(_travel, stride)
		_step_surface = surface_at(foot_position, indoors)
		_play_step()

static func surface_at(foot_position: Vector3, indoors: bool) -> String:
	if indoors:
		return "TILE"
	var x := fposmod(foot_position.x + Plan.BLOCK_SIZE * 0.5, Plan.BLOCK_SIZE) - Plan.BLOCK_SIZE * 0.5
	var z := fposmod(foot_position.z + Plan.BLOCK_SIZE * 0.5, Plan.BLOCK_SIZE) - Plan.BLOCK_SIZE * 0.5
	# Use the actual roadway widths. The retained gravel edge is outside
	# the last through lane, so ordinary sidewalks keep their concrete sound.
	if absf(foot_position.x) > Plan.city_bounds() + 9.0 or absf(foot_position.z) > Plan.city_bounds() + 9.0:
		return "GRAVEL"
	if foot_position.y < 3.5 and minf(absf(x), absf(z)) < 7.8:
		return "ASPHALT"
	return "CONCRETE"

## Bounded, prewarmed positional action voices; never allocate players or
## synthesize PCM during driving, animation or mission events.
func play_event(kind: String, at: Vector3) -> void:
	if not EVENTS.has(kind) or sfx_volume <= 0.0 or _events.is_empty():
		return
	var voice: AudioStreamPlayer3D = _events[_event_cursor]
	_event_cursor = (_event_cursor + 1) % _events.size()
	voice.stop()
	voice.stream = Foley.sound(kind)
	voice.bus = AudioMix.ROOM_EFFECTS if _indoors else AudioMix.EFFECTS
	voice.global_position = at
	voice.volume_db = -12.0 if kind in ["BRAKE", "BUS_DOOR", "RAIL_DOOR"] else -6.0
	voice.pitch_scale = 1.0
	voice.play()
	_event_count += 1
	_last_event = kind

func _play_step() -> void:
	var samples: Array = _step_bank[_step_surface]
	_footsteps.stream = samples[_step_index % samples.size()]
	_footsteps.bus = AudioMix.ROOM_EFFECTS if _indoors else AudioMix.EFFECTS
	var energy := clampf((_step_speed - 1.0) / 10.0, 0.0, 1.0)
	_footsteps.volume_db = lerpf(-18.0, -9.0, energy)
	_footsteps.pitch_scale = 0.93 + float(posmod(_step_index * 7, 5)) * 0.035 + energy * 0.08
	if sfx_volume > 0.0:
		_footsteps.play()
	_step_index += 1

func get_audio_stats() -> Dictionary:
	return {"environment_layers": _beds.size(), "steps": _step_index,
		"foley_cached": Foley.cache_count(), "district": _district,
		"action_voices": _events.size(), "action_cues": _event_count,
		"inside": _indoors, "traffic_audio": _traffic_audio.call("get_stats"),
		"surface": _step_surface, "last_event": _last_event, "transport": _transport,
		"exterior_cutoff": _enclosure, "sites": _sites.call("stats")}

func _target_db(kind: String) -> float:
	if ambience_volume <= 0.0:
		return -80.0
	var nighttime := _hour >= 19.0 or _hour < 6.0
	var profile: Array = PROFILE_DB.get(_district, PROFILE_DB["BRICKWATER"])
	var level: float = profile[BEDS.find(kind)]
	if nighttime and kind == "TRAFFIC":
		level += 2.0 if _district == "AFTERHOURS" else -5.0
	if _indoors:
		level -= 21.0
	elif kind == "WIND" or kind == "WATER":
		level += 4.0
	if _in_car and not _indoors:
		level -= 6.0
	if level <= -80.0:
		return -80.0
	return level # CityAmbience bus holds the player gain for all sources.

func _update_cabin(delta: float, dimmed: bool) -> void:
	var moving := not _transport.is_empty() and _transport_speed > 1.0
	var target := -80.0
	if moving and sfx_volume > 0.0:
		target = lerpf(-40.0, -13.0, clampf(_transport_speed / 26.0, 0.0, 1.0))
		if dimmed:
			target -= 20.0
		if not _cabin.playing:
			_cabin.play()
	_cabin.pitch_scale = clampf((_transport_speed * 0.026) + (0.61 if _transport == "TRAIN" else 0.76), 0.65, 1.43)
	_cabin.volume_db = move_toward(_cabin.volume_db, target, delta * 80.0)
	if not moving and _cabin.volume_db < -75.0:
		_cabin.stop()
	_brake_cooldown = maxf(0.0, _brake_cooldown - delta)
	if not dimmed and _brake_cooldown == 0.0 and moving and _previous_speed > 4.5 and (
		_brake_pressed or _previous_speed - _transport_speed > delta * 5.0):
		play_event("BRAKE", _listener)
		_brake_cooldown = 0.85
	_previous_speed = _transport_speed

func _process(delta: float) -> void:
	# World keeps positional/movement context updated during play. While the
	# game is paused, ambience continues softly instead of hard-cutting.
	var dimmed := is_instance_valid(menu) and bool(menu.call("is_open"))
	_sites.call("set_context", _listener, _hour, _indoors, sfx_volume <= 0.0, dimmed)
	_acoustic_clock += delta
	var enclosure := 950.0 if _indoors else (2700.0 if _in_car else 18000.0)
	_enclosure = lerpf(_enclosure, enclosure, 1.0 - exp(-6.0 * delta))
	if _acoustic_clock >= 0.05:
		_acoustic_clock = fposmod(_acoustic_clock, 0.05)
		AudioMix.set_exterior_cutoff(_enclosure)
	_update_cabin(delta, dimmed)
	for kind in BEDS:
		var player: AudioStreamPlayer = _beds[kind]
		var target := _target_db(kind)
		if dimmed and target > -80.0:
			target -= 13.0
		player.volume_db = move_toward(player.volume_db, target, FADE_DB_PER_SECOND * delta)
