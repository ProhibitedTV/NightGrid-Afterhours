extends RefCounted
## Deterministic fixed-step arcade driving. World distances are meters; x is road width in lanes.
const Track = preload("res://scripts/grand_delay_track.gd")
const Garage = preload("res://scripts/grand_delay_garage.gd")
const Rivals = preload("res://scripts/grand_delay_rivals.gd")
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
var bend = 0.0
var drifting = false
var drift_time = 0.0
var drift_bend = -1
var drift_awards: Array[int] = []
var drift_count = 0
var drift_points = 0
var shoulder = false
var car_index = 0
var competitive = false
var rivals: Array[Dictionary] = []
var finish_place = 0
var rival_contacts = 0
var rival_cooldown = 0.0

func start(id: String, selected_car: int = 0, race_rivals: bool = false) -> bool:
	if id != "grand_delay":
		return false
	game_id = id
	car_index = clampi(selected_car,0,Garage.CARS.size()-1)
	competitive = race_rivals
	rivals.clear()
	if competitive:
		rivals = Rivals.new_grid()
	finish_place = 0
	rival_contacts = 0
	rival_cooldown = 0.0
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
	bend = 0.0
	drifting = false
	drift_time = 0.0
	drift_bend = -1
	drift_awards.clear()
	drift_count = 0
	drift_points = 0
	shoulder = false
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
			drifting = false
			drift_time = 0.0
			drift_bend = -1
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
	bend = Track.curvature(distance)
	var bend_id = Track.bend_index(distance)
	var slide = brake and absf(steering)>.35 and absf(bend)>.25 and speed>44.0 and invulnerable<=0.0 and not shoulder
	if slide:
		if drift_bend != bend_id:
			drift_time = 0.0
			drift_bend = bend_id
		drifting = true
		drift_time += DT
	elif drifting:
		_finish_drift(not shoulder and invulnerable<=0.0)
	var car = Garage.spec(car_index)
	var target = (49.0 if drifting else 28.0) if brake else (float(car["top"]) if throttle else float(car["top"])*53.0/76.0)
	if nitro_left > 0.0 and not brake:
		target = float(car["boost"])
	# Curves exert outward load proportional to speed. Feathering brake allows
	# a controlled slide; shoulders reduce top speed but never steal a life.
	if shoulder:
		target = minf(target,39.0)
	speed = move_toward(speed,target,(48.0 if drifting else (float(car["brake"]) if brake else (35.0 if nitro_left>0.0 else float(car["accel"]))))*DT)
	var grip: float = car["grip"]
	var desired = steering*(2.3+speed*.009)*grip - bend*.38*pow(speed/76.0,2.0)/grip
	lateral_velocity = move_toward(lateral_velocity,desired,(7.0 if drifting else 12.0)*grip*DT)
	position_x = clampf(position_x+lateral_velocity*DT,-.10,2.10)
	shoulder = position_x < -.065 or position_x > 2.065
	if shoulder and drifting:
		_finish_drift(false)
	var old_distance = distance
	var crossing_speed = speed
	distance = minf(LENGTH,distance+crossing_speed*DT)
	_spawn_visible()
	for i in range(objects.size()-1,-1,-1):
		var item: Dictionary = objects[i]
		item["z"] = float(item["z"])+float(item["velocity"])*DT
		if float(item["z"]) <= distance:
			_hit(item,absf(position_x-float(item["x"])))
			objects.remove_at(i)
	if competitive:
		Rivals.advance(rivals,objects,course,DT,race_time)
		_rival_contact()
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
		var finish_time = race_time-DT+clampf((LENGTH-old_distance)/maxf(crossing_speed,.01),0.0,DT)
		finish_place = Rivals.place(rivals,LENGTH,finish_time) if competitive else 0
		splits.append(race_time)
		_add_points(300+floori(remaining)*5+lives*50)
		if competitive:
			_add_points([400,250,100,0][finish_place-1])
		_message("GOLD MASTER / THANK YOU FOR PLAYING")
	elif remaining <= 0.0:
		finished = true
		_message("TIME OUT / RELEASE POSTPONED")

func _rival_contact() -> void:
	rival_cooldown = maxf(0.0,rival_cooldown-DT)
	if rival_cooldown>0.0:
		return
	for driver in rivals:
		if float(driver["finish"])>=0.0:
			continue
		if absf(float(driver["z"])-distance)<7.0 and absf(float(driver["x"])-position_x)<.29:
			rival_contacts += 1
			rival_cooldown = 1.15
			speed *= .82
			driver["speed"] = float(driver["speed"])*.94
			_finish_drift(false)
			streak = 0
			_message("RIVAL CONTACT / KEEP IT CLEAN")
			return

func race_place() -> int:
	return finish_place if finish_place>0 else Rivals.place(rivals,distance)

func _finish_drift(clean: bool) -> void:
	if clean and drift_time >= .25 and drift_bend>=0 and not drift_awards.has(drift_bend):
		drift_awards.append(drift_bend)
		drift_count += 1
		var points = mini(120,40+floori(drift_time*40.0))
		drift_points += points
		_add_points(points)
		_message("CLEAN DRIFT +%d" % points)
	drifting = false
	drift_time = 0.0
	drift_bend = -1

func result() -> Dictionary:
	return {"game_id":game_id,"score":score,"lives":lives,"finished":finished,"cleared":cleared,"time":race_time,"distance":distance,"pickups":pickups,"near_misses":near_misses,"overtakes":overtakes,"collisions":collisions,"best_streak":best_streak,"splits":splits.duplicate(),"drifts":drift_count,"drift_points":drift_points,"car":car_index,"competitive":competitive,"place":finish_place,"rival_contacts":rival_contacts}

func grade() -> String:
	if not cleared:
		return "D"
	if collisions==0 and rival_contacts==0 and race_time<52.0 and pickups>=9:
		return "S"
	if race_time<58.0 and lives>=2:
		return "A"
	if lives>=2:
		return "B"
	return "C"
