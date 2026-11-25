extends Node
const AudioMix = preload("res://scripts/audio_mix.gd")
const VenueCatalog = preload("res://scripts/venue_system.gd")
## NightGrid FM: authored, creator-owned chipwave music for Morrow Bay.
## Streams are loaded only when needed. Missing optional .ogg assets never
## prevent the prototype from launching; procedural venue ambience remains.
const ROOT = "res://assets/audio/nightgrid_fm/"
const TRACKS = {
	"boot_sequence": "BOOT SEQUENCE",
	"neon_checksum": "NEON CHECKSUM",
	"packet_loss": "PACKET LOSS",
	"phosphor_ghosts": "PHOSPHOR GHOSTS",
	"overclock": "OVERCLOCK",
	"memory_address": "MEMORY ADDRESS",
	"midnight_bus": "MIDNIGHT BUS",
	"rasterburn": "RASTERBURN",
	"save_point": "SAVE POINT",
	"null_district": "NULL DISTRICT",
	"last_packet_home": "LAST PACKET HOME",
	"carrier_signal": "CARRIER SIGNAL",
	"blackout_bonus_round": "Blackout Bonus Round",
	"door_on_the_spin_cycle": "Door on the Spin Cycle",
	"fix_it_with_a_paper_clip": "Fix It With a Paper Clip",
	"high_score_with_no_name": "High Score With No Name",
	"second_controller": "Second Controller",
	"sweep_the_carpet_at_sunrise": "Sweep the Carpet at Sunrise",
	"the_coin_slot_is_taped": "The Coin Slot Is Taped",
	"tournament_in_the_back_room": "Tournament in the Back Room"
}
const PLAYLISTS = {
	"title": ["boot_sequence", "neon_checksum", "phosphor_ghosts", "carrier_signal"],
	"car": ["midnight_bus", "carrier_signal", "packet_loss", "neon_checksum",
		"memory_address", "overclock", "rasterburn", "null_district", "last_packet_home",
		"boot_sequence", "phosphor_ghosts", "save_point", "blackout_bonus_round",
		"door_on_the_spin_cycle", "fix_it_with_a_paper_clip", "high_score_with_no_name",
		"second_controller", "sweep_the_carpet_at_sunrise",
		"the_coin_slot_is_taped", "tournament_in_the_back_room"],
	"club": ["overclock", "rasterburn", "packet_loss", "blackout_bonus_round",
		"tournament_in_the_back_room", "neon_checksum"],
	"bar": ["null_district", "memory_address", "phosphor_ghosts",
		"the_coin_slot_is_taped", "last_packet_home"],
	"cafe": ["save_point", "high_score_with_no_name", "second_controller",
		"sweep_the_carpet_at_sunrise", "fix_it_with_a_paper_clip"],
	"retail": ["memory_address", "save_point", "midnight_bus", "second_controller"],
	"retail_quay": ["midnight_bus","last_packet_home","fix_it_with_a_paper_clip"],
	"retail_vesper": ["save_point","phosphor_ghosts","memory_address"],
	"retail_nocturne": ["null_district","packet_loss","rasterburn"],
	"retail_obscura": ["phosphor_ghosts","carrier_signal","neon_checksum"],
	"retail_thrift": ["rasterburn","blackout_bonus_round","the_coin_slot_is_taped","high_score_with_no_name"],
	"stall": ["door_on_the_spin_cycle", "midnight_bus", "carrier_signal",
		"second_controller", "the_coin_slot_is_taped"]
}
const FADE_SECONDS = 1.15
const SILENCE = 0.0005
const MUSIC_HEADROOM = 0.68
const MAX_LOADS = 3
const VENUE_IN_RANGE = 31.0
const VENUE_OUT_RANGE = 39.0

