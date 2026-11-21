extends SceneTree
const Arsenal = preload("res://scripts/arsenal.gd")

func _initialize() -> void:
	create_timer(35.0, true, false, true).timeout.connect(func() -> void: _fail("timeout"))
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("COMBAT_SMOKE: " + message)
	paused = false
	quit(1)

func _verify() -> void:
	var kit = Arsenal.new()
	if kit.discharge():
		_fail("Holstered weapon must not fire")
		return
	kit.cycle()
	if kit.equipped != "pulse" or not kit.discharge() or kit.discharge() or int(kit.ammo["pulse"]) != 7:
		_fail("Cycle, ammunition or cooldown incorrect")
		return
	kit.tick(1.0)
	if not kit.reload() or kit.discharge():
		_fail("Reload state must block firing")
		return
	kit.tick(2.0)
	if int(kit.ammo["pulse"]) != 8 or int(kit.reserve["pulse"]) != 31:
		_fail("Reload did not conserve ammunition")
		return
	kit.restore({"ammo": {"pulse": 200, "arc": -8}, "reserve": {"pulse": "bad"}})
	if kit.equipped != "holstered" or int(kit.ammo["pulse"]) != 8 or int(kit.ammo["arc"]) != 0 or int(kit.reserve["pulse"]) != 32:
		_fail("Save restore must clamp invalid fields and holster")
		return
	var packed: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var player: CharacterBody3D = world.get("player")
	var camera: Camera3D = world.get("camera")
	var weapons = world.get("weapons")
	weapons.cycle()
	world.set("weapon_aiming", true)
	world.call("_update_weapon_hud")
	if not (world.get("_weapon_card") as Control).visible or not (world.get("_reticle") as Control).visible:
		_fail("Equipped and aiming HUD not visible")
		return
	# Put the player and a real patrol on the unobstructed central road.
	player.global_position = Vector3(0, 1.15, 5)
	var patrol: CharacterBody3D = world.call("_create_car", Vector3(0, 1.15, -12), Color("192943"), true)
	var officers: Array = world.get("officers")
	officers.append(patrol)
	# Existing pursuit cleanup despawns officers at heat <0.15. Preserve
	# the actual real-world collider during this deterministic fixture.
	world.set("heat", 1.0)
	world.set("police_cooldown", 100.0)
	patrol.set_physics_process(false)
	world.set("yaw", 0.0)
	world.set("pitch", 0.42)
	await physics_frame
	world.set("weapon_aiming", true)
	camera.global_position = Vector3(0, 1.7, 7)
	camera.look_at(Vector3(0, 1.7, -12), Vector3.UP)
	var old_heat: float = world.get("heat")
	if not world.call("_fire_weapon"):
		_fail("Outdoor aimed fire did not discharge")
		return
	if not is_instance_valid(patrol) or float(patrol.get("condition")) >= 100.0 or float(world.get("heat")) <= old_heat or int(weapons.ammo["pulse"]) != 7:
		_fail("Real raycast vehicle hit, ammunition and heat were not integrated")
		return
	# Real wall obstruction between the player and target.
	var damaged: float = patrol.get("condition")
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 1.8, -2)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.4)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	weapons.tick(1.0)
	world.set("weapon_aiming", true)
	camera.global_position = Vector3(0, 1.7, 7)
	camera.look_at(Vector3(0, 1.7, -12), Vector3.UP)
	if not world.call("_fire_weapon") or not is_equal_approx(float(patrol.get("condition")), damaged):
		_fail("A real wall must block damage to the patrol behind it")
		return
	wall.queue_free()
	patrol.call("take_arcade_damage", 999.0)
	if not is_equal_approx(float(patrol.get("condition")), 18.0):
		_fail("Disabled patrol condition is not bounded")
		return
	var snapshot: Dictionary = world.call("_capture_snapshot")
	if int(snapshot["weapons"]["ammo"]["pulse"]) != 6:
		_fail("Actual world snapshot omitted ammunition")
		return
	var menu := world.get_node("GameMenus")
	menu.call("open_pause")
	weapons.tick(1.0)
	if world.call("_fire_weapon") or int(weapons.ammo["pulse"]) != 6:
		_fail("Pause must block discharge")
		return
	menu.call("hide_for_game")
	var cars: Array = world.get("cars")
	world.set("current_car", cars[0])
	if world.call("_fire_weapon") or int(weapons.ammo["pulse"]) != 6:
		_fail("Driving must block fire")
		return
	world.set("current_car", null)
	world.call("_update_combat", 0.1)
	if bool(world.get("weapon_aiming")):
		_fail("Aim should not stay active after releasing input")
		return
	print("COMBAT_SMOKE PASS: inventory, cooldown, reload, save, real patrol damage, wall occlusion, police heat, paused/driver gates and HUD")
	quit(0)
