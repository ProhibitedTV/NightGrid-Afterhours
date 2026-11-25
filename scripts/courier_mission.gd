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

func has_package() -> bool:
	return step == 1

func target() -> Vector3:
	return ROUTES[completed_runs % ROUTES.size()][OBJECTIVES[step]["point"]] + Vector3.UP * 0.2

func payout() -> int:
	# Starter meal delivery: estimated 2026 $15–24 net platform payout.
	if gig_economy:
		return Economy.price_2036(15+mini(completed_runs,9))
	return 250 + 50 * mini(completed_runs, 8)

func objective() -> Dictionary:
	var result: Dictionary = OBJECTIVES[step].duplicate()
	if gig_economy:
		result["title"] = "QuotaDrop / Collect meal" if step == 0 else "QuotaDrop / Deliver meal"
		result["hud"] = "QUOTADROP / PICK UP MEAL" if step == 0 else "QUOTADROP / DELIVER MEAL"
	result["route_id"] = ROUTES[completed_runs % ROUTES.size()]["id"]
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
