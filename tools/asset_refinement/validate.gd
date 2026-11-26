extends SceneTree
# Offline structural gate only. Does not approve art or write into the project.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass an absolute GLB path after --")
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
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	var surfaces := 0
	for node in meshes:
		if node.mesh != null:
			surfaces += node.mesh.get_surface_count()
	root.free()
	print("Godot import surfaces: ", surfaces)
	quit(0 if surfaces > 0 else 1)
