extends RefCounted
## Deterministic fixed-step arcade driving. World distances are meters; x is road width in lanes.
const DT = 1.0/60.0
const LENGTH = 3600.0
const DISTRICT_LENGTH = 1200.0
const VIEW = 460.0
const MAX_SCORE = 20000
const DISTRICTS = ["PROMISE BEACH","ROADMAP DOWNTOWN","GOLD MASTER EXPRESSWAY"]
const SUBTITLES = ["A city. Eventually.","900 icons, three activities.","The actual ending is included."]
const FEATURES = ["OFFLINE MODE","TRAFFIC AI","SAVE SLOT","RADIO","GOOD PHYSICS","ACTUAL ENDING"]
const WALLS = ["DELUXE TAX","PREORDER","SEASON PASS","ACCOUNT REQUIRED","ROADMAP"]
# Each row: offset from district start, type, horizontal lane. Traffic moves; gates do not.
const ROUTES = [
	[[170,"feature",0],[290,"traffic",1],[400,"feature",2],[520,"wall",1],[650,"traffic",0],[760,"feature",1],[870,"traffic",2],[990,"feature",0],[1080,"wall",2]],
	[[100,"traffic",1],[230,"feature",2],[350,"wall",0],[470,"traffic",2],[580,"feature",1],[690,"traffic",0],[790,"wall",1],[910,"feature",0],[1040,"traffic",2],[1110,"feature",1]],
	[[110,"feature",0],[220,"traffic",1],[330,"wall",2],[440,"feature",2],[550,"traffic",0],[650,"wall",1],[760,"feature",1],[870,"traffic",2],[970,"feature",0],[1060,"wall",1],[1120,"traffic",0]]
]
var game_id = ""
var score = 0
var lives = 3
var finished = true
var cleared = false
var position_x = 1.0
var steering = 0.0
var lateral_velocity = 0.0
var speed = 0.0
var distance = 0.0
var remaining = 32.0
var race_time = 0.0
var countdown = 2.0
var district = 0
var nitro_charge = 0
var nitro_left = 0.0
var invulnerable = 0.0
var streak = 0
var best_streak = 0
var pickups = 0
var near_misses = 0
var overtakes = 0
var collisions = 0
var feedback = ""
var feedback_time = 0.0
var objects: Array[Dictionary] = []
var course: Array[Dictionary] = []
var next_event = 0
var splits: Array[float] = []

func start(id: String) -> bool:
	if id != "grand_delay":
		return false
	game_id = id
	score = 0
	lives = 3
	finished = false
	cleared = false
	position_x = 1.0
	steering = 0.0
	lateral_velocity = 0.0
	speed = 0.0
	distance = 0.0
	remaining = 32.0
	race_time = 0.0
	countdown = 2.0
	district = 0
	nitro_charge = 0
	nitro_left = 0.0
	invulnerable = 0.0
	streak = 0
	best_streak = 0
	pickups = 0
	near_misses = 0
	overtakes = 0
	collisions = 0
	feedback = "GET READY / NO PREORDER REQUIRED"
	feedback_time = 2.0
	objects.clear()
	course.clear()
	splits.clear()
	next_event = 0
	for stage in range(ROUTES.size()):
		for entry in ROUTES[stage]:
			var kind: String = entry[1]
			var index: int = course.size()
			course.append({"z": stage*DISTRICT_LENGTH+float(entry[0]),"x":float(entry[2]),"kind":kind,"label":FEATURES[index%FEATURES.size()] if kind=="feature" else WALLS[index%WALLS.size()],"velocity": 18.0+float(index%3)*4.0 if kind=="traffic" else 0.0})
	_spawn_visible()
	return true

func steer(direction: float) -> void:
	if not finished:
		steering = clampf(direction,-1.0,1.0)

func strike() -> bool:
	if finished or countdown > 0.0 or nitro_charge < 3 or nitro_left > 0.0:
		return false
	nitro_charge = 0
	nitro_left = 2.8
	_message("NITRO / FULL GAME UNLOCKED")
	return true

