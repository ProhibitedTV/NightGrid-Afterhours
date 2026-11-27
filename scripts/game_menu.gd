extends CanvasLayer
const FashionStores=preload("res://scripts/clothing_store.gd")
const AudioMix = preload("res://scripts/audio_mix.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
const CityFoley = preload("res://scripts/city_foley.gd")
const Ui = preload("res://scripts/ui_style.gd")
const DialogueWheel = preload("res://scripts/dialogue_wheel.gd")
const Rhythm=preload("res://scripts/rhythm_rehearsal.gd")
var _rhythm=Rhythm.new()
var _rhythm_sequence:=0
var _rhythm_focus_set:=false
var _music_desk:Dictionary={}
const Instruments=preload("res://scripts/instrument_catalog.gd")
const PocketBeat=preload("res://assets/instruments/pocketbeat_m3.glb")
const MusicSetPreview=preload("res://scripts/music_set_preview.gd")
var _rhythm_status:Label
var _rhythm_meter:ProgressBar
var _rhythm_claim:Button
var _rhythm_player:AudioStreamPlayer
var _rhythm_intro:AudioStreamPlayer
const BAND_INTRO=preload("res://assets/audio/music/band_demo.wav")
const STREET_INTRO=preload("res://assets/audio/music/busker_demo.wav")
const PAD_CLIPS=[preload("res://assets/audio/rehearsal/kick.wav"),preload("res://assets/audio/rehearsal/clap.wav"),preload("res://assets/audio/rehearsal/hat.wav")]
const Opening = preload("res://scripts/opening_story.gd")
const OpeningVoice = preload("res://scripts/opening_voice.gd")
var _opening_voice: Node
const Phone = preload("res://scripts/morrow_phone.gd")
const SynaxisBrand = preload("res://scripts/synaxis_brand.gd")
const Consumables = preload("res://scripts/consumables.gd")
## Keyboard/mouse/controller-friendly menu layer. It remains interactive while
## the 3D SceneTree is paused; all buttons use Godot's built-in focus navigation.
signal action_requested(action: String)
signal settings_changed(settings: Dictionary)

const SAVE_SETTINGS = "user://settings.cfg"
const RenderQuality = preload("res://scripts/render_quality.gd")
const DEFAULT_SETTINGS = {
	"master_volume": 0.80, "music_volume": 0.65, "ambience_volume": 0.65,
	"sfx_volume": 0.75, "dialogue_volume": 0.82, "radio_on": true, "mouse_sensitivity": 0.0032,
	"stick_sensitivity": 2.6, "invert_look_y": false,
	"ssr_enabled": true, "glow_enabled": true,
	"ao_enabled": true, "fog_enabled": true, "ssil_enabled": false,
	"render_quality": "high", "render_overrides": {},
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
	{"title": "SYSTEM", "keyboard": "Esc pause · M map · Tab journal · P phone · F5 save at hotel · F9 load · F6 new game · F3 FPS · F8 CSV · F10 photo",
		"pad": "Start pause · View/Select map · B back · Phone/Save/Load/New in pause menu"}
]

var screen := "hidden"
var _back_screen := "pause"
var _confirmation_origin := "pause"
var _has_save := false
var _pause_opening_goal := ""
var _save_feedback := ""
var _world: Node3D
var _journal_data: Dictionary = {}
var _phone_data: Dictionary = {}
var _phone_app := ""
var _phone_from_pause := false
var _opening_stage := 0
var _opening_report := ""
var _opening_exit := ""
var _physical_opening := false
var _briefing_beat := 0
var _breakroom_choice := ""
const ParkingDialogue=preload("res://scripts/synaxis_parking_dialogue.gd")
var _guard_topic:=""
var _guard_former:=false
var _guard_contact:=0
var _interview:Dictionary={}
var _interview_topic:=-1
var _investigation_notes:Dictionary={}
var _notes_origin:="opening"
const Workstation=preload("res://scripts/synaxis_workstation.gd")
var _terminal_tab:="inbox"
var _terminal_origin:="cubicle"
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
	_opening_voice = OpeningVoice.new()
	add_child(_opening_voice)
	_rhythm_player=AudioStreamPlayer.new()
	_rhythm_player.bus=AudioMix.MUSIC
	_rhythm_player.process_mode=Node.PROCESS_MODE_ALWAYS
	_rhythm_player.volume_db=-8.0
	add_child(_rhythm_player)
	_rhythm_intro=AudioStreamPlayer.new()
	_rhythm_intro.name="MusicSetIntro"
	_rhythm_intro.bus=AudioMix.MUSIC
	_rhythm_intro.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(_rhythm_intro)
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

func open_opening(physical: bool = false) -> void:
	_physical_opening = physical
	_opening_stage = 0
	_briefing_beat = 0
	_opening_report = ""
	_opening_exit = ""
	_investigation_notes.clear()
	_notes_origin="opening"
	_terminal_tab="inbox"
	_terminal_origin="cubicle"
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
	var count:int=contact.get("topics",[]).size()
	if count!=2 and (contact.get("character","")!="daddy_stanky" or count!=8):
		return
	_street_contact=contact.duplicate(true)
	_open("street_contact")

func open_staff_interview(data:Dictionary) -> void:
	if data.is_empty() or not data.has("topics"):
		return
	_interview=data.duplicate(true)
	_interview_topic=-1
	_open("staff_interview")

func open_parking_guard(former:bool,contact:int=0) -> void:
	_guard_former=former
	_guard_contact=contact
	_guard_topic=""
	_open("parking_guard")

func open_breakroom() -> void:
	_breakroom_choice=""
	_open("breakroom")

func open_cubicle_terminal() -> void:
	if not _physical_opening or _opening_stage!=0:
		return
	_terminal_origin="cubicle"
	_terminal_tab="inbox"
	_open("workstation")

func open_opening_stage() -> void:
	_open("opening")

func _opening_next_location() -> void:
	if _physical_opening:
		hide_for_game()
		action_requested.emit("opening_walk")
	else:
		_render()

func open_phone(context: Dictionary, from_pause: bool = false) -> void:
	_phone_data = context.duplicate(true)
	_phone_app = ""
	_phone_from_pause = from_pause
	_open("phone")

func refresh_phone(context: Dictionary) -> void:
	if screen == "phone":
		_phone_data = context.duplicate(true)
		_render()

func _phone_back() -> void:
	if not _phone_app.is_empty():
		_phone_app = ""
		_render()
	elif _phone_from_pause:
		_open("pause")
	else:
		hide_for_game()

func open_pause(opening_goal: String = "") -> void:
	_save_feedback = ""
	_pause_opening_goal = opening_goal
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
	if is_instance_valid(_opening_voice):
		_opening_voice.call("stop")
	if screen=="blue_hour_set":
		_stop_music_set_audio()
		_rhythm.cancel()
	screen = "hidden"
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func get_buttons() -> Dictionary:
	return _buttons.duplicate()

func get_settings() -> Dictionary:
	return settings.duplicate(true)

func _open(value: String) -> void:
	if screen=="blue_hour_set" and value!="blue_hour_set":
		_stop_music_set_audio()
		_rhythm.cancel()
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
	if screen == "phone" and event.is_action_pressed("phone_open"):
		hide_for_game()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("game_pause") or event.is_action_pressed("game_back"):
		match screen:
			"phone":
				_phone_back()
			"settings", "controls", "map", "journal", "inventory":
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
			"staff_interview":
				_choice("interview_leave")
			"investigation_notes":
				_choice("notes_back")
			"workstation":
				_choice("terminal_leave")
			"street_contact":
				_choice("street_leave")
			"blue_hour_set":
				_choice("rhythm_cancel")
			"music_desk":
				_choice("music_desk_leave")
			_:
				pass
		get_viewport().set_input_as_handled()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_SETTINGS) != OK:
		_normalize()
		return
	for key in DEFAULT_SETTINGS:
		settings[key] = config.get_value("player", key, DEFAULT_SETTINGS[key])
	_normalize(not config.has_section_key("player", "render_quality"))

