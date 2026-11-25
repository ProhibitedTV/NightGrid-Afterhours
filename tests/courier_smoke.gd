extends SceneTree
const START = Vector3(3.35, 1.15, 26.0)
var world: Node3D
var player: CharacterBody3D
var visual: Node3D
var rig: Skeleton3D
var faults: Array[String] = []
var captures := ""
var evidence: Dictionary = {}

func _initialize() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		_expect(false, "Courier test timed out")
		quit(1))
	call_deferred("_run")

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		faults.append(detail)
		push_error("COURIER_SMOKE: " + detail)

func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	captures = OS.get_environment("NIGHTGRID_COURIER_PLAYBACK_DIR")
	if not captures.is_empty() and (DisplayServer.get_name() == "headless" or not captures.is_absolute_path()
			or DirAccess.dir_exists_absolute(captures) or DirAccess.make_dir_recursive_absolute(captures) != OK):
		_expect(false, "Playback capture requires a renderer and a new absolute path")
		quit(1)
		return
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	# The scripted camera must ignore desktop mouse motion during native replay.
	world.set_process_input(false)
	world.get_node("SurfaceTraffic").process_mode = Node.PROCESS_MODE_DISABLED
	player = world.get("player")
	visual = player.get_node("Visual")
	rig = visual.get("skeleton")
	world.get("city_details").call("set_focus", START)
	await _ticks(30)
	_check_asset()
	await _check_controls()
	await _check_jump_and_equipment()
	await _check_vehicle_and_save()
	await _check_integrated_collision()
	await _check_integrated_rail()
	print("COURIER_EVIDENCE ", JSON.stringify(evidence))
	print("COURIER_SMOKE ", "PASS" if faults.is_empty() else "FAIL")
	quit(0 if faults.is_empty() else 1)

func _check_asset() -> void:
	var library: AnimationPlayer = visual.get("animations")
	var skinned := visual.find_children("*", "MeshInstance3D", true, false)
	var model: MeshInstance3D
	for mesh in skinned:
		if (mesh as MeshInstance3D).skin != null:
			model = mesh
			break
	_expect(rig.get_bone_count() >= 60 and rig.find_bone("RightHandIndex1") >= 0
		and model != null, "Imported game rig must drive a weighted mesh and articulated fingers")
	if model != null:
		var head_at := rig.get_bone_global_rest(rig.find_bone("Head")).origin
		var depth := _eye_surface_depth(model)
		_expect(depth > head_at.z + 0.03, "The weighted face must point toward local +Z")
		evidence["eye_ahead_of_head_m"] = depth - head_at.z
	for clip in [&"idle", &"walk", &"run", &"walk_back", &"strafe_left", &"strafe_right", &"jump_air",
			&"jump_start", &"jump_land", &"interact", &"sit", &"aim", &"fire", &"reload",
			&"board_car", &"drive_car", &"stand_up"]:
		_expect(library.has_animation(clip) and library.get_animation(clip).get_track_count() >= 35,
			"Missing weighted animation tracks for " + str(clip))
	var wardrobe_count: int = visual.call("wardrobe_surface_count")
	_expect(wardrobe_count >= 2, "Actual imported jacket and pants must expose garment surfaces")
	var old_mesh := model.mesh if model != null else null
	var old_skin := model.skin if model != null else null
	_expect(visual.call("set_outfit","tideline") and visual.get("outfit_id")=="tideline","Real weighted outfit changes")
	_expect(model != null and model.mesh==old_mesh and model.skin==old_skin and visual.get("skeleton")==rig,"Colorway must preserve mesh, skin and rig")
	_expect(visual.call("set_outfit","dispatch") and not visual.call("set_outfit","unknown"),"Restore original appearance and reject unknown colorway")
	_expect(Engine.physics_ticks_per_second == 60, "Physics must stay at 60 Hz")

func _eye_surface_depth(model: MeshInstance3D) -> float:
	for i in range(model.mesh.get_surface_count()):
		if model.mesh.surface_get_material(i).resource_name != "Eyes":
			continue
		var data := model.mesh.surface_get_arrays(i)
		var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
		var depth := 0.0
		for index in indices:
			depth += points[index].z
		return depth / float(indices.size())
	return -INF

