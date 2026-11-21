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

static func is_routed() -> bool:
	for stem in STEMS:
		var index := AudioServer.get_bus_index(stem)
		if index < 0 or AudioServer.get_bus_send(index) != "Master":
			return false
	return true
