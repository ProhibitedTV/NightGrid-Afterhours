extends SkeletonModifier3D
## One temporary hand target during an authored interaction. Never controls
## gameplay, moves the capsule, adds a physics query or owns the streamed prop.
const MAX_CORRECTION = .28
const CHAINS = [["LeftArm","LeftForeArm","LeftHand"],["RightArm","RightForeArm","RightHand"]]
var _chains: Array[Vector3i] = []
var _target: WeakRef
var _anchor := Vector3.ZERO
var _side := 1
var _animation: AnimationPlayer
var _clip: StringName
var _ready_rig := false

func configure() -> bool:
	var rig := get_skeleton()
	_chains.clear()
	for names in CHAINS:
		var chain := Vector3i(rig.find_bone(names[0]),rig.find_bone(names[1]),rig.find_bone(names[2]))
		if mini(chain.x,mini(chain.y,chain.z))<0 or rig.get_bone_parent(chain.y)!=chain.x or rig.get_bone_parent(chain.z)!=chain.y:
			return false
		_chains.append(chain)
	_ready_rig = true
	return true

func reset() -> void:
	_target = null
	_animation = null
	_clip = &""
	active = false

func begin(target: Node3D,anchor: Vector3,side: int,anim: AnimationPlayer,clip: StringName) -> bool:
	reset()
	if not _ready_rig or not is_instance_valid(target) or not is_instance_valid(anim) or side<0 or side>1:
		return false
	_target = weakref(target)
	_anchor = anchor
	_side = side
	_animation = anim
	_clip = clip
	active = true
	return true

func _process_modification_with_delta(_delta: float) -> void:
	if _target == null or not is_instance_valid(_animation):
		reset()
		return
	var target := _target.get_ref() as Node3D
	if not is_instance_valid(target) or not target.is_inside_tree() or _animation.current_animation!=_clip or not _animation.is_playing():
		reset()
		return
	var phase := _animation.current_animation_position/maxf(.001,_animation.current_animation_length)
	var weight := smoothstep(.12,.34,phase)*(1.0-smoothstep(.65,.92,phase))
	if weight>.001:
		_solve(get_skeleton(),_chains[_side],target.to_global(_anchor),weight)

func _solve(rig: Skeleton3D,chain: Vector3i,world_target: Vector3,weight: float) -> bool:
	var shoulder := rig.get_bone_global_pose(chain.x)
	var elbow := rig.get_bone_global_pose(chain.y)
	var wrist := rig.get_bone_global_pose(chain.z)
	var target := rig.to_local(world_target)
	var a := shoulder.origin.distance_to(elbow.origin)
	var b := elbow.origin.distance_to(wrist.origin)
	# Distant interactions retain their authored gesture; do not stretch
	# the arm across the interaction radius.
	if a<.01 or b<.01 or shoulder.origin.distance_to(target)>a+b+.04:
		return false
	target = wrist.origin+(target-wrist.origin).limit_length(MAX_CORRECTION)*clampf(weight,0.0,1.0)
	var direction := target-shoulder.origin
	if direction.length()<.001:
		return false
	var axis := direction.normalized()
	var length := clampf(direction.length(),absf(a-b)+.002,a+b-.002)
	var bend := elbow.origin-shoulder.origin
	bend -= axis*bend.dot(axis)
	if bend.length_squared()<.00001:
		bend = Vector3.DOWN-axis*Vector3.DOWN.dot(axis)
	if bend.length_squared()<.00001:
		return false
	var along := (a*a-b*b+length*length)/(2.0*length)
	var joint := shoulder.origin+axis*along+bend.normalized()*sqrt(maxf(0.0,a*a-along*along))
	var end := shoulder.origin+axis*length
	var upper := Basis(Quaternion((elbow.origin-shoulder.origin).normalized(),(joint-shoulder.origin).normalized()))*shoulder.basis
	var lower := Basis(Quaternion((wrist.origin-elbow.origin).normalized(),(end-joint).normalized()))*elbow.basis
	rig.set_bone_global_pose(chain.x,Transform3D(upper,shoulder.origin))
	rig.set_bone_global_pose(chain.y,Transform3D(lower,joint))
	rig.set_bone_global_pose(chain.z,Transform3D(wrist.basis,end))
	return true
