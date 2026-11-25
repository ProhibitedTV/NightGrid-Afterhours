extends RefCounted
## Optional imported authored WAVs. No inference, downloads, or external services in game.
const ROOT="res://assets/audio/generated/synaxis/"
const AudioMix=preload("res://scripts/audio_mix.gd")

static func stream(id:String,loop:bool=false) -> AudioStreamWAV:
	var path:=ROOT+id+".wav"
	if not ResourceLoader.exists(path,"AudioStreamWAV"):
		return null
	var original:=load(path) as AudioStreamWAV
	if original==null:
		return null
	var sound:=original.duplicate() as AudioStreamWAV
	sound.loop_mode=AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	if loop:
		sound.loop_begin=0
		sound.loop_end=roundi(sound.get_length()*sound.mix_rate)
	return sound

static func emitter(parent:Node3D,id:String,at:Vector3,db:float,distance:float,loop:bool=false) -> AudioStreamPlayer3D:
	var audio:=stream(id,loop)
	if audio==null:
		return null
	var player:=AudioStreamPlayer3D.new()
	player.name=id
	AudioMix.ensure()
	player.bus=AudioMix.AMBIENCE if loop else AudioMix.ROOM_EFFECTS
	player.stream=audio
	player.position=at
	player.volume_db=db
	player.max_distance=distance
	parent.add_child(player)
	return player

static func activate(player:AudioStreamPlayer3D,active:bool) -> void:
	if not is_instance_valid(player):
		return
	if active and not player.playing:
		player.play()
	elif not active:
		player.stop()
