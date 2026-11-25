extends RefCounted
## All three cars are unlocked; no persistent purchases or gameplay advantage sold.
const CARS = [
	{"name":"MIRAGE GT","tag":"BALANCED / STREET SPEC","top":76.0,"accel":24.0,"grip":1.0,"boost":98.0,"brake":85.0,"pitch":1.0,"color":"79efd4"},
	{"name":"DEADLINE RS","tag":"HIGH SPEED / LIGHT REAR","top":84.0,"accel":21.0,"grip":.76,"boost":105.0,"brake":76.0,"pitch":1.12,"color":"ffa36c"},
	{"name":"PATCHBACK XR","tag":"QUICK RESPONSE / HIGH GRIP","top":73.0,"accel":30.0,"grip":1.23,"boost":94.0,"brake":96.0,"pitch":.88,"color":"c3b2fa"}
]
static func spec(index: int) -> Dictionary:
	return CARS[clampi(index,0,CARS.size()-1)]
