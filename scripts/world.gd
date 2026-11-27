extends Node3D
## NIGHTGRID: AFTERHOURS — a generated 3D city with an original courier/crime loop.

const PlayerScript = preload("res://scripts/player.gd")
const CourierVisual = preload("res://scripts/courier_visual.gd")
const PedestrianDirector = preload("res://scripts/pedestrian_director.gd")
const PedestrianRoutes = preload("res://scripts/pedestrian_routes.gd")
const PEDESTRIAN_MODELS = [
	"res://assets/models/nightgrid/pedestrians/casual-walker.glb",
	"res://assets/models/nightgrid/pedestrians/dog-walker.glb",
	"res://assets/models/nightgrid/pedestrians/road-worker.glb",
	"res://assets/models/nightgrid/pedestrians/hiker.glb",
]
const CarScript = preload("res://scripts/car.gd")
const KestrelVisual = preload("res://scripts/kestrel_s6_visual.gd")
const RoadCars = preload("res://scripts/road_car_catalog.gd")
const RoadCarVisual = preload("res://scripts/road_car_visual.gd")
const RadarScript = preload("res://scripts/hud_radar.gd")
const Ui = preload("res://scripts/ui_style.gd")
const Nav = preload("res://scripts/navigation_waypoint.gd")
const StreetRoute = preload("res://scripts/street_route.gd")
const DrivingTrial = preload("res://scripts/driving_trial.gd")
var _driving_trial := DrivingTrial.new()
var _trial_beacon: Node3D
var _trial_beacon_label: Label3D
var _trial_ghost: Node3D
var _trial_rival_visual:Node3D
const CircuitRival=preload("res://scripts/circuit_rival.gd")
var _circuit_rival:=CircuitRival.new()
const HorizonTrail=preload("res://scripts/horizon_commons_garden.gd")
var _garden_trail_mask:=0
const RoadRestrictions = preload("res://scripts/road_restrictions.gd")
const FreightJob = preload("res://scripts/freight_job.gd")
var _freight := FreightJob.new()
const CargoCase=preload("res://scripts/freight_cargo_case.gd")
var _freight_case: Node3D
const TaxiJob=preload("res://scripts/taxi_job.gd")
var _taxi:=TaxiJob.new()
const TaxiRider=preload("res://scripts/taxi_waiting_rider.gd")
var _taxi_rider:Node3D
var _taxi_visual_timer:=0.0
const Arsenal = preload("res://scripts/arsenal.gd")
const Wanted = preload("res://scripts/wanted_system.gd")
const PoliceDispatch = preload("res://scripts/police_dispatch.gd")
const AmbientCivicLedger = preload("res://scripts/ambient_civic_ledger.gd")
const CivicPatrolService = preload("res://scripts/civic_patrol_service.gd")
const PoliceRadio = preload("res://scripts/police_radio.gd")
const DialogueDirector = preload("res://scripts/dialogue_director.gd")
const StreetSatire = preload("res://scripts/street_satire.gd")
const EquipmentWheel = preload("res://scripts/equipment_wheel.gd")
const Reticle = preload("res://scripts/weapon_reticle.gd")
const CombatFoley = preload("res://scripts/city_foley.gd")
const CityDetailsScript = preload("res://scripts/city_details.gd")
const CityPerimeterScript = preload("res://scripts/city_perimeter.gd")
const DayNightScript = preload("res://scripts/day_night.gd")
const FloraScript = preload("res://scripts/flora.gd")
const Materials = preload("res://scripts/material_library.gd")
const NightLightingScript = preload("res://scripts/night_lighting.gd")
const WetStreetsScript = preload("res://scripts/wet_streets.gd")
const HeroIntersectionScript = preload("res://scripts/central_exchange_hero.gd")
const PhotoRoadNetwork = preload("res://scripts/photo_road_network.gd")
const TrafficSignalsScript = preload("res://scripts/traffic_signals.gd")
const TrafficSystemScript = preload("res://scripts/traffic_system.gd")
const RailSystemScript = preload("res://scripts/rail_system.gd")
const VenueSystemScript = preload("res://scripts/venue_system.gd")
const CivicServicesScript = preload("res://scripts/civic_services.gd")
const InteriorSystemScript = preload("res://scripts/interior_system.gd")
const GameInput = preload("res://scripts/game_input.gd")
const GameMenuScript = preload("res://scripts/game_menu.gd")
const NightGridFMScript = preload("res://scripts/nightgrid_fm.gd")
const WorldAudioScript = preload("res://scripts/world_audio.gd")
const AudioMix = preload("res://scripts/audio_mix.gd")
const FrameTimeRecorder = preload("res://scripts/frame_time_recorder.gd")
const BrickwaterRepair = preload("res://scripts/brickwater_storefront.gd")
const StreamProfile = preload("res://scripts/streaming_profile.gd")
const PlaytestEvidence = preload("res://scripts/playtest_evidence.gd")
const PlaytestLogger = preload("res://scripts/playtest_logger.gd")
const BuildInfo = preload("res://scripts/build_info.gd")
const CELL = 58.0
const GRID_RADIUS = 4
const PLAYER_START = Vector3(0.0, 1.15, 6.0)
const VEHICLE_COLORS = [
	Color("f04e59"), Color("40b1ff"), Color("e9bf51"),
	Color("9b75e7"), Color("dedee0"), Color("58c99e")
]
const CourierMission = preload("res://scripts/courier_mission.gd")
const StoryMission = preload("res://scripts/story_mission.gd")
const Opening = preload("res://scripts/opening_story.gd")
const OpeningOffice = preload("res://scripts/synaxis_office.gd")
var _opening_office: Node3D
const StarterHome = preload("res://scripts/starter_home.gd")
var _home_panel := false
var _storage_upgrade_quote := false
var _wardrobe_panel := false
var _clothing_retail := false
var _retail_id:=""
var _retail_stock:Array=[]
var _retail_day:=0
var _fitting_yaw:=0.0
var _fitting_rotation:=0.0
var _fitting_zoom:=0.0
var _fitting_compare:=false
var _wardrobe_category:="ALL"
var _look_index:=0
var _look_save_pending:=false
var _wardrobe_controls:HBoxContainer
var _wardrobe_category_label:Label
var _wardrobe_compare_button:Button
const ClothingStore = preload("res://scripts/clothing_store.gd")
var _wardrobe_index := 0
var _wardrobe_quote_id := ""
var _wardrobe_tender := "USD"
var _exchange_panel := false
var _tenancy_panel := false
const Economy = preload("res://scripts/economy.gd")
const Wardrobe = preload("res://scripts/wardrobe_catalog.gd")
const StarterGarage = preload("res://scripts/starter_garage.gd")
var _garage_panel := false
# Transient quote; never serialized, never charges on selection.
var _title_offer_id := ""
var _title_quote_id := ""
var _sale_offer_id := ""
var _sale_quote_id := ""
var _sale_quote_amount := 0

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var current_car: CharacterBody3D
var cars: Array[CharacterBody3D] = []
var officers: Array[CharacterBody3D] = []
var routine_patrols: Array[CharacterBody3D] = []
var wanted = Wanted.new()
var dispatch = PoliceDispatch.new()
var ambient_civic = AmbientCivicLedger.new()
var civic_patrol_service = CivicPatrolService.new()
var _civic_patrol: CharacterBody3D
var _civic_patrol_poll := 0.0
var police_radio: Node
var dialogue_director: Node3D
var _dialogue_card: PanelContainer
var _dialogue_caption: Label
var _radio_caption: Label
var _radio_card: PanelContainer
var _radio_close_tail := 0.0
var _radio_was_wanted := false
var _civic_radio_announced: Dictionary = {}
var _receiver_sites: Array[Dictionary] = []
var returning_units: Array[CharacterBody3D] = []
var _sight_clock := 0.0
var _wanted_label: Label
var _pending_theft: Variant = null
var camera: Camera3D
var _cinder_cockpit := false
var _cockpit_look := Vector2.ZERO
var _cockpit_camera_active := false
var marker: Node3D
var marker_light: OmniLight3D
var hud_label: Label
var hud_objective: Label
var hud_navigation: Label
var weapons = Arsenal.new()
var weapon_aiming := false
var _fire_held := true
var _hit_feedback := 0.0
var _weapon_audio: AudioStreamPlayer3D
var _weapon_card: PanelContainer
var equipment_wheel: Control
var _weapon_label: Label
var _reticle: Control
var navigation_waypoint: Variant = null
var _vehicle_job_waypoint_owner := ""
var road_restrictions = RoadRestrictions.new()
var _route_revision := -1
var _route_cache: Dictionary = {}
var _route_origin := Vector2.INF
var _route_target := Vector2.INF
var hud_jobs: Label
var hud_location: Label
var hud_health: ProgressBar
var hud_prompt: Label
var hud_prompt_card: PanelContainer
var hud_notice: Label
var hud_notice_card: PanelContainer
var hud_drive_card: PanelContainer
var hud_drive_name: Label
var hud_drive_speed: Label
var hud_drive_radio: Label
var show_control_hints := true
var show_hud_inventory := true
var performance_label: Label
var performance_overlay := false
var minimap: Control
var city_details: Node3D
var pedestrians: Node3D
var _pedestrian_scan := 0.0
var _street_contact_id:=""
var _cal_pending:Dictionary={}
var _cal_tracking:=false
var _cal_nav_clock:=0.0
const CAL_PICKUP="moon_noodles"
const BUSKING_SITES=["moon_noodles","copper_cup"]
var _music_session_site:=""
const Instruments=preload("res://scripts/instrument_catalog.gd")
var city_perimeter: Node3D
var flora: Node3D
var day_night: Node
var street_lights: Node3D
var wet_streets: Node3D
var hero_intersection: Node3D
var signal_controller: Node3D
var traffic: Node3D
var rail: Node3D
var venue_system: Node3D
var civic_services: Node3D
var interiors: Node3D
var game_menu: CanvasLayer
var _arcade_layer: CanvasLayer
var _arcade_best: Dictionary = {}
const ArcadeScreen = preload("res://scenes/arcade_pilot.tscn")
const ArcadeScores = preload("res://scripts/arcade_scores.gd")
const ArcadeCircuit = preload("res://scripts/arcade_circuit_board.gd")
var nightgrid_fm: Node
var world_audio: Node
var frame_time_recorder = FrameTimeRecorder.new()
var playtest_logger = PlaytestLogger.new()
var _capturing_evidence := false
var gamepad_active := false
var mouse_sensitivity := 0.0032
var stick_sensitivity := 2.6
var invert_look_y := false
var civic_selected_id := ""
const TechnicalContracts = preload("res://scripts/technical_contracts.gd")
var _technical_case_open := false
var _technical_feedback := ""
const IndependentInvestigation = preload("res://scripts/independent_investigation.gd")
var investigation := IndependentInvestigation.new()
var _investigation_open := false
var _investigation_feedback := ""
var civic_job_active := ""
var civic_job_completed: Array[String] = []
var civic_intel: Array[String] = []
const Consumables = preload("res://scripts/consumables.gd")
var ration_packs := 0
var consumable_inventory: Dictionary = {}
var _vending_machine: Node3D
var hud_stamina: ProgressBar
var venue_panel: PanelContainer
var venue_label: Label
var venue_service_button: Button
var venue_job_button: Button
var venue_talk_button: Button
var venue_close_button: Button
var mara_dialogue_line := ""
const DialogueCaption = preload("res://scripts/dialogue_caption.gd")
var ambient_caption: PanelContainer
var contact_caption: PanelContainer
var venue_selected_id := ""
var _repair_panel := false
var _pooled_traffic_enabled := false
var venue_job_active := ""
var venue_job_completed: Array[String] = []
var _venue_clock_tick := 0.0
# Stream/city lights and HUD need not update at the monitor's refresh rate.
var _focus_update_clock := 1.0
var _hud_update_clock := 1.0
var current_transit: Node3D
var transit_kind := ""
var _active_station_lift: Node3D
var _rail_platform_rider := false
var _camera_probe := PhysicsShapeQueryParameters3D.new()
var session: Node
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var yaw := 0.0
var pitch := 0.42
const ProgressionLedger = preload("res://scripts/progression_ledger.gd")
const SceneReputation = preload("res://scripts/scene_reputation.gd")
var progression := ProgressionLedger.new()
# Keep the existing HUD/test/gameplay cash interface; one live wallet owns it.
var cash: int:
	get:
		return progression.balance
	set(value):
		progression.set_balance(value)
var health := 100.0
var heat := 0.0
var courier_mission := CourierMission.new()
var story_mission := StoryMission.new()
# Compatibility accessors for HUD and existing save fields.
var deliveries: int:
	get:
		return courier_mission.completed_runs
var carrying: bool:
	get:
		return courier_mission.has_package()
var mission_position := Vector3.ZERO
var notification := "Morrow Bay / Find your next shift. Follow the delivery marker."
var notification_time := 8.0
var police_cooldown := 4.0

func _ready() -> void:
	var clearance_ball := SphereShape3D.new()
	clearance_ball.radius = 0.30
	_camera_probe.shape = clearance_ball
	_camera_probe.margin = 0.02
	_camera_probe.collision_mask = 1
	GameInput.install()
	AudioMix.ensure()
	session = get_node("/root/GameSession")
	# Diagnostics stay local, capped and silent on headless CI. Capture startup
	# before loading the world so real Windows sessions have a known baseline.
	if DisplayServer.get_name() != "headless":
		var path: String = playtest_logger.start_session(int(session.get("world_seed")), {
			"release_version": BuildInfo.VERSION,
			"build_channel": BuildInfo.CHANNEL,
			"build_revision": BuildInfo.REVISION
		})
		if not path.is_empty():
			print("NIGHTGRID_PLAYTEST_LOG: ", path)
	rng.seed = int(session.get("world_seed"))
	_build_environment()
	_build_city()
	_build_city_perimeter()
	_build_world_systems()
	_create_player()
	_spawn_traffic()
	_build_transport()
	_register_police_stations()
	_configure_ambient_civic()
	_build_routine_patrols()
	_create_camera()
	if "--living-streets" in OS.get_cmdline_user_args():
		enable_living_streets()
	_create_marker()
	_create_trial_beacon()
	_build_hud()
	_build_game_menu()
	_build_nightgrid_fm()
	_build_world_audio()
	police_radio = PoliceRadio.new()
	police_radio.name = "PoliceRadio"
	add_child(police_radio)
	dialogue_director = DialogueDirector.new()
	dialogue_director.name = "DialogueDirector"
	add_child(dialogue_director)
	dialogue_director.connect("caption_changed", _show_dialogue_caption)
	for line in StreetSatire.LINES:
		dialogue_director.call("prewarm",str(line["id"]))
	var restore: Dictionary = session.call("take_pending_restore")
	if restore.is_empty():
		_refresh_courier_target()
	else:
		_apply_snapshot(restore)
		if current_transit == null:
			_resume_restored_actor_after_collision_sync(current_car if current_car != null else player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if bool(session.get("opening_pending")) and restore.is_empty():
		session.set("opening_pending",false)
		_start_opening_office()
	elif DisplayServer.get_name() != "headless" and not bool(session.get("boot_menu_shown")):
		session.set("boot_menu_shown", true)
		game_menu.call("open_title")
	_log_playtest("world_ready", {"restored": not restore.is_empty()})

func _resume_restored_actor_after_collision_sync(actor: CharacterBody3D) -> void:
	# A newly rebuilt world's traffic colliders can still be at their initial
	# physics-server transforms on the first tick. Skip that movement step so
	# kinematic recovery cannot push a restored actor away from the saved point.
	actor.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(actor):
		actor.set_physics_process(true)

func _exit_tree() -> void:
	playtest_logger.end_session()

func _log_playtest(name: String, details: Dictionary = {}) -> void:
	if not playtest_logger.is_active() or not is_instance_valid(player):
		return
	var actor := _actor()
	var indoors: bool = interiors != null and interiors.call("is_inside")
	var street: Vector3 = interiors.get("exterior_position") if indoors else actor.global_position
	var context := {
		"x": snappedf(actor.global_position.x, 0.01),
		"y": snappedf(actor.global_position.y, 0.01),
		"z": snappedf(actor.global_position.z, 0.01),
		"district": city_details.call("get_district_at", street),
		"clock": day_night.call("clock_string"),
		"render_profile": str(day_night.call("get_render_profile")),
		"indoors": indoors,
		"mode": "car" if current_car != null else ("transit_" + transit_kind.to_lower() if current_transit != null else "on_foot")
	}
	if is_instance_valid(_opening_office):
		context["chapter"]=_opening_diagnostic_context()
		context["indoors"]=_inside_opening_hq()
	if current_car != null:
		context["speed_kph"] = current_car.call("speed_kph")
	if name == "manual_marker":
		# Capture a full snapshot only on F7; never incur a SceneTree walk on
		# ordinary gameplay frames or continuous frame-time recording.
		context["render_batch_stats"] = city_details.call("get_render_batch_stats")
		context["practical_light_stats"] = street_lights.call("get_practical_light_stats")
	playtest_logger.record_event(name, {"context": context, "details": details})

func _build_game_menu() -> void:
	game_menu = GameMenuScript.new()
	game_menu.name = "GameMenus"
	add_child(game_menu)
	game_menu.call("set_world_node", self)
	game_menu.connect("action_requested", Callable(self, "_on_menu_action"))
	game_menu.connect("settings_changed", Callable(self, "_apply_game_settings"))
	game_menu.call("set_has_save", not (session.call("read_snapshot") as Dictionary).is_empty())
	_apply_game_settings(game_menu.call("get_settings"))

func _build_nightgrid_fm() -> void:
	nightgrid_fm = NightGridFMScript.new()
	nightgrid_fm.name = "NightGridFM"
	nightgrid_fm.set("venues", venue_system)
	nightgrid_fm.set("menu", game_menu)
	add_child(nightgrid_fm)
	var options: Dictionary = game_menu.call("get_settings")
	nightgrid_fm.call("set_preferences", float(options.get("music_volume", 0.65)), bool(options.get("radio_on", true)))

func _update_police_radio(delta: float) -> void:
	if not is_instance_valid(police_radio):
		return
	var active := Wanted.stars(heat) > 0
	if _radio_was_wanted and not active:
		# Drain the closing sequence, bounded even if new messages keep arriving.
		_radio_close_tail = 20.0
	_radio_was_wanted = active
	_radio_close_tail = maxf(0.0, _radio_close_tail - delta)
	var station: Dictionary = {}
	var receiver := Vector3.INF
	if bool(interiors.call("is_inside")) and str(interiors.call("active_site_group")) == "CIVIC":
		station = civic_services.call("site_by_id", str(interiors.call("active_site_id")))
	var in_station := station.has("station_id")
	if in_station:
		receiver = (interiors.call("get_counter_point") as Vector3) + Vector3(0.75, 0.3, 0.25)
	elif not active and not bool(interiors.call("is_inside")):
		for site in _receiver_sites:
			var address: Vector3 = site["address"]
			if player.global_position.distance_squared_to(address) < 12.0 * 12.0:
				station = {"station_id": site["id"], "headquarters": site["hq"]}
				receiver = address + Vector3.UP * 0.7
				break
	police_radio.call("ingest", dispatch.history)
	police_radio.call("update_state", active, wanted.police_seen, delta)
	var closing := _radio_close_tail > 0.0 and bool(police_radio.call("has_traffic"))
	var local_receiver := receiver.is_finite() and not active and not closing
	if local_receiver and not bool(day_night.get("paused")):
		_announce_civic_at_station(station)
	police_radio.call("set_receiver", receiver if local_receiver else Vector3.INF)
	police_radio.call("tick", delta, active or local_receiver or closing)
	if is_instance_valid(nightgrid_fm):
		nightgrid_fm.set("dialogue_active", bool(police_radio.call("speaking")) or (is_instance_valid(dialogue_director) and bool(dialogue_director.call("speaking"))))
	if not active and not bool(police_radio.call("has_traffic")):
		_radio_close_tail = 0.0
	var caption: String = police_radio.get("current")
	_radio_card.visible = not caption.is_empty()
	_radio_caption.text = caption
	if in_station:
		interiors.call("update_dispatch_board", dispatch.status() + " / CIVIC %d / %s" % [ambient_civic.open_count(), str(civic_patrol_service.task.get("phase", "PATROL"))], officers.size(), returning_units.size(), caption)

func _announce_civic_at_station(station: Dictionary) -> void:
	# Administrative requests only: no invented unit arrival or resolution.
	# Never compete with active player dispatch or its closing sequence.
	if not station.has("station_id") or bool(police_radio.call("has_traffic")):
		return
	var cases: Array[Dictionary] = ambient_civic.catalog()
	var retained := {}
	for incident in cases:
		var id := str(incident["id"])
		if _civic_radio_announced.has(id):
			retained[id] = true
	_civic_radio_announced = retained
	for incident in cases:
		var id := str(incident["id"])
		if _civic_radio_announced.has(id) or incident["state"] == "RESOLVED":
			continue
		if not bool(station.get("headquarters", false)) and incident["station_id"] != station["station_id"]:
			continue
		var kind: String = {"MOTORIST ASSISTANCE":"CIVICMOTORIST", "TRAFFIC SERVICE":"CIVICTRAFFIC", "PUBLIC SERVICE REQUEST":"CIVICPUBLIC"}.get(str(incident["kind"]), "")
		if kind.is_empty():
			continue
		var detail := "%s / %s / %s" % [id, str(incident["station_id"]).to_upper(), str(incident["district"])]
		police_radio.call("enqueue", kind, detail)
		_civic_radio_announced[id] = true
		return

func _build_world_audio() -> void:
	world_audio = WorldAudioScript.new()
	world_audio.name = "WorldAudio"
	world_audio.set("menu", game_menu)
	add_child(world_audio)
	_receiver_sites = civic_services.call("police_station_sites")
	world_audio.call("set_traffic", traffic)
	world_audio.call("set_pedestrians", pedestrians)
	var options: Dictionary = game_menu.call("get_settings")
	world_audio.call("set_preferences", float(options.get("ambience_volume", 0.65)),
		float(options.get("sfx_volume", 0.75)))

func _on_menu_action(action: String) -> void:
	if action in ["phone_work_off","phone_work_on"]:
		_phone_set_duty(action == "phone_work_on")
		return
	if action == "phone_work_decline":
		_phone_decline_order()
		return
	if action.begins_with("phone_route_"):
		_phone_route(action)
		return
	if action == "phone":
		_open_phone(true)
		return
	if action.begins_with("fashion_waypoint:"):
		var id:=action.trim_prefix("fashion_waypoint:")
		if ClothingStore.STORES.has(id):
			var entry:=ClothingStore.entry(id)
			set_navigation_waypoint(Vector2(entry.x,entry.z))
			_notify("Route set to "+str(ClothingStore.STORES[id]["name"]))
		game_menu.call("open_journal",_journal_context())
		return
	if action.begins_with("music_desk_name:"):
		_music_desk_action(action)
		return
	match action:
		"cal_accept","cal_complete":
			if not _street_contact_id.is_empty():
				_cal_pending={"id":_street_contact_id,"action":action}
			_street_contact_id=""
		"music_desk_buy","music_desk_busk","music_desk_practice","music_desk_owned","music_desk_recruit","music_desk_rehearse","music_desk_press","music_desk_leave":
			_music_desk_action(action)
		"rhythm_claim":
			var site:=_music_session_site
			_music_session_site=""
			if site=="band_rehearsal:copper_cup":
				var sequence:int=game_menu.call("consume_band_rehearsal")
				if sequence>0 and _busking_reachable("copper_cup") and progression.complete_band_rehearsal(sequence):
					_notify(progression.band_summary())
				else:
					_notify("BAND REHEARSAL / Set not recorded.")
			elif site=="practice:copper_cup":
				var sequence:int=game_menu.call("consume_sampler_practice")
				if sequence>0 and _busking_reachable("copper_cup") and progression.complete_sampler_practice(sequence):
					_notify(progression.instrument_summary())
				else:
					_notify("PRACTICE / Set not recorded.")
			elif site=="owned:copper_cup":
				var sequence:int=game_menu.call("consume_owned_sampler_set")
				if sequence>0 and _busking_reachable("copper_cup") and progression.settle_owned_sampler_set(sequence):
					_notify("PERSONAL SET / +$14 • +4 STREET CRED")
				else:
					_notify("PERSONAL SET / Not settled.")
			elif site in BUSKING_SITES:
				var sequence:int=game_menu.call("consume_busking_result")
				if sequence>0 and _busking_reachable(site) and progression.settle_busking_set(sequence):
					_notify("BUSKING / SET COMPLETE +$8 • +4 STREET CRED")
				else:
					_notify("BUSKING / Set not settled.")
			elif site=="band_encore:blue_hour":
				var sequence:int=game_menu.call("consume_band_booking","band_encore")
				if sequence>0 and _blue_hour_set_reachable() and progression.settle_band_encore(sequence):
					_notify("BLUE HOUR / ENCORE +$120 • +12 STREET CRED • "+progression.band_merch_summary())
				else:
					_notify("ENCORE / Not settled. Retry the booking.")
			elif site=="band_showcase:static_room":
				var sequence:int=game_menu.call("consume_band_booking","band_showcase")
				if sequence==1 and _band_contact_reachable("static_room") and progression.settle_band_showcase():
					_notify("STATIC ROOM / SHOWCASE +$480 • +45 STREET CRED • "+progression.band_merch_summary())
				else:
					_notify("SHOWCASE / Not settled. Retry the booking.")
			elif site=="band_debut:blue_hour":
				var sequence:int=game_menu.call("consume_band_debut")
				if sequence==1 and _blue_hour_set_reachable() and progression.settle_band_debut():
					_notify("BLUE HOUR / TRIO DEBUT +$240 • +30 STREET CRED")
				else:
					_notify("TRIO DEBUT / Not settled. Retry the booking.")
			elif site=="blue_hour":
				var sequence:int=game_menu.call("consume_blue_hour_result")
				if sequence>0 and _blue_hour_set_reachable() and progression.settle_blue_hour_set(sequence):
					_notify("BLUE HOUR / SET COMPLETE +$45 • +12 STREET CRED")
				else:
					_notify("BLUE HOUR / Set not settled.")
		"rhythm_cancel":
			_music_session_site=""
			_notify("MUSIC / Set ended. No reward.")
		"busking_waypoint":
			var site:="moon_noodles" if venue_system.call("is_open","moon_noodles") or not venue_system.call("is_open","copper_cup") else "copper_cup"
			var point:Vector3=venue_system.call("venue_position",site)
			set_navigation_waypoint(Vector2(point.x,point.z))
			game_menu.call("open_journal",_journal_context())
		"music_waypoint":
			if progression.street_cred()>=100 and not progression.has_receipt("venue:soundcheck_pass"):
				var point:Vector3=venue_system.call("venue_position","blue_hour" if venue_job_active=="soundcheck_pass" else "static_room")
				set_navigation_waypoint(Vector2(point.x,point.z))
			game_menu.call("open_journal",_journal_context())
		"cal_waypoint":
			_track_cal_waypoint()
			game_menu.call("open_journal",_journal_context())
		"street_reply_0","street_reply_1":
			if _street_contact_id==StreetSatire.STANKY_ID:
				_play_stanky_reply(0 if action=="street_reply_0" else 1)
			elif is_instance_valid(pedestrians) and not _street_contact_id.is_empty():
				pedestrians.call("request_player_reply",_street_contact_id,0 if action=="street_reply_0" else 1)
			_street_contact_id=""
		"street_leave":
			if _street_contact_id==StreetSatire.STANKY_ID:
				var legend:Node3D=venue_system.call("daddy_stanky_near",player.global_position)
				if is_instance_valid(legend):
					legend.call("set_attention_target",Vector3.ZERO,false)
			_street_contact_id=""
		"begin_opening":
			if not progression.has_receipt(Opening.RECEIPT):
				_start_opening_office()
			else:
				game_menu.call("hide_for_game")
		"guard_shift", "guard_followup":
			# Only the real local actor can update the contact; menu actions alone
			# do not grant progress, access, or money.
			if game_menu.get("screen")=="parking_guard" and _parking_guard_near():
				if action=="guard_shift":
					progression.meet_synaxis_contact()
				elif bool(game_menu.get("_guard_former")):
					progression.complete_synaxis_checkin()
				game_menu.set("_guard_contact",progression.synaxis_contact)
		"guard_leave":
			_snap_camera()
		"restroom_leave":
			if is_instance_valid(_opening_office):
				_snap_camera()
		"breakroom_leave":
			if is_instance_valid(_opening_office):
				_opening_office.call("mark_breakroom_seen")
				_snap_camera()
		"opening_walk":
			if is_instance_valid(_opening_office):
				_opening_office.call("end_dialogue")
				_opening_office.call("set_stage",int(game_menu.get("_opening_stage")))
				_snap_camera()
		"opening_camera":
			if is_instance_valid(_opening_office):
				_opening_office.call("dialogue_camera",camera,int(game_menu.get("_opening_stage")),int(game_menu.get("_briefing_beat")))
		"accept_opening":
			_accept_opening()
		"save":
			_save_game()
		"save_waypoint":
			var entrance := StarterHome.entry()
			set_navigation_waypoint(Vector2(entrance.x, entrance.z))
			game_menu.call("hide_for_game")
			_notify("Route set to Lantern Court / save point.")
		"load":
			_load_game()
		"new":
			_new_game()
		"journal":
			game_menu.call("open_journal", _journal_context())
		"inventory":
			game_menu.call("open_inventory", _journal_context())
		"restart_courier":
			if courier_mission.restart():
				_refresh_courier_target()
				_notify("Package abandoned. Return to the pickup to retry.")
			game_menu.call("open_journal", _journal_context())
		"story_waypoint":
			if story_mission.status != "complete":
				var target := _story_target()
				if target.is_finite():
					set_navigation_waypoint(Vector2(target.x,target.z))
			game_menu.call("open_journal", _journal_context())
		"garage_waypoint":
			if progression.owns_home():
				var entry := StarterGarage.entry()
				set_navigation_waypoint(Vector2(entry.x,entry.z))
			if game_menu.get("screen") == "inventory":
				game_menu.call("open_inventory", _journal_context())
			else:
				game_menu.call("open_journal", _journal_context())
		"synaxis_waypoint":
			set_navigation_waypoint(Vector2(OpeningOffice.ENTRY.x,OpeningOffice.ENTRY.z))
			game_menu.call("open_journal",_journal_context())
		"home_waypoint":
			if progression.has_receipt(StarterHome.ACCESS_RECEIPT):
				var entry := StarterHome.entry()
				set_navigation_waypoint(Vector2(entry.x, entry.z))
			game_menu.call("open_journal", _journal_context())
		"abandon_story":
			if story_mission.interrupt("abandoned"):
				_notify("Contact mission abandoned. Speak to Mara to retry.")
			game_menu.call("open_journal", _journal_context())

func _start_opening_office() -> void:
	if is_instance_valid(_opening_office) or progression.has_receipt(Opening.RECEIPT):
		return
	city_details.call("set_focus",OpeningOffice.ENTRY)
	_opening_office = city_details.call("synaxis_headquarters")
	if not is_instance_valid(_opening_office):
		# Fail safely to the accessible dialogue rather than strand a new game.
		game_menu.call("open_opening")
		return
	if is_instance_valid(dialogue_director):
		dialogue_director.call("cancel_all")
	_cancel_street_interactions()
	_opening_office.call("begin_prologue")
	player.get("visual").call("set_corporate_attire",true)
	player.global_position = _opening_office.to_global(OpeningOffice.START)
	player.velocity = Vector3.ZERO
	yaw = 0.0
	player.set("camera_yaw",yaw)
	get_node("HUD").hide()
	marker.hide()
	game_menu.call("open_opening",true)
	_opening_office.call("start_arrival",player,camera)

func _opening_interact() -> void:
	if not is_instance_valid(_opening_office) or game_menu.call("is_open"):
		return
	if _opening_office.call("arrival_active"):
		_opening_office.call("finish_arrival",player,camera)
		_snap_camera()
		return
	if _opening_office.call("lift_active"):
		return
	if _opening_office.call("exit_active"):
		_opening_office.call("try_exit_step",player)
		return
	if _opening_office.call("try_lift",player):
		return
	if _opening_office.call("try_office_service",player.global_position):
		player.call("play_visual_action",&"interact")
		return
	if _opening_office.call("parking_guard_reachable",player.global_position):
		game_menu.call("open_parking_guard",false,progression.synaxis_contact)
		return
	if not _opening_office.call("errand_complete"):
		if _opening_office.call("try_errand",player):
			return
	var stage := int(game_menu.get("_opening_stage"))
	if _opening_office.call("breakroom_reachable",player.global_position) and not bool(_opening_office.get("_breakroom_seen")):
		_opening_office.call("breakroom_camera",camera)
		game_menu.call("open_breakroom")
		return
	if _opening_office.call("errand_complete") and _opening_office.call("reachable",stage,player.global_position):
		if stage in [2,4]:
			_opening_office.call("dialogue_camera",camera,stage,int(game_menu.get("_briefing_beat")))
		game_menu.call("open_opening_stage")
		return
	if _opening_office.call("terminal_reachable",player.global_position):
		game_menu.call("open_cubicle_terminal")
		return
	# Optional interviews are subordinate to lift, folder, and main objective
	# interactions, and never mutate the main opening stage or economy.
	var objective: int = _opening_office.call("objective_stage",stage)
	var interview: Dictionary = _opening_office.call("interview_at",player.global_position,objective)
	if not interview.is_empty():
		game_menu.call("open_staff_interview",interview)

func _finish_opening_office() -> void:
	if not is_instance_valid(_opening_office):
		return
	var old := _opening_office
	_opening_office = null
	old.call("finish_prologue")
	player.get("visual").call("set_corporate_attire",false)
	player.global_position = OpeningOffice.ENTRY
	player.velocity = Vector3.ZERO
	player.call("restore_stamina",100.0)
	get_node("HUD").show()
	marker.show()
	city_details.call("set_focus",player.global_position)
	_snap_camera()

func _accept_opening() -> void:
	if is_instance_valid(_opening_office):
		if not _opening_office.call("exit_active"):
			if int(game_menu.get("_opening_stage"))==5:
				_opening_office.call("begin_exit",player.global_position)
			return
		if not _opening_office.call("exit_ready",player.global_position):
			return
	if progression.credit_once(Opening.RECEIPT,Opening.SEVERANCE):
		_finish_opening_office()
		courier_mission.gig_economy = true
		_refresh_courier_target()
		_notify("SYNAXIS: $75 severance credited. QUOTADROP: Your first delivery is ready. Earn your pod deposit.")

# Resolve from existing venue/route contracts, never save another position.
func _story_target() -> Vector3:
	if story_mission.status == "complete":
		return Vector3.INF
	if story_mission.step == 1:
		return mission_position if courier_mission.mission_active() else Vector3.INF
	return venue_system.call("venue_position", "lantern_cup")

func phone_available() -> bool:
	return is_instance_valid(player) and not is_instance_valid(_opening_office) and current_car == null and current_transit == null and not is_instance_valid(_arcade_layer) and _music_session_site.is_empty() and not venue_panel.visible and not equipment_wheel.visible

func _open_phone(from_pause: bool) -> void:
	if not phone_available():
		_notify("Use your phone on foot, outside an active conversation.")
		return
	if from_pause and game_menu.get("screen") != "pause":
		return
	game_menu.call("open_phone", _phone_context(), from_pause)

func _phone_nearest(points: Array, origin: Vector2) -> Vector2:
	var best := Vector2.INF
	var distance := INF
	for point in points:
		if not point is Vector2 or not point.is_finite():
			continue
		var gap: float = origin.distance_to(point)
		if gap < distance:
			distance = gap
			best = point
	return best

func _phone_transit() -> Dictionary:
	var outside: Vector3 = interiors.get("exterior_position") if interiors.call("is_inside") else player.global_position
	var origin := Vector2(outside.x, outside.z)
	return {"origin":origin, "rail":_phone_nearest(rail.call("get_map_stations"),origin), "bus":_phone_nearest(traffic.call("get_map_stops"),origin)}

# Existing authored contracts remain the authority for offers, receipts, and payouts.
# Phone browsing only exposes a destination; acceptance happens at the counter.
func _phone_workboard() -> Array[Dictionary]:
	var listings: Array[Dictionary] = []
	for category in ["local","civic"]:
		var local: bool = category == "local"
		var active: String = venue_job_active if local else civic_job_active
		var completed: Array[String] = venue_job_completed if local else civic_job_completed
		var service: Node = venue_system if local else civic_services
		var catalog: Array = VenueSystemScript.SIDE_JOBS if local else CivicServicesScript.WORK_ORDERS
		for job in catalog:
			var id: String = job["id"]
			if completed.has(id) or progression.has_receipt(("venue:" if local else "civic:")+id):
				continue
			if not active.is_empty() and id != active:
				continue
			if local and id != active and not venue_system.call("job_unlocked",job,progression.street_cred()):
				continue
			var site: String = job["to"] if id == active else job["from"]
			var record: Dictionary = service.call("venue_by_id" if local else "site_by_id",site)
			if record.is_empty():
				continue
			var position: Vector3 = service.call("venue_position" if local else "position_for",site)
			if not position.is_finite():
				continue
			listings.append({
				"id":category+":"+id,"category":"Private contact" if local else "Civic contract",
				"title":job["title"],"brief":str(job.get("brief",job["title"])),"reward":job["reward"],
				"site":record["name"],"open":service.call("is_open",site),
				"active":id == active,"position":Vector2(position.x,position.z)
			})
	var freight_offer:=_freight.route if _freight.active else FreightJob.offer(progression.freight_runs)
	if not freight_offer.is_empty():
		var freight_site:String=freight_offer["to"] if _freight.active else freight_offer["from"]
		var depot:Dictionary=civic_services.call("site_by_id",freight_site)
		listings.append({"id":"freight:current","category":"Vehicle freight","title":freight_offer["name"],"brief":"Stop a civilian Kestrel S6 at the loading point. G/X to load or unload; same vehicle required.","reward":freight_offer["reward"],"site":depot["name"],"open":true,"active":_freight.active,"position":freight_offer["drop"] if _freight.active else freight_offer["pickup"],"action_label":"Deliver freight" if _freight.active else "Navigate to loading point"})
	var taxi_offer:=_taxi.route if _taxi.active else TaxiJob.offer(progression.taxi_runs)
	if not taxi_offer.is_empty():
		var taxi_site:String=taxi_offer["to"] if _taxi.active else taxi_offer["from"]
		var taxi_venue:Dictionary=venue_system.call("venue_by_id",taxi_site)
		listings.append({"id":"taxi:current","category":"Passenger fare","title":taxi_offer["name"],"brief":"Civilian Kestrel, condition 50+, stop for G/X pickup or drop-off. Four-minute fare.","reward":taxi_offer["reward"],"site":taxi_venue["name"],"open":true,"active":_taxi.active,"position":taxi_offer["drop"] if _taxi.active else taxi_offer["pickup"],"action_label":"Passenger destination" if _taxi.active else "Find waiting rider"})
	for site in TechnicalContracts.CASES:
		if not TechnicalContracts.available(site,progression):
			continue
		var contract: Dictionary = TechnicalContracts.CASES[site]
		var record: Dictionary = civic_services.call("site_by_id",site)
		var point: Vector3 = civic_services.call("position_for",site)
		if record.is_empty() or not point.is_finite():
			continue
		listings.append({"id":contract["id"],"category":"Technical consulting","title":contract["title"],"brief":contract["brief"],"reward":contract["reward"],"site":record["name"],"open":civic_services.call("is_open",site),"active":false,"position":Vector2(point.x,point.z),"action_label":"Visit for diagnosis"})
	var lead: Dictionary = investigation.current(progression)
	if not lead.is_empty():
		var site: String = lead["site"]
		var record: Dictionary = civic_services.call("site_by_id",site)
		var point: Vector3 = civic_services.call("position_for",site)
		if not record.is_empty() and point.is_finite():
			listings.append({"id":IndependentInvestigation.ID,"category":"Independent investigation","title":IndependentInvestigation.TITLE,"brief":lead["title"],"reward":IndependentInvestigation.REWARD,"site":record["name"],"open":civic_services.call("is_open",site),"active":investigation.stage>0,"position":Vector2(point.x,point.z),"action_label":"Follow evidence"})
	return listings

func _phone_context() -> Dictionary:
	var transit := _phone_transit()
	var origin: Vector2 = transit["origin"]
	var rail_point: Vector2 = transit["rail"]
	var bus_point: Vector2 = transit["bus"]
	return {
		"clock":day_night.call("clock_string"), "gig":courier_mission.gig_economy,
		"offboarded":progression.has_receipt(Opening.RECEIPT), "order":courier_mission.objective()["title"],
		"carrying":carrying, "payout":courier_mission.payout(), "deliveries":deliveries,
		"can_decline_order":courier_mission.can_decline_offer(), "on_duty":courier_mission.on_duty,
		"cash":cash, "bitcoin_sats":progression.bitcoin_sats, "story":story_mission.journal(),
		"home_owned":progression.owns_home(), "home_access":progression.has_receipt(StarterHome.ACCESS_RECEIPT),
		"deposit":StarterHome.move_in_price(), "notice":Opening.app_notice(deliveries),
		"global_street_cred":progression.street_cred_summary(), "cred_sources":progression.street_cred_sources(), "scene_scores":SceneReputation.scores(progression),
		"workboard":_phone_workboard(), "circuit_completed":progression.has_receipt(DrivingTrial.RECEIPT), "circuit_best_ms":progression.circuit_best_ms, "brickwater_completed":progression.has_receipt(DrivingTrial.BRICK_RECEIPT), "brickwater_best_ms":progression.brickwater_best_ms, "instrument_status":progression.instrument_summary(),
		"music_contact":_music_contact_status(), "music_sets":progression.street_activity_runs("busking"),
		"live_sets":progression.street_activity_runs("live_gig"), "music_unlocked":progression.has_receipt("venue:soundcheck_pass"),
		"music_contact_available":progression.street_cred()>=100 and not progression.has_receipt("venue:soundcheck_pass"),
		"music_demo_active":venue_job_active=="soundcheck_pass" and not progression.has_receipt("venue:soundcheck_pass"),
		"music_recruit_milo":progression.band_recruit_available("milo"),
		"music_showcase":progression.band_showcase_available(),
		"music_merch":progression.band_merch_summary() if not progression.band_name.is_empty() else "",
		"rail_available":rail_point.is_finite(), "bus_available":bus_point.is_finite(),
		"rail_name":"%d m away (direct)" % roundi(origin.distance_to(rail_point)) if rail_point.is_finite() else "Unavailable",
		"bus_name":"%d m away (direct)" % roundi(origin.distance_to(bus_point)) if bus_point.is_finite() else "Unavailable"
	}

func _phone_set_duty(value: bool) -> void:
	if not phone_available() or game_menu.get("screen") != "phone" or game_menu.get("_phone_app") != "work":
		return
	if not courier_mission.set_on_duty(value):
		return
	if not value and navigation_waypoint != null and Vector2(mission_position.x,mission_position.z).distance_to(navigation_waypoint) < 5.0:
		clear_navigation_waypoint()
	_refresh_courier_target()
	game_menu.call("refresh_phone",_phone_context())

func _phone_decline_order() -> void:
	if not phone_available() or game_menu.get("screen") != "phone" or game_menu.get("_phone_app") != "work":
		return
	var old_target := Vector2(mission_position.x,mission_position.z)
	if not courier_mission.decline_offer():
		return
	_refresh_courier_target()
	# Keep unrelated player waypoints. Replace only a route pointing at the old offer.
	if navigation_waypoint != null and old_target.distance_to(navigation_waypoint) < 5.0:
		set_navigation_waypoint(Vector2(mission_position.x,mission_position.z))
	game_menu.call("refresh_phone",_phone_context())

func _phone_route(action: String) -> void:
	if not phone_available() or game_menu.get("screen") != "phone":
		return
	var destination := Vector2.INF
	var exact_stop := false
	var app: String = game_menu.get("_phone_app")
	if action.begins_with("phone_route_contract:") and app == "opportunities":
		var id := action.trim_prefix("phone_route_contract:")
		for listing in _phone_workboard():
			if listing["id"] == id:
				destination = listing["position"]
				exact_stop = id == "taxi:current" or id == "freight:current"
				break
	match action:
		"phone_route_circuit", "phone_route_brickwater":
			if app == "opportunities":
				destination = DrivingTrial.BRICK_START if action=="phone_route_brickwater" else DrivingTrial.START
				exact_stop = true
		"phone_route_order":
			if app == "work" and courier_mission.gig_economy and courier_mission.mission_active():
				destination = Vector2(mission_position.x,mission_position.z)
		"phone_route_mara":
			if app == "contacts":
				var p: Vector3 = venue_system.call("venue_position","lantern_cup")
				destination = Vector2(p.x,p.z)
		"phone_route_home":
			if app == "housing":
				var p := StarterHome.entry()
				destination = Vector2(p.x,p.z)
		"phone_route_music_shop", "phone_route_music_gig", "phone_route_music_contact":
			if app == "music":
				if action == "phone_route_music_gig" and not progression.has_receipt("venue:soundcheck_pass"):
					return
				if action == "phone_route_music_contact" and (progression.street_cred()<100 or progression.has_receipt("venue:soundcheck_pass")):
					return
				var site := "copper_cup" if action == "phone_route_music_shop" else ("blue_hour" if action == "phone_route_music_gig" or venue_job_active=="soundcheck_pass" else "static_room")
				var p: Vector3 = venue_system.call("venue_position",site)
				destination = Vector2(p.x,p.z)
		"phone_route_music_milo", "phone_route_music_showcase":
			if app == "music":
				var is_milo := action == "phone_route_music_milo"
				if (is_milo and not progression.band_recruit_available("milo")) or (not is_milo and not progression.band_showcase_available()):
					return
				var p: Vector3 = venue_system.call("venue_position","dock_nine" if is_milo else "static_room")
				destination = Vector2(p.x,p.z)
		"phone_route_rail":
			if app == "transit":
				destination = _phone_transit()["rail"]
		"phone_route_bus":
			if app == "transit":
				destination = _phone_transit()["bus"]
	if destination.is_finite():
		set_navigation_waypoint(destination,not exact_stop)
		_sync_trial_beacon()
		game_menu.call("hide_for_game")
		_notify("Phone: route set.")

func _journal_context() -> Dictionary:
	var outside: Vector3 = interiors.get("exterior_position") if interiors.call("is_inside") else _actor().global_position
	var district: String = city_details.call("get_district_at", outside)
	var landmark: String = city_details.call("get_nearby_landmark", outside)
	var objective: Dictionary = courier_mission.objective()
	var remaining := roundi(outside.distance_to(mission_position))
	var loaded: Dictionary = city_details.call("get_streaming_stats")
	return {
		"district": district if landmark.is_empty() else "%s / %s" % [district, landmark],
		"clock": day_night.call("clock_string"),
		"seed": session.get("world_seed"),
		"platform_notice": Opening.app_notice(deliveries) if courier_mission.gig_economy else "",
		"synaxis_site": "SYNAXIS HQ / Glassline / Access revoked" if progression.has_receipt(Opening.RECEIPT) else "",
		"synaxis_contact": _synaxis_contact_objective(),
		"opening_goal": "QUOTADROP / POD DEPOSIT: $%d of $%d saved" % [mini(cash,StarterHome.move_in_price()),StarterHome.move_in_price()] if courier_mission.gig_economy and not progression.owns_home() else "",
		"main_objective": ("%s  •  STEP %d/%d  •  %dm  •  $%d" % [objective["title"], objective["step"], objective["total_steps"], remaining, objective["reward"]]) if courier_mission.mission_active() else "QuotaDrop / off duty. Open Morrow OS to resume.",
		"courier_can_restart": carrying,
		"story_objective": story_mission.journal(),
		"conditioning": courier_mission.conditioning_text(),
		"clothing_store": ClothingStore.directory(), "fashion_locations": ClothingStore.IDS.duplicate(),
		"fashion_remaining": ClothingStore.remaining_stock(int(day_night.get("day_index")),progression),
		"outfit": "OUTFIT: %s / %s" % [Wardrobe.ITEMS[progression.outfit_id]["name"],Wardrobe.ITEMS[progression.outfit_id]["rarity"]],
		"bitcoin_sats": progression.bitcoin_sats,
		"story_can_navigate": _story_target().is_finite(),
		"story_can_abandon": story_mission.status == "active",
		"venue_job": _venue_job_text(),
		"cal_quest":_cal_objective(),
		"street_cred":progression.street_cred_rank(),
		"street_cred_summary":progression.street_cred_summary(),
		"street_cred_sources":progression.street_cred_sources(),"scene_reputation":SceneReputation.summary(SceneReputation.scores(progression)),
		"music_contact":_music_contact_status(),
		"instrument_status":progression.instrument_summary(),
		"busking_status":"STREET MUSIC / Moon Noodles or Copper Cup • %d sets completed"%progression.street_activity_runs("busking"),
		"music_can_navigate":progression.street_cred()>=100 and not progression.has_receipt("venue:soundcheck_pass"),
		"cal_can_navigate":_cal_target().is_finite(),
		"civic_job": _civic_job_text(),
		"investigation": investigation.case_review(progression),
		"cash": cash, "health": health, "heat": heat,
		"stamina": float(player.get("stamina")),
		"consumables": consumable_inventory.duplicate(true),
		"owned_vehicles": _owned_vehicle_text(),
		"home_owned": progression.owns_home(),
		"home_can_navigate": progression.has_receipt(StarterHome.ACCESS_RECEIPT),
		"garage_text": "GARAGE: Two reserved bays / recovery desk" if progression.owns_home() else "GARAGE: Locked services",
		"home_text": "HOME: %s / %d of %d stored provisions" % [StarterHome.NAME,progression.home_supplies,progression.home_capacity()] if progression.owns_home() else "HOME: Complete Mara’s contact mission and pay the move-in cost.",
		"weapons": weapons.inventory_text(),
		"dispatch": dispatch.status(),
		"ambient_civic_open": ambient_civic.open_count(),
		"civic_patrol_phase": str(civic_patrol_service.task.get("phase", "PATROL")),
		"stations": dispatch.stations.size(),
		"supplies": ration_packs, "deliveries": deliveries,
		"venue_completed": venue_job_completed.size(),
		"civic_completed": civic_job_completed.size(),
		"archives": civic_intel.size(),
		"loaded_blocks": loaded.get("loaded_blocks", 0)
	}

func _apply_game_settings(options: Dictionary) -> void:
	show_control_hints = bool(options.get("show_control_hints", true))
	show_hud_inventory = bool(options.get("show_hud_inventory", true))
	mouse_sensitivity = clampf(float(options.get("mouse_sensitivity", 0.0032)), 0.001, 0.010)
	stick_sensitivity = clampf(float(options.get("stick_sensitivity", 2.6)), 0.5, 5.0)
	invert_look_y = bool(options.get("invert_look_y", false))
	if is_instance_valid(nightgrid_fm):
		nightgrid_fm.call("set_preferences", float(options.get("music_volume", 0.65)), bool(options.get("radio_on", true)))
	if is_instance_valid(world_audio):
		world_audio.call("set_preferences", float(options.get("ambience_volume", 0.65)), float(options.get("sfx_volume", 0.75)))
	AudioMix.set_level(AudioMix.DIALOGUE, float(options.get("dialogue_volume", 0.82)))
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(0.001, float(options.get("master_volume", 0.8)))))
	world_environment.environment.ssr_enabled = bool(options.get("ssr_enabled", true))
	world_environment.environment.glow_enabled = bool(options.get("glow_enabled", true))
	world_environment.environment.ssao_enabled = bool(options.get("ao_enabled", true))
	world_environment.environment.fog_enabled = bool(options.get("fog_enabled", true))
	performance_overlay = bool(options.get("show_fps", false))
	performance_label.visible = performance_overlay
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if bool(options.get("vsync_enabled", true)) else DisplayServer.VSYNC_DISABLED)

