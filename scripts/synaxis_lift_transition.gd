extends CanvasLayer
## Screen-space elevator doors conceal a collision-safe floor change.
## This is a staged transition, not a simulated moving physics cabin.
const DOOR_TIME=.42
var elapsed:=0.0
var duration:=0.0
var transferred:=false
var active:=false
var _left:ColorRect
var _right:ColorRect
var _display:Label

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
	hide()

func _panel() -> ColorRect:
	var panel:=ColorRect.new()
	panel.color=Color("28343c")
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func begin(from:int,to:int,title:String) -> void:
	elapsed=0.0
	transferred=false
	active=true
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

func advance(delta:float) -> void:
	elapsed=minf(duration,elapsed+maxf(0.0,delta))
	var closed:=smoothstep(0.0,DOOR_TIME,elapsed)*(1.0-smoothstep(duration-DOOR_TIME,duration,elapsed))
	_apply(closed)

func transfer_ready() -> bool:
	return active and not transferred and elapsed>=DOOR_TIME

func complete() -> bool:
	return active and elapsed>=duration

func reset() -> void:
	active=false
	transferred=false
	hide()
