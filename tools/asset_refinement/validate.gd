extends SceneTree
# Offline import gate; not native render or art approval.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(args[0], state)
	if err != OK:
		push_error("GLB import failed: %s" % err)
		quit(1)
		return
	var root := doc.generate_scene(state)
	if root == null:
		quit(1)
		return
	var nodes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)
	var meshes := 0
	var surfaces := 0
	var vertices := 0
	for node in nodes:
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		meshes += 1
		surfaces += instance.mesh.get_surface_count()
		for i in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(i)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for point in points:
				if not point.is_finite():
					root.free()
					quit(1)
					return
			vertices += points.size()
	root.free()
	if meshes == 0 or surfaces == 0 or vertices == 0:
		quit(1)
		return
	print("ANUBIS_IMPORT_PASS ", JSON.stringify({"meshes": meshes, "surfaces": surfaces, "vertices": vertices}))
	quit(0)
