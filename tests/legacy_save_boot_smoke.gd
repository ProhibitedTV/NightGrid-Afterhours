extends SceneTree

const START := Vector3(0.0, 0.870156, 2.56)
const SEED := 1241220418

func _initialize() -> void:
	create_timer(25.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")

func _verify() -> void:
	var session := root.get_node("GameSession")
	session.set("world_seed", SEED)
	session.set("boot_menu_shown", true)
	# Replay the Afterhours intersection from a published Beta.7 v1 save.
	session.set("pending_restore", {
		"version": 1, "seed": SEED, "player_position": [START.x, START.y, START.z],
		"cash": 0, "health": 100, "deliveries": 0, "carrying": false, "hour": 19.2667,
		"cars": [], "rail": {}, "traffic": {"vehicles": [{
			"id": "bus-3", "position": [157.0, 1.75, 170.75], "yaw": PI * 0.5,
			"next_index": 3, "dwell": 5.716667, "last_served": 4
		}]}
	})
	if change_scene_to_file("res://scenes/main.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var player: CharacterBody3D = current_scene.get("player")
	for tick in range(12):
		await physics_frame
		if player.global_position.distance_to(START) > 0.15:
			push_error("LEGACY_SAVE_BOOT: restored courier displaced on tick %d to %s" % [tick, player.global_position])
			quit(1)
			return
	if not player.is_physics_processing() or not player.is_on_floor():
		push_error("LEGACY_SAVE_BOOT: restored courier must resume ordinary physics on the actual street")
		quit(1)
		return
	print("LEGACY_SAVE_BOOT PASS: v1 position survives first street physics ticks")
	quit(0)
