extends SceneTree
const Director = preload("res://scripts/dialogue_director.gd")
const Mix = preload("res://scripts/audio_mix.gd")
var failures: Array[String] = []
var endings: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _verify() -> void:
	var director := Director.new()
	root.add_child(director)
	await process_frame
	director.line_ended.connect(func(id: String, reason: String) -> void: endings.append(id + ":" + reason))
	check(director.stats()["voice_nodes"] == 2, "fixed voice pool")
	check(not director.prewarm("nonexistent.line"), "optional missing clip")
	check(not director.enqueue("../unsafe", "bad"), "invalid id")
	check(director.enqueue("ambient.one", "Hello there.", Director.AMBIENT), "ambient enqueue")
	director.tick(0.0, Vector3.ZERO)
	check(director.current_caption() == "Hello there.", "missing audio caption fallback")
	check(not director.speaking(), "no fake audio for missing clip")
	check(not director.enqueue("ambient.one", "Hello there.", Director.AMBIENT), "active dedup")
	check(director.enqueue("story.one", "Important story.", Director.STORY), "story enqueue")
	check(endings.has("ambient.one:preempted"), "ambient interrupted")
	director.tick(0.0, Vector3.ZERO)
	check(director.current_caption() == "Important story.", "story priority")
	var remaining: float = director.stats()["remaining"]
	director.set_paused(true)
	director.tick(30.0, Vector3.ZERO)
	check(director.stats()["remaining"] == remaining, "explicit pause")
	director.set_paused(false)
	paused = true
	director.tick(30.0, Vector3.ZERO)
	check(director.stats()["remaining"] == remaining, "tree pause")
	paused = false
	Mix.set_level(Mix.DIALOGUE, 0.0)
	check(not director.speaking() and director.current_caption() == "Important story.", "muted captions")
	Mix.set_level(Mix.DIALOGUE, 0.82)
	director.skip()
	check(endings.has("story.one:skipped") and director.current_caption().is_empty(), "skip")
	for i in range(30):
		director.enqueue("ambient.%d" % i, "Bark.", Director.AMBIENT, null, "street")
	check(director.stats()["pending"] == Director.MAX_QUEUE, "bounded queue")
	director.enqueue("urgent.one", "Emergency.", Director.CRITICAL, null, "mission")
	director.tick(0.0, Vector3.ZERO)
	check(director.stats()["active"] == "urgent.one", "priority eviction")
	director.cancel_scope("street")
	check(director.stats()["pending"] == 0, "scope cancellation")
	director.cancel_all()
	var speaker := Node3D.new()
	root.add_child(speaker)
	speaker.position = Vector3(50, 0, 0)
	director.enqueue("npc.far", "Out of range.", Director.AMBIENT, speaker)
	director.tick(0.0, Vector3.ZERO)
	check(director.current_caption().is_empty() and endings.has("npc.far:speaker_unavailable"), "range gate")
	speaker.position = Vector3(1, 0, 0)
	director.enqueue("npc.near", "Nearby.", Director.AMBIENT, speaker)
	director.tick(0.0, Vector3.ZERO)
	check(director.current_caption() == "Nearby.", "nearby caption")
	speaker.queue_free()
	await process_frame
	director.tick(0.0, Vector3.ZERO)
	check(director.current_caption().is_empty() and endings.has("npc.near:speaker_unavailable"), "streamed actor removal")
	var clip := AudioStreamWAV.new()
	clip.mix_rate = 8000
	clip.format = AudioStreamWAV.FORMAT_8_BITS
	var data := PackedByteArray()
	data.resize(8000)
	clip.data = data
	check(director.cache_clip("fixture.wav", clip), "prewarm fixture")
	director.enqueue("fixture.wav", "Fixture caption.", Director.STORY)
	director.tick(0.0, Vector3.ZERO)
	check(director.stats()["remaining"] >= 1.0, "clip duration")
	director.tick(2.0, Vector3.ZERO)
	check(endings.has("fixture.wav:complete"), "clip completion")
	director.clear_bank()
	check(director.stats()["cached"] == 0, "bank reset")
	if not failures.is_empty():
		for issue in failures:
			push_error("DIALOGUE_DIRECTOR: " + issue)
		quit(1)
		return
	print("DIALOGUE_DIRECTOR PASS: bounded pool, priority, pause, captions, range, despawn, skip, cache and completion")
	quit(0)
