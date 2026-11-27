extends TextureRect
## A camera inside an authored car during the collision-safe staged ride.
const Architecture = preload("res://scripts/synaxis_architecture.gd")
const CABIN = preload("res://assets/models/nightgrid/synaxis_architecture/lift_cabin.glb")
const INDICATOR_COLOUR = Color("a8f4dc")
var _view: SubViewport
var _indicator: Label3D

func _ready() -> void:
	name = "CabinPresentation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	var room := Node3D.new()
	_view.add_child(room)
	var model := Architecture.assembly(room, "AuthoredCabin", CABIN, Vector3.ZERO)
	_indicator = Architecture.inscription(model, "↑  14", Vector3(.16,2.373,-1.022), Vector2(.54,.159), INDICATOR_COLOUR)
	_indicator.name = "FloorIndicator"
	Architecture.inscription(model, "SYNAXIS\nCAR 02", Vector3(-.285,2.383,-1.022), Vector2(.310,.145))
	Architecture.inscription(model, "CAR 02", Vector3(.961,1.53,-1.009), Vector2(.165,.055), INDICATOR_COLOUR)
	var legends := ["G", "B1", "2", "3", "4", "5", "14", "•", "‹›", "◉"]
	for i in legends.size():
		var x := .923 if i % 2 == 0 else .998
		var y := 1.40 - floorf(i / 2.0) * .12
		Architecture.inscription(model, legends[i], Vector3(x,y,-1.010), Vector2(.036,.030))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("171e23")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f1e8dc")
	environment.ambient_light_energy = .45
	var camera := Camera3D.new()
	camera.environment = environment
	camera.near = .04
	camera.far = 8.0
	camera.fov = 70
	room.add_child(camera)
	camera.position = Vector3(-.43,1.61,.94)
	camera.look_at(Vector3(.13,1.62,-1.09))
	camera.make_current()
	var light := OmniLight3D.new()
	light.position = Vector3(0,2.46,-.20)
	light.light_color = Color("fff2de")
	light.light_energy = 1.85
	light.omni_range = 3.5
	room.add_child(light)
	texture = _view.get_texture()
	hide()

func start(floor_label: String) -> void:
	var area := get_viewport_rect().size
	var ratio := minf(1.0, 1280.0 / maxf(area.x, area.y))
	_view.size = Vector2i(area * ratio)
	_indicator.text = floor_label
	modulate.a = 0
	show()
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_presentation(floor_label: String, opacity: float) -> void:
	if _indicator.text != floor_label:
		_indicator.text = floor_label
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	modulate.a = opacity

func finish() -> void:
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
