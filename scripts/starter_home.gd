extends RefCounted
## Fixed pilot parcel adjacent to Lantern Cup. No mutable geometry in saves.
const ID = "home:lantern_01"
const NAME = "LANTERN COURT / UNIT 01"
const BLOCK = Vector2i(-2,-3)
const LOT = 0
const ACCESS_RECEIPT = "story:night_shift_contact"
const MAX_STORAGE = 20
const EXPANDED_STORAGE = 60
const STORAGE_UPGRADE_PRICE = 350
const WorldPlan = preload("res://scripts/world_plan.gd")
static func entry() -> Vector3:
	return Vector3((BLOCK.x + .5)*58.0-10.5,1.15,(BLOCK.y+.5)*58.0-WorldPlan.PUBLIC_FACADE_SETBACK-1.5)
