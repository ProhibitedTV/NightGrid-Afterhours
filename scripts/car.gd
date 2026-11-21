extends CharacterBody3D
## Arcade driving and basic police-pursuit steering.

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
var speed := 0.0
var condition := 100.0
var _impact_cooldown := 0.0
@onready var hero_visual: Node3D = get_node_or_null("KestrelS6HeroVisual")

func _ready() -> void:
	floor_snap_length = 0.5

func _physics_process(delta: float) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	var visual_steer := 0.0
	var braking := false
	if is_police and condition <= 18.0:
		speed = move_toward(speed, 0.0, BRAKE * delta)
		braking = true
	elif is_police:
		var responding := police_destination.is_finite()
		var goal := police_destination
		if not responding and not routine_route.is_empty():
			goal = routine_route[routine_index]
			if global_position.distance_to(goal) < 5.0:
				routine_index = (routine_index + 1) % routine_route.size()
				goal = routine_route[routine_index]
		if not goal.is_finite():
			goal = global_position
		var vector := goal - global_position
		vector.y = 0.0
		if vector.length_squared() > 0.5:
			var target_yaw := atan2(-vector.x, -vector.z)
			visual_steer = clampf(wrapf(target_yaw - rotation.y, -PI, PI), -1.0, 1.0)
			rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 2.1, 1.0))
		var target_speed := (17.0 + 2.0 * float(response_level) if responding else 9.0) if vector.length() > 5.0 else 0.0
		speed = move_toward(speed, target_speed, ACCEL * delta)
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
	if hero_visual != null:
		hero_visual.call("update_motion", speed, visual_steer, braking, occupied, is_police and police_destination.is_finite(), delta)

func take_arcade_damage(amount: float) -> void:
	condition = maxf(18.0, condition - maxf(amount, 0.0))

func repair() -> void:
	condition = 100.0

func speed_kph() -> int:
	return roundi(absf(speed) * 3.6)
