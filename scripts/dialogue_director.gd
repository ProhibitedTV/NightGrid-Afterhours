extends Node3D
## Scene-owned speech channel. Callers supply canonical captions and prewarm
## approved streams outside the active conversation. No inference or disk IO
## in enqueue/tick; no save-state or story progression mutations.
signal caption_changed(line_id: String, caption: String)
signal line_ended(line_id: String, reason: String)
const Mix = preload("res://scripts/audio_mix.gd")
const MAX_QUEUE = 8
const MAX_CLIPS = 64
const MAX_DISTANCE = 18.0
const MAX_SECONDS = 45.0
const AMBIENT = 0
const STORY = 1
const CRITICAL = 2

var _screen: AudioStreamPlayer
var _spatial: AudioStreamPlayer3D
var _bank: Dictionary = {}
var _pending: Array[Dictionary] = []
var _active: Dictionary = {}
var _remaining := 0.0
var _paused := false
var _listener := Vector3.ZERO


func _ready() -> void:
	Mix.ensure()
	_screen = AudioStreamPlayer.new()
	_screen.name = "ScreenSpeech"
	_screen.bus = Mix.DIALOGUE
	add_child(_screen)
	_spatial = AudioStreamPlayer3D.new()
	_spatial.name = "PositionalSpeech"
	_spatial.bus = Mix.DIALOGUE
	_spatial.unit_size = 3.0
	_spatial.max_distance = MAX_DISTANCE
	_spatial.max_polyphony = 1
	add_child(_spatial)


## Asset IO explicitly belongs to scene setup, not playback.
func prewarm(line_id: String) -> bool:
	if not _valid_id(line_id):
		return false
	var path := "res:" + "//assets/audio/voiced/%s/take.wav" % line_id
	if not ResourceLoader.exists(path):
		return false
	return cache_clip(line_id, load(path) as AudioStream)


static func _valid_id(line_id: String) -> bool:
	if line_id.is_empty() or line_id.length() > 101:
		return false
	if not "abcdefghijklmnopqrstuvwxyz".contains(line_id[0]):
		return false
	for c in line_id:
		if not "abcdefghijklmnopqrstuvwxyz0123456789_.-".contains(c):
			return false
	return true


func cache_clip(line_id: String, stream: AudioStream) -> bool:
	if not _valid_id(line_id) or stream == null:
		return false
	if not _bank.has(line_id) and _bank.size() >= MAX_CLIPS:
		return false
	if stream.get_length() <= 0.0 or stream.get_length() > MAX_SECONDS:
		return false
	# Published voices are one-shots; reject incorrectly imported loops.
	if stream is AudioStreamWAV and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return false
	if stream is AudioStreamOggVorbis and stream.loop:
		return false
	_bank[line_id] = stream
	return true


func clear_bank() -> void:
	cancel_all()
	_bank.clear()


## speaker=null means screen/phone UI. Physical speakers are weakly owned:
## streamed-out NPCs cannot keep talking and no reference keeps them alive.
func enqueue(line_id: String, caption: String, priority: int = STORY,
		speaker: Node3D = null, scope: String = "") -> bool:
	if not is_node_ready() or not _valid_id(line_id) or caption.strip_edges().is_empty():
		return false
	if priority < AMBIENT or priority > CRITICAL:
		return false
	if speaker != null and (not speaker.is_inside_tree() or speaker.is_queued_for_deletion()):
		return false
	var ref: WeakRef = weakref(speaker) if speaker != null else null
	var instance := speaker.get_instance_id() if speaker != null else 0
	var entry := {"id": line_id, "caption": caption, "priority": priority,
		"speaker": ref, "speaker_id": instance, "scope": scope}
	if _same(_active, entry):
		return false
	for item in _pending:
		if _same(item, entry):
			return false
	# Stable FIFO within each priority. Never displace equal/higher priority.
	var index := 0
	while index < _pending.size() and int(_pending[index]["priority"]) >= priority:
		index += 1
	if index >= MAX_QUEUE:
		return false
	_pending.insert(index, entry)
	if _pending.size() > MAX_QUEUE:
		_pending.pop_back()
	# An important scene line can cut an ambient bark, not another story line.
	if not _active.is_empty() and int(_active["priority"]) == AMBIENT and priority > AMBIENT:
		_finish("preempted")
	return true


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and a["id"] == b["id"] and a["speaker_id"] == b["speaker_id"] and a["scope"] == b["scope"]


