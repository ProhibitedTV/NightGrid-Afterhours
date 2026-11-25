extends RefCounted
## Two distinct bounded games: real-time grid repair and turn-based studio management.
const COLS := 4
const ROWS := 3
const PATCH_STEPS := 30
const PATCH_SECONDS := 0.65
const WEEKS := 8
const ACTIONS := ["Build", "Fix", "Rest", "Community"]
const DETAILS := ["+3 quality, +2 bugs, -2 energy", "-3 bugs, +1 quality, -1 energy", "+4 energy", "+3 fans, -1 energy"]
var game_id := ""
var finished := true
var score := 0
var lives := 3
var step := 0
var cursor := Vector2i.ZERO
var bugs: Dictionary = {}
var choice := 0
var quality := 0
var debt := 0
var energy := 6
var fans := 0
var cleared := false
var feedback := ""

func start(id: String) -> bool:
	if id != "patch_day" and id != "indie_dev":
		return false
	game_id = id
	finished = false
	score = 0
	lives = 3
	step = 0
	cursor = Vector2i(1, 1)
	bugs.clear()
	choice = 0
	quality = 0
	debt = 0
	energy = 6
	fans = 0
	cleared = false
	feedback = "The community is rooting for you."
	if id == "patch_day":
		bugs[Vector2i(1, 1)] = 5
	return true

func steer(direction: int) -> void:
	if finished:
		return
	var n := clampi(direction, -1, 1)
	if game_id == "patch_day":
		cursor.x = clampi(cursor.x + n, 0, COLS - 1)
	else:
		choice = posmod(choice + n, ACTIONS.size())

func vertical(direction: int) -> void:
	if not finished and game_id == "patch_day":
		cursor.y = clampi(cursor.y + clampi(direction, -1, 1), 0, ROWS - 1)

func strike() -> bool:
	if finished:
		return false
	if game_id == "patch_day":
		if not bugs.has(cursor):
			return false
		score += 100 + int(bugs[cursor]) * 10
		bugs.erase(cursor)
		feedback = "Fixed! The players noticed."
		return true
	return _studio_week()

func advance() -> void:
	if finished or game_id != "patch_day":
		return
	step += 1
	for cell in bugs.keys():
		bugs[cell] = int(bugs[cell]) - 1
		if int(bugs[cell]) <= 0:
			bugs.erase(cell)
			lives -= 1
			feedback = "Crash report received. Keep going!"
	if lives <= 0 or step >= PATCH_STEPS:
		lives = maxi(0, lives)
		cleared = lives > 0
		finished = true
		if cleared:
			score += lives * 100
		return
	if step % 2 == 0 and step <= PATCH_STEPS - 5:
		var slot := posmod(step * 5 + 3, COLS * ROWS)
		# Scan only the fixed grid for an empty cell, never overwrite a live bug.
		for offset in range(COLS * ROWS):
			var index := posmod(slot + offset, COLS * ROWS)
			var cell := Vector2i(index % COLS, floori(float(index) / float(COLS)))
			if not bugs.has(cell):
				bugs[cell] = 5
				break

func _studio_week() -> bool:
	var cost := 0 if choice == 2 else (2 if choice == 0 else 1)
	if energy < cost:
		feedback = "Too tired. Rest is part of making good games."
		return false
	match choice:
		0:
			quality += 3
			debt += 2
			feedback = "A real feature, not a teaser trailer."
		1:
			debt = maxi(0, debt - 3)
			quality += 1
			feedback = "A player submitted a great bug report."
		2:
			energy = mini(8, energy + 4)
			feedback = "You took the weekend off. Good."
		3:
			fans += 3
			feedback = "Someone made fan art of your game."
	energy -= cost
	step += 1
	score = maxi(0, quality * 100 + fans * 50 - debt * 40)
	if step >= WEEKS:
		finished = true
		cleared = quality >= 9 and debt <= 2 and fans >= 3
		if cleared:
			score += 500
			feedback = "CULT CLASSIC! Your players kept the lights on."
		else:
			feedback = "You shipped. Your community hopes you keep creating."
	return true

func result() -> Dictionary:
	return {"game_id":game_id, "score":score, "lives":lives, "steps":step, "finished":finished, "cleared":cleared}
