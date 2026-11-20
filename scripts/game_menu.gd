extends CanvasLayer
const MinimapScript = preload("res://scripts/minimap.gd")
const CityFoley = preload("res://scripts/city_foley.gd")
## Keyboard/mouse/controller-friendly menu layer. It remains interactive while
## the 3D SceneTree is paused; all buttons use Godot's built-in focus navigation.
signal action_requested(action: String)
signal settings_changed(settings: Dictionary)

const SAVE_SETTINGS = "user://settings.cfg"
const DEFAULT_SETTINGS = {
	"master_volume": 0.80, "music_volume": 0.65, "ambience_volume": 0.65,
	"sfx_volume": 0.75, "radio_on": true, "mouse_sensitivity": 0.0032,
	"stick_sensitivity": 2.6, "invert_look_y": false,
	"ssr_enabled": true, "glow_enabled": true,
	"ao_enabled": true, "fog_enabled": true,
	"vsync_enabled": true, "show_fps": false
}
const HELP_SECTIONS = [
	{"title": "ON FOOT", "keyboard": "WASD move · Mouse look · Shift sprint · Space jump",
		"pad": "Left stick move · Right stick look · L3 sprint · A jump"},
	{"title": "WORLD ACTIONS", "keyboard": "E vehicle · F bus/train · H enter/exit shop · G interact · R supplies",
		"pad": "Y vehicle · RB bus/train · LB enter/exit shop · X interact · D-pad Down supplies"},
	{"title": "DRIVING / NIGHTGRID FM", "keyboard": "W accelerate · S reverse · A/D steer · Space brake · B radio · N next song",
		"pad": "RT accelerate · LT reverse · Left stick steer · B brake · D-pad Right radio · D-pad Up next"},
	{"title": "SHOP / CONTACTS", "keyboard": "G interact/close · 1 buy/use · 2 contract · Esc close",
		"pad": "X interact/contract · A service · B close · D-pad navigate"},
	{"title": "SYSTEM", "keyboard": "Esc pause · M map · Tab journal · F5 save · F9 load · F6 new world · F3 FPS",
		"pad": "Start pause · View/Select map · B back · Save/Load/New in pause menu"}
]

var screen := "hidden"
var _back_screen := "pause"
var _confirmation_origin := "pause"
var _has_save := false
var _world: Node3D
var _journal_data: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _root: Control
var _screen_nodes: Array[Control] = []
var _buttons: Dictionary = {}
var _first_focus: Control
var _ui_click: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_root = Control.new()
	_root.name = "MenuRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_ui_click = AudioStreamPlayer.new()
	_ui_click.name = "OriginalMenuSelect"
	_ui_click.stream = CityFoley.sound("UI")
	_ui_click.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_click)
	visible = false

func set_world_node(world: Node3D) -> void:
	_world = world

func open_map() -> void:
	_back_screen = "pause"
	_open("map")

func open_journal(context: Dictionary) -> void:
	_journal_data = context.duplicate(true)
	_back_screen = "pause"
	_open("journal")

func set_has_save(value: bool) -> void:
	_has_save = value

func is_open() -> bool:
	return visible and screen != "hidden"

func open_title() -> void:
	_open("title")

func open_pause() -> void:
	_open("pause")

func open_settings() -> void:
	_back_screen = screen if screen == "title" or screen == "pause" else _back_screen
	_open("settings")

func open_controls() -> void:
	_back_screen = screen if screen == "title" or screen == "pause" else _back_screen
	_open("controls")

func confirm_new_game() -> void:
	_confirmation_origin = screen if screen == "title" or screen == "pause" else "pause"
	_open("confirm_new")

func hide_for_game() -> void:
	screen = "hidden"
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func get_buttons() -> Dictionary:
	return _buttons.duplicate()

func get_settings() -> Dictionary:
	return settings.duplicate(true)

func _open(value: String) -> void:
	screen = value
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("game_pause") or event.is_action_pressed("game_back"):
		match screen:
			"settings", "controls", "map", "journal":
				_open(_back_screen)
			"confirm_new":
				_open(_confirmation_origin)
			"pause":
				hide_for_game()
			_:
				pass
		get_viewport().set_input_as_handled()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_SETTINGS) != OK:
		return
	for key in DEFAULT_SETTINGS:
		settings[key] = config.get_value("player", key, DEFAULT_SETTINGS[key])
	_normalize()