func _normalize(legacy_graphics: bool = false) -> void:
	settings["master_volume"] = clampf(float(settings.get("master_volume", 0.8)), 0.0, 1.0)
	settings["music_volume"] = clampf(float(settings.get("music_volume", 0.65)), 0.0, 1.0)
	settings["ambience_volume"] = clampf(float(settings.get("ambience_volume", 0.65)), 0.0, 1.0)
	settings["sfx_volume"] = clampf(float(settings.get("sfx_volume", 0.75)), 0.0, 1.0)
	settings["dialogue_volume"] = clampf(float(settings.get("dialogue_volume", 0.82)), 0.0, 1.0)
	settings["radio_on"] = bool(settings.get("radio_on", true))
	settings["mouse_sensitivity"] = clampf(float(settings.get("mouse_sensitivity", 0.0032)), 0.001, 0.010)
	settings["stick_sensitivity"] = clampf(float(settings.get("stick_sensitivity", 2.6)), 0.5, 5.0)
	for key in ["invert_look_y", "vsync_enabled", "show_fps", "show_control_hints", "show_hud_inventory"]:
		settings[key] = bool(settings.get(key, DEFAULT_SETTINGS[key]))
	RenderQuality.normalize(settings, legacy_graphics)

func _save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("player", key, settings[key])
	config.save(SAVE_SETTINGS)
	settings_changed.emit(get_settings())

func update_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	if key in RenderQuality.FEATURES:
		RenderQuality.set_feature(settings, key, bool(value))
	else:
		settings[key] = value
	_normalize()
	_save_settings()