func _eligible(entry: Dictionary) -> bool:
	var ref: WeakRef = entry["speaker"]
	if ref == null:
		return true
	var speaker := ref.get_ref() as Node3D
	return is_instance_valid(speaker) and speaker.is_inside_tree() and not speaker.is_queued_for_deletion() \
		and speaker.global_position.distance_squared_to(_listener) <= MAX_DISTANCE * MAX_DISTANCE


func set_paused(value: bool) -> void:
	_paused = value
	if is_node_ready():
		_screen.stream_paused = value
		_spatial.stream_paused = value


## World calls once per update with the actual listener. Captions advance
## against gameplay elapsed time even with muted or absent audio.
func tick(delta: float, listener: Vector3) -> void:
	if not is_node_ready() or _paused or get_tree().paused:
		return
	_listener = listener
	if not _active.is_empty():
		if not _eligible(_active):
			_finish("speaker_unavailable")
		else:
			var ref: WeakRef = _active["speaker"]
			if ref != null:
				var speaker := ref.get_ref() as Node3D
				_spatial.global_position = speaker.global_position + Vector3.UP * 0.35
			_remaining = maxf(0.0, _remaining - maxf(0.0, delta))
			if _remaining <= 0.0:
				_finish("complete")
	if not _active.is_empty():
		return
	while not _pending.is_empty():
		var entry: Dictionary = _pending.pop_front()
		if not _eligible(entry):
			line_ended.emit(str(entry["id"]), "speaker_unavailable")
			continue
		_start(entry)
		break


func _start(entry: Dictionary) -> void:
	_active = entry
	var id := str(entry["id"])
	var text := str(entry["caption"])
	var clip: AudioStream = _bank.get(id)
	# Fallback reading time is deliberately approximate; production timing
	# comes from the approved clip. Missing speech never plays a UI beep.
	_remaining = clampf(1.0 + float(text.length()) / 15.0, 1.5, 12.0)
	if clip != null:
		_remaining = maxf(1.0, clip.get_length() + 0.15)
		var ref: WeakRef = entry["speaker"]
		if ref == null:
			_screen.stream = clip
			_screen.play()
		else:
			var speaker := ref.get_ref() as Node3D
			_spatial.global_position = speaker.global_position + Vector3.UP * 0.35
			_spatial.stream = clip
			_spatial.play()
	caption_changed.emit(id, text)


func _finish(reason: String) -> void:
	if _active.is_empty():
		return
	var id := str(_active["id"])
	_active = {}
	_remaining = 0.0
	_screen.stop()
	_spatial.stop()
	caption_changed.emit("", "")
	line_ended.emit(id, reason)


func skip() -> void:
	_finish("skipped")


func cancel_scope(scope: String) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		if _pending[i]["scope"] == scope:
			_pending.remove_at(i)
	if not _active.is_empty() and _active["scope"] == scope:
		_finish("cancelled")


func cancel_all() -> void:
	_pending.clear()
	_finish("cancelled")


func current_caption() -> String:
	return str(_active.get("caption", ""))


func speaking() -> bool:
	var bus := AudioServer.get_bus_index(Mix.DIALOGUE)
	return is_node_ready() and not _paused and not get_tree().paused and bus >= 0 \
		and not AudioServer.is_bus_mute(bus) and (_screen.playing or _spatial.playing)


func stats() -> Dictionary:
	return {"pending": _pending.size(), "cached": _bank.size(), "active": str(_active.get("id", "")),
		"remaining": _remaining, "voice_nodes": 2 if is_node_ready() else 0}
