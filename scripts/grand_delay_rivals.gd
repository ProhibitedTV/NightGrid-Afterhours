extends RefCounted
## Fixed authored drivers. No rubber-banding, teleporting or real-world dependencies.
const Track = preload("res://scripts/grand_delay_track.gd")
const LENGTH = 3600.0
const DRIVERS = [
	{"name":"JET","top":78.0,"accel":24.0,"grip":.74,"x":0.0,"z":12.0,"color":"ff916d"},
	{"name":"NYX","top":75.0,"accel":29.0,"grip":1.12,"x":2.0,"z":8.0,"color":"c6a5ff"},
	{"name":"ROOK","top":71.0,"accel":25.0,"grip":1.30,"x":1.0,"z":22.0,"color":"f1cd82"}
]
static func new_grid() -> Array[Dictionary]:
	var grid: Array[Dictionary] = []
	for driver in DRIVERS:
		var row: Dictionary = driver.duplicate()
		row["speed"] = 0.0
		row["finish"] = -1.0
		row["home"] = float(row["x"])
		row["kind"] = "rival"
		row["contact"] = 0.0
		grid.append(row)
	return grid

static func advance(grid: Array[Dictionary], obstacles: Array[Dictionary], course: Array[Dictionary], dt: float, elapsed: float) -> void:
	for driver in grid:
		if float(driver["finish"])>=0.0:
			continue
		var z: float = driver["z"]
		var x: float = driver["x"]
		var bend = Track.curvature(z+35.0)
		var target: float = clampf(float(driver["home"])+bend*.26,.12,1.88)
		var target_speed: float = float(driver["top"])-absf(bend)*6.0/float(driver["grip"])
		var nearest = 125.0
		# Only hazards in the driver's forward range influence their choice.
		# The full authored course supplies static gates not yet spawned for the player.
		for item in course:
			if item["kind"]!="wall":
				continue
			var gap = float(item["z"])-z
			if gap>0.0 and gap<nearest and absf(float(item["x"])-target)<.52:
				nearest = gap
				target = 1.35 if float(item["x"])<1.0 else (.65 if float(item["x"])>1.0 else (0.3 if x<1.0 else 1.7))
		for item in obstacles:
			if item["kind"]!="traffic":
				continue
			var gap = float(item["z"])-z
			if gap>0.0 and gap<nearest and absf(float(item["x"])-target)<.52:
				nearest = gap
				target = 1.50 if float(item["x"])<1.0 else (.50 if float(item["x"])>1.0 else (0.3 if x<1.0 else 1.7))
				if gap<36.0 and absf(float(item["x"])-x)<.40:
					target_speed = minf(target_speed,45.0)
		driver["x"] = move_toward(x,target,1.20*float(driver["grip"])*dt)
		var old_speed: float = driver["speed"]
		var speed = move_toward(old_speed,target_speed,(float(driver["accel"]) if target_speed>old_speed else 46.0)*dt)
		driver["speed"] = speed
		driver["z"] = minf(LENGTH,z+speed*dt)
		driver["contact"] = maxf(0.0,float(driver["contact"])-dt)
		if float(driver["z"])>=LENGTH:
			driver["finish"] = elapsed-dt+clampf((LENGTH-z)/maxf(speed,.01),0.0,dt)

static func place(grid: Array[Dictionary], distance: float, finish_time: float = -1.0) -> int:
	var rank = 1
	for driver in grid:
		if finish_time>=0.0:
			if float(driver["finish"])>=0.0 and float(driver["finish"])<=finish_time:
				rank += 1
		elif float(driver["z"])>distance:
			rank += 1
	return rank