func _walk_to(start: Vector3, yaw: float, inputs: Array, ticks: int, strength: float = 1.0) -> Vector3:
	player.global_position = start
	player.velocity = Vector3.ZERO
	world.set("yaw", yaw)
	player.set("camera_yaw", yaw)
	for action in inputs:
		Input.action_press(action, strength)
	await _ticks(ticks)
	for action in inputs:
		Input.action_release(action)
	return player.global_position - start

func _check_controls() -> void:
	var paths := [
		[["move_forward"], Vector3.FORWARD], [["move_backward"], Vector3.BACK],
		[["move_left"], Vector3.LEFT], [["move_right"], Vector3.RIGHT],
		[["move_forward", "move_left"], Vector3(-1, 0, -1)],
		[["move_forward", "move_right"], Vector3(1, 0, -1)],
		[["move_backward", "move_left"], Vector3(-1, 0, 1)],
		[["move_backward", "move_right"], Vector3(1, 0, 1)]]
	for i in range(paths.size()):
		var yaw := float(i - 4) * 0.38
		var displacement: Vector3 = await _walk_to(START, yaw, paths[i][0], 29)
		displacement.y = 0.0
		var expected: Vector3 = (paths[i][1] as Vector3).rotated(Vector3.UP, yaw).normalized()
		_expect(displacement.length() > 1.1 and expected.dot(displacement.normalized()) > 0.98
			and visual.global_basis.z.dot(expected) > 0.98,
			"Camera-relative facing failed for %s (movement %s, expected %s, facing %s)" %
			[str(paths[i][0]), displacement, expected, visual.global_basis.z])
	player.velocity = Vector3.ZERO
	var facing := visual.global_basis.z
	world.set("yaw", 2.764)
	await _ticks(13)
	_expect(visual.global_basis.z.dot(facing) > 0.999, "Stationary camera orbit rotated the courier")
	await _walk_to(START, 0.0, ["move_forward"], 28, 0.23)
	_expect(visual.get("current_pose") == &"walk", "Analogue-strength movement did not select the authored walk")
	await _capture("walk")
	Input.action_press("sprint")
	await _walk_to(START, 0.0, ["move_forward"], 39)
	Input.action_release("sprint")
	_expect(visual.get("current_pose") == &"run" and player.get_real_velocity().length() > 11.5,
		"Sprint must retain its gameplay speed and select the run animation")
	await _capture("sprint")
	player.velocity = Vector3.ZERO
	await _ticks(16)
	var query := PhysicsRayQueryParameters3D.create(player.global_position,
		player.global_position + Vector3.DOWN * 2.0, 1, [player.get_rid()])
	var floor := world.get_world_3d().direct_space_state.intersect_ray(query)
	if not floor.is_empty():
		var contact: Vector3 = floor["position"]
		var error := absf(visual.global_position.y - contact.y)
		_expect(error < 0.04, "Visual boot origin is off the physical floor")
		evidence["boot_origin_floor_error_m"] = error

func _check_jump_and_equipment() -> void:
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	_expect(visual.get("current_pose") == &"jump_start", "Jump must enter anticipation/takeoff")
	await _ticks(22)
	_expect(visual.get("current_pose") == &"jump_air", "Unlanded courier must play its airborne cycle")
	await _capture("jump")
	await _ticks(48)
	_expect(player.is_on_floor() and visual.get("current_pose") in [&"jump_land", &"idle"], "Courier did not settle after landing")
	var equipment = world.get("weapons")
	equipment.cycle()
	Input.action_press("weapon_aim")
	await _ticks(25)
	_expect(visual.get("current_pose") == &"aim" and visual.global_basis.z.dot(Vector3.FORWARD) > 0.96,
		"Aim did not align the equipped courier with the view")
	var hand := rig.get_bone_global_pose(rig.find_bone("RightHand")).origin
	_expect(hand.z > 0.35 and hand.y > 1.20, "The real wrist did not reach the equipped aim pose")
	evidence["aim_wrist"] = str(hand)
	await _capture("aim")
	await _capture("aim-detail", player.global_position + Vector3(-2.24, 0.78, -1.67),
		player.global_position + Vector3(0.0, 0.50, -0.25))
	Input.action_press("weapon_fire")
	await _ticks(3)
	Input.action_release("weapon_fire")
	_expect(visual.get("current_pose") == &"fire" and int(equipment.ammo["pulse"]) == 7,
		"Accepted fire must animate without changing the existing ammo cost")
	equipment.tick(1.0)
	var reload := InputEventAction.new()
	reload.action = &"weapon_reload"
	reload.pressed = true
	world.call("_unhandled_input", reload)
	_expect(visual.get("current_pose") == &"reload", "The existing reload action did not animate")
	await _ticks(27)
	await _capture("reload", player.global_position + Vector3(-2.24, 0.78, -1.67),
		player.global_position + Vector3(0.0, 0.50, -0.25))
	Input.action_release("weapon_aim")
	equipment.holster()

