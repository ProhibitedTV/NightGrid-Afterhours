extends PanelContainer
## A presentation-only caption: never advances missions, changes input, or plays voice.
## Embedded conversation lines remain visible; ambient lines expire in game time.
const Ui = preload("res://scripts/ui_style.gd")
const MIN_SECONDS := 3.0
const MAX_SECONDS := 18.0
var speaker_label: Label
var line_label: Label
var remaining := 0.0
var persistent := false
var _speaker := ""
var _line := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", Ui.card(0.86, 10))
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 4)
	add_child(layout)
	speaker_label = Label.new()
	speaker_label.name = "Speaker"
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_label.add_theme_font_size_override("font_size", 15)
	speaker_label.add_theme_color_override("font_color", Ui.AMBER)
	speaker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(speaker_label)
	line_label = Label.new()
	line_label.name = "SpokenLine"
	line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_label.add_theme_font_size_override("font_size", 22)
	line_label.add_theme_color_override("font_color", Ui.TEXT)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(line_label)
	hide()
	set_process(false)

func present(speaker: String, line: String, hold: bool = false, voice_seconds: float = 0.0) -> void:
	var clean_speaker := speaker.strip_edges()
	var clean_line := line.strip_edges()
	if not clean_speaker.is_empty():
		var prefix := clean_speaker + ":"
		if clean_line.to_lower().begins_with(prefix.to_lower()):
			clean_line = clean_line.substr(prefix.length()).strip_edges()
	if clean_line.is_empty():
		clear()
		return
	# The venue panel refreshes at 10 Hz. Identical persistent content does
	# not allocate labels, restart a timer or animate on each update.
	if visible and _speaker == clean_speaker and _line == clean_line and persistent and hold:
		return
	_speaker = clean_speaker
	_line = clean_line
	persistent = hold
	speaker_label.text = clean_speaker.to_upper()
	speaker_label.visible = not clean_speaker.is_empty()
	line_label.text = clean_line
	remaining = maxf(clampf(1.0 + float(clean_line.length()) / 16.0, MIN_SECONDS, MAX_SECONDS), maxf(0.0, voice_seconds))
	show()
	set_process(not hold)

func clear() -> void:
	remaining = 0.0
	persistent = false
	_speaker = ""
	_line = ""
	hide()
	set_process(false)

func _process(delta: float) -> void:
	if persistent:
		return
	remaining -= maxf(0.0, delta)
	if remaining <= 0.0:
		clear()

func content() -> Dictionary:
	return {"speaker": _speaker, "line": _line, "persistent": persistent}
