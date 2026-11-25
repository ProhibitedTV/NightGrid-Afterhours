extends RefCounted
## Original NightGrid coastal sky art, deterministic preset selector.
## Sky pictures are LDR converted scenic images, not captured HDR radiance.
const ROOT = "res://assets/skyboxes/nightgrid_original/"
const FILES = {
	"clear_day": "clear_day.webp",
	"dawn_clear": "dawn_clear.webp",
	"dawn_overcast": "dawn_overcast.webp",
	"afternoon_clouds": "afternoon_clouds.webp",
	"evening_clear": "evening_clear.webp",
	"overcast_day": "overcast_day.webp",
	"storm_day": "storm_day.webp",
	"moonlit_night": "moonlit_night.webp"
}
const WEATHER_ORDER = ["clear", "cloudy", "overcast", "rain", "storm"]

static func texture_path(preset: String) -> String:
	return ROOT + str(FILES.get(preset, FILES["clear_day"]))

static func valid_weather(value: String) -> bool:
	return WEATHER_ORDER.has(value)

static func select_preset(hour_value: float, weather: String) -> String:
	var t := fposmod(hour_value, 24.0)
	var state := weather if valid_weather(weather) else "clear"
	if t < 5.0 or t >= 20.0:
		return "moonlit_night" if state == "clear" else ("storm_day" if state == "rain" or state == "storm" else "overcast_day")
	if state == "rain" or state == "storm":
		return "storm_day"
	if t < 8.0:
		return "dawn_clear" if state == "clear" else "dawn_overcast"
	if state == "overcast":
		return "overcast_day"
	if state == "cloudy":
		return "afternoon_clouds"
	if t >= 16.0:
		return "evening_clear"
	return "clear_day"

static func sun_factor(weather: String) -> float:
	match weather:
		"cloudy": return 0.82
		"overcast": return 0.58
		"rain": return 0.36
		"storm": return 0.22
	return 1.0

static func panorama_energy(hour_value: float, weather: String) -> float:
	var t := fposmod(hour_value, 24.0)
	if t < 5.0 or t >= 20.0:
		return 0.82 if weather == "clear" else 0.25
	if weather == "storm":
		return 0.65
	if weather == "rain":
		return 0.75
	return 1.0

static func fog_factor(weather: String) -> float:
	match weather:
		"cloudy": return 1.10
		"overcast": return 1.32
		"rain": return 1.58
		"storm": return 1.87
	return 1.0