func _input(event: InputEvent) -> void:
	if GameInput.is_gamepad_event(event):
		gamepad_active = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		gamepad_active = false
	if game_menu != null and game_menu.call("is_open"):
		return
	if _wardrobe_panel and venue_panel.visible:
		# Route venue shortcuts before GUI focus can consume controller A.
		if event is InputEventKey and event.echo:
			get_viewport().set_input_as_handled()
			return
		for index in range(3):
			if event.is_action_pressed(["service_one","service_two","service_three"][index]):
				_venue_action(index+1)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("game_back"):
			_close_venue()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interior_toggle") or event.is_action_pressed("transit_toggle"):
			_cycle_wardrobe_category(-1 if event.is_action_pressed("interior_toggle") else 1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("use_supply"):
			_toggle_fitting_compare()
			get_viewport().set_input_as_handled()
			return
		if _clothing_retail and event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_fitting_rotation=wrapf(_fitting_rotation+event.relative.x*.012,-PI,PI)
			get_viewport().set_input_as_handled()
			return
		if _clothing_retail and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_fitting_zoom=clampf(_fitting_zoom+(.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -.12),0.0,1.0)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _cinder_cockpit and _can_use_cinder_view():
			_adjust_cockpit_look(Vector2(-event.relative.x, event.relative.y * (-1.0 if invert_look_y else 1.0) * .625) * mouse_sensitivity)
		else:
			yaw -= event.relative.x * mouse_sensitivity
			pitch = clampf(pitch + event.relative.y * mouse_sensitivity * (-1.0 if invert_look_y else 1.0) * 0.625, 0.20, 0.85)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not venue_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if game_menu != null and game_menu.call("is_open"):
		return
	if event is InputEventKey and event.echo:
		return
	if not event.is_pressed():
		return
	if _handle_playtest_diagnostic(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_opening_office):
		if event.is_action_pressed("interact") or (_opening_office.call("arrival_active") and event.is_action_pressed("game_pause")):
			_opening_interact()
		return
	if event.is_action_pressed("game_pause"):
		if venue_panel.visible:
			_close_venue()
		game_menu.call("open_pause")
	elif event.is_action_pressed("game_back"):
		if venue_panel.visible:
			_close_venue()
		else:
			# The B button doubles as the car's handbrake. Only Start/Esc
			# opens the pause menu in free gameplay.
			return
	elif event.is_action_pressed("map_open"):
		if venue_panel.visible:
			_close_venue()
		game_menu.call("open_map")
	elif event.is_action_pressed("phone_open"):
		_open_phone(false)
	elif event.is_action_pressed("journal_open"):
		if venue_panel.visible:
			_close_venue()
		game_menu.call("open_journal", _journal_context())
	elif event.is_action_pressed("radio_toggle") and current_car != null:
		var prefs: Dictionary = game_menu.call("get_settings")
		var enabled := not bool(prefs.get("radio_on", true))
		game_menu.call("update_setting", "radio_on", enabled)
		_notify("NightGrid FM tuned in. B toggle / N next." if enabled else "NightGrid FM switched off.")
	elif event.is_action_pressed("radio_next") and current_car != null:
		if nightgrid_fm.call("next_car_track"):
			_notify(str(nightgrid_fm.call("get_now_playing")))
	elif venue_panel.visible:
		if event.is_action_pressed("service_one"):
			_venue_action(1)
		elif event.is_action_pressed("service_two"):
			_venue_action(2)
		elif event.is_action_pressed("service_three"):
			_venue_action(3)
		elif event.is_action_pressed("interact"):
			_close_venue()
	elif event.is_action_pressed("weapon_wheel") and _can_use_weapon():
		_open_equipment_wheel()
	elif event.is_action_pressed("vehicle_view") and _can_use_cinder_view():
		_toggle_cinder_view()
	elif event.is_action_pressed("weapon_cycle") and _can_use_weapon():
		weapons.cycle()
		_fire_held = true
	elif event.is_action_pressed("weapon_reload") and _can_use_weapon():
		if weapons.reload():
			_play_weapon_sound("RELOAD")
	elif event.is_action_pressed("car_toggle"):
		_toggle_car()
	elif event.is_action_pressed("transit_toggle"):
		_toggle_transit()
	elif event.is_action_pressed("interior_toggle"):
		_toggle_interior()
	elif event.is_action_pressed("interact"):
		if current_car!=null and not _driving_trial.active and not _freight.active and _taxi_interaction_available():
			_taxi_interact()
		elif current_car!=null and not _driving_trial.active and not _taxi.active and _freight_interaction_available():
			_freight_interact()
		elif current_car != null and (_driving_trial.active or DrivingTrial.near_start(Vector2(current_car.global_position.x,current_car.global_position.z))):
			_toggle_driving_trial()
		else:
			_toggle_interaction()
	elif event.is_action_pressed("use_supply"):
		_consume_ration()
	elif event.is_action_pressed("game_save"):
		_save_game()
	elif event.is_action_pressed("game_load"):
		_load_game()
	elif event.is_action_pressed("game_new"):
		game_menu.call("confirm_new_game")
	elif event.is_action_pressed("advance_clock"):
		day_night.call("advance_hour", 1.0)
	elif event.is_action_pressed("pause_clock"):
		day_night.call("toggle_pause")
	elif event.is_action_pressed("sky_weather_cycle"):
		var state: String = str(day_night.call("cycle_weather"))
		_log_playtest("sky_weather_preview", {"weather": state, "sky": str(day_night.call("active_sky_preset"))})
		_notify("Original sky preview: " + state + " (F2 cycles clear/cloudy/overcast/rain/storm)")
	elif event.is_action_pressed("toggle_fps"):
		performance_overlay = not performance_overlay
		performance_label.visible = performance_overlay
	elif event.is_action_pressed("compare_render_look"):
		var profile: String = str(day_night.call("cycle_render_profile"))
		_log_playtest("render_profile_switched", {"render_profile": profile})
		playtest_logger.flush()
		_notify("Rendering comparison: " + profile + " (F11 cycles Filmic / ACES / AgX; F10 captures)")
	elif event.is_action_pressed("toggle_ssr"):
		world_environment.environment.ssr_enabled = not world_environment.environment.ssr_enabled
	else:
		return
	get_viewport().set_input_as_handled()

func _handle_playtest_diagnostic(event:InputEvent) -> bool:
	if event.is_action_pressed("playtest_mark"):
		_log_playtest("manual_marker", {"note": "Player pressed F7 after noticing an issue"})
		playtest_logger.flush()
		_notify("Playtest marker saved: " + playtest_logger.get_log_path() if playtest_logger.is_active() else "Playtest logging unavailable.")
	elif event.is_action_pressed("record_frame_trace"):
		if frame_time_recorder.recording or frame_time_recorder.capture_full:
			frame_time_recorder.end_capture()
			var exported: String = frame_time_recorder.export_csv()
			var transitions: String = frame_time_recorder.export_vehicle_trace(exported)
			_log_playtest("frame_trace_saved", {"path": exported, "vehicle_transitions":transitions,"frames":frame_time_recorder.captured_frames()})
			_notify("Frame trace saved: " + exported if not exported.is_empty() else "Frame trace export failed.")
		else:
			var stream_start: Dictionary = city_details.call("get_streaming_stats")
			frame_time_recorder.begin_capture(int(stream_start["loads"]),
				int(stream_start.get("stage_steps", 0)), int(stream_start.get("total_build_usec", 0)))
			_log_playtest("frame_trace_started")
			_notify("Frame trace recording. Press F8 again to save a CSV.")
	elif event.is_action_pressed("capture_playtest_frame"):
		if not _capturing_evidence:
			call_deferred("_capture_playtest_frame")
	else:
		return false
	return true

## F10 produces a genuine rendered viewport frame without HUD, plus an
## adjacent JSON record with exact camera pose, game world, settings and
## measured rolling frame intervals. No world teleport or save mutation.
func _capture_playtest_frame() -> void:
	if _capturing_evidence or camera == null or not is_instance_valid(player):
		return
	if game_menu != null and game_menu.call("is_open"):
		return
	var office_capture:=is_instance_valid(_opening_office)
	if office_capture and (_opening_office.call("arrival_active") or _opening_office.call("lift_active")):
		print("F10: capture after the arrival or lift transition.")
		return
	_capturing_evidence = true
	var office_layer:CanvasLayer=_opening_office.get("_intro_canvas") if office_capture else null
	var office_was_visible:=is_instance_valid(office_layer) and office_layer.visible
	if is_instance_valid(office_layer):
		office_layer.hide()
	var hud_layer := get_node_or_null("HUD") as CanvasLayer
	var hud_was_visible := hud_layer != null and hud_layer.visible
	if hud_layer != null:
		hud_layer.visible = false
	# Framebuffer must be sampled only after the *new* HUD-hidden frame.
	# Never store an old composited frame then mislabel it as a clean view.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var framebuffer := get_viewport().get_texture().get_image()
	if hud_layer != null:
		hud_layer.visible = hud_was_visible
	if is_instance_valid(office_layer) and is_instance_valid(_opening_office) and not _opening_office.call("lift_active"):
		office_layer.visible=office_was_visible
	if framebuffer == null or framebuffer.is_empty():
		_capturing_evidence = false
		_notify("F10 capture failed: renderer returned no framebuffer.")
		return
	var actual_actor := _actor()
	var outdoor_position: Vector3 = interiors.get("exterior_position") if interiors.call("is_inside") else actual_actor.global_position
	var motion := "on_foot"
	if current_car != null:
		motion = "player_vehicle"
	elif current_transit != null:
		motion = {"TRAIN": "rail", "BUS": "bus", "LIFT": "station_lift"}[transit_kind]
	var metadata: Dictionary = PlaytestEvidence.build_metadata(camera, actual_actor, {
		"world_seed": int(session.get("world_seed")),
		"game_clock": str(day_night.call("clock_string")),
		"district": str(city_details.call("get_district_at", outdoor_position)),
		"indoors": bool(interiors.call("is_inside")) or _inside_opening_hq(),
		"chapter_context": _opening_diagnostic_context(),
		"build_revision": BuildInfo.REVISION,
		"motion_context": motion,
		"graphic_settings": game_menu.call("get_settings"),
		"render_profile": str(day_night.call("get_render_profile")),
		"sky_weather": str(day_night.call("get_weather")),
		"sky_preset": str(day_night.call("active_sky_preset")),
		"frame_interval_metrics": frame_time_recorder.get_frame_metrics(),
		"streaming": city_details.call("get_streaming_stats"),
		"render_batch_stats": city_details.call("get_render_batch_stats"),
		"practical_light_stats": street_lights.call("get_practical_light_stats"),
		"frame_trace_recording": frame_time_recorder.recording
	})
	var result: Dictionary = PlaytestEvidence.export_bundle(framebuffer, metadata)
	_capturing_evidence = false
	if bool(result.get("ok", false)):
		print("PLAYTEST_FRAME_EVIDENCE PNG: ", result["png_path"])
		print("PLAYTEST_FRAME_EVIDENCE JSON: ", result["json_path"])
		_log_playtest("screenshot_captured", {"png_path": result["png_path"], "json_path": result["json_path"]})
		playtest_logger.flush()
		_notify("F10 screenshot + metrics saved in: " + str(result["directory"]))
	else:
		_log_playtest("screenshot_failed", {"error": str(result.get("error", "unknown error"))})
		_notify("F10 capture failed: " + str(result.get("error", "unknown error")))

func _inside_opening_hq() -> bool:
	if not is_instance_valid(_opening_office):
		return false
	var local:=_opening_office.to_local(player.global_position)
	return absf(local.x)<8.5 and absf(local.z)<10.0

func _opening_diagnostic_context() -> Dictionary:
	if not is_instance_valid(_opening_office):
		return {}
	return {"site":"synaxis_hq","floor":int(_opening_office.get("_active_floor")),"stage":int(_opening_office.call("objective_stage",int(game_menu.get("_opening_stage")))),"arrival":bool(_opening_office.call("arrival_active")),"lift":bool(_opening_office.call("lift_active")),"offboarding":bool(_opening_office.call("exit_active"))}

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if is_instance_valid(_opening_office):
		var opening_stream:Dictionary=city_details.call("get_streaming_stats")
		frame_time_recorder.sample_frame(delta,opening_stream,player.global_position,false)
		playtest_logger.sample_frame(delta,opening_stream,player.global_position,"synaxis_opening")
		if _opening_office.call("arrival_active"):
			if not _opening_office.call("tick_arrival",delta,player,camera):
				_snap_camera()
			return
		if _opening_office.call("lift_active"):
			if _opening_office.call("tick_lift",delta,player):
				_snap_camera()
			return
		var look := GameInput.look_vector()
		yaw -= look.x * stick_sensitivity * delta
		pitch = clampf(pitch+look.y*stick_sensitivity*delta*(-1.0 if invert_look_y else 1.0),.20,.85)
		player.set("camera_yaw",yaw)
		_update_camera(delta)
		_opening_office.call("update_prompt",int(_opening_office.call("objective_stage",int(game_menu.get("_opening_stage")))),player.global_position,gamepad_active)
		if _opening_office.call("exit_ready",player.global_position):
			_accept_opening()
			return
		if _opening_office.call("exit_active"):
			return
		if not game_menu.call("is_open"):
			var restroom := str(_opening_office.call("restroom_encounter",player.global_position))
			if not restroom.is_empty():
				game_menu.call("open_restroom",restroom)
		return
	var actor := _actor()
	if current_car != null and current_car.get("model_id") == RoadCars.R9:
		current_car.set("road_wetness", day_night.call("surface_film"))
		current_car.get("hero_visual").call("set_lighting_hour", float(day_night.get("hour")))
	var stream_snapshot: Dictionary = city_details.call("get_streaming_stats")
	frame_time_recorder.sample_frame(delta, stream_snapshot, actor.global_position, current_car != null)
	playtest_logger.sample_frame(delta, stream_snapshot, actor.global_position,
		"car" if current_car != null else ("transit_" + transit_kind.to_lower() if current_transit != null else "on_foot"))
	var indoors: bool = interiors.call("is_inside")
	var repair := _repair_storefront()
	var in_workshop := repair != null and repair.contains(actor.global_position)
	if repair != null:
		repair.set_listener(actor.global_position, in_workshop)
	if is_instance_valid(dialogue_director):
		dialogue_director.call("tick", delta, actor.global_position)
	_update_police_radio(delta)
	var interior_id := str(interiors.call("active_site_id")) if indoors else ""
	var interior_kind := ""
	var physical_room: Node3D = city_details.call("nearby_walk_in",actor.global_position) if not indoors and current_car == null and current_transit == null else null
	var in_physical_room := is_instance_valid(physical_room) and bool(physical_room.call("contains",actor.global_position))
	if in_physical_room:
		interior_id = str(physical_room.get("physical_venue_id"))
		interior_kind = str((venue_system.call("venue_by_id",interior_id) as Dictionary).get("kind",""))
		if not str(physical_room.get("clothing_store_id")).is_empty():
			interior_id=str(physical_room.get("clothing_store_id"))
			interior_kind=str(ClothingStore.THEMES[interior_id]["music"]).to_upper()
	if indoors and str(interiors.call("active_site_group")) == "VENUE":
		interior_kind = str((venue_system.call("venue_by_id", interior_id) as Dictionary).get("kind", ""))
	if is_instance_valid(nightgrid_fm):
		nightgrid_fm.call("update_listener", actor.global_position, current_car != null, interior_id, interior_kind, current_transit != null)
	if is_instance_valid(world_audio):
		world_audio.call("set_room_kind", "WORKSHOP" if in_workshop else interior_kind)
		world_audio.call("set_doorway_leak", repair.doorway_leak(actor.global_position) if in_workshop else 0.0)
		var street_position: Vector3 = interiors.get("exterior_position") if indoors else actor.global_position
		var district: String = city_details.call("get_district_at", street_position)
		var foot_speed := Vector2(player.velocity.x, player.velocity.z).length()
		world_audio.call("update_context", actor.global_position, player.global_position,
			current_car == null and current_transit == null, player.is_on_floor(),
			indoors or in_workshop or in_physical_room, district, float(day_night.get("hour")), foot_speed, player.velocity.y)
		if is_instance_valid(current_car):
			world_audio.call("set_transport", "CAR", float(current_car.get("speed")), Input.is_action_pressed("drive_brake"),
				current_car.get("model_id") == RoadCars.R9)
		elif transit_kind == "TRAIN":
			world_audio.call("set_transport", "TRAIN", float(rail.get("speed")), false)
		elif transit_kind == "BUS" and is_instance_valid(current_transit):
			world_audio.call("set_transport", "BUS", float(current_transit.get("speed")), false)
		else:
			world_audio.call("set_transport", "", 0.0, false)
	if indoors and str(interiors.call("active_site_id")) == "lantern_cup":
		interiors.call("set_mara_focus", player.global_position)
	if not venue_panel.visible:
		# Right stick or mouse may orbit the camera on foot, in vehicles or in transit.
		var right_look: Vector2 = GameInput.look_vector()
		if _cinder_cockpit and _can_use_cinder_view():
			_adjust_cockpit_look(Vector2(-right_look.x, right_look.y * (-1.0 if invert_look_y else 1.0)) * stick_sensitivity * delta)
		else:
			yaw -= right_look.x * stick_sensitivity * delta
			pitch = clampf(pitch + right_look.y * stick_sensitivity * delta * (-1.0 if invert_look_y else 1.0), 0.20, 0.85)
	_focus_update_clock += delta
	if _focus_update_clock >= 0.1:
		_focus_update_clock = 0.0
		if not indoors:
			var traversal_velocity := Vector3.ZERO
			if actor is CharacterBody3D:
				traversal_velocity = (actor as CharacterBody3D).velocity
			city_details.call("request_focus", actor.global_position, traversal_velocity)
		city_details.call("update_walk_in_light", actor.global_position if not indoors and current_car == null and current_transit == null else Vector3.INF)
		var headquarters: Node3D = city_details.call("synaxis_headquarters")
		if is_instance_valid(headquarters):
			headquarters.call("update_public_light",actor.global_position if not indoors and current_car == null and current_transit == null else Vector3.INF)
		var started := StreamProfile.begin()
		street_lights.call("set_focus", interiors.get("exterior_position") if indoors else actor.global_position)
		StreamProfile.end(started, "street_light_focus")
		started = StreamProfile.begin()
		venue_system.call("set_focus", actor.global_position)
		StreamProfile.end(started, "venue_focus")
		started = StreamProfile.begin()
		civic_services.call("set_focus", actor.global_position)
		StreamProfile.end(started, "civic_focus")
	_venue_clock_tick += delta
	if _venue_clock_tick >= 0.5:
		_venue_clock_tick = 0.0
		_sync_band_flyers()
		venue_system.call("set_hour", float(day_night.get("hour")))
		civic_services.call("set_hour", float(day_night.get("hour")))
	if venue_panel.visible:
		var menu_position: Vector3
		if is_instance_valid(_vending_machine):
			menu_position = _vending_machine.global_position if city_details.call("nearby_vending",player.global_position) == _vending_machine else Vector3.INF
		elif _wardrobe_panel:
			var wardrobe_lot:Node3D=city_details.call("nearby_walk_in",player.global_position)
			var reachable:bool=is_instance_valid(wardrobe_lot) and (wardrobe_lot.get("clothing_store_id")==_retail_id and wardrobe_lot.call("clothing_reachable",player.global_position) if _clothing_retail else progression.owns_home() and wardrobe_lot.call("home_action",player.global_position)=="wardrobe")
			menu_position=player.global_position if reachable else Vector3.INF
		elif _repair_panel:
			menu_position = repair.counter_position() if repair != null else Vector3.INF
		elif indoors:
			menu_position = interiors.call("get_counter_point")
		elif venue_selected_id == "helix_espresso":
			var lot: Node3D = city_details.call("nearby_walk_in",player.global_position)
			menu_position = lot.call("service_counter") if is_instance_valid(lot) and str(lot.get("physical_venue_id")) == venue_selected_id else Vector3.INF
			if not is_instance_valid(lot) or not lot.call("service_reachable",player.global_position):
				menu_position = Vector3.INF
		else:
			menu_position = civic_services.call("position_for", civic_selected_id) if not civic_selected_id.is_empty() else venue_system.call("venue_position", venue_selected_id)
		if current_car != null or current_transit != null or menu_position.distance_to(player.global_position) > 7.0:
			_close_venue()
	if current_car == null and current_transit == null:
		player.set("camera_yaw", yaw)
	var camera_started := StreamProfile.begin()
	_update_camera(delta, false)
	StreamProfile.accumulate(camera_started, "world_camera")
	_hud_update_clock += delta
	if _hud_update_clock >= 0.1:
		_hud_update_clock = 0.0
		_update_hud()

func _physics_process(delta: float) -> void:
	# Gameplay mission/heat/damage timers are fixed-tick, not render-tick.
	if not is_instance_valid(player):
		return
	if is_instance_valid(_opening_office):
		if _opening_office.call("needs_recovery",player.global_position):
			player.global_position = _opening_office.call("recovery_position")
			player.velocity = Vector3.ZERO
			_snap_camera()
		return
	if _active_station_lift != null and not bool(_active_station_lift.get("travelling")):
		var landing: Vector3 = _active_station_lift.call("destination")
		var upstairs: bool = _active_station_lift.get("going_up")
		_active_station_lift = null
		_leave_transit(landing, "M-Line platform. Board a stopped train." if upstairs else "Back at street level.")
	var actor := _actor()
	var indoors: bool = interiors.call("is_inside")
	if _pooled_traffic_enabled:
		var vehicle_speed: float = (actor as CharacterBody3D).velocity.length() if actor is CharacterBody3D else 0.0
		var repair := _repair_storefront()
		var storefront_inside := repair != null and repair.contains(actor.global_position)
		traffic.call("tick_pooled", delta, actor.global_position, vehicle_speed, camera,
			city_details, indoors or storefront_inside or current_transit != null,
			cars + officers + routine_patrols, road_restrictions)
	var started := StreamProfile.begin()
	if is_instance_valid(pedestrians):
		_update_pedestrians(delta, actor, indoors)
	StreamProfile.accumulate(started, "world_pedestrians")
	started = StreamProfile.begin()
	_update_combat(delta)
	_update_freight(delta)
	_update_taxi(delta)
	_update_taxi_waiting_rider(delta)
	if not courier_mission.gig_economy and not indoors and current_transit == null and actor.global_position.distance_to(mission_position) < CourierMission.RADIUS:
		_advance_mission()
	if (actor.global_position.y < -15.0 or not indoors and
			(absf(actor.global_position.x) > 390.0 or absf(actor.global_position.z) > 390.0)):
		_respawn()
	_update_driving_trial(delta)
	_sync_trial_beacon()
	_sync_trial_ghost(delta)
	_update_wanted(delta)
	_update_ambient_civic(delta)
	_update_civic_patrols(delta)
	StreamProfile.accumulate(started, "world_civic_combat_and_wanted")
	if not indoors and wanted.police_seen:
		for officer in officers:
			if is_instance_valid(officer) and float(officer.get("condition")) > 18.0 and officer.global_position.distance_to(actor.global_position) < 3.8:
				# Contact damage remains a separate arcade gameplay consequence;
				# the driving controller never intentionally targets collisions.
				health -= delta * 7.0
	if health <= 0.0:
		_respawn()
	if notification_time > 0.0:
		notification_time -= delta

func _toggle_driving_trial()->void:
	if _driving_trial.active:
		_driving_trial.stop("ABANDONED")
		_notify(DrivingTrial.name_for(_driving_trial.course_id)+" abandoned. Return to the start to retry.")
		return
	if current_car==null or current_transit!=null or Wanted.stars(heat)>0:
		_notify("Driving challenge / park a roadworthy car and clear your wanted level.")
		return
	var at:=Vector2(current_car.global_position.x,current_car.global_position.z)
	if _driving_trial.start(at,current_car.get_instance_id(),float(current_car.get("condition")),float(current_car.get("speed"))):
		var origin:=DrivingTrial.BRICK_START if _driving_trial.course_id==DrivingTrial.BRICK else DrivingTrial.START
		_circuit_rival.configure(origin,_driving_trial.gates())
		_notify("%s / %d checkpoints. Rival on course. First finish $%d."%[DrivingTrial.name_for(_driving_trial.course_id),_driving_trial.gates().size(),_driving_trial.reward()])
	else:
		_notify("Driving challenge / stop at the start with a roadworthy car.")

func _update_driving_trial(delta:float)->void:
	if not _driving_trial.active:
		return
	if not is_instance_valid(current_car) or Wanted.stars(heat)>0:
		_driving_trial.stop("ABANDONED")
		_notify(DrivingTrial.name_for(_driving_trial.course_id)+" abandoned.")
		return
	var at:=Vector2(current_car.global_position.x,current_car.global_position.z)
	_tick_circuit_rival(delta)
	var outcome:=_driving_trial.tick(delta,at,current_car.get_instance_id(),float(current_car.get("condition")))
	if outcome=="GATE":
		_notify("Checkpoint %d / %d • pace %+.1fs"%[_driving_trial.index,_driving_trial.gates().size(),_driving_trial.pace_split()])
	elif outcome=="COMPLETE":
		var course:=_driving_trial.course_id
		var record:=progression.record_circuit_time(_driving_trial.elapsed,course)
		var paid:=progression.credit_once(_driving_trial.receipt(),_driving_trial.reward())
		var best:=progression.brickwater_best_ms if course==DrivingTrial.BRICK else progression.circuit_best_ms
		var won:=not _circuit_rival.finished or _driving_trial.elapsed<=_circuit_rival.elapsed
		_notify("%s / %.2fs / %s%s%s%s"%[DrivingTrial.name_for(course),_driving_trial.elapsed,"FIRST" if won else "SECOND"," / PERSONAL BEST" if record else ""," / PACE BEATEN" if _driving_trial.elapsed<_driving_trial.pace_time() else ""," +$%d"%_driving_trial.reward() if paid else " / practice finish"])
		_log_playtest("driving_trial_finish",{"course":course,"seconds":_driving_trial.elapsed,"paid":paid,"personal_best":record,"best_ms":best,"pace_beaten":_driving_trial.elapsed<_driving_trial.pace_time(),"rival_finished":_circuit_rival.finished,"rival_seconds":_circuit_rival.elapsed,"rival_beaten":won})
	elif not outcome.is_empty():
		_notify(DrivingTrial.name_for(_driving_trial.course_id)+" / "+outcome)

func _freight_interaction_available()->bool:
	if current_car==null:
		return false
	var at:=Vector2(current_car.global_position.x,current_car.global_position.z)
	var offer:=FreightJob.offer(progression.freight_runs)
	return _freight.active or (not offer.is_empty() and FreightJob.near(at,offer["pickup"]))

func _freight_interact()->void:
	if not is_instance_valid(current_car) or _taxi.active or _driving_trial.active:
		return
	if _freight.active and Wanted.stars(heat)>0:
		_cancel_freight()
		_notify("Freight lost / retry at pickup.")
		return
	var at:=Vector2(current_car.global_position.x,current_car.global_position.z)
	if not FreightJob.supports_vehicle(str(current_car.get("model_id")),bool(current_car.get("is_police"))):
		_notify("Freight / use a civilian Kestrel S6 with rear cargo space.")
		return
	var id:=current_car.get_instance_id()
	var condition:=float(current_car.get("condition"))
	var speed:=float(current_car.get("speed"))
	if _freight.active:
		if FreightJob.near(at,_freight.route["drop"]):
			if _freight.ready_to_deliver(at,id,condition,speed):
				var pay:=int(_freight.route["reward"])
				if progression.settle_freight(_freight.sequence):
					_cancel_freight()
					_notify("FREIGHT / cargo delivered +$%d"%pay)
					_log_playtest("freight_finish",{"sequence":progression.freight_runs,"paid":pay})
				else:
					_notify("Freight settlement unavailable. Retry.")
			else:
				_notify("Freight / stop at the delivery point in the original vehicle.")
		else:
			_cancel_freight()
			_notify("Freight cancelled. Return to the pickup.")
		return
	if Wanted.stars(heat)>0:
		_notify("Freight / clear police attention first.")
		return
	if _freight.begin(progression.freight_runs,at,id,condition,speed):
		_attach_freight_case()
		var drop:Vector2=_freight.route["drop"]
		set_navigation_waypoint(drop,false)
		_vehicle_job_waypoint_owner = "freight"
		_notify("FREIGHT / %s • loaded. Deliver in this vehicle."%_freight.route["name"])
	else:
		_notify("Freight / stop a roadworthy vehicle at the loading point.")

func _attach_freight_case()->void:
	_remove_freight_case()
	_freight_case=CargoCase.new()
	_freight_case.name="SecuredFreightCase"
	_freight_case.position=Vector3(.46,.52,.69)
	_freight_case.configure(_freight.route["name"])
	current_car.add_child(_freight_case)

func _remove_freight_case()->void:
	if is_instance_valid(_freight_case):
		_freight_case.hide()
		_freight_case.queue_free()
	_freight_case=null

func _clear_vehicle_job_waypoint(owner: String) -> void:
	if _vehicle_job_waypoint_owner == owner:
		clear_navigation_waypoint()

func _cancel_freight()->void:
	_clear_vehicle_job_waypoint("freight")
	_freight.cancel()
	_remove_freight_case()

func _update_freight(delta:float)->void:
	if not _freight.active:
		return
	if not is_instance_valid(current_car) or Wanted.stars(heat)>0:
		_cancel_freight()
		_notify("Freight lost / retry at pickup.")
		return
	var at:=Vector2(current_car.global_position.x,current_car.global_position.z)
	if not _freight.tick(at,current_car.get_instance_id(),float(current_car.get("condition")),delta):
		_cancel_freight()
		_notify("FREIGHT / "+_freight.failure_reason+" Retry at pickup.")

func _taxi_interaction_available()->bool:
	if current_car==null:
		return false
	var at:=Vector2(current_car.global_position.x,current_car.global_position.z)
	var offer:=TaxiJob.offer(progression.taxi_runs)
	return _taxi.active or (not offer.is_empty() and TaxiJob.near(at,offer["pickup"]))

func _taxi_interact()->void:
	if not is_instance_valid(current_car) or _freight.active or _driving_trial.active:
		return
	if _taxi.active and Wanted.stars(heat)>0:
		_cancel_taxi()
		_notify("Taxi fare cancelled.")
		return
	var at:=Vector2(current_car.global_position.x,current_car.global_position.z)
	var id:=current_car.get_instance_id()
	var condition:=float(current_car.get("condition"))
	var speed:=float(current_car.get("speed"))
	if _taxi.active:
		if TaxiJob.near(at,_taxi.route["drop"]):
			if _taxi.ready_to_arrive(at,id,condition,speed):
				var fare:=int(_taxi.route["reward"])
				if progression.settle_taxi(_taxi.sequence):
					ambient_caption.call("present",str(_taxi.route["rider"]),str(_taxi.route["arrival"]))
					_show_taxi_arrival()
					_cancel_taxi(true)
					_notify("TAXI / fare complete +$%d"%fare)
					_log_playtest("taxi_finish",{"sequence":progression.taxi_runs,"paid":fare})
				else:
					_notify("Taxi / settlement unavailable. Retry.")
			else:
				_notify("Taxi / stop safely at the destination.")
		else:
			_cancel_taxi()
			_notify("Taxi fare cancelled. Return to pickup to retry.")
		return
	if Wanted.stars(heat)>0 or not FreightJob.supports_vehicle(str(current_car.get("model_id")),bool(current_car.get("is_police"))):
		_notify("Taxi / civilian Kestrel required, no police attention.")
		return
	if _taxi.begin(progression.taxi_runs,at,id,condition,speed):
		if not is_instance_valid(_taxi_rider):
			_taxi_rider=TaxiRider.new()
			_taxi_rider.name="WaitingTaxiRider"
			add_child(_taxi_rider)
		_taxi_rider.call("seat_rider",_taxi.sequence-1,str(_taxi.route["rider"]),current_car)
		ambient_caption.call("present",str(_taxi.route["rider"]),str(_taxi.route["request"]))
		set_navigation_waypoint(_taxi.route["drop"],false)
		_vehicle_job_waypoint_owner = "taxi"
		_notify("TAXI / %s • passenger fare started"%_taxi.route["name"])
	else:
		_notify("Taxi / stop with vehicle condition of at least 50.")

func _cancel_taxi(keep_departure: bool = false) -> void:
	_clear_vehicle_job_waypoint("taxi")
	_taxi.cancel()
	if not keep_departure and is_instance_valid(_taxi_rider):
		_taxi_rider.call("hide_rider")

func _update_taxi(delta:float)->void:
	if not _taxi.active:
		return
	if not is_instance_valid(current_car) or Wanted.stars(heat)>0:
		_cancel_taxi()
		_notify("Taxi fare cancelled.")
		return
	var at:=Vector2(current_car.global_position.x,current_car.global_position.z)
	if not _taxi.tick(at,current_car.get_instance_id(),float(current_car.get("condition")),delta):
		_cancel_taxi()
		_notify("TAXI / "+_taxi.failure_reason+" Retry at pickup.")

func _show_taxi_arrival()->void:
	var point:=TaxiJob.arrival_point(_taxi.route)
	# Select the short sidewalk segment toward the block center, away
	# from the nearest crossing. Do not move the rider through a fixture.
	var midpoint:float=(floorf(point.x/58.0)+.5)*58.0
	var direction:=signf(midpoint-point.x)
	var goal:=point+Vector3(direction*3.0,0,0)
	var space:=get_world_3d().direct_space_state
	var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.8,goal+Vector3.UP*.8,1,[current_car.get_rid(),player.get_rid()])
	if not space.intersect_ray(ray).is_empty():
		goal=point
	if not is_instance_valid(_taxi_rider):
		_taxi_rider=TaxiRider.new()
		_taxi_rider.name="WaitingTaxiRider"
		add_child(_taxi_rider)
	_taxi_rider.call("begin_departure",_taxi.sequence-1,str(_taxi.route["rider"]),point,goal)

