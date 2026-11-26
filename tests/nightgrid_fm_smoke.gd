extends SceneTree
## Exercises the original packed library and the bounded asynchronous mixer.
func _initialize() -> void:
	create_timer(22.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("NIGHTGRID_FM_SMOKE: " + message)
	quit(1)

func _wait_track(radio: Node, different_from: String = "") -> Dictionary:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var stats: Dictionary = radio.call("playback_stats")
		var track: String = stats["track"]
		if not track.is_empty() and track != different_from:
			return stats
		await process_frame
	return {}

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
	if script.menu_music_factor("blue_hour_set")!=0.0 or script.menu_music_factor("pause")!=0.44 or script.menu_music_factor("hidden")!=1.0 or script.menu_music_factor("title")!=1.0:
		_fail("Rhythm cues must own their mix without muting ordinary menu music")
		return
	var available: int = radio.call("available_tracks")
	if available != tracks.size():
		_fail("Incomplete audio pack: expected twenty original Ogg assets, found %d" % available)
		return
	radio.call("set_preferences", 0.25, true)
	radio.call("update_listener", Vector3.ZERO, true, "", "")
	var first := await _wait_track(radio)
	if first.is_empty() or first["context"] != "car" or not radio.call("next_car_track"):
		_fail("Installed soundtrack does not tune into or skip through the car station")
		return
	var second := await _wait_track(radio, first["track"])
	if second.is_empty() or int(second["playing"]) != 2 or int(second["pending_loads"]) > 3:
		_fail("Car skip must keep the outgoing decoder during the bounded crossfade")
		return
	var saved: Dictionary = radio.call("snapshot")
	var restored: Node = script.new()
	root.add_child(restored)
	restored.call("restore", saved)
	restored.call("update_listener", Vector3.ZERO, true, "", "")
	var resume := await _wait_track(restored)
	if resume.get("track", "") != second["track"]:
		_fail("The v1 optional tuning slot did not restore the saved track")
		return
	radio.call("set_preferences", 0.0, false)
	await process_frame
	if radio.call("next_car_track") or str(radio.call("get_now_playing")) != "NIGHTGRID FM  /  OFF":
		_fail("Car radio power must block skip and clear the station display")
		return
	print("NIGHTGRID_FM_SMOKE PASS: twenty original tracks, asynchronous skip, overlapping decks and v1 tuning restore")
	quit(0)