var venues: Node3D
var menu: CanvasLayer
var music_volume := 0.65
var radio_enabled := true
var dialogue_active := false
var _actor_position := Vector3.ZERO
var _in_car := false
var _in_transit := false
var _inside_id := ""
var _inside_kind := ""
var _current_context := ""
var _active_deck_context := ""
var _now_playing := ""
var _cursor: Dictionary = {}
var _available: Dictionary = {}
var _decks: Array[AudioStreamPlayer] = []
var _gain: Dictionary = {}
var _front: AudioStreamPlayer
var _venue: AudioStreamPlayer3D
var _venue_id := ""
var _venue_track := ""
var _venue_next_id := ""
var _venue_refresh := 0.35
var _venue_gain := 0.0
var _music_gain := 0.0
var _deck_request := {}
var _venue_request := {}
var _loading := {}
var _ready_streams := {}
var _car_resume := {}
var _door_resume := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioMix.ensure()
	for id in TRACKS:
		var path: String = ROOT + id + ".ogg"
		if ResourceLoader.exists(path):
			_available[id] = path
	for index in range(2):
		var deck := AudioStreamPlayer.new()
		deck.name = "NightGridStereo_%d" % index
		deck.bus = AudioMix.MUSIC
		deck.volume_db = -80.0
		add_child(deck)
		deck.finished.connect(_on_deck_finished.bind(deck))
		_decks.append(deck)
		_gain[deck] = 0.0
	_venue = AudioStreamPlayer3D.new()
	_venue.name = "NightGridStreetVenue"
	_venue.bus = AudioMix.STREET_MUSIC
	_venue.max_distance = 48.0
	_venue.unit_size = 7.0
	_venue.volume_db = -80.0
	add_child(_venue)

func available_tracks() -> int:
	return _available.size()

func set_preferences(volume: float, car_radio_on: bool) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	radio_enabled = car_radio_on

func update_listener(position: Vector3, in_car: bool, interior_id: String, interior_kind: String, in_transit: bool = false) -> void:
	_actor_position = position
	_in_car = in_car
	_in_transit = in_transit
	_inside_id = interior_id
	_inside_kind = interior_kind

func get_now_playing() -> String:
	if not _in_car:
		return ""
	if _current_context == "car" and _active_deck_context == "car" and not _now_playing.is_empty():
		return "NIGHTGRID FM  /  " + _now_playing
	if radio_enabled and not _available.is_empty():
		return "NIGHTGRID FM  /  TUNING"
	return "NIGHTGRID FM  /  OFF"

func next_car_track() -> bool:
	if not _in_car or not radio_enabled or _available.is_empty() or _context() != "car":
		return false
	_cue("car")
	return not _deck_request.is_empty()

func get_track_titles() -> Dictionary:
	return TRACKS.duplicate(true)

func get_playlists() -> Dictionary:
	return PLAYLISTS.duplicate(true)

func snapshot() -> Dictionary:
	if _active_deck_context == "car" and is_instance_valid(_front) and _front.playing:
		return {"track": str(_front.get_meta("track", "")), "position": _front.get_playback_position()}
	return _car_resume.duplicate()

func restore(value: Variant) -> void:
	if not value is Dictionary or not TRACKS.has(value.get("track", "")):
		return
	var seconds: Variant = value.get("position")
	if (seconds is float or seconds is int) and is_finite(float(seconds)) and float(seconds) >= 0.0:
		_car_resume = {"track": value["track"], "position": float(seconds)}
		_cursor["car"] = (PLAYLISTS["car"].find(value["track"]) + 1) % PLAYLISTS["car"].size()

func playback_stats() -> Dictionary:
	var playing := int(_venue.playing)
	for deck in _decks:
		playing += int(deck.playing)
	return {"context": _current_context, "track": str(_front.get_meta("track", "")) if _front != null else "",
		"venue": _venue_id, "venue_track": _venue_track, "playing": playing,
		"pending_loads": _loading.size(), "music_gain": _music_gain, "cue": _deck_request.duplicate()}

func _menu_screen() -> String:
	return str(menu.get("screen")) if is_instance_valid(menu) else "hidden"

func _context() -> String:
	if _menu_screen() == "title":
		return "title"
	if not _inside_id.is_empty() and PLAYLISTS.has(_inside_kind.to_lower()):
		return "interior:" + _inside_kind.to_lower() + ":" + _inside_id
	if _in_car and radio_enabled:
		return "car"
	return ""

