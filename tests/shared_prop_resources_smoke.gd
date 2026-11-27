extends SceneTree
const Cargo = preload("res://scripts/freight_cargo_case.gd")

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var a := Cargo.new()
	var b := Cargo.new()
	root.add_child(a)
	root.add_child(b)
	var meshes := {}
	var materials := {}
	var count := 0
	for i in range(a.get_child_count()):
		var first := a.get_child(i) as MeshInstance3D
		if first == null:
			continue
		var second := b.get_child(i) as MeshInstance3D
		if second == null or first.mesh != second.mesh or first.material_override != second.material_override or first.position != second.position:
			push_error("Freight resources or placement differ")
			quit(1)
			return
		meshes[first.mesh.get_instance_id()] = true
		materials[first.material_override.get_instance_id()] = true
		count += 1
	if count != 8 or meshes.size() != 5 or materials.size() != 4:
		push_error("Unexpected freight resource cardinality")
		quit(1)
		return
	a.queue_free()
	b.queue_free()
	await process_frame
	print("SHARED_PROP_RESOURCES PASS")
	quit(0)
