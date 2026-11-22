extends SceneTree
## Windows Forward+ screenshots and ordinary F8 walking traces with fixed
## seed, graphics, input, camera and clock. Compare launch flag off and on.
const Game = preload("res://scenes/main.tscn")
const Plan = preload("res://scripts/world_plan.gd")
const STREET_NAMES = {"brickwater": "BRICKWATER", "afterhours": "AFTERHOURS", "west-docks": "WEST DOCKS"}
const DISTRICTS = {
	"brickwater": [Vector3(-18.5, 1.18, -37), Vector3(-27, 1.18, 1), Vector3(-31, 2.3, 5), Vector3(-18.5, 1.36, 10), PI * 0.5],
	"afterhours": [Vector3(29, 1.18, -36), Vector3(32, 1.18, 1), Vector3(22, 2.3, 5), Vector3(32, 1.36, 10), -PI * 0.5],
	"west-docks": [Vector3(-203, 1.18, -37), Vector3(-184, 1.18, 1), Vector3(-197, 2.3, 5), Vector3(-211, 1.36, 10), PI * 0.5]
}
var output: String
var reports: Array[Dictionary] = []
var reference_views := {}

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	output = OS.get_environment("NIGHTGRID_LIVING_STREETS_DIR")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		push_error("Capture needs Forward+ and a new absolute output directory")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	var reference := OS.get_environment("NIGHTGRID_LIVING_STREETS_REFERENCE")
	if not reference.is_empty():
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(reference))
		if not manifest is Dictionary:
			quit(1)
			return
		for record in manifest.get("reports", []):
			var shot: Dictionary = record["screenshot"]
			reference_views[record["label"]] = [_point(shot["camera_at"]), _point(shot["look_at"])]
	var district_filter := OS.get_environment("NIGHTGRID_LIVING_STREETS_DISTRICT")
	for district in DISTRICTS:
		if not district_filter.is_empty() and district != district_filter:
			continue
		for hour in [12.0, 22.0]:
			if not await _sample(district, hour):
				quit(1)
				return
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null or reports.is_empty():
		quit(1)
		return
	file.store_string(JSON.stringify({
		"seed": root.get_node("GameSession").get("world_seed"),
		"revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"living_streets": "--living-streets" in OS.get_cmdline_user_args(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"resolution": [root.size.x, root.size.y],
		"settings": {"ssr": true, "ao": true, "glow": true, "fog": true, "vsync": false},
		"reports": reports
	}, "\t"))
	file.close()
	print("LIVING_STREETS_CAPTURE PASS")
	quit()

