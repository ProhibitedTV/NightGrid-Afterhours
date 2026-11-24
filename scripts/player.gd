extends CharacterBody3D
## Third-person player controller.

const WALK_SPEED = 7.5
const RUN_SPEED = 12.5
const JUMP_SPEED = 9.0
const Locomotion = preload("res://scripts/locomotion_policy.gd")
const GRAVITY = 24.0

const STAMINA_MAX = 100.0
const SPRINT_DRAIN = 14.0
const STAMINA_REGEN = 18.0
const JUMP_COST = 12.0
var stamina := STAMINA_MAX
var _stamina_delay := 0.0
var _exhausted := false
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

func restore_stamina(value: Variant) -> void:
	stamina = clampf(float(value),0.0,STAMINA_MAX) if (value is int or value is float) and is_finite(float(value)) else STAMINA_MAX
	_exhausted = stamina <= 0.0
	_stamina_delay = 0.0

func add_stamina(amount: float) -> void:
	stamina = clampf(stamina+amount,0.0,STAMINA_MAX)
	if stamina >= 20.0:
		_exhausted = false

func tick_stamina(delta: float, wants_sprint: bool, moving: bool, wants_jump: bool) -> Vector2i:
	# Return actual sprint/jump permission. Exhaustion hysteresis avoids
	# rapidly alternating run/walk when sprint remains held at zero.
	var sprint := wants_sprint and moving and not _exhausted and stamina > 0.0
	var jump := wants_jump and stamina >= JUMP_COST
	if sprint or jump:
		stamina = maxf(0.0,stamina-(SPRINT_DRAIN*delta if sprint else 0.0)-(JUMP_COST if jump else 0.0))
		_stamina_delay = .8
		if stamina <= 0.0:
			_exhausted = true
	else:
		_stamina_delay = maxf(0.0,_stamina_delay-delta)
		if _stamina_delay <= 0.0:
			add_stamina(STAMINA_REGEN*delta)
	return Vector2i(int(sprint),int(jump))

func _physics_process(delta: float) -> void:
	if driving or input_blocked:
		velocity = Vector3.ZERO
		if driving:
			tick_stamina(delta,false,false,false)
		return
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction := Vector3(axes.x, 0.0, axes.y).rotated(Vector3.UP, camera_yaw)
	var was_grounded := is_on_floor()
	var allowance := tick_stamina(delta,Input.is_action_pressed("sprint"),move_direction.length_squared()>.01,was_grounded and Input.is_action_just_pressed("jump"))
	var sprinting := allowance.x == 1
	var speed := RUN_SPEED if sprinting else WALK_SPEED
	# Keep the verified physical controller contract; visual smoothing must
	# not change the displacement of a timed traversal or rail approach.
	velocity = Locomotion.step_velocity(velocity,move_direction*speed,was_grounded,delta)
	var jumped := allowance.y == 1
	if was_grounded:
		if jumped:
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	# Human mesh faces local +Z (nose/eyes are on +Z). Movement uses -Z
	# for W; negate neither axis or the player faces the camera while moving.
	if visual != null and weapon_aiming:
		visual.rotation.y = Locomotion.step_yaw(visual.rotation.y,camera_yaw+PI,true,delta)
	elif visual != null and move_direction.length_squared() > 0.01:
		visual.rotation.y = Locomotion.step_yaw(visual.rotation.y,visual_yaw_for_motion(move_direction),false,delta)
	move_and_slide()
	if visual != null and visual.has_method("update_motion"):
		var local_velocity := visual.global_basis.inverse() * get_real_velocity()
		visual.call("update_motion", local_velocity, is_on_floor(), jumped, not was_grounded and is_on_floor(), sprinting,delta)

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
