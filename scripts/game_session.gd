extends Node
## One immutable seed per new game. Save slot contains seed plus mutable player/world state.
## Seeds are deliberately not regenerated on scene reload or loading a save.
const SAVE_VERSION = 1
const SAVE_PATH = "user://saves/afterhours_slot_1.json"
const DEFAULT_SEED = 834726

var world_seed: int = DEFAULT_SEED
var pending_restore: Dictionary = {}

func start_new_game() -> int:
	var old := world_seed
	world_seed = randi_range(1, 2147483646)
	if world_seed == old:
		world_seed = (world_seed % 2147483646) + 1
	pending_restore.clear()
	return world_seed

func make_snapshot(state: Dictionary) -> Dictionary:
	var data := state.duplicate(true)
	data["version"] = SAVE_VERSION
	data["seed"] = world_seed
	return data

func is_valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if int(data.get("version", -1)) != SAVE_VERSION:
		return false
	var seed_value = data.get("seed", 0)
	if not (seed_value is float or seed_value is int):
		return false
	if int(seed_value) <= 0 or int(seed_value) > 2147483646:
		return false
	for key in ["player_position", "cash", "health", "deliveries", "carrying", "hour", "cars", "traffic", "rail"]:
		if not data.has(key):
			return false
	if not data["player_position"] is Array or data["player_position"].size() != 3:
		return false
	if not data["cars"] is Array or not data["traffic"] is Dictionary or not data["rail"] is Dictionary:
		return false
	if not data["carrying"] is bool:
		return false
	return true

func save_snapshot(state: Dictionary) -> bool:
	var snapshot := make_snapshot(state)
	if not is_valid_snapshot(snapshot):
		return false
	var directory := ProjectSettings.globalize_path("user://saves")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot, "  "))
	file.flush()
	return file.get_error() == OK

func read_snapshot() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
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
	pending_restore = decoded
	return true

func take_pending_restore() -> Dictionary:
	var snapshot := pending_restore.duplicate(true)
	pending_restore.clear()
	return snapshot
