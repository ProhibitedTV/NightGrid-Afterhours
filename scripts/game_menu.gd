extends CanvasLayer
const AudioMix = preload("res://scripts/audio_mix.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
const CityFoley = preload("res://scripts/city_foley.gd")
const Ui = preload("res://scripts/ui_style.gd")
const Opening = preload("res://scripts/opening_story.gd")
const SynaxisBrand = preload("res://scripts/synaxis_brand.gd")
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
	"vsync_enabled": true, "show_fps": false
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
	{"title": "SYSTEM", "keyboard": "Esc pause · M map · Tab journal · F5 save · F9 load · F6 new world · F3 FPS · F8 CSV · F10 photo",
		"pad": "Start pause · View/Select map · B back · Save/Load/New in pause menu"}
]

var screen := "hidden"
var _back_screen := "pause"
var _confirmation_origin := "pause"
var _has_save := false
var _world: Node3D
var _journal_data: Dictionary = {}
var _opening_stage := 0
var _opening_report := ""
var _opening_exit := ""
var _physical_opening := false
var _briefing_beat := 0
var _breakroom_choice := ""
const ParkingDialogue=preload("res://scripts/synaxis_parking_dialogue.gd")
var _guard_topic:=""
var _guard_former:=false
const Restrooms = preload("res://scripts/synaxis_restrooms.gd")
var _restroom_id := ""
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _root: Control
var _screen_nodes: Array[Control] = []
var _buttons: Dictionary = {}
var _first_focus: Control
var _ui_click: AudioStreamPlayer
var _body_scroll: ScrollContainer
var _body_col: VBoxContainer
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

func set_has_save(value: bool) -> void:
	_has_save = value

func is_open() -> bool:
	return visible and screen != "hidden"

func open_title() -> void:
	_open("title")

func open_opening(physical: bool = false) -> void:
	_physical_opening = physical
	_opening_stage = 0
	_briefing_beat = 0
	_opening_report = ""
	_opening_exit = ""
	if physical:
		hide_for_game()
	else:
		_open("opening")

func open_restroom(id: String) -> void:
	if id not in [Restrooms.MEN,Restrooms.WOMEN]:
		return
	_restroom_id=id
	_open("restroom")

var _street_contact:Dictionary={}

func open_street_contact(contact:Dictionary)->void:
	if contact.get("topics",[]).size()!=2:
		return
	_street_contact=contact.duplicate(true)
	_open("street_contact")

func open_parking_guard(former:bool) -> void:
	_guard_former=former
	_guard_topic=""
	_open("parking_guard")

func open_breakroom() -> void:
	_breakroom_choice=""
	_open("breakroom")

func open_opening_stage() -> void:
	_open("opening")

