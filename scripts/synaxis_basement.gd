extends "res://scripts/synaxis_workfloor.gd"
## Physical B1 infrastructure level. No permanent per-rack processing.
const GeneratedSFX=preload("res://scripts/synaxis_generated_audio.gd")
const FLOOR=-1
const TITLE="B1 / INFORMATION TECHNOLOGY & INFRASTRUCTURE"
const GOAL=Vector3(-5,1.15,4)
const DESK=Vector3(-5,0,2.55)
const RACK_X=[-6.6,-2.8,2.8,6.6]
const RACK_Z=[-7.7,-6.3,-4.9,-3.5,-2.1]
var _racks:=0
var _hum:AudioStreamPlayer3D

func _ready() -> void:
	_part("steel",Vector3(0,.005,0),Vector3(16.6,.01,19.7))
	for x in range(-8,9,2):
		_part("black",Vector3(x,.012,0),Vector3(.012,.006,19.7))
	for z in range(-9,10,2):
		_part("black",Vector3(0,.012,z),Vector3(16.6,.006,.012))
	for x in RACK_X:
		for z in RACK_Z:
			_rack(Vector3(x,0,z),1.0 if x<0 else -1.0)
		# Contiguous rack collision and overhead cable trays.
		_solid(Vector3(x,1.14,-4.9),Vector3(.92,2.28,6.82))
		_part("black",Vector3(x,2.95,-4.9),Vector3(.64,.15,7.0))
		for z in range(-8,0):
			_part("steel",Vector3(x,3.04,z),Vector3(.71,.05,.07))
		_part("blue",Vector3(x-.16,3.06,-4.9),Vector3(.08,.08,7.0))
		_part("rust",Vector3(x+.16,3.06,-4.9),Vector3(.08,.08,7.0))
	for x in [-7.75,7.75]:
		_part("white",Vector3(x,1.35,6.9),Vector3(.8,2.7,2.3))
		_solid(Vector3(x,1.35,6.9),Vector3(.8,2.7,2.3))
		for vent in range(8):
			_part("black",Vector3(x-signf(x)*.415,1.7+vent*.075,6.9),Vector3(.018,.028,1.9))
		_part("rust",Vector3(x-signf(x)*.42,.9,6.9),Vector3(.02,.19,.32))
	_label("COOLING / DO NOT BLOCK AIRFLOW",Vector3(7.28,2.5,6.9),.0028,-PI/2)
	_label("UPS / AUTHORIZED PERSONNEL ONLY",Vector3(-7.28,2.5,6.9),.0028,PI/2)
	# Marked circulation strip down the main aisle and around the lift.
	for x in [-1.8,1.8]:
		_part("rust",Vector3(x,.017,-3.5),Vector3(.07,.009,10.8))
	_part("rust",Vector3(0,.017,1.2),Vector3(15.5,.009,.07))
	# Service desk and the physical folder drop-off.
	_part("oak",DESK+Vector3(0,1.025,0),Vector3(2.6,.11,.85))
	_part("steel",DESK+Vector3(-1.18,.49,0),Vector3(.08,.98,.72))
	_part("steel",DESK+Vector3(1.18,.49,0),Vector3(.08,.98,.72))
	_solid(DESK+Vector3(0,.54,0),Vector3(2.6,1.08,.85))
	_monitor(DESK+Vector3(-.48,1.36,0),1.0)
	_monitor(DESK+Vector3(.20,1.36,0),1.0)
	_part("black",DESK+Vector3(-.1,1.10,.26),Vector3(.43,.025,.15))
	_chair(DESK+Vector3(0,0,1.06),-1.0)
	_label("IT SUPPORT / ACCESS CONTROL",Vector3(-5,2.02,2.09),.0038)
	# Workbench, antistatic mat, stacked equipment boxes.
	_part("steel",Vector3(5,.89,2.7),Vector3(2.8,.13,.9))
	_solid(Vector3(5,.46,2.7),Vector3(2.8,.92,.9))
	_part("blue",Vector3(5,.97,2.7),Vector3(1.5,.02,.72))
	for i in range(3):
		_part("black",Vector3(4.05+i*.55,1.09,2.72),Vector3(.42,.23,.45))
	_label("REPAIR / ESD WORKBENCH",Vector3(5,1.95,2.25),.003)
	_label("CAUTION / HIGH NOISE AREA\nHEARING PROTECTION RECOMMENDED",Vector3(0,2.45,9.75),.004,PI)
	_label("DANGER / ELECTRICAL HAZARD\nAUTHORIZED PERSONNEL ONLY",Vector3(0,2.45,-9.73),.004)
	_label("FIRE SUPPRESSION SYSTEM ACTIVE",Vector3(-8.20,2.55,-1.0),.003,PI/2)
	_label("REPORT ALARMS / DO NOT OBSTRUCT AISLES",Vector3(8.20,2.55,-1.0),.003,-PI/2)
	_label("LIFT UP / LOBBY",Vector3(-.9,1.85,5.48),.003)
	_part("blue",Vector3(-.9,.018,5),Vector3(.78,.016,.82))
	for x in [-5.5,0.0,5.5]:
		for z in [-6.5,0.0,6.5]:
			_part("light",Vector3(x,3.22,z),Vector3(2.6,.055,.19))
	for z in [-5.5,0.0,6.5]:
		var lamp:=OmniLight3D.new()
		lamp.position=Vector3(0,2.9,z)
		lamp.light_color=Color("c4dfef")
		lamp.omni_range=10.8
		lamp.light_energy=1.35
		lamp.shadow_enabled=false
		add_child(lamp)
		_lights.append(lamp)
	_flush()
	_build_hum()
	set_occupied(false)

