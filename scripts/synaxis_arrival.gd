extends RefCounted
## A short, deterministic, skippable real-world scene. Positions are in HQ
## local coordinates. Cuts deliberately omit the intervening commute.
const SHOTS = [
	{"duration":2.7,"from":Vector3(0,1.15,-12.32),"to":Vector3(0,1.15,-8.95),"camera":Vector3(-2.2,2.65,-12.8),"look":Vector3(0,1.65,-9.8),"caption":"MORROW BAY / GLASSLINE / SHIFT CHANGE"},
	{"duration":2.0,"from":Vector3(0,1.15,-8.95),"to":Vector3(0,1.15,-8.95),"camera":Vector3(-1.12,2.35,-9.60),"look":Vector3(0,1.45,-8.2),"caption":"SYNAXIS OMNISYSTEMS / EMPLOYEE ACCESS"},
	{"duration":2.6,"from":Vector3(0,1.15,-8.95),"to":Vector3(0,1.15,-7.38),"camera":Vector3(1.0,2.7,-9.35),"look":Vector3(0,1.7,-7.7),"caption":""},
	{"duration":2.8,"from":Vector3(1.7,1.15,3.8),"to":Vector3(4.5,1.15,3.8),"camera":Vector3(6.85,2.6,4.8),"look":Vector3(4.0,1.55,2.8),"caption":"SYSTEMS OPERATIONS / DESK 04"},
	{"duration":.9,"from":Vector3(4.5,1.15,3.8),"to":Vector3(4.5,1.15,2.95),"camera":Vector3(3.0,2.45,3.95),"look":Vector3(4.5,1.45,1.8),"caption":""},
	{"duration":1.7,"from":Vector3(4.5,1.15,2.95),"to":Vector3(4.5,1.15,2.95),"camera":Vector3(3.0,2.45,3.95),"look":Vector3(4.5,1.45,1.8),"caption":"JUST ANOTHER SHIFT"}
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
	return {"position":start.lerp(end,clampf(elapsed/duration,0.0,1.0)),
		"motion":(end-start)/duration,"camera":shot["camera"],"look":shot["look"],
		"caption":shot["caption"],"gate_open":index==2,"desk":index==SHOTS.size()-1}
