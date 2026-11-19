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

# Each two-building parcel has an explicit design picked by the world artist.
# Columns ix=-3..2, rows iz=-3..2; major world blocks replace their entries.
const LOT_ROWS = [
	"V1/V3,V2/V4,V3/V1,G1/G2,G4/G3,G2/G1",
	"V4/V2,V1/V2,V2/V3,G3/G4,G1/G3,G4/G2",
	"V2/V1,V3/V4,V4/V1,G2/G3,G3/G1,G1/G4",
	"B1/B2,B4/B3,B3/B1,A2/A1,A4/A3,A1/A3",
	"B2/B4,B3/B2,B1/B4,A4/A2,A1/A4,A3/A2",
	"B4/B1,B2/B3,B4/B2,A1/A3,A2/A4,A4/A1"
]
const LOT_PROFILES = {
	"V1": {"height": 18.0, "width": 16.0, "depth": 23.0, "offset_z": -1.2, "wall": "766070", "material": "BRICK"},
	"V2": {"height": 24.0, "width": 14.5, "depth": 21.0, "offset_z": 0.8, "wall": "665e6c", "material": "CONCRETE"},
	"V3": {"height": 14.0, "width": 16.8, "depth": 25.0, "offset_z": 0.1, "wall": "745f58", "material": "BRICK"},
	"V4": {"height": 21.0, "width": 15.2, "depth": 22.0, "offset_z": -2.0, "wall": "536276", "material": "CONCRETE"},
	"G1": {"height": 67.0, "width": 16.7, "depth": 24.0, "offset_z": 0.4, "wall": "42596d", "material": "GLASS"},
	"G2": {"height": 48.0, "width": 14.9, "depth": 23.0, "offset_z": -1.2, "wall": "40556a", "material": "GLASS"},
	"G3": {"height": 38.0, "width": 16.0, "depth": 21.0, "offset_z": 0.1, "wall": "4b5f6f", "material": "METAL"},
	"G4": {"height": 60.0, "width": 15.5, "depth": 25.0, "offset_z": -0.4, "wall": "344b60", "material": "GLASS"},
	"B1": {"height": 14.0, "width": 16.8, "depth": 24.0, "offset_z": -0.8, "wall": "794c52", "material": "BRICK"},
	"B2": {"height": 20.0, "width": 14.9, "depth": 22.0, "offset_z": 0.0, "wall": "70625c", "material": "BRICK"},
	"B3": {"height": 27.0, "width": 15.7, "depth": 25.0, "offset_z": 0.8, "wall": "5d6065", "material": "METAL"},
	"B4": {"height": 17.0, "width": 16.2, "depth": 21.0, "offset_z": -1.2, "wall": "845e54", "material": "BRICK"},
	"A1": {"height": 41.0, "width": 16.5, "depth": 25.0, "offset_z": -0.5, "wall": "514563", "material": "CONCRETE"},
	"A2": {"height": 27.0, "width": 15.0, "depth": 23.0, "offset_z": 0.4, "wall": "4a425b", "material": "BRICK"},
	"A3": {"height": 46.0, "width": 16.0, "depth": 24.0, "offset_z": -1.0, "wall": "344258", "material": "METAL"},
	"A4": {"height": 32.0, "width": 15.5, "depth": 22.0, "offset_z": 1.0, "wall": "624d66", "material": "CONCRETE"}
}

# Eight fixed parcels have three pre-authored facade compositions. A seed
# selects one composition per *new game*; gameplay never rerolls any parcel.
# Roads, transit paths, foundations and all four story landmarks stay immutable.
const VARIANT_PARCELS = {
	"-3,-3": ["V3/V1", "V4/V2"],
	"-1,-2": ["V1/V4", "V2/V3"],
	"1,-3": ["G3/G1", "G4/G2"],
	"2,-1": ["G2/G4", "G1/G3"],
	"-3,1": ["B4/B1", "B2/B3"],
	"-1,2": ["B2/B4", "B1/B3"],
	"0,2": ["A2/A4", "A3/A1"],
	"2,0": ["A4/A2", "A1/A3"]
}

static func lot_variant_index(ix: int, iz: int, world_seed: int) -> int:
	if world_seed <= 0 or not VARIANT_PARCELS.has("%d,%d" % [ix, iz]):
		return 0
	return (world_seed + (ix + 3) * 13 + (iz + 3) * 7) % 3

static func lot_profile(ix: int, iz: int, building_index: int, world_seed: int = 0) -> Dictionary:
	assert(ix >= -3 and ix <= 2 and iz >= -3 and iz <= 2)
	assert(building_index == 0 or building_index == 1)
	var codes: PackedStringArray = LOT_ROWS[iz + 3].split(",")[ix + 3].split("/")
	var variant := lot_variant_index(ix, iz, world_seed)
	if variant > 0:
		var options: Array = VARIANT_PARCELS["%d,%d" % [ix, iz]]
		codes = str(options[variant - 1]).split("/")
	return LOT_PROFILES[codes[building_index]].duplicate()

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