func _render() -> void:
	if is_instance_valid(_opening_voice):
		_opening_voice.call("select_scene", OpeningVoice.scene_for(screen, _opening_stage, _briefing_beat, _breakroom_choice))
	# queue_free keeps the 3D world untouched; old menu controls are detached
	# from the active input tree immediately before new controls gain focus.
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_focus_order.clear()
	_first_focus = null
	var staged := screen in ["breakroom","restroom","parking_guard","street_contact","staff_interview"] or (screen=="opening" and _physical_opening and _opening_stage in [2,3,4])
	var shade := ColorRect.new()
	shade.name = "Scrim"
	shade.color = Color(0.028, 0.045, 0.060, .36 if screen == "phone" else (.12 if staged else (.94 if screen in ["title", "opening"] else .68)))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if staged or screen == "phone":
		center.anchor_left = .5
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	_menu_panel = panel
	panel.custom_minimum_size = Vector2(410.0 if screen == "phone" else (500.0 if staged else 760.0), 0.0)
	panel.add_theme_stylebox_override("panel", Ui.card(0.97, 22))
	center.add_child(panel)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	panel.add_child(shell)
	_label(shell, "MORROW MOBILE  ·  " + str(_phone_data.get("clock","--:--")) if screen == "phone" else "NIGHTGRID  /  MORROW BAY", 14, Ui.AMBER)
	_title(shell, "EXECUTIVE PRIVILEGE" if staged else ("AFTERHOURS" if screen == "title" else {"phone": "Morrow OS", "pause": "Paused", "settings": "Settings", "controls": "Controls", "map": "City atlas", "journal": "Journal", "inventory": "Player & inventory", "confirm_new": "New Game", "opening": "People operations"}.get(screen, "Afterhours")), 26 if staged or screen == "phone" else 34, Ui.TEXT)
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
				_button(col, "continue", "CONTINUE  •  NO COMPATIBLE SAVE", "load", false)
			_button(col, "new", "NEW GAME", "new")
			_button(col, "settings", "SETTINGS", "settings")
			_button(col, "controls", "CONTROLS & GAMEPAD", "controls")
			_button(col, "quit", "QUIT TO DESKTOP", "quit")
		"restroom":
			SynaxisBrand.ui_lockup(col)
			_title(col,"AIR QUALITY INCIDENT" if _restroom_id==Restrooms.MEN else "FACILITIES / REQUIRED TRAINING",23,Ui.AMBER)
			_label(col,Restrooms.MEN_DIALOGUE if _restroom_id==Restrooms.MEN else Restrooms.WOMEN_DIALOGUE,16,Ui.TEXT)
			_button(col,"restroom_leave","BACK TO WORK","restroom_leave")
		"music_desk":
			_title(col,"COPPER CUP / MUSIC CONSIGNMENT",24,Ui.AMBER)
			_pocketbeat_preview(col)
			_label(col,"Hal has a refurbished PocketBeat M3 sampler on the counter. Loaners are still free.",16,Ui.TEXT)
			_label(col,str(_music_desk.get("summary","")),16,Ui.ACCENT)
			_label(col,"CASH $%d"%int(_music_desk.get("cash",0)),16,Ui.MUTED)
			_button(col,"music_desk_busk","BORROW SAMPLER / BUSK","music_desk_busk")
			_button(col,"music_desk_buy","BUY POCKETBEAT M3 / $40","music_desk_buy",not bool(_music_desk.get("owned",false)) and int(_music_desk.get("cash",0))>=Instruments.price(Instruments.STARTER))
			_button(col,"music_desk_practice","PRACTICE OWNED SAMPLER","music_desk_practice",bool(_music_desk.get("owned",false)))
			_button(col,"music_desk_owned","PERSONAL SET / $14 +4 STREET CRED","music_desk_owned",bool(_music_desk.get("owned_set",false)))
			_label(col,str(_music_desk.get("band","")),16,Ui.TEXT)
			if bool(_music_desk.get("recruit_rhea",false)):
				_button(col,"music_desk_recruit","INVITE RHEA VALE / BASS","music_desk_recruit")
			if bool(_music_desk.get("band_rehearse",false)):
				_button(col,"music_desk_rehearse","REHEARSE WITH RHEA AND MILO","music_desk_rehearse")
			var names:Array=_music_desk.get("band_names",[])
			for i in range(names.size()):
				var key:="music_desk_name:%d"%i
				_button(col,key,"NAME BAND / "+str(names[i]),key)
			_label(col,str(_music_desk.get("merch","")),16,Ui.MUTED)
			if bool(_music_desk.get("press_tapes",false)):
				_button(col,"music_desk_press","PRESS 12 TAPES / $60","music_desk_press")
			_button(col,"music_desk_leave","LEAVE","music_desk_leave")
		"blue_hour_set":
			_render_rhythm(col)
		"street_contact":
			_title(col,str(_street_contact["name"]).to_upper(),23,Ui.AMBER)
			_label(col,str(_street_contact["role"]),16,Ui.MUTED)
			if _street_contact.get("character","")=="daddy_stanky":
				_button(col,"stanky_show","SHARKTOOTH SESSIONS / FREESTYLE","stanky_show")
				_button(col,"stanky_fight","FIGHT NIGHT / LIVE COMMENTARY","stanky_fight")
				_button(col,"stanky_family","AFTERHOURS / THE REGULARS","stanky_family")
				_button(col,"stanky_trio","RC & BOON / OLD FRIENDS","stanky_trio")
				var story_next:=str(_street_contact.get("story_next",""))
				if story_next=="offclock":
					_button(col,"stanky_story","I JUST GOT LAID OFF / OFF THE CLOCK","stanky_story")
				elif story_next=="archive":
					_button(col,"stanky_story","GOOD TO SEE YOU AGAIN / KEEP A COPY","stanky_story")
			for i in range(_street_contact["topics"].size()):
				var key:="stanky_reply_%d"%i if _street_contact.get("character","")=="daddy_stanky" else "street_reply_%d"%i
				_button(col,key,str(_street_contact["topics"][i]["question"]),key)
			match int(_street_contact.get("cal_quest",-1)):
				0: _button(col,"cal_accept","HELP WITH THE ANNIVERSARY GIFT","cal_accept")
				1: _label(col,"The prepaid gift is at Moon Noodles.",15,Ui.MUTED)
				2: _button(col,"cal_complete","HAND OVER THE HEAT SINK","cal_complete")
				3: _label(col,"Compatibility Patch / Completed",15,Ui.MUTED)
			_button(col,"street_leave","SEE YOU AROUND","street_leave")
		"workstation":
			SynaxisBrand.ui_lockup(col)
			_title(col,"SYNAXIS WORKSPACE / INTERNAL",25,Ui.TEXT)
			_label(col,"CORPORATE IP SECURITY  /  READ-ONLY SESSION",14,Ui.MUTED)
			_button(col,"terminal_leave","RETURN TO "+("IT REVIEW" if _terminal_origin=="opening" else "WORKFLOOR"),"terminal_leave")
			_button(col,"terminal_inbox","INBOX","terminal_inbox",_terminal_tab!="inbox")
			_button(col,"terminal_ticket","SERVICE DESK","terminal_ticket",_terminal_tab!="ticket")
			_button(col,"terminal_access","ACCESS RECORDS","terminal_access",_terminal_tab!="access")
			var page:Dictionary=Workstation.page(_terminal_tab,_terminal_origin=="opening" and _opening_stage==1)
			_title(col,str(page["title"]),20,Ui.AMBER)
			if page.has("body"):
				_label(col,str(page["body"]),16,Ui.TEXT)
			for entry in page.get("rows",[]):
				_divider(col)
				if entry.has("subject"):
					_label(col,str(entry["from"])+" / "+str(entry["subject"]),16,Ui.AMBER)
					_label(col,str(entry["body"]),16,Ui.TEXT)
				else:
					_label(col,str(entry["event"])+" / "+str(entry["actor"]),16,Ui.AMBER)
					_label(col,str(entry["resource"])+" — "+str(entry["status"]),16,Ui.TEXT)
		"investigation_notes":
			SynaxisBrand.ui_lockup(col)
			_title(col,"PRIVATE INVESTIGATION NOTES",23,Ui.AMBER)
			_label(col,"Personal notes from conversations. Statements are not verified audit evidence.",15,Ui.MUTED)
			_button(col,"notes_back","RETURN TO CONVERSATION","notes_back")
			if _investigation_notes.is_empty():
				_label(col,"No employee statements recorded.",16,Ui.TEXT)
			for id in _investigation_notes:
				var note:Dictionary=_investigation_notes[id]
				_label(col,str(note["name"])+" / "+str(note["question"]),16,Ui.AMBER)
				_label(col,str(note["reply"]),16,Ui.TEXT)
		"staff_interview":
			SynaxisBrand.ui_lockup(col)
			_title(col,str(_interview["name"]),23,Ui.AMBER)
			_label(col,str(_interview["role"]),15,Ui.MUTED)
			var topics:Array=_interview["topics"]
			if _interview_topic<0 and topics.size()==2:
				_dialogue_wheel(col, [
					["interview_0", "Ask about work", str(topics[0]["question"]), "left"],
					["interview_1", "Ask about access", str(topics[1]["question"]), "right"],
					["notes_open", "Review notes", "Read private investigation notes.", "up"],
					["interview_leave", "Back to work", "End this conversation.", "down"]])
			elif _interview_topic<0:
				for i in mini(topics.size(),2):
					_button(col,"interview_%d" % i,str(topics[i]["question"]),"interview_%d" % i)
			else:
				_label(col,str(topics[_interview_topic]["question"]),16,Ui.MUTED)
				_label(col,str(topics[_interview_topic]["reply"]),17,Ui.TEXT)
				_button(col,"interview_back","ASK SOMETHING ELSE","interview_back")
			if _interview_topic>=0 or topics.size()!=2:
				_button(col,"notes_open","REVIEW PRIVATE NOTES (%d)" % _investigation_notes.size(),"notes_open")
				_button(col,"interview_leave","BACK TO WORK","interview_leave")
		"parking_guard":
			SynaxisBrand.ui_lockup(col)
			_title(col,"MARCUS VALE / PARKING SECURITY",23,Ui.AMBER)
			if _guard_topic.is_empty():
				_label(col,ParkingDialogue.greeting(_guard_former,_guard_contact),16,Ui.TEXT)
				for topic in ParkingDialogue.TOPICS:
					if ParkingDialogue.available(topic,_guard_former,_guard_contact):
						_button(col,topic,str(ParkingDialogue.TOPICS[topic]["question"]),topic)
			else:
				_label(col,str(ParkingDialogue.TOPICS[_guard_topic]["question"]),16,Ui.MUTED)
				_label(col,ParkingDialogue.reply(_guard_topic,_guard_former,_guard_contact),17,Ui.TEXT)
				_button(col,"guard_back","ASK SOMETHING ELSE","guard_back")
			_button(col,"guard_leave","SEE YOU AROUND","guard_leave")
		"breakroom":
			SynaxisBrand.ui_lockup(col)
			_title(col,Opening.BREAKROOM_TITLE,23,Ui.AMBER)
			if _breakroom_choice.is_empty():
				_label(col,Opening.BREAKROOM_PARTY,16,Ui.TEXT)
				_dialogue_wheel(col, [
					["breakroom_photo","Play along","Join the corporate photo.","right"],
					["breakroom_decline","Decline","Skip the corporate photo.","left"]])
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
					_button(col,"terminal_open","OPEN SERVICE DESK","terminal_open")
					_button(col, "opening_inspect", "REVIEW ACCESS ALERT", "opening_inspect")
				1:
					_title(col, "EXECUTIVE EXCEPTION", 29, Ui.TEXT)
					_label(col, Opening.AUDIT, 17, Color("cbd8e3"))
					_label(col, "The security policy applies to everyone. Except, apparently, the people who wrote it.", 16, Ui.MUTED)
					_button(col,"terminal_open","INSPECT VALIDATED ACCESS RECORDS","terminal_open")
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
							if not _investigation_notes.is_empty():
								_button(col,"notes_open","REVIEW PRIVATE NOTES (%d)" % _investigation_notes.size(),"notes_open")
							_dialogue_wheel(col, [
								["opening_security","Escalate","Escalate to the security director.","right"],
								["opening_legal","Preserve evidence","Ask legal to preserve the audit.","left"]])
				3:
					_title(col, "YOUR CONCERN HAS BEEN RECEIVED", 29, Ui.TEXT)
					_label(col, Opening.REPORT_RESPONSE if _opening_report == "opening_security" else Opening.LEGAL_RESPONSE, 17, Color("cbd8e3"))
					_label(col, "Company share price: record high. Employee access: revoked.", 16, Ui.AMBER)
					_button(col, "opening_read_notice", "OPEN PEOPLE OPERATIONS NOTICE", "opening_read_notice")
				4:
					_title(col, "WE VALUE YOUR FEEDBACK", 29, Ui.TEXT)
					_label(col, Opening.OFFBOARDING, 17, Color("cbd8e3"))
					_dialogue_wheel(col, [
						["opening_exit_accept","Give feedback","Submit exit feedback.","right"],
						["opening_exit_decline","Decline","Decline the exit interview.","left"]])
				5:
					_label(col, Opening.EXIT_ACCEPT if _opening_exit == "opening_exit_accept" else Opening.EXIT_DECLINE, 16, Ui.MUTED)
					_title(col, Opening.HEADLINE, 29, Color("e3a39b"))
					_label(col, Opening.NOTICE, 17, Color("cbd8e3"))
					_divider(col)
					_label(col, Opening.OFFER, 17, Ui.TEXT)
					_button(col, "opening_accept", "ACCEPT TERMS / RETURN COMPANY PROPERTY" if _physical_opening else "ACCEPT TERMS / START DELIVERING", "opening_accept")
		"phone":
			_render_phone(col)
		"pause":
			_button(col, "resume", "Resume game", "resume")
			if _pause_opening_goal.is_empty():
				_section_heading(col, "WORLD")
				_button(col, "map", "City atlas", "map")
				_button(col, "journal", "Mission journal", "journal")
				_button(col, "phone", "Smartphone", "phone", is_instance_valid(_world) and bool(_world.call("phone_available")))
				_button(col, "inventory", "Player & inventory", "inventory")
			else:
				_section_heading(col, "CHAPTER ONE / EXECUTIVE PRIVILEGE")
				_label(col, _pause_opening_goal, 17, Ui.AMBER)
			_section_heading(col, "SESSION")
			var save_info: Dictionary = _world.call("save_availability") if is_instance_valid(_world) else {"allowed": false, "reason": "Visit Lantern Court to save."}
			var can_save := bool(save_info["allowed"])
			_button(col, "save", "SAVE PROGRESS" if can_save else "SAVE PROGRESS  /  UNAVAILABLE", "save", can_save)
			_label(col, _save_feedback if not _save_feedback.is_empty() else str(save_info["reason"]), 15, Ui.ACCENT if can_save else Ui.MUTED)
			if not can_save and _pause_opening_goal.is_empty():
				_button(col, "save_waypoint", "ROUTE TO LANTERN COURT", "save_waypoint")
			_button(col, "load", "Load saved game", "load", _has_save)
			_button(col, "new", "New Game", "new")
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
			_quality_selector(col)
			_check(col, "SCREEN-SPACE REFLECTIONS", "ssr_enabled")
			_check(col, "NEON BLOOM", "glow_enabled")
			_check(col, "CONTACT SHADOWS / AO", "ao_enabled")
			_check(col, "ATMOSPHERIC DISTANCE HAZE", "fog_enabled")
			_check(col, "SCREEN-SPACE INDIRECT LIGHT (SSIL)", "ssil_enabled")
			_check(col, "VERTICAL SYNC", "vsync_enabled")
			_check(col, "SHOW LIVE FPS & CHUNK METRICS", "show_fps")
			_label(col, "Each profile remembers its feature switches. Cinematic enables a more expensive indirect-light pass.", 14, Color("90a7ba"))
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
			var investigation_note: String = str(_journal_data.get("investigation",""))
			if not investigation_note.is_empty():
				_label(col, investigation_note, 16, Ui.ACCENT)
			if not str(_journal_data.get("cal_quest","")).is_empty():
				_label(col,str(_journal_data["cal_quest"]),16,Ui.ACCENT)
				if bool(_journal_data.get("cal_can_navigate",false)):
					_button(col,"cal_waypoint","SET COMPATIBILITY PATCH WAYPOINT","cal_waypoint")
			_divider(col)
			_title(col,"REPUTATION / STREET CRED",18,Ui.AMBER)
			_label(col,str(_journal_data.get("street_cred_summary","STREET CRED 0 / UNKNOWN")),16,Ui.ACCENT)
			_label(col,str(_journal_data.get("scene_reputation","")),15,Ui.TEXT)
			var cred:Dictionary=_journal_data.get("street_cred",{})
			if int(cred.get("next",0))>int(cred.get("floor",0)):
				var bar:=ProgressBar.new()
				bar.min_value=float(cred.get("floor",0))
				bar.max_value=float(cred["next"])
				bar.value=float(cred.get("points",0))
				bar.show_percentage=false
				bar.custom_minimum_size=Vector2(0,12)
				col.add_child(bar)
			_label(col,str(_journal_data.get("instrument_status","")),16,Ui.ACCENT)
			_label(col,str(_journal_data.get("busking_status","")),16,Ui.ACCENT)
			_button(col,"busking_waypoint","SET STREET MUSIC WAYPOINT","busking_waypoint")
			_label(col,str(_journal_data.get("music_contact","")),16,Ui.ACCENT)
			if bool(_journal_data.get("music_can_navigate",false)):
				_button(col,"music_waypoint","SET UNDERGROUND MUSIC CONTACT WAYPOINT","music_waypoint")
			for source in _journal_data.get("street_cred_sources",[]):
				_label(col,"%s  /  +%d earned"%[str(source["name"]),int(source["points"])],14,Ui.MUTED)
			_divider(col)
			_title(col, "INVENTORY / STATUS", 18, Color("f0d1a0"))
			_label(col, str(_journal_data.get("weapons", "No equipment data")), 16, Ui.ACCENT)
			_label(col, str(_journal_data.get("owned_vehicles", "VEHICLE TITLES: None")), 16, Color("c4d6da"))
			_label(col, str(_journal_data.get("conditioning", "")), 16, Ui.ACCENT)
			_label(col, str(_journal_data.get("outfit", "")), 16, Ui.ACCENT)
			if _journal_data.has("fashion_locations"):
				_title(col,"FASHION DIRECTORY",18,Color("f0d1a0"))
				for id in _journal_data["fashion_locations"]:
					if FashionStores.STORES.has(id):
						var site:Dictionary=FashionStores.STORES[id]
						var remaining:Dictionary=_journal_data.get("fashion_remaining",{})
						var count_text: String = " • %d unowned"%int(remaining[id]) if remaining.has(id) else ""
						_button(col,"fashion_"+id,"%s / %s%s" % [site["name"],site["district"],count_text],"fashion_waypoint:"+id)
			_label(col, "BTC WALLET: %d sats" % int(_journal_data.get("bitcoin_sats",0)), 16, Ui.ACCENT)
			if not str(_journal_data.get("synaxis_site","")).is_empty():
				_label(col,str(_journal_data["synaxis_site"]),16,Ui.MUTED)
				_button(col,"synaxis_waypoint","SET WAYPOINT TO SYNAXIS HQ","synaxis_waypoint")
			if not str(_journal_data.get("synaxis_contact","")).is_empty():
				_label(col,str(_journal_data["synaxis_contact"]),16,Ui.ACCENT)
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
			_button(col, "inventory", "Player & inventory", "inventory")
			_button(col, "back", "Back to pause", "back")
		"inventory":
			_render_inventory(col)
			_button(col, "journal", "Mission journal", "journal")
			_button(col, "back", "Back to pause", "back")
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
			_title(col, "START A NEW GAME?", 24, Color("f0cdab"))
			_label(col, "The current unsaved session will be discarded. Your last saved slot will remain intact until you save your new game. Morrow Bay’s layout remains unchanged.", 17, Color("cbd8e3"))
			_button(col, "cancel", "KEEP CURRENT SESSION", "cancel_new")
			_button(col, "confirm_new", "DISCARD SESSION / NEW GAME", "confirm_new")
	_divider(shell)
	_label(shell, "Arrows / D-pad  Navigate   •   Enter / A  Select   •   Esc / B  Back", 16, Ui.MUTED)
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
		var staged := screen in ["breakroom","restroom","parking_guard","street_contact"] or (screen == "opening" and _physical_opening and _opening_stage in [2,3,4])
		var target_width := 500.0 if staged else (840.0 if screen in ["inventory","journal"] else 760.0)
		_menu_panel.custom_minimum_size.x = minf(target_width, maxf(320.0, viewport_size.x - 64.0))
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
	# Override the list focus chain within the wheel. Surrounding controls remain
	# reachable via Tab and the original list order.
	for node in _root.find_children("DialogueWheel", "Control", true, false):
		node.call("wire_directions")
	if screen == "phone" and _phone_app.is_empty() and _focus_order.size() == Phone.APPS.size()+1:
		var count: int = Phone.APPS.size()
		for i in range(count):
			var item := _focus_order[i]
			item.focus_neighbor_left = item.get_path_to(_focus_order[i-1] if i%2 == 1 else item)
			item.focus_neighbor_right = item.get_path_to(_focus_order[i+1] if i%2 == 0 and i+1<count else item)
			item.focus_neighbor_top = item.get_path_to(_focus_order[i-2] if i>=2 else _focus_order[count])
			item.focus_neighbor_bottom = item.get_path_to(_focus_order[i+2] if i+2<count else _focus_order[count])
		_focus_order[count].focus_neighbor_top = _focus_order[count].get_path_to(_focus_order[count-1])
		_focus_order[count].focus_neighbor_bottom = _focus_order[count].get_path_to(_focus_order[0])