func _normalize() -> void:
	settings["master_volume"] = clampf(float(settings.get("master_volume", 0.8)), 0.0, 1.0)
	settings["music_volume"] = clampf(float(settings.get("music_volume", 0.65)), 0.0, 1.0)
	settings["ambience_volume"] = clampf(float(settings.get("ambience_volume", 0.65)), 0.0, 1.0)
	settings["sfx_volume"] = clampf(float(settings.get("sfx_volume", 0.75)), 0.0, 1.0)
	settings["radio_on"] = bool(settings.get("radio_on", true))
	settings["mouse_sensitivity"] = clampf(float(settings.get("mouse_sensitivity", 0.0032)), 0.001, 0.010)
	settings["stick_sensitivity"] = clampf(float(settings.get("stick_sensitivity", 2.6)), 0.5, 5.0)
	for key in ["invert_look_y", "ssr_enabled", "glow_enabled", "ao_enabled", "fog_enabled", "vsync_enabled", "show_fps"]:
		settings[key] = bool(settings.get(key, DEFAULT_SETTINGS[key]))

func _save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("player", key, settings[key])
	config.save(SAVE_SETTINGS)
	settings_changed.emit(get_settings())

func update_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	settings[key] = value
	_normalize()
	_save_settings()

func _render() -> void:
	# queue_free keeps the 3D world untouched; old menu controls are detached
	# from the active input tree immediately before new controls gain focus.
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_first_focus = null
	var shade := ColorRect.new()
	shade.name = "Scrim"
	shade.color = Color(0.025, 0.042, 0.067, 0.93)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	var card := StyleBoxFlat.new()
	card.bg_color = Color("111f31")
	card.border_width_left = 2
	card.border_width_top = 2
	card.border_width_right = 2
	card.border_width_bottom = 2
	card.border_color = Color("63b4be")
	card.corner_radius_top_left = 10
	card.corner_radius_top_right = 10
	card.corner_radius_bottom_left = 10
	card.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", card)
	center.add_child(panel)
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(padding)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 9)
	padding.add_child(col)
	_title(col, "NIGHTGRID  /  AFTERHOURS", 32, Color("8ae9e5"))
	_label(col, "MORROW BAY  •  CITY AFTER DARK", 15, Color("c9ad7f"))
	_divider(col)
	match screen:
		"title":
			_title(col, "YOUR NIGHT. YOUR CITY.", 22, Color("f0dfcd"))
			_label(col, "A persistent noir metropolis, shaped by your choices.", 17, Color("a8b6c9"))
			_button(col, "play", "ENTER MORROW BAY", "play")
			_button(col, "continue", "CONTINUE SAVED GAME", "load", _has_save)
			_button(col, "new", "NEW WORLD / NEW SEED", "new")
			_button(col, "settings", "SETTINGS", "settings")
			_button(col, "controls", "CONTROLS & GAMEPAD", "controls")
			_button(col, "quit", "QUIT TO DESKTOP", "quit")
		"pause":
			_title(col, "PAUSED / SAFE MOMENT", 22, Color("f0dfcd"))
			_button(col, "resume", "RESUME GAME", "resume")
			_button(col, "save", "SAVE WORLD  •  SLOT 1", "save")
			_button(col, "map", "CITY MAP / DISTRICTS", "map")
			_button(col, "journal", "JOURNAL / OBJECTIVES", "journal")
			_button(col, "load", "LOAD SAVED WORLD", "load", _has_save)
			_button(col, "new", "NEW WORLD / NEW SEED", "new")
			_button(col, "settings", "SETTINGS", "settings")
			_button(col, "controls", "CONTROLS & GAMEPAD", "controls")
			_button(col, "title", "TITLE SCREEN", "title")
			_button(col, "quit", "QUIT TO DESKTOP", "quit")
		"settings":
			_title(col, "SETTINGS / YOUR RIG", 22, Color("f0dfcd"))
			_slider(col, "MASTER VOLUME", "master_volume", 0.0, 1.0, 0.05)
			_slider(col, "NIGHTGRID FM / MUSIC VOLUME", "music_volume", 0.0, 1.0, 0.05)
			_slider(col, "CITY AMBIENCE", "ambience_volume", 0.0, 1.0, 0.05)
			_slider(col, "FOOTSTEPS / INTERACTIONS / UI", "sfx_volume", 0.0, 1.0, 0.05)
			_check(col, "CAR RADIO ENABLED BY DEFAULT", "radio_on")
			_slider(col, "MOUSE LOOK", "mouse_sensitivity", 0.001, 0.010, 0.0002)
			_slider(col, "GAMEPAD LOOK", "stick_sensitivity", 0.5, 5.0, 0.1)
			_check(col, "INVERT LOOK Y", "invert_look_y")
			_check(col, "SCREEN-SPACE REFLECTIONS", "ssr_enabled")
			_check(col, "NEON BLOOM", "glow_enabled")
			_check(col, "CONTACT SHADOWS / AO", "ao_enabled")
			_check(col, "ATMOSPHERIC DISTANCE HAZE", "fog_enabled")
			_check(col, "VERTICAL SYNC", "vsync_enabled")
			_check(col, "SHOW LIVE FPS & CHUNK METRICS", "show_fps")
			_label(col, "Changes save automatically. Toggle SSR, AO, haze and bloom to profile GPU cost.", 14, Color("90a7ba"))
			_button(col, "back", "BACK", "back")
		"controls":
			_title(col, "CONTROLS / KEYBOARD + PAD", 22, Color("f0dfcd"))
			for section in HELP_SECTIONS:
				_label(col, str(section["title"]), 17, Color("87dcd8"))
				_label(col, "KEYS   " + str(section["keyboard"]), 14, Color("e2dfd6"))
				_label(col, "PAD    " + str(section["pad"]), 14, Color("b8cade"))
				_divider(col)
			_label(col, "Xbox / XInput layout. Controller support depends on Godot/OS device detection.", 14, Color("9db5c7"))
			_button(col, "back", "BACK", "back")
		"journal":
			_title(col, "JOURNAL / NIGHT-SHIFT LEDGER", 22, Color("f0dfcd"))
			_label(col, "CURRENT DISTRICT  " + str(_journal_data.get("district", "MORROW BAY")), 18, Color("8ad9d6"))
			_label(col, "LOCAL TIME  " + str(_journal_data.get("clock", "--:--")) +
				"  |  WORLD SEED  " + str(_journal_data.get("seed", "-")), 16, Color("bdcddd"))
			_divider(col)
			_title(col, "ACTIVE DELIVERIES", 18, Color("f0d1a0"))
			_label(col, str(_journal_data.get("main_objective", "Explore Morrow Bay")),
				17, Color("e1ebef"))
			_label(col, str(_journal_data.get("venue_job", "No local contacts")),
				16, Color("bfced5"))
			_label(col, str(_journal_data.get("civic_job", "No freight work")),
				16, Color("bfced5"))
			_divider(col)
			_title(col, "INVENTORY / STATUS", 18, Color("f0d1a0"))
			_label(col, "CASH  $%d     HEALTH  %d     HEAT  %.1f" % [
				int(_journal_data.get("cash", 0)), int(_journal_data.get("health", 100)),
				float(_journal_data.get("heat", 0.0))], 17, Color("e1ebef"))
			_label(col, "SUPPLY PACKS  %d    COURIER DELIVERIES  %d" % [
				int(_journal_data.get("supplies", 0)), int(_journal_data.get("deliveries", 0))],
				17, Color("c4d6da"))
			_label(col, "LOCAL JOBS COMPLETE  %d     CIVIC JOBS COMPLETE  %d" % [
				int(_journal_data.get("venue_completed", 0)),
				int(_journal_data.get("civic_completed", 0))], 16, Color("c4d6da"))
			_label(col, "ARCHIVES VISITED  %d     LIVE STREET BLOCKS  %d" % [
				int(_journal_data.get("archives", 0)), int(_journal_data.get("loaded_blocks", 0))],
				16, Color("c4d6da"))
			_button(col, "back", "BACK TO PAUSE", "back")
		"map":
			_title(col, "MORROW BAY / CITY ATLAS", 22, Color("f0dfcd"))
			_label(col, "Player • quests • shops • bus stops (gold) • M-Line (cyan) • police", 15, Color("adc8d2"))
			var atlas := Control.new()
			atlas.name = "WorldMapView"
			atlas.custom_minimum_size = Vector2(480.0, 480.0)
			atlas.set_script(MinimapScript)
			atlas.set("world_node", _world)
			col.add_child(atlas)
			_label(col, "Map addresses and active quests remain stable in the saved world.", 14, Color("a2b5bc"))
			_button(col, "back", "BACK TO PAUSE", "back")
		"confirm_new":
			_title(col, "START ANOTHER WORLD?", 24, Color("f0cdab"))
			_label(col, "The current unsaved session will be discarded. Your last saved slot will remain intact until you save the new world.", 17, Color("cbd8e3"))
			_button(col, "confirm_new", "YES — NEW CITY SEED", "confirm_new")
			_button(col, "cancel", "CANCEL", "cancel_new")
	_divider(col)
	_label(col, "WASD / mouse  •  Xbox controller  •  Start / Esc pause  •  B back", 14, Color("94abb8"))
	if _first_focus != null:
		_first_focus.call_deferred("grab_focus")

