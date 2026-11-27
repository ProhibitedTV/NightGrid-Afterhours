extends RefCounted
## Skippable staged commute through the actual HQ. Cuts change the camera,
## never the player's route. HQ-local coordinates shared with its floor plan.
const PARTITION_NEAR_Z = -5.95
const PARTITION_FAR_Z = -.4
const SHOTS = [
	{"duration":2.7,"from":Vector3(0,1.15,-12.32),"to":Vector3(0,1.15,-8.95),"camera":Vector3(-2.2,2.65,-12.8),"camera_end":Vector3(-1.8,2.55,-12.35),"look":Vector3(0,1.65,-9.8),"caption":"MORROW BAY / GLASSLINE / SHIFT CHANGE"},
	{"duration":2.0,"from":Vector3(0,1.15,-8.95),"to":Vector3(0,1.15,-8.95),"camera":Vector3(-1.12,2.35,-9.60),"look":Vector3(0,1.45,-8.2),"caption":"SYNAXIS OMNISYSTEMS / EMPLOYEE ACCESS"},
	{"duration":2.2,"from":Vector3(0,1.15,-8.95),"to":Vector3(0,1.15,-6.85),"camera":Vector3(1.0,2.7,-9.35),"look":Vector3(0,1.7,-7.7),"caption":"CAM 004 / EMPLOYEE INGRESS","surveillance":true,"fov":76.0},
	{"duration":1.7,"from":Vector3(0,1.15,-6.85),"to":Vector3(2.15,1.15,-6.85),"camera":Vector3(2.9,2.55,-6.55),"look":Vector3(1.0,1.5,-6.85),"caption":""},
	{"duration":4.0,"from":Vector3(2.15,1.15,-6.85),"to":Vector3(2.15,1.15,-.95),"camera":Vector3(1.08,2.65,-5.6),"camera_end":Vector3(1.08,2.65,.3),"look":Vector3(2.15,1.55,-5.75),"look_end":Vector3(2.15,1.55,.15),"caption":""},
	{"duration":3.5,"from":Vector3(2.15,1.15,-.95),"to":Vector3(2.15,1.15,3.8),"camera":Vector3(3.0,2.6,3.85),"look":Vector3(2.15,1.5,1.6),"caption":"CORPORATE IP SECURITY"},
	{"duration":1.8,"from":Vector3(2.15,1.15,3.8),"to":Vector3(4.5,1.15,3.8),"camera":Vector3(6.85,2.6,4.8),"look":Vector3(4.0,1.55,2.8),"caption":"DESK 04"},
	{"duration":.9,"from":Vector3(4.5,1.15,3.8),"to":Vector3(4.5,1.15,2.95),"camera":Vector3(3.0,2.45,3.95),"look":Vector3(4.5,1.45,1.8),"caption":""},
	{"duration":1.7,"from":Vector3(4.5,1.15,2.95),"to":Vector3(4.5,1.15,2.95),"camera":Vector3(3.0,2.45,3.95),"camera_end":Vector3(3.25,2.35,3.75),"look":Vector3(4.5,1.45,1.8),"caption":"JUST ANOTHER SHIFT"}
]
var index := 0
var elapsed := 0.0

func advance(delta: float) -> bool:
	elapsed += maxf(0.0,delta)
	while index < SHOTS.size() and elapsed >= float(SHOTS[index]["duration"]):
		elapsed -= float(SHOTS[index]["duration"])
		index += 1
	return index < SHOTS.size()

func sample() -> Dictionary:
	if index >= SHOTS.size():
		return {}
	var shot: Dictionary = SHOTS[index]
	var start: Vector3 = shot["from"]
	var end: Vector3 = shot["to"]
	var duration := float(shot["duration"])
	var progress := clampf(elapsed/duration,0.0,1.0)
	var camera_start: Vector3=shot["camera"]
	var camera_end: Vector3=shot.get("camera_end",camera_start)
	var look_start: Vector3=shot["look"]
	var look_end: Vector3=shot.get("look_end",look_start)
	return {"position":start.lerp(end,progress),
		"motion":(end-start)/duration,"camera":camera_start.lerp(camera_end,progress),
		"look":look_start.lerp(look_end,progress),"caption":shot["caption"],
		"gate_open":index==2,"desk":index==SHOTS.size()-1,
		"surveillance":bool(shot.get("surveillance",false)), "fov":float(shot.get("fov",60.0))}
