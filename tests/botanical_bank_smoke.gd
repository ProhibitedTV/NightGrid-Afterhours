extends SceneTree
const Bank = preload("res://scripts/botanical_bank.gd")
const Flora = preload("res://scripts/flora.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var required := "--require-bank" in OS.get_cmdline_user_args()
	for species in Bank.SPECIES:
		for lod in [0, 1]:
			var mesh := Bank.mesh_for(species, lod)
			if mesh == null:
				if required:
					push_error("BOTANICAL FAIL: missing " + species + " tier " + str(lod))
					quit(1)
					return
				print("BOTANICAL optional bank absent")
				quit()
				return
			if mesh.get_surface_count() < 1 or mesh.get_aabb().size.y <= 0.0:
				push_error("BOTANICAL FAIL: invalid mesh " + species)
				quit(1)
				return
	var flora := Flora.new()
	root.add_child(flora)
	flora.generate()
	var stats := flora.get_stats()
	if stats["street_trees"] != 128 or stats["imported_trees"] != stats["street_trees"] + stats["landmark_trees"] or stats["imported_shrubs"] != stats["shrubs"] or stats["scanned_hero_ferns"] != 1:
		push_error("BOTANICAL FAIL: incomplete coverage " + str(stats))
		quit(1)
		return
	print("BOTANICAL PASS: ", stats)
	quit()
