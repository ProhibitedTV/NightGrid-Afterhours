extends CanvasLayer
const AudioMix = preload("res://scripts/audio_mix.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
const CityFoley = preload("res://scripts/city_foley.gd")
const Ui = preload("res://scripts/ui_style.gd")
const Opening = preload("res://scripts/opening_story.gd")
const Consumables = preload("res://scripts/consumables.gd")
## Keyboard/mouse/controller-friendly menu layer. It remains interactive while
## the 3D SceneTree is paused; all buttons use Godot's built-in focus navigation.
signal action_requested(action: String)
signal settings_changed(settings: Dictionary)

const SAVE_SETTINGS = "user://settings.cfg"
const DEFAULT_SETTINGS = {
	"master_volume": 0.80, "music_volume": 0.65, "ambience_volume": 0.65,
	"sfx_volume": 0.75, "dialogue_volume": 0.82, "radio_on": true, "mouse_sensitivity": 0.0032,
	"stick_sensitivity": 2.6, "invert_look_y": false,
	"ssr_enabled": true, "glow_enabled": true,
	"ao_enabled": true, "fog_enabled": true,
	"vsync_enabled": true, "show_fps": false,
	"show_control_hints": true, "show_hud_inventory": true
}
const HELP_SECTIONS = [
	{"title": "ON FOOT", "keyboard": "WASD move · Mouse look · Shift sprint · Space jump",
		"pad": "Left stick move · Right stick look · L3 sprint · A jump"},
	{"title": "WEAPONS / ON FOOT", "keyboard": "Q cycle · C equipment wheel · Hold RMB aim · LMB fire · Z reload",
		"pad": "D-pad Left cycle · R3 equipment wheel · LT aim · RT fire · D-pad Up reload"},
	{"title": "WORLD ACTIONS", "keyboard": "E vehicle · F bus/train · H enter/exit shop · G interact · R supplies",
		"pad": "Y vehicle · RB bus/train · LB enter/exit shop · X interact · D-pad Down supplies"},
	{"title": "DRIVING / NIGHTGRID FM", "keyboard": "W accelerate · S reverse · A/D steer · Space brake · B radio · N next song · V Cinder view",
		"pad": "RT accelerate · LT reverse · Left stick steer · B brake · D-pad Right radio · D-pad Up next · D-pad Left Cinder view"},
	{"title": "SHOP / CONTACTS", "keyboard": "G interact/close · 1 buy/use · 2 contract · Esc close",
		"pad": "X interact/contract · A service · B close · D-pad navigate"},
	{"title": "SYSTEM", "keyboard": "Esc pause · M map · Tab journal · F5 save at hotel · F9 load · F6 new world · F3 FPS · F8 CSV · F10 photo",
		"pad": "Start pause · View/Select map · B back · Save/Load/New in pause menu"}
]

var screen := "hidden"
var _back_screen := "pause"
var _confirmation_origin := "pause"
var _has_save := false
var _save_feedback := ""
var _world: Node3D
var _journal_data: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _root: Control
var _screen_nodes: Array[Control] = []
var _buttons: Dictionary = {}
var _first_focus: Control
var _ui_click: AudioStreamPlayer
var _body_scroll: ScrollContainer
var _body_col: VBoxContainer
var _menu_panel: PanelContainer
var _focus_order: Array[Control] = []
var _last_focus: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_load_settings()
	_root = Control.new()
	_root.name = "MenuRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = Ui.make_theme()
	add_child(_root)
	get_viewport().size_changed.connect(_fit_menu)
	_ui_click = AudioStreamPlayer.new()
	_ui_click.name = "OriginalMenuSelect"
	AudioMix.ensure()
	_ui_click.bus = AudioMix.UI
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

func open_inventory(context: Dictionary) -> void:
	_journal_data = context.duplicate(true)
	_back_screen = "pause"
	_open("inventory")

func set_has_save(value: bool) -> void:
	_has_save = value

func set_save_feedback(value: String) -> void:
	_save_feedback = value

func is_open() -> bool:
	return visible and screen != "hidden"

func open_title() -> void:
	_open("title")

func open_opening() -> void:
	_open("opening")

func open_pause() -> void:
	_save_feedback = ""
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
	if is_instance_valid(_world):
		_world.call("suspend_weapon")
	var previous := get_viewport().gui_get_focus_owner()
	if is_instance_valid(previous) and _root.is_ancestor_of(previous):
		_last_focus[screen] = str(previous.name)
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
			"settings", "controls", "map", "journal", "inventory":
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
	settings["dialogue_volume"] = clampf(float(settings.get("dialogue_volume", 0.82)), 0.0, 1.0)
	settings["radio_on"] = bool(settings.get("radio_on", true))
	settings["mouse_sensitivity"] = clampf(float(settings.get("mouse_sensitivity", 0.0032)), 0.001, 0.010)
	settings["stick_sensitivity"] = clampf(float(settings.get("stick_sensitivity", 2.6)), 0.5, 5.0)
	for key in ["invert_look_y", "ssr_enabled", "glow_enabled", "ao_enabled", "fog_enabled", "vsync_enabled", "show_fps", "show_control_hints", "show_hud_inventory"]:
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
	_focus_order.clear()
	_first_focus = null
	var shade := ColorRect.new()
	shade.name = "Scrim"
	shade.color = Color(0.028, 0.045, 0.060, 0.94 if screen == "title" or screen == "opening" else 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	_menu_panel = panel
	panel.custom_minimum_size = Vector2(760.0, 0.0)
	panel.add_theme_stylebox_override("panel", Ui.card(0.97, 22))
	center.add_child(panel)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	panel.add_child(shell)
	_label(shell, "NIGHTGRID  /  MORROW BAY", 14, Ui.AMBER)
	_title(shell, "AFTERHOURS" if screen == "title" else {"pause": "Paused", "settings": "Settings", "controls": "Controls", "map": "City atlas", "journal": "Journal", "inventory": "Player & inventory", "confirm_new": "New session", "opening": "People operations"}.get(screen, "Afterhours"), 34, Ui.TEXT)
	_divider(shell)
	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "MenuScroll"
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_body_scroll.follow_focus = true
	shell.add_child(_body_scroll)
	var col := VBoxContainer.new()
	col.name = "MenuContent"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 9)
	_body_scroll.add_child(col)
	_body_col = col
	match screen:
		"title":
			_title(col, "YOUR NIGHT. YOUR CITY.", 22, Color("f0dfcd"))
			_label(col, "A persistent noir metropolis, shaped by your choices.", 17, Color("a8b6c9"))
			if _has_save:
				_button(col, "continue", "CONTINUE SAVED GAME", "load")
				_button(col, "play", "ENTER CURRENT SESSION", "play")
			else:
				_button(col, "play", "BEGIN YOUR NEXT CHAPTER", "play")
				_button(col, "continue", "CONTINUE  •  NO SAVE FOUND", "load", false)
			_button(col, "new", "NEW WORLD / NEW SEED", "new")
			_button(col, "settings", "SETTINGS", "settings")
			_button(col, "controls", "CONTROLS & GAMEPAD", "controls")
			_button(col, "quit", "QUIT TO DESKTOP", "quit")
		"opening":
			_title(col, Opening.EMPLOYER + " / PEOPLE OPERATIONS", 21, Ui.AMBER)
			_title(col, Opening.HEADLINE, 29, Color("e3a39b"))
			_label(col, Opening.NOTICE, 17, Color("cbd8e3"))
			_divider(col)
			_label(col, Opening.OFFER, 17, Ui.TEXT)
			_button(col, "opening_accept", "ACCEPT TERMS / START DELIVERING", "opening_accept")
		"pause":
			_button(col, "resume", "Resume game", "resume")
			_section_heading(col, "WORLD")
			_button(col, "map", "City atlas", "map")
			_button(col, "journal", "Mission journal", "journal")
			_button(col, "inventory", "Player & inventory", "inventory")
			_section_heading(col, "SESSION")
			var save_info: Dictionary = _world.call("save_availability") if is_instance_valid(_world) else {"allowed": false, "reason": "Visit Lantern Court to save."}
			var can_save := bool(save_info["allowed"])
			_button(col, "save", "SAVE PROGRESS" if can_save else "SAVE PROGRESS  /  UNAVAILABLE", "save", can_save)
			_label(col, _save_feedback if not _save_feedback.is_empty() else str(save_info["reason"]), 15, Ui.ACCENT if can_save else Ui.MUTED)
			if not can_save:
				_button(col, "save_waypoint", "ROUTE TO LANTERN COURT", "save_waypoint")
			_button(col, "load", "Load saved game", "load", _has_save)
			_button(col, "new", "New session", "new")
			_section_heading(col, "SYSTEM")
			_button(col, "settings", "Settings", "settings")
			_button(col, "controls", "Controls & gamepad", "controls")
			_button(col, "title", "Title screen", "title")
			_button(col, "quit", "Quit to desktop", "quit")
		"settings":
			_label(col, "AUDIO", 16, Ui.AMBER)
			_slider(col, "MASTER VOLUME", "master_volume", 0.0, 1.0, 0.05)
			_slider(col, "NIGHTGRID FM / MUSIC VOLUME", "music_volume", 0.0, 1.0, 0.05)
			_slider(col, "CITY AMBIENCE", "ambience_volume", 0.0, 1.0, 0.05)
			_slider(col, "FOOTSTEPS / INTERACTIONS / UI", "sfx_volume", 0.0, 1.0, 0.05)
			_slider(col, "DISPATCH DIALOGUE", "dialogue_volume", 0.0, 1.0, 0.05)
			_check(col, "CAR RADIO ENABLED BY DEFAULT", "radio_on")
			_divider(col)
			_label(col, "CONTROLS", 16, Ui.AMBER)
			_slider(col, "MOUSE LOOK", "mouse_sensitivity", 0.001, 0.010, 0.0002)
			_slider(col, "GAMEPAD LOOK", "stick_sensitivity", 0.5, 5.0, 0.1)
			_check(col, "INVERT LOOK Y", "invert_look_y")
			_divider(col)
			_label(col, "INTERFACE", 16, Ui.AMBER)
			_check(col, "SHOW GENERAL CONTROL REMINDERS", "show_control_hints")
			_check(col, "SHOW INVENTORY COUNTS IN HUD", "show_hud_inventory")
			_label(col, "Nearby actions, navigation and health remain visible. Review controls and status from the pause menu.", 14, Ui.MUTED)
			_divider(col)
			_label(col, "DISPLAY & PERFORMANCE", 16, Ui.AMBER)
			_check(col, "SCREEN-SPACE REFLECTIONS", "ssr_enabled")
			_check(col, "NEON BLOOM", "glow_enabled")
			_check(col, "CONTACT SHADOWS / AO", "ao_enabled")
			_check(col, "ATMOSPHERIC DISTANCE HAZE", "fog_enabled")
			_check(col, "VERTICAL SYNC", "vsync_enabled")
			_check(col, "SHOW LIVE FPS & CHUNK METRICS", "show_fps")
			_label(col, "Changes save automatically. Toggle SSR, AO, haze and bloom to profile GPU cost.", 14, Color("90a7ba"))
			_button(col, "back", "BACK", "back")
		"controls":
			for section in HELP_SECTIONS:
				_label(col, str(section["title"]), 17, Color("87dcd8"))
				_label(col, "KEYS   " + str(section["keyboard"]), 14, Color("e2dfd6"))
				_label(col, "PAD    " + str(section["pad"]), 14, Color("b8cade"))
				_divider(col)
			_label(col, "Xbox / XInput layout. Controller support depends on Godot/OS device detection.", 14, Color("9db5c7"))
			_button(col, "back", "BACK", "back")
		"journal":
			_label(col, "CURRENT DISTRICT  " + str(_journal_data.get("district", "MORROW BAY")), 18, Color("8ad9d6"))
			_label(col, "LOCAL TIME  " + str(_journal_data.get("clock", "--:--")), 16, Ui.MUTED)
			_divider(col)
			_title(col, "ACTIVE DELIVERIES", 18, Color("f0d1a0"))
			if not str(_journal_data.get("opening_goal","")).is_empty():
				_label(col, str(_journal_data["opening_goal"]), 17, Ui.AMBER)
			_label(col, str(_journal_data.get("main_objective", "Explore Morrow Bay")),
				17, Color("e1ebef"))
			_button(col, "restart_courier", "ABANDON PACKAGE / RETRY ROUTE", "restart_courier", bool(_journal_data.get("courier_can_restart", false)))
			_label(col, str(_journal_data.get("story_objective", "")), 16, Ui.ACCENT)
			if bool(_journal_data.get("story_can_navigate", false)):
				_button(col, "story_waypoint", "SET WAYPOINT TO CONTACT OBJECTIVE", "story_waypoint")
			if bool(_journal_data.get("story_can_abandon", false)):
				_button(col, "abandon_story", "ABANDON CONTACT MISSION", "abandon_story")
			_label(col, str(_journal_data.get("venue_job", "No local contacts")),
				16, Color("bfced5"))
			_label(col, str(_journal_data.get("civic_job", "No freight work")),
				16, Color("bfced5"))
			_section_heading(col, "COMPLETED WORK")
			_value_row(col, "Courier deliveries", str(_journal_data.get("deliveries", 0)))
			_value_row(col, "Local contracts", str(_journal_data.get("venue_completed", 0)))
			_value_row(col, "Civic contracts", str(_journal_data.get("civic_completed", 0)))
			_value_row(col, "Archives visited", str(_journal_data.get("archives", 0)))
			_button(col, "inventory", "Player & inventory", "inventory")
			_button(col, "back", "Back to pause", "back")
		"inventory":
			_render_inventory(col)
			_button(col, "journal", "Mission journal", "journal")
			_button(col, "back", "Back to pause", "back")
		"map":
			_label(col, "Player • quests • shops • buses (gold) • M-Line (cyan) • police stations (blue shields)", 15, Color("adc8d2"))
			var atlas := Control.new()
			atlas.name = "WorldMapView"
			atlas.custom_minimum_size = Vector2(500.0, 500.0)
			atlas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			atlas.set_script(MinimapScript)
			atlas.set("world_node", _world)
			atlas.set("interactive", true)
			col.add_child(atlas)
			_focus_order.append(atlas)
			_first_focus = atlas
			var destination := Label.new()
			destination.name = "AtlasDestination"
			destination.add_theme_color_override("font_color", Color("c9a8ff"))
			destination.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(destination)
			var refresh_destination := func() -> void:
				destination.text = str(_world.call("navigation_text")) if is_instance_valid(_world) else "No waypoint"
			atlas.connect("destination_changed", refresh_destination)
			refresh_destination.call()
			_label(col, "Click to pin  •  Arrows / D-pad move  •  Enter / A pin  •  Right click / X clear", 15, Ui.TEXT)
			_label(col, "Purple = waypoint / route. Dotted purple = off-street access. Orange dashed = closed street. Esc / B back.", 14, Ui.MUTED)
			_button(col, "back", "BACK TO PAUSE", "back")
		"confirm_new":
			_title(col, "START ANOTHER WORLD?", 24, Color("f0cdab"))
			_label(col, "The current unsaved session will be discarded. Your last saved slot will remain intact until you save the new world.", 17, Color("cbd8e3"))
			_button(col, "cancel", "KEEP CURRENT SESSION", "cancel_new")
			_button(col, "confirm_new", "DISCARD SESSION / NEW WORLD", "confirm_new")
	_divider(shell)
	_label(shell, "↑ ↓  Navigate   •   Enter / A  Select   •   Esc / B  Back", 16, Ui.MUTED)
	_wire_focus()
	_fit_menu.call_deferred()
	if screen != "confirm_new":
		for item in _focus_order:
			if str(item.name) == str(_last_focus.get(screen, "")):
				_first_focus = item
				break
	_focus_current.call_deferred()

func _focus_current() -> void:
	if visible and is_instance_valid(_first_focus) and _first_focus.is_inside_tree():
		_first_focus.grab_focus()

func _fit_menu() -> void:
	if not is_instance_valid(_body_scroll) or not is_instance_valid(_body_col):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if is_instance_valid(_menu_panel):
		_menu_panel.custom_minimum_size.x = minf(840.0 if screen == "inventory" or screen == "journal" else 760.0, maxf(320.0, viewport_size.x - 64.0))
	_body_scroll.custom_minimum_size.y = minf(_body_col.get_combined_minimum_size().y, maxf(140.0, viewport_size.y - 200.0))

func _wire_focus() -> void:
	# Explicit vertical order avoids focus jumping between unrelated rows.
	# Sliders retain native left/right adjustment; the scroll follows focus.
	for i in range(_focus_order.size()):
		var item := _focus_order[i]
		var prev := _focus_order[posmod(i - 1, _focus_order.size())]
		var next := _focus_order[(i + 1) % _focus_order.size()]
		item.focus_neighbor_top = item.get_path_to(prev)
		item.focus_neighbor_bottom = item.get_path_to(next)
		item.focus_previous = item.get_path_to(prev)
		item.focus_next = item.get_path_to(next)

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

func _section_heading(parent: VBoxContainer, caption: String) -> void:
	_divider(parent)
	_label(parent, caption, 14, Ui.AMBER)

func _value_row(parent: VBoxContainer, caption: String, value: String, tint: Color = Ui.TEXT, texture: Texture2D = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", Ui.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var amount := Label.new()
	amount.text = value
	amount.add_theme_color_override("font_color", tint)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)

func _inventory_meter(parent: VBoxContainer, caption: String, value: float, tint: Color) -> void:
	_value_row(parent, caption, "%d / 100" % ceili(value), tint)
	var meter := ProgressBar.new()
	meter.max_value = 100
	meter.value = value
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.custom_minimum_size.y = 7
	meter.add_theme_stylebox_override("background", Ui.meter(Color("29363e")))
	meter.add_theme_stylebox_override("fill", Ui.meter(tint))
	parent.add_child(meter)

func _render_inventory(col: VBoxContainer) -> void:
	_section_heading(col, "VITALS & WALLET")
	_inventory_meter(col, "Health", float(_journal_data.get("health", 100)), Ui.ACCENT)
	_inventory_meter(col, "Stamina", float(_journal_data.get("stamina", 100)), Ui.AMBER)
	_value_row(col, "Cash", "$%d" % int(_journal_data.get("cash", 0)), Ui.ACCENT)
	_value_row(col, "Bitcoin wallet", "%d sats" % int(_journal_data.get("bitcoin_sats", 0)))
	_value_row(col, "Police heat", "%.1f" % float(_journal_data.get("heat", 0)))
	_section_heading(col, "CARRIED SUPPLIES")
	var carried: Dictionary = _journal_data.get("consumables", {})
	_value_row(col, "Pack capacity", "%d / %d" % [Consumables.count(carried), Consumables.MAX_ITEMS])
	_value_row(col, "Ration packs", str(_journal_data.get("supplies", 0)))
	for id in Consumables.ITEMS:
		var quantity := int(carried.get(id, 0))
		if quantity > 0:
			var item: Dictionary = Consumables.ITEMS[id]
			_value_row(col, str(item["name"]), "×%d" % quantity, Ui.TEXT, Consumables.PRODUCT_ICONS[id])
	if Consumables.count(carried) == 0:
		_label(col, "No portable food or drinks.", 15, Ui.MUTED)
	_label(col, "Use R / D-pad Down while on foot to consume a useful supply.", 14, Ui.MUTED)
	_section_heading(col, "EQUIPMENT & CONDITIONING")
	_label(col, str(_journal_data.get("weapons", "No equipment data")), 16, Ui.TEXT)
	_label(col, str(_journal_data.get("outfit", "")), 16, Ui.TEXT)
	_label(col, str(_journal_data.get("conditioning", "")), 16, Ui.ACCENT)
	_section_heading(col, "PROPERTY & VEHICLES")
	_label(col, str(_journal_data.get("home_text", "")), 16, Ui.TEXT)
	_button(col, "save_waypoint", "Route to Lantern Court / save point", "save_waypoint")
	if bool(_journal_data.get("home_owned", false)):
		_label(col, str(_journal_data.get("garage_text", "")), 16, Ui.TEXT)
		_button(col, "garage_waypoint", "Route to garage", "garage_waypoint")
	_label(col, str(_journal_data.get("owned_vehicles", "VEHICLE TITLES: None")), 16, Ui.TEXT)
	_section_heading(col, "CITY STATUS")
	_label(col, str(_journal_data.get("dispatch", "DISPATCH")), 16, Ui.MUTED)
	_value_row(col, "Police locations", str(_journal_data.get("stations", 0)))

func _divider(parent: VBoxContainer) -> void:
	var line := HSeparator.new()
	parent.add_child(line)

func _button(parent: VBoxContainer, key: String, caption: String, action: String, enabled: bool = true) -> void:
	var button := Button.new()
	button.name = "Menu_" + key
	button.text = caption
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(func() -> void: _choice(action))
	parent.add_child(button)
	_buttons[key] = button
	if enabled:
		_focus_order.append(button)
	if _first_focus == null and enabled:
		_first_focus = button

func _slider(parent: VBoxContainer, caption: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title := Label.new()
	title.text = caption
	title.modulate = Ui.MUTED
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var amount := Label.new()
	amount.name = "Value_" + key
	amount.text = _format_setting(key, float(settings[key]))
	row.add_child(amount)
	var slider := HSlider.new()
	slider.name = "Setting_" + key
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = float(settings[key])
	slider.custom_minimum_size = Vector2(0.0, 30.0)
	slider.focus_mode = Control.FOCUS_ALL
	parent.add_child(slider)
	_focus_order.append(slider)
	slider.value_changed.connect(func(value: float) -> void:
		update_setting(key, value)
		amount.text = _format_setting(key, float(settings[key])))
	if _first_focus == null:
		_first_focus = slider

func _format_setting(key: String, value: float) -> String:
	if key.ends_with("_volume"):
		return "%d%%" % roundi(value * 100.0)
	return "%.4f" % value if key == "mouse_sensitivity" else "%.1f" % value

func _check(parent: VBoxContainer, caption: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.name = "Setting_" + key
	toggle.text = caption
	toggle.button_pressed = bool(settings[key])
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.custom_minimum_size.y = 40.0
	parent.add_child(toggle)
	_focus_order.append(toggle)
	toggle.toggled.connect(func(value: bool) -> void: update_setting(key, value))
	if _first_focus == null:
		_first_focus = toggle

func _choice(action: String) -> void:
	if is_instance_valid(_ui_click):
		_ui_click.volume_db = -80.0 if float(settings.get("sfx_volume", 0.75)) <= 0.0 else linear_to_db(float(settings.get("sfx_volume", 0.75))) - 11.0
		_ui_click.play()
	match action:
		"play":
			if screen == "title" and not _has_save:
				action_requested.emit("begin_opening")
			else:
				hide_for_game()
		"opening_accept":
			hide_for_game()
			action_requested.emit("accept_opening")
		"resume":
			hide_for_game()
		"settings":
			open_settings()
		"controls":
			open_controls()
		"map":
			open_map()
		"journal", "inventory":
			action_requested.emit(action)
		"restart_courier", "abandon_story", "home_waypoint", "garage_waypoint", "story_waypoint":
			action_requested.emit(action)
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
		"save_waypoint":
			action_requested.emit("save_waypoint")
		"title":
			open_title()
		"quit":
			get_tree().quit()
