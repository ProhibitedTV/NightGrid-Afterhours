extends CharacterBody3D
## Arcade driving with separate policy-inspired police road controller.
const PoliceDrive = preload("res://scripts/police_drive.gd")
const Foley = preload("res://scripts/city_foley.gd")
const Mix = preload("res://scripts/audio_mix.gd")
const RoadCars = preload("res://scripts/road_car_catalog.gd")

const MAX_SPEED = 36.0
const MAX_REVERSE = 14.0
const ACCEL = 23.0
const BRAKE = 35.0
const COAST = 9.0
const TURN_RATE = 1.7
const GRAVITY = 24.0

var occupied := false
var is_police := false
var police_target: Node3D # legacy fixture compatibility; dispatch uses observed positions
var police_destination := Vector3.INF
var routine_route: Array[Vector3] = []
var routine_index := 0
var response_level := 1
var police_priority := false
var civic_service_hold := false
var police_night := false
var police_signals: Node
var drive_policy = PoliceDrive.new()
var _siren: AudioStreamPlayer3D
var speed := 0.0
var condition := 100.0
var model_id := ""
var specification: Dictionary = {}
var damage_zones := Vector4.ZERO
var road_wetness := 0.0
var _impact_cooldown := 0.0
var _impact_audio: AudioStreamPlayer3D
var _hard_impact_sound: AudioStreamWAV
var _carton_impact_sound: AudioStreamWAV
@onready var hero_visual: Node3D = get_node_or_null("RoadCarVisual") if not model_id.is_empty() else get_node_or_null("KestrelS6HeroVisual")

func configure_road_car(id: String) -> void:
	model_id = id
	specification = RoadCars.DATA[id]

func display_name() -> String:
	return str(specification.get("name", "Kestrel S6"))

func driving_seat() -> Vector3:
	return specification.get("seat", Vector3(-0.52, -0.23, -0.43))

func toggle_near_door(point: Vector3, ignore: RID = RID()) -> bool:
	return not model_id.is_empty() and not occupied and absf(speed) < 0.35 \
		and hero_visual.call("toggle_near_door", point, ignore)

func play_access_door(point: Vector3, leaving: bool, ignore: RID) -> void:
	if not model_id.is_empty():
		hero_visual.call("cycle_access_door", point, leaving, ignore)

func _ready() -> void:
	floor_snap_length = 0.5
	if is_police:
		_siren = AudioStreamPlayer3D.new()
		_siren.name = "ResponseWarning"
		_siren.bus = Mix.EFFECTS
		_siren.stream = Foley.sound("RESPONSE_WARNING")
		_siren.volume_db = -14.0
		_siren.unit_size = 8.0
		_siren.max_distance = 60.0
		add_child(_siren)
	else:
		_hard_impact_sound = Foley.sound("VEHICLE_IMPACT")
		_carton_impact_sound = Foley.sound("CARTON_IMPACT")
		_impact_audio = AudioStreamPlayer3D.new()
		_impact_audio.name = "VehicleImpact"
		_impact_audio.bus = Mix.EFFECTS
		_impact_audio.max_distance = 38.0
		add_child(_impact_audio)