func _render_phone(col: VBoxContainer) -> void:
	if _phone_app.is_empty():
		_label(col, "Your city, connected.", 18, Ui.MUTED)
		var apps := GridContainer.new()
		apps.columns = 2
		apps.add_theme_constant_override("h_separation",10)
		apps.add_theme_constant_override("v_separation",10)
		col.add_child(apps)
		for entry in Phone.APPS:
			var id: String = entry["id"]
			var app_button := Button.new()
			app_button.name = "Menu_phone_app_" + id
			app_button.text = str(entry["name"])
			app_button.icon = Phone.ICONS[id]
			app_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			app_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			app_button.expand_icon = true
			app_button.add_theme_constant_override("icon_max_width",42)
			app_button.custom_minimum_size = Vector2(0,100)
			app_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			app_button.add_theme_font_size_override("font_size",20)
			app_button.add_theme_color_override("font_color",Color(entry["color"]))
			var tile := Ui.button_style(Color("1b2934"),Color("344752"))
			tile.set_corner_radius_all(12)
			app_button.add_theme_stylebox_override("normal",tile)
			app_button.pressed.connect(_choice.bind("phone_app_"+id))
			apps.add_child(app_button)
			_buttons["phone_app_"+id] = app_button
			_focus_order.append(app_button)
			if _first_focus == null:
				_first_focus = app_button
		_button(col, "phone_back", "Put phone away" if not _phone_from_pause else "Back to pause", "phone_back")
		return
	var entry: Dictionary = Phone.app(_phone_app)
	var view: Dictionary = Phone.view(_phone_app,_phone_data)
	_title(col,str(entry["name"]),28,Color(entry["color"]))
	_label(col,str(view["subtitle"]),16,Ui.MUTED)
	_divider(col)
	for row in view["rows"]:
		_label(col,str(row["label"]),15,Ui.AMBER)
		_label(col,str(row["value"]),20,Ui.TEXT)
		if row.has("action"):
			_button(col,str(row["action"]),str(row["action_label"]),str(row["action"]))
		_divider(col)
	for item in view["actions"]:
		_button(col,str(item["action"]),str(item["label"]),str(item["action"]))
	_button(col,"phone_back","Back to apps","phone_back")

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

