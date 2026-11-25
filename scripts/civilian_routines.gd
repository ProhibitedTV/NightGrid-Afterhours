extends RefCounted
## Deterministic district activity profiles. Fictional city design, not
## empirical population estimates. No teleportation or destination claims.
## Six four-hour knots: midnight, 04, 08, noon, 16, 20.
const PROFILES = {
	"VESPER MARKET":[0.25,0.12,0.65,0.92,0.84,0.65],
	"GLASSLINE":[0.12,0.08,0.92,0.85,0.90,0.30],
	"BRICKWATER":[0.30,0.32,0.84,0.74,0.69,0.46],
	"AFTERHOURS":[0.94,0.63,0.18,0.30,0.52,0.88],
	"NORTH QUAY":[0.22,0.28,0.72,0.83,0.78,0.55],
	"WEST DOCKS":[0.36,0.48,0.88,0.74,0.78,0.62],
	"HORIZON GARDENS":[0.14,0.10,0.50,0.78,0.83,0.44],
	"SOUTHWORKS":[0.23,0.25,0.80,0.77,0.70,0.38]
}
const ROLES = {
	"VESPER MARKET":["SHOPPER","SHOP_WORKER","RESIDENT"],
	"GLASSLINE":["OFFICE_WORKER","COMMUTER","VISITOR"],
	"BRICKWATER":["SHIFT_WORKER","RESIDENT","COURIER"],
	"AFTERHOURS":["NIGHT_SHIFT","PATRON","RESIDENT"],
	"NORTH QUAY":["VISITOR","COMMUTER","RESIDENT"],
	"WEST DOCKS":["DOCK_WORKER","SHIFT_WORKER","COURIER"],
	"HORIZON GARDENS":["RESIDENT","VISITOR","SERVICE_WORKER"],
	"SOUTHWORKS":["CIVIC_WORKER","SHIFT_WORKER","RESIDENT"]
}
static func demand(district: String,hour: float) -> float:
	if not is_finite(hour) or not PROFILES.has(district):
		return 0.0
	var phase := fposmod(hour,24.0)/4.0
	var i := floori(phase)
	var profile: Array = PROFILES[district]
	return lerpf(float(profile[i]),float(profile[(i+1)%6]),smoothstep(0.0,1.0,phase-float(i)))

static func identity(seed_value: int,id: String,district: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ int(id.hash()) ^ 781639
	var roles: Array = ROLES.get(district,["RESIDENT"])
	return {"role":roles[rng.randi_range(0,roles.size()-1)],"threshold":rng.randf()}

static func eligible(profile: Dictionary,district: String,hour: float) -> bool:
	if not PROFILES.has(district) or not is_finite(hour):
		return false
	var value: Variant = profile.get("threshold")
	if not (value is float or value is int) or not is_finite(float(value)) or float(value)<0.0 or float(value)>1.0:
		return false
	return float(value)<demand(district,hour)

## Local activity intent: does not imply a route reaches a home or job.
static func activity(profile: Dictionary,hour: float) -> String:
	if not is_finite(hour) or hour<0.0:
		return "RESTING"
	var h:=fposmod(hour,24.0)
	var role:=str(profile.get("role","RESIDENT"))
	if role in ["OFFICE_WORKER","COMMUTER","CIVIC_WORKER","SHOP_WORKER","SERVICE_WORKER"]:
		if (h>=6.0 and h<10.0) or (h>=16.0 and h<19.0):
			return "COMMUTE"
		if h>=11.5 and h<14.0:
			return "BREAK"
	if role in ["NIGHT_SHIFT","PATRON"] and (h>=19.0 or h<4.0):
		return "NIGHT_OUT"
	if role in ["DOCK_WORKER","SHIFT_WORKER","COURIER"] and ((h>=5.0 and h<9.0) or (h>=15.0 and h<19.0)):
		return "COMMUTE"
	if role=="SHOPPER" and h>=9.0 and h<20.0:
		return "ERRAND"
	return "RESTING"

static func dwell(intent:String) -> float:
	match intent:
		"COMMUTE": return 0.45
		"BREAK": return 5.0
		"NIGHT_OUT": return 4.0
		"ERRAND": return 3.0
	return 2.0
