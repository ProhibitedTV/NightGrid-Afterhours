extends SceneTree
const Caption = preload("res://scripts/dialogue_caption.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("DIALOGUE_CAPTION_SMOKE: " + reason)
	quit(1)

func _verify() -> void:
	var caption := Caption.new()
	root.add_child(caption)
	if caption.visible or caption.is_processing():
		_fail("Idle caption must be hidden and not process")
		return
	caption.present("Mara", "Mara: Take care out there.")
	if not caption.visible or caption.content()["line"] != "Take care out there." or caption.speaker_label.text != "MARA":
		_fail("Speaker and line must render independently")
		return
	if caption.mouse_filter != Control.MOUSE_FILTER_IGNORE or caption.line_label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("Caption must never intercept world input")
		return
	caption._process(caption.remaining + 0.1)
	if caption.visible or caption.is_processing():
		_fail("Timed caption did not expire")
		return
	caption.present("Dispatch", "Stand by.", false, 10.0)
	if caption.remaining < 10.0:
		_fail("Future voice playback duration must be respected")
		return
	caption.present("Mara", "Come back when the run is done.", true)
	var hold := caption.remaining
	caption._process(30.0)
	caption.present("Mara", "Come back when the run is done.", true)
	if not caption.visible or not caption.persistent or caption.is_processing() or caption.remaining != hold:
		_fail("Persistent choice caption should survive refresh without processing")
		return
	caption.present("Mara", "Different response.", true)
	if caption.content()["line"] != "Different response.":
		_fail("Caption did not replace old speech")
		return
	caption.clear()
	if caption.visible or not str(caption.content()["line"]).is_empty():
		_fail("Clear did not remove previous speech")
		return
	print("DIALOGUE_CAPTION_SMOKE PASS: speaker, passive input, timer, voice floor, persistent refresh")
	quit(0)
