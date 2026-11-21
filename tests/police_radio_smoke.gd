extends SceneTree
const Radio = preload("res://scripts/police_radio.gd")
const Dispatch = preload("res://scripts/police_dispatch.gd")
func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")
func _verify() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var radio: Node = world.get_node("PoliceRadio")
	if int(radio.call("voice_count")) != Radio.LINES.size():
		push_error("MBPD_RADIO: generated speech missing")
		quit(1)
		return
	world.call("_report_incident", "THEFT", Vector3(0,1,0), true)
	world.call("_update_police_radio", 0.1)
	if not str(radio.get("current")).contains("New incident reported") or not (world.get("_radio_card") as Control).visible:
		push_error("MBPD_RADIO: live incident did not speak/display coded caption")
		quit(1)
		return
	if not str(Radio.LINES["ACK"]).contains("10-4") or not str(Radio.LINES["CLOSED"]).contains("Code 4") or not str(Radio.LINES["AVAILABLE"]).contains("10-8"):
		push_error("MBPD_RADIO: familiar radio terminology missing")
		quit(1)
		return
	var dispatch = world.get("dispatch")
	var count: int = radio.get("last_sequence")
	radio.call("ingest", dispatch.history)
	if int(radio.get("last_sequence")) != count:
		quit(1)
		return
	for j in range(20):
		radio.call("enqueue", "ASSIGNED", str(j))
	if (radio.get("pending") as Array).size() > Radio.MAX_QUEUE:
		quit(1)
		return
	radio.call("tick", 10.0, false)
	if not str(radio.get("current")).is_empty() or not (radio.get("pending") as Array).is_empty():
		quit(1)
		return
	var civic := world.get_node("CivicServices")
	var player: CharacterBody3D = world.get("player")
	player.global_position = civic.call("position_for", "police_hq")
	world.call("_toggle_interior")
	world.call("_update_police_radio", 0.1)
	var room := world.get_node("Interiors/Interior_police_hq")
	if room.get_node_or_null("DispatchBoard") == null or room.get_node_or_null("RadioOperator_1") == null or not str(room.get_node("DispatchBoard").text).contains("CASE"):
		push_error("MBPD_RADIO: live staffed board missing")
		quit(1)
		return
	print("MBPD_RADIO_SMOKE PASS: eight voiced clips, incident caption/audio queue, bounded deduplication and live staffed HQ")
	quit(0)
