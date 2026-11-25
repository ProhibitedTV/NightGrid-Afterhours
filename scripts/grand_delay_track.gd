extends RefCounted
## Authored geometry shared by handling and projection. Distances in meters.
## Each bend has a smooth entry/exit and a signed strength. No per-run RNG.
const BENDS = [
	[260.0,620.0,.78],[760.0,1090.0,-.68],
	[1290.0,1580.0,-.92],[1690.0,2040.0,.95],[2090.0,2350.0,-.65],
	[2450.0,2830.0,.85],[2900.0,3220.0,-1.0],[3300.0,3540.0,.62]
]
const HILLS = [[180.0,940.0,13.0],[1220.0,2250.0,-11.0],[2420.0,3250.0,17.0],[3250.0,3600.0,-7.0]]
const PACE = [17.0,33.0,50.0]
static func bend_index(z: float) -> int:
	for i in range(BENDS.size()):
		var segment: Array = BENDS[i]
		if z>=float(segment[0]) and z<float(segment[1]):
			return i
	return -1

static func curvature(z: float) -> float:
	var i = bend_index(z)
	if i<0:
		return 0.0
	var segment: Array = BENDS[i]
	var u = (z-float(segment[0]))/(float(segment[1])-float(segment[0]))
	return sin(PI*u)*sin(PI*u)*float(segment[2])

static func height_at(z: float) -> float:
	for hill in HILLS:
		if z>=float(hill[0]) and z<float(hill[1]):
			var u = (z-float(hill[0]))/(float(hill[1])-float(hill[0]))
			return sin(PI*u)*sin(PI*u)*float(hill[2])
	return 0.0

static func road_center(z: float, ahead: float) -> float:
	# Look-ahead bend projection. Center at the player's contact line is fixed.
	var d = clampf(ahead/460.0,0.0,1.0)
	return 116.0*d*d*(curvature(z+ahead*.33)*.5+curvature(z+ahead*.8)*.5)

static func pace_delta(z: float, elapsed: float) -> float:
	var district = mini(2,floori(clampf(z,0.0,3600.0)/1200.0))
	var previous = 0.0 if district==0 else float(PACE[district-1])
	var target = lerpf(previous,float(PACE[district]),clampf((z-district*1200.0)/1200.0,0.0,1.0))
	return elapsed-target
