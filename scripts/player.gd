extends CharacterBody3D
## Third-person player controller.

const WALK_SPEED = 7.5
const RUN_SPEED = 12.5
const JUMP_SPEED = 9.0
const ACCEL = 24.0
const GRAVITY = 24.0

var camera_yaw := 0.0
var driving := false:
	set(value):
		driving = value
		if not driving and is_instance_valid(visual) and visual.get_parent() != self:
			visual.call("return_to_player", self)
var input_blocked := false
var weapon_aiming := false
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
	var sprinting := Input.is_action_pressed("sprint")
	var speed := RUN_SPEED if sprinting else WALK_SPEED
	velocity.x = move_toward(velocity.x, move_direction.x * speed, ACCEL * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * speed, ACCEL * delta)
	var was_grounded := is_on_floor()
	var jumped := was_grounded and Input.is_action_just_pressed("jump")
	if was_grounded:
		if jumped:
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	# Human mesh faces local +Z (nose/eyes are on +Z). Movement uses -Z
	# for W; negate neither axis or the player faces the camera while moving.
	if visual != null and weapon_aiming:
		visual.rotation.y = lerp_angle(visual.rotation.y, camera_yaw + PI, minf(delta * 18.0, 1.0))
	elif visual != null and move_direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, visual_yaw_for_motion(move_direction), minf(delta * 12.0, 1.0))
	move_and_slide()
	if visual != null and visual.has_method("update_motion"):
		var local_velocity := visual.global_basis.inverse() * get_real_velocity()
		visual.call("update_motion", local_velocity, is_on_floor(), jumped, not was_grounded and is_on_floor(), sprinting)

func show_vehicle_rider(vehicle: Node3D, offer_entry: bool) -> void:
	if visual == null or not visual.has_method("sit_in_vehicle"):
		return
	var at := vehicle.to_local(global_position)
	var at_driver_side := at.x < -1.0 and at.x > -2.4 and absf(at.z + 0.43) < 0.9
	var local_boot_y := vehicle.to_local(visual.global_position).y
	visual.call("sit_in_vehicle", vehicle, offer_entry and at_driver_side, local_boot_y)

func play_visual_action(clip: StringName) -> void:
	if not driving and is_instance_valid(visual):
		visual.call("play_action", clip)
