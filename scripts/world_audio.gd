extends Node
## Runtime audio for city travel and player action. Musical programming is
## handled separately by NightGridFM. This layer uses original cached WAVs.
const Foley = preload("res://scripts/city_foley.gd")
const TrafficSpatialAudio = preload("res://scripts/traffic_spatial_audio.gd")
const BEDS = ["WIND", "TRAFFIC", "INDUSTRIAL", "WATER"]
const FADE_DB_PER_SECOND = 25.0

var menu: CanvasLayer
var ambience_volume := 0.65
var sfx_volume := 0.75
var _district := ""
var _hour := 19.0
var _indoors := false
var _in_car := false
var _moving_on_foot := false
var _grounded := true
var _travel := 0.0
var _last_foot := Vector3.ZERO
var _has_foot := false
var _step_index := 0
var _beds: Dictionary = {}
var _footsteps: AudioStreamPlayer3D
var _traffic_audio: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for kind in BEDS:
		var player := AudioStreamPlayer.new()
		player.name = "MorrowBay_" + kind
		player.stream = Foley.sound(kind)
		player.volume_db = -80.0
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		player.play()
		_beds[kind] = player
	_footsteps = AudioStreamPlayer3D.new()
	_footsteps.name = "CourierFootsteps"
	_footsteps.max_distance = 20.0
	_footsteps.unit_size = 3.0
	_footsteps.volume_db = -16.0
	add_child(_footsteps)
	_traffic_audio = TrafficSpatialAudio.new()
	_traffic_audio.name = "PassingTrafficSoundfield"
	add_child(_traffic_audio)

func set_traffic(traffic_root: Node3D) -> void:
	_traffic_audio.call("set_traffic", traffic_root)

func set_preferences(ambience: float, effects: float) -> void:
	ambience_volume = clampf(ambience, 0.0, 1.0)
	sfx_volume = clampf(effects, 0.0, 1.0)

func update_context(actor_position: Vector3, foot_position: Vector3,
		on_foot: bool, on_ground: bool, indoors: bool,
		district: String, hour: float, speed: float) -> void:
	_district = district
	_hour = fposmod(hour, 24.0)
	_indoors = indoors
	_in_car = not on_foot
	_moving_on_foot = on_foot and speed > 0.7
	_grounded = on_ground
	_footsteps.global_position = foot_position
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
	var stride := 2.05 if speed > 9.0 else 1.65
	if _travel >= stride:
		_travel = fposmod(_travel, stride)
		_play_step()

func _play_step() -> void:
	var surface := "STEP_TILE" if _indoors else "STEP_CONCRETE"
	_footsteps.stream = Foley.sound(surface, posmod(_step_index, 4))
	_footsteps.volume_db = -80.0 if sfx_volume <= 0.0 else linear_to_db(sfx_volume) - 9.0
	_footsteps.pitch_scale = 0.93 + float(posmod(_step_index * 7, 5)) * 0.035
	_footsteps.play()
	_step_index += 1

func get_audio_stats() -> Dictionary:
	return {"environment_layers": _beds.size(), "steps": _step_index,
		"foley_cached": Foley.cache_count(), "district": _district,
		"inside": _indoors, "traffic_audio": _traffic_audio.call("get_stats")}

func _target_db(kind: String) -> float:
	if ambience_volume <= 0.0:
		return -80.0
	var nighttime := _hour >= 19.0 or _hour < 6.0
	var level := -80.0
	match kind:
		"WIND":
			level = -23.0 if not _indoors else -45.0
		"TRAFFIC":
			level = -21.0 if _district in ["BRICKWATER", "GLASSLINE", "AFTERHOURS", "VESPER MARKET"] else -28.0
			if nighttime:
				level -= 3.0
			if _indoors:
				level -= 19.0
		"INDUSTRIAL":
			level = -20.5 if _district in ["SOUTHWORKS", "WEST DOCKS"] else -80.0
			if _indoors:
				level -= 19.0
		"WATER":
			level = -22.0 if _district in ["NORTH QUAY", "WEST DOCKS"] else -80.0
			if _indoors:
				level -= 18.0
	if _in_car and not _indoors:
		level -= 6.0
	if level <= -80.0:
		return -80.0
	return level + linear_to_db(maxf(0.001, ambience_volume))

func _process(delta: float) -> void:
	# World keeps positional/movement context updated during play. While the
	# game is paused, ambience continues softly instead of hard-cutting.
	var dimmed := is_instance_valid(menu) and bool(menu.call("is_open"))
	for kind in BEDS:
		var player: AudioStreamPlayer = _beds[kind]
		var target := _target_db(kind)
		if dimmed and target > -80.0:
			target -= 13.0
		player.volume_db = move_toward(player.volume_db, target, FADE_DB_PER_SECOND * delta)