func _check_vehicle_and_save() -> void:
	var car: CharacterBody3D = world.get("cars")[0]
	car.global_position = Vector3(1.2, 0.78, 27.0)
	car.rotation.y = 0.0
	player.global_position = car.global_position + Vector3(-1.65, 0.5, -0.43)
	player.velocity = Vector3.ZERO
	car.set_meta("claimed", true)
	var equipment = world.get("weapons")
	equipment.equip("pulse")
	await _ticks(2)
	var prop := rig.get_node("RightHandEquipment/EquippedWeapon") as Node3D
	_expect(prop.visible, "The equipment prop must be visible before vehicle entry")
	world.call("_toggle_car")
	_expect(world.get("current_car") == car and not player.visible and visual.get_parent() == car
		and visual.get("current_pose") == &"board_car", "Vehicle entry must seat the real rig without changing the player capsule")
	_expect(not prop.visible, "The seated courier must stow the equipped prop")
	await _ticks(24)
	await _capture("vehicle-entry", car.global_position + Vector3(-3.7, 1.35, -1.2),
		car.global_position + Vector3(-0.6, 0.45, -0.43))
	await _ticks(172)
	_expect(visual.get("current_pose") == &"drive_car", "The courier did not reach the seated driving loop")
	var head := rig.get_bone_global_pose(rig.find_bone("Head")).origin
	var seated_head := car.to_local(rig.to_global(head))
	_expect(seated_head.x < -0.35 and seated_head.y > 0.7 and seated_head.y < 1.18,
		"The seated head must be in the driver's side of the cabin under the roof")
	evidence["seated_head_car_local"] = str(seated_head)
	await _capture("vehicle-seated", car.global_position + Vector3(-3.0, 0.75, -1.7),
		car.global_position + Vector3(-0.45, 0.56, -0.43))
	var state: Dictionary = world.call("_capture_snapshot")
	_expect(int(state["occupied_car"]) == 0, "The existing v1 snapshot must retain the occupied vehicle index")
	world.call("_apply_snapshot", state)
	_expect(visual.get_parent() == car and visual.get("current_pose") == &"drive_car",
		"Restoring an occupied v1 slot must rebuild the seated pose")
	world.call("_toggle_car")
	_expect(player.visible and visual.get_parent() == player and player.collision_layer == 1
		and visual.get("current_pose") == &"alight_car", "Car exit must return the same rig and restore the capsule")
	equipment.equip("pulse")
	await _ticks(2)
	_expect(prop.visible, "Re-equipping the same item immediately on exit must restore its prop")
	equipment.holster()
	await _ticks(14)
	await _capture("vehicle-exit", player.global_position + Vector3(2.65, 0.95, -1.80),
		player.global_position + Vector3(-0.5, 0.1, 0.0))

