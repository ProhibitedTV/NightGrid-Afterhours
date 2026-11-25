extends RefCounted
## Two offline score attacks: route optimization and timed command sequences.
const WIDTH = 5
const HEIGHT = 3
const CHECK_TICKS = 36
const CHECK_INTERVAL = 0.9
const SEASON_INTERVAL = 0.75
const SEASONS = 6
const SEASON_TICKS = 8
const COMMANDS = ["LEFT","UP","RIGHT","DOWN","A"]
const TASKS = ["TOWER","SHARD","CHEST"]
const OBJECTIVES = ["Log in for one glove","Visit the store (don't buy anything)","Complete three daily chores","Prove you are having fun","Defeat the engagement metric","Play because you want to"]
var game_id := ""
var finished := true
var cleared := false
var score := 0
var lives := 3
var step := 0
var cursor := Vector2i(2,1)
var icons: Dictionary = {}
var completed := 0
var season := 0
var time_left := 0
var chain: Array[int] = []
var progress := 0
var feedback := ""
var clean_waves := 0
var command_errors := 0
var perfect_seasons := 0
var season_errors := 0

func start(id: String) -> bool:
	if id != "open_world_checklist" and id != "battle_pass_hero":
		return false
	game_id = id
	finished = false
	cleared = false
	score = 0
	lives = 3
	step = 0
	cursor = Vector2i(2,1)
	icons.clear()
	completed = 0
	season = 0
	progress = 0
	time_left = 0
	chain.clear()
	clean_waves = 0
	command_errors = 0
	perfect_seasons = 0
	season_errors = 0
	if id == "open_world_checklist":
		feedback = "Your map is now 90 percent icons."
		_spawn_icons(0)
	else:
		_load_season()
	return true

func steer(direction: int) -> void:
	if direction != 0:
		if game_id == "battle_pass_hero":
			_command(0 if direction < 0 else 2)
		else:
			_move(Vector2i(clampi(direction,-1,1),0))

func vertical(direction: int) -> void:
	if direction != 0:
		if game_id == "battle_pass_hero":
			_command(1 if direction < 0 else 3)
		else:
			_move(Vector2i(0,clampi(direction,-1,1)))

func strike() -> bool:
	if finished:
		return false
	if game_id == "battle_pass_hero":
		return _command(4)
	return _collect()

func _move(delta: Vector2i) -> void:
	if finished or game_id != "open_world_checklist":
		return
	var next := Vector2i(clampi(cursor.x+delta.x,0,WIDTH-1),clampi(cursor.y+delta.y,0,HEIGHT-1))
	if next != cursor:
		cursor = next
		_collect()

func _collect() -> bool:
	if finished or not icons.has(cursor):
		return false
	var kind: int = icons[cursor]
	icons.erase(cursor)
	completed += 1
	score += [150,50,100][kind]
	feedback = ["Tower liberated. Sock unlocked.","Shard 1 of approximately infinity.","Chest found. Actual loot!"][kind]
	if icons.is_empty():
		score += 200
		clean_waves += 1
		feedback = "Map cleared! Go enjoy the scenery."
	return true

func _spawn_icons(wave: int) -> void:
	for n in range(4):
		var index := posmod(wave*7+n*4+1,WIDTH*HEIGHT)
		var cell := Vector2i(index % WIDTH, floori(float(index)/WIDTH))
		if cell != cursor and not icons.has(cell):
			icons[cell] = posmod(n+wave,TASKS.size())

func _load_season() -> void:
	progress = 0
	season_errors = 0
	time_left = SEASON_TICKS
	chain.clear()
	for i in range(3 + floori(float(season)/2.0)):
		chain.append(posmod(season*3+i*2+i*i,COMMANDS.size()))
	feedback = OBJECTIVES[season]

func _command(value: int) -> bool:
	if finished or game_id != "battle_pass_hero":
		return false
	if value != chain[progress]:
		command_errors += 1
		season_errors += 1
		progress = 0
		feedback = "Combo reset. You can try again."
		return false
	progress += 1
	if progress == chain.size():
		score += 200 + time_left * 10
		if season_errors==0:
			perfect_seasons += 1
			score += 20
		completed += 1
		_next_season()
	return true

func _next_season() -> void:
	season += 1
	if season >= SEASONS or lives <= 0:
		finished = true
		cleared = completed >= 4 and lives > 0
		feedback = "You earned your glove. Now go have fun." if cleared else "Season over. Your free time still belongs to you."
	else:
		_load_season()

func advance() -> void:
	if finished:
		return
	step += 1
	if game_id == "open_world_checklist":
		if step >= CHECK_TICKS:
			finished = true
			cleared = completed >= 12
			feedback = "You beat the checklist. The city is yours to explore."
			return
		if step % 6 == 0:
			_spawn_icons(floori(float(step)/6.0))
	else:
		time_left -= 1
		if time_left <= 0:
			lives -= 1
			_next_season()

func result() -> Dictionary:
	return {"game_id":game_id,"score":score,"lives":lives,"steps":step,"finished":finished,"cleared":cleared}
