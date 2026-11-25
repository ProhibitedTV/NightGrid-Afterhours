extends SceneTree
## Regression for issue #32: reaching a partial city chunk must not force all
## decorative construction into a single physics/render callback.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("OCCUPIED_COLLISION_STREAMING_SMOKE: " + reason)
	quit(1)

func _solid_count(chunk: Node3D) -> int:
	var result := 0
	for child in chunk.get_children():
		if child is StaticBody3D:
			result += 1
	return result

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable scene unavailable")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if city == null or session == null:
		_fail("The live city or persistent save session is missing")
		return
	var seed := int(session.get("world_seed"))
	var manifest_signature := WorldPlan.manifest_signature(session.call("get_world_manifest"))

	# A block partially prebuilt by the predictor has collision shells, but
	# its facades and details are not finished. Crossing into it should not
	# force an expensive complete build, nor replace the staged node.
	var parcel := Vector2i(3, 1)
	if (city.get("_loaded") as Dictionary).has(parcel):
		_fail("Remote parcel is unexpectedly loaded on boot")
		return
	city.call("_run_build_stage", parcel)
	var staged: Dictionary = city.get("_staging")
	if not staged.has(parcel) or int(staged[parcel]["phase"]) != 1:
		_fail("Prewarm did not build exactly the collision-shell stage")
		return
	var original := staged[parcel]["node"] as Node3D
	if _solid_count(original) != 2:
		_fail("Prewarmed parcel lacks both physical building shells")
		return
	var prior: Dictionary = city.call("get_streaming_stats")
	city.call("request_focus", Vector3(203.0, 0.0, 87.0), Vector3.ZERO)
	var arrived: Dictionary = city.call("get_streaming_stats")
	if int(arrived["stage_steps"]) != int(prior["stage_steps"]) or int(arrived["loads"]) != int(prior["loads"]):
		_fail("Crossing a staged parcel synchronously finished decorative work")
		return
	staged = city.get("_staging")
	if not staged.has(parcel) or staged[parcel]["node"] != original or not (city.get("_pending") as Array).has(parcel):
		_fail("Crossing a staged parcel discarded its geometry or lost its pending work")
		return

	# Major landmarks are different: their first physical structures are
	# emitted in phase 1, so a surprise arrival must prime that phase too.
	var landmark := Vector2i(0, 3) # SOUTHWORKS HALL
	if WorldPlan.landmark_for_block(landmark.x, landmark.y).is_empty():
		_fail("Landmark coordinate no longer identifies Southworks Hall")
		return
	var before_landmark: Dictionary = city.call("get_streaming_stats")
	city.call("request_focus", Vector3(29.0, 0.0, 203.0), Vector3.ZERO)
	var after_landmark: Dictionary = city.call("get_streaming_stats")
	staged = city.get("_staging")
	if int(after_landmark["stage_steps"]) != int(before_landmark["stage_steps"]) + 2:
		_fail("Landmark should prime only its foundation and physical structure stages")
		return
	if not staged.has(landmark) or int(staged[landmark]["phase"]) != 4:
		_fail("Landmark's physical structure was not prepared on arrival")
		return
	if _solid_count(staged[landmark]["node"]) < 1:
		_fail("Arriving at Southworks Hall exposes a collision-free landmark")
		return
	if int(after_landmark["loads"]) != int(before_landmark["loads"]):
		_fail("Landmark arrival forced all its batched visual details to finish")
		return
	if int(after_landmark["occupied_collision_fallback_stages"]) < 2:
		_fail("Emergency collider stages were not counted for field profiling")
		return

	# A deliberate teleport still has an immediately complete ring. This
	# separately guards the synchronous restore path and save determinism.
	city.call("set_focus", Vector3(29.0, 0.0, 203.0))
	if not (city.get("_loaded") as Dictionary).has(landmark):
		_fail("Explicit restore did not complete the destination geometry")
		return
	if int(session.get("world_seed")) != seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != manifest_signature:
		_fail("Collision-first arrival modified the saved city")
		return
	# A genuine loaded parcel remains present while a live pedestrian holds
	# its reservation, even on explicit long-distance relocation.
	# The World render tick normally requests the actual player focus. For
	# this explicit streaming fixture, keep that producer from overriding
	# the test relocation while CityDetails continues its own processing.
	world.set_process(false)
	var pinned_cell := Vector2i(0,3)
	var start := Vector3(10,0.3,190)
	var end := Vector3(10,0.3,210)
	if not city.call("reserve_pedestrian_parcel","fixture",start,end):
		_fail("Fully loaded same-parcel sidewalk reservation rejected")
		return
	if city.call("reserve_pedestrian_parcel","crossing",start,Vector3(65,0.3,210)):
		_fail("A multi-parcel link was accepted by single-parcel reservation")
		return
	for i in range(11):
		if not city.call("reserve_pedestrian_parcel","fixture%d" % i,start,end):
			_fail("Reservation capacity prematurely exhausted")
			return
	if city.call("reserve_pedestrian_parcel","overflow",start,end):
		_fail("Reservation cap exceeded")
		return
	city.call("set_focus",Vector3(29,0,-203))
	if not pinned_cell in city.call("get_loaded_blocks"):
		_fail("Pinned pedestrian parcel unloaded")
		return
	if city.call("reserve_pedestrian_parcel","fixture",Vector3(10,0.3,-210),Vector3(10,0.3,-190)):
		_fail("Existing lease could be silently moved")
		return
	for i in range(11):
		city.call("release_pedestrian_parcel","fixture%d" % i)
	await process_frame
	await process_frame
	if not pinned_cell in city.call("get_loaded_blocks"):
		_fail("Other active reservation lost its parcel")
		return
	city.call("release_pedestrian_parcel","fixture")
	await process_frame
	await process_frame
	if pinned_cell in city.call("get_loaded_blocks"):
		_fail("Released remote parcel not collected without focus movement")
		return
	print("OCCUPIED_COLLISION_STREAMING_SMOKE PASS: pre-staged crossing, landmark collision, bounded fallback, stable save")
	quit(0)
