extends Node
## One immutable seed per new game. Save slot contains seed plus mutable player/world state.
## Seeds are deliberately not regenerated on scene reload or loading a save.
const SAVE_VERSION = 1
const SAVE_PATH = "user://saves/afterhours_slot_1.json"
const DEFAULT_SEED = 834726
const MAX_SAVE_BYTES = 16 * 1024 * 1024

var world_seed: int = DEFAULT_SEED
var pending_restore: Dictionary = {}
# Transient per-launch flag: reloading a saved/new game should enter the world,
# not force a second title screen after a deliberate menu choice.
var boot_menu_shown := false
var opening_pending := false
var world_manifest: Dictionary = {}
const WorldPlan = preload("res://scripts/world_plan.gd")
const ProgressionLedger = preload("res://scripts/progression_ledger.gd")
const CourierMission = preload("res://scripts/courier_mission.gd")
const StoryMission = preload("res://scripts/story_mission.gd")

func start_new_game() -> int:
	var old := world_seed
	world_seed = randi_range(1, 2147483646)
	if world_seed == old:
		world_seed = (world_seed % 2147483646) + 1
	pending_restore.clear()
	opening_pending = true
	world_manifest.clear()
	return world_seed

func get_world_manifest() -> Dictionary:
	if not WorldPlan.valid_manifest(world_manifest):
		world_manifest = WorldPlan.build_manifest(world_seed)
	return world_manifest.duplicate(true)

func make_snapshot(state: Dictionary) -> Dictionary:
	var data := state.duplicate(true)
	data["version"] = SAVE_VERSION
	data["seed"] = world_seed
	data["world_manifest"] = get_world_manifest()
	return data

func is_valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	var version: Variant = data.get("version")
	if not _whole_number(version, SAVE_VERSION, SAVE_VERSION):
		return false
	var seed_value: Variant = data.get("seed", 0)
	if not _whole_number(seed_value, 1, 2147483646):
		return false
	for key in ["player_position", "cash", "health", "deliveries", "carrying", "hour", "cars", "traffic", "rail"]:
		if not data.has(key):
			return false
	if not _valid_position(data["player_position"]):
		return false
	if not data["cars"] is Array or not data["traffic"] is Dictionary or not data["rail"] is Dictionary:
		return false
	if data["cars"].size() > 12:
		return false
	for car in data["cars"]:
		if not car is Dictionary or not _valid_position(car.get("position")):
			return false
		if not _finite_number(car.get("yaw",0.0)) or not _finite_number(car.get("condition",100.0)):
			return false
	if not _whole_number(data.get("occupied_car",-1), -1, 11):
		return false
	if not _finite_number(data["health"]) or not _finite_number(data["hour"]):
		return false
	if not data["carrying"] is bool or not CourierMission.valid_run_count(data["deliveries"]):
		return false
	if data.has("courier_on_duty") and (not data["courier_on_duty"] is bool or (data["carrying"] and not data["courier_on_duty"])):
		return false
	if data.has("courier_offer_offset") and not _whole_number(data["courier_offer_offset"], 0, CourierMission.GIG_ORDERS.size() - 1):
		return false
	if not ProgressionLedger.valid_cash(data["cash"]):
		return false
	if data.has("progression") and not ProgressionLedger.valid_snapshot(data["progression"]):
		return false
	var paid: Array = data.get("progression", {}).get("receipts", [])
	var case_stage: Variant = data.get("investigation_stage",0)
	if not _whole_number(case_stage,0,4):
		return false
	if (int(case_stage) == 4) != paid.has("investigation:paper_city"):
		return false
	if int(case_stage) > 0 and not (paid.has("technical:crane_interlock") or paid.has("technical:grid_telemetry")):
		return false
	if data.has("story_mission"):
		if not StoryMission.valid_snapshot(data["story_mission"]):
			return false
		if (data["story_mission"]["status"] == "complete") != paid.has(StoryMission.ID):
			return false
	elif paid.has(StoryMission.ID):
		return false
	# Older v1 saves do not contain a manifest; synthesize it once from their seed.
	if data.has("world_manifest") and not WorldPlan.valid_manifest(data["world_manifest"]):
		return false
	if data.has("interior"):
		if not data["interior"] is Dictionary:
			return false
		var room: Dictionary = data["interior"]
		if not room.is_empty():
			if not (str(room.get("group", "")) == "CIVIC" or str(room.get("group", "")) == "VENUE"):
				return false
			if str(room.get("id", "")).is_empty():
				return false
			if not room.get("outside", []) is Array or room["outside"].size() != 3:
				return false
	return true

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _whole_number(value: Variant, low: int, high: int) -> bool:
	return _finite_number(value) and float(value) >= low and float(value) <= high and floor(float(value)) == float(value)

static func _valid_position(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for axis in value:
		if not _finite_number(axis) or absf(float(axis)) > 10000.0:
			return false
	return true

func save_snapshot(state: Dictionary) -> bool:
	return save_snapshot_to(state, SAVE_PATH)

func save_snapshot_to(state: Dictionary, path: String) -> bool:
	var snapshot := make_snapshot(state)
	if not is_valid_snapshot(snapshot):
		return false
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	# Never truncate the existing slot. Write and validate a sibling staging
	# file, close it, then replace by rename on the same filesystem.
	var temporary := path + ".tmp"
	var bytes := JSON.stringify(snapshot, "  ").to_utf8_buffer()
	if bytes.size() > MAX_SAVE_BYTES:
		return false
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var wrote := file.get_error() == OK
	file.close()
	var absolute_temp := ProjectSettings.globalize_path(temporary)
	if not wrote or read_snapshot_from(temporary).is_empty():
		DirAccess.remove_absolute(absolute_temp)
		return false
	var result := DirAccess.rename_absolute(absolute_temp, ProjectSettings.globalize_path(path))
	if result != OK:
		DirAccess.remove_absolute(absolute_temp)
		return false
	return true

func read_snapshot() -> Dictionary:
	return read_snapshot_from(SAVE_PATH)

func read_snapshot_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_SAVE_BYTES:
		return {}
	var decoded = JSON.parse_string(file.get_as_text())
	if not is_valid_snapshot(decoded):
		return {}
	return (decoded as Dictionary).duplicate(true)

func prepare_load() -> bool:
	var decoded := read_snapshot()
	if decoded.is_empty():
		return false
	world_seed = int(decoded["seed"])
	world_manifest = decoded.get("world_manifest", {}).duplicate(true)
	if not WorldPlan.valid_manifest(world_manifest):
		world_manifest = WorldPlan.build_manifest(world_seed)
	pending_restore = decoded
	return true

func take_pending_restore() -> Dictionary:
	var snapshot := pending_restore.duplicate(true)
	pending_restore.clear()
	return snapshot
