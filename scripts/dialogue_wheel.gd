extends Control
## Original, compact screen-space intent selector. Native Buttons preserve
## accessible focus, mouse hit testing and explicit confirmation.
const Ui = preload("res://scripts/ui_style.gd")
const ORDER = ["left", "up", "right", "down"]
const DIRECTIONS = {"left":Vector2.LEFT, "right":Vector2.RIGHT,
	"up":Vector2.UP, "down":Vector2.DOWN}
var _choices: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(0, 206)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)

func register_choice(slot: String, button: Button) -> void:
	if not DIRECTIONS.has(slot) or _choices.has(slot):
		return
	_choices[slot] = button
	button.focus_entered.connect(queue_redraw)
	button.focus_exited.connect(queue_redraw)
	_layout()

func _layout() -> void:
	var center := size * .5
	var width := maxf(100, minf(180, (size.x-64)*.5))
	var height := 44.0
	for slot in _choices:
		var button := _choices[slot] as Button
		var direction: Vector2 = DIRECTIONS[slot]
		button.custom_minimum_size = Vector2.ZERO
		button.size = Vector2(width,height)
		var distance := width*.5+30 if direction.x != 0 else 72.0
		button.position = center + direction*distance - button.size*.5
	queue_redraw()

func wire_directions() -> void:
	for slot in _choices:
		var button := _choices[slot] as Button
		# The arrow toward a slot selects it; absent directions retain the
		# menu's existing focus chain. Tab always retains linear traversal.
		for direction in ORDER:
			if slot == direction or not _choices.has(direction):
				continue
			var target := _choices[direction] as Button
			var path := button.get_path_to(target)
			match direction:
				"left": button.focus_neighbor_left = path
				"right": button.focus_neighbor_right = path
				"up": button.focus_neighbor_top = path
				"down": button.focus_neighbor_bottom = path

func _draw() -> void:
	var center := size*.5
	draw_circle(center,24,Color("182832"),true,-1,true)
	draw_arc(center,24,0,TAU,64,Color("536b74"),1.2,true)
	for slot in _choices:
		var direction: Vector2 = DIRECTIONS[slot]
		var button := _choices[slot] as Button
		var tint := Ui.ACCENT if button.has_focus() else Color("536b74")
		var distance := (button.position+button.size*.5-center).length()
		var edge := button.size.x*.5 if direction.x != 0 else button.size.y*.5
		draw_line(center+direction*24,center+direction*maxf(24,distance-edge-3),tint,1.5,true)
	var font := ThemeDB.fallback_font
	var extent := font.get_string_size("INTENT",HORIZONTAL_ALIGNMENT_LEFT,-1,9)
	draw_string(font,center+Vector2(-extent.x*.5,3),"INTENT",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Ui.MUTED)
