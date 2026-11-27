extends CanvasLayer
## Screen-space elevator doors conceal a collision-safe floor change.
## This is a staged transition, not a simulated moving physics cabin.
const DOOR_TIME=.42
const GeneratedAudio=preload("res://scripts/synaxis_generated_audio.gd")
const AudioMix=preload("res://scripts/audio_mix.gd")
var elapsed:=0.0
var duration:=0.0
var transferred:=false
var active:=false
var _left:ColorRect
var _right:ColorRect
var _display:Label
var _floor_display:Label
var _from_floor:=0
var _to_floor:=0
var _motor:AudioStreamPlayer

func _ready() -> void:
	layer=7
	_left=_panel()
	_right=_panel()
	_left.anchor_left=0.0
	_left.anchor_right=.5
	_right.anchor_left=.5
	_right.anchor_right=1.0
	for panel in [_left,_right]:
		panel.anchor_bottom=1.0
		var seam:=ColorRect.new()
		seam.color=Color("88959a")
		seam.anchor_top=0.0
		seam.anchor_bottom=1.0
		seam.anchor_left=1.0 if panel==_left else 0.0
		seam.anchor_right=seam.anchor_left
		seam.offset_left=-3.0 if panel==_left else 0.0
		seam.offset_right=0.0 if panel==_left else 3.0
		panel.add_child(seam)
	_display=Label.new()
	_display.anchor_left=.15
	_display.anchor_right=.85
	_display.anchor_top=.10
	_display.anchor_bottom=.19
	_display.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_display.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_display.add_theme_color_override("font_color",Color("e5c78e"))
	_display.add_theme_font_size_override("font_size",24)
	add_child(_display)
	_floor_display=Label.new()
	_floor_display.anchor_left=.32
	_floor_display.anchor_right=.68
	_floor_display.anchor_top=.21
	_floor_display.anchor_bottom=.30
	_floor_display.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_floor_display.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_floor_display.add_theme_font_size_override("font_size",38)
	_floor_display.add_theme_color_override("font_color",Color("b7e0d7"))
	add_child(_floor_display)
	var motor_stream:=GeneratedAudio.stream("lift_motor",true)
	if motor_stream!=null:
		AudioMix.ensure()
		_motor=AudioStreamPlayer.new()
		_motor.name="CabinMotor"
		_motor.stream=motor_stream
		_motor.bus=AudioMix.ROOM_EFFECTS
		_motor.volume_db=-22.0
		add_child(_motor)
	hide()

func _panel() -> ColorRect:
	var panel:=ColorRect.new()
	panel.color=Color("414b50")
	# Static brushed-metal strips move with each panel.
	for i in range(12):
		var strip:=ColorRect.new()
		strip.color=Color(.72,.77,.79,.035 if i%2==0 else .075)
		strip.anchor_left=float(i)/12.0
		strip.anchor_right=float(i+1)/12.0
		strip.anchor_bottom=1.0
		strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
		panel.add_child(strip)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func begin(from:int,to:int,title:String) -> void:
	elapsed=0.0
	transferred=false
	active=true
	_from_floor=from
	_to_floor=to
	# Express ride is perceptibly longer, not nine individual floor loads.
	duration=2.10 if absi(to-from)>1 else 1.35
	_display.text="SYNAXIS  /  LIFT   →   "+title
	show()
	_apply(0.0)

func _apply(closed:float) -> void:
	var half:=get_viewport().get_visible_rect().size.x*.5
	var offset:=half*(1.0-closed)
	_left.offset_left=-offset
	_left.offset_right=-offset
	_right.offset_left=offset
	_right.offset_right=offset
	_display.modulate.a=smoothstep(.6,1.0,closed)
	_floor_display.modulate.a=_display.modulate.a
	var fraction:=clampf((elapsed-DOOR_TIME)/maxf(.01,duration-2.0*DOOR_TIME),0.0,1.0)
	var floor_number:=roundi(lerpf(float(_from_floor),float(_to_floor),fraction))
	var floor_text:="B%d" % absi(floor_number) if floor_number<0 else ("G" if floor_number==0 else str(floor_number+1))
	_floor_display.text=("↑  " if _to_floor>_from_floor else "↓  ")+floor_text

## True once when the destination doors begin to open.
func advance(delta:float) -> bool:
	if not active:
		return false
	var opening_time:=duration-DOOR_TIME
	var was_opening:=elapsed>=opening_time
	elapsed=minf(duration,elapsed+maxf(0.0,delta))
	var closed:=smoothstep(0.0,DOOR_TIME,elapsed)*(1.0-smoothstep(opening_time,duration,elapsed))
	_apply(closed)
	var opening:=elapsed>=opening_time
	if is_instance_valid(_motor):
		if elapsed>=DOOR_TIME and not opening and not _motor.playing:
			_motor.play()
		elif opening and _motor.playing:
			_motor.stop()
	return opening and not was_opening

func transfer_ready() -> bool:
	return active and not transferred and elapsed>=DOOR_TIME

func complete() -> bool:
	return active and elapsed>=duration

func reset() -> void:
	if is_instance_valid(_motor):
		_motor.stop()
	active=false
	transferred=false
	hide()
