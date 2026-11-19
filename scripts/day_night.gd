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
var _update_accumulator := 0.0

func configure(world_environment: WorldEnvironment, sun: DirectionalLight3D, city: Node, lights: Node) -> void:
	_environment = world_environment
	_sun = sun
	_city = city
	_lights = lights
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_environment.environment.sky = sky
	_environment.environment.background_mode = Environment.BG_SKY
	_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_apply()

func _process(delta: float) -> void:
	if not paused:
		hour = fposmod(hour + delta * 24.0 / DAY_LENGTH_SECONDS, 24.0)
	_update_accumulator += delta
	if _update_accumulator >= 0.20:
		_update_accumulator = 0.0
		_apply()

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
	var noon := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
	var twilight := 1.0 - absf(light * 2.0 - 1.0)
	var night_top := Color("10182d")
	var day_top := Color("74b7cf")
	_sky.sky_top_color = night_top.lerp(day_top, light)
	_sky.sky_horizon_color = Color("4c3153").lerp(Color("d9c5a3"), light)
	_sky.ground_bottom_color = Color("0f1728").lerp(Color("617276"), light)
	_sky.ground_horizon_color = Color("433145").lerp(Color("b4a999"), light)
	_environment.environment.ambient_light_color = Color("8291b5").lerp(Color("f3dbb5"), light)
	_environment.environment.ambient_light_energy = lerpf(0.43, 0.82, light)
	_sun.light_color = Color("8eabda").lerp(Color("ffe6c2"), light).lerp(Color("ffad86"), twilight * 0.15)
	_sun.light_energy = lerpf(0.13, 1.30, light)
	var altitude := 9.0 + 64.0 * noon
	_sun.rotation_degrees = Vector3(-altitude, hour * 15.0 + 90.0, -4.0)
	if is_instance_valid(_city):
		_city.call("set_night_factor", 1.0 - light)
	if is_instance_valid(_lights):
		_lights.call("set_night_factor", 1.0 - light)