func _update_taxi_waiting_rider(delta:float)->void:
	if _taxi.active and is_instance_valid(_taxi_rider) and _taxi_rider.call("is_seated"):
		return
	if not _taxi.active and is_instance_valid(_taxi_rider) and _taxi_rider.call("is_seated"):
		_taxi_rider.call("hide_rider")
	if is_instance_valid(_taxi_rider) and _taxi_rider.call("is_departing"):
		if _taxi.active or _freight.active or _driving_trial.active or interiors.call("is_inside") or current_transit!=null or _actor().global_position.distance_squared_to(_taxi_rider.global_position)>42.0*42.0:
			_taxi_rider.call("hide_rider")
		elif _taxi_rider.call("advance_departure",delta):
			return
	_taxi_visual_timer+=delta
	if _taxi_visual_timer<.25:
		return
	_taxi_visual_timer=0.0
	var offer:=TaxiJob.offer(progression.taxi_runs)
	# Waiting riders are world actors, not phone UI. Keep them visible to
	# an approaching driver while retaining the prologue and world-state guards.
	if _taxi.active or _freight.active or _driving_trial.active or offer.is_empty() or not is_instance_valid(player) or is_instance_valid(_opening_office) or interiors.call("is_inside") or current_transit!=null:
		if is_instance_valid(_taxi_rider):
			_taxi_rider.call("hide_rider")
		return
	var point:=TaxiJob.waiting_point(offer)
	if _actor().global_position.distance_squared_to(point)>42.0*42.0:
		if is_instance_valid(_taxi_rider):
			_taxi_rider.call("hide_rider")
		return
	if not is_instance_valid(_taxi_rider):
		_taxi_rider=TaxiRider.new()
		_taxi_rider.name="WaitingTaxiRider"
		add_child(_taxi_rider)
	_taxi_rider.call("show_rider",progression.taxi_runs,str(offer["rider"]),point)

func _actor() -> Node3D:
	if current_transit != null:
		return current_transit
	return current_car if current_car != null else player

func enable_living_streets() -> bool:
	if is_instance_valid(pedestrians):
		return true
	var models: Array[PackedScene] = []
	for path in PEDESTRIAN_MODELS:
		var model := load(path) as PackedScene
		if model == null:
			return false
		models.append(model)
	var director := PedestrianDirector.new()
	director.name = "LivingStreets"
	add_child(director)
	var visual := load("res://scenes/pedestrian_visual.tscn") as PackedScene
	if not director.configure(city_details, int(session.get("world_seed")), PedestrianRoutes.city_links(), visual, 12, models):
		director.queue_free()
		return false
	pedestrians = director
	if is_instance_valid(world_audio):
		world_audio.call("set_pedestrians", pedestrians)
	return true

func _update_pedestrians(delta: float, actor: Node3D, indoors: bool) -> void:
	pedestrians.call("track_cal_quest",progression.cal_quest in [1,2])
	var occupied: Array[Vector3] = [actor.global_position]
	var street_mode := not indoors and current_transit == null and is_instance_valid(camera)
	pedestrians.call("tick", delta, actor.global_position, camera, not street_mode,
		occupied, float(day_night.get("hour")), signal_controller)
	if is_instance_valid(dialogue_director):
		pedestrians.call("update_street_dialogue",dialogue_director,actor.global_position+Vector3.UP*1.6,player.get_rid(),street_mode and current_car==null and weapons.equipped=="holstered",delta)
	_resolve_cal_action(street_mode and current_car==null and weapons.equipped=="holstered")
	_update_cal_navigation(delta)
	_pedestrian_scan += delta
	if not street_mode or _pedestrian_scan < 0.18:
		return
	_pedestrian_scan = 0.0
	var nearby: Array[CharacterBody3D] = []
	var fleet: Array = traffic.get("fleet")
	for vehicle in cars + officers + routine_patrols + fleet:
		if is_instance_valid(vehicle) and actor.global_position.distance_squared_to(vehicle.global_position) < 105.0 * 105.0:
			nearby.append(vehicle)
	pedestrians.call("react_to_traffic", nearby)

# The former chase camera always interpolated over the full world distance.
# Interiors are in a dedicated scene at (950, 950); on H exit this exposed the
# empty space between it and the city for many frames. A spatial discontinuity
# now snaps the camera, while regular following is collision-constrained.
func _camera_focus() -> Vector3:
	var actor := _actor()
	return actor.global_position + Vector3.UP * (
		1.65 if current_car != null or current_transit != null else 1.45)

func _camera_goal() -> Vector3:
	var distance := (3.0 if is_instance_valid(_opening_office) or interiors.call("is_inside") else
		(21.0 if transit_kind == "TRAIN" else
		(15.0 if transit_kind == "BUS" else
		(13.0 if current_car != null else 7.5))))
	return _camera_focus() + Vector3(0.0, sin(pitch) * distance,
		cos(pitch) * distance).rotated(Vector3.UP, yaw)

func _camera_clearance(focus: Vector3, target: Vector3) -> Vector3:
	var motion := target - focus
	if motion.length_squared() < 0.000001:
		return target
	# Sweep the near plane's clearance volume so canopy edges and corners
	# protect the whole view even when the camera arm's centre ray misses.
	_camera_probe.transform.origin = focus
	_camera_probe.motion = motion
	var ignored: Array[RID] = [player.get_rid()]
	if current_car != null:
		ignored.append(current_car.get_rid())
	if current_transit is CollisionObject3D:
		ignored.append((current_transit as CollisionObject3D).get_rid())
	if is_instance_valid(pedestrians):
		ignored.append_array(pedestrians.call("camera_exclusions"))
	_camera_probe.exclude = ignored
	var space := get_world_3d().direct_space_state
	var clearance := space.cast_motion(_camera_probe)
	if clearance[0] < 1.0:
		return focus + motion * clearance[0]
	# A sweep ignores a collider overlapping its starting volume. Check
	# the centreline so an avatar tight against a wall cannot orbit through it.
	var ray := PhysicsRayQueryParameters3D.create(focus, target, 1, ignored)
	var obstruction := space.intersect_ray(ray)
	if obstruction.is_empty():
		return target
	var hit: Vector3 = obstruction["position"]
	return focus + motion.normalized() * maxf(0.0, focus.distance_to(hit) - 0.30)

func _can_use_cinder_view() -> bool:
	return is_instance_valid(current_car) and current_car.get("model_id") == RoadCars.R9

func _adjust_cockpit_look(amount: Vector2) -> void:
	_cockpit_look.x = clampf(_cockpit_look.x + amount.x, -.60, .60)
	_cockpit_look.y = clampf(_cockpit_look.y + amount.y, -.22, .28)

func _toggle_cinder_view() -> void:
	if not _can_use_cinder_view():
		return
	_cinder_cockpit = not _cinder_cockpit
	_cockpit_look = Vector2.ZERO
	# Switch modes without sweeping the chase camera through the car.
	_snap_camera()
	_notify("Cinder cockpit view." if _cinder_cockpit else "Chase camera.")

func _update_camera(delta: float, teleport: bool = false) -> void:
	if camera == null or not is_instance_valid(player):
		return
	if _wardrobe_panel and _clothing_retail and venue_panel.visible:
		var visual:Node3D=player.get_node("Visual")
		var stick:=GameInput.look_vector()
		_fitting_rotation=wrapf(_fitting_rotation+stick.x*delta*2.2,-PI,PI)
		_fitting_zoom=clampf(_fitting_zoom-stick.y*delta*.8,0.0,1.0)
		var patch_view:=false
		if _wardrobe_category!="LOOKS" and _wardrobe_index>=0 and _wardrobe_index<Wardrobe.browse_ids().size():
			var selected:String=Wardrobe.browse_ids()[_wardrobe_index]
			patch_view=Wardrobe.reset_slot(selected)=="patch" or (Wardrobe.piece_valid(selected) and Wardrobe.PIECES[selected]["slot"]=="patch")
		visual.rotation.y=PI/2+_fitting_rotation+(PI if patch_view else 0.0)
		var focus:=player.global_position+Vector3.UP*lerpf(.03,.58,_fitting_zoom)
		var offset:=Vector3(2.25,.26,1.05)*lerpf(1.0,.53,_fitting_zoom)
		camera.global_position=_camera_clearance(focus,focus+offset)
		if camera.global_position.distance_squared_to(focus)>.001:
			camera.look_at(focus,Vector3.UP)
		return
	if _cinder_cockpit and _can_use_cinder_view():
		var coach := current_car.get_node("RoadCarVisual/Coachwork") as Node3D
		# Center-cabin viewpoint is clear of the seated driver mesh. This
		# is an interior perspective rather than an exact driver-eye rig.
		camera.global_position = coach.to_global(Vector3(.08, 1.12, .12))
		var view_basis := Basis.from_euler(Vector3(-.14 - _cockpit_look.y, _cockpit_look.x, 0.0))
		camera.global_basis = coach.global_basis.orthonormalized() * view_basis
		camera.fov = 78.0
		camera.near = .035
		_cockpit_camera_active = true
		return
	if _cockpit_camera_active:
		camera.fov = 68.0
		camera.near = .08
		_cockpit_camera_active = false
		teleport = true
	if not _can_use_cinder_view():
		_cinder_cockpit = false
		_cockpit_look = Vector2.ZERO
	var focus := _camera_focus()
	if weapon_aiming and _can_use_weapon():
		var shoulder := player.global_position + Vector3.UP * 0.65
		var forward := Vector3(0, sin(0.42 - pitch), -cos(0.42 - pitch)).rotated(Vector3.UP, yaw)
		var offset := Vector3(0.64, 0.20, 3.2).rotated(Vector3.UP, yaw)
		camera.global_position = _camera_clearance(shoulder, shoulder + offset)
		camera.look_at(camera.global_position + forward, Vector3.UP)
		return
	var goal := _camera_goal()
	var distance_to_goal := camera.global_position.distance_to(goal)
	# Suppress stale camera positions after a save-load or streaming jump
	# even when teleport was triggered through another system.
	if teleport or distance_to_goal > 35.0:
		if not teleport and distance_to_goal > 35.0:
			_log_playtest("camera_distance_snap", {"distance_m": snappedf(distance_to_goal, 0.01)})
		camera.global_position = _camera_clearance(focus, goal)
	else:
		var smoothed := camera.global_position.lerp(goal, minf(delta * 7.0, 1.0))
		camera.global_position = _camera_clearance(focus, smoothed)
	if camera.global_position.distance_squared_to(focus) > 0.000001:
		camera.look_at(focus, Vector3.UP)

func _snap_camera() -> void:
	_update_camera(0.0, true)

# Same reachability rule for the actual action and reduced-HUD prompt.
func _nearby_drivable_car() -> CharacterBody3D:
	var nearest: CharacterBody3D
	var nearest_distance := 5.0
	for car in cars:
		if not is_instance_valid(car):
			continue
		var dist := player.global_position.distance_to(car.global_position)
		if dist < nearest_distance:
			nearest = car
			nearest_distance = dist
	return nearest

func _toggle_car() -> void:
	if venue_panel != null and venue_panel.visible:
		_close_venue()
	if current_transit != null:
		_notify("You're a passenger. Press F to leave at the next stop.")
		return
	if current_car != null:
		var exit_trace: int = frame_time_recorder.begin_vehicle_transition("exit",str(current_car.get("model_id")))
		if int(current_car.call("speed_kph")) > 15:
			_log_playtest("vehicle_exit_blocked", {"reason": "speed"})
			_notify("Slow down before exiting.")
			frame_time_recorder.finish_vehicle_transition(exit_trace,"blocked_speed")
			return
		var exit_position := _clear_car_exit(current_car)
		frame_time_recorder.mark_vehicle_stage(exit_trace,"clearance")
		if not exit_position.is_finite():
			_log_playtest("vehicle_exit_blocked", {"reason": "clearance"})
			_notify("Both sides are blocked. Pull forward to make room.")
			frame_time_recorder.finish_vehicle_transition(exit_trace,"blocked_clearance")
			return
		player.global_position = exit_position
		player.velocity = Vector3.ZERO
		player.collision_layer = 1
		player.collision_mask = 1
		player.visible = true
		frame_time_recorder.mark_vehicle_stage(exit_trace,"capsule_visibility")
		player.set("driving", false)
		player.call("play_visual_action", &"alight_car")
		frame_time_recorder.mark_vehicle_stage(exit_trace,"rig_reparent_animation")
		if current_car.get("model_id") == RoadCars.R9:
			current_car.call("play_access_door", exit_position, true, player.get_rid())
		else:
			world_audio.call("play_event", "DOOR", current_car.global_position)
		frame_time_recorder.mark_vehicle_stage(exit_trace,"door_audio")
		_cancel_taxi()
		if is_instance_valid(_taxi_rider):
			_taxi_rider.call("hide_rider")
		_cancel_freight()
		current_car.set("occupied", false)
		current_car = null
		_cinder_cockpit = false
		_snap_camera()
		frame_time_recorder.mark_vehicle_stage(exit_trace,"occupancy_camera")
		_log_playtest("vehicle_exit", {"exit_x": exit_position.x, "exit_z": exit_position.z})
		_notify("Back on foot. Find your next pickup.")
		frame_time_recorder.mark_vehicle_stage(exit_trace,"log_hud")
		frame_time_recorder.finish_vehicle_transition(exit_trace,"ok")
		return
	var nearest := _nearby_drivable_car()
	if nearest == null:
		_notify("No vehicle nearby. Stand beside a parked car and press E.")
		return
	var entry_trace: int = frame_time_recorder.begin_vehicle_transition("enter",str(nearest.get("model_id")))
	current_car = nearest
	if nearest.get("model_id") == RoadCars.R9:
		nearest.call("play_access_door", player.global_position, false, player.get_rid())
	else:
		world_audio.call("play_event", "DOOR", nearest.global_position)
	frame_time_recorder.mark_vehicle_stage(entry_trace,"door_audio")
	_log_playtest("vehicle_enter", {"vehicle": nearest.name})
	frame_time_recorder.mark_vehicle_stage(entry_trace,"log")
	current_car.set("occupied", true)
	player.set("driving", true)
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0
	frame_time_recorder.mark_vehicle_stage(entry_trace,"occupancy_capsule_visibility")
	player.call("show_vehicle_rider", current_car, true)
	frame_time_recorder.mark_vehicle_stage(entry_trace,"rig_reparent_animation")
	if progression.owns_vehicle(str(current_car.get_meta("vehicle_id", ""))):
		_notify("Your vehicle. Drive with WASD; Space is the handbrake.")
	elif not current_car.has_meta("claimed"):
		current_car.set_meta("claimed", true)
		# Capture the entry position before the player is hidden. Resolve the
		# witness query in the next physics tick, not an input callback.
		_pending_theft = {"position": player.global_position + Vector3.UP * 0.55, "car": current_car}
		_notify("Vehicle acquired.")
	else:
		_notify("Drive with WASD. Space is the handbrake.")
	frame_time_recorder.mark_vehicle_stage(entry_trace,"claim_hud")
	frame_time_recorder.finish_vehicle_transition(entry_trace,"ok")

func _clear_car_exit(car: CharacterBody3D) -> Vector3:
	var space := get_world_3d().direct_space_state
	var excluded: Array[RID] = [player.get_rid(), car.get_rid()]
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	var collider := car.get_node("CollisionShape3D") as CollisionShape3D
	var body := collider.shape as BoxShape3D
	var threshold_y := collider.global_position.y - body.size.y * .5
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.collision_mask = 1
	clearance.exclude = excluded
	for side in [1.0, -1.0]:
		var point := car.to_global(Vector3(side * (body.size.x * .5 + capsule.radius + .125), 0, -.22))
		var floor := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .80,
			point - Vector3.UP * 1.42, 1, excluded)
		var support := space.intersect_ray(floor)
		if support.is_empty() or (support["normal"] as Vector3).y < .72:
			continue
		var ground_y := (support["position"] as Vector3).y
		if ground_y > threshold_y + .32 or ground_y < threshold_y - .42:
			continue
		point.y = ground_y + capsule.height * .5 + .045
		clearance.transform = Transform3D(Basis.IDENTITY, point)
		if not space.intersect_shape(clearance, 1).is_empty():
			continue
		var sill := car.to_global(Vector3(side * .85, 0, -.22))
		sill.y = point.y
		clearance.transform.origin = sill
		clearance.motion = point - sill
		# Casts omit overlaps at the start. Check both the sill and end point.
		if space.intersect_shape(clearance, 1).is_empty() and space.cast_motion(clearance)[0] >= 1.0:
			return point
	return Vector3.INF

func _advance_mission() -> void:
	if not courier_mission.mission_active():
		return
	var objective := courier_mission.objective()
	if courier_mission.gig_economy:
		if current_car != null or current_transit != null or interiors.call("is_inside"):
			return
		if not carrying and not venue_system.call("is_open",str(objective.get("vendor",""))):
			_notify("QuotaDrop: kitchen closed. Return during posted opening hours.")
			return
	var event_id: String = objective["id"]
	var result := courier_mission.advance(event_id, _actor().global_position, progression)
	match result.get("event", ""):
		"collected":
			world_audio.call("play_event", "PICKUP", _actor().global_position)
			_refresh_courier_target()
			if courier_mission.gig_economy:
				player.call("play_visual_action",&"interact")
				_notify("QuotaDrop: prepaid order collected. Deliver to the customer.")
			else:
				_notify("Package secured! Follow the cyan beacon.")
		"delivered":
			player.call("set_courier_conditioning",courier_mission.conditioning_rank())
			world_audio.call("play_event", "DELIVERY", _actor().global_position)
			_refresh_courier_target()
			if courier_mission.gig_economy:
				player.call("play_visual_action",&"interact")
				_notify("QuotaDrop: delivered. +$%d base + $%d tip. Next order offered." % [objective["base_pay"],objective["tip"]])
			else:
				_notify("Delivery done! +$%d. Next pickup marked in amber." % int(result["reward"]))
			if story_mission.event("courier_delivered", progression) == "delivered":
				_notify("Delivery done! +$%d. Report back to Mara at Lantern Cup." % int(result["reward"]))
		"blocked":
			_notify("Cannot settle delivery. Check wallet capacity.")

func _refresh_courier_target() -> void:
	_set_mission_target(courier_mission.target() - Vector3.UP * 0.2, carrying)
	if is_instance_valid(player):
		var visual: Node3D = player.get("visual")
		if is_instance_valid(visual):
			visual.call("set_meal_bag",courier_mission.gig_economy and carrying)

func _set_mission_target(pos: Vector3, has_package: bool) -> void:
	mission_position = pos + Vector3.UP * 0.2
	if marker == null:
		return
	marker.global_position = mission_position
	marker.visible = courier_mission.mission_active()
	var color := Color("38e5e4") if has_package else Color("ffba56")
	for child in marker.get_children():
		if child is MeshInstance3D:
			var material := (child as MeshInstance3D).material_override as StandardMaterial3D
			if material != null:
				material.albedo_color = Color(color.r, color.g, color.b, 0.45)
				material.emission = color
	marker_light.light_color = color

func _register_police_stations() -> void:
	for site in civic_services.call("police_station_sites"):
		var district: String = city_details.call("get_district_at", site["address"])
		dispatch.register_station(site["id"], site["name"], district, site["address"], site["launch"], site["capacity"], site["hq"])

func _configure_ambient_civic() -> void:
	var sites: Array[Dictionary] = []
	for pin in civic_services.call("get_map_pins"):
		if bool(pin.get("station", false)):
			continue
		var id := str(pin["id"])
		var site: Dictionary = civic_services.call("site_by_id", id)
		if site.is_empty():
			continue
		var address: Vector3 = civic_services.call("position_for", id)
		# Same street-side staging convention as registered police stations.
		var point := Vector3(address.x, 1.1, float(site["iz"]) * 58.0 + 3.25)
		var ranked: Array[Dictionary] = dispatch.ranked(point, {})
		if ranked.is_empty():
			continue
		sites.append({"site_id":id, "point":point, "station_id":ranked[0]["id"],
			"district":str(city_details.call("get_district_at", address))})
	ambient_civic.configure(int(session.get("world_seed")), sites)

func _update_ambient_civic(delta: float) -> void:
	if not bool(day_night.get("paused")):
		var minutes := delta * 1440.0 / DayNightScript.DAY_LENGTH_SECONDS
		ambient_civic.advance(minutes)
		road_restrictions.advance(minutes)

