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
	if not str(Radio.LINES["ACK"]).contains("10-17") or not str(Radio.LINES["RELEASED"]).contains("10-19") or not str(Radio.LINES["UNAVAILABLE"]).contains("10-7"):
		push_error("MBPD_RADIO: service lifecycle codes missing")
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
	# Burst traffic must not bury the closing announcement or replay stale calls.
	radio.call("enqueue", "SEARCH")
	radio.call("enqueue", "ACK", "OLD")
	radio.call("enqueue", "CONTACT")
	radio.call("enqueue", "CLOSED", "THEFT")
	for j in range(12):
		radio.call("enqueue", "RELEASED", str(j))
	var queue: Array = radio.get("pending")
	if queue.size() != Radio.MAX_QUEUE or queue[0]["kind"] != "CLOSED":
		push_error("MBPD_RADIO: closing event evicted during burst")
		quit(1)
		return
	for item in queue:
		if str(item["kind"]) in ["SEARCH", "ACK", "CONTACT"]:
			push_error("MBPD_RADIO: obsolete response chatter survives closure")
			quit(1)
			return
	radio.call("tick", 0.1, true)
	if not str(radio.get("current")).contains("Code 4") or not bool(radio.call("has_traffic")):
		push_error("MBPD_RADIO: closure not played first")
		quit(1)
		return
	radio.call("tick", 0.1, false)
	if bool(radio.call("has_traffic")):
		push_error("MBPD_RADIO: silent channel failed to reset")
		quit(1)
		return
	# Real world release path: a disabled cruiser must never announce a return.
	world.call("_spawn_police")
	var units: Array = world.get("officers")
	if units.size() != 1:
		push_error("MBPD_RADIO: could not dispatch test cruiser")
		quit(1)
		return
	var officer: CharacterBody3D = units[0]
	var unit_id := str(officer.get_meta("unit_id"))
	officer.set("condition", 0.0)
	world.call("_release_response", officer)
	units.clear()
	var last_event: Dictionary = dispatch.history.back()
	if last_event["event"] != "UNAVAILABLE" or last_event["detail"] != unit_id or not officer.is_queued_for_deletion() or not (world.get("returning_units") as Array).is_empty():
		push_error("MBPD_RADIO: disabled unit incorrectly returned to station")
		quit(1)
		return
	# Verify the spoken/caption selection against a real dispatch event.
	radio.set("last_sequence", int(last_event["sequence"]) - 1)
	radio.call("ingest", dispatch.history)
	radio.call("tick", 0.1, true)
	if not str(radio.get("current")).contains("10-7") or not str(radio.get("current")).contains(unit_id):
		push_error("MBPD_RADIO: out-of-service event did not reach receiver")
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
	# Real ledger and real station room; never fabricate a call or unit arrival.
	world.set("heat", 0.0)
	dispatch.update_case(Vector3.INF, 0)
	radio.set("last_sequence", dispatch.event_sequence)
	radio.call("tick", 0.1, false)
	world.set("_radio_was_wanted", false)
	world.set("_radio_close_tail", 0.0)
	var ledger = world.get("ambient_civic")
	ledger.restore({})
	ledger.advance(21.0)
	var incident: Dictionary = ledger.catalog()[0]
	var station_id := str(incident["station_id"])
	world.call("_announce_civic_at_station", {"station_id":"other"})
	if bool(radio.call("has_traffic")):
		push_error("MBPD_RADIO: unrelated precinct received civic request")
		quit(1)
		return
	world.call("_update_police_radio", 0.1)
	var notice: String = radio.get("current")
	if not notice.contains("request on file") or not notice.contains(str(incident["id"])) or not notice.contains(station_id.to_upper()):
		push_error("MBPD_RADIO: real civic ledger request not announced at HQ")
		quit(1)
		return
	radio.call("tick", 20.0, true)
	world.call("_update_police_radio", 0.1)
	if bool(radio.call("has_traffic")):
		push_error("MBPD_RADIO: repeated civic request")
		quit(1)
		return
	ledger.advance(18.0)
	world.call("_update_police_radio", 0.1)
	if bool(radio.call("has_traffic")) or float(world.get("heat")) != 0.0:
		push_error("MBPD_RADIO: resolved civic request or player heat changed")
		quit(1)
		return
	print("MBPD_RADIO_SMOKE PASS: twelve voiced clips, service lifecycle, bounded queue, real station board and independent civic request announcements")
	quit(0)
