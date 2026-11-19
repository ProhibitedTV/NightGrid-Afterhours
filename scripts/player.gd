extends CharacterBody3D
## Third-person player controller.

const WALK_SPEED = 7.5
const RUN_SPEED = 12.5
const JUMP_SPEED = 9.0
const ACCEL = 24.0
const GRAVITY = 24.0

var camera_yaw := 0.0
var driving := false
var visual: Node3D

func _ready() -> void:
	floor_snap_length = 0.35
	visual = get_node_or_null("Visual")

func _physics_process(delta: float) -> void:
	if driving:
		return
	var axes := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).normalized()
	var move_direction := Vector3(axes.x, 0.0, axes.y).rotated(Vector3.UP, camera_yaw)
	var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	velocity.x = move_toward(velocity.x, move_direction.x * speed, ACCEL * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * speed, ACCEL * delta)
	if is_on_floor():
		if Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	if visual != null and move_direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-move_direction.x, -move_direction.z), minf(delta * 12.0, 1.0))
	move_and_slide()
