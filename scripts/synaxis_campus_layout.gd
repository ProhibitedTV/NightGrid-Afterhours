extends RefCounted
## One corporate-owned block; no unrelated east-lot building.
## Local coordinates relative to the retained west tower and street entrance.
const PODIUM=Rect2(8.5,-5.5,21.0,30.0)
const BREAKROOM=Rect2(17.0,17.5,12.5,7.0)
const PARTY_OFFSET=Vector3(27.2,0,14.45)
const GROSS_AREA=970.0
const WALL_EDGES=[
	[Vector2(8.5,-5.5),Vector2(29.5,-5.5)],
	[Vector2(29.5,-5.5),Vector2(29.5,24.5)],
	[Vector2(29.5,24.5),Vector2(8.5,24.5)],
	[Vector2(8.5,10.0),Vector2(8.5,24.5)],
	# North conference and training suites, opening onto 3m cross-corridor.
	[Vector2(8.5,3.25),Vector2(11.0,3.25)],
	[Vector2(13.0,3.25),Vector2(22.0,3.25)],
	[Vector2(24.0,3.25),Vector2(29.5,3.25)],
	[Vector2(19.0,-5.5),Vector2(19.0,3.25)],
	# Facilities and employee lounge flank a 3m north/south corridor.
	[Vector2(8.5,6.25),Vector2(10.0,6.25)],
	[Vector2(12.0,6.25),Vector2(14.0,6.25)],
	[Vector2(14.0,6.25),Vector2(14.0,24.5)],
	[Vector2(17.0,6.25),Vector2(21.0,6.25)],
	[Vector2(23.0,6.25),Vector2(29.5,6.25)],
	[Vector2(17.0,6.25),Vector2(17.0,19.5)],
	[Vector2(17.0,21.5),Vector2(17.0,24.5)],
	[Vector2(17.0,17.5),Vector2(29.5,17.5)]
]
static func contains(local:Vector3) -> bool:
	return local.is_finite() and PODIUM.grow(.1).has_point(Vector2(local.x,local.z))
static func in_breakroom(local:Vector3) -> bool:
	return local.is_finite() and absf(local.y-1.15)<.8 and BREAKROOM.grow(-.12).has_point(Vector2(local.x,local.z))
