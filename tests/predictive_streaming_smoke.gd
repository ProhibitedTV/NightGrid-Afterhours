extends SceneTree
## Incremental streaming contract: a moving car must not synchronously spawn
## an entire new district; explicit teleports keep immediate collision coverage.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("PREDICTIVE_STREAMING_SMOKE: " + message)
	quit(1)

func _verify() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Playable scene missing")
		return
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails")
	var player: CharacterBody3D = world.get("player")
	var session := root.get_node_or_null("GameSession")
	if city == null or player == null or session == null:
		_fail("Required city, player, or save session missing")
		return
	var seed_before: int = session.get("world_seed")
	var blocks_before: Array = city.call("get_loaded_blocks")
	var initial: Dictionary = city.call("get_streaming_stats")
	if blocks_before.size() != 25 or int(initial["pending_blocks"]) != 0:
		_fail("Expected 25 solid downtown blocks and no startup backlog: " + str(initial))
		return
	# Car at 72 m/s predicts an upcoming new ring; request must not build it
	# synchronously. The normal runtime limits speed to a lower value.
	city.call("request_focus", player.global_position, Vector3(72.0, 0.0, 0.0))
	var queued: Dictionary = city.call("get_streaming_stats")
	if int(queued["loads"]) != int(initial["loads"]) or int(queued["pending_blocks"]) != 5:
		_fail("Prefetch request built blocks synchronously or missed the next ring: " + str(queued))
		return
	city.call("_process", 0.016)
	var first: Dictionary = city.call("get_streaming_stats")
	if int(first["loads"]) - int(queued["loads"]) != 1 or int(first["pending_blocks"]) != 4:
		_fail("One frame must construct no more than one queued block: " + str(first))
		return
	for index in range(12):
		if int(city.call("get_streaming_stats")["pending_blocks"]) == 0:
			break
		var before: int = int(city.call("get_streaming_stats")["loads"])
		city.call("_process", 0.016)
		if int(city.call("get_streaming_stats")["loads"]) - before > 1:
			_fail("A frame constructed more than one district block")
			return
	if int(city.call("get_streaming_stats")["pending_blocks"]) != 0:
		_fail("Scheduled block queue never drained")
		return
	if not (city.get("_loaded") as Dictionary).has(Vector2i(3, 0)):
		_fail("Driving lookahead failed to prewarm a forward collision block")
		return
	var after: Dictionary = city.call("get_streaming_stats")
	if int(after["queue_replans"]) < 1 or int(after["peak_build_usec"]) < 1:
		_fail("Streamer did not report build-time instrumentation")
		return
	# Idempotent focus and explicit teleport still preserve authored geography.
	city.call("request_focus", player.global_position, Vector3(72.0, 0.0, 0.0))
	if int(city.call("get_streaming_stats")["pending_blocks"]) != 0:
		_fail("Same predicted focus unnecessarily recreated the streaming queue")
		return
	var remote := Vector3(-203.0, 1.15, -203.0)
	player.global_position = remote
	var before_jump: int = int(city.call("get_streaming_stats")["loads"])
	city.call("request_focus", remote, Vector3.ZERO)
	if not (city.get("_loaded") as Dictionary).has(Vector2i(-4, -4)) or int(city.call("get_streaming_stats")["loads"]) != before_jump + 1:
		_fail("Unexpected fast travel must synchronously protect the occupied collision cell")
		return
	city.call("set_focus", remote)
	if not (city.get("_loaded") as Dictionary).has(Vector2i(-4, -4)):
		_fail("Teleport did not immediately load physical destination geometry")
		return
	if (city.get("_loaded") as Dictionary).has(Vector2i(3, 0)):
		_fail("Teleport failed to evict stale remote city blocks")
		return
	if int(session.get("world_seed")) != seed_before:
		_fail("Incremental streaming changed the immutable saved world seed")
		return
	print("PREDICTIVE_STREAMING_SMOKE PASS: forward ring queued, one block/frame, collision-safe fast jump and teleport, seed=", seed_before)
	quit(0)