# Keep the existing action dispatcher and Button focus semantics. A wheel only
# changes presentation, never conversation state or mission consequences.
func _dialogue_wheel(parent: VBoxContainer, choices: Array) -> void:
	var wheel := DialogueWheel.new()
	wheel.name = "DialogueWheel"
	parent.add_child(wheel)
	var preview := Label.new()
	preview.name = "DialogueIntentPreview"
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.custom_minimum_size.y = 44
	preview.add_theme_font_size_override("font_size", 15)
	preview.add_theme_color_override("font_color", Ui.MUTED)
	parent.add_child(preview)
	for choice in choices:
		var id := str(choice[0])
		_button(wheel, id, str(choice[1]), id)
		var button := _buttons[id] as Button
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 15)
		button.tooltip_text = str(choice[2])
		wheel.register_choice(str(choice[3]), button)
		var reveal := func() -> void: preview.text = button.tooltip_text
		button.focus_entered.connect(reveal)
		button.mouse_entered.connect(reveal)
	preview.text = str(choices[0][2])

func _button(parent: Control, key: String, caption: String, action: String, enabled: bool = true) -> void:
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

func _quality_selector(parent: VBoxContainer) -> void:
	var selector := OptionButton.new()
	selector.name = "Setting_render_quality"
	selector.custom_minimum_size.y = 40
	for profile: String in RenderQuality.PROFILES:
		selector.add_item(profile.capitalize())
	selector.select(RenderQuality.PROFILES.find(settings["render_quality"]))
	parent.add_child(selector)
	_focus_order.append(selector)
	selector.item_selected.connect(func(index: int) -> void:
		update_setting("render_quality", RenderQuality.PROFILES[index])
		for key: String in RenderQuality.FEATURES:
			var toggle := parent.get_node("Setting_" + key) as CheckButton
			toggle.set_pressed_no_signal(settings[key]))

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
	if action in ["stanky_show","stanky_fight","stanky_family","stanky_trio","stanky_story"]:
		if screen=="street_contact" and _street_contact.get("character","")=="daddy_stanky":
			_street_contact={}
			hide_for_game()
			action_requested.emit(action)
		return
	if action.begins_with("stanky_reply_"):
		var suffix:=action.trim_prefix("stanky_reply_")
		if screen=="street_contact" and _street_contact.get("character","")=="daddy_stanky" and suffix.is_valid_int() and int(suffix)>=0 and int(suffix)<_street_contact["topics"].size():
			_street_contact={}
			hide_for_game()
			action_requested.emit(action)
		return
	if action.begins_with("music_desk_name:"):
		if screen=="music_desk":
			action_requested.emit(action)
		return
	if is_instance_valid(_ui_click):
		_ui_click.volume_db = -80.0 if float(settings.get("sfx_volume", 0.75)) <= 0.0 else linear_to_db(float(settings.get("sfx_volume", 0.75))) - 11.0
		_ui_click.play()
	if action.begins_with("phone_app_") and screen == "phone":
		var id := action.trim_prefix("phone_app_")
		if not Phone.app(id).is_empty():
			_phone_app = id
			_render()
		return
	if (action.begins_with("phone_route_") or action in ["phone_work_decline","phone_work_off","phone_work_on"]) and screen == "phone":
		action_requested.emit(action)
		return
	match action:
		"phone_back":
			if screen == "phone":
				_phone_back()
		"phone":
			if screen == "pause":
				action_requested.emit("phone")
		"play":
			if screen == "title" and not _has_save:
				action_requested.emit("begin_opening")
			else:
				hide_for_game()
		"music_desk_buy","music_desk_busk","music_desk_practice","music_desk_owned","music_desk_recruit","music_desk_rehearse","music_desk_press":
			if screen=="music_desk":
				action_requested.emit(action)
		"music_desk_leave":
			if screen=="music_desk":
				hide_for_game()
				action_requested.emit(action)
		"rhythm_pad_0","rhythm_pad_1","rhythm_pad_2":
			if screen=="blue_hour_set":
				_rhythm_strike(int(action.right(1)))
		"rhythm_claim":
			if screen=="blue_hour_set" and _rhythm.passed():
				action_requested.emit("rhythm_claim")
				hide_for_game()
		"rhythm_cancel":
			if screen=="blue_hour_set":
				hide_for_game()
				action_requested.emit("rhythm_cancel")
		"street_reply_0","street_reply_1","street_leave","cal_accept","cal_complete":
			if screen=="street_contact":
				_street_contact={}
				hide_for_game()
				action_requested.emit(action)
		"interview_0", "interview_1":
			if screen=="staff_interview":
				var index:=int(action.trim_prefix("interview_"))
				if index>=0 and index<(_interview["topics"] as Array).size():
					_interview_topic=index
					_record_interview(index)
					_render()
		"terminal_open":
			if screen=="opening" and _opening_stage in [0,1]:
				_terminal_origin="opening"
				_terminal_tab="access" if _opening_stage==1 else "ticket"
				_open("workstation")
		"terminal_inbox", "terminal_ticket", "terminal_access":
			if screen=="workstation":
				_terminal_tab=action.trim_prefix("terminal_")
				_render()
		"terminal_leave":
			if screen=="workstation":
				if _terminal_origin=="opening":
					_open("opening")
				else:
					hide_for_game()
		"notes_open":
			if screen=="staff_interview" or (screen=="opening" and _opening_stage==2 and _briefing_beat==2):
				_notes_origin=screen
				_open("investigation_notes")
		"notes_back":
			if screen=="investigation_notes":
				_open(_notes_origin)
		"interview_back":
			if screen=="staff_interview":
				_interview_topic=-1
				_render()
		"interview_leave":
			if screen=="staff_interview":
				_interview.clear()
				_interview_topic=-1
				hide_for_game()
		"guard_r9", "guard_parking", "guard_robots", "guard_access", "guard_shift", "guard_layoff", "guard_followup":
			if screen=="parking_guard" and ParkingDialogue.available(action,_guard_former,_guard_contact):
				_guard_topic=action
				if action in ["guard_shift","guard_followup"]:
					action_requested.emit(action)
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
				if _physical_opening:
					action_requested.emit("opening_camera")
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
		"journal", "inventory":
			action_requested.emit(action)
		"restart_courier", "abandon_story", "home_waypoint", "garage_waypoint", "story_waypoint", "synaxis_waypoint", "cal_waypoint", "music_waypoint", "busking_waypoint":
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

