extends SceneTree
## Runs in source-only and fully packaged checkouts.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("NIGHTGRID_FM_SMOKE: " + message)
	quit(1)

func _verify() -> void:
	var script = load("res://scripts/nightgrid_fm.gd")
	if script == null:
		_fail("Cannot load NightGrid FM director")
		return
	var radio: Node = script.new()
	root.add_child(radio)
	await process_frame
	var tracks: Dictionary = radio.call("get_track_titles")
	var playlists: Dictionary = radio.call("get_playlists")
	if tracks.size() != 20:
		_fail("Expected the 20 creator-supplied soundtrack tracks")
		return
	for category in ["title", "car", "club", "bar", "cafe", "stall"]:
		if not playlists.has(category) or (playlists[category] as Array).is_empty():
			_fail("Playlist missing: " + category)
			return
		for id in playlists[category]:
			if not tracks.has(id):
				_fail("Playlist contains unknown track: " + str(id))
				return
	if (playlists["car"] as Array).size() != tracks.size():
		_fail("In-car NightGrid FM must carry the whole library")
		return
	for id in tracks:
		if not (playlists["car"] as Array).has(id):
			_fail("Car station omitted track: " + str(id))
			return
	if str(radio.call("_group", "street:club:prism_club")) != "club":
		_fail("Street venue playlist grouping is broken")
		return
	if str(radio.call("_group", "interior:cafe:lantern_cup")) != "cafe":
		_fail("Interior programming is broken")
		return
	var available: int = radio.call("available_tracks")
	if available != 0 and available != tracks.size():
		_fail("Incomplete audio pack: expected 0 (source-only) or 20 Ogg assets, found %d" % available)
		return
	radio.call("set_preferences", 0.25, true)
	radio.call("update_listener", Vector3.ZERO, true, "", "")
	radio.call("_process", 0.3)
	if available == tracks.size():
		if not radio.call("next_car_track") or not str(radio.call("get_now_playing")).begins_with("NIGHTGRID FM"):
			_fail("Installed soundtrack does not tune in from the car")
			return
	else:
		if radio.call("next_car_track"):
			_fail("Missing audio pack should not report successful playback")
			return
	radio.call("set_preferences", 0.0, false)
	radio.call("_process", 0.3)
	print("NIGHTGRID_FM_SMOKE PASS: 20/20 tracks curated; %d audio resources installed" % available)
	quit(0)