func _update_civic_patrols(delta: float) -> void:
	if bool(day_night.get("paused")):
		return
	if not civic_patrol_service.task.is_empty():
		if not is_instance_valid(_civic_patrol) or float(_civic_patrol.get("condition")) <= 18.0:
			civic_patrol_service.finish("INTERRUPTED")
			_release_civic_patrol()
			return
		var goal: Vector3 = civic_patrol_service.task["point"]
		var at := Vector2(_civic_patrol.global_position.x, _civic_patrol.global_position.z)
		var target := Vector2(goal.x, goal.z)
		var policy = _civic_patrol.get("drive_policy")
		var arrived: bool = at.distance_to(target) <= 7.0 and absf(float(_civic_patrol.get("speed"))) <= 1.0 and (policy.arrived(at, target) or bool(_civic_patrol.get("civic_service_hold")))
		civic_patrol_service.tick(delta, arrived)
		if civic_patrol_service.task.is_empty():
			_release_civic_patrol()
		elif civic_patrol_service.task["phase"] == "SERVICING":
			_civic_patrol.set("civic_service_hold", true)
		return
	_civic_patrol_poll -= delta
	if _civic_patrol_poll > 0.0:
		return
	_civic_patrol_poll = 1.0
	# Existing response fleet remains dedicated to actual witnessed player events.
	if Wanted.stars(heat) > 0:
		return
	var cases: Array[Dictionary] = ambient_civic.catalog()
	civic_patrol_service.prune(cases)
	for incident in cases:
		if incident["state"] != "ACTIVE":
			continue
		for patrol in routine_patrols:
			if not is_instance_valid(patrol) or float(patrol.get("condition")) <= 18.0 or patrol.get_meta("station_id") != incident["station_id"]:
				continue
			if civic_patrol_service.claim(incident, str(patrol.get_meta("unit_id"))):
				_civic_patrol = patrol
				patrol.set("police_destination", incident["point"])
				patrol.set("police_priority", false)
				patrol.get("drive_policy").reset()
				return

func _release_civic_patrol() -> void:
	if is_instance_valid(_civic_patrol):
		_civic_patrol.set("civic_service_hold", false)
		_civic_patrol.set("police_destination", Vector3.INF)
		_civic_patrol.set("police_priority", false)
		_civic_patrol.get("drive_policy").reset()
	_civic_patrol = null

func _build_routine_patrols() -> void:
	# Two visible patrol cars on fixed street loops, present even at zero
	# heat. Keep them separate from the five-unit dispatch budget.
	for i in range(2):
		var route: Array[Vector3] = []
		var span := 58.0 if i == 0 else 174.0
		route.assign([Vector3(-span + 3.25, 1.1, -span + 3.25),
			Vector3(span - 3.25, 1.1, -span + 3.25),
			Vector3(span - 3.25, 1.1, span - 3.25),
			Vector3(-span + 3.25, 1.1, span - 3.25)])
		var start := i * 2
		var patrol := _create_car(route[start], Color("192943"), true)
		patrol.name = "RoutinePatrol_%d" % i
		patrol.set_meta("station_id", "central" if i == 0 else "west")
		patrol.set_meta("unit_id", "PATROL-%02d" % (i + 1))
		patrol.set("routine_route", route)
		patrol.set("routine_index", (start + 1) % route.size())
		var direction := route[(start + 1) % route.size()] - route[start]
		patrol.rotation.y = atan2(-direction.x, -direction.z)
		routine_patrols.append(patrol)

func _witness_candidates(at: Vector3) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = venue_system.call("witness_candidates", at)
	candidates.append_array(traffic.call("witness_candidates", at))
	if is_instance_valid(pedestrians) and not interiors.call("is_inside"):
		candidates.append_array(pedestrians.call("witness_candidates", at, camera))
	for patrol in routine_patrols + officers:
		if is_instance_valid(patrol) and float(patrol.get("condition")) > 18.0 and patrol.global_position.distance_squared_to(at) < 45.0 * 45.0:
			candidates.append({"eye": patrol.global_position + Vector3.UP * 0.65, "facing": -patrol.global_basis.z, "police": true, "rid": patrol.get_rid()})
	return candidates

func _witness_at(at: Vector3, extra: CollisionObject3D = null) -> Dictionary:
	var ignore: Array[RID] = [player.get_rid()]
	if is_instance_valid(extra):
		ignore.append(extra.get_rid())
	return wanted.witnesses(get_world_3d().direct_space_state, at, _witness_candidates(at), ignore)

func _report_incident(reason: String, at: Vector3, officer: bool) -> void:
	var previous: int = Wanted.stars(heat)
	heat = wanted.report(heat, reason, at, officer)
	dispatch.report(reason, at, Wanted.stars(heat))
	_log_playtest("wanted_report", {"reason": reason, "officer": officer, "stars": Wanted.stars(heat)})
	if Wanted.stars(heat) > previous:
		police_cooldown = minf(police_cooldown, 1.0)
	_notify("REPORTED • %s • %d STAR%s" % [reason, Wanted.stars(heat), "" if Wanted.stars(heat) == 1 else "S"])
	if is_instance_valid(pedestrians) and officer:
		var ignore: Array[RID] = [player.get_rid()]
		pedestrians.call("react_to_incident", at, 18.0, ignore)

func _update_wanted(delta: float) -> void:
	var actor := _actor()
	var indoors: bool = interiors.call("is_inside")
	if _pending_theft != null:
		var event: Dictionary = _pending_theft
		_pending_theft = null
		var at: Vector3 = event["position"]
		var sight := _witness_at(at, event["car"])
		if bool(sight["any"]):
			_report_incident("THEFT", at, bool(sight["police"]))
		else:
			_notify("Vehicle acquired • no report")
	_sight_clock += delta
	if _sight_clock >= Wanted.SIGHT_INTERVAL:
		var elapsed := _sight_clock
		_sight_clock = 0.0
		var at := actor.global_position + Vector3.UP * 0.55
		var sight: Dictionary = {"any": false, "police": false}
		if not indoors and (weapons.equipped != "holstered" or Wanted.stars(heat) > 0):
			sight = _witness_at(at, actor as CollisionObject3D)
		var old_heat := heat
		heat = wanted.observe(heat, at, sight, not indoors and current_car == null and current_transit == null and weapons.equipped != "holstered", elapsed)
		if heat > old_heat:
			dispatch.report("BRANDISH", at, Wanted.stars(heat))
			_log_playtest("wanted_report", {"reason": "BRANDISH", "officer": bool(sight["police"]), "stars": Wanted.stars(heat)})
			if Wanted.stars(heat) > Wanted.stars(old_heat):
				police_cooldown = minf(police_cooldown, 1.0)
				_notify("WEAPON REPORTED • police dispatched")
	heat = wanted.decay(heat, delta)
	police_cooldown -= delta
	var tier: int = Wanted.stars(heat)
	dispatch.update_case(wanted.last_known, tier)
	# Response units released from an incident return to their registered
	# staging point. Count them against the fleet until they arrive.
	for i in range(officers.size() - 1, -1, -1):
		var car := officers[i]
		if not is_instance_valid(car) or tier == 0 or i >= tier or (float(car.get("condition")) <= 18.0 and police_cooldown <= 0.0):
			if is_instance_valid(car):
				_release_response(car)
			officers.remove_at(i)
	_update_returning_units()
	if tier > 0 and not indoors and wanted.last_known.is_finite() and officers.size() < tier and officers.size() + returning_units.size() < PoliceDispatch.MAX_UNITS and police_cooldown <= 0.0:
		_spawn_police()
		police_cooldown = Wanted.reinforcement_delay(heat)
	# Fictional dispatch policy: only a bounded subset uses warning lights
	# and urgent response; remaining units travel under ordinary traffic rules.
	# Priority is a gameplay decision, not a reproduction of an agency rule.
	var hour: float = day_night.get("hour")
	var night := hour < 6.0 or hour > 19.0
	for i in range(officers.size()):
		var officer := officers[i]
		if is_instance_valid(officer):
			officer.set("police_destination", wanted.last_known)
			officer.set("response_level", tier)
			officer.set("police_priority", i < 2 and tier >= 3 and wanted.police_seen)
			officer.set("police_night", night)
	for patrol in routine_patrols:
		if is_instance_valid(patrol):
			patrol.set("police_night", night)

func _release_response(car: CharacterBody3D) -> void:
	var unit_id := str(car.get_meta("unit_id", "LEGACY"))
	var station: Dictionary = dispatch.stations.get(str(car.get_meta("station_id", "")), {})
	if station.is_empty() or float(car.get("condition")) <= 18.0:
		dispatch.unavailable(unit_id)
		car.queue_free()
		return
	dispatch.released(unit_id)
	car.set("police_priority", false)
	car.set("police_destination", station["launch"])
	returning_units.append(car)

func _update_returning_units() -> void:
	for i in range(returning_units.size() - 1, -1, -1):
		var car := returning_units[i]
		if not is_instance_valid(car):
			returning_units.remove_at(i)
			continue
		var goal: Vector3 = car.get("police_destination")
		var plan = car.get("drive_policy")
		if car.global_position.distance_to(goal) < 4.0 or plan.arrived(Vector2(car.global_position.x, car.global_position.z), Vector2(goal.x, goal.z)):
			dispatch.available(str(car.get_meta("unit_id", "LEGACY")))
			car.queue_free()
			returning_units.remove_at(i)

func _spawn_police() -> void:
	if not wanted.last_known.is_finite() or officers.size() + returning_units.size() >= PoliceDispatch.MAX_UNITS:
		return
	dispatch.update_case(wanted.last_known, Wanted.stars(heat))
	var deployed := {}
	for vehicle in officers + returning_units:
		if is_instance_valid(vehicle):
			var id := str(vehicle.get_meta("station_id", ""))
			deployed[id] = int(deployed.get(id, 0)) + 1
	for station in dispatch.ranked(wanted.last_known, deployed):
		var launch: Vector3 = station["launch"]
		var clear := true
		for vehicle in officers + returning_units + routine_patrols + cars + traffic.get("fleet"):
			if is_instance_valid(vehicle) and launch.distance_to(vehicle.global_position) < 6.0:
				clear = false
				break
		if not clear or launch.distance_to(_actor().global_position) < 4.0:
			continue
		var officer := _create_car(launch, Color("192943"), true)
		var id: String = station["id"]
		var unit: String = dispatch.assign(id)
		officer.name = "DispatchUnit_" + unit
		officer.set_meta("station_id", id)
		officer.set_meta("unit_id", unit)
		officer.set("police_destination", wanted.last_known)
		officer.set("response_level", Wanted.stars(heat))
		# Exit the staging lane facing east; the road controller handles turns.
		officer.rotation.y = -PI * 0.5
		officers.append(officer)
		_log_playtest("police_spawn", {"x": launch.x, "z": launch.z, "tier": Wanted.stars(heat), "station": id, "unit": unit})
		return

func _reset_pursuit_runtime() -> void:
	# Response cars and queued witness events belong to the current runtime,
	# never to the save being restored. Keep permanent stations and patrols.
	for officer in officers + returning_units:
		if is_instance_valid(officer):
			officer.set_physics_process(false)
			officer.collision_layer = 0
			officer.collision_mask = 0
			officer.hide()
			officer.queue_free()
	officers.clear()
	returning_units.clear()
	dispatch.update_case(Vector3.INF, 0)
	wanted.reset()
	_pending_theft = null
	_sight_clock = 0.0
	police_cooldown = 0.0

func _respawn() -> void:
	if is_instance_valid(_taxi_rider):
		_taxi_rider.call("hide_rider")
	_cancel_taxi()
	_cancel_freight()
	_garden_trail_mask=0
	_driving_trial.stop("ABANDONED")
	_cancel_street_interactions()
	_log_playtest("respawn", {"health": health, "reason": "fall_or_boundary_or_damage"})
	_close_venue()
	weapons.holster()
	weapon_aiming = false
	_fire_held = true
	if interiors.call("is_inside"):
		interiors.call("leave")
	current_transit = null
	transit_kind = ""
	_active_station_lift = null
	_rail_platform_rider = false
	if current_car != null:
		current_car.set("occupied", false)
		current_car = null
	player.set("driving", false)
	player.collision_layer = 1
	player.collision_mask = 1
	player.visible = true
	player.global_position = PLAYER_START
	player.velocity = Vector3.ZERO
	health = 100.0
	player.call("restore_stamina",100.0)
	heat = 0.0
	_reset_pursuit_runtime()
	var failed_story := story_mission.interrupt("failed")
	var lost_order := courier_mission.gig_economy and courier_mission.restart()
	if lost_order:
		_refresh_courier_target()
	progression.charge_up_to(100)
	city_details.call("set_focus", player.global_position)
	_snap_camera()
	_notify("Returned to the street. Emergency recovery fee: up to $100." + (" Order canceled without pay." if lost_order else "") + (" Contact mission failed; speak to Mara to retry." if failed_story else ""))

func _notify(message: String) -> void:
	notification = message
	notification_time = 6.0

func _make_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.12
	material.roughness = 0.77
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.7
	return material

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color, collider: bool = false, glow: bool = false, surface_kind: String = "") -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	visual.position = at
	visual.material_override = Materials.surface(surface_kind, color) if not surface_kind.is_empty() else _make_material(color, glow)
	parent.add_child(visual)
	if collider:
		var static_body := StaticBody3D.new()
		static_body.position = at
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = dimensions
		shape.shape = box_shape
		static_body.add_child(shape)
		parent.add_child(static_body)
	return visual

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101627")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8194c4")
	environment.ambient_light_energy = 0.65
	# Forward+ baseline: physically inspired PBR, contact occlusion, atmospheric depth.
	# Keep SDFGI, volumetric fog and shadow-casting local lights OFF for performance.
	environment.ssr_enabled = true
	environment.ssr_max_steps = 24
	environment.ssr_fade_out = 1.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.46
	environment.glow_hdr_threshold = 1.15
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.85
	environment.ssao_intensity = 0.95
	environment.ssao_power = 1.25
	environment.ssil_enabled = false
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.0085
	environment.fog_light_color = Color("2b354b")
	environment.fog_sky_affect = 0.35
	world_environment.environment = environment
	add_child(world_environment)
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48.0, -27.0, 0.0)
	sun_light.light_color = Color("ffc39e")
	sun_light.light_energy = 0.7
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 170.0
	add_child(sun_light)
	# The playable foundation stops at the authored perimeter. Beyond this
	# point the quay/water, wooded ridges and industrial yard own the skyline.
	_box(self, Vector3(0.0, -0.58, 0.0), Vector3(490.0, 1.0, 490.0), Color("34434a"), true, false, "CONCRETE")

func _build_city() -> void:
	# Replace the overlapping visual strips with continuous UV-authored
	# photographic asphalt. The world foundation remains the collider.
	var pavement := PhotoRoadNetwork.new()
	pavement.name = "PhotoRoadNetwork"
	add_child(pavement)
	var sidewalk := Color("b2b0ac")
	for block_x in range(-GRID_RADIUS, GRID_RADIUS):
		for block_z in range(-GRID_RADIUS, GRID_RADIUS):
			var center := Vector3((float(block_x) + 0.5) * CELL, 0.07, (float(block_z) + 0.5) * CELL)
			_box(self, center, Vector3(42.0, 0.14, 42.0), sidewalk, false, false, "PHOTO_SIDEWALK").name = "PhotographicSidewalk_%d_%d" % [block_x,block_z]
	city_details = CityDetailsScript.new()
	city_details.name = "CityDetails"
	add_child(city_details)
	city_details.call("set_world_seed", rng.seed)
	city_details.call("set_world_manifest", session.call("get_world_manifest"))
	city_details.call("generate")

func _build_city_perimeter() -> void:
	# Permanent geography is independent of streamed lots and saved seeds.
	city_perimeter = CityPerimeterScript.new()
	city_perimeter.name = "MorrowBayPerimeter"
	city_perimeter.set("ridge_pilot_enabled", "--horizon-ridge" in OS.get_cmdline_user_args())
	add_child(city_perimeter)

func _build_world_systems() -> void:
	# Geography and story anchors are authored; botanical infill is seeded.
	flora = FloraScript.new()
	flora.name = "CityFlora"
	add_child(flora)
	flora.call("set_world_seed", rng.seed)
	flora.call("generate")
	street_lights = NightLightingScript.new()
	street_lights.name = "NightLighting"
	add_child(street_lights)
	wet_streets = WetStreetsScript.new()
	wet_streets.name = "WetStreets"
	add_child(wet_streets)
	hero_intersection = HeroIntersectionScript.new()
	hero_intersection.name = "CentralExchangeHero"
	add_child(hero_intersection)
	day_night = DayNightScript.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.call("configure", world_environment, sun_light, city_details, street_lights, hero_intersection)
	day_night.call("register_surface_receiver", get_node("PhotoRoadNetwork"))
	day_night.call("register_surface_receiver", wet_streets)
	venue_system = VenueSystemScript.new()
	venue_system.name = "SocialVenues"
	add_child(venue_system)
	venue_system.call("set_hour", float(day_night.get("hour")))
	civic_services = CivicServicesScript.new()
	civic_services.name = "CivicServices"
	add_child(civic_services)
	civic_services.call("set_hour", float(day_night.get("hour")))
	if not courier_mission.configure_gig_routes(venue_system,civic_services):
		push_error("QuotaDrop authored route catalog failed to resolve")
	interiors = InteriorSystemScript.new()
	interiors.name = "Interiors"
	add_child(interiors)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = PLAYER_START
	var capsule := CollisionShape3D.new()
	capsule.name = "CollisionShape3D"
	var collision := CapsuleShape3D.new()
	collision.radius = 0.45
	collision.height = 1.9
	capsule.shape = collision
	player.add_child(capsule)
	var visual := CourierVisual.new()
	visual.name = "Visual"
	# The avatar's boots meet the physical 1.9-metre capsule footprint.
	visual.position.y = CourierVisual.FOOT_OFFSET
	player.add_child(visual)
	add_child(player)
	_weapon_audio = AudioStreamPlayer3D.new()
	_weapon_audio.name = "WeaponEffects"
	_weapon_audio.bus = AudioMix.EFFECTS
	_weapon_audio.unit_size = 4.0
	_weapon_audio.max_distance = 65.0
	player.add_child(_weapon_audio)
	# Cache original effects once, not on the physics tick.
	for kind in ["PULSE", "ARC", "RELOAD"]:
		CombatFoley.sound(kind)

func _create_car(where: Vector3, color: Color, police: bool = false, model_id: String = "") -> CharacterBody3D:
	var car := CharacterBody3D.new()
	car.name = "PoliceCruiser" if police else "StreetVehicle"
	car.set_script(CarScript)
	car.position = where
	car.set("is_police", police)
	if police:
		car.set("police_signals", signal_controller)
	var hitbox := CollisionShape3D.new()
	hitbox.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.35, 1.65, 4.7)
	hitbox.shape = shape
	car.add_child(hitbox)
	if model_id == RoadCars.R9:
		car.call("configure_road_car", model_id)
		shape.size = RoadCars.DATA[model_id]["body"]
		hitbox.position.y = shape.size.y * .5 + RoadCarVisual.GROUND
		var supercar := RoadCarVisual.new()
		supercar.name = "RoadCarVisual"
		supercar.configure(color)
		car.add_child(supercar)
	else:
		var hero := KestrelVisual.new()
		hero.name = "KestrelS6HeroVisual"
		hero.configure(color, police)
		car.add_child(hero)
	add_child(car)
	return car

func _spawn_traffic() -> void:
	var parked := [
		Vector3(5.0, 1.0, 18.0), Vector3(-63.0, 1.0, -28.0),
		Vector3(63.0, 1.0, 33.0), Vector3(121.0, 1.0, 88.0),
		Vector3(-121.0, 1.0, -80.0), Vector3(-5.0, 1.0, 125.0),
		Vector3(63.0, 1.0, -143.0), Vector3(-63.0, 1.0, 139.0),
		Vector3(-237.0, 1.0, -202.0), Vector3(237.0, 1.0, -146.0),
		Vector3(203.0, 1.0, 237.0), Vector3(-146.0, 1.0, 237.0)
	]
	for i in range(parked.size()):
		var model_id := RoadCars.R9 if i in RoadCars.R9_PAID_PARKING_SLOTS else ""
		var color: Color = RoadCars.R9_PAID_PARKING_SLOTS.get(i, VEHICLE_COLORS[i % VEHICLE_COLORS.size()])
		var car := _create_car(parked[i], color, false, model_id)
		car.rotation.y = PI if i % 2 == 1 else 0.0
		car.set_meta("vehicle_id", RoadCars.PARKED_IDS[i])
		cars.append(car)

func _build_transport() -> void:
	signal_controller = TrafficSignalsScript.new()
	signal_controller.name = "TrafficSignals"
	add_child(signal_controller)
	traffic = TrafficSystemScript.new()
	traffic.name = "SurfaceTraffic"
	add_child(traffic)
	_pooled_traffic_enabled = _pooled_traffic_enabled or "--pooled-traffic" in OS.get_cmdline_user_args()
	traffic.call("initialize", rng.seed, signal_controller, _pooled_traffic_enabled)
	rail = RailSystemScript.new()
	rail.name = "MorrowLine"
	add_child(rail)

func _toggle_transit() -> void:
	if current_car != null:
		_notify("Park and exit your car before boarding transit.")
		return
	if current_transit != null:
		if transit_kind == "LIFT":
			_notify("Wait for the lift to reach the landing.")
			return
		var exit_pos := Vector3.ZERO
		if transit_kind == "BUS":
			if not bool(current_transit.call("is_boardable")):
				_notify("Wait for the bus to stop before alighting.")
				return
			exit_pos = current_transit.call("alight_position")
		else:
			if not bool(rail.call("can_alight")):
				_notify("M-Line is moving. Wait for the next station.")
				return
			exit_pos = rail.call("alight_position", _rail_platform_rider)
		_leave_transit(exit_pos, "M-Line platform. Use the lift to return to the street." if _rail_platform_rider else "Back on the street.")
		return
	var lift: Node3D = rail.call("lift_at", player.global_position)
	if lift != null:
		_active_station_lift = lift
		lift.call("start", player.global_position)
		_board_transit(lift.get("carrier"), "LIFT")
		_notify("M-Line lift called.")
		return
	if bool(rail.call("boardable_from", player.global_position)):
		_board_transit(rail.get_node("MorrowLineTrain"), "TRAIN")
		_rail_platform_rider = rail.call("on_platform", player.global_position, int(rail.get("current_station")))
		_notify("M-Line boarded. F to leave at a station.")
		return
	var bus: CharacterBody3D = traffic.call("get_boardable_bus", player.global_position)
	if bus != null:
		_board_transit(bus, "BUS")
		_notify("City Loop boarded. F to leave at the next stop.")
		return
	_notify("Board a stopped vehicle or use a marked M-Line lift.")

func _board_transit(vehicle: Node3D, kind: String, play_audio: bool = true) -> void:
	current_transit = vehicle
	transit_kind = kind
	player.set("driving", true)
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	if play_audio:
		world_audio.call("play_event", _transit_sound(kind), vehicle.global_position)
	_log_playtest("transit_board", {"kind": kind})

func _leave_transit(at: Vector3, message: String = "Back on the street.") -> void:
	world_audio.call("play_event", _transit_sound(transit_kind), at)
	_log_playtest("transit_exit", {"kind": transit_kind, "destination": [at.x, at.y, at.z]})
	current_transit = null
	transit_kind = ""
	_rail_platform_rider = false
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.collision_layer = 1
	player.collision_mask = 1
	player.visible = true
	player.set("driving", false)
	_notify(message)

func _transit_sound(kind: String) -> String:
	if kind == "TRAIN":
		return "RAIL_DOOR"
	if kind == "BUS":
		return "BUS_DOOR"
	return "TRANSIT"

# All player-facing save paths use this same live location/entitlement gate.
# The free check-in is at the real hotel door, not a global pre-tenancy exemption.
func save_availability() -> Dictionary:
	if is_instance_valid(_opening_office):
		return {"allowed": false, "reason": "Finish the corporate prologue before saving."}
	if not is_instance_valid(player) or current_car != null or current_transit != null:
		return {"allowed": false, "reason": "Save on foot at Lantern Court."}
	if interiors.call("is_inside") or venue_panel.visible or (is_instance_valid(equipment_wheel) and equipment_wheel.visible):
		return {"allowed": false, "reason": "Leave the current interaction and visit Lantern Court."}
	var lot: Node3D = city_details.call("nearby_walk_in", player.global_position)
	if not is_instance_valid(lot) or str(lot.get("home_id")) != StarterHome.ID:
		return {"allowed": false, "reason": "Visit Lantern Court to save."}
	var at_save_point: bool = lot.call("home_action", player.global_position) == "save" if progression.owns_home() else (bool(lot.call("doorway_reachable", player.global_position)) and not bool(lot.call("contains", player.global_position)))
	if not at_save_point:
		return {"allowed": false, "reason": "Approach your capsule's save desk." if progression.owns_home() else "Use the free check-in checkpoint at the hotel entrance."}
	if heat > 0.01:
		return {"allowed": false, "reason": "Lose police attention before saving."}
	return {"allowed": true, "reason": "Capsule save desk ready." if progression.owns_home() else "Free hotel check-in checkpoint ready."}

func _save_game() -> bool:
	var availability := save_availability()
	var message: String
	var success := false
	if not bool(availability["allowed"]):
		message = str(availability["reason"])
		_log_playtest("save_blocked", {"reason": message})
	elif bool(session.call("save_snapshot", _capture_snapshot())):
		success = true
		message = "Progress saved at Lantern Court."
		if game_menu != null:
			game_menu.call("set_has_save", true)
		_log_playtest("save_success", {"seed": int(session.get("world_seed"))})
	else:
		_log_playtest("save_failed")
		message = "Save failed. Check user data folder or permissions."
	_notify(message)
	if game_menu != null and game_menu.call("is_open"):
		game_menu.call("set_save_feedback", message)
	return success

func _load_game() -> void:
	_close_arcade()
	if game_menu != null and game_menu.call("is_open"):
		game_menu.call("hide_for_game")
	if not bool(session.call("prepare_load")):
		_log_playtest("load_failed", {"reason": "no_valid_slot"})
		_notify("No valid saved game in slot 1.")
		return
	_log_playtest("load_requested")
	playtest_logger.flush()
	get_tree().call_deferred("reload_current_scene")

func _new_game() -> void:
	_close_arcade()
	if game_menu != null and game_menu.call("is_open"):
		game_menu.call("hide_for_game")
	_log_playtest("new_game_requested")
	playtest_logger.flush()
	session.call("start_new_game")
	get_tree().call_deferred("reload_current_scene")

func _capture_snapshot() -> Dictionary:
	var stored_cars := []
	for car in cars:
		var saved := {
			"position": [car.global_position.x, car.global_position.y, car.global_position.z],
			"yaw": car.rotation.y, "claimed": car.has_meta("claimed"),
			"condition": car.get("condition")
		}
		# Preserve pristine legacy sedan records; damaged sedans now use the
		# same optional four-channel field as Cinder. Old saves still load.
		if car.get("model_id") == RoadCars.R9 or car.get("damage_zones") != Vector4.ZERO:
			var zones: Vector4 = car.get("damage_zones")
			saved["damage"] = [zones.x, zones.y, zones.z, zones.w]
		stored_cars.append(saved)
	var aboard_id := ""
	if transit_kind == "BUS" and current_transit != null:
		aboard_id = str(current_transit.get("vehicle_id"))
	# A save during an elevator transfer resumes safely at its destination.
	var saved_at := player.global_position
	if _active_station_lift != null:
		saved_at = _active_station_lift.call("destination")
	var state := {
		"player_position": [saved_at.x, saved_at.y, saved_at.z],
		"camera_yaw": yaw, "cash": cash, "progression": progression.snapshot(), "health": health, "heat": heat,
		"deliveries": deliveries, "carrying": carrying, "story_mission": story_mission.snapshot(),
		"courier_offer_offset": courier_mission.offer_offset, "courier_on_duty":courier_mission.on_duty,
		"investigation_stage": investigation.stage,
		"hour": day_night.get("hour"), "day_index":day_night.get("day_index"), "cars": stored_cars,
		"occupied_car": cars.find(current_car),
		"traffic": traffic.call("snapshot"), "rail": rail.call("snapshot"),
		"signal_elapsed": signal_controller.get("elapsed"),
		"transit_kind": "" if transit_kind == "LIFT" else transit_kind, "transit_id": aboard_id,
		"rail_platform_rider": _rail_platform_rider,
		"venue_job_active": venue_job_active, "venue_job_completed": venue_job_completed.duplicate(),
		"civic_job_active": civic_job_active, "civic_job_completed": civic_job_completed.duplicate(),
		"civic_intel": civic_intel.duplicate(), "ration_packs": ration_packs,
		"consumables": consumable_inventory.duplicate(), "stamina": player.get("stamina"),
		"interior": interiors.call("snapshot"), "arcade_best": _arcade_best.duplicate(),
		"navigation_waypoint": [] if navigation_waypoint == null or not _vehicle_job_waypoint_owner.is_empty() else [navigation_waypoint.x, navigation_waypoint.y],
		"weapons": weapons.snapshot(),
		"ambient_civic": ambient_civic.snapshot(),
		"civic_patrol_service": civic_patrol_service.snapshot(),
		"wanted_last_known": [wanted.last_known.x, wanted.last_known.y, wanted.last_known.z] if Wanted.stars(heat) > 0 and wanted.last_known.is_finite() else []
	}
	if is_instance_valid(pedestrians):
		var street_state: Dictionary = pedestrians.call("snapshot")
		if not street_state.is_empty():
			state["sidewalk_population"] = street_state
	if is_instance_valid(nightgrid_fm):
		var tuning: Dictionary = nightgrid_fm.call("snapshot")
		if not tuning.is_empty():
			state["nightgrid_radio"] = tuning
	var repair := _repair_storefront()
	if repair != null and (repair.contains(saved_at) or repair.door_reachable(saved_at)):
		state["night_shift_door_open"] = repair.door.is_requested_open() or repair.overlaps_threshold(saved_at)
	return state

func _apply_snapshot(data: Dictionary) -> void:
	if is_instance_valid(_taxi_rider):
		_taxi_rider.call("hide_rider")
	_cancel_taxi()
	_cancel_freight()
	_garden_trail_mask=0
	_driving_trial.stop("ABANDONED")
	_close_arcade()
	_cancel_street_interactions()
	if is_instance_valid(dialogue_director):
		dialogue_director.call("cancel_all")
	if not progression.restore(data.get("cash", 0), data.get("progression", {"version": ProgressionLedger.VERSION, "receipts": []})):
		push_error("Invalid progression snapshot")
		return
	_arcade_best = ArcadeScores.normalized(data.get("arcade_best", {}))
	var saved_visual: Node3D = player.get("visual")
	if is_instance_valid(saved_visual):
		saved_visual.call("set_look",progression.outfit_id,progression.clothing_slots)
	_cinder_cockpit = false
	_cockpit_look = Vector2.ZERO
	# Geometry is already reconstructed from the saved immutable seed.
	if is_instance_valid(nightgrid_fm):
		nightgrid_fm.call("restore", data.get("nightgrid_radio", {}))
	# A saved active favor is explicit prior opt-in; do not strand the job
	# when the next launch omits --living-streets.
	if progression.cal_quest in [1,2] and not is_instance_valid(pedestrians):
		enable_living_streets()
	if is_instance_valid(pedestrians):
		pedestrians.call("restore", data.get("sidewalk_population", {}))
	_vehicle_job_waypoint_owner = ""
	navigation_waypoint = Nav.decode(data.get("navigation_waypoint", []))
	# No live closures are saved until physical scene/traffic integration.
	road_restrictions = RoadRestrictions.new()
	_route_revision = -1
	_route_cache.clear()
	weapons.restore(data.get("weapons", {}))
	ambient_civic.restore(data.get("ambient_civic", {}))
	_release_civic_patrol()
	civic_patrol_service.restore(data.get("civic_patrol_service", {}))
	_civic_radio_announced.clear()
	traffic.call("restore", data["traffic"])
	rail.call("restore", data["rail"])
	signal_controller.set("elapsed", fposmod(float(data.get("signal_elapsed", 0.0)), 72.0))
	health = clampf(float(data.get("health", 100.0)), 1.0, 100.0)
	_reset_pursuit_runtime()
	heat = clampf(float(data.get("heat", 0.0)), 0.0, 5.0)
	if Wanted.stars(heat) == 0:
		heat = 0.0
	var last: Variant = data.get("wanted_last_known", [])
	if last is Array and last.size() == 3 and (last[0] is float or last[0] is int) and (last[1] is float or last[1] is int) and (last[2] is float or last[2] is int):
		var p := Vector3(float(last[0]), float(last[1]), float(last[2]))
		if p.is_finite() and absf(p.x) <= 390.0 and absf(p.z) <= 390.0 and absf(p.y) <= 25.0 and heat >= Wanted.MIN_HEAT:
			wanted.last_known = p
	# Restore only a valid saved case; never invent a witness or position.
	dispatch.update_case(wanted.last_known, Wanted.stars(heat))
	courier_mission.gig_economy = progression.has_receipt(Opening.RECEIPT)
	courier_mission.restore(data.get("deliveries", 0), data.get("carrying", false))
	courier_mission.restore_offer_offset(data.get("courier_offer_offset",0))
	courier_mission.restore_duty(data.get("courier_on_duty",true))
	investigation.restore(int(data.get("investigation_stage",0)),progression)
	player.call("set_courier_conditioning",courier_mission.conditioning_rank())
	story_mission.restore(data.get("story_mission", StoryMission.new().snapshot()))
	yaw = float(data.get("camera_yaw", 0.0))
	var position_data: Array = data["player_position"]
	player.global_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	var saved_cars: Array = data.get("cars", [])
	for i in range(mini(saved_cars.size(), cars.size())):
		var info: Dictionary = saved_cars[i]
		var c: CharacterBody3D = cars[i]
		var pos: Array = info.get("position", [])
		if pos.size() == 3:
			c.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		c.rotation.y = float(info.get("yaw", c.rotation.y))
		c.set("condition", clampf(float(info.get("condition", 100.0)), 18.0, 100.0))
		c.call("restore_damage", info.get("damage", []))
		if bool(info.get("claimed", false)):
			c.set_meta("claimed", true)
		elif c.has_meta("claimed"):
			c.remove_meta("claimed")
	var selected := int(data.get("occupied_car", -1))
	if selected >= 0 and selected < cars.size():
		current_car = cars[selected]
		current_car.set("occupied", true)
		player.set("driving", true)
		player.visible = false
		player.collision_layer = 0
		player.collision_mask = 0
		player.call("show_vehicle_rider", current_car, false)
	else:
		var saved_transit := str(data.get("transit_kind", ""))
		if saved_transit == "BUS":
			var bus: CharacterBody3D = traffic.call("bus_by_id", str(data.get("transit_id", "")))
			if bus != null:
				_board_transit(bus, "BUS", false)
		elif saved_transit == "TRAIN":
			_board_transit(rail.get_node("MorrowLineTrain"), "TRAIN", false)
			_rail_platform_rider = bool(data.get("rail_platform_rider", false))
	day_night.set("day_index",int(data.get("day_index",0)))
	day_night.call("set_hour", float(data.get("hour", 19.25)))
	_sync_band_flyers()
	venue_system.call("set_hour", float(day_night.get("hour")))
	civic_services.call("set_hour", float(day_night.get("hour")))
	venue_job_active = str(data.get("venue_job_active", ""))
	if not venue_job_active.is_empty() and venue_system.call("job_by_id", venue_job_active).is_empty():
		venue_job_active = ""
	venue_job_completed.clear()
	var saved_jobs = data.get("venue_job_completed", [])
	if saved_jobs is Array:
		for job_id in saved_jobs:
			var valid_id := str(job_id)
			if not venue_system.call("job_by_id", valid_id).is_empty() and not venue_job_completed.has(valid_id):
				venue_job_completed.append(valid_id)
	ration_packs = clampi(int(data.get("ration_packs", 0)), 0, 99)
	consumable_inventory = Consumables.restore(data.get("consumables",{}))
	player.call("restore_stamina",data.get("stamina",100.0))
	civic_job_active = str(data.get("civic_job_active", ""))
	if civic_services.call("order_by_id", civic_job_active).is_empty():
		civic_job_active = ""
	civic_job_completed.clear()
	var saved_civic = data.get("civic_job_completed", [])
	if saved_civic is Array:
		for job_id in saved_civic:
			var checked := str(job_id)
			if not civic_services.call("order_by_id", checked).is_empty() and not civic_job_completed.has(checked):
				civic_job_completed.append(checked)
	civic_intel.clear()
	var saved_intel = data.get("civic_intel", [])
	if saved_intel is Array:
		for site_id in saved_intel:
			var confirmed := str(site_id)
			# Keep civic site intel validated and explicitly allow Mara's
			# original authored venue note (no arbitrary user-provided IDs).
			var is_valid_note: bool = confirmed == "lantern_cup_shift_notes"
			var is_civic_site: bool = not civic_services.call("site_by_id", confirmed).is_empty()
			if (is_civic_site or is_valid_note) and not civic_intel.has(confirmed):
				civic_intel.append(confirmed)
	# Old save slots have no indoor field and continue to open outdoors.
	var restored_room: Dictionary = data.get("interior", {})
	if not restored_room.is_empty() and current_car == null and current_transit == null:
		var group := str(restored_room.get("group", ""))
		var room_id := str(restored_room.get("id", ""))
		var room_site: Dictionary = civic_services.call("site_by_id", room_id) if group == "CIVIC" else venue_system.call("venue_by_id", room_id)
		if interiors.call("restore", restored_room, room_site):
			interiors.call("refresh_arcade_scores",_arcade_best)
			player.global_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
			if player.global_position.distance_to(interiors.call("get_entry_point")) > 13.0:
				player.global_position = interiors.call("get_entry_point")
			player.velocity = Vector3.ZERO
			city_details.call("set_focus", interiors.get("exterior_position"))
	if not interiors.call("is_inside"):
		city_details.call("set_focus", player.global_position)
		var walk_in: Node3D = city_details.call("nearby_walk_in",player.global_position)
		if is_instance_valid(walk_in) and current_car == null and current_transit == null:
			walk_in.call("restore_safe_threshold",player.global_position)
			city_details.call("update_walk_in_light",player.global_position)
		var repair := _repair_storefront()
		if repair != null and (repair.contains(player.global_position) or repair.door_reachable(player.global_position)):
			repair.door.restore_open(data.get("night_shift_door_open", false) == true or repair.overlaps_threshold(player.global_position))
	_refresh_courier_target()
	_snap_camera()
	_log_playtest("save_restored", {"seed": int(session.get("world_seed"))})
	_notify("Save loaded. Seed %d; Morrow Bay restored." % int(session.get("world_seed")))

