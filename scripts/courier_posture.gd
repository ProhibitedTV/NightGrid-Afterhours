extends SkeletonModifier3D
## Subtle inertia applied to the upper body only. Does not alter feet,
## collision, camera facing or authored action poses.
const MAX_PITCH = deg_to_rad(8.0)
const MAX_ROLL = deg_to_rad(10.0)
var _spine := -1
var _previous_velocity := Vector3.ZERO
var _initialized := false
var lean := Vector2.ZERO

func configure() -> bool:
	_spine = get_skeleton().find_bone("Spine")
	return _spine>=0

func reset() -> void:
	_initialized = false
	_previous_velocity = Vector3.ZERO
	lean = Vector2.ZERO
	active = false

static func target_lean(acceleration: Vector3,speed: float,yaw_rate: float) -> Vector2:
	var pitch := clampf(acceleration.z*.006,-MAX_PITCH,MAX_PITCH)
	var roll := clampf(-acceleration.x*.006-yaw_rate*minf(speed,8.0)*.008,-MAX_ROLL,MAX_ROLL)
	return Vector2(pitch,roll)*smoothstep(.2,1.5,speed)

func update_posture(velocity: Vector3,yaw_rate: float,delta: float,enabled: bool) -> void:
	if not enabled or _spine<0:
		reset()
		return
	active = true
	var acceleration := Vector3.ZERO
	if _initialized:
		acceleration = (velocity-_previous_velocity)/maxf(delta,.001)
	_previous_velocity = velocity
	_initialized = true
	var target := target_lean(acceleration,Vector2(velocity.x,velocity.z).length(),yaw_rate)
	lean = lean.lerp(target,1.0-exp(-8.0*delta))

func _process_modification_with_delta(_delta: float) -> void:
	if _spine<0 or lean.length_squared()<.000001:
		return
	var rig := get_skeleton()
	var spine := rig.get_bone_global_pose(_spine)
	# Imported courier faces local +Z. X rotation pitches forward,
	# Z rotation inclines the torso sideways. Preserve authored translation.
	spine.basis = Basis.from_euler(Vector3(lean.x,0,lean.y))*spine.basis
	rig.set_bone_global_pose(_spine,spine)
