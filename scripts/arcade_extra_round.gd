extends RefCounted
## Original target gallery and sliding puzzle. No currency or real purchases.
const SIDE = 3
const GALLERY_STEPS = 24
const GALLERY_SECONDS = 1.2
const MAGAZINE = 4
const MOVE_LIMIT = 36
const SOLVED = [1,2,3,4,5,6,7,8,0]
const SCRAMBLES = [
	[Vector2i.LEFT,Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN],
	[Vector2i.UP,Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT],
	[Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
]
var game_id := ""
var finished := true
var cleared := false
var score := 0
var lives := 3
var step := 0
var cursor := Vector2i(1,1)
var target := Vector2i.ZERO
var decoy := Vector2i.ZERO
var target_hit := false
var ammo := MAGAZINE
var streak := 0
var stage := 0
var moves := 0
var tiles: Array = []
var blank := Vector2i(2,2)
var feedback := ""

func start(id: String) -> bool:
	if id != "annual_warfare" and id != "day_one_dlc":
		return false
	game_id = id
	finished = false
	cleared = false
	score = 0
	lives = 3
	step = 0
	cursor = Vector2i(1,1)
	ammo = MAGAZINE
	streak = 0
	stage = 0
	moves = 0
	tiles.clear()
	if id == "annual_warfare":
		_spawn_targets()
		feedback = "Reloads included in the base game."
	else:
		_load_puzzle()
	return true

func steer(direction: int) -> void:
	_move(Vector2i(clampi(direction,-1,1),0))

func vertical(direction: int) -> void:
	_move(Vector2i(0,clampi(direction,-1,1)))

func _move(delta: Vector2i) -> void:
	if finished or delta == Vector2i.ZERO:
		return
	if game_id == "annual_warfare":
		cursor = Vector2i(clampi(cursor.x + delta.x,0,2),clampi(cursor.y + delta.y,0,2))
	elif _slide(delta):
		moves += 1
		if tiles == SOLVED:
			score += 500 + (MOVE_LIMIT - moves) * 10
			stage += 1
			if stage == SCRAMBLES.size():
				finished = true
				cleared = true
				feedback = "Complete game unlocked. No wallet required."
			else:
				_load_puzzle()
		elif moves >= MOVE_LIMIT:
			finished = true
			feedback = "The puzzle won this time. Try again for free."

func strike() -> bool:
	if finished or game_id != "annual_warfare":
		return false
	if ammo == 0:
		ammo = MAGAZINE
		feedback = "Reloaded. No premium ammunition pack."
		return true
	ammo -= 1
	if cursor == target and not target_hit:
		target_hit = true
		streak += 1
		score += 100 + mini(streak - 1, 9) * 20
		feedback = "Nice shot! Same bot since 2031."
	elif cursor == decoy:
		streak = 0
		lives -= 1
		feedback = "Spare the fans. They're here for their friends."
		if lives == 0:
			finished = true
	else:
		streak = 0
		feedback = "Miss! Take your time."
	return true

func advance() -> void:
	if finished or game_id != "annual_warfare":
		return
	if not target_hit:
		streak = 0
	step += 1
	if step >= GALLERY_STEPS:
		cleared = score >= 800
		finished = true
		feedback = "Your squad stuck around. That's what counts."
	else:
		_spawn_targets()

func _spawn_targets() -> void:
	var n := posmod(step * 5 + 4, 9)
	var other := posmod(n + 4, 9)
	target = Vector2i(n % SIDE, floori(float(n) / SIDE))
	decoy = Vector2i(other % SIDE, floori(float(other) / SIDE))
	target_hit = false

func _load_puzzle() -> void:
	tiles = SOLVED.duplicate()
	blank = Vector2i(2,2)
	moves = 0
	for delta in SCRAMBLES[stage]:
		_slide(delta)
	feedback = "Pack %d of 3: restore the complete base game." % (stage + 1)

func _slide(delta: Vector2i) -> bool:
	var next := blank + delta
	if next.x < 0 or next.x >= SIDE or next.y < 0 or next.y >= SIDE:
		return false
	var old_index := blank.y * SIDE + blank.x
	var index := next.y * SIDE + next.x
	tiles[old_index] = tiles[index]
	tiles[index] = 0
	blank = next
	return true

func result() -> Dictionary:
	return {"game_id":game_id,"score":score,"lives":lives,"steps":step if game_id == "annual_warfare" else stage,"finished":finished,"cleared":cleared}
