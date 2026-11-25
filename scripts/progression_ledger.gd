extends RefCounted
## Session-owned progression wallet. The existing top-level save cash field
## is the single serialized balance; receipts are independent of city geometry.
const VERSION = 1
const MAX_CASH = 1000000000
const MAX_RECEIPTS = 4096
const MAX_ID_LENGTH = 96
const RoadCars = preload("res://scripts/road_car_catalog.gd")
const StarterHome = preload("res://scripts/starter_home.gd")
const Wardrobe = preload("res://scripts/wardrobe_catalog.gd")
const Economy = preload("res://scripts/economy.gd")
var bitcoin_sats: int = 0
const CAL_RECEIPT="street:compatibility_patch"
const CAL_REWARD=85
var cal_quest:int=0 # 0 offered, 1 accepted, 2 collected, 3 completed

var balance: int = 0
var _receipts: Dictionary = {}
var _owned_vehicles: Dictionary = {}
var home_supplies: int = 0
var home_storage_expanded := false
var home_tenancy_paid := false
var outfit_id := Wardrobe.DEFAULT
var _purchased_outfits: Dictionary = {}

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
	if not spend(RoadCars.title_price(id)):
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
	return home_tenancy_paid and has_receipt(StarterHome.ACCESS_RECEIPT)

func activate_home_tenancy() -> bool:
	if not has_receipt(StarterHome.ACCESS_RECEIPT) or home_tenancy_paid:
		return false
	if not spend(StarterHome.move_in_price()):
		return false
	home_tenancy_paid = true
	return true

func grant_starter_vehicle() -> bool:
	# Historical API retained for garage callers; now a paid title.
	return owns_home() and buy_vehicle("street:kestrel_01")

func owns_outfit(id: String) -> bool:
	return Wardrobe.valid_id(id) and (id == Wardrobe.DEFAULT or _purchased_outfits.has(id))

func purchased_outfit_ids() -> Array:
	var ids: Array = _purchased_outfits.keys()
	ids.sort()
	return ids

func exchange_bitcoin(buy: bool) -> bool:
	var gross := Economy.EXCHANGE_USD
	var fee := Economy.EXCHANGE_FEE_USD
	if buy:
		var received := Economy.sats_for_usd(gross-fee)
		if bitcoin_sats > Economy.MAX_SATS-received or not spend(gross):
			return false
		bitcoin_sats += received
	else:
		var paid := Economy.sats_for_usd(gross)
		if bitcoin_sats < paid or not credit(gross-fee):
			return false
		bitcoin_sats -= paid
	return true

func can_pay(usd: int, tender: String) -> bool:
	if usd <= 0:
		return false
	if tender == "USD":
		return balance >= usd
	return tender == "BTC" and bitcoin_sats >= Economy.sats_for_usd(usd)

func buy_outfit(id: String, tender: String = "USD") -> bool:
	if not owns_home() or not Wardrobe.valid_id(id) or owns_outfit(id):
		return false
	var price := Wardrobe.price(id)
	if not can_pay(price,tender):
		return false
	if tender == "BTC":
		bitcoin_sats -= Economy.sats_for_usd(price)
	else:
		balance -= price
	_purchased_outfits[id] = true
	return true

func select_outfit(id: String) -> bool:
	if not owns_home() or not owns_outfit(id):
		return false
	outfit_id = id
	return true

func home_capacity() -> int:
	return StarterHome.EXPANDED_STORAGE if home_storage_expanded else StarterHome.MAX_STORAGE

func expand_home_storage() -> bool:
	if not owns_home() or home_storage_expanded:
		return false
	if not spend(StarterHome.STORAGE_UPGRADE_PRICE):
		return false
	home_storage_expanded = true
	return true

# Return the number actually transferred; caller updates carried count once.
func deposit_supply(carried: int) -> int:
	if not owns_home() or carried <= 0 or home_supplies >= home_capacity():
		return 0
	home_supplies += 1
	return 1

func withdraw_supply(carried: int) -> int:
	if not owns_home() or carried >= 99 or carried < 0 or home_supplies <= 0:
		return 0
	home_supplies -= 1
	return 1

func accept_cal_quest()->bool:
	if cal_quest!=0 or has_receipt(CAL_RECEIPT):
		return false
	cal_quest=1
	return true

func collect_cal_gift()->bool:
	if cal_quest!=1:
		return false
	cal_quest=2
	return true

func complete_cal_quest()->bool:
	if cal_quest!=2 or not credit_once(CAL_RECEIPT,CAL_REWARD):
		return false
	cal_quest=3
	return true

func snapshot() -> Dictionary:
	var ids: Array = _receipts.keys()
	ids.sort()
	return {"version": VERSION, "receipts": ids, "owned_vehicles": owned_vehicle_ids(), "home_supplies":home_supplies, "home_storage_expanded":home_storage_expanded, "home_tenancy_paid":home_tenancy_paid, "outfit_id":outfit_id, "purchased_outfits":purchased_outfit_ids(), "bitcoin_sats":bitcoin_sats, "cal_quest":cal_quest}

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
	var cal:Variant=data.get("cal_quest",0)
	if not valid_cash(cal) or int(cal)>3 or (int(cal)==3)!=seen.has(CAL_RECEIPT):
		return false
	# Older saves already granted residence access; grandfather it, not new missions.
	var tenancy: Variant = data.get("home_tenancy_paid",seen.has(StarterHome.ACCESS_RECEIPT))
	if not tenancy is bool or (tenancy and not seen.has(StarterHome.ACCESS_RECEIPT)):
		return false
	var sats: Variant = data.get("bitcoin_sats",0)
	if not (sats is int or sats is float) or not is_finite(float(sats)) or float(sats)<0 or float(sats)>Economy.MAX_SATS or floor(float(sats))!=float(sats):
		return false
	var purchased: Variant = data.get("purchased_outfits",[])
	if not purchased is Array or purchased.size() > Wardrobe.IDS.size() or (not purchased.is_empty() and not tenancy):
		return false
	var closet: Dictionary = {}
	for id in purchased:
		if not Wardrobe.valid_id(id) or id == Wardrobe.DEFAULT or closet.has(id):
			return false
		closet[id] = true
	var outfit: Variant = data.get("outfit_id",Wardrobe.DEFAULT)
	if not Wardrobe.valid_id(outfit) or (outfit != Wardrobe.DEFAULT and not tenancy):
		return false
	if outfit != Wardrobe.DEFAULT and not closet.has(outfit):
		return false
	var expanded: Variant = data.get("home_storage_expanded", false)
	if not expanded is bool or (expanded and not tenancy):
		return false
	var limit := StarterHome.EXPANDED_STORAGE if expanded else StarterHome.MAX_STORAGE
	var stored: Variant = data.get("home_supplies", 0)
	if not valid_cash(stored) or int(stored) > limit or (int(stored) > 0 and not tenancy):
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
	home_tenancy_paid = data.get("home_tenancy_paid",next.has(StarterHome.ACCESS_RECEIPT))
	_owned_vehicles = titles
	home_supplies = int(data.get("home_supplies",0))
	home_storage_expanded = data.get("home_storage_expanded",false)
	outfit_id = data.get("outfit_id",Wardrobe.DEFAULT)
	bitcoin_sats = int(data.get("bitcoin_sats",0))
	cal_quest=int(data.get("cal_quest",0))
	_purchased_outfits.clear()
	for id in data.get("purchased_outfits",[]):
		_purchased_outfits[id] = true
	return true