## In-memory optional interview notes; no save schema, rewards or progression.
func _record_interview(index:int) -> void:
	var topic:Dictionary=_interview["topics"][index]
	var id:=str(topic["id"])+":"+str(topic.get("phase","before"))
	if _investigation_notes.has(id) or _investigation_notes.size()>=28:
		return
	_investigation_notes[id]={"name":_interview["name"],"question":topic["question"],"reply":topic["reply"]}

func open_blue_hour_set(sequence:int)->void:
	_open_music_set(sequence,"live_gig")

func open_busking_set(sequence:int)->void:
	_open_music_set(sequence,"busking")

func open_music_desk(data:Dictionary)->void:
	_music_desk=data.duplicate()
	_open("music_desk")

func open_band_booking(sequence:int,source:String)->void:
	if source in ["band_encore","band_showcase"]:
		_open_music_set(sequence,source)

func consume_band_booking(source:String)->int:
	if source in ["band_encore","band_showcase"] and screen=="blue_hour_set" and _rhythm.mode==source and _rhythm.claim():
		return _rhythm_sequence
	return 0

func open_band_debut()->void:
	_open_music_set(1,"band_debut")

func consume_band_debut()->int:
	if screen=="blue_hour_set" and _rhythm.mode=="band_debut" and _rhythm.claim():
		return _rhythm_sequence
	return 0

