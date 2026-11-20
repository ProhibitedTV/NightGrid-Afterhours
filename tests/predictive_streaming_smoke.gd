extends SceneTree
## Real scene-graph streaming: safe collision shells first, bounded decoration
## batches per render frame, and paced eviction without altering saved seeds.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("PREDICTIVE_STREAMING_SMOKE: " + message)
	quit(1)

func _step(city: Node) -> Dictionary:
	var before: Dictionary = city.call("get_streaming_stats")
	var before_nodes: int = (city.get("_loaded") as Dictionary).size()
	city.call("_process", 0.016)
	var after: Dictionary = city.call("get_streaming_stats")
	if int(after["loads"]) - int(before["loads"]) > 1:
		return {"error": "More than one authored block completed in one frame"}
	if (city.get("_loaded") as Dictionary).size() - before_nodes > 1:
		return {"error": "More than one collision-ready block was created in one frame"}
	if int(after["unloads"]) - int(before["unloads"]) > 1:
		return {"error": "More than one old block was unloaded in one frame"}
	if int(after["completed_detail_batches"]) - int(before["completed_detail_batches"]) > 8:
		return {"error": "More than eight MultiMesh batches were uploaded in one frame"}
	return after

func _drain(city: Node, limit: int) -> bool:
	for index in range(limit):
		var pending: int = int(city.call("get_streaming_stats")["pending_blocks"])
		var queued_unloads: int = int(city.call("get_streaming_stats")["pending_unloads"])
		if pending == 0 and queued_unloads == 0:
			return true
		var state := _step(city)
		if state.has("error"):
			_fail(str(state["error"]))
			return false
	return false

func _verify() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Playable scene missing")
		return
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails") as Node3D
	var player: CharacterBody3D = world.get("player")
	var session := root.get_node_or_null("GameSession")
	if city == null or player == null or session == null:
		_fail("Required city, player or save session missing")
		return
	var seed_before: int = session.get("world_seed")
	var loaded_before: Array = city.call("get_loaded_blocks")
	var initial: Dictionary = city.call("get_streaming_stats")
	if loaded_before.size() != 25 or int(initial["pending_blocks"]) != 0:
		_fail("Downtown startup must be fully solid with no queued assets: " + str(initial))
		return
	# A 72 m/s driver predicts the next physical 5-block strip.
	city.call("request_focus", player.global_position, Vector3(72.0, 0.0, 0.0))
	var queued: Dictionary = city.call("get_streaming_stats")
	if int(queued["loads"]) != int(initial["loads"]) or int(queued["pending_blocks"]) != 5:
		_fail("Predictive request built speculative blocks synchronously: " + str(queued))
		return
	var first := _step(city)
	if first.has("error"):
		_fail(str(first["error"]))
		return
	if (city.get("_loaded") as Dictionary).size() != 26 or int(first["pending_blocks"]) != 5:
		_fail("First frame must prepare one collision-ready block, not drain all visual batches: " + str(first))
		return
	if int(first["completed_detail_batches"]) <= int(initial["completed_detail_batches"]):
		_fail("Visual details were never committed to first speculative block")
		return
	if city.get("_inflight_node") == null:
		_fail("Large authored block unexpectedly finished all detail batches in one frame")
		return
	# The occupied player's collision ring must continue to exist even while
	# the neighboring facades are still being uploaded.
	if not (city.get("_loaded") as Dictionary).has(Vector2i(0, 0)):
		_fail("Streaming removed the player collision neighborhood")
		return
	var inflight: Node3D = city.get("_inflight_node")
	var has_collider := false
	for child in inflight.get_children():
		if child is StaticBody3D:
			has_collider = true
			break
	if not has_collider:
		_fail("Decorations began streaming before the new block's solid building collider")
		return
	if not _drain(city, 500):
		_fail("Frame-budgeted speculative detail jobs failed to drain")
		return
	if not (city.get("_loaded") as Dictionary).has(Vector2i(3, 0)):
		_fail("Driving prediction did not prepare forward collision geometry")
		return
	var after: Dictionary = city.call("get_streaming_stats")
	if int(after["queue_replans"]) < 1 or int(after["peak_build_usec"]) < 1:
		_fail("Build-time instrumentation did not report any work")
		return
	if int(after["pending_detail_batches"]) != 0 or city.get("_inflight_node") != null:
		_fail("Streamer left an incomplete visual block after draining")
		return
	# Idempotent request should not recreate the same queue.
	city.call("request_focus", player.global_position, Vector3(72.0, 0.0, 0.0))
	if int(city.call("get_streaming_stats")["pending_blocks"]) != 0:
		_fail("Repeated focus unnecessarily rescheduled finished chunks")
		return
	# Simulate an unexpected fast jump while a second speculative ring is
	# active. The destination collision cell must be prepared immediately.
	var remote := Vector3(-203.0, 1.15, -203.0)
	player.global_position = remote
	var before_jump: int = int(city.call("get_streaming_stats")["loads"])
	city.call("request_focus", remote, Vector3.ZERO)
	if not (city.get("_loaded") as Dictionary).has(Vector2i(-4, -4)):
		_fail("Fast jump left occupied destination physically empty")
		return
	if int(city.call("get_streaming_stats")["loads"]) != before_jump + 1:
		_fail("Emergency destination built more than its own collision block")
		return
	if not _drain(city, 500):
		_fail("Fast-jump speculative geometry or paced unloads failed to drain")
		return
	if (city.get("_loaded") as Dictionary).has(Vector2i(3, 0)):
		_fail("Distant loaded blocks were never evicted after crossing the map")
		return
	if int(city.call("get_streaming_stats")["unloads"]) <= int(after["unloads"]):
		_fail("Streamer did not pace any stale-city unload work")
		return
	city.call("set_focus", remote)
	if not (city.get("_loaded") as Dictionary).has(Vector2i(-4, -4)):
		_fail("Explicit teleport does not immediately retain physical city")
		return
	if int(session.get("world_seed")) != seed_before:
		_fail("Speculative streaming altered the immutable saved world seed")
		return
	print("PREDICTIVE_STREAMING_SMOKE PASS: collision-first staged detail, <=8 visual batches and <=1 eviction/frame, save-safe jump")
	quit(0)
