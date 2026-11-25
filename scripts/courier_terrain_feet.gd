extends SkeletonModifier3D
## Post-animation, presentation-only adjustment. Two ground queries per
## active player tick at most; no physics queries inside modifier callback.
const MAX_RISE = .22
const MAX_DROP = .15
const MAX_PELVIS_DROP = .12
const MAX_LOCK_DISTANCE = .14
const MAX_LOCK_SECONDS = .24
const LOCK_ENGAGE = .85
const LOCK_RELEASE = .45
const MAX_TILT = deg_to_rad(20.0)
const PROBE_UP = .40
const PROBE_DOWN = .48
const LEGS = [["LeftUpLeg","LeftLeg","LeftFoot"],["RightUpLeg","RightLeg","RightFoot"]]
var _chains: Array[Vector3i] = []
var _offsets := PackedFloat32Array([0.0,0.0])
var _ankle_rest := PackedFloat32Array([0.0,0.0])
var _normals: Array[Vector3] = [Vector3.UP,Vector3.UP]
var _stance := PackedFloat32Array([0.0,0.0])
var _pelvis := -1
var _pelvis_drop := 0.0
var _locks: Array[Dictionary] = [{},{}]
var _lock_armed: Array[bool] = [true,true]
var _lock_weights := PackedFloat32Array([0.0,0.0])
var _ready_rig := false
var probe_count := 0
var corrected_feet := 0

func configure() -> bool:
	var rig := get_skeleton()
	if rig == null:
		return false
	_chains.clear()
	_pelvis = rig.find_bone("Hips")
	if _pelvis<0:
		return false
	for i in LEGS.size():
		var names: Array = LEGS[i]
		var indices := Vector3i(rig.find_bone(names[0]),rig.find_bone(names[1]),rig.find_bone(names[2]))
		if mini(indices.x,mini(indices.y,indices.z))<0:
			return false
		if rig.get_bone_parent(indices.z)!=indices.y or rig.get_bone_parent(indices.y)!=indices.x:
			return false
		_chains.append(indices)
		_ankle_rest[i] = rig.get_bone_global_rest(indices.z).origin.y
	_ready_rig = true
	return true

func reset() -> void:
	_offsets.fill(0.0)
	_stance.fill(0.0)
	_normals = [Vector3.UP,Vector3.UP]
	_pelvis_drop = 0.0
	_locks = [{},{}]
	_lock_armed = [true,true]
	_lock_weights.fill(0.0)
	probe_count = 0
	corrected_feet = 0
	active = false

func sample_ground(body: CharacterBody3D,delta: float,enabled: bool) -> void:
	probe_count = 0
	if not enabled or not _ready_rig or not is_instance_valid(body) or not body.is_inside_tree():
		reset()
		return
	var rig := get_skeleton()
	if rig == null:
		reset()
		return
	active = true
	var space := body.get_world_3d().direct_space_state
	var visual_floor := (get_parent() as Skeleton3D).to_global(Vector3.ZERO).y
	var excluded: Array[RID] = [body.get_rid()]
	for i in 2:
		var ankle := rig.get_bone_global_pose(_chains[i].z).origin
		var point := rig.to_global(ankle)
		var base := Vector3(point.x,visual_floor,point.z)
		var query := PhysicsRayQueryParameters3D.create(base+Vector3.UP*PROBE_UP,base-Vector3.UP*PROBE_DOWN,1,excluded)
		var hit := space.intersect_ray(query)
		probe_count += 1
		var correction := 0.0
		var normal := Vector3.UP
		var stance := 0.0
		if not hit.is_empty() and (hit["normal"] as Vector3).y>.72:
			var ground: Vector3 = hit["position"]
			# Restrict adjustment to the planted part of the mocap cycle.
			stance = 1.0-smoothstep(.035,.14,maxf(0.0,ankle.y-_ankle_rest[i]))
			correction = clampf(ground.y-visual_floor,-MAX_DROP,MAX_RISE)*stance
			normal = hit["normal"]
		var support: RID = hit.get("rid",RID()) if stance>0.0 and hit.get("collider") is StaticBody3D and not hit.get("collider") is AnimatableBody3D else RID()
		_tick_lock(i,point,stance,support,delta)
		var response := 1.0-exp(-16.0*delta)
		_offsets[i] = lerpf(_offsets[i],correction,response)
		_stance[i] = lerpf(_stance[i],stance,response)
		_normals[i] = _normals[i].lerp(normal,response).normalized()
	var desired_drop := clampf(minf(0.0,minf(_offsets[0],_offsets[1])),-MAX_PELVIS_DROP,0.0)
	_pelvis_drop = lerpf(_pelvis_drop,desired_drop,1.0-exp(-10.0*delta))

