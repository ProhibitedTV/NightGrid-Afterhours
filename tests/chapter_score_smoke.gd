extends SceneTree
const Score = preload("res://scripts/chapter_score.gd")
const Radio = preload("res://scripts/nightgrid_fm.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("CHAPTER_SCORE_SMOKE: " + message)
	quit(1)

func _verify() -> void:
	if Score.context(true,false,"SYNAXIS_LOBBY","hidden",0) != "score:arrival":
		_fail("arrival must take precedence")
		return
	if Score.context(false,true,"SYNAXIS_BASEMENT","hidden",5) != "score:offboarding" or Score.context(false,false,"SYNAXIS_OFFICE","opening",4) != "score:offboarding":
		_fail("offboarding speech and departure must select the same score")
		return
	if Score.context(false,false,"SYNAXIS_BASEMENT","hidden",1) != "score:basement" or Score.context(false,false,"SYNAXIS_PARKING","hidden",1) != "":
		_fail("room score routing")
		return
	if not Score.one_shot("score:arrival") or not Score.one_shot("score:offboarding") or Score.one_shot("score:lobby"):
		_fail("cinematic cues must not repeat")
		return
	var radio := Radio.new()
	root.add_child(radio)
	radio.set_process(false)
	var count := radio.available_tracks()
	var installed: Dictionary = radio.get("_available")
	var id := Score.cue_id("score:arrival")
	installed.erase(id)
	radio.set_chapter_context(true,true,false,"SYNAXIS_LOBBY")
	if radio.call("_context") != "" or radio.call("_next_id","score:arrival") != "":
		_fail("missing optional score must fail to silence")
		return
	# Inject an in-memory availability entry, not an unreviewed audio file.
	installed[id] = "test-only"
	if radio.call("_context") != "score:arrival" or radio.call("_next_id","score:arrival") != id or radio.available_tracks() != count or radio.get_track_titles().size() != 20:
		_fail("score must reuse deck selection without modifying radio inventory")
		return
	radio.set_chapter_context(true,false,false,"SYNAXIS_BASEMENT")
	radio.set_chapter_context(true,false,false,"SYNAXIS_LIFT")
	if radio.get("_chapter_room") != "SYNAXIS_BASEMENT":
		_fail("lift must retain previous room")
		return
	radio.set_chapter_context(false)
	radio.update_listener(Vector3.ZERO,true,"","")
	if radio.call("_context") != "car":
		_fail("free roam must restore original radio context")
		return
	print("CHAPTER_SCORE_SMOKE PASS: optional score policy, one-shots, lift continuity, radio isolation")
	quit(0)
