extends CharacterBody3D
## Arcade driving with separate policy-inspired police road controller.
const PoliceDrive = preload("res://scripts/police_drive.gd")
const Foley = preload("res://scripts/city_foley.gd")
const Mix = preload("res://scripts/audio_mix.gd")

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
var _impact_cooldown := 0.0
@onready var hero_visual: Node3D = get_node_or_null("KestrelS6HeroVisual")

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

func _physics_process(delta: float) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	var visual_steer := 0.0
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
		var throttle := Input.get_action_strength("drive_accelerate") - Input.get_action_strength("drive_reverse")
		var steering := Input.get_axis("move_left", "move_right")
		visual_steer = steering
		braking = Input.is_action_pressed("drive_brake") or (throttle < 0.0 and speed > 0.25)
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
	else:
		speed = move_toward(speed, 0.0, COAST * delta)
	var forward := -global_transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	if absf(speed) > 8.0:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_normal().y < 0.5:
				if not is_police and _impact_cooldown <= 0.0:
					condition = maxf(18.0, condition - 9.0)
					_impact_cooldown = 1.2
				speed *= 0.5
				braking = true
				break
	var warning := is_police and condition > 18.0 and police_destination.is_finite() and police_priority
	if is_instance_valid(_siren):
		if warning and not _siren.playing:
			_siren.play()
		elif not warning and _siren.playing:
			_siren.stop()
	if hero_visual != null:
		hero_visual.call("update_motion", speed, visual_steer, braking, occupied, warning, delta)

func take_arcade_damage(amount: float) -> void:
	condition = maxf(18.0, condition - maxf(amount, 0.0))

func repair() -> void:
	condition = 100.0

func speed_kph() -> int:
	return roundi(absf(speed) * 3.6)
