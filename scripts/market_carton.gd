extends StaticBody3D
## A delivery carton stays static until struck. One short-lived rigid body
## takes its place and remains owned by the same streamed landmark.
const SOURCE = preload("res://assets/models/polyhaven/cardboard_box_01/cardboard_box_01.gltf")
const BREAK_SPEED = 4.0
const DEBRIS_SECONDS = 4.0
static var _mesh: Mesh
var _view: MeshInstance3D
var _collider: CollisionShape3D
var _broken := false

func _ready() -> void:
	if _mesh == null:
		var source := SOURCE.instantiate()
		var views := source.find_children("*", "MeshInstance3D", true, false)
		_mesh = (views[0] as MeshInstance3D).mesh
		source.free()
	var bounds := _mesh.get_aabb()
	_view = MeshInstance3D.new()
	_view.mesh = _mesh
	_view.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	add_child(_view)
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	_collider = CollisionShape3D.new()
	_collider.shape = shape
	_collider.position.y = bounds.size.y * 0.5
	add_child(_collider)

func knock_loose(closing_speed: float, direction: Vector3, point: Vector3) -> bool:
	if not is_finite(closing_speed) or closing_speed < BREAK_SPEED or not direction.is_finite() or direction.length_squared()<.001 or not point.is_finite():
		return false
	if not _broken:
		_broken = true
		_release.call_deferred(direction, closing_speed, point)
	return true

func _release(direction: Vector3, closing_speed: float, point: Vector3) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var debris := RigidBody3D.new()
	debris.name = "CartonDebris"
	debris.mass = 1.25
	debris.continuous_cd = true
	debris.collision_layer = 0
	debris.collision_mask = 1
	add_child(debris)
	var center := _collider.position
	debris.position = center
	_view.reparent(debris, false)
	_view.position -= center
	_collider.reparent(debris, false)
	_collider.position = Vector3.ZERO
	var impulse := (direction * minf(closing_speed * 0.42, 8.0) + Vector3.UP * 1.45) * debris.mass
	var lever := (point - debris.global_position).limit_length(0.30)
	debris.apply_impulse(impulse, lever)
	get_tree().create_timer(DEBRIS_SECONDS, false, true).timeout.connect(debris.queue_free)