func open_band_rehearsal(sequence:int)->void:
	_open_music_set(sequence,"band_rehearsal")

func consume_band_rehearsal()->int:
	if screen=="blue_hour_set" and _rhythm.mode=="band_rehearsal" and _rhythm.claim():
		return _rhythm_sequence
	return 0

func open_sampler_practice(sequence:int)->void:
	_open_music_set(sequence,"practice")

func consume_sampler_practice()->int:
	if screen=="blue_hour_set" and _rhythm.mode=="practice" and _rhythm.claim():
		return _rhythm_sequence
	return 0

func _open_music_set(sequence:int,source:String)->void:
	_rhythm_sequence=sequence
	_rhythm_focus_set=false
	_stop_music_set_audio()
	_rhythm.start(sequence,source)
	_open("blue_hour_set")
	_start_music_intro()

func _stop_music_set_audio()->void:
	var preview := _root.find_child("MusicSetPreview",true,false) if is_instance_valid(_root) else null
	if is_instance_valid(preview):
		preview.get_parent().remove_child(preview)
		preview.queue_free()
	_rhythm_player.stop()
	_rhythm_intro.stop()

func _music_set_gain(headroom:float)->float:
	return linear_to_db(maxf(0.0001,clampf(float(settings.get("music_volume",0.65)),0.0,1.0))) + headroom

func _start_music_intro()->void:
	# A short authored soundcheck, not a timing track. Cut it before the
	# first playable window; the player's pad hits remain the timing cue.
	if _rhythm.mode=="practice" or float(settings.get("music_volume",0.65))<=0.0:
		return
	var band:bool=_rhythm.mode in ["band_rehearsal","band_debut","band_encore","band_showcase"]
	var source:AudioStreamWAV=BAND_INTRO if band else STREET_INTRO
	var clip:=source.duplicate() as AudioStreamWAV
	clip.loop_mode=AudioStreamWAV.LOOP_DISABLED
	_rhythm_intro.stream=clip
	_rhythm_intro.volume_db=_music_set_gain(-16.0)
	_rhythm_intro.play()

func open_owned_sampler_set(sequence:int)->void:
	_open_music_set(sequence,"owned_busking")

func consume_owned_sampler_set()->int:
	if screen=="blue_hour_set" and _rhythm.mode=="owned_busking" and _rhythm.claim():
		return _rhythm_sequence
	return 0

func consume_busking_result()->int:
	if screen=="blue_hour_set" and _rhythm.mode=="busking" and _rhythm.claim():
		return _rhythm_sequence
	return 0

func consume_blue_hour_result()->int:
	if screen=="blue_hour_set" and _rhythm.mode=="live_gig" and _rhythm.claim():
		return _rhythm_sequence
	return 0

