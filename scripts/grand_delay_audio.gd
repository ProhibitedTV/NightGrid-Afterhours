extends Node
## Two original seamless mono loops. Updated only by the active race modal.
const EngineLoop = preload("res://assets/arcade/audio/grand_delay_engine.wav")
const TireLoop = preload("res://assets/arcade/audio/grand_delay_tires.wav")
const AudioMix = preload("res://scripts/audio_mix.gd")
var engine: AudioStreamPlayer
var tires: AudioStreamPlayer

func _ready() -> void:
	engine = _voice("EngineLoop",EngineLoop)
	tires = _voice("TireLoop",TireLoop)

func _voice(id: String, source: AudioStreamWAV) -> AudioStreamPlayer:
	var voice = AudioStreamPlayer.new()
	voice.name = id
	voice.bus = AudioMix.EFFECTS
	var loop = source.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length()*loop.mix_rate)
	voice.stream = loop
	voice.volume_db = -48.0
	add_child(voice)
	return voice

func start_race() -> void:
	engine.pitch_scale = .72
	engine.volume_db = -24.0
	engine.play()
	tires.volume_db = -48.0
	tires.pitch_scale = .9
	# Start tires on demand, not as an inaudible looping voice.

func update_race(race, delta: float) -> void:
	var rpm = clampf(race.speed/98.0,0.0,1.0)
	var pitch = .72+rpm*1.30
	if race.nitro_left>0.0:
		pitch += .14
	engine.pitch_scale = move_toward(engine.pitch_scale,pitch,delta*3.0)
	engine.volume_db = move_toward(engine.volume_db,-24.0+rpm*9.0,delta*24.0)
	if race.drifting or race.shoulder:
		if not tires.playing:
			tires.play()
		tires.volume_db = move_toward(tires.volume_db,-20.0 if race.drifting else -26.0,delta*70.0)
		tires.pitch_scale = .75+rpm*.45
	elif tires.playing:
		tires.volume_db = move_toward(tires.volume_db,-48.0,delta*90.0)
		if tires.volume_db<=-47.9:
			tires.stop()

func stop_race() -> void:
	if is_instance_valid(engine):
		engine.stop()
	if is_instance_valid(tires):
		tires.stop()
