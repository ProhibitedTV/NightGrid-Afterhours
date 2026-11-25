extends RefCounted
## Repeatable courier contract. Only the run count and current objective are
## mutable; authored route geometry is independent of save and streaming.
const MAX_RUNS = 1000000
const ROUTES = [
	{"id":"courier:quay_east","pickup":Vector3(-116,0,0),"dropoff":Vector3(116,0,116)},
	{"id":"courier:northwest","pickup":Vector3(58,0,-116),"dropoff":Vector3(-116,0,58)},
	{"id":"courier:central_north","pickup":Vector3(116,0,58),"dropoff":Vector3(0,0,-116)},
	{"id":"courier:south_east","pickup":Vector3(-58,0,116),"dropoff":Vector3(116,0,-58)}
]
# Stable restaurant-to-workplace orders. Both endpoints resolve through the
# existing authored catalogs, not road centers or randomly spawned customers.
const GIG_ORDERS = [
	{"id":"gig:moon_freight","vendor":"moon_noodles","customer":"freight_control","meal":"Noodle bowl","recipient":"Freight Control / Cato","base":10,"tip":5},
	{"id":"gig:furnace_docks","vendor":"furnace_skewers","customer":"cold_storage","meal":"Skewer box","recipient":"Cold Chain 09 / Rook","base":11,"tip":7},
	{"id":"gig:bao_union","vendor":"neon_bao","customer":"union_supply","meal":"Bao dinner","recipient":"Union Distribution / Edda","base":12,"tip":8},
	{"id":"gig:moon_clinic","vendor":"moon_noodles","customer":"tide_clinic","meal":"Noodle bowl","recipient":"Tide Clinic / night staff","base":12,"tip":4},
	{"id":"gig:furnace_fire","vendor":"furnace_skewers","customer":"east_fire","meal":"Skewer box","recipient":"Eastside Fire 4 / Ash","base":12,"tip":6},
	{"id":"gig:bao_grid","vendor":"neon_bao","customer":"power_annex","meal":"Bao dinner","recipient":"Grid Annex Four / Lin","base":13,"tip":5}
]
var _gig_routes: Array[Dictionary] = []
# Declining rotates offers without incrementing paid delivery progress.
var offer_offset := 0

func configure_gig_routes(venues: Node, civic: Node) -> bool:
	var routes: Array[Dictionary] = []
	for order in GIG_ORDERS:
		var vendor: Dictionary = venues.call("venue_by_id",order["vendor"])
		var customer: Dictionary = civic.call("site_by_id",order["customer"])
		if vendor.is_empty() or customer.is_empty():
			return false
		var route: Dictionary = order.duplicate()
		route["pickup"] = venues.call("venue_position",order["vendor"])
		route["dropoff"] = civic.call("position_for",order["customer"])
		route["vendor_name"] = vendor["name"]
		routes.append(route)
	_gig_routes = routes
	return true

func _route() -> Dictionary:
	if gig_economy and not _gig_routes.is_empty():
		return _gig_routes[(completed_runs + offer_offset) % _gig_routes.size()]
	return ROUTES[completed_runs % ROUTES.size()]

const OBJECTIVES = [
	{"id":"collect","kind":"acquire","title":"Collect courier package","hud":"PICK UP PACKAGE","point":"pickup"},
	{"id":"deliver","kind":"deliver","title":"Deliver package","hud":"DELIVER PACKAGE","point":"dropoff"}
]
const RADIUS = 5.3
# Milestone-based courier conditioning. Derive from the existing validated
# successful-run count; no second XP balance or farmable frame counter.
const CONDITIONING_MILESTONES = [2,5,10]
const CONDITIONING_REDUCTION = .05

func conditioning_rank() -> int:
	var rank := 0
	for milestone in CONDITIONING_MILESTONES:
		if completed_runs >= milestone:
			rank += 1
	return rank

func conditioning_text() -> String:
	var rank := conditioning_rank()
	var detail := "MAX RANK" if rank == CONDITIONING_MILESTONES.size() else "NEXT: %d deliveries" % CONDITIONING_MILESTONES[rank]
	return "COURIER CONDITIONING  %d/%d  |  %d%% less sprint drain  |  %s" % [rank,CONDITIONING_MILESTONES.size(),rank*5,detail]

const Economy = preload("res://scripts/economy.gd")
var gig_economy := false
var completed_runs: int = 0
var step: int = 0

static func valid_run_count(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var n := float(value)
	return is_finite(n) and n >= 0.0 and n <= MAX_RUNS and floor(n) == n

func restore(runs: Variant, carrying: Variant) -> bool:
	if not valid_run_count(runs) or not carrying is bool:
		return false
	completed_runs = int(runs)
	step = 1 if carrying else 0
	return true

func can_decline_offer() -> bool:
	return gig_economy and step == 0 and _gig_routes.size() > 1

func decline_offer() -> bool:
	if not can_decline_offer():
		return false
	offer_offset = (offer_offset + 1) % _gig_routes.size()
	return true

func restore_offer_offset(value: Variant) -> void:
	offer_offset = int(value) if valid_run_count(value) and int(value) < GIG_ORDERS.size() else 0

func has_package() -> bool:
	return step == 1

func target() -> Vector3:
	return _route()[OBJECTIVES[step]["point"]] + (Vector3.ZERO if gig_economy and not _gig_routes.is_empty() else Vector3.UP * .2)

func payout() -> int:
	# Starter meal delivery: estimated 2026 $15–24 net platform payout.
	if gig_economy and not _gig_routes.is_empty():
		var order := _route()
		return Economy.price_2036(int(order["base"])+int(order["tip"]))
	if gig_economy:
		return Economy.price_2036(15)
	return 250 + 50 * mini(completed_runs, 8)

func objective() -> Dictionary:
	var result: Dictionary = OBJECTIVES[step].duplicate()
	var route := _route()
	if gig_economy and not _gig_routes.is_empty():
		var destination: String = route["vendor_name"] if step == 0 else route["recipient"]
		result["title"] = "QuotaDrop / %s / %s" % [route["meal"],destination]
		result["hud"] = "QUOTADROP / " + ("PICKUP: " if step == 0 else "DELIVER: ") + destination
		result["vendor"] = route["vendor"]
		result["customer"] = route["customer"]
		result["base_pay"] = Economy.price_2036(route["base"])
		result["tip"] = payout()-int(result["base_pay"])
	result["route_id"] = route["id"]
	result["run"] = completed_runs + 1
	result["step"] = step + 1
	result["total_steps"] = OBJECTIVES.size()
	result["reward"] = payout()
	return result

## Events must match the current objective ID and the actual target.
## Final step pays before mutating the run counter; no per-run receipt growth.
func advance(event_id: String, at: Vector3, wallet: RefCounted) -> Dictionary:
	if event_id != OBJECTIVES[step]["id"] or not at.is_finite() or at.distance_to(target()) >= RADIUS:
		return {}
	if step == 0:
		step = 1
		return {"event":"collected"}
	var amount := payout()
	if completed_runs >= MAX_RUNS or not wallet.call("credit", amount):
		return {"event":"blocked"}
	completed_runs += 1
	step = 0
	return {"event":"delivered","reward":amount}

## Abandon the carried package and immediately retry the same route.
## No payout, fee, teleport or run-counter change.
func restart() -> bool:
	if step == 0:
		return false
	step = 0
	return true