func _render_rhythm(col:VBoxContainer)->void:
	var street:bool=_rhythm.mode=="busking"
	var practice:bool=_rhythm.mode=="practice"
	var owned:bool=_rhythm.mode=="owned_busking"
	var band:bool=_rhythm.mode=="band_rehearsal"
	var debut:bool=_rhythm.mode=="band_debut"
	var encore:bool=_rhythm.mode=="band_encore"
	var showcase:bool=_rhythm.mode=="band_showcase"
	_title(col,"STATIC ROOM / SHOWCASE" if showcase else "BLUE HOUR / TRIO ENCORE" if encore else "BLUE HOUR / TRIO DEBUT" if debut else "UNSIGNED TRIO / REHEARSAL" if band else "POCKETBEAT M3 / PERSONAL SET" if owned else ("POCKETBEAT M3 / PRACTICE" if practice else ("STREET SAMPLER / BUSKING" if street else "BLUE HOUR / OPENING SET")),24,Ui.AMBER)
	_label(col,("Headline the underground showcase. Keep the trio in sync." if showcase else "Back by demand. Play a different arrangement." if encore else "First paid trio booking. Keep the rhythm tight through the whole set." if debut else "Keep the trio in time. Rhea counts in, Milo follows. No cash or cred for rehearsal." if band else "Play your own sampler for the neighborhood." if owned else ("Practice your own sampler. No cash or reputation reward." if practice else ("Borrow the neighborhood loaner sampler." if street else "Borrow Rae's three-pad sampler.")))+" Hit the indicated pad in the timing window. %d of %d required."%[_rhythm.required_hits,_rhythm.pattern.size()],16,Ui.TEXT)
	col.add_child(MusicSetPreview.build(band or debut or encore or showcase))
	_label(col,"1 / A: kick   2 / X: clap   3 / Y: hat",16,Ui.MUTED)
	_rhythm_status=Label.new()
	_rhythm_status.add_theme_font_size_override("font_size",22)
	col.add_child(_rhythm_status)
	_rhythm_meter=ProgressBar.new()
	_rhythm_meter.max_value=1.0
	_rhythm_meter.show_percentage=false
	col.add_child(_rhythm_meter)
	for lane in range(3):
		var key:="rhythm_pad_%d"%lane
		_button(col,key,["1 / A  KICK","2 / X  CLAP","3 / Y  HI-HAT"][lane],key)
	_button(col,"rhythm_claim","COLLECT $480 / +45 STREET CRED" if showcase else "COLLECT $120 / +12 STREET CRED" if encore else "COLLECT $240 / +30 STREET CRED" if debut else "RECORD BAND REHEARSAL" if band else "COLLECT $14 / +4 STREET CRED" if owned else ("RECORD PRACTICE SET" if practice else ("COLLECT $8 / +4 STREET CRED" if street else "COLLECT $45 / +12 STREET CRED")),"rhythm_claim",false)
	_rhythm_claim=_buttons["rhythm_claim"]
	_button(col,"rhythm_cancel","LEAVE SET","rhythm_cancel")
	_refresh_rhythm()

func _process(delta:float)->void:
	if screen!="blue_hour_set":
		return
	_rhythm.advance(delta)
	if _rhythm.elapsed>=Rhythm.LEAD-_rhythm.hit_window or _rhythm.finished or _rhythm.cancelled:
		_rhythm_intro.stop()
	_refresh_rhythm()

func _input(event:InputEvent)->void:
	if screen!="blue_hour_set" or _rhythm.finished or not event.is_pressed() or event.is_echo():
		return
	for lane in range(3):
		if event.is_action_pressed(["service_one","service_two","service_three"][lane]):
			_rhythm_strike(lane)
			get_viewport().set_input_as_handled()
			return

func _rhythm_strike(lane:int)->void:
	if _rhythm.finished or _rhythm.cancelled or lane<0 or lane>=PAD_CLIPS.size():
		return
	if float(settings.get("music_volume",0.65))>0.0:
		_rhythm_player.volume_db=_music_set_gain(-8.0)
		_rhythm_player.stream=PAD_CLIPS[lane]
		_rhythm_player.play()
	_rhythm.strike(lane)
	_refresh_rhythm()

func _refresh_rhythm()->void:
	if not is_instance_valid(_rhythm_status) or not is_instance_valid(_rhythm_meter) or not is_instance_valid(_rhythm_claim):
		return
	if _rhythm.finished:
		_rhythm_status.text="%s / %d of %d correct (need %d)\nBEST STREAK %d  •  %d%% ACCURACY"%["SET COMPLETE" if _rhythm.passed() else "TRY ANOTHER SET",_rhythm.hits,_rhythm.pattern.size(),_rhythm.required_hits,_rhythm.best_combo,roundi(100.0*float(_rhythm.hits)/maxi(1,_rhythm.pattern.size()))]
		_rhythm_status.modulate=Ui.ACCENT if _rhythm.passed() else Ui.TEXT
		_rhythm_meter.value=0.0
		_rhythm_claim.disabled=not _rhythm.passed()
		if _rhythm.passed() and not _rhythm_focus_set:
			_rhythm_focus_set=true
			_rhythm_claim.grab_focus()
		return
	var remaining:float=_rhythm.target_time()-_rhythm.elapsed
	var lane:int=_rhythm.pattern[_rhythm.index]
	var window:bool=absf(remaining)<=_rhythm.hit_window
	_rhythm_status.text="%s / %s / %d of %d\n%d / %d needed  •  %s\nSTREAK %d  •  %s"%[["KICK","CLAP","HI-HAT"][lane],"HIT NOW" if window else "READY %.1fs"%maxf(0.0,remaining),_rhythm.index+1,_rhythm.pattern.size(),_rhythm.hits,_rhythm.required_hits,_rhythm.feedback,_rhythm.combo,"MISSES LEFT %d"%_rhythm.mistakes_left() if _rhythm.mistakes_left()>=0 else "PASS NO LONGER POSSIBLE"]
	_rhythm_status.modulate=Ui.ACCENT if window else Ui.TEXT
	_rhythm_meter.value=clampf(1.0-maxf(0.0,remaining)/_rhythm.beat_seconds,0.0,1.0)

## Isolated static model preview; render one frame, no continuous extra camera.
func _pocketbeat_preview(col:VBoxContainer)->void:
	var frame:=SubViewportContainer.new()
	frame.name="PocketBeatPreview"
	frame.custom_minimum_size=Vector2(360,160)
	frame.stretch=true
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	col.add_child(frame)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(480,192)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	frame.add_child(viewport)
	var model:=PocketBeat.instantiate() as Node3D
	viewport.add_child(model)
	var cam:=Camera3D.new()
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=0.29
	cam.position=Vector3(0.21,0.26,0.27)
	viewport.add_child(cam)
	cam.look_at(Vector3(0,0.028,0),Vector3.UP)
	cam.current=true
	var key:=DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-48,-32,0)
	key.light_energy=1.5
	viewport.add_child(key)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-32,145,0)
	fill.light_energy=0.85
	fill.light_color=Color("a0d6ee")
	viewport.add_child(fill)