func _parking_guard_near() -> bool:
	if current_car!=null or current_transit!=null or interiors.call("is_inside"):
		return false
	var hq:Node3D=city_details.call("synaxis_headquarters")
	return is_instance_valid(hq) and bool(hq.call("parking_guard_reachable",player.global_position))

func _try_parking_guard() -> bool:
	if _parking_guard_near():
		game_menu.call("open_parking_guard",progression.has_receipt(Opening.RECEIPT),progression.synaxis_contact)
		return true
	return false

func _synaxis_access_notice() -> bool:
	var hq: Node3D = city_details.call("synaxis_headquarters")
	if is_instance_valid(hq) and hq.call("public_checkpoint_reachable",player.global_position):
		_notify("SYNAXIS SECURITY: Badge access revoked. Your concern has been resolved. Authorized visitors only beyond this checkpoint.")
		return true
	if OpeningOffice.entrance_reachable(player.global_position):
		_notify("SYNAXIS: Public lobby open. Badge access revoked for the restricted offices.")
		return true
	return false

func _open_arcade(id: String) -> bool:
	if is_instance_valid(_arcade_layer) or get_tree().paused or current_car != null or current_transit != null:
		return false
	if str(interiors.call("arcade_cabinet_near", player.global_position)) != id or id.is_empty():
		return false
	var screen := ArcadeScreen.instantiate()
	if not screen.call("configure_cabinet", id, _arcade_best):
		screen.free()
		return false
	screen.connect("score_recorded", _record_arcade_score)
	if id == "grand_delay":
		screen.call("bind_deluxe_cabinet",interiors.call("arcade_cabinet_node",id))
	return _present_arcade_overlay(screen)

func _open_arcade_circuit() -> bool:
	if is_instance_valid(_arcade_layer) or get_tree().paused or current_car != null or current_transit != null:
		return false
	if not interiors.call("arcade_circuit_near",player.global_position):
		return false
	var screen := ArcadeCircuit.new()
	screen.configure(_arcade_best)
	return _present_arcade_overlay(screen)

func _present_arcade_overlay(screen: Control) -> bool:
	_arcade_layer = CanvasLayer.new()
	_arcade_layer.name = "ArcadeModal"
	_arcade_layer.layer = 100
	_arcade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_arcade_layer)
	_arcade_layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.connect("exit_requested", _close_arcade)
	suspend_weapon()
	player.set("input_blocked", true)
	player.velocity = Vector3.ZERO
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true

func _record_arcade_score(id: String, value: int) -> void:
	var before := ArcadeScores.circuit_count(_arcade_best)
	if ArcadeScores.record(_arcade_best,id,value):
		interiors.call("refresh_arcade_scores",_arcade_best)
		var after := ArcadeScores.circuit_count(_arcade_best)
		if after > before:
			_notify("ROOK: Local Legend! All eight stamps earned." if after == 8 else "ROOK: Circuit stamp earned. %d/8." % after)

