extends RefCounted
## Pure, fixed-step locomotion policy. Capsule stays authoritative.
const ACCELERATION = 24.0
const TURN_RESPONSE = 14.0
const AIM_RESPONSE = 18.0

static func step_velocity(current: Vector3, target: Vector3, _grounded: bool, delta: float) -> Vector3:
	# Preserve the proven RC6 component-wise response in all gameplay contexts.
	# Revisit physical acceleration only with a traversal-specific balance pass.
	var distance := ACCELERATION*maxf(delta,0.0)
	return Vector3(move_toward(current.x,target.x,distance),current.y,move_toward(current.z,target.z,distance))

static func step_yaw(current: float,target: float,aim: bool,delta: float) -> float:
	return lerp_angle(current,target,1.0-exp(-(AIM_RESPONSE if aim else TURN_RESPONSE)*maxf(delta,0.0)))

static func run_gait(speed: float, was_running: bool) -> bool:
	# Small dead band prevents clip oscillation at analogue thresholds.
	return speed > (3.05 if was_running else 3.55)

static func loop_phase(position: float,length: float) -> float:
	return fposmod(position,maxf(length,.001))/maxf(length,.001)
