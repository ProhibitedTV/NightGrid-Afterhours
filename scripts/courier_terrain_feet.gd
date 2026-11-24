extends SkeletonModifier3D
## Post-animation, presentation-only adjustment. Two ground queries per
## active player tick at most; no physics queries inside modifier callback.
const MAX_RISE = .22
const MAX_DROP = .15
const PROBE_UP = .40
const PROBE_DOWN = .48
const LEGS = [["LeftUpLeg","LeftLeg","LeftFoot"],["RightUpLeg","RightLeg","RightFoot"]]
var _chains: Array[Vector3i] = []
var _offsets := PackedFloat32Array([0.0,0.0])
var _ankle_rest := PackedFloat32Array([0.0,0.0])
var _ready_rig := false
var probe_count := 0
var corrected_feet := 0

func configure() -> bool:
	var rig := get_skeleton()
	if rig == null:
		return false
	_chains.clear()
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
		if not hit.is_empty() and (hit["normal"] as Vector3).y>.72:
			var ground: Vector3 = hit["position"]
			# Restrict adjustment to the planted part of the mocap cycle.
			var stance := 1.0-smoothstep(.035,.14,maxf(0.0,ankle.y-_ankle_rest[i]))
			correction = clampf(ground.y-visual_floor,-MAX_DROP,MAX_RISE)*stance
		_offsets[i] = lerpf(_offsets[i],correction,1.0-exp(-16.0*delta))

func _process_modification_with_delta(_delta: float) -> void:
	corrected_feet = 0
	if not _ready_rig:
		return
	var rig := get_skeleton()
	for i in 2:
		if absf(_offsets[i])<.002:
			continue
		if _solve_leg(rig,_chains[i],_offsets[i]):
			corrected_feet += 1

func _solve_leg(rig: Skeleton3D,chain: Vector3i,offset: float) -> bool:
	var hip := rig.get_bone_global_pose(chain.x)
	var knee := rig.get_bone_global_pose(chain.y)
	var ankle := rig.get_bone_global_pose(chain.z)
	var target := ankle.origin+rig.global_basis.inverse()*Vector3(0,offset,0)
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
	rig.set_bone_global_pose(chain.z,Transform3D(ankle.basis,end))
	return true