func _message(message: String) -> void:
	feedback = message
	feedback_time = 2.0

func _add_points(points: int) -> void:
	score = mini(MAX_SCORE,score+points)

func _spawn_visible() -> void:
	while next_event < course.size() and float(course[next_event]["z"]) <= distance+VIEW:
		objects.append(course[next_event].duplicate())
		next_event += 1

func _hit(item: Dictionary, gap: float) -> void:
	var kind: String = item["kind"]
	if kind == "feature":
		if gap <= .36:
			pickups += 1
			streak += 1
			best_streak = maxi(best_streak,streak)
			nitro_charge = mini(3,nitro_charge+1)
			_add_points(100+mini(streak-1,4)*15)
			_message("FEATURE SHIPPED: "+str(item["label"]))
		else:
			streak = 0
		return
	if gap < .32:
		if kind == "wall" and nitro_left > 0.0:
			_add_points(50)
			_message("PAYWALL BYPASSED / FREE OF CHARGE")
			return
		if invulnerable <= 0.0:
			lives -= 1
			collisions += 1
			streak = 0
			speed *= .48
			nitro_left = 0.0
			invulnerable = 1.2
			_message("TRAFFIC CONTACT" if kind=="traffic" else "PAYWALL: "+str(item["label"]))
	elif kind == "traffic":
		overtakes += 1
		if gap < .60 and speed >= 50.0:
			near_misses += 1
			_add_points(45)
			_message("CLEAN NEAR MISS +45")
		else:
			_add_points(15)

func advance(throttle: bool = false, brake: bool = false) -> void:
	if finished:
		return
	if countdown > 0.0:
		countdown = maxf(0.0,countdown-DT)
		if countdown == 0.0:
			_message("GO! / ALL CONTENT INCLUDED")
		return
	race_time += DT
	remaining = maxf(0.0,remaining-DT)
	feedback_time = maxf(0.0,feedback_time-DT)
	invulnerable = maxf(0.0,invulnerable-DT)
	nitro_left = maxf(0.0,nitro_left-DT)
	var target = 28.0 if brake else (76.0 if throttle else 53.0)
	if nitro_left > 0.0 and not brake:
		target = 98.0
	speed = move_toward(speed,target,(85.0 if brake else (35.0 if nitro_left>0.0 else 24.0))*DT)
	var desired = steering*(2.3+speed*.009)
	lateral_velocity = move_toward(lateral_velocity,desired,12.0*DT)
	position_x = clampf(position_x+lateral_velocity*DT,-.10,2.10)
	var previous = distance
	distance = minf(LENGTH,distance+speed*DT)
	_spawn_visible()
	for i in range(objects.size()-1,-1,-1):
		var item: Dictionary = objects[i]
		item["z"] = float(item["z"])+float(item["velocity"])*DT
		if float(item["z"]) <= distance:
			_hit(item,absf(position_x-float(item["x"])))
			objects.remove_at(i)
	var new_district = mini(2,floori(distance/DISTRICT_LENGTH))
	if new_district > district:
		district = new_district
		splits.append(race_time)
		remaining += 20.0
		_add_points(150)
		_message("CHECKPOINT +20 SEC / "+DISTRICTS[district])
	if lives <= 0:
		lives = 0
		finished = true
		_message("GAME OVER / RELEASE POSTPONED")
	elif distance >= LENGTH:
		cleared = true
		finished = true
		splits.append(race_time)
		_add_points(300+floori(remaining)*5+lives*50)
		_message("GOLD MASTER / THANK YOU FOR PLAYING")
	elif remaining <= 0.0:
		finished = true
		_message("TIME OUT / RELEASE POSTPONED")

func result() -> Dictionary:
	return {"game_id":game_id,"score":score,"lives":lives,"finished":finished,"cleared":cleared,"time":race_time,"distance":distance,"pickups":pickups,"near_misses":near_misses,"overtakes":overtakes,"collisions":collisions,"best_streak":best_streak,"splits":splits.duplicate()}
