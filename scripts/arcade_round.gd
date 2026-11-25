extends RefCounted
## Deterministic, bounded cabinet simulation. No world, wallet or save dependencies.
const GAMES := {
	"grand_delay": {"title":"GRAND DELAY AUTO VI", "studio":"Milestone Mirage", "tagline":"A revolutionary city. Available eventually.", "instructions":"Steer into green feature drops. Avoid red paywalls.", "color":"69d8c2"},
	"claw_compliance": {"title":"CLAW & COMPLIANCE", "studio":"Committee Interactive", "tagline":"Unleash your inner focus group.", "instructions":"Move between lanes. Strike approaching audit drones before they reach you.", "color":"efb169"},
	"patch_day": {"title":"PATCH DAY 2077", "studio":"Quarterly Vision", "tagline":"The hotfix needs a hotfix.", "instructions":"Move across the grid and repair bugs before they crash the build.", "color":"c4a2f3"},
	"indie_dev": {"title":"INDIE DEV SIMULATOR", "studio":"Two Friends & A Laptop", "tagline":"No shareholders were consulted.", "instructions":"Choose how to spend eight weeks. Ship a game, not a roadmap.", "color":"f1cd82"},
	"annual_warfare": {"title":"ANNUAL WARFARE 19", "studio":"Recurrence Media", "tagline":"Same war. Different price.", "instructions":"Aim at recurring bots. Spare the fan targets. Reload for free.", "color":"a5ca82"},
	"day_one_dlc": {"title":"DAY-ONE DLC", "studio":"Partition Publishing", "tagline":"Some assembly required.", "instructions":"Slide the empty space to put all eight base-game tiles in order.", "color":"ed9db5"}
}
const IDS := ["grand_delay", "claw_compliance", "patch_day", "indie_dev", "annual_warfare", "day_one_dlc"]
const LANES := 3
const END_ROW := 5
const ROUND_STEPS := 32
const STEP_SECONDS := 0.40
var game_id := ""
var lane := 1
var score := 0
var lives := 3
var step := 0
var finished := true
var objects: Array[Dictionary] = []

func start(id: String) -> bool:
	if id != "grand_delay" and id != "claw_compliance":
		return false
	game_id = id
	lane = 1
	score = 0
	lives = 3
	step = 0
	finished = false
	objects.clear()
	return true

func steer(direction: int) -> void:
	if not finished:
		lane = clampi(lane + clampi(direction, -1, 1), 0, LANES - 1)

func strike() -> bool:
	if finished or game_id != "claw_compliance":
		return false
	for i in range(objects.size() - 1, -1, -1):
		var item: Dictionary = objects[i]
		if int(item["lane"]) == lane and int(item["row"]) >= 3:
			objects.remove_at(i)
			score += 100
			return true
	return false

func advance() -> void:
	if finished:
		return
	step += 1
	for i in range(objects.size() - 1, -1, -1):
		var item: Dictionary = objects[i]
		item["row"] = int(item["row"]) + 1
		if int(item["row"]) >= END_ROW:
			if int(item["lane"]) == lane:
				if item["kind"] == "feature":
					score += 100
				else:
					lives -= 1
			objects.remove_at(i)
	if lives <= 0 or step >= ROUND_STEPS:
		lives = maxi(lives, 0)
		finished = true
		objects.clear()
		return
	if step % 2 == 1 and step <= ROUND_STEPS - END_ROW:
		var wave := floori(float(step - 1) / 2.0)
		var target := (int(wave) * 2 + 1) % LANES
		if game_id == "grand_delay":
			objects.append({"lane": target, "row": 0, "kind": "feature"})
			objects.append({"lane": (target + 1) % LANES, "row": 0, "kind": "paywall"})
		else:
			objects.append({"lane": target, "row": 0, "kind": "drone"})

func result() -> Dictionary:
	return {"game_id": game_id, "score": score, "lives": lives, "steps": step, "finished": finished, "cleared": finished and step == ROUND_STEPS and lives > 0}
