extends AnimatableBody3D
## Local hinge, fitted leaf and obstruction check shared by walk-in storefronts.
const OPEN_ANGLE = 1.48
const SWING_SPEED = 2.7

var _leaf: CollisionShape3D
var _goal := 0.0
var art_ready := false
var movement_blocked := false

func configure(leaf_size: Vector3, center: Vector3) -> void:
	sync_to_physics = false
	collision_mask = 0
	_leaf = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = leaf_size
	_leaf.shape = shape
	_leaf.position = center
	add_child(_leaf)
	set_physics_process(false)

func install_art(source: PackedScene) -> void:
	add_child(source.instantiate())
	art_ready = true

func request_toggle() -> bool:
	if not art_ready:
		return false
	_goal = OPEN_ANGLE if is_zero_approx(_goal) else 0.0
	set_physics_process(true)
	return true

func is_requested_open() -> bool:
	return _goal > 0.0

func openness() -> float:
	return rotation.y / OPEN_ANGLE

func restore_open(value: bool) -> void:
	_goal = OPEN_ANGLE if value else 0.0
	rotation.y = _goal
	movement_blocked = false
	reset_physics_interpolation()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	var step := move_toward(rotation.y, _goal, delta * SWING_SPEED)
	var next := Transform3D(Basis(Vector3.UP, step), position)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _leaf.shape
	query.transform = get_parent_node_3d().global_transform * next * _leaf.transform
	query.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 16):
		if hit["collider"] is CharacterBody3D or hit["collider"] is RigidBody3D:
			movement_blocked = true
			return
	movement_blocked = false
	rotation.y = step
	if is_equal_approx(step, _goal):
		set_physics_process(false)