func _title(parent: VBoxContainer, value: String, font_size: int, tint: Color) -> void:
	_label(parent, value, font_size, tint, true)

func _label(parent: VBoxContainer, value: String, font_size: int, tint: Color, bold: bool = false) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	if bold:
		label.add_theme_constant_override("outline_size", 1)
	parent.add_child(label)

func _divider(parent: VBoxContainer) -> void:
	var line := HSeparator.new()
	parent.add_child(line)

func _button(parent: VBoxContainer, key: String, caption: String, action: String, enabled: bool = true) -> void:
	var button := Button.new()
	button.name = "Menu_" + key
	button.text = caption
	button.custom_minimum_size = Vector2(470.0, 36.0)
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func() -> void: _choice(action))
	parent.add_child(button)
	_buttons[key] = button
	if _first_focus == null and enabled:
		_first_focus = button

func _slider(parent: VBoxContainer, caption: String, key: String, lo: float, hi: float, step: float) -> void:
	_label(parent, caption, 15, Color("b2dce0"))
	var slider := HSlider.new()
	slider.name = "Setting_" + key
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = float(settings[key])
	slider.custom_minimum_size = Vector2(470.0, 24.0)
	slider.focus_mode = Control.FOCUS_ALL
	parent.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void: update_setting(key, value))
	if _first_focus == null:
		_first_focus = slider

