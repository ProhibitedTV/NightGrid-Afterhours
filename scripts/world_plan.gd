extends RefCounted
## Morrow Bay is authored first; seeded procedural detail fills the authored blocks.
## Block keys are fixed map coordinates and must not depend on the random generator.
const CITY_NAME = "MORROW BAY"
const LANDMARK_BLOCKS = {
	"-2,-2": "LANTERN COURT",
	"0,-2": "HELIX TERMINAL",
	"-2,0": "FOUNDRY COMMONS",
	"1,1": "SABLE SQUARE"
}
const LANDMARK_SUMMARIES = {
	"LANTERN COURT": "A night market run by independent vendors.",
	"HELIX TERMINAL": "The elevated transit node dividing the corporate city.",
	"FOUNDRY COMMONS": "An industrial lot reclaimed by the community.",
	"SABLE SQUARE": "The city's unofficial late-night performance plaza."
}
const BLOCK_SIZE = 58.0

static func landmark_for_block(ix: int, iz: int) -> String:
	return LANDMARK_BLOCKS.get("%d,%d" % [ix, iz], "")

static func landmark_center(name: String) -> Vector3:
	for key in LANDMARK_BLOCKS:
		if LANDMARK_BLOCKS[key] == name:
			var coords: PackedStringArray = key.split(",")
			return Vector3((float(int(coords[0])) + 0.5) * BLOCK_SIZE, 0.0, (float(int(coords[1])) + 0.5) * BLOCK_SIZE)
	return Vector3.ZERO

static func nearby_landmark(position: Vector3) -> String:
	for name in LANDMARK_SUMMARIES:
		var center := landmark_center(name)
		if Vector2(center.x - position.x, center.z - position.z).length() <= 31.0:
			return name
	return ""

static func district_at(position: Vector3) -> String:
	if position.x < 0.0:
		return "VESPER MARKET" if position.z < 0.0 else "BRICKWATER"
	return "GLASSLINE" if position.z < 0.0 else "AFTERHOURS"