func _group(context: String) -> String:
	if context.begins_with("interior:") or context.begins_with("street:"):
		return context.split(":")[1]
	return context

func _next_id(context: String) -> String:
	var group := _group(context)
	if not PLAYLISTS.has(group):
		return ""
	var options: Array = PLAYLISTS[group]
	var start: int = int(_cursor.get(context, 0 if context == "title" else posmod(context.hash(), options.size())))
	for offset in range(options.size()):
		var id: String = options[(start + offset) % options.size()]
		if _available.has(id):
			_cursor[context] = (start + offset + 1) % options.size()
			return id
	return ""

func _cue(context: String, resume: Dictionary = {}) -> void:
	var id := str(resume.get("track", ""))
	if not _available.has(id):
		id = _next_id(context)
		resume = {}
	_deck_request = {} if id.is_empty() else {
		"track": id, "context": context, "position": float(resume.get("position", 0.0))
	}

func _request(id: String) -> void:
	if id.is_empty() or _loading.has(id) or _ready_streams.has(id) or _loading.size() >= MAX_LOADS:
		return
	if _venue_track == id and _venue.stream != null:
		_ready_streams[id] = _venue.stream
		return
	for deck in _decks:
		if deck.get_meta("track", "") == id and deck.stream != null:
			_ready_streams[id] = deck.stream
			return
	var status := ResourceLoader.load_threaded_request(_available[id], "AudioStream")
	if status in [OK, ERR_BUSY]:
		_loading[id] = true

func _poll_streams() -> void:
	var wanted := [str(_deck_request.get("track", "")), str(_venue_request.get("track", ""))]
	for id in _loading.keys():
		var path: String = _available[id]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_loading.erase(id)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var stream := ResourceLoader.load_threaded_get(path) as AudioStreamOggVorbis
			if stream != null and id in wanted:
				_ready_streams[id] = stream
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			# Consume the completed failed job so later context changes can retry.
			ResourceLoader.load_threaded_get(path)
			if id == wanted[0]:
				_deck_request.clear()
			if id == wanted[1]:
				_venue_request.clear()
	for id in _ready_streams.keys():
		if not id in wanted:
			_ready_streams.erase(id)
	for id in wanted:
		_request(id)

func _start_deck() -> void:
	if _deck_request.is_empty():
		return
	var id: String = _deck_request["track"]
	var incoming: AudioStreamPlayer = _decks[0] if _front != _decks[0] else _decks[1]
	if not _ready_streams.has(id) or float(_gain[incoming]) > SILENCE:
		return
	if _active_deck_context == "car" and _deck_request["context"] != "car":
		_car_resume = snapshot()
	var stream: AudioStream = _ready_streams[id]
	var start := clampf(float(_deck_request["position"]), 0.0, maxf(0.0, stream.get_length() - 1.4))
	incoming.stop()
	incoming.stream = stream
	incoming.set_meta("track", id)
	incoming.volume_db = -80.0
	incoming.play(start)
	_front = incoming
	_active_deck_context = _deck_request["context"]
	_now_playing = TRACKS[id]
	_deck_request.clear()

func _on_deck_finished(deck: AudioStreamPlayer) -> void:
	if deck == _front and _active_deck_context == _current_context and not _current_context.is_empty() and _deck_request.is_empty():
		_cue(_current_context)

func _select_venue() -> String:
	if not is_instance_valid(venues) or not _inside_id.is_empty() or _in_car or _in_transit or _menu_screen() == "title":
		return ""
	if not _venue_id.is_empty() and bool(venues.call("is_open", _venue_id)):
		var point: Vector3 = venues.call("venue_position", _venue_id)
		if Vector2(_actor_position.x - point.x, _actor_position.z - point.z).length() < VENUE_OUT_RANGE:
			return _venue_id
	var best := VENUE_IN_RANGE
	var selected := ""
	for site in VenueCatalog.VENUES:
		var id: String = site["id"]
		if not bool(venues.call("is_open", id)):
			continue
		var position: Vector3 = venues.call("venue_position", id)
		var distance := Vector2(_actor_position.x - position.x, _actor_position.z - position.z).length()
		if distance < best:
			best = distance
			selected = id
	return selected

