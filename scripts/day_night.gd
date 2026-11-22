extends Node
## A cheap, continuously interpolated 24-hour light cycle.
## A single shadow caster is retained for predictable midrange GPU performance.

const DAY_LENGTH_SECONDS = 1440.0
const START_HOUR = 19.25
var hour: float = START_HOUR
var paused := false
var _environment: WorldEnvironment
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _city: Node
var _lights: Node
var _hero_intersection: Node
var _update_accumulator := 0.0
var _last_atmosphere_hour := -1.0
var _last_atmosphere_profile := ""
var _last_sky_light := -1.0
var _atmosphere_updates := 0
var _sky_updates := 0
# Temporary comparison only. The legacy Filmic renderer remains the default;
# we will not promote a preset without Windows Forward+ and frame-time review.
var _compare_sky_aces := false
var _compare_sky_agx := false
var _original_shadow_distance := 170.0
var _original_sun_angle := 0.0

func configure(world_environment: WorldEnvironment, sun: DirectionalLight3D, city: Node, lights: Node, hero_intersection: Node = null) -> void:
	_environment = world_environment
	_sun = sun
	_city = city
	_lights = lights
	_hero_intersection = hero_intersection
	_original_shadow_distance = _sun.directional_shadow_max_distance
	_original_sun_angle = _sun.light_angular_distance
	_last_atmosphere_hour = -1.0
	_last_atmosphere_profile = ""
	_last_sky_light = -1.0
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_environment.environment.sky = sky
	_environment.environment.background_mode = Environment.BG_SKY
	_apply()

func _process(delta: float) -> void:
	if not paused:
		hour = fposmod(hour + delta * 24.0 / DAY_LENGTH_SECONDS, 24.0)
	_update_accumulator += delta
	if _update_accumulator >= 0.20:
		_update_accumulator = 0.0
		_apply()

func set_render_comparison(enabled: bool) -> void:
	# Preserve the beta.3 scripting contract. Engine-upgrade A/B uses the
	# explicit cycle below so older test automation still behaves identically.
	_compare_sky_aces = enabled
	_compare_sky_agx = false
	_apply()

func cycle_render_profile() -> String:
	if _compare_sky_aces:
		_compare_sky_aces = false
		_compare_sky_agx = true
	elif _compare_sky_agx:
		_compare_sky_agx = false
	else:
		_compare_sky_aces = true
	_apply()
	return get_render_profile()

func is_render_comparison_enabled() -> bool:
	return _compare_sky_aces or _compare_sky_agx

func get_render_profile() -> String:
	if _compare_sky_agx:
		return "sky_agx_experiment"
	return "sky_aces_experiment" if _compare_sky_aces else "filmic_baseline"

func set_hour(value: float) -> void:
	hour = fposmod(value, 24.0)
	_apply()

func advance_hour(value: float = 1.0) -> void:
	set_hour(hour + value)

func toggle_pause() -> void:
	paused = not paused

func clock_string() -> String:
	var total_minutes := int(floor(hour * 60.0)) % 1440
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]

func daylight_amount() -> float:
	var sunrise := smoothstep(5.5, 7.5, hour)
	var sunset := 1.0 - smoothstep(18.0, 20.0, hour)
	return clampf(sunrise * sunset, 0.0, 1.0)

func _apply() -> void:
	if _environment == null or _sun == null or _sky == null:
		return
	var light := daylight_amount()
	var profile := get_render_profile()
	if hour != _last_atmosphere_hour or profile != _last_atmosphere_profile:
		_apply_atmosphere(light)
		_last_atmosphere_hour = hour
		_last_atmosphere_profile = profile
		_atmosphere_updates += 1
	# Keep notifications at their original cadence: newly streamed materials
	# and newly focused practical lights may need synchronization even when
	# the player pauses the time of day.
	if is_instance_valid(_city):
		_city.call("set_night_factor", 1.0 - light)
	if is_instance_valid(_lights):
		_lights.call("set_night_factor", 1.0 - light)
	if is_instance_valid(_hero_intersection):
		_hero_intersection.call("set_night_factor", 1.0 - light)

func _apply_atmosphere(light:float) -> void:
	var noon := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
	var twilight := 1.0 - absf(light * 2.0 - 1.0)
	# Day/night plateaus have byte-identical sky colors. Do not dirty the sky
	# resource just because the sun rotates or F11 changes tonemapping.
	if light != _last_sky_light:
		var night_top := Color("10182d")
		var day_top := Color("74b7cf")
		_sky.sky_top_color = night_top.lerp(day_top, light)
		_sky.sky_horizon_color = Color("4c3153").lerp(Color("d9c5a3"), light)
		_sky.ground_bottom_color = Color("0f1728").lerp(Color("617276"), light)
		_sky.ground_horizon_color = Color("433145").lerp(Color("b4a999"), light)
		_last_sky_light = light
		_sky_updates += 1
	_environment.environment.ambient_light_color = Color("8291b5").lerp(Color("f3dbb5"), light)
	_environment.environment.ambient_light_energy = lerpf(0.40, 0.78, light)
	# Godot 4.7.2 supports the video creator's AgX highlight rolloff.
	# F11 cycles old Filmic (default), beta.3's ACES, then new AgX.
	# Sky lighting, fog and shadows are identical for the two experimental
	# modes: the ACES/AgX comparison isolates tonemapping differences.
	# Do not enable heavy GI/volumetrics without RTX 3060 measurements.
	var experiment := _compare_sky_aces or _compare_sky_agx
	_environment.environment.tonemap_mode = (Environment.TONE_MAPPER_AGX if _compare_sky_agx
		else Environment.TONE_MAPPER_ACES if _compare_sky_aces else Environment.TONE_MAPPER_FILMIC)
	_environment.environment.tonemap_exposure = 1.11 if experiment else 1.0
	_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if experiment else Environment.AMBIENT_SOURCE_COLOR
	_environment.environment.ambient_light_sky_contribution = 0.78 if experiment else 0.0
	_sun.directional_shadow_max_distance = 96.0 if experiment else _original_shadow_distance
	_sun.light_angular_distance = 0.7 if experiment else _original_sun_angle
	# Distance haze shifts from cool coastal night to warm daytime air, but does
	# not override the player's fog toggle or allocate volumetric fog buffers.
	_environment.environment.fog_density = (lerpf(0.0052, 0.0036, light)
		if _compare_sky_aces or _compare_sky_agx else lerpf(0.0085, 0.0045, light))
	_environment.environment.fog_sky_affect = 0.24 if _compare_sky_aces or _compare_sky_agx else 0.35
	_environment.environment.fog_light_color = Color("2b354b").lerp(Color("c4d0c7"), light).lerp(Color("b77d65"), twilight * 0.22)
	_sun.light_color = Color("8eabda").lerp(Color("ffe6c2"), light).lerp(Color("ffad86"), twilight * 0.15)
	_sun.light_energy = lerpf(0.13, 1.30, light)
	var altitude := 9.0 + 64.0 * noon
	_sun.rotation_degrees = Vector3(-altitude, hour * 15.0 + 90.0, -4.0)

