extends RefCounted
## Ground-floor zoning shared by physical collision, encounter and radar.
const BREAKROOM_FRONT=6.05
const BREAKROOM_WEST=-8.32
const BREAKROOM_EAST=-1.95
const BREAKROOM_REAR=9.85
const DOOR_LEFT=-5.15
const DOOR_RIGHT=-3.25
const BREAKROOM_EDGES=[
	[Vector2(BREAKROOM_WEST,BREAKROOM_FRONT),Vector2(DOOR_LEFT,BREAKROOM_FRONT)],
	[Vector2(DOOR_RIGHT,BREAKROOM_FRONT),Vector2(BREAKROOM_EAST,BREAKROOM_FRONT)]
]
static func in_breakroom(local:Vector3) -> bool:
	return local.is_finite() and local.x>BREAKROOM_WEST+.10 and local.x<BREAKROOM_EAST-.10 and local.z>BREAKROOM_FRONT+.12 and local.z<BREAKROOM_REAR and absf(local.y-1.15)<.8