func _physics_process(delta: float) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	var speed_before := speed
	var yaw_before := rotation.y
	var visual_steer := 0.0
	var throttle := 0.0
	var braking := false
	if is_police and (condition <= 18.0 or civic_service_hold):
		speed = move_toward(speed, 0.0, BRAKE * delta)
		braking = true
	elif is_police:
		var responding := police_destination.is_finite()
		var goal := police_destination
		if not responding and not routine_route.is_empty():
			goal = routine_route[routine_index]
			if drive_policy.arrived(Vector2(global_position.x, global_position.z), Vector2(goal.x, goal.z)) or global_position.distance_to(goal) < 1.5:
				routine_index = (routine_index + 1) % routine_route.size()
				goal = routine_route[routine_index]
		if not goal.is_finite():
			goal = global_position
		var at := Vector2(global_position.x, global_position.z)
		var point: Vector2 = drive_policy.next_point(at, Vector2(goal.x, goal.z))
		var toward := Vector3(point.x - at.x, 0, point.y - at.y)
		var turn_error := 0.0
		if toward.length_squared() > 0.5:
			var target_yaw := atan2(-toward.x, -toward.z)
			turn_error = wrapf(target_yaw - rotation.y, -PI, PI)
			visual_steer = clampf(turn_error, -1.0, 1.0)
			rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 2.3, 1.0))
		var signal_cap := PoliceDrive.RESPONSE_SPEED
		if is_instance_valid(police_signals):
			var heading := -global_basis.z
			signal_cap = float(police_signals.call("approach_speed_cap", global_position, heading, signal_cap))
		var clear: float = drive_policy.clearance(self, delta)
		var target_speed: float = PoliceDrive.safe_speed(responding and police_priority, toward.length(), turn_error, clear, signal_cap, police_night)
		braking = speed > target_speed + 0.1
		speed = move_toward(speed, target_speed, (BRAKE if braking else 8.0) * delta)
	elif occupied:
		throttle = Input.get_action_strength("drive_accelerate") - Input.get_action_strength("drive_reverse")
		var steering := Input.get_axis("move_left", "move_right")
		visual_steer = steering
		braking = Input.is_action_pressed("drive_brake") or (throttle < 0.0 and speed > 0.25)
		if specification.is_empty():
			_drive_legacy(throttle, steering, delta)
		else:
			_drive_road_car(throttle, steering, delta)
	else:
		speed = move_toward(speed, 0.0, COAST * delta)
	var forward := -global_transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1
	var incoming := Vector3(velocity.x, 0.0, velocity.z)
	var before_slide := global_position
	move_and_slide()
	# Use this tick's real longitudinal movement for road-car wheel roll.
	# Wall clipping, glancing contact, and momentum loss must not fake travel.
	var rolling_distance := (global_position - before_slide).dot(forward)
	braking = _resolve_contacts(incoming) or braking
	var warning := is_police and condition > 18.0 and police_destination.is_finite() and police_priority
	if is_instance_valid(_siren):
		if warning and not _siren.playing:
			_siren.play()
		elif not warning and _siren.playing:
			_siren.stop()
	if hero_visual != null:
		if specification.is_empty():
			hero_visual.call("update_motion", speed, visual_steer, braking, occupied, warning, delta)
		else:
			# Cosmetic loads only: use measured travel and heading change; never
			# tilt the CharacterBody3D or alter its collider/steering policy.
			var loads := Vector2.ZERO
			if occupied and is_on_floor() and delta > 0.0:
				var measured_speed := rolling_distance / delta
				loads.x = (measured_speed - speed_before) / delta
				loads.y = -angle_difference(yaw_before, rotation.y) / delta * measured_speed
			hero_visual.call("update_motion", speed, visual_steer, braking, occupied, throttle, road_wetness, delta, rolling_distance, loads)
			hero_visual.call("sample_suspension", get_rid(), occupied and is_on_floor(), delta,
				rolling_distance / delta if delta > 0.0 else 0.0, road_wetness, is_on_floor())

func _drive_legacy(throttle: float, steering: float, delta: float) -> void:
	if throttle > 0.0:
		speed = move_toward(speed, MAX_SPEED * lerpf(0.55, 1.0, condition / 100.0), ACCEL * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, -MAX_REVERSE, BRAKE * delta)
	else:
		speed = move_toward(speed, 0.0, COAST * delta)
	if Input.is_action_pressed("drive_brake"):
		speed = move_toward(speed, 0.0, BRAKE * 2.0 * delta)
	if absf(speed) > 0.5:
		rotation.y -= steering * TURN_RATE * clampf(absf(speed) / 14.0, 0.15, 1.0) * signf(speed) * delta

func _drive_road_car(throttle: float, steer: float, delta: float) -> void:
	var top := float(specification["top"])
	var tyre_grip := 1.0 - road_wetness * 0.23
	var engine := smoothstep(18.0, 100.0, condition)
	var moving := absf(speed)
	var braking := float(specification["brake"]) * tyre_grip
	if Input.is_action_pressed("drive_brake"):
		speed = move_toward(speed, 0.0, braking * 1.22 * delta)
	elif throttle < -0.01:
		var target := 0.0 if speed > 0.18 else -8.0 * engine
		speed = move_toward(speed, target, braking * -throttle * delta)
	elif throttle > 0.01 and engine > 0.0:
		var launch_grip := lerpf(tyre_grip, 1.0, smoothstep(0.0, 23.0, moving))
		var power_band := lerpf(1.0, 0.38, pow(clampf(moving / top, 0.0, 1.0), 1.58))
		var acceleration := float(specification["accel"]) * power_band * launch_grip * engine
		speed = move_toward(speed, top * lerpf(0.42, 1.0, engine), acceleration * throttle * delta)
	else:
		speed = move_toward(speed, 0.0, (1.65 + moving * 0.035) * delta)
	if moving > 0.45:
		var low_speed := smoothstep(0.28, 12.0, moving)
		var fast_speed := lerpf(1.0, 0.27, smoothstep(17.0, top, moving))
		var pull := clampf(damage_zones.z - damage_zones.w, -0.65, 0.65) * 0.13
		var response := float(specification["turn"]) * float(specification["grip"]) / 11.5
		rotation.y -= (steer + pull) * response * low_speed * fast_speed * tyre_grip * signf(speed) * delta

