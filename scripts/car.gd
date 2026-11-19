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
var police_target: Node3D
var speed := 0.0

func _ready() -> void:
	floor_snap_length = 0.5

func _physics_process(delta: float) -> void:
	if is_police and is_instance_valid(police_target):
		var vector := police_target.global_position - global_position
		vector.y = 0.0
		if vector.length_squared() > 0.5:
			var target_yaw := atan2(-vector.x, -vector.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 2.1, 1.0))
		var target_speed := 19.0 if vector.length() > 4.0 else 3.0
		speed = move_toward(speed, target_speed, ACCEL * delta)
	elif occupied:
		var throttle := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
		var steering := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		if throttle > 0.0:
			speed = move_toward(speed, MAX_SPEED, ACCEL * delta)
		elif throttle < 0.0:
			speed = move_toward(speed, -MAX_REVERSE, BRAKE * delta)
		else:
			speed = move_toward(speed, 0.0, COAST * delta)
		if Input.is_physical_key_pressed(KEY_SPACE):
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
				speed *= 0.5
				break

func speed_kph() -> int:
	return roundi(absf(speed) * 3.6)