func _check_integrated_collision() -> void:
	var city: Node3D = world.get("city_details")
	var car: CharacterBody3D = world.get("cars")[0]
	car.global_position = Vector3(203.0, 0.75, 38.0)
	car.rotation = Vector3.ZERO
	car.velocity = Vector3.ZERO
	car.set("speed", 0.0)
	player.global_position = car.global_position + Vector3(-1.65, 0.45, -0.43)
	player.velocity = Vector3.ZERO
	city.call("set_focus", car.global_position)
	world.call("_toggle_car")
	world.set("yaw", 0.0)
	world.set("pitch", 0.82)
	await _ticks(125)
	world.call("_snap_camera")
	var camera: Camera3D = world.get("camera")
	var chase_height := camera.global_position.y
	_expect(world.get("current_car") == car and visual.get_parent() == car
		and visual.get("current_pose") == &"drive_car" and chase_height < 5.0,
		"The seated courier must preserve the car chase sweep under the actual Horizon canopy")
	evidence["horizon_chase_height_m"] = chase_height
	await _capture("horizon-chase")
	world.call("_toggle_car")
	await _ticks(22)
	_expect(player.visible and visual.get_parent() == player and player.collision_layer == 1
		and player.is_on_floor(), "Canopy-area vehicle exit must restore the same grounded courier")
	var market := Vector3(-32.0, 1.12, -214.0)
	city.call("set_focus", market)
	await _walk_to(market, PI, ["move_forward"], 88)
	_expect(player.global_position.z > -211.0 and player.global_position.z < -210.40 and player.is_on_floor()
		and visual.get("current_pose") == &"idle", "The courier must stop and settle against the actual North Quay counter")
	evidence["north_quay_counter_stop_z"] = player.global_position.z
	await _capture("market-counter", player.global_position + Vector3(2.1, 0.60, -2.3),
		player.global_position + Vector3(0.0, 0.02, 0.35))

func _check_integrated_rail() -> void:
	var rail := world.get_node("MorrowLine")
	var lift := rail.get_node_or_null("MLineStation_04/AccessibleLift")
	if lift == null:
		_expect(false, "Missing the integrated East Gardens lift")
		return
	var lower: Vector3 = lift.call("landing_position", false)
	var upper: Vector3 = lift.call("landing_position", true)
	player.global_position = lower
	player.velocity = Vector3.ZERO
	world.get("city_details").call("set_focus", lower)
	world.set("yaw", 0.0)
	world.set("pitch", 0.38)
	await _ticks(4)
	world.call("_toggle_transit")
	_expect(world.get("transit_kind") == "LIFT" and not visual.is_visible_in_tree()
		and visual.get_parent() == player, "Lift passengers must hide the pedestrian rig and keep its owner")
	await _ticks(205)
	_expect(world.get("current_transit") == null and visual.is_visible_in_tree() and player.is_on_floor()
		and player.global_position.distance_to(upper) < 0.16, "Lift arrival must restore the grounded skinned courier")
	Input.action_press("move_forward")
	await _ticks(53)
	Input.action_release("move_forward")
	rail.call("restore", {"x": 232.0, "current_station": 4, "next_station": 3, "direction": -1, "dwell": 7.0})
	Input.action_press("move_left")
	await _ticks(56)
	Input.action_release("move_left")
	_expect(rail.call("boardable_from", player.global_position) and visual.is_visible_in_tree(),
		"Walk the integrated bridge and platform to the actual stopped M-Line door")
	await _capture("east-gardens-platform")
	world.call("_toggle_transit")
	var journey: Dictionary = world.call("_capture_snapshot")
	_expect(world.get("transit_kind") == "TRAIN" and journey.get("rail_platform_rider") == true
		and not visual.is_visible_in_tree() and visual.get_parent() == player,
		"Door-side boarding must preserve the platform status and hide the on-foot rig")
	rail.call("restore", {"x": 120.0, "current_station": 4, "next_station": 3, "direction": -1, "speed": 6.0})
	await _ticks(120)
	world.call("_toggle_transit")
	await _ticks(10)
	_expect(world.get("current_transit") == null and rail.call("on_platform", player.global_position, 3)
		and player.is_on_floor() and visual.is_visible_in_tree() and visual.get_parent() == player,
		"Train alight must restore the courier, capsule and correct platform")
	evidence["helix_alight_position"] = str(player.global_position)
	await _capture("helix-alight")

func _capture(label: String, at: Vector3 = Vector3.INF, look: Vector3 = Vector3.ZERO) -> void:
	if captures.is_empty():
		return
	var camera: Camera3D = world.get("camera")
	var previous := camera.global_transform
	var fov := camera.fov
	if at.is_finite():
		world.set_process(false)
		camera.global_position = at
		camera.look_at(look)
		camera.fov = 53.0
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	_expect(pixels != null and not pixels.is_empty() and pixels.save_png(captures.path_join(label + ".png")) == OK,
		"Could not capture live gameplay state " + label)
	if at.is_finite():
		camera.global_transform = previous
		camera.fov = fov
		world.set_process(true)
