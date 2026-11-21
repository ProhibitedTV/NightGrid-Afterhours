extends RefCounted
## Shared routing contract for the original game soundtrack and effects.
## Buses are initialized once per process and survive scene reloads.
## Existing player-facing volume settings continue to control source gain;
## the independent buses allow actual stem metering and future DSP/mix passes.
const MUSIC = "NightGridMusic"
const AMBIENCE = "CityAmbience"
const EFFECTS = "WorldSFX"
const UI = "NightGridUI"
const STEMS = [MUSIC, AMBIENCE, EFFECTS, UI]

static func ensure() -> void:
	for stem in STEMS:
		if AudioServer.get_bus_index(stem) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, stem)
		AudioServer.set_bus_send(index, "Master")

## Ambience is attenuated at its bus so indoor/outdoor sources share one
## effective slider without double-applying source gain. World effects use
## the same gain, including train and hero vehicle sounds that previously
## ignored the SFX slider entirely.
static func apply_game_levels(ambience: float, effects: float) -> void:
	ensure()
	for stem in [AMBIENCE, EFFECTS]:
		var volume := clampf(ambience if stem == AMBIENCE else effects, 0.0, 1.0)
		var index := AudioServer.get_bus_index(stem)
		AudioServer.set_bus_mute(index, volume <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, volume)))

static func is_routed() -> bool:
	for stem in STEMS:
		var index := AudioServer.get_bus_index(stem)
		if index < 0 or AudioServer.get_bus_send(index) != "Master":
			return false
	return true
