extends SceneTree
const Wheel = preload("res://scripts/equipment_wheel.gd")

func _initialize() -> void:
	create_timer(35.0, true, false, true).timeout.connect(func() -> void: _fail("timeout"))
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("EQUIPMENT_WHEEL_SMOKE: " + message)
	paused = false
	quit(1)

func _key(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	return event

func _pad(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event

func _verify() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var kit = world.get("weapons")
	var wheel: Control = world.get("equipment_wheel")
	if not is_instance_valid(wheel) or wheel.visible or paused:
		_fail("Wheel should start hidden with simulation running")
		return
	if wheel.is_processing() or wheel.is_processing_input():
		_fail("Hidden wheel should not receive frame or input processing")
		return
	kit.equip("pulse")
	var before: Dictionary = kit.snapshot()
	world.call("_unhandled_input", _key(KEY_C))
	if not wheel.visible or not paused or int(wheel.get("selected")) != 1:
		_fail("C must open a modal preview of the equipped weapon")
		return
	if not wheel.is_processing() or not wheel.is_processing_input():
		_fail("Visible wheel must restore frame and input processing")
		return
	if wheel.call("index_for_direction", Vector2.INF) != -1 or wheel.call("index_for_direction", Vector2.ZERO) != -1:
		_fail("Nonfinite and neutral directions must not select a slot")
		return
	if wheel.call("index_for_direction", Vector2.UP) != 0 or wheel.call("index_for_direction", Vector2(1, 0.5)) != 1 or wheel.call("index_for_direction", Vector2(-1, 0.5)) != 2:
		_fail("Radial direction selection incorrect")
		return
	wheel.call("_input", _key(KEY_3))
	if int(wheel.get("selected")) != 2 or kit.snapshot() != before:
		_fail("Preview must not mutate equipment or ammo")
		return
	# Animation is visual only; selection and ammo are already deterministic.
	wheel.call("_process", 0.07)
	var weights: PackedFloat32Array = wheel.get("_selection_weights")
	if weights[2] <= 0.0 or weights[2] >= 1.0 or not is_equal_approx(weights[1] + weights[2], 1.0):
		_fail("Selection highlight must interpolate between slots")
		return
	wheel.call("_process", 0.14)
	weights = wheel.get("_selection_weights")
	if not is_equal_approx(weights[2], 1.0) or not is_zero_approx(weights[1]) or kit.snapshot() != before:
		_fail("Selection highlight must settle without modifying live equipment")
		return
	if world.call("_fire_weapon"):
		_fail("Paused selector must block firing")
		return
	wheel.call("_input", _pad(JOY_BUTTON_B))
	if paused or wheel.visible or kit.snapshot() != before:
		_fail("Cancel must preserve equipment and ammo")
		return
	if wheel.is_processing() or wheel.is_processing_input():
		_fail("Cancelled wheel must stop processing")
		return
	world.call("_unhandled_input", _pad(JOY_BUTTON_RIGHT_STICK))
	weights = wheel.get("_selection_weights")
	if not is_equal_approx(weights[1], 1.0) or not is_zero_approx(weights[2]):
		_fail("Reopening must restore equipped highlight instead of stale preview")
		return
	wheel.call("_input", _pad(JOY_BUTTON_DPAD_RIGHT))
	wheel.call("_input", _pad(JOY_BUTTON_A))
	if paused or wheel.visible or kit.equipped != "arc" or kit.ammo != before["ammo"] or kit.reserve != before["reserve"] or not bool(world.get("_fire_held")):
		_fail("Controller confirm must equip and require trigger release")
		return
	if kit.equip("invalid"):
		_fail("Invalid equipment IDs must be rejected")
		return
	world.call("_open_equipment_wheel")
	await process_frame
	var center := wheel.size * 0.5
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = wheel.get_global_transform_with_canvas() * center
	wheel.call("_input", mouse)
	if not wheel.visible:
		_fail("Middle dead zone must not commit a choice")
		return
	mouse.position = wheel.get_global_transform_with_canvas() * (center + Vector2.UP * float(wheel.call("_radius")) * 0.72)
	wheel.call("_input", mouse)
	if paused or wheel.visible or kit.equipped != "holstered":
		_fail("Mouse click in top segment should holster")
		return
	var cars: Array = world.get("cars")
	world.set("current_car", cars[0])
	if world.call("_open_equipment_wheel"):
		_fail("Vehicle context must reject wheel")
		return
	world.set("current_car", null)
	var menu := world.get_node("GameMenus")
	menu.call("open_pause")
	if world.call("_open_equipment_wheel"):
		_fail("System menu must reject wheel")
		return
	menu.call("hide_for_game")
	print("EQUIPMENT_WHEEL_SMOKE PASS: modal world pause, mouse dead zone, keyboard preview/cancel, controller equip, trigger gate and contexts")
	quit(0)
