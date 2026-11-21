extends Node
## MBPD radio language inspired by published common ten-codes. Only events emitted by the game
## dispatch controller enter the receiver. No live radio or network access.
const Mix = preload("res://scripts/audio_mix.gd")
const Foley = preload("res://scripts/city_foley.gd")
const MAX_QUEUE = 6
const LINES = {
	"REPORT": "Dispatch to all units. New incident reported.",
	"ASSIGNED": "Dispatch to unit. Respond to assigned call.",
	"ACK": "Unit to dispatch. 10-4, responding.",
	"CONTACT": "Unit to dispatch. Visual contact.",
	"SEARCH": "Unit to dispatch. Checking reported location.",
	"CLOSED": "Dispatch. Code 4. Incident closed.",
	"RELEASED": "Unit to dispatch. Returning to station.",
	"AVAILABLE": "Unit to dispatch. 10-8, available."
}
var pending: Array[Dictionary] = []
var current := ""
var last_sequence := 0
var elapsed := 0.0
var _voice: AudioStreamPlayer
var _clips: Dictionary = {}
var _last_state := ""
var _cooldown := 0.0

func _ready() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.name = "MBPDReceiver"
	_voice.bus = Mix.EFFECTS
	_voice.volume_db = -8.0
	add_child(_voice)
	for key in LINES:
		var resource := "res://assets/audio/mbpd/" + str(key).to_lower() + ".wav"
		if ResourceLoader.exists(resource):
			_clips[key] = load(resource)

func enqueue(kind: String, detail: String = "") -> void:
	if not LINES.has(kind):
		return
	# A bounded non-overlapping channel; coalesce repeat pending events.
	for item in pending:
		if item["kind"] == kind and item["detail"] == detail:
			return
	if pending.size() >= MAX_QUEUE:
		pending.pop_front()
	pending.append({"kind":kind, "detail":detail})

func ingest(events: Array[Dictionary]) -> void:
	for event in events:
		var seq := int(event.get("sequence", 0))
		if seq <= last_sequence:
			continue
		last_sequence = seq
		var kind := str(event["event"])
		var detail := str(event["detail"])
		enqueue(kind, detail)
		if kind == "ASSIGNED":
			enqueue("ACK", detail)

func update_state(active: bool, seen: bool, delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not active:
		_last_state = ""
		return
	var state := "CONTACT" if seen else "SEARCH"
	if state != _last_state and _cooldown <= 0.0:
		_last_state = state
		_cooldown = 4.0
		enqueue(state)

func tick(delta: float, audible: bool) -> void:
	if not audible:
		pending.clear()
		current = ""
		elapsed = 0.0
		_voice.stop()
		return
	elapsed = maxf(0.0, elapsed - delta)
	if elapsed > 0.0:
		return
	current = ""
	if pending.is_empty():
		return
	var item: Dictionary = pending.pop_front()
	var kind: String = item["kind"]
	var detail: String = item["detail"]
	current = "MBPD  /  " + str(LINES[kind])
	if not detail.is_empty():
		current += "  [" + detail + "]"
	var clip: AudioStream = _clips.get(kind, Foley.sound("UI"))
	_voice.stream = clip
	_voice.play()
	elapsed = maxf(2.7, clip.get_length() + 0.35)

func voice_count() -> int:
	return _clips.size()