func _close_arcade() -> void:
	if not is_instance_valid(_arcade_layer):
		return
	# Completed results are recorded immediately; abandoned rounds do not settle.
	# Stop the cabinet synchronously before its deferred deletion.
	for child in _arcade_layer.get_children():
		if child.has_method("abort_session"):
			child.call("abort_session")
	_arcade_layer.hide()
	_arcade_layer.process_mode = Node.PROCESS_MODE_DISABLED
	_arcade_layer.queue_free()
	_arcade_layer = null
	get_tree().paused = false
	player.set("input_blocked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_fire_held = true

func _toggle_interior() -> void:
	if interiors.call("is_inside"):
		if not interiors.call("exit_reachable", player.global_position):
			_notify("Return to the glowing doorway, then press H to leave.")
			return
		_close_venue()
		var previous_room := str(interiors.call("active_site_id"))
		var return_position: Vector3 = interiors.call("leave")
		# Rebuild the actual collision district BEFORE returning the player.
		city_details.call("set_focus", return_position)
		player.global_position = return_position
		player.velocity = Vector3.ZERO
		_snap_camera()
		_log_playtest("interior_exit", {"site_id": previous_room, "return_position": [return_position.x, return_position.y, return_position.z]})
		_notify("Back on the street. Your saved city is exactly where you left it.")
		return
	if current_car != null or current_transit != null:
		_notify("Exit your vehicle before entering a building.")
		return
	if _synaxis_access_notice():
		return
	var repair := _repair_storefront()
	if repair != null:
		if repair.door_reachable(player.global_position):
			if repair.door.request_toggle():
				player.call("play_visual_action", &"interact")
				world_audio.call("play_event", "DOOR", repair.door.global_position)
			else:
				_notify("Night Shift Repairs is preparing the entrance.")
			return
		if repair.contains(player.global_position):
			_notify("Return to the front door to open or close it.")
			return
	var venue: Dictionary = venue_system.call("nearest_venue", player.global_position)
	var civic: Dictionary = civic_services.call("nearest_site", player.global_position)
	var physical_lot: Node3D = city_details.call("nearby_walk_in",player.global_position)
	if is_instance_valid(physical_lot) and not str(physical_lot.get("home_id")).is_empty() and not progression.owns_home() and not physical_lot.call("contains",player.global_position):
		if progression.has_receipt(StarterHome.ACCESS_RECEIPT) and physical_lot.call("doorway_reachable",player.global_position):
			_tenancy_panel = true
			_show_venue_dialogue()
			_update_venue_panel()
		else:
			_notify("Locked residence. Speak to Mara at Lantern Cup first.")
		return
	# Migrated café has no remote-room entry. Approach the actual hinge.
	if str(venue.get("id","")) == "helix_espresso":
		venue = {}
	# Existing named shops keep H at their exact old public anchor. Their
	# service migration is separate from the generic building conversion.
	var legacy_anchor := false
	if str(venue.get("id", "")) == "insert_coin":
		if not venue_system.call("is_open", "insert_coin"):
			_notify("INSERT COIN is closed. Open 14:00–03:00.")
			return
		legacy_anchor = true
	if not venue.is_empty() and not legacy_anchor:
		legacy_anchor = player.global_position.distance_to(venue_system.call("venue_position",str(venue["id"]))) < .3
	if not civic.is_empty():
		legacy_anchor = legacy_anchor or player.global_position.distance_to(civic_services.call("position_for",str(civic["id"]))) < .3
	if physical_lot != null and not legacy_anchor:
		if physical_lot.call("doorway_reachable",player.global_position):
			var leaf: AnimatableBody3D = physical_lot.get("door")
			if leaf.call("request_toggle"):
				player.call("play_visual_action",&"interact")
				player.get_node("Visual").call("reach_target",leaf,physical_lot.call("door_handle_anchor"),1)
				world_audio.call("play_event","DOOR",leaf.global_position)
		else:
			_notify("Return to the front door to open or close it.")
		return
	if venue.is_empty() and civic.is_empty():
		_notify("Approach a marked storefront and press H to enter.")
		return
	var group := "VENUE"
	var site: Dictionary = venue
	var distance := 9999.0
	if not venue.is_empty():
		distance = player.global_position.distance_to(venue_system.call("venue_position", str(venue["id"])))
	if not civic.is_empty():
		var civic_distance: float = player.global_position.distance_to(civic_services.call("position_for", str(civic["id"])))
		if civic_distance < distance:
			group = "CIVIC"
			site = civic
	var old_position := player.global_position
	_close_venue()
	player.global_position = interiors.call("enter", site, group, old_position)
	interiors.call("refresh_arcade_scores",_arcade_best)
	player.velocity = Vector3.ZERO
	_log_playtest("interior_enter", {"site_id": str(site["id"]), "group": group})
	_snap_camera()
	_notify("Inside %s. Approach the service counter with G; H exits at the doorway." % str(site["name"]))

func _toggle_interaction() -> void:
	if venue_panel.visible:
		_close_venue()
		return
	if interiors.call("is_inside"):
		if str(interiors.call("active_site_id")) == "insert_coin":
			var cabinet_id := str(interiors.call("arcade_cabinet_near", player.global_position))
			if not cabinet_id.is_empty():
				_open_arcade(cabinet_id)
			elif interiors.call("arcade_circuit_near",player.global_position):
				_open_arcade_circuit()
			else:
				var exhibit: Dictionary = interiors.call("arcade_exhibit_near",player.global_position)
				if not exhibit.is_empty():
					_notify("%s / %s" % [exhibit["title"],exhibit["line"]])
					return
				var regular: Dictionary = interiors.call("arcade_talk_regular",player.global_position)
				if not regular.is_empty():
					_notify("%s / %s: %s" % [regular["name"],regular["role"],regular["line"]])
				elif interiors.call("counter_reachable", player.global_position):
					_notify("ROOK: " + str(interiors.call("arcade_rook_line")))
				else:
					_notify("Approach a cabinet from the front to play. Practice is free.")
			return
		# Mara's collectible, one-time shift note is a real world interaction,
		# available only beside the flagship café booth. Reuse the already
		# persisted civic-intel list; old saves and quest schemas are unchanged.
		var room_detail: Dictionary = interiors.call("inspect_hero_rumor", player.global_position)
		if not room_detail.is_empty():
			var clue_id := str(room_detail["id"])
			if not civic_intel.has(clue_id):
				civic_intel.append(clue_id)
				interiors.call("mara_discovery_reaction")
				_notify("MARA'S SHIFT NOTES: " + str(room_detail["text"]))
			else:
				_notify("You already copied Mara's shift notes to your journal.")
			return
		# Free, authored ambient conversation when standing beside a regular.
		# This occurs after Mara's clue interaction and before generic counters.
		var regular: Dictionary = interiors.call("talk_to_patron", player.global_position, {
			"hour": float(day_night.get("hour")),
			"shift_notes": civic_intel.has("lantern_cup_shift_notes")
		})
		if not regular.is_empty():
			ambient_caption.call("present", str(regular["name"]), str(regular["line"]))
			return
		if not interiors.call("counter_reachable", player.global_position):
			_notify("Walk toward the staffed service counter to interact.")
			return
		player.call("play_visual_action", &"interact")
		if str(interiors.call("active_site_group")) == "CIVIC":
			_toggle_civic()
		else:
			_toggle_venue()
		return
	if current_car != null or current_transit != null:
		_notify("Get out of the vehicle before interacting with neighborhood businesses.")
		return
	if _garden_trail_interact():
		return
	if _try_parking_guard():
		return
	if _synaxis_access_notice():
		return
	if courier_mission.gig_economy and courier_mission.mission_active() and player.global_position.distance_to(mission_position) < CourierMission.RADIUS:
		_advance_mission()
		return
	var garage: Node3D = city_details.call("starter_garage",player.global_position)
	if is_instance_valid(garage) and garage.call("desk_reachable",player.global_position):
		if not progression.owns_home():
			_notify("Garage services unlock after Mara’s contact mission.")
			return
		_garage_panel = true
		_show_venue_dialogue()
		_update_venue_panel()
		return
	var repair := _repair_storefront()
	if repair != null and repair.contains(player.global_position):
		if repair.counter_reachable(player.global_position):
			_repair_panel = true
			player.call("play_visual_action", &"interact")
			_show_venue_dialogue()
			_update_venue_panel()
		else:
			_notify("Approach the service counter.")
		return
	var physical_lot: Node3D = city_details.call("nearby_walk_in",player.global_position)
	if is_instance_valid(physical_lot) and not str(physical_lot.get("clothing_store_id")).is_empty():
		if physical_lot.call("clothing_reachable",player.global_position):
			_clothing_retail=true
			_retail_id=str(physical_lot.get("clothing_store_id"))
			_retail_day=int(day_night.get("day_index"))
			_retail_stock=ClothingStore.stock_for_day(_retail_id,_retail_day)
			_fitting_yaw=player.get_node("Visual").rotation.y
			_fitting_rotation=0.0
			_fitting_zoom=0.0
			_fitting_compare=false
			_wardrobe_category="ALL"
			_wardrobe_panel=true
			_wardrobe_index=Wardrobe.browse_ids().find(progression.outfit_id if progression.outfit_id in _retail_stock else "dispatch")
			var greeting:String=physical_lot.call("clothing_greeting")
			if not greeting.is_empty():
				_notify(greeting)
			_show_venue_dialogue()
			_update_venue_panel()
		else:
			_notify(str(ClothingStore.STORES[physical_lot.get("clothing_store_id")]["name"])+": approach the fitting and checkout counter.")
		return
	if is_instance_valid(physical_lot) and not str(physical_lot.get("home_id")).is_empty():
		if not progression.owns_home():
			if str(physical_lot.get("home_id")) == StarterHome.ID and physical_lot.call("doorway_reachable", player.global_position) and not physical_lot.call("contains", player.global_position):
				_save_game()
				return
			_notify("Complete Mara’s contact mission first.")
			return
		match str(physical_lot.call("home_action",player.global_position)):
			"rest":
				if heat > 0.01:
					_notify("Lose police attention before resting.")
				else:
					health = 100.0
					player.call("restore_stamina",100.0)
					_notify("Rested at home. Health and stamina restored.")
			"save":
				_save_game()
			"exchange":
				_exchange_panel = true
				_show_venue_dialogue()
				_update_venue_panel()
			"wardrobe":
				_wardrobe_category="ALL"
				_wardrobe_panel = true
				_wardrobe_index = Wardrobe.IDS.find(progression.outfit_id)
				_show_venue_dialogue()
				_update_venue_panel()
			"storage":
				_home_panel = true
				_show_venue_dialogue()
				_update_venue_panel()
			_:
				_notify("At home: approach the bed, desk, wardrobe or storage cabinet.")
		return
	if is_instance_valid(physical_lot) and not str(physical_lot.get("physical_venue_id")).is_empty():
		if physical_lot.call("service_reachable",player.global_position):
			venue_selected_id = str(physical_lot.get("physical_venue_id"))
			player.call("play_visual_action",&"interact")
			_show_venue_dialogue()
			_update_venue_panel()
		else:
			_notify("Walk to the indoor service counter.")
		return
	if _cal_pickup_reachable() and progression.collect_cal_gift():
		_notify("COMPATIBILITY PATCH: Collected Cal\u0027s prepaid anniversary heat sink. Return to Cal Mercer.")
		_track_cal_waypoint()
		return
	var machine: Node3D = city_details.call("nearby_vending",player.global_position)
	if is_instance_valid(machine):
		_vending_machine = machine
		_show_venue_dialogue()
		_update_venue_panel()
		return
	if weapons.equipped=="holstered" and current_car==null and current_transit==null:
		var legend:Node3D=venue_system.call("daddy_stanky_near",player.global_position)
		if is_instance_valid(legend):
			_street_contact_id=StreetSatire.STANKY_ID
			legend.call("set_attention_target",player.global_position,true)
			game_menu.call("open_street_contact",StreetSatire.stanky_profile())
			return
	var shop: Dictionary = venue_system.call("nearest_venue", player.global_position)
	var service: Dictionary = civic_services.call("nearest_site", player.global_position)
	if shop.is_empty() and service.is_empty() and is_instance_valid(pedestrians) and weapons.equipped=="holstered":
		var contact:Dictionary=pedestrians.call("nearby_contact")
		if not contact.is_empty():
			_street_contact_id=str(contact["lease_id"])
			if pedestrians.call("is_named_cal",_street_contact_id) and progression.has_receipt(Opening.RECEIPT):
				contact["cal_quest"]=progression.cal_quest
			game_menu.call("open_street_contact",contact)
			return
	if str(shop.get("id","")) == "helix_espresso":
		_notify("HELIX ESPRESSO: enter the actual building to order.")
		return
	if shop.is_empty() and service.is_empty():
		for car in cars:
			if car.global_position.distance_squared_to(player.global_position) < 12.0 \
					and car.call("toggle_near_door", player.global_position, player.get_rid()):
				return
	if not service.is_empty():
		var civic_distance: float = civic_services.call("position_for", str(service["id"])).distance_to(player.global_position)
		var shop_distance: float = 9999.0 if shop.is_empty() else venue_system.call("venue_position", str(shop["id"])).distance_to(player.global_position)
		if civic_distance <= shop_distance:
			_toggle_civic()
			return
	_toggle_venue()

func _garden_trail_interact()->bool:
	if current_car!=null or current_transit!=null or interiors.call("is_inside"):
		return false
	var stop:int=city_details.call("horizon_trail_stop",player.global_position)
	if stop<0:
		return false
	if heat>0.01 or weapons.equipped!="holstered":
		_notify("Horizon Commons / holster equipment and clear police attention.")
		return true
	var entry:Dictionary=HorizonTrail.STOPS[stop]
	var note:="%s / %s"%[entry["name"],entry["text"]]
	if progression.has_receipt(HorizonTrail.RECEIPT):
		_notify(note)
		return true
	_garden_trail_mask |= 1 << stop
	var count:=0
	for i in range(HorizonTrail.STOPS.size()):
		if _garden_trail_mask & (1 << i):
			count+=1
	if count==HorizonTrail.STOPS.size() and progression.credit_once(HorizonTrail.RECEIPT,HorizonTrail.REWARD):
		_notify("HORIZON GARDEN TRAIL COMPLETE / +$25 • +10 STREET CRED")
		_log_playtest("garden_trail_complete",{"stops":count})
	else:
		_notify("%s (%d/4)"%[note,count])
	return true

func _toggle_civic() -> void:
	if current_car != null or current_transit != null:
		_notify("Get out of the vehicle to visit public services.")
		return
	if venue_panel.visible:
		_close_venue()
		return
	var site: Dictionary = civic_services.call("site_by_id", str(interiors.call("active_site_id"))) if interiors.call("is_inside") else civic_services.call("nearest_site", player.global_position)
	if site.is_empty():
		_notify("No public service counter within reach.")
		return
	civic_selected_id = str(site["id"])
	_show_venue_dialogue()
	_update_civic_panel()

func _consume_ration() -> void:
	if current_car == null and current_transit == null:
		var id := Consumables.best_item(consumable_inventory,health,float(player.get("stamina")))
		if not id.is_empty():
			var item: Dictionary = Consumables.ITEMS[id]
			consumable_inventory[id] -= 1
			if int(consumable_inventory[id]) == 0:
				consumable_inventory.erase(id)
			health = minf(100.0,health+float(item["health"]))
			player.call("add_stamina",float(item["stamina"]))
			player.get_node("Visual").call("play_product_action",id,false)
			_notify("Consumed %s. Health %d / stamina %d." % [item["name"],ceili(health),ceili(float(player.get("stamina")))])
			return
	if current_car != null or current_transit != null:
		_notify("Use a ration pack when safely on foot.")
	elif ration_packs <= 0:
		_notify("No provisions. Visit a grocery store in an outer district.")
	elif health >= 99.9:
		_notify("You're at full health; save your provisions.")
	else:
		ration_packs -= 1
		health = minf(100.0, health + 25.0)
		_notify("Used a supply pack. +25 health (%d remaining)." % ration_packs)

func _civic_service_text(site: Dictionary) -> String:
	match str(site["kind"]):
		"GROCERY":
			return "2 take-away ration packs"
		"CLINIC":
			return "Walk-in medical care (+55 health)"
		"FIRE":
			return "Emergency first aid (+35 health)"
		"CIVIC":
			return "Pay municipal citations (-1.75 heat)"
		"GARAGE":
			return "Restore condition of a parked nearby vehicle"
		"LIBRARY":
			return "Read the community archive (free intel)"
		"UTILITY":
			return "Inspect grid ownership records (free intel)"
		"WAREHOUSE":
			return "Read today's shipping workboard (free)"
	return "Visit"

func _repair_storefront() -> BrickwaterRepair:
	return city_details.call("repair_storefront") as BrickwaterRepair

func _garage_vehicle(id: String) -> CharacterBody3D:
	for candidate in cars:
		if is_instance_valid(candidate) and str(candidate.get_meta("vehicle_id","")) == id:
			return candidate
	return null

func _recover_garage_vehicle(garage: Node3D,index: int) -> void:
	# Explicit recovery service only. Never spawn another vehicle or move an
	# occupied one; test clearance before changing money or ownership.
	if index < 0 or index >= StarterGarage.IDS.size() or not is_instance_valid(garage) or current_car != null or current_transit != null or not progression.owns_home():
		return
	var id: String = StarterGarage.IDS[index]
	var owned := progression.owns_vehicle(id)
	if not owned and index != 0:
		_notify("Register the Cinder title at Night Shift Repairs first.")
		return
	if heat > 0.01:
		_notify("Lose police attention before requesting recovery.")
		return
	var car := _garage_vehicle(id)
	if not is_instance_valid(car) or car.get("occupied") or not is_finite(float(car.get("speed"))) or absf(float(car.get("speed"))) > .5:
		_notify("Vehicle unavailable for recovery.")
		return
	if garage.call("parked_at",car.global_position,index):
		if not owned and not progression.grant_starter_vehicle():
			_notify("Not enough cash for the Kestrel title.")
			return
		_notify("Vehicle already parked in its bay.")
		return
	var collider := car.get_node("CollisionShape3D") as CollisionShape3D
	var box := collider.shape as BoxShape3D
	var bay: Vector3 = garage.call("bay_point",index)
	var target := bay + Vector3.UP*(box.size.y*.5-collider.position.y+.05)
	var query := PhysicsShapeQueryParameters3D.new()
	var clearance := BoxShape3D.new()
	clearance.size = box.size + Vector3(.45,0,.45)
	query.shape = clearance
	query.transform = Transform3D(Basis.IDENTITY,target+collider.position)
	query.exclude = [car.get_rid()]
	query.collision_mask = car.collision_mask
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		_notify("Recovery bay blocked. Clear it before requesting the vehicle.")
		return
	if owned:
		if not progression.spend(StarterGarage.RECOVERY_FEE):
			_notify("Not enough cash for recovery.")
			return
	elif not progression.grant_starter_vehicle():
		_notify("Not enough cash for the Kestrel title.")
		return
	car.global_position = target
	car.rotation.y = 0.0
	car.velocity = Vector3.ZERO
	car.set("speed",0.0)
	_notify("Vehicle returned to its reserved bay." if owned else "Starter Kestrel registered and parked. It’s yours.")

func _owned_vehicle_text() -> String:
	var names: Array[String] = []
	for id in progression.owned_vehicle_ids():
		names.append(str(RoadCars.TITLES[id]["name"]))
	return "VEHICLE TITLES: " + ("None" if names.is_empty() else ", ".join(names))

# Actual nearby stationary pilot stock only; no new spawn or remote purchase.
func _title_eligible(car: CharacterBody3D) -> bool:
	if not is_instance_valid(car):
		return false
	var id := str(car.get_meta("vehicle_id", ""))
	if not RoadCars.TITLES.has(id) or progression.owns_vehicle(id):
		return false
	# With residence access, the Kestrel title is sold at the garage.
	if progression.owns_home() and id == StarterGarage.IDS[0]:
		return false
	return not bool(car.get("occupied")) and absf(float(car.get("speed"))) <= .28 and car.global_position.distance_to(player.global_position) < 18.0

func _title_by_id(id: String) -> CharacterBody3D:
	for car in cars:
		if is_instance_valid(car) and str(car.get_meta("vehicle_id","")) == id:
			return car
	return null

func _nearby_title_candidate() -> CharacterBody3D:
	var selected: CharacterBody3D
	var nearest := 18.0
	for car in cars:
		if not _title_eligible(car):
			continue
		var distance := car.global_position.distance_to(player.global_position)
		if distance < nearest:
			selected = car
			nearest = distance
	return selected

func _open_title_quote() -> void:
	var car := _title_by_id(_title_offer_id)
	if not _title_eligible(car):
		_notify("That vehicle is no longer eligible. Select a new offer.")
		return
	var price: int = RoadCars.title_price(_title_offer_id)
	if cash < price:
		_notify("Not enough cash for this vehicle title.")
		return
	_title_quote_id = _title_offer_id

func _confirm_title_quote() -> void:
	# Consume the quote before validating; a second action cannot replay it.
	var id := _title_quote_id
	_title_quote_id = ""
	var car := _title_by_id(id)
	if not _title_eligible(car) or str(car.get_meta("vehicle_id","")) != id:
		_notify("Offer expired. No payment taken.")
		return
	if not progression.buy_vehicle(id):
		_notify("Not enough cash for this vehicle title.")
		return
	_notify("TITLE REGISTERED: %s. This vehicle is yours." % RoadCars.TITLES[id]["name"])

func _sale_value(car: CharacterBody3D) -> int:
	if not is_instance_valid(car) or heat > .01 or bool(car.get("occupied")) or absf(float(car.get("speed"))) > .28 or car.global_position.distance_to(player.global_position) >= 18.0:
		return 0
	var id := str(car.get_meta("vehicle_id",""))
	if not progression.owns_vehicle(id):
		return 0
	return RoadCars.resale_price(id,float(car.get("condition")))

func _nearby_sale_candidate() -> CharacterBody3D:
	var selected: CharacterBody3D
	var nearest := 18.0
	for car in cars:
		if _sale_value(car) <= 0:
			continue
		var distance := car.global_position.distance_to(player.global_position)
		if distance < nearest:
			selected = car
			nearest = distance
	return selected

func _clear_sale_quote() -> void:
	_sale_quote_id = ""
	_sale_quote_amount = 0

func _open_sale_quote() -> void:
	var car := _title_by_id(_sale_offer_id)
	var value := _sale_value(car)
	if value <= 0 or value > ProgressionLedger.MAX_CASH - cash:
		_notify("Vehicle unavailable for sale or wallet full.")
		return
	_sale_quote_id = _sale_offer_id
	_sale_quote_amount = value

func _confirm_sale_quote() -> void:
	var id := _sale_quote_id
	var amount := _sale_quote_amount
	_clear_sale_quote()
	var car := _title_by_id(id)
	if amount <= 0 or _sale_value(car) != amount:
		_notify("Sale offer expired. No title or money changed.")
		return
	if not progression.sell_vehicle(id,float(car.get("condition"))):
		_notify("Sale declined. No title or money changed.")
		return
	# This is now dealer stock; taking it without a new title is theft.
	if car.has_meta("claimed"):
		car.remove_meta("claimed")
	_notify("TITLE TRANSFERRED: %s  +$%d" % [RoadCars.TITLES[id]["name"],amount])

func _repair_nearby_vehicle(price: int) -> void:
	var selected_car: CharacterBody3D
	var nearest := 18.0
	for car in cars:
		var distance := car.global_position.distance_to(player.global_position)
		if distance < nearest and float(car.get("condition")) < 99.9:
			selected_car = car
			nearest = distance
	if selected_car == null:
		_notify("Park a damaged vehicle near the shop.")
	elif not progression.spend(price):
		_notify("Not enough cash to repair this vehicle.")
	else:
		selected_car.call("repair")
		_notify("Vehicle repaired. Roadworthiness restored.")

func _update_civic_panel() -> void:
	if civic_selected_id.is_empty() or venue_label == null:
		return
	if _investigation_open:
		_update_investigation_panel()
		return
	if _technical_case_open:
		_update_technical_panel()
		return
	# This fourth menu action must never leak into another venue or service.
	if venue_talk_button != null:
		venue_talk_button.visible = false
	var site: Dictionary = civic_services.call("site_by_id", civic_selected_id)
	if site.is_empty():
		_close_venue()
		return
	var opened: bool = civic_services.call("is_open", civic_selected_id)
	var title := "%s | %s | %s\n%s: %s\n" % [
		str(site["name"]), str(site["kind"]), "OPEN" if opened else "CLOSED",
		str(site["host"]), str(site["flavor"])]
	if opened:
		var item := _civic_service_text(site)
		title += "[1 / A] %s ($%d)\n" % [item, int(site["price"])]
		if civic_job_active.is_empty():
			var offer: Dictionary = civic_services.call("order_from", civic_selected_id)
			if not offer.is_empty() and not civic_job_completed.has(str(offer["id"])):
				title += "[2 / X] WORK ORDER: %s (+$%d)\n" % [str(offer["title"]), int(offer["reward"])]
		else:
			var job: Dictionary = civic_services.call("order_by_id", civic_job_active)
			if not job.is_empty() and str(job["to"]) == civic_selected_id:
				title += "[2 / X] DELIVER: %s (+$%d)\n" % [str(job["title"]), int(job["reward"])]
	else:
		title += "Return during staffed hours.\n"
	title += "[G / B] Close  |  CASH $%d  |  PROVISIONS %d" % [cash, ration_packs]
	venue_label.text = title
	if venue_service_button != null:
		venue_service_button.disabled = not opened
		venue_service_button.text = "1 / A  ·  %s  $%d" % [_civic_service_text(site), int(site["price"])]
	if venue_job_button != null:
		var offered: Dictionary = civic_services.call("order_from", civic_selected_id) if civic_job_active.is_empty() else civic_services.call("order_by_id", civic_job_active)
		var available:bool = not offered.is_empty() and (
			(not civic_job_active.is_empty() and str(offered["to"]) == civic_selected_id) or
			(civic_job_active.is_empty() and not civic_job_completed.has(str(offered["id"]))))
		venue_job_button.disabled = not opened or not available
		venue_job_button.text = "2 / X  •  WORK ORDER"
	if venue_talk_button != null and TechnicalContracts.available(civic_selected_id,progression):
		venue_talk_button.show()
		venue_talk_button.disabled = not opened
		venue_talk_button.text = "3 / Y  •  DIAGNOSTIC CONTRACT"
	var lead: Dictionary = investigation.current(progression)
	if venue_talk_button != null and not lead.is_empty() and lead["site"] == civic_selected_id:
		venue_talk_button.show()
		venue_talk_button.disabled = not opened
		venue_talk_button.text = "3 / Y  •  THE PAPER CITY"

func _investigation_reachable() -> bool:
	var lead: Dictionary = investigation.current(progression)
	if lead.is_empty() or lead["site"] != civic_selected_id or not venue_panel.visible or current_car != null or current_transit != null or not civic_services.call("is_open",civic_selected_id):
		return false
	if interiors.call("is_inside"):
		return interiors.call("active_site_group") == "CIVIC" and interiors.call("active_site_id") == civic_selected_id and interiors.call("counter_reachable",player.global_position)
	var point: Vector3 = civic_services.call("position_for",civic_selected_id)
	return player.global_position.distance_to(point) <= CivicServicesScript.VISIT_RADIUS

func _update_investigation_panel() -> void:
	if not _investigation_reachable():
		_investigation_open = false
		_investigation_feedback = ""
		_update_civic_panel()
		return
	var lead: Dictionary = investigation.current(progression)
	var final: bool = investigation.stage == IndependentInvestigation.STAGES.size()-1
	venue_label.text = "%s / %d of %d\n%s\n%s" % [IndependentInvestigation.TITLE,investigation.stage+1,IndependentInvestigation.STAGES.size(),lead["title"],lead["line"]]
	if not _investigation_feedback.is_empty():
		venue_label.text += "\n"+_investigation_feedback
	venue_service_button.show()
	venue_service_button.disabled = false
	venue_service_button.text = "1 / A  •  Report conflicting records" if final else "1 / A  •  Record lead"
	venue_job_button.show()
	venue_job_button.disabled = not final
	venue_job_button.text = "2 / X  •  Accuse a specific executive" if final else "2 / X  •  No conclusion yet"
	venue_talk_button.show()
	venue_talk_button.disabled = false
	venue_talk_button.text = "3 / Y  •  BACK"

func _investigation_action(option: int) -> void:
	if not _investigation_reachable():
		_close_venue()
		return
	if option == 3:
		_investigation_open = false
		_investigation_feedback = ""
		_update_civic_panel()
		return
	if option != 1 and (option != 2 or investigation.stage != IndependentInvestigation.STAGES.size()-1):
		return
	var result: Dictionary = investigation.advance(civic_selected_id,option-1,progression)
	match str(result.get("status","")):
		"advanced","complete":
			_notify(str(result["message"]) if result["status"] == "advanced" else "INVESTIGATION COMPLETE +$%d: %s" % [result["reward"],result["message"]])
			_close_venue()
		"incorrect","blocked":
			_investigation_feedback = str(result["message"])
			_update_investigation_panel()

func _technical_reachable() -> bool:
	if not venue_panel.visible or current_car != null or current_transit != null or not TechnicalContracts.available(civic_selected_id,progression) or not civic_services.call("is_open",civic_selected_id):
		return false
	if interiors.call("is_inside"):
		return interiors.call("active_site_group") == "CIVIC" and interiors.call("active_site_id") == civic_selected_id and interiors.call("counter_reachable",player.global_position)
	var point: Vector3 = civic_services.call("position_for",civic_selected_id)
	return player.global_position.distance_to(point) <= CivicServicesScript.VISIT_RADIUS

func _update_technical_panel() -> void:
	if not _technical_reachable():
		_technical_case_open = false
		_technical_feedback = ""
		_update_civic_panel()
		return
	var job: Dictionary = TechnicalContracts.CASES[civic_selected_id]
	venue_label.text = "%s / $%d\n%s\n%s" % [job["title"],job["reward"],job["brief"],job["evidence"]]
	if not _technical_feedback.is_empty():
		venue_label.text += "\n"+_technical_feedback
	venue_service_button.show()
	venue_service_button.disabled = false
	venue_service_button.text = "1 / A  •  "+str(job["options"][0])
	venue_job_button.show()
	venue_job_button.disabled = false
	venue_job_button.text = "2 / X  •  "+str(job["options"][1])
	venue_talk_button.show()
	venue_talk_button.disabled = false
	venue_talk_button.text = "3 / Y  •  BACK"

func _technical_action(option: int) -> void:
	if not _technical_reachable():
		_close_venue()
		return
	if option == 3:
		_technical_case_open = false
		_technical_feedback = ""
		_update_civic_panel()
		return
	if option not in [1,2]:
		return
	var result := TechnicalContracts.resolve(civic_selected_id,option-1,progression)
	match str(result.get("status","")):
		"complete":
			_notify("DIAGNOSTIC COMPLETE +$%d: %s" % [result["reward"],result["message"]])
			_close_venue()
		"incorrect":
			_technical_feedback = str(result["message"])
			_update_technical_panel()
		"blocked":
			_technical_feedback = "Wallet full. Try again after freeing capacity."
			_update_technical_panel()

func _civic_action(option: int) -> void:
	if not venue_panel.visible or civic_selected_id.is_empty():
		return
	var site: Dictionary = civic_services.call("site_by_id", civic_selected_id)
	if site.is_empty() or not civic_services.call("is_open", civic_selected_id):
		_notify("This public service is not open right now.")
		return
	if _investigation_open:
		_investigation_action(option)
		return
	if _technical_case_open:
		_technical_action(option)
		return
	if option == 3:
		if _investigation_reachable():
			_investigation_open = true
			_investigation_feedback = ""
			_update_investigation_panel()
			return
		if _technical_reachable():
			_technical_case_open = true
			_technical_feedback = ""
			_update_technical_panel()
		return
	var kind: String = site["kind"]
	if option == 1:
		var price := int(site["price"])
		var purchase := true
		match kind:
			"GROCERY":
				if ration_packs > 97:
					_notify("Supply pack inventory is full.")
					return
			"CLINIC", "FIRE":
				if health >= 99.9:
					_notify("No first aid needed. Save your money.")
					return
			"CIVIC":
				if heat <= 0.01:
					_notify("No citations are currently outstanding.")
					return
			"GARAGE":
				_repair_nearby_vehicle(price)
				return
			"LIBRARY", "UTILITY":
				purchase = false
			"WAREHOUSE":
				_notify("The warehouse shift board lists work under option [2].")
				return
		if purchase:
			if not progression.spend(price):
				_notify("Not enough cash; visit a courier pickup or complete a work order.")
				return
		match kind:
			"GROCERY":
				ration_packs += 2
				_notify("Bought two provisions. Press R on foot to use one.")
			"CLINIC":
				health = minf(100.0, health + 55.0)
				_notify("Clinic treatment complete. +55 health.")
			"FIRE":
				health = minf(100.0, health + 35.0)
				_notify("Emergency first aid complete. +35 health.")
			"CIVIC":
				heat = maxf(0.0, heat - 1.75)
				_notify("Municipal citation settled. Police heat reduced.")
			"LIBRARY", "UTILITY":
				if not civic_intel.has(civic_selected_id):
					civic_intel.append(civic_selected_id)
					_notify("ARCHIVE DISCOVERY: %s" % str(site["flavor"]))
				else:
					_notify("Already examined this local archive.")
	elif option == 2:
		if civic_job_active.is_empty():
			var order: Dictionary = civic_services.call("order_from", civic_selected_id)
			if order.is_empty() or civic_job_completed.has(str(order.get("id", ""))):
				_notify("No new delivery contract here.")
				return
			civic_job_active = str(order["id"])
			_notify("WORK ORDER: %s — %s" % [str(order["title"]), str(order["brief"])])
		else:
			var active: Dictionary = civic_services.call("order_by_id", civic_job_active)
			if active.is_empty():
				civic_job_active = ""
				return
			if str(active["to"]) != civic_selected_id:
				var destination: Dictionary = civic_services.call("site_by_id", str(active["to"]))
				_notify("Work in progress. Destination: %s" % str(destination["name"]))
				return
			if civic_job_completed.has(civic_job_active) or progression.has_receipt("civic:" + civic_job_active):
				civic_job_active = ""
				_notify("Work order already paid.")
				_update_civic_panel()
				return
			if not progression.credit_once("civic:" + civic_job_active, int(active["reward"])):
				_notify("Unable to settle work order. Check wallet capacity.")
				return
			civic_job_completed.append(civic_job_active)
			civic_job_active = ""
			_notify("WORK ORDER COMPLETE +$%d: %s" % [int(active["reward"]), str(active["ending"])])
	_update_civic_panel()

func _civic_job_text() -> String:
	if civic_job_active.is_empty():
		return "CITY SERVICES: %d provisions | %d archive clues" % [ration_packs, civic_intel.size()]
	var order: Dictionary = civic_services.call("order_by_id", civic_job_active)
	if order.is_empty():
		return ""
	var point: Vector3 = civic_services.call("position_for", str(order["to"]))
	var place: Dictionary = civic_services.call("site_by_id", str(order["to"]))
	return "WORK ORDER: %s / %s (%dm)" % [str(order["title"]), str(place["name"]), roundi((interiors.get("exterior_position") if interiors.call("is_inside") else _actor().global_position).distance_to(point))]

func _civic_job_target() -> Vector3:
	var order: Dictionary = civic_services.call("order_by_id", civic_job_active)
	return civic_services.call("position_for", str(order["to"])) if not order.is_empty() else Vector3.ZERO

func _toggle_venue() -> void:
	if current_car != null or current_transit != null:
		_notify("Get out of the vehicle before visiting a venue.")
		return
	if venue_panel.visible:
		_close_venue()
		return
	var venue: Dictionary = venue_system.call("venue_by_id", str(interiors.call("active_site_id"))) if interiors.call("is_inside") else venue_system.call("nearest_venue", player.global_position)
	if not interiors.call("is_inside") and str(venue.get("id","")) == "helix_espresso":
		_notify("Enter Helix Espresso and use its physical counter.")
		return
	if str(venue.get("id", "")) == "insert_coin":
		_notify("INSERT COIN: enter with H / LB to play.")
		return
	if venue.is_empty():
		_notify("Find a glowing venue frontage, then press G to visit.")
		return
	venue_selected_id = str(venue["id"])
	mara_dialogue_line = ""
	_show_venue_dialogue()
	_update_venue_panel()

func _show_venue_dialogue() -> void:
	if venue_selected_id == "lantern_cup" and interiors.call("is_inside"):
		interiors.call("set_mara_attention", true)
	if is_instance_valid(ambient_caption):
		ambient_caption.call("clear")
	venue_panel.visible = true
	player.set("input_blocked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if venue_service_button != null:
		venue_service_button.call_deferred("grab_focus")

func _close_venue() -> void:
	_investigation_open = false
	_investigation_feedback = ""
	_technical_case_open = false
	_technical_feedback = ""
	if is_instance_valid(dialogue_director):
		dialogue_director.call("cancel_scope","venue:music_contact")
	if interiors != null:
		interiors.call("set_mara_attention", false)
	mara_dialogue_line = ""
	if is_instance_valid(contact_caption):
		contact_caption.call("clear")
	if is_instance_valid(ambient_caption):
		ambient_caption.call("clear")
	if venue_talk_button != null:
		venue_talk_button.visible = false
	venue_selected_id = ""
	_repair_panel = false
	_title_offer_id = ""
	_title_quote_id = ""
	_clear_sale_quote()
	_sale_offer_id = ""
	_home_panel = false
	_storage_upgrade_quote = false
	if _wardrobe_panel and is_instance_valid(player):
		player.get_node("Visual").call("set_look",progression.outfit_id,progression.clothing_slots)
		if _clothing_retail:
			player.get_node("Visual").rotation.y=_fitting_yaw
	_wardrobe_panel = false
	_clothing_retail=false
	_retail_id=""
	_retail_stock.clear()
	_fitting_compare=false
	_wardrobe_category="ALL"
	_look_index=0
	_look_save_pending=false
	if is_instance_valid(_wardrobe_controls):
		_wardrobe_controls.hide()
	_wardrobe_quote_id = ""
	_wardrobe_tender = "USD"
	_exchange_panel = false
	_tenancy_panel = false
	_garage_panel = false
	_vending_machine = null
	for button in [venue_service_button,venue_job_button,venue_talk_button]:
		if is_instance_valid(button):
			button.icon = null
	civic_selected_id = ""
	if venue_panel != null:
		venue_panel.visible = false
	if venue_job_button != null:
		venue_job_button.show()
	if is_instance_valid(player):
		player.set("input_blocked", false)
	if game_menu == null or not game_menu.call("is_open"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _wardrobe_visible_ids() -> Array:
	var result:Array=[]
	for id in Wardrobe.category_ids(_wardrobe_category):
		if _wardrobe_category=="OWNED":
			if _clothing_owned(id):
				result.append(id)
			continue
		var available:bool=(id in _retail_stock or id in Wardrobe.RESET_IDS) if _clothing_retail else (id not in ClothingStore.EXCLUSIVE or _clothing_owned(id))
		if not available:
			continue
		if _wardrobe_category in ["AFFORDABLE","UNOWNED"]:
			if _clothing_owned(id):
				continue
			var cost:=int(Wardrobe.listing(id)["price"])
			if _wardrobe_category=="AFFORDABLE" and not progression.can_pay(cost,"USD") and not progression.can_pay(cost,"BTC"):
				continue
		result.append(id)
	return result

func _cycle_wardrobe_category(direction:int) -> void:
	if not _wardrobe_panel or not _wardrobe_quote_id.is_empty():
		return
	var index:=Wardrobe.CATEGORIES.find(_wardrobe_category)
	_wardrobe_category=Wardrobe.CATEGORIES[posmod(index+direction,Wardrobe.CATEGORIES.size())]
	player.get_node("Visual").call("set_look",progression.outfit_id,progression.clothing_slots)
	_fitting_rotation=0.0
	_fitting_zoom=0.0
	_look_save_pending=false
	_look_index=0
	var visible_ids:=_wardrobe_visible_ids()
	if not visible_ids.is_empty():
		_wardrobe_index=Wardrobe.browse_ids().find(visible_ids[0])
	_fitting_compare=false
	_update_venue_panel()

func _toggle_fitting_compare() -> void:
	if _wardrobe_panel and _wardrobe_category=="LOOKS":
		_save_fitting_look()
		return
	if not _wardrobe_panel or not _clothing_retail:
		return
	_fitting_compare=not _fitting_compare
	_update_venue_panel()

func _wardrobe_session_valid() -> bool:
	if not _wardrobe_panel or not is_instance_valid(player) or not venue_panel.visible or current_car!=null or current_transit!=null:
		return false
	var lot:Node3D=city_details.call("nearby_walk_in",player.global_position)
	if not is_instance_valid(lot):
		return false
	if _clothing_retail:
		return lot.get("clothing_store_id")==_retail_id and lot.call("clothing_reachable",player.global_position)
	return progression.owns_home() and lot.call("home_action",player.global_position)=="wardrobe"

func _save_fitting_look() -> void:
	if not _wardrobe_session_valid() or _wardrobe_category!="LOOKS":
		return
	var id:String=ProgressionLedger.LOOK_IDS[_look_index]
	if not progression.saved_look(id).is_empty() and not _look_save_pending:
		_look_save_pending=true
		_update_venue_panel()
		return
	if progression.save_look(id,_clothing_retail):
		_notify("Saved current outfit to Look %d." % (_look_index+1))
	_look_save_pending=false
	_update_venue_panel()

func _update_saved_looks() -> void:
	var id:String=ProgressionLedger.LOOK_IDS[_look_index]
	var look:Dictionary=progression.saved_look(id)
	var visual:Node3D=player.get_node("Visual")
	var preview_ok:=true
	if look.is_empty():
		visual.call("set_look",progression.outfit_id,progression.clothing_slots)
	else:
		preview_ok=bool(visual.call("set_look",look["outfit"],look["slots"]))
	_wardrobe_controls.show()
	_wardrobe_category_label.text="LOOKS / %d of %d" % [_look_index+1,ProgressionLedger.LOOK_IDS.size()]
	for button in _wardrobe_controls.get_children():
		if button is Button:
			button.disabled=false
	_wardrobe_compare_button.show()
	_wardrobe_compare_button.text="R / ↓ CONFIRM REPLACE" if _look_save_pending else "R / ↓ SAVE CURRENT"
	var info:="Empty slot" if look.is_empty() else str(Wardrobe.ITEMS[look["outfit"]]["name"])
	if not look.is_empty():
		for slot in Wardrobe.SLOTS:
			if look["slots"].has(slot):
				info+=" / "+str(Wardrobe.PIECES[look["slots"][slot]]["name"])
	venue_label.text="PERSONAL LOOK %d\n%s\n%s" % [_look_index+1,info,"Confirm replacement with your committed look." if _look_save_pending else "Save the look you are wearing or equip this saved combination. No charge."]
	venue_service_button.show()
	venue_service_button.text="1 / A  •  PREVIOUS"
	venue_service_button.disabled=_look_index==0
	venue_job_button.show()
	venue_job_button.text="2 / X  •  NEXT"
	venue_job_button.disabled=_look_index==ProgressionLedger.LOOK_IDS.size()-1
	venue_talk_button.show()
	venue_talk_button.text="3 / Y  •  EQUIP LOOK"
	venue_talk_button.disabled=look.is_empty() or not preview_ok

func _step_wardrobe(direction:int) -> void:
	var visible_ids:=_wardrobe_visible_ids()
	if visible_ids.is_empty():
		return
	var current:String=Wardrobe.browse_ids()[_wardrobe_index]
	var index:=visible_ids.find(current)
	_wardrobe_index=Wardrobe.browse_ids().find(visible_ids[clampi(index+direction,0,visible_ids.size()-1)])
	_fitting_compare=false
	_fitting_rotation=0.0
	_fitting_zoom=0.0

func _clothing_owned(id:String) -> bool:
	if not Wardrobe.reset_slot(id).is_empty():
		return true
	return progression.owns_piece(id) if Wardrobe.piece_valid(id) else progression.owns_outfit(id)

func _clothing_selected(id:String) -> bool:
	var slot:=Wardrobe.reset_slot(id)
	if not slot.is_empty():
		return not progression.clothing_slots.has(slot)
	if Wardrobe.piece_valid(id):
		return progression.clothing_slots.get(Wardrobe.PIECES[id]["slot"],"")==id
	return progression.outfit_id==id and progression.clothing_slots.is_empty()

func _preview_clothing(id:String) -> bool:
	var visual:Node3D=player.get_node("Visual")
	var reset:=Wardrobe.reset_slot(id)
	if not reset.is_empty():
		var slots:Dictionary=progression.clothing_slots.duplicate()
		slots.erase(reset)
		return visual.call("set_look",progression.outfit_id,slots)
	if Wardrobe.piece_valid(id):
		var slots:Dictionary=progression.clothing_slots.duplicate()
		slots[Wardrobe.PIECES[id]["slot"]]=id
		return visual.call("set_look",progression.outfit_id,slots)
	return visual.call("set_look",id,{})

func _update_venue_panel() -> void:
	if is_instance_valid(contact_caption) and (venue_selected_id != "lantern_cup" or not interiors.call("is_inside")):
		contact_caption.call("clear")
	if _tenancy_panel:
		var price := StarterHome.move_in_price()
		venue_label.text = "LANTERN COURT / CAPSULE TENANCY\nInitial deposit $%d  |  CASH $%d\nStarter rental access. [1 / A] Cancel  [3 / Y] Confirm" % [price,cash]
		venue_service_button.show()
		venue_service_button.text = "1 / A  •  CANCEL"
		venue_service_button.disabled = false
		venue_job_button.hide()
		venue_talk_button.show()
		venue_talk_button.text = "3 / Y  •  PAY POD DEPOSIT"
		venue_talk_button.disabled = cash < price
		return
	if _exchange_panel:
		venue_label.text = "MORROW EXCHANGE / HOME TERMINAL\nUSD $%d  |  BTC %d sats\n$100 buy: +39,200 sats\n40,000 sats sell: +$98\n2%% fee each trade; fictional fixed rate." % [cash,progression.bitcoin_sats]
		venue_service_button.show()
		venue_service_button.text = "1 / A  •  BUY BTC ($100)"
		venue_service_button.disabled = cash < Economy.EXCHANGE_USD or progression.bitcoin_sats > Economy.MAX_SATS-Economy.sats_for_usd(Economy.EXCHANGE_USD-Economy.EXCHANGE_FEE_USD)
		venue_job_button.show()
		venue_job_button.text = "2 / X  •  SELL BTC (40,000 sats)"
		venue_job_button.disabled = progression.bitcoin_sats < Economy.sats_for_usd(Economy.EXCHANGE_USD) or cash > ProgressionLedger.MAX_CASH-(Economy.EXCHANGE_USD-Economy.EXCHANGE_FEE_USD)
		venue_talk_button.hide()
		return
	if _wardrobe_panel:
		if _wardrobe_category=="LOOKS":
			_update_saved_looks()
			return
		var id: String = _wardrobe_quote_id if not _wardrobe_quote_id.is_empty() else Wardrobe.browse_ids()[_wardrobe_index]
		var item: Dictionary = Wardrobe.listing(id)
		var price:=int(item["price"])
		var visible_ids:=_wardrobe_visible_ids()
		if visible_ids.is_empty() and _wardrobe_quote_id.is_empty():
			player.get_node("Visual").call("set_look",progression.outfit_id,progression.clothing_slots)
			_wardrobe_controls.show()
			_wardrobe_category_label.text=_wardrobe_category+" / 0 items"
			_wardrobe_compare_button.hide()
			for button in _wardrobe_controls.get_children():
				if button is Button:
					button.disabled=false
			venue_label.text="NO MATCHING CLOTHING\n"+("No unowned items fit either wallet balance." if _wardrobe_category=="AFFORDABLE" else "Nothing available in this category.")+"\nChange category to continue browsing."
			venue_service_button.show()
			venue_job_button.show()
			venue_talk_button.show()
			venue_service_button.text="1 / A  •  PREVIOUS"
			venue_job_button.text="2 / X  •  NEXT"
			venue_talk_button.text="3 / Y  •  SELECT"
			venue_service_button.disabled=true
			venue_job_button.disabled=true
			venue_talk_button.disabled=true
			return
		var visible_index:=visible_ids.find(id)
		if visible_index<0 and _wardrobe_quote_id.is_empty() and not visible_ids.is_empty():
			id=visible_ids[0]
			_wardrobe_index=Wardrobe.browse_ids().find(id)
			item=Wardrobe.listing(id)
			price=int(item["price"])
			visible_index=0
		var preview_ok:=true
		if _clothing_retail:
			preview_ok=bool(player.get_node("Visual").call("set_look",progression.outfit_id,progression.clothing_slots)) if _fitting_compare else _preview_clothing(id)
		_wardrobe_controls.show()
		_wardrobe_category_label.text=_wardrobe_category+"  /  "+str(visible_index+1)+" of "+str(visible_ids.size())+("  •  DROP "+str(_retail_day%3+1) if _retail_id==ClothingStore.THRIFT else "")
		_wardrobe_compare_button.visible=_clothing_retail
		_wardrobe_compare_button.text="R / ↓  PREVIEW" if _fitting_compare else "R / ↓  COMPARE"
		for button in _wardrobe_controls.get_children():
			if button is Button and button!=_wardrobe_compare_button:
				button.disabled=not _wardrobe_quote_id.is_empty()
		venue_service_button.show()
		venue_talk_button.show()
		if not _wardrobe_quote_id.is_empty():
			var cost := "$%d" % price if _wardrobe_tender == "USD" else "%d sats" % Economy.sats_for_usd(price)
			venue_label.text = "CONFIRM CLOTHING PURCHASE\n%s / %s\nPay %s (%s)\nUSD $%d  |  BTC %d sats\nCosmetic only. Owned permanently." % [item["name"],item["rarity"],cost,_wardrobe_tender,cash,progression.bitcoin_sats]
			venue_service_button.text = "1 / A  •  CANCEL"
			venue_service_button.disabled = false
			venue_job_button.show()
			venue_job_button.text = "2 / X  •  SWITCH USD / BTC"
			venue_job_button.disabled = false
			venue_talk_button.text = "3 / Y  •  CONFIRM PURCHASE"
			venue_talk_button.disabled = visible_index<0 or not preview_ok or not progression.can_pay(price,_wardrobe_tender) or _clothing_owned(id)
			return
		var owned := _clothing_owned(id)
		venue_label.text = (str(ClothingStore.STORES[_retail_id]["name"])+" / FITTING" if _clothing_retail else "WARDROBE")+"\n%s  ·  %s\n%s   |   CASH $%d\n%s" % [item["name"],item["type"]+" / "+item["rarity"],"EQUIPPED" if _clothing_selected(id) else ("OWNED" if owned else "$%d / %d sats" % [price,Economy.sats_for_usd(price)]),cash,"CURRENT LOOK" if _fitting_compare else ("TRY-ON ONLY • Right stick / drag RMB to rotate • zoom with stick / wheel" if _clothing_retail else "Wearing: "+str(Wardrobe.ITEMS[progression.outfit_id]["name"]))]
		venue_label.text+="\n"+str(item.get("detail",""))
		venue_service_button.text = "1 / A  •  PREVIOUS"
		venue_service_button.disabled = visible_index<=0
		venue_job_button.show()
		venue_job_button.text = "2 / X  •  NEXT"
		venue_job_button.disabled = visible_index>=visible_ids.size()-1
		venue_talk_button.text = ("3 / Y  •  REMOVE / RESTORE" if not Wardrobe.reset_slot(id).is_empty() else "3 / Y  •  EQUIP") if owned else "3 / Y  •  REVIEW PURCHASE"
		if _clothing_retail and Wardrobe.piece_valid(id) and Wardrobe.PIECES[id]["slot"]=="patch":
			venue_label.text+="\nBACKPACK ART / "+("CURRENT PATCH" if _fitting_compare else "ROTATE TO INSPECT")
		venue_talk_button.disabled = not preview_ok or _clothing_selected(id) or (not owned and not progression.can_pay(price,"USD") and not progression.can_pay(price,"BTC"))
		return
	if _garage_panel:
		venue_label.text = "LANTERN GARAGE / RECOVERY\nDrive into either marked bay and leave your car there. Recovery $75; damage retained."
		var buttons := [venue_service_button,venue_job_button]
		var garage: Node3D = city_details.call("starter_garage",player.global_position)
		for i in range(2):
			var id: String = StarterGarage.IDS[i]
			var owned := progression.owns_vehicle(id)
			buttons[i].show()
			var label := "BUY KESTREL TITLE $%d" % RoadCars.title_price(id) if i==0 else "CINDER TITLE REQUIRED"
			var disabled := i!=0 or cash<RoadCars.title_price(id) or heat>.01
			var car := _garage_vehicle(id)
			if not owned and i==0 and (not is_instance_valid(car) or car.get("occupied") or not is_finite(float(car.get("speed"))) or absf(float(car.get("speed")))>.5):
				label = "KESTREL / UNAVAILABLE"
				disabled = true
			if owned:
				var name := str(RoadCars.TITLES[id]["name"])
				if not is_instance_valid(car) or car.get("occupied") or not is_finite(float(car.get("speed"))) or absf(float(car.get("speed")))>.5:
					label = name+" / UNAVAILABLE"
					disabled = true
				elif is_instance_valid(garage) and garage.call("parked_at",car.global_position,i):
					label = name+" / PARKED • NO FEE"
					disabled = true
				else:
					label = "RECOVER "+name+" $%d"%StarterGarage.RECOVERY_FEE
					disabled = cash<StarterGarage.RECOVERY_FEE or heat>.01
			buttons[i].text = "%d / %s  •  %s" % [i+1,"A" if i==0 else "X",label]
			buttons[i].disabled = disabled
		venue_talk_button.hide()
		return
	if _home_panel:
		if _storage_upgrade_quote:
			venue_label.text = "HOME / STORAGE EXPANSION\nCapacity %d → %d provisions\nPrice $%d  |  Cash after $%d\n[1 / A] Cancel  •  [3 / Y] Confirm" % [StarterHome.MAX_STORAGE,StarterHome.EXPANDED_STORAGE,StarterHome.STORAGE_UPGRADE_PRICE,cash-StarterHome.STORAGE_UPGRADE_PRICE]
			venue_service_button.text = "1 / A  •  CANCEL"
			venue_service_button.disabled = false
			venue_job_button.hide()
			venue_talk_button.show()
			venue_talk_button.text = "3 / Y  •  CONFIRM UPGRADE"
			venue_talk_button.disabled = progression.home_storage_expanded or cash < StarterHome.STORAGE_UPGRADE_PRICE
			return
		venue_label.text = "HOME STORAGE / %d of %d provisions\nCarrying %d / 99" % [progression.home_supplies,progression.home_capacity(),ration_packs]
		venue_service_button.text = "1 / A  •  STORE ONE"
		venue_service_button.disabled = ration_packs <= 0 or progression.home_supplies >= progression.home_capacity()
		venue_job_button.show()
		venue_job_button.text = "2 / X  •  TAKE ONE"
		venue_job_button.disabled = ration_packs >= 99 or progression.home_supplies <= 0
		venue_talk_button.visible = not progression.home_storage_expanded
		venue_talk_button.text = "3 / Y  •  REVIEW UPGRADE $%d" % StarterHome.STORAGE_UPGRADE_PRICE
		venue_talk_button.disabled = cash < StarterHome.STORAGE_UPGRADE_PRICE
		return
	if is_instance_valid(_vending_machine):
		var items: Array = _vending_machine.get_meta("items",[])
		var body := "NIGHTGRID / 24H  •  VENDING\nCASH $%d  |  PACK %d/%d\n" % [cash,Consumables.count(consumable_inventory),Consumables.MAX_ITEMS]
		var buttons := [venue_service_button,venue_job_button,venue_talk_button]
		for i in range(3):
			var item: Dictionary = Consumables.ITEMS[items[i]]
			body += "%d. %s  $%d  +%d HP / +%d ST\n" % [i+1,item["name"],item["price"],item["health"],item["stamina"]]
			buttons[i].show()
			buttons[i].icon = Consumables.PRODUCT_ICONS[items[i]]
			buttons[i].add_theme_constant_override("icon_max_width",36)
			buttons[i].disabled = cash < int(item["price"]) or Consumables.count(consumable_inventory) >= Consumables.MAX_ITEMS
			buttons[i].text = "%d  •  BUY $%d" % [i+1,item["price"]]
		venue_label.text = body+"[G / B] Close  •  R / D-pad down: use best snack"
		return
	if _repair_panel:
		if not _sale_quote_id.is_empty():
			var quoted_car := _title_by_id(_sale_quote_id)
			venue_label.text = "CONFIRM VEHICLE SALE\n%s / %s\nOffer $%d  |  Cash after $%d\nTitle transfers to dealer. Vehicle stays parked.\n[3 / Y] Confirm  •  [1 / A] Cancel" % [RoadCars.TITLES[_sale_quote_id]["name"],_sale_quote_id,_sale_quote_amount,cash+_sale_quote_amount]
			venue_service_button.text = "1 / A  •  CANCEL"
			venue_service_button.disabled = false
			venue_job_button.hide()
			venue_talk_button.show()
			venue_talk_button.text = "3 / Y  •  CONFIRM SALE"
			venue_talk_button.disabled = _sale_value(quoted_car) != _sale_quote_amount or _sale_quote_amount > ProgressionLedger.MAX_CASH-cash
			return
		if not _title_quote_id.is_empty():
			var title: Dictionary = RoadCars.TITLES[_title_quote_id]
			var quoted_car := _title_by_id(_title_quote_id)
			var condition := "%.0f%%" % float(quoted_car.get("condition")) if is_instance_valid(quoted_car) else "Unavailable"
			venue_label.text = "CONFIRM VEHICLE TITLE\n%s / %s\nCondition %s   |   Price $%d\nCash $%d  →  $%d\n[2 / X] Confirm  •  [1 / A] Cancel" % [title["name"],_title_quote_id,condition,RoadCars.title_price(_title_quote_id),cash,cash-RoadCars.title_price(_title_quote_id)]
			venue_service_button.text = "1 / A  •  CANCEL"
			venue_service_button.disabled = false
			venue_job_button.show()
			venue_job_button.text = "2 / X  •  CONFIRM TITLE"
			venue_job_button.disabled = not _title_eligible(quoted_car) or cash < RoadCars.title_price(_title_quote_id)
			venue_talk_button.hide()
			return
		venue_label.text = "NIGHT SHIFT REPAIRS\nLeave the vehicle outside and bring the keys to the counter.\n[1 / A] Repair parked vehicle  $%d\n[G / B] Close   |   CASH $%d" % [BrickwaterRepair.PRICE, cash]
		venue_service_button.text = "1 / A  •  REPAIR"
		venue_service_button.disabled = false
		var candidate := _nearby_title_candidate()
		_title_offer_id = str(candidate.get_meta("vehicle_id")) if candidate != null else ""
		venue_job_button.show()
		venue_job_button.disabled = candidate == null
		venue_job_button.text = "2 / X  •  REGISTER VEHICLE TITLE"
		if candidate != null:
			var title: Dictionary = RoadCars.TITLES[str(candidate.get_meta("vehicle_id"))]
			venue_job_button.text = "2 / X  •  REVIEW %s TITLE  $%d" % [title["name"], RoadCars.title_price(_title_offer_id)]
			venue_job_button.disabled = cash < RoadCars.title_price(_title_offer_id)
		venue_label.text += "\nTitle desk: bring eligible parked stock to the shop."
		if progression.owns_home() and not progression.owns_vehicle(StarterGarage.IDS[0]):
			venue_label.text += "\nKestrel title available at Lantern Garage."
		var sale := _nearby_sale_candidate()
		_sale_offer_id = str(sale.get_meta("vehicle_id")) if sale != null else ""
		venue_talk_button.visible = sale != null
		if sale != null:
			venue_talk_button.text = "3 / Y  •  REVIEW SALE  $%d" % _sale_value(sale)
			venue_talk_button.disabled = _sale_value(sale) > ProgressionLedger.MAX_CASH-cash
		return
	if not civic_selected_id.is_empty():
		_update_civic_panel()
		return
	if venue_label == null or venue_selected_id.is_empty():
		return
	var venue: Dictionary = venue_system.call("venue_by_id", venue_selected_id)
	if venue.is_empty():
		_close_venue()
		return
	var open_now: bool = venue_system.call("is_open", venue_selected_id)
	var status := "OPEN" if open_now else "CLOSED"
	var hours_text := "%02d:00-%02d:00" % [int(venue["opens"]), int(venue["closes"])]
	var body := "%s | %s | %s (%s)\n%s: %s\n" % [
		str(venue["name"]), str(venue["kind"]), status, hours_text,
		str(venue["host"]), str(venue["flavor"])]
	var is_mara := venue_selected_id == "lantern_cup" and bool(interiors.call("is_inside"))
	if is_mara:
		var introduction := str(interiors.call("mara_greeting", _mara_context()))
		contact_caption.call("present", "Mara", mara_dialogue_line if not mara_dialogue_line.is_empty() else introduction, true)
	else:
		contact_caption.call("clear")
	if open_now:
		body += "Available: %s  $%d   " % [str(venue["item"]), int(venue["price"])]
		if venue_job_active.is_empty():
			var offer: Dictionary = venue_system.call("job_from", venue_selected_id)
			if not offer.is_empty() and not venue_job_completed.has(str(offer["id"])) and not progression.has_receipt("venue:"+str(offer["id"])):
				if venue_system.call("job_unlocked",offer,progression.street_cred()):
					body += "\nLocal work: %s (+$%d)" % [str(offer["title"]), int(offer["reward"])]
				else:
					body += "\n%s / Requires %d Street Cred (you have %d)"%[str(offer["title"]),int(offer["min_cred"]),progression.street_cred()]
		else:
			var active: Dictionary = venue_system.call("job_by_id", venue_job_active)
			if not active.is_empty() and str(active["to"]) == venue_selected_id:
				body += "\nDeliver: %s (+$%d)" % [str(active["title"]), int(active["reward"])]
	else:
		body += "Come back during business hours."
	body += "\nCash  $%d" % cash
	venue_label.text = body
	if venue_service_button != null:
		venue_service_button.disabled = not open_now
		venue_service_button.text = "1 / A  •  SERVICE"
	if venue_job_button != null:
		var offered: Dictionary = venue_system.call("job_from", venue_selected_id) if venue_job_active.is_empty() else venue_system.call("job_by_id", venue_job_active)
		var available:bool = not offered.is_empty() and (
			(not venue_job_active.is_empty() and str(offered["to"]) == venue_selected_id) or
			(venue_job_active.is_empty() and not venue_job_completed.has(str(offered["id"])) and not progression.has_receipt("venue:"+str(offered["id"])) and venue_system.call("job_unlocked",offered,progression.street_cred())))
		venue_job_button.disabled = not open_now or not available
		venue_job_button.text = "2 / X  ·  " + ("Turn in job" if not venue_job_active.is_empty() else "Ask for work")
	if venue_talk_button != null:
		var music_set:=venue_selected_id=="blue_hour" and progression.has_receipt("venue:soundcheck_pass")
		var busk:bool=bool(venue_selected_id in BUSKING_SITES and not interiors.call("is_inside"))
		var recruit:bool=venue_selected_id=="dock_nine" and progression.band_recruit_available("milo") and _band_contact_reachable("dock_nine")
		venue_talk_button.visible = is_mara or music_set or busk or recruit
		venue_talk_button.disabled = not is_mara and not (music_set and open_now and _blue_hour_set_reachable()) and not (busk and _busking_reachable(venue_selected_id))
		venue_talk_button.text="3 / Y  •  PLAY OPENING SET" if music_set else (("3 / Y  •  MUSIC DESK" if venue_selected_id=="copper_cup" else "3 / Y  •  BUSK WITH LOANER SAMPLER") if busk else "3 / Y  •  TALK TO MARA")

		if music_set and progression.band_debut_available():
			venue_talk_button.text="3 / Y  •  TRIO DEBUT / $240"
		elif music_set and progression.band_encore_available():
			venue_talk_button.text="3 / Y  •  TRIO ENCORE / $120"
		if venue_selected_id=="static_room" and progression.band_showcase_available():
			venue_talk_button.show()
			venue_talk_button.disabled=not _band_contact_reachable("static_room")
			venue_talk_button.text="3 / Y  •  SHOWCASE / $480"
		if recruit:
			venue_talk_button.disabled=false
			venue_talk_button.text="3 / Y  •  INVITE MILO STATIC"

func _band_contact_reachable(site:String)->bool:
	if not is_instance_valid(player) or current_car!=null or current_transit!=null or weapons.equipped!="holstered" or not venue_system.call("is_open",site):
		return false
	if interiors.call("is_inside"):
		return str(interiors.call("active_site_id"))==site and bool(interiors.call("counter_reachable",player.global_position))
	var point:Vector3=venue_system.call("venue_position",site)
	return player.global_position.distance_to(point)<=5.5

func _mara_context() -> Dictionary:
	return {
		"hour": float(day_night.get("hour")),
		"health": health, "heat": heat,
		"shift_notes": civic_intel.has("lantern_cup_shift_notes"),
		"job": venue_job_active,
		"outfit_tier": int(Wardrobe.ITEMS[progression.outfit_id]["tier"]) if story_mission.status == "complete" else 0
	}

func _venue_action(option: int) -> void:
	if _tenancy_panel:
		var lot: Node3D = city_details.call("nearby_walk_in",player.global_position)
		if not venue_panel.visible or not is_instance_valid(lot) or lot.get("home_id") != StarterHome.ID or not lot.call("doorway_reachable",player.global_position) or current_car != null or current_transit != null:
			_close_venue()
			return
		if option == 1:
			_close_venue()
		elif option == 3:
			if progression.activate_home_tenancy():
				_close_venue()
				_notify("Deposit accepted. Sleep Pod 01 is unlocked.")
			else:
				_notify("Payment declined. Earn more from courier contracts.")
		return
	if _exchange_panel:
		var lot: Node3D = city_details.call("nearby_walk_in",player.global_position)
		if not venue_panel.visible or not is_instance_valid(lot) or lot.call("home_action",player.global_position) != "exchange" or not progression.owns_home() or current_car != null or current_transit != null:
			_close_venue()
			return
		if option in [1,2]:
			if progression.exchange_bitcoin(option == 1):
				_notify("Currency exchanged. 2% fee paid.")
			else:
				_notify("Exchange declined. No balances changed.")
		_update_venue_panel()
		return
	if _wardrobe_panel:
		var lot: Node3D = city_details.call("nearby_walk_in",player.global_position)
		var retail_ok:bool=is_instance_valid(lot) and _clothing_retail and lot.get("clothing_store_id")==_retail_id and lot.call("clothing_reachable",player.global_position)
		var home_ok:bool=is_instance_valid(lot) and not _clothing_retail and progression.owns_home() and lot.call("home_action",player.global_position)=="wardrobe"
		if not venue_panel.visible or not (retail_ok or home_ok) or current_car != null or current_transit != null:
			_close_venue()
			return
		var visual := player.get_node("Visual")
		if _wardrobe_category=="LOOKS":
			_look_save_pending=false
			if option in [1,2]:
				_look_index=clampi(_look_index+(-1 if option==1 else 1),0,ProgressionLedger.LOOK_IDS.size()-1)
			elif option==3:
				var look_id:String=ProgressionLedger.LOOK_IDS[_look_index]
				var look:Dictionary=progression.saved_look(look_id)
				if not look.is_empty() and visual.call("set_look",look["outfit"],look["slots"]) and progression.equip_look(look_id,retail_ok):
					_notify("Equipped personal look %d." % (_look_index+1))
			_update_venue_panel()
			return
		if not _wardrobe_quote_id.is_empty():
			if option == 1:
				_wardrobe_quote_id = ""
			elif option == 2:
				_wardrobe_tender = "BTC" if _wardrobe_tender == "USD" else "USD"
			elif option == 3:
				var id := _wardrobe_quote_id
				_wardrobe_quote_id = ""
				if id in _wardrobe_visible_ids() and _preview_clothing(id) and int(visual.call("wardrobe_surface_count"))>0 and (progression.buy_piece(id,_wardrobe_tender,retail_ok) if Wardrobe.piece_valid(id) else progression.buy_outfit(id,_wardrobe_tender,retail_ok)):
					_notify("Purchased "+str(Wardrobe.listing(id)["name"])+". Ready to equip."+(" "+str(lot.call("clothing_remark",true)) if retail_ok else ""))
					if _wardrobe_category in ["AFFORDABLE","UNOWNED"]:
						_wardrobe_category="OWNED"
						_wardrobe_index=Wardrobe.browse_ids().find(id)
				else:
					_notify("Purchase unavailable. No payment taken.")
		elif option == 1:
			_step_wardrobe(-1)
		elif option == 2:
			_step_wardrobe(1)
		elif option == 3:
			var id:String=Wardrobe.browse_ids()[_wardrobe_index]
			if id not in _wardrobe_visible_ids():
				return
			var price:=int(Wardrobe.listing(id)["price"])
			_fitting_compare=false
			if _clothing_owned(id):
				if _preview_clothing(id):
					var reset:=Wardrobe.reset_slot(id)
					var changed:bool=progression.clear_piece(reset,retail_ok) if not reset.is_empty() else (progression.select_piece(id,retail_ok) if Wardrobe.piece_valid(id) else progression.select_outfit(id,retail_ok))
					if changed:
						_notify("Appearance: "+str(Wardrobe.listing(id)["name"]))
			elif progression.can_pay(price,"USD") or progression.can_pay(price,"BTC"):
				_wardrobe_tender="USD" if progression.can_pay(price,"USD") else "BTC"
				_wardrobe_quote_id=id
		_update_venue_panel()
		return
	if _garage_panel:
		var garage: Node3D = city_details.call("starter_garage",player.global_position)
		if not venue_panel.visible or not is_instance_valid(garage) or not garage.call("desk_reachable",player.global_position) or not progression.owns_home() or current_car != null or current_transit != null:
			_close_venue()
			return
		if option in [1,2]:
			_recover_garage_vehicle(garage,option-1)
		_update_venue_panel()
		return
	if _home_panel:
		var lot: Node3D = city_details.call("nearby_walk_in",player.global_position)
		if not venue_panel.visible or current_car != null or current_transit != null or not is_instance_valid(lot) or lot.get("home_id") != StarterHome.ID or lot.call("home_action",player.global_position) != "storage" or not progression.owns_home():
			_close_venue()
			return
		if _storage_upgrade_quote:
			if option == 1:
				_storage_upgrade_quote = false
			elif option == 3:
				_storage_upgrade_quote = false
				if progression.expand_home_storage():
					_notify("Storage expanded to %d provisions." % progression.home_capacity())
				else:
					_notify("Upgrade unavailable. No payment taken.")
		elif option == 1:
			ration_packs -= progression.deposit_supply(ration_packs)
		elif option == 2:
			ration_packs += progression.withdraw_supply(ration_packs)
		elif option == 3 and not progression.home_storage_expanded and cash >= StarterHome.STORAGE_UPGRADE_PRICE:
			_storage_upgrade_quote = true
		_update_venue_panel()
		return
	if is_instance_valid(_vending_machine):
		if not venue_panel.visible or city_details.call("nearby_vending",player.global_position) != _vending_machine or current_car != null or current_transit != null:
			_close_venue()
			return
		var items: Array = _vending_machine.get_meta("items",[])
		if option < 1 or option > items.size():
			return
		var id: String = items[option-1]
		var item: Dictionary = Consumables.ITEMS[id]
		if Consumables.count(consumable_inventory) >= Consumables.MAX_ITEMS or not progression.spend(int(item["price"])):
			_notify("Not enough cash or inventory is full.")
			return
		consumable_inventory[id] = int(consumable_inventory.get(id,0))+1
		var facing := _vending_machine.global_position-player.global_position
		player.get_node("Visual").rotation.y = atan2(facing.x,facing.z)
		player.get_node("Visual").call("play_product_action",id,true)
		# The right hand holds the packaged product; the free left hand
		# can contact the cabinet terminal when within anatomical reach.
		player.get_node("Visual").call("reach_target",_vending_machine,_vending_machine.call("payment_anchor"),0)
		_vending_machine.call("dispense_feedback")
		_notify("Dispensed %s. R / D-pad down to consume." % item["name"])
		_update_venue_panel()
		return
	if _repair_panel:
		var repair := _repair_storefront()
		if not venue_panel.visible or repair == null or not repair.counter_reachable(player.global_position) or current_car != null or current_transit != null:
			_close_venue()
			return
		if not _sale_quote_id.is_empty():
			if option == 1:
				_clear_sale_quote()
			elif option == 3:
				_confirm_sale_quote()
		elif not _title_quote_id.is_empty():
			if option == 1:
				_title_quote_id = ""
			elif option == 2:
				_confirm_title_quote()
		elif option == 1:
			_repair_nearby_vehicle(BrickwaterRepair.PRICE)
		elif option == 2:
			_open_title_quote()
		elif option == 3:
			_open_sale_quote()
		_update_venue_panel()
		return
	if not civic_selected_id.is_empty():
		_civic_action(option)
		return
	if venue_panel == null or not venue_panel.visible or venue_selected_id.is_empty():
		return
	var venue: Dictionary = venue_system.call("venue_by_id", venue_selected_id)
	if venue.is_empty():
		_close_venue()
		return
	# Dialogue is no-cost and remains accessible even near closing time.
	if option == 3:
		if venue_selected_id=="static_room" and _band_contact_reachable("static_room") and progression.band_showcase_available():
			_close_venue()
			_music_session_site="band_showcase:static_room"
			game_menu.call("open_band_booking",1,"band_showcase")
			return
		if venue_selected_id=="dock_nine" and _band_contact_reachable("dock_nine") and progression.recruit_band_member("milo"):
			_notify("MILO STATIC / "+str(ProgressionLedger.BAND_MEMBERS["milo"]["line"]))
			_update_venue_panel()
			return
		if venue_selected_id=="copper_cup" and _busking_reachable(venue_selected_id):
			_close_venue()
			_music_session_site="desk:copper_cup"
			_open_music_desk()
			return
		if _busking_reachable(venue_selected_id):
			var site:=venue_selected_id
			var sequence:=progression.street_activity_runs("busking")+1
			_close_venue()
			_music_session_site=site
			game_menu.call("open_busking_set",sequence)
			return
		if venue_selected_id=="blue_hour" and _blue_hour_set_reachable():
			if progression.band_debut_available():
				_close_venue()
				_music_session_site="band_debut:blue_hour"
				game_menu.call("open_band_debut")
				return
			if progression.band_encore_available():
				var encore_sequence:=progression.street_activity_runs("band_encore")+1
				_close_venue()
				_music_session_site="band_encore:blue_hour"
				game_menu.call("open_band_booking",encore_sequence,"band_encore")
				return
			var sequence:=progression.street_activity_runs("live_gig")+1
			_close_venue()
			_music_session_site="blue_hour"
			game_menu.call("open_blue_hour_set",sequence)
			return
		if venue_selected_id == "lantern_cup" and interiors.call("is_inside"):
			var response: Dictionary = interiors.call("mara_talk", _mara_context())
			if not response.is_empty():
				mara_dialogue_line = str(response["line"])
				_notify("MARA / " + str(response["topic"]))
			if interiors.call("active_site_id") == "lantern_cup" and interiors.call("counter_reachable", player.global_position):
				match story_mission.event("mara_talk", progression):
					"started":
						mara_dialogue_line = "Mara: I need someone who knows these streets. Finish a courier run, then come tell me how it went."
						_notify("NIGHT SHIFT CONTACT / New mission")
					"complete":
						mara_dialogue_line = "Mara: You made it back. Here’s a hundred for the referral. Lantern Court has a sleep pod available. Scrape together the deposit and pay at the entrance. It’s not much, but it locks."
						_notify("NIGHT SHIFT CONTACT COMPLETE +$%d" % StoryMission.REWARD)
					"blocked":
						_notify("Wallet full. Speak to Mara again after spending some cash.")
			_update_venue_panel()
		return
	if not bool(venue_system.call("is_open", venue_selected_id)):
		_notify("%s is closed until %02d:00." % [str(venue["name"]), int(venue["opens"])])
		_update_venue_panel()
		return
	if option == 1:
		var price := int(venue["price"])
		var service: Dictionary = venue_system.call("service_effect", str(venue["kind"]))
		var healing := float(service.get("heal", 0.0))
		var cover := float(service.get("heat", 0.0))
		var energy := 40.0 if str(venue["kind"]) == "CAFE" else (20.0 if str(venue["kind"]) == "STALL" else 0.0)
		if healing > 0.0 and health >= 99.9 and (energy <= 0.0 or float(player.get("stamina")) >= 99.9):
			_notify("You're already feeling rested. Save your cash.")
			return
		if cover > 0.0 and heat < 0.01:
			_notify("No police attention to shake. Enjoy the atmosphere.")
			return
		if not progression.spend(price):
			_notify("Not enough cash for %s. Try a courier or side job." % str(venue["item"]))
			return
		health = minf(100.0, health + healing)
		player.call("add_stamina",energy)
		if energy>0.0:
			player.get_node("Visual").call("play_product_action","energy" if str(venue["kind"])=="CAFE" else "sandwich",false)
		heat = maxf(0.0, heat - cover)
		if venue_selected_id == "lantern_cup" and interiors.call("is_inside"):
			interiors.call("mara_purchase_reaction")
			mara_dialogue_line = "Mara: That's freshly pulled. Stay a while; the city's not going anywhere."
		_notify("%s: %s. %s" % [str(venue["name"]), str(venue["item"]),
			"Recovered strength." if healing > 0.0 else "You blend into the crowd."])
	elif option == 2:
		if venue_job_active.is_empty():
			var job: Dictionary = venue_system.call("job_from", venue_selected_id)
			if job.is_empty() or venue_job_completed.has(str(job.get("id", ""))) or progression.has_receipt("venue:"+str(job.get("id",""))):
				_notify("No new work from this contact.")
				return
			if not venue_system.call("job_unlocked",job,progression.street_cred()):
				_notify("Build your local reputation first. Requires %d Street Cred."%int(job.get("min_cred",0)))
				return
			venue_job_active = str(job["id"])
			_notify("NEW SIDE JOB: %s — %s" % [str(job["title"]), str(job["brief"])])
			_play_music_contact_cue(venue_job_active,"brief")
			if venue_job_active=="soundcheck_pass":
				var target:=_venue_job_target()
				set_navigation_waypoint(Vector2(target.x,target.z))
		else:
			var contract: Dictionary = venue_system.call("job_by_id", venue_job_active)
			if contract.is_empty():
				venue_job_active = ""
				return
			if str(contract["to"]) != venue_selected_id:
				_notify("Job active: %s. Destination: %s." % [
					str(contract["title"]),
					str(venue_system.call("venue_by_id", str(contract["to"]))["name"])])
				return
			if venue_job_completed.has(venue_job_active) or progression.has_receipt("venue:" + venue_job_active):
				venue_job_active = ""
				_notify("Side job already paid.")
				_update_venue_panel()
				return
			if not venue_system.call("job_unlocked",contract,progression.street_cred()):
				_notify("This contract requires more Street Cred.")
				return
			var previous_cred:=progression.street_cred()
			if not progression.credit_once("venue:" + venue_job_active, int(contract["reward"])):
				_notify("Unable to settle side job. Check wallet capacity.")
				return
			venue_job_completed.append(venue_job_active)
			_play_music_contact_cue(venue_job_active,"ending")
			venue_job_active = ""
			_notify("SIDE JOB COMPLETE +$%d • +%d STREET CRED: %s" % [int(contract["reward"]),progression.street_cred()-previous_cred,str(contract["ending"])])
	_update_venue_panel()

func _venue_job_text() -> String:
	if venue_job_active.is_empty():
		return "SIDE JOB: Explore social hubs for local work."
	var job: Dictionary = venue_system.call("job_by_id", venue_job_active)
	if job.is_empty():
		return ""
	var venue: Dictionary = venue_system.call("venue_by_id", str(job["to"]))
	var dist := roundi((interiors.get("exterior_position") if interiors.call("is_inside") else _actor().global_position).distance_to(venue_system.call("venue_position", str(job["to"]))))
	return "SIDE JOB: %s / %s (%dm)" % [str(job["title"]), str(venue["name"]), dist]

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.current = true
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = 720.0
	camera.position = PLAYER_START + Vector3(0.0, 5.0, 8.0)
	add_child(camera)

func _create_marker() -> void:
	marker = Node3D.new()
	marker.name = "DeliveryBeacon"
	var disk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.7
	cylinder.bottom_radius = 2.7
	cylinder.height = 0.13
	disk.mesh = cylinder
	disk.position.y = 0.10
	var disk_material := _make_material(Color("ffba56"), true)
	disk_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disk_material.albedo_color.a = 0.47
	disk.material_override = disk_material
	marker.add_child(disk)
	var pillar := MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.3
	beam.bottom_radius = 0.3
	beam.height = 15.0
	pillar.mesh = beam
	pillar.position.y = 7.5
	var pillar_material := _make_material(Color("ffba56"), true)
	pillar_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_material.albedo_color.a = 0.42
	pillar.material_override = pillar_material
	marker.add_child(pillar)
	marker_light = OmniLight3D.new()
	marker_light.position.y = 3.0
	marker_light.light_energy = 1.8
	marker_light.omni_range = 10.0
	marker.add_child(marker_light)
	add_child(marker)

func _create_trial_beacon() -> void:
	# One reusable, noncolliding world-space game marker; no dynamic light.
	_trial_beacon=Node3D.new()
	_trial_beacon.name="DrivingTrialBeacon"
	var ring:=MeshInstance3D.new()
	var mesh:=TorusMesh.new()
	mesh.inner_radius=DrivingTrial.RADIUS-.25
	mesh.outer_radius=DrivingTrial.RADIUS
	mesh.rings=48
	mesh.ring_segments=6
	ring.mesh=mesh
	ring.position.y=.18
	ring.material_override=_make_material(Color("68e0da"),true)
	_trial_beacon.add_child(ring)
	_trial_beacon_label=Label3D.new()
	_trial_beacon_label.position.y=3.6
	_trial_beacon_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	_trial_beacon_label.font_size=42
	_trial_beacon_label.pixel_size=.012
	_trial_beacon_label.modulate=Color("b2fff0")
	_trial_beacon_label.outline_size=8
	_trial_beacon.add_child(_trial_beacon_label)
	add_child(_trial_beacon)
	_sync_trial_beacon()

func _sync_trial_beacon()->void:
	if not is_instance_valid(_trial_beacon):
		return
	var selected:=_driving_trial.course_id
	var target:=DrivingTrial.START
	if _driving_trial.active:
		target=_driving_trial.gates()[_driving_trial.index]
	else:
		var focus:=Vector2(_actor().global_position.x,_actor().global_position.z)
		var routed:=DrivingTrial.course_at(navigation_waypoint) if navigation_waypoint is Vector2 else ""
		selected=routed if not routed.is_empty() else (DrivingTrial.BRICK if focus.distance_squared_to(DrivingTrial.BRICK_START)<focus.distance_squared_to(DrivingTrial.START) else DrivingTrial.SOUTH)
		target=DrivingTrial.BRICK_START if selected==DrivingTrial.BRICK else DrivingTrial.START
	var at:=Vector3(target.x,0.0,target.y)
	var title:="CHECKPOINT %d / %d"%[_driving_trial.index+1,_driving_trial.gates().size()] if _driving_trial.active else DrivingTrial.name_for(selected).to_upper()+" / START"
	if _trial_beacon.position!=at:
		_trial_beacon.position=at
	if _trial_beacon_label.text!=title:
		_trial_beacon_label.text=title
	_trial_beacon.visible=is_instance_valid(player) and not is_instance_valid(_opening_office) and not interiors.call("is_inside") and _actor().global_position.distance_squared_to(at)<120.0*120.0

func _create_trial_ghost()->void:
	# Static Cinder coachwork; one visual opponent, no collision body.
	_trial_ghost=Node3D.new()
	_trial_ghost.name="CircuitRoadRival"
	var visual:=RoadCarVisual.new()
	visual.configure_founder_display()
	_trial_rival_visual=visual
	_trial_ghost.add_child(visual)
	add_child(_trial_ghost)
	var label:=Label3D.new()
	label.text="RIVAL / NON-CONTACT"
	label.position.y=2.0
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=28
	label.pixel_size=.009
	label.modulate=Color("91eaff")
	_trial_ghost.add_child(label)

func _tick_circuit_rival(delta:float)->void:
	if not _circuit_rival.active:
		return
	var at:=_circuit_rival.position
	var forward:=_circuit_rival.desired_heading()
	var right:=Vector2(-forward.y,forward.x)
	var distance:=4.5+_circuit_rival.speed*.55
	var space:=get_world_3d().direct_space_state
	var blocked:=false
	# Three forward samples cover the width of the visual coachwork.
	for lane in [-.8,0.0,.8]:
		var p:=at+right*float(lane)
		var origin:=Vector3(p.x,.7,p.y)
		var target:=origin+Vector3(forward.x,0,forward.y)*distance
		var ray:=PhysicsRayQueryParameters3D.create(origin,target,1)
		if not space.intersect_ray(ray).is_empty():
			blocked=true
			break
	_circuit_rival.tick(delta,blocked)

func _sync_trial_ghost(delta:float)->void:
	if not _driving_trial.active or not _circuit_rival.active:
		if not _driving_trial.active:
			_circuit_rival.stop()
		if is_instance_valid(_trial_ghost):
			_trial_ghost.hide()
		return
	var newly_visible:=not is_instance_valid(_trial_ghost)
	if newly_visible:
		_create_trial_ghost()
	var at:=_circuit_rival.position
	var forward:=_circuit_rival.heading
	_trial_ghost.position=Vector3(at.x,.825,at.y)
	var yaw:=atan2(-forward.x,-forward.y)
	var steer:=clampf(-angle_difference(_trial_ghost.rotation.y,yaw)*2.0,-1.0,1.0)
	_trial_ghost.rotation.y=yaw if newly_visible or _driving_trial.elapsed<.1 else rotate_toward(_trial_ghost.rotation.y,yaw,delta*3.6)
	_trial_rival_visual.call("update_display_motion",_circuit_rival.travel,steer,delta)
	_trial_ghost.visible=_actor().global_position.distance_squared_to(_trial_ghost.global_position)<100.0*100.0

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "HUD"
	add_child(ui)
	# Small, anchored hierarchy: status and objective top left, circular radar bottom left,
	# transient notices at top center, context-only inputs at bottom center.
	var backing := PanelContainer.new()
	backing.name = "PlayerStatus"
	backing.position = Vector2(24.0, 24.0)
	backing.custom_minimum_size = Vector2(390.0, 0.0)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.theme = Ui.make_theme()
	backing.add_theme_stylebox_override("panel", Ui.card(0.84, 12))
	ui.add_child(backing)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	backing.add_child(stack)
	hud_location = _hud_text(stack, "Location", 15, Ui.AMBER)
	hud_label = _hud_text(stack, "PlayerVitals", 17, Ui.TEXT)
	_wanted_label = _hud_text(stack, "WantedStatus", 17, Ui.AMBER)
	hud_health = ProgressBar.new()
	hud_health.name = "HealthBar"
	hud_health.max_value = 100.0
	hud_health.show_percentage = false
	hud_health.custom_minimum_size.y = 6
	hud_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_health.add_theme_stylebox_override("background", Ui.meter(Color("29363e")))
	hud_health.add_theme_stylebox_override("fill", Ui.meter(Ui.ACCENT))
	stack.add_child(hud_health)
	hud_stamina = ProgressBar.new()
	hud_stamina.name = "StaminaBar"
	hud_stamina.max_value = 100.0
	hud_stamina.show_percentage = false
	hud_stamina.custom_minimum_size.y = 5
	hud_stamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stamina.add_theme_stylebox_override("background",Ui.meter(Color("29363e")))
	hud_stamina.add_theme_stylebox_override("fill",Ui.meter(Ui.AMBER))
	stack.add_child(hud_stamina)
	var rule := HSeparator.new()
	stack.add_child(rule)
	_hud_text(stack, "ObjectiveHeading", 15, Ui.MUTED).text = "CURRENT OBJECTIVE"
	hud_objective = _hud_text(stack, "Objective", 21, Ui.ACCENT)
	hud_navigation = _hud_text(stack, "Waypoint", 18, Nav.COLOR)
	hud_navigation.hide()
	hud_jobs = _hud_text(stack, "ActiveContracts", 15, Ui.MUTED)
	var center_notice := _hud_card(ui, "NotificationCard", 1.0, 0.0, Vector4(-434, 24, -24, 92))
	hud_notice_card = center_notice
	hud_notice = _hud_text(center_notice, "Notice", 18, Ui.TEXT)
	hud_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_notice_card.hide()
	hud_prompt_card = _hud_card(ui, "ContextCard", 0.5, 1.0, Vector4(-320, -112, 320, -24))
	hud_prompt_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_prompt = _hud_text(hud_prompt_card, "ContextActions", 16, Ui.TEXT)
	hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_card = _hud_card(ui, "WeaponCard", 1.0, 1.0, Vector4(-302, -112, -24, -24))
	_weapon_label = _hud_text(_weapon_card, "WeaponAmmo", 18, Ui.TEXT)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_card.hide()
	# Driving and weapon displays share a mutually exclusive HUD slot.
	hud_drive_card = _hud_card(ui, "DrivingCard", 1.0, 1.0, Vector4(-302, -150, -24, -24))
	hud_drive_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var drive_stack := VBoxContainer.new()
	drive_stack.add_theme_constant_override("separation", 3)
	drive_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_drive_card.add_child(drive_stack)
	hud_drive_name = _hud_text(drive_stack, "VehicleName", 15, Ui.MUTED)
	hud_drive_speed = _hud_text(drive_stack, "Speed", 32, Ui.TEXT)
	hud_drive_radio = _hud_text(drive_stack, "NowPlaying", 15, Ui.ACCENT)
	for label in [hud_drive_name, hud_drive_speed, hud_drive_radio]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_drive_card.hide()
	_radio_card = _hud_card(ui, "PoliceRadioCard", 1.0, 0.0, Vector4(-402, 278, -24, 362))
	_radio_caption = _hud_text(_radio_card, "Transmission", 16, Color("a4c7ef"))
	_radio_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio_card.hide()
	_dialogue_card = _hud_card(ui, "SpeechCaptionCard", 0.5, 1.0, Vector4(-375, -238, 375, -160))
	_dialogue_caption = _hud_text(_dialogue_card, "SpeechCaption", 19, Ui.TEXT)
	_dialogue_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_card.hide()
	_reticle = Reticle.new()
	_reticle.name = "AimReticle"
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_reticle)
	_reticle.hide()
	minimap = Control.new()
	minimap.name = "Minimap"
	minimap.set_script(RadarScript)
	minimap.anchor_left = 0.0
	minimap.anchor_right = 0.0
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_left = 24.0
	minimap.offset_right = 264.0
	minimap.offset_top = -264.0
	minimap.offset_bottom = -24.0
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.set("world_node", self)
	ui.add_child(minimap)
	performance_label = Label.new()
	performance_label.name = "PerformanceOverlay"
	performance_label.visible = false
	performance_label.anchor_left = 0.5
	performance_label.anchor_right = 1.0
	performance_label.offset_left = 0.0
	performance_label.offset_right = -24.0
	performance_label.offset_top = 116.0
	performance_label.offset_bottom = 166.0
	performance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	performance_label.add_theme_font_size_override("font_size", 15)
	performance_label.add_theme_color_override("font_color", Color("b5eae4"))
	ui.add_child(performance_label)
	venue_panel = PanelContainer.new()
	venue_panel.name = "VenueDialogue"
	venue_panel.anchor_top = 1.0
	venue_panel.anchor_bottom = 1.0
	venue_panel.offset_left = 24.0
	venue_panel.offset_right = 784.0
	venue_panel.offset_top = -330.0
	venue_panel.offset_bottom = -94.0
	venue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	venue_panel.custom_minimum_size = Vector2(0.0, 218.0)
	venue_panel.theme = Ui.make_theme()
	venue_panel.add_theme_stylebox_override("panel", Ui.card(0.97, 20))
	venue_panel.visible = false
	ui.add_child(venue_panel)
	venue_panel.visibility_changed.connect(func() -> void:
		minimap.visible = not venue_panel.visible
		if venue_panel.visible:
			hud_drive_card.hide()
			hud_prompt_card.hide())
	venue_label = Label.new()
	venue_label.add_theme_font_size_override("font_size", 20)
	venue_label.add_theme_color_override("font_color", Color("eadcc9"))
	venue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var dialogue_layout := VBoxContainer.new()
	dialogue_layout.add_theme_constant_override("separation", 7)
	venue_panel.add_child(dialogue_layout)
	_wardrobe_controls=HBoxContainer.new()
	_wardrobe_controls.name="FittingCategories"
	_wardrobe_controls.hide()
	dialogue_layout.add_child(_wardrobe_controls)
	var previous_category:=Button.new()
	previous_category.text="H / LB  ‹"
	previous_category.pressed.connect(func()->void: _cycle_wardrobe_category(-1))
	_wardrobe_controls.add_child(previous_category)
	_wardrobe_category_label=Label.new()
	_wardrobe_category_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_wardrobe_category_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_wardrobe_controls.add_child(_wardrobe_category_label)
	var next_category:=Button.new()
	next_category.text="›  F / RB"
	next_category.pressed.connect(func()->void: _cycle_wardrobe_category(1))
	_wardrobe_controls.add_child(next_category)
	_wardrobe_compare_button=Button.new()
	_wardrobe_compare_button.pressed.connect(_toggle_fitting_compare)
	_wardrobe_controls.add_child(_wardrobe_compare_button)
	dialogue_layout.add_child(venue_label)
	contact_caption = DialogueCaption.new()
	contact_caption.name = "ContactCaption"
	dialogue_layout.add_child(contact_caption)
	var action_row := HFlowContainer.new()
	action_row.add_theme_constant_override("h_separation", 7)
	action_row.add_theme_constant_override("v_separation", 7)
	dialogue_layout.add_child(action_row)
	venue_service_button = Button.new()
	venue_service_button.name = "ServiceAction"
	venue_service_button.text = "1 / A  •  SERVICE"
	venue_service_button.focus_mode = Control.FOCUS_ALL
	venue_service_button.pressed.connect(func() -> void: _venue_action(1))
	action_row.add_child(venue_service_button)
	venue_job_button = Button.new()
	venue_job_button.name = "JobAction"
	venue_job_button.text = "2 / X  •  CONTRACT"
	venue_job_button.focus_mode = Control.FOCUS_ALL
	venue_job_button.pressed.connect(func() -> void: _venue_action(2))
	action_row.add_child(venue_job_button)
	venue_talk_button = Button.new()
	venue_talk_button.name = "TalkToMara"
	venue_talk_button.text = "3 / Y  •  TALK"
	venue_talk_button.focus_mode = Control.FOCUS_ALL
	venue_talk_button.visible = false
	venue_talk_button.pressed.connect(func() -> void: _venue_action(3))
	action_row.add_child(venue_talk_button)
	venue_close_button = Button.new()
	venue_close_button.name = "CloseDialogue"
	venue_close_button.text = "G / B  •  BACK"
	venue_close_button.focus_mode = Control.FOCUS_ALL
	venue_close_button.pressed.connect(func() -> void: _close_venue())
	action_row.add_child(venue_close_button)
	ambient_caption = DialogueCaption.new()
	ambient_caption.name = "AmbientCaption"
	ambient_caption.anchor_left = 0.5
	ambient_caption.anchor_right = 0.5
	ambient_caption.anchor_top = 1.0
	ambient_caption.anchor_bottom = 1.0
	ambient_caption.offset_left = -420.0
	ambient_caption.offset_right = 420.0
	ambient_caption.offset_top = -300.0
	ambient_caption.offset_bottom = -205.0
	ambient_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(ambient_caption)
	var equipment_layer := CanvasLayer.new()
	equipment_layer.name = "EquipmentOverlay"
	equipment_layer.layer = 9
	add_child(equipment_layer)
	equipment_wheel = EquipmentWheel.new()
	equipment_wheel.name = "EquipmentWheel"
	equipment_layer.add_child(equipment_wheel)
	equipment_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	equipment_wheel.connect("confirmed", _finish_equipment_wheel)
	equipment_wheel.connect("cancelled", func() -> void: _finish_equipment_wheel(""))

func _hud_text(parent: Node, node_name: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label

func _show_dialogue_caption(_line_id: String, caption: String) -> void:
	if is_instance_valid(_dialogue_card):
		_dialogue_caption.text = caption
		_dialogue_card.visible = not caption.is_empty()

func _hud_card(layer: CanvasLayer, node_name: String, ax: float, ay: float, bounds: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.anchor_left = ax
	panel.anchor_right = ax
	panel.anchor_top = ay
	panel.anchor_bottom = ay
	panel.offset_left = bounds.x
	panel.offset_top = bounds.y
	panel.offset_right = bounds.z
	panel.offset_bottom = bounds.w
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Ui.card(0.86, 10))
	layer.add_child(panel)
	return panel

func _update_hud() -> void:
	var outdoors: Vector3 = interiors.get("exterior_position") if interiors.call("is_inside") else _actor().global_position
	var district: String = city_details.call("get_district_at", outdoors)
	var landmark: String = city_details.call("get_nearby_landmark", outdoors)
	var local_name := district if landmark.is_empty() else "%s / %s" % [district, landmark]
	var clock: String = day_night.call("clock_string")
	var vehicle_text := "ON FOOT"
	hud_drive_card.visible = current_car != null and not venue_panel.visible
	if current_car != null:
		vehicle_text = "DRIVING"
		hud_drive_name.text = "VEHICLE" if current_car.get("model_id") == "" else str(current_car.call("display_name")).to_upper()
		hud_drive_speed.text = "%d km/h" % maxi(0, roundi(absf(float(current_car.call("speed_kph")))))
		var now_playing := str(nightgrid_fm.call("get_now_playing")) if is_instance_valid(nightgrid_fm) else ""
		hud_drive_radio.text = now_playing
		hud_drive_radio.visible = not now_playing.is_empty()
		_weapon_card.hide()
	elif current_transit != null:
		vehicle_text = {"TRAIN": "M-LINE RIDER", "BUS": "CITY LOOP RIDER", "LIFT": "STATION LIFT"}[transit_kind]
	var tier: int = Wanted.stars(heat)
	var wanted_text := "★".repeat(tier) + "☆".repeat(5 - tier)
	_wanted_label.text = "%s  •  %s" % [wanted.status_text(heat), "%d RESPONSE UNIT%s" % [officers.size(), "" if officers.size() == 1 else "S"]]
	if tier > 0:
		_wanted_label.text = wanted_text + "  " + _wanted_label.text + "\n" + dispatch.status()
	_wanted_label.visible = tier > 0 or weapons.equipped != "holstered"
	_wanted_label.add_theme_color_override("font_color", Ui.DANGER if wanted.police_seen and tier > 0 else Ui.AMBER)
	var active_order := courier_mission.objective()
	var mission: String = active_order["hud"]
	var distance := roundi(outdoors.distance_to(mission_position))
	var message := notification if notification_time > 0.0 else ""
	if performance_overlay:
		var fps := maxi(Engine.get_frames_per_second(), 1)
		var stream: Dictionary = city_details.call("get_streaming_stats")
		var indoor_count := 1 if interiors.call("is_inside") else 0
		var metrics: Dictionary = frame_time_recorder.get_frame_metrics()
		var capture_status := "REC %d" % frame_time_recorder.captured_frames() if frame_time_recorder.recording else "F8 RECORD"
		performance_label.text = "RTX 3060 target 1080p/60 | %d FPS | %.1f ms avg | p95 %.1f | p99 %.1f | 1%% low %.0f FPS | >33ms %d" % [
			fps, float(metrics["avg_ms"]), float(metrics["p95_ms"]), float(metrics["p99_ms"]),
			float(metrics["low_1pct_fps"]), int(metrics["hitches"])]
		performance_label.text += "\n%d/%d blocks | %d shells | room %d | queue %d | last build %.1f ms | peak %.1f ms | %s" % [
			int(stream["loaded_blocks"]), int(stream["total_blocks"]), int(stream["loaded_buildings"]), indoor_count,
			int(stream.get("pending_blocks", 0)), float(stream.get("last_build_usec", 0)) / 1000.0,
			float(stream.get("peak_build_usec", 0)) / 1000.0, capture_status]
	hud_location.text = "%s   /   %s" % [local_name, clock]
	hud_label.text = "$%d  ·  %s\nHealth %d  ·  Stamina %d" % [cash, vehicle_text, ceili(health), ceili(float(player.get("stamina")))]
	hud_health.value = health
	hud_stamina.value = float(player.get("stamina"))
	if show_hud_inventory:
		hud_label.text += "\n%d deliveries  ·  %d supplies  ·  %d snacks" % [deliveries, ration_packs, Consumables.count(consumable_inventory)]
	hud_objective.text = ("%s  /  %dm" % [mission, distance]) if courier_mission.mission_active() else "QUOTADROP / OFF DUTY"
	if courier_mission.gig_economy and courier_mission.mission_active() and current_car == null and current_transit == null and not interiors.call("is_inside") and player.global_position.distance_to(mission_position) < CourierMission.RADIUS:
		hud_objective.text += "  /  " + ("X" if gamepad_active else "G") + (" HAND OFF" if carrying else " COLLECT ORDER")
	hud_objective.add_theme_color_override("font_color", Ui.ACCENT if carrying else Ui.AMBER)
	hud_navigation.visible = navigation_waypoint != null
	hud_navigation.text = navigation_text() if navigation_waypoint != null else ""
	var jobs: Array[String] = []
	if _driving_trial.active and current_car!=null:
		jobs.append(_driving_trial.status(Vector2(current_car.global_position.x,current_car.global_position.z)))
	if courier_mission.gig_economy and not progression.owns_home():
		jobs.append("POD DEPOSIT / $%d of $%d" % [mini(cash,StarterHome.move_in_price()),StarterHome.move_in_price()])
	if story_mission.status != "complete":
		jobs.append(story_mission.journal())
	if _taxi.active:
		jobs.append("TAXI / %s • %ds • $%d"%[_taxi.route["name"],ceili(TaxiJob.LIMIT-_taxi.elapsed),_taxi.route["reward"]])
	if _freight.active:
		jobs.append("FREIGHT / %s • $%d"%[_freight.route["name"],_freight.route["reward"]])
	if not venue_job_active.is_empty():
		jobs.append(_venue_job_text())
	if not civic_job_active.is_empty():
		jobs.append(_civic_job_text())
	var investigation_note: String = investigation.journal(progression)
	if not investigation_note.is_empty():
		jobs.append(investigation_note)
	if progression.cal_quest in [1,2]:
		jobs.append(_cal_objective())
	if progression.street_cred()>0:
		jobs.append(progression.street_cred_summary())
	hud_jobs.text = "\n".join(jobs)
	hud_jobs.visible = not jobs.is_empty()
	hud_notice.text = message
	hud_notice_card.visible = not message.is_empty()
	var prompts: Array[String] = []
	var interact_key := "X" if gamepad_active else "G"
	var enter_key := "LB" if gamepad_active else "H"
	var utility := "Start Pause  •  View Map" if gamepad_active else "Esc Pause  •  M Map  •  Tab Journal"
	var repair := _repair_storefront()
	if current_car != null:
		prompts.append(("RT/LT Drive  •  B Brake  •  Y Exit" if gamepad_active else "W/S Drive  •  Space Brake  •  E Exit") if show_control_hints else ("Y Exit vehicle" if gamepad_active else "E Exit vehicle"))
		if _taxi_interaction_available() and not _driving_trial.active and not _freight.active:
			var taxi_at:=Vector2(current_car.global_position.x,current_car.global_position.z)
			prompts.append("%s %s"%[interact_key,("Complete fare" if TaxiJob.near(taxi_at,_taxi.route["drop"]) else "Cancel fare") if _taxi.active else "Pick up passenger / stop"])
		elif _freight_interaction_available() and not _driving_trial.active and not _taxi.active:
			var freight_at:=Vector2(current_car.global_position.x,current_car.global_position.z)
			prompts.append("%s %s"%[interact_key,("Unload freight" if FreightJob.near(freight_at,_freight.route["drop"]) else "Cancel freight") if _freight.active else "Load freight / stop"])
		if _driving_trial.active:
			prompts.append("%s Abandon circuit"%interact_key)
		elif not _taxi.active and not _freight.active and DrivingTrial.near_start(Vector2(current_car.global_position.x,current_car.global_position.z)):
			prompts.append("%s %s / stop to start"%[interact_key,DrivingTrial.name_for(DrivingTrial.course_at(Vector2(current_car.global_position.x,current_car.global_position.z)))])
		if is_instance_valid(nightgrid_fm) and show_control_hints:
			prompts.append("D-pad → Radio  •  ↑ Next" if gamepad_active else "B Radio  •  N Next")
	elif current_transit != null:
		prompts.append("RB Leave at next stop" if gamepad_active else "F Leave at next stop")
	elif _parking_guard_near():
		prompts.append("%s  Talk to Marcus Vale  •  Synaxis security" % interact_key)
	elif repair != null and repair.door_reachable(player.global_position):
		prompts.append("%s %s door  •  NIGHT SHIFT REPAIRS" % [enter_key, "Close" if repair.door.is_requested_open() else "Open"])
		if repair.door.movement_blocked:
			prompts.append("Step clear of the door swing")
	elif repair != null and repair.contains(player.global_position):
		prompts.append("%s Service counter" % interact_key if repair.counter_reachable(player.global_position) else "NIGHT SHIFT REPAIRS")
	elif interiors.call("is_inside"):
		var site_id := str(interiors.call("active_site_id"))
		var room_site: Dictionary = civic_services.call("site_by_id", site_id) if str(interiors.call("active_site_group")) == "CIVIC" else venue_system.call("venue_by_id", site_id)
		prompts.append("%s  •  %s" % [str(room_site.get("name", site_id)), enter_key + " Exit" if interiors.call("exit_reachable", player.global_position) else "Return to front door"])
		if site_id == "insert_coin":
			var cabinet_id := str(interiors.call("arcade_cabinet_near", player.global_position))
			if not cabinet_id.is_empty():
				prompts.append("%s  Play %s (free)" % [interact_key, cabinet_id.replace("_", " ").capitalize()])
			elif interiors.call("arcade_circuit_near",player.global_position):
				prompts.append("%s  Rook's circuit (%d/8)" % [interact_key,ArcadeScores.circuit_count(_arcade_best)])
			else:
				var exhibit: Dictionary = interiors.call("arcade_exhibit_near",player.global_position)
				var regular: Dictionary = interiors.call("arcade_regular_near",player.global_position)
				if not exhibit.is_empty():
					prompts.append("%s  Inspect %s" % [interact_key,exhibit["title"]])
				elif not regular.is_empty():
					prompts.append("%s  Chat with %s" % [interact_key,regular["name"]])
				elif interiors.call("counter_reachable", player.global_position):
					prompts.append("%s  Talk to Rook" % interact_key)
		elif interiors.call("counter_reachable", player.global_position):
			prompts.append("%s  Service counter" % interact_key)
		if site_id == "lantern_cup":
			var local_regular: Dictionary = interiors.call("patron_near", player.global_position)
			if not local_regular.is_empty():
				prompts.append("%s  Chat with %s" % [interact_key, str(local_regular["name"])])
	else:
		var trail_stop:int=city_details.call("horizon_trail_stop",player.global_position)
		if trail_stop>=0:
			prompts.append("%s Read garden trail / %s"%[interact_key,HorizonTrail.STOPS[trail_stop]["name"]])
		var garage: Node3D = city_details.call("starter_garage",player.global_position)
		if is_instance_valid(garage) and garage.call("desk_reachable",player.global_position):
			prompts.append("%s  LANTERN GARAGE / RECOVERY" % interact_key)
		var near: Dictionary = venue_system.call("nearest_venue", player.global_position)
		if not near.is_empty():
			var accessible := "OPEN" if venue_system.call("is_open", str(near["id"])) else "CLOSED"
			prompts.append("%s  %s (%s)   •   %s Enter" % [interact_key, str(near["name"]), accessible, enter_key])
		var nearby_service: Dictionary = civic_services.call("nearest_site", player.global_position)
		if not nearby_service.is_empty():
			var availability := "OPEN" if civic_services.call("is_open", str(nearby_service["id"])) else "CLOSED"
			prompts.append("%s  %s (%s)   •   %s Enter" % [interact_key, str(nearby_service["name"]), availability, enter_key])
		var physical_lot: Node3D = city_details.call("nearby_walk_in",player.global_position)
		if physical_lot != null and not str(physical_lot.get("home_id")).is_empty():
			var home_action := str(physical_lot.call("home_action",player.global_position))
			var at_checkin := not progression.owns_home() and bool(physical_lot.call("doorway_reachable", player.global_position)) and not bool(physical_lot.call("contains", player.global_position))
			if at_checkin or (progression.owns_home() and home_action == "save"):
				var save_info := save_availability()
				prompts.append(interact_key + "  Save progress / " + ("Free hotel check-in" if at_checkin else "Capsule desk") if bool(save_info["allowed"]) else str(save_info["reason"]))
			else:
				prompts.append("HOME / " + (interact_key + " " + home_action.capitalize() if progression.owns_home() and not home_action.is_empty() else ("Unit 01" if progression.owns_home() else "Locked — tenancy payment required")))
		if physical_lot != null and physical_lot.call("clothing_reachable",player.global_position):
			prompts.append("%s Browse %s clothing" % [interact_key,ClothingStore.STORES[physical_lot.get("clothing_store_id")]["name"]])
		if physical_lot != null and physical_lot.call("service_reachable",player.global_position):
			prompts.append("%s Order at HELIX ESPRESSO" % interact_key)
		if physical_lot != null and physical_lot.call("doorway_reachable",player.global_position):
			var leaf: AnimatableBody3D = physical_lot.get("door")
			prompts.append("%s %s building door" % [enter_key,"Close" if leaf.call("is_requested_open") else "Open"])
		if is_instance_valid(city_details.call("nearby_vending",player.global_position)):
			prompts.append("%s  Vending machine" % interact_key)
		if _cal_pickup_reachable():
			prompts.append("%s  Collect Cal\u0027s prepaid gift" % interact_key)
		if prompts.is_empty() and is_instance_valid(pedestrians) and weapons.equipped=="holstered":
			var contact:Dictionary=pedestrians.call("nearby_contact")
			if not contact.is_empty():
				prompts.append("%s  Talk to %s" % [interact_key,str(contact["name"])])
		if not show_control_hints:
			if _nearby_drivable_car() != null:
				prompts.append("Y Enter vehicle" if gamepad_active else "E Enter vehicle")
			if rail.call("lift_at", player.global_position) != null or bool(rail.call("boardable_from", player.global_position)) or traffic.call("get_boardable_bus", player.global_position) != null:
				prompts.append("RB Board transit" if gamepad_active else "F Board transit")
		if prompts.is_empty() and show_control_hints:
			prompts.append("Y Vehicle  •  RB Transit  •  X Interact" if gamepad_active else "E Vehicle  •  F Transit  •  G Interact")
	if _can_use_weapon() and (show_control_hints or weapons.equipped != "holstered"):
		prompts.append("D-pad ← Cycle • R3 Equipment" if gamepad_active else "Q Cycle • C Equipment")
	if show_control_hints:
		prompts.append(utility)
	hud_prompt.text = "\n".join(prompts)
	hud_prompt_card.visible = not venue_panel.visible and not prompts.is_empty()
	# Reflow upward for long contextual text without covering the bottom inset.
	hud_prompt_card.offset_top = -24.0 - maxf(40.0, hud_prompt_card.get_combined_minimum_size().y)
	hud_prompt_card.offset_bottom = -24.0
	if venue_panel.visible:
		_update_venue_panel()
	if is_instance_valid(ambient_caption) and ambient_caption.visible:
		# Keep the subtitle above the actual contextual action stack, even if
		# a future HUD layout changes its height or hides its prompts.
		var bottom := minf(-150.0, hud_prompt_card.offset_top - 12.0) if hud_prompt_card.visible else -150.0
		ambient_caption.offset_bottom = bottom
		ambient_caption.offset_top = bottom - maxf(90.0, ambient_caption.get_combined_minimum_size().y)

func _venue_job_target() -> Vector3:
	if venue_job_active.is_empty():
		return Vector3.ZERO
	var job: Dictionary = venue_system.call("job_by_id", venue_job_active)
	if job.is_empty():
		return Vector3.ZERO
	return venue_system.call("venue_position", str(job["to"]))

func set_navigation_waypoint(point: Vector2, snap_to_pin: bool = true) -> Vector2:
	if not point.is_finite():
		return Vector2.ZERO if navigation_waypoint == null else navigation_waypoint
	_cal_tracking=false
	_vehicle_job_waypoint_owner = ""
	point = Nav.clamp_point(point)
	# Authored road stops must not snap to a nearby sidewalk or entrance.
	if not snap_to_pin:
		navigation_waypoint = point
		_route_cache.clear()
		_route_revision = -1
		return point
	# Prefer exact, persistent interaction positions when clicking near pins.
	var selected := point
	var distance := Nav.SNAP_RADIUS
	var candidates: Array[Vector2] = []
	for pin in venue_system.call("get_map_pins"):
		var p: Vector3 = venue_system.call("venue_position", str(pin["id"]))
		candidates.append(Vector2(p.x, p.z))
	for pin in civic_services.call("get_map_pins"):
		var p: Vector3 = civic_services.call("position_for", str(pin["id"]))
		candidates.append(Vector2(p.x, p.z))
	var hotel_entry := StarterHome.entry()
	candidates.append(Vector2(hotel_entry.x, hotel_entry.z))
	if progression.owns_home():
		var garage_entry := StarterGarage.entry()
		candidates.append(Vector2(garage_entry.x, garage_entry.z))
	for candidate in candidates:
		var gap := point.distance_to(candidate)
		if gap <= distance and Nav.valid(candidate):
			selected = candidate
			distance = gap
	navigation_waypoint = selected
	_route_cache.clear()
	_route_revision = -1
	return selected

func clear_navigation_waypoint() -> void:
	_vehicle_job_waypoint_owner = ""
	_cal_tracking=false
	navigation_waypoint = null
	_route_cache.clear()
	_route_revision = -1

func _open_equipment_wheel() -> bool:
	if not _can_use_weapon() or not is_instance_valid(equipment_wheel) or equipment_wheel.visible:
		return false
	weapon_aiming = false
	player.set("weapon_aiming", false)
	_fire_held = true
	_reticle.hide()
	_weapon_card.hide()
	equipment_wheel.call("present", weapons.snapshot(), gamepad_active)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true

func _finish_equipment_wheel(id: String) -> void:
	if not is_instance_valid(equipment_wheel) or not equipment_wheel.visible:
		return
	equipment_wheel.call("dismiss")
	get_tree().paused = false
	if game_menu != null and game_menu.call("is_open"):
		get_tree().paused = true
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_fire_held = true
	if _can_use_weapon() and not id.is_empty():
		weapons.equip(id)
	_update_weapon_hud()

func suspend_weapon() -> void:
	if is_instance_valid(equipment_wheel) and equipment_wheel.visible:
		equipment_wheel.call("dismiss")
	weapons.holster()
	weapon_aiming = false
	_fire_held = true
	if is_instance_valid(player):
		player.set("weapon_aiming", false)
		var rig := player.get_node_or_null("Visual")
		if is_instance_valid(rig):
			rig.call("set_weapon_pose", "holstered", false)
	if is_instance_valid(_weapon_card):
		_weapon_card.hide()
		_reticle.hide()

func _can_use_weapon() -> bool:
	return is_instance_valid(player) and is_instance_valid(venue_panel) and not venue_panel.visible and current_car == null and current_transit == null and not interiors.call("is_inside") and not get_tree().paused and (game_menu == null or not game_menu.call("is_open"))

func _play_weapon_sound(kind: String) -> void:
	player.call("play_visual_action", &"reload" if kind == "RELOAD" else &"fire")
	if is_instance_valid(_weapon_audio):
		_weapon_audio.stream = CombatFoley.sound(kind)
		_weapon_audio.play()

func _update_combat(delta: float) -> void:
	_hit_feedback = maxf(0.0, _hit_feedback - delta)
	var permitted := _can_use_weapon()
	var fire := Input.is_action_pressed("weapon_fire")
	if not permitted:
		weapons.holster()
		_fire_held = true
	else:
		weapons.tick(delta)
	weapon_aiming = permitted and weapons.equipped != "holstered" and Input.is_action_pressed("weapon_aim")
	player.set("weapon_aiming", weapon_aiming)
	var rig := player.get_node_or_null("Visual")
	if is_instance_valid(rig):
		rig.call("set_weapon_pose", weapons.equipped, weapon_aiming)
	# Fire is edge-triggered; held RT when exiting a car/dialogue cannot
	# accidentally discharge. Camera updates in the same fixed tick.
	if permitted and weapon_aiming and fire and not _fire_held:
		_update_camera(0.0, true)
		_fire_weapon()
	_fire_held = fire or not permitted
	_update_weapon_hud()

func _update_weapon_hud() -> void:
	if not is_instance_valid(_weapon_card):
		return
	_weapon_card.visible = _can_use_weapon() and weapons.equipped != "holstered"
	if _weapon_card.visible:
		var help := "LT aim • RT fire • ↑ reload" if gamepad_active else "RMB aim • LMB fire • Z reload"
		_weapon_label.text = weapons.status_text() + "\n" + help
	_reticle.visible = weapon_aiming and _can_use_weapon()
	_reticle.set("impact", _hit_feedback > 0.0)
	if _reticle.visible:
		_reticle.queue_redraw()

func _fire_weapon() -> bool:
	if not _can_use_weapon() or not weapon_aiming or not weapons.discharge():
		return false
	var spec: Dictionary = weapons.spec()
	_play_weapon_sound("PULSE" if weapons.equipped == "pulse" else "ARC")
	# Game-only arcade hitscan: first find the screen-center target, then
	# check the player-to-target segment so walls block camera-peeking.
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var view_start := camera.project_ray_origin(screen_center)
	var view_end := view_start + camera.project_ray_normal(screen_center) * float(spec["reach"])
	var ignore: Array[RID] = [player.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(view_start, view_end, 1, ignore)
	var space := get_world_3d().direct_space_state
	var camera_hit := space.intersect_ray(query)
	var target: Vector3 = camera_hit.get("position", view_end)
	var origin := player.global_position + Vector3.UP * 0.55
	if is_instance_valid(pedestrians):
		pedestrians.call("react_to_incident", origin, 22.0, ignore, true)
	var direction := origin.direction_to(target)
	var endpoint := origin + direction * minf(origin.distance_to(target) + 0.05, float(spec["reach"]))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, endpoint, 1, ignore))
	var shot_sight := _witness_at(origin)
	var hit_police := false
	if not hit.is_empty():
		var body: Object = hit["collider"]
		if is_instance_valid(body) and body.has_method("take_arcade_damage"):
			body.call("take_arcade_damage", float(spec["damage"]))
			_hit_feedback = 0.22
			hit_police = body in officers or body in routine_patrols
			if hit_police and float(body.get("condition")) <= 18.0:
				_notify("PATROL DISABLED • police heat remains")
	if hit_police or bool(shot_sight["any"]):
		_report_incident("SHOT", origin, hit_police or bool(shot_sight["police"]))
	_log_playtest("weapon_discharge", {"equipment": weapons.equipped, "vehicle_hit": _hit_feedback > 0.0})
	return true

func _navigation_origin() -> Vector2:
	var pos: Vector3 = interiors.get("exterior_position") if interiors.call("is_inside") else _actor().global_position
	return Vector2(pos.x, pos.z)

func _navigation_route(origin: Vector2) -> Dictionary:
	if navigation_waypoint == null:
		return {}
	var target: Vector2 = navigation_waypoint
	# At most one small graph calculation per meaningful movement; the map
	# and HUD share it. This remains independent of render/physics cadence.
	if _route_revision != road_restrictions.revision or _route_target != target or _route_origin.distance_to(origin) >= 1.0:
		_route_origin = origin
		_route_target = target
		_route_revision = road_restrictions.revision
		_route_cache = road_restrictions.plan(origin, target)
	return _route_cache

func navigation_text() -> String:
	if navigation_waypoint == null:
		return "No custom waypoint"
	var destination: Vector2 = navigation_waypoint
	var origin := _navigation_origin()
	var label := city_details.call("get_district_at", Vector3(destination.x, 0.0, destination.y)) as String
	for pin in venue_system.call("get_map_pins"):
		var p: Vector3 = venue_system.call("venue_position", str(pin["id"]))
		if destination.distance_to(Vector2(p.x, p.z)) < 0.1:
			label = str(venue_system.call("venue_by_id", str(pin["id"]))["name"])
			break
	for pin in civic_services.call("get_map_pins"):
		var p: Vector3 = civic_services.call("position_for", str(pin["id"]))
		if destination.distance_to(Vector2(p.x, p.z)) < 0.1:
			label = str(civic_services.call("site_by_id", str(pin["id"]))["name"])
			break
	var home := StarterHome.entry()
	if destination.distance_to(Vector2(home.x,home.z)) < .1:
		label = StarterHome.NAME if progression.owns_home() else "LANTERN COURT / FREE CHECK-IN"
	elif progression.owns_home():
		var garage := StarterGarage.entry()
		if destination.distance_to(Vector2(garage.x,garage.z)) < .1:
			label = StarterGarage.NAME
	var route := _navigation_route(origin)
	var line := "WAYPOINT  %s  •  %dm direct" % [label, roundi(origin.distance_to(destination))]
	if route.is_empty():
		return line + "\nStreet route unavailable" if not road_restrictions.catalog().is_empty() else line
	if interiors.call("is_inside"):
		return line + "\nExit building to follow street route"
	if current_transit != null:
		return line + "\nLeave transit at a stop to follow street route"
	return line + "\n%d m by street  |  %s" % [roundi(float(route["road_m"])), StreetRoute.guidance(route, origin, destination)]

func get_map_state() -> Dictionary:
	var car_positions: Array[Vector2] = []
	var patrol_positions: Array[Vector2] = []
	for patrol in routine_patrols:
		if is_instance_valid(patrol):
			patrol_positions.append(Vector2(patrol.global_position.x, patrol.global_position.z))
	for officer in officers:
		if is_instance_valid(officer):
			car_positions.append(Vector2(officer.global_position.x, officer.global_position.z))
	var actor := _actor()
	var map_actor: Vector3 = interiors.get("exterior_position") if interiors.call("is_inside") else actor.global_position
	var quest: Vector3 = _venue_job_target()
	var heading: Vector3 = -actor.global_basis.z
	if actor == player:
		var visual: Node3D = player.get("visual")
		if is_instance_valid(visual):
			heading = visual.global_basis.z
	return {
		"player": Vector2(map_actor.x, map_actor.z),
		"player_heading": Vector2(heading.x, heading.z),
		"mission": Vector2(mission_position.x, mission_position.z), "mission_active":courier_mission.mission_active(),
		"waypoint_active": navigation_waypoint != null,
		"waypoint": Vector2.ZERO if navigation_waypoint == null else navigation_waypoint,
		"street_route": _navigation_route(Vector2(map_actor.x, map_actor.z)),
		"road_restrictions": road_restrictions.catalog(),
		"officers": car_positions,
		"routine_patrols": patrol_positions,
		"police_stations": dispatch.catalog(),
		"wanted_stars": Wanted.stars(heat),
		"wanted_seen": wanted.police_seen,
		"wanted_last_known": Vector2(wanted.last_known.x, wanted.last_known.z) if wanted.last_known.is_finite() else Vector2.INF,
		"carrying": carrying,
		"side_quest": Vector2(quest.x, quest.z),
		"side_quest_active": not venue_job_active.is_empty(),
		"venues": venue_system.call("get_map_pins"),
		"services": civic_services.call("get_map_pins"),
		"bus_stops": traffic.call("get_map_stops"),
		"rail_stations": rail.call("get_map_stations"),
		"indoors": interiors.call("is_inside"),
		"civic_quest_active": not civic_job_active.is_empty(),
		"civic_quest": Vector2(_civic_job_target().x, _civic_job_target().z)
	}

func _synaxis_contact_objective() -> String:
	if not progression.has_receipt(Opening.RECEIPT) or progression.synaxis_contact==0:
		return ""
	if progression.synaxis_contact==1:
		return "A FAMILIAR FACE / Optional: check in with Marcus Vale at the rear Synaxis parking booth."
	return "CONTACT / Marcus Vale — checked in. Rear Synaxis parking booth."

func _cancel_street_interactions()->void:
	if is_instance_valid(dialogue_director):
		dialogue_director.call("cancel_scope",StreetSatire.STANKY_SCOPE)
	_music_session_site=""
	_street_contact_id=""
	_cal_pending={}
	if is_instance_valid(pedestrians) and is_instance_valid(dialogue_director):
		pedestrians.call("cancel_street_dialogue",dialogue_director)

## Anniversaries are optional; the ledger is the sole reward/state owner.
func _cal_pickup_reachable()->bool:
	if progression.cal_quest!=1 or not is_instance_valid(venue_system) or not is_instance_valid(player) or current_car!=null or current_transit!=null or interiors.call("is_inside") or weapons.equipped!="holstered":
		return false
	var at:Vector3=venue_system.call("venue_position",CAL_PICKUP)
	return player.global_position.distance_to(at)<=3.0

func _cal_target()->Vector3:
	if progression.cal_quest==1 and is_instance_valid(venue_system):
		return venue_system.call("venue_position",CAL_PICKUP)
	if progression.cal_quest==2 and is_instance_valid(pedestrians):
		return pedestrians.call("cal_position")
	return Vector3.INF

func _cal_objective()->String:
	match progression.cal_quest:
		1: return "COMPATIBILITY PATCH / Collect prepaid gift at Moon Noodles"
		2:
			if not is_instance_valid(pedestrians):
				return "COMPATIBILITY PATCH / Living Streets unavailable; relaunch with --living-streets"
			if not pedestrians.call("cal_is_live"):
				return "COMPATIBILITY PATCH / Cal's neighborhood; approach from 35–95m with the sidewalk out of view"
			return "COMPATIBILITY PATCH / Return heat sink to Cal Mercer"
		3: return "COMPATIBILITY PATCH / Completed"
	return ""

func _resolve_cal_action(allowed:bool)->void:
	if _cal_pending.is_empty():
		return
	var pending:=_cal_pending
	_cal_pending={}
	var id:=str(pending["id"])
	var listener:Vector3=player.global_position+Vector3.UP*1.6
	if not allowed or not progression.has_receipt(Opening.RECEIPT) or not pedestrians.call("confirm_cal_contact",id,listener,player.get_rid()):
		_notify("Cal is no longer within reach. Approach him again.")
		return
	var action:="accept" if pending["action"]=="cal_accept" else "complete"
	var before_cred:=progression.street_cred()
	var changed:=progression.accept_cal_quest() if action=="accept" else progression.complete_cal_quest()
	if not changed:
		_notify("Unable to advance Compatibility Patch.")
		return
	var cue:=StreetSatire.cal_quest_line(action)
	var reward_notice:="COMPATIBILITY PATCH / Accepted" if action=="accept" else "COMPATIBILITY PATCH / Completed +$85 • +%d STREET CRED"%(progression.street_cred()-before_cred)
	if not is_instance_valid(dialogue_director) or not pedestrians.call("play_cal_quest_line",dialogue_director,id,action,listener,player.get_rid()):
		_notify(reward_notice+" / "+str(cue["text"]))
	else:
		_notify(reward_notice)
	if action=="accept":
		_track_cal_waypoint()
	elif _cal_tracking:
		clear_navigation_waypoint()

## Quest-owned waypoints bypass venue snapping; manual map pins keep priority.
func _track_cal_waypoint()->void:
	var point:=_cal_target()
	if not point.is_finite():
		return
	_cal_tracking=true
	_cal_nav_clock=0.0
	_update_cal_navigation(0.0)

func _update_cal_navigation(delta:float)->void:
	if not _cal_tracking:
		return
	if progression.cal_quest not in [1,2]:
		clear_navigation_waypoint()
		return
	_cal_nav_clock-=delta
	if _cal_nav_clock>0.0:
		return
	_cal_nav_clock=1.0
	var point:=_cal_target()
	if not point.is_finite():
		return
	var target:=Nav.clamp_point(Vector2(point.x,point.z))
	if navigation_waypoint==null or target.distance_to(navigation_waypoint)>=4.0:
		navigation_waypoint=target
		_route_cache.clear()
		_route_revision=-1

func _music_contact_status()->String:
	if progression.has_receipt("venue:soundcheck_pass"):
		return "UNDERGROUND / Rae at Blue Hour: Opening sets available • %d completed\n"%progression.street_activity_runs("live_gig")+progression.band_summary()
	if venue_job_active=="soundcheck_pass":
		return "UNDERGROUND / Deliver Nyx's demo to Blue Hour."
	if progression.street_cred()>=100:
		return "UNDERGROUND / Nyx at Static Room has a music favor for you."
	return "UNDERGROUND / Reach 100 Street Cred to meet Nyx."

func _play_music_contact_cue(id:String,beat:String)->void:
	var cue:=StreetSatire.venue_job_line(id,beat)
	if cue.is_empty() or not is_instance_valid(dialogue_director):
		return
	# Existing venue panel does not expose a physical host node; use the
	# bounded nonspatial voice channel rather than inventing a world speaker.
	dialogue_director.call("cancel_scope","venue:music_contact")
	dialogue_director.call("enqueue",str(cue["id"]),str(cue["text"]),DialogueDirector.STORY,null,"venue:music_contact")

func _blue_hour_set_reachable()->bool:
	if not progression.has_receipt("venue:soundcheck_pass") or not is_instance_valid(player) or current_car!=null or current_transit!=null or weapons.equipped!="holstered" or not venue_system.call("is_open","blue_hour"):
		return false
	if interiors.call("is_inside"):
		return str(interiors.call("active_site_id"))=="blue_hour" and bool(interiors.call("counter_reachable",player.global_position))
	var point:Vector3=venue_system.call("venue_position","blue_hour")
	return player.global_position.distance_to(point)<=5.5

func _busking_reachable(site:String)->bool:
	if site not in BUSKING_SITES or not is_instance_valid(player) or current_car!=null or current_transit!=null or interiors.call("is_inside") or weapons.equipped!="holstered" or not venue_system.call("is_open",site):
		return false
	var point:Vector3=venue_system.call("venue_position",site)
	return player.global_position.distance_to(point)<=5.5

func _open_music_desk()->void:
	game_menu.call("open_music_desk",{"owned":progression.owns_instrument(Instruments.STARTER),"owned_set":progression.owned_set_unlocked(),"cash":cash,"summary":progression.instrument_summary(),"band":progression.band_summary(),"recruit_rhea":progression.band_recruit_available("rhea"),"band_rehearse":progression.band_rehearsal_available(),"band_names":ProgressionLedger.BAND_NAMES if progression.can_name_band() else [],"press_tapes":progression.can_press_tapes(),"merch":progression.band_merch_summary()})

func _music_desk_action(action:String)->void:
	if action=="music_desk_leave":
		_music_session_site=""
		return
	if _music_session_site!="desk:copper_cup" or game_menu.get("screen")!="music_desk" or not _busking_reachable("copper_cup"):
		return
	if action.begins_with("music_desk_name:"):
		var index:=action.trim_prefix("music_desk_name:")
		if index.is_valid_int() and progression.choose_band_name(int(index)):
			_notify("BAND / "+progression.band_name)
		_open_music_desk()
		return
	match action:
		"music_desk_press":
			if progression.press_tapes():
				_notify("AFTER THE LAST SHIFT / 12 tapes pressed for $60")
			_open_music_desk()
		"music_desk_rehearse":
			if progression.band_rehearsal_available():
				_music_session_site="band_rehearsal:copper_cup"
				game_menu.call("open_band_rehearsal",progression.band_rehearsals+1)
		"music_desk_recruit":
			if progression.recruit_band_member("rhea"):
				_notify("RHEA VALE / "+str(ProgressionLedger.BAND_MEMBERS["rhea"]["line"]))
			_open_music_desk()
		"music_desk_buy":
			if progression.buy_instrument(Instruments.STARTER):
				_notify("Purchased PocketBeat M3. Your own sampler is ready to practice.")
			_open_music_desk()
		"music_desk_busk":
			_music_session_site="copper_cup"
			game_menu.call("open_busking_set",progression.street_activity_runs("busking")+1)
		"music_desk_owned":
			if progression.owned_set_unlocked():
				_music_session_site="owned:copper_cup"
				game_menu.call("open_owned_sampler_set",progression.street_activity_runs("busking")+1)
		"music_desk_practice":
			if progression.owns_instrument(Instruments.STARTER) and progression.sampler_practice<Instruments.MAX_PRACTICE:
				_music_session_site="practice:copper_cup"
				game_menu.call("open_sampler_practice",progression.sampler_practice+1)

func _sync_band_flyers()->void:
	if is_instance_valid(venue_system):
		venue_system.call("set_band_promotion",progression.band_name,progression.has_receipt(ProgressionLedger.BAND_DEBUT_RECEIPT),progression.band_showcase_available(),progression.has_receipt(ProgressionLedger.BAND_SHOWCASE_RECEIPT),progression.tape_stock+progression.tapes_sold>0)

func _play_stanky_reply(topic:int) -> void:
	if not is_instance_valid(player) or not is_instance_valid(venue_system) or not is_instance_valid(dialogue_director) or current_car!=null or current_transit!=null or interiors.call("is_inside") or weapons.equipped!="holstered":
		return
	var legend:Node3D=venue_system.call("daddy_stanky_near",player.global_position)
	if not is_instance_valid(legend):
		return
	var profile:Dictionary=StreetSatire.stanky_profile()
	var topics:Array=profile["topics"]
	if topic<0 or topic>=topics.size():
		return
	var cue:Dictionary=topics[topic]
	dialogue_director.call("cancel_scope",StreetSatire.STANKY_SCOPE)
	dialogue_director.call("enqueue",str(cue["id"]),"Daddy Stanky: "+str(cue["text"]),DialogueDirector.STORY,legend,StreetSatire.STANKY_SCOPE)
	legend.call("set_attention_target",Vector3.ZERO,false)
