extends RefCounted
## Fixed-step original retro games. Simulation uses a 600 x 250 logical arena.
const WIDTH = 600.0
const HEIGHT = 250.0
const DT = 1.0 / 30.0
const MAX_TICKS = 3600
const PADDLE_HALF = 43.0
const BALL_RADIUS = 5.0
const SHIP_Y = 231.0
const SHIP_SPEED = 250.0
const SHOT_SPEED = 350.0
const MAX_SHOTS = 8
var game_id := ""
var finished := true
var cleared := false
var score := 0
var lives := 3
var step := 0
var wave := 1
var player_x := WIDTH * .5
var axis := 0
var shots: Array[Vector2] = []
var enemies: Array[Vector2] = []
var enemy_shots: Array[Vector2] = []
var enemy_direction := 1
var cooldown := 0
var bricks: Array[Rect2] = []
var ball := Vector2.ZERO
var velocity := Vector2.ZERO
var launched := false
var feedback := ""

func start(id: String) -> bool:
	if id != "starline_patrol" and id != "neon_rebound":
		return false
	game_id = id
	finished = false
	cleared = false
	score = 0
	lives = 3
	step = 0
	wave = 1
	player_x = WIDTH * .5
	axis = 0
	cooldown = 0
	shots.clear()
	enemies.clear()
	enemy_shots.clear()
	bricks.clear()
	if id == "starline_patrol":
		_spawn_wave()
		feedback = "Protect the colony. Three waves."
	else:
		_build_wall()
		_reset_ball()
		feedback = "Launch when ready."
	return true

func steer(direction: int) -> void:
	axis = clampi(direction,-1,1)

func strike() -> bool:
	if finished:
		return false
	if game_id == "neon_rebound":
		if launched:
			return false
		launched = true
		velocity = Vector2(92,-170) if wave == 1 else Vector2(-115,-185)
		return true
	if cooldown > 0 or shots.size() >= MAX_SHOTS:
		return false
	shots.append(Vector2(player_x,SHIP_Y-12))
	cooldown = 6
	return true

func advance() -> void:
	if finished:
		return
	step += 1
	var margin := PADDLE_HALF if game_id == "neon_rebound" else 14.0
	player_x = clampf(player_x + axis * SHIP_SPEED * DT, margin, WIDTH-margin)
	if game_id == "starline_patrol":
		_advance_shooter()
	else:
		_advance_bricks()
	if not finished and step >= MAX_TICKS:
		finished = true
		feedback = "Time! Come back for another try."

func _spawn_wave() -> void:
	enemies.clear()
	enemy_shots.clear()
	shots.clear()
	enemy_direction = 1
	for y in range(3):
		for x in range(7):
			enemies.append(Vector2(125+x*53,20+y*29))

func _advance_shooter() -> void:
	cooldown = maxi(0,cooldown-1)
	var dx := float(enemy_direction)*(30.0+wave*12.0)*DT
	var turn := false
	for enemy in enemies:
		if enemy.x+dx < 15 or enemy.x+dx > WIDTH-15:
			turn = true
			break
	for i in range(enemies.size()):
		enemies[i] += Vector2(0,10) if turn else Vector2(dx,0)
	if turn:
		enemy_direction *= -1
	for i in range(shots.size()-1,-1,-1):
		var shot := shots[i] + Vector2(0,-SHOT_SPEED*DT)
		shots[i] = shot
		var hit := false
		for j in range(enemies.size()-1,-1,-1):
			if Rect2(enemies[j]-Vector2(13,9),Vector2(26,18)).grow(3).has_point(shot):
				enemies.remove_at(j)
				score += 100
				hit = true
				break
		if hit or shot.y < 0:
			shots.remove_at(i)
	if enemies.is_empty():
		if wave >= 3:
			_win("Colony safe. Nice flying!")
		else:
			wave += 1
			_spawn_wave()
		return
	if step % maxi(15,42-wave*6) == 0 and enemy_shots.size() < 12:
		var source := enemies[posmod(step*7,enemies.size())]
		enemy_shots.append(source+Vector2(0,10))
	for i in range(enemy_shots.size()-1,-1,-1):
		enemy_shots[i] += Vector2(0,(100.0+wave*20.0)*DT)
		var projectile := enemy_shots[i]
		if Rect2(Vector2(player_x-13,SHIP_Y-8),Vector2(26,16)).grow(3).has_point(projectile):
			enemy_shots.clear()
			_lose_life()
			break
		elif projectile.y > HEIGHT:
			enemy_shots.remove_at(i)
	if not finished:
		for enemy in enemies:
			if enemy.y >= SHIP_Y-18:
				_lose_life()
				if not finished:
					_spawn_wave()
				break

func _build_wall() -> void:
	bricks.clear()
	for y in range(4):
		for x in range(10):
			bricks.append(Rect2(17+x*57,17+y*19,53,15))

func _reset_ball() -> void:
	launched = false
	ball = Vector2(player_x,SHIP_Y-12)
	velocity = Vector2.ZERO

func _advance_bricks() -> void:
	if not launched:
		ball = Vector2(player_x,SHIP_Y-12)
		return
	var old := ball
	ball += velocity*DT
	if ball.x <= BALL_RADIUS or ball.x >= WIDTH-BALL_RADIUS:
		ball.x = clampf(ball.x,BALL_RADIUS,WIDTH-BALL_RADIUS)
		velocity.x = -velocity.x
	if ball.y <= BALL_RADIUS:
		ball.y = BALL_RADIUS
		velocity.y = absf(velocity.y)
	if velocity.y > 0 and old.y <= SHIP_Y-BALL_RADIUS and ball.y >= SHIP_Y-BALL_RADIUS and absf(ball.x-player_x) <= PADDLE_HALF+BALL_RADIUS:
		ball.y = SHIP_Y-BALL_RADIUS
		var offset := clampf((ball.x-player_x)/PADDLE_HALF,-1,1)
		var speed := minf(270.0,velocity.length()+2.0)
		velocity = Vector2(offset*.82,-1.0).normalized()*speed
	for i in range(bricks.size()-1,-1,-1):
		var bounds := bricks[i].grow(BALL_RADIUS)
		if bounds.has_point(ball):
			if old.y < bounds.position.y or old.y >= bounds.end.y:
				velocity.y *= -1
			else:
				velocity.x *= -1
			ball = old
			bricks.remove_at(i)
			score += 50
			break
	if bricks.is_empty():
		if wave >= 2:
			_win("Two walls cleared. Beautiful!")
		else:
			wave += 1
			_build_wall()
			_reset_ball()
	elif ball.y > HEIGHT+BALL_RADIUS:
		_lose_life()
		_reset_ball()

func _lose_life() -> void:
	lives = maxi(0,lives-1)
	if lives == 0:
		finished = true
		feedback = "Game over. One more try?"
	else:
		feedback = "Still in the game."

func _win(message: String) -> void:
	cleared = true
	finished = true
	score += lives*200
	feedback = message

func result() -> Dictionary:
	return {"game_id":game_id,"score":score,"lives":lives,"steps":step,"finished":finished,"cleared":cleared}
