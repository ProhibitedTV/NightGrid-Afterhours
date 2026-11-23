extends RefCounted
## Shared routing contract for the original game soundtrack and effects.
## Buses are initialized once per process and survive scene reloads.
## Existing player-facing volume settings continue to control source gain;
## the independent buses allow actual stem metering and future DSP/mix passes.
const MUSIC = "NightGridMusic"
const AMBIENCE = "CityAmbience"
const EFFECTS = "WorldSFX"
const UI = "NightGridUI"
const DIALOGUE = "DispatchDialogue"
const OUTSIDE_BEDS = "OutsideBeds"
const OUTSIDE_EFFECTS = "OutsideSFX"
const ROOM_EFFECTS = "RoomSFX"
const STREET_MUSIC = "VenueBleed"
const STEMS = [MUSIC, AMBIENCE, EFFECTS, UI, DIALOGUE]
const ROUTES = {
	OUTSIDE_BEDS: AMBIENCE,
	OUTSIDE_EFFECTS: EFFECTS,
	ROOM_EFFECTS: EFFECTS,
	STREET_MUSIC: MUSIC,
}

static func ensure() -> void:
	for stem in STEMS:
		_add_bus(stem, "Master")
	for bus in ROUTES:
		var index := _add_bus(bus, ROUTES[bus])
		if AudioServer.get_bus_effect_count(index) != 0:
			continue
		if bus == ROOM_EFFECTS:
			var room := AudioEffectReverb.new()
			room.room_size = 0.28
			room.damping = 0.58
			room.spread = 0.45
			room.dry = 0.92
			room.wet = 0.16
			AudioServer.add_bus_effect(index, room)
		else:
			var filter := AudioEffectLowPassFilter.new()
			filter.cutoff_hz = 2800.0 if bus == STREET_MUSIC else 18000.0
			AudioServer.add_bus_effect(index, filter)

static func _add_bus(bus: String, send: String) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, send)
	return index

## Ambience is attenuated at its bus so indoor/outdoor sources share one
## effective slider without double-applying source gain. World effects use
## the same gain, including train and hero vehicle sounds that previously
## ignored the SFX slider entirely.
static func apply_game_levels(ambience: float, effects: float) -> void:
	ensure()
	set_level(AMBIENCE, ambience)
	set_level(EFFECTS, effects)

static func set_level(bus: String, value: float) -> void:
	var volume := clampf(value, 0.0, 1.0)
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, volume <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, volume)))

static func set_exterior_cutoff(hz: float) -> void:
	for bus in [OUTSIDE_BEDS, OUTSIDE_EFFECTS]:
		var index := AudioServer.get_bus_index(bus)
		var filter := AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter
		if filter != null:
			filter.cutoff_hz = hz

static func exterior_cutoff() -> float:
	var index := AudioServer.get_bus_index(OUTSIDE_BEDS)
	var filter := AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter
	return filter.cutoff_hz if filter != null else 18000.0

static func set_room_character(kind: String) -> void:
	var index := AudioServer.get_bus_index(ROOM_EFFECTS)
	var room := AudioServer.get_bus_effect(index, 0) as AudioEffectReverb
	if room != null:
		room.room_size = 0.52 if kind == "CLUB" else (0.24 if kind == "CAFE" else 0.32)
		room.wet = 0.23 if kind == "CLUB" else (0.12 if kind == "CAFE" else 0.16)

static func is_routed() -> bool:
	for stem in STEMS:
		var index := AudioServer.get_bus_index(stem)
		if index < 0 or AudioServer.get_bus_send(index) != "Master":
			return false
	for bus in ROUTES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0 or AudioServer.get_bus_send(index) != ROUTES[bus]:
			return false
	return true
