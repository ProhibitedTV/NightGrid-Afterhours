extends RefCounted
## Persistent quality choices are separate from the live day/night and F11 look.
const PROFILES = ["performance", "high", "ultra", "cinematic"]
const FEATURES = ["ssr_enabled", "ao_enabled", "glow_enabled", "fog_enabled", "ssil_enabled"]
const PRESETS = {
	"performance": {"ssr_enabled":false,"ao_enabled":false,"glow_enabled":true,"fog_enabled":true,"ssil_enabled":false,"scale":.90,"ssr_steps":16},
	"high": {"ssr_enabled":true,"ao_enabled":true,"glow_enabled":true,"fog_enabled":true,"ssil_enabled":false,"scale":1.0,"ssr_steps":24},
	"ultra": {"ssr_enabled":true,"ao_enabled":true,"glow_enabled":true,"fog_enabled":true,"ssil_enabled":false,"scale":1.0,"ssr_steps":48},
	"cinematic": {"ssr_enabled":true,"ao_enabled":true,"glow_enabled":true,"fog_enabled":true,"ssil_enabled":true,"scale":1.0,"ssr_steps":64},
}
var _applied: Dictionary = {}
var active_profile := "high"

static func normalized_profile(value: Variant) -> String:
	return value if value is String and value in PROFILES else "high"

static func normalize(settings: Dictionary, legacy: bool = false) -> void:
	var chosen := normalized_profile(settings.get("render_quality"))
	settings["render_quality"] = chosen
	var stored: Variant = settings.get("render_overrides", {})
	var overrides := {}
	if stored is Dictionary:
		for profile in PROFILES:
			var entries: Variant = stored.get(profile)
			if entries is Dictionary:
				for key in FEATURES:
					if entries.get(key) is bool and entries[key] != PRESETS[profile][key]:
						if not overrides.has(profile):
							overrides[profile] = {}
						overrides[profile][key] = entries[key]
	if legacy:
		# Existing config files persist the individual choices as flat keys.
		for key in FEATURES:
			var old := bool(settings.get(key, PRESETS["high"][key]))
			if old != PRESETS["high"][key]:
				if not overrides.has("high"):
					overrides["high"] = {}
				overrides["high"][key] = old
	settings["render_overrides"] = overrides
	for key in FEATURES:
		settings[key] = overrides.get(chosen, {}).get(key, PRESETS[chosen][key])

static func set_feature(settings: Dictionary, key: String, enabled: bool) -> void:
	var profile: String = settings["render_quality"]
	var overrides: Dictionary = settings["render_overrides"]
	if not overrides.has(profile):
		overrides[profile] = {}
	overrides[profile][key] = enabled

func apply(environment: Environment, viewport: Viewport, settings: Dictionary) -> void:
	var profile := normalized_profile(settings.get("render_quality"))
	active_profile = profile
	var options: Dictionary = PRESETS[profile].duplicate()
	for key in FEATURES:
		if settings.has(key):
			options[key] = settings[key]
	if options == _applied:
		return
	_applied = options
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus" or DisplayServer.get_name() == "headless"
	environment.ssr_enabled = forward and options["ssr_enabled"]
	environment.ssr_max_steps = options["ssr_steps"]
	environment.ssr_fade_out = 1.4
	environment.ssao_enabled = forward and options["ao_enabled"]
	environment.ssao_radius = 1.85
	environment.ssao_intensity = .95
	environment.ssao_power = 1.25
	environment.ssil_enabled = forward and options["ssil_enabled"]
	environment.glow_enabled = options["glow_enabled"]
	environment.glow_intensity = .46
	environment.glow_hdr_threshold = 1.15
	environment.fog_enabled = options["fog_enabled"]
	viewport.scaling_3d_scale = options["scale"]