func _schedule_venue(site: String) -> void:
	var source: Dictionary = venues.call("venue_by_id", site)
	var resume := _door_resume if _door_resume.get("site", "") == site else {}
	var id := str(resume.get("track", ""))
	if not _available.has(id):
		id = _next_id("street:" + str(source.get("kind", "")).to_lower() + ":" + site)
	_venue_request = {} if id.is_empty() else {"track": id, "site": site, "position": float(resume.get("position", 0.0))}
	_door_resume.clear()

func _update_venue(delta: float) -> void:
	_venue_refresh += delta
	if _venue_refresh >= 0.25:
		_venue_refresh = 0.0
		_venue_next_id = _select_venue()
		if _venue_request.get("site", "") != _venue_next_id:
			_venue_request.clear()
	var remaining := _venue.stream.get_length() - _venue.get_playback_position() if _venue.playing else 0.0
	var changing := _venue_next_id != _venue_id or remaining < FADE_SECONDS
	var target := 0.0 if changing or _venue_next_id.is_empty() else 1.0
	_venue_gain = move_toward(_venue_gain, target, delta / FADE_SECONDS)
	_venue.volume_db = linear_to_db(maxf(SILENCE, _music_gain * _venue_gain * 0.22))
	if changing and not _venue_next_id.is_empty() and _venue_request.is_empty():
		_schedule_venue(_venue_next_id)
	if _venue_gain > SILENCE or not changing:
		return
	_venue.stop()
	_venue_id = ""
	if _venue_request.is_empty():
		return
	var id: String = _venue_request["track"]
	if not _ready_streams.has(id):
		return
	_venue_id = _venue_request["site"]
	_venue_track = id
	_venue.stream = _ready_streams[id]
	_venue.global_position = venues.call("venue_position", _venue_id) + Vector3.UP * 1.6
	_venue.play(clampf(float(_venue_request["position"]), 0.0, maxf(0.0, _venue.stream.get_length() - 1.4)))
	_venue_request.clear()

func _process(delta: float) -> void:
	if _available.is_empty():
		return
	var context := _context()
	if context != _current_context:
		if _active_deck_context == "car":
			_car_resume = snapshot()
		elif _active_deck_context.begins_with("interior:") and _front != null and _front.playing:
			_door_resume = {"site": _active_deck_context.split(":")[2],
				"track": str(_front.get_meta("track", "")), "position": _front.get_playback_position()}
		_current_context = context
		_deck_request.clear()
		if context == "car":
			_cue(context, _car_resume)
		elif not context.is_empty():
			if context.begins_with("interior:") and _inside_id == _venue_id and _venue.playing:
				_cue(context, {"track": _venue_track, "position": _venue.get_playback_position()})
			else:
				_cue(context)
		else:
			_now_playing = ""
	if not context.is_empty() and _active_deck_context == context and _front != null and _front.playing and _deck_request.is_empty():
		if _front.stream.get_length() - _front.get_playback_position() <= FADE_SECONDS + 0.35:
			_cue(context)
	var paused_factor := 0.44 if _menu_screen() not in ["hidden", "title"] else 1.0
	var speech_factor := 0.58 if dialogue_active else 1.0
	_music_gain = move_toward(_music_gain, music_volume * paused_factor * speech_factor, delta * 2.0)
	_update_venue(delta)
	_poll_streams()
	_start_deck()
	for deck in _decks:
		var target := 1.0 if deck == _front and not context.is_empty() else 0.0
		var gain := move_toward(float(_gain[deck]), target, delta / FADE_SECONDS)
		_gain[deck] = gain
		deck.volume_db = linear_to_db(maxf(SILENCE, sqrt(gain) * _music_gain * MUSIC_HEADROOM))
		if gain <= SILENCE and target == 0.0:
			deck.stop()
			deck.stream = null