func _check(parent: VBoxContainer, caption: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.name = "Setting_" + key
	toggle.text = caption
	toggle.button_pressed = bool(settings[key])
	toggle.focus_mode = Control.FOCUS_ALL
	parent.add_child(toggle)
	toggle.toggled.connect(func(value: bool) -> void: update_setting(key, value))
	if _first_focus == null:
		_first_focus = toggle

func _choice(action: String) -> void:
	if is_instance_valid(_ui_click):
		_ui_click.volume_db = -80.0 if float(settings.get("sfx_volume", 0.75)) <= 0.0 else linear_to_db(float(settings.get("sfx_volume", 0.75))) - 11.0
		_ui_click.play()
	match action:
		"play", "resume":
			hide_for_game()
		"settings":
			open_settings()
		"controls":
			open_controls()
		"map":
			open_map()
		"journal":
			action_requested.emit("journal")
		"back":
			_open(_back_screen)
		"new":
			confirm_new_game()
		"cancel_new":
			_open(_confirmation_origin)
		"confirm_new":
			hide_for_game()
			action_requested.emit("new")
		"load":
			if _has_save:
				hide_for_game()
				action_requested.emit("load")
		"save":
			action_requested.emit("save")
			_open("pause")
		"title":
			open_title()
		"quit":
			get_tree().quit()
