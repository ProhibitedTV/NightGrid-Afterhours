extends RefCounted
## Fixed-size per-save local scores. No network, wallet, run history or rewards.
const Catalog = preload("res://scripts/arcade_round.gd")
const MAX_SCORE = 20000
const RIVALS = {
	"grand_delay": [["JET",1100],["ROOK",800],["MARA",500]],
	"claw_compliance": [["NYX",1100],["ROOK",800],["ASH",400]],
	"patch_day": [["ROOK",1850],["EV",1400],["MARA",850]],
	"indie_dev": [["MARA",1500],["ROOK",1200],["HAL",850]],
	"annual_warfare": [["ASH",4400],["JET",2600],["ROOK",1300]],
	"day_one_dlc": [["EV",2100],["ROOK",1900],["MARA",1500]],
	"open_world_checklist": [["JET",2300],["HAL",1700],["ROOK",1200]],
	"battle_pass_hero": [["NYX",1560],["MARA",1300],["ROOK",1000]],
	"starline_patrol": [["ROOK",6100],["NYX",4500],["ASH",2400]],
	"neon_rebound": [["EV",4100],["ROOK",3300],["HAL",1800]]
}

# Designed to be reachable by ordinary play, with no daily attendance requirement.
const CIRCUIT = [
	{"id":"grand_delay","goal":800,"rival":"JET","title":"ROAD TRIP"},
	{"id":"claw_compliance","goal":600,"rival":"NYX","title":"NO COMMITTEE"},
	{"id":"patch_day","goal":1000,"rival":"EV","title":"HOTFIX HERO"},
	{"id":"indie_dev","goal":1000,"rival":"HAL","title":"SHIP IT"},
	{"id":"annual_warfare","goal":1800,"rival":"ASH","title":"OLD SQUAD"},
	{"id":"day_one_dlc","goal":1400,"rival":"EV","title":"COMPLETE EDITION"},
	{"id":"open_world_checklist","goal":1000,"rival":"JET","title":"TOUCH GRASS"},
	{"id":"battle_pass_hero","goal":900,"rival":"NYX","title":"FREE TIME"}
]

# Independent mastery board: legacy eight circuit stamps never move.
const MASTERY = {
	"grand_delay":[800,1800,2600],"claw_compliance":[400,800,1200],
	"patch_day":[650,1200,1800],"indie_dev":[700,1300,1700],
	"annual_warfare":[900,2200,4000],"day_one_dlc":[800,1500,2200],
	"open_world_checklist":[700,1500,2300],"battle_pass_hero":[600,1050,1500],
	"starline_patrol":[1200,3200,6100],"neon_rebound":[700,2200,4100]
}

static func mastery_level(id: String, score: int) -> int:
	var level := 0
	for goal in MASTERY.get(id,[]):
		if score >= int(goal):
			level += 1
	return level

static func mastery_rows(scores: Dictionary) -> Array:
	var rows := []
	for id in Catalog.IDS:
		var best := int(scores.get(id,0))
		var level := mastery_level(id,best)
		var goals: Array = MASTERY[id]
		rows.append({"id":id,"best":best,"level":level,"next":int(goals[mini(level,2)]),"gold":level==3})
	return rows

static func mastery_total(scores: Dictionary) -> int:
	var total := 0
	for row in mastery_rows(scores):
		total += int(row["level"])
	return total

static func circuit_rows(scores: Dictionary) -> Array:
	var rows := []
	for challenge in CIRCUIT:
		var row: Dictionary = challenge.duplicate()
		row["best"] = int(scores.get(row["id"],0))
		row["earned"] = row["best"] >= row["goal"]
		rows.append(row)
	return rows

static func circuit_count(scores: Dictionary) -> int:
	var count := 0
	for row in circuit_rows(scores):
		if row["earned"]:
			count += 1
	return count

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() > Catalog.IDS.size():
		return false
	for id in value:
		if not id is String or not Catalog.IDS.has(id):
			return false
		var score: Variant = value[id]
		if not (score is int or score is float) or not is_finite(float(score)):
			return false
		if float(score) < 0.0 or float(score) > MAX_SCORE or floor(float(score)) != float(score):
			return false
	return true

static func normalized(value: Variant) -> Dictionary:
	var scores := {}
	if valid(value):
		for id in value:
			scores[id] = int(value[id])
	return scores

static func record(scores: Dictionary, id: String, score: int) -> bool:
	if not Catalog.IDS.has(id) or score < 0 or score > MAX_SCORE:
		return false
	if scores.has(id) and int(scores[id]) >= score:
		return false
	scores[id] = score
	return true

static func board(id: String, scores: Dictionary) -> Array:
	var rows: Array = RIVALS.get(id, []).duplicate(true)
	if scores.has(id) and Catalog.IDS.has(id):
		rows.append(["YOU", int(scores[id])])
	# Score descending; ties prefer the established score-holder.
	rows.sort_custom(func(a: Array,b: Array) -> bool:
		if a[1] == b[1]:
			if a[0] == "YOU" or b[0] == "YOU":
				return b[0] == "YOU" and a[0] != "YOU"
			return str(a[0]) < str(b[0])
		return int(a[1]) > int(b[1]))
	return rows
