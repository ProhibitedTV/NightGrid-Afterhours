extends Node
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
	"stall": ["door_on_the_spin_cycle", "midnight_bus", "carrier_signal",
		"second_controller", "the_coin_slot_is_taped"]
}
const CROSSFADE_DB_PER_SECOND = 28.0
const VENUE_IN_RANGE = 31.0
const VENUE_OUT_RANGE = 39.0

var venues: Node3D
var menu: CanvasLayer
var music_volume := 0.65
var radio_enabled := true
var _actor_position := Vector3.ZERO
var _in_car := false
var _inside_id := ""
var _inside_kind := ""
var _current_context := ""
var _now_playing := ""
var _cursor: Dictionary = {}
var _available: Dictionary = {}
var _decks: Array[AudioStreamPlayer] = []
var _front: AudioStreamPlayer
var _venue: AudioStreamPlayer3D
var _venue_id := ""
var _venue_next_id := ""
var _venue_refresh := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in TRACKS:
		var path: String = ROOT + id + ".ogg"
		if ResourceLoader.exists(path):
			_available[id] = path
	for index in range(2):
		var deck := AudioStreamPlayer.new()
		deck.name = "NightGridStereo_%d" % index
		deck.volume_db = -80.0
		deck.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(deck)
		deck.finished.connect(_on_deck_finished.bind(deck))
		_decks.append(deck)
	_venue = AudioStreamPlayer3D.new()
	_venue.name = "NightGridStreetVenue"
	_venue.max_distance = 48.0
	_venue.unit_size = 7.0
	_venue.volume_db = -80.0
	_venue.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_venue)
	_venue.finished.connect(_on_venue_finished)

func available_tracks() -> int:
	return _available.size()

func set_preferences(volume: float, car_radio_on: bool) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	radio_enabled = car_radio_on

func update_listener(position: Vector3, in_car: bool, interior_id: String, interior_kind: String) -> void:
	_actor_position = position
	_in_car = in_car
	_inside_id = interior_id
	_inside_kind = interior_kind

func get_now_playing() -> String:
	if _current_context == "car" and not _now_playing.is_empty():
		return "NIGHTGRID FM  /  " + _now_playing
	return "NIGHTGRID FM  /  OFF" if _in_car else ""

func next_car_track() -> bool:
	if not _in_car or not radio_enabled or _available.is_empty():
		return false
	_cue("car")
	return true

func get_track_titles() -> Dictionary:
	return TRACKS.duplicate(true)

func get_playlists() -> Dictionary:
	return PLAYLISTS.duplicate(true)

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

func _stream_for(id: String) -> AudioStream:
	if not _available.has(id):
		return null
	var stream := load(str(_available[id])) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	return stream

func _cue(context: String) -> void:
	var id := _next_id(context)
	if id.is_empty():
		return
	var stream := _stream_for(id)
	if stream == null:
		return
	var incoming: AudioStreamPlayer = _decks[0] if _front != _decks[0] else _decks[1]
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	_front = incoming
	_now_playing = str(TRACKS[id])

func _on_deck_finished(deck: AudioStreamPlayer) -> void:
	if deck == _front and not _current_context.is_empty():
		_cue(_current_context)

func _on_venue_finished() -> void:
	if not _venue_id.is_empty():
		_play_venue(_venue_id)

func _play_venue(id: String) -> void:
	if not is_instance_valid(venues):
		return
	var site: Dictionary = venues.call("venue_by_id", id)
	if site.is_empty():
		return
	var group := str(site["kind"]).to_lower()
	var track := _next_id("street:" + group + ":" + id)
	if track.is_empty():
		# Street venues use the same curation as their corresponding interior.
		var options: Array = PLAYLISTS.get(group, [])
		for t in options:
			if _available.has(t):
				track = t
				break
	if track.is_empty():
		return
	var stream := _stream_for(track)
	if stream == null:
		return
	_venue.stop()
	_venue.stream = stream
	_venue.global_position = venues.call("venue_position", id) + Vector3(0.0, 1.6, 0.0)
	_venue.volume_db = -80.0
	_venue.play()

func _select_venue() -> String:
	if not is_instance_valid(venues) or not _inside_id.is_empty() or _in_car or _menu_screen() == "title":
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

func _process(delta: float) -> void:
	var context := _context()
	if context != _current_context:
		_current_context = context
		if not context.is_empty():
			_cue(context)
		else:
			_now_playing = ""
	var paused_factor := 0.32 if _menu_screen() != "hidden" and _menu_screen() != "title" else 1.0
	var target_gain := music_volume * paused_factor
	for deck in _decks:
		var target_db := linear_to_db(maxf(0.001, target_gain)) if deck == _front and not context.is_empty() else -80.0
		deck.volume_db = move_toward(deck.volume_db, target_db, CROSSFADE_DB_PER_SECOND * delta)
		if deck.playing and deck.volume_db <= -75.0 and (deck != _front or context.is_empty()):
			deck.stop()
	_venue_refresh += delta
	if _venue_refresh >= 0.35:
		_venue_refresh = 0.0
		_venue_next_id = _select_venue()
	var venue_target_db := (-15.0 + linear_to_db(maxf(0.001, target_gain))) if not _venue_next_id.is_empty() else -80.0
	if _venue_next_id != _venue_id:
		_venue.volume_db = move_toward(_venue.volume_db, -80.0, CROSSFADE_DB_PER_SECOND * delta)
		if _venue.volume_db <= -75.0:
			_venue.stop()
			_venue_id = _venue_next_id
			if not _venue_id.is_empty():
				_play_venue(_venue_id)
	elif _venue.playing:
		_venue.volume_db = move_toward(_venue.volume_db, venue_target_db, CROSSFADE_DB_PER_SECOND * delta)
