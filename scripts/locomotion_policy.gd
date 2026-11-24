extends RefCounted
## Pure, fixed-step locomotion policy. Capsule stays authoritative.
const ACCELERATION = 32.0
const BRAKING = 36.0
const REVERSAL_BRAKE = 46.0
const AIR_ACCELERATION = 13.0
const TURN_RESPONSE = 14.0
const AIM_RESPONSE = 18.0

static func step_velocity(current: Vector3, target: Vector3, grounded: bool, delta: float) -> Vector3:
	var horizontal := Vector3(current.x,0,current.z)
	var wanted := Vector3(target.x,0,target.z)
	var rate := ACCELERATION
	if not grounded:
		rate = AIR_ACCELERATION
	elif wanted.length_squared()<.001:
		rate = BRAKING
	elif horizontal.dot(wanted)<0.0:
		rate = REVERSAL_BRAKE
	elif wanted.length_squared()<horizontal.length_squared():
		rate = BRAKING
	var next := horizontal.move_toward(wanted,rate*maxf(delta,0.0))
	return Vector3(next.x,current.y,next.z)

static func step_yaw(current: float,target: float,aim: bool,delta: float) -> float:
	return lerp_angle(current,target,1.0-exp(-(AIM_RESPONSE if aim else TURN_RESPONSE)*maxf(delta,0.0)))

static func run_gait(speed: float, was_running: bool) -> bool:
	# Small dead band prevents clip oscillation at analogue thresholds.
	return speed > (3.05 if was_running else 3.55)

static func loop_phase(position: float,length: float) -> float:
	return fposmod(position,maxf(length,.001))/maxf(length,.001)
