extends Node
## Menu-owned dialogue: the menu deliberately pauses the world, not its speech.
## Canonical scene captions remain visible even when a clip is unavailable.
const Mix = preload("res://scripts/audio_mix.gd")
const SCENES = {
	"conference": [1, 2],
	"call_mandarin": [1, 2],
	"conference_end": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
	"offboarding": [6],
	"breakroom_party": [1, 2, 3, 4, 5, 6, 7],
	"breakroom_photo": [1, 2, 3],
	"breakroom_decline": [1, 2],
}
var _player: AudioStreamPlayer
var _scene := ""
var _pending: Array[Dictionary] = []
var active_id := ""

static func scene_for(screen: String, stage: int, beat: int, choice: String) -> String:
	if screen == "breakroom":
		return "breakroom_party" if choice.is_empty() else choice
	if screen != "opening":
		return ""
	if stage == 2 and beat >= 0 and beat < 3:
		return ["conference", "call_mandarin", "conference_end"][beat]
	if stage == 4:
		return "offboarding"
	return ""

static func line_ids(scene: String) -> Array[String]:
	var result: Array[String] = []
	for row in SCENES.get(scene, []):
		result.append("synaxis.%s.%02d" % [scene, row])
	return result

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Mix.ensure()
	_player = AudioStreamPlayer.new()
	_player.name = "SynaxisSceneSpeech"
	_player.bus = Mix.DIALOGUE
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.finished.connect(_advance)

func select_scene(scene: String) -> void:
	# Menu rerenders (focus, settings) must not restart an ongoing scene.
	if scene == _scene:
		return
	stop()
	_scene = scene
	# Only load the small scene's resources, never the full city bank.
	for id in line_ids(scene):
		var path := "res://assets/audio" + ("/voiced/%s/take.wav" % id)
		if not ResourceLoader.exists(path):
			continue
		var clip := load(path) as AudioStream
		if clip == null or clip.get_length() <= 0.0 or clip.get_length() > 45.0:
			continue
		if clip is AudioStreamWAV and clip.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			continue
		if clip is AudioStreamOggVorbis and clip.loop:
			continue
		_pending.append({"id": id, "clip": clip})
	_advance()

func _advance() -> void:
	active_id = ""
	if _pending.is_empty():
		_player.stream = null
		return
	var entry: Dictionary = _pending.pop_front()
	active_id = str(entry["id"])
	_player.stream = entry["clip"] as AudioStream
	_player.play()

func stop() -> void:
	_pending.clear()
	active_id = ""
	_scene = ""
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null

func current_scene() -> String:
	return _scene
