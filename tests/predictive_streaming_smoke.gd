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
	# A completed chunk used to arrive after one call, which was itself a
	# single expensive frame. Now a single call should execute one SMALL stage.
	var steps_before := int(queued["stage_steps"])
	city.call("_process", 0.016)
	var first: Dictionary = city.call("get_streaming_stats")
	if int(first["loads"]) != int(queued["loads"]) or int(first["pending_blocks"]) != 5:
		_fail("A frame completed a whole district instead of one stage: " + str(first))
		return
	if int(first["stage_steps"]) != steps_before + 1 or int(first["staging_blocks"]) != 1:
		_fail("First predicted block did not enter bounded construction: " + str(first))
		return
	# Every frame advances at most one work stage and never submits more than
	# one fully built chunk. Continue until all five front-loaded lots are ready.
	for index in range(250):
		if int(city.call("get_streaming_stats")["pending_blocks"]) == 0:
			break
		var before: Dictionary = city.call("get_streaming_stats")
		city.call("_process", 0.016)
		var after_frame: Dictionary = city.call("get_streaming_stats")
		if int(after_frame["stage_steps"]) - int(before["stage_steps"]) > 1:
			_fail("A frame ran more than one streaming build stage")
			return
		if int(after_frame["loads"]) - int(before["loads"]) > 1:
			_fail("A frame completed multiple district chunks")
			return
	if int(city.call("get_streaming_stats")["pending_blocks"]) != 0:
		_fail("Staged build queue never drained")
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
	var before_jump: Dictionary = city.call("get_streaming_stats")
	city.call("request_focus", remote, Vector3.ZERO)
	var jump: Dictionary = city.call("get_streaming_stats")
	var jump_stage: Dictionary = city.get("_staging")
	var occupied := Vector2i(-4, -4)
	if not jump_stage.has(occupied) or int(jump["loads"]) != int(before_jump["loads"]):
		_fail("Fast arrival should stage the occupied physical shells, not build its entire visual chunk")
		return
	if int(jump["stage_steps"]) != int(before_jump["stage_steps"]) + 1 or int(jump_stage[occupied]["phase"]) != 1:
		_fail("Fast arrival did not prime exactly one collision-bearing parcel stage")
		return
	var physical_shells := 0
	for child in (jump_stage[occupied]["node"] as Node3D).get_children():
		if child is StaticBody3D:
			physical_shells += 1
	if physical_shells != 2:
		_fail("Emergency occupied cell is missing its two physical building shells")
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
	print("PREDICTIVE_STREAMING_SMOKE PASS: forward ring queued, one stage/frame, collider-first fast arrival and complete teleport, seed=", seed_before)
	quit(0)