func _sample(district: String, hour: float) -> bool:
	var locations: Array = DISTRICTS[district]
	var label := district + ("-day" if hour == 12.0 else "-night")
	var game := Game.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	game.get_node("GameMenus").call("hide_for_game")
	game.call("_apply_game_settings", {"ssr_enabled": true, "ao_enabled": true, "glow_enabled": true,
		"fog_enabled": true, "vsync_enabled": false})
	game.set_process_input(false)
	game.set_process(false)
	var city: Node3D = game.get("city_details")
	var player: CharacterBody3D = game.get("player")
	var camera: Camera3D = game.get("camera")
	var clock: Node = game.get("day_night")
	var pedestrians: Node3D = game.get("pedestrians")
	if not is_instance_valid(pedestrians) and "--living-streets" in OS.get_cmdline_user_args():
		return false
	clock.set("paused", true)
	clock.call("set_hour", hour)
	player.global_position = locations[0]
	city.call("set_focus", player.global_position)
	camera.global_position = player.global_position + Vector3.UP * 1.5
	camera.look_at(camera.global_position + Vector3.FORWARD)
	await _ticks(245)

	player.global_position = locations[1]
	player.velocity = Vector3.ZERO
	city.call("set_focus", player.global_position)
	game.get_node("HUD").hide()
	var view: Array = reference_views.get(label, [locations[2], locations[3]])
	if is_instance_valid(pedestrians):
		view = _street_view(pedestrians, STREET_NAMES[district], locations[1], view)
	camera.global_position = view[0]
	camera.look_at(view[1])
	camera.fov = 52.0
	await _ticks(8)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var photo := output.path_join(label + ".png")
	if image == null or image.save_png(photo) != OK:
		return false
	await physics_frame
	var active: Dictionary = pedestrians.call("active_positions") if is_instance_valid(pedestrians) else {}
	var visible := 0
	var unobstructed := 0
	var excluded: Array[RID] = pedestrians.call("camera_exclusions") if is_instance_valid(pedestrians) else []
	var space := game.get_world_3d().direct_space_state
	for at in active.values():
		if camera.is_position_in_frustum(at + Vector3.UP):
			visible += 1
			unobstructed += int(_clear(space, camera.global_position, at + Vector3.UP * 1.45, excluded))
	var shot := {"file": label + ".png", "sha256": FileAccess.get_sha256(photo),
		"camera": str(camera.global_position), "rotation": str(camera.global_rotation),
		"camera_at": _components(view[0]), "look_at": _components(view[1]),
		"camera_fov": camera.fov, "active": active.size(), "in_frustum": visible, "unobstructed": unobstructed}
	game.get_node("HUD").show()

	# Traverse with the real chase camera and recorder. Keep the screenshot
	# and settling work out of the measured interval.
	game.set("yaw", locations[4])
	game.set("pitch", 0.38)
	game.call("_snap_camera")
	game.set_process(true)
	for index in range(55):
		await RenderingServer.frame_post_draw
	var recorder: RefCounted = game.get("frame_time_recorder")
	var stream: Dictionary = city.call("get_streaming_stats")
	recorder.begin_capture(stream["loads"], stream["stage_steps"], stream["total_build_usec"])
	var start := player.global_position
	var peak := active.size()
	Input.action_press("move_forward", 0.63)
	for index in range(290):
		await physics_frame
		if is_instance_valid(pedestrians) and index % 12 == 0:
			peak = maxi(peak, int((pedestrians.call("stats") as Dictionary)["active"]))
	Input.action_release("move_forward")
	recorder.end_capture()
	var csv: String = recorder.export_csv(output.path_join(label + ".csv"))
	var report := {"label": label, "hour": hour, "screenshot": shot, "start": str(start),
		"end": str(player.global_position), "distance_m": player.global_position.distance_to(start),
		"frames": recorder.captured_frames(), "peak_active": peak}
	if is_instance_valid(pedestrians):
		report["population"] = pedestrians.call("stats")
	reports.append(report)
	print("LIVING_STREETS_SAMPLE ", JSON.stringify(report))
	game.queue_free()
	await process_frame
	return not csv.is_empty()

func _ticks(count: int) -> void:
	for index in range(count):
		await physics_frame

func _street_view(director: Node3D, district: String, anchor: Vector3, fallback: Array) -> Array:
	var at_by_id: Dictionary = director.call("active_positions")
	var excluded: Array[RID] = director.call("camera_exclusions")
	var space := director.get_world_3d().direct_space_state
	var best := fallback
	var rating := INF
	for id in at_by_id:
		var at: Vector3 = at_by_id[id]
		if Plan.district_at(at) != district:
			continue
		var target := at + Vector3.UP * 1.12
		var eye := at + Vector3.UP * 1.55
		for offset in [Vector3(-1.8, 2.0, -7.0), Vector3(1.8, 2.0, -7.0),
				Vector3(-1.8, 2.0, 7.0), Vector3(1.8, 2.0, 7.0),
				Vector3(7.0, 2.0, 1.8), Vector3(-7.0, 2.0, 1.8)]:
			var from: Vector3 = at + offset
			var score := anchor.distance_to(at) + (0.0 if str(id).begins_with("central-retail") else 4.0)
			if score < rating and _clear(space, from, eye, excluded):
				best = [from, target]
				rating = score
	return best

func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, toward: Vector3, excluded: Array[RID]) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, toward, 1, excluded)
	ray.hit_from_inside = true
	return space.intersect_ray(ray).is_empty()

func _components(point: Vector3) -> Array[float]:
	return [point.x, point.y, point.z]

func _point(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
