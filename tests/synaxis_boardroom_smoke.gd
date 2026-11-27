extends SceneTree

const ExecutiveFloor = preload("res://scripts/synaxis_executive_floor.gd")
const ChairAsset = preload("res://scripts/synaxis_chair_asset.gd")

func _initialize() -> void:
	var floor := ExecutiveFloor.new()
	floor._boardroom()
	var error := _verify_boardroom(floor)
	floor.free()
	if not error.is_empty():
		push_error("SYNAXIS_BOARDROOM " + error)
		quit(1)
		return
	print("SYNAXIS_BOARDROOM PASS: eight authored chairs face the table, seated staff align, and the tabletop uses photographic PBR")
	quit()

func _verify_boardroom(floor: Node3D) -> String:
	var poses: Array[Transform3D] = floor.get("_chair_poses")
	var chair_count := poses.size()
	if chair_count != 8:
		return "Expected four chairs on each side of the table"
	for pose in poses:
		var front := pose.basis.z.normalized()
		var toward_table := Vector3(-signf(pose.origin.x), 0, 0)
		if not front.is_equal_approx(toward_table):
			return "Chair at %s faces away from the table" % [pose.origin]
	for spec in ExecutiveFloor.EXECUTIVES:
		if spec.id not in ["coo", "legal"]:
			continue
		var actor_front := Basis(Vector3.UP, spec.yaw).z
		var aligned := false
		for pose in poses:
			if pose.origin.is_equal_approx(spec.position) and actor_front.is_equal_approx(pose.basis.z.normalized()):
				aligned = true
		if not aligned:
			return "Seated staff member %s does not line up with a boardroom chair" % spec.id
	floor._flush()
	var chairs := floor.get_node_or_null("AuthoredTaskChairs") as MultiMeshInstance3D
	if chairs == null or chairs.multimesh.instance_count != chair_count or chairs.multimesh.mesh != ChairAsset.mesh_resource():
		return "Seating did not reach the authored chair batch"
	var surface := floor.get_node_or_null("boardroom_walnut_box") as MultiMeshInstance3D
	if surface == null:
		return "The conference table is missing its walnut surface"
	var veneer := surface.material_override as StandardMaterial3D
	if veneer == null or veneer.albedo_texture == null or not veneer.normal_enabled or veneer.normal_texture == null or veneer.roughness_texture == null or not veneer.uv1_world_triplanar:
		return "The tabletop lacks its world-scaled walnut albedo, normal or roughness map"
	return ""