func _tick_lock(i: int,point: Vector3,stance: float,support: RID,delta: float) -> void:
	var lock: Dictionary = _locks[i]
	if stance<LOCK_RELEASE:
		_lock_armed[i] = true
	if not lock.is_empty():
		lock["age"] = float(lock["age"])+delta
		if stance<LOCK_RELEASE or not support.is_valid() or lock["support"]!=support or float(lock["age"])>MAX_LOCK_SECONDS or _lock_delta(point,lock["anchor"]).length()>MAX_LOCK_DISTANCE:
			_locks[i] = {}
			_lock_weights[i] = 0.0
			return
	elif _lock_armed[i] and stance>=LOCK_ENGAGE and support.is_valid():
		_locks[i] = {"anchor":point,"support":support,"age":0.0}
		_lock_armed[i] = false
	_lock_weights[i] = lerpf(_lock_weights[i],stance if not _locks[i].is_empty() else 0.0,1.0-exp(-25.0*delta))

static func _lock_delta(point: Vector3,anchor: Vector3) -> Vector3:
	var shift := anchor-point
	shift.y = 0.0
	return shift

func _horizontal_lock(i: int,point: Vector3) -> Vector3:
	if _locks[i].is_empty():
		return Vector3.ZERO
	return _lock_delta(point,_locks[i]["anchor"]).limit_length(MAX_LOCK_DISTANCE)*_lock_weights[i]

func _process_modification_with_delta(_delta: float) -> void:
	corrected_feet = 0
	if not _ready_rig:
		return
	var rig := get_skeleton()
	if absf(_pelvis_drop)>.002:
		var hips := rig.get_bone_global_pose(_pelvis)
		hips.origin += rig.global_basis.inverse()*Vector3(0,_pelvis_drop,0)
		rig.set_bone_global_pose(_pelvis,hips)
	# Targets are relative to the original animation, not the lowered hips.
	for i in 2:
		var offset := _offsets[i]-_pelvis_drop
		var tilt := _bounded_tilt(_normals[i],_stance[i])
		var foot := rig.to_global(rig.get_bone_global_pose(_chains[i].z).origin)
		var horizontal := _horizontal_lock(i,foot)
		if absf(offset)<.002 and tilt.get_angle()<.01 and horizontal.length_squared()<.000004:
			continue
		if _solve_leg(rig,_chains[i],offset,tilt,horizontal):
			corrected_feet += 1

static func _bounded_tilt(normal: Vector3,stance: float) -> Quaternion:
	var direction := normal.normalized()
	if direction.y<=.72:
		return Quaternion.IDENTITY
	var angle := acos(clampf(Vector3.UP.dot(direction),-1.0,1.0))
	var axis := Vector3.UP.cross(direction)
	if axis.length_squared()<.000001:
		return Quaternion.IDENTITY
	return Quaternion(axis.normalized(),minf(angle,MAX_TILT)*clampf(stance,0.0,1.0))

func _solve_leg(rig: Skeleton3D,chain: Vector3i,offset: float,tilt: Quaternion = Quaternion.IDENTITY,horizontal: Vector3 = Vector3.ZERO) -> bool:
	var hip := rig.get_bone_global_pose(chain.x)
	var knee := rig.get_bone_global_pose(chain.y)
	var ankle := rig.get_bone_global_pose(chain.z)
	var target := ankle.origin+rig.global_basis.inverse()*(Vector3(0,offset,0)+horizontal)
	var a := hip.origin.distance_to(knee.origin)
	var b := knee.origin.distance_to(ankle.origin)
	var reach := target-hip.origin
	if minf(a,b)<.01 or reach.length()<.01:
		return false
	var axis := reach.normalized()
	var length := clampf(reach.length(),absf(a-b)+.005,a+b-.005)
	var bend := knee.origin-hip.origin
	bend -= axis*bend.dot(axis)
	if bend.length_squared()<.00001:
		bend = Vector3.FORWARD-axis*Vector3.FORWARD.dot(axis)
	if bend.length_squared()<.00001:
		return false
	bend = bend.normalized()
	var along := (a*a-b*b+length*length)/(2.0*length)
	var joint := hip.origin+axis*along+bend*sqrt(maxf(0.0,a*a-along*along))
	var end := hip.origin+axis*length
	var hip_basis := Basis(Quaternion((knee.origin-hip.origin).normalized(),(joint-hip.origin).normalized()))*hip.basis
	var knee_basis := Basis(Quaternion((ankle.origin-knee.origin).normalized(),(end-joint).normalized()))*knee.basis
	rig.set_bone_global_pose(chain.x,Transform3D(hip_basis,hip.origin))
	rig.set_bone_global_pose(chain.y,Transform3D(knee_basis,joint))
	var world_rotation := rig.global_basis.orthonormalized()
	var ankle_basis := world_rotation.inverse()*Basis(tilt)*world_rotation*ankle.basis
	rig.set_bone_global_pose(chain.z,Transform3D(ankle_basis,end))
	return true
