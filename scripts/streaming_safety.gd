extends RefCounted
## Shared conservative guards for optional traffic and pedestrian pools.
## Call on the physics thread/tick with the actual active gameplay camera.
## No spawning, chunk construction, ray-based occlusion permission or heat.
const CAMERA_SETTLE_SECONDS = 0.35
const CAMERA_MARGIN = 8.0
const CAMERA_TURN_RATE = 0.9
const VEHICLE_RADIUS = 3.2
const PEDESTRIAN_RADIUS = 0.65
var _previous_basis: Basis = Basis.IDENTITY
var _camera_id := 0
var _settled := 0.0
var _sampled_frame := -1

func observe(camera: Camera3D, delta: float) -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree() or not camera.current or not is_finite(delta) or delta<=0.0:
		_camera_id = 0
		_settled = 0.0
		return
	var id := camera.get_instance_id()
	var basis := camera.global_basis.orthonormalized()
	var rotation_delta := _previous_basis.get_rotation_quaternion().angle_to(basis.get_rotation_quaternion())
	if id != _camera_id or rotation_delta > CAMERA_TURN_RATE*delta:
		_settled = 0.0
	else:
		_settled = minf(CAMERA_SETTLE_SECONDS,_settled+delta)
	_previous_basis = basis
	_camera_id = id
	_sampled_frame = Engine.get_physics_frames()

static func outside_expanded_view(camera: Camera3D, at: Vector3, radius: float) -> bool:
	if not is_instance_valid(camera) or not camera.is_inside_tree() or not camera.current or not at.is_finite() or not is_finite(radius) or radius<0.0:
		return false
	# Treat any point in the actual camera frustum as potentially visible,
	# even if occluded. Use the planes to reject only a whole expanded sphere.
	if camera.is_position_in_frustum(at):
		return false
	var planes := camera.get_frustum()
	if planes.size()!=6:
		return false
	var pose := camera.get_camera_transform()
	var inside := pose.origin-pose.basis.z.normalized()*((camera.near+camera.far)*0.5)
	for plane in planes:
		var reference: float = plane.distance_to(inside)
		var distance: float = plane.distance_to(at)
		if not is_finite(reference) or not is_finite(distance) or absf(reference)<0.001:
			return false
		if distance*signf(reference) < -(radius+CAMERA_MARGIN):
			return true
	return false

func hidden(camera: Camera3D, at: Vector3, radius: float) -> bool:
	if not is_instance_valid(camera) or camera.get_instance_id()!=_camera_id or _sampled_frame!=Engine.get_physics_frames() or _settled<CAMERA_SETTLE_SECONDS:
		return false
	# If another callback moved the camera since observation, fail closed.
	if _previous_basis.get_rotation_quaternion().angle_to(camera.global_basis.orthonormalized().get_rotation_quaternion())>0.001:
		return false
	return outside_expanded_view(camera,at,radius)

static func clear_grounded_volume(city: Node, space: PhysicsDirectSpaceState3D, at: Vector3, radius: float, height: float, expected_floor: float) -> bool:
	if not is_instance_valid(city) or space==null or not at.is_finite() or not is_finite(radius) or not is_finite(height) or not is_finite(expected_floor) or radius<=0.0 or height<=0.0:
		return false
	if not city.has_method("is_spawn_area_ready") or not bool(city.call("is_spawn_area_ready",at,radius)):
		return false
	# Query actual supporting static geometry. Never exclude nearby actors.
	var floor_point := Vector3(at.x,expected_floor,at.z)
	var ray := PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*0.65,floor_point-Vector3.UP*0.65,1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or not hit.get("collider") is StaticBody3D or (hit["normal"] as Vector3).y<0.8:
		return false
	var ground: Vector3 = hit["position"]
	if absf(ground.y-expected_floor)>0.4:
		return false
	# Box is orientation-independent; conservative lateral extent for a car.
	# Lift the lower face clear of the support surface to avoid floor overlap.
	var shape := BoxShape3D.new()
	shape.size = Vector3(radius*2.0,height,radius*2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,ground+Vector3.UP*(height*0.5+0.12))
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_shape(query,1).is_empty()

func vehicle_spawn_allowed(camera: Camera3D, city: Node, space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	return hidden(camera,at,VEHICLE_RADIUS) and clear_grounded_volume(city,space,at,VEHICLE_RADIUS,2.0,at.y-1.0)

func pedestrian_spawn_allowed(camera: Camera3D, city: Node, space: PhysicsDirectSpaceState3D, entry: Dictionary, link_certified: Callable) -> bool:
	# Full path validation is a separate cached #98 responsibility.
	var at: Variant = entry.get("position")
	return at is Vector3 and link_certified.is_valid() and hidden(camera,at,PEDESTRIAN_RADIUS) and bool(link_certified.call(entry)) and clear_grounded_volume(city,space,at,PEDESTRIAN_RADIUS,1.9,at.y)
