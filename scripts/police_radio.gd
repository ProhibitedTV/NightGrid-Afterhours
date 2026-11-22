extends Node
## MBPD radio language inspired by published common ten-codes. Only events emitted by the game
## dispatch controller enter the receiver. No live radio or network access.
const Mix = preload("res://scripts/audio_mix.gd")
const Foley = preload("res://scripts/city_foley.gd")
const MAX_QUEUE = 6
const LINES = {
	"REPORT": "Dispatch to all units. New incident reported.",
	"ASSIGNED": "Dispatch to unit. Respond to assigned call.",
	"ACK": "Unit to dispatch. 10-4. 10-17, en route.",
	"CONTACT": "Unit to dispatch. Visual contact.",
	"SEARCH": "Unit to dispatch. Checking reported location.",
	"CLOSED": "Dispatch. Code 4. Incident closed.",
	"RELEASED": "Unit to dispatch. 10-19, returning to station.",
	"UNAVAILABLE": "Unit to dispatch. 10-7, out of service.",
	"AVAILABLE": "Unit to dispatch. 10-8, available.",
	"CIVICMOTORIST": "Dispatch. Motorist assistance request on file.",
	"CIVICTRAFFIC": "Dispatch. Traffic service request on file.",
	"CIVICPUBLIC": "Dispatch. Public service request on file."
}
var pending: Array[Dictionary] = []
var current := ""
var last_sequence := 0
var elapsed := 0.0
var _voice: AudioStreamPlayer
var _local_voice: AudioStreamPlayer3D
var _receiver := Vector3.INF
var _clips: Dictionary = {}
var _last_state := ""
var _cooldown := 0.0

func _ready() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.name = "MBPDReceiver"
	_voice.bus = Mix.DIALOGUE
	_voice.volume_db = -5.0
	add_child(_voice)
	_local_voice = AudioStreamPlayer3D.new()
	_local_voice.name = "MBPDLocalReceiver"
	_local_voice.bus = Mix.DIALOGUE
	_local_voice.volume_db = -3.0
	_local_voice.unit_size = 7.0
	_local_voice.max_distance = 18.0
	add_child(_local_voice)
	for key in LINES:
		var resource := "res://assets/audio/mbpd/" + str(key).to_lower() + ".wav"
		if ResourceLoader.exists(resource):
			_clips[key] = load(resource)

func enqueue(kind: String, detail: String = "") -> void:
	if not LINES.has(kind):
		return
	# Once dispatch closes a case, queued response chatter is obsolete.
	# Let the current clip finish, then announce closure before routine traffic.
	if kind == "CLOSED":
		for i in range(pending.size() - 1, -1, -1):
			if str(pending[i]["kind"]) in ["REPORT", "ASSIGNED", "ACK", "CONTACT", "SEARCH", "CLOSED"]:
				pending.remove_at(i)
		if pending.size() >= MAX_QUEUE:
			pending.pop_front()
		pending.push_front({"kind":kind, "detail":detail})
		return
	# A bounded non-overlapping channel; coalesce repeat pending events.
	for item in pending:
		if item["kind"] == kind and item["detail"] == detail:
			return
	var urgent := kind in ["REPORT", "CONTACT", "ASSIGNED"]
	if not urgent and pending.size() >= MAX_QUEUE:
		return
	if pending.size() >= MAX_QUEUE:
		pending.pop_back()
	var entry := {"kind":kind, "detail":detail}
	if urgent:
		var index := 0
		while index < pending.size() and pending[index]["kind"] in ["CLOSED", "REPORT", "CONTACT", "ASSIGNED"]:
			index += 1
		pending.insert(index, entry)
	else:
		pending.append(entry)

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
		_local_voice.stop()
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
	_voice.stop()
	_local_voice.stop()
	if _receiver.is_finite():
		_local_voice.global_position = _receiver
		_local_voice.stream = clip
		_local_voice.play()
	else:
		_voice.stream = clip
		_voice.play()
	elapsed = maxf(2.7, clip.get_length() + 0.35)

func set_receiver(at: Vector3) -> void:
	_receiver = at

func speaking() -> bool:
	var bus := AudioServer.get_bus_index(Mix.DIALOGUE)
	return not AudioServer.is_bus_mute(bus) and (_voice.playing or _local_voice.playing)

func has_traffic() -> bool:
	return elapsed > 0.0 or not pending.is_empty()

func voice_count() -> int:
	return _clips.size()