func _opening_next_location() -> void:
	if _physical_opening:
		hide_for_game()
		action_requested.emit("opening_walk")
	else:
		_render()

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
			"settings", "controls", "map", "journal":
				_open(_back_screen)
			"confirm_new":
				_open(_confirmation_origin)
			"pause":
				hide_for_game()
			"restroom":
				_choice("restroom_leave")
			"breakroom":
				_choice("breakroom_leave")
			"parking_guard":
				_choice("guard_leave")
			"street_contact":
				_choice("street_leave")
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
	_focus_order.clear()
	_first_focus = null
	var staged := screen in ["breakroom","restroom","parking_guard","street_contact"] or (screen=="opening" and _physical_opening and _opening_stage in [2,4])
	var shade := ColorRect.new()
	shade.name = "Scrim"
	shade.color = Color(0.028, 0.045, 0.060, .12 if staged else .94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if staged:
		center.anchor_left = .5
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size = Vector2(500.0 if staged else 760.0, 0.0)
	panel.add_theme_stylebox_override("panel", Ui.card(0.99, 26))
	center.add_child(panel)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 16)
	panel.add_child(shell)
	_label(shell, "MORROW BAY   /   NIGHT SHIFT", 16, Ui.AMBER)
	_title(shell, "EXECUTIVE PRIVILEGE" if staged else "NIGHTGRID: AFTERHOURS", 26 if staged else 40, Ui.TEXT)
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
		"restroom":
			SynaxisBrand.ui_lockup(col)
			_title(col,"AIR QUALITY INCIDENT" if _restroom_id==Restrooms.MEN else "FACILITIES / REQUIRED TRAINING",23,Ui.AMBER)
			_label(col,Restrooms.MEN_DIALOGUE if _restroom_id==Restrooms.MEN else Restrooms.WOMEN_DIALOGUE,16,Ui.TEXT)
			_button(col,"restroom_leave","BACK TO WORK","restroom_leave")
		"street_contact":
			_title(col,str(_street_contact["name"]).to_upper(),23,Ui.AMBER)
			_label(col,str(_street_contact["role"]),16,Ui.MUTED)
			for i in range(2):
				var key:="street_reply_%d"%i
				_button(col,key,str(_street_contact["topics"][i]["question"]),key)
			match int(_street_contact.get("cal_quest",-1)):
				0: _button(col,"cal_accept","HELP WITH THE ANNIVERSARY GIFT","cal_accept")
				1: _label(col,"The prepaid gift is at Moon Noodles.",15,Ui.MUTED)
				2: _button(col,"cal_complete","HAND OVER THE HEAT SINK","cal_complete")
				3: _label(col,"Compatibility Patch / Completed",15,Ui.MUTED)
			_button(col,"street_leave","SEE YOU AROUND","street_leave")
		"parking_guard":
			SynaxisBrand.ui_lockup(col)
			_title(col,"MARCUS VALE / PARKING SECURITY",23,Ui.AMBER)
			if _guard_topic.is_empty():
				_label(col,ParkingDialogue.greeting(_guard_former),16,Ui.TEXT)
				for topic in ParkingDialogue.TOPICS:
					if ParkingDialogue.available(topic,_guard_former):
						_button(col,topic,str(ParkingDialogue.TOPICS[topic]["question"]),topic)
			else:
				_label(col,str(ParkingDialogue.TOPICS[_guard_topic]["question"]),16,Ui.MUTED)
				_label(col,ParkingDialogue.reply(_guard_topic,_guard_former),17,Ui.TEXT)
				_button(col,"guard_back","ASK SOMETHING ELSE","guard_back")
			_button(col,"guard_leave","SEE YOU AROUND","guard_leave")
		"breakroom":
			SynaxisBrand.ui_lockup(col)
			_title(col,Opening.BREAKROOM_TITLE,23,Ui.AMBER)
			if _breakroom_choice.is_empty():
				_label(col,Opening.BREAKROOM_PARTY,16,Ui.TEXT)
				_button(col,"breakroom_photo","JOIN THE CORPORATE PHOTO","breakroom_photo")
				_button(col,"breakroom_decline","SKIP THE PHOTO","breakroom_decline")
			else:
				_label(col,Opening.BREAKROOM_PHOTO if _breakroom_choice=="breakroom_photo" else Opening.BREAKROOM_DECLINE,17,Ui.TEXT)
				_button(col,"breakroom_leave","BACK TO WORK","breakroom_leave")
		"opening":
			SynaxisBrand.ui_lockup(col)
			_label(col, "OMNISYSTEMS / INTERNAL USE ONLY / 2036", 14, SynaxisBrand.AQUA)
			_label(col, "CHAPTER ONE / EXECUTIVE PRIVILEGE  •  %d/6" % (_opening_stage+1), 16, Ui.MUTED)
			match _opening_stage:
				0:
					_title(col, "ONE LAST TICKET", 29, Ui.TEXT)
					_label(col, Opening.TICKET, 17, Color("cbd8e3"))
					_label(col, "Eli: The override came from the executive floor. Your job is to establish who accessed the IP and whether they were authorized.", 16, Ui.MUTED)
					_button(col, "opening_inspect", "REVIEW ACCESS ALERT", "opening_inspect")
				1:
					_title(col, "EXECUTIVE EXCEPTION", 29, Ui.TEXT)
					_label(col, Opening.AUDIT, 17, Color("cbd8e3"))
					_label(col, "The security policy applies to everyone. Except, apparently, the people who wrote it.", 16, Ui.MUTED)
					_button(col, "opening_brief", "ATTEND EXECUTIVE BRIEFING", "opening_brief")
				2:
					_title(col, "A PERSONNEL MATTER", 29, Ui.TEXT)
					match _briefing_beat:
						0:
							_label(col, Opening.CONFERENCE, 17, Color("cbd8e3"))
							_button(col, "opening_phone", "WAIT FOR THE CALL", "opening_phone")
						1:
							_label(col, "INCOMING CALL / MANDARIN", 16, Ui.AMBER)
							_label(col, Opening.CALL_SUBTITLES, 17, Ui.TEXT)
							_button(col, "opening_hangup", "CONTINUE BRIEFING", "opening_hangup")
						2:
							_label(col, Opening.CONFERENCE_END, 17, Color("cbd8e3"))
							_button(col, "opening_security", "ESCALATE TO SECURITY DIRECTOR", "opening_security")
							_button(col, "opening_legal", "ASK LEGAL TO PRESERVE AUDIT", "opening_legal")
				3:
					_title(col, "YOUR CONCERN HAS BEEN RECEIVED", 29, Ui.TEXT)
					_label(col, Opening.REPORT_RESPONSE if _opening_report == "opening_security" else Opening.LEGAL_RESPONSE, 17, Color("cbd8e3"))
					_label(col, "Company share price: record high. Employee access: revoked.", 16, Ui.AMBER)
					_button(col, "opening_read_notice", "OPEN PEOPLE OPERATIONS NOTICE", "opening_read_notice")
				4:
					_title(col, "WE VALUE YOUR FEEDBACK", 29, Ui.TEXT)
					_label(col, Opening.OFFBOARDING, 17, Color("cbd8e3"))
					_button(col, "opening_exit_accept", "SUBMIT EXIT FEEDBACK", "opening_exit_accept")
					_button(col, "opening_exit_decline", "DECLINE EXIT INTERVIEW", "opening_exit_decline")
				5:
					_label(col, Opening.EXIT_ACCEPT if _opening_exit == "opening_exit_accept" else Opening.EXIT_DECLINE, 16, Ui.MUTED)
					_title(col, Opening.HEADLINE, 29, Color("e3a39b"))
					_label(col, Opening.NOTICE, 17, Color("cbd8e3"))
					_divider(col)
					_label(col, Opening.OFFER, 17, Ui.TEXT)
					_button(col, "opening_accept", "ACCEPT TERMS / RETURN COMPANY PROPERTY" if _physical_opening else "ACCEPT TERMS / START DELIVERING", "opening_accept")
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
			_title(col, "Settings", 28, Ui.TEXT)
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
			if not str(_journal_data.get("opening_goal","")).is_empty():
				_label(col, str(_journal_data["opening_goal"]), 17, Ui.AMBER)
			if not str(_journal_data.get("platform_notice","")).is_empty():
				_label(col, str(_journal_data["platform_notice"]), 16, Ui.MUTED)
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
			if not str(_journal_data.get("cal_quest","")).is_empty():
				_label(col,str(_journal_data["cal_quest"]),16,Ui.ACCENT)
				if bool(_journal_data.get("cal_can_navigate",false)):
					_button(col,"cal_waypoint","SET COMPATIBILITY PATCH WAYPOINT","cal_waypoint")
			_divider(col)
			_title(col,"REPUTATION / STREET CRED",18,Ui.AMBER)
			_label(col,str(_journal_data.get("street_cred_summary","STREET CRED 0 / UNKNOWN")),16,Ui.ACCENT)
			var cred:Dictionary=_journal_data.get("street_cred",{})
			if int(cred.get("next",0))>int(cred.get("floor",0)):
				var bar:=ProgressBar.new()
				bar.min_value=float(cred.get("floor",0))
				bar.max_value=float(cred["next"])
				bar.value=float(cred.get("points",0))
				bar.show_percentage=false
				bar.custom_minimum_size=Vector2(0,12)
				col.add_child(bar)
			_divider(col)
			_title(col, "INVENTORY / STATUS", 18, Color("f0d1a0"))
			_label(col, str(_journal_data.get("weapons", "No equipment data")), 16, Ui.ACCENT)
			_label(col, str(_journal_data.get("owned_vehicles", "VEHICLE TITLES: None")), 16, Color("c4d6da"))
			_label(col, str(_journal_data.get("conditioning", "")), 16, Ui.ACCENT)
			_label(col, str(_journal_data.get("outfit", "")), 16, Ui.ACCENT)
			_label(col, "BTC WALLET: %d sats" % int(_journal_data.get("bitcoin_sats",0)), 16, Ui.ACCENT)
			if not str(_journal_data.get("synaxis_site","")).is_empty():
				_label(col,str(_journal_data["synaxis_site"]),16,Ui.MUTED)
				_button(col,"synaxis_waypoint","SET WAYPOINT TO SYNAXIS HQ","synaxis_waypoint")
			_label(col, str(_journal_data.get("home_text", "")), 16, Ui.ACCENT)
			if bool(_journal_data.get("home_can_navigate", false)):
				_button(col, "home_waypoint", "SET WAYPOINT TO POD", "home_waypoint")
			if bool(_journal_data.get("home_owned", false)):
				_label(col, str(_journal_data.get("garage_text", "")), 16, Ui.ACCENT)
				_button(col, "garage_waypoint", "SET WAYPOINT TO GARAGE", "garage_waypoint")
			_label(col, "%s  |  %d POLICE LOCATIONS" % [str(_journal_data.get("dispatch", "DISPATCH")), int(_journal_data.get("stations", 0))], 16, Color("77a7e0"))
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
	var height := get_viewport().get_visible_rect().size.y
	_body_scroll.custom_minimum_size.y = minf(_body_col.get_combined_minimum_size().y, maxf(140.0, height - 250.0))

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
	button.add_theme_font_size_override("font_size", 18)
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
		"street_reply_0","street_reply_1","street_leave","cal_accept","cal_complete":
			if screen=="street_contact":
				_street_contact={}
				hide_for_game()
				action_requested.emit(action)
		"guard_r9", "guard_parking", "guard_robots", "guard_access", "guard_shift", "guard_layoff":
			if screen=="parking_guard" and ParkingDialogue.available(action,_guard_former):
				_guard_topic=action
				_render()
		"guard_back":
			if screen=="parking_guard":
				_guard_topic=""
				_render()
		"guard_leave":
			if screen=="parking_guard":
				hide_for_game()
				action_requested.emit("guard_leave")
		"breakroom_photo", "breakroom_decline":
			if screen=="breakroom" and _breakroom_choice.is_empty():
				_breakroom_choice=action
				_render()
		"restroom_leave":
			if screen=="restroom":
				hide_for_game()
				action_requested.emit("restroom_leave")
		"breakroom_leave":
			if screen=="breakroom":
				hide_for_game()
				action_requested.emit("breakroom_leave")
		"opening_inspect":
			if screen == "opening" and _opening_stage == 0:
				_opening_stage = 1
				_render()
		"opening_brief":
			if screen == "opening" and _opening_stage == 1:
				_opening_stage = 2
				_opening_next_location()
		"opening_phone", "opening_hangup":
			if screen == "opening" and _opening_stage == 2 and ((action=="opening_phone" and _briefing_beat==0) or (action=="opening_hangup" and _briefing_beat==1)):
				_briefing_beat += 1
				if _physical_opening:
					action_requested.emit("opening_camera")
				_render()
		"opening_security", "opening_legal":
			if screen == "opening" and _opening_stage == 2 and _briefing_beat == 2:
				_opening_report = action
				_opening_stage = 3
				_render()
		"opening_read_notice":
			if screen == "opening" and _opening_stage == 3:
				_opening_stage = 4
				_opening_next_location()
		"opening_exit_accept", "opening_exit_decline":
			if screen == "opening" and _opening_stage == 4:
				_opening_exit = action
				_opening_stage = 5
				_opening_next_location()
		"opening_accept":
			if screen == "opening" and _opening_stage == 5:
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
		"journal":
			action_requested.emit("journal")
		"restart_courier", "abandon_story", "home_waypoint", "garage_waypoint", "story_waypoint", "synaxis_waypoint", "cal_waypoint":
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
		"title":
			open_title()
		"quit":
			get_tree().quit()