func _resolve_contacts(incoming: Vector3) -> bool:
	var entry_speed := incoming.length()
	if entry_speed < 0.1:
		return false
	var retained := 1.0
	var hard_closing := 0.0
	var light_closing := 0.0
	var impact_at := Vector3.ZERO
	var impacted_vehicle: CharacterBody3D
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var normal := contact.get_normal()
		if absf(normal.y) >= 0.50:
			continue
		normal = Vector3(normal.x, 0.0, normal.z).normalized()
		var closing := -(incoming - contact.get_collider_velocity()).dot(normal)
		if closing <= 0.2:
			continue
		var obstacle := contact.get_collider()
		if obstacle != null and obstacle.has_method("knock_loose"):
			if obstacle.call("knock_loose", closing, -normal, contact.get_position()):
				light_closing = maxf(light_closing, closing)
				retained = minf(retained, 0.90)
				continue
		# A glancing scrape sheds only its into-wall component. A direct
		# strike loses forward momentum even during the damage cooldown.
		var incidence := clampf(-incoming.dot(normal) / entry_speed, 0.0, 1.0)
		retained = minf(retained, sqrt(1.0 - incidence * incidence))
		if closing > hard_closing:
			hard_closing = closing
			impact_at = to_local(contact.get_position())
			impacted_vehicle = obstacle as CharacterBody3D
	speed *= retained
	if not is_police:
		if hard_closing >= 5.0 and _impact_cooldown <= 0.0:
			var crush := 1.0 if specification.is_empty() else sqrt(1740.0 / float(specification["mass"]))
			var damage_limit := 20.0 if specification.is_empty() else 25.0
			take_arcade_damage(clampf((hard_closing - 4.0) * 0.62 * crush, 1.0, damage_limit))
			if not model_id.is_empty():
				_record_body_impact(impact_at, hard_closing)
			_impact_cooldown = 0.65
			_play_impact(_hard_impact_sound, hard_closing, 30.0)
			if impacted_vehicle != null and impacted_vehicle.has_method("receive_vehicle_impact"):
				impacted_vehicle.call("receive_vehicle_impact", to_global(impact_at), incoming.normalized(),
					hard_closing, float(specification.get("mass", 1740.0)))
		elif light_closing > 0.0 and not _impact_audio.playing:
			_play_impact(_carton_impact_sound, light_closing, 18.0)
	return retained < 0.75

func _play_impact(stream: AudioStreamWAV, closing_speed: float, full_scale: float) -> void:
	_impact_audio.stream = stream
	_impact_audio.volume_db = lerpf(-22.0, -5.0, clampf(closing_speed / full_scale, 0.0, 1.0))
	_impact_audio.play()

func take_arcade_damage(amount: float) -> void:
	condition = maxf(18.0, condition - maxf(amount, 0.0))

func _record_body_impact(point: Vector3, closing: float) -> void:
	var bounds: Vector3 = specification["body"]
	var fore_aft := absf(point.z) / (bounds.z * 0.5)
	var crosswise := absf(point.x) / (bounds.x * 0.5)
	var zone := 0 if point.z < 0.0 else 1
	if crosswise > fore_aft + 0.17:
		zone = 2 if point.x < 0.0 else 3
	damage_zones[zone] = minf(1.0, damage_zones[zone] + clampf((closing - 4.0) / 33.0, 0.04, 0.95))
	hero_visual.call("apply_damage", damage_zones)

func receive_vehicle_impact(world_contact: Vector3, direction: Vector3, closing: float, striking_mass: float) -> void:
	if model_id.is_empty() or closing < 6.0 or _impact_cooldown > 0.0:
		return
	var mass_share := striking_mass / (float(specification["mass"]) + striking_mass)
	var push := clampf(direction.dot(-global_basis.z) * closing * mass_share * 0.52, -6.0, 9.0)
	speed += push
	var severity := closing * lerpf(0.44, 1.0, mass_share)
	take_arcade_damage(clampf((severity - 4.0) * 0.62, 1.0, 20.0))
	_record_body_impact(to_local(world_contact), severity)
	_impact_cooldown = 0.65

func restore_damage(saved: Variant) -> void:
	damage_zones = Vector4.ZERO
	if saved is Array and saved.size() == 4:
		for index in 4:
			var channel: Variant = saved[index]
			if (channel is float or channel is int) and is_finite(float(channel)):
				damage_zones[index] = clampf(float(channel), 0.0, 1.0)
	if not model_id.is_empty():
		hero_visual.call("apply_damage", damage_zones)
		hero_visual.call("close_doors_immediate")
		hero_visual.call("reset_body_pose")
		hero_visual.call("reset_suspension")
		hero_visual.call("reset_instrument_cluster")

func repair() -> void:
	condition = 100.0
	restore_damage([])

func speed_kph() -> int:
	return roundi(absf(speed) * 3.6)