func _rack(at:Vector3,face:float) -> void:
	_racks+=1
	_part("black",at+Vector3(0,1.14,0),Vector3(.92,2.28,1.28))
	_part("steel",at+Vector3(0,2.28,0),Vector3(.94,.06,1.30))
	for side in [-1.0,1.0]:
		_part("steel",at+Vector3(face*.47,1.15,side*.59),Vector3(.035,2.18,.06))
	for u in range(9):
		var y:=.24+u*.225
		_part("steel",at+Vector3(face*.47,y,0),Vector3(.025,.175,1.10))
		_part("black",at+Vector3(face*.488,y,0),Vector3(.018,.065,.78))
		for i in range(5):
			_part("ui" if (i+u)%4!=0 else "rust",at+Vector3(face*.50,y,.43-i*.10),Vector3(.012,.018,.032))
		_part("black",at+Vector3(face*.495,y,-.50),Vector3(.02,.11,.05))

func _build_hum() -> void:
	_hum=GeneratedSFX.emitter(self,"server_fans",Vector3(0,1,-4.9),-18.0,18.0,true)
	if _hum!=null:
		return
	# Quiet original synthetic HVAC fallback until an approved clip exists.
	const RATE=22050
	var pcm:=PackedByteArray()
	pcm.resize(RATE*2)
	for i in range(RATE):
		var t:=float(i)/float(RATE)
		var wave:=sin(TAU*60.0*t)*.19+sin(TAU*120.0*t)*.07+sin(TAU*180.0*t)*.035
		pcm.encode_s16(i*2,int(wave*32767.0))
	var audio:=AudioStreamWAV.new()
	audio.format=AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate=RATE
	audio.loop_mode=AudioStreamWAV.LOOP_FORWARD
	audio.loop_end=RATE
	audio.data=pcm
	_hum=AudioStreamPlayer3D.new()
	_hum.name="ServerRoomHum"
	_hum.stream=audio
	_hum.volume_db=-23.0
	_hum.max_distance=18.0
	_hum.position=Vector3(0,1,-4.9)
	add_child(_hum)

func set_occupied(active:bool) -> void:
	super.set_occupied(active)
	if is_instance_valid(_hum):
		if active and not _hum.playing:
			_hum.play()
		elif not active:
			_hum.stop()

func basement_stats() -> Dictionary:
	return {"racks":_racks,"colliders":_colliders,"parts":_parts,"hum":is_instance_valid(_hum) and _hum.playing}
