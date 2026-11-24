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

# Measured from the committed courier GLB: 64 samples per gait cycle.
# Vector2(left ankle contact, right ankle contact). These are approximate
# minimum-height/low-vertical-speed anchors, not manually authored events.
const CONTACT_PHASES = {
	&"walk":Vector2(.890625,.203125),
	&"aim_walk":Vector2(.890625,.203125),
	&"run":Vector2(.75,.25),
	&"aim_run":Vector2(.75,.25),
	&"walk_back":Vector2(.125,.796875),
	&"strafe_left":Vector2(.015625,.1875),
	&"aim_left":Vector2(.015625,.1875),
	&"strafe_right":Vector2(.1875,.015625),
	&"aim_right":Vector2(.1875,.015625)
}

static func contact_phase(source: StringName,destination: StringName,phase: float) -> float:
	if source==destination or not CONTACT_PHASES.has(source) or not CONTACT_PHASES.has(destination):
		return fposmod(phase,1.0)
	var a: Vector2 = CONTACT_PHASES[source]
	var b: Vector2 = CONTACT_PHASES[destination]
	# Map both intervals around the circular cycle, preserving the identity
	# of each planted foot and progress toward the next contact.
	var progress := fposmod(phase-a.x,1.0)
	var source_arc := fposmod(a.y-a.x,1.0)
	var target_arc := fposmod(b.y-b.x,1.0)
	if progress<=source_arc:
		return fposmod(b.x+progress/maxf(source_arc,.001)*target_arc,1.0)
	return fposmod(b.y+(progress-source_arc)/maxf(1.0-source_arc,.001)*(1.0-target_arc),1.0)

# Reuse the authored landing clip, varying recovery duration by measured
# impact velocity. Normal jump speed stays on the previously tested timing.
static func landing_rate(impact: float) -> float:
	return lerpf(1.45,.78,smoothstep(3.0,15.0,impact))

static func pivot_clip(speed: float,yaw_rate: float) -> StringName:
	if speed>1.35 or absf(yaw_rate)<3.5:
		return &""
	# Positive yaw rotates the +Z-forward courier toward +X (its left).
	return &"turn_left" if yaw_rate>0.0 else &"turn_right"
