extends CharacterBody3D
## Third-person player controller.

const WALK_SPEED = 7.5
const RUN_SPEED = 12.5
const JUMP_SPEED = 9.0
const ACCEL = 24.0
const GRAVITY = 24.0

var camera_yaw := 0.0
var driving := false
var input_blocked := false
var visual: Node3D

func _ready() -> void:
	floor_snap_length = 0.35
	visual = get_node_or_null("Visual")

# The original courier's nose/eyes are authored toward +Z, unlike the
# conventional Godot -Z camera axis. Keep this convention testable when
# camera orientation or character assets change.
static func visual_yaw_for_motion(motion: Vector3) -> float:
	return atan2(motion.x, motion.z)

func _physics_process(delta: float) -> void:
	if driving or input_blocked:
		velocity = Vector3.ZERO
		return
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction := Vector3(axes.x, 0.0, axes.y).rotated(Vector3.UP, camera_yaw)
	var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if visual != null and visual.has_method("set_locomotion"):
		visual.call("set_locomotion", move_direction.length() * speed)
	velocity.x = move_toward(velocity.x, move_direction.x * speed, ACCEL * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * speed, ACCEL * delta)
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	# Human mesh faces local +Z (nose/eyes are on +Z). Movement uses -Z
	# for W; negate neither axis or the player faces the camera while moving.
	if visual != null and move_direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, visual_yaw_for_motion(move_direction), minf(delta * 12.0, 1.0))
	move_and_slide()
