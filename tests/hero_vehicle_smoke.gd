extends SceneTree
## Visual and gameplay integration preflight for the actual player-drivable sedan.
## No user save slot is touched; the scene is created in an isolated headless tree.
func _initialize() -> void:
	call_deferred("_check")

func _fail(reason: String) -> void:
	push_error("HERO_VEHICLE_SMOKE: " + reason)
	quit(1)

func _check() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("Missing playable world")
		return
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	var fleet: Array = world.get("cars")
	if fleet.size() != 12:
		_fail("Parking fleet count or indices changed")
		return
	var sample: CharacterBody3D = fleet[0]
	var hero := sample.get_node_or_null("KestrelS6HeroVisual")
	if hero == null or not bool(sample.get("hero_visual") == hero):
		_fail("Hero visuals must be attached to the actual physical player car")
		return
	var shell := hero.get_node_or_null("KestrelMonocoque") as MeshInstance3D
	if shell == null or not shell.mesh is ArrayMesh:
		_fail("Missing bespoke lofted Kestrel bodywork")
		return
	var vertices: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if vertices.size() < 350:
		_fail("Kestrel shell has insufficient beveled original geometry")
		return
	var stats: Dictionary = hero.call("get_visual_stats")
	if int(stats.get("wheels", 0)) != 4 or int(stats.get("cabins", 0)) != 1:
		_fail("Kestrel must have a cabin and four articulated wheel assemblies")
		return
	if int(stats.get("transparent_glass", 0)) != 5 or int(stats.get("seats", 0)) != 4:
		_fail("Four furnished seats and five tinted glass panels expected")
		return
	if int(stats.get("headlamps", 0)) != 2 or int(stats.get("brake_lamps", 0)) != 2:
		_fail("Dual drive-responsive front/rear lights are missing")
		return
	if int(stats.get("door_reveals", 0)) != 4:
		_fail("Four door handles and surrounding panel joints expected")
		return
	if int(stats.get("hero_components", 0)) > 220:
		_fail("Per-vehicle detail count exceeds low-poly hero budget: %s" % stats)
		return
	if hero.get_node_or_null("OriginalElectricDrivetrain") == null:
		_fail("Hero vehicle missing original electric drivetrain audio")
		return
	var audio = load("res://scripts/kestrel_vehicle_audio.gd")
	if audio.sound() == null:
		_fail("Original synth audio did not generate")
		return
	# The visual pass must react to actual signed driving speed and inputs.
	hero.call("update_motion", 11.0, 0.6, true, true, false, 0.12)
	var active: Dictionary = hero.call("get_motion_state")
	if absf(float(active["wheel_rotation"])) < 0.01 or float(active["steering"]) < 0.10:
		_fail("Wheel rotation and steering are not tied to actual motion")
		return
	if not bool(active["braking"]) or int(active["live_beams"]) != 2:
		_fail("Driver brake lamps/headlight beams did not engage")
		return
	hero.call("update_motion", 0.0, 0.0, false, false, false, 0.10)
	var parked_state: Dictionary = hero.call("get_motion_state")
	if bool(parked_state["braking"]) or int(parked_state["live_beams"]) != 0:
		_fail("Parked cars should not retain active dynamic lights")
		return
	# Exact save contract for existing games: still positions/yaw, condition,
	# claimed flag and occupied index; no serialised cosmetic transforms.
	sample.global_position = Vector3(7.0, 1.15, 18.0)
	sample.rotation.y = 0.81
	sample.set("condition", 86.0)
	sample.set_meta("claimed", true)
	var saved: Dictionary = world.call("_capture_snapshot")
	if saved["cars"].size() != fleet.size():
		_fail("Save data lost parked cars")
		return
	world.call("_apply_snapshot", saved)
	if sample.global_position.distance_to(Vector3(7.0, 1.15, 18.0)) > 0.01:
		_fail("Car location changed after snapshot restore")
		return
	if absf(sample.rotation.y - 0.81) > 0.01 or absf(float(sample.get("condition")) - 86.0) > 0.01:
		_fail("Car yaw/condition changed during visual-only save restore")
		return
	if sample.get_node_or_null("KestrelS6HeroVisual/KestrelMonocoque") == null:
		_fail("New cosmetic geometry missing after save restore")
		return
	# Both police pursuit and ordinary parked vehicles have the same body,
	# but emergency lighting should be unique to the pursuit configuration.
	var patrol: CharacterBody3D = world.call("_create_car", Vector3(25.0, 1.0, 20.0), Color("78939d"), true)
	var pursuit := patrol.get_node_or_null("KestrelS6HeroVisual")
	if pursuit == null or pursuit.get_node_or_null("PursuitRoofBase") == null:
		_fail("Pursuit fleet must use the matching high-detail emergency variant")
		return
	if hero.get_node_or_null("PursuitRoofBase") != null:
		_fail("Civilian sedan must not carry police hardware")
		return
	patrol.queue_free()
	print("HERO_VEHICLE_SMOKE PASS: ", stats, " / archive compatible")
	quit(0)
