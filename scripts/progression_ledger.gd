extends RefCounted
## Session-owned progression wallet. The existing top-level save cash field
## is the single serialized balance; receipts are independent of city geometry.
const VERSION = 1
const MAX_CASH = 1000000000
const MAX_RECEIPTS = 4096
const MAX_ID_LENGTH = 96
const RoadCars = preload("res://scripts/road_car_catalog.gd")
const StarterHome = preload("res://scripts/starter_home.gd")

var balance: int = 0
var _receipts: Dictionary = {}
var _owned_vehicles: Dictionary = {}
var home_supplies: int = 0

static func valid_cash(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var n := float(value)
	return is_finite(n) and n >= 0.0 and n <= float(MAX_CASH) and floor(n) == n

static func valid_id(value: Variant) -> bool:
	if not value is String:
		return false
	var id: String = value
	if id.is_empty() or id.length() > MAX_ID_LENGTH:
		return false
	for i in range(id.length()):
		var c := id.unicode_at(i)
		if not ((c >= 97 and c <= 122) or (c >= 65 and c <= 90) or (c >= 48 and c <= 57) or c in [45, 46, 58, 95]):
			return false
	return true

func set_balance(amount: int) -> void:
	balance = clampi(amount, 0, MAX_CASH)

func credit(amount: int) -> bool:
	if amount <= 0 or amount > MAX_CASH - balance:
		return false
	balance += amount
	return true

func spend(amount: int) -> bool:
	if amount < 0 or amount > balance:
		return false
	balance -= amount
	return true

func charge_up_to(amount: int) -> void:
	if amount > 0:
		balance -= mini(balance, amount)

func has_receipt(id: String) -> bool:
	return _receipts.has(id)

## Idempotent one-time payout. All checks precede both state changes.
## Repeatable jobs should use a monotonic counter, not an unbounded receipt per run.
func credit_once(id: String, amount: int) -> bool:
	if not valid_id(id) or has_receipt(id) or _receipts.size() >= MAX_RECEIPTS:
		return false
	if not credit(amount):
		return false
	_receipts[id] = true
	return true

func owns_vehicle(id: String) -> bool:
	return _owned_vehicles.has(id)

func owned_vehicle_ids() -> Array:
	var ids: Array = _owned_vehicles.keys()
	ids.sort()
	return ids

## Catalog owns price; caller cannot choose it. Validate before debit.
func buy_vehicle(id: String) -> bool:
	if not RoadCars.TITLES.has(id) or owns_vehicle(id):
		return false
	if not spend(int(RoadCars.TITLES[id]["price"])):
		return false
	_owned_vehicles[id] = true
	return true

## Transfer title only after the catalog-derived credit succeeds.
func sell_vehicle(id: String, condition: float) -> bool:
	if not owns_vehicle(id):
		return false
	var amount := RoadCars.resale_price(id, condition)
	if amount <= 0 or not credit(amount):
		return false
	_owned_vehicles.erase(id)
	return true

func owns_home() -> bool:
	return has_receipt(StarterHome.ACCESS_RECEIPT)

func grant_starter_vehicle() -> bool:
	var id := "street:kestrel_01"
	if not owns_home() or owns_vehicle(id):
		return false
	_owned_vehicles[id] = true
	return true

# Return the number actually transferred; caller updates carried count once.
func deposit_supply(carried: int) -> int:
	if not owns_home() or carried <= 0 or home_supplies >= StarterHome.MAX_STORAGE:
		return 0
	home_supplies += 1
	return 1

func withdraw_supply(carried: int) -> int:
	if not owns_home() or carried >= 99 or carried < 0 or home_supplies <= 0:
		return 0
	home_supplies -= 1
	return 1

func snapshot() -> Dictionary:
	var ids: Array = _receipts.keys()
	ids.sort()
	return {"version": VERSION, "receipts": ids, "owned_vehicles": owned_vehicle_ids(), "home_supplies":home_supplies}

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	var version: Variant = data.get("version")
	if not valid_cash(version) or int(version) != VERSION:
		return false
	var raw: Variant = data.get("receipts")
	if not raw is Array or raw.size() > MAX_RECEIPTS:
		return false
	var seen: Dictionary = {}
	for id in raw:
		if not valid_id(id) or seen.has(id):
			return false
		seen[id] = true
	var stored: Variant = data.get("home_supplies", 0)
	if not valid_cash(stored) or int(stored) > StarterHome.MAX_STORAGE or (int(stored) > 0 and not seen.has(StarterHome.ACCESS_RECEIPT)):
		return false
	var owned: Variant = data.get("owned_vehicles", [])
	if not owned is Array or owned.size() > RoadCars.TITLES.size():
		return false
	seen.clear()
	for id in owned:
		if not valid_id(id) or not RoadCars.TITLES.has(id) or seen.has(id):
			return false
		seen[id] = true
	return true

## Validate first, then replace state as a unit. Empty optional data is only
## used by callers for the pre-ledger format, never for an unknown version.
func restore(amount: Variant, data: Variant) -> bool:
	if not valid_cash(amount) or not valid_snapshot(data):
		return false
	var next: Dictionary = {}
	for id in data["receipts"]:
		next[id] = true
	var titles: Dictionary = {}
	for id in data.get("owned_vehicles", []):
		titles[id] = true
	balance = int(amount)
	_receipts = next
	_owned_vehicles = titles
	home_supplies = int(data.get("home_supplies",0))
	return true
